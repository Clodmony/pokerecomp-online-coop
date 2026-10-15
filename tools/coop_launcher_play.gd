extends "res://tools/coop_play.gd"

## The launcher's Co-op tab worked through its own cards, fields and buttons, then the world as coop_play.gd's:
##   Godot --path . -s res://tools/coop_launcher_play.gd -- <address> <port> <player> [game] host|join|partner [name=RED] [starter=0..2] [split[=stacked]]
##     [rival=1..3 (Oak's speech)] [rival_name=<NAME>] [both_versions] [clock=HH:MM[:D] (a new Gold campaign's)] [by_address [untouched]] [round=<frame>[:<TITLE>]]... [tour=<dir>] [keys=] [capture=]; `tour` shoots each screen in both themes, wide and upright; `split` presses Split screen (then Top and bottom with `=stacked`), whose window runs this tool as `partner` with $COOP_SPLIT_ARGS

const LAUNCHER: String = "res://game/main/main.tscn"
const STEP_FRAMES: int = 20
const SHOT_FRAMES: int = 24
const WIDE: Vector2i = Vector2i(1152, 648)
const UPRIGHT: Vector2i = Vector2i(390, 844)
const LOOKS: Array = [[&"light", WIDE], [&"light", UPRIGHT], [&"dark", UPRIGHT], [&"dark", WIDE]]
const NOTCHED: Dictionary = {"left": 0.0, "top": 47.0, "right": 0.0, "bottom": 34.0}

var _role: String = ""
var _game: StringName = &"red"
var _trainer: String = ""
var _address: String = ""
var _port: int = PokeCoopEnetTransport.DEFAULT_PORT
var _starter: int = -1
var _rival: int = -1
var _rival_name: String = ""
var _by_address: bool = false
var _untouched: bool = false
var _both_versions: bool = false
var _split: bool = false
var _layout: String = "Side by side"
var _halves_pressed: int = 0
var _tour: String = ""
var _keys_field: String = ""
var _rounds: Array = []
var _round: int = -1
var _steps: Array = []
var _step_at: int = 0
var _in_world: bool = false
var _look: int = -1
var _look_at: int = 0
var _theme_now: StringName = &"light"
var _shot_name: String = ""
var _shot_reopen: Callable = Callable()


func _initialize() -> void:
	var positional: PackedStringArray = []
	for arg: String in OS.get_cmdline_user_args():
		if not _read_option(arg):
			positional.append(arg)
	if positional.size() < 3 or not _role in ["host", "join", "partner"]:
		push_error("usage: <address> <port> <player> [game] host|join [name=] [starter=] [round=<frame>[:<title>]] [tour=<dir>]")
		quit(2)
		return
	_address = positional[0]
	_port = int(positional[1])
	_player_id = positional[2]
	_game = StringName(positional[3]) if positional.size() > 3 else &"red"
	_trainer = _trainer if not _trainer.is_empty() else _player_id.to_upper()
	PokeCoopPage.host_port = _port
	PokeCoopLobby.beacon_port = _port + 1
	PokeCoopLobby.memory_path = "user://coop_tab_%s.json" % _player_id
	if _split:
		PokeCoopLobby.SplitScreen.tool_args = PackedStringArray(["--max-fps", str(Engine.max_fps), "-s", "res://tools/coop_launcher_play.gd", "--"]) \
			+ OS.get_environment("COOP_SPLIT_ARGS").split(" ", false)
	if _rounds.is_empty():
		_rounds.append({"at": KEYS_START_FRAMES, "campaign": ""})
	var launcher: Node = (load(LAUNCHER) as PackedScene).instantiate()
	root.add_child(launcher)
	current_scene = launcher


