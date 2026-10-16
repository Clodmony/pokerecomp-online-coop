class_name PokeCoopHost
extends RefCounted

## The authoritative side of a co-op session: checks each client's intentions and answers with the state it may see.

const PROTOCOL: int = 10
## A walk step, or a ledge hop over the cell between.
const MAX_STEP_CELLS: int = 2
const SHUTDOWN_GRACE_MSEC: int = 2000
const MAX_TRAINER_NAME: int = 16
const MAX_WIN_TEXT: int = 512
const MAX_NICKNAME: int = 10
const MAX_NOTE: int = 64
## How often a changed campaign is written between battles: a crashed host loses at most this much.
var autosave_msec: int = 30000

var data: GameData = null
var campaign: PokeCoopCampaign = null
var players: Dictionary = {}
var battles: Dictionary = {}
var encounters: Dictionary = {}
var scenes: Dictionary = {}
var transport: PokeCoopTransport = null
var save_path: String = ""
var allow_new_players: bool = false
var host_player_id: String = ""
var seeds: RandomNumberGenerator = RandomNumberGenerator.new()
var ended: bool = false
var _closing_at: int = -1
var _refused_peers: Dictionary = {}
var _peers: Dictionary = {}
var _badge_flags: Array[int] = []
var _own_entries: Dictionary = {}
var _last_seq: Dictionary = {}
## Final battle views a participant who was away when a battle ended is told on coming back.
var _finished: Dictionary = {}
var _named_catches: Dictionary = {}
var _box_sent: Dictionary = {}
var trades: PokeCoopTrades = null
var _controllers: Dictionary = {}
var _changed: bool = false
var _kept_revision: int = 0
var _boxes_written: Dictionary = {}
var _written_at: int = 0
var _saves: int = 0
var _saved_by: String = ""
var _saved_unix: float = 0.0
var journal: PokeCoopLog = PokeCoopLog.new()
var _log_peers: Dictionary = {}
## The latest log batches, for a device that starts sharing later, and the last each device got.
var _log_backlog: Array = []
var _log_backlog_bytes: int = 0
var _log_batches: int = 0
var _log_delivered: Dictionary = {}
var _streamed_at: int = 0
var _started: bool = false
var _logged_revision: int = -1
var _logged_views: Dictionary = {}
var _league_cleared: bool = false
var notes: Dictionary = {}
var challenges: Dictionary = {}
var _challenge_serial: int = 0
var _challenge_told: Dictionary = {}
var _seated: Dictionary = {}  ## who sits at the Colosseum's table waiting on whom
var wild_tables: Dictionary = {}


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
	out._own_entries = PokeCoopPolicy.own_entries(game_data)
	for flag: int in PokeCoopPolicy.own_walks(game_data) if not out._own_entries.is_empty() else []:
		run.flags.erase(flag)
	out.trades = PokeCoopTrades.create(game_data)
	if PokeCoopJohto.is_game(run.game_id):
		run.clock = PokeCoopJohto.wind(run.clock, Gen2WorldClock.host_seconds())
	out._kept_revision = run.revision
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


## A battle a client may ask for by id: `kind` (`wild` or `trainer`), `species`, `level` and optional
## `moves`, or `trainer_class` and `trainer_index`; `unique`, `victory_flags` and `badge` for story fights.
func register_encounter(encounter_id: String, descriptor: Dictionary) -> void:
	encounters[encounter_id] = descriptor.duplicate(true)
	if _started:
		journal.add(PokeCoopLog.HOST, "encounter", {"id": encounter_id, "descriptor": descriptor})


func player(player_id: String) -> PokeCoopPlayer:
	return players.get(player_id, null)


func poll() -> void:
	if ended:
		return
	if not _started:
		_log_start()
	for event: Dictionary in transport.poll():
		var peer: int = int(event["peer"])
		var kind: StringName = StringName(event["kind"])
		if kind == PokeCoopTransport.DISCONNECTED:
			_on_disconnected(peer)
		elif kind == PokeCoopTransport.MESSAGE and not _refused_peers.has(peer) and (_closing_at < 0 or _is_log(event["message"])):
			_on_message(peer, event["message"])
		else:
			journal.add(PokeCoopLog.HOST, "ignored" if kind == PokeCoopTransport.MESSAGE else String(kind), {"peer": peer})
	_drop_refused()
	_advance_forced()
	_end_abandoned()
	_expire_challenges()
	_announce_stand_ins()
	_autosave()
	_keep_story()
	_note_campaign()
	_share_log()
	if _closing_at >= 0 and (_peers.is_empty() or Time.get_ticks_msec() >= _closing_at):
		transport.close()
		ended = true
		journal.add(PokeCoopLog.HOST, "closed", {"players": players.size()})
	journal.poll()


## What a replay starts from: campaign and players as saved, encounters, and the generator of every seed.
func _log_start() -> void:
	_started = true
	_logged_revision = campaign.revision
	if journal.is_on():
		journal.add(PokeCoopLog.HOST, "host_start", {
			"protocol": PROTOCOL, "summary": campaign.summary(), "save": PokeCoopSave.to_dict(campaign, players.values()),
			"encounters": encounters, "seed": str(seeds.seed), "rng_state": str(seeds.state),
			"allow_new_players": allow_new_players, "save_path": save_path, "autosave_msec": autosave_msec,
		})


func _on_message(peer: int, message: Dictionary) -> StringName:
	var kind: String = PokeCoopTransport.text(message.get("type"))
	if kind == "log":
		_relay_log(peer, message.get("lines"))
		return &""
	if kind == "note":
		_take_note(String(_peers.get(peer, "")), message.get("text"))
		return &""
	if kind == "wild_tables":
		_take_wild_tables(String(_peers.get(peer, "")), message.get("tables"))
		return &""
	var line: Dictionary = journal.add(PokeCoopLog.HOST, "in", {"peer": peer, "message": message}, String(_peers.get(peer, "")))
	if kind == "probe":
		transport.send(peer, probe_answer(message))
		return &""
	var result: StringName = _hello(peer, message) if kind == "hello" else _answer(peer, kind, message)
	if not line.is_empty():
		line["data"]["result"] = String(result) if result != &"" else "ok"
		line["player"] = String(_peers.get(peer, ""))
	_note_campaign()
	return result


