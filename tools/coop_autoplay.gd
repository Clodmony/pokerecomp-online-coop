extends "res://tools/coop_play.gd"

## A co-op window that plays itself to BROCK's badge with `tools/checks/played.gd`'s legs, fighting from the panel:
##   Godot --path . -s res://tools/coop_autoplay.gd -- <address> [port] <player_id> [game] [opening]
##     [route=brock|misty|trade|surge|koga|sabrina|watch_brock] [from=<leg>] [speed=1..4] [ball=0..2] [shots=<dir>]; prints "... finished" or "FAILED".

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
	"surge": [&"_misty_legs", &"_surge_legs"], "watch_brock": [&"_stand_by_legs"],
	"koga": [&"_misty_legs", &"_surge_legs", &"_koga_legs"],
	"sabrina": [&"_misty_legs", &"_surge_legs", &"_koga_legs", &"_sabrina_legs"],
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
	var battle: Gen2BattleScreen = screen.get("_battle_host")
	if battle != null and battle.capture_safari_catch_rate() >= 0 and not bool(screen.call(&"_input_locked")):
		return _safari_button(battle)
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
		return _menu_button(panel)
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
		_heal(screen)
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


const KOGA_MAPS: Dictionary = {
	&"lavender_town": Vector2i(0, 4), &"route_12": Vector2i(0, 23), &"route_12_gate": Vector2i(0, 87),
	&"route_13": Vector2i(0, 24), &"route_14": Vector2i(0, 25), &"route_15": Vector2i(0, 26),
	&"route_15_gate": Vector2i(0, 184), &"fuchsia_city": Vector2i(0, 7), &"fuchsia_gym": Vector2i(0, 157),
	&"safari_gate": Vector2i(0, 156), &"safari_east": Vector2i(0, 217), &"safari_north": Vector2i(0, 218),
	&"safari_west": Vector2i(0, 219), &"safari_center": Vector2i(0, 220), &"secret_house": Vector2i(0, 222),
	&"wardens_house": Vector2i(0, 155),
}
const BESIDE_SNORLAX: Array[Vector2i] = [Vector2i(10, 61), Vector2i(11, 61)]
const SNORLAX := Vector2i(10, 62)
const SNORLAX_ENCOUNTER: String = "static:143:0:23"
const ROUTE_12_GATE_SOUTH := Vector2i(4, 7)
const ROUTE_13_WEST_EDGE := Vector2i(0, 8)
const ROUTE_15_GATE_WEST := Vector2i(0, 4)
const SAFARI_GATE_OFFER := Vector2i(3, 2)
const BELOW_FISHING_GURU := Vector2i(3, 4)
const BELOW_GOLD_TEETH := Vector2i(19, 8)
const WARDEN := Vector2i(2, 3)
const KOGA := Vector2i(4, 10)
const SAFARI_WAY_OUT: Dictionary = {222: 219, 219: 218, 218: 217, 217: 220, 220: 156, 156: 7}
const GOLD_TEETH: int = 0x40
const HM03: int = Gen1Layout.HM_FIRST_ITEM + 2
const HM04: int = Gen1Layout.HM_FIRST_ITEM + 3
const EVENT_GOT_HM03: int = 2176
const EVENT_GOT_HM04: int = 568
const EVENT_GAVE_GOLD_TEETH: int = 569
const SNORLAX_LEVEL: int = 45
const KOGA_LEVEL: int = 50

var _joining: String = ""
var _fluted: bool = false
var _safari_team: int = -1
var _safari_caught: bool = false


