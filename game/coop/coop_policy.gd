class_name PokeCoopPolicy
extends RefCounted

## Rules the original games never had to decide, kept apart from the simulation; `docs/coop/design.md` says which the owner settled.

const NEW_PLAYER_MONEY: int = 3000
## Red and Blue's three starters, and the level Oak's lab hands one out at.
const STARTERS: Array[int] = [1, 4, 7]
const STARTER_LEVEL: int = 5
## Pallet Town, and where each joining player stands in it: the two doorsteps first.
const START_MAP: Vector2i = Vector2i(0, 0)
const START_CELLS: Array[Vector2i] = [
	Vector2i(5, 6), Vector2i(13, 6), Vector2i(6, 6), Vector2i(12, 6),
]
## Where a played opening leaves the story (D58): its flags, the lab's, Pallet Town's and the house's script steps, the objects it took.
const INTRO_DONE_FLAGS: Array[int] = [0x00, 0x20, 0x21, 0x22, 0x23, 0x27]
const INTRO_DONE_WORLD: Dictionary = {
	"gen1_map_scripts": {"set": {0: 18, 1: 5, 28: 1}, "erase": []},
	"toggled_objects": {"set": {0x2A: true, 0x2B: true, 0x2C: true, 0x2E: true}, "erase": []},
}
const PLAY_OPENING: int = -1
const OPENING_SPEECH: String = "speech"
const OPENING_PLAYING: String = "playing"
## REDS_HOUSE_2F, OAKS_LAB and EVENT_GOT_STARTER at the pinned pokered.
const OPENING_BEDROOM: Vector2i = Vector2i(0, 0x26)
const OPENING_BEDROOM_CELL: Vector2i = Vector2i(3, 6)
const OPENING_LAB: Vector2i = Vector2i(0, 0x28)
const OPENING_DONE_FLAG: int = 0x22
## Red and Blue's unique items kept for good: the map, bicycle, keys, ticket, coin case, itemfinder, scope, flute, Exp. All, rods, HMs.
const SHARED_ITEMS: Array[int] = [
	5, 6, 43, 48, 63, 69, 71, 72, 73, 74, 75, 76, 77, 78, 196, 197, 198, 199, 200,
]
## EVENT_GOT_TMxx at the pinned pokered and the TM each person hands over.
const GIFT_TMS: Dictionary = {
	41: 242, 80: 227, 118: 234, 190: 211, 358: 224, 384: 241, 396: 213, 397: 248,
	398: 249, 399: 218, 424: 221, 600: 206, 664: 238, 727: 235, 832: 231, 864: 246,
	944: 229, 1152: 239, 1791: 236,
}
const GIFT_COMMIT_PREFIX: String = "gift:"
## OLD_AMBER, DOME_FOSSIL and HELIX_FOSSIL: each player revives their own (D52).
const OWN_FOSSILS: Array[int] = [0x1F, 0x29, 0x2A]
const IN_SEAFOAM_ISLANDS: int = 0x500
const OWN_WALKS: Array[int] = [Gen1Layout.SAFARI_GAME_OVER_EVENT, Gen1Layout.IN_SAFARI_ZONE_EVENT, IN_SEAFOAM_ISLANDS]
## Each player's own (D61): gifts EVENT_GOT_HITMONLEE, _HITMONCHAN, _BOUGHT_MAGIKARP, EEVEE and Dojo balls; Safari Game; EVENT_IN_PURIFIED_ZONE;
## EVENT_MANSION_SWITCH_ON and EVENT_IN_SEAFOAM_ISLANDS, which Cinnabar Island and Route 20 (resetting Seafoam's boulders) clear; the fossil lab's EVENT_GAVE_FOSSIL_TO_LAB and next two.
const OWN_GIFTS: Dictionary = {
	"event_flags": [0x356, 0x357, 0x3FF, Gen1Layout.SAFARI_GAME_OVER_EVENT, Gen1Layout.IN_SAFARI_ZONE_EVENT, 0x107, IN_SEAFOAM_ISLANDS,
		0x278, 0x2E0, 0x2E1, 0x2E2, 0x8E6, 0x8EE, 0x8F6, 0x8FF],  # EVENT_AUTOWALKED_INTO_*_ROOM, EVENT_LANCES_ROOM_LOCK_DOOR
	"toggled_objects": [0x45, 0x4A, 0x4B],
}
## The team's Elite Four run (D91): INDIGO_PLATEAU_EVENTS_START to _END, which the lobby and the Hall of Fame clear.
const ELITE_FOUR_RUN := Vector2i(0x8E0, 0x907)
const LEAGUE_MAPS: Array[Vector2i] = [
	Vector2i(0, 0xF5), Vector2i(0, 0xF6), Vector2i(0, 0xF7), Vector2i(0, 0x71), Vector2i(0, 0x78), Vector2i(0, 0x76),
]
const EVENT_BEAT_CHAMPION_RIVAL: int = 0x901
const LEAGUE_TRAINER_CLASSES: Array[int] = [33, 43, 44, 46, 47]  # BRUNO, RIVAL3, LORELEI, AGATHA, LANCE
## Red and Blue's one-off wild Pokémon, never met in the grass: SNORLAX, the three birds and MEWTWO, one encounter each.
const UNIQUE_WILD: Array[int] = [143, 144, 145, 146, 150]
## How long a dropped controller is waited for before the others are asked to stand in (D61).
const STAND_IN_MSEC: int = 30000
## How long a battle nobody is left in waits to end as fled: as long as a window redials (D61).
const ABANDON_MSEC: int = 120000
## The rival scenes the first player in drives (D72, #24), by map, with the `w<Map>CurScript` states each runs in.
const RIVAL_SCENES: Dictionary = {
	Vector2i(0, 0x21): [1, 2, 3, 4, 5, 6],  # ROUTE_22, both fights
	Vector2i(0, 0x03): [1, 2, 3],  # CERULEAN_CITY
	Vector2i(0, 0x60): [1, 2, 3],  # SS_ANNE_2F
	Vector2i(0, 0x8F): [1, 2],  # POKEMON_TOWER_2F
	Vector2i(0, 0xD4): [3, 4, 5],  # SILPH_CO_7F
}


