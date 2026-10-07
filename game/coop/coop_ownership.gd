class_name PokeCoopOwnership
extends RefCounted

## Who owns each piece of single-player state in a co-op run: the CAMPAIGN all
## players share, one PLAYER, or this window alone (LOCAL). `test_coop_ownership`
## fails on a field missing here, so a new one is classified when it lands.
## Synced keys travel as patches: a Dictionary as `{set, erase}`, else `{value}`.

const CAMPAIGN: StringName = &"campaign"
const PLAYER: StringName = &"player"
const LOCAL: StringName = &"local"
## Owned entry by entry: the campaign keeps the badges among the engine flags, Vermilion Gym's locks among
## the Gen 1 bytes, and every event flag and object but a player's own gifts.
const BY_FLAG: StringName = &"by_flag"
const CAMPAIGN_BYTES: Array[String] = [
	Gen2WorldAPI.GEN1_FIRST_LOCK, Gen2WorldAPI.GEN1_SECOND_LOCK, Gen2WorldAPI.GEN1_SECOND_LOCK_ALT,
]
const KANTO_BADGES: int = 8

const WORLD_STATE: Dictionary = {
	"beat_red": CAMPAIGN, "starter_species": CAMPAIGN, "gs_ball_stage": CAMPAIGN,
	"gs_ball_wait": CAMPAIGN, "event_flags": BY_FLAG, "engine_flags": BY_FLAG,
	"map_scenes": CAMPAIGN, "items": PLAYER, "pc_items": PLAYER, "money": PLAYER,
	"coins": PLAYER, "phone_contacts": PLAYER, "just_battled": LOCAL,
	"repel_steps": PLAYER, "wild_encounter_cooldown": LOCAL, "step_count": PLAYER,
	"poison_step_count": PLAYER, "happiness_step_count": PLAYER,
	"wild_encounters_off": LOCAL, "trainer_sightings_off": LOCAL, "park_balls": PLAYER,
	"bug_contest_started": PLAYER, "contest_mon": PLAYER,
	"contest_second_party_species": PLAYER, "swarm_map": CAMPAIGN,
	"yanma_swarm_map": CAMPAIGN, "fishing_swarm_species": CAMPAIGN,
	"roaming_mons": CAMPAIGN, "roam_cur_map": CAMPAIGN, "roam_last_map": CAMPAIGN,
	"seen_species": PLAYER, "caught_species": PLAYER, "unown_dex": PLAYER,
	"first_unown_seen": PLAYER, "phone_receive_cycle": PLAYER,
	"phone_receive_minutes": PLAYER, "pending_special_phone_call": PLAYER,
	"script_memory": LOCAL, "used_flash": PLAYER, "bike_step": PLAYER, "map_music": LOCAL,
	"radio_knob": LOCAL, "radio_channel": LOCAL, "last_dex_mode": PLAYER,
	"maptile_decorations": PLAYER, "kurt_apricorn_quantity": PLAYER,
	"picked_fruit_trees": CAMPAIGN, "toggled_objects": BY_FLAG,
	"gen1_map_scripts": CAMPAIGN, "gen1_starters": CAMPAIGN, "safari_balls": PLAYER,
	"safari_steps": PLAYER, "card_key_door": CAMPAIGN, "gen1_bytes": BY_FLAG,
	"npc_trades": PLAYER, "registered_item": PLAYER, "day_care_man": PLAYER,
	"day_care_lady": PLAYER, "day_care_mons": PLAYER, "steps_to_egg": PLAYER,
	"day_care_egg": PLAYER, "battle_caught_celebi": CAMPAIGN, "lucky_id_number": PLAYER,
	"lucky_number_day": PLAYER, "lucky_number_days_left": PLAYER,
	"kenji_break_timer": CAMPAIGN, "best_magikarp": PLAYER, "mom_savings_flags": PLAYER,
	"mom_item_index": PLAYER, "mom_item_set": PLAYER, "mom_item_trigger_balance": PLAYER,
	"blue_card_balance": PLAYER, "buenas_password": CAMPAIGN, "variable_sprites": CAMPAIGN,
	"battle_tower": PLAYER,
}

