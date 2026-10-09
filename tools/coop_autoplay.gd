extends "res://tools/coop_play.gd"

## A co-op window that plays itself with `tools/checks/played.gd`'s legs, fighting from the panel; prints "... finished" or "FAILED":
##   Godot --path . -s res://tools/coop_autoplay.gd -- <address> [port] <player_id> [game] [opening] [route=brock|misty|trade|surge|erika|tower|koga|sabrina|blaine|victory|elite|watch_brock] [from=<leg>[#<n>]|finished] [speed=1..4] [ball=0..2] [shots=<dir>, also <dir>/<player>_texts.tsv: every text shown]

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
	"erika": [&"_misty_legs", &"_surge_legs", &"_erika_legs"],
	"tower": [&"_misty_legs", &"_surge_legs", &"_erika_legs", &"_tower_legs"],
	"koga": [&"_misty_legs", &"_surge_legs", &"_erika_legs", &"_tower_legs", &"_koga_legs"],
	"sabrina": [&"_misty_legs", &"_surge_legs", &"_erika_legs", &"_tower_legs", &"_koga_legs", &"_sabrina_legs"],
	"blaine": [&"_misty_legs", &"_surge_legs", &"_erika_legs", &"_tower_legs", &"_koga_legs", &"_sabrina_legs", &"_blaine_legs"],
	"victory": [&"_misty_legs", &"_surge_legs", &"_erika_legs", &"_tower_legs", &"_koga_legs", &"_sabrina_legs",
		&"_blaine_legs", &"_victory_legs"],
	"elite": [&"_misty_legs", &"_surge_legs", &"_erika_legs", &"_tower_legs", &"_koga_legs", &"_sabrina_legs",
		&"_blaine_legs", &"_victory_legs", &"_elite_legs"],
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
const CAR_ASIDE := Vector2i(3, 3)
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
var _texts: FileAccess = null
var _last_text: Dictionary = {}
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
var _filmed: Dictionary = {}
var _car_floor: int = -1
var _whiteout: bool = false
var _losing: bool = false
var _partner_lost: bool = false
var _labels: Array = []
var _skipped: int = 0
var _noting: String = ""
var _noted: String = ""
var _rested: int = 0


func _read_option(arg: String) -> bool:
	for option: String in ["route=", "from=", "speed=", "ball=", "shots=", "whiteout="]:
		if arg.begins_with(option):
			var value: String = arg.trim_prefix(option)
			match option:
				"route=": _route = value
				"from=": _from = value
				"speed=": _speed = clampf(value.to_float(), 1.0, float(Gen2WorldAnimation.MAX_CATCHUP_FRAMES))
				"ball=": _ball = clampi(value.to_int(), 0, 2)
				"shots=": _shots = value if not PokeToolPath.refuses(value) else ""
				"whiteout=": _whiteout = value == "1"
			return true
	return super(arg)


func _process(delta: float) -> bool:
	super(delta)
	if _session != null and _session.is_ready():
		_note_leg()
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
	_dump_texts()
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
		_film_battle(_session.panel.battle_view())
		return _panel_button(_session.panel)
	if _played._screen != screen:
		_played._screen = screen
		_played._editor = Gen2SaveEditor.new()
		_played._editor.data = _session.data
		_legs = _route_legs()
		_leg_started = Time.get_ticks_msec()
	_played._editor.save = screen.active_save()
	_watch_hall_of_fame(screen)
	if screen.get("_link_host") != null:
		return _link_button(screen)
	_hide_wait_box_left_over_the_link_room(screen)
	if _frames % 60 == 0 and not _losing and screen.active_save().party.any(_worn):
		_heal(screen)
	if _frames % 60 == 30:
		_box_with_room(screen.active_save())
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
	if String(view.get("encounter", "")).begins_with("trainer:") and panel._controls(view) and not _filmed.has(view["battle"]):
		_filmed[view["battle"]] = true
		_shot("battle_%s_%s" % [view["battle"], String(view.get("trainer_name", "")).to_lower().validate_filename()])
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
	var enemy: Array = _session.data.species(int((view.get("enemy", {}) as Dictionary).get("species", 0))).get("types", [])
	for index: int in rows.size():
		var command: Dictionary = (rows[index] as Dictionary).get("command", {})
		if String(command.get("type", "")) != wanted:
			continue
		if wanted != "move":
			return index
		var slot: int = int(command["slot"])
		var usable: bool = int((active.get("pp", []) as Array)[slot]) > 0 and slot != int(active.get("disabled", -1))
		var move: Dictionary = _session.data.move(int(active["moves"][slot]))
		var power: int = int(move.get("power", 0)) * _session.data.type_effectiveness(int(move.get("type", 0)), enemy) if usable else -1
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
	if _seconds_since(_leg_started) > LEG_SECONDS and row[1] != _standing:
		return _fail("%s took longer than %d s: %s" % [row[0], LEG_SECONDS, _played._where()])
	var car: int = _elevator_button(screen) if _answer < 0 else _quiz_button(screen)
	return car if car >= 0 else _played._button_for(row[1])


func _route_legs() -> Array:
	var legs: Array = _opening_legs() + _brock_legs()
	for stretch: StringName in ROUTES.get(_route, []):
		legs += call(stretch)
	_labels = _leg_labels(legs)
	if _from.is_empty():
		return legs
	var start: int = legs.size() if _from == "finished" else _labels.find(_from)
	if start < 0:
		_fail("route %s has no leg %s" % [_route, _from])
	while start > 0 and legs[start - 1] is Callable and String((legs[start - 1] as Callable).get_method()).begins_with("_note_"):
		start -= 1
	_skipped = maxi(start, 0)
	return legs.slice(_skipped)


static func _leg_labels(legs: Array) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for leg: Variant in legs:
		var name: String = String(leg[0]) if leg is Array else ""
		seen[name] = int(seen.get(name, 0)) + 1
		out.append(name if seen[name] == 1 or name.is_empty() else "%s#%d" % [name, seen[name]])
	return out


## The running leg reaches the host after the world it starts from: once the link has rested since it began.
func _note_leg() -> void:
	var link: PokeCoopWorldLink = _session.link
	var leg: String = _running_leg()
	if leg != _noting:
		_noting = leg
		_rested = 0
	_rested = _rested + 1 if link != null and link._rest_streak >= PokeCoopWorldLink.REST_FRAMES else 0
	if _noting.is_empty() or _noting == _noted or _rested <= PokeCoopWorldLink.REST_FRAMES:
		return
	if not link.hold_holdings and link._is_free():
		link.push_party()
	_session.client.note(_noting)
	_noted = _noting


func _running_leg() -> String:
	if _played == null or _played._screen == null:
		return ""
	for at: int in range(_leg, _legs.size()):
		if _legs[at] is Array:
			return _labels[at + _skipped]
	return "finished"


