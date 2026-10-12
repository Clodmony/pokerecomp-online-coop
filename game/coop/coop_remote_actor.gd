class_name PokeCoopRemoteActor
extends RefCounted

## The other players as world actors, registered as a mod's are, eased at their own pace in one colour each in
## every window and wearing the shock emote in a battle; this player's position goes to the host, and B held runs.
## A partner off the screen is an arrow on its edge, or over the door or edge on the way to them, and an icon on the TOWN MAP.

const STEP_FRAMES: int = 16
const PLAYER_COLORS: Array = [
	[Color8(248, 248, 248), Color8(248, 152, 120), Color8(200, 48, 32), Color8(48, 16, 16)],
	[Color8(248, 248, 248), Color8(120, 176, 248), Color8(32, 72, 200), Color8(16, 16, 48)],
	[Color8(248, 248, 248), Color8(144, 216, 120), Color8(40, 136, 56), Color8(16, 40, 16)],
	[Color8(248, 248, 248), Color8(248, 216, 112), Color8(184, 128, 24), Color8(56, 32, 8)],
]

const ARROW_SIDE: PackedStringArray = ["oo......", "offo....", "offffo..", "offffffo", "offffffo", "offffo..", "offo....", "oo......"]
const ARROW_CORNER: PackedStringArray = [".......o", "......oo", ".....ofo", "....offo", "...offfo", "..offffo", ".offfffo", "oooooooo"]
const ARROW_SIZE: int = 8
const MARK_INSET: int = 4
const MARK_BLINK_FRAMES: int = 52
const MARK_CYCLE_FRAMES: int = 64
const SCREEN_MIDDLE: Vector2 = Vector2(72, 68)
const ROUTE_MAPS: int = 256

var client: PokeCoopClient = null
var meet: Callable = Callable()
var _world: Gen2WorldAPI = null
var _reported: Dictionary = {}
var _walks: Dictionary = {}
var _routes: Dictionary = {}
var _marks: TextureRect = null
var _marks_shown: String = ""
var _mark_frame: int = 0


static func over(session: PokeCoopClient) -> PokeCoopRemoteActor:
	var out := PokeCoopRemoteActor.new()
	out.client = session
	return out


func set_world(world: Gen2WorldAPI) -> void:
	_world = world
	_walks.clear()
	_routes.clear()


func advance_frame() -> void:
	if _world == null or client == null:
		return
	_report()
	var shown: Dictionary = _shown()
	for player_id: String in shown:
		_advance_walk(player_id, shown[player_id])


func _report() -> void:
	var here: Dictionary = {
		"map": _world.map_id(), "cell": _world.player_cell, "facing": _world.player_facing,
		"places": {"gen1_last_map": _world.gen1_last_map(), "gen1_last_blackout_map": _world.gen1_last_blackout_map()},
	}
	if here == _reported or not client.connected:
		return
	var walked: bool = not _reported.is_empty() and here["map"] == _reported["map"] \
		and _distance(here["cell"], _reported["cell"]) <= PokeCoopHost.MAX_STEP_CELLS
	if here["map"] != _reported.get("map"):
		client.journal.add(PokeCoopLog.WORLD, "map", {"map": here["map"], "cell": here["cell"], "from": _reported.get("map")}, client.player_id)
	_reported = here
	client.step(here["map"], here["cell"], here["facing"], not walked, here["places"])


static func _distance(first: Vector2i, second: Vector2i) -> int:
	return absi(first.x - second.x) + absi(first.y - second.y)


## Nobody in a Cable Club room, whose own friend sprite is the partner there.
func _visible() -> Array[String]:
	var out: Array[String] = []
	if _world.gen1_link_state() == Gen1Layout.LINK_STATE_IN_CABLE_CLUB:
		return out
	for player_id: Variant in client.nearby():
		var view: Dictionary = _view(String(player_id))
		if not view.is_empty() and view.get("map") == _world.map_id():
			out.append(String(player_id))
	return out


func _shown() -> Dictionary:
	var out: Dictionary = {}
	for player_id: String in _visible():
		out[player_id] = Vector2.ZERO
	if _world.gen1_link_state() == Gen1Layout.LINK_STATE_IN_CABLE_CLUB:
		return out
	var everyone: Dictionary = client.state.get("players", {})
	for player_id: String in everyone:
		var view: Dictionary = everyone[player_id]
		if player_id == client.player_id or out.has(player_id) or not _partner_out(view) or view["map"] == _world.map_id():
			continue
		var route: Dictionary = _route(view["map"])
		if route.has("origin"):
			out[player_id] = route["origin"]
	return out


