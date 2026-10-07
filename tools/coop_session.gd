extends SceneTree

## Co-op sessions over ENet on the synthetic test cache, no cartridge needed:
##   Godot --headless --path . -s res://tools/coop_session.gd -- demo [port] [logs]
##   Godot --headless --path . -s res://tools/coop_session.gd -- check host|p1|p2 [port] [logs]
##   Godot --headless --path . -s res://tools/coop_session.gd -- host [port] [game]
##   Godot --headless --path . -s res://tools/coop_session.gd -- client <address> [port] <player_id> [game]
## `demo` runs a host and two clients in one process, `check` one per process (tools/coop_two_process.sh), over
## localhost; each exits 0 only if every step passed. `host red` plays an imported cartridge, campaign in
## `user://coop_campaigns/<game>/<game>.json`. Session logs go to `user://coop_logs` (`demo`, `check`: with `logs`).

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const STEP_FRAMES: int = 600
const CHECK_STEP_MSEC: int = 20000
const PALLET: Vector2i = Vector2i(0, 0)
const ROUTE_1: Vector2i = Vector2i(0, 12)
const BEAT_LEADER: int = 0x77
const SAVE_PATH: String = "user://coop_demo_campaign.json"
## `constants/event_constants.asm` at the pinned pokered commit, and Pallet Town's
## two doorsteps. Brock is trainer class 34, party 0.
const EVENT_BEAT_BROCK: int = 0x77
const BROCK_CLASS: int = 34
const PALLET_RED: Vector2i = Vector2i(5, 6)
const PALLET_BLUE: Vector2i = Vector2i(13, 6)
const CHARMANDER: int = 4
const SQUIRTLE: int = 7
const PIDGEY: int = 16
const RATTATA: int = 19

var _directory: String = ""
var _data: GameData = null
var _host: PokeCoopHost = null
var _red: PokeCoopClient = null
var _blue: PokeCoopClient = null
var _steps: Array = []
var _step: int = 0
var _frames: int = 0
var _begun: bool = false
var _begun_at: int = 0
var _patience_msec: int = 0
var _title: String = "demo"
var _handed_at: int = -1
var _acted: Dictionary = {}
var _battle: String = ""
var _known: Array = []
var _mode: String = ""
var _logging: bool = false
var _journals: Array = []


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_mode = args[0] if not args.is_empty() else "demo"
	_logging = args.has("logs") or _mode in ["host", "client"]
	if args.has("logs"):
		args.remove_at(args.find("logs"))
	_directory = RomCache.directory_for(
		StringName("coop%s%d" % [_mode, OS.get_process_id()]), "0123456789abcdef"
	)
	var game: String = _game_arg(args)
	_data = GameData.open(StringName(game)) if not game.is_empty() \
		else Fixture.build(_directory, "testgame", RomRegistry.GEN1)
	if _data == null:
		push_error("coop: no imported cache for %s" % game)
		_finish(1)
		return
	match _mode:
		"demo":
			_start_demo(_port(args, 1))
		"check":
			_start_check(args[1] if args.size() > 1 else "", _port(args, 2))
		"host":
			_start_host(_port(args, 1), game)
		"client":
			_start_client(args)
		_:
			push_error("usage: demo [port] | check host|p1|p2 [port] | host [port] | client <address> [port] <player_id>")
			_finish(2)


## The cartridge: a host's first argument that is not a port, or the one after a client's player id.
static func _game_arg(args: PackedStringArray) -> String:
	if args.is_empty():
		return ""
	if args[0] == "host":
		for index: int in range(1, args.size()):
			if not args[index].is_valid_int():
				return args[index]
	if args[0] == "client":
		var game_at: int = 4 if args.size() > 2 and args[2].is_valid_int() else 3
		return args[game_at] if args.size() > game_at else ""
	return ""


static func _port(args: PackedStringArray, at: int) -> int:
	return int(args[at]) if args.size() > at and args[at].is_valid_int() else PokeCoopEnetTransport.DEFAULT_PORT


