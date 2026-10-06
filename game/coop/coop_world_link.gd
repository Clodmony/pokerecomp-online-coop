class_name PokeCoopWorldLink
extends RefCounted

## Keeps one window's world state and party in step with the host. Local changes
## go out as patches and the host's come in as patches against what was last
## seen of it, so neither side's change is overwritten by a stale copy. The
## party and PC go out while the player is free and the host's own changes come
## back whole. The world's own SAVE asks the host for a campaign checkpoint.

const PARTY_CHECK_FRAMES: int = 30

var client: PokeCoopClient = null
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
var _saved_world: Object = null
## The sequence number of the last checkpoint the world's SAVE asked for.
var save_seq: int = -1
## While the Cable Club trades on the window's party; the host's swap comes after.
var hold_holdings: bool = false


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
	out._saved_world = window_save.world
	world_state.changed.connect(out._on_state_changed)
	return out


func _on_state_changed() -> void:
	_dirty = true


## Once a frame: what this window changed goes out before what the host changed
## comes in, so a pull never lands on an unsent local change.
func advance() -> void:
	if client == null or client.me().is_empty():
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
	if save.world != _saved_world:
		_saved_world = save.world
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
		client.send({"type": "world", "patch": changes})


func _host_world() -> Dictionary:
	var shared: Dictionary = (client.state.get("campaign", {}) as Dictionary).get("world", {})
	var own: Dictionary = client.me().get("world", {})
	var out: Dictionary = shared.duplicate(true)
	out.merge(own, true)
	var engine: Dictionary = (shared.get("engine_flags", {}) as Dictionary).duplicate()
	engine.merge(own.get("engine_flags", {}) as Dictionary, true)
	out["engine_flags"] = engine
	return out


func _pull_world() -> void:
	var host: Dictionary = _host_world()
	if host == _host_seen:
		return
	var changes: Dictionary = PokeCoopOwnership.patch(_host_seen, host)
	_host_seen = host
	if not changes.is_empty():
		var merged: Dictionary = state.to_dict()
		PokeCoopOwnership.apply_patch(merged, changes)
		state.restore_from_dict(merged)
	_baseline = state.to_dict()
	_dirty = false


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
	_fill(save, me, client.box.get("rows", []))
	_holdings_sent = _holdings()