func _answer(peer: int, kind: String, message: Dictionary) -> StringName:
	var sender: PokeCoopPlayer = player(String(_peers.get(peer, "")))
	var seq: int = PokeCoopTransport.number(message.get("seq"), -1)
	if sender == null:
		transport.send(peer, _rejected(seq, &"hello_first"))
		return &"hello_first"
	if seq <= int(_last_seq.get(sender.player_id, 0)):
		transport.send(peer, _rejected(seq, &"duplicate"))
		return &"duplicate"
	_last_seq[sender.player_id] = seq
	if message.get("shift") is bool:
		sender.battle_shift = message["shift"]
	var refusal: StringName = _dispatch(sender, kind, message)
	_settle_league()
	_changed = _changed or refusal == &""
	if refusal != &"":
		transport.send(peer, _rejected(seq, refusal))
	broadcast()
	return refusal


## A client's own log lines, kept when this device shares too and passed on to every other that shares.
func _relay_log(peer: int, raw: Variant) -> void:
	var sender: String = String(_peers.get(peer, ""))
	if sender.is_empty() or not _streams_to(peer):
		return
	var taken: Array = journal.take_relayed(raw, sender, String(_log_peers[peer]["device"]), journal.share)
	journal.add(PokeCoopLog.HOST, "in", {"peer": peer, "message": {"type": "log", "lines": (raw as Array).size() if raw is Array else -1},
		"result": "%d taken" % taken.size()}, sender)
	_pass_log(taken, peer)


func _take_note(sender: String, text: Variant) -> void:
	if not sender.is_empty() and text is String:
		notes[sender] = (text as String).left(MAX_NOTE)
		journal.add(PokeCoopLog.HOST, "note", {"text": notes[sender]}, sender)


func _take_wild_tables(sender_id: String, raw: Variant) -> void:
	var sender: PokeCoopPlayer = player(sender_id)
	var tables: Dictionary = PokeCoopPolicy.sane_wild_tables(raw, not PokeCoopJohto.plays(data))
	if sender == null or tables.is_empty() or wild_tables.has(sender.game_id):
		return
	wild_tables[sender.game_id] = tables
	journal.add(PokeCoopLog.HOST, "wild_tables", {"game": sender.game_id, "maps": (tables["grass"] as Dictionary).size()}, sender_id)
	for peer: int in _peers:
		_send_wild_tables(peer)


func _send_wild_tables(peer: int) -> void:
	var member: PokeCoopPlayer = player(String(_peers.get(peer, "")))
	var other: String = String(PokeCoopPolicy.other_version(StringName(member.game_id))) if member != null else ""
	if campaign.both_versions and wild_tables.has(other):
		transport.send(peer, {"type": "wild_tables", "game_id": other, "tables": wild_tables[other]})


func wild_tables_missing() -> Array:
	if not campaign.both_versions:
		return []
	return PokeCoopLobby.partners(campaign.game_id).filter(func(game: StringName) -> bool: return not wild_tables.has(String(game)))


static func _is_log(message: Dictionary) -> bool:
	return PokeCoopTransport.text(message.get("type")) == "log"


func _pass_log(lines: Array, from_peer: int) -> void:
	if lines.is_empty():
		return
	_log_batches += 1
	_log_backlog.append({"serial": _log_batches, "lines": lines, "bytes": var_to_bytes(lines).size()})
	_log_backlog_bytes += int(_log_backlog[-1]["bytes"])
	while _log_backlog_bytes > PokeCoopLog.BACKLOG_BYTES:
		_log_backlog_bytes -= int(_log_backlog.pop_front()["bytes"])
	for peer: int in _peers:
		if peer != from_peer and _streams_to(peer):
			transport.send(peer, {"type": "log", "lines": lines})
			_log_delivered[_log_peers[peer]["device"]] = _log_batches


func _streams_to(peer: int) -> bool:
	var shared: Dictionary = _log_peers.get(peer, {})
	return bool(shared.get("share", false)) and String(shared.get("device", "")) != journal.device


## What a device sharing from now on missed of the others' lines, as far back as the backlog goes.
func _send_backlog(peer: int) -> void:
	if not _streams_to(peer):
		return
	var device: String = _log_peers[peer]["device"]
	for batch: Dictionary in _log_backlog:
		var lines: Array = (batch["lines"] as Array).filter(func(line: Dictionary) -> bool: return line.get("device") != device)
		if int(batch["serial"]) > int(_log_delivered.get(device, 0)) and not lines.is_empty():
			transport.send(peer, {"type": "log", "lines": lines})
	_log_delivered[device] = _log_batches


func _share_log(now: bool = false) -> void:
	if not journal.share or (not now and Time.get_ticks_msec() - _streamed_at < journal.stream_msec):
		return
	_streamed_at = Time.get_ticks_msec()
	_pass_log(journal.take_stream(), -1)


func _note_campaign() -> void:
	if campaign.revision != _logged_revision and _started:
		_logged_revision = campaign.revision
		journal.add(PokeCoopLog.HOST, "campaign", campaign.summary())


func _dispatch(sender: PokeCoopPlayer, kind: String, message: Dictionary) -> StringName:
	var battle_id: String = PokeCoopTransport.text(message.get("battle"))
	match kind:
		"move":
			return step(sender, _vector(message.get("map")), _vector(message.get("cell")),
				PokeCoopTransport.number(message.get("facing"), sender.facing), PokeCoopTransport.number(message.get("warp")) == 1,
				message.get("places", {}))
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
		"join", "leave_battle", "stand_in":
			return _membership(sender, kind, battle_id)
		"world":
			return apply_world(sender, PokeCoopOwnership.well_formed(message.get("patch", {})))
		"party":
			return apply_party(sender, message)
		"save":
			var refused: StringName = save_checkpoint("asked by " + sender.player_id)
			if refused == &"":
				_saves += 1
				_saved_by = sender.player_id
			return refused
		"opening":
			return finish_speech(sender, PokeCoopTransport.text(message.get("rival")))
		"challenge":
			return challenge(sender, message)
		"scene":
			return claim_scene(sender, _vector(message.get("map")), message.get("on") is bool and bool(message.get("on")))
		"trade":
			return _trade(sender, message)
		"name_catch":
			return name_catch(sender, battle_id, PokeCoopTransport.text(message.get("nickname")).left(MAX_NICKNAME))
		"clock":
			return set_clock(sender, message)
	return &"unknown_message"


