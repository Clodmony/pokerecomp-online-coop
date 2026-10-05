extends SceneTree

## One co-op player's window on the real world screen, against a host started
## with `tools/coop_session.gd -- host [port] <game>` and a locally imported cartridge:
##   Godot --path . -s res://tools/coop_play.gd -- <address> [port] <player_id> [game] [options]
## SELECT opens the session menu. `keys=R,R,SELECT,A` presses buttons once the
## world is up, `-` waiting a slot; `capture=<png>@<frames>` writes the window to a
## PNG outside the project.

const KEYS_START_FRAMES: int = 90
const KEY_HOLD_FRAMES: int = 18
const LOCAL_ACTOR: StringName = &"coop_players"
const KEYS: Dictionary = {
	"U": PokeButton.UP, "D": PokeButton.DOWN, "L": PokeButton.LEFT, "R": PokeButton.RIGHT,
	"A": PokeButton.A, "B": PokeButton.B, "START": PokeButton.START, "SELECT": PokeButton.SELECT,
	"-": PokeButton.NONE,
}

var _client: PokeCoopClient = null
var _data: GameData = null
var _screen: Gen2WorldScreen = null
var _panel: PokeCoopBattlePanel = null
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
	_data = GameData.open(StringName(positional[game_at] if positional.size() > game_at else "red"))
	var link: PokeCoopEnetTransport = PokeCoopEnetTransport.dial(positional[0], port)
	if _data == null or link == null:
		push_error("coop play: no imported cache for that game, or no connection")
		quit(1)
		return
	_client = PokeCoopClient.over(link)
	_client.greet(_player_id, _data.id, _data.sha1, _player_id)


func _read_option(arg: String) -> bool:
	if arg.begins_with("keys="):
		for key: String in arg.trim_prefix("keys=").split(",", false):
			_keys.append(KEYS.get(key.to_upper(), PokeButton.NONE))
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
	if _client == null:
		return false
	_client.poll()
	if not _client.ended_reason.is_empty():
		print("coop play: session ended (%s)" % _client.ended_reason)
		quit(0)
		return false
	if _screen == null and not _client.me().is_empty():
		_launch()
	if _screen != null:
		_frames += 1
		_hold_world_under_panel()
		_drive_keys()
		_capture_due()
	return false


## The world walks on held directions, not only on press events, so it stands
## still for as long as the panel is open rather than relying on the panel
## swallowing presses.
func _hold_world_under_panel() -> void:
	var mode: Node.ProcessMode = Node.PROCESS_MODE_DISABLED if _panel.is_open() \
		else Node.PROCESS_MODE_INHERIT
	if _screen.process_mode != mode:
		_screen.process_mode = mode


func _launch() -> void:
	var view: Dictionary = (_client.state.get("players", {}) as Dictionary).get(_player_id, {})
	var save: Gen2SaveData = _local_save(_client.me())
	Gen2ModHost.instance().register_world_actor(LOCAL_ACTOR, PokeCoopRemoteActor.over(_client))
	_screen = (load("res://game/world/world_screen.tscn") as PackedScene).instantiate() as Gen2WorldScreen
	var map: Vector2i = view.get("map", Vector2i.ZERO)
	_screen.map_group = map.x
	_screen.map_number = map.y
	_screen.start_cell = view.get("cell", Vector2i.ZERO)
	_screen.set_data(_data)
	_screen.set_save(save)
	Gen2ModHost.instance().created_save(save)
	Gen2ModHost.instance().activate_save(save)
	root.add_child(_screen)
	current_scene = _screen
	var world: Gen2WorldAPI = _screen.get("_world")
	if world != null:
		world.state.set_wild_encounters_off(true)
		world.state.set_trainer_sightings_off(true)
	var layer := CanvasLayer.new()
	layer.layer = 20
	root.add_child(layer)
	_panel = PokeCoopBattlePanel.over(_client, _data)
	layer.add_child(_panel)
	print("coop play: %s on map %s at %s" % [_player_id, map, view.get("cell")])


## The world screen explores on a save of its own, built from this player's
## record; the host's copy stays the one that counts.
func _local_save(me: Dictionary) -> Gen2SaveData:
	var save := Gen2SaveData.new()
	save.game_id = _data.id
	save.rom_sha1 = _data.sha1
	save.player_name = String(me.get("name", _player_id))
	save.player_id = int(me.get("trainer_id", 0))
	save.run_rules = Gen2Rules.new()
	for row: Dictionary in me.get("party", []):
		var mon: Gen2SaveMon = Gen2SaveMon.from_dict(row["mon"])
		if mon != null:
			save.party.append(mon)
	return save


func _drive_keys() -> void:
	var at: int = _frames - KEYS_START_FRAMES
	if at < 0 or _keys.is_empty():
		return
	var slot: int = at / KEY_HOLD_FRAMES
	var input: Gen2InputRuntime = Gen2InputRuntime.instance()
	if _held != PokeButton.NONE and at % KEY_HOLD_FRAMES == KEY_HOLD_FRAMES - 2:
		input.release(_held)
		_held = PokeButton.NONE
	elif at % KEY_HOLD_FRAMES == 0 and slot < _keys.size() and int(_keys[slot]) != PokeButton.NONE:
		_held = int(_keys[slot])
		input.press(_held)


func _capture_due() -> void:
	for shot: Dictionary in _captures.duplicate():
		if _frames < int(shot["frame"]):
			continue
		var image: Image = root.get_viewport().get_texture().get_image()
		print("coop play: capture %s %s" % [shot["path"], error_string(image.save_png(shot["path"]))])
		_captures.erase(shot)
