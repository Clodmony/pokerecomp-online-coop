extends "res://tools/coop_play.gd"

## A co-op window that plays itself to BROCK's badge with `tools/checks/played.gd`'s legs, fighting from the panel:
##   Godot --path . -s res://tools/coop_autoplay.gd -- <address> [port] <player_id> [game] [opening]
##     [route=brock|misty|trade|surge|erika|watch_brock] [from=<leg>] [speed=1..4] [ball=0..2] [shots=<dir>]; prints "... finished" or "FAILED".

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
const RIGHT: int = Gen2WorldSprite.FACING_RIGHT
const CABLE_CLUB_RECEPTIONIST := Vector2i(11, 2)
const MACHOKE: int = 67
const TRADE_EVOLVED: Dictionary = {MACHOKE: 68}
const FILM_FRAMES: int = 30
const ROUTES: Dictionary = {
	"brock": [], "misty": [&"_misty_legs"], "trade": [&"_trade_legs"],
	"surge": [&"_misty_legs", &"_surge_legs"], "erika": [&"_misty_legs", &"_surge_legs", &"_erika_legs"],
	"watch_brock": [&"_stand_by_legs"],
}
const STAND_BY_SECONDS: float = 20.0
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
const ERIKA_MAPS: Dictionary = {
	&"route_9": Vector2i(0, 20), &"route_10": Vector2i(0, 21), &"rock_tunnel_1f": Vector2i(0, 82),
	&"rock_tunnel_b1f": Vector2i(0, 232), &"lavender_town": Vector2i(0, 4), &"route_8": Vector2i(0, 19),
	&"underground_route_8": Vector2i(0, 80), &"underground_west_east": Vector2i(0, 121),
	&"underground_route_7": Vector2i(0, 77), &"route_7": Vector2i(0, 18), &"celadon_city": Vector2i(0, 6),
	&"celadon_gym": Vector2i(0, 134), &"game_corner": Vector2i(0, 135), &"hideout_b1f": Vector2i(0, 199),
	&"hideout_b2f": Vector2i(0, 200), &"hideout_b3f": Vector2i(0, 201), &"hideout_b4f": Vector2i(0, 202),
	&"hideout_elevator": Vector2i(0, 203),
}
const ROUTE_9_TREE := Vector2i(5, 8)
const ROCK_TUNNEL_LADDERS: Array = [
	[&"rock_tunnel_b1f", Vector2i(37, 3)], [&"rock_tunnel_1f", Vector2i(27, 3)],
	[&"rock_tunnel_b1f", Vector2i(17, 11)], [&"rock_tunnel_1f", Vector2i(3, 3)],
]
const ROCK_TUNNEL_SOUTH_EXIT := Vector2i(15, 33)
const CELADON_TREE := Vector2i(35, 32)
const CELADON_GYM_TREE := Vector2i(5, 7)
const ERIKA := Vector2i(4, 3)
const RAINBOW_BADGE: int = 3
const GAME_CORNER_ROCKET := Vector2i(9, 5)
const GAME_CORNER_STAIRS := Vector2i(17, 4)
const HIDEOUT_ROCKET_3 := Vector2i(11, 2)
const LIFT_KEY_BALL := Vector2i(10, 2)
const CAR_PANEL_FRONT := Vector2i(1, 2)
const CAR_DOOR := Vector2i(2, 1)
const DOOR_ROCKETS: Array = [Vector2i(23, 12), Vector2i(26, 12)]
const GIOVANNI := Vector2i(25, 3)
const LIFT_KEY: int = 0x4A
const SILPH_SCOPE: int = 0x48
const EVENT_ROCKET_DROPPED_LIFT_KEY: int = 1702
const EVENT_BEAT_DOOR_ROCKETS: Array = [1698, 1699]
const EVENT_BEAT_ROCKET_HIDEOUT_GIOVANNI: int = 1703
const ROCK_TUNNEL_LEVEL: int = 34
const ERIKA_LEVEL: int = 38
const GROWLITHE_DEX: int = 58

