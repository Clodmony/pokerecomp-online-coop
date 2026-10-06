class_name PokeCoopHost
extends RefCounted

## The authoritative side of a co-op session. Clients send intentions; this
## validates them against the campaign, the players and the running battles, and
## answers every connected client with the state they may see.

const PROTOCOL: int = 1
## A walk step, or a ledge hop over the cell between.
const MAX_STEP_CELLS: int = 2
const SHUTDOWN_GRACE_MSEC: int = 2000
const MAX_TRAINER_NAME: int = 16
const MAX_WIN_TEXT: int = 512
## How often a changed campaign is written while no battle runs, so a host that
## crashes loses at most this much of what the windows did.
var autosave_msec: int = 30000

var data: GameData = null
var campaign: PokeCoopCampaign = null
var players: Dictionary = {}
var battles: Dictionary = {}
var encounters: Dictionary = {}
var transport: PokeCoopTransport = null
var save_path: String = ""
var allow_new_players: bool = false
var seeds: RandomNumberGenerator = RandomNumberGenerator.new()
var ended: bool = false
var _closing_at: int = -1
var _refused_peers: Dictionary = {}
var _peers: Dictionary = {}
var _badge_flags: Array[int] = []
var _last_seq: Dictionary = {}
## Each player's final battle views not yet delivered: a participant who was
## away when a battle ended is told on coming back.
var _finished: Dictionary = {}
var _box_sent: Dictionary = {}
var trades: PokeCoopTrades = null
var _controllers: Dictionary = {}
var _changed: bool = false
var _written_at: int = 0
var _saves: int = 0
var _saved_by: String = ""
var _saved_unix: float = 0.0


static func create(
	game_data: GameData, run: PokeCoopCampaign, link: PokeCoopTransport
) -> PokeCoopHost:
	if game_data == null or run == null or link == null:
		return null
	var out := PokeCoopHost.new()
	out.data = game_data
	out.campaign = run
	out.transport = link
	out._badge_flags = PokeCoopOwnership.badge_flags(game_data)
	out.trades = PokeCoopTrades.create(game_data)
	return out


func add_player(player_name: String, trainer_id: int) -> PokeCoopPlayer:
	var created := PokeCoopPlayer.create(campaign.take_player_id(), player_name, trainer_id)
	created.money = PokeCoopPolicy.new_player_money()
	players[created.player_id] = created
	return created


func adopt_players(loaded: Array) -> void:
	for member: PokeCoopPlayer in loaded:
		member.connected = false
		member.battle_id = ""
		players[member.player_id] = member


## A battle a client may ask for by id: `kind` (`wild` or `trainer`), `species`,
## `level` and optional `moves`, or `trainer_class` and `trainer_index`; `unique`,
## `victory_flags` and `badge` for story fights.
func register_encounter(encounter_id: String, descriptor: Dictionary) -> void:
	encounters[encounter_id] = descriptor.duplicate(true)


func player(player_id: String) -> PokeCoopPlayer:
	return players.get(player_id, null)


func poll() -> void:
	if ended:
		return
	for event: Dictionary in transport.poll():
		var peer: int = int(event["peer"])
		var kind: StringName = StringName(event["kind"])
		if kind == PokeCoopTransport.DISCONNECTED:
			_on_disconnected(peer)
		elif kind == PokeCoopTransport.MESSAGE and _closing_at < 0 and not _refused_peers.has(peer):
			_on_message(peer, event["message"])
	_drop_refused()
	_end_abandoned()
	_announce_stand_ins()
	_autosave()
	if _closing_at >= 0 and (_peers.is_empty() or Time.get_ticks_msec() >= _closing_at):
		transport.close()
		ended = true


func _on_message(peer: int, message: Dictionary) -> void:
	var kind: String = PokeCoopTransport.text(message.get("type"))
	if kind == "hello":
		_hello(peer, message)
		return
	var sender: PokeCoopPlayer = player(String(_peers.get(peer, "")))
	var seq: int = PokeCoopTransport.number(message.get("seq"), -1)
	if sender == null:
		transport.send(peer, _rejected(seq, &"hello_first"))
		return
	if seq <= int(_last_seq.get(sender.player_id, 0)):
		transport.send(peer, _rejected(seq, &"duplicate"))
		return
	_last_seq[sender.player_id] = seq
	var refusal: StringName = _dispatch(sender, kind, message)
	_changed = _changed or refusal == &""
	if refusal != &"":
		transport.send(peer, _rejected(seq, refusal))
	broadcast()


