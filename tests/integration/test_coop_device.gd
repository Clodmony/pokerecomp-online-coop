extends GutTest

## A co-op session as a device runs one, over real localhost sockets: hosting
## starts or loads the campaign and plays on it, a second device joins, and a
## device that comes back is the same player it was, in each of the host's campaigns.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const PORT: int = 24791
const IDENTITY: String = "user://coop_device_test_identity.json"
const OTHER_DEVICE: String = "user://coop_device_test_other_identity.json"
const LEGACY: String = "user://coop_testgame_campaign.json"
const TAB: String = "user://coop_device_test_tab.json"
const WAIT_MSEC: int = 3000

var _directory: String = ""
var _data: GameData = null
var _identity_before: String = ""
var _sessions: Array = []
var _window_size: Vector2i = Vector2i.ZERO


func before_each() -> void:
	_directory = RomCache.directory_for(&"coopdevicetest", "0123456789abcdef")
	_data = Fixture.build(_directory, "testgame", RomRegistry.GEN1)
	_identity_before = PokeCoopSession.identity_path
	PokeCoopSession.identity_path = IDENTITY
	PokeCoopSession.campaigns_dir = "user://coop_campaigns_test"
	PokeCoopLobby.memory_path = TAB
	PokeCoopLobby.beacon_port = PORT + 50
	PokeCoopPage.host_port = PORT
	PokeCoopSession.move_legacy(_data)
	_sessions = []


func after_each() -> void:
	for session: PokeCoopSession in _sessions:
		session.close()
	PokeCoopSession.identity_path = _identity_before
	PokeCoopLobby.memory_path = "user://coop_tab.json"
	PokeCoopLobby.beacon_port = PokeCoopLobby.BEACON_PORT
	PokeCoopLobby.open_game = Callable()
	PokeCoopPage.host_port = PokeCoopEnetTransport.DEFAULT_PORT
	Gen2GameRuntime.instance().coop = null
	PokeCoopSession.ended_note = ""
	PokeCoopLobby.SplitScreen.asked = {}
	PokeCoopLobby.SplitScreen.quit_both = false
	PokeCoopLobby.SplitScreen.partner_pid = 0
	## A sheet opens on the root, so a test that ends with one up would leave its buttons to the next test's presses.
	for sheet: Node in get_tree().get_nodes_in_group(Gen2FocusGuard.MODAL_GROUP):
		if sheet is PokeCoopTabParts.Sheet:
			Gen2Screen.drop(sheet)
	if _window_size != Vector2i.ZERO:
		get_tree().root.size = _window_size
		_window_size = Vector2i.ZERO
	var folder: String = PokeCoopSession.campaign_path(_data).get_base_dir()
	var paths: Array = [IDENTITY, OTHER_DEVICE, LEGACY, TAB]
	for file_name: String in DirAccess.get_files_at(folder):
		paths.append("%s/%s" % [folder, file_name])
	for path: String in paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	RomCache.clear(_directory)


func _until_ready(wanted: Array) -> bool:
	var deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < deadline:
		for session: PokeCoopSession in _sessions:
			session.process()
		if wanted.all(func(session: PokeCoopSession) -> bool: return session.is_ready()):
			return true
		OS.delay_msec(5)
	return false


func test_a_device_hosts_and_another_joins_with_their_own_starters() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	_sessions.append(hosting)
	var joining: PokeCoopSession = PokeCoopSession.joining(
		_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR
	)
	_sessions.append(joining)

	assert_true(_until_ready([hosting, joining]), "both answered within %d ms" % WAIT_MSEC)
	assert_eq(int(hosting.client.me()["team"][0]["species"]), Fixture.CHARMANDER)
	assert_eq(int(joining.client.me()["team"][0]["species"]), Fixture.BULBASAUR)
	assert_true(hosting.host.campaign.has_flag(0x22), "a new campaign starts after Oak's intro")


func test_closing_a_session_gives_a_solo_game_back_the_cartridges_bag() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	_sessions.append(hosting)
	assert_true(_until_ready([hosting]))
	Gen2WorldPack.gen1_bag_capacity = PokeCoopPolicy.BAG_CAPACITY
	hosting.close()
	_sessions.erase(hosting)
	assert_eq(Gen2WorldPack.gen1_bag_capacity, Gen1Layout.BAG_ITEM_CAPACITY)


func test_a_reset_with_no_world_open_is_left_to_the_game() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	_sessions.append(hosting)
	assert_true(_until_ready([hosting]))

	assert_false(hosting.continue_after_reset(), "Oak's speech or the launcher resets as it always did")


func _until(condition: Callable, wait_msec: int) -> bool:
	var deadline: int = Time.get_ticks_msec() + wait_msec
	while Time.get_ticks_msec() < deadline:
		for session: PokeCoopSession in _sessions:
			session.process()
		if condition.call():
			return true
		OS.delay_msec(5)
	return false


func test_a_device_whose_link_drops_comes_back_on_its_own() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	_sessions.append(hosting)
	var joining: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR)
	_sessions.append(joining)
	assert_true(_until_ready([hosting, joining]))
	var blue_id: String = joining.client.player_id

	joining.client.transport.close()

	assert_true(_until(func() -> bool:
		return joining.client.connected and hosting.host.player(blue_id).connected, 10000
	), "the device dialled again and the host took the same player back")
	assert_eq(joining.client.player_id, blue_id)
	assert_eq(hosting.host.players.size(), 2)
	assert_eq(int(joining.get("_reconnect_attempts")), 0, "the next drop gets its own tries")


func test_a_link_the_host_still_holds_is_waited_out_as_the_same_trainer() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	_sessions.append(hosting)
	var first: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR)
	_sessions.append(first)
	assert_true(_until_ready([hosting, first]))
	var blue_id: String = first.client.player_id
	first.close()
	_sessions.erase(first)
	assert_true(_until(func() -> bool: return not hosting.host.player(blue_id).connected, 5000))
	var joining: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR)
	_sessions.append(joining)
	assert_true(_until(func() -> bool: return joining.client.welcomes == 1, WAIT_MSEC), "back as the remembered player")

	## The link dies without the host hearing it, as a phone's does when its network is still waking.
	var dead: PokeCoopTransport = joining.client.transport
	joining.client.transport = PokeCoopTransport.new()
	joining.client.connected = false

	assert_true(_until(func() -> bool: return joining.client.welcomes == 2, 12000), "welcomed again once the host let the dead link go")
	dead.close()
	assert_eq(joining.client.player_id, blue_id, "the same trainer, not a new one")
	assert_eq(hosting.host.players.size(), 2)


