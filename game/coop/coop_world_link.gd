class_name PokeCoopWorldLink
extends RefCounted

## A window's world opened as a Continue does, its state, party and PC in step with the host at rest points (D72).

const PARTY_CHECK_FRAMES: int = 30
## A scene's states hand over with a frame or two between them that no script holds.
const REST_FRAMES: int = 3
const VERMILION_CITY := Vector2i(0, 5)
const VERMILION_GYM := Vector2i(0, 92)
const CINNABAR_GYM := Vector2i(0, 166)
const EVENT_CINNABAR_GYM_GATE1_UNLOCKED: int = 681
const CINNABAR_GATES_REDRAWN: Array = [CINNABAR_GYM, Gen1Layout.MAP_LOADED_1_BIT]
const MAP_LOADS_OWED_BY_FLAG: Dictionary = {
	Gen1Layout.LOCK_2ND_EVENT: [VERMILION_GYM, Gen1Layout.MAP_LOADED_2_BIT],
	EVENT_CINNABAR_GYM_GATE1_UNLOCKED: CINNABAR_GATES_REDRAWN, EVENT_CINNABAR_GYM_GATE1_UNLOCKED + 1: CINNABAR_GATES_REDRAWN,
	EVENT_CINNABAR_GYM_GATE1_UNLOCKED + 2: CINNABAR_GATES_REDRAWN, EVENT_CINNABAR_GYM_GATE1_UNLOCKED + 3: CINNABAR_GATES_REDRAWN,
	EVENT_CINNABAR_GYM_GATE1_UNLOCKED + 4: CINNABAR_GATES_REDRAWN, EVENT_CINNABAR_GYM_GATE1_UNLOCKED + 5: CINNABAR_GATES_REDRAWN,
}
const NO_SCENE := Vector2i(-1, -1)

var client: PokeCoopClient = null
var world: Gen2WorldAPI = null
var state: Gen2WorldState = null
var save: Gen2SaveData = null
var badge_flags: Array[int] = []
var _baseline: Dictionary = {}
var _host_seen: Dictionary = {}
var _dirty: bool = true
var _holdings_sent: Dictionary = {}
var _rev_seen: int = -1
var _box_rev_seen: int = -1
var _uids: Array = []
var _box_uids: Array = []
## Stored Pokémon only move, so the PC is re-read only when its slots change.
var _box_objects: Array = []
var _box_rows: Array = []
var _frames: int = 0
## A SAVE or a transaction writes a fresh snapshot, a battle a copy; a SAVE checkpoints, a gated one with its scene.
var _saved_world: Object = null
var _saved_frame: int = 0
var save_seq: int = -1
var hold_holdings: bool = false
## Why the window is away from a rest point (D72), empty at one: a scene leaves whole when it ends, or with a SAVE.
var busy: StringName = &""
var _save_allowed: bool = false
var _save_written: bool = false
var _rest_streak: int = 0
var _held_frames: int = 0
var _held_by: StringName = &""
var _owed_step: Dictionary = {}
var _scene: Vector2i = NO_SCENE
var _scene_welcome: int = -1
var scene_driver: String = ""
## Patches the host has not applied yet, by sequence number (D51).
var _unacked: Dictionary = {}


static func over(
	session: PokeCoopClient, world_state: Gen2WorldState, window_save: Gen2SaveData, data: GameData
) -> PokeCoopWorldLink:
	var out := PokeCoopWorldLink.new()
	out.client = session
	out.state = world_state
	out.save = window_save
	out.badge_flags = PokeCoopOwnership.badge_flags(data)
	out._rev_seen = int(session.me().get("holdings_rev", -1))
	out._holdings_sent = out._holdings()
	out._world_saved()
	world_state.changed.connect(out._on_state_changed)
	return out


func _on_state_changed() -> void:
	_dirty = true


