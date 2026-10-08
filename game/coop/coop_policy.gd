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
## Each player's own (D61): gifts EVENT_GOT_HITMONLEE, _HITMONCHAN, _BOUGHT_MAGIKARP, EEVEE and Dojo balls; Safari Game;
## EVENT_IN_PURIFIED_ZONE; EVENT_MANSION_SWITCH_ON, which Cinnabar Island clears; the fossil lab's EVENT_GAVE_FOSSIL_TO_LAB and next two.
const OWN_GIFTS: Dictionary = {
	"event_flags": [0x356, 0x357, 0x3FF, Gen1Layout.SAFARI_GAME_OVER_EVENT, Gen1Layout.IN_SAFARI_ZONE_EVENT, 0x107,
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


## Prize money with Pay Day's: every participant is paid all of it (D61).
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


## A trainer brought from a single-player save: their team, PC, bag, money, place
## and own world keys, and with [param story] that campaign's flags, badges and
## world too. Only a campaign's first player brings the story.
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