func test_a_second_window_on_a_device_whose_player_is_in_joins_as_somebody_new() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	_sessions.append(hosting)
	var first: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR)
	_sessions.append(first)
	assert_true(_until_ready([hosting, first]))

	var second: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "GREEN", Fixture.PIKACHU)
	_sessions.append(second)

	assert_true(_until_ready([hosting, first, second]))
	assert_ne(second.client.player_id, first.client.player_id)
	assert_eq(hosting.host.players.size(), 3)


func test_a_player_who_lost_their_remembered_id_gets_their_trainer_back_by_name() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	_sessions.append(hosting)
	var joining: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR)
	_sessions.append(joining)
	assert_true(_until_ready([hosting, joining]))
	var blue_id: String = joining.client.player_id
	joining.close()
	_sessions.erase(joining)
	assert_true(_until(func() -> bool: return not hosting.host.player(blue_id).connected, 5000))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IDENTITY))

	var back: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.PIKACHU)
	_sessions.append(back)
	assert_true(_until_ready([hosting, back]))
	assert_eq(back.client.player_id, blue_id, "the same trainer, not a new one")
	assert_eq(hosting.host.players.size(), 2)


func test_a_host_that_never_answers_is_reported_rather_than_waited_for() -> void:
	var joining: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT + 7, "BLUE", Fixture.BULBASAUR)
	_sessions.append(joining)
	joining.process()
	assert_eq(joining.ended_reason(), "", "a fresh dial is given its time")
	joining.set("_dialled_at", Time.get_ticks_msec() - PokeCoopSession.JOIN_TIMEOUT_MSEC - 1000)
	joining.process()
	assert_eq(joining.ended_reason(), "host_unreachable")
	assert_string_contains(PokeCoopPage.why_not(joining.ended_reason()), "UDP port")
	assert_string_contains(PokeCoopPage.why_not("refused: content_mismatch"), "Red or Blue of the same language")


func test_a_joining_device_back_from_a_long_pause_dials_again_at_once() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	_sessions.append(hosting)
	var joining: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR)
	_sessions.append(joining)
	assert_true(_until_ready([hosting, joining]))
	var blue_id: String = joining.client.player_id

	joining.suspend()
	joining.resume()
	assert_true(joining.client.connected, "a moment in the background keeps the link")

	joining.suspend()
	joining.set("_paused_at", Time.get_ticks_msec() - PokeCoopSession.RESUME_REDIAL_MSEC - 1000)
	joining.resume()
	assert_false(joining.client.connected, "a long pause drops the link it can no longer trust")
	assert_true(_until(func() -> bool:
		return joining.client.connected and hosting.host.player(blue_id).connected, 10000
	), "and dials straight back in as the same player")


func test_a_device_that_comes_back_is_the_same_player() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	_sessions.append(hosting)
	var first: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR)
	_sessions.append(first)
	assert_true(_until_ready([hosting, first]))
	var blue_id: String = first.client.player_id
	first.close()
	_sessions.erase(first)

	var again: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", 0)
	_sessions.append(again)
	assert_true(_until_ready([again]), "the host let the same player back in")

	assert_eq(again.client.player_id, blue_id)
	assert_eq(hosting.host.players.size(), 2, "nobody new was made")


func test_a_host_that_leaves_saves_the_campaign_and_tells_the_others() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	_sessions.append(hosting)
	var joining: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR)
	_sessions.append(joining)
	assert_true(_until_ready([hosting, joining]))

	hosting.leave()

	assert_true(_until(func() -> bool:
		return hosting.host.ended and joining.ended_reason() == "host_shutdown", WAIT_MSEC
	), "the joining device heard why the session ended")
	assert_false(hosting.is_ready(), "a session that was left does not open its world again")
	var saved: Dictionary = PokeCoopSave.read(PokeCoopSession.campaign_path(_data))
	assert_eq((saved.get("players", []) as Array).size(), 2, "both players are in the saved campaign")


func test_a_hosting_device_sent_to_the_background_keeps_the_campaign() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	_sessions.append(hosting)
	assert_true(_until_ready([hosting]))
	if FileAccess.file_exists(PokeCoopSession.campaign_path(_data)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PokeCoopSession.campaign_path(_data)))

	hosting.suspend()

	var saved: Dictionary = PokeCoopSave.read(PokeCoopSession.campaign_path(_data))
	assert_eq((saved.get("players", []) as Array).size(), 1, "the host's player is in the saved campaign")


## A single-player save of the fixture cartridge: [param species] in the party,
## a Pidgey in box 3, a story flag, two potions and 1234 money; the fixture has no maps to stand on.
func _single_player_save(trainer: String, species: int) -> Gen2SaveData:
	var save := Gen2SaveData.new()
	save.game_id = _data.id
	save.rom_sha1 = _data.sha1
	save.slot = 0
	save.player_name = trainer
	save.player_id = 4321 if trainer == "RED" else 8765
	save.run_rules = Gen2Rules.new()
	for at: int in [species, Fixture.PIKACHU]:
		var mon: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(
			Gen2BattleMon.create(_data, at, 10, [Fixture.TACKLE])
		)
		if at == species:
			save.party.append(mon)
		else:
			(save.boxes[3] as Gen2SaveBox).put(mon)
	save.current_box = 3
	save.world = Gen2WorldSnapshot.new()
	save.world.world_state.set_event_flag(0x77)
	save.world.world_state.apply_changes({}, {}, {"items": {Fixture.POTION: 2}, "money": {0: 1234}})
	return save