var _played: Variant = null
var _kit: GDScript = null
var _route: String = "brock"
var _from: String = ""
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
var _trade: Dictionary = {}
var _trade_rounds: int = 0
var _link_pressed_at: int = 0


func _read_option(arg: String) -> bool:
	for option: String in ["route=", "from=", "speed=", "ball=", "shots="]:
		if arg.begins_with(option):
			var value: String = arg.trim_prefix(option)
			match option:
				"route=": _route = value
				"from=": _from = value
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
	if screen.get("_link_host") != null:
		return _link_button(screen)
	_hide_wait_box_left_over_the_link_room(screen)
	if _frames % 60 == 0 and screen.active_save().party.any(_worn):
		_heal(screen)
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
		var join: int = panel._rows.find_custom(func(row: Dictionary) -> bool: return row.get("id") == _partner_fight())
		return _paced(PokeButton.B if join < 0 else (PokeButton.A if panel._cursor == join else PokeButton.DOWN))
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
		var usable: bool = int((active.get("pp", []) as Array)[slot]) > 0 and slot != int(active.get("disabled", -1))
		var power: int = int(_session.data.move(int(active["moves"][slot])).get("power", 0)) if usable else -1
		if power > best_power or best < 0:
			best_power = power
			best = index
	var switch: int = rows.find_custom(func(row: Dictionary) -> bool: return row.get("command", {}).get("type") == "switch")
	return switch if best_power <= 0 and switch >= 0 else best


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
		_heal(screen)
		_leg += 1
		_leg_started = Time.get_ticks_msec()
		return PokeButton.NONE
	if _seconds_since(_leg_started) > LEG_SECONDS:
		return _fail("%s took longer than %d s: %s" % [row[0], LEG_SECONDS, _played._where()])
	var car: int = _elevator_button(screen)
	return car if car >= 0 else _played._button_for(row[1])


func _route_legs() -> Array:
	var legs: Array = _opening_legs() + _brock_legs()
	for stretch: StringName in ROUTES.get(_route, []):
		legs += call(stretch)
	if _from.is_empty():
		return legs
	var start: int = legs.find_custom(func(leg: Variant) -> bool: return leg is Array and leg[0] == _from)
	if start < 0:
		_fail("route %s has no leg %s" % [_route, _from])
	return legs.slice(maxi(start, 0))


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
		["brock", _standing if _route == "watch_brock" else p._talk_to(BROCK), p._flag(_kit.EVENT_BEAT_BROCK)],
		["boulder_badge", _standing, _badge(BOULDER_BADGE)],
	]


func _stand_by_legs() -> Array:
	return [["stand_by", _standing, func(_world: Gen2WorldAPI) -> bool: return _seconds_since(_leg_started) > STAND_BY_SECONDS]]


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
		["gym_tree", _cut_tree.bind(p._talk(GYM_TREE_FRONT, Gen2WorldSprite.FACING_DOWN)), _tree_gone(GYM_TREE)],
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


