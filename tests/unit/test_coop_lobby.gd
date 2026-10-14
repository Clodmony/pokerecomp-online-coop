extends GutTest

## What the Co-op tab does before a session exists: the LAN beacon, the dial that retries, the
## cartridges it offers, the advice it gives and what it remembers.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const MEMORY: String = "user://coop_lobby_test.json"
const BEACON_PORT: int = 24797
const NOBODY_PORT: int = 24798
const VIEW: Dictionary = {
	"kind": PokeCoopLobby.KIND, "protocol": 7, "build": "0.1.75", "game_id": "red_de", "rom_sha1": "abc", "campaign": "red_de-1",
	"title": "CAMPAIGN 1", "host": "CLOEDL", "players": [{"name": "CLOEDL", "game": "red_de", "connected": true},
		{"name": "MÖKI", "game": "blue_de", "connected": false}], "badges": 3, "place": "Pewter City",
}

var _directory: String = ""
var _data: GameData = null


func before_each() -> void:
	PokeCoopLobby.memory_path = MEMORY
	PokeCoopLobby.beacon_port = BEACON_PORT
	_directory = RomCache.directory_for(&"cooplobbytest", "0123456789abcdef")
	_data = Fixture.build(_directory, "testgame", RomRegistry.GEN1)


func after_each() -> void:
	PokeCoopLobby.memory_path = "user://coop_tab.json"
	PokeCoopLobby.beacon_port = PokeCoopLobby.BEACON_PORT
	PokeCoopLobby.open_game = Callable()
	PokeCoopLobby.SplitScreen.stacked = false
	if FileAccess.file_exists(MEMORY):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MEMORY))
	RomCache.clear(_directory)
	RomCache.clear(RomCache.directory_for(&"cooplobbystale", ""))


func test_a_beacon_reads_back_as_the_row_join_lists_and_nothing_else_does() -> void:
	var row: Dictionary = PokeCoopLobby.read_beacon(PokeCoopLobby.beacon_bytes(VIEW, 24850), "192.168.1.150")

	assert_eq([row["address"], row["port"], row["host"], row["title"], row["game_id"], row["badges"], row["protocol"]],
		["192.168.1.150", 24850, "CLOEDL", "CAMPAIGN 1", "red_de", 3, 7])
	assert_eq((row["players"] as Array).map(func(member: Dictionary) -> Array: return [member["name"], member["connected"]]),
		[["CLOEDL", true], ["MÖKI", false]])
	var foreign: Dictionary = VIEW.duplicate()
	foreign["kind"] = "someone-else"
	var oversized := PackedByteArray()
	oversized.resize(PokeCoopLobby.MAX_BEACON_BYTES + 1)
	for refused: PackedByteArray in [PokeCoopLobby.beacon_bytes(foreign, 24850), PokeCoopLobby.beacon_bytes(VIEW, 0),
			"not json".to_utf8_buffer(), oversized]:
		assert_eq(PokeCoopLobby.read_beacon(refused, "192.168.1.150"), {})


func test_join_lists_the_hosts_heard_lately_by_their_network_address() -> void:
	var listener := PokeCoopLobby.Listener.new()
	var heard: Callable = func(from: String) -> Dictionary:
		return PokeCoopLobby.read_beacon(PokeCoopLobby.beacon_bytes(VIEW, 24680), from)

	listener.hear(heard.call("192.168.1.150"), 1000)
	listener.hear(heard.call("127.0.0.1"), 1100)

	assert_eq(listener.hosts(1200).map(func(row: Dictionary) -> String: return row["address"]), ["192.168.1.150"],
		"the host's own loopback copy is one host, still at the address a partner dials")
	assert_eq(listener.hosts(1100 + PokeCoopLobby.SEEN_MSEC + 1), [], "a host that stopped is gone in a few seconds")


