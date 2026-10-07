extends "res://tools/coop_play.gd"

## A co-op window that plays itself to BROCK's badge with `tools/checks/played.gd`'s legs, fighting from the panel:
##   Godot --path . -s res://tools/coop_autoplay.gd -- <address> [port] <player_id> [game] [opening]
##     [route=brock] [speed=1..4] [ball=0..2] [shots=<dir>]; prints "autoplay: <player> finished" or "FAILED".

const PLAYED: String = "res://tools/checks/played.gd"
const CHECK_RUN: String = "res://tools/lib/check_run.gd"
const TAP_FRAMES: int = 4
const TAP_EVERY: int = 8
const LEG_SECONDS: float = 420.0
const STILL_SECONDS: float = 150.0
const BROCK := Vector2i(4, 1)
const BOULDER_BADGE: int = 0
const CASCADE_BADGE: int = 1
const UP: int = Gen2WorldSprite.FACING_UP
const ROUTES: Dictionary = {"brock": [], "misty": [&"_misty_legs"], "surge": [&"_misty_legs", &"_surge_legs"]}
const SURGE_MAPS: Dictionary = {
	&"route_24": Vector2i(0, 35), &"route_25": Vector2i(0, 36), &"bills_house": Vector2i(0, 88),
	&"trashed_house": Vector2i(0, 62), &"route_5": Vector2i(0, 16), &"underground_route_5": Vector2i(0, 71),
	&"underground_path": Vector2i(0, 119), &"underground_route_6": Vector2i(0, 74), &"route_6": Vector2i(0, 17),
	&"vermilion_city": Vector2i(0, 5), &"vermilion_dock": Vector2i(0, 94), &"ss_anne_1f": Vector2i(0, 95),
	&"ss_anne_2f": Vector2i(0, 96), &"captains_room": Vector2i(0, 101), &"vermilion_gym": Vector2i(0, 92),
}
const BILL_POKEMON := Vector2i(6, 5)
const BILLS_PC_FRONT := Vector2i(1, 5)
const BILL := Vector2i(4, 4)
const TRASHED_HOUSE_HOLE := Vector2i(3, 0)
const CAPTAIN := Vector2i(4, 2)
const GYM_TREE := Vector2i(15, 18)
const GYM_TREE_FRONT := Vector2i(15, 17)
const LT_SURGE := Vector2i(5, 1)
const FIRST_TRASH_CAN := Vector2i(1, 7)
const TRASH_CANS_PER_COLUMN: int = 3
const TRASH_CAN_SPACING: int = 2
const THUNDER_BADGE: int = 2
const EVENT_BILL_SAID_USE_CELL_SEPARATOR: int = 0x55E
const EVENT_USED_CELL_SEPARATOR_ON_BILL: int = 0x55B
const EVENT_GOT_SS_TICKET: int = 0x55C
const EVENT_GOT_HM01: int = 0x5E0
const S_S_TICKET: int = 0x3F
const SURGE_LEVEL: int = 30
const SANDSHREW_DEX: int = 27

var _played: Variant = null
var _kit: GDScript = null
var _route: String = "brock"
var _speed: float = 1.0
var _ball: int = 0
var _shots: String = ""
var _legs: Array = []
var _leg: int = 0
var _leg_started: int = 0
var _still_since: int = 0
var _signature: String = ""
var _tap: int = PokeButton.NONE
var _tap_at: int = -TAP_EVERY
var _direction: int = PokeButton.NONE
var _done: bool = false


func _read_option(arg: String) -> bool:
	for option: String in ["route=", "speed=", "ball=", "shots="]:
		if arg.begins_with(option):
			var value: String = arg.trim_prefix(option)
			match option:
				"route=": _route = value
				"speed=": _speed = clampf(value.to_float(), 1.0, float(Gen2WorldAnimation.MAX_CATCHUP_FRAMES))
				"ball=": _ball = clampi(value.to_int(), 0, 2)
				"shots=": _shots = value if not PokeToolPath.refuses(value) else ""
			return true
	return super(arg)


