extends GutTest

## A window's START > SAVE while the host would refuse the campaign checkpoint (a
## battle is running): the game's own box says the save failed, never that it
## saved, and no checkpoint is asked for. Over the in-memory transport; the world
## screen runs on the synthetic world cache, the session on the battle fixture.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const WorldFixture := preload("res://tests/integration/world_trainer_fixture.gd")
const SAVE_PATH: String = "user://coop_save_refusal_test.json"
const WORLD_GAME: StringName = &"coopsaverefusal"
const PALLET: Vector2i = Vector2i(0, 0)
const QUESTION_PRESS_CAP: int = 12
const FAILED_LINES: Array = ["Save failed:", "battle in progress"]

var _directory: String = ""
var _data: GameData = null
var _host: PokeCoopHost = null
var _clients: Array = []
var _links: Array = []
var _red: PokeCoopClient = null
var _blue: PokeCoopClient = null
var _world_screen: Gen2WorldScreen = null
var _frame: int = 1000


func before_each() -> void:
	_directory = RomCache.directory_for(&"coopsaverefusaltest", "0123456789abcdef")
	_data = Fixture.build(_directory, "testgame", RomRegistry.GEN1)
	_host = PokeCoopHost.create(
		_data, PokeCoopCampaign.create("c1", _data.id, _data.sha1), PokeCoopTransport.new()
	)
	_host.save_path = SAVE_PATH
	_host.seeds.seed = 99
	var red: PokeCoopPlayer = _host.add_player("RED", 100)
	red.place(PALLET, Vector2i(5, 5), 0)
	red.add_mon(_saved(Fixture.CHARMANDER, 60, [Fixture.SLASH, Fixture.GROWL], 100))
	var blue: PokeCoopPlayer = _host.add_player("BLUE", 200)
	blue.place(PALLET, Vector2i(6, 5), 0)
	blue.add_mon(_saved(Fixture.BULBASAUR, 20, [Fixture.TACKLE], 200))
	_host.register_encounter("wild:weak", {"species": Fixture.BULBASAUR, "level": 2, "moves": [Fixture.GROWL]})
	_clients = []
	_links = []
	_red = _connect(1, red.player_id)
	_blue = _connect(2, blue.player_id)


func after_each() -> void:
	if is_instance_valid(_world_screen):
		_world_screen.free()
		_world_screen = null
	RomCache.clear(WorldFixture.directory(WORLD_GAME))
	RomCache.clear(_directory)
	for path: String in [SAVE_PATH, SAVE_PATH + PokeCoopSave.BACKUP_SUFFIX, SAVE_PATH + PokeCoopSave.JOURNAL_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _saved(species: int, level: int, moves: Array, ot: int) -> Gen2SaveMon:
	var out: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(
		Gen2BattleMon.create(_data, species, level, moves)
	)
	out.ot_id = ot
	return out


func _connect(peer: int, player_id: String) -> PokeCoopClient:
	var link := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, link, peer)
	var client: PokeCoopClient = PokeCoopClient.over(link)
	client.greet("", _data.id, _data.sha1, player_id)
	_clients.append(client)
	_pump()
	return client


func _pump() -> void:
	for _round: int in 4:
		for client: PokeCoopClient in _clients:
			client.poll()
		for link: PokeCoopWorldLink in _links:
			link.advance()
		_host.poll()
	for client: PokeCoopClient in _clients:
		client.poll()


func _window(client: PokeCoopClient) -> PokeCoopWorldLink:
	var state := Gen2WorldState.new()
	state.gen1 = true
	var link: PokeCoopWorldLink = PokeCoopWorldLink.over(client, state, PokeCoopWorldLink.local_save(client, _data), _data)
	_links.append(link)
	_pump()
	return link


func _send(call: Callable) -> void:
	call.call()
	_pump()


func _settle() -> void:
	for _wait: int in PokeCoopWorldLink.PARTY_CHECK_FRAMES:
		_pump()


func _battle_of(client: PokeCoopClient) -> String:
	return String(client.current_battle().get("battle", ""))


func _fight_out(battle_id: String) -> void:
	for _turn: int in 60:
		var controller: PokeCoopClient = null
		for client: PokeCoopClient in _clients:
			if client.is_controller(battle_id):
				controller = client
		if controller == null or String(controller.battle(battle_id).get("outcome", "")) != "":
			return
		controller.act(battle_id, {"type": "move", "slot": 0})
		_pump()