func _read_option(arg: String) -> bool:
	var value: String = arg.get_slice("=", 1)
	match arg.get_slice("=", 0):
		"host", "join", "partner":
			_role = arg
		"split":
			_split = true
			_layout = "Top and bottom" if value == "stacked" else _layout
		"name":
			_trainer = value.to_upper()
		"starter":
			_starter = clampi(value.to_int(), 0, PokeCoopPolicy.STARTERS.size() - 1)
		"rival":
			_rival = clampi(value.to_int(), 1, 3)
		"rival_name":
			_rival_name = value.to_upper()
		"by_address":
			_by_address = true
		"untouched":
			_untouched = true
		"both_versions":
			_both_versions = true
		"clock":
			PokeCoopJohto.first_reading = Gen2WorldClock.parse_pin(PackedStringArray([Gen2WorldClock.PIN_ARGUMENT + value]))
		"tour":
			_tour = value if not PokeToolPath.refuses(value) else ""
		"round":
			_rounds.append({"at": value.get_slice(":", 0).to_int(), "campaign": value.get_slice(":", 1).replace("_", " ")})
		_:
			return arg.begins_with(PokeCoopLobby.SplitScreen.ARG) or super(arg)
	return true


func _process(_delta: float) -> bool:
	_frames += 1
	var launcher: Control = current_scene as Control \
		if current_scene != null and current_scene.scene_file_path == LAUNCHER else null
	if launcher == null:
		_drive_keys()
		_note_world()
		_read_speech()
	else:
		_hold_keys()
	_drive_round()
	_capture_due()
	return false


func _hold_keys() -> void:
	if _held != PokeButton.NONE:
		Gen2InputRuntime.instance().release(_held)
		_held = PokeButton.NONE
	if _in_world:
		_in_world = false
		var shell: Gen2LauncherShell = current_scene.get("_shell")
		print("coop launcher: %s back at the launcher, on its %s page%s" % [_player_id, shell.current_page(), _window()])


func _note_world() -> void:
	var session: PokeCoopSession = Gen2GameRuntime.instance().coop
	if _in_world or session == null or not session.is_ready() or current_scene == null:
		return
	_in_world = true
	var me: Dictionary = session.client.me()
	var team: Array = (me.get("team", []) as Array).map(func(mon: Dictionary) -> String:
		return "%s:%d" % [session.data.species(int(mon["species"])).get("name", "?"), int(mon["level"])])
	print("coop launcher: %s round %d in %s (%s) as %s %s, trainer %d, team %s, opening %s, on %s" % [
		_player_id, _round + 1, (session.client.state.get("campaign", {}) as Dictionary).get("title", ""),
		session.client.campaign_id, session.client.player_id, me.get("name", ""), int(me.get("trainer_id", 0)),
		",".join(team), (me.get("opening", {}) as Dictionary).get("stage", "done"), current_scene.name,
	] + _window())


func _window() -> String:
	return ", window at %s" % Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size()) if _split or _role == "partner" else ""


func _read_speech() -> void:
	var session: PokeCoopSession = Gen2GameRuntime.instance().coop
	var intro: Gen2IntroScreen = session.opening_screen if session != null and _rival > 0 else null
	if intro == null or _frames % (KEY_HOLD_FRAMES / 2) != 0 or intro.animation_frames_left() != 0:
		return
	var speech: Control = intro.current()
	if speech != null and speech.has_method(&"choosing_name") and bool(speech.call(&"choosing_name")):
		for _step: int in _rival:
			intro.handle_button(PokeButton.DOWN)
	intro.handle_button(PokeButton.A)
	intro.release_button(PokeButton.A)


func _drive_round() -> void:
	if _look >= 0:
		_shoot_next()
		return
	if _steps.is_empty():
		if _round + 1 >= _rounds.size() or _frames < int(_rounds[_round + 1]["at"]):
			return
		_round += 1
		_steps = _plan(String(_rounds[_round]["campaign"]))
		_step_at = _frames
	if (_frames - _step_at) % STEP_FRAMES != 0:
		return
	var step: Callable = _steps.front()
	if bool(step.call()):
		_steps.pop_front()
		_step_at = _frames


func _plan(campaign: String) -> Array:
	if _role == "partner":
		return [_join_as]
	var plan: Array = [_open_tab, _choose_cartridge]
	if _role == "host":
		plan.append_array([_shot.bind("start"), _press.bind("HOST"), _shot.bind("host"), _host_or_create.bind(campaign)])
		if _split:
			plan.append_array([_until_hosting, _press.bind("Split screen"), _choose_layout, _choose_halves, _shot.bind("split_hosting"), _until_partner])
		plan.append_array(_tour_host() if not _tour.is_empty() else [_until_hosting, _press.bind("Enter the world")])
	else:
		plan.append_array(_tour_join() if not _tour.is_empty() else [_press.bind("JOIN"), _join_host, _join_as])
	return plan