const WORLD_SNAPSHOT: Dictionary = {
	"format_version": LOCAL, "map": PLAYER, "player_cell": PLAYER, "player_facing": PLAYER,
	"movement_mode": PLAYER, "player_sprite_number": PLAYER, "clock": CAMPAIGN,
	"dst_enabled": CAMPAIGN, "world_clock_stamp": CAMPAIGN, "random_seed": LOCAL,
	"frame_number": LOCAL, "last_spawn_map": PLAYER, "gen1_last_map": PLAYER,
	"gen1_last_blackout_map": PLAYER, "gen1_map_pal_offset": LOCAL,
	"gen1_rival_name": CAMPAIGN, "gen1_fossil": PLAYER, "gen1_pikachu": PLAYER,
	"dig_warp": PLAYER, "backup_warp": PLAYER, "spawn_after_champion": CAMPAIGN,
	"world_state": BY_FLAG,
}

const SAVE_DATA: Dictionary = {
	"format_version": LOCAL, "game_id": CAMPAIGN, "rom_sha1": CAMPAIGN, "slot": LOCAL,
	"player_name": PLAYER, "player_id": PLAYER, "gender": PLAYER, "game_time": PLAYER,
	"label": LOCAL, "party": PLAYER, "contest_stashed_party": PLAYER, "boxes": PLAYER,
	"current_box": PLAYER, "hall_of_fame": CAMPAIGN, "link_record": PLAYER,
	"mystery_gift": PLAYER, "nuzlocke": CAMPAIGN, "reset_count": LOCAL,
	"save_file_exists": LOCAL, "box_names": PLAYER, "mailbox": PLAYER, "world": BY_FLAG,
	"mods": PLAYER, "run": CAMPAIGN,
}

const GAME_RUNTIME: Dictionary = {
	"selected_game_id": LOCAL, "selected_save_slot": LOCAL, "pending_new_game_slot": LOCAL,
	"pending_new_game_label": LOCAL, "pending_new_game_challenge": LOCAL, "_save": LOCAL,
	"_save_key": LOCAL, "_loaded_mods": LOCAL, "_second_screen": LOCAL,
	"_second_screen_host": LOCAL, "coop": LOCAL,
}


## The engine flag behind each campaign badge bit: Kanto's eight on Generation 1, all sixteen on Generation 2.
static func badge_flags(data: GameData) -> Array[int]:
	var out: Array[int] = []
	if data == null or data.generation == RomRegistry.GEN1:
		for bit: int in KANTO_BADGES:
			out.append(Gen2WorldState.gen1_badge_flag(bit))
		return out
	var crystal: bool = Gen2WorldState.is_crystal_profile(data)
	for badge: int in Gen2WorldState.BADGE_ENGINE_FLAGS.size():
		out.append(Gen2WorldState.badge_flag(badge, crystal))
	return out


const TEXT_KEYED: Array[String] = ["gen1_starters", "gen1_bytes"]
static var _reference: Dictionary = {}


## [param changes] cut to what a window could have sent: each synced key in its own
## shape and type, the campaign's tables holding plain numbered or named entries.
static func well_formed(changes: Variant) -> Dictionary:
	if _reference.is_empty():
		_reference = Gen2WorldState.new().to_dict()
	var out: Dictionary = {}
	for key: Variant in changes if changes is Dictionary else {}:
		var change: Variant = (changes as Dictionary)[key]
		if not key is String or not syncs(key) or not change is Dictionary or not _reference.has(key):
			continue
		var kept: Dictionary = {}
		var expected: Variant = _reference[key]
		if (change as Dictionary).has("value") and _same_kind(change["value"], expected) \
				and (not expected is Dictionary or _plain_table(key, change["value"])):
			kept["value"] = change["value"]
		if expected is Dictionary and change.get("set") is Dictionary and _plain_table(key, change["set"]):
			kept["set"] = change["set"]
		if expected is Dictionary and change.get("erase") is Array and _plain_names(key, change["erase"]):
			kept["erase"] = change["erase"]
		if not kept.is_empty():
			out[key] = kept
	return out


static func _same_kind(value: Variant, expected: Variant) -> bool:
	var numbers: Array[int] = [TYPE_INT, TYPE_FLOAT]
	return typeof(value) == typeof(expected) or (numbers.has(typeof(value)) and numbers.has(typeof(expected)))


## Player tables only ever reach their own window; the campaign's reach all.
static func _plain_table(key: String, entries: Dictionary) -> bool:
	if StringName(WORLD_STATE.get(key, LOCAL)) == PLAYER:
		return true
	for entry: Variant in entries:
		var value: Variant = entries[entry]
		if not (entry is String if TEXT_KEYED.has(key) else entry is int) \
				or not (value is bool or value is int or value is float):
			return false
	return true