func _partner_out(view: Dictionary) -> bool:
	return bool(view.get("connected", false)) and view.get("opening") != true and view.get("map") is Vector2i and view.get("cell") is Vector2i


func _view(player_id: String) -> Dictionary:
	return (client.state.get("players", {}) as Dictionary).get(player_id, {})


func _advance_walk(player_id: String, origin: Vector2) -> void:
	var target: Vector2 = origin + Vector2(_view(player_id)["cell"] as Vector2i)
	var walk: Dictionary = _walks.get(player_id, {})
	if walk.is_empty() or walk["to"] != target:
		var start: Vector2 = target if walk.is_empty() else walk["at"]
		if start.distance_to(target) > float(PokeCoopHost.MAX_STEP_CELLS):
			start = target
		var pace: int = clampi(int(walk.get("since", STEP_FRAMES)), STEP_FRAMES / 2, STEP_FRAMES)
		walk = {"from": start, "to": target, "at": start, "frame": 0, "frames": pace, "since": 0}
	walk["since"] = int(walk["since"]) + 1
	if walk["at"] != walk["to"]:
		walk["frame"] = int(walk["frame"]) + 1
		var progress: float = minf(float(walk["frame"]) / float(walk["frames"]), 1.0)
		walk["at"] = (walk["from"] as Vector2).lerp(walk["to"], progress)
	_walks[player_id] = walk


func runs_while_held() -> bool:
	return client != null


func sprites() -> Array:
	var out: Array = []
	if _world == null or client == null:
		return out
	var shown: Dictionary = _shown()
	for player_id: String in shown:
		var view: Dictionary = _view(player_id)
		var walk: Dictionary = _walks.get(player_id, {})
		var entry: Dictionary = {
			"sprite": Gen2WorldSprite.SPRITE_PLAYER, "facing": int(view["facing"]),
			"position_cells": walk.get("at", (shown[player_id] as Vector2) + Vector2(view["cell"] as Vector2i)),
			"frame": _walk_frame(walk), "id": StringName(player_id), "colors": _colors(player_id),
			"solid": view.get("map") == _world.map_id(),
		}
		if not String(view.get("battle", "")).is_empty():
			entry["emote"] = Gen2WorldActors.EMOTE_SHOCK
		out.append(entry)
	return out


func interact(cell: Vector2i, _facing: int) -> bool:
	if not meet.is_valid():
		return false
	for id: String in _visible():
		if _view(id).get("cell") == cell:
			meet.call(id)
			return true
	return false


func _colors(player_id: String) -> PackedColorArray:
	return colors_of(client.state, player_id)


static func colors_of(state: Dictionary, player_id: String) -> PackedColorArray:
	var ids: Array = (state.get("players", {}) as Dictionary).keys()
	ids.sort()
	return PackedColorArray(PLAYER_COLORS[maxi(ids.find(player_id), 0) % PLAYER_COLORS.size()])


static func _walk_frame(walk: Dictionary) -> int:
	if walk.is_empty() or walk["at"] == walk["to"]:
		return 0
	return 1 if (int(walk["frame"]) / (int(walk["frames"]) / 2)) % 2 == 0 else 3


func show_marks(hardware: Gen2Screen, quiet: bool) -> void:
	_mark_frame += 1
	var marks: Array = partner_marks() if quiet and _mark_frame % MARK_CYCLE_FRAMES < MARK_BLINK_FRAMES else []
	if _marks != null and not is_instance_valid(_marks):
		_marks = null
	if marks.is_empty() or hardware == null:
		if _marks != null:
			_marks.visible = false
		return
	if _marks == null:
		_marks = TextureRect.new()
		_marks.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hardware.viewport().add_child(_marks)
		hardware.viewport().move_child(_marks, hardware.interface_layer().get_index())
		_marks_shown = ""
	_marks.visible = true
	var key: String = str(marks)
	if key == _marks_shown:
		return
	_marks_shown = key
	var image := Image.create(_world.view_pixels.x, _world.view_pixels.y, false, Image.FORMAT_RGBA8)
	for mark: Dictionary in marks:
		var arrow: Image = arrow_image(mark["direction"], mark["colors"])
		image.blend_rect(arrow, Rect2i(Vector2i.ZERO, arrow.get_size()), mark["at"])
	Gen2PicImage.show(_marks, image)