func test_a_campaign_hosted_from_a_save_takes_its_story_and_its_trainer() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(
		_data, PORT, "RED", 0, _single_player_save("RED", Fixture.CHARMANDER)
	)
	_sessions.append(hosting)
	var joining: PokeCoopSession = PokeCoopSession.joining(
		_data, "127.0.0.1", PORT, "BLUE", 0, "", _single_player_save("BLUE", Fixture.BULBASAUR)
	)
	_sessions.append(joining)
	assert_true(_until_ready([hosting, joining]))

	var red: PokeCoopPlayer = hosting.host.player(hosting.client.player_id)
	assert_true(hosting.host.campaign.has_flag(0x77), "the first player's save brought the story")
	assert_eq(red.team[0]["mon"].species, Fixture.CHARMANDER)
	assert_eq([red.box.size(), int(red.box[0]["box"]), red.current_box], [1, 3, 3], "the PC came along")
	assert_eq([red.item_count(Fixture.POTION), red.money], [2, 1234])
	assert_eq(red.trainer_id, 4321, "their own Pokémon are not counted as traded")
	var blue: PokeCoopPlayer = hosting.host.player(joining.client.player_id)
	assert_eq(blue.team[0]["mon"].species, Fixture.BULBASAUR, "a later player brings their trainer only")
	assert_eq(blue.money, 1234)


func test_a_full_pc_reaches_its_window_over_real_sockets() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	_sessions.append(hosting)
	assert_true(_until_ready([hosting]))
	var red: PokeCoopPlayer = hosting.host.player(hosting.client.player_id)
	for count: int in 200:
		red.store_mon(Gen2SaveBattleAdapter.from_battle_mon(
			Gen2BattleMon.create(_data, Fixture.PIKACHU, 5 + count % 40, [Fixture.TACKLE])
		))

	hosting.host.broadcast()

	assert_true(_until(func() -> bool:
		return (hosting.client.box.get("rows", []) as Array).size() == 200, WAIT_MSEC
	), "two hundred stored Pokémon arrived in one box message")


func test_a_campaign_file_this_build_cannot_read_is_left_alone() -> void:
	var path: String = PokeCoopSession.campaign_path(_data)
	FileAccess.open(path, FileAccess.WRITE).store_string("{\"kind\": \"pokerecomp_coop_campaign\", \"format_version\": 999}")

	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)

	assert_null(hosting, "no new campaign is started over it")
	assert_eq(PokeCoopSession.last_failure, "campaign_unreadable")
	assert_string_contains(FileAccess.get_file_as_string(path), "999", "the file is as it was")


func test_a_world_held_under_the_panel_keeps_its_audio_playing() -> void:
	var world: Node = add_child_autofree(Node.new())
	var audio := Node.new()
	world.add_child(audio)

	PokeCoopSession.hold_world(world, audio, true)
	assert_eq([world.can_process(), audio.can_process()], [false, true], "the battle's music goes on")
	PokeCoopSession.hold_world(world, audio, false)
	assert_eq([world.can_process(), audio.can_process()], [true, true])
	assert_eq(audio.process_mode, Node.PROCESS_MODE_INHERIT, "a paused game pauses it again")


func test_a_world_held_under_the_panel_keeps_its_touch_controls() -> void:
	var world: Node = add_child_autofree(Node.new())
	var pad: Gen2TouchPad = Gen2TouchPad.new()
	world.add_child(pad)

	PokeCoopSession.hold_world(world, null, true)
	assert_true(pad.can_process(), "a phone's A still reaches the panel")
	PokeCoopSession.hold_world(world, null, false)
	assert_eq(pad.process_mode, Node.PROCESS_MODE_INHERIT)


class Heard:
	extends Node
	var buttons: Array = []

	func _input(event: InputEvent) -> void:
		if PokeButton.pressed_in(event) != PokeButton.NONE:
			buttons.append(PokeButton.pressed_in(event))


func _finger(gestures: PokeCoopTouchGestures, index: int, at: Vector2, pressed: Variant = null) -> void:
	var event: InputEvent
	if pressed == null:
		event = InputEventScreenDrag.new()
	else:
		event = InputEventScreenTouch.new()
	event.set("index", index)
	event.set("position", at)
	if pressed != null:
		event.set("pressed", pressed)
	gestures._input(event)


func test_over_a_co_op_menu_a_swipe_is_one_press_a_row_and_a_tap_is_a() -> void:
	var input: Gen2InputRuntime = Gen2InputRuntime.instance()
	for button: int in PokeButton.ALL:
		input.release(button)
	for action: StringName in PokeButton.UI_ACTIONS.values():
		Input.action_release(action)
	input.stall(0)
	input._held_back.clear()
	Input.flush_buffered_events()
	await wait_process_frames(2)
	var options := Gen2Options.new()
	options.touch_mode = Gen2Options.TOUCH_ALWAYS
	Gen2InputRuntime.instance().apply_options(options)
	var screen: Control = add_child_autofree(Control.new())
	screen.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT) * 4.0
	var pad: Gen2TouchPad = add_child_autofree(Gen2TouchPad.new())
	pad.size = screen.size
	var open: Array = [false]
	var gestures: PokeCoopTouchGestures = add_child_autofree(PokeCoopTouchGestures.over(screen, func() -> bool: return open[0]))
	var heard: Heard = add_child_autofree(Heard.new())
	var middle := Vector2(320, 280)
	var row: float = gestures.row_pixels()
	assert_eq(row, 64.0, "two tiles at four screen pixels a hardware pixel")

	for walking: Array in [[middle, middle + Vector2(0, row * 3)], [middle, middle]]:
		_finger(gestures, 0, walking[0], true)
		_finger(gestures, 0, walking[1])
		_finger(gestures, 0, walking[1], false)
	await wait_frames(10)
	assert_eq(heard.buttons, [], "walking on the map is the pad's alone")

	open[0] = true
	_finger(gestures, 0, middle, true)
	for at: Vector2 in [middle + Vector2(0, row * 0.4), middle + Vector2(0, row * 2.2), middle + Vector2(0, row * 1.1)]:
		_finger(gestures, 0, at)
	_finger(gestures, 0, middle + Vector2(0, row * 1.1), false)
	_finger(gestures, 0, middle, true)
	_finger(gestures, 0, middle + Vector2(row * 1.5, 4), false)
	_finger(gestures, 0, middle, true)
	_finger(gestures, 0, middle + Vector2(row * 0.2, 3), false)
	await wait_frames(30)
	assert_eq(heard.buttons, [PokeButton.DOWN, PokeButton.DOWN, PokeButton.UP, PokeButton.RIGHT, PokeButton.A],
		"down two rows and back one, right one, then a tap that wobbled less than half a row")

	heard.buttons.clear()
	_finger(gestures, 0, middle, true)
	_finger(gestures, 1, middle + Vector2(50, 0), true)
	_finger(gestures, 0, middle + Vector2(0, row * 3))
	_finger(gestures, 0, middle, false)
	_finger(gestures, 1, middle, false)
	var on_pad: Vector2 = Vector2(-1, -1)
	for x: int in range(0, int(screen.size.x), 16):
		for y: int in range(0, int(screen.size.y), 16):
			if on_pad.x < 0 and pad.button_at(Vector2(x, y)) != PokeButton.NONE:
				on_pad = Vector2(x, y)
	assert_gt(on_pad.x, -1.0, "the pad stands over the screen")
	_finger(gestures, 0, on_pad, true)
	_finger(gestures, 0, on_pad, false)
	_finger(gestures, 0, screen.size + Vector2(10, 10), true)
	_finger(gestures, 0, screen.size + Vector2(10, 10), false)
	await wait_frames(10)
	Gen2InputRuntime.instance().apply_options(Gen2Options.new())
	assert_eq(heard.buttons, [], "two fingers, a finger on the pad and one off the screen are left alone")