## Once a frame, this window's changes go out before the host's come in, and wait while the link is down.
func advance() -> void:
	if client == null or client.me().is_empty() or not client.connected:
		return
	var asked: bool = _save_allowed
	_save_allowed = false
	_rest_streak = _rest_streak + 1 if busy.is_empty() else 0
	var resting: bool = _rest_streak >= REST_FRAMES
	var scene_ended: bool = resting and _held_frames > 0
	if resting:
		_push_world()
		_land_owed_step()
		_pull_world()
		_held_frames = 0
	else:
		_held_frames += 1
		_held_by = busy if not busy.is_empty() else _held_by
	_frames += 1
	_tend_scene(resting)
	if hold_holdings:
		return
	if resting and _is_free() and (scene_ended or _frames % PARTY_CHECK_FRAMES == 0):
		push_party()
	_pull_party()
	var written: bool = _save_written
	_save_written = false
	if _world_saved() or written:
		if asked:
			_push_world()
		push_party()
		if written:
			save_seq = client.request_save()


## Why [param screen]'s world is not where the cartridge could save: a script, map load, forced walk, battle or overlay.
static func unrest(screen: Gen2WorldScreen) -> StringName:
	var world: Gen2WorldAPI = screen.world()
	if screen.process_mode == Node.PROCESS_MODE_DISABLED:
		return &"panel"
	if world.script_busy():
		return &"script"
	if world.gen1_map_load_pending():
		return &"map_load"
	if world.gen1_player_movement_running() or world.gen1_object_movement_running() or world.gen1_movement_script_running():
		return &"movement"
	if screen.get("_battle_host") != null or screen.get("_takeover_host") != null:
		return &"battle"
	if Gen2WorldScreen.OVERLAY_HOSTS.any(func(host: StringName) -> bool: return screen.get(host) != null):
		return &"overlay"
	return &"locked" if bool(screen.call(&"_input_locked")) else &""


func _push_world() -> void:
	_keep_locks()
	if not _dirty or _host_seen.is_empty():
		return
	_dirty = false
	var now: Dictionary = state.to_dict()
	var changes: Dictionary = PokeCoopOwnership.patch(_baseline, now)
	_baseline = now
	if not changes.is_empty():
		_unacked[client.send({"type": "world", "patch": changes})] = changes


## `.setFirstLockTrashCanIndex` rolls on every load of the city; with a partner in the city or gym, the agreed lock stays.
func _keep_locks() -> void:
	if world == null or world.map_id() != VERMILION_CITY or _baseline.is_empty():
		return
	var agreed: int = int((_baseline.get("gen1_bytes", {}) as Dictionary).get(Gen2WorldAPI.GEN1_FIRST_LOCK, 0))
	var rolled: int = state.gen1_byte(Gen2WorldAPI.GEN1_FIRST_LOCK)
	if rolled != agreed and not _partner_on([VERMILION_CITY, VERMILION_GYM]).is_empty():
		client.journal.add(PokeCoopLog.WORLD, "locks_kept", {"rolled": rolled, "kept": agreed}, client.player_id)
		state.set_gen1_byte(Gen2WorldAPI.GEN1_FIRST_LOCK, agreed)


func _partner_on(maps: Array, key: String = "map") -> String:
	var players: Dictionary = client.state.get("players", {})
	for player_id: String in players:
		var view: Dictionary = players[player_id]
		if player_id != client.player_id and bool(view.get("connected", false)) and maps.has(view.get(key)):
			return player_id
	return ""


## A rival scene this world plays is claimed as it starts and given back once its result is out (#24).
func _tend_scene(resting: bool) -> void:
	var map: Vector2i = world.map_id() if world != null else NO_SCENE
	var states: Array = PokeCoopPolicy.RIVAL_SCENES.get(map, [])
	var playing: bool = states.has(Gen1MapScripts.gen1_map_script_state(world)) if not states.is_empty() else false
	if playing and (_scene != map or _scene_welcome != client.welcomes):
		_scene = map
		_scene_welcome = client.welcomes
		client.send({"type": "scene", "map": map, "on": true})
	elif _scene != NO_SCENE and resting and not playing:
		client.send({"type": "scene", "map": _scene, "on": false})
		_scene = NO_SCENE
	_wait_on_scene(map, resting)