func _process(delta: float) -> bool:
	super(delta)
	if _session == null or _done or not _session.is_ready():
		return false
	Engine.time_scale = _speed
	if _played == null:
		_kit = load(PLAYED)
		_played = _kit.new()
		_played._r = (load(CHECK_RUN) as GDScript).new()
		_played._r.data = _session.data
		_played._r.game_id = _session.data.id
	_played._frames = _frames
	_apply(_choose())
	_watch_progress()
	return false


func _choose() -> int:
	if _session.opening_screen != null:
		if _frames - _tap_at == TAP_FRAMES:
			_session.opening_screen.release_button(PokeButton.A)
		var press: int = _intro_button(_session.opening_screen)
		if press != PokeButton.NONE:
			_session.opening_screen.handle_button(press)
			_tap_at = _frames
		return PokeButton.NONE
	var screen: Gen2WorldScreen = _session.screen
	if screen == null or not is_instance_valid(screen) or screen.world() == null or _session.panel == null:
		return PokeButton.NONE
	if _session.panel.is_open():
		return _panel_button(_session.panel)
	if _played._screen != screen:
		_played._screen = screen
		_played._editor = Gen2SaveEditor.new()
		_played._editor.data = _session.data
		_legs = _route_legs()
		_leg_started = Time.get_ticks_msec()
	_played._editor.save = screen.active_save()
	return _leg_button(screen)


func _intro_button(intro: Gen2IntroScreen) -> int:
	if intro.animation_frames_left() != 0 or _paced(PokeButton.A) == PokeButton.NONE:
		return PokeButton.NONE
	var screen: Control = intro.current()
	if screen != null and screen.has_method(&"choosing_name") and bool(screen.call(&"choosing_name")):
		intro.handle_button(PokeButton.DOWN)
	return PokeButton.A


func _panel_button(panel: PokeCoopBattlePanel) -> int:
	var view: Dictionary = panel.battle_view()
	if view.is_empty():
		return _paced(PokeButton.B)
	if panel.busy.is_valid() and bool(panel.busy.call()):
		return PokeButton.NONE
	if not String(view.get("outcome", "")).is_empty():
		return _paced(PokeButton.A)
	var target: int = -1
	if bool(view.get("stand_in_due", false)):
		target = panel._rows.find_custom(func(row: Dictionary) -> bool: return row.get("session") == "stand_in")
	elif panel._controls(view):
		target = _target_row(view, panel._rows)
	if target < 0:
		return PokeButton.NONE
	return _paced(PokeButton.DOWN if panel._cursor != target else PokeButton.A)


func _target_row(view: Dictionary, rows: Array) -> int:
	var wanted: String = {"send_out": "send_out", "learn": "decline", "mimic": "mimic"}.get(String(view.get("phase", "")), "move")
	var active: Dictionary = {}
	for ally: Dictionary in view.get("allies", []):
		if int(ally["index"]) == int(view["active"]):
			active = ally
	var best: int = -1
	var best_power: int = -1
	for index: int in rows.size():
		var command: Dictionary = (rows[index] as Dictionary).get("command", {})
		if String(command.get("type", "")) != wanted:
			continue
		if wanted != "move":
			return index
		var slot: int = int(command["slot"])
		var power: int = int(_session.data.move(int(active["moves"][slot])).get("power", 0)) \
			if int((active.get("pp", []) as Array)[slot]) > 0 else -1
		if power > best_power:
			best_power = power
			best = index
	return best


