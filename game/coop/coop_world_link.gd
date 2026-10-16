class_name PokeCoopWorldLink
extends RefCounted

## A window's world opened as a Continue does, its state, party and PC in step with the host at rest points (D72).

const PARTY_CHECK_FRAMES: int = 30
## A scene's states hand over with a frame or two between them that no script holds.
const REST_FRAMES: int = 3
const VERMILION_CITY := Vector2i(0, 5)
const VERMILION_GYM := Vector2i(0, 92)
const VICTORY_ROAD_1F := Vector2i(0, 108)
const VICTORY_ROAD_2F := Vector2i(0, 194)
const VICTORY_ROAD_3F := Vector2i(0, 198)
const VICTORY_ROAD_FLOORS: Array[Vector2i] = [VICTORY_ROAD_1F, VICTORY_ROAD_2F, VICTORY_ROAD_3F]
const EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH: int = 2327
const EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1: int = 1336
const EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH2: int = 1343
const EVENT_VICTORY_ROAD_3_BOULDER_ON_SWITCH1: int = 1632
const HALL_OF_FAME := Vector2i(0, 0x76)
const CINNABAR_GYM := Vector2i(0, 166)
const EVENT_CINNABAR_GYM_GATE1_UNLOCKED: int = 681
const CINNABAR_GATES_REDRAWN: Array = [CINNABAR_GYM, Gen1Layout.MAP_LOADED_1_BIT]
const MAP_LOADS_OWED_BY_FLAG: Dictionary = {
	Gen1Layout.LOCK_2ND_EVENT: [VERMILION_GYM, Gen1Layout.MAP_LOADED_2_BIT],
	EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH: [VICTORY_ROAD_1F, Gen1Layout.MAP_LOADED_1_BIT],
	EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1: [VICTORY_ROAD_2F, Gen1Layout.MAP_LOADED_1_BIT],
	EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH2: [VICTORY_ROAD_2F, Gen1Layout.MAP_LOADED_1_BIT],
	EVENT_VICTORY_ROAD_3_BOULDER_ON_SWITCH1: [VICTORY_ROAD_3F, Gen1Layout.MAP_LOADED_1_BIT],
	EVENT_CINNABAR_GYM_GATE1_UNLOCKED: CINNABAR_GATES_REDRAWN, EVENT_CINNABAR_GYM_GATE1_UNLOCKED + 1: CINNABAR_GATES_REDRAWN,
	EVENT_CINNABAR_GYM_GATE1_UNLOCKED + 2: CINNABAR_GATES_REDRAWN, EVENT_CINNABAR_GYM_GATE1_UNLOCKED + 3: CINNABAR_GATES_REDRAWN,
	EVENT_CINNABAR_GYM_GATE1_UNLOCKED + 4: CINNABAR_GATES_REDRAWN, EVENT_CINNABAR_GYM_GATE1_UNLOCKED + 5: CINNABAR_GATES_REDRAWN,
}
const EVENT_BEAT_AGATHAS_ROOM_TRAINER_0: int = 0x8F1
const SCRIPT_CHAMPIONSROOM_PLAYER_ENTERS: int = 1
## A member beaten for the team opens the room's exit in a window inside (D91): `*ShowOrHideExitBlock` runs on a map load.
const LEAGUE_EXITS_REDRAWN: Dictionary = {
	0x8E1: [Vector2i(0, 0xF5), Gen1Layout.MAP_LOADED_1_BIT], 0x8E9: [Vector2i(0, 0xF6), Gen1Layout.MAP_LOADED_1_BIT],
	EVENT_BEAT_AGATHAS_ROOM_TRAINER_0: [Vector2i(0, 0xF7), Gen1Layout.MAP_LOADED_1_BIT],
}
const NO_SCENE := Vector2i(-1, -1)

