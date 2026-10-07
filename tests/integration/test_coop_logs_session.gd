extends GutTest

## The session log of a host and two clients over the in-memory transport, each its
## own device with its own file: what each writes, and how the debug stream carries
## every device's lines to the others without feeding itself.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const LogTool := preload("res://tools/coop_log.gd")
const DIR: String = "user://coop_logs_session_test"
const SAVE_PATH: String = "user://coop_logs_session_test.json"
const PALLET: Vector2i = Vector2i(0, 0)
const BEAT_LEADER: int = 0x77

var _directory: String = ""
var _data: GameData = null
var _host: PokeCoopHost = null
var _red: PokeCoopClient = null
var _blue: PokeCoopClient = null
var _clients: Array = []
var _links: Array = []
var _journals: Array = []


func before_each() -> void:
	_directory = RomCache.directory_for(&"coopsessionlogs", "0123456789abcdef")
	_data = Fixture.build(_directory, "testgame", RomRegistry.GEN1)
	_host = PokeCoopHost.create(
		_data, PokeCoopCampaign.create("c1", _data.id, _data.sha1), PokeCoopTransport.new()
	)
	_host.save_path = SAVE_PATH
	_host.seeds.seed = 99
	_host.journal = _journal("host", "HOST", true)
	var red: PokeCoopPlayer = _host.add_player("RED", 100)
	red.place(PALLET, Vector2i(5, 5), 0)
	red.add_mon(_saved(Fixture.CHARMANDER, 60, [Fixture.SLASH, Fixture.GROWL], 100))
	var blue: PokeCoopPlayer = _host.add_player("BLUE", 200)
	blue.place(PALLET, Vector2i(6, 5), 0)
	blue.add_mon(_saved(Fixture.CHARMANDER, 20, [Fixture.TACKLE, Fixture.GROWL], 200))
	_host.register_encounter("trainer:leader", {
		"kind": "trainer", "trainer_class": Fixture.GEN1_LEADER, "trainer_index": 0,
		"victory_flags": [BEAT_LEADER], "badge": 0,
	})
	_clients = []
	_links = []


func after_each() -> void:
	for journal: PokeCoopLog in _journals:
		journal.close()
	_journals = []
	RomCache.clear(_directory)
	for path: String in [SAVE_PATH, SAVE_PATH + PokeCoopSave.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if DirAccess.dir_exists_absolute(DIR):
		for file: String in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR.path_join(file)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))


func _journal(role: String, who: String, share: bool) -> PokeCoopLog:
	var out: PokeCoopLog = PokeCoopLog.create(share, DIR)
	out.stream_msec = 0
	out.flush_msec = 0
	out.open(role, who, {"game_id": "testgame"})
	_journals.append(out)
	return out


func _saved(species: int, level: int, moves: Array, ot: int) -> Gen2SaveMon:
	var out: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(Gen2BattleMon.create(_data, species, level, moves))
	out.ot_id = ot
	return out


func _connect(peer: int, player_id: String, share: bool = true) -> PokeCoopClient:
	var link := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, link, peer)
	var client: PokeCoopClient = PokeCoopClient.over(link)
	client.journal = _journal("join", _host.player(player_id).name, share)
	client.greet("", _data.id, _data.sha1, player_id)
	_clients.append(client)
	_pump()
	return client


func _both(blue_shares: bool = true) -> void:
	_red = _connect(1, "p1")
	_blue = _connect(2, "p2", blue_shares)


func _pump(rounds: int = 4) -> void:
	for _round: int in rounds:
		for client: PokeCoopClient in _clients:
			client.poll()
		for link: PokeCoopWorldLink in _links:
			link.advance()
		_host.poll()
	for client: PokeCoopClient in _clients:
		client.poll()


