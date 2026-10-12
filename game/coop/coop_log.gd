class_name PokeCoopLog
extends RefCounted

## One device's co-op session as JSON lines, enough to retrace it. With sharing on, a device's
## own lines also reach the other devices, which keep them marked `relay`.

const DIRECTORY: String = "user://coop_logs"
const KEEP_FILES: int = 30
const KEEP_BYTES: int = 256 << 20
const MAX_FILE_BYTES: int = 128 << 20
const FLUSH_MSEC: int = 1000
const STREAM_MSEC: int = 2000
const STREAM_BYTES: int = 64 * 1024
const STREAM_LINE_BYTES: int = 8 * 1024
const STREAM_MAX_LINES: int = 1024
const BACKLOG_BYTES: int = 256 * 1024
const FULL_STATE_MSEC: int = 30000
const ENGINE_ERRORS_PER_FLUSH: int = 20
const DROPPED: String = "stream_dropped"
const HOST: StringName = &"host"
const CLIENT: StringName = &"client"
const WORLD: StringName = &"world"
const DEVICE: StringName = &"device"

static var settings_path: String = "user://coop_settings.json"
static var logs_folder: String = DIRECTORY

var directory: String = logs_folder
var path: String = ""
var device: String = ""
var player_name: String = ""
var share: bool = false
var stream_msec: int = STREAM_MSEC
var flush_msec: int = FLUSH_MSEC
var sent_lines: int = 0
var received_lines: int = 0
var _wanted: bool = false
var _on: bool = false
var _file: FileAccess = null
var _bytes: int = 0
var _pending: Array = []
var _outbox: Array = []
var _outbox_bytes: int = 0
var _dropped: int = 0
var _serial: int = 0
var _flushed_at: int = 0
var _urgent: bool = false
var _sink: Sink = null
var _states: int = 0
var _same_states: int = 0
var _state_key: int = 0
var _full_state_at: int = -1
var _views: Dictionary = {}


static func create(shares: bool, folder: String = "") -> PokeCoopLog:
	var out := PokeCoopLog.new()
	out.share = shares
	out.directory = folder if not folder.is_empty() else logs_folder
	out._wanted = true
	return out


## A folder that cannot be written leaves the lines to the stream; the game goes on either way.
func open(role: String, name: String, fields: Dictionary = {}) -> void:
	if not _wanted or _on:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	device = "%06x" % (rng.randi() & 0xFFFFFF)
	player_name = name
	_on = true
	_flushed_at = Time.get_ticks_msec()
	_sink = Sink.new()
	OS.add_logger(_sink)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) == OK:
		_rotate()
		path = _free_path(role, name)
		_file = FileAccess.open(path, FileAccess.WRITE)
	add(DEVICE, "header", {
		"version": ProjectSettings.get_setting("application/config/version", ""), "protocol": PokeCoopHost.PROTOCOL,
		"engine": Engine.get_version_info().get("string", ""), "os": OS.get_name(), "os_version": OS.get_version(),
		"role": role, "player_name": name, "share": share, "file": path.get_file(), "written": _file != null,
	}.merged(fields))


func is_on() -> bool:
	return _on


func _rotate() -> void:
	var names: Array = Array(DirAccess.get_files_at(directory)).filter(
		func(file: String) -> bool: return file.ends_with(".jsonl"))
	names.sort()
	names.reverse()
	var kept: int = 0
	for index: int in names.size():
		var file: String = ProjectSettings.globalize_path("%s/%s" % [directory, names[index]])
		var opened: FileAccess = FileAccess.open(file, FileAccess.READ)
		if opened != null:
			kept += opened.get_length()
			opened.close()
		if index >= KEEP_FILES - 1 or kept > KEEP_BYTES:
			DirAccess.remove_absolute(file)


func _free_path(role: String, name: String) -> String:
	var stamp: String = Time.get_datetime_string_from_system(false, true).replace(" ", "_").replace(":", "-")
	var base: String = "%s/%s_%s_%s" % [directory, stamp, role, (name if not name.is_empty() else "player").validate_filename()]
	var out: String = base + ".jsonl"
	var extra: int = 1
	while FileAccess.file_exists(out):
		extra += 1
		out = "%s_%d.jsonl" % [base, extra]
	return out