func set_clock(sender: PokeCoopPlayer, message: Dictionary) -> StringName:  ## the hosting player's opening or Mom's weekday (D133); -1 keeps a field
	if campaign.clock.is_empty():
		return &"no_clock"
	if sender.player_id != host_player_id:
		return &"not_host"
	var now: float = Gen2WorldClock.host_seconds()
	var was: Dictionary = PokeCoopJohto.reading(campaign.clock, now)
	var asked: Dictionary = {}
	for key: String in ["day", "hour", "minute", "cur_day"]:
		var value: int = PokeCoopTransport.number(message.get(key), -1)
		asked[key] = value if value >= 0 else int(was[key])
	campaign.clock = PokeCoopJohto.set_to(asked, now)
	campaign.revision += 1
	journal.add(PokeCoopLog.HOST, "clock", {"was": was, "now": asked}, sender.player_id)
	return &""


func _spared(trainer_class: int, map: Vector2i) -> bool:
	if PokeCoopJohto.plays(data):
		return PokeCoopJohto.spared(trainer_class, map)
	return trainer_class == Gen1Layout.RIVAL1_CLASS and map.y == Gen1Layout.OAKS_LAB


func name_catch(sender: PokeCoopPlayer, battle_id: String, nickname: String) -> StringName:
	var filed: Dictionary = _named_catches.get(battle_id, {})
	if String(filed.get("player", "")) != sender.player_id:
		return &"not_your_catch"
	_named_catches.erase(battle_id)
	return &"" if sender.rename(String(filed["uid"]), nickname) else &"invalid_nickname"


func _trade(sender: PokeCoopPlayer, message: Dictionary) -> StringName:
	if PokeCoopTransport.number(message.get("colosseum")) == 1:
		return _colosseum(sender, message)
	var swaps: int = trades.swaps
	var answer: StringName = trades.handle(sender, message, players)
	if trades.swaps != swaps:
		journal.add(PokeCoopLog.HOST, "trade_swap", {"swaps": trades.swaps}, sender.player_id)
		if battles.is_empty():
			_write_campaign("trade")
	return answer


func _colosseum(sender: PokeCoopPlayer, message: Dictionary) -> StringName:  ## Gold and Silver's Colosseum: both at its table, one battle (D137)
	_seated.erase(sender.player_id)
	if PokeCoopTransport.number(message.get("leave")) == 1:
		return &""
	var partner: PokeCoopPlayer = trades.partner_for(sender, players)
	if not PokeCoopJohto.plays(data) or partner == null or partner.player_id != PokeCoopTransport.text(message.get("partner")) \
			or not sender.is_free() or not partner.is_free():
		return &"no_partner"
	if String(_seated.get(partner.player_id, "")) != sender.player_id:
		_seated[sender.player_id] = partner.player_id
		return &""
	_seated.erase(partner.player_id)
	var battle_id: String = campaign.take_battle_id()
	var session: PokeCoopVersus = PokeCoopVersus.pit(data, battle_id, seeds.randi(), partner, sender)
	if session == null:
		return &"no_fit_pokemon"
	session.colosseum = true
	_open_battle(session)
	return &""


func _hello(peer: int, message: Dictionary) -> StringName:
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
					brought, joining, campaign if joined_before == 0 else null, _badge_flags, _own_entries
				)
			elif message.get("opening") is bool and bool(message.get("opening")):
				PokeCoopPolicy.set_up_opening_player(data, joining)
			else:
				PokeCoopPolicy.set_up_new_player(
					data, joining, PokeCoopTransport.number(message.get("starter")), joined_before
				)
			PokeCoopPolicy.hand_over_gifts(campaign, joining)
			journal.add(PokeCoopLog.HOST, "new_player", joining.to_dict(), joining.player_id)
	if refusal == &"" and joining.connected:
		refusal = &"already_connected"
	if refusal != &"":
		transport.send(peer, _rejected(-1, refusal))
		_refused_peers[peer] = Time.get_ticks_msec() + SHUTDOWN_GRACE_MSEC
		return refusal
	_peers[peer] = joining.player_id
	joining.game_id = PokeCoopTransport.text(message.get("game_id"))
	joining.via = PokeCoopTransport.text(message.get("via"))
	_log_peers[peer] = _log_peer(message.get("logs"))
	_box_sent.erase(peer)
	joining.connected = true
	for session: PokeCoopBattleSession in battles.values():
		session.set_absent(joining.player_id, false)
	transport.send(peer, {
		"type": "welcome", "protocol": PROTOCOL, "player_id": joining.player_id, "campaign": campaign.campaign_id,
		"last_seq": int(_last_seq.get(joining.player_id, 0)),
	})
	_send_backlog(peer)
	_send_wild_tables(peer)
	broadcast()
	return &""


static func _log_peer(raw: Variant) -> Dictionary:
	var said: Dictionary = raw if raw is Dictionary else {}
	return {"device": PokeCoopTransport.text(said.get("device")), "share": said.get("share") is bool and bool(said.get("share"))}


## A saved player not here, by name: a device that lost its id or dialled another address.
func _returning(player_name: String) -> PokeCoopPlayer:
	for member: PokeCoopPlayer in players.values():
		if not member.connected and member.name == player_name and not player_name.is_empty():
			return member
	return null


## A new player's own save, rebuilt from vetted parts: legal Pokémon, sendable world keys, where they stood.
func _brought_save(raw: Variant) -> Gen2SaveData:
	if not raw is Dictionary or not PokeCoopPolicy.same_story(StringName(PokeCoopTransport.text(raw.get("game_id"))), data.id):
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


