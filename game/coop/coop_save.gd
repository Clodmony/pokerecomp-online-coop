class_name PokeCoopSave
extends RefCounted

## A co-op campaign on disk: the shared campaign and each player in their own
## section, versioned. Only written between battles, so it holds no session.

const KIND: String = "pokerecomp-coop-campaign"
const FORMAT_VERSION: int = 2
const BACKUP_SUFFIX: String = ".bak"


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
	if not stored or read(staging).is_empty():
		DirAccess.remove_absolute(staging)
		return ERR_FILE_CANT_WRITE
	if not read(path).is_empty():
		DirAccess.copy_absolute(target, target + BACKUP_SUFFIX)
	return DirAccess.rename_absolute(staging, target)


static func read(path: String) -> Dictionary:
	var target: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(target):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(target)) != OK:
		return {}
	return from_dict(json.data)