func _leg_button(screen: Gen2WorldScreen) -> int:
	while _leg < _legs.size() and _legs[_leg] is Callable:
		if not bool((_legs[_leg] as Callable).call()):
			return _fail("step %d refused" % _leg)
		_leg += 1
	if _leg >= _legs.size():
		_finish_route()
		return PokeButton.NONE
	var row: Array = _legs[_leg]
	if _played._idle() and bool((row[2] as Callable).call(screen.world())):
		print("coop autoplay: %s leg %-24s %.0f s, map %s cell %s" % [
			_player_id, row[0], _seconds_since(_leg_started), screen.world().map_id(), screen.world().player_cell])
		_shot("%02d_%s" % [_leg, row[0]])
		_leg += 1
		_leg_started = Time.get_ticks_msec()
		return PokeButton.NONE
	if _seconds_since(_leg_started) > LEG_SECONDS:
		return _fail("%s took longer than %d s: %s" % [row[0], LEG_SECONDS, _played._where()])
	return _played._button_for(row[1])


func _route_legs() -> Array:
	var legs: Array = _opening_legs() + _brock_legs()
	for stretch: StringName in ROUTES.get(_route, []):
		legs += call(stretch)
	return legs


func _opening_legs() -> Array:
	var p: Variant = _played
	var game: StringName = _session.data.id
	if String((_session.client.me().get("opening", {}) as Dictionary).get("stage", "")).is_empty():
		return []
	return [
		["bedroom_to_1f", p._warp_to(_kit.REDS_HOUSE_1F), p._on_map(_kit.REDS_HOUSE_1F)],
		["house_to_pallet", p._warp_to(_kit.PALLET_TOWN), p._on_map(_kit.PALLET_TOWN)],
		["north_path_to_lab", p._walk(_kit.PALLET_NORTH_PATH[game]), p._on_map(_kit.OAKS_LAB)],
		["starter", p._talk(_kit.LAB_STARTER_BALLS[game] + Vector2i(_ball, 0), UP), p._flag(_kit.EVENT_GOT_STARTER)],
		["rival_and_out", p._warp_to(_kit.PALLET_TOWN), p._on_map(_kit.PALLET_TOWN)],
	]


func _brock_legs() -> Array:
	var p: Variant = _played
	var pokedex: Callable = p._flag(_kit.EVENT_GOT_POKEDEX)
	return [
		_grind.bind(_kit.ROUTE_1_LEVEL, 0),
		["parcel", p._fetch(_kit.OAKS_PARCEL), _either(p._holds(_kit.OAKS_PARCEL), pokedex)],
		["parcel_to_lab", p._route(_kit.OAKS_LAB), p._on_map(_kit.OAKS_LAB)],
		["pokedex", p._talk(_kit.LAB_BELOW_OAK, UP), pokedex],
		["lab_out", p._warp_to(_kit.PALLET_TOWN), p._on_map(_kit.PALLET_TOWN)],
		["pallet_to_route_1", p._cross(Vector2i.UP, _kit.ROUTE_1), p._on_map(_kit.ROUTE_1)],
		["route_1_to_viridian", p._cross(Vector2i.UP, _kit.VIRIDIAN_CITY), p._on_map(_kit.VIRIDIAN_CITY)],
		_grind.bind(_kit.FOREST_LEVEL, 0),
		["viridian_to_route_2", p._cross(Vector2i.UP, _kit.ROUTE_2), p._on_map(_kit.ROUTE_2)],
		["route_2_to_south_gate", p._warp_to(_kit.VIRIDIAN_FOREST_SOUTH_GATE), p._on_map(_kit.VIRIDIAN_FOREST_SOUTH_GATE)],
		["south_gate_to_forest", p._warp_to(_kit.VIRIDIAN_FOREST), p._on_map(_kit.VIRIDIAN_FOREST)],
		["forest_to_north_gate", p._warp_to(_kit.VIRIDIAN_FOREST_NORTH_GATE), p._on_map(_kit.VIRIDIAN_FOREST_NORTH_GATE)],
		["north_gate_to_route_2", p._warp_to(_kit.ROUTE_2), p._on_map(_kit.ROUTE_2)],
		["route_2_to_pewter", p._cross(Vector2i.UP, _kit.PEWTER_CITY), p._on_map(_kit.PEWTER_CITY)],
		_grind.bind(_kit.BROCK_LEVEL, _kit.MANKEY_DEX),
		["pewter_gym", p._warp_to(_kit.PEWTER_GYM), p._on_map(_kit.PEWTER_GYM)],
		_meet_partner("meet_in_pewter_gym", p._flag(_kit.EVENT_BEAT_BROCK)),
		["brock", p._talk_to(BROCK), p._flag(_kit.EVENT_BEAT_BROCK)],
		["boulder_badge", _standing, _badge(BOULDER_BADGE)],
	]