func _new_host(port: int) -> bool:
	var link: PokeCoopEnetTransport = PokeCoopEnetTransport.listen(port)
	if link == null:
		push_error("coop: cannot listen on port %d" % port)
		return false
	_host = PokeCoopHost.create(_data, PokeCoopCampaign.create("demo", _data.id, _data.sha1), link)
	_host.save_path = SAVE_PATH
	_host.journal = _journal("host", "HOST", port)
	var red: PokeCoopPlayer = _host.add_player("RED", 100)
	red.place(PALLET, Vector2i(5, 5), 0)
	red.add_mon(_saved(Fixture.CHARMANDER, 60, [Fixture.SLASH, Fixture.GROWL], 100))
	red.add_mon(_saved(Fixture.PIKACHU, 20, [Fixture.TACKLE], 100))
	var blue: PokeCoopPlayer = _host.add_player("BLUE", 200)
	blue.place(PALLET, Vector2i(6, 5), 0)
	blue.add_mon(_saved(Fixture.CHARMANDER, 20, [Fixture.TACKLE, Fixture.GROWL], 200))
	_host.register_encounter("wild:stall", {"species": Fixture.GEODUDE, "level": 50, "moves": [Fixture.GROWL]})
	_host.register_encounter("wild:weak", {"species": Fixture.BULBASAUR, "level": 2, "moves": [Fixture.GROWL]})
	_host.register_encounter("trainer:leader", {
		"kind": "trainer", "trainer_class": Fixture.GEN1_LEADER, "trainer_index": 0,
		"victory_flags": [BEAT_LEADER], "badge": 0,
	})
	print("coop: host on port %d, players p1 (RED) and p2 (BLUE)" % port)
	return true


func _saved(species: int, level: int, moves: Array, ot: int) -> Gen2SaveMon:
	var out: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(
		Gen2BattleMon.create(_data, species, level, moves)
	)
	out.ot_id = ot
	return out


func _dial(address: String, port: int, player_id: String) -> PokeCoopClient:
	var link: PokeCoopEnetTransport = PokeCoopEnetTransport.dial(address, port)
	if link == null:
		return null
	var client: PokeCoopClient = PokeCoopClient.over(link)
	client.journal = _journal("join", player_id.to_upper(), port)
	client.greet(player_id, _data.id, _data.sha1, player_id)
	return client


func _journal(role: String, name: String, port: int) -> PokeCoopLog:
	if not _logging:
		return PokeCoopLog.new()
	var out: PokeCoopLog = PokeCoopLog.create(PokeCoopLog.sharing())
	out.open(role, name, {"tool": "coop_session " + _mode, "port": port, "game_id": String(_data.id), "rom_sha1": _data.sha1})
	_journals.append(out)
	return out


func _start_host(port: int, game: String) -> void:
	if game.is_empty():
		if not _new_host(port):
			_finish(1)
		return
	var link: PokeCoopEnetTransport = PokeCoopEnetTransport.listen(port)
	if link == null:
		push_error("coop: cannot listen on port %d" % port)
		_finish(1)
		return
	PokeCoopSession.move_legacy(_data)
	var path: String = PokeCoopSession.campaign_path(_data)
	var loaded: Dictionary = PokeCoopSave.read(path)
	var campaign: PokeCoopCampaign = loaded.get("campaign", PokeCoopCampaign.create(game, _data.id, _data.sha1))
	_host = PokeCoopHost.create(_data, campaign, link)
	_host.save_path = path
	_host.journal = _journal("host", "HOST", port)
	if loaded.is_empty():
		_cartridge_players()
		PokeCoopPolicy.start_campaign(campaign)
	else:
		_host.adopt_players(loaded["players"])
	_cartridge_encounters()
	print("coop: %s host on port %d, %s campaign %s, players %s" % [
		game, port, "fresh" if loaded.is_empty() else "reloaded", path, _host.players.keys(),
	])