func _koga_legs() -> Array:
	var p: Variant = _played
	var m: Dictionary = KOGA_MAPS
	var beaten: Callable = p._flag(int(Gen1Layout.SNORLAX_FLUTES[0]["beat"]))
	var hm03: Callable = _either(p._holds(HM03), p._flag(EVENT_GOT_HM03))
	var teeth: Callable = _either(p._holds(GOLD_TEETH), p._flag(EVENT_GAVE_GOLD_TEETH))
	var hm04: Callable = _either(p._holds(HM04), p._flag(EVENT_GOT_HM04))
	var both: Callable = func(world: Gen2WorldAPI) -> bool: return bool(hm03.call(world)) and bool(teeth.call(world))
	var spot: Callable = func(world: Gen2WorldAPI) -> bool: return world.player_cell == _snorlax_spot()
	var inside: Callable = func(world: Gen2WorldAPI) -> bool: return world.gen1_safari_active() and world.map_id() == m.safari_center
	return [
		["mr_fujis_house_out", p._warp_to(m.lavender_town), p._on_map(m.lavender_town)],
		_grind.bind(SNORLAX_LEVEL, 0),
		["lavender_to_route_12", p._cross(Vector2i.DOWN, m.route_12), p._on_map(m.route_12)],
		["route_12_gate", p._warp_to(m.route_12_gate), p._on_map(m.route_12_gate)],
		["route_12_gate_south", p._walk(ROUTE_12_GATE_SOUTH), p._on_map(m.route_12)],
		["beside_snorlax", func(world: Gen2WorldAPI) -> int: return p._walk(_snorlax_spot()).call(world), _either(spot, beaten)],
		["meet_at_snorlax", _standing, _either(_partner_near(m.route_12, SNORLAX, 2), beaten)],
		["snorlax", _wake_or_join_snorlax, _snorlax_gone],
		["route_12_to_route_13", p._cross(Vector2i.DOWN, m.route_13), p._on_map(m.route_13)],
		["route_13_to_route_14", _cross_at(ROUTE_13_WEST_EDGE, Vector2i.LEFT), p._on_map(m.route_14)],
		["route_14_to_route_15", p._cross(Vector2i.LEFT, m.route_15), p._on_map(m.route_15)],
		["route_15_gate", p._warp_to(m.route_15_gate), p._on_map(m.route_15_gate)],
		["route_15_gate_west", p._walk(ROUTE_15_GATE_WEST), p._on_map(m.route_15)],
		["route_15_to_fuchsia", p._cross(Vector2i.LEFT, m.fuchsia_city), p._on_map(m.fuchsia_city)],
		["safari_gate", p._warp_to(m.safari_gate), p._on_map(m.safari_gate)],
		["safari_fee", p._walk(SAFARI_GATE_OFFER), inside],
		_note_team,
		["safari_catch", _walk_grass, _caught_on_host],
		["safari_center_to_east", p._warp_to(m.safari_east), _either(p._on_map(m.safari_east), both)],
		["safari_east_to_north", p._warp_to(m.safari_north), _either(p._on_map(m.safari_north), both)],
		["safari_north_to_west", p._warp_to(m.safari_west), _either(p._on_map(m.safari_west), both)],
		["secret_house", p._warp_to(m.secret_house), _either(p._on_map(m.secret_house), hm03)],
		["hm03", p._talk(BELOW_FISHING_GURU, UP), hm03],
		["secret_house_out", p._warp_to(m.safari_west), _either(p._on_map(m.safari_west), both)],
		["gold_teeth", p._talk(BELOW_GOLD_TEETH, UP), teeth],
		["safari_out", _leave_safari, p._on_map(m.fuchsia_city)],
		["wardens_house", p._warp_to(m.wardens_house), _either(p._on_map(m.wardens_house), hm04)],
		["warden", p._talk_to(WARDEN), hm04],
		["wardens_house_out", p._warp_to(m.fuchsia_city), p._on_map(m.fuchsia_city)],
		_grind.bind(KOGA_LEVEL, 0),
		["fuchsia_gym", p._warp_to(m.fuchsia_gym), p._on_map(m.fuchsia_gym)],
		_meet_partner("meet_in_fuchsia_gym", _badge(Gen1Layout.SOULBADGE)),
		["koga", p._talk_to(KOGA), _badge(Gen1Layout.SOULBADGE)],
		_koga_done,
	]