func _dispatch(sender: PokeCoopPlayer, kind: String, message: Dictionary) -> StringName:
	var battle_id: String = PokeCoopTransport.text(message.get("battle"))
	match kind:
		"move":
			return step(sender, _vector(message.get("map")), _vector(message.get("cell")),
				PokeCoopTransport.number(message.get("facing"), sender.facing), PokeCoopTransport.number(message.get("warp")) == 1)
		"start_battle":
			return start_battle(sender, PokeCoopTransport.text(message.get("encounter")))
		"window_battle":
			return start_window_battle(sender, message)
		"command":
			var command: Variant = message.get("command", {})
			return battle_command(sender, battle_id, command if command is Dictionary else {})
		"suggest":
			var suggestion: Variant = message.get("suggestion", {})
			return suggest(sender, battle_id, suggestion if suggestion is Dictionary else {})
		"join":
			return join_battle(sender, battle_id)
		"world":
			return apply_world(sender, PokeCoopOwnership.well_formed(message.get("patch", {})))
		"party":
			return apply_party(sender, message)
		"save":
			var refused: StringName = save_checkpoint()
			if refused == &"":
				_saves += 1
				_saved_by = sender.player_id
			return refused
		"trade":
			var swaps: int = trades.swaps
			var answer: StringName = trades.handle(sender, message, players)
			if trades.swaps != swaps and battles.is_empty():
				_write_campaign()
			return answer
	return &"unknown_message"


func _hello(peer: int, message: Dictionary) -> void:
	var refusal: StringName = _hello_refusal(message)
	var joining: PokeCoopPlayer = player(PokeCoopTransport.text(message.get("player_id")))
	var known: Variant = message.get("known", {})
	if joining == null and known is Dictionary:
		joining = player(PokeCoopTransport.text((known as Dictionary).get(campaign.campaign_id)))
	if refusal == &"" and joining == null:
		joining = _returning(PokeCoopTransport.text(message.get("name")))
	if refusal == &"" and joining == null:
		if not allow_new_players:
			refusal = &"unknown_player"
		else:
			var joined_before: int = players.size()
			var brought: Gen2SaveData = _brought_save(message.get("save", null))
			joining = add_player(PokeCoopTransport.text(message.get("name")), seeds.randi() & 0xFFFF)
			if brought != null:
				PokeCoopPolicy.import_save(
					brought, joining, campaign if joined_before == 0 else null, _badge_flags
				)
			else:
				PokeCoopPolicy.set_up_new_player(
					data, joining, PokeCoopTransport.number(message.get("starter")), joined_before
				)
			PokeCoopPolicy.hand_over_gifts(campaign, joining)
	if refusal == &"" and joining.connected:
		refusal = &"already_connected"
	if refusal != &"":
		transport.send(peer, _rejected(-1, refusal))
		_refused_peers[peer] = Time.get_ticks_msec() + SHUTDOWN_GRACE_MSEC
		return
	_peers[peer] = joining.player_id
	_box_sent.erase(peer)
	joining.connected = true
	for session: PokeCoopBattleSession in battles.values():
		session.set_absent(joining.player_id, false)
	transport.send(peer, {
		"type": "welcome", "protocol": PROTOCOL, "player_id": joining.player_id, "campaign": campaign.campaign_id,
		"last_seq": int(_last_seq.get(joining.player_id, 0)),
	})
	broadcast()


## A saved player not here, by name: a device that lost its id or dialled another address.
func _returning(player_name: String) -> PokeCoopPlayer:
	for member: PokeCoopPlayer in players.values():
		if not member.connected and member.name == player_name and not player_name.is_empty():
			return member
	return null