func test_a_beacon_crosses_a_real_socket_and_a_second_listener_on_the_port_waits() -> void:
	var listener := PokeCoopLobby.Listener.new()
	var second := PokeCoopLobby.Listener.new()
	var beacon := PokeCoopLobby.Beacon.new()
	listener.poll()
	second.poll()
	assert_true(listener.listening())
	assert_false(second.listening(), "the port is taken: this one hears nothing rather than failing")

	beacon.tick(VIEW, 24680)
	var deadline: int = Time.get_ticks_msec() + 2000
	while listener.hosts().is_empty() and Time.get_ticks_msec() < deadline:
		OS.delay_msec(10)
		listener.poll()

	assert_eq(listener.hosts().map(func(row: Dictionary) -> String: return row["title"]), ["CAMPAIGN 1"])
	listener.close()
	second.poll(Time.get_ticks_msec() + PokeCoopLobby.RETRY_MSEC)
	assert_true(second.listening(), "and takes the port once it is free")
	second.close()
	beacon.close()


func test_a_dial_tries_again_every_few_seconds_for_a_minute_then_waits_to_be_asked() -> void:
	var dial: PokeCoopLobby.Dial = PokeCoopLobby.Dial.to("127.0.0.1", NOBODY_PORT, _data, "BLUE")
	var started: int = dial.started_at
	assert_eq([dial.step, dial.attempts], [PokeCoopLobby.Dial.Step.DIALING, 1])

	dial.process(started + PokeCoopLobby.RETRY_MSEC - 1)
	assert_eq(dial.attempts, 1, "a dial is given its few seconds")
	dial.process(started + PokeCoopLobby.RETRY_MSEC)
	assert_eq([dial.step, dial.attempts, dial.seconds_left(started + PokeCoopLobby.RETRY_MSEC)],
		[PokeCoopLobby.Dial.Step.DIALING, 2, (PokeCoopLobby.DIAL_MSEC - PokeCoopLobby.RETRY_MSEC) / 1000])
	dial.process(started + PokeCoopLobby.DIAL_MSEC + PokeCoopLobby.RETRY_MSEC)
	assert_eq(dial.step, PokeCoopLobby.Dial.Step.GAVE_UP, "a minute with no host")
	assert_null(dial.client, "and the link is closed")

	dial.retry_now()
	assert_eq([dial.step, dial.attempts, dial.seconds_left(dial.started_at)], [PokeCoopLobby.Dial.Step.DIALING, 3,
		PokeCoopLobby.DIAL_MSEC / 1000], "Try now starts the minute again")
	dial.close()
	assert_eq(dial.step, PokeCoopLobby.Dial.Step.CLOSED)


func test_each_co_op_cartridge_is_ready_needs_a_new_import_or_is_missing() -> void:
	PokeCoopLobby.open_game = func(id: StringName) -> GameData: return _data if id == &"cooplobbyready" else null
	var stale: String = RomCache.directory_for(&"cooplobbystale", "")
	RomCache.prepare(stale)
	RomCache.write_json(RomCache.manifest_path(stale), {"format_version": RomCache.FORMAT_VERSION - 1, "complete": true})

	var rows: Array = PokeCoopLobby.cartridges([&"cooplobbyready", &"cooplobbystale", &"cooplobbymissing"])

	assert_eq(rows.map(func(row: Dictionary) -> StringName: return row["status"]),
		[PokeCoopLobby.READY, PokeCoopLobby.STALE, PokeCoopLobby.MISSING], "GameData not opening it is not hidden")
	assert_eq(rows[0]["data"], _data)


func test_a_host_none_of_the_cartridges_fits_names_the_one_that_would() -> void:
	var blue: GameData = Fixture.build(RomCache.directory_for(&"cooplobbyblue", ""), "blue", RomRegistry.GEN1)
	blue.sha1 = RomRegistry.sha1_for(RomRegistry.BLUE)
	var rote: GameData = Fixture.build(RomCache.directory_for(&"cooplobbyrote", ""), "red_de", RomRegistry.GEN1)
	rote.sha1 = RomRegistry.sha1_for(RomRegistry.RED_DE)
	var rows: Array = [{"id": RomRegistry.RED_DE, "data": rote}, {"id": RomRegistry.BLUE, "data": blue}]

	var fits: Array = PokeCoopLobby.fitting(rows, RomRegistry.RED, RomRegistry.sha1_for(RomRegistry.RED))

	assert_eq(fits.map(func(row: Dictionary) -> StringName: return row["id"]), [RomRegistry.BLUE])
	assert_eq(PokeCoopLobby.fitting(rows, RomRegistry.YELLOW, RomRegistry.sha1_for(RomRegistry.YELLOW)), [])
	RomCache.clear(RomCache.directory_for(&"cooplobbyblue", ""))
	RomCache.clear(RomCache.directory_for(&"cooplobbyrote", ""))