## Plays [param battle_id] out with whoever holds the turn using their first move.
func _fight_out(battle_id: String) -> void:
	for _turn: int in 60:
		var controller: PokeCoopClient = null
		for client: PokeCoopClient in _clients:
			if client.is_controller(battle_id):
				controller = client
		if controller == null or not String(controller.battle(battle_id).get("outcome", "")).is_empty():
			return
		controller.act(battle_id, {"type": "move", "slot": 0})
		_pump()


func _lines(journal: PokeCoopLog) -> Array:
	journal.flush()
	var out: Array = []
	for line: String in FileAccess.get_file_as_string(journal.path).split("\n", false):
		out.append(JSON.parse_string(line))
	return out


static func _kinds(lines: Array) -> Array:
	return lines.map(func(line: Dictionary) -> String: return line["kind"])


static func _of(lines: Array, kind: String) -> Array:
	return lines.filter(func(line: Dictionary) -> bool: return line["kind"] == kind and not line.has("relay"))


static func _from(lines: Array, journal: PokeCoopLog) -> Array:
	return lines.filter(func(line: Dictionary) -> bool: return line["device"] == journal.device)


func _beat_the_leader() -> String:
	_red.start_battle("trainer:leader")
	_pump()
	var battle_id: String = String(_red.current_battle().get("battle", ""))
	_fight_out(battle_id)
	return battle_id


func test_the_host_log_holds_its_start_its_seeds_and_every_message_with_what_came_of_it() -> void:
	_both()
	_red.step(PALLET, Vector2i(5, 9), 0)
	_pump()
	var battle_id: String = _beat_the_leader()
	_blue.request_save()
	_pump()
	_host.shutdown("host_shutdown", 0)
	var lines: Array = _from(_lines(_host.journal), _host.journal)

	var start: Dictionary = _of(lines, "host_start")[0]["data"]
	assert_eq([start["seed"], int(start["protocol"])], ["99", PokeCoopHost.PROTOCOL])
	assert_eq((start["save"]["players"] as Array).size(), 2, "the players as a save holds them")
	assert_true((start["encounters"] as Dictionary).has("trainer:leader"))
	var inbound: Array = _of(lines, "in")
	var hellos: Array = inbound.filter(func(line: Dictionary) -> bool: return line["data"]["message"]["type"] == "hello")
	assert_eq(hellos.map(func(line: Dictionary) -> Array: return [line["player"], line["data"]["result"]]),
		[["p1", "ok"], ["p2", "ok"]])
	var refused: Array = inbound.filter(func(line: Dictionary) -> bool: return line["data"]["result"] == "not_adjacent")
	assert_eq(refused.size(), 1, "a refusal is logged with its reason")
	assert_eq([refused[0]["data"]["message"]["cell"], refused[0]["data"]["message"]["seq"]], [[5.0, 9.0], 1.0])
	var began: Dictionary = _of(lines, "battle_start")[0]["data"]
	assert_eq([began["battle"], began["encounter"]["id"]], [battle_id, "trainer:leader"])
	assert_true(began["seed"] is float, "the battle's own seed")
	var views: Array = _of(lines, "battle_view")
	assert_gt(views.size(), 1)
	assert_true(views.all(func(line: Dictionary) -> bool: return line["data"].has("events")), "views carry their events")
	assert_eq(_of(lines, "battle_end")[0]["data"]["outcome"], "won")
	assert_eq(_of(lines, "commit")[0]["data"]["id"], "victory:trainer:leader")
	assert_true((_of(lines, "campaign")[-1]["data"]["flags"] as Array).has(float(BEAT_LEADER)))
	var saves: Array = _of(lines, "save").map(func(line: Dictionary) -> String: return line["data"]["why"])
	assert_eq(saves, ["battle_end", "asked by p2", "shutdown"])
	assert_eq(_kinds(lines).slice(-4), ["shutdown", "host_end", "save", "closed"])