## A new player's own single-player save, rebuilt from vetted parts: Pokémon that pass
## the game's rules, the world-state keys a window could send, and where they stood.
func _brought_save(raw: Variant) -> Gen2SaveData:
	if not raw is Dictionary or PokeCoopTransport.text(raw.get("game_id")) != String(data.id):
		return null
	var save := Gen2SaveData.new()
	save.game_id = data.id
	save.rom_sha1 = data.sha1
	save.slot = 0
	save.player_name = PokeCoopTransport.text(raw.get("player_name"))
	save.player_id = PokeCoopTransport.number(raw.get("player_id")) & 0xFFFF
	save.run_rules = Gen2Rules.new()
	for row: Variant in raw.get("party") if raw.get("party") is Array else []:
		save.party.append(PokeCoopPlayer.mon_from(row))
	var boxes: Variant = raw.get("boxes")
	for at: int in mini((boxes as Array).size(), save.boxes.size()) if boxes is Array else 0:
		for row: Variant in boxes[at] if boxes[at] is Array else []:
			if row != null and (save.boxes[at] as Gen2SaveBox).put(PokeCoopPlayer.mon_from(row)).get("ok") != true:
				return null
	save.current_box = clampi(PokeCoopTransport.number(raw.get("current_box")), 0, save.boxes.size() - 1)
	if save.party.has(null) or not bool(Gen2SaveValidator.validate(save, data).get("ok", false)):
		return null
	var world: Variant = raw.get("world")
	if world is Dictionary and not (world as Dictionary).is_empty():
		save.world = Gen2WorldSnapshot.new()
		save.world.map_id = _vector(world.get("map"))
		save.world.player_cell = _vector(world.get("player_cell"))
		save.world.player_facing = PokeCoopTransport.number(world.get("player_facing"))
		var kept: Dictionary = {}
		PokeCoopOwnership.apply_patch(kept, PokeCoopOwnership.well_formed(
			PokeCoopOwnership.patch({}, world.get("world_state") if world.get("world_state") is Dictionary else {})
		))
		save.world.world_state = Gen2WorldState.from_dict(kept)
	return save


func _hello_refusal(message: Dictionary) -> StringName:
	if PokeCoopTransport.number(message.get("protocol"), -1) != PROTOCOL:
		return &"protocol_mismatch"
	if StringName(PokeCoopTransport.text(message.get("game_id"))) != campaign.game_id \
			or PokeCoopTransport.text(message.get("rom_sha1")) != campaign.rom_sha1:
		return &"content_mismatch"
	return &""


func _autosave() -> void:
	if _changed and battles.is_empty() and _closing_at < 0 \
			and Time.get_ticks_msec() - _written_at >= autosave_msec and _write_campaign() == OK:
		_changed = false


## A battle everyone has left for longer than a stand-in waits ends as fled,
## so it no longer holds up every save.
func _end_abandoned() -> void:
	for session: PokeCoopBattleSession in battles.values():
		if session.everyone_away_for() >= PokeCoopPolicy.STAND_IN_MSEC:
			session.abandon()
			_finish(session)
			broadcast()


## A stand-in's turn starts with no message to answer, so it is announced.
func _announce_stand_ins() -> void:
	var changed: bool = false
	for session: PokeCoopBattleSession in battles.values():
		var now: String = session.controller()
		changed = changed or String(_controllers.get(session.id, now)) != now
		_controllers[session.id] = now
	if changed and _closing_at < 0:
		broadcast()


## A refused client is let go after the grace a refusal needs to arrive.
func _drop_refused() -> void:
	for peer: int in _refused_peers.keys():
		if Time.get_ticks_msec() >= int(_refused_peers[peer]):
			_refused_peers.erase(peer)
			transport.drop(peer)


func _on_disconnected(peer: int) -> void:
	_refused_peers.erase(peer)
	var leaving: PokeCoopPlayer = player(String(_peers.get(peer, "")))
	_peers.erase(peer)
	_box_sent.erase(peer)
	if leaving == null:
		return
	leaving.connected = false
	trades.leave(leaving.player_id, players)
	for session: PokeCoopBattleSession in battles.values():
		if session.involves(leaving.player_id):
			session.set_absent(leaving.player_id, true)
	if _closing_at < 0:
		broadcast()