func lobby_view() -> Dictionary:
	var members: Array = []
	for member: PokeCoopPlayer in players.values():
		members.append({"name": member.name, "game": member.game_id, "connected": member.connected})
	var hosting: PokeCoopPlayer = player(host_player_id)
	return {
		"kind": PokeCoopLobby.KIND, "protocol": PROTOCOL, "build": PokeCoopLobby.build(),
		"game_id": String(campaign.game_id), "rom_sha1": campaign.rom_sha1, "campaign": campaign.campaign_id,
		"title": campaign.title, "host": hosting.name if hosting != null else "", "players": members,
		"badges": String.num_int64(campaign.badges, 2).count("1"), "new_players": allow_new_players,
		"place": PokeCoopLobby.place(data, hosting.map) if hosting != null else "",
	}


## Answered whatever the asker's protocol, so an older or newer build is told exactly what differs.
func probe_answer(message: Dictionary) -> Dictionary:
	var out: Dictionary = lobby_view()
	out["type"] = "probe"
	out["refused"] = String(_hello_refusal(message))
	var known: Variant = message.get("known", {})
	var mine: PokeCoopPlayer = player(PokeCoopTransport.text((known as Dictionary).get(campaign.campaign_id))) \
		if known is Dictionary else null
	mine = mine if mine != null else _returning(PokeCoopTransport.text(message.get("name")))
	out["you"] = {"player_id": mine.player_id, "name": mine.name} if mine != null and not mine.connected else {}
	return out


func _hello_refusal(message: Dictionary) -> StringName:
	if PokeCoopTransport.number(message.get("protocol"), -1) != PROTOCOL:
		return &"protocol_mismatch"
	if not PokeCoopPolicy.plays_with(StringName(PokeCoopTransport.text(message.get("game_id"))),
			PokeCoopTransport.text(message.get("rom_sha1")), campaign.game_id, campaign.rom_sha1):
		return &"content_mismatch"
	return &""


func _autosave() -> void:
	if _changed and battles.is_empty() and _closing_at < 0 \
			and Time.get_ticks_msec() - _written_at >= autosave_msec and _write_campaign("autosave") == OK:
		_changed = false


func _advance_forced() -> void:
	for session: PokeCoopBattleSession in battles.values():
		if session.advance():
			journal.add(PokeCoopLog.HOST, "battle_advance", {"battle": session.id})
			if session.phase() == PokeCoopBattleSession.OVER:
				_finish(session)
			broadcast()


## A battle nobody has been in for as long as a window redials ends as fled, holding up no save.
func _end_abandoned() -> void:
	for session: PokeCoopBattleSession in battles.values():
		if session.everyone_away_for() >= PokeCoopPolicy.ABANDON_MSEC:
			journal.add(PokeCoopLog.HOST, "battle_abandoned", {"battle": session.id})
			session.abandon()
			_finish(session)
			broadcast()


## The offer to stand in comes with no message to answer, so it is announced.
func _announce_stand_ins() -> void:
	var changed: bool = false
	for session: PokeCoopBattleSession in battles.values():
		var now: String = "%s/%s" % [session.controller(), session.stand_in_due()]
		if String(_controllers.get(session.id, now)) != now:
			changed = true
			journal.add(PokeCoopLog.HOST, "controller", {"battle": session.id, "controller": session.controller(),
				"stand_in_due": session.stand_in_due()})
		_controllers[session.id] = now
	if changed and _closing_at < 0:
		broadcast()


## A refused client is let go after the grace a refusal needs to arrive.
func _drop_refused() -> void:
	for peer: int in _refused_peers.keys():
		if Time.get_ticks_msec() >= int(_refused_peers[peer]):
			_refused_peers.erase(peer)
			journal.add(PokeCoopLog.HOST, "dropped", {"peer": peer})
			transport.drop(peer)


func _on_disconnected(peer: int) -> void:
	_refused_peers.erase(peer)
	var leaving: PokeCoopPlayer = player(String(_peers.get(peer, "")))
	journal.add(PokeCoopLog.HOST, "disconnected", {"peer": peer}, String(_peers.get(peer, "")))
	_peers.erase(peer)
	_box_sent.erase(peer)
	_log_peers.erase(peer)
	if leaving == null:
		return
	leaving.connected = false
	_release_scenes(leaving.player_id)
	trades.leave(leaving.player_id, players)
	trades.unpair(leaving.player_id)
	_seated.erase(leaving.player_id)
	for asked: Dictionary in challenges.values():
		if leaving.player_id in [asked["from"], asked["to"]]:
			_settle_challenge(asked, "left")
	for session: PokeCoopBattleSession in battles.values():
		if session.involves(leaving.player_id):
			session.set_absent(leaving.player_id, true)
	_settle_league()
	if _closing_at < 0:
		broadcast()


## A clear of the team's League run reaches the campaign once nothing holds it (D91).
func _settle_league() -> void:
	if not _league_cleared or PokeCoopPolicy.league_held(campaign, players.values()):
		return
	_league_cleared = false
	_changed = true
	PokeCoopPolicy.clear_league(campaign)
	journal.add(PokeCoopLog.HOST, "league_cleared", campaign.summary()["defeated"])


## A step on the current map, or a [param warp] the client's world made, trusted until the host simulates it.
func step(
	mover: PokeCoopPlayer, to_map: Vector2i, to_cell: Vector2i, toward: int, warp: bool = false, places: Variant = {}
) -> StringName:
	if not exploring(mover):
		return &"in_battle"
	var distance: int = absi(to_cell.x - mover.cell.x) + absi(to_cell.y - mover.cell.y)
	if not warp and to_map == mover.map and distance > MAX_STEP_CELLS:
		return &"not_adjacent"
	_release_scenes(mover.player_id, to_map)
	mover.place(to_map, to_cell, toward)
	mover.keep_places(places)
	_settle_opening(mover)
	return &""


func exploring(member: PokeCoopPlayer) -> bool:
	var session: PokeCoopBattleSession = battles.get(member.battle_id, null)
	return member.is_free() or (session != null and session.has_left(member.player_id))


