extends "res://tools/coop_play.gd"

## The launcher's Co-op tab worked through its own tab, rows, fields and buttons, then the world as coop_play.gd's:
##   Godot --path . -s res://tools/coop_launcher_play.gd -- <address> <port> <player> [game] host|join [name=RED] [starter=0..2]
##     [rival=1..3 (reads Oak's speech)] [round=<frame>[:<NEW_TITLE>]]... [keys=] [capture=]; frames count from launch.

const LAUNCHER: String = "res://game/main/main.tscn"
const STEP_FRAMES: int = 30
const OPENING_ROW: String = "The opening, if you are new to the campaign"

var _role: String = ""
var _trainer: String = ""
var _address: String = ""
var _port: int = PokeCoopEnetTransport.DEFAULT_PORT
var _starter: int = -1
var _rival: int = -1
var _rounds: Array = []
var _round: int = -1
var _round_at: int = 0
var _steps: Array = []
var _sheet_pick: String = ""
var _in_world: bool = false


func _initialize() -> void:
	var positional: PackedStringArray = []
	for arg: String in OS.get_cmdline_user_args():
		if not _read_option(arg):
			positional.append(arg)
	if positional.size() < 3 or not _role in ["host", "join"]:
		push_error("usage: <address> <port> <player> [game] host|join [name=] [starter=] [round=<frame>[:<title>]]")
		quit(2)
		return
	_address = positional[0]
	_port = int(positional[1])
	_player_id = positional[2]
	_trainer = _trainer if not _trainer.is_empty() else _player_id.to_upper()
	if _rounds.is_empty():
		_rounds.append({"at": KEYS_START_FRAMES, "campaign": ""})
	var launcher: Node = (load(LAUNCHER) as PackedScene).instantiate()
	root.add_child(launcher)
	current_scene = launcher


func _read_option(arg: String) -> bool:
	if arg in ["host", "join"]:
		_role = arg
	elif arg.begins_with("name="):
		_trainer = arg.trim_prefix("name=").to_upper()
	elif arg.begins_with("starter="):
		_starter = clampi(arg.trim_prefix("starter=").to_int(), 0, PokeCoopPage.STARTER_NAMES.size() - 1)
	elif arg.begins_with("rival="):
		_rival = clampi(arg.trim_prefix("rival=").to_int(), 1, 3)
	elif arg.begins_with("round="):
		var spec: String = arg.trim_prefix("round=")
		_rounds.append({"at": spec.get_slice(":", 0).to_int(), "campaign": spec.get_slice(":", 1).replace("_", " ")})
	else:
		return super(arg)
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
		_drive_round(launcher)
	_capture_due()
	return false


func _hold_keys() -> void:
	if _held != PokeButton.NONE:
		Gen2InputRuntime.instance().release(_held)
		_held = PokeButton.NONE
	var at: int = _frames - KEYS_START_FRAMES
	if at >= 0 and at % KEY_HOLD_FRAMES == 0 and at / KEY_HOLD_FRAMES < _keys.size() \
			and int(_keys[at / KEY_HOLD_FRAMES]) != PokeButton.NONE:
		print("coop launcher: %s dropped key slot %d at the launcher" % [_player_id, at / KEY_HOLD_FRAMES])
	if _in_world:
		_in_world = false
		var shell: Gen2LauncherShell = current_scene.get("_shell")
		print("coop launcher: %s back at the launcher, on its %s page" % [_player_id, shell.current_page()])


func _note_world() -> void:
	var session: PokeCoopSession = Gen2GameRuntime.instance().coop
	if _in_world or session == null or not session.is_ready() or current_scene == null:
		return
	_in_world = true
	_steps.clear()
	var me: Dictionary = session.client.me()
	var team: Array = (me.get("team", []) as Array).map(func(mon: Dictionary) -> String:
		return "%s:%d" % [session.data.species(int(mon["species"])).get("name", "?"), int(mon["level"])])
	print("coop launcher: %s round %d in %s (%s) as %s %s, trainer %d, team %s, opening %s, on %s" % [
		_player_id, _round + 1, (session.client.state.get("campaign", {}) as Dictionary).get("title", ""),
		session.client.campaign_id, session.client.player_id, me.get("name", ""), int(me.get("trainer_id", 0)),
		",".join(team), (me.get("opening", {}) as Dictionary).get("stage", "done"), current_scene.name,
	])


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