func partner_marks() -> Array:
	var out: Array = []
	if _world == null or client == null or _world.current_map == null or _world.gen1_link_state() == Gen1Layout.LINK_STATE_IN_CABLE_CLUB:
		return out
	var everyone: Dictionary = client.state.get("players", {})
	for player_id: String in everyone:
		var view: Dictionary = everyone[player_id]
		if player_id == client.player_id or not _partner_out(view):
			continue
		var goal: Dictionary = _goal(player_id, view)
		if goal.is_empty():
			continue
		var mark: Dictionary = _mark_towards(goal)
		if not mark.is_empty():
			mark["id"] = player_id
			mark["colors"] = _colors(player_id)
			out.append(mark)
	return out


func _goal(player_id: String, view: Dictionary) -> Dictionary:
	var route: Dictionary = _route(view["map"])
	if route.has("origin"):
		var at: Vector2 = (route["origin"] as Vector2) + Vector2(view["cell"] as Vector2i)
		return {"partner": (_walks.get(player_id, {}) as Dictionary).get("at", at)}
	if route.has("door"):
		return {"cell": _door(route["door"], view["map"], view["cell"])}
	var here: Dictionary = _world.data.landmark(_world.data.area_landmark(_world.map_id().y))
	var there: Dictionary = _world.data.landmark(_world.data.area_landmark((view["map"] as Vector2i).y))
	if here.is_empty() or there.is_empty():
		return {}
	var apart := Vector2(int(there["x"]) - int(here["x"]), int(there["y"]) - int(here["y"]))
	return {} if apart == Vector2.ZERO else {"direction": apart}


func _mark_towards(goal: Dictionary) -> Dictionary:
	var size := Vector2(_world.view_pixels)
	var middle: Vector2 = SCREEN_MIDDLE + Vector2(_world.view_surround_offset())
	var away: Vector2 = goal.get("direction", Vector2.ZERO)
	if not goal.has("direction"):
		var cell: Vector2 = goal.get("partner", goal.get("cell", Vector2.ZERO))
		var drawn: Vector2 = (cell - _world.visible_origin_cells()) * float(Gen2WorldAPI.CELL_PIXELS) + middle - SCREEN_MIDDLE + Vector2(8, 4)
		if Rect2(Vector2.ZERO, size).has_point(drawn):
			if goal.has("partner") or Vector2i(cell) == _world.player_cell:
				return {}
			var over: Vector2 = (drawn - Vector2(ARROW_SIZE / 2, ARROW_SIZE + 6)).clamp(Vector2.ONE * MARK_INSET, size - Vector2.ONE * (MARK_INSET + ARROW_SIZE))
			return {"at": Vector2i(over), "direction": Vector2i.DOWN}
		away = drawn - middle
	var low := Vector2.ONE * float(MARK_INSET + ARROW_SIZE / 2)
	var reach := Vector2(
		((size.x - low.x - middle.x) if away.x > 0.0 else (middle.x - low.x)) / maxf(absf(away.x), 0.001),
		((size.y - low.y - middle.y) if away.y > 0.0 else (middle.y - low.y)) / maxf(absf(away.y), 0.001))
	var at: Vector2 = (middle + away * minf(reach.x, reach.y)).clamp(low, size - low)
	return {"at": Vector2i(at) - Vector2i.ONE * (ARROW_SIZE / 2), "direction": eighth(away)}


static func eighth(away: Vector2) -> Vector2i:
	var turn: int = posmod(roundi(away.angle() / (PI / 4.0)), 8)
	return Vector2i(Vector2.RIGHT.rotated(turn * PI / 4.0).round())


static func arrow_image(direction: Vector2i, colors: PackedColorArray) -> Image:
	var corner: bool = direction.x != 0 and direction.y != 0
	var rows: PackedStringArray = ARROW_CORNER if corner else ARROW_SIDE
	var image := Image.create(ARROW_SIZE, ARROW_SIZE, false, Image.FORMAT_RGBA8)
	for y: int in ARROW_SIZE:
		for x: int in ARROW_SIZE:
			var pixel: String = rows[y][x]
			if pixel != ".":
				image.set_pixel(x, y, colors[3] if pixel == "o" else colors[2])
	if corner:
		if direction.x < 0:
			image.flip_x()
		if direction.y < 0:
			image.flip_y()
	elif direction.x < 0:
		image.flip_x()
	elif direction.y != 0:
		image.rotate_90(CLOCKWISE if direction.y > 0 else COUNTERCLOCKWISE)
	return image