## A window's world-state patch, trusted for now: the shared half to the campaign, the rest to [param sender].
func apply_world(sender: PokeCoopPlayer, changes: Dictionary) -> StringName:
	var halves: Dictionary = PokeCoopOwnership.route(changes, _badge_flags, _own_entries)
	if not sender.opening.is_empty():
		PokeCoopOwnership.apply_patch(sender.opening["world"], halves[PokeCoopOwnership.CAMPAIGN])
		sender.apply_world_patch(halves[PokeCoopOwnership.PLAYER])
		_settle_opening(sender)
		return &""
	var flags_before: Dictionary = campaign.flags.duplicate()
	var held_before: Dictionary = sender.items.duplicate()
	var money_before: int = sender.money
	PokeCoopJohto.keep_story(halves[PokeCoopOwnership.CAMPAIGN], campaign)
	if PokeCoopPolicy.take_league_clear(halves[PokeCoopOwnership.CAMPAIGN], campaign.game_id):
		_league_cleared = true
		journal.add(PokeCoopLog.HOST, "league_clear", {"held": PokeCoopPolicy.league_held(campaign, players.values())}, sender.player_id)
	var story_moved: bool = campaign.apply_world_patch(halves[PokeCoopOwnership.CAMPAIGN], _badge_flags)
	sender.apply_world_patch(halves[PokeCoopOwnership.PLAYER])
	if not story_moved and _sets_entries(halves[PokeCoopOwnership.CAMPAIGN]) and sender.money >= money_before:
		PokeCoopPolicy.keep_once(sender, held_before)
	var handled: Array[int] = PokeCoopPolicy.share_gifts(campaign, sender, players.values(), flags_before, held_before)
	if story_moved:
		PokeCoopPolicy.share_found_items(data, sender, players.values(), held_before, handled)
	return &""


static func _sets_entries(changes: Dictionary) -> bool:
	return ["event_flags", "toggled_objects"].any(func(key: String) -> bool:
		return not ((changes.get(key, {}) as Dictionary).get("set", {}) as Dictionary).is_empty())


## The first window into a rival scene drives it and a later one plays its own copy, the battle being one (#24).
func claim_scene(sender: PokeCoopPlayer, map: Vector2i, on: bool) -> StringName:
	var driver: String = String(scenes.get(map, ""))
	if not PokeCoopPolicy.rival_scenes(data).has(map):
		return &"not_a_scene"
	if on and not driver.is_empty() and driver != sender.player_id:
		return &"scene_taken"
	if on:
		scenes[map] = sender.player_id
	elif driver == sender.player_id:
		scenes.erase(map)
	return &""


func _release_scenes(player_id: String, kept: Vector2i = Vector2i(-1, -1)) -> void:
	for map: Vector2i in scenes.keys():
		if scenes[map] == player_id and map != kept:
			scenes.erase(map)


func finish_speech(sender: PokeCoopPlayer, rival: String) -> StringName:
	var named: String = rival.strip_edges().left(Gen2SaveData.MAX_PLAYER_NAME)
	var officer: bool = PokeCoopJohto.plays(data) and not named.is_empty() \
		and String(sender.opening.get("stage", "")) == PokeCoopPolicy.OPENING_PLAYING  ## Johto's officer asks after the theft (D131)
	if String(sender.opening.get("stage", "")) != PokeCoopPolicy.OPENING_SPEECH and not officer:
		return &"not_in_speech"
	sender.opening["stage"] = PokeCoopPolicy.OPENING_PLAYING
	sender.opening["rival"] = named
	if campaign.rival_name.is_empty():
		campaign.rival_name = named
	journal.add(PokeCoopLog.HOST, "opening", {"stage": PokeCoopPolicy.OPENING_PLAYING, "rival": named}, sender.player_id)
	return &""


## With a starter and the lab left, the player is drawn and the story is the campaign's (D50).
func _settle_opening(member: PokeCoopPlayer) -> void:
	if member.opening.is_empty():
		return
	var story: Dictionary = member.opening["world"]
	if not PokeCoopPolicy.opening_over(data, story, member.map):
		return
	var blank: Dictionary = PokeCoopOwnership.route(
		PokeCoopOwnership.patch({}, Gen2WorldState.new({}, {}, {}, {}).to_dict()), _badge_flags
	)[PokeCoopOwnership.CAMPAIGN]
	var missing: Dictionary = {}
	for key: String in blank:
		if not campaign.world.has(key) and not key in ["event_flags", "engine_flags"]:
			missing[key] = blank[key]
	if (campaign.world.get("gen1_starters", {}) as Dictionary).is_empty() and story.has("gen1_starters"):
		missing["gen1_starters"] = {"value": story["gen1_starters"]}
	campaign.apply_world_patch(missing, _badge_flags)
	member.opening = {}
	journal.add(PokeCoopLog.HOST, "opening", {"stage": "done", "map": member.map, "cell": member.cell}, member.player_id)


## A window's party and PC after a heal, gift, deposit or release; refused in a battle, whose results the host writes.
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


func challenge(sender: PokeCoopPlayer, message: Dictionary, now: int = Time.get_ticks_msec()) -> StringName:
	if message.has("mystery_gift"):
		return PokeCoopJohto.note_mystery_gift(data, sender, message)
	if message.has("answer"):
		var asked: Dictionary = challenges.get(PokeCoopTransport.text(message.get("id")), {})
		if asked.is_empty() or String(asked["to"]) != sender.player_id:
			return &"no_challenge"
		var met: StringName = _meet(asked) if PokeCoopTransport.number(message.get("answer")) == 1 else &"declined"
		_settle_challenge(asked, "accepted" if met == &"" else String(met))
		return &""
	var partner: PokeCoopPlayer = player(PokeCoopTransport.text(message.get("partner")))
	var kind: String = PokeCoopTransport.text(message.get("kind"))
	if partner == null or partner == sender or not kind in [PokeCoopPolicy.CHALLENGE_BATTLE, PokeCoopPolicy.CHALLENGE_TRADE, PokeCoopPolicy.CHALLENGE_GIFT] \
			or (kind == PokeCoopPolicy.CHALLENGE_GIFT and not (PokeCoopJohto.gift_ready(sender) and PokeCoopJohto.gift_ready(partner))):
		return &"invalid_challenge"
	if not free_to_meet(sender) or not free_to_meet(partner):
		return &"partner_busy"
	if challenges.values().any(func(open: Dictionary) -> bool:
			return [open["from"], open["to"]].any(func(member_id: String) -> bool: return member_id in [sender.player_id, partner.player_id])):
		return &"challenge_pending"
	_challenge_serial += 1
	var id: String = str(_challenge_serial)
	challenges[id] = {"id": id, "from": sender.player_id, "to": partner.player_id, "kind": kind, "at": now}
	journal.add(PokeCoopLog.HOST, "challenge", challenges[id], sender.player_id)
	return &""