func test_the_failure_checklist_fits_the_address() -> void:
	var mine: Array = [{"address": "10.8.0.7", "network": "wg0", "kind": PokeCoopLobby.VPN},
		{"address": "192.168.1.150", "network": "eno1", "kind": PokeCoopLobby.HOME}]

	var vpn: String = "\n".join(PokeCoopLobby.advice("10.8.0.6", 24680, "CLOEDL", mine))
	var home: String = "\n".join(PokeCoopLobby.advice("192.168.1.42", 24680, "", mine))
	var public: String = "\n".join(PokeCoopLobby.advice("84.12.3.4", 24680, "", mine))

	assert_string_contains(vpn, "CLOEDL has pressed Host")
	assert_string_contains(vpn, "10.8.0.6 only works through it")
	assert_string_contains(home, "same Wi-Fi")
	assert_string_contains(home, "firewall")
	assert_string_contains(public, "forwards UDP port 24680")
	assert_false(public.contains("same Wi-Fi"))


func test_the_tab_remembers_the_last_hosts_joined_newest_first_and_once_each() -> void:
	for address: String in ["10.8.0.6", "192.168.1.150", "10.0.0.2", "10.0.0.3", "10.8.0.6"]:
		PokeCoopLobby.add_recent({"address": address, "port": 24680, "title": "AT " + address})
	PokeCoopLobby.remember({"name": "MÖKI"})

	assert_eq(PokeCoopLobby.recent().map(func(row: Dictionary) -> String: return row["address"]),
		["10.8.0.6", "10.0.0.3", "10.0.0.2", "192.168.1.150"])
	assert_eq(PokeCoopLobby.remembered()["name"], "MÖKI", "remembering one thing keeps the rest")
	assert_eq(PokeCoopLobby.split_address(" 10.8.0.6:24850 ", 24680), ["10.8.0.6", 24850])
	assert_eq(PokeCoopLobby.split_address("10.8.0.6", 24680), ["10.8.0.6", 24680])


func _pad_press(device: int, button: JoyButton = JOY_BUTTON_A) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = true
	return event


func test_split_screen_halves_play_only_the_controllers_their_players_press_a_on() -> void:
	var dualsense: Dictionary = {"guid": "0300e0274c050000f20d000000016800", "name": "DualSense Edge Wireless Controller", "serial": "14-3a-9a-61-b0-8d", "nth": 0}
	var virtual: Dictionary = {"guid": "0300c5d95e040000ea02000010010000", "name": "Xbox One S Controller", "serial": "", "nth": 0}
	var twin: Dictionary = virtual.merged({"nth": 1}, true)
	var pads: Array = [virtual.merged({"device": 0}), twin.merged({"device": 1}), dualsense.merged({"device": 2})]
	var split: GDScript = PokeCoopLobby.SplitScreen
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true

	var chosen: Array = split.halves(dualsense, pads)
	assert_eq(chosen, [dualsense, null], "Settings' pick plays on the left, not the first pad plugged in")
	assert_eq(split.pressed(chosen, _pad_press(2), pads), chosen, "the left's pad cannot take the right half too")
	assert_eq(split.pressed(chosen, _pad_press(1, JOY_BUTTON_B), pads), chosen, "only A chooses")
	chosen = split.pressed(chosen, _pad_press(1), pads)
	assert_eq(chosen, [dualsense, twin])
	assert_eq(split.pressed(chosen, _pad_press(0), pads), chosen, "both halves are taken")

	var a: StringName = PokeButton.action(PokeButton.A)
	PokePadChoice.held = chosen[1]
	PokePadChoice.apply(dualsense, pads)
	assert_eq([_pad_press(0).is_action_pressed(a), _pad_press(1).is_action_pressed(a), _pad_press(2).is_action_pressed(a)], [false, true, false],
		"the right half hears its own pad, not its twin nor the DualSense")
	PokePadChoice.held = chosen[0]
	PokePadChoice.apply(dualsense, pads)
	assert_eq([_pad_press(0).is_action_pressed(a), _pad_press(1).is_action_pressed(a), _pad_press(2).is_action_pressed(a)], [false, false, true])
	PokePadChoice.held = {}
	PokePadChoice.apply({}, [])

	chosen = split.halves({}, pads)
	assert_eq(chosen, [null, null], "Every controller in Settings: each half's player presses")
	chosen = split.pressed(chosen, enter, pads)
	assert_eq(chosen, [PokeCoopLobby.SplitScreen.NO_PAD, null], "Enter gives the left half the keyboard")
	assert_eq(split.pressed(chosen, enter, pads), chosen, "the keyboard plays one half")
	assert_eq(split.pressed(chosen, _pad_press(2), pads), [PokeCoopLobby.SplitScreen.NO_PAD, dualsense])
	assert_eq(split.halves(dualsense, pads.slice(0, 2)), [null, null], "a pick that is unplugged is asked for like the rest")