var client: PokeCoopClient = null
var world: Gen2WorldAPI = null
var state: Gen2WorldState = null
var save: Gen2SaveData = null
var badge_flags: Array[int] = []
var johto: bool = false
var _rival_scenes: Dictionary = PokeCoopPolicy.RIVAL_SCENES
var _baseline: Dictionary = {}
var _host_seen: Dictionary = {}
var _dirty: bool = true
var _holdings_sent: Dictionary = {}
var _rev_seen: int = -1
var _box_rev_seen: int = -1
var _uids: Array = []
var _kept_uids: Array = []
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
var _kept_switches: Dictionary = {}
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
	out.johto = PokeCoopJohto.plays(data)
	out._rival_scenes = PokeCoopPolicy.rival_scenes(data)
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
		_release_switches()
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
		if asked or written:
			_push_world()
		push_party()
		if written:
			save_seq = client.request_save()


## Before the world goes (#88): a SAVE it just made leaves with its scene; answers the sequence number the host must reach.
func flush() -> int:
	if _save_written:
		_save_written = false
		_push_world()
		push_party()
		save_seq = client.request_save()
	return client.sent()


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
	var states: Array = _rival_scenes.get(map, [])
	var playing: bool = PokeCoopJohto.scene_playing(world) if johto \
		else states.has(Gen1MapScripts.gen1_map_script_state(world)) if not states.is_empty() else false
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
	var held: Dictionary = _held_erasures(host)
	if host == _host_seen and held.is_empty():
		return
	var changes: Dictionary = PokeCoopOwnership.patch(_host_seen, host)
	_host_seen = host
	if not held.is_empty():
		var flags: Dictionary = changes.get_or_add("event_flags", {"set": {}, "erase": []})
		var into: Dictionary = flags["value"] if flags.has("value") else flags.get_or_add("set", {})
		into.merge(held)
	var echoes: Dictionary = {}
	for pending: Dictionary in _unacked.values():
		_drop_overlap(changes, pending, echoes)
	var owed: int = _owe_step(changes)
	_keep_switches(changes)
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
	_ready_champions_room((changes.get("event_flags", {}) as Dictionary).get("set", {}))


## `AgathasRoomAgathaEndBattleScript` readies the Champion's room, which a world the team's win reached never ran.
func _ready_champions_room(flags_set: Dictionary) -> void:
	var byte: int = PokeCoopOwnership.PLAYER_MAP_SCRIPTS["wChampionsRoomCurScript"]
	if bool(flags_set.get(EVENT_BEAT_AGATHAS_ROOM_TRAINER_0, false)) and state.gen1_map_script(byte) == 0:
		state.set_gen1_map_script(byte, SCRIPT_CHAMPIONSROOM_PLAYER_ENTERS)


## Flags a patch the host has applied erased but the host still holds (the team's League run, D91), to take back.
func _held_erasures(host: Dictionary) -> Dictionary:
	var applied: int = int(client.state.get("last_seq", 0))
	var erased: Array = []
	for seq: int in _unacked.keys():
		if seq <= applied:
			erased.append_array(((_unacked[seq] as Dictionary).get("event_flags", {}) as Dictionary).get("erase", []))
			_unacked.erase(seq)
	var standing: Dictionary = host.get("event_flags", {})
	var out: Dictionary = {}
	for flag: Variant in erased:
		var pending: bool = _unacked.values().any(func(sent: Dictionary) -> bool:
			var change: Dictionary = sent.get("event_flags", {})
			return (change.get("set", {}) as Dictionary).has(flag) or (change.get("erase", []) as Array).has(flag))
		if bool(standing.get(flag, false)) and not pending:
			out[flag] = true
	return out


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


func _keep_switches(changes: Dictionary) -> void:
	var flags: Dictionary = changes.get("event_flags", {})
	for flag: Variant in (flags.get("erase", []) as Array).duplicate():
		if _inside(int(flag)) and state.is_event_flag_active(int(flag)):
			(flags["erase"] as Array).erase(flag)
			_kept_switches[int(flag)] = true
	if flags.has("erase") and (flags["erase"] as Array).is_empty() and (flags.get("set", {}) as Dictionary).is_empty():
		changes.erase("event_flags")