func _close_all() -> void:
	for session: PokeCoopSession in _sessions:
		session.close()
	_sessions = []


func test_each_campaign_keeps_its_own_trainers_and_a_device_is_remembered_in_each() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(
		_data, PORT, "RED", Fixture.CHARMANDER, null, "testgame-a", "WITH BLUE"
	)
	var blue: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR)
	_sessions.append_array([hosting, blue])
	assert_true(_until_ready([hosting, blue]))
	var blue_in_a: String = blue.client.player_id
	_close_all()

	PokeCoopSession.identity_path = OTHER_DEVICE
	hosting = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER, null, "testgame-b", "WITH GREEN")
	var green: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "GREEN", Fixture.PIKACHU)
	_sessions.append_array([hosting, green])
	assert_true(_until_ready([hosting, green]))
	assert_eq(green.client.player_id, blue_in_a, "the second campaign numbers its own players")
	green.close()
	_sessions.erase(green)
	assert_true(_until(func() -> bool: return not hosting.host.player(blue_in_a).connected, 5000))
	PokeCoopSession.identity_path = IDENTITY
	var stranger: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR)
	_sessions.append(stranger)
	assert_true(_until_ready([stranger]))
	assert_ne(stranger.client.player_id, blue_in_a, "BLUE's device does not take GREEN's trainer")
	assert_eq(hosting.host.players.size(), 3)
	_close_all()

	hosting = PokeCoopSession.hosting(_data, PORT, "RED", 0, null, "testgame-a")
	var back: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "AZURE", 0)
	_sessions.append_array([hosting, back])
	assert_true(_until_ready([hosting, back]))
	assert_eq(back.client.player_id, blue_in_a, "the device is BLUE again in BLUE's campaign")
	assert_eq([hosting.host.players.size(), hosting.host.campaign.title], [2, "WITH BLUE"])
	var listed: Dictionary = {}
	for row: Dictionary in PokeCoopSession.campaigns(_data, PORT):
		listed[row["id"]] = row
	assert_eq(listed.keys().size(), 2)
	assert_eq([listed["testgame-a"]["you"], listed["testgame-b"]["you"]], ["RED", ""], "who this device is where it hosted")
	assert_eq(listed["testgame-b"]["members"], [{"name": "RED", "game": "testgame"}, {"name": "GREEN", "game": "testgame"},
		{"name": "BLUE", "game": "testgame"}], "each player with the cartridge they play")


func test_the_campaign_file_of_earlier_builds_moves_into_the_folder_and_still_loads() -> void:
	var campaign: PokeCoopCampaign = PokeCoopCampaign.create(String(_data.id), _data.id, _data.sha1)
	campaign.flags[0x77] = true
	assert_eq(PokeCoopSave.write(LEGACY, campaign, []), OK)

	var listed: Array = PokeCoopSession.campaigns(_data)

	assert_eq(listed.map(func(row: Dictionary) -> String: return row["id"]), [String(_data.id)])
	assert_false(FileAccess.file_exists(LEGACY))
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	_sessions.append(hosting)
	assert_true(hosting.host.campaign.has_flag(0x77), "the moved campaign is the one hosted")


func test_closing_a_hosting_window_tells_the_joiner_before_the_app_quits() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	var joining: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR)
	_sessions.append_array([hosting, joining])
	assert_true(_until_ready([hosting, joining]))
	var quit: Array = []
	hosting.quit_app = func() -> void: quit.append(true)

	hosting.quit_after_goodbye()

	assert_true(_until(func() -> bool: return not quit.is_empty(), 5000), "the app quits once the goodbye is out")
	assert_eq(joining.ended_reason(), "host_shutdown", "and the joiner heard why")
	joining.close()
	assert_true((Engine.get_main_loop() as SceneTree).is_auto_accept_quit(), "a closed session lets the window close again")


func _launcher_on_coop_tab(pick_tab: bool = true) -> Control:
	Gen2InputRuntime.instance().apply_options(Gen2Options.new())
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1152, 648)
	var launcher: Control = add_child_autofree(load(PokeCoopSession.LAUNCHER_SCENE).instantiate())
	await get_tree().process_frame
	Gen2InputRuntime.instance()._input(InputEventJoypadButton.new())
	if pick_tab:
		launcher.select_page(&"coop")
	await wait_frames(4)
	return launcher


func test_a_host_alone_in_a_new_campaign_hears_the_first_partner_arrive() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	_sessions.append(hosting)
	assert_true(_until_ready([hosting]))
	var notice: Label = autofree(Label.new())
	hosting.set("_notice", notice)
	hosting._tell_partners()

	var joining: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR)
	_sessions.append(joining)
	assert_true(_until(func() -> bool:
		return PokeCoopSession.partner_states(hosting.client).values().any(func(view: Dictionary) -> bool:
			return bool(view["connected"])), WAIT_MSEC))
	hosting._tell_partners()

	assert_eq(notice.text, "BLUE joined the session.", "nobody was there before, which is not nobody seen yet")


func test_a_device_the_host_sent_away_is_back_on_the_co_op_tab_and_told_why() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	var joining: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR)
	_sessions.append_array([hosting, joining])
	assert_true(_until_ready([hosting, joining]))
	hosting.leave()
	assert_true(_until(func() -> bool: return joining.ended_reason() == "host_shutdown", WAIT_MSEC))

	joining.leave()
	var launcher: Control = await _launcher_on_coop_tab(false)

	var shell: Gen2LauncherShell = launcher.get("_shell")
	assert_eq(shell.current_page(), &"coop", "not the cartridge shelf")
	assert_eq((shell.toast().get("_heading") as Label).text, "The host closed the session.", "said where it is seen")
	Gen2OptionsStore.use_test_path()