func _cross_at(cell: Vector2i, direction: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> int:
		if world.player_cell == cell:
			return _played._direction_button(direction)
		return _played._step_toward(world, _played._is(cell))


func _snorlax_spot() -> Vector2i:
	return BESIDE_SNORLAX[0 if _wakes_snorlax() else 1]


func _wakes_snorlax() -> bool:
	var ids: Array = (_session.client.state.get("players", {}) as Dictionary).keys()
	ids.sort()
	return ids.is_empty() or ids[0] == _session.client.player_id


func _partner_near(map: Vector2i, cell: Vector2i, reach: int) -> Callable:
	return func(_world: Gen2WorldAPI) -> bool:
		var players: Dictionary = _session.client.state.get("players", {})
		for player_id: String in players:
			var view: Dictionary = players[player_id]
			var at: Vector2i = view.get("cell", Vector2i(-99, -99))
			if player_id != _session.client.player_id and view.get("map") == map and bool(view.get("connected", false)) \
					and absi(at.x - cell.x) + absi(at.y - cell.y) <= reach:
				return true
		return false


func _wake_or_join_snorlax(world: Gen2WorldAPI) -> int:
	if not _wakes_snorlax():
		return _join_button(SNORLAX_ENCOUNTER)
	var button: int = _played._talk(BESIDE_SNORLAX[0], Gen2WorldSprite.FACING_DOWN).call(world)
	if button != PokeButton.A:
		return button
	if not _fluted:
		_fluted = true
		var request: Dictionary = {"ok": true, "effect": Gen2WorldPack.FIELD_EFFECT_POKE_FLUTE, "item": Gen1Layout.ITEM_POKE_FLUTE}
		request.merge(world.poke_flute_request(), true)
		print("coop autoplay: %s played the POKé FLUTE: %s" % [_player_id, request])
		_played._screen.call(&"_on_field_item_used", request)
	return PokeButton.NONE


func _join_button(encounter: String) -> int:
	for running: Dictionary in _session.client.state.get("battles", []):
		if String(running.get("encounter", "")) == encounter and not (running["participants"] as Array).has(_session.client.player_id):
			_joining = String(running["battle"])
			return _paced(PokeButton.SELECT)
	return PokeButton.NONE


func _menu_button(panel: PokeCoopBattlePanel) -> int:
	var row: int = panel._rows.find_custom(func(entry: Dictionary) -> bool:
		return String(entry.get("action", "")) == "join" and String(entry.get("id", "")) == _joining)
	if _joining.is_empty() or row < 0:
		return _paced(PokeButton.B)
	var press: int = _paced(PokeButton.A if panel._cursor == row else PokeButton.DOWN)
	if press == PokeButton.A:
		print("coop autoplay: %s joins %s from the session menu" % [_player_id, _joining])
		_joining = ""
	return press


func _snorlax_gone(world: Gen2WorldAPI) -> bool:
	var defeated: Array = (_session.client.state.get("campaign", {}) as Dictionary).get("defeated", [])
	var drawn: bool = world.active_objects().any(func(object: Gen2WorldObject) -> bool: return object.initial_cell == SNORLAX)
	var gone: bool = world.event_flag_active(int(Gen1Layout.SNORLAX_FLUTES[0]["beat"])) and not drawn \
		and defeated.has(SNORLAX_ENCOUNTER)
	if gone:
		print("coop autoplay: %s SNORLAX is gone here and %s on the host" % [_player_id, SNORLAX_ENCOUNTER])
	return gone


func _note_team() -> bool:
	_safari_team = _host_team_size()
	return true


func _host_team_size() -> int:
	return (_session.client.me().get("party", []) as Array).size() + (_session.client.box.get("rows", []) as Array).size()


func _caught_on_host(_world: Gen2WorldAPI) -> bool:
	if _safari_team < 0 or _host_team_size() <= _safari_team:
		return false
	_safari_caught = true
	var rows: Array = (_session.client.me().get("party", []) as Array) + (_session.client.box.get("rows", []) as Array)
	print("coop autoplay: %s caught in the Safari Zone, on the host: %s" % [
		_player_id, rows.map(func(row: Dictionary) -> String: return "%s %d" % [row["uid"], int(row["mon"]["species"])])])
	return true


func _walk_grass(world: Gen2WorldAPI) -> int:
	var here: Vector2i = world.player_cell
	return _played._step_toward(world, func(at: Vector2i) -> bool: return at != here and world.in_grass(at))


func _safari_button(battle: Gen2BattleScreen) -> int:
	var prompt: Gen2NicknamePromptScreen = battle.get("_capture_nickname_host")
	if prompt != null:
		return _played._paced(PokeButton.B if prompt.question_ready() else PokeButton.A)
	var snapshot: Dictionary = battle.battle_snapshot()
	if not _safari_caught or StringName(snapshot.get("menu_stage", &"")) != &"main":
		return _played._battle_button()
	var position: int = int(snapshot.get("menu_position", Gen2BattleMenu.FIGHT))
	if position == Gen2BattleMenu.RUN:
		return _played._paced(PokeButton.A)
	return _played._paced(PokeButton.RIGHT if position == Gen2BattleMenu.PACK else PokeButton.DOWN)


func _leave_safari(world: Gen2WorldAPI) -> int:
	return _played._warp_to(Vector2i(0, int(SAFARI_WAY_OUT.get(world.map_id().y, KOGA_MAPS.fuchsia_city.y)))).call(world)


func _koga_done() -> bool:
	var world: Gen2WorldAPI = _played._screen.world()
	var me: Dictionary = _session.client.me()
	var held: Dictionary = me.get("items", {})
	var missing: PackedStringArray = []
	for item: int in [HM03, HM04]:
		if world.state.item_quantity(item) <= 0 or int(held.get(item, 0)) <= 0:
			missing.append("item %d" % item)
	if not _snorlax_gone(world):
		missing.append("SNORLAX")
	if not world.state.is_engine_flag_active(Gen2WorldState.gen1_badge_flag(Gen1Layout.SOULBADGE)):
		missing.append("SOULBADGE")
	print("coop autoplay: %s after KOGA: badges %d, team on host %s, missing %s" % [
		_player_id, world.state.badge_count(), (me.get("party", []) as Array).map(
			func(row: Dictionary) -> int: return int(row["mon"]["species"])), missing])
	return missing.is_empty()


const SABRINA_MAPS: Dictionary = {
	&"route_8": Vector2i(0, 19), &"underground_route_8": Vector2i(0, 80), &"underground_west_east": Vector2i(0, 121),
	&"underground_route_7": Vector2i(0, 77), &"route_7": Vector2i(0, 18), &"celadon_city": Vector2i(0, 6),
	&"route_7_gate": Vector2i(0, 76), &"saffron_city": Vector2i(0, 10), &"silph_1f": Vector2i(0, 181),
	&"silph_2f": Vector2i(0, 207), &"silph_3f": Vector2i(0, 208), &"silph_4f": Vector2i(0, 209),
	&"silph_5f": Vector2i(0, 210), &"silph_7f": Vector2i(0, 212), &"silph_9f": Vector2i(0, 233),
	&"silph_11f": Vector2i(0, 235), &"saffron_gym": Vector2i(0, 178),
}
const CELADON_MART_FLOORS: Array[int] = [122, 123, 124, 125, 136, 126]
const ROUTE_15_WEST_DOOR := Vector2i(7, 8)
const ROUTE_15_GATE_EAST := Vector2i(7, 4)
const ROUTE_14_EAST_EDGE := Vector2i(19, 8)
const ROUTE_12_GATE_SOUTH_DOOR := Vector2i(10, 21)
const ROUTE_12_GATE_NORTH := Vector2i(4, 0)
const ROUTE_8_UNDERGROUND := Vector2i(13, 3)
const BELOW_VENDING_MACHINES: Array[Vector2i] = [Vector2i(10, 2), Vector2i(11, 2)]
const ROUTE_7_GATE_EAST := Vector2i(5, 3)
const ROUTE_7_EAST_DOOR_X: int = 18
const SILPH_STAIRS_UP: Array[Vector2i] = [Vector2i(26, 0), Vector2i(26, 0), Vector2i(24, 0), Vector2i(26, 0)]
const SILPH_5F_PAD := Vector2i(9, 15)
const SILPH_9F_PAD := Vector2i(17, 15)
const BESIDE_CARD_KEY := Vector2i(20, 16)
const SILPH_5F_PAD_TO_3F := Vector2i(11, 5)
const SILPH_3F_DOOR_SIDE := Vector2i(18, 8)
const SILPH_3F_PAD_TO_7F := Vector2i(11, 11)
const LAPRAS_WORKER := Vector2i(1, 5)
const SILPH_7F_PAD_TO_11F := Vector2i(5, 7)
const SILPH_11F_DOOR_SIDE := Vector2i(6, 14)
const GIOVANNI := Vector2i(6, 9)
const PRESIDENT := Vector2i(7, 5)
const SILPH_11F_PAD_TO_7F := Vector2i(3, 2)
const SILPH_7F_PAD_TO_3F := Vector2i(5, 3)
const SILPH_3F_STAIRS_DOWN := Vector2i(26, 0)
const SILPH_2F_STAIRS_DOWN := Vector2i(24, 0)
const SAFFRON_GYM_PADS: Array[Vector2i] = [Vector2i(11, 15), Vector2i(15, 15), Vector2i(15, 5), Vector2i(1, 5)]
const SAFFRON_GYM_LANDINGS: Array[Vector2i] = [Vector2i(19, 17), Vector2i(19, 3), Vector2i(1, 3), Vector2i(11, 11)]
const SABRINA := Vector2i(9, 8)
const FRESH_WATER: int = 0x3C
const CARD_KEY: int = 0x30
const MASTER_BALL: int = 0x01
const LAPRAS_DEX: int = 131
const MARSHBADGE: int = 5
const GAVE_GUARDS_DRINK_BIT: int = 6
const EVENT_GOT_MASTER_BALL: int = 1933
const EVENT_BEAT_SILPH_CO_GIOVANNI: int = 1935
const GIOVANNI_CLASS: int = 29
const SABRINA_CLASS: int = 40
const RIVAL_CLASS: int = 42
const SILPH_LEVEL: int = 52
const SABRINA_LEVEL: int = 54


func _sabrina_legs() -> Array:
	var p: Variant = _played
	var m: Dictionary = SABRINA_MAPS
	var k: Dictionary = KOGA_MAPS
	var drink: Callable = _either(p._holds(FRESH_WATER), p._engine(Gen1Layout.status_flag_1(GAVE_GUARDS_DRINK_BIT)))
	var east_of_gate: Callable = func(world: Gen2WorldAPI) -> bool:
		return world.map_id() == m.route_7 and world.player_cell.x >= ROUTE_7_EAST_DOOR_X
	var legs: Array = [
		["fuchsia_gym_out", p._warp_to(k.fuchsia_city), p._on_map(k.fuchsia_city)],
		["fuchsia_to_route_15", p._cross(Vector2i.RIGHT, k.route_15), p._on_map(k.route_15)],
		["route_15_gate_back", p._walk(ROUTE_15_WEST_DOOR), p._on_map(k.route_15_gate)],
		["route_15_gate_east", p._walk(ROUTE_15_GATE_EAST), p._on_map(k.route_15)],
		["route_15_to_route_14", p._cross(Vector2i.RIGHT, k.route_14), p._on_map(k.route_14)],
		["route_14_to_route_13", _cross_at(ROUTE_14_EAST_EDGE, Vector2i.RIGHT), p._on_map(k.route_13)],
		["route_13_to_route_12", p._cross(Vector2i.UP, k.route_12), p._on_map(k.route_12)],
		["route_12_gate_back", p._walk(ROUTE_12_GATE_SOUTH_DOOR), p._on_map(k.route_12_gate)],
		["route_12_gate_north", p._walk(ROUTE_12_GATE_NORTH), p._on_map(k.route_12)],
		["route_12_to_lavender", p._cross(Vector2i.UP, k.lavender_town), p._on_map(k.lavender_town)],
		["lavender_to_route_8", p._cross(Vector2i.LEFT, m.route_8), p._on_map(m.route_8)],
		["route_8_to_underground", p._walk(ROUTE_8_UNDERGROUND), p._on_map(m.underground_route_8)],
		["underground_east_entrance", p._warp_to(m.underground_west_east), p._on_map(m.underground_west_east)],
		["underground_west_exit", p._warp_to(m.underground_route_7), p._on_map(m.underground_route_7)],
		["underground_to_route_7", p._warp_to(m.route_7), p._on_map(m.route_7)],
		["route_7_to_celadon", p._cross(Vector2i.LEFT, m.celadon_city), p._on_map(m.celadon_city)],
	]
	var floors: Array = [m.celadon_city] + CELADON_MART_FLOORS.map(func(number: int) -> Vector2i: return Vector2i(0, number))
	for floor: int in range(1, floors.size()):
		legs.append(["celadon_mart_up_%d" % floor, p._warp_to(floors[floor]), p._on_map(floors[floor])])
	var meet: Array = _meet_partner("meet_on_the_roof", p._holds(FRESH_WATER))
	meet[1] = func(world: Gen2WorldAPI) -> int: return p._walk(_vending_cell()).call(world)
	legs.append(meet)
	legs.append(["fresh_water", func(world: Gen2WorldAPI) -> int: return p._talk(_vending_cell(), UP).call(world), drink])
	for floor: int in range(floors.size() - 2, -1, -1):
		legs.append(["celadon_mart_down_%d" % floor, p._warp_to(floors[floor]), p._on_map(floors[floor])])
	return legs + [
		["celadon_to_route_7", p._cross(Vector2i.RIGHT, m.route_7), p._on_map(m.route_7)],
		["route_7_gate", p._warp_to(m.route_7_gate), p._on_map(m.route_7_gate)],
		["route_7_gate_east", p._walk(ROUTE_7_GATE_EAST), east_of_gate],
		["route_7_to_saffron", p._cross(Vector2i.RIGHT, m.saffron_city), p._on_map(m.saffron_city)],
	] + _silph_legs() + _saffron_gym_legs()


func _silph_legs() -> Array:
	var p: Variant = _played
	var m: Dictionary = SABRINA_MAPS
	var key: Callable = p._holds(CARD_KEY)
	var giovanni: Callable = p._flag(EVENT_BEAT_SILPH_CO_GIOVANNI)
	var ball: Callable = _either(p._holds(MASTER_BALL), p._flag(EVENT_GOT_MASTER_BALL))
	var legs: Array = [["saffron_to_silph_co", p._warp_to(m.silph_1f), p._on_map(m.silph_1f)], _grind.bind(SILPH_LEVEL, 0)]
	var floors: Array = [m.silph_1f, m.silph_2f, m.silph_3f, m.silph_4f, m.silph_5f]
	for floor: int in SILPH_STAIRS_UP.size():
		legs.append(["silph_%df_to_%df" % [floor + 1, floor + 2], p._walk(SILPH_STAIRS_UP[floor]), p._on_map(floors[floor + 1])])
	return legs + [
		["silph_5f_pad_to_9f", _ride(SILPH_5F_PAD), _either(p._on_map(m.silph_9f), key)],
		["silph_9f_pad_back", _ride(SILPH_9F_PAD), p._on_map(m.silph_5f)],
		["card_key", p._talk(BESIDE_CARD_KEY, Gen2WorldSprite.FACING_RIGHT), key],
		["silph_5f_pad_to_9f_again", _ride(SILPH_5F_PAD), _either(p._on_map(m.silph_9f), _reaches(SILPH_5F_PAD_TO_3F))],
		["silph_9f_pad_back_again", _ride(SILPH_9F_PAD), p._on_map(m.silph_5f)],
		["silph_5f_pad_to_3f", _ride(SILPH_5F_PAD_TO_3F), p._on_map(m.silph_3f)],
		["silph_3f_door", p._talk(SILPH_3F_DOOR_SIDE, Gen2WorldSprite.FACING_LEFT), _open(SILPH_3F_DOOR_SIDE + Vector2i.LEFT)],
		["silph_3f_pad_to_7f", _ride(SILPH_3F_PAD_TO_7F), p._on_map(m.silph_7f)],
		["lapras", p._talk_to(LAPRAS_WORKER), _has_lapras],
		["silph_7f_pad_to_11f", _ride(SILPH_7F_PAD_TO_11F), p._on_map(m.silph_11f)],
		_meet_to_join("meet_on_silph_11f", GIOVANNI_CLASS, giovanni),
		["silph_11f_door", _join_or(GIOVANNI_CLASS, p._talk(SILPH_11F_DOOR_SIDE, UP)),
			_either(_open(SILPH_11F_DOOR_SIDE + Vector2i.UP), ball)],
		["giovanni", _join_or(GIOVANNI_CLASS, p._talk_to(GIOVANNI)), giovanni],
		["master_ball", p._talk_to(PRESIDENT), ball],
		["silph_11f_pad_to_7f", _ride(SILPH_11F_PAD_TO_7F), p._on_map(m.silph_7f)],
		["silph_7f_pad_to_3f", _ride(SILPH_7F_PAD_TO_3F), p._on_map(m.silph_3f)],
		["silph_3f_to_2f", p._walk(SILPH_3F_STAIRS_DOWN), p._on_map(m.silph_2f)],
		["silph_2f_to_1f", p._walk(SILPH_2F_STAIRS_DOWN), p._on_map(m.silph_1f)],
		["silph_co_exit", p._warp_to(m.saffron_city), p._on_map(m.saffron_city)],
	]


func _saffron_gym_legs() -> Array:
	var p: Variant = _played
	var marsh: Callable = _badge(MARSHBADGE)
	var legs: Array = [
		_grind.bind(SABRINA_LEVEL, 0),
		["saffron_gym", p._warp_to(SABRINA_MAPS.saffron_gym), p._on_map(SABRINA_MAPS.saffron_gym)],
		_meet_to_join("meet_in_saffron_gym", SABRINA_CLASS, marsh),
	]
	for pad: int in SAFFRON_GYM_PADS.size():
		legs.append(["saffron_gym_pad_%d" % (pad + 1), _join_or(SABRINA_CLASS, _ride(SAFFRON_GYM_PADS[pad])),
			_either(p._at(SAFFRON_GYM_LANDINGS[pad]), marsh)])
	return legs + [["sabrina", _join_or(SABRINA_CLASS, p._talk_to(SABRINA)), marsh], _sabrina_done]


func _ride(pad: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> int:
		if world.player_cell != pad:
			return _played._walk(pad).call(world)
		for direction: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
			var off: Vector2i = pad + direction
			if not world.step_blocked_from(pad, direction) and world.can_walk_to(off) and world.warp_at(off).is_empty():
				return _played._direction_button(direction)
		return PokeButton.NONE


func _meet_to_join(label: String, trainer_class: int, or_done: Callable) -> Array:
	var row: Array = _meet_partner(label, or_done)
	row[1] = _join_or(trainer_class, _standing)
	return row


func _join_or(trainer_class: int, goal: Callable) -> Callable:
	return func(world: Gen2WorldAPI) -> int:
		for running: Dictionary in _session.client.state.get("battles", []):
			var encounter: String = String(running.get("encounter", ""))
			if encounter.begins_with("trainer:%d:" % trainer_class) and not (running["participants"] as Array).has(_session.client.player_id):
				return _join_button(encounter)
		return goal.call(world)


func _reaches(cell: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> bool:
		return world.player_cell == cell or _played._step_toward(world, _played._is(cell)) != PokeButton.NONE


func _open(door: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> bool: return world.can_walk_to(door)


func _vending_cell() -> Vector2i:
	var ids: Array = (_session.client.state.get("players", {}) as Dictionary).keys()
	ids.sort()
	return BELOW_VENDING_MACHINES[clampi(ids.find(_session.client.player_id), 0, BELOW_VENDING_MACHINES.size() - 1)]


func _has_lapras(_world: Gen2WorldAPI) -> bool:
	return _played._screen.active_save().party.any(func(mon: Gen2SaveMon) -> bool: return mon.species == LAPRAS_DEX)


func _sabrina_done() -> bool:
	var world: Gen2WorldAPI = _played._screen.world()
	var me: Dictionary = _session.client.me()
	var rows: Array = (me.get("party", []) as Array) + (_session.client.box.get("rows", []) as Array)
	var laprases: Array = rows.filter(func(row: Dictionary) -> bool: return int(row["mon"]["species"]) == LAPRAS_DEX)
	var missing: PackedStringArray = []
	if not bool(_badge(MARSHBADGE).call(world)):
		missing.append("MARSHBADGE")
	if world.state.item_quantity(MASTER_BALL) != 1 or int((me.get("items", {}) as Dictionary).get(MASTER_BALL, 0)) != 1:
		missing.append("one MASTER BALL")
	if laprases.size() != 1 or not String(laprases[0]["uid"]).begins_with(_session.client.player_id + ":") \
			or not _has_lapras(world):
		missing.append("own LAPRAS")
	var defeated: Array = (_session.client.state.get("campaign", {}) as Dictionary).get("defeated", [])
	print("coop autoplay: %s after SABRINA: badges %d, team on host %s, MASTER BALLs %d, beaten %s, missing %s" % [
		_player_id, world.state.badge_count(), rows.map(func(row: Dictionary) -> String: return "%s %d" % [
			row["uid"], int(row["mon"]["species"])]), world.state.item_quantity(MASTER_BALL),
		defeated.filter(func(id: String) -> bool: return [GIOVANNI_CLASS, SABRINA_CLASS, RIVAL_CLASS].any(
			func(trainer_class: int) -> bool: return id.begins_with("trainer:%d:" % trainer_class))),
		missing])
	return missing.is_empty()


func _either(first: Callable, second: Callable) -> Callable:
	return func(world: Gen2WorldAPI) -> bool: return bool(first.call(world)) or bool(second.call(world))


func _meet_partner(label: String, or_done: Callable) -> Array:
	return [label, _standing, _either(func(_world: Gen2WorldAPI) -> bool: return not _session.client.nearby().is_empty(), or_done)]


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
		if _direction != button or not PokeButton.held(button):
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
	if _leg < _legs.size() and _legs[_leg] is Array and _legs[_leg][1] == _standing:
		now += str(_session.client.state.get("players", {}))
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