const VERSION_PAIRS: Array = [[RomRegistry.RED, RomRegistry.BLUE], [RomRegistry.RED_DE, RomRegistry.BLUE_DE]]
## A wild met in the grass or the water is, half the time, the other version's Pokémon from the same map and slot (D104).
const WILD_TABLES: Dictionary = {"grass": Gen2WorldEncounter.METHOD_GRASS, "water": Gen2WorldEncounter.METHOD_SURF}
const WILD_SLOTS: int = 10
const OTHER_VERSION_TAG: StringName = &"other_version"
const CHALLENGE_BATTLE: String = "battle"
const CHALLENGE_TRADE: String = "trade"
const CHALLENGE_ANSWER_MSEC: int = 30000
const CHALLENGE_EXPIRE_MSEC: int = 60000


static func versus_experience(award: Gen2Battle, faced: Dictionary, foes: Array) -> Array:
	var events: Array = []
	var learners: Array = faced.keys()
	learners.sort()
	for index: int in learners:
		var met: Array = (faced[index] as Dictionary).keys()
		met.sort()
		for foe: int in met:
			var learner: Gen2BattleMon = award.party(Gen2Battle.PLAYER).at(index)
			var defeated: Gen2BattleMon = foes[foe]
			var block: Dictionary = Gen2Experience.shared_block(defeated.base_stat_exp_shape(), defeated.base_exp(), false, 1)
			award.call(&"_give_experience_to", learner, index, award.call(&"_award_to", learner, defeated, block),
				block["stats"], false, events)
	return events


## Prize money with Pay Day's: every participant is paid all of it (D61).
static func same_story(game: StringName, other: StringName) -> bool:
	return game == other or VERSION_PAIRS.any(func(pair: Array) -> bool: return pair.has(game) and pair.has(other))


static func other_version(game: StringName) -> StringName:
	for pair: Array in VERSION_PAIRS:
		if pair.has(game):
			return pair[1] if pair[0] == game else pair[0]
	return &""


## This cartridge's Generation 1 wild slots, `{"grass"|"water": {map number: [[species, level], ...]}}`.
static func wild_tables(data: GameData) -> Dictionary:
	var out: Dictionary = {}
	for table: String in WILD_TABLES:
		var maps: Dictionary = {}
		for number: int in (256 if data != null and data.generation == RomRegistry.GEN1 else 0):
			var slots: Variant = data.world_encounter(WILD_TABLES[table], 0, number).get("slots", [])
			if slots is Array and not (slots as Array).is_empty():
				maps[str(number)] = (slots as Array).map(func(slot: Dictionary) -> Array: return [int(slot["species"]), int(slot["level"])])
		out[table] = maps
	return out