func test_a_split_screen_stacks_its_halves_top_and_bottom_when_asked() -> void:
	var split: GDScript = PokeCoopLobby.SplitScreen
	var whole := Rect2i(0, 30, 1921, 1051)

	assert_eq([split.half(whole, 0, true), split.half(whole, 1, true)], [Rect2i(0, 30, 1921, 525), Rect2i(0, 555, 1921, 526)],
		"each the screen's full width, the second below the first")
	assert_eq(split.half(whole, 1), Rect2i(960, 30, 961, 1051), "side by side stays the default")
	assert_eq([split.named(0, true), split.named(1, true), split.named(0, false), split.named(1, false)], ["top", "bottom", "left", "right"])
	var asked: Dictionary = split.read([split.argument(24850, &"red", {}, 0, true)])
	assert_true(asked["stacked"], "the second window learns the layout from its argument")
	assert_false(split.read([split.ARG + Marshalls.utf8_to_base64("{\"port\": 24850}")])["stacked"], "an argument without it is side by side")
	split.choose(true)
	split.stacked = false
	assert_true(split.remembered_stacked(), "the layout picked last time is the one the sheet opens on")
	assert_eq(PokeCoopLobby.remembered(), {"split_stacked": true}, "kept in the tab's memory")
	split.choose(false)
	assert_false(split.remembered_stacked())


func test_a_split_screen_gives_each_half_its_own_controller_over_the_one_settings_picked() -> void:
	var first: Dictionary = {"guid": "030000005e0400008e02000010010000", "name": "Xbox 360 Controller", "serial": "", "nth": 0}
	var second: Dictionary = first.merged({"nth": 1}, true)
	var pads: Array = [first.merged({"device": 0}), second.merged({"device": 1})]

	assert_eq(PokeCoopLobby.SplitScreen.halves({}, []), [{}, {}], "no controller: both halves play by keyboard")
	assert_eq(PokeCoopLobby.SplitScreen.half(Rect2i(0, 30, 1921, 1050), 0), Rect2i(0, 30, 960, 1050))
	assert_eq(PokeCoopLobby.SplitScreen.half(Rect2i(0, 30, 1921, 1050), 1), Rect2i(960, 30, 961, 1050))
	var asked: Dictionary = PokeCoopLobby.SplitScreen.read(["127.0.0.1", PokeCoopLobby.SplitScreen.argument(24850, &"blue", second, 1)])
	assert_eq(asked, {"port": 24850, "game": &"blue", "pad": second, "screen": 1, "stacked": false})
	assert_eq(PokeCoopLobby.SplitScreen.read([PokeCoopLobby.SplitScreen.ARG + Marshalls.utf8_to_base64("[24850]")]), {})

	PokePadChoice.held = second
	PokePadChoice.apply({}, pads)
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	assert_false(press.is_action_pressed(PokeButton.action(PokeButton.A)), "Every controller in Settings, still only the half's own")
	press.device = 1
	assert_true(press.is_action_pressed(PokeButton.action(PokeButton.A)))
	PokePadChoice.held = PokeCoopLobby.SplitScreen.NO_PAD
	PokePadChoice.apply(first, pads)
	assert_eq(PokePadChoice.device(), PokePadChoice.AWAY, "the keyboard's half hears no controller")
	PokePadChoice.held = {}
	PokePadChoice.apply({}, [])
