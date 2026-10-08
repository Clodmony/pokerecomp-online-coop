extends SceneTree

## One co-op player's window on the real world screen, the Co-op tab's session, against `tools/coop_session.gd -- host [port] <game>`:
##   Godot --path . -s res://tools/coop_play.gd -- <address> [port] <player_id> [game] [options]
## SELECT opens the session menu. `keys=R,SELECT,A` presses buttons once the world is up (`-` waits a slot, `@THROW.+BLUE`
## picks the panel's first matching row); `capture=<png>@<frames>` writes a PNG outside the project; `opening` plays it.

const KEYS_START_FRAMES: int = 90
const KEY_HOLD_FRAMES: int = 18
const KEYS: Dictionary = {
	"U": PokeButton.UP, "D": PokeButton.DOWN, "L": PokeButton.LEFT, "R": PokeButton.RIGHT,
	"A": PokeButton.A, "B": PokeButton.B, "START": PokeButton.START, "SELECT": PokeButton.SELECT,
	"-": PokeButton.NONE,
}

var _session: PokeCoopSession = null
var _screen: Control = null
var _opening: bool = false
var _player_id: String = ""
var _keys: Array = []
var _captures: Array = []
var _frames: int = 0
var _held: int = PokeButton.NONE


func _initialize() -> void:
	var positional: PackedStringArray = []
	for arg: String in OS.get_cmdline_user_args():
		if not _read_option(arg):
			positional.append(arg)
	if positional.size() < 2:
		push_error("usage: <address> [port] <player_id> [game] [keys=R,A] [capture=<png>@<frames>]")
		quit(2)
		return
	var has_port: bool = positional.size() > 2 and positional[1].is_valid_int()
	var port: int = int(positional[1]) if has_port else PokeCoopEnetTransport.DEFAULT_PORT
	_player_id = positional[2 if has_port else 1]
	var game_at: int = 3 if has_port else 2
	var data: GameData = GameData.open(
		StringName(positional[game_at] if positional.size() > game_at else "red")
	)
	_session = PokeCoopSession.joining(
		data, positional[0], port, _player_id.to_upper(), PokeCoopPolicy.PLAY_OPENING if _opening else 0,
		"" if _opening else _player_id, null, PokeCoopLog.create(PokeCoopLog.sharing())
	)
	if _session == null:
		push_error("coop play: no imported cache for that game, or no connection")
		quit(1)
		return
	Gen2GameRuntime.instance().coop = _session


func _read_option(arg: String) -> bool:
	if arg == "opening":
		_opening = true
		return true
	if arg.begins_with("keys="):
		for key: String in arg.trim_prefix("keys=").split(",", false):
			_keys.append(key.substr(1) if key.begins_with("@") else KEYS.get(key.to_upper(), PokeButton.NONE))
		return true
	if arg.begins_with("capture="):
		var spec: String = arg.trim_prefix("capture=")
		var path: String = spec.get_slice("@", 0)
		if PokeToolPath.refuses(path):
			return true
		_captures.append({"path": path, "frame": int(spec.get_slice("@", 1))})
		return true
	return false


func _process(_delta: float) -> bool:
	if _session == null:
		return false
	if not _session.ended_reason().is_empty():
		print("coop play: session ended (%s)" % _session.ended_reason())
		_session.close()
		quit(0)
		return false
	if _screen == null and _session.is_ready():
		_screen = _session.open_start()
		if not _screen.is_inside_tree():
			root.add_child(_screen)
			current_scene = _screen
		print("coop play: %s opened %s" % [_player_id, _screen.name])
	if _screen != null:
		_frames += 1
		_drive_keys()
		_capture_due()
	return false


func _drive_keys() -> void:
	var at: int = _frames - KEYS_START_FRAMES
	if at < 0 or _keys.is_empty():
		return
	var slot: int = at / KEY_HOLD_FRAMES
	var input: Gen2InputRuntime = Gen2InputRuntime.instance()
	if _held != PokeButton.NONE and at % KEY_HOLD_FRAMES == KEY_HOLD_FRAMES - 2:
		input.release(_held)
		_held = PokeButton.NONE
	elif at % KEY_HOLD_FRAMES == 0 and slot < _keys.size() and (_keys[slot] is String or int(_keys[slot]) != PokeButton.NONE):
		if _keys[slot] is String and not _point_at_row(String(_keys[slot])):
			return
		_held = PokeButton.A if _keys[slot] is String else int(_keys[slot])
		input.press(_held)


func _point_at_row(pattern: String) -> bool:
	var panel: PokeCoopBattlePanel = _session.panel
	var matcher := RegEx.create_from_string(pattern)
	var index: int = -1 if panel == null or not panel.is_open() else panel._rows.find_custom(
		func(row: Dictionary) -> bool: return matcher.search(String(row.get("text", ""))) != null)
	if index >= 0:
		panel._set_cursor(index)
	return index >= 0


func _capture_due() -> void:
	for shot: Dictionary in _captures.duplicate():
		if _frames < int(shot["frame"]):
			continue
		var image: Image = root.get_viewport().get_texture().get_image()
		print("coop play: capture %s %s" % [shot["path"], error_string(image.save_png(shot["path"]))])
		_captures.erase(shot)
