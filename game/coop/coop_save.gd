class_name PokeCoopSave
extends RefCounted

## A co-op campaign on disk: the shared campaign and each player in their own section, versioned, written between
## battles. Beside it a journal keeps the state after each story change until the next checkpoint replaces it.

const KIND: String = "pokerecomp-coop-campaign"
const FORMAT_VERSION: int = 2
const BACKUP_SUFFIX: String = ".bak"
const JOURNAL_SUFFIX: String = ".journal"


static func to_dict(campaign: PokeCoopCampaign, players: Array) -> Dictionary:
	var rows: Array = []
	for member: PokeCoopPlayer in players:
		rows.append(member.to_dict())
	rows.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return String(first["player_id"]) < String(second["player_id"])
	)
	return {
		"kind": KIND, "format_version": FORMAT_VERSION,
		"campaign": campaign.to_dict(), "players": rows,
	}


## `{campaign, players}`, or empty for anything unreadable, foreign or newer.
static func from_dict(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var source: Dictionary = raw
	var version: int = int(source.get("format_version", -1))
	if String(source.get("kind", "")) != KIND or version < 1 or version > FORMAT_VERSION:
		return {}
	var campaign: PokeCoopCampaign = PokeCoopCampaign.from_dict(source.get("campaign", {}))
	if campaign == null:
		return {}
	if version < 2:
		PokeCoopPolicy.settle_intro(campaign)
	var players: Array = []
	var seen: Dictionary = {}
	for row: Variant in source.get("players", []) as Array:
		var member: PokeCoopPlayer = PokeCoopPlayer.from_dict(row)
		if member == null or seen.has(member.player_id):
			return {}
		seen[member.player_id] = true
		players.append(member)
	return {"campaign": campaign, "players": players}


static func write(path: String, campaign: PokeCoopCampaign, players: Array) -> Error:
	var target: String = ProjectSettings.globalize_path(path)
	var staging: String = target + ".tmp"
	var file: FileAccess = FileAccess.open(staging, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored: bool = file.store_string(JSON.stringify(to_dict(campaign, players), "\t"))
	file.close()
	if not stored or from_dict(_parsed(staging)).is_empty():
		DirAccess.remove_absolute(staging)
		return ERR_FILE_CANT_WRITE
	if not from_dict(_parsed(target)).is_empty():
		DirAccess.copy_absolute(target, target + BACKUP_SUFFIX)
	var renamed: Error = DirAccess.rename_absolute(staging, target)
	if renamed == OK and FileAccess.file_exists(target + JOURNAL_SUFFIX):
		DirAccess.remove_absolute(target + JOURNAL_SUFFIX)
	return renamed


## A journal line: the whole state less each PC that [param boxes_written] (id to `box_rev`) says the checkpoint holds.
static func append(path: String, campaign: PokeCoopCampaign, players: Array, boxes_written: Dictionary = {}) -> Error:
	var line: Dictionary = to_dict(campaign, [])
	for member: PokeCoopPlayer in players:
		var row: Dictionary = member.to_dict()
		if int(boxes_written.get(member.player_id, -1)) == member.box_rev:
			row.erase("box")
		(line["players"] as Array).append(row)
	var target: String = ProjectSettings.globalize_path(path) + JOURNAL_SUFFIX
	var file: FileAccess = FileAccess.open(target, FileAccess.READ_WRITE if FileAccess.file_exists(target) else FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.seek_end()
	## Each line opens with its newline, so one a crash cut short never runs into the next.
	var stored: bool = file.store_string("\n" + JSON.stringify(line))
	file.close()
	return OK if stored else ERR_FILE_CANT_WRITE


## The checkpoint at [param path], or the newest whole journal line of the same campaign written after it.
static func read(path: String) -> Dictionary:
	var target: String = ProjectSettings.globalize_path(path)
	var saved: Variant = _parsed(target)
	var loaded: Dictionary = from_dict(saved)
	if loaded.is_empty() or not FileAccess.file_exists(target + JOURNAL_SUFFIX):
		return loaded
	var lines: PackedStringArray = FileAccess.get_file_as_string(target + JOURNAL_SUFFIX).split("\n", false)
	var kept: PokeCoopCampaign = loaded["campaign"]
	for at: int in range(lines.size() - 1, -1, -1):
		var json := JSON.new()
		var line: Dictionary = from_dict(_with_boxes(json.data, saved)) if json.parse(lines[at]) == OK else {}
		if not line.is_empty() and (line["campaign"] as PokeCoopCampaign).campaign_id == kept.campaign_id:
			return line if (line["campaign"] as PokeCoopCampaign).revision > kept.revision else loaded
	return loaded


static func _with_boxes(line: Variant, saved: Dictionary) -> Variant:
	if not line is Dictionary or not (line as Dictionary).get("players") is Array:
		return line
	var boxes: Dictionary = {}
	for row: Dictionary in saved.get("players", []) as Array:
		boxes[row.get("player_id")] = row.get("box", [])
	for row: Variant in line["players"]:
		if row is Dictionary and not (row as Dictionary).has("box"):
			row["box"] = boxes.get((row as Dictionary).get("player_id"), [])
	return line


static func _parsed(target: String) -> Variant:
	var json := JSON.new()
	if not FileAccess.file_exists(target) or json.parse(FileAccess.get_file_as_string(target)) != OK:
		return null
	return json.data
