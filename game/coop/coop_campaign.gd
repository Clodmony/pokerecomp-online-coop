class_name PokeCoopCampaign
extends RefCounted

## What every player of a co-op run shares: story flags, badges and which unique encounters are taken. Progress
## only moves through [method commit], keyed by an id, so a message delivered twice cannot apply twice.

const ENCOUNTER_FREE: StringName = &"free"
const ENCOUNTER_ACTIVE: StringName = &"active"
const ENCOUNTER_DONE: StringName = &"done"

var campaign_id: String = ""
var title: String = ""
var rival_name: String = ""
var both_versions: bool = false
var game_id: StringName = &""
var rom_sha1: String = ""
var flags: Dictionary = {}
var badges: int = 0
## The shared keys of the world state other than the event flags and badges [member flags] and [member badges] hold.
var world: Dictionary = {}
var revision: int = 0
var next_battle_serial: int = 1
var next_player_serial: int = 1
var _encounters: Dictionary = {}
var _commits: Dictionary = {}


static func create(id: String, game: StringName, sha1: String) -> PokeCoopCampaign:
	var out := PokeCoopCampaign.new()
	out.campaign_id = id
	out.game_id = game
	out.rom_sha1 = sha1
	return out


func has_flag(flag: int) -> bool:
	return flags.has(flag)


func has_badge(bit: int) -> bool:
	return (badges & (1 << bit)) != 0


func is_committed(commit_id: String) -> bool:
	return _commits.has(commit_id)


## The ids of every commit made so far that begin with [param prefix].
func commit_ids(prefix: String) -> Array[String]:
	var out: Array[String] = []
	for commit_id: String in _commits:
		if commit_id.begins_with(prefix):
			out.append(commit_id)
	out.sort()
	return out


## Applies [param changes] (`flags`, `badges`, `defeated`) once per [param commit_id].
func commit(commit_id: String, changes: Dictionary) -> bool:
	if commit_id.is_empty() or _commits.has(commit_id):
		return false
	for flag: Variant in changes.get("flags", []) as Array:
		flags[int(flag)] = true
	badges |= int(changes.get("badges", 0))
	for encounter: Variant in changes.get("defeated", []) as Array:
		_encounters[String(encounter)] = {"state": ENCOUNTER_DONE, "battle": ""}
	_commits[commit_id] = true
	revision += 1
	return true


## The campaign's half of a world state: [member world], its event flags and its badges as [param badge_flags].
func world_part(badge_flags: Array[int]) -> Dictionary:
	var out: Dictionary = world.duplicate(true)
	out["event_flags"] = flags.duplicate()
	var engine: Dictionary = (world.get("engine_flags", {}) as Dictionary).duplicate()
	for bit: int in badge_flags.size():
		if has_badge(bit):
			engine[badge_flags[bit]] = true
	out["engine_flags"] = engine
	return out


func apply_world_patch(changes: Dictionary, badge_flags: Array[int]) -> bool:
	var current: Dictionary = world_part(badge_flags)
	var before: Dictionary = current.duplicate(true)
	PokeCoopOwnership.apply_patch(current, changes)
	if current == before:
		return false
	flags = {}
	for flag: Variant in current["event_flags"] as Dictionary:
		if bool((current["event_flags"] as Dictionary)[flag]):
			flags[int(flag)] = true
	badges = 0
	var engine: Dictionary = {}
	for flag: Variant in current["engine_flags"] as Dictionary:
		var bit: int = badge_flags.find(int(flag))
		if not bool((current["engine_flags"] as Dictionary)[flag]):
			continue
		if bit >= 0:
			badges |= 1 << bit
		else:
			engine[int(flag)] = true
	current.erase("event_flags")
	current.erase("engine_flags")
	if not engine.is_empty():
		current["engine_flags"] = engine
	world = current
	revision += 1
	return true


func encounter_state(encounter_id: String) -> StringName:
	return StringName((_encounters.get(encounter_id, {}) as Dictionary).get("state", ENCOUNTER_FREE))


func claim_encounter(encounter_id: String, battle_id: String) -> bool:
	if encounter_state(encounter_id) != ENCOUNTER_FREE:
		return false
	_encounters[encounter_id] = {"state": ENCOUNTER_ACTIVE, "battle": battle_id}
	revision += 1
	return true


func release_encounter(encounter_id: String, battle_id: String) -> void:
	var held: Dictionary = _encounters.get(encounter_id, {})
	if StringName(held.get("state", ENCOUNTER_FREE)) == ENCOUNTER_ACTIVE \
			and String(held.get("battle", "")) == battle_id:
		_encounters.erase(encounter_id)
		revision += 1


## A rematch (D91): [param encounter_id] is free again, and its next win commits once more.
func forget_encounter(encounter_id: String) -> void:
	_encounters.erase(encounter_id)
	_commits.erase("victory:" + encounter_id)


func take_battle_id() -> String:
	next_battle_serial += 1
	return "b%d" % (next_battle_serial - 1)


func take_player_id() -> String:
	next_player_serial += 1
	return "p%d" % (next_player_serial - 1)


func summary() -> Dictionary:
	var done: Array = []
	for encounter: String in _encounters:
		if StringName((_encounters[encounter] as Dictionary)["state"]) == ENCOUNTER_DONE:
			done.append(encounter)
	done.sort()
	return {
		"campaign_id": campaign_id, "title": title, "rival_name": rival_name, "revision": revision, "flags": _sorted_flags(),
		"badges": badges, "defeated": done,
	}


func _sorted_flags() -> Array:
	var out: Array = flags.keys()
	out.sort()
	return out


## Active claims are not written: a save is only taken with no battle running.
func to_dict() -> Dictionary:
	var done: Array = summary()["defeated"]
	var commits: Array = _commits.keys()
	commits.sort()
	return {
		"campaign_id": campaign_id, "title": title, "rival_name": rival_name, "game_id": String(game_id), "rom_sha1": rom_sha1,
		"both_versions": both_versions, "flags": _sorted_flags(), "badges": badges, "revision": revision,
		"defeated": done, "commits": commits, "world": world.duplicate(true),
		"next_battle_serial": next_battle_serial, "next_player_serial": next_player_serial,
	}


static func from_dict(raw: Variant) -> PokeCoopCampaign:
	if not raw is Dictionary:
		return null
	var source: Dictionary = raw
	var out := PokeCoopCampaign.create(
		String(source.get("campaign_id", "")), StringName(source.get("game_id", "")),
		String(source.get("rom_sha1", ""))
	)
	if out.campaign_id.is_empty():
		return null
	out.title = String(source.get("title", "")) if source.get("title", "") is String else ""
	out.rival_name = String(source.get("rival_name", "")) if source.get("rival_name", "") is String else ""
	out.both_versions = source.get("both_versions") is bool and bool(source["both_versions"])
	for flag: Variant in source.get("flags", []) as Array:
		out.flags[int(flag)] = true
	for encounter: Variant in source.get("defeated", []) as Array:
		out._encounters[String(encounter)] = {"state": ENCOUNTER_DONE, "battle": ""}
	for commit_id: Variant in source.get("commits", []) as Array:
		out._commits[String(commit_id)] = true
	out.badges = int(source.get("badges", 0))
	var raw_world: Variant = source.get("world", {})
	if raw_world is Dictionary:
		out.world = PokeCoopOwnership.canonical(raw_world, PokeCoopOwnership.CAMPAIGN)
	out.revision = int(source.get("revision", 0))
	out.next_battle_serial = maxi(int(source.get("next_battle_serial", 1)), 1)
	out.next_player_serial = maxi(int(source.get("next_player_serial", 1)), 1)
	return out