func _tour_host() -> Array:
	return [_until_hosting, _shot.bind("hosting"), _until_partner, _wait.bind(240), _shot.bind("hosting_joined"),
		_press.bind("Stop hosting"), _shot.bind("stop_hosting", _press.bind("Stop hosting")), _press.bind("Stop hosting"),
		_wait.bind(60), _shot.bind("start_last_session"), _open_troubleshooting, _shot.bind("troubleshooting", _open_troubleshooting),
		_press.bind("Close"), _press.bind("HOST"), _shot.bind("host_cards"), _edit_first, _shot.bind("edit_campaign", _edit_first),
		_press.bind("Delete campaign…"), _shot.bind("delete_campaign", _ask_delete), _press.bind("Keep it"), _press.bind("Back"),
		_press.bind("Host again"), _until_partner, _press.bind("Enter the world")]


func _tour_join() -> Array:
	return [_until_heard, _shot.bind("start_nearby"), _press.bind("JOIN"), _shot.bind("join"),
		_open_keys.bind("address"), _shot.bind("keys_address"), _close_keys,
		_type.bind("address", "127.0.0.1:%d" % (_port + 7)), _press.bind("Join"), _shot.bind("connecting"), _wait.bind(260),
		_shot.bind("failure"), _press.bind("Cancel"), _join_host, _until_screen.bind(PokeCoopPage.NEW_PLAYER), _fill_new_player,
		_shot.bind("new_player"), _open_keys.bind("name"), _shot.bind("keys_name"), _close_keys, _press_join_as, _until_world, _until_launcher, _wait.bind(30), _shot.bind("sent_back"),
		_press.bind("HOST"), _shot.bind("host_other_version"), _press.bind("Back"), _press.bind("Join again"), _until_known, _shot.bind("connecting_known"), _join_as]


func _page() -> PokeCoopPage:
	var found: Array = PokeCoopPage._find(current_scene, func(node: Node) -> bool: return node is PokeCoopPage) \
		if current_scene != null else []
	return found[0] if not found.is_empty() else null


func _launcher() -> Control:
	return current_scene as Control if current_scene != null and current_scene.scene_file_path == LAUNCHER else null


func _open_tab() -> bool:
	var shell: Gen2LauncherShell = _launcher().get("_shell") if _launcher() != null else null
	if shell == null:
		return false
	print("coop launcher: %s round %d opens the launcher's %s page" % [_player_id, _round + 1, shell.current_page()])
	for tab: Gen2LauncherButton in shell.tabs():
		if tab.tooltip_text == "Co-op":
			tab.pressed.emit()
	return true


func _until_heard() -> bool:
	return _page() != null and not PokeCoopPage.nearby().is_empty()


func _choose_cartridge() -> bool:
	if _page() == null or not _page().is_visible_in_tree():
		return false
	return _press(PokeCoopLobby.title(_game)) or true


func _buttons(label: String) -> Array:
	var roots: Array = root.get_tree().get_nodes_in_group(Gen2FocusGuard.MODAL_GROUP).filter(func(node: Node) -> bool:
		return node is PokeCoopTabParts.Sheet and (node as Control).is_visible_in_tree())
	roots.append(current_scene)
	for scope: Node in roots:
		var found: Array = PokeCoopPage._find(scope, func(node: Node) -> bool:
			return node is BaseButton and (node as Control).is_visible_in_tree() and not (node as BaseButton).disabled \
				and (node.get_meta("label", "") == label or (node is Gen2LauncherButton and (node as Gen2LauncherButton).text == label)))
		if not found.is_empty():
			return found
	return []


func _press(label: String) -> bool:
	var found: Array = _buttons(label)
	if found.is_empty():
		return false
	print("coop launcher: %s presses %s" % [_player_id, label])
	if found[0] is PokeCoopTabParts.Tile:
		(found[0] as PokeCoopTabParts.Tile).chosen.emit()
	else:
		(found[0] as BaseButton).pressed.emit()
	return true


func _type(field: String, text: String) -> bool:
	var found: Array = PokeCoopPage._find(current_scene, func(node: Node) -> bool:
		return node is LineEdit and node.name == field and (node as Control).is_visible_in_tree())
	if found.is_empty():
		return false
	(found[0] as LineEdit).text = text
	(found[0] as LineEdit).text_changed.emit(text)
	return true


