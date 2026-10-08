class_name PokeCoopRemoteActor
extends RefCounted

## The other players as world actors, registered as a mod's are, eased over a walk's frames in one colour
## each in every window and wearing the shock emote in a battle; this player's position goes to the host.

const STEP_FRAMES: int = 16
const PLAYER_COLORS: Array = [
	[Color8(248, 248, 248), Color8(248, 152, 120), Color8(200, 48, 32), Color8(48, 16, 16)],
	[Color8(248, 248, 248), Color8(120, 176, 248), Color8(32, 72, 200), Color8(16, 16, 48)],
	[Color8(248, 248, 248), Color8(144, 216, 120), Color8(40, 136, 56), Color8(16, 40, 16)],
	[Color8(248, 248, 248), Color8(248, 216, 112), Color8(184, 128, 24), Color8(56, 32, 8)],
]

var client: PokeCoopClient = null
var _world: Gen2WorldAPI = null
var _reported: Dictionary = {}
var _walks: Dictionary = {}


static func over(session: PokeCoopClient) -> PokeCoopRemoteActor:
	var out := PokeCoopRemoteActor.new()
	out.client = session
	return out


func set_world(world: Gen2WorldAPI) -> void:
	_world = world
	_walks.clear()


func advance_frame() -> void:
	if _world == null or client == null:
		return
	_report()
	for player_id: String in _visible():
		_advance_walk(player_id)


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


func _view(player_id: String) -> Dictionary:
	return (client.state.get("players", {}) as Dictionary).get(player_id, {})


func _advance_walk(player_id: String) -> void:
	var target := Vector2(_view(player_id)["cell"] as Vector2i)
	var walk: Dictionary = _walks.get(player_id, {})
	if walk.is_empty() or walk["to"] != target:
		var start: Vector2 = target if walk.is_empty() else walk["at"]
		if start.distance_to(target) > float(PokeCoopHost.MAX_STEP_CELLS):
			start = target
		walk = {"from": start, "to": target, "at": start, "frame": 0}
	if walk["at"] != walk["to"]:
		walk["frame"] = int(walk["frame"]) + 1
		var progress: float = minf(float(walk["frame"]) / float(STEP_FRAMES), 1.0)
		walk["at"] = (walk["from"] as Vector2).lerp(walk["to"], progress)
	_walks[player_id] = walk


func sprites() -> Array:
	var out: Array = []
	if _world == null or client == null:
		return out
	for player_id: String in _visible():
		var view: Dictionary = _view(player_id)
		var walk: Dictionary = _walks.get(player_id, {})
		var entry: Dictionary = {
			"sprite": Gen2WorldSprite.SPRITE_PLAYER, "facing": int(view["facing"]),
			"position_cells": walk.get("at", Vector2(view["cell"] as Vector2i)),
			"frame": _walk_frame(walk), "id": StringName(player_id), "colors": _colors(player_id),
			"solid": true,
		}
		if not String(view.get("battle", "")).is_empty():
			entry["emote"] = Gen2WorldActors.EMOTE_SHOCK
		out.append(entry)
	return out


func _colors(player_id: String) -> PackedColorArray:
	return colors_of(client.state, player_id)


static func colors_of(state: Dictionary, player_id: String) -> PackedColorArray:
	var ids: Array = (state.get("players", {}) as Dictionary).keys()
	ids.sort()
	return PackedColorArray(PLAYER_COLORS[maxi(ids.find(player_id), 0) % PLAYER_COLORS.size()])


static func _walk_frame(walk: Dictionary) -> int:
	if walk.is_empty() or walk["at"] == walk["to"]:
		return 0
	return 1 if (int(walk["frame"]) / (STEP_FRAMES / 2)) % 2 == 0 else 3