## Breadth first over warps and connections: `origin` where connections alone reach, else `door`, whose [method _door] is walkable and lands nearest them.
func _route(to: Vector2i) -> Dictionary:
	var start: Vector2i = _world.map_id()
	var key: String = "%s|%s|%d" % [start, to, _world.gen1_last_map()]
	if _routes.has(key):
		return _routes[key]
	var seen: Dictionary = {start: {"origin": Vector2.ZERO, "own": true}}
	var queue: Array[Vector2i] = [start]
	var found: Dictionary = {}
	while not queue.is_empty() and seen.size() < ROUTE_MAPS:
		var at: Vector2i = queue.pop_front()
		if at == to:
			found = seen[at]
			break
		var map: Gen2WorldMap = _world.data.world_map(at.x, at.y)
		if map == null:
			continue
		for step: Dictionary in _steps(map, seen[at]):
			if not seen.has(step["map"]):
				seen[step["map"]] = step
				queue.append(step["map"])
	if found.is_empty() and seen.has(to):
		found = seen[to]
	_routes[key] = found
	return found


func _steps(map: Gen2WorldMap, here: Dictionary) -> Array:
	var out: Array = []
	for connection: Dictionary in map.connections:
		var next := Vector2i(int(connection.get("map_group", -1)), int(connection.get("map_number", -1)))
		var target: Gen2WorldMap = _world.data.world_map(next.x, next.y)
		if target == null:
			continue
		var step: Dictionary = {"map": next, "own": false}
		if here.has("origin"):
			step["origin"] = (here["origin"] as Vector2) \
				+ Vector2(Gen2WorldAPI.connection_origin_blocks(map, target, connection) * Gen2Layout.MAP_BLOCK_CELL_WIDTH)
		elif here.has("door"):
			step["door"] = here["door"]
		out.append(step)
	for warp: Dictionary in map.events.get("warps", []):
		var next: Vector2i = _warp_target(map, warp, bool(here["own"]))
		if next.y < 0:
			continue
		var step: Dictionary = {"map": next, "own": bool(here["own"]) and next.y != _world.gen1_last_map()}
		if here.has("origin"):
			step["door"] = {"map": map, "origin": here["origin"], "own": here["own"], "to": next}
		elif here.has("door"):
			step["door"] = here["door"]
		out.append(step)
	return out


func _warp_target(map: Gen2WorldMap, warp: Dictionary, own: bool) -> Vector2i:
	var number: int = int(warp.get("map_number", -1))
	if number == Gen1Layout.WARP_TO_LAST_MAP:
		number = _world.gen1_last_map() if own else -1
	return Vector2i(int(warp.get("map_group", map.group)), number)


func _door(door: Dictionary, to: Vector2i, cell: Vector2i) -> Vector2:
	var map: Gen2WorldMap = door["map"]
	var target: Gen2WorldMap = _world.data.world_map(to.x, to.y) if door["to"] == to else null
	var best: Vector2 = Vector2.INF
	var best_score: float = INF
	for warp: Dictionary in map.events.get("warps", []):
		if _warp_target(map, warp, bool(door["own"])) != door["to"]:
			continue
		var at := Vector2(int(warp.get("x", 0)), int(warp.get("y", 0)))
		var block := Vector2i((at / float(Gen2Layout.MAP_BLOCK_CELL_WIDTH)).floor())
		var reached: bool = Vector2i(map.group, map.number) != _world.map_id() or _world.camera_reaches(block.x, block.y)
		var score: float = (0.0 if reached else 10000.0) + at.distance_to(Vector2(_world.player_cell))
		var arrival: Array = target.events.get("warps", []) if target != null else []
		var landing: int = int(warp.get("destination", -1))
		if landing >= 0 and landing < arrival.size():
			score = (0.0 if reached else 10000.0) + Vector2(int(arrival[landing].get("x", 0)), int(arrival[landing].get("y", 0))).distance_to(Vector2(cell))
		if score < best_score:
			best_score = score
			best = (door["origin"] as Vector2) + at
	return best


func town_map_marks() -> Array:
	var out: Array = []
	if client == null or _world == null:
		return out
	var everyone: Dictionary = client.state.get("players", {})
	for player_id: String in everyone:
		var view: Dictionary = everyone[player_id]
		if player_id != client.player_id and _partner_out(view):
			out.append({"map": _world.data.area_landmark((view["map"] as Vector2i).y), "colors": _colors(player_id)})
	return out