static func _plain_names(key: String, names: Array) -> bool:
	return StringName(WORLD_STATE.get(key, LOCAL)) == PLAYER or names.all(
		func(entry: Variant) -> bool: return entry is String if TEXT_KEYED.has(key) else entry is int)


static func syncs(key: String) -> bool:
	return StringName(WORLD_STATE.get(key, LOCAL)) != LOCAL


## What changed from [param before] to [param after] in the synced keys.
static func patch(before: Dictionary, after: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in after:
		if not syncs(key) or before.get(key) == after[key]:
			continue
		var was: Variant = before.get(key)
		if after[key] is Dictionary and was is Dictionary:
			out[key] = _dictionary_patch(was, after[key])
		else:
			out[key] = {"value": after[key]}
	return out


static func _dictionary_patch(was: Dictionary, now: Dictionary) -> Dictionary:
	var changed: Dictionary = {}
	for entry: Variant in now:
		if not was.has(entry) or was[entry] != now[entry]:
			changed[entry] = now[entry]
	var erased: Array = []
	for entry: Variant in was:
		if not now.has(entry):
			erased.append(entry)
	return {"set": changed, "erase": erased}


static func apply_patch(into: Dictionary, changes: Dictionary) -> void:
	for key: String in changes:
		var change: Dictionary = changes[key]
		if change.has("value"):
			into[key] = change["value"]
			continue
		var target: Dictionary = (into.get(key, {}) as Dictionary).duplicate(true)
		var set_entries: Dictionary = change.get("set", {})
		for entry: Variant in set_entries:
			target[entry] = set_entries[entry]
		for entry: Variant in change.get("erase", []) as Array:
			target.erase(entry)
		into[key] = target


## [param changes] cut into the campaign's and the player's halves; [param own] lists entries players keep.
static func route(changes: Dictionary, badges: Array[int], own: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {CAMPAIGN: {}, PLAYER: {}}
	for key: String in changes:
		var owner: StringName = StringName(WORLD_STATE.get(key, LOCAL))
		if owner == BY_FLAG:
			_split_flags(key, changes[key], badges, own.get(key, []), out)
		elif owner != LOCAL:
			(out[owner] as Dictionary)[key] = changes[key]
	return out


static func _split_flags(key: String, change: Dictionary, badges: Array[int], own: Array, out: Dictionary) -> void:
	var halves: Dictionary = {CAMPAIGN: {"set": {}, "erase": []}, PLAYER: {"set": {}, "erase": []}}
	var shared: Callable = func(flag: Variant) -> bool:
		if key == "gen1_bytes":
			return CAMPAIGN_BYTES.has(flag)
		return badges.has(int(flag)) if key == "engine_flags" else not own.has(int(flag))
	var entries: Dictionary = change.get("set", change.get("value", {}))
	for flag: Variant in entries:
		var half: Dictionary = halves[CAMPAIGN if shared.call(flag) else PLAYER]
		(half["set"] as Dictionary)[flag] = entries[flag]
	for flag: Variant in change.get("erase", []) as Array:
		var half: Dictionary = halves[CAMPAIGN if shared.call(flag) else PLAYER]
		(half["erase"] as Array).append(flag)
	for owner: StringName in [CAMPAIGN, PLAYER]:
		var half: Dictionary = halves[owner]
		if change.has("value"):
			half = {"value": half["set"]}
		if not (half.get("set", {}) as Dictionary).is_empty() \
				or not (half.get("erase", []) as Array).is_empty() or half.has("value"):
			(out[owner] as Dictionary)[key] = half


## The synced keys of a world state in their in-memory types, whatever a save
## file made of them: JSON leaves a Dictionary's integer keys as strings.
static func canonical(world: Dictionary, owner: StringName) -> Dictionary:
	var restored: Gen2WorldState = Gen2WorldState.from_dict(world)
	var full: Dictionary = restored.to_dict() if restored != null else {}
	var out: Dictionary = {}
	for key: String in world:
		var key_owner: StringName = StringName(WORLD_STATE.get(key, LOCAL))
		if full.has(key) and (key_owner == owner or key_owner == BY_FLAG):
			out[key] = full[key]
	return out