func test_a_new_campaign_names_its_rival_and_renaming_or_deleting_it_keeps_a_backup() -> void:
	var id: String = PokeCoopSession.new_campaign(_data, "WITH BLUE", "GARY")
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", PokeCoopPolicy.PLAY_OPENING, null, id)
	var joining: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", PokeCoopPolicy.PLAY_OPENING)
	_sessions.append_array([hosting, joining])
	assert_true(_until_ready([hosting, joining]))
	assert_eq([hosting.host.campaign.title, joining.rival_name()], ["WITH BLUE", "GARY"], "Oak asks nobody for the rival's name")
	_close_all()

	assert_eq(PokeCoopSession.edit_campaign(_data, id, "RIVALS", "JOHN"), OK)
	var listed: Dictionary = PokeCoopSession.campaigns(_data, PORT)[0]
	assert_eq([listed["title"], listed["rival"], listed["players"]], ["RIVALS", "JOHN", ["RED", "BLUE"]], "the players stay")

	assert_eq(PokeCoopSession.delete_campaign(_data, id), OK)
	var path: String = PokeCoopSession.campaign_path(_data, id)
	assert_eq(PokeCoopSession.campaigns(_data, PORT), [])
	assert_false(FileAccess.file_exists(path))
	var kept: Dictionary = PokeCoopSave.read(path + PokeCoopSave.BACKUP_SUFFIX)
	assert_eq([(kept["campaign"] as PokeCoopCampaign).title, (kept["players"] as Array).size()], ["RIVALS", 2],
		"the last checkpoint stays as the backup")


func test_a_blaue_cartridge_lists_and_hosts_a_rote_campaign_from_its_own_folder() -> void:
	var blaue_cache: String = RomCache.directory_for(&"coopdeviceblaue", "")
	var blaue: GameData = Fixture.build(blaue_cache, String(RomRegistry.BLUE_DE), RomRegistry.GEN1)
	blaue.sha1 = RomRegistry.sha1_for(RomRegistry.BLUE_DE)
	var rote: PokeCoopCampaign = PokeCoopCampaign.create("rote-1", RomRegistry.RED_DE, RomRegistry.sha1_for(RomRegistry.RED_DE))
	rote.title = "ROTE RUN"
	PokeCoopPolicy.start_campaign(rote)
	var rote_path: String = PokeCoopSession.campaign_path(blaue, "rote-1", RomRegistry.RED_DE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(rote_path.get_base_dir()))
	assert_eq(PokeCoopSave.write(rote_path, rote, []), OK)
	PokeCoopLobby.open_game = func(id: StringName) -> GameData: return blaue if id == RomRegistry.BLUE_DE else null
	PokeCoopPage.forget()
	var page: PokeCoopPage = add_child_autofree(PokeCoopPage.create(Gen2LauncherTheme.active()))

	assert_true(_press(page, "HOST"))
	var said: Array = PokeCoopPage._find(page, func(node: Node) -> bool: return node is Label).map(func(label: Label) -> String:
		return label.text)
	assert_has(said, "ROTE RUN", "the other version's campaign is listed")
	assert_has(said, "%s campaign" % PokeCoopLobby.short_title(RomRegistry.RED_DE), "and labelled with its game")
	assert_true(_press(page, "Host ROTE RUN"))
	_type(page, "name", "blau")
	assert_true(_press(page, "Start in Pallet Town"))
	assert_true(_press(page, "Host as BLAU"))
	var hosting: PokeCoopSession = Gen2GameRuntime.instance().coop
	_sessions.append(hosting)
	assert_true(_until_ready([hosting]))

	assert_eq([hosting.data.id, hosting.host.campaign.game_id, hosting.host.save_path], [RomRegistry.BLUE_DE, RomRegistry.RED_DE, rote_path],
		"the host's window plays Blaue; the campaign stays in Rote's folder")
	assert_eq(hosting.host.player(hosting.client.player_id).game_id, String(RomRegistry.BLUE_DE))
	assert_eq(PokeCoopSession.campaigns(blaue, PORT), [], "no copy in Blaue's folder")
	_close_all()
	assert_eq(PokeCoopSession.campaigns(blaue, PORT, RomRegistry.RED_DE)[0]["you"], "BLAU", "remembered as the campaign's host")
	for path: String in [rote_path, rote_path + PokeCoopSave.BACKUP_SUFFIX, rote_path + PokeCoopSave.JOURNAL_SUFFIX]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for folder: String in [rote_path.get_base_dir(), PokeCoopSession.campaign_path(blaue).get_base_dir()]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	RomCache.clear(blaue_cache)


func test_wild_pokemon_from_both_versions_is_a_campaign_switch_off_until_turned_on() -> void:
	var cache: String = RomCache.directory_for(&"coopdevicerote", "")
	var rote: GameData = Fixture.build(cache, String(RomRegistry.RED_DE), RomRegistry.GEN1)
	rote.sha1 = RomRegistry.sha1_for(RomRegistry.RED_DE)
	PokeCoopLobby.open_game = func(id: StringName) -> GameData: return rote if id == RomRegistry.RED_DE else null
	PokeCoopPage.forget()
	var page: PokeCoopPage = add_child_autofree(PokeCoopPage.create(Gen2LauncherTheme.active()))
	_press(page, "HOST")
	_press(page, "+ New campaign")
	_type(page, "title", "plain")
	_press(page, "Create and host")
	_sessions.append(Gen2GameRuntime.instance().coop)
	_close_all()
	var plain: Dictionary = PokeCoopSession.campaigns(rote, PORT)[0]
	assert_false(bool(plain["both_versions"]), "off unless turned on")

	page = add_child_autofree(PokeCoopPage.create(Gen2LauncherTheme.active()))
	_press(page, "HOST")
	(page as PokeCoopPage)._open_edit(0)
	assert_true(_press(page, "Wild Pokémon from both versions"), "an existing campaign can take it")
	assert_true(_press(page, "Save"))
	var hosting: PokeCoopSession = PokeCoopSession.hosting(rote, PORT, "ROT", 0, null, String(plain["id"]))
	_sessions.append(hosting)
	assert_true(hosting.host.campaign.both_versions)
	assert_eq(hosting.host.wild_tables_missing(), [RomRegistry.RED_DE, RomRegistry.BLUE_DE], "until each version's device sends its slots")
	_close_all()
	for path: String in DirAccess.get_files_at(PokeCoopSession.campaign_path(rote).get_base_dir()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PokeCoopSession.campaign_path(rote).get_base_dir().path_join(path)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PokeCoopSession.campaign_path(rote).get_base_dir()))
	RomCache.clear(cache)