func _misty_legs() -> Array:
	var p: Variant = _played
	var fossil: Callable = p._flag(_kit.EVENT_GOT_DOME_FOSSIL[_session.data.id])
	return [
		["gym_out", p._warp_to(_kit.PEWTER_CITY), p._on_map(_kit.PEWTER_CITY)],
		["pewter_to_route_3", p._cross(Vector2i.RIGHT, _kit.ROUTE_3), p._on_map(_kit.ROUTE_3)],
		["route_3_to_route_4", p._cross(Vector2i.UP, _kit.ROUTE_4), p._on_map(_kit.ROUTE_4)],
		_grind.bind(_kit.MT_MOON_LEVEL, 0),
		["route_4_to_mt_moon", p._warp_to(_kit.MT_MOON_1F), p._on_map(_kit.MT_MOON_1F)],
		["mt_moon_1f_to_b1f", p._walk(_kit.MT_MOON_1F_LADDER), p._on_map(_kit.MT_MOON_B1F)],
		["mt_moon_b1f_to_b2f", p._warp_to(_kit.MT_MOON_B2F), p._on_map(_kit.MT_MOON_B2F)],
		["super_nerd", p._walk(_kit.MT_MOON_NERD_CELL), _either(p._at(_kit.MT_MOON_NERD_CELL), fossil)],
		["dome_fossil", p._talk(_kit.MT_MOON_BELOW_DOME, UP), fossil],
		["mt_moon_b2f_to_b1f", p._walk(_kit.MT_MOON_B2F_EXIT_LADDER), p._on_map(_kit.MT_MOON_B1F)],
		["mt_moon_b1f_to_route_4", p._walk(_kit.MT_MOON_B1F_EXIT), p._on_map(_kit.ROUTE_4)],
		["route_4_to_cerulean", p._cross(Vector2i.RIGHT, _kit.CERULEAN_CITY), p._on_map(_kit.CERULEAN_CITY)],
		_grind.bind(_kit.MISTY_LEVEL, _kit.ODDISH_DEX),
		["cerulean_gym", p._warp_to(_kit.CERULEAN_GYM), p._on_map(_kit.CERULEAN_GYM)],
		_meet_partner("meet_in_cerulean_gym", _badge(CASCADE_BADGE)),
		["misty", p._talk_to(_kit.MISTY), _badge(CASCADE_BADGE)],
	]