func test_a_client_log_holds_what_it_sent_and_a_digest_of_what_it_saw() -> void:
	_both()
	_red.step(PALLET, Vector2i(5, 9), 0)
	_pump()
	_beat_the_leader()
	_host.shutdown("host_shutdown", 0)
	_pump()
	var lines: Array = _from(_lines(_red.journal), _red.journal)

	assert_eq(_kinds(lines).slice(0, 4), ["header", "connected", "hello", "welcome"])
	assert_eq(_of(lines, "welcome")[0]["data"]["player_id"], "p1")
	var sent: Array = _of(lines, "out")
	assert_eq(sent[0]["data"], {"type": "move", "map": [0.0, 0.0], "cell": [5.0, 9.0], "facing": 0.0, "warp": false, "seq": 1.0})
	assert_eq(_of(lines, "rejected")[0]["data"]["reason"], "not_adjacent")
	var states: Array = _of(lines, "state")
	assert_true(states[0]["data"].has("state"), "the first state after a welcome is whole")
	assert_false(states[-1]["data"].has("state"), "the rest are digests")
	assert_eq(states[-1]["data"]["cell"], [5.0, 5.0])
	var outcomes: Array = _of(lines, "battle_view").map(func(line: Dictionary) -> String: return line["data"]["outcome"])
	assert_eq(outcomes[-1], "won")
	assert_eq(_of(lines, "ended")[0]["data"]["reason"], "host_shutdown")


func test_every_device_ends_up_with_every_players_lines_once_and_the_stream_goes_quiet() -> void:
	_both()
	_beat_the_leader()
	_pump(8)

	for journal: PokeCoopLog in [_host.journal, _red.journal, _blue.journal]:
		var lines: Array = _lines(journal)
		var relayed: Array = lines.filter(func(line: Dictionary) -> bool: return line.has("relay"))
		for other: PokeCoopLog in [_host.journal, _red.journal, _blue.journal]:
			if other != journal:
				assert_gt(_from(relayed, other).size(), 0, "%s holds %s's lines" % [journal.player_name, other.player_name])
		assert_eq(_from(relayed, journal), [], "nothing comes back to the device it came from")
		var keys: Dictionary = {}
		for line: Dictionary in lines:
			keys["%s:%d" % [line["device"], int(line["n"])]] = true
		assert_eq(keys.size(), lines.size(), "no line twice")
	var red_own: Array = _from(_lines(_red.journal), _red.journal).filter(
		func(line: Dictionary) -> bool: return not line.has("relay"))
	var red_at_blue: Array = _from(_lines(_blue.journal), _red.journal)
	assert_eq(red_at_blue.map(func(line: Dictionary) -> float: return line["n"]),
		red_own.map(func(line: Dictionary) -> float: return line["n"]), "blue has all of red's lines")
	assert_eq(red_at_blue[0]["relay"]["via"], "host")
	var sizes: Array = [_host.journal, _red.journal, _blue.journal].map(func(journal: PokeCoopLog) -> int: return _lines(journal).size())
	_pump(10)
	assert_eq([_host.journal, _red.journal, _blue.journal].map(func(journal: PokeCoopLog) -> int: return _lines(journal).size()),
		sizes, "with nothing happening, the stream adds nothing")


func test_a_device_that_comes_back_is_sent_what_it_missed_and_nothing_twice() -> void:
	_both()
	_pump(4)
	_red.transport.close()
	_pump()
	_blue.step(PALLET, Vector2i(6, 6), 0)
	_pump()
	var away: Array = _from(_lines(_blue.journal), _blue.journal).filter(func(line: Dictionary) -> bool:
		return line["kind"] == "out")
	var link := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, link, 3)
	_red.transport = link
	_red.greet("", _data.id, _data.sha1, "p1")
	_pump(6)

	var lines: Array = _lines(_red.journal)
	var keys: Dictionary = {}
	for line: Dictionary in lines:
		keys["%s:%d" % [line["device"], int(line["n"])]] = true
	assert_eq(keys.size(), lines.size(), "no line twice")
	assert_true(keys.has("%s:%d" % [_blue.journal.device, int(away[-1]["n"])]), "blue's step while red was away")