## A partner's rival scene is waited out from rest point to rest point, then its result lands with its script step (#24).
func _wait_on_scene(map: Vector2i, resting: bool) -> void:
	var driver: String = _partner_on([map], "scene") if _scene == NO_SCENE and map != NO_SCENE else ""
	if not resting:
		driver = scene_driver
	elif scene_driver.is_empty() and world != null and world.player_step_in_progress():
		driver = ""
	if driver == scene_driver:
		return
	client.journal.add(PokeCoopLog.WORLD, "scene_wait", {"map": map, "driver": driver, "after": scene_driver}, client.player_id)
	scene_driver = driver
	if driver.is_empty():
		_land_owed_step(true)


static func _host_world(session: PokeCoopClient) -> Dictionary:
	var shared: Dictionary = (session.state.get("campaign", {}) as Dictionary).get("world", {})
	var own: Dictionary = session.me().get("world", {})
	var out: Dictionary = shared.duplicate(true)
	for key: String in own:
		if out.get(key) is Dictionary and own[key] is Dictionary:
			(out[key] as Dictionary).merge(own[key], true)
		else:
			out[key] = own[key]
	return out


func _pull_world() -> void:
	var host: Dictionary = _host_world(client)
	if host == _host_seen:
		return
	var changes: Dictionary = PokeCoopOwnership.patch(_host_seen, host)
	_host_seen = host
	var applied: int = int(client.state.get("last_seq", 0))
	for seq: int in _unacked.keys():
		if seq <= applied:
			_unacked.erase(seq)
	var echoes: Dictionary = {}
	for pending: Dictionary in _unacked.values():
		_drop_overlap(changes, pending, echoes)
	var owed: int = _owe_step(changes)
	if not changes.is_empty() or not echoes.is_empty() or owed >= 0:
		client.journal.add(PokeCoopLog.WORLD, "world_pull", {"changes": changes, "echoes": echoes, "unacked": _unacked.keys(),
			"held": _held_frames, "held_by": _held_by, "owed": owed}, client.player_id)
	if not changes.is_empty():
		var merged: Dictionary = state.to_dict()
		PokeCoopOwnership.apply_patch(merged, changes)
		state.restore_from_dict(merged)
		_owe_map_loads((changes.get("event_flags", {}) as Dictionary).get("set", {}))
		if world != null and changes.has("toggled_objects"):
			world.load_object_masks()
	_baseline = state.to_dict()
	_dirty = false


## A step for the map the window stands on waits for its next map load, never landing under the player: the byte, or -1.
func _owe_step(changes: Dictionary) -> int:
	var change: Dictionary = changes.get("gen1_map_scripts", {})
	var byte: int = Gen1MapScripts._gen1_map_script_byte(world) if world != null and world.current_map != null else -1
	var entries: Dictionary = change.get("set", change.get("value", {}))
	var mine: int = state.gen1_map_script(byte)
	var lands: bool = entries.has(byte) or change.has("value") or (change.get("erase", []) as Array).has(byte)
	if byte < 0 or not lands or int(entries.get(byte, 0)) == mine:
		return -1
	_owed_step = {"map": world.map_id(), "byte": byte}
	if change.has("value"):
		var kept: Dictionary = entries.duplicate()
		kept.erase(byte)
		if mine != 0:
			kept[byte] = mine
		change["value"] = kept
	else:
		(change["set"] as Dictionary).erase(byte)
		(change["erase"] as Array).erase(byte)
	if (change.get("set", {}) as Dictionary).is_empty() and (change.get("erase", []) as Array).is_empty() and not change.has("value"):
		changes.erase("gen1_map_scripts")
	return byte


func _land_owed_step(waited: bool = false) -> void:
	if _owed_step.is_empty() or world == null or (world.map_id() == _owed_step["map"] and not waited):
		return
	var byte: int = _owed_step["byte"]
	_owed_step = {}
	if _unacked.values().any(func(sent: Dictionary) -> bool: return PokeCoopWorldLink._touches(sent, byte)):
		return
	state.set_gen1_map_script(byte, int((_host_seen.get("gen1_map_scripts", {}) as Dictionary).get(byte, 0)))
	_baseline = state.to_dict()
	_dirty = false