func _cartridge_players() -> void:
	var red: PokeCoopPlayer = _host.add_player("RED", 100)
	red.place(PALLET, PALLET_RED, Gen2WorldSprite.FACING_DOWN)
	red.add_mon(_saved(CHARMANDER, 12, _data.moves_at_level(CHARMANDER, 12), 100))
	red.add_mon(_saved(PIDGEY, 9, _data.moves_at_level(PIDGEY, 9), 100))
	var blue: PokeCoopPlayer = _host.add_player("BLUE", 200)
	blue.place(PALLET, PALLET_BLUE, Gen2WorldSprite.FACING_DOWN)
	blue.add_mon(_saved(SQUIRTLE, 12, _data.moves_at_level(SQUIRTLE, 12), 200))
	blue.add_mon(_saved(RATTATA, 9, _data.moves_at_level(RATTATA, 9), 200))


func _cartridge_encounters() -> void:
	_host.register_encounter("wild:pidgey", {"species": PIDGEY, "level": 5, "label": "wild PIDGEY L5"})
	_host.register_encounter("wild:rattata", {"species": RATTATA, "level": 4, "label": "wild RATTATA L4"})
	_host.register_encounter("trainer:brock", {
		"kind": "trainer", "trainer_class": BROCK_CLASS, "trainer_index": 0,
		"victory_flags": [EVENT_BEAT_BROCK], "badge": 0, "label": "BROCK (Pewter Gym)", "gym": true,
	})


func _start_client(args: PackedStringArray) -> void:
	if args.size() < 3:
		push_error("client needs <address> [port] <player_id> [game]")
		_finish(2)
		return
	var has_port: bool = args[2].is_valid_int()
	if has_port and args.size() < 4:
		push_error("client needs <address> [port] <player_id> [game]")
		_finish(2)
		return
	_red = _dial(args[1], _port(args, 2), args[3 if has_port else 2])
	if _red == null:
		_finish(1)


func _start_demo(port: int) -> void:
	_remove_demo_files()
	if not _new_host(port):
		_finish(1)
		return
	_red = _dial("127.0.0.1", port, "p1")
	_blue = _dial("127.0.0.1", port, "p2")
	_steps = [
		["both clients are welcomed", _noop, func() -> bool: return _red.player_id == "p1" and _blue.player_id == "p2"],
		["each sees the other in Pallet Town", _noop, func() -> bool: return _red.nearby().has("p2") and _blue.nearby().has("p1")],
		["red starts a battle", func() -> void: _red.start_battle("wild:stall"), _red_battle_known],
		["blue explores meanwhile", func() -> void: _blue.step(PALLET, Vector2i(6, 6), 0), func() -> bool: return _host.player("p2").cell == Vector2i(6, 6)],
		["blue starts and wins a battle of its own", func() -> void: _fight(_blue, "wild:weak"), func() -> bool: return _won(_blue, _new_battle(_blue))],
		["blue joins red's battle", func() -> void: _blue.join_battle(_battle), func() -> bool: return (_red.battle(_battle).get("participants", []) as Array).has("p2")],
		["blue's suggestion shows without acting", func() -> void: _blue.suggest(_battle, "switch", 2), _suggestion_seen],
		["switching to blue's Pokemon hands blue the turn", func() -> void: _red.act(_battle, {"type": "switch", "index": 2}), func() -> bool: return _blue.is_controller(_battle)],
		["blue hands the turn back", func() -> void: _blue.act(_battle, {"type": "switch", "index": 0}), func() -> bool: return _red.is_controller(_battle)],
		["the shared battle is won", _noop, func() -> bool: return _won(_red, _battle)],
		["experience landed on both owners", _noop, _both_gained],
		["red beats the leader", func() -> void: _fight(_red, "trainer:leader"), func() -> bool: return _won(_red, _new_battle(_red))],
		["blue shares the story flag", _noop, func() -> bool: return ((_blue.state.get("campaign", {}) as Dictionary).get("flags", []) as Array).has(BEAT_LEADER)],
		["the campaign saves between battles", func() -> void: _blue.request_save(), func() -> bool: return FileAccess.file_exists(SAVE_PATH)],
		["the save reloads both players", _noop, _save_matches],
		["host shutdown ends both clients", func() -> void: _host.shutdown(), func() -> bool: return _red.ended_reason != "" and _blue.ended_reason != ""],
	]