## A step on the current map, or a [param warp] the client's own world made, trusted
## until the shared world simulation can check collision and warps.
func step(
	mover: PokeCoopPlayer, to_map: Vector2i, to_cell: Vector2i, toward: int, warp: bool = false
) -> StringName:
	if not mover.is_free():
		return &"in_battle"
	var distance: int = absi(to_cell.x - mover.cell.x) + absi(to_cell.y - mover.cell.y)
	if not warp and to_map == mover.map and distance > MAX_STEP_CELLS:
		return &"not_adjacent"
	mover.place(to_map, to_cell, toward)
	return &""


## A window's world-state patch, the shared half to the campaign and the rest
## to [param sender]. Trusted until the host simulates the world itself.
func apply_world(sender: PokeCoopPlayer, changes: Dictionary) -> StringName:
	var halves: Dictionary = PokeCoopOwnership.route(changes, _badge_flags)
	var flags_before: Dictionary = campaign.flags.duplicate()
	var held_before: Dictionary = sender.items.duplicate()
	campaign.apply_world_patch(halves[PokeCoopOwnership.CAMPAIGN], _badge_flags)
	sender.apply_world_patch(halves[PokeCoopOwnership.PLAYER])
	PokeCoopPolicy.share_gifts(campaign, sender, players.values(), flags_before, held_before)
	return &""


## A window's party and PC after a heal, a gift, a deposit or a release.
## Refused in a battle, whose results the host writes itself.
func apply_party(sender: PokeCoopPlayer, message: Dictionary) -> StringName:
	var rows: Variant = message.get("rows", [])
	var stored: Variant = message.get("boxes", null)
	if not sender.is_free():
		return &"in_battle"
	if not rows is Array or (stored != null and not stored is Array):
		return &"invalid_party"
	if not message.has("rev"):
		return &"" if sender.replace_team(rows) else &"invalid_party"
	return sender.replace_holdings(
		rows, stored, PokeCoopTransport.number(message.get("current_box")),
		PokeCoopTransport.number(message.get("rev"), -1)
	)


func start_battle(initiator: PokeCoopPlayer, encounter_id: String) -> StringName:
	var descriptor: Dictionary = encounters.get(encounter_id, {})
	if descriptor.is_empty():
		return &"unknown_encounter"
	if not initiator.is_free():
		return &"already_in_battle"
	var battle_id: String = campaign.take_battle_id()
	var unique: bool = _is_unique(descriptor)
	if unique and not campaign.claim_encounter(encounter_id, battle_id):
		return &"encounter_taken"
	var info: Dictionary = descriptor.duplicate(true)
	info["id"] = encounter_id
	var session: PokeCoopBattleSession = PokeCoopBattleSession.start(
		data, battle_id, seeds.randi(), initiator, _enemy_party(descriptor), info, _badge_mask()
	)
	if session == null:
		if unique:
			campaign.release_encounter(encounter_id, battle_id)
		return &"cannot_start"
	battles[battle_id] = session
	return &""