func test_a_device_asks_the_host_first_and_says_hello_on_the_same_link() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER, null, "", "WITH BLUE")
	_sessions.append(hosting)
	assert_true(_until_ready([hosting]))
	var dial: PokeCoopLobby.Dial = PokeCoopLobby.Dial.to("127.0.0.1", PORT, _data, "BLUE")
	assert_true(_until(func() -> bool:
		dial.process()
		return dial.step == PokeCoopLobby.Dial.Step.ANSWERED, WAIT_MSEC))
	assert_eq([dial.answer()["title"], dial.answer()["host"], dial.answer()["you"]], ["WITH BLUE", "RED", {}])
	assert_eq(hosting.host.players.size(), 1, "asking made nobody")

	var joining: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR, "", null, null, dial.take())
	_sessions.append(joining)
	assert_true(_until_ready([hosting, joining]))
	assert_eq(dial.step, PokeCoopLobby.Dial.Step.CLOSED)
	var blue: PokeCoopPlayer = hosting.host.player(joining.client.player_id)
	assert_eq([blue.name, blue.game_id, blue.via], ["BLUE", String(_data.id), "127.0.0.1"])


func _tab() -> PokeCoopPage:
	PokeCoopLobby.open_game = func(id: StringName) -> GameData: return _data if id == RomRegistry.RED else null
	PokeCoopPage.forget()
	return add_child_autofree(PokeCoopPage.create(Gen2LauncherTheme.active()))


func _press(page: Node, label: String) -> bool:
	var roots: Array = page.get_tree().get_nodes_in_group(Gen2FocusGuard.MODAL_GROUP).filter(func(node: Node) -> bool:
		return node is PokeCoopTabParts.Sheet)
	roots.append(page)
	for root: Node in roots:
		for node: Node in PokeCoopPage._find(root, func(node: Node) -> bool:
				return node is BaseButton and (node as Control).is_visible_in_tree() and (node.get_meta("label", "") == label \
					or (node is Gen2LauncherButton and (node as Gen2LauncherButton).text == label))):
			if node is PokeCoopTabParts.Tile:
				(node as PokeCoopTabParts.Tile).chosen.emit()
			else:
				(node as BaseButton).pressed.emit()
			return true
	return false


func _type(page: Node, field: String, text: String) -> void:
	var edit: LineEdit = PokeCoopPage._find(page, func(node: Node) -> bool: return node is LineEdit and node.name == field)[0]
	edit.text = text
	edit.text_changed.emit(text)


func _refresh(page: PokeCoopPage) -> void:
	page.set("_refreshed_at", -PokeCoopPage.REFRESH_MSEC)
	page._process(0.0)


func test_the_co_op_tab_hosts_a_new_campaign_and_shows_who_joins() -> void:
	var page: PokeCoopPage = _tab()
	assert_eq(page.screen(), PokeCoopPage.START)

	assert_true(_press(page, "HOST"))
	assert_eq(page.screen(), PokeCoopPage.HOST)
	assert_true(_press(page, "+ New campaign"))
	assert_eq(page.screen(), PokeCoopPage.NEW_CAMPAIGN)
	_type(page, "title", "with blue")
	_type(page, "rival", "gary")
	_type(page, "name", "red")
	assert_true(_press(page, "Start in Pallet Town"))
	assert_true(_press(page, "Create and host"))

	assert_eq(page.screen(), PokeCoopPage.HOSTING)
	var hosting: PokeCoopSession = Gen2GameRuntime.instance().coop
	_sessions.append(hosting)
	assert_eq([hosting.host.campaign.title, hosting.host.campaign.rival_name], ["WITH BLUE", "GARY"])
	var joining: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR)
	_sessions.append(joining)
	assert_true(_until_ready([hosting, joining]))
	_refresh(page)
	var states: Array = PokeCoopPage._find(page, func(node: Node) -> bool: return node is Label and node.text in ["Here", "Joined"])
	assert_eq(states.map(func(label: Label) -> String: return label.text), ["Here", "Joined"], "RED here, BLUE joined")

	assert_true(_press(page, "Stop hosting"))
	assert_eq(page.screen(), PokeCoopPage.HOSTING, "a partner is in: asked first")
	assert_true(_press(page, "Stop hosting"))
	assert_eq(page.screen(), PokeCoopPage.START)
	assert_true(_until(func() -> bool: return joining.ended_reason() == "host_shutdown", WAIT_MSEC), "BLUE is told, not left redialling")
	assert_eq(PokeCoopSession.ended_note, "", "and the host's own tab does not say it left")


func test_the_co_op_tab_joins_by_address_and_a_new_player_names_themself() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER, null, "", "WITH BLUE")
	_sessions.append(hosting)
	assert_true(_until_ready([hosting]))
	var page: PokeCoopPage = _tab()

	assert_true(_press(page, "JOIN"))
	assert_eq(page.screen(), PokeCoopPage.JOIN)
	_type(page, "address", "127.0.0.1:%d" % PORT)
	assert_true(_press(page, "Join"))
	assert_true(_until(func() -> bool:
		_refresh(page)
		return page.screen() == PokeCoopPage.NEW_PLAYER, WAIT_MSEC), "asked, and the host does not know this device")
	assert_eq((page.get("_title") as Label).text, "New in WITH BLUE")
	_type(page, "name", "blue")
	assert_true(_press(page, "Start in Pallet Town"))
	assert_true(_press(page, "Join as BLUE"))
	var joining: PokeCoopSession = Gen2GameRuntime.instance().coop
	_sessions.append(joining)
	assert_true(_until_ready([hosting, joining]))
	PokeCoopPage.forget()
	assert_eq(int(joining.client.me()["team"][0]["species"]), PokeCoopPolicy.STARTERS[1])
	assert_eq(hosting.host.players.size(), 2)

	var again: PokeCoopPage = _tab()
	_press(again, "JOIN")
	assert_eq((PokeCoopPage._find(again, func(node: Node) -> bool: return node is LineEdit)[0] as LineEdit).text,
		"127.0.0.1:%d" % PORT, "the address last joined")
	assert_true(_press(again, "127.0.0.1:%d · WITH BLUE" % PORT), "and among the recent hosts")


