class_name PokeCoopHost
extends RefCounted

## The authoritative side of a co-op session. Clients send intentions; this
## validates them against the campaign, the players and the running battles, and
## answers every connected client with the state they may see.

const PROTOCOL: int = 1
const SHUTDOWN_GRACE_MSEC: int = 2000

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
var _peers: Dictionary = {}
var _last_seq: Dictionary = {}
var _finished: Array = []


static func create(
	game_data: GameData, run: PokeCoopCampaign, link: PokeCoopTransport
) -> PokeCoopHost:
	if game_data == null or run == null or link == null:
		return null
	var out := PokeCoopHost.new()
	out.data = game_data
	out.campaign = run
	out.transport = link
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
		elif kind == PokeCoopTransport.MESSAGE and _closing_at < 0:
			_on_message(peer, event["message"])
	if _closing_at >= 0 and (_peers.is_empty() or Time.get_ticks_msec() >= _closing_at):
		transport.close()
		ended = true


func _on_message(peer: int, message: Dictionary) -> void:
	var kind: String = String(message.get("type", ""))
	if kind == "hello":
		_hello(peer, message)
		return
	var sender: PokeCoopPlayer = player(String(_peers.get(peer, "")))
	var seq: int = int(message.get("seq", -1))
	if sender == null:
		transport.send(peer, _rejected(seq, &"hello_first"))
		return
	if seq <= int(_last_seq.get(sender.player_id, 0)):
		transport.send(peer, _rejected(seq, &"duplicate"))
		return
	_last_seq[sender.player_id] = seq
	var refusal: StringName = _dispatch(sender, kind, message)
	if refusal != &"":
		transport.send(peer, _rejected(seq, refusal))
	broadcast()


func _dispatch(sender: PokeCoopPlayer, kind: String, message: Dictionary) -> StringName:
	var battle_id: String = String(message.get("battle", ""))
	match kind:
		"move":
			return step(sender, _vector(message.get("map")), _vector(message.get("cell")),
				int(message.get("facing", sender.facing)))
		"start_battle":
			return start_battle(sender, String(message.get("encounter", "")))
		"command":
			var command: Variant = message.get("command", {})
			return battle_command(sender, battle_id, command if command is Dictionary else {})
		"suggest":
			var suggestion: Variant = message.get("suggestion", {})
			return suggest(sender, battle_id, suggestion if suggestion is Dictionary else {})
		"join":
			return join_battle(sender, battle_id)
		"save":
			return save_checkpoint()
	return &"unknown_message"


func _hello(peer: int, message: Dictionary) -> void:
	var refusal: StringName = _hello_refusal(message)
	var joining: PokeCoopPlayer = player(String(message.get("player_id", "")))
	if refusal == &"" and joining == null:
		if not allow_new_players:
			refusal = &"unknown_player"
		else:
			joining = add_player(String(message.get("name", "")), seeds.randi() & 0xFFFF)
	if refusal == &"" and joining.connected:
		refusal = &"already_connected"
	if refusal != &"":
		transport.send(peer, _rejected(-1, refusal))
		transport.drop(peer)
		return
	_peers[peer] = joining.player_id
	joining.connected = true
	for session: PokeCoopBattleSession in battles.values():
		session.set_absent(joining.player_id, false)
	transport.send(peer, {
		"type": "welcome", "protocol": PROTOCOL, "player_id": joining.player_id,
		"last_seq": int(_last_seq.get(joining.player_id, 0)),
	})
	broadcast()


func _hello_refusal(message: Dictionary) -> StringName:
	if int(message.get("protocol", -1)) != PROTOCOL:
		return &"protocol_mismatch"
	if StringName(message.get("game_id", "")) != campaign.game_id \
			or String(message.get("rom_sha1", "")) != campaign.rom_sha1:
		return &"content_mismatch"
	return &""


func _on_disconnected(peer: int) -> void:
	var leaving: PokeCoopPlayer = player(String(_peers.get(peer, "")))
	_peers.erase(peer)
	if leaving == null:
		return
	leaving.connected = false
	for session: PokeCoopBattleSession in battles.values():
		if session.involves(leaving.player_id):
			session.set_absent(leaving.player_id, true)
	if _closing_at < 0:
		broadcast()


## A step on the current map or a warp to another. Collision and warp checks wait
## for the shared world simulation.
func step(mover: PokeCoopPlayer, to_map: Vector2i, to_cell: Vector2i, toward: int) -> StringName:
	if not mover.is_free():
		return &"in_battle"
	if to_map == mover.map and absi(to_cell.x - mover.cell.x) + absi(to_cell.y - mover.cell.y) > 1:
		return &"not_adjacent"
	mover.place(to_map, to_cell, toward)
	return &""


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
	if outcome == &"won":
		_pay(session)
		if unique:
			campaign.commit("victory:" + encounter_id, _victory_changes(session.encounter, encounter_id))
	elif unique:
		campaign.release_encounter(encounter_id, session.id)
	for participant_id: String in session.participants:
		var participant: PokeCoopPlayer = player(participant_id)
		if outcome == &"lost":
			participant.add_money(-PokeCoopPolicy.blackout_cost(participant.money))
		participant.battle_id = ""
		participant.resume_exploration()
	var final_view: Dictionary = session.view()
	final_view["evolvable"] = session.evolvable_uids()
	_finished.append(final_view)
	battles.erase(session.id)


func _pay(session: PokeCoopBattleSession) -> void:
	var total: int = session.battle.battle_reward + session.battle.pay_day_money
	var split: Dictionary = PokeCoopPolicy.prize_split(total, session.participants, session.initiator)
	for payee: String in split:
		player(payee).add_money(int(split[payee]))


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
	return &"" if PokeCoopSave.write(save_path, campaign, players.values()) == OK else &"save_failed"


## Tells every client the session is over, then closes once they have all left
## or [param grace_msec] has passed: a socket closed at once can lose the notice.
func shutdown(reason: String = "host_shutdown", grace_msec: int = SHUTDOWN_GRACE_MSEC) -> void:
	if ended or _closing_at >= 0:
		return
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
		})
	for peer: int in _peers:
		var viewer: PokeCoopPlayer = player(String(_peers[peer]))
		transport.send(peer, {
			"type": "state", "campaign": campaign.summary(), "players": everyone,
			"you": viewer.private_view(), "nearby": nearby(viewer), "battles": running,
			"last_seq": int(_last_seq.get(viewer.player_id, 0)),
		})
		for session: PokeCoopBattleSession in battles.values():
			if session.involves(viewer.player_id):
				transport.send(peer, {"type": "battle", "view": session.view()})
		for final_view: Dictionary in _finished:
			if (final_view["participants"] as Array).has(viewer.player_id):
				transport.send(peer, {"type": "battle", "view": final_view})
	_finished.clear()


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
		return Vector2i(int(raw[0]), int(raw[1]))
	return Vector2i(-1, -1)