## A battle the player's own world opened, its enemies trusted until the host simulates
## the world. A second window walking into a trainer joins; a beaten one stays beaten.
## The world's script sets the flags; the host records who was defeated.
func start_window_battle(initiator: PokeCoopPlayer, message: Dictionary) -> StringName:
	if not initiator.is_free():
		return &"already_in_battle"
	var enemies: Array = []
	var rows: Variant = message.get("enemy", [])
	for row: Variant in rows if rows is Array else []:
		var enemy: Gen2BattleMon = Gen2SaveBattleAdapter.to_battle_mon(data, PokeCoopPlayer.mon_from(row))
		if enemy == null:
			return &"invalid_enemy"
		enemies.append(enemy)
	var party: Gen2Party = Gen2Party.create(enemies)
	if party == null:
		return &"invalid_enemy"
	var trainer: bool = PokeCoopTransport.text(message.get("kind"), "wild") == "trainer"
	var trainer_class: int = PokeCoopTransport.number(message.get("trainer_class"))
	var trainer_index: int = PokeCoopTransport.number(message.get("trainer_index"))
	var encounter_id: String = _window_encounter(trainer, trainer_class, trainer_index,
		(enemies[0] as Gen2BattleMon).species, _vector(message.get("map")))
	var unique: bool = not encounter_id.is_empty()
	if unique and campaign.encounter_state(encounter_id) == PokeCoopCampaign.ENCOUNTER_DONE:
		return &"encounter_done"
	if unique and campaign.encounter_state(encounter_id) == PokeCoopCampaign.ENCOUNTER_ACTIVE:
		return _join_window_battle(initiator, encounter_id)
	var battle_id: String = campaign.take_battle_id()
	if unique and not campaign.claim_encounter(encounter_id, battle_id):
		return &"encounter_taken"
	var info: Dictionary = {
		"id": encounter_id if unique else "window:%s" % battle_id,
		"kind": "trainer" if trainer else "wild", "unique": unique,
		"trainer_class": trainer_class if trainer else 0, "trainer_index": trainer_index,
		"trainer_name": PokeCoopTransport.text(message.get("trainer_name")).left(MAX_TRAINER_NAME),
		"win_text": PokeCoopTransport.text(message.get("win_text")).left(MAX_WIN_TEXT),
		"gym": message.get("gym") is bool and bool(message.get("gym")),
	}
	var session: PokeCoopBattleSession = PokeCoopBattleSession.start(
		data, battle_id, seeds.randi(), initiator, party, info, _badge_mask()
	)
	if session == null:
		if unique:
			campaign.release_encounter(encounter_id, battle_id)
		return &"cannot_start"
	battles[battle_id] = session
	return &""


## One encounter for the whole campaign: a trainer by class and index, or one
## of Red and Blue's one-off wild Pokémon where it stands; empty for the grass.
static func _window_encounter(
	trainer: bool, trainer_class: int, trainer_index: int, species: int, map: Vector2i
) -> String:
	if trainer:
		return "trainer:%d:%d" % [trainer_class, trainer_index]
	if PokeCoopPolicy.UNIQUE_WILD.has(species):
		return "static:%d:%d:%d" % [species, map.x, map.y]
	return ""


## A second window opened a trainer the campaign is already fighting.
func _join_window_battle(joiner: PokeCoopPlayer, encounter_id: String) -> StringName:
	for session: PokeCoopBattleSession in battles.values():
		if String(session.encounter.get("id", "")) != encounter_id:
			continue
		return session.request_join(data, joiner)
	return &"encounter_taken"


static func _is_unique(descriptor: Dictionary) -> bool:
	return bool(descriptor.get("unique", false)) \
		or not (descriptor.get("victory_flags", []) as Array).is_empty()


func _enemy_party(descriptor: Dictionary) -> Gen2Party:
	if String(descriptor.get("kind", "wild")) == "trainer":
		return Gen2TrainerParty.build(
			data, int(descriptor.get("trainer_class", 0)), int(descriptor.get("trainer_index", 0))
		)
	var species: int = int(descriptor.get("species", 0))
	var level: int = int(descriptor.get("level", 1))
	var moves: Array = descriptor.get("moves", data.moves_at_level(species, level))
	var wild: Gen2BattleMon = Gen2BattleMon.create(
		data, species, level, moves, Gen2BattleMon.random_dvs(seeds)
	)
	return null if wild == null else Gen2Party.of(wild)


## Gen 1 keeps Kanto's eight above Johto's in the engine's mask.
func _badge_mask() -> int:
	if data.generation == RomRegistry.GEN1:
		return campaign.badges << Gen2WorldState.KANTO_BADGE_FIRST
	return campaign.badges


func battle_command(sender: PokeCoopPlayer, battle_id: String, command: Dictionary) -> StringName:
	var session: PokeCoopBattleSession = battles.get(battle_id, null)
	if session == null:
		return &"unknown_battle"
	var result: Dictionary = session.submit(sender, command)
	if not bool(result.get("ok", false)):
		return StringName(result.get("reason", &"refused"))
	if session.phase() == PokeCoopBattleSession.OVER:
		_finish(session)
	return &""