func _start_check(role: String, port: int) -> void:
	_title = "check " + role
	_patience_msec = CHECK_STEP_MSEC
	match role:
		"host":
			if _new_host(port):
				_host.save_path = ""
				_steps = _hosting_steps()
		"p1":
			_red = _dial("127.0.0.1", port, "p1")
			_steps = _starting_steps() if _red != null else []
		"p2":
			_blue = _dial("127.0.0.1", port, "p2")
			_steps = _joining_steps() if _blue != null else []
	if _steps.is_empty():
		push_error("coop check: no %s on port %d (roles: host, p1, p2)" % [role, port])
		_finish(1)


func _hosting_steps() -> Array:
	return [
		["both players connect", _noop, func() -> bool: return _host.player("p1").connected and _host.player("p2").connected],
		["a battle holds both players", _noop, _shared_battle_found],
		["the shared battle ends", _noop, func() -> bool: return not _host.battles.has(_battle)],
		["the host shuts down", func() -> void: _host.shutdown(), func() -> bool: return _host.ended],
	]


func _starting_steps() -> Array:
	return [
		["p1 is welcomed", _noop, func() -> bool: return _red.player_id == "p1"],
		["p1 sees p2 connected", _noop, func() -> bool: return _sees(_red, "p2")],
		["p1 starts a battle", func() -> void: _red.start_battle("wild:stall"), _red_battle_known],
		["p2 joins p1's battle", _noop, func() -> bool: return (_red.battle(_battle).get("participants", []) as Array).has("p2")],
		["switching to p2's Pokemon hands p2 the turn until p2 switches back", _hand_over, _handed_back],
		["the shared battle is won", _noop, func() -> bool: return _won(_red, _battle)],
		["host shutdown ends p1", _noop, func() -> bool: return _red.ended_reason == "host_shutdown"],
	]


func _joining_steps() -> Array:
	return [
		["p2 is welcomed", _noop, func() -> bool: return _blue.player_id == "p2"],
		["p2 sees p1 connected", _noop, func() -> bool: return _sees(_blue, "p1")],
		["p2 finds p1's battle", _noop, _listed_battle_found],
		["p2 joins p1's battle", func() -> void: _blue.join_battle(_battle), func() -> bool: return (_blue.battle(_battle).get("participants", []) as Array).has("p2")],
		["p1's switch hands p2 the turn", _noop, func() -> bool: return _blue.is_controller(_battle)],
		["p2 hands the turn back", func() -> void: _blue.act(_battle, {"type": "switch", "index": 0}), func() -> bool: return not _blue.is_controller(_battle)],
		["the shared battle is won", _noop, func() -> bool: return _won(_blue, _battle)],
		["host shutdown ends p2", _noop, func() -> bool: return _blue.ended_reason == "host_shutdown"],
	]


func _noop() -> void:
	pass


func _process(_delta: float) -> bool:
	if _host != null:
		_host.poll()
	for client: PokeCoopClient in [_red, _blue]:
		if client != null:
			client.poll()
	if not _steps.is_empty():
		_advance_steps()
	elif _mode == "client" and _red != null:
		_watch_client()
	return false


func _advance_steps() -> void:
	if _step >= _steps.size():
		print("coop %s: all %d steps passed" % [_title, _steps.size()])
		_finish(0)
		return
	var row: Array = _steps[_step]
	if not _begun:
		(row[1] as Callable).call()
		_begun = true
		_frames = 0
		_begun_at = Time.get_ticks_msec()
	if (row[2] as Callable).call():
		print("PASS  %s" % row[0])
		_step += 1
		_begun = false
	elif _frames > STEP_FRAMES and Time.get_ticks_msec() - _begun_at >= _patience_msec:
		print("FAIL  %s" % row[0])
		_finish(1)
	_frames += 1


func _watch_client() -> void:
	if _red.ended_reason != "":
		print("coop client: session ended (%s)" % _red.ended_reason)
		_finish(0)
		return
	if _red.last_rejection() != &"" and not _acted.has("refused:%d" % _red.rejections.size()):
		_acted["refused:%d" % _red.rejections.size()] = true
		print("coop client: refused (%s)" % _red.last_rejection())
	var seen: int = _red.state.hash()
	if not _red.player_id.is_empty() and not _acted.has(seen):
		_acted[seen] = true
		print("coop client %s: nearby %s, battles %s" % [
			_red.player_id, _red.nearby(), _red.state.get("battles", []),
		])