static func sane_wild_tables(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var out: Dictionary = {}
	for table: String in WILD_TABLES:
		var maps: Variant = (raw as Dictionary).get(table, {})
		if not maps is Dictionary or (maps as Dictionary).size() > 256:
			return {}
		out[table] = {}
		for number: Variant in maps:
			var slots: Variant = maps[number]
			if not String(number).is_valid_int() or not slots is Array or (slots as Array).size() > WILD_SLOTS \
					or not (slots as Array).all(func(slot: Variant) -> bool: return _sane_slot(slot)):
				return {}
			out[table][str(int(String(number)))] = (slots as Array).map(func(slot: Array) -> Array: return [int(slot[0]), int(slot[1])])
	return out


static func _sane_slot(slot: Variant) -> bool:
	return slot is Array and (slot as Array).size() == 2 and Gen2WorldEncounter.valid_mon(int(slot[0]), int(slot[1]), true)


## A [method Gen2ModHost.substitute_wild] answer: on the upper half of `roll`, the other version's slot when it holds a Pokémon [param own] never has.
static func other_wild(context: Dictionary, tables: Dictionary, own: Dictionary) -> Dictionary:
	var table: String = "water" if StringName(context.get("method", &"")) == Gen2WorldEncounter.METHOD_SURF else "grass"
	var slots: Array = (tables.get(table, {}) as Dictionary).get(str(int(context.get("map_number", -1))), [])
	var slot: int = int(context.get("slot", -1))
	if int(context.get("roll", 0)) < 128 or int(context.get("map_group", -1)) != 0 or slot < 0 or slot >= slots.size():
		return {}
	var other: Array = slots[slot]
	if own.has(int(other[0])):
		return {}
	return {"species": int(other[0]), "level": int(other[1]), "tag": OTHER_VERSION_TAG}


static func wild_species(tables: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for maps: Dictionary in tables.values():
		for slots: Array in maps.values():
			for slot: Array in slots:
				out[int(slot[0])] = true
	return out


static func plays_with(game: StringName, sha1: String, campaign_game: StringName, campaign_sha1: String) -> bool:
	if game == campaign_game:
		return sha1 == campaign_sha1
	return same_story(game, campaign_game) and sha1 == RomRegistry.sha1_for(game) \
		and campaign_sha1 == RomRegistry.sha1_for(campaign_game)


static func prize_shares(total: int, participants: Array) -> Dictionary:
	var out: Dictionary = {}
	for player_id: Variant in participants if total > 0 else []:
		out[String(player_id)] = total
	return out


static func own_entries(data: GameData) -> Dictionary:
	return OWN_GIFTS if data != null and data.generation == RomRegistry.GEN1 else {}


## Takes a window's clear of the run out of [param changes], for the host to hold: answers whether there was one.
static func take_league_clear(changes: Dictionary) -> bool:
	var erased: Array = (changes.get("event_flags", {}) as Dictionary).get("erase", [])
	var run: Array = erased.filter(func(flag: Variant) -> bool: return int(flag) >= ELITE_FOUR_RUN.x and int(flag) <= ELITE_FOUR_RUN.y)
	for flag: Variant in run:
		erased.erase(flag)
	return not run.is_empty()


## The team's run stands while a connected player is in the League, or has yet to be inducted once the Champion fell.
static func league_held(campaign: PokeCoopCampaign, members: Array) -> bool:
	var champion_beaten: bool = campaign.has_flag(EVENT_BEAT_CHAMPION_RIVAL)
	for member: PokeCoopPlayer in members:
		var inducted: bool = bool((member.world.get("engine_flags", {}) as Dictionary).get(Gen2WorldState.ENGINE_HALL_OF_FAME, false))
		if member.connected and member.opening.is_empty() and (LEAGUE_MAPS.has(member.map) or (champion_beaten and not inducted)):
			return true
	return false


## The run cleared for the campaign: the next one fights the League's trainers for real again.
static func clear_league(campaign: PokeCoopCampaign) -> void:
	for flag: int in range(ELITE_FOUR_RUN.x, ELITE_FOUR_RUN.y + 1):
		campaign.flags.erase(flag)
	for encounter: String in campaign.summary()["defeated"]:
		if encounter.begins_with("trainer:") and LEAGUE_TRAINER_CLASSES.has(int(encounter.get_slice(":", 1))):
			campaign.forget_encounter(encounter)
	campaign.revision += 1


static func new_player_money() -> int:
	return NEW_PLAYER_MONEY


## A new campaign begins after Oak's intro, which its players never see.
static func start_campaign(campaign: PokeCoopCampaign) -> void:
	campaign.commit("intro:starters_given", {"flags": INTRO_DONE_FLAGS})
	settle_intro(campaign)


## A campaign begun after the intro gets the intro's world where it has none (D58).
static func settle_intro(campaign: PokeCoopCampaign) -> void:
	if not campaign.has_flag(INTRO_DONE_FLAGS[4]):
		return
	var changed: bool = not campaign.has_flag(INTRO_DONE_FLAGS[5])
	campaign.flags[INTRO_DONE_FLAGS[5]] = true
	for key: String in INTRO_DONE_WORLD:
		var table: Dictionary = (campaign.world.get(key, {}) as Dictionary).duplicate()
		var wanted: Dictionary = (INTRO_DONE_WORLD[key] as Dictionary)["set"]
		for entry: int in wanted:
			if not table.has(entry):
				table[entry] = wanted[entry]
				changed = true
		campaign.world[key] = table
	if changed:
		campaign.revision += 1


## A player new to the campaign in Pallet Town: [param starter] if it is one of the three, at Oak's level, theirs.
static func set_up_new_player(
	data: GameData, player: PokeCoopPlayer, starter: int, joined_before: int
) -> void:
	var species: int = starter if STARTERS.has(starter) else STARTERS[joined_before % STARTERS.size()]
	var mon: Gen2BattleMon = Gen2BattleMon.create(
		data, species, STARTER_LEVEL, data.moves_at_level(species, STARTER_LEVEL)
	)
	if mon != null:
		var saved: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(mon)
		saved.ot_id = player.trainer_id
		saved.original_trainer = player.name
		saved.caught_level = STARTER_LEVEL
		player.add_mon(saved)
	player.place(START_MAP, START_CELLS[joined_before % START_CELLS.size()], 0)


static func set_up_opening_player(data: GameData, player: PokeCoopPlayer) -> void:
	var snapshot: Gen2WorldSnapshot = Gen2WorldSpawn.new_game_snapshot(data)
	var fresh: Gen2WorldState = snapshot.world_state if snapshot != null \
		else Gen2WorldState.new({}, {}, {}, {0: NEW_PLAYER_MONEY})
	var halves: Dictionary = PokeCoopOwnership.route(
		PokeCoopOwnership.patch({}, fresh.to_dict()), PokeCoopOwnership.badge_flags(data), own_entries(data)
	)
	var story: Dictionary = {"event_flags": {}, "engine_flags": {}}
	PokeCoopOwnership.apply_patch(story, halves[PokeCoopOwnership.CAMPAIGN])
	player.apply_world_patch(halves[PokeCoopOwnership.PLAYER])
	player.opening = {"stage": OPENING_SPEECH, "world": story, "rival": ""}
	if snapshot != null:
		player.place(snapshot.map_id, snapshot.player_cell, snapshot.player_facing)
	else:
		player.place(OPENING_BEDROOM, OPENING_BEDROOM_CELL, Gen2WorldSpawn.GEN1_HOME_FACING)


## Joining needs a free, connected player with somebody able to fight.
static func may_join(player: PokeCoopPlayer, fit_count: int) -> StringName:
	if player == null:
		return &"unknown_player"
	if not player.is_free():
		return &"already_in_battle"
	if not player.connected:
		return &"not_connected"
	if fit_count <= 0:
		return &"no_fit_pokemon"
	return &""


## A story gift reaches every player once: the shared items [param receiver] just gained, the TMs of gift flags just set. Answers them.
static func share_gifts(
	campaign: PokeCoopCampaign, receiver: PokeCoopPlayer, others: Array,
	flags_before: Dictionary, held_before: Dictionary,
) -> Array[int]:
	var gifts: Array[int] = []
	for item: int in SHARED_ITEMS:
		if int(held_before.get(item, 0)) == 0 and receiver.item_count(item) > 0:
			gifts.append(item)
	for flag: int in GIFT_TMS:
		if not flags_before.has(flag) and campaign.has_flag(flag):
			gifts.append(int(GIFT_TMS[flag]))
	for item: int in gifts:
		if campaign.commit(GIFT_COMMIT_PREFIX + str(item), {}):
			for other: PokeCoopPlayer in others:
				if other != receiver:
					hand_over(other, item)
	return gifts


## Items gained with a story change reach everyone; a key item it took is taken from all (D52).
static func share_found_items(
	data: GameData, receiver: PokeCoopPlayer, others: Array, held_before: Dictionary, handled: Array[int],
) -> void:
	var touched: Dictionary = held_before.duplicate()
	touched.merge(receiver.items)
	for item: int in touched:
		var change: int = receiver.item_count(item) - int(held_before.get(item, 0))
		if change == 0 or handled.has(item) or SHARED_ITEMS.has(item):
			continue
		var key: bool = (int(data.item(item).get("permissions", 0)) & Gen2WorldPack.CANT_TOSS) != 0
		for other: PokeCoopPlayer in others:
			if other == receiver:
				continue
			if change > 0:
				_stow(other, item, change)
			elif key and not OWN_FOSSILS.has(item):
				other.take_item(item, mini(-change, other.item_count(item)))


## A gift a second window handed out before it heard of the first (#24): the share is all it keeps.
static func keep_once(receiver: PokeCoopPlayer, held_before: Dictionary) -> void:
	for item: Variant in receiver.items.keys():
		var extra: int = receiver.item_count(int(item)) - int(held_before.get(item, 0))
		if extra > 0:
			receiver.take_item(int(item), extra)


## Everything the campaign's players were given before [param player] joined.
static func hand_over_gifts(campaign: PokeCoopCampaign, player: PokeCoopPlayer) -> void:
	for commit_id: String in campaign.commit_ids(GIFT_COMMIT_PREFIX):
		hand_over(player, int(commit_id.trim_prefix(GIFT_COMMIT_PREFIX)))


static func hand_over(player: PokeCoopPlayer, item: int) -> void:
	var stored: Dictionary = player.world.get("pc_items", {})
	if player.item_count(item) == 0 and int(stored.get(item, 0)) == 0:
		_stow(player, item, 1)


## Into the bag, or the PC's items when the bag's twenty rows are taken.
static func _stow(player: PokeCoopPlayer, item: int, count: int) -> void:
	if player.item_count(item) > 0 or player.items.size() < Gen1Layout.BAG_ITEM_CAPACITY:
		player.give_item(item, count)
		return
	var stored: Dictionary = player.world.get("pc_items", {})
	stored[item] = mini(int(stored.get(item, 0)) + count, PokeCoopPlayer.MAX_ITEM_COUNT)
	player.world["pc_items"] = stored


## A trainer brought from a single-player save: their team, PC, bag, money, place and own world keys, and with
## [param story] that campaign's flags, badges and world too. Only a campaign's first player brings the story.
static func import_save(
	save: Gen2SaveData, player: PokeCoopPlayer, story: PokeCoopCampaign, badge_flags: Array[int], own: Dictionary = {}
) -> void:
	if save.player_id > 0:
		player.trainer_id = save.player_id & 0xFFFF
	var snapshot: Gen2WorldSnapshot = save.world
	if snapshot != null:
		var halves: Dictionary = PokeCoopOwnership.route(
			PokeCoopOwnership.patch({}, snapshot.world_state.to_dict()), badge_flags, own
		)
		if story != null:
			story.apply_world_patch(halves[PokeCoopOwnership.CAMPAIGN], badge_flags)
		player.apply_world_patch(halves[PokeCoopOwnership.PLAYER])
		if snapshot.map_id.x >= 0:
			player.place(snapshot.map_id, snapshot.player_cell, snapshot.player_facing)
		player.keep_places({"gen1_last_map": snapshot.gen1_last_map, "gen1_last_blackout_map": snapshot.gen1_last_blackout_map})
	for mon: Gen2SaveMon in save.party:
		player.add_mon(mon)
	for at: int in mini(save.boxes.size(), PokeCoopPlayer.BOXES):
		for mon: Variant in (save.boxes[at] as Gen2SaveBox).slots:
			if mon != null:
				player.store_mon_at(mon, at)
	player.current_box = clampi(save.current_box, 0, PokeCoopPlayer.BOXES - 1)