func free_to_meet(member: PokeCoopPlayer) -> bool:
	return member != null and member.connected and member.is_free() and member.opening.is_empty() and not trades.is_direct(member.player_id)


func _meet(asked: Dictionary) -> StringName:
	var first: PokeCoopPlayer = player(String(asked["from"]))
	var second: PokeCoopPlayer = player(String(asked["to"]))
	if not free_to_meet(first) or not free_to_meet(second):
		return &"partner_busy"
	if String(asked["kind"]) == PokeCoopPolicy.CHALLENGE_TRADE:
		trades.pair(first, second)
		return &""
	if String(asked["kind"]) == PokeCoopPolicy.CHALLENGE_GIFT:
		PokeCoopJohto.mystery_gift(data, [first, second], int(PokeCoopJohto.reading(campaign.clock, Gen2WorldClock.host_seconds())["cur_day"]), seeds)
		journal.add(PokeCoopLog.HOST, "mystery_gift", {"rounds": [first.gift_round, second.gift_round]}, second.player_id)
		if battles.is_empty():
			_write_campaign("mystery_gift")
		return &""
	var battle_id: String = campaign.take_battle_id()
	var session: PokeCoopVersus = PokeCoopVersus.pit(data, battle_id, seeds.randi(), first, second)
	if session == null:
		return &"no_fit_pokemon"
	_open_battle(session)
	return &""


func _settle_challenge(asked: Dictionary, answer: String) -> void:
	challenges.erase(String(asked["id"]))
	var told: Dictionary = _challenge_told.get(String(asked["from"]), {"serial": 0})
	_challenge_told[String(asked["from"])] = {"serial": int(told["serial"]) + 1, "kind": asked["kind"], "partner": asked["to"], "answer": answer}
	journal.add(PokeCoopLog.HOST, "challenge_answer", {"id": asked["id"], "answer": answer}, String(asked["to"]))


func _expire_challenges(now: int = Time.get_ticks_msec()) -> void:
	var expired: Array = challenges.values().filter(func(asked: Dictionary) -> bool:
		return now - int(asked["at"]) >= PokeCoopPolicy.CHALLENGE_EXPIRE_MSEC)
	for asked: Dictionary in expired:
		_settle_challenge(asked, "timeout")
	if not expired.is_empty() and _closing_at < 0:
		broadcast()


func _challenge_view(viewer: String) -> Dictionary:
	var out: Dictionary = {"answered": _challenge_told.get(viewer, {})}
	for asked: Dictionary in challenges.values():
		var seen: Dictionary = {"id": asked["id"], "kind": asked["kind"], "from": asked["from"], "to": asked["to"]}
		if String(asked["to"]) == viewer:
			out["incoming"] = seen
		elif String(asked["from"]) == viewer:
			out["outgoing"] = seen
	return out


func start_battle(initiator: PokeCoopPlayer, encounter_id: String) -> StringName:
	var descriptor: Dictionary = encounters.get(encounter_id, {})
	if descriptor.is_empty():
		return &"unknown_encounter"
	if not initiator.is_free() or trades.is_direct(initiator.player_id):
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
	_open_battle(session)
	return &""


## A battle the player's own world opened, its enemies trusted: a second window joins, a beaten trainer stays beaten.
func start_window_battle(initiator: PokeCoopPlayer, message: Dictionary) -> StringName:
	if not initiator.is_free() or trades.is_direct(initiator.player_id):
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
	var encounter_id: String = "" if not initiator.opening.is_empty() else _window_encounter(
		trainer, trainer_class, trainer_index, (enemies[0] as Gen2BattleMon).species, _vector(message.get("map")), data)
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
		"loss_text": PokeCoopTransport.text(message.get("loss_text")).left(MAX_WIN_TEXT),
		"spared": _spared(trainer_class, _vector(message.get("map"))),
		"gym": message.get("gym") is bool and bool(message.get("gym")),
		"private": not initiator.opening.is_empty(),
	}
	var session: PokeCoopBattleSession = PokeCoopBattleSession.start(
		data, battle_id, seeds.randi(), initiator, party, info, _badge_mask()
	)
	if session == null:
		if unique:
			campaign.release_encounter(encounter_id, battle_id)
		return &"cannot_start"
	_open_battle(session)
	return &""


## One encounter per campaign: a trainer by class and index, or a one-off wild Pokémon where it stands; empty for grass.
static func _window_encounter(
	trainer: bool, trainer_class: int, trainer_index: int, species: int, map: Vector2i, game_data: GameData = null
) -> String:
	if trainer:
		return "trainer:%d:%d" % [trainer_class, trainer_index]
	if PokeCoopPolicy.unique_wild(game_data).has(species):
		return "static:%d:%d:%d" % [species, map.x, map.y]
	return ""


## A second window opened a trainer the campaign is already fighting.
func _join_window_battle(joiner: PokeCoopPlayer, encounter_id: String) -> StringName:
	for session: PokeCoopBattleSession in battles.values():
		if String(session.encounter.get("id", "")) != encounter_id:
			continue
		var refused: StringName = session.request_join(data, joiner)
		if refused == &"":
			session.attach(joiner.player_id)
		return refused
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
	_log_view(session)
	if session.phase() == PokeCoopBattleSession.OVER:
		_finish(session)
	return &""