func test_a_clients_last_lines_reach_the_host_while_it_closes() -> void:
	_both()
	_red.step(PALLET, Vector2i(5, 6), 0)
	_host.shutdown("host_shutdown", 2000)
	_pump()

	var last: Dictionary = _from(_lines(_red.journal), _red.journal).filter(func(line: Dictionary) -> bool:
		return line["kind"] == "ended")[0]
	var at_host: Array = _from(_lines(_host.journal), _red.journal).filter(func(line: Dictionary) -> bool:
		return line["kind"] == "ended")
	assert_eq(at_host.map(func(line: Dictionary) -> float: return line["n"]), [last["n"]])
	assert_true(_host.ended)


func test_a_device_that_does_not_share_sends_and_receives_no_lines() -> void:
	_both(false)
	_beat_the_leader()
	_pump(8)

	assert_eq(_blue.journal.sent_lines, 0)
	assert_eq(_lines(_blue.journal).filter(func(line: Dictionary) -> bool: return line.has("relay")), [])
	assert_eq(_from(_lines(_host.journal), _blue.journal), [])
	assert_eq(_from(_lines(_red.journal), _blue.journal), [])
	assert_gt(_from(_lines(_red.journal), _host.journal).size(), 0, "the others still share")
	var batches: Array = _of(_lines(_host.journal), "in").filter(func(line: Dictionary) -> bool:
		return line["data"]["message"]["type"] == "log" and line["player"] == "p2")
	assert_eq(batches, [])


func test_the_host_passes_on_only_a_senders_own_plain_lines() -> void:
	_both()
	var own: Dictionary = {"ms": 1, "device": _red.journal.device, "n": 9000, "kind": "forged but own"}
	_red.transport.send(PokeCoopTransport.HOST_PEER, {"type": "log", "lines": [
		own, 7, {"device": _blue.journal.device, "n": 9001, "kind": "someone else's"},
		own.merged({"n": 9002, "relay": {"via": "host"}}, true), {"kind": "no device"},
	]})
	var stranger := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, stranger, 9)
	stranger.send(PokeCoopTransport.HOST_PEER, {"type": "log", "lines": [own.merged({"n": 9003}, true)]})
	_red.transport.send(PokeCoopTransport.HOST_PEER, {"type": "log", "lines": "not a list"})
	_pump()

	var at_blue: Array = _lines(_blue.journal).filter(func(line: Dictionary) -> bool: return int(line["n"]) >= 9000)
	assert_eq(at_blue.map(func(line: Dictionary) -> String: return line["kind"]), ["forged but own"])
	var batches: Array = _of(_lines(_host.journal), "in").filter(func(line: Dictionary) -> bool:
		return line["data"]["message"]["type"] == "log" and int(line["data"]["message"]["lines"]) != 0)
	assert_eq(batches.slice(-2).map(func(line: Dictionary) -> Array: return [line["data"]["message"]["lines"], line["data"]["result"]]),
		[[5.0, "1 taken"], [-1.0, "0 taken"]], "counted, never copied into the message log")


func test_a_batch_over_the_cap_reaches_the_others_with_its_dropped_count() -> void:
	_both()
	for index: int in 120:
		_red.journal.add(PokeCoopLog.CLIENT, "filler", {"text": "f".repeat(1000)}, "p1")
	_pump()

	var dropped: Array = _from(_lines(_blue.journal), _red.journal).filter(
		func(line: Dictionary) -> bool: return line["kind"] == PokeCoopLog.DROPPED)
	assert_eq(dropped.size(), 1)
	assert_gt(int(dropped[0]["data"]["lines"]), 0)


