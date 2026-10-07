extends SceneTree

## Co-op session logs (`user://coop_logs/*.jsonl`), as files or folders:
##   Godot --headless --path . -s res://tools/coop_log.gd -- merge|summary <files...> [out=<path>]
## `merge` interleaves the devices' lines by time, a line also relayed kept once; `summary` lists
## sessions, players, battles, saves and errors.

const MODES: Array[String] = ["merge", "summary"]


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2 or not MODES.has(args[0]):
		push_error("usage: merge|summary <files or folders...> [out=<path>]")
		quit(2)
		return
	var out_path: String = ""
	var logs: Array = []
	for arg: String in args.slice(1):
		if arg.begins_with("out="):
			out_path = arg.trim_prefix("out=")
			continue
		for path: String in files_in(arg):
			logs.append(read(path))
	var timeline: Array = merge(logs)
	if args[0] == "summary":
		print(summary_text(summary(timeline)))
		quit(0)
		return
	quit(_write(timeline, out_path))


static func files_in(arg: String) -> Array[String]:
	var path: String = ProjectSettings.globalize_path(arg) if arg.contains("://") else arg
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(path):
		out.append(path)
		return out
	for name: String in DirAccess.get_files_at(path):
		if name.ends_with(".jsonl"):
			out.append(path.path_join(name))
	out.sort()
	return out


## Every readable line of one file; a line cut short by a crash is skipped.
static func read(path: String) -> Array:
	var out: Array = []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("coop log: cannot read %s" % path)
		return out
	while not file.eof_reached():
		var line: String = file.get_line()
		var parsed: Variant = JSON.parse_string(line) if not line.is_empty() else null
		if parsed is Dictionary:
			out.append(parsed)
	return out


## One timeline: each device's lines in their own order, the devices interleaved by time.
static func merge(logs: Array) -> Array:
	var by_device: Dictionary = {}
	for entries: Array in logs:
		for entry: Dictionary in entries:
			var lines: Dictionary = by_device.get_or_add(str(entry.get("device", "")), {})
			var n: int = int(entry.get("n", 0))
			var held: Variant = lines.get(n)
			if held == null or ((held as Dictionary).has("relay") and not entry.has("relay")):
				lines[n] = entry
	var queues: Array = []
	for device: String in by_device:
		var numbers: Array = (by_device[device] as Dictionary).keys()
		numbers.sort()
		queues.append(numbers.map(func(n: int) -> Dictionary: return by_device[device][n]))
	var heads: Array = []
	heads.resize(queues.size())
	heads.fill(0)
	var out: Array = []
	var best: int = _next(queues, heads)
	while best >= 0:
		out.append(queues[best][heads[best]])
		heads[best] += 1
		best = _next(queues, heads)
	return out


static func _next(queues: Array, heads: Array) -> int:
	var best: int = -1
	for at: int in queues.size():
		if heads[at] < (queues[at] as Array).size() and (best < 0 or _earlier(queues[at][heads[at]], queues[best][heads[best]])):
			best = at
	return best


static func _earlier(first: Dictionary, second: Dictionary) -> bool:
	var left: float = float(first.get("ms", 0))
	var right: float = float(second.get("ms", 0))
	return left < right or (left == right and str(first.get("device", "")) < str(second.get("device", "")))


static func _write(timeline: Array, out_path: String) -> int:
	if out_path.is_empty():
		for entry: Dictionary in timeline:
			print(JSON.stringify(entry, "", false))
		return 0
	if PokeToolPath.refuses(out_path):
		return 2
	var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		printerr("coop log: cannot write %s" % out_path)
		return 1
	for entry: Dictionary in timeline:
		file.store_line(JSON.stringify(entry, "", false))
	print("coop log: %d lines to %s" % [timeline.size(), out_path])
	return 0