## The line as it will be written, still open to a field the caller learns later.
func add(source: StringName, kind: String, data: Variant = {}, player: String = "") -> Dictionary:
	if not _on:
		return {}
	_serial += 1
	var entry: Dictionary = {
		"ms": unix_msec(), "frame": Engine.get_process_frames(), "device": device, "name": player_name,
		"n": _serial, "source": String(source),
	}
	if not player.is_empty():
		entry["player"] = player
	entry["kind"] = kind
	entry["data"] = plain(data)
	_pending.append(entry)
	_urgent = _urgent or kind.ends_with("error")
	return entry


## A digest of each `state` that changed beyond steps, whole after a welcome and every [constant FULL_STATE_MSEC].
func log_state(message: Dictionary, player: String) -> void:
	if not _on:
		return
	_states += 1
	var saved: Dictionary = message.get("saved", {})
	var key: int = [message.get("campaign"), message.get("you"), message.get("nearby"), message.get("battles"),
		message.get("encounters"), saved.get("count"), saved.get("blocked")].hash()
	if key == _state_key:
		_same_states += 1
		return
	_state_key = key
	var me: Dictionary = message.get("you", {})
	if player_name.is_empty():
		player_name = PokeCoopTransport.text(me.get("name"))
	var where: Dictionary = (message.get("players", {}) as Dictionary).get(player, {})
	var data: Dictionary = {
		"n": _states, "same": _same_states, "digest": message.hash(), "last_seq": message.get("last_seq"),
		"revision": (message.get("campaign", {}) as Dictionary).get("revision"), "map": where.get("map"),
		"cell": where.get("cell"), "holdings_rev": me.get("holdings_rev"), "box_rev": me.get("box_rev"),
		"money": me.get("money"), "battles": (message.get("battles", []) as Array).map(
			func(row: Variant) -> Variant: return row.get("battle") if row is Dictionary else null),
	}
	if _full_state_at < 0 or Time.get_ticks_msec() - _full_state_at >= FULL_STATE_MSEC:
		_full_state_at = Time.get_ticks_msec()
		data["state"] = message
	_same_states = 0
	add(CLIENT, "state", data, player)


func want_full_state() -> void:
	_full_state_at = -1
	_state_key = 0


func log_view(view: Dictionary, player: String) -> void:
	var mark: Array = [view.get("revision"), view.get("outcome"), view.get("controller")]
	if not _on or _views.get(view.get("battle")) == mark:
		return
	_views[view.get("battle")] = mark
	add(CLIENT, "battle_view", {
		"battle": view.get("battle"), "revision": view.get("revision"), "phase": view.get("phase"),
		"controller": view.get("controller"), "outcome": view.get("outcome"),
	}, player)


func poll() -> void:
	if not _on:
		return
	_take_engine_errors()
	if _urgent or Time.get_ticks_msec() - _flushed_at >= flush_msec:
		flush()


func flush() -> void:
	_flushed_at = Time.get_ticks_msec()
	_urgent = false
	for entry: Variant in _pending:
		var text: String = entry if entry is String else JSON.stringify(entry, "", false)
		if share and entry is Dictionary and String(entry["kind"]) != DROPPED:
			_queue(entry, text.length())
		_store(text)
	_pending.clear()
	if _file != null:
		_file.flush()


func _store(text: String) -> void:
	if _file == null or _bytes > MAX_FILE_BYTES:
		return
	_file.store_line(text)
	_bytes += text.length() + 1
	if _bytes > MAX_FILE_BYTES:
		_file.store_line(JSON.stringify({"ms": unix_msec(), "device": device, "kind": "file_full"}))


func _queue(entry: Dictionary, size: int) -> void:
	var sent: Dictionary = entry
	if size > STREAM_LINE_BYTES:
		sent = entry.duplicate()
		sent["data"] = {"omitted_bytes": size}
		size = JSON.stringify(sent, "", false).length()
	if _outbox_bytes + size > STREAM_BYTES or _outbox.size() >= STREAM_MAX_LINES:
		_dropped += 1
		return
	_outbox.append(sent)
	_outbox_bytes += size


## Own lines since the last call; what did not fit a batch is counted in a [constant DROPPED] line.
func take_stream() -> Array:
	flush()
	var out: Array = _outbox
	_outbox = []
	_outbox_bytes = 0
	if _dropped > 0:
		out.append(add(DEVICE, DROPPED, {"lines": _dropped}))
		_dropped = 0
	sent_lines += out.size()
	return out