func test_a_window_logs_its_own_battle_and_the_hosts_echo_it_left_out() -> void:
	_both()
	var state := Gen2WorldState.new()
	state.gen1 = true
	var window: PokeCoopWorldLink = PokeCoopWorldLink.over(_red, state, PokeCoopWorldLink.local_save(_red, _data), _data)
	_links.append(window)
	_pump()
	state.set_gen1_map_script(0x28, 3)
	window.advance()
	_host.poll()
	state.set_gen1_map_script(0x28, 4)
	window.advance()
	_red.poll()
	window.advance()
	_pump()
	var pulls: Array = _of(_lines(_red.journal), "world_pull")
	var echoes: Array = pulls.filter(func(line: Dictionary) -> bool: return (line["data"]["echoes"] as Dictionary).has("gen1_map_scripts"))
	assert_eq(echoes.size(), 1, "the host's copy of 3 arrived while 4 was unconfirmed")

	var enemy: Gen2Party = Gen2Party.of(Gen2BattleMon.create(_data, Fixture.BULBASAUR, 2, [Fixture.GROWL]))
	var party: Gen2Party = Gen2SaveBattleAdapter.to_battle_party(_data, window.save)
	var bridge: Node = PokeCoopBattleTakeover.over(_red, _data).create_battle()
	add_child_autofree(bridge)
	bridge.call("start", {
		"battle": Gen2Battle.create_parties(_data, party, enemy, RandomNumberGenerator.new(), false),
		"player_party": party, "enemy_party": enemy, "data": _data, "summary": {"battle_kind": &"wild"},
	})
	_pump()
	_fight_out(String(_red.current_battle().get("battle", "")))
	bridge.call("_process", 0.0)
	var red_lines: Array = _lines(_red.journal)
	assert_eq(_of(red_lines, "takeover_start")[0]["data"]["summary"]["battle_kind"], "wild")
	assert_eq(_of(red_lines, "takeover_end")[0]["data"]["outcome"], "won")


func test_the_merged_timeline_of_three_devices_summarises_the_session() -> void:
	_both()
	_beat_the_leader()
	_blue.request_save()
	_pump()
	_host.shutdown("host_shutdown", 0)
	_pump()
	var files: Array = [_host.journal, _red.journal, _blue.journal].map(func(journal: PokeCoopLog) -> Array: return _lines(journal))

	var timeline: Array = LogTool.merge(files)
	var everything: int = 0
	for journal: PokeCoopLog in [_host.journal, _red.journal, _blue.journal]:
		everything += _from(_lines(journal), journal).filter(func(line: Dictionary) -> bool: return not line.has("relay")).size()
	assert_eq(timeline.size(), everything, "every device's own lines once")
	var found: Dictionary = LogTool.summary(timeline)
	assert_eq((found["sessions"] as Dictionary).size(), 3)
	assert_eq((found["sessions"] as Dictionary).values().map(func(row: Dictionary) -> String: return row["campaign_id"]),
		["c1", "c1", "c1"], "a joiner's campaign comes with its welcome")
	assert_eq(found["players"], {"p1": "RED", "p2": "BLUE"})
	var battles: Array = (found["battles"] as Dictionary).values()
	assert_eq(battles.map(func(row: Dictionary) -> Array: return [row["encounter"], row["outcome"]]), [["trainer:leader", "won"]])
	assert_eq((found["saves"] as Array).size(), 3)
	assert_string_contains(LogTool.summary_text(found), "trainer:leader by p1: won")