func _blocked(client: PokeCoopClient) -> String:
	return String((client.state.get("saved", {}) as Dictionary).get("blocked", "missing"))


func _saves(client: PokeCoopClient) -> int:
	return int((client.state.get("saved", {}) as Dictionary).get("count", -1))


func test_the_host_says_why_it_would_refuse_a_save() -> void:
	assert_eq(_blocked(_blue), "", "nothing holds a save")
	_send(func() -> void: _red.start_battle("wild:weak"))
	assert_eq(_blocked(_blue), "battle_in_progress", "a partner's battle holds every save")
	assert_eq(_blocked(_red), "battle_in_progress")
	assert_eq(_host.save_checkpoint(), _host.save_blocker(), "the host refuses what it said")

	_fight_out(_battle_of(_red))
	assert_true(_host.battles.is_empty())
	assert_eq(_blocked(_blue), "")
	_host.save_path = ""
	_host.broadcast()
	_pump()
	assert_eq(_blocked(_blue), "no_save_path")


func test_a_window_refuses_its_own_save_with_the_hosts_reason() -> void:
	var blue: PokeCoopWorldLink = _window(_blue)
	assert_eq(blue.save_refusal(), {})
	_send(func() -> void: _red.start_battle("wild:weak"))
	assert_eq(blue.save_refusal(), {"ok": false, "reason": "battle in progress"})
	_fight_out(_battle_of(_red))
	assert_eq(blue.save_refusal(), {})


## pokered's `SaveMenu` over [param link]'s window, its write the one the world's
## START menu has: the gate first, then a snapshot of the live world into the save.
func _gen1_save(link: PokeCoopWorldLink) -> Gen2SavePrompt:
	var write: Callable = func() -> Dictionary:
		var refusal: Dictionary = link.save_refusal()
		if not refusal.is_empty():
			return refusal
		_frame += 1
		var snapshot := Gen2WorldSnapshot.new()
		snapshot.frame_number = _frame
		link.save.world = snapshot
		return {"ok": true}
	var timing: Dictionary = Gen2SavePrompt.TIMINGS[Gen2SavePrompt.Kind.GEN1_MENU]
	var prompt: Gen2SavePrompt = Gen2SavePrompt.open(Gen2SavePrompt.Kind.GEN1_MENU, link.save.player_name, write)
	prompt.frames_elapsed(int(timing["hold"]))
	assert_eq(prompt.lines, Gen2SavePrompt.GEN1_ASK_LINES)
	prompt.text_printed()
	prompt.confirm(true)
	prompt.frames_elapsed(Gen2WorldMenu.ANSWER_HOLD_FRAMES)
	assert_eq(prompt.lines, Gen2SavePrompt.GEN1_SAVING_LINES, "Now saving... goes up either way")
	prompt.text_printed()
	prompt.frames_elapsed(int(timing["result"]))
	return prompt


func test_the_red_save_menu_says_the_save_failed_during_a_partners_battle() -> void:
	var blue: PokeCoopWorldLink = _window(_blue)
	_send(func() -> void: _red.start_battle("wild:weak"))
	var before: Gen2WorldSnapshot = blue.save.world
	var rejected: int = _blue.rejections.size()
	var saves: int = _saves(_blue)

	var prompt: Gen2SavePrompt = _gen1_save(blue)
	assert_eq(prompt.step, Gen2SavePrompt.Step.FAILED, "never SAVED")
	assert_eq(prompt.lines, FAILED_LINES)
	assert_eq(prompt.cursor, -1, "the YES/NO is gone once the answer is in")
	prompt.text_printed()
	prompt.confirm(true)
	assert_true(prompt.refused(), "the failed save ends the way a NO does")
	_settle()
	assert_same(blue.save.world, before, "the window's save was not written")
	assert_eq(blue.save_seq, -1, "no checkpoint was asked for")
	assert_eq(_blue.rejections.size(), rejected, "so the host refused none")
	assert_eq(_saves(_blue), saves)

	_fight_out(_battle_of(_red))
	var saved: Gen2SavePrompt = _gen1_save(blue)
	assert_eq(saved.step, Gen2SavePrompt.Step.SAVED)
	assert_eq(saved.lines, ["BLUE saved", "the game!"])
	_settle()
	assert_ne(blue.save_seq, -1, "the same SAVE after the battle asks for a checkpoint")
	assert_eq(_blue.rejections.size(), rejected, "which the host takes")
	assert_eq(_saves(_blue), saves + 1)
	assert_eq(String(_blue.state["saved"]["by"]), _blue.player_id)