func _open_keys(field: String) -> bool:
	_keys_field = field
	var found: Array = PokeCoopPage._find(current_scene, func(node: Node) -> bool:
		return node is LineEdit and node.name == field and (node as Control).is_visible_in_tree())
	if found.is_empty():
		return false
	if not get_nodes_in_group(Gen2FocusGuard.MODAL_GROUP).any(func(sheet: Node) -> bool: return not sheet.is_queued_for_deletion()):
		(found[0] as LineEdit).grab_focus()
		for down: bool in [true, false]:
			var press := InputEventJoypadButton.new()
			press.button_index = JOY_BUTTON_A
			press.pressed = down
			root.push_input(press)
	return true


func _close_keys() -> bool:
	_keys_field = ""
	return _press("Done")


func _wait(frames: int) -> bool:
	return _frames - _step_at >= frames


func _until_screen(screen: StringName) -> bool:
	return _page() != null and _page().screen() == screen


func _host_or_create(campaign: String) -> bool:
	if not campaign.is_empty() and _press(campaign):
		print("coop launcher: %s picks %s" % [_player_id, campaign])
		_steps.insert(1, _press.bind("Host %s" % campaign))
		_steps.insert(2, _new_player_if_asked.bind("Host"))
		return true
	if not _press("+ New campaign"):
		return false
	_steps.insert(1, _fill_new_campaign.bind(campaign))
	_steps.insert(2, _shot.bind("new_campaign"))
	_steps.insert(3, _press.bind("Create and host"))
	return true


func _fill_new_campaign(campaign: String) -> bool:
	if not campaign.is_empty():
		_type("title", campaign)
	if not _rival_name.is_empty():
		_type("rival", _rival_name)
	_type("name", _trainer)
	_choose_start()
	if _both_versions:
		_press("Wild Pokémon from both versions")
	return true


func _choose_start() -> void:
	if _starter < 0:
		return
	var data: GameData = GameData.open(_game)
	_press(PokeCoopPage.start_label(data))
	_press(String(data.species(PokeCoopPolicy.starters(data)[_starter]).get("name", "")) if data != null else "")


func _new_player_if_asked(verb: String) -> bool:
	if not _until_screen(PokeCoopPage.NEW_PLAYER):
		return true
	_fill_new_player()
	_steps.insert(1, _press.bind("%s as %s" % [verb, _trainer]))
	return true


func _fill_new_player() -> bool:
	_type("name", _trainer)
	_choose_start()
	return true


func _until_hosting() -> bool:
	return _until_screen(PokeCoopPage.HOSTING)


func _finalize() -> void:
	print("coop launcher: %s quits at frame %d" % [_player_id, _frames])


func _choose_layout() -> bool:
	if not _captures.is_empty():
		root.get_viewport().get_texture().get_image().save_png(String(_captures[0]["path"]).get_base_dir() + "/split_layout.png")
	return _press(_layout)


func _choose_halves() -> bool:
	if not get_nodes_in_group(Gen2FocusGuard.MODAL_GROUP).any(func(sheet: Node) -> bool:
			return sheet is PokeCoopTabParts.Sheet and (sheet as PokeCoopTabParts.Sheet).listens and not sheet.is_queued_for_deletion()):
		return _halves_pressed > 0 or _frames - _step_at > 180
	if _halves_pressed == 0 and not _captures.is_empty():
		root.get_viewport().get_texture().get_image().save_png(String(_captures[0]["path"]).get_base_dir() + "/who_plays_where.png")
	var press: InputEvent = InputEventKey.new()
	(press as InputEventKey).physical_keycode = KEY_ENTER
	if _halves_pressed > 0:
		press = InputEventJoypadButton.new()
		(press as InputEventJoypadButton).button_index = JOY_BUTTON_A
		var pads: Array = PokePadChoice.connected()
		if pads.is_empty():
			return false
		press.device = int(pads[(_halves_pressed - 1) % pads.size()]["device"])
	press.set("pressed", true)
	print("coop launcher: %s chooses a half with %s on device %d" % [_player_id, press.as_text(), press.device])
	_halves_pressed += 1
	root.push_input(press)
	return false