func test_a_host_log_replays_to_the_campaign_it_logged_and_a_changed_message_does_not() -> void:
	_both()
	_host.register_encounter("wild:weak", {"species": Fixture.BULBASAUR, "level": 2, "moves": [Fixture.GROWL]})
	_red.step(PALLET, Vector2i(5, 9), 0)
	_blue.step(PALLET, Vector2i(6, 6), 0)
	_pump()
	_blue.send({"type": "world", "patch": {"event_flags": {"set": {0x30: true}, "erase": []}}})
	_beat_the_leader()
	_blue.start_battle("wild:weak")
	_pump()
	_fight_out(String(_blue.current_battle().get("battle", "")))
	_red.request_save()
	_pump()
	_host.shutdown("host_shutdown", 0)
	var lines: Array = _lines(_host.journal)

	var replayed: Dictionary = LogTool.replay(lines, _data)
	assert_eq([replayed["mismatches"], replayed["end"]], [[], "match"], JSON.stringify(replayed))
	assert_gt(int(replayed["messages"]), 10)
	var step: Dictionary = lines.filter(func(line: Dictionary) -> bool:
		return line["kind"] == "in" and line["data"]["message"]["type"] == "move" and line["player"] == "p2")[0]
	step["data"]["message"]["cell"] = [6.0, 4.0]
	var changed: Dictionary = LogTool.replay(lines, _data)
	assert_eq([changed["end"], changed["differences"]], ["differs", ["players.p2.cell"]], "another step ends elsewhere")


## Over localhost sockets, as the Co-op tab runs it: the hosting device's host and
## its own client share one file and send it once; the joining device gets all of it.
func test_a_hosting_device_writes_one_file_for_its_host_and_client_and_the_joiner_gets_it() -> void:
	var identity_before: String = PokeCoopSession.identity_path
	PokeCoopSession.identity_path = "user://coop_logs_session_test_identity.json"
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, 25155, "RED", Fixture.CHARMANDER, null, "", "", _journal_for_session())
	var joining: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", 25155, "BLUE", Fixture.BULBASAUR, "", null, _journal_for_session())
	var deadline: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline and not (hosting.is_ready() and joining.is_ready()):
		hosting.process()
		joining.process()
		OS.delay_msec(5)
	hosting.say("Hello from the host.")
	for _round: int in 20:
		hosting.process()
		joining.process()
		OS.delay_msec(5)
	hosting.close()
	for _round: int in 20:
		joining.process()
		OS.delay_msec(5)
	joining.close()
	PokeCoopSession.identity_path = identity_before
	for path: String in ["user://coop_logs_session_test_identity.json", PokeCoopSession.campaign_path(_data, hosting.host.campaign.campaign_id)]:
		for file: String in [path, path + PokeCoopSave.BACKUP_SUFFIX]:
			if FileAccess.file_exists(file):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	var campaigns: String = PokeCoopSession.campaign_path(_data).get_base_dir()
	if DirAccess.dir_exists_absolute(campaigns) and DirAccess.get_files_at(campaigns).is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(campaigns))

	assert_true(hosting.host.journal == hosting.client.journal, "one device, one file")
	var host_lines: Array = _lines(hosting.journal)
	var header: Dictionary = host_lines[0]["data"]
	assert_eq([header["role"], header["port"], header["campaign_id"]], ["host", 25155.0, hosting.host.campaign.campaign_id])
	var sources: Array = _from(host_lines, hosting.journal).map(func(line: Dictionary) -> String: return line["source"])
	assert_true(sources.has("host") and sources.has("client") and sources.has("world"))
	assert_eq(host_lines.filter(func(line: Dictionary) -> bool: return line.has("relay") and line["device"] == hosting.journal.device), [],
		"the host never takes its own client's lines back")
	var joiner_lines: Array = _lines(joining.journal)
	var said: Array = _from(joiner_lines, hosting.journal).filter(func(line: Dictionary) -> bool: return line["kind"] == "say")
	assert_eq(said.map(func(line: Dictionary) -> String: return line["data"]["text"]), ["Hello from the host."])
	assert_gt(_from(host_lines, joining.journal).size(), 0, "and the joiner's lines reach the host")
	assert_eq(joiner_lines[0]["data"]["role"], "join")


func _journal_for_session() -> PokeCoopLog:
	var out: PokeCoopLog = PokeCoopLog.create(true, DIR)
	out.stream_msec = 0
	out.flush_msec = 0
	_journals.append(out)
	return out