func _open_world() -> void:
	var world_data: GameData = WorldFixture.build(WORLD_GAME)
	_world_screen = (load("res://game/world/world_screen.tscn") as PackedScene).instantiate() as Gen2WorldScreen
	_world_screen.map_group = WorldFixture.MAP_GROUP
	_world_screen.map_number = WorldFixture.MAP_NUMBER
	_world_screen.start_cell = Vector2i(7, 6)
	var world := Gen2WorldAPI.open(
		world_data, WorldFixture.MAP_GROUP, WorldFixture.MAP_NUMBER, Vector2i(7, 6), Gen2WorldState.new()
	)
	var save := Gen2SaveStore.create_development_save(world_data, 0)
	save.world = world.snapshot()
	_world_screen.set_data(world_data)
	_world_screen.set_save(save)
	add_child(_world_screen)
	await get_tree().process_frame


func _print_out(host: Gen2StartMenuScreen) -> void:
	for _step: int in WorldFixture.PRINT_FRAME_CAP:
		if not host._box_up or not host._box.is_revealing():
			return
		host.advance_frame()


func _read_question(host: Gen2StartMenuScreen) -> void:
	for _press: int in QUESTION_PRESS_CAP:
		_print_out(host)
		if not host._box_printing():
			return
		host.handle_button(PokeButton.A)


## SAVE from the START list through Crystal's two questions to the result, as
## test_world_start_menu_screen.gd plays it.
func _save_from_list(host: Gen2StartMenuScreen) -> void:
	var menu: Gen2WorldStartMenu = host.get("_menu")
	for _row: int in menu.size() + 1:
		if menu.selected_kind() == Gen2WorldStartMenu.ITEM_SAVE:
			break
		host.handle_button(PokeButton.DOWN)
	host.handle_button(PokeButton.A)
	assert_eq(host.get("_mode"), Gen2StartMenuScreen.Mode.SAVE_ASK)
	_read_question(host)
	host.handle_button(PokeButton.A)
	host.advance_frames(Gen2WorldMenu.ANSWER_HOLD_FRAMES)
	assert_eq(host.get("_mode"), Gen2StartMenuScreen.Mode.SAVE_OVERWRITE)
	_read_question(host)
	host.handle_button(PokeButton.A)
	host.handle_button(PokeButton.A)
	host.advance_frames(Gen2WorldMenu.ANSWER_HOLD_FRAMES)
	assert_eq(host.get("_mode"), Gen2StartMenuScreen.Mode.SAVE_SAVING)
	_print_out(host)
	host.advance_frames(Gen2StartMenuScreen.SAVE_SAVING_FRAMES + Gen2StartMenuScreen.SAVE_WRITE_FRAMES)


func test_start_save_in_a_window_during_a_battle_ends_in_save_failed() -> void:
	await _open_world()
	var save: Gen2SaveData = _world_screen._injected_save
	var link: PokeCoopWorldLink = PokeCoopWorldLink.over(_blue, Gen2WorldState.new(), save, _data)
	_world_screen.save_gate = link.save_refusal
	_send(func() -> void: _red.start_battle("wild:weak"))
	var before: Gen2WorldSnapshot = save.world

	_world_screen._open_start_menu()
	await get_tree().process_frame
	var host: Gen2StartMenuScreen = _world_screen._start_menu_host
	_save_from_list(host)
	assert_eq(host.get("_mode"), Gen2StartMenuScreen.Mode.SAVE_FAILED, "never SAVE_SAVED")
	assert_eq(host.get("_save_lines"), FAILED_LINES)
	assert_same(save.world, before, "the world was not written to the window's save")
	_print_out(host)
	host.handle_button(PokeButton.A)
	assert_eq(host.get("_mode"), Gen2StartMenuScreen.Mode.LIST, "back to the list, as after a NO")
	link.advance()
	assert_eq(link.save_seq, -1, "no checkpoint was asked for")

	_fight_out(_battle_of(_red))
	_world_screen._world.frame_number = 4321
	_save_from_list(host)
	assert_eq(host.get("_mode"), Gen2StartMenuScreen.Mode.SAVE_SAVED, "free again, the save goes through")
	assert_ne(save.world, before)
	var saves: int = _saves(_blue)
	link.advance()
	_pump()
	assert_ne(link.save_seq, -1)
	assert_eq(_saves(_blue), saves + 1, "and the host wrote the campaign")