func _surge_legs() -> Array:
	var p: Variant = _played
	var m: Dictionary = SURGE_MAPS
	var ticket: Callable = _either(p._holds(S_S_TICKET), p._flag(EVENT_GOT_SS_TICKET))
	var hm01: Callable = _either(p._holds(Gen1Layout.HM_FIRST_ITEM), p._flag(EVENT_GOT_HM01))
	return [
		["misty_gym_out", p._warp_to(_kit.CERULEAN_CITY), p._on_map(_kit.CERULEAN_CITY)],
		["cerulean_rival", p._cross(Vector2i.UP, m.route_24), p._on_map(m.route_24)],
		["nugget_bridge", p._cross(Vector2i.RIGHT, m.route_25), p._on_map(m.route_25)],
		["route_25_to_bill", p._warp_to(m.bills_house), _either(p._on_map(m.bills_house), ticket)],
		["bill", p._talk_to(BILL_POKEMON), _either(p._flag(EVENT_BILL_SAID_USE_CELL_SEPARATOR), ticket)],
		["cell_separator", p._talk(BILLS_PC_FRONT, UP), _either(p._flag(EVENT_USED_CELL_SEPARATOR_ON_BILL), ticket)],
		["ss_ticket", p._talk_to(BILL), ticket],
		["back_to_cerulean", p._route(_kit.CERULEAN_CITY), p._on_map(_kit.CERULEAN_CITY)],
		["trashed_house", p._warp_to(m.trashed_house), p._on_map(m.trashed_house)],
		["trashed_house_hole", p._walk(TRASHED_HOUSE_HOLE), p._on_map(_kit.CERULEAN_CITY)],
		["rocket_thief", p._cross(Vector2i.DOWN, m.route_5), p._on_map(m.route_5)],
		["route_5_to_underground", p._warp_to(m.underground_route_5), p._on_map(m.underground_route_5)],
		["underground_stairs", p._warp_to(m.underground_path), p._on_map(m.underground_path)],
		["underground_path", p._warp_to(m.underground_route_6), p._on_map(m.underground_route_6)],
		["underground_out", p._warp_to(m.route_6), p._on_map(m.route_6)],
		["route_6_to_vermilion", p._cross(Vector2i.DOWN, m.vermilion_city), p._on_map(m.vermilion_city)],
		_grind.bind(SURGE_LEVEL, SANDSHREW_DEX),
		["vermilion_dock", p._warp_to(m.vermilion_dock), _either(p._on_map(m.vermilion_dock), hm01)],
		["ss_anne", p._warp_to(m.ss_anne_1f), _either(p._on_map(m.ss_anne_1f), hm01)],
		["ss_anne_2f", p._warp_to(m.ss_anne_2f), _either(p._on_map(m.ss_anne_2f), hm01)],
		["ss_anne_rival", p._warp_to(m.captains_room), _either(p._on_map(m.captains_room), hm01)],
		["captain", p._talk_to(CAPTAIN), hm01],
		["ss_anne_out", p._route(m.vermilion_city), p._on_map(m.vermilion_city)],
		_teach_cut,
		["gym_tree", _cut_tree.bind(p._talk(GYM_TREE_FRONT, Gen2WorldSprite.FACING_DOWN)), _tree_cut],
		["vermilion_gym", p._warp_to(m.vermilion_gym), p._on_map(m.vermilion_gym)],
		["trash_cans", _search_cans, _either(p._flag(Gen1Layout.LOCK_2ND_EVENT), _badge(THUNDER_BADGE))],
		_meet_partner("meet_in_vermilion_gym", _badge(THUNDER_BADGE)),
		["lt_surge", p._talk_to(LT_SURGE), _badge(THUNDER_BADGE)],
	]


func _teach_cut() -> bool:
	var save: Gen2SaveData = _played._screen.active_save()
	if _played._screen.world().state.item_quantity(Gen1Layout.HM_FIRST_ITEM) <= 0:
		return false
	for mon: Gen2SaveMon in save.party:
		if Gen2WorldTMHM.can_learn(_session.data, mon.species, Gen2WorldFieldMove.MOVE_CUT):
			_played._editor.set_move(mon, Gen2SaveMon.MAX_MOVES - 1, Gen2WorldFieldMove.MOVE_CUT)
			_played._screen.call(&"_refresh_party_summary")
			return true
	return false


func _cut_tree(world: Gen2WorldAPI, face: Callable) -> int:
	var button: int = face.call(world)
	if button != PokeButton.A:
		return button
	_played._screen.call(&"_run_party_action", {"kind": &"field_move", "move": Gen2WorldFieldMove.MOVE_CUT,
		"slot": world.party_slot_with_move(Gen2WorldFieldMove.MOVE_CUT)})
	return PokeButton.NONE


func _tree_cut(world: Gen2WorldAPI) -> bool:
	return Gen1Layout.cut_tile(world.current_map.tileset, int(world.call(&"_gen1_tile_drawn_at", GYM_TREE))) < 0