func _inside(flag: int) -> bool:
	var owed: Array = MAP_LOADS_OWED_BY_FLAG.get(flag, [])
	if world == null or owed.is_empty():
		return false
	return world.map_id() == owed[0] or (VICTORY_ROAD_FLOORS.has(owed[0]) and VICTORY_ROAD_FLOORS.has(world.map_id()))


func _release_switches() -> void:
	for flag: int in _kept_switches.keys():
		if _inside(flag):
			continue
		_kept_switches.erase(flag)
		if not (_host_seen.get("event_flags", {}) as Dictionary).has(flag):
			state.clear_event_flag(flag)
			_baseline = state.to_dict()
			_dirty = false


func _owe_map_loads(flags_set: Dictionary) -> void:
	if johto:
		if world != null and flags_set.keys().any(func(flag: Variant) -> bool:
				return bool(flags_set[flag]) and PokeCoopJohto.REDRAWN_BY_FLAG.get(int(flag)) == world.map_id()):
			world.reload_current_map()
		return
	var redrawn: Dictionary = MAP_LOADS_OWED_BY_FLAG.merged(LEAGUE_EXITS_REDRAWN)
	for flag: int in redrawn:
		var owed: Array = redrawn[flag]
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


## The world's trainer sight gate: a trainer the team is fighting or has beaten spots nobody else.
func trainer_free(row: Dictionary) -> bool:
	if not row.has("trainer_class"):
		return true
	var key: String = "trainer:%d:%d" % [int(row["trainer_class"]), maxi(int(row.get("trainer_number", 1)) - 1, 0)]
	return not engaged(client).has(key)


static func engaged(session: PokeCoopClient) -> Dictionary:
	var out: Dictionary = {}
	for running: Dictionary in session.state.get("battles", []):
		out[String(running.get("encounter", ""))] = true
	for done: Variant in (session.state.get("campaign", {}) as Dictionary).get("defeated", []):
		out[String(done)] = true
	return out


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
	after_the_credits(world, data.gen1_fly_warp(PokeCoopPolicy.START_MAP.y) if data.generation == RomRegistry.GEN1 else {})
	out_of_a_link_room(world, data.gen1_fly_warp(world.gen1_last_blackout_map) if data.generation == RomRegistry.GEN1 else {})
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
	view = view.get("rest", view)
	var places: Dictionary = session.me().get("places", {})
	var out := Gen2WorldSnapshot.new()
	out.map_id = view.get("map", PokeCoopPolicy.START_MAP)
	out.player_cell = view.get("cell", Vector2i.ZERO)
	out.player_facing = int(view.get("facing", Gen2WorldSprite.FACING_DOWN))
	out.world_state = Gen2WorldState.from_dict(_host_world(session))
	out.gen1_last_map = int(view.get("last_map", places.get("gen1_last_map", out.gen1_last_map)))
	out.gen1_last_blackout_map = int(places.get("gen1_last_blackout_map", out.gen1_last_blackout_map))
	on_host_clock(out, session)
	return out


## `MainMenu`'s CONTINUE where the credits left a player, in the Hall of Fame: a fly warp to Pallet Town's [param landing].
static func after_the_credits(world: Gen2WorldSnapshot, landing: Dictionary) -> void:
	if world.map_id != HALL_OF_FAME or world.world_state == null or not world.world_state.hall_of_fame() or landing.is_empty():
		return
	world.map_id = PokeCoopPolicy.START_MAP
	world.player_cell = Vector2i(int(landing["x"]), int(landing["y"]))
	world.player_facing = Gen2WorldSprite.FACING_DOWN


static func out_of_a_link_room(world: Gen2WorldSnapshot, landing: Dictionary) -> void:
	if not PokeCoopTrades.LINK_ROOMS.has(world.map_id) or landing.is_empty():
		return
	world.map_id = Vector2i(0, world.gen1_last_blackout_map)
	world.player_cell = Vector2i(int(landing["x"]), int(landing["y"]))
	world.player_facing = Gen2WorldSprite.FACING_DOWN
	world.gen1_last_map = world.gen1_last_blackout_map