func test_a_device_the_host_knows_joins_as_its_trainer_in_one_press() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER, null, "", "WITH BLUE")
	var first: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR)
	_sessions.append_array([hosting, first])
	assert_true(_until_ready([hosting, first]))
	var blue_id: String = first.client.player_id
	first.close()
	_sessions.erase(first)
	assert_true(_until(func() -> bool: return not hosting.host.player(blue_id).connected, 5000))
	var page: PokeCoopPage = _tab()
	_press(page, "JOIN")
	_type(page, "address", "127.0.0.1:%d" % PORT)
	_press(page, "Join")

	assert_true(_until(func() -> bool:
		_refresh(page)
		return _press(page, "Join as BLUE"), WAIT_MSEC), "the sheet says who this device is")
	var joining: PokeCoopSession = Gen2GameRuntime.instance().coop
	_sessions.append(joining)
	assert_true(_until_ready([hosting, joining]))
	PokeCoopPage.forget()
	assert_eq(joining.client.player_id, blue_id)


func test_join_dials_the_remembered_address_the_field_shows() -> void:
	PokeCoopLobby.remember({"address": "127.0.0.1:%d" % (PORT + 9)})
	var page: PokeCoopPage = _tab()
	_press(page, "JOIN")
	_press(page, "Join")
	var dial: PokeCoopLobby.Dial = PokeCoopPage.dialling()
	assert_not_null(dial, "Join dials what the field shows without a keystroke")
	_press(page, "Cancel")


func test_a_failed_join_says_what_to_check_for_the_address_and_keeps_trying() -> void:
	var page: PokeCoopPage = _tab()
	_press(page, "JOIN")
	_type(page, "address", "127.0.0.1:%d" % (PORT + 9))
	_press(page, "Join")
	var dial: PokeCoopLobby.Dial = PokeCoopPage.dialling()
	dial.process(dial.started_at + PokeCoopLobby.RETRY_MSEC)
	_refresh(page)

	var said: String = " ".join(PokeCoopPage._find(page.get_tree().root, func(node: Node) -> bool: return node is Label).map(
		func(label: Label) -> String: return label.text))
	assert_string_contains(said, "Still looking for 127.0.0.1:%d" % (PORT + 9))
	assert_string_contains(said, "of 1:00")
	assert_string_contains(said, "Host on the other window first", "a loopback address gets this device's advice")
	assert_true(_press(page, "Cancel"))
	assert_null(PokeCoopPage.dialling(), "Cancel closes the dial")


func test_a_phone_held_upright_stacks_the_tab_and_raises_its_sheets_from_the_bottom() -> void:
	var page: PokeCoopPage = _tab()
	page.set_compact(true)
	assert_true((page.get("_bar") as BoxContainer).vertical, "the primary button is pinned full width")
	var strips: Array = PokeCoopPage._find(page, func(node: Node) -> bool:
		return node is ScrollContainer and (node as ScrollContainer).vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED)
	assert_eq(strips.size(), 1, "the cartridges are a sideways strip")
	for entry: Dictionary in page.hints():
		if entry["action"] == &"ui_menu":
			(entry["run"] as Callable).call()
	await wait_frames(3)

	var sheet: Control = page.get_tree().get_nodes_in_group(Gen2FocusGuard.MODAL_GROUP)[0]
	var card: Control = sheet.get("_card")
	assert_almost_eq(card.position.y + card.size.y, sheet.size.y, 1.0, "the sheet rises from the bottom edge")
	assert_almost_eq(card.size.x, sheet.size.x, 1.0)
	page.set_compact(false)
	assert_false((page.get("_bar") as BoxContainer).vertical)


func _pad_reach(from: Control) -> Array:
	var reached: Array = [from]
	var at: int = 0
	while at < reached.size():
		for side: int in [SIDE_TOP, SIDE_BOTTOM, SIDE_LEFT, SIDE_RIGHT]:
			var next: Control = (reached[at] as Control).find_valid_focus_neighbor(side)
			if next != null and not reached.has(next):
				reached.append(next)
		at += 1
	return reached


func test_a_pad_reaches_every_button_and_field_on_the_co_op_tabs_screens() -> void:
	PokeCoopLobby.open_game = func(id: StringName) -> GameData: return _data if id == RomRegistry.RED else null
	PokeCoopPage.forget()
	var launcher: Control = await _launcher_on_coop_tab()
	var page: PokeCoopPage = launcher.find_children("*", "Control", true, false).filter(
		func(node: Node) -> bool: return node is PokeCoopPage)[0]

	for screen: StringName in [PokeCoopPage.START, PokeCoopPage.HOST, PokeCoopPage.NEW_CAMPAIGN, PokeCoopPage.JOIN,
			PokeCoopPage.NEW_PLAYER]:
		page._show(screen)
		await wait_frames(4)
		var landed: Control = launcher.get_viewport().gui_get_focus_owner()
		assert_true(landed != null and page.is_ancestor_of(landed), "%s: a pad lands on the screen" % screen)
		if landed == null:
			continue
		var reached: Array = _pad_reach(landed)
		var missed: Array = page.find_children("*", "Control", true, false).filter(func(control: Control) -> bool:
			return control.focus_mode == Control.FOCUS_ALL and control.is_visible_in_tree() \
				and not (control is BaseButton and (control as BaseButton).disabled) and not reached.has(control)
		).map(func(control: Control) -> String: return "%s %s" % [control.get_class(), control.get_meta("label", control.name)])
		assert_eq(missed, [], "%s: the d-pad reaches every button and field" % screen)
	Gen2OptionsStore.use_test_path()