func _drive_round(launcher: Control) -> void:
	if _steps.is_empty():
		if _round + 1 >= _rounds.size() or _frames < int(_rounds[_round + 1]["at"]):
			return
		_round += 1
		_round_at = _frames
		_steps = _plan(launcher, String(_rounds[_round]["campaign"]))
	if (_frames - _round_at) % STEP_FRAMES == 0:
		var step: Variant = _steps.pop_front()
		if step is Callable:
			(step as Callable).call()


func _plan(launcher: Control, campaign: String) -> Array:
	var plan: Array = [_open_tab.bind(launcher), _type.bind(&"_name", _trainer)]
	if _starter >= 0:
		plan.append_array([_choose.bind(OPENING_ROW, PokeCoopPage.OPENINGS[1]), _pick,
			_choose.bind("Starter", PokeCoopPage.STARTER_NAMES[_starter]), _pick])
	else:
		plan.append_array([null, null, null, null])
	if _role == "host":
		plan.append_array([_choose.bind("Campaign", campaign), _pick, _name_campaign.bind(campaign)])
	else:
		plan.append_array([_type.bind(&"_address", _address), null, null])
	plan.append_array([_press, _status])
	return plan


func _open_tab(launcher: Control) -> void:
	var shell: Gen2LauncherShell = launcher.get("_shell")
	print("coop launcher: %s round %d opens the launcher's %s page" % [_player_id, _round + 1, shell.current_page()])
	for tab: Gen2LauncherButton in shell.tabs():
		if tab.tooltip_text == "Co-op":
			tab.pressed.emit()


func _page() -> PokeCoopPage:
	var found: Array = _find(current_scene, func(node: Node) -> bool: return node is PokeCoopPage)
	return found[0] if not found.is_empty() else null


func _type(field: StringName, text: String) -> void:
	var edit: LineEdit = _page().get(field)
	if not edit.is_visible_in_tree() or not edit.editable:
		print("coop launcher: %s cannot reach the field %s" % [_player_id, edit.placeholder_text])
	edit.text = text
	edit.text_changed.emit(text)


func _choose(label: String, wanted: String) -> void:
	_sheet_pick = ""
	var rows: Array = _find(_page(), func(node: Node) -> bool:
		return node is Gen2LauncherUI.SettingRow and node.get("_name").text == label)
	if rows.is_empty():
		print("coop launcher: %s finds no %s row" % [_player_id, label])
		return
	var row: Gen2LauncherUI.SettingRow = rows[0]
	var choices: Array = row.get("_choices")
	var matching: Array = choices.filter(func(text: String) -> bool: return text == wanted or text.begins_with(wanted + ":"))
	var target: String = String(matching[0] if not matching.is_empty() else choices[0])
	print("coop launcher: %s %s shows \"%s\"%s" % [_player_id, label, row.value_text(),
		"" if row.value_text() == target else ", choosing \"%s\"" % target])
	if row.value_text() != target:
		_sheet_pick = target
		row.pressed.emit()


func _pick() -> void:
	var sheets: Array = current_scene.get_children().filter(func(node: Node) -> bool: return node is Gen2LauncherSheet)
	if _sheet_pick.is_empty() or sheets.is_empty():
		return
	var picks: Array = _find(sheets.back(), func(node: Node) -> bool:
		return node is Gen2LauncherButton and node.text == _sheet_pick)
	if picks.is_empty():
		print("coop launcher: %s's list has no \"%s\"" % [_player_id, _sheet_pick])
		return
	(picks[0] as Gen2LauncherButton).pressed.emit()


func _name_campaign(campaign: String) -> void:
	var title: LineEdit = _page().get(&"_title")
	if title.is_visible_in_tree():
		_type(&"_title", campaign)


func _press() -> void:
	var page: PokeCoopPage = _page()
	var label: String = "Host" if _role == "host" else "Join"
	var buttons: Array = _find(page, func(node: Node) -> bool: return node is Gen2LauncherButton and node.text == label)
	var button: Gen2LauncherButton = buttons[0]
	print("coop launcher: %s presses %s%s" % [_player_id, label,
		"" if button.is_visible_in_tree() and not button.disabled else ", which a player cannot reach"])
	if _port == PokeCoopEnetTransport.DEFAULT_PORT:
		button.pressed.emit()
	elif _role == "host":
		page.host_campaign(_port)
	else:
		page.join_campaign((page.get(&"_address") as LineEdit).text.strip_edges(), _port)


func _status() -> void:
	print("coop launcher: %s's tab says \"%s\"" % [_player_id, (_page().get(&"_status") as Label).text])


static func _find(node: Node, wanted: Callable) -> Array:
	var out: Array = []
	for child: Node in (node.get_children() if node != null else []):
		if wanted.call(child):
			out.append(child)
		out.append_array(_find(child, wanted))
	return out
