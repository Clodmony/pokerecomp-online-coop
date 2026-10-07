class_name PokeCoopWorldLink
extends RefCounted

## Opens a window's world as a Continue does and keeps its state, party and PC in step with the host: world
## patches both ways, holdings out while the player is free and back whole, and its SAVE asks for a checkpoint.

const PARTY_CHECK_FRAMES: int = 30
const VERMILION_GYM := Vector2i(0, 92)
const MAP_LOADS_OWED_BY_FLAG: Dictionary = {Gen1Layout.LOCK_2ND_EVENT: [VERMILION_GYM, Gen1Layout.MAP_LOADED_2_BIT]}

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
## The world's SAVE puts in a fresh snapshot; a battle handed over puts back a copy, frames and all.
var _saved_world: Object = null
var _saved_frame: int = 0
## The sequence number of the last checkpoint the world's SAVE asked for.
var save_seq: int = -1
## While the Cable Club trades on the window's party; the host's swap comes after.
var hold_holdings: bool = false
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
	if not _host_seen.is_empty():
		_push_world()
	_pull_world()
	_frames += 1
	if hold_holdings:
		return
	if _frames % PARTY_CHECK_FRAMES == 0 and _is_free():
		_push_party()
	_pull_party()
	if _world_saved():
		_push_party()
		save_seq = client.request_save()


func _push_world() -> void:
	if not _dirty:
		return
	_dirty = false
	var now: Dictionary = state.to_dict()
	var changes: Dictionary = PokeCoopOwnership.patch(_baseline, now)
	_baseline = now
	if not changes.is_empty():
		_unacked[client.send({"type": "world", "patch": changes})] = changes


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
	if not changes.is_empty() or not echoes.is_empty():
		client.journal.add(PokeCoopLog.WORLD, "world_pull", {"changes": changes, "echoes": echoes, "unacked": _unacked.keys()}, client.player_id)
	if not changes.is_empty():
		var merged: Dictionary = state.to_dict()
		PokeCoopOwnership.apply_patch(merged, changes)
		state.restore_from_dict(merged)
		_owe_map_loads((changes.get("event_flags", {}) as Dictionary).get("set", {}))
	_baseline = state.to_dict()
	_dirty = false


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
	return {} if blocked.is_empty() else {"ok": false, "reason": blocked.replace("_", " ")}


func _world_saved() -> bool:
	if save.world == _saved_world:
		return false
	_saved_world = save.world
	var frame: int = save.world.frame_number if save.world != null else _saved_frame
	var saved: bool = frame != _saved_frame
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
	if data.world_map(world.map_id.x, world.map_id.y) != null:
		out.world = world
	return out


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


## The host's uid for each row of the window's party, as last pulled.
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


func _push_party() -> void:
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