func test_a_pad_types_an_address_and_a_name_on_the_tabs_own_keys() -> void:
	PokeCoopLobby.open_game = func(id: StringName) -> GameData: return _data if id == RomRegistry.RED else null
	PokeCoopPage.forget()
	var launcher: Control = await _launcher_on_coop_tab()
	var page: PokeCoopPage = launcher.find_children("*", "Control", true, false).filter(
		func(node: Node) -> bool: return node is PokeCoopPage)[0]
	page._show(PokeCoopPage.JOIN)
	await wait_frames(4)
	var address: LineEdit = launcher.get_viewport().gui_get_focus_owner()
	assert_eq(address.name, "address")
	await _pad_press(JOY_BUTTON_A)
	var keys: Array = get_tree().get_nodes_in_group(Gen2FocusGuard.MODAL_GROUP)
	assert_eq(keys.size(), 1, "A on the field opens the keys")
	if keys.is_empty():
		Gen2OptionsStore.use_test_path()
		return
	var landed: Control = launcher.get_viewport().gui_get_focus_owner()
	assert_true(landed != null and (keys[0] as Node).is_ancestor_of(landed), "the pad lands on a key")
	var on_card: Array = (keys[0] as Node).find_children("*", "BaseButton", true, false)
	assert_eq(on_card.filter(func(key: Control) -> bool: return not _pad_reach(landed).has(key)), [], "the d-pad reaches every key")
	for key: String in Array("127.0.0.19".split("")) + ["Delete"] + Array((":%d" % (PORT + 9)).split("")):
		assert_true(_press(page, key), "a key for %s" % key)
	await _pad_press(JOY_BUTTON_B)
	assert_eq(address.text, "127.0.0.1:%d" % (PORT + 9))
	assert_eq(launcher.get_viewport().gui_get_focus_owner(), address, "B puts the pad back on the field")
	_press(page, "Join")
	assert_not_null(PokeCoopPage.dialling(), "Join dials what the keys typed")
	_press(page, "Cancel")

	page._show(PokeCoopPage.NEW_PLAYER)
	await wait_frames(4)
	await _pad_press(JOY_BUTTON_A)
	for key: String in ["Delete", "Delete", "Delete", "A", "S", "H", "Space", "K"]:
		assert_true(_press(page, key), "a key for %s" % key)
	_press(page, "Done")
	await wait_frames(2)
	assert_eq(page._name(), "ASH K")
	assert_eq(get_tree().get_nodes_in_group(Gen2FocusGuard.MODAL_GROUP).size(), 0, "Done closes the keys")
	Gen2OptionsStore.use_test_path()


func _pad_press(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = down
		Input.parse_input_event(event)
		await wait_frames(2)


func test_a_pad_entering_the_co_op_tab_lands_on_host() -> void:
	PokeCoopLobby.open_game = func(id: StringName) -> GameData: return _data if id == RomRegistry.RED else null
	PokeCoopPage.forget()
	var launcher: Control = await _launcher_on_coop_tab()

	var focused: Control = launcher.get_viewport().gui_get_focus_owner()
	assert_eq(focused.get_meta("label", "") if focused != null else "", "HOST", "a pad lands on Host")
	Gen2OptionsStore.use_test_path()


func test_a_cartridge_imported_while_the_tab_is_away_is_ready_when_the_tab_is_shown_again() -> void:
	PokeCoopLobby.remember({"game": String(RomRegistry.RED)})
	PokeCoopLobby.open_game = func(_id: StringName) -> GameData: return null
	PokeCoopPage.forget()
	var page: PokeCoopPage = add_child_autofree(PokeCoopPage.create(Gen2LauncherTheme.active()))
	var red: Callable = func() -> PokeCoopTabParts.Tile:
		return PokeCoopPage._find(page, func(node: Node) -> bool:
			return node is PokeCoopTabParts.Tile and node.get_meta("label", "") == PokeCoopLobby.title(RomRegistry.RED))[0]
	var says: Callable = func(tile: Node) -> Array:
		return PokeCoopPage._find(tile, func(node: Node) -> bool: return node is Label).map(func(label: Label) -> String: return label.text)
	assert_false(says.call(red.call()).has("Ready"))

	page.visible = false
	PokeCoopLobby.open_game = func(id: StringName) -> GameData: return _data if id == RomRegistry.RED else null
	page.visible = true

	assert_true(says.call(red.call()).has("Ready"), "the tab reads the cartridges again when it comes back")
	var host: Array = PokeCoopPage._find(page, func(node: Node) -> bool: return node is PokeCoopTabParts.Tile and node.get_meta("label", "") == "HOST")
	assert_false((host[0] as PokeCoopTabParts.Tile).disabled, "and hosts with it")


func test_quit_both_closes_a_split_screens_right_half_with_the_code_its_host_reads() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	var joining: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR)
	_sessions.append_array([hosting, joining])
	assert_true(_until_ready([hosting, joining]))
	var quit: Array = []
	hosting.quit_app = func() -> void: quit.append("RED")
	joining.quit_app = func() -> void: quit.append("BLUE %d" % PokeCoopLobby.SplitScreen.exit_code())
	PokeCoopLobby.SplitScreen.asked = {"port": PORT}

	PokeCoopLobby.SplitScreen.quit_both = true

	assert_true(_until(func() -> bool: return quit.has("BLUE %d" % PokeCoopLobby.SplitScreen.QUIT_BOTH), 5000),
		"the right half quits after its goodbye, with the code that asks the host to follow")


func test_a_split_screens_host_quits_when_its_right_half_quit_both() -> void:
	if not FileAccess.file_exists("/bin/sh"):
		pass_test("needs /bin/sh to stand in for the right half's process")
		return
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	var joining: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR)
	_sessions.append_array([hosting, joining])
	assert_true(_until_ready([hosting, joining]))
	var quit: Array = []
	hosting.quit_app = func() -> void: quit.append("RED")
	joining.quit_app = func() -> void: quit.append("BLUE")

	PokeCoopLobby.SplitScreen.partner_pid = OS.create_process("/bin/sh", ["-c", "exit %d" % PokeCoopLobby.SplitScreen.QUIT_BOTH])

	assert_true(_until(func() -> bool: return quit.has("RED"), 5000), "the host follows its right half out")
	assert_eq(joining.ended_reason(), "host_shutdown", "after saying goodbye")


func test_a_split_screens_right_half_whose_host_is_gone_gives_up_at_once() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	var joining: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR)
	_sessions.append_array([hosting, joining])
	assert_true(_until_ready([hosting, joining]))
	PokeCoopLobby.SplitScreen.asked = {"port": PORT}

	joining.client.transport.close()

	assert_true(_until(func() -> bool: return joining.ended_reason() == "host_unreachable", 1000),
		"the host's window is on this device: a dropped link means it is gone")
	assert_eq(int(joining.get("_reconnect_attempts")), 0, "no two minutes of redialling")