func suggest(sender: PokeCoopPlayer, battle_id: String, suggestion: Dictionary) -> StringName:
	var session: PokeCoopBattleSession = battles.get(battle_id, null)
	return &"unknown_battle" if session == null else session.suggest(sender.player_id, suggestion)


func join_battle(joiner: PokeCoopPlayer, battle_id: String) -> StringName:
	var session: PokeCoopBattleSession = battles.get(battle_id, null)
	return &"unknown_battle" if session == null else session.request_join(data, joiner)


## Writes each participant's Pokémon back by uid, pays and commits a win once,
## and takes the battle off the host, so nothing about it can apply twice.
func _finish(session: PokeCoopBattleSession) -> void:
	var outcome: StringName = session.outcome()
	var by_owner: Dictionary = session.results()
	for owner_id: String in by_owner:
		var holder: PokeCoopPlayer = player(owner_id)
		for row: Dictionary in by_owner[owner_id]:
			holder.absorb_battle_mon(String(row["uid"]), row["mon"])
	var encounter_id: String = String(session.encounter.get("id", ""))
	var unique: bool = _is_unique(session.encounter)
	for player_id: String in session.participants:
		player(player_id).apply_world_patch({"seen_species": {"set": session.seen.duplicate(), "erase": []}})
	if outcome == PokeCoopBattleSession.CAUGHT:
		_file_catch(session.catch)
	var prizes: Dictionary = _pay(session) if outcome == &"won" else {}
	if unique and (outcome == &"won" or outcome == PokeCoopBattleSession.CAUGHT):
		campaign.commit("victory:" + encounter_id, _victory_changes(session.encounter, encounter_id))
	elif unique:
		campaign.release_encounter(encounter_id, session.id)
	var final_view: Dictionary = session.view()
	final_view["evolvable"] = session.evolvable_uids()
	final_view["prizes"] = prizes
	for player_id: String in session.participants + session.pending_players():
		var participant: PokeCoopPlayer = player(player_id)
		participant.battle_id = ""
		participant.resume_exploration()
		(_finished.get_or_add(player_id, []) as Array).append(final_view)
	battles.erase(session.id)
	if battles.is_empty():
		_write_campaign()


## The wild a ball held, filed once with its recipient as its trainer: the team
## if there is room, else the box, and caught in their own Pokédex.
func _file_catch(caught: Dictionary) -> void:
	var recipient: PokeCoopPlayer = player(String(caught.get("recipient", "")))
	var wild: Gen2BattleMon = caught.get("mon", null)
	if recipient == null or wild == null:
		return
	var saved: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(wild)
	saved.ot_id = recipient.trainer_id
	saved.original_trainer = recipient.name
	saved.caught_level = wild.level
	if recipient.add_mon(saved).is_empty():
		recipient.store_mon(saved)
	var species: int = wild.persistent_species()
	recipient.apply_world_patch({
		"caught_species": {"set": {species: true}, "erase": []},
		"seen_species": {"set": {species: true}, "erase": []},
	})


func _pay(session: PokeCoopBattleSession) -> Dictionary:
	var total: int = session.battle.battle_reward + session.battle.pay_day_money
	var split: Dictionary = PokeCoopPolicy.prize_split(total, session.participants, session.initiator)
	for payee: String in split:
		player(payee).add_money(int(split[payee]))
	return split


static func _victory_changes(encounter: Dictionary, encounter_id: String) -> Dictionary:
	var badge: int = int(encounter.get("badge", -1))
	return {
		"flags": encounter.get("victory_flags", []),
		"badges": (1 << badge) if badge >= 0 else 0,
		"defeated": [encounter_id],
	}


func save_checkpoint() -> StringName:
	if not battles.is_empty():
		return &"battle_in_progress"
	if save_path.is_empty():
		return &"no_save_path"
	return &"" if _write_campaign() == OK else &"save_failed"


## The campaign between battles: a battle still running when the host closes is left out.
func _write_campaign() -> Error:
	_written_at = Time.get_ticks_msec()
	var written: Error = PokeCoopSave.write(save_path, campaign, players.values()) \
		if not save_path.is_empty() else ERR_UNCONFIGURED
	if written == OK:
		_saved_unix = Time.get_unix_time_from_system()
	return written