func suggest(sender: PokeCoopPlayer, battle_id: String, suggestion: Dictionary) -> StringName:
	var session: PokeCoopBattleSession = battles.get(battle_id, null)
	return &"unknown_battle" if session == null else session.suggest(sender.player_id, suggestion)


func _membership(sender: PokeCoopPlayer, kind: String, battle_id: String) -> StringName:
	var session: PokeCoopBattleSession = battles.get(battle_id, null)
	if kind == "join" or session == null:
		return join_battle(sender, battle_id)
	return session.leave(sender) if kind == "leave_battle" else session.stand_in(sender.player_id)


func join_battle(joiner: PokeCoopPlayer, battle_id: String) -> StringName:
	var session: PokeCoopBattleSession = battles.get(battle_id, null)
	if trades.is_direct(joiner.player_id):
		return &"partner_busy"
	if session != null and bool(session.encounter.get("private", false)):
		return &"private_battle"
	return &"unknown_battle" if session == null else session.request_join(data, joiner)


func _open_battle(session: PokeCoopBattleSession) -> void:  ## Morning Sun, Synthesis and Moonlight read the campaign's clock, as in the world (D133)
	session.battle.time_of_day = PokeCoopJohto.time_of_day(campaign.clock, Gen2WorldClock.host_seconds())
	battles[session.id] = session
	_log_battle_start(session)


func _log_battle_start(session: PokeCoopBattleSession) -> void:
	if journal.is_on():
		journal.add(PokeCoopLog.HOST, "battle_start", {
			"battle": session.id, "seed": session.rng.seed, "encounter": session.encounter,
			"initiator": session.initiator, "view": session.view(),
		}, session.initiator)


func _log_view(session: PokeCoopBattleSession) -> void:
	if journal.is_on() and int(_logged_views.get(session.id, -1)) != session.revision:
		_logged_views[session.id] = session.revision
		journal.add(PokeCoopLog.HOST, "battle_view", session.view())


## Writes Pokémon back by uid, pays and commits a win once, and drops the battle, so nothing applies twice.
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
		_file_catch(session.catch, session.id)
	var prizes: Dictionary = _pay(session) if outcome == &"won" else {}
	if unique and (outcome == &"won" or outcome == PokeCoopBattleSession.CAUGHT):
		var changes: Dictionary = _victory_changes(session.encounter, encounter_id)
		var applied: bool = campaign.commit("victory:" + encounter_id, changes)
		journal.add(PokeCoopLog.HOST, "commit", {"id": "victory:" + encounter_id, "changes": changes, "applied": applied})
	elif unique:
		campaign.release_encounter(encounter_id, session.id)
	var final_view: Dictionary = session.view().merged({"evolvable": session.evolvable_uids(), "prizes": prizes}, true)
	for player_id: String in session.participants + session.pending_players():
		var participant: PokeCoopPlayer = player(player_id)
		participant.battle_id = ""
		participant.resume_exploration()
		var seen: Dictionary = session.view_for(player_id)
		seen.merge({"evolvable": session.evolvable_uids(), "prizes": prizes}, true)
		(_finished.get_or_add(player_id, []) as Array).append(seen)
	battles.erase(session.id)
	_logged_views.erase(session.id)
	journal.add(PokeCoopLog.HOST, "battle_end", {
		"battle": session.id, "outcome": outcome, "prizes": prizes, "results": _result_rows(by_owner),
		"caught_for": String(session.catch.get("recipient", "")), "view": final_view,
	})
	if battles.is_empty():
		_write_campaign("battle_end")


