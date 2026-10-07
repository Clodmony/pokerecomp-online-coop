extends GutTest

## The co-op session log on its own: what one line holds, the folder it keeps, the
## stream's batches and caps, and the tool that merges several devices' files.

const LogTool := preload("res://tools/coop_log.gd")
const DIR: String = "user://coop_logs_unit_test"
const SETTINGS: String = "user://coop_settings_unit_test.json"

var _settings_before: String = ""


func before_each() -> void:
	_settings_before = PokeCoopLog.settings_path
	PokeCoopLog.settings_path = SETTINGS
	_clear()


func after_each() -> void:
	PokeCoopLog.settings_path = _settings_before
	_clear()


static func _clear() -> void:
	for folder: String in [DIR, DIR + "_blocked"]:
		if DirAccess.dir_exists_absolute(folder):
			for file: String in DirAccess.get_files_at(folder):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(file)))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	for path: String in [SETTINGS, DIR + "_blocked"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _read(path: String) -> Array:
	var out: Array = []
	for line: String in FileAccess.get_file_as_string(path).split("\n", false):
		out.append(JSON.parse_string(line))
	return out


func _opened(share: bool, folder: String = DIR) -> PokeCoopLog:
	var journal: PokeCoopLog = PokeCoopLog.create(share, folder)
	journal.open("join", "RED", {"game_id": "testgame"})
	return journal


func test_every_line_is_plain_json_with_when_where_and_who() -> void:
	var journal: PokeCoopLog = _opened(false)
	var before: int = PokeCoopLog.unix_msec()
	journal.add(PokeCoopLog.CLIENT, "out", {
		"cell": Vector2i(3, 4), &"kind": &"move", "flags": {0x22: true}, "list": PackedInt32Array([1, 2]),
		"mon": Gen2SaveMon.new(), "object": RefCounted.new(),
	}, "p1")
	journal.close()

	assert_true(journal.path.get_file().match("????-??-??_??-??-??_join_RED.jsonl"), journal.path)
	var lines: Array = _read(journal.path)
	assert_eq(lines.map(func(line: Dictionary) -> String: return line["kind"]), ["header", "out", "close"])
	var header: Dictionary = lines[0]["data"]
	assert_eq([header["version"], int(header["protocol"]), header["role"], header["game_id"]],
		[ProjectSettings.get_setting("application/config/version"), PokeCoopHost.PROTOCOL, "join", "testgame"])
	var out: Dictionary = lines[1]
	assert_true(float(out["ms"]) >= before and float(out["ms"]) <= PokeCoopLog.unix_msec(), "unix time in ms")
	assert_eq([out["device"], out["name"], out["source"], out["player"]], [journal.device, "RED", "client", "p1"])
	assert_eq(String(out["device"]).length(), 6)
	assert_true(out.has("frame"))
	assert_eq([lines[0]["n"], out["n"], lines[2]["n"]], [1.0, 2.0, 3.0], "numbered in the order written")
	var data: Dictionary = out["data"]
	assert_eq([data["cell"], data["kind"], data["flags"], data["list"]], [[3.0, 4.0], "move", {"34": true}, [1.0, 2.0]])
	assert_eq(data["mon"]["species"], float(Gen2SaveMon.new().species), "an object with to_dict is its dictionary")
	assert_eq(data["object"], "<RefCounted>")


func test_only_the_latest_thirty_session_files_are_kept() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for second: int in 35:
		FileAccess.open(DIR.path_join("2020-01-01_00-00-%02d_host_OLD.jsonl" % second), FileAccess.WRITE).store_line("{}")
	FileAccess.open(DIR.path_join("notes.txt"), FileAccess.WRITE).store_line("kept")
	var journal: PokeCoopLog = _opened(false)
	journal.close()

	var kept: Array = Array(DirAccess.get_files_at(DIR)).filter(func(file: String) -> bool: return file.ends_with(".jsonl"))
	assert_eq(kept.size(), PokeCoopLog.KEEP_FILES)
	assert_false(kept.has("2020-01-01_00-00-05_host_OLD.jsonl"), "the oldest go first")
	assert_true(kept.has("2020-01-01_00-00-06_host_OLD.jsonl"))
	assert_true(kept.has(journal.path.get_file()))
	assert_true(FileAccess.file_exists(DIR.path_join("notes.txt")), "only session logs are rotated")


func test_a_folder_that_cannot_be_written_costs_the_file_and_nothing_else() -> void:
	FileAccess.open(DIR + "_blocked", FileAccess.WRITE).store_line("a file where the folder would be")
	var journal: PokeCoopLog = _opened(true, DIR + "_blocked/logs")
	journal.add(PokeCoopLog.WORLD, "say", {"text": "hello"})

	assert_eq(journal.path, "")
	assert_true(journal.is_on())
	var streamed: Array = journal.take_stream()
	assert_eq(streamed.map(func(line: Dictionary) -> String: return line["kind"]), ["header", "say"], "the stream still has them")
	assert_false(streamed[0]["data"]["written"])
	assert_engine_error_count(1, "the engine says it could not make the folder")
	journal.poll()
	var errors: Array = journal.take_stream()
	assert_eq(errors.map(func(line: Dictionary) -> String: return line["kind"]), ["engine_error"], "and that is logged too")
	assert_string_contains(String(errors[0]["data"]["at"]), "(")
	journal.close()


func test_a_batch_holds_at_most_its_cap_and_counts_what_it_dropped() -> void:
	var journal: PokeCoopLog = _opened(true)
	var filler: String = "x".repeat(1000)
	for index: int in 200:
		journal.add(PokeCoopLog.CLIENT, "out", {"index": index, "filler": filler})

	var batch: Array = journal.take_stream()
	var bytes: int = 0
	for line: Dictionary in batch.slice(0, -1):
		bytes += JSON.stringify(line, "", false).length()
	assert_lte(bytes, PokeCoopLog.STREAM_BYTES)
	var marker: Dictionary = batch[-1]
	assert_eq(marker["kind"], PokeCoopLog.DROPPED)
	assert_eq(int(marker["data"]["lines"]), 201 - (batch.size() - 1), "every line left out is counted")
	assert_eq(int(batch[-2]["data"]["index"]), batch.size() - 3, "the earliest lines go first")

	journal.add(PokeCoopLog.WORLD, "say", {"text": "after"})
	assert_eq(journal.take_stream().map(func(line: Dictionary) -> String: return line["kind"]), ["say"],
		"the marker is sent once, in the place of what it counts")
	journal.close()
	var kinds: Array = _read(journal.path).map(func(line: Dictionary) -> String: return line["kind"])
	assert_eq(kinds.count("out"), 200, "the device's own file keeps every line")
	assert_eq(kinds.count(PokeCoopLog.DROPPED), 1)


func test_a_line_too_long_to_stream_travels_without_its_data() -> void:
	var journal: PokeCoopLog = _opened(true)
	journal.add(PokeCoopLog.CLIENT, "out", {"type": "party", "rows": ["y".repeat(PokeCoopLog.STREAM_LINE_BYTES)]}, "p1")

	var sent: Dictionary = journal.take_stream()[-1]
	assert_eq([sent["kind"], sent["player"]], ["out", "p1"])
	assert_gt(int(sent["data"]["omitted_bytes"]), PokeCoopLog.STREAM_LINE_BYTES)
	journal.close()
	assert_eq(String(_read(journal.path)[1]["data"]["rows"][0]).length(), PokeCoopLog.STREAM_LINE_BYTES)


func test_relayed_lines_are_kept_marked_and_only_a_senders_own_plain_lines_are_taken() -> void:
	var journal: PokeCoopLog = _opened(true)
	var good: Dictionary = {"ms": 5, "device": "abc123", "n": 7, "kind": "out", "data": {"cell": [1, 2]}}
	var taken: Array = journal.take_relayed([
		good, "text", {}, {"device": "abc123", "kind": "no number"}, good.merged({"relay": {"via": "host"}}),
		good.merged({"device": "other1"}, true),
	], "p2", "abc123")

	assert_eq(taken, [good])
	assert_eq(journal.take_stream().map(func(line: Dictionary) -> String: return line["kind"]), ["header"],
		"a relayed line is never sent on again")
	journal.close()
	var relayed: Dictionary = _read(journal.path)[1]
	assert_eq([relayed["device"], relayed["n"], relayed["data"]], ["abc123", 7.0, {"cell": [1.0, 2.0]}])
	assert_eq(relayed["relay"]["via"], "p2")


func test_a_relayed_batch_over_the_cap_is_cut_short() -> void:
	var journal: PokeCoopLog = _opened(true)
	var lines: Array = []
	for n: int in 300:
		lines.append({"device": "abc123", "n": n, "kind": "out", "data": {"filler": "z".repeat(1000)}})

	var taken: Array = journal.take_relayed(lines, "p2", "abc123")
	assert_gt(taken.size(), 50)
	assert_lt(taken.size(), 100, "a batch is about 64 KB")
	journal.close()


func test_sharing_is_on_until_the_player_turns_it_off() -> void:
	assert_true(PokeCoopLog.sharing())
	PokeCoopLog.set_sharing(false)
	assert_false(PokeCoopLog.sharing())
	assert_eq(JSON.parse_string(FileAccess.get_file_as_string(SETTINGS)), {"share_logs": false})
	FileAccess.open(SETTINGS, FileAccess.WRITE).store_string("{\"share_logs\": \"yes\"}")
	assert_true(PokeCoopLog.sharing(), "an unreadable setting is the default")


func test_a_log_never_opened_writes_nothing() -> void:
	var journal := PokeCoopLog.new()
	journal.open("host", "RED")
	assert_eq(journal.add(PokeCoopLog.HOST, "in", {}), {})
	assert_false(DirAccess.dir_exists_absolute(DIR))


func test_merge_interleaves_devices_by_time_and_keeps_a_relayed_line_once() -> void:
	var red: Array = [
		{"ms": 100, "device": "aaaaaa", "n": 1, "kind": "a1"},
		{"ms": 300, "device": "aaaaaa", "n": 2, "kind": "a2"},
		{"ms": 200, "device": "bbbbbb", "n": 1, "kind": "b1", "relay": {"via": "host"}},
		{"ms": 500, "device": "aaaaaa", "n": 3, "kind": "a3"},
		{"ms": 50, "device": "aaaaaa", "n": 4, "kind": "a4 after a clock step back"},
	]
	var blue: Array = [
		{"ms": 300, "device": "aaaaaa", "n": 2, "kind": "a2", "relay": {"via": "host"}},
		{"ms": 200, "device": "bbbbbb", "n": 1, "kind": "b1"},
		{"ms": 400, "device": "bbbbbb", "n": 2, "kind": "b2"},
	]

	var timeline: Array = LogTool.merge([red, blue])
	assert_eq(timeline.map(func(line: Dictionary) -> String: return line["kind"]),
		["a1", "b1", "a2", "b2", "a3", "a4 after a clock step back"], "each device keeps its own order")
	assert_false(timeline.any(func(line: Dictionary) -> bool: return line.has("relay")), "a device's own copy is kept")
	assert_eq(LogTool.merge([blue]).size(), 3, "a line only relayed is still in the timeline")