static func _touches(sent: Dictionary, byte: int) -> bool:
	var change: Dictionary = sent.get("gen1_map_scripts", {})
	return (change.get("set", change.get("value", {})) as Dictionary).has(byte) or (change.get("erase", []) as Array).has(byte)


func _owe_map_loads(flags_set: Dictionary) -> void:
	for flag: int in MAP_LOADS_OWED_BY_FLAG:
		var owed: Array = MAP_LOADS_OWED_BY_FLAG[flag]
		if world != null and bool(flags_set.get(flag, false)) and world.map_id() == owed[0]:
			world.set("_gen1_map_load_pending", int(world.get("_gen1_map_load_pending")) | (1 << int(owed[1])))


static func _drop_overlap(changes: Dictionary, pending: Dictionary, echoes: Dictionary) -> void:
	for key: String in pending:
		if not changes.has(key):
			continue
		var mine: Dictionary = pending[key]
		var theirs: Dictionary = changes[key]
		if mine.has("value") or theirs.has("value"):
			echoes[key] = theirs
			changes.erase(key)
			continue
		for entry: Variant in (mine.get("set", {}) as Dictionary).keys() + (mine.get("erase", []) as Array):
			if (theirs.get("set", {}) as Dictionary).erase(entry) or (theirs.get("erase", []) as Array).has(entry):
				(echoes.get_or_add(key, []) as Array).append(entry)
			(theirs.get("erase", []) as Array).erase(entry)


## The world's START > SAVE gate: the host's last state names why it would refuse a checkpoint.
func save_refusal() -> Dictionary:
	var blocked: String = String((client.state.get("saved", {}) as Dictionary).get("blocked", ""))
	if not blocked.is_empty():
		client.journal.add(PokeCoopLog.WORLD, "save_gate", {"reason": blocked}, client.player_id)
	_save_allowed = blocked.is_empty()
	return {} if blocked.is_empty() else {"ok": false, "reason": blocked.replace("_", " ")}


func note_save_written() -> void:
	_save_written = true


func _world_saved() -> bool:
	if save.world == _saved_world:
		return false
	_saved_world = save.world
	var frame: int = save.world.frame_number if save.world != null else _saved_frame
	var saved: bool = frame != _saved_frame and busy != &"battle"
	_saved_frame = frame
	return saved


## The save a window's world explores on: this player's name, party and PC.
static func local_save(session: PokeCoopClient, data: GameData) -> Gen2SaveData:
	var me: Dictionary = session.me()
	var out := Gen2SaveData.new()
	out.game_id = data.id
	out.rom_sha1 = data.sha1
	out.player_name = String(me.get("name", ""))
	out.player_id = int(me.get("trainer_id", 0))
	out.slot = 0
	out.run_rules = Gen2Rules.new()
	_fill(out, me, session.box.get("rows", []))
	var world: Gen2WorldSnapshot = continued_world(session)
	var map: Gen2WorldMap = data.world_map(world.map_id.x, world.map_id.y)
	if map != null:
		if data.generation == RomRegistry.GEN1 and afloat(data.world_tileset(map.tileset), map, world.player_cell):
			world.movement_mode = Gen2WorldAPI.MOVEMENT_SURF
			world.player_sprite_number = Gen2WorldSprite.SPRITE_SURF
		out.world = world
	return out


static func afloat(tileset: Gen2WorldTileset, map: Gen2WorldMap, cell: Vector2i) -> bool:
	return Gen2WorldCollision.gen1_permission(tileset, map.collision_at(cell.x, cell.y)) == Gen2WorldCollision.WATER_TILE


static func continued_world(session: PokeCoopClient) -> Gen2WorldSnapshot:
	var view: Dictionary = (session.state.get("players", {}) as Dictionary).get(session.player_id, {})
	var places: Dictionary = session.me().get("places", {})
	var out := Gen2WorldSnapshot.new()
	out.map_id = view.get("map", PokeCoopPolicy.START_MAP)
	out.player_cell = view.get("cell", Vector2i.ZERO)
	out.player_facing = int(view.get("facing", Gen2WorldSprite.FACING_DOWN))
	out.world_state = Gen2WorldState.from_dict(_host_world(session))
	out.gen1_last_map = int(places.get("gen1_last_map", out.gen1_last_map))
	out.gen1_last_blackout_map = int(places.get("gen1_last_blackout_map", out.gen1_last_blackout_map))
	return out