func _search_cans(world: Gen2WorldAPI) -> int:
	var lock: String = Gen2WorldAPI.GEN1_SECOND_LOCK if world.event_flag_active(Gen1Layout.LOCK_1ST_EVENT) \
		else Gen2WorldAPI.GEN1_FIRST_LOCK
	var can: int = world.state.gen1_byte(lock)
	var column_and_row := Vector2i(can / TRASH_CANS_PER_COLUMN, can % TRASH_CANS_PER_COLUMN)
	return _played._talk_button(world, FIRST_TRASH_CAN + column_and_row * TRASH_CAN_SPACING)


func _either(first: Callable, second: Callable) -> Callable:
	return func(world: Gen2WorldAPI) -> bool: return bool(first.call(world)) or bool(second.call(world))


func _meet_partner(label: String, or_done: Callable) -> Array:
	return [label, _standing, _either(func(_world: Gen2WorldAPI) -> bool: return not _session.client.nearby().is_empty(), or_done)]


func _standing(_world: Gen2WorldAPI) -> int:
	return PokeButton.NONE


func _badge(bit: int) -> Callable:
	return func(world: Gen2WorldAPI) -> bool: return world.state.is_engine_flag_active(Gen2WorldState.gen1_badge_flag(bit))


func _grind(level: int, caught: int) -> bool:
	var grown: bool = _played._grind(level, caught)
	for failure: String in _played._r.failures:
		print("coop autoplay: %s %s" % [_player_id, failure])
	return grown


func _apply(button: int) -> void:
	var input: Gen2InputRuntime = Gen2InputRuntime.instance()
	if _tap != PokeButton.NONE and _frames - _tap_at >= TAP_FRAMES:
		input.release(_tap)
		_tap = PokeButton.NONE
	if PokeButton.is_direction(button) and _tap == PokeButton.NONE and _session.opening_screen == null \
			and not _session.panel.is_open():
		if _direction != button:
			if _direction != PokeButton.NONE:
				input.release(_direction)
			input.press(button)
			_direction = button
		return
	if _direction != PokeButton.NONE:
		input.release(_direction)
		_direction = PokeButton.NONE
	if button != PokeButton.NONE and _tap == PokeButton.NONE:
		input.press(button)
		_tap = button
		_tap_at = _frames
		if _played != null:
			_played._pressed_at = _frames


func _paced(button: int) -> int:
	return button if _frames - _tap_at >= TAP_EVERY else PokeButton.NONE


func _watch_progress() -> void:
	if _frames % 30 != 0:
		return
	var world: Gen2WorldAPI = _played._screen.world() if _played._screen != null and is_instance_valid(_played._screen) else null
	var now: String = "%s %s %d %s" % [world.map_id(), world.player_cell, _leg, world.script_busy()] if world != null else ""
	now += str(_session.panel.battle_view().get("revision", "")) if _session.panel != null else ""
	if now != _signature:
		_signature = now
		_still_since = Time.get_ticks_msec()
	elif _seconds_since(_still_since) > STILL_SECONDS:
		_fail("nothing moved for %d s: %s" % [STILL_SECONDS, _played._where() if world != null else now])


func _finish_route() -> void:
	_done = true
	_session.client.request_save()
	print("coop autoplay: %s finished, %s reached in %.0f s" % [_player_id, _route, Time.get_ticks_msec() / 1000.0])
	_shot("done")


func _fail(why: String) -> int:
	_done = true
	print("coop autoplay: %s FAILED at leg %d: %s" % [_player_id, _leg, why])
	_shot("failed")
	return PokeButton.NONE


func _shot(name: String) -> void:
	if _shots.is_empty():
		return
	var path: String = "%s/%s_%s.png" % [_shots, _player_id, name]
	root.get_viewport().get_texture().get_image().save_png(path)


static func _seconds_since(msec: int) -> float:
	return (Time.get_ticks_msec() - msec) / 1000.0
