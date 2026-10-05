class_name PokeCoopWorldLink
extends RefCounted

## Keeps one window's world state and party in step with the host. Local changes
## go out as patches and the host's come in as patches against what was last
## seen of it, so neither side's change is overwritten by a stale copy. The
## party goes out while the player is free and comes back after a co-op battle.
## The world's own SAVE asks the host for a campaign checkpoint.

const PARTY_CHECK_FRAMES: int = 30

var client: PokeCoopClient = null
var state: Gen2WorldState = null
var save: Gen2SaveData = null
var badge_flags: Array[int] = []
var _baseline: Dictionary = {}
var _host_seen: Dictionary = {}
var _dirty: bool = true
var _party_seen: Array = []
var _party_sent: Array = []
var _uids: Array = []
var _frames: int = 0
var _saved_world: Object = null


static func over(
	session: PokeCoopClient, world_state: Gen2WorldState, local_save: Gen2SaveData, data: GameData
) -> PokeCoopWorldLink:
	var out := PokeCoopWorldLink.new()
	out.client = session
	out.state = world_state
	out.save = local_save
	out.badge_flags = PokeCoopOwnership.badge_flags(data)
	out._party_sent = out._local_rows()
	out._saved_world = local_save.world
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
	if _frames % PARTY_CHECK_FRAMES == 0 and _is_free():
		_push_party()
	_pull_party()
	if save.world != _saved_world:
		_saved_world = save.world
		_push_party()
		client.request_save()


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


## The host's uid for each row of the window's party, as last pulled.
func uids() -> Array:
	return _uids.duplicate()


func _is_free() -> bool:
	var view: Dictionary = (client.state.get("players", {}) as Dictionary).get(client.player_id, {})
	return String(view.get("battle", "")).is_empty()


func _local_rows() -> Array:
	var out: Array = []
	for mon: Gen2SaveMon in save.party:
		out.append(mon.to_dict())
	return out


func _push_party() -> void:
	var rows: Array = _local_rows()
	if rows == _party_sent:
		return
	_party_sent = rows
	var hinted: Array = []
	for index: int in rows.size():
		hinted.append({"uid": _uids[index] if index < _uids.size() else "", "mon": rows[index]})
	client.send({"type": "party", "rows": hinted})


func _pull_party() -> void:
	var host_rows: Array = client.me().get("party", [])
	if host_rows == _party_seen:
		return
	_party_seen = host_rows.duplicate(true)
	_uids = host_rows.map(func(row: Dictionary) -> String: return String(row["uid"]))
	var mons: Array = host_rows.map(func(row: Dictionary) -> Dictionary: return row["mon"])
	if mons == _local_rows():
		_party_sent = mons
		return
	save.party.clear()
	for mon_row: Dictionary in mons:
		var mon: Gen2SaveMon = Gen2SaveMon.from_dict(mon_row)
		if mon != null:
			save.party.append(mon)
	_party_sent = _local_rows()