static func _fill(into: Gen2SaveData, me: Dictionary, stored: Array) -> void:
	into.party.clear()
	for row: Dictionary in me.get("party", []):
		var mon: Gen2SaveMon = Gen2SaveMon.from_dict(row["mon"])
		if mon != null:
			into.party.append(mon)
	for held: Gen2SaveBox in into.boxes:
		held.slots.fill(null)
	for row: Dictionary in stored:
		var at: int = clampi(int(row.get("box", 0)), 0, into.boxes.size() - 1)
		while at < into.boxes.size() - 1 and (into.boxes[at] as Gen2SaveBox).first_empty_slot() < 0:
			at += 1
		(into.boxes[at] as Gen2SaveBox).put(Gen2SaveMon.from_dict(row["mon"]))
	into.current_box = clampi(int(me.get("current_box", 0)), 0, into.boxes.size() - 1)


func uids() -> Array:
	return _uids.duplicate()


func _is_free() -> bool:
	var view: Dictionary = (client.state.get("players", {}) as Dictionary).get(client.player_id, {})
	return String(view.get("battle", "")).is_empty()


func _holdings() -> Dictionary:
	var objects: Array = save.boxes.map(func(held: Gen2SaveBox) -> Array: return held.slots.duplicate())
	if objects != _box_objects:
		_box_objects = objects
		_box_rows = []
		for held: Gen2SaveBox in save.boxes:
			_box_rows.append(held.slots.filter(func(mon: Variant) -> bool: return mon != null).map(
				func(mon: Gen2SaveMon) -> Dictionary: return mon.to_dict()
			))
	return {
		"party": save.party.map(func(mon: Gen2SaveMon) -> Dictionary: return mon.to_dict()),
		"boxes": _box_rows, "current_box": save.current_box,
	}


func push_party() -> void:
	var now: Dictionary = _holdings()
	if now == _holdings_sent:
		return
	var message: Dictionary = {
		"type": "party", "rows": _hinted(now["party"], _uids), "rev": _rev_seen,
		"current_box": now["current_box"],
	}
	if now["boxes"] != _holdings_sent.get("boxes") or now["current_box"] != _holdings_sent.get("current_box"):
		var stored: Array = []
		for at: int in (now["boxes"] as Array).size():
			var uids_here: Array = _box_uids[at] if at < _box_uids.size() else []
			for row: Dictionary in _hinted(now["boxes"][at], uids_here):
				row["box"] = at
				stored.append(row)
		message["boxes"] = stored
	_holdings_sent = now
	client.send(message)


static func _hinted(mons: Array, hints: Array) -> Array:
	var out: Array = []
	for index: int in mons.size():
		out.append({"uid": hints[index] if index < hints.size() else "", "mon": mons[index]})
	return out


func _pull_party() -> void:
	var me: Dictionary = client.me()
	_uids = (me.get("party", []) as Array).map(func(row: Dictionary) -> String: return String(row["uid"]))
	var box_rev: int = int(client.box.get("rev", -1))
	if box_rev != _box_rev_seen:
		_box_rev_seen = box_rev
		_box_uids = []
		for row: Dictionary in client.box.get("rows", []):
			var at: int = int(row.get("box", 0))
			while _box_uids.size() <= at:
				_box_uids.append([])
			(_box_uids[at] as Array).append(String(row["uid"]))
	var rev: int = int(me.get("holdings_rev", -1))
	if rev == _rev_seen:
		return
	_rev_seen = rev
	client.journal.add(PokeCoopLog.WORLD, "party_pull", {"rev": rev, "party": (me.get("party", []) as Array).size(),
		"box": (client.box.get("rows", []) as Array).size()}, client.player_id)
	_fill(save, me, client.box.get("rows", []))
	_holdings_sent = _holdings()