static func _result_rows(by_owner: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for owner_id: String in by_owner:
		out[owner_id] = (by_owner[owner_id] as Array).map(func(row: Dictionary) -> Dictionary:
			var fought: Gen2BattleMon = row["mon"]
			return {"uid": row["uid"], "species": fought.species, "level": fought.level, "hp": fought.hp, "exp": fought.exp})
	return out


## The wild a ball held, filed once with its recipient as trainer: the team if there is room, else the box.
func _file_catch(caught: Dictionary, battle_id: String) -> void:
	var recipient: PokeCoopPlayer = player(String(caught.get("recipient", "")))
	var wild: Gen2BattleMon = caught.get("mon", null)
	if recipient == null or wild == null:
		return
	var saved: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(wild)
	saved.ot_id = recipient.trainer_id
	saved.original_trainer = recipient.name
	saved.caught_level = wild.level
	var uid: String = recipient.add_mon(saved)
	uid = uid if not uid.is_empty() else recipient.store_mon(saved)
	_named_catches[battle_id] = {"player": recipient.player_id, "uid": uid}
	var species: int = wild.persistent_species()
	recipient.apply_world_patch({
		"caught_species": {"set": {species: true}, "erase": []},
		"seen_species": {"set": {species: true}, "erase": []},
	})


func _pay(session: PokeCoopBattleSession) -> Dictionary:
	var total: int = session.battle.battle_reward + session.battle.pay_day_money
	var split: Dictionary = PokeCoopJohto.prize_shares(session.battle, session.participants) \
		if PokeCoopJohto.plays(data) else PokeCoopPolicy.prize_shares(total, session.participants)
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


## Why a checkpoint asked for now would be refused; windows refuse their own SAVE with it.
func save_blocker() -> StringName:
	if not battles.is_empty():
		return &"battle_in_progress"
	return &"no_save_path" if save_path.is_empty() else &""


func save_checkpoint(why: String = "checkpoint") -> StringName:
	var blocked: StringName = save_blocker()
	if blocked != &"":
		journal.add(PokeCoopLog.HOST, "save_refused", {"why": why, "reason": blocked})
		return blocked
	return &"" if _write_campaign(why) == OK else &"save_failed"


## The checkpoint's content written to [param path] (a run's snapshot), neither a SAVE nor the checkpoint.
func write_copy(path: String) -> Error:
	return ERR_BUSY if not battles.is_empty() else PokeCoopSave.write(path, campaign, players.values())


## The campaign between battles: a battle still running when the host closes is left out.
func _write_campaign(why: String) -> Error:
	_written_at = Time.get_ticks_msec()
	var written: Error = PokeCoopSave.write(save_path, campaign, players.values()) \
		if not save_path.is_empty() else ERR_UNCONFIGURED
	if written == OK:
		_saved_unix = Time.get_unix_time_from_system()
		_kept_revision = campaign.revision
		for member: PokeCoopPlayer in players.values():
			_boxes_written[member.player_id] = member.box_rev
	journal.add(PokeCoopLog.HOST, "save" if written in [OK, ERR_UNCONFIGURED] else "save_error",
		{"why": why, "path": save_path, "result": error_string(written)})
	return written


func _keep_story() -> void:
	if campaign.revision == _kept_revision or save_path.is_empty():
		return
	_kept_revision = campaign.revision
	var kept: Error = PokeCoopSave.append(save_path, campaign, players.values(), _boxes_written)
	if kept != OK:
		journal.add(PokeCoopLog.HOST, "journal_error", {"path": save_path, "result": error_string(kept)})


## Tells every client the session is over, closing once all left or after [param grace_msec], so the notice arrives.
func shutdown(reason: String = "host_shutdown", grace_msec: int = SHUTDOWN_GRACE_MSEC) -> void:
	if ended or _closing_at >= 0:
		return
	journal.add(PokeCoopLog.HOST, "shutdown", {"reason": reason, "grace_msec": grace_msec, "battles": battles.keys(), "peers": _peers.values()})
	for session: PokeCoopBattleSession in battles.values():
		session.abandon()
		_finish(session)
	if journal.is_on():
		journal.add(PokeCoopLog.HOST, "host_end", {"save": PokeCoopSave.to_dict(campaign, players.values())})
	_write_campaign("shutdown")
	_share_log(true)
	for peer: int in _peers:
		transport.send(peer, {"type": "ended", "reason": reason})
	_closing_at = Time.get_ticks_msec() + maxi(grace_msec, 0)
	if grace_msec <= 0:
		poll()


func broadcast() -> void:
	var everyone: Dictionary = {}
	for player_id: String in players:
		everyone[player_id] = player(player_id).public_view().merged({"meeting": trades.is_direct(player_id)})
	for map: Vector2i in scenes:
		(everyone[scenes[map]] as Dictionary)["scene"] = map
	var running: Array = []
	for session: PokeCoopBattleSession in battles.values():
		_log_view(session)
		running.append({
			"battle": session.id, "encounter": String(session.encounter.get("id", "")),
			"participants": session.participants.duplicate(), "phase": session.phase(),
			"left": session.participants.filter(session.has_left),
			"enemy": session.battle.mon(Gen2Battle.ENEMY).species, "trainer_class": int(session.encounter.get("trainer_class", 0)),
			"private": bool(session.encounter.get("private", false)),
			"versus": session.participants.duplicate() if session is PokeCoopVersus else [],
		})
	var offered: Array = []
	for encounter_id: String in encounters:
		offered.append({
			"id": encounter_id,
			"label": String((encounters[encounter_id] as Dictionary).get("label", encounter_id)),
		})
	var shared: Dictionary = campaign.summary()
	shared["world"] = campaign.world_part(_badge_flags)
	var told: Dictionary = {}
	if not campaign.clock.is_empty():
		campaign.clock = PokeCoopJohto.wind(campaign.clock, Gen2WorldClock.host_seconds())
		told = PokeCoopJohto.reading(campaign.clock, Gen2WorldClock.host_seconds())
	for peer: int in _peers:
		var viewer: PokeCoopPlayer = player(String(_peers[peer]))
		if int(_box_sent.get(peer, -1)) != viewer.box_rev:
			_box_sent[peer] = viewer.box_rev
			transport.send(peer, {"type": "box", "rev": viewer.box_rev, "rows": viewer.box_rows()})
		var story: Dictionary = shared
		if not viewer.opening.is_empty():
			story = shared.duplicate()
			story["world"] = viewer.opening["world"]
		var view: Dictionary = {
			"type": "state", "campaign": story, "players": everyone,
			"you": _private_view(viewer), "nearby": nearby(viewer), "battles": running,
			"encounters": offered, "last_seq": int(_last_seq.get(viewer.player_id, 0)),
			"saved": {"ago": Time.get_unix_time_from_system() - _saved_unix if _saved_unix > 0.0 else -1.0,
				"count": _saves, "by": _saved_by, "blocked": String(save_blocker())},
		}
		if not told.is_empty():
			view["clock"] = told
		transport.send(peer, view)
		for session: PokeCoopBattleSession in battles.values():
			if session.involves(viewer.player_id):
				transport.send(peer, {"type": "battle", "view": session.view_for(viewer.player_id)})
		for final_view: Dictionary in _finished.get(viewer.player_id, []):
			transport.send(peer, {"type": "battle", "view": final_view})
		_finished.erase(viewer.player_id)


## The player's own view with the Cable Club's: their trade round and partner.
func _private_view(viewer: PokeCoopPlayer) -> Dictionary:
	var out: Dictionary = viewer.private_view()
	out["trade"] = trades.view(viewer.player_id)
	out["challenge"] = _challenge_view(viewer.player_id)
	var partner: PokeCoopPlayer = trades.partner_for(viewer, players)
	if partner != null:
		out["trade_partner"] = {
			"player_id": partner.player_id, "name": partner.name,
			"trainer_id": partner.trainer_id, "party": partner.team_rows(),
			"game_id": partner.game_id if not partner.game_id.is_empty() else String(campaign.game_id),
		}
	return out


## Everybody else connected and out exploring on [param viewer]'s map.
func nearby(viewer: PokeCoopPlayer) -> Array[String]:
	var out: Array[String] = []
	for player_id: String in players:
		var other: PokeCoopPlayer = player(player_id)
		if other != viewer and other.connected and other.map == viewer.map \
				and other.return_point.is_empty() and not other.is_hidden() and not viewer.is_hidden():
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