static func _fill(into: Gen2SaveData, me: Dictionary, stored: Array) -> void:
	into.party.clear()
	into.contest_stashed_party = []
	for key: String in ["party", "kept"]:
		for row: Dictionary in me.get(key, []):
			var mon: Gen2SaveMon = Gen2SaveMon.from_dict(row["mon"])
			if mon != null:
				(into.party if key == "party" else into.contest_stashed_party).append(mon)
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
		"kept": save.contest_stashed_party.map(func(mon: Gen2SaveMon) -> Dictionary: return mon.to_dict()),
		"boxes": _box_rows, "current_box": save.current_box,
	}


func push_party() -> void:
	var now: Dictionary = _holdings()
	if now == _holdings_sent:
		return
	var message: Dictionary = {
		"type": "party", "rows": _hinted(now["party"], _uids), "rev": _rev_seen,
		"current_box": now["current_box"], "kept": _hinted(now["kept"], _kept_uids),
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
	_kept_uids = (me.get("kept", []) as Array).map(func(row: Dictionary) -> String: return String(row["uid"]))
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


const CLOCK_DRIFT_SECONDS: float = 1.0
const CLOCK_TICK_SECONDS: float = 120.0  ## more than a frame's clock ever moves on its own; a bigger jump is a script's
var _clock_shown: Dictionary = {}
var _clock_seq: int = -1


static func on_host_clock(world: Gen2WorldSnapshot, session: PokeCoopClient) -> void:  ## a world opens at the host's time (D133)
	var told: Dictionary = session.clock()
	if told.is_empty():
		return
	world.world_day = int(told["day"])
	world.world_hour = int(told["hour"])
	world.world_minute = int(told["minute"])
	world.world_cur_day = int(told["cur_day"])
	world.world_clock_stamp = Gen2WorldClock.host_seconds()


func follow_clock(screen: Gen2WorldScreen, sets_clock: bool) -> void:  ## to the host's; a jump a script made is the hosting player's to send
	var clock: Gen2WorldClock = screen.get("_clock")
	var told: Dictionary = client.clock()
	if clock == null or clock.pinned or told.is_empty() or world == null or screen.process_mode == Node.PROCESS_MODE_DISABLED:
		return
	var shown: Dictionary = _shown(clock)
	var jumped: float = 0.0 if _clock_shown.is_empty() else PokeCoopJohto.behind(_clock_shown, shown)
	if sets_clock and not _clock_shown.is_empty() and (jumped < -CLOCK_DRIFT_SECONDS or jumped > CLOCK_TICK_SECONDS
			or not PokeCoopJohto.same_week(_clock_shown, shown)):
		_clock_seq = client.set_clock(int(shown["day"]), int(shown["hour"]), int(shown["minute"]), int(shown["cur_day"]))
	_clock_shown = shown
	if _clock_seq > int(client.state.get("last_seq", 0)):
		return
	var gap: float = PokeCoopJohto.behind(shown, told)
	if gap > CLOCK_DRIFT_SECONDS and PokeCoopJohto.same_week(shown, told):
		screen.call(&"_advance_day_cycle", gap)
	elif gap < -CLOCK_DRIFT_SECONDS or not PokeCoopJohto.same_week(shown, told):
		world.set_world_clock(int(told["day"]), int(told["hour"]), int(told["minute"]), int(told["cur_day"]))
		clock.set("_elapsed_seconds", float(told["second"]))
		for step: StringName in [&"_sync_host_clock", &"_update_time_of_day", &"_refresh_labels"]:
			screen.call(step)
	_clock_shown = _shown(clock)


static func _shown(clock: Gen2WorldClock) -> Dictionary:
	var out: Dictionary = clock.snapshot()
	out["second"] = out["elapsed_seconds"]
	return out