func _opening_legs() -> Array:
	var p: Variant = _played
	var game: StringName = _session.data.id
	if String((_session.client.me().get("opening", {}) as Dictionary).get("stage", "")).is_empty():
		return []
	return [
		["bedroom_to_1f", p._warp_to(_kit.REDS_HOUSE_1F), p._on_map(_kit.REDS_HOUSE_1F)],
		["house_to_pallet", p._warp_to(_kit.PALLET_TOWN), p._on_map(_kit.PALLET_TOWN)],
		["north_path_to_lab", p._walk(RomRegistry.pick(_kit.PALLET_NORTH_PATH, game)), p._on_map(_kit.OAKS_LAB)],
		["starter", p._talk(RomRegistry.pick(_kit.LAB_STARTER_BALLS, game) + Vector2i(_ball, 0), UP), p._flag(_kit.EVENT_GOT_STARTER)],
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
	var fossil: Callable = p._flag(RomRegistry.pick(_kit.EVENT_GOT_DOME_FOSSIL, _session.data.id))
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
	_party_with(_learns.bind([Gen2WorldFieldMove.MOVE_CUT]))
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
		["elevator_panel", _car_panel(m.hideout_b4f), _car_bound_for(m.hideout_b4f)],
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


func _car_panel(map: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> int:
		_car_floor = map.y
		if (world.player_cell != CAR_PANEL_FRONT or _order() > 0) and bool(_partner_near(world.map_id(), CAR_PANEL_FRONT, 0).call(world)):
			return _played._walk(CAR_ASIDE).call(world)
		return _played._talk(CAR_PANEL_FRONT, UP).call(world)


func _elevator_button(screen: Gen2WorldScreen) -> int:
	var host: Gen2WorldServiceScreen = screen.get("_service_host")
	if host == null or int(host.get("_mode")) != Gen2WorldServiceScreen.MODE.ELEVATOR or bool(host.call(&"_box_printing")):
		return -1
	var floors: Array = host.call(&"_elevator_floors")
	var wanted: int = floors.find_custom(func(row: Dictionary) -> bool: return int(row["map"]) == _car_floor)
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


const TOWER_MAPS: Dictionary = {
	&"hideout_b1f": Vector2i(0, 199), &"hideout_elevator": Vector2i(0, 203), &"game_corner": Vector2i(0, 135),
	&"celadon_city": Vector2i(0, 6), &"route_7": Vector2i(0, 18), &"underground_route_7": Vector2i(0, 77),
	&"underground_west_east": Vector2i(0, 121), &"underground_route_8": Vector2i(0, 80), &"route_8": Vector2i(0, 19),
	&"lavender_town": Vector2i(0, 4), &"tower_1f": Vector2i(0, 142), &"tower_2f": Vector2i(0, 143),
	&"tower_3f": Vector2i(0, 144), &"tower_4f": Vector2i(0, 145), &"tower_5f": Vector2i(0, 146),
	&"tower_6f": Vector2i(0, 147), &"tower_7f": Vector2i(0, 148), &"mr_fujis_house": Vector2i(0, 149),
}
const HIDEOUT_B1F_DOOR_ROCKET := Vector2i(28, 18)
const TOWER_RIVAL_CELLS: Array = [Vector2i(14, 6), Vector2i(15, 5)]
const ABOVE_RARE_CANDY := Vector2i(6, 7)
const RARE_CANDY_GAP: Array = [ABOVE_RARE_CANDY, Vector2i(6, 8), Vector2i(6, 9)]
const MAROWAK_CELL := Vector2i(10, 16)
const MR_FUJI := Vector2i(10, 3)
const BELOW_MR_FUJI_HOME := Vector2i(3, 2)
const RARE_CANDY: int = 0x28
const POKE_FLUTE: int = 0x49
const MAROWAK: int = 105
const TOWER_LEVEL: int = 46
const EVENT_BEAT_HIDEOUT_B1F_DOOR_ROCKET: int = 0x675
const EVENT_BEAT_POKEMON_TOWER_RIVAL: int = 0xEF
const EVENT_BEAT_GHOST_MAROWAK: int = 0x10F
const EVENT_GOT_POKE_FLUTE: int = 0x128
const EVENT_RESCUED_MR_FUJI: int = 0x4CF


func _tower_legs() -> Array:
	var p: Variant = _played
	var m: Dictionary = TOWER_MAPS
	var rival: Callable = p._flag(EVENT_BEAT_POKEMON_TOWER_RIVAL)
	var marowak: Callable = p._flag(EVENT_BEAT_GHOST_MAROWAK)
	return [
		["hideout_b4f_elevator", p._warp_to(m.hideout_elevator), p._on_map(m.hideout_elevator)],
		_grind.bind(TOWER_LEVEL, 0),
		["hideout_elevator_panel", _car_panel(m.hideout_b1f), _car_bound_for(m.hideout_b1f)],
		["hideout_elevator_to_b1f", p._walk(CAR_DOOR), p._on_map(m.hideout_b1f)],
		["hideout_b1f_door_rocket", p._talk_to(HIDEOUT_B1F_DOOR_ROCKET), p._flag(EVENT_BEAT_HIDEOUT_B1F_DOOR_ROCKET)],
		["hideout_b1f_to_game_corner", p._warp_to(m.game_corner), p._on_map(m.game_corner)],
		["game_corner_exit", p._warp_to(m.celadon_city), p._on_map(m.celadon_city)],
		["celadon_to_route_7", p._cross(Vector2i.RIGHT, m.route_7), p._on_map(m.route_7)],
		["route_7_to_underground", p._warp_to(m.underground_route_7), p._on_map(m.underground_route_7)],
		["underground_west_entrance", p._warp_to(m.underground_west_east), p._on_map(m.underground_west_east)],
		["underground_east_exit", p._warp_to(m.underground_route_8), p._on_map(m.underground_route_8)],
		["underground_to_route_8", p._warp_to(m.route_8), p._on_map(m.route_8)],
		["route_8_to_lavender", p._cross(Vector2i.RIGHT, m.lavender_town), p._on_map(m.lavender_town)],
		["lavender_to_tower", p._warp_to(m.tower_1f), p._on_map(m.tower_1f)],
		["tower_1f_to_2f", p._warp_to(m.tower_2f), p._on_map(m.tower_2f)],
		_meet_partner("meet_on_tower_2f", rival),
		["tower_2f_rival", func(world: Gen2WorldAPI) -> int: return p._walk(TOWER_RIVAL_CELLS[_order()]).call(world), rival],
		["tower_2f_to_3f", p._warp_to(m.tower_3f), p._on_map(m.tower_3f)],
		["tower_3f_to_4f", p._warp_to(m.tower_4f), p._on_map(m.tower_4f)],
		["tower_4f_to_5f", p._warp_to(m.tower_5f), p._on_map(m.tower_5f)],
		["tower_5f_to_6f", p._warp_to(m.tower_6f), p._on_map(m.tower_6f)],
		["tower_6f_rare_candy", p._talk(ABOVE_RARE_CANDY, Gen2WorldSprite.FACING_DOWN), p._holds(RARE_CANDY)],
		_meet_partner("meet_on_tower_6f", marowak),
		["tower_6f_marowak", _marowak_button.bind(p._walk(MAROWAK_CELL)), marowak],
		["tower_6f_marowak_gone", p._walk(MAROWAK_CELL), p._at(MAROWAK_CELL)],
		["tower_6f_to_7f", p._warp_to(m.tower_7f), p._on_map(m.tower_7f)],
		["tower_7f_mr_fuji", p._talk_to(MR_FUJI), _either(p._on_map(m.mr_fujis_house), p._flag(EVENT_RESCUED_MR_FUJI))],
		["to_mr_fujis_house", p._route(m.mr_fujis_house), p._on_map(m.mr_fujis_house)],
		["poke_flute", p._talk(BELOW_MR_FUJI_HOME, UP), _either(p._holds(POKE_FLUTE), p._flag(EVENT_GOT_POKE_FLUTE))],
		["poke_flute_on_host", _standing, func(world: Gen2WorldAPI) -> bool: return p._holds(POKE_FLUTE).call(world) and _hosted(POKE_FLUTE) > 0],
		_flute_once,
	]


func _order() -> int:
	var ids: Array = (_session.client.state.get("players", {}) as Dictionary).keys()
	ids.sort()
	return maxi(ids.find(_session.client.player_id), 0)


func _marowak_button(world: Gen2WorldAPI, walk: Callable) -> int:
	var running: Array = _session.client.state.get("battles", [])
	var at: int = running.find_custom(func(row: Dictionary) -> bool: return int(row["enemy"]) == MAROWAK)
	if at >= 0 and not (running[at]["participants"] as Array).has(_session.client.player_id):
		_joining = String(running[at]["battle"])
		return _paced(PokeButton.SELECT)
	if _order() == 0:
		return walk.call(world) if at < 0 else PokeButton.NONE
	return _played._step_toward(world, func(at: Vector2i) -> bool: return not RARE_CANDY_GAP.has(at))


func _flute_once() -> bool:
	var held: int = _played._screen.world().state.item_quantity(POKE_FLUTE)
	print("coop autoplay: %s holds %d POKé FLUTE, %d on the host" % [_player_id, held, _hosted(POKE_FLUTE)])
	return held == 1 and _hosted(POKE_FLUTE) == 1


func _hosted(item: int) -> int:
	return int((_session.client.me().get("items", {}) as Dictionary).get(item, 0))


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
var _safari_retried: bool = false


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
	var wanted: String = _joining if not _joining.is_empty() else _partner_fight()
	var row: int = panel._rows.find_custom(func(entry: Dictionary) -> bool:
		return String(entry.get("action", "")) == "join" and String(entry.get("id", "")) == wanted)
	if wanted.is_empty() or row < 0:
		return _paced(PokeButton.B)
	var press: int = _paced(PokeButton.A if panel._cursor == row else PokeButton.DOWN)
	if press == PokeButton.A:
		print("coop autoplay: %s joins %s from the session menu" % [_player_id, wanted])
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
	return _host_team().size()


func _host_team() -> Array:
	return (_session.client.me().get("party", []) as Array) + (_session.client.box.get("rows", []) as Array)


func _caught_on_host(_world: Gen2WorldAPI) -> bool:
	if _safari_team < 0 or _host_team_size() <= _safari_team:
		return false
	_safari_caught = true
	var rows: Array = _host_team()
	print("coop autoplay: %s caught in the Safari Zone, on the host: %s" % [
		_player_id, rows.map(func(row: Dictionary) -> String: return "%s %d" % [row["uid"], int(row["mon"]["species"])])])
	return true


func _walk_grass(world: Gen2WorldAPI) -> int:
	if not world.gen1_safari_active():
		if not _safari_retried:
			_safari_retried = true
			print("coop autoplay: %s Safari Game over with no catch, paying again" % _player_id)
		return _played._walk(SAFARI_GATE_OFFER).call(world) if world.map_id() == KOGA_MAPS.safari_gate \
			else _played._warp_to(KOGA_MAPS.safari_gate).call(world)
	_safari_retried = false
	var here: Vector2i = world.player_cell
	return _played._step_toward(world, func(at: Vector2i) -> bool: return at != here and world.can_encounter_wild_mon_at(at))


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
const SILPH_GIOVANNI := Vector2i(6, 9)
const PRESIDENT := Vector2i(7, 5)
const SILPH_11F_PAD_TO_7F := Vector2i(3, 2)
const SILPH_7F_PAD_TO_3F := Vector2i(5, 3)
const SILPH_3F_STAIRS_DOWN := Vector2i(26, 0)
const SILPH_2F_STAIRS_DOWN := Vector2i(24, 0)
const SAFFRON_GYM_PADS: Array[Vector2i] = [Vector2i(11, 15), Vector2i(15, 15), Vector2i(15, 5), Vector2i(1, 5)]
const SAFFRON_GYM_LANDINGS: Array[Vector2i] = [Vector2i(19, 17), Vector2i(19, 3), Vector2i(1, 3), Vector2i(11, 11)]
const SABRINA := Vector2i(9, 8)
const SABRINA_ROOM_REACH: int = 5
const FRESH_WATER: int = 0x3C
const CARD_KEY: int = 0x30
const MASTER_BALL: int = 0x01
const LAPRAS_DEX: int = 131
const FIELD_MOVES: Array[int] = [Gen2WorldFieldMove.MOVE_CUT, Gen2WorldFieldMove.MOVE_SURF, Gen2WorldFieldMove.MOVE_STRENGTH]
const MARSHBADGE: int = 5
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
	var gate_open: Callable = p._engine(Gen1Layout.status_flag_1(PokeCoopOwnership.SAFFRON_DRINK_BIT))
	var bought: Callable = func(world: Gen2WorldAPI) -> bool: return not _partner_on(world.map_id())
	var partner_in_gate: Callable = func(_world: Gen2WorldAPI) -> bool: return _partner_on(m.route_7_gate)
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
	var drinker: bool = _order() == 0
	if drinker:
		legs.append(["fresh_water", p._talk(_vending_cell(), UP), _either(p._holds(FRESH_WATER), gate_open)])
	else:
		legs += [["fresh_water", p._walk(_vending_cell()), _either(p._at(_vending_cell()), bought)],
			["fresh_water_bought", _standing, bought]]
	for floor: int in range(floors.size() - 2, -1, -1):
		legs.append(["celadon_mart_down_%d" % floor, p._warp_to(floors[floor]), p._on_map(floors[floor])])
	return legs + [
		["celadon_to_route_7", p._cross(Vector2i.RIGHT, m.route_7), p._on_map(m.route_7)],
		["route_7_gate", p._warp_to(m.route_7_gate), p._on_map(m.route_7_gate)],
	] + ([["route_7_gate_partner", _standing, _either(partner_in_gate, gate_open)]] if drinker else []) + [
		["route_7_gate_drink", p._walk(ROUTE_7_GATE_EAST) if drinker else _standing, _either(gate_open, east_of_gate)],
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
		["lapras", _join_or(p._talk_to(LAPRAS_WORKER)), func(_world: Gen2WorldAPI) -> bool: return _owns(LAPRAS_DEX)],
		["silph_7f_pad_to_11f", _join_or(_ride(SILPH_7F_PAD_TO_11F)), p._on_map(m.silph_11f)],
		_meet_to_join("meet_on_silph_11f", giovanni),
		["silph_11f_door", _join_or(p._talk(SILPH_11F_DOOR_SIDE, UP)),
			_either(_open(SILPH_11F_DOOR_SIDE + Vector2i.UP), ball)],
		["giovanni", _join_or(p._talk_to(SILPH_GIOVANNI)), giovanni],
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
		_meet_to_join("meet_in_saffron_gym", marsh),
	]
	for pad: int in SAFFRON_GYM_PADS.size():
		legs.append(["saffron_gym_pad_%d" % (pad + 1), _join_or(_ride(SAFFRON_GYM_PADS[pad])),
			_either(p._at(SAFFRON_GYM_LANDINGS[pad]), marsh)])
	return legs + [
		["meet_before_sabrina", _join_or(_standing), _either(_partner_near(SABRINA_MAPS.saffron_gym, SABRINA, SABRINA_ROOM_REACH), marsh)],
		["sabrina", _join_or(p._talk_to(SABRINA)), marsh], _sabrina_done,
	]


func _ride(pad: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> int:
		if world.player_cell != pad:
			return _played._walk(pad).call(world)
		for direction: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
			var off: Vector2i = pad + direction
			if not world.step_blocked_from(pad, direction) and world.can_walk_to(off) and world.warp_at(off).is_empty():
				return _played._direction_button(direction)
		return PokeButton.NONE


func _meet_to_join(label: String, or_done: Callable) -> Array:
	var row: Array = _meet_partner(label, or_done)
	row[1] = _join_or(_standing)
	return row


func _reaches(cell: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> bool:
		return world.player_cell == cell or _played._step_toward(world, _played._is(cell)) != PokeButton.NONE


func _open(door: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> bool: return world.can_walk_to(door)


func _vending_cell() -> Vector2i:
	var ids: Array = (_session.client.state.get("players", {}) as Dictionary).keys()
	ids.sort()
	return BELOW_VENDING_MACHINES[clampi(ids.find(_session.client.player_id), 0, BELOW_VENDING_MACHINES.size() - 1)]


func _owns(species: int) -> bool:
	var save: Gen2SaveData = _played._screen.active_save()
	var mons: Array = save.party.duplicate()
	for box: Gen2SaveBox in save.boxes:
		mons.append_array(box.slots.filter(func(mon: Variant) -> bool: return mon != null))
	return mons.any(func(mon: Gen2SaveMon) -> bool: return mon.species == species)


func _box_with_room(save: Gen2SaveData) -> void:
	if bool(save.deposit_box_slot().get("ok", false)):
		return
	var at: int = save.boxes.find_custom(func(box: Gen2SaveBox) -> bool: return box.first_empty_slot() >= 0)
	if at >= 0:
		save.current_box = at
		print("coop autoplay: %s changed to box %d, the current one is full" % [_player_id, at + 1])


func _room() -> bool:
	var save: Gen2SaveData = _played._screen.active_save()
	_box_with_room(save)
	var at: Dictionary = save.deposit_box_slot()
	if save.party.size() < Gen2SaveData.MAX_PARTY:
		return true
	if not bool(at.get("ok", false)):
		return false
	var spare: int = save.party.size() - 1
	while spare > 1 and FIELD_MOVES.any(func(move: int) -> bool: return (save.party[spare] as Gen2SaveMon).moves.has(move)):
		spare -= 1
	var mon: Gen2SaveMon = save.party.pop_at(spare)
	(save.boxes[int(at["box"])] as Gen2SaveBox).put(mon, int(at["slot"]))
	Gen2SaveStorage.deposited(_session.data, mon)
	print("coop autoplay: %s boxed %d for room in the party" % [_player_id, mon.species])
	_played._screen.call(&"_refresh_party_summary")
	return true


func _party_with(fits: Callable) -> bool:
	var save: Gen2SaveData = _played._screen.active_save()
	if save.party.any(fits):
		return true
	for box: Gen2SaveBox in save.boxes:
		var at: int = box.slots.find_custom(func(mon: Variant) -> bool: return mon != null and bool(fits.call(mon)))
		if at >= 0 and _room():
			var mon: Gen2SaveMon = box.take(at)
			save.party.append(mon)
			mon.calc_stats(_session.data)
			print("coop autoplay: %s took %d from the PC box" % [_player_id, mon.species])
			_played._screen.call(&"_refresh_party_summary")
			return true
	return false


func _learns(mon: Gen2SaveMon, moves: Array) -> bool:
	return moves.all(func(move: int) -> bool: return Gen2WorldTMHM.can_learn(_session.data, mon.species, move))


func _sabrina_done() -> bool:
	var world: Gen2WorldAPI = _played._screen.world()
	var me: Dictionary = _session.client.me()
	var rows: Array = _host_team()
	var laprases: Array = rows.filter(func(row: Dictionary) -> bool: return int(row["mon"]["species"]) == LAPRAS_DEX)
	var missing: PackedStringArray = []
	if not bool(_badge(MARSHBADGE).call(world)):
		missing.append("MARSHBADGE")
	if world.state.item_quantity(MASTER_BALL) != 1 or int((me.get("items", {}) as Dictionary).get(MASTER_BALL, 0)) != 1:
		missing.append("one MASTER BALL")
	if laprases.size() != 1 or not String(laprases[0]["uid"]).begins_with(_session.client.player_id + ":") \
			or not _owns(LAPRAS_DEX):
		missing.append("own LAPRAS")
	var defeated: Array = (_session.client.state.get("campaign", {}) as Dictionary).get("defeated", [])
	print("coop autoplay: %s after SABRINA: badges %d, team on host %s, MASTER BALLs %d, beaten %s, missing %s" % [
		_player_id, world.state.badge_count(), rows.map(func(row: Dictionary) -> String: return "%s %d" % [
			row["uid"], int(row["mon"]["species"])]), world.state.item_quantity(MASTER_BALL),
		defeated.filter(func(id: String) -> bool: return [GIOVANNI_CLASS, SABRINA_CLASS, RIVAL_CLASS].any(
			func(trainer_class: int) -> bool: return id.begins_with("trainer:%d:" % trainer_class))),
		missing])
	return missing.is_empty()


const BLAINE_MAPS: Dictionary = {
	&"saffron_gym": Vector2i(0, 178), &"saffron_city": Vector2i(0, 10), &"route_8": Vector2i(0, 19),
	&"route_8_gate": Vector2i(0, 79), &"route_19": Vector2i(0, 30), &"route_20": Vector2i(0, 31),
	&"seafoam_1f": Vector2i(0, 192), &"seafoam_b1f": Vector2i(0, 159), &"seafoam_b2f": Vector2i(0, 160),
	&"seafoam_b3f": Vector2i(0, 161), &"seafoam_b4f": Vector2i(0, 162), &"cinnabar_island": Vector2i(0, 8),
	&"mansion_1f": Vector2i(0, 165), &"mansion_2f": Vector2i(0, 214), &"mansion_3f": Vector2i(0, 215),
	&"mansion_b1f": Vector2i(0, 216), &"cinnabar_lab": Vector2i(0, 167), &"fossil_room": Vector2i(0, 170),
	&"cinnabar_gym": Vector2i(0, 166),
}
const SAFFRON_GYM_PADS_OUT: Array[Vector2i] = [Vector2i(11, 11), Vector2i(5, 5), Vector2i(5, 11), Vector2i(5, 15), Vector2i(19, 17)]
const ROUTE_8_GATE_WEST := Vector2i(1, 10)
const ROUTE_8_GATE_EAST := Vector2i(5, 3)
const ROUTE_19_SHORE := Vector2i(8, 9)
const ROUTE_20_NORTH_FIELD := Vector2i(61, 3)
const ROUTE_20_SEAFOAM_WEST := Vector2i(48, 5)
const ROUTE_20_EAST_BEACH := Vector2i(58, 11)
## upstream's GEN1_SEAFOAM_PUZZLE as rows [kind, label, cell, direction or map, pushes or still surfing, hole flag]; the partner walks the calm way.
const SEAFOAM_PUZZLE: Array = [
	["strength", "seafoam_1f_strength"],
	["push", "seafoam_1f_boulder_1_up", Vector2i(18, 11), Vector2i.UP, 4],
	["push", "seafoam_1f_boulder_1_into_hole", Vector2i(19, 6), Vector2i.LEFT, 1, 1294],
	["push", "seafoam_1f_boulder_2_left", Vector2i(27, 7), Vector2i.LEFT, 2],
	["push", "seafoam_1f_boulder_2_into_hole", Vector2i(24, 8), Vector2i.UP, 1, 1295],
	["warp", "seafoam_1f_east_ladder", Vector2i(25, 3), 159],
	["push", "seafoam_b1f_boulder_2_into_hole", Vector2i(21, 6), Vector2i.RIGHT, 1, 2497],
	["warp", "seafoam_b1f_east_ladder_up", Vector2i(25, 3), 192],
	["warp", "seafoam_1f_to_b1f", Vector2i(7, 5), 159],
	["push", "seafoam_b1f_boulder_1_into_hole", Vector2i(16, 6), Vector2i.RIGHT, 1, 2496],
	["warp", "seafoam_b1f_northwest_ladder", Vector2i(4, 2), 160],
	["push", "seafoam_b2f_boulder_1_into_hole", Vector2i(17, 6), Vector2i.RIGHT, 1, 2504],
	["warp", "seafoam_b2f_northwest_ladder_up", Vector2i(5, 3), 159],
	["warp", "seafoam_b1f_to_b2f", Vector2i(13, 7), 160],
	["warp", "seafoam_b2f_to_b3f", Vector2i(5, 13), 161],
	["surf", "seafoam_b3f_current", Vector2i(15, 7), 162, false],
	["walk", "seafoam_b4f_pool_stairs", Vector2i(23, 5)],
	["warp", "seafoam_b4f_pocket_ladder", Vector2i(25, 4), 161],
	["warp", "seafoam_b3f_pocket_ladder", Vector2i(25, 3), 160],
	["push", "seafoam_b2f_boulder_2_into_hole", Vector2i(24, 6), Vector2i.LEFT, 1, 2505],
	["warp", "seafoam_b2f_pocket_ladder_down", Vector2i(25, 3), 161],
	["warp", "seafoam_b3f_pocket_down", Vector2i(25, 4), 162],
	["surf", "seafoam_b4f_surf_back", Vector2i(23, 5), 162, true],
	["warp", "seafoam_b4f_to_b3f", Vector2i(20, 17), 161],
]
const SEAFOAM_CALM_WAY: Array = [
	["warp", "seafoam_1f_west_ladder", Vector2i(7, 5), 159],
	["warp", "seafoam_b1f_west_ladder", Vector2i(13, 7), 160],
	["warp", "seafoam_b2f_west_ladder", Vector2i(5, 13), 161],
	["surf", "seafoam_b3f_calm_water", Vector2i(15, 7), 161, true],
]
const SEAFOAM_WAY_OUT: Array = [
	["walk", "seafoam_b3f_east_bank", Vector2i(23, 9)],
	["warp", "seafoam_b3f_to_b2f", Vector2i(25, 14), 160],
	["warp", "seafoam_b2f_to_b1f", Vector2i(25, 11), 159],
	["warp", "seafoam_b1f_to_1f", Vector2i(23, 15), 192],
	["warp", "seafoam_east_door", Vector2i(26, 17), 31],
]
const EVENT_SEAFOAM3_BOULDERS: Array[int] = [2504, 2505]
const CINNABAR_SHORE := Vector2i(19, 13)
const MANSION_SWITCHES: Dictionary = {
	&"3f": Vector2i(10, 6), &"b1f_south": Vector2i(18, 26), &"b1f_north": Vector2i(20, 4),
}
const MANSION_3F_HOLE := Vector2i(16, 14)
const MANSION_SECRET_KEY := Vector2i(5, 13)
const MANSION_EAST_DOOR := Vector2i(26, 27)
const FOSSIL_DOCTOR := Vector2i(5, 2)
const CINNABAR_QUIZ: Array = [
	[Vector2i(15, 8), 0, Vector2i(9, 3)], [Vector2i(10, 2), 1, Vector2i(6, 3)], [Vector2i(9, 8), 1, Vector2i(6, 6)],
	[Vector2i(9, 14), 1, Vector2i(3, 8)], [Vector2i(1, 14), 0, Vector2i(2, 6)], [Vector2i(1, 8), 1, Vector2i(2, 3)],
]
const OPEN_GATE_BLOCK: int = 0x0E
const BLAINE := Vector2i(3, 3)
const SECRET_KEY: int = 0x2B
const DOME_FOSSIL: int = 0x29
const KABUTO: int = 140
const TM38: int = 238
const VOLCANO_BADGE: int = 6
const EVENT_MANSION_SWITCH_ON: int = 632
const EVENT_GAVE_FOSSIL_TO_LAB: int = 736
const BLAINE_LEVEL: int = 55

var _answer: int = -1
var _field_move_at: int = -1000


func _blaine_legs() -> Array:
	var p: Variant = _played
	var m: Dictionary = BLAINE_MAPS
	var k: Dictionary = KOGA_MAPS
	var key: Callable = p._holds(SECRET_KEY)
	var legs: Array = []
	for pad: int in SAFFRON_GYM_PADS_OUT.size():
		legs.append(["saffron_gym_pad_out_%d" % (pad + 1), p._walk(SAFFRON_GYM_PADS_OUT[pad]),
			p._at(_pad_landing(m.saffron_gym, SAFFRON_GYM_PADS_OUT[pad]))])
		if pad == 0:
			legs += [_grind.bind(BLAINE_LEVEL, 0), _teach_surf_and_strength]
	legs += [
		["saffron_gym_exit", p._warp_to(m.saffron_city), p._on_map(m.saffron_city)],
		["saffron_to_route_8", p._cross(Vector2i.RIGHT, m.route_8), p._on_map(m.route_8)],
		["route_8_gate", p._walk(ROUTE_8_GATE_WEST), p._on_map(m.route_8_gate)],
		["route_8_gate_east", p._walk(ROUTE_8_GATE_EAST), p._on_map(m.route_8)],
		["route_8_to_lavender_again", p._cross(Vector2i.RIGHT, k.lavender_town), p._on_map(k.lavender_town)],
		["lavender_to_route_12_again", p._cross(Vector2i.DOWN, k.route_12), p._on_map(k.route_12)],
		["route_12_gate_again", p._warp_to(k.route_12_gate), p._on_map(k.route_12_gate)],
		["route_12_gate_south_again", p._walk(ROUTE_12_GATE_SOUTH), p._on_map(k.route_12)],
		["route_12_to_route_13_again", p._cross(Vector2i.DOWN, k.route_13), p._on_map(k.route_13)],
		["route_13_to_route_14_again", _cross_at(ROUTE_13_WEST_EDGE, Vector2i.LEFT), p._on_map(k.route_14)],
		["route_14_to_route_15_again", p._cross(Vector2i.LEFT, k.route_15), p._on_map(k.route_15)],
		["route_15_gate_again", p._warp_to(k.route_15_gate), p._on_map(k.route_15_gate)],
		["route_15_gate_west_again", p._walk(ROUTE_15_GATE_WEST), p._on_map(k.route_15)],
		["route_15_to_fuchsia_again", p._cross(Vector2i.LEFT, k.fuchsia_city), p._on_map(k.fuchsia_city)],
		["fuchsia_to_route_19", p._cross(Vector2i.DOWN, m.route_19), p._on_map(m.route_19)],
		["route_19_surf", _surf_from(ROUTE_19_SHORE, Gen2WorldSprite.FACING_DOWN), _surfing],
		["route_19_to_route_20", p._cross(Vector2i.LEFT, m.route_20), p._on_map(m.route_20)],
		["route_20_north_field", p._walk(ROUTE_20_NORTH_FIELD), p._at(ROUTE_20_NORTH_FIELD)],
		["seafoam_west_door", p._walk(ROUTE_20_SEAFOAM_WEST), p._on_map(m.seafoam_1f)],
	]
	legs += _seafoam_legs()
	legs += [
		["route_20_surf_again", _surf_from(ROUTE_20_EAST_BEACH, Gen2WorldSprite.FACING_DOWN), _surfing],
		["route_20_to_cinnabar", p._cross(Vector2i.LEFT, m.cinnabar_island), p._on_map(m.cinnabar_island)],
		["cinnabar_shore", p._walk(CINNABAR_SHORE), p._at(CINNABAR_SHORE)],
		["cinnabar_lab", p._warp_to(m.cinnabar_lab), p._on_map(m.cinnabar_lab)],
		["fossil_room", p._warp_to(m.fossil_room), p._on_map(m.fossil_room)],
		["give_fossil", _talk_to_walker(FOSSIL_DOCTOR), _gave_fossil],
		["fossil_room_out", p._warp_to(m.cinnabar_lab), p._on_map(m.cinnabar_lab)],
		["cinnabar_lab_out", p._warp_to(m.cinnabar_island), p._on_map(m.cinnabar_island)],
		["mansion_entry", p._warp_to(m.mansion_1f), p._on_map(m.mansion_1f)],
		["mansion_1f_to_2f", p._warp_to(m.mansion_2f), p._on_map(m.mansion_2f)],
		["mansion_2f_to_3f", p._walk(Vector2i(6, 1)), p._on_map(m.mansion_3f)],
		_mansion_switch("mansion_3f_switch_on", MANSION_SWITCHES[&"3f"], true),
		["mansion_3f_hole", p._walk(MANSION_3F_HOLE), p._on_map(m.mansion_1f)],
		["mansion_1f_to_b1f", p._warp_to(m.mansion_b1f), p._on_map(m.mansion_b1f)],
		_mansion_switch("mansion_b1f_south_switch_off", MANSION_SWITCHES[&"b1f_south"], false),
		_mansion_switch("mansion_b1f_north_switch_on", MANSION_SWITCHES[&"b1f_north"], true),
		["mansion_b1f_secret_key", p._talk_to(MANSION_SECRET_KEY), key],
		_mansion_switch("mansion_b1f_north_switch_off", MANSION_SWITCHES[&"b1f_north"], false),
		_mansion_switch("mansion_b1f_south_switch_on", MANSION_SWITCHES[&"b1f_south"], true),
		["mansion_b1f_to_1f", p._warp_to(m.mansion_1f), p._on_map(m.mansion_1f)],
		["mansion_exit", p._walk(MANSION_EAST_DOOR), p._on_map(m.cinnabar_island)],
		["cinnabar_lab_again", p._warp_to(m.cinnabar_lab), p._on_map(m.cinnabar_lab)],
		["fossil_room_again", p._warp_to(m.fossil_room), p._on_map(m.fossil_room)],
		["revived_fossil", _talk_to_walker(FOSSIL_DOCTOR), _revived],
		["fossil_room_out_again", p._warp_to(m.cinnabar_lab), p._on_map(m.cinnabar_lab)],
		["cinnabar_lab_out_again", p._warp_to(m.cinnabar_island), p._on_map(m.cinnabar_island)],
		["cinnabar_gym", p._warp_to(m.cinnabar_gym), p._on_map(m.cinnabar_gym)],
	]
	for machine: int in CINNABAR_QUIZ.size():
		var row: Array = CINNABAR_QUIZ[machine]
		legs.append(["cinnabar_gym_quiz_%d" % (machine + 1), _quiz(row[0], int(row[1])), _gate_open(row[2])])
	return legs + [
		_meet_partner("meet_in_cinnabar_gym", _badge(VOLCANO_BADGE)),
		["blaine", _join_or(p._talk_to(BLAINE)), _badge(VOLCANO_BADGE)],
		["tm38_on_host", _standing, func(world: Gen2WorldAPI) -> bool: return p._holds(TM38).call(world) and _hosted(TM38) > 0],
		["cinnabar_gym_exit", p._warp_to(m.cinnabar_island), p._on_map(m.cinnabar_island)],
		_blaine_done,
	]


func _pad_landing(map: Vector2i, pad: Vector2i) -> Vector2i:
	var warps: Array = _session.data.world_map(map.x, map.y).events.get("warps", [])
	var at: int = warps.find_custom(func(warp: Dictionary) -> bool: return Vector2i(int(warp["x"]), int(warp["y"])) == pad)
	var landing: Dictionary = warps[int(warps[at]["destination"])]
	return Vector2i(int(landing["x"]), int(landing["y"]))


func _teach_surf_and_strength() -> bool:
	var save: Gen2SaveData = _played._screen.active_save()
	var taught: Array = []
	for row: Array in [[HM03, Gen2WorldFieldMove.MOVE_SURF, Gen2SaveMon.MAX_MOVES - 1], [HM04, Gen2WorldFieldMove.MOVE_STRENGTH, 0]]:
		if _played._screen.world().state.item_quantity(int(row[0])) <= 0:
			return false
		_party_with(_learns.bind([int(row[1])]))
		for mon: Gen2SaveMon in save.party:
			if Gen2WorldTMHM.can_learn(_session.data, mon.species, int(row[1])):
				_played._editor.set_move(mon, int(row[2]), int(row[1]))
				taught.append(mon.species)
				break
	_played._screen.call(&"_refresh_party_summary")
	print("coop autoplay: %s taught SURF and STRENGTH to %s" % [_player_id, taught])
	return taught.size() == 2


func _field_move(move: int) -> void:
	if _frames - _field_move_at < 120:
		return
	_field_move_at = _frames
	_played._screen.call(&"_run_party_action", {"kind": &"field_move", "move": move,
		"slot": _played._screen.world().party_slot_with_move(move)})


func _surf_from(cell: Vector2i, facing: int) -> Callable:
	var face: Callable = _played._talk(cell, facing)
	return func(world: Gen2WorldAPI) -> int:
		if world.movement_mode == Gen2WorldAPI.MOVEMENT_SURF:
			return _played._warp_press(world, world.player_cell)
		var button: int = face.call(world)
		if button != PokeButton.A:
			return button
		_field_move(Gen2WorldFieldMove.MOVE_SURF)
		return PokeButton.NONE


func _surfing(world: Gen2WorldAPI) -> bool:
	return world.movement_mode == Gen2WorldAPI.MOVEMENT_SURF


func _surfing_on(map: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> bool: return world.map_id() == map and _surfing(world)


func _seafoam_legs() -> Array:
	var p: Variant = _played
	var calm: Callable = func(world: Gen2WorldAPI) -> bool: return EVENT_SEAFOAM3_BOULDERS.all(world.event_flag_active)
	var rows: Array = SEAFOAM_PUZZLE
	var legs: Array = []
	if _order() != 0:
		rows = SEAFOAM_CALM_WAY
		legs.append(["seafoam_wait_for_partner", _standing, calm])
	for row: Array in rows + SEAFOAM_WAY_OUT:
		match String(row[0]):
			"strength":
				legs.append([row[1], _use_strength, func(world: Gen2WorldAPI) -> bool: return world.strength_active()])
			"push":
				var hole: int = int(row[5]) if row.size() > 5 else -1
				legs.append([row[1], _push(row[2], row[3], int(row[4])), _pushed(row[2], row[3], int(row[4]), hole)])
			"warp":
				legs.append([row[1], p._walk(row[2]), p._on_map(Vector2i(0, int(row[3])))])
			"walk":
				legs.append([row[1], p._walk(row[2]), p._at(row[2])])
			"surf":
				var map := Vector2i(0, int(row[3]))
				legs.append([row[1], _surf_from(row[2], Gen2WorldSprite.FACING_DOWN), _surfing_on(map) if bool(row[4]) else p._on_map(map)])
	return legs


func _use_strength(_world: Gen2WorldAPI) -> int:
	_field_move(Gen2WorldFieldMove.MOVE_STRENGTH)
	return PokeButton.NONE


func _push(approach: Vector2i, direction: Vector2i, count: int) -> Callable:
	return func(world: Gen2WorldAPI) -> int:
		var boulder: Vector2i = _boulder_on(world, approach, direction, count)
		if boulder.x < 0:
			return PokeButton.NONE
		if not world.strength_active():
			_field_move(Gen2WorldFieldMove.MOVE_STRENGTH)
			return PokeButton.NONE
		if world.player_cell == boulder - direction:
			return _played._direction_button(direction)
		return _played._step_toward(world, _played._is(boulder - direction))


func _pushed(approach: Vector2i, direction: Vector2i, count: int, hole: int) -> Callable:
	return func(world: Gen2WorldAPI) -> bool:
		return world.event_flag_active(hole) if hole >= 0 else _boulder_on(world, approach, direction, count).x < 0


func _boulder_on(world: Gen2WorldAPI, approach: Vector2i, direction: Vector2i, count: int) -> Vector2i:
	for step: int in range(1, count + 1):
		var object: Gen2WorldObject = world.object_at(approach + direction * step)
		if object != null:
			return object.cell
	return Vector2i(-1, -1)


func _mansion_switch(label: String, cell: Vector2i, on: bool) -> Array:
	return [label, _played._talk(cell, UP), func(world: Gen2WorldAPI) -> bool: return world.event_flag_active(EVENT_MANSION_SWITCH_ON) == on]


func _talk_to_walker(initial: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> int: return _played._talk_button(world, _played._live_cell(world, initial))


func _gave_fossil(world: Gen2WorldAPI) -> bool:
	return world.state.item_quantity(DOME_FOSSIL) <= 0 and world.event_flag_active(EVENT_GAVE_FOSSIL_TO_LAB)


func _revived(world: Gen2WorldAPI) -> bool:
	return not world.event_flag_active(EVENT_GAVE_FOSSIL_TO_LAB) \
		and _owns(KABUTO)


func _quiz(cell: Vector2i, answer: int) -> Callable:
	var face: Callable = _played._talk(cell, UP)
	return func(world: Gen2WorldAPI) -> int:
		_answer = answer
		return face.call(world)


func _quiz_button(screen: Gen2WorldScreen) -> int:
	var host: Gen2WorldServiceScreen = screen.get("_service_host")
	if _answer < 0 or host == null or bool(host.call(&"_box_printing")):
		return -1
	return _paced(PokeButton.A if host.selected_index() == _answer else PokeButton.DOWN)


func _gate_open(gate: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> bool:
		var open: bool = world.block_at(gate.x, gate.y) == OPEN_GATE_BLOCK
		if open:
			_answer = -1
		return open


func _blaine_done() -> bool:
	var world: Gen2WorldAPI = _played._screen.world()
	var me: Dictionary = _session.client.me()
	var missing: PackedStringArray = []
	if world.state.item_quantity(SECRET_KEY) <= 0 or int((me.get("items", {}) as Dictionary).get(SECRET_KEY, 0)) <= 0:
		missing.append("SECRET KEY")
	if not _host_team().any(func(row: Dictionary) -> bool: return int(row["mon"]["species"]) == KABUTO):
		missing.append("KABUTO on the host")
	if not _badge(VOLCANO_BADGE).call(world):
		missing.append("VOLCANOBADGE")
	if world.state.item_quantity(TM38) != 1 or _hosted(TM38) != 1:
		missing.append("one TM38")
	print("coop autoplay: %s after BLAINE: badges %d, team on host %s, TM38 %d (host %d), missing %s" % [
		_player_id, world.state.badge_count(), (me.get("party", []) as Array).map(
			func(row: Dictionary) -> int: return int(row["mon"]["species"])), world.state.item_quantity(TM38), _hosted(TM38), missing])
	return missing.is_empty()


const VICTORY_MAPS: Dictionary = {
	&"cinnabar_island": Vector2i(0, 8), &"route_21": Vector2i(0, 32), &"pallet_town": Vector2i(0, 0),
	&"route_1": Vector2i(0, 12), &"viridian_city": Vector2i(0, 1), &"viridian_gym": Vector2i(0, 45),
	&"route_22": Vector2i(0, 33), &"route_22_gate": Vector2i(0, 193), &"route_23": Vector2i(0, 34),
	&"victory_road_1f": Vector2i(0, 108), &"victory_road_2f": Vector2i(0, 194), &"victory_road_3f": Vector2i(0, 198),
	&"indigo_plateau": Vector2i(0, 9), &"indigo_plateau_lobby": Vector2i(0, 174),
}
const CINNABAR_SHORES: Array = [Vector2i(4, 4), Vector2i(4, 5)]
const GIOVANNI_FRONTS: Array = [[Vector2i(2, 2), Gen2WorldSprite.FACING_UP], [Vector2i(3, 1), Gen2WorldSprite.FACING_LEFT]]
const ROUTE_22_GATE_NORTH: Array = [Vector2i(4, 0), Vector2i(5, 0)]
const ROUTE_23_SOUTH_BANKS: Array = [Vector2i(11, 104), Vector2i(10, 104)]
const ROUTE_23_NORTH_BANKS: Array = [Vector2i(8, 71), Vector2i(9, 71)]
const VICTORY_ROAD_PUSHES: Dictionary = {
	&"1f": [Vector2i(5, 15), Vector2i(5, 16), Vector2i(9, 16), Vector2i(9, 14), Vector2i(16, 14), Vector2i(16, 12),
		Vector2i(17, 12), Vector2i(17, 13)],
	&"2f": [Vector2i(4, 14), Vector2i(3, 14), Vector2i(3, 16), Vector2i(1, 16)],
	&"3f": [Vector2i(22, 3), Vector2i(22, 1), Vector2i(6, 1), Vector2i(6, 2), Vector2i(2, 2), Vector2i(2, 5), Vector2i(3, 5)],
	&"hole": [Vector2i(22, 15), Vector2i(23, 15)],
	&"2f_fallen": [Vector2i(23, 16), Vector2i(9, 16)],
}
const VICTORY_ROAD_ASIDE: Dictionary = {
	&"1f": Vector2i(6, 17), &"2f": Vector2i(1, 6), &"2f_ladder": Vector2i(21, 7), &"3f_hole": Vector2i(19, 14),
}
const VICTORY_ROAD_2F_LADDER := Vector2i(23, 7)
const VICTORY_ROAD_3F_HOLE := Vector2i(23, 15)
const VICTORY_ROAD_2F_EAST_LADDER := Vector2i(25, 14)
const VICTORY_ROAD_3F_LADDER_DOWN := Vector2i(26, 8)
const VICTORY_ROAD_2F_EXIT := Vector2i(29, 8)
const EARTH_BADGE: int = 7
const TM11: int = Gen1Layout.TM_FIRST_ITEM + 10
const TM27: int = Gen1Layout.TM_FIRST_ITEM + 26
const VICTORY_LEVEL: int = 55


func _victory_legs() -> Array:
	var p: Variant = _played
	var m: Dictionary = VICTORY_MAPS
	var me: int = mini(_order(), 1)
	var earth: Callable = _badge(EARTH_BADGE)
	var surfing: Callable = func(world: Gen2WorldAPI) -> bool: return world.movement_mode == Gen2WorldAPI.MOVEMENT_SURF
	var north_bank: Vector2i = ROUTE_23_NORTH_BANKS[me]
	return [
		["cinnabar_gym_out", p._warp_to(m.cinnabar_island), p._on_map(m.cinnabar_island)],
		_grind.bind(VICTORY_LEVEL, 0),
		_teach_victory_moves,
		["cinnabar_surf", _field_move_from.bind(CINNABAR_SHORES[me], Gen2WorldSprite.FACING_LEFT, Gen2WorldFieldMove.MOVE_SURF),
			_either(surfing, p._on_map(m.route_21))],
		["cinnabar_to_route_21", _swim.bind(Vector2i.UP, m.route_21), p._on_map(m.route_21)],
		["route_21_to_pallet", _swim.bind(Vector2i.UP, m.pallet_town), p._on_map(m.pallet_town)],
		["tm27_room", _toss_for_tm27, func(_world: Gen2WorldAPI) -> bool: return _hosted(TM11) <= 0],
		["pallet_to_route_1", p._cross(Vector2i.UP, m.route_1), p._on_map(m.route_1)],
		["route_1_to_viridian", p._cross(Vector2i.UP, m.viridian_city), p._on_map(m.viridian_city)],
		["viridian_gym", p._warp_to(m.viridian_gym), p._on_map(m.viridian_gym)],
		_meet_partner("meet_in_viridian_gym", earth),
		["viridian_gym_giovanni", _join_or(_to_giovanni.bind(GIOVANNI_FRONTS[me])), earth],
		["viridian_gym_out", _glide_to(m.viridian_city), p._on_map(m.viridian_city)],
		["viridian_to_route_22", p._cross(Vector2i.LEFT, m.route_22), p._on_map(m.route_22)],
		["route_22_rival", _join_or(p._warp_to(m.route_22_gate)), p._on_map(m.route_22_gate)],
		["route_22_gate_north", p._walk(ROUTE_22_GATE_NORTH[me]), p._on_map(m.route_23)],
		["route_23_surf", _field_move_from.bind(ROUTE_23_SOUTH_BANKS[me], UP, Gen2WorldFieldMove.MOVE_SURF), surfing],
		["route_23_north_bank", _swim_to.bind(north_bank), p._at(north_bank)],
		["victory_road_entry", p._warp_to(m.victory_road_1f), p._on_map(m.victory_road_1f)],
	] + _victory_road_legs(me == 0) + [
		["victory_road_exit", p._walk(VICTORY_ROAD_2F_EXIT), p._on_map(m.route_23)],
		["route_23_to_indigo_plateau", p._cross(Vector2i.UP, m.indigo_plateau), p._on_map(m.indigo_plateau)],
		["indigo_plateau_lobby", p._warp_to(m.indigo_plateau_lobby), p._on_map(m.indigo_plateau_lobby)],
		_victory_done,
	]


func _victory_road_legs(lead: bool) -> Array:
	var p: Variant = _played
	var m: Dictionary = VICTORY_MAPS
	var third: Callable = p._flag(PokeCoopWorldLink.EVENT_VICTORY_ROAD_3_BOULDER_ON_SWITCH1)
	var last: Callable = p._flag(PokeCoopWorldLink.EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH2)
	var hole: Array = VICTORY_ROAD_PUSHES[&"hole"]
	var legs: Array = _floor_legs(&"1f", p._flag(PokeCoopWorldLink.EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH), lead)
	legs.append(["victory_road_1f_to_2f", p._warp_to(m.victory_road_2f), p._on_map(m.victory_road_2f)])
	legs += _floor_legs(&"2f", p._flag(PokeCoopWorldLink.EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1), lead)
	legs += _aside_legs(&"2f_ladder", third, not lead)
	legs.append(["victory_road_2f_to_3f", p._walk(VICTORY_ROAD_2F_LADDER), p._on_map(m.victory_road_3f)])
	legs += _push_legs(&"3f", third, lead)
	legs += _aside_legs(&"3f_hole", last, not lead)
	if lead:
		legs.append(["victory_road_3f_hole_push", _push_boulder.bind(hole[0], hole[1]), _gone(hole[0])])
	legs.append(["victory_road_3f_hole", p._walk(VICTORY_ROAD_3F_HOLE), p._on_map(m.victory_road_2f)])
	legs += _push_legs(&"2f_fallen", last, lead)
	return legs + [
		["victory_road_2f_east_ladder", p._walk(VICTORY_ROAD_2F_EAST_LADDER), p._on_map(m.victory_road_3f)],
		["victory_road_3f_ladder_down", p._walk(VICTORY_ROAD_3F_LADDER_DOWN), p._on_map(m.victory_road_2f)],
	]


func _floor_legs(stage: StringName, switch: Callable, lead: bool) -> Array:
	var spot: Vector2i = _behind(VICTORY_ROAD_PUSHES[stage][0], VICTORY_ROAD_PUSHES[stage][1]) if lead else VICTORY_ROAD_ASIDE[stage]
	var legs: Array = [
		["victory_road_%s_spot" % stage, _played._walk(spot), _either(_played._at(spot), switch)],
		_meet_partner("meet_in_victory_road_%s" % stage, switch),
	]
	if lead:
		legs.append(["victory_road_%s_strength" % stage, _strength_button, func(world: Gen2WorldAPI) -> bool: return world.strength_active()])
	return legs + _push_legs(stage, switch, lead) + _aside_legs(stage, switch, not lead)


func _push_legs(stage: StringName, switch: Callable, lead: bool) -> Array:
	var cells: Array = VICTORY_ROAD_PUSHES[stage]
	var legs: Array = []
	for index: int in range(1, cells.size() if lead else 1):
		legs.append(["victory_road_%s_push_%d" % [stage, index], _push_boulder.bind(cells[0], cells[index]),
			_either(_boulder_at(cells[0], cells[index]), switch)])
	return legs


func _aside_legs(stage: StringName, until: Callable, waits: bool) -> Array:
	if not waits:
		return []
	var aside: Vector2i = VICTORY_ROAD_ASIDE[stage]
	return [
		["victory_road_%s_aside" % stage, _played._walk(aside), _either(_played._at(aside), until)],
		["victory_road_%s_wait" % stage, _standing, until],
	]


func _behind(boulder: Vector2i, target: Vector2i) -> Vector2i:
	return boulder - (target - boulder).sign()


func _push_boulder(world: Gen2WorldAPI, boulder: Vector2i, target: Vector2i) -> int:
	var at: Vector2i = _played._live_cell(world, boulder)
	if at == target:
		return PokeButton.NONE
	if world.player_cell == _behind(at, target):
		return _played._direction_button((target - at).sign())
	return _played._step_toward(world, _played._is(_behind(at, target)))


func _boulder_at(boulder: Vector2i, target: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> bool: return _played._live_cell(world, boulder) == target


func _gone(initial: Vector2i) -> Callable:
	return func(world: Gen2WorldAPI) -> bool:
		return not world.active_objects().any(func(object: Gen2WorldObject) -> bool: return object.initial_cell == initial)


func _strength_button(world: Gen2WorldAPI) -> int:
	_played._screen.call(&"_run_party_action", {"kind": &"field_move", "move": Gen2WorldFieldMove.MOVE_STRENGTH,
		"slot": world.party_slot_with_move(Gen2WorldFieldMove.MOVE_STRENGTH)})
	return PokeButton.NONE


func _field_move_from(world: Gen2WorldAPI, cell: Vector2i, facing: int, move: int) -> int:
	var button: int = _played._talk(cell, facing).call(world)
	if button != PokeButton.A:
		return button
	_played._screen.call(&"_run_party_action", {"kind": &"field_move", "move": move, "slot": world.party_slot_with_move(move)})
	return PokeButton.NONE


func _to_giovanni(world: Gen2WorldAPI, front: Array) -> int:
	if world.map_id() != VICTORY_MAPS.viridian_gym:
		return _played._warp_to(VICTORY_MAPS.viridian_gym).call(world)
	if world.player_cell == front[0]:
		return _played._talk(front[0], front[1]).call(world)
	var button: int = _glide_button(world, front[0])
	return button if button != PokeButton.NONE else _glide_to(VICTORY_MAPS.viridian_city).call(world)


func _swim(world: Gen2WorldAPI, direction: Vector2i, map: Vector2i) -> int:
	if _played._crosses(world, world.player_cell, direction, map):
		return _played._direction_button(direction)
	return _swim_button(world, func(at: Vector2i) -> bool: return _played._crosses(world, at, direction, map))


func _swim_to(world: Gen2WorldAPI, cell: Vector2i) -> int:
	return _swim_button(world, _played._is(cell))


func _swim_button(world: Gen2WorldAPI, goal: Callable) -> int:
	var first: Dictionary = {world.player_cell: Vector2i.ZERO}
	var frontier: Array[Vector2i] = [world.player_cell]
	while not frontier.is_empty():
		var at: Vector2i = frontier.pop_front()
		if at != world.player_cell and goal.call(at):
			return _played._direction_button(first[at])
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = at + direction
			if first.has(next) or not world.can_walk_to(next):
				continue
			if goal.call(next) or world.collision_permission_at(next) == Gen2WorldCollision.WATER_TILE:
				first[next] = direction if at == world.player_cell else first[at]
				frontier.append(next)
	return PokeButton.NONE


func _teach_victory_moves() -> bool:
	_party_with(_learns.bind([Gen2WorldFieldMove.MOVE_SURF, Gen2WorldFieldMove.MOVE_STRENGTH]))
	for mon: Gen2SaveMon in _played._screen.active_save().party:
		if Gen2WorldTMHM.can_learn(_session.data, mon.species, Gen2WorldFieldMove.MOVE_SURF) \
				and Gen2WorldTMHM.can_learn(_session.data, mon.species, Gen2WorldFieldMove.MOVE_STRENGTH):
			_played._editor.set_move(mon, 0, Gen2WorldFieldMove.MOVE_STRENGTH)
			_played._editor.set_move(mon, 1, Gen2WorldFieldMove.MOVE_SURF)
			_played._screen.call(&"_refresh_party_summary")
			return true
	return false


func _toss_for_tm27(world: Gen2WorldAPI) -> int:
	if world.state.item_quantity(TM11) > 0:
		var tossed: Dictionary = Gen2WorldBagHost.toss(world, _played._screen.active_save(), TM11, world.state.item_quantity(TM11), false)
		print("coop autoplay: %s tossed TM11 for TM27's room: %s" % [_player_id, tossed.get("ok")])
	return PokeButton.NONE


func _victory_done() -> bool:
	var world: Gen2WorldAPI = _played._screen.world()
	var earth: bool = bool(_badge(EARTH_BADGE).call(world))
	var lobby: bool = world.map_id() == VICTORY_MAPS.indigo_plateau_lobby
	print("coop autoplay: %s in the Indigo Plateau lobby %s: EARTHBADGE %s, badges %d (campaign %d), TM27 %d (host %d)" % [
		_player_id, lobby, earth, world.state.badge_count(),
		int((_session.client.state.get("campaign", {}) as Dictionary).get("badges", 0)),
		world.state.item_quantity(TM27), _hosted(TM27)])
	return earth and lobby


const ELITE_MAPS: Dictionary = {
	&"lorelei": Vector2i(0, 245), &"bruno": Vector2i(0, 246), &"agatha": Vector2i(0, 247), &"lance": Vector2i(0, 113),
	&"champion": Vector2i(0, 120),
}
const INDIGO_PLATEAU: int = 9
const BELOW_LOBBY_NURSE := Vector2i(7, 7)
const ELITE_MEMBER := Vector2i(5, 2)
const LANCE := Vector2i(6, 1)
const ELITE_ROOMS: Array = [["lorelei", &"bruno", 0x8E1], ["bruno", &"agatha", 0x8E9], ["agatha", &"lance", 0x8F1],
	["lance", &"champion", 0x8FE]]
const ELITE_LEVEL: int = 62

var _hall: Dictionary = {}
var _beaten_before: Array = []
var _battles_shot: Dictionary = {}
var _seen_beaten: Dictionary = {}


## The team's run (D91): LORELEI and AGATHA fought with the partner joined beside, BRUNO and LANCE from the room behind.
func _elite_legs() -> Array:
	var p: Variant = _played
	var m: Dictionary = ELITE_MAPS
	var legs: Array = [
		["lobby_nurse", p._talk(BELOW_LOBBY_NURSE, UP), func(world: Gen2WorldAPI) -> bool:
			return world.gen1_last_blackout_map() == INDIGO_PLATEAU],
		_grind.bind(ELITE_LEVEL, 0),
	]
	for room: int in ELITE_ROOMS.size():
		var row: Array = ELITE_ROOMS[room]
		var map: Vector2i = m[StringName(row[0])]
		var beaten: Callable = p._flag(int(row[2]))
		var member: Callable = p._talk_to(LANCE if row[0] == "lance" else ELITE_MEMBER)
		var walk_in: Array = ["lobby_stairs" if room == 0 else "%ss_room_in" % row[0], p._warp_to(map), p._on_map(map)]
		if room % 2 == 0:
			legs += [walk_in, _meet_partner("meet_in_%ss_room" % row[0], beaten), _note_beaten,
				[String(row[0]), _join_or(_fights(room, member)), beaten]]
		else:
			if _whiteout and room == 1:
				var lobby: Vector2i = VICTORY_MAPS.indigo_plateau_lobby
				legs += [["%ss_room_lost" % row[0], _lose_at(room, map, member), _whited_out(room)],
					["lobby_again", _fights(room, p._warp_to(lobby)), _either(p._on_map(lobby), _follows(room))],
					["back_through_loreleis_room", _fights(room, p._warp_to(m.lorelei)), _either(p._on_map(m.lorelei), _follows(room))]]
			legs += [_note_beaten, ["%ss_room_ahead" % row[0], _join_any(_leads(room, p._warp_to(map))), _either(p._on_map(map), beaten)],
				[String(row[0]), _fights(room, member), beaten], walk_in]
		legs.append(["%ss_exit_open" % row[0], _standing, _settled(String(row[0]), beaten)])
	return legs + [_note_beaten, ["champion", _join_any(_leads(ELITE_ROOMS.size(), p._warp_to(m.champion), true)), _inducted],
		["league_cleared", _standing, _league_cleared]]


func _settled(room: String, beaten: Callable) -> Callable:
	return func(world: Gen2WorldAPI) -> bool:
		return bool(beaten.call(world)) and _frames - int(_seen_beaten.get_or_add(room, _frames)) >= FILM_FRAMES * 2


func _follows(room: int) -> Callable:
	return func(_world: Gen2WorldAPI) -> bool: return _order() != room % 2


func _lose_at(room: int, map: Vector2i, member: Callable) -> Callable:
	var to_room: Callable = _played._warp_to(map)
	return func(world: Gen2WorldAPI) -> int:
		if _order() != room % 2:
			return PokeButton.NONE
		if world.map_id() != map:
			return to_room.call(world)
		if not _losing:
			_losing = true
			var party: Array = _played._screen.active_save().party
			for at: int in party.size():
				(party[at] as Gen2SaveMon).hp = 1 if at == 0 else 0
				(party[at] as Gen2SaveMon).status = 7 if at == 0 else 0
			print("coop autoplay: %s faces %s with one sleeping Pokémon at 1 HP, to white out" % [_player_id, map])
		return member.call(world)


func _whited_out(room: int) -> Callable:
	var outside: Vector2i = Vector2i(0, INDIGO_PLATEAU)
	return func(world: Gen2WorldAPI) -> bool:
		if _order() == room % 2:
			_losing = _losing and world.map_id() != outside
			return world.map_id() == outside
		_partner_lost = _partner_lost or _partner_on(outside)
		_still_since = Time.get_ticks_msec()
		return _partner_lost


func _fights(room: int, member: Callable) -> Callable:
	return func(world: Gen2WorldAPI) -> int: return member.call(world) if _order() == room % 2 else PokeButton.NONE


func _leads(room: int, goal: Callable, alone: bool = false) -> Callable:
	return func(world: Gen2WorldAPI) -> int:
		var partner_there: bool = alone and _partner_on(ELITE_MAPS.champion)
		var won: bool = _beaten().size() > _beaten_before.size() and not partner_there
		return goal.call(world) if _order() == room % 2 or won else PokeButton.NONE


func _note_beaten() -> bool:
	_beaten_before = _beaten()
	return true


func _beaten() -> Array:
	var defeated: Array = (_session.client.state.get("campaign", {}) as Dictionary).get("defeated", [])
	return defeated.filter(func(id: String) -> bool: return id.begins_with("trainer:"))


func _partner_on(map: Vector2i) -> bool:
	var players: Dictionary = _session.client.state.get("players", {})
	return players.keys().any(func(id: String) -> bool: return id != _player_id and (players[id] as Dictionary).get("map") == map)


func _join_any(goal: Callable) -> Callable:
	return func(world: Gen2WorldAPI) -> int:
		_joining = _partner_fight(true)
		return PokeButton.SELECT if not _joining.is_empty() else goal.call(world)


func _inducted(world: Gen2WorldAPI) -> bool:
	var host: Dictionary = (_session.client.me().get("world", {}) as Dictionary).get("engine_flags", {})
	return world.map_id() == PokeCoopPolicy.START_MAP and world.state.hall_of_fame() and host.has(Gen2WorldState.ENGINE_HALL_OF_FAME)


func _league_cleared(world: Gen2WorldAPI) -> bool:
	var run: Array = range(PokeCoopPolicy.ELITE_FOUR_RUN.x, PokeCoopPolicy.ELITE_FOUR_RUN.y + 1)
	var host: Dictionary = (_session.client.me().get("world", {}) as Dictionary).get("event_flags", {})
	var campaign: Array = ((_session.client.state.get("campaign", {}) as Dictionary).get("flags", []) as Array)
	var left: Array = run.filter(func(flag: int) -> bool: return world.event_flag_active(flag) or host.has(flag) or campaign.has(flag))
	if not left.is_empty():
		_still_since = Time.get_ticks_msec()
		return false
	print("coop autoplay: %s inducted on %s %s, run cleared for the campaign, beaten %s, partners %s" % [_player_id,
		world.map_id(), world.player_cell, _beaten(), _session.client.state.get("players", {}).keys()])
	return true


func _film_battle(view: Dictionary) -> void:
	if _route != "elite" or not bool(view.get("trainer", false)):
		return
	var seen: int = int(_battles_shot.get_or_add(view["battle"], _frames))
	if _frames - seen == FILM_FRAMES * 8:
		_shot("battle_%s_%s" % [String(view.get("trainer_name", "")).to_lower(), view["battle"]])


func _watch_hall_of_fame(screen: Gen2WorldScreen) -> void:
	for host: StringName in [&"_hall_of_fame_host", &"_credits_host"]:
		if screen.get(host) == null:
			continue
		_still_since = Time.get_ticks_msec()
		if not _hall.has(host):
			_hall[host] = _frames
			print("coop autoplay: %s %s on map %s, ENGINE_HALL_OF_FAME %s" % [
				_player_id, host, screen.world().map_id(), screen.world().state.hall_of_fame()])
		if _frames - int(_hall[host]) == FILM_FRAMES * 16:
			_shot(String(host).trim_prefix("_").trim_suffix("_host"))


func _either(first: Callable, second: Callable) -> Callable:
	return func(world: Gen2WorldAPI) -> bool: return bool(first.call(world)) or bool(second.call(world))


func _meet_partner(label: String, or_done: Callable) -> Array:
	return [label, _standing, _either(func(_world: Gen2WorldAPI) -> bool: return not _session.client.nearby().is_empty(), or_done)]


func _partner_fight(anywhere: bool = false) -> String:
	if _session.client.nearby().is_empty() and not anywhere:
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
	var grown: bool = (caught <= 0 or _room()) and _played._grind(level, caught)
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


func _dump_texts() -> void:
	var screen: Gen2WorldScreen = _played._screen
	if _shots.is_empty() or _frames % 6 != 0 or screen == null or not is_instance_valid(screen) or screen.world() == null:
		return
	if _texts == null:
		_texts = FileAccess.open("%s/%s_texts.tsv" % [_shots, _player_id], FileAccess.WRITE)
		if _texts == null:
			return
	var lines: Dictionary = {"world": _box_lines(screen.get("_text_box"))}
	var battle: Gen2BattleScreen = screen.get("_battle_host")
	lines["battle"] = String(battle.battle_snapshot().get("message", "")) if battle != null else ""
	if _session.panel != null and _session.panel.get_parent() != null:
		for node: Node in _session.panel.get_parent().get_children():
			if node is PokeCoopBattleField:
				lines["field"] = _box_lines(node.get("_box"))
	var leg: String = String(_legs[_leg][0]) if _leg < _legs.size() and _legs[_leg] is Array else ""
	for where: String in lines:
		var text: String = String(lines[where]).replace("\n", " / ")
		if text.is_empty() or text == _last_text.get(where, ""):
			continue
		_last_text[where] = text
		_texts.store_line("%s\t%d\t%s\t%s" % [where, screen.world().map_id().y, leg, text])
		_texts.flush()


func _box_lines(box: Gen2TextBox) -> String:
	if box == null or not is_instance_valid(box) or not box.visible or box.is_revealing():
		return ""
	var shown: PackedStringArray = []
	for line: String in box.text_lines():
		if shown.is_empty() or shown[-1] != line:
			shown.append(line)
	return "\n".join(shown)


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
	if not _room() or not bool(_played._editor.add_party_member(MACHOKE, _kit.BROCK_LEVEL).get("ok", false)):
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
