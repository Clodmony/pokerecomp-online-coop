extends SceneTree

## Co-op session logs (`user://coop_logs/*.jsonl`), as files or folders:
##   Godot --headless --path . -s res://tools/coop_log.gd -- merge|summary|replay <files...> [out=<path>]
## `merge` interleaves the devices' lines by time, a line also relayed kept once; `summary` lists
## sessions, players, battles, saves and errors; `replay` runs the host of a log again from its start,
## seeds and messages on this device's import of the cartridge, and exits 1 if anything came out otherwise.

const MODES: Array[String] = ["merge", "summary", "replay"]
const REPLAY_SAVE: String = "user://coop_log_replay.json"


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
	if args[0] == "replay":
		quit(_replay_cli(timeline))
		return
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
	var out: Dictionary = {"sessions": {}, "players": {}, "battles": {}, "saves": [], "errors": [], "refusals": {}, "ended": []}
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
			out["sessions"][entry.get("device")] = data.merged({"device": entry.get("device"), "ms": entry.get("ms")})
		"welcome", "host_start":
			(out["sessions"].get_or_add(entry.get("device"), {}) as Dictionary)["campaign_id"] = data.get(
				"campaign", (data.get("summary", {}) as Dictionary).get("campaign_id"))
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
	lines.append("sessions: %d" % (found["sessions"] as Dictionary).size())
	for row: Dictionary in (found["sessions"] as Dictionary).values():
		lines.append("  %s %s %s as %s, %s v%s protocol %d, campaign %s" % [
			_when(row.get("ms")), row.get("device"), row.get("role"), row.get("player_name"), row.get("game_id"),
			row.get("version"), int(row.get("protocol", 0)), row.get("campaign_id", "?"),
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
	var local: int = int(float(ms) / 1000.0) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_datetime_string_from_unix_time(local, true) if ms != null else "?"


func _replay_cli(timeline: Array) -> int:
	var headers: Array = timeline.filter(func(line: Dictionary) -> bool:
		return line.get("kind") == "header" and (line.get("data", {}) as Dictionary).get("role") == "host")
	var game: String = str((headers[0]["data"] as Dictionary).get("game_id", "")) if not headers.is_empty() else ""
	var data: GameData = GameData.open(StringName(game)) if not game.is_empty() else null
	if data == null:
		printerr("coop log: no host log, or %s is not imported on this device" % game)
		return 2
	if data.sha1 != str((headers[0]["data"] as Dictionary).get("rom_sha1", "")):
		printerr("coop log: this device's %s is another revision than the host's" % game)
	var found: Dictionary = replay(timeline, data)
	print(JSON.stringify(found, "  "))
	return 0 if found.get("ok") == true and (found["mismatches"] as Array).is_empty() and found["end"] != "differs" else 1


## The host of [param timeline] run again: messages whose answer differs, and whether it ends as logged.
static func replay(timeline: Array, data: GameData) -> Dictionary:
	var starts: Array = timeline.filter(func(line: Dictionary) -> bool: return line.get("kind") == "host_start" and not line.has("relay"))
	var host: PokeCoopHost = _replay_host(starts[0]["data"], data) if not starts.is_empty() else null
	if host == null:
		return {"ok": false, "why": "no readable host_start line"}
	var lines: Array = timeline.filter(func(line: Dictionary) -> bool:
		return line.get("device") == starts[0].get("device") and not line.has("relay"))
	lines.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return float(first["n"]) < float(second["n"]))
	var out: Dictionary = {"ok": true, "messages": 0, "mismatches": [], "end": "not logged", "differences": []}
	for line: Dictionary in lines:
		_replay_line(host, line, out)
	var ends: Array = lines.filter(func(line: Dictionary) -> bool: return line.get("kind") == "host_end")
	var summaries: Array = lines.filter(func(line: Dictionary) -> bool: return line.get("kind") == "campaign")
	if not ends.is_empty():
		var now: Variant = JSON.parse_string(JSON.stringify(PokeCoopLog.plain(PokeCoopSave.to_dict(host.campaign, host.players.values()))))
		out["differences"] = _differences(ends[-1]["data"]["save"], now)
		out["end"] = "match" if (out["differences"] as Array).is_empty() else "differs"
	elif not summaries.is_empty():
		var shared: Variant = JSON.parse_string(JSON.stringify(PokeCoopLog.plain(host.campaign.summary())))
		out["end"] = "campaign matches" if shared == summaries[-1]["data"] else "differs"
	for suffix: String in ["", PokeCoopSave.BACKUP_SUFFIX, PokeCoopSave.JOURNAL_SUFFIX, ".tmp"]:
		if FileAccess.file_exists(REPLAY_SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(REPLAY_SAVE + suffix))
	return out


static func _replay_host(start: Dictionary, data: GameData) -> PokeCoopHost:
	var loaded: Dictionary = PokeCoopSave.from_dict(start.get("save"))
	if loaded.is_empty():
		return null
	var host: PokeCoopHost = PokeCoopHost.create(data, loaded["campaign"], PokeCoopTransport.new())
	host.adopt_players(loaded["players"])
	host.allow_new_players = start.get("allow_new_players") == true
	host.autosave_msec = 1 << 62
	host.save_path = REPLAY_SAVE
	var offered: Variant = start.get("encounters", {})
	for encounter_id: String in offered if offered is Dictionary else {}:
		host.register_encounter(encounter_id, restored(offered[encounter_id]))
	host.seeds.seed = str(start.get("seed", "0")).to_int()
	host.seeds.state = str(start.get("rng_state", "0")).to_int()
	return host


static func _replay_line(host: PokeCoopHost, line: Dictionary, out: Dictionary) -> void:
	var data: Dictionary = line["data"] if line.get("data") is Dictionary else {}
	match str(line.get("kind")):
		"in":
			var message: Variant = data.get("message")
			if not message is Dictionary or message.get("type") == "log":
				return
			if message.get("type") == "stand_in":
				_away_long_enough(host, str(message.get("battle")))
			var answer: StringName = host._on_message(int(data.get("peer", 0)), restored(message))
			out["messages"] += 1
			var replayed: String = String(answer) if answer != &"" else "ok"
			if replayed != str(data.get("result")):
				(out["mismatches"] as Array).append({"n": line.get("n"), "type": message.get("type"), "seq": message.get("seq"),
					"player": line.get("player", ""), "logged": data.get("result"), "replayed": replayed})
		"disconnected":
			host._on_disconnected(int(data.get("peer", 0)))
		"battle_abandoned":
			var session: PokeCoopBattleSession = host.battles.get(str(data.get("battle")))
			if session != null:
				session.abandon()
				host._finish(session)
		"battle_advance":
			var forced: PokeCoopBattleSession = host.battles.get(str(data.get("battle")))
			if forced is PokeCoopVersus:
				forced.set("_forced_at", Time.get_ticks_msec() - 200)
				if forced.advance() and forced.phase() == PokeCoopBattleSession.OVER:
					host._finish(forced)
		"challenge_answer":
			var expired: Dictionary = host.challenges.get(str(data.get("id")), {})
			if data.get("answer") == "timeout" and not expired.is_empty():
				host._settle_challenge(expired, "timeout")
		"encounter":
			host.register_encounter(str(data.get("id")), restored(data.get("descriptor", {})))
		"shutdown":
			host.shutdown(str(data.get("reason")), 0)


## A stand-in was offered once the absent owner had been away long enough; here they have been.
static func _away_long_enough(host: PokeCoopHost, battle_id: String) -> void:
	var session: PokeCoopBattleSession = host.battles.get(battle_id)
	if session == null:
		return
	for player_id: String in session.participants:
		if not host.player(player_id).connected:
			session.set_absent(player_id, true, Time.get_ticks_msec() - PokeCoopPolicy.STAND_IN_MSEC)


## A message as JSON left it, with whole numbers and number keys whole again.
static func restored(value: Variant) -> Variant:
	if value is float and is_finite(value) and value == floorf(value):
		return int(value)
	if value is Array:
		return (value as Array).map(restored)
	if not value is Dictionary:
		return value
	var out: Dictionary = {}
	for key: Variant in value as Dictionary:
		out[int(key) if key is String and (key as String).is_valid_int() else key] = restored((value as Dictionary)[key])
	return out


static func _differences(logged: Dictionary, now: Dictionary) -> Array:
	var out: Array = []
	for key: String in logged.get("campaign", {}) as Dictionary:
		if logged["campaign"][key] != (now.get("campaign", {}) as Dictionary).get(key):
			out.append("campaign.%s" % key)
	var rows: Dictionary = {}
	for row: Dictionary in now.get("players", []):
		rows[row.get("player_id")] = row
	for row: Dictionary in logged.get("players", []):
		var mine: Dictionary = rows.get(row.get("player_id"), {})
		for key: String in row:
			if row[key] != mine.get(key):
				out.append("players.%s.%s" % [row.get("player_id"), key])
	return out