func _until_partner() -> bool:
	var session: PokeCoopSession = Gen2GameRuntime.instance().coop
	return session != null and session.host != null and session.host.players.values().any(func(member: PokeCoopPlayer) -> bool:
		return member.connected and member.player_id != session.client.player_id)


func _join_host() -> bool:
	if not _by_address and _press("Join with %s" % PokeCoopLobby.short_title(_game)):
		return true
	if _frames - _step_at < 240 and not _by_address:
		return false
	if _untouched and _round > 0:
		var field: Array = PokeCoopPage._find(current_scene, func(node: Node) -> bool:
			return node is LineEdit and node.name == "address" and (node as Control).is_visible_in_tree())
		if field.is_empty():
			return false
		print("coop launcher: %s joins with the address field untouched, showing \"%s\"" % [_player_id, (field[0] as LineEdit).text])
		return _press("Join")
	return _type("address", "%s:%d" % [_address, _port]) and _press("Join")


func _join_as() -> bool:
	if _until_screen(PokeCoopPage.NEW_PLAYER):
		_fill_new_player()
		_steps.insert(1, _press_join_as)
		return true
	var known: Array = _buttons("Join as %s" % _trainer) + PokeCoopPage._find(root, func(node: Node) -> bool:
		return node is Gen2LauncherButton and (node as Gen2LauncherButton).text.begins_with("Join as ") and (node as Control).is_visible_in_tree())
	if known.is_empty():
		return false
	print("coop launcher: %s presses %s" % [_player_id, (known[0] as Gen2LauncherButton).text])
	(known[0] as BaseButton).pressed.emit()
	return true


func _press_join_as() -> bool:
	return _press("Join as %s" % _trainer)


func _until_known() -> bool:
	return PokeCoopPage._find(root, func(node: Node) -> bool:
		return node is Gen2LauncherButton and (node as Gen2LauncherButton).text.begins_with("Join as ") and (node as Control).is_visible_in_tree()).size() > 0


func _until_world() -> bool:
	return _launcher() == null


func _until_launcher() -> bool:
	return _launcher() != null and _page() != null


func _open_troubleshooting() -> bool:
	for entry: Dictionary in _page().hints() if _page() != null else []:
		if entry["action"] == &"ui_menu":
			(entry["run"] as Callable).call()
			return true
	return false


func _edit_first() -> bool:
	var cards: Array = PokeCoopPage._find(current_scene, func(node: Node) -> bool:
		return node is PokeCoopTabParts.Tile and node.has_meta("campaign"))
	if cards.is_empty():
		return false
	(cards[0] as PokeCoopTabParts.Tile).secondary.emit()
	return true


func _ask_delete() -> bool:
	return _edit_first() and _press("Delete campaign…")


func _shot(name: String, reopen: Callable = Callable()) -> bool:
	if _tour.is_empty():
		return true
	_look = 0
	_shot_name = name
	_shot_reopen = reopen
	_apply_look(0)
	return true


func _shoot_next() -> void:
	if _frames - _look_at < SHOT_FRAMES:
		return
	var look: Array = LOOKS[_look]
	var path: String = "%s/%s_%s_%s.png" % [_tour, _shot_name, look[0], "wide" if look[1] == WIDE else "upright"]
	var image: Image = root.get_viewport().get_texture().get_image()
	print("coop launcher: %s tour %s %s" % [_player_id, path.get_file(), error_string(image.save_png(path))])
	_look += 1
	if _look >= LOOKS.size():
		_look = -1
		_apply_look(-1)
		_step_at = _frames
		return
	_apply_look(_look)


func _apply_look(index: int) -> void:
	var look: Array = LOOKS[index] if index >= 0 else [&"light", WIDE]
	Gen2LauncherUI.preview_insets = NOTCHED if look[1] == UPRIGHT else {}
	DisplayServer.window_set_size(look[1])
	root.set_content_scale_size(look[1])
	root.size = look[1]
	if look[0] != _theme_now and _launcher() != null:
		_theme_now = look[0]
		_launcher().call(&"preview_theme", look[0])
		_launcher().call(&"select_page", &"coop")
		if _shot_reopen.is_valid():
			_shot_reopen.call_deferred()
	if not _keys_field.is_empty():
		_open_keys.call_deferred(_keys_field)
	_look_at = _frames