## Another device's lines, kept if [param keep] marked with who passed them on: only lines of [param from_device]
## (any when empty) never relayed before, up to a batch. The ones taken come back for passing on.
func take_relayed(raw: Variant, via: String, from_device: String = "", keep: bool = true) -> Array:
	var taken: Array = []
	var bytes: int = 0
	var mark: String = JSON.stringify({"via": via, "ms": unix_msec()}, "", false)
	for line: Variant in raw if raw is Array else []:
		if not _relayable(line, from_device):
			continue
		var text: String = JSON.stringify(line, "", false)
		bytes += text.length()
		if bytes > STREAM_BYTES + STREAM_LINE_BYTES or taken.size() >= STREAM_MAX_LINES:
			break
		taken.append(line)
		if keep and _on:
			_pending.append("%s,\"relay\":%s}" % [text.left(-1), mark])
	received_lines += taken.size() if keep else 0
	return taken


static func _relayable(line: Variant, from_device: String) -> bool:
	if not line is Dictionary or (line as Dictionary).has("relay") or not (line as Dictionary).has("n"):
		return false
	var origin: String = PokeCoopTransport.text((line as Dictionary).get("device"))
	return not origin.is_empty() and (from_device.is_empty() or origin == from_device)


func close() -> void:
	if not _on:
		return
	add(DEVICE, "close", {"sent": sent_lines, "received": received_lines, "dropped": _dropped})
	_take_engine_errors()
	flush()
	_on = false
	OS.remove_logger(_sink)
	_sink = null
	if _file != null:
		_file.close()
		_file = null


func _take_engine_errors() -> void:
	for row: Dictionary in _sink.take():
		add(DEVICE, "engine_%s" % row["level"], row)


static func unix_msec() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


## [param value] as JSON keeps it: text keys, vectors as `[x, y]`, objects by `to_dict()`.
static func plain(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return value
		TYPE_FLOAT:
			return value if is_finite(value) else null
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return String(value)
		TYPE_VECTOR2I, TYPE_VECTOR2:
			return [value.x, value.y]
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key: Variant in value as Dictionary:
				out[_key(key)] = plain((value as Dictionary)[key])
			return out
		TYPE_ARRAY:
			var items: Array = []
			for item: Variant in value as Array:
				items.append(plain(item))
			return items
		TYPE_OBJECT:
			return _object(value)
	return plain(Array(value)) if typeof(value) >= TYPE_PACKED_BYTE_ARRAY else str(value)


static func _key(key: Variant) -> String:
	return String(key) if key is String or key is StringName else JSON.stringify(plain(key))


static func _object(value: Object) -> Variant:
	if not is_instance_valid(value):
		return null
	if value.has_method("to_dict"):
		return plain(value.call("to_dict"))
	var script: Script = value.get_script()
	var named: String = String(script.get_global_name()) if script != null else ""
	return "<%s>" % (named if not named.is_empty() else value.get_class())


static func sharing() -> bool:
	var stored: Variant = _settings().get("share_logs", true)
	return stored if stored is bool else true


static func set_sharing(on: bool) -> void:
	var stored: Dictionary = _settings()
	stored["share_logs"] = on
	var file: FileAccess = FileAccess.open(settings_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(stored, "\t"))


static func _settings() -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(settings_path)) \
		if FileAccess.file_exists(settings_path) else null
	return raw if raw is Dictionary else {}


## Engine errors and warnings while a session runs; the engine calls it from any thread.
class Sink extends Logger:
	var _lock: Mutex = Mutex.new()
	var _rows: Array = []
	var _missed: int = 0

	func _log_error(
		function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace],
	) -> void:
		var row: Dictionary = {
			"level": "warning" if error_type == Logger.ERROR_TYPE_WARNING else "error",
			"message": rationale if not rationale.is_empty() else code, "at": "%s (%s:%d)" % [function, file, line],
		}
		if not script_backtraces.is_empty() and not script_backtraces[0].is_empty():
			row["backtrace"] = script_backtraces[0].format(4).strip_edges()
		_lock.lock()
		if _rows.size() < PokeCoopLog.ENGINE_ERRORS_PER_FLUSH:
			_rows.append(row)
		else:
			_missed += 1
		_lock.unlock()

	func take() -> Array:
		_lock.lock()
		var out: Array = _rows
		_rows = []
		if _missed > 0:
			out.append({"level": "error", "message": "%d more not kept" % _missed, "at": ""})
			_missed = 0
		_lock.unlock()
		return out