static func summary(timeline: Array) -> Dictionary:
	var out: Dictionary = {"sessions": [], "players": {}, "battles": {}, "saves": [], "errors": [], "refusals": {}, "ended": []}
	for entry: Dictionary in timeline:
		var kind: String = str(entry.get("kind", ""))
		var data: Dictionary = entry.get("data", {}) if entry.get("data") is Dictionary else {}
		if entry.has("player") and not str(entry.get("name", "")).is_empty() and str(entry.get("source")) != "host":
			out["players"][entry["player"]] = entry["name"]
		_summarise(out, kind, entry, data)
	return out


static func _summarise(out: Dictionary, kind: String, entry: Dictionary, data: Dictionary) -> void:
	var battle: String = "%s:%s" % [entry.get("device", ""), data.get("battle", "")]
	match kind:
		"header":
			(out["sessions"] as Array).append(data.merged({"device": entry.get("device"), "ms": entry.get("ms")}))
		"battle_start":
			out["battles"][battle] = {"battle": data.get("battle"), "encounter": (data.get("encounter", {}) as Dictionary).get("id"),
				"initiator": data.get("initiator"), "seed": data.get("seed"), "ms": entry.get("ms")}
		"battle_end":
			(out["battles"].get_or_add(battle, {"battle": data.get("battle")}) as Dictionary).merge(
				{"outcome": data.get("outcome"), "prizes": data.get("prizes"), "ended_ms": entry.get("ms")}, true)
		"save", "save_error", "save_refused":
			(out["saves"] as Array).append(data.merged({"kind": kind, "ms": entry.get("ms"), "device": entry.get("device")}))
		"rejected":
			var reason: String = str(data.get("reason", ""))
			out["refusals"][reason] = int(out["refusals"].get(reason, 0)) + 1
		"ended", "unreachable", "leaving":
			(out["ended"] as Array).append({"device": entry.get("device"), "kind": kind, "reason": data.get("reason", "")})
	if kind.ends_with("error") or kind == "engine_warning":
		(out["errors"] as Array).append({"device": entry.get("device"), "name": entry.get("name"), "kind": kind,
			"message": data.get("message", data.get("result", "")), "at": data.get("at", ""), "ms": entry.get("ms")})


static func summary_text(found: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("sessions: %d" % (found["sessions"] as Array).size())
	for row: Dictionary in found["sessions"]:
		lines.append("  %s %s %s as %s, %s v%s protocol %s, campaign %s" % [
			_when(row.get("ms")), row.get("device"), row.get("role"), row.get("player_name"), row.get("game_id"),
			row.get("version"), row.get("protocol"), row.get("campaign_id", "?"),
		])
	lines.append("players: %s" % ", ".join((found["players"] as Dictionary).keys().map(
		func(id: Variant) -> String: return "%s (%s)" % [id, found["players"][id]])))
	lines.append("battles: %d" % (found["battles"] as Dictionary).size())
	for row: Dictionary in (found["battles"] as Dictionary).values():
		lines.append("  %s %s %s by %s: %s" % [_when(row.get("ms")), row.get("battle"), row.get("encounter"),
			row.get("initiator"), row.get("outcome", "unfinished")])
	lines.append("saves: %d" % (found["saves"] as Array).size())
	for row: Dictionary in found["saves"]:
		lines.append("  %s %s %s: %s" % [_when(row.get("ms")), row.get("kind"), row.get("why"), row.get("result", row.get("reason"))])
	lines.append("refused: %s" % JSON.stringify(found["refusals"]))
	for row: Dictionary in found["ended"]:
		lines.append("ended on %s: %s %s" % [row["device"], row["kind"], row["reason"]])
	lines.append("errors: %d" % (found["errors"] as Array).size())
	for row: Dictionary in found["errors"]:
		lines.append("  %s %s %s %s %s" % [_when(row.get("ms")), row.get("name"), row.get("kind"), row.get("message"), row.get("at")])
	return "\n".join(lines)


static func _when(ms: Variant) -> String:
	return Time.get_datetime_string_from_unix_time(int(float(ms) / 1000.0), true) if ms != null else "?"