func _red_battle_known() -> bool:
	_battle = String(_red.current_battle().get("battle", ""))
	return not _battle.is_empty()


func _suggestion_seen() -> bool:
	var view: Dictionary = _red.battle(_battle)
	return (view.get("suggestions", {}) as Dictionary).has("p2") and _red.is_controller(_battle)


static func _sees(client: PokeCoopClient, other: String) -> bool:
	return bool((client.state.get("players", {}) as Dictionary).get(other, {}).get("connected", false))


func _shared_battle_found() -> bool:
	for session: PokeCoopBattleSession in _host.battles.values():
		if session.participants.has("p1") and session.participants.has("p2"):
			_battle = session.id
	return not _battle.is_empty()


func _listed_battle_found() -> bool:
	for row: Dictionary in _blue.state.get("battles", []):
		if (row["participants"] as Array).has("p1"):
			_battle = String(row["battle"])
	return not _battle.is_empty()


func _hand_over() -> void:
	_handed_at = int(_red.battle(_battle)["revision"])
	_red.act(_battle, {"type": "switch", "index": 2})


## Two views can land in one poll, so p2's turn is read off red's Pokemon back two revisions later.
func _handed_back() -> bool:
	var view: Dictionary = _red.battle(_battle)
	return _red.is_controller(_battle) and int(view["active"]) == 0 and int(view["revision"]) >= _handed_at + 2


func _fight(client: PokeCoopClient, encounter: String) -> void:
	_known = client.battles.keys()
	client.start_battle(encounter)


func _new_battle(client: PokeCoopClient) -> String:
	for battle_id: String in client.battles:
		if not _known.has(battle_id):
			return battle_id
	return ""


## True once [param battle_id] is won; until then a client here holding the turn acts once a revision.
func _won(client: PokeCoopClient, battle_id: String) -> bool:
	var view: Dictionary = client.battle(battle_id)
	if view.is_empty():
		return false
	if String(view.get("outcome", "")) != "":
		return String(view["outcome"]) == "won"
	var turn_key: String = "%s@%d" % [battle_id, int(view["revision"])]
	for player: PokeCoopClient in [_red, _blue]:
		if player != null and player.is_controller(battle_id) and not _acted.has(turn_key):
			_acted[turn_key] = true
			player.act(battle_id, _next_command(player.battle(battle_id)))
	return false


static func _next_command(view: Dictionary) -> Dictionary:
	if String(view.get("phase", "")) != String(PokeCoopBattleSession.AWAITING_SEND_OUT):
		return {"type": "move", "slot": 0}
	for ally: Dictionary in view["allies"]:
		if int(ally["hp"]) > 0 and int(ally["index"]) != int(view["active"]):
			return {"type": "send_out", "index": int(ally["index"])}
	return {"type": "run"}


func _both_gained() -> bool:
	var red_team: Array = _red.me().get("team", [])
	var blue_team: Array = _blue.me().get("team", [])
	return not red_team.is_empty() and not blue_team.is_empty() \
		and int(red_team[0]["exp"]) > int(_saved(Fixture.CHARMANDER, 60, [], 100).exp) \
		and int(blue_team[0]["exp"]) > int(_saved(Fixture.CHARMANDER, 20, [], 200).exp)


func _save_matches() -> bool:
	var loaded: Dictionary = PokeCoopSave.read(SAVE_PATH)
	return not loaded.is_empty() and PokeCoopSave.to_dict(loaded["campaign"], loaded["players"]) \
		== PokeCoopSave.to_dict(_host.campaign, _host.players.values())


func _finish(code: int) -> void:
	if _host != null:
		_host.shutdown("host_shutdown", 0)
	for journal: PokeCoopLog in _journals:
		journal.close()
	if DirAccess.dir_exists_absolute(_directory):
		RomCache.clear(_directory)
	if _mode == "demo":
		_remove_demo_files()
	quit(code)


static func _remove_demo_files() -> void:
	for path: String in [SAVE_PATH, SAVE_PATH + PokeCoopSave.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