func _tree_gone(tree: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> bool:
		return Gen1Layout.cut_tile(world.current_map.tileset, int(world.call(&"_gen1_tile_drawn_at", tree))) < 0


func _erika_legs() -> Array:
	var p: Variant = _played
	var m: Dictionary = ERIKA_MAPS
	var s: Dictionary = SURGE_MAPS
	var lift_key: Callable = _either(p._holds(LIFT_KEY), p._holds(SILPH_SCOPE))
	var legs: Array = [
		["surge_gym_out", p._warp_to(s.vermilion_city), p._on_map(s.vermilion_city)],
		_grind.bind(ROCK_TUNNEL_LEVEL, 0),
		_teach_cut,
		["gym_tree_inside", _cut_tree.bind(p._talk(GYM_TREE + Vector2i.DOWN, UP)), _tree_gone(GYM_TREE)],
		["vermilion_to_route_6", p._cross(Vector2i.UP, s.route_6), p._on_map(s.route_6)],
		["route_6_to_underground", p._warp_to(s.underground_route_6), p._on_map(s.underground_route_6)],
		["underground_stairs_south", p._warp_to(s.underground_path), p._on_map(s.underground_path)],
		["underground_path_north", p._warp_to(s.underground_route_5), p._on_map(s.underground_route_5)],
		["underground_to_route_5", p._warp_to(s.route_5), p._on_map(s.route_5)],
		["route_5_to_cerulean", p._cross(Vector2i.UP, _kit.CERULEAN_CITY), p._on_map(_kit.CERULEAN_CITY)],
		["cerulean_to_route_9", p._cross(Vector2i.RIGHT, m.route_9), p._on_map(m.route_9)],
		["route_9_tree", _cut_tree.bind(p._talk(ROUTE_9_TREE + Vector2i.LEFT, RIGHT)), _tree_gone(ROUTE_9_TREE)],
		["route_9_to_route_10", p._cross(Vector2i.RIGHT, m.route_10), p._on_map(m.route_10)],
		["route_10_to_rock_tunnel", p._warp_to(m.rock_tunnel_1f), p._on_map(m.rock_tunnel_1f)],
	]
	for ladder: int in ROCK_TUNNEL_LADDERS.size():
		var row: Array = ROCK_TUNNEL_LADDERS[ladder]
		legs.append(["rock_tunnel_ladder_%d" % (ladder + 1), p._walk(row[1]), p._on_map(m[row[0]])])
	return legs + [
		["rock_tunnel_south_exit", p._walk(ROCK_TUNNEL_SOUTH_EXIT), p._on_map(m.route_10)],
		["route_10_to_lavender", p._cross(Vector2i.DOWN, m.lavender_town), p._on_map(m.lavender_town)],
		["lavender_to_route_8", p._cross(Vector2i.LEFT, m.route_8), p._on_map(m.route_8)],
		["route_8_to_underground", p._warp_to(m.underground_route_8), p._on_map(m.underground_route_8)],
		["underground_stairs_east", p._warp_to(m.underground_west_east), p._on_map(m.underground_west_east)],
		["underground_path_west", p._warp_to(m.underground_route_7), p._on_map(m.underground_route_7)],
		["underground_to_route_7", p._warp_to(m.route_7), p._on_map(m.route_7)],
		["route_7_to_celadon", p._cross(Vector2i.LEFT, m.celadon_city), p._on_map(m.celadon_city)],
		_grind.bind(ERIKA_LEVEL, GROWLITHE_DEX),
		_teach_cut,
		["celadon_tree", _cut_tree.bind(p._talk(CELADON_TREE + Vector2i.UP, Gen2WorldSprite.FACING_DOWN)),
			_tree_gone(CELADON_TREE)],
		["celadon_gym", p._warp_to(m.celadon_gym), p._on_map(m.celadon_gym)],
		["celadon_gym_tree", _cut_tree.bind(p._talk(CELADON_GYM_TREE + Vector2i.DOWN, UP)), _tree_gone(CELADON_GYM_TREE)],
		_meet_partner("meet_in_celadon_gym", _badge(RAINBOW_BADGE)),
		["erika", _join_or(p._talk_to(ERIKA)), _badge(RAINBOW_BADGE)],
		["erika_gym_out", p._warp_to(m.celadon_city), p._on_map(m.celadon_city)],
		["celadon_tree_inside", _cut_tree.bind(p._talk(CELADON_TREE + Vector2i.DOWN, UP)), _tree_gone(CELADON_TREE)],
		["game_corner", p._warp_to(m.game_corner), p._on_map(m.game_corner)],
		["poster", _poster, func(world: Gen2WorldAPI) -> bool: return world.can_walk_to(GAME_CORNER_STAIRS)],
		["game_corner_stairs", p._warp_to(m.hideout_b1f), p._on_map(m.hideout_b1f)],
		["hideout_b1f_to_b2f", _glide_to(m.hideout_b2f), p._on_map(m.hideout_b2f)],
		["hideout_b2f_to_b3f", _glide_to(m.hideout_b3f), p._on_map(m.hideout_b3f)],
		["hideout_b3f_to_b4f", _glide_to(m.hideout_b4f), p._on_map(m.hideout_b4f)],
		["lift_key_rocket", p._talk_to(HIDEOUT_ROCKET_3), _either(p._flag(EVENT_ROCKET_DROPPED_LIFT_KEY), lift_key)],
		["lift_key", p._talk(LIFT_KEY_BALL + Vector2i.DOWN, UP), lift_key],
		["hideout_b4f_to_b3f", _glide_to(m.hideout_b3f), p._on_map(m.hideout_b3f)],
		["hideout_b3f_to_b2f", _glide_to(m.hideout_b2f), p._on_map(m.hideout_b2f)],
		["hideout_b2f_elevator", _glide_to(m.hideout_elevator), p._on_map(m.hideout_elevator)],
		["elevator_panel", p._talk(CAR_PANEL_FRONT, UP), _car_bound_for(m.hideout_b4f)],
		["elevator_to_b4f", p._walk(CAR_DOOR), p._on_map(m.hideout_b4f)],
		["door_rocket_1", p._talk_to(DOOR_ROCKETS[0]), p._flag(EVENT_BEAT_DOOR_ROCKETS[0])],
		["door_rocket_2", p._talk_to(DOOR_ROCKETS[1]), p._flag(EVENT_BEAT_DOOR_ROCKETS[1])],
		["giovanni", _join_or(p._talk_to(GIOVANNI)), p._flag(EVENT_BEAT_ROCKET_HIDEOUT_GIOVANNI)],
		["silph_scope", p._talk(GIOVANNI, UP), p._holds(SILPH_SCOPE)],
	]


func _poster(world: Gen2WorldAPI) -> int:
	if world.object_at(GAME_CORNER_ROCKET) != null:
		return _played._talk_button(world, GAME_CORNER_ROCKET)
	return _played._talk(GAME_CORNER_ROCKET, UP).call(world)


func _car_bound_for(map: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> bool: return int((world.get("_gen1_warp_entry") as Dictionary).get("map", -1)) == map.y


func _elevator_button(screen: Gen2WorldScreen) -> int:
	var host: Gen2WorldServiceScreen = screen.get("_service_host")
	if host == null or int(host.get("_mode")) != Gen2WorldServiceScreen.MODE.ELEVATOR or bool(host.call(&"_box_printing")):
		return -1
	var floors: Array = host.call(&"_elevator_floors")
	var wanted: int = floors.find_custom(func(row: Dictionary) -> bool: return int(row["map"]) == ERIKA_MAPS.hideout_b4f.y)
	if wanted < 0:
		return -1
	return _paced(PokeButton.A if host.selected_index() == wanted else PokeButton.DOWN)


func _glide_to(map: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> int:
		for warp: Dictionary in world.current_map.events.get("warps", []):
			if _played._warp_target(world, warp) == map:
				var button: int = _glide_button(world, Vector2i(int(warp["x"]), int(warp["y"])))
				if button != PokeButton.NONE:
					return button
		return PokeButton.NONE


func _glide_button(world: Gen2WorldAPI, target: Vector2i) -> int:
	if world.player_cell == target:
		return _played._warp_press(world, target)
	var spins: Dictionary = _spin_landings(world)
	var goal: Callable = _played._is(target)
	var first: Dictionary = {world.player_cell: Vector2i.ZERO}
	var frontier: Array[Vector2i] = [world.player_cell]
	while not frontier.is_empty():
		var at: Vector2i = frontier.pop_front()
		if at == target:
			return _played._direction_button(first[at])
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = _played._neighbour(world, at, direction, goal)
			next = spins.get(next, next)
			if next.x >= 0 and not first.has(next):
				first[next] = direction if at == world.player_cell else first[at]
				frontier.append(next)
	return PokeButton.NONE


func _spin_landings(world: Gen2WorldAPI) -> Dictionary:
	var out: Dictionary = {}
	var pending: Array = [world.current_map.scripts.get("states", [])]
	while not pending.is_empty():
		for node: Variant in pending.pop_back():
			if not node is Dictionary:
				continue
			for key: String in Gen1Layout.SCRIPT_BRANCH_KEYS + ["nodes"]:
				if node.has(key) and node[key] is Array:
					pending.append(node[key])
			if String(node.get("op", "")) != "arrow_movement":
				continue
			for cell: Dictionary in node["cells"]:
				var landing := Vector2i(int(cell["x"]), int(cell["y"]))
				for leg: Dictionary in cell["moves"]:
					landing += world.movement_direction(int(leg["direction"])) * int(leg["steps"])
				out[Vector2i(int(cell["x"]), int(cell["y"]))] = landing
	return out


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


func _partner_fight() -> String:
	if _session.client.nearby().is_empty():
		return ""
	for running: Dictionary in _session.client.state.get("battles", []):
		if String(running.get("encounter", "")).begins_with("trainer:") and not bool(running.get("private", false)) \
				and not (running.get("participants", []) as Array).has(_player_id) and running.get("phase") != "over":
			return String(running["battle"])
	return ""


func _join_or(goal: Callable) -> Callable:
	return func(world: Gen2WorldAPI) -> int: return PokeButton.SELECT if not _partner_fight().is_empty() else goal.call(world)


func _standing(_world: Gen2WorldAPI) -> int:
	return PokeButton.NONE


func _badge(bit: int) -> Callable:
	return func(world: Gen2WorldAPI) -> bool: return world.state.is_engine_flag_active(Gen2WorldState.gen1_badge_flag(bit))


func _worn(mon: Gen2SaveMon) -> bool:
	if mon.is_egg:
		return false
	var spent: bool = range(Gen2SaveMon.MAX_MOVES).any(func(slot: int) -> bool:
		return int(mon.pp[slot]) * 2 < mon.max_pp(_session.data, slot))
	return mon.status != 0 or mon.hp * 2 < _played._editor.max_hp_for(mon) or spent


func _heal(screen: Gen2WorldScreen) -> void:
	for mon: Gen2SaveMon in screen.active_save().party:
		if not mon.is_egg:
			mon.hp = _played._editor.max_hp_for(mon)
			mon.status = 0
			for slot: int in Gen2SaveMon.MAX_MOVES:
				mon.pp[slot] = mon.max_pp(_session.data, slot)
	screen.call(&"_refresh_party_summary")


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
	if _done:
		return PokeButton.NONE
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


func _trade_legs() -> Array:
	var p: Variant = _played
	var center: Vector2i = p._named(&"PEWTER_POKECENTER")
	var room: Dictionary = _session.data.gen1_cable_club_warp("trade_center")
	var trade_center := Vector2i(0, int(room["map"]))
	return [
		["gym_out", p._warp_to(_kit.PEWTER_CITY), p._on_map(_kit.PEWTER_CITY)],
		["pewter_center", p._warp_to(center), p._on_map(center)],
		_give_machoke,
		["machoke_on_host", _standing, _machoke_on_host],
		["cable_club", p._talk_to(CABLE_CLUB_RECEPTIONIST), p._on_map(trade_center)],
		_meet_partner("meet_in_trade_center", _traded),
		["trade", p._talk(Vector2i(int(room["x"]), int(room["y"])), RIGHT), _traded],
		["window_takes_the_swap", _standing, _window_matches_host],
		_check_trade,
	]


func _give_machoke() -> bool:
	var ids: Array = (_session.client.state.get("players", {}) as Dictionary).keys()
	ids.sort()
	if ids.size() < 2 or ids[0] != _session.client.player_id:
		return true
	var save: Gen2SaveData = _played._screen.active_save()
	if not bool(_played._editor.add_party_member(MACHOKE, _kit.BROCK_LEVEL).get("ok", false)):
		return false
	var machoke: Gen2SaveMon = save.party.back()
	machoke.ot_id = save.player_id
	machoke.original_trainer = save.player_name
	_played._screen.call(&"_refresh_party_summary")
	return true


func _hide_wait_box_left_over_the_link_room(screen: Gen2WorldScreen) -> void:
	var box: Gen2TextBox = screen.get("_text_box")
	var world: Gen2WorldAPI = screen.world()
	if box != null and box.visible and not box.is_revealing() and PokeCoopTrades.LINK_ROOMS.has(world.map_id()) \
			and not world.script_busy() and not world.script_input_waiting() and world.pending_runtime_request().is_empty():
		box.visible = false


func _machoke_on_host(_world: Gen2WorldAPI) -> bool:
	return _slot_of(_rows(false), MACHOKE) >= 0 or _slot_of(_rows(true), MACHOKE) >= 0


func _rows(partner: bool) -> Array:
	var me: Dictionary = _session.client.me()
	return (me.get("trade_partner", {}) as Dictionary).get("party", []) if partner else me.get("party", [])


static func _slot_of(rows: Array, species: int) -> int:
	return rows.find_custom(func(row: Dictionary) -> bool: return int(row["mon"]["species"]) == species)


static func _species_of(rows: Array, uid: String) -> int:
	var at: int = rows.find_custom(func(row: Dictionary) -> bool: return String(row["uid"]) == uid)
	return int(rows[at]["mon"]["species"]) if at >= 0 else 0


func _traded(_world: Gen2WorldAPI) -> bool:
	return String(_trade.get("outcome", "")) == PokeCoopTrades.TRADED


func _window_matches_host(_world: Gen2WorldAPI) -> bool:
	var window: Array = _played._screen.active_save().party.map(func(mon: Gen2SaveMon) -> int: return mon.species)
	return window == _rows(false).map(func(row: Dictionary) -> int: return int(row["mon"]["species"]))


func _link_button(screen: Gen2WorldScreen) -> int:
	for overlay: StringName in [&"_trade_anim_host", &"_evolution_host"]:
		if screen.get(overlay) != null:
			if _frames % FILM_FRAMES == 0:
				_shot("%s_%05d" % [String(overlay).trim_prefix("_").trim_suffix("_host"), _frames])
			return _link_paced(PokeButton.A) if overlay == &"_evolution_host" else PokeButton.NONE
	var host: Gen2LinkScreen = screen.get("_link_host")
	var state: Dictionary = host.trade_state()
	match host.step():
		Gen2LinkScreen.STEP.SELECT:
			return _link_paced(_select_button(screen, state))
		Gen2LinkScreen.STEP.FOOTER:
			var press: int = _link_paced(
				PokeButton.A if int(state["footer"]) == Gen2LinkScreen.FOOTER_TRADE else PokeButton.RIGHT)
			_trade["offered"] = bool(_trade.get("offered", false)) or press == PokeButton.A
			return press
		Gen2LinkScreen.STEP.GEN1_ASK:
			var box: Gen2TextBox = state["box"]
			var paging: bool = box != null and box.has_pages_left() and not box.is_revealing()
			return _link_paced(PokeButton.A) if paging else PokeButton.NONE
		Gen2LinkScreen.STEP.CONFIRM:
			return _link_paced(_confirm_button(int(state["confirm"])))
	return PokeButton.NONE


func _confirm_button(row: int) -> int:
	if not _trade.has("asked"):
		_trade["asked"] = true
		_shot("trade_confirm_%d" % _trade_rounds)
	var wanted: int = 1 if bool(_trade.get("cancel", false)) else 0
	return PokeButton.A if row == wanted else (PokeButton.DOWN if row < wanted else PokeButton.UP)


func _select_button(screen: Gen2WorldScreen, state: Dictionary) -> int:
	if _trade.is_empty():
		_trade = _trade_plan(screen)
	if _trade.is_empty() or not _round_settled():
		return PokeButton.NONE
	if _trade.has("outcome"):
		return PokeButton.A if bool(state["cancel"]) else PokeButton.DOWN
	if bool(state["cancel"]):
		return PokeButton.UP
	if int(state["list"]) != Gen2LinkScreen.LIST_PLAYER:
		return PokeButton.LEFT
	var index: int = int(state["index"])
	var slot: int = int(_trade["slot"])
	return PokeButton.A if index == slot else (PokeButton.DOWN if index < slot else PokeButton.UP)


func _round_settled() -> bool:
	if not bool(_trade.get("offered", false)) or _trade.has("outcome"):
		return true
	var round: Dictionary = _session.client.me().get("trade", {})
	if int(round.get("serial", 0)) <= int(_trade["serial"]):
		return false
	var outcome: String = String(round.get("outcome", ""))
	var expected: String = PokeCoopTrades.CANCELED if _trade_rounds == 0 else PokeCoopTrades.TRADED
	_trade_rounds += 1
	if outcome != expected:
		_fail("trade round %d was %s, not %s" % [_trade_rounds, outcome, expected])
		return false
	if outcome == PokeCoopTrades.CANCELED:
		_canceled_round_moved_nobody()
		return false
	_trade["outcome"] = outcome
	return true


func _canceled_round_moved_nobody() -> void:
	if _both_teams() != _trade["teams"]:
		_fail("the canceled round moved %s to %s" % [_trade["teams"], _both_teams()])
		return
	print("coop autoplay: %s trade round 1 canceled by the MACHOKE's receiver, both teams kept" % _player_id)
	_trade = {}


func _both_teams() -> Array:
	var rows: Callable = func(row: Dictionary) -> Array: return [String(row["uid"]), int(row["mon"]["species"])]
	return [_rows(false).map(rows), _rows(true).map(rows)]


func _trade_plan(screen: Gen2WorldScreen) -> Dictionary:
	var mine: Array = _rows(false)
	var theirs: Array = _rows(true)
	var giving: int = _slot_of(mine, MACHOKE)
	var slot: int = maxi(giving, 0)
	var their_slot: int = 0 if giving >= 0 else _slot_of(theirs, MACHOKE)
	var party: Array = screen.active_save().party
	if their_slot < 0 or their_slot >= theirs.size() or slot >= mine.size() or slot >= party.size():
		_fail("no MACHOKE to trade: %d with %d" % [mine.size(), theirs.size()])
		return {}
	if (party[slot] as Gen2SaveMon).species != int(mine[slot]["mon"]["species"]):
		_fail("the window's slot %d is not the host's" % slot)
		return {}
	_shot("trade_lists_%d" % _trade_rounds)
	return {
		"slot": slot, "given": String(mine[slot]["uid"]), "given_species": int(mine[slot]["mon"]["species"]),
		"taken": String(theirs[their_slot]["uid"]), "taken_species": int(theirs[their_slot]["mon"]["species"]),
		"sizes": [mine.size(), theirs.size()], "teams": _both_teams(), "cancel": _trade_rounds == 0 and giving < 0,
		"serial": int((_session.client.me().get("trade", {}) as Dictionary).get("serial", 0)),
	}


func _check_trade() -> bool:
	var mine: Array = _rows(false)
	var theirs: Array = _rows(true)
	var given: String = _trade["given"]
	var taken: String = _trade["taken"]
	var uids: Array = (mine + theirs).map(func(row: Dictionary) -> String: return String(row["uid"]))
	var problems: PackedStringArray = []
	if _species_of(mine, taken) != TRADE_EVOLVED.get(_trade["taken_species"], _trade["taken_species"]):
		problems.append("%s is not on this team as it should arrive" % taken)
	if _species_of(theirs, given) != TRADE_EVOLVED.get(_trade["given_species"], _trade["given_species"]):
		problems.append("%s is not on the partner's team as it should arrive" % given)
	if _species_of(mine, given) != 0 or _species_of(theirs, taken) != 0:
		problems.append("a traded Pokémon is still with its sender")
	if [mine.size(), theirs.size()] != _trade["sizes"] or uids.size() != _unique(uids):
		problems.append("the teams went from %s to %s: %s" % [_trade["sizes"], [mine.size(), theirs.size()], uids])
	if not problems.is_empty():
		_fail("; ".join(problems))
		return false
	print("coop autoplay: %s traded %s %d for %s %d" % [
		_player_id, given, _trade["given_species"], taken, _trade["taken_species"]])
	return true


static func _unique(values: Array) -> int:
	var seen: Dictionary = {}
	for value: Variant in values:
		seen[value] = true
	return seen.size()


func _link_paced(button: int) -> int:
	if button == PokeButton.NONE or _frames - _link_pressed_at < TAP_EVERY:
		return PokeButton.NONE
	_link_pressed_at = _frames
	return button