## Tells every client the session is over, then closes once they have all left
## or [param grace_msec] has passed: a socket closed at once can lose the notice.
func shutdown(reason: String = "host_shutdown", grace_msec: int = SHUTDOWN_GRACE_MSEC) -> void:
	if ended or _closing_at >= 0:
		return
	for session: PokeCoopBattleSession in battles.values():
		session.abandon()
		_finish(session)
	_write_campaign()
	for peer: int in _peers:
		transport.send(peer, {"type": "ended", "reason": reason})
	_closing_at = Time.get_ticks_msec() + maxi(grace_msec, 0)
	if grace_msec <= 0:
		poll()


func broadcast() -> void:
	var everyone: Dictionary = {}
	for player_id: String in players:
		everyone[player_id] = player(player_id).public_view()
	var running: Array = []
	for session: PokeCoopBattleSession in battles.values():
		running.append({
			"battle": session.id, "encounter": String(session.encounter.get("id", "")),
			"participants": session.participants.duplicate(), "phase": session.phase(),
			"enemy": session.battle.mon(Gen2Battle.ENEMY).species, "trainer_class": int(session.encounter.get("trainer_class", 0)),
		})
	var offered: Array = []
	for encounter_id: String in encounters:
		offered.append({
			"id": encounter_id,
			"label": String((encounters[encounter_id] as Dictionary).get("label", encounter_id)),
		})
	var shared: Dictionary = campaign.summary()
	shared["world"] = campaign.world_part(_badge_flags)
	for peer: int in _peers:
		var viewer: PokeCoopPlayer = player(String(_peers[peer]))
		if int(_box_sent.get(peer, -1)) != viewer.box_rev:
			_box_sent[peer] = viewer.box_rev
			transport.send(peer, {"type": "box", "rev": viewer.box_rev, "rows": viewer.box_rows()})
		transport.send(peer, {
			"type": "state", "campaign": shared, "players": everyone,
			"you": _private_view(viewer), "nearby": nearby(viewer), "battles": running,
			"encounters": offered, "last_seq": int(_last_seq.get(viewer.player_id, 0)),
			"saved": {"ago": Time.get_unix_time_from_system() - _saved_unix if _saved_unix > 0.0 else -1.0,
				"count": _saves, "by": _saved_by},
		})
		for session: PokeCoopBattleSession in battles.values():
			if session.involves(viewer.player_id):
				transport.send(peer, {"type": "battle", "view": session.view()})
		for final_view: Dictionary in _finished.get(viewer.player_id, []):
			transport.send(peer, {"type": "battle", "view": final_view})
		_finished.erase(viewer.player_id)


## The player's own view with the Cable Club's: their trade round and partner.
func _private_view(viewer: PokeCoopPlayer) -> Dictionary:
	var out: Dictionary = viewer.private_view()
	out["trade"] = trades.view(viewer.player_id)
	var partner: PokeCoopPlayer = trades.partner_for(viewer, players)
	if partner != null:
		out["trade_partner"] = {
			"player_id": partner.player_id, "name": partner.name,
			"trainer_id": partner.trainer_id, "party": partner.team_rows(),
		}
	return out


## Everybody else connected and out exploring on [param viewer]'s map.
func nearby(viewer: PokeCoopPlayer) -> Array[String]:
	var out: Array[String] = []
	for player_id: String in players:
		var other: PokeCoopPlayer = player(player_id)
		if other != viewer and other.connected and other.map == viewer.map \
				and other.return_point.is_empty():
			out.append(player_id)
	return out


static func _rejected(seq: int, reason: StringName) -> Dictionary:
	return {"type": "rejected", "seq": seq, "reason": reason}


static func _vector(raw: Variant) -> Vector2i:
	if raw is Vector2i:
		return raw
	if raw is Array and (raw as Array).size() == 2:
		return Vector2i(PokeCoopTransport.number(raw[0], -1), PokeCoopTransport.number(raw[1], -1))
	return Vector2i(-1, -1)
