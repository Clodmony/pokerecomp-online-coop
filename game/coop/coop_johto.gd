class_name PokeCoopJohto  ## Gold and Silver's own co-op rules (D130): the core asks here; Red and Blue's stay in PokeCoopPolicy.
extends RefCounted

const STARTERS: Array[int] = [152, 155, 158]  ## CHIKORITA, CYNDAQUIL, TOTODILE
const START_MAP: Vector2i = Vector2i(24, 4)  ## NEW_BARK_TOWN
const TOWN: String = "New Bark Town"
const START_CELLS: Array[Vector2i] = [Vector2i(13, 6), Vector2i(12, 6), Vector2i(14, 6), Vector2i(11, 6)]  ## the house's doorstep first
const ELMS_LAB: Vector2i = Vector2i(24, 5)
const CHERRYGROVE_CITY: Vector2i = Vector2i(26, 3)
const RIVAL1_CLASS: int = 9  ## pokegold's `trainer_constants.asm`; the flags and ids below are its event, engine, item and phone constants
const EVENT_GAVE_MYSTERY_EGG_TO_ELM: int = 31  ## with Elm's lab left, the end of a player's own opening (D131)
const STARTER_FLAGS: Dictionary = {  ## EVENT_GOT_<it>_FROM_ELM, EVENT_<it>_POKEBALL_IN_ELMS_LAB, the ball MrPokemonsHouse_OakScript has the rival take
	155: [27, 1600, 1601], 158: [28, 1601, 1602], 152: [29, 1602, 1600],
}
const OPENING_FLAGS: Array[int] = [  ## the story a played opening leaves (D131)
	26, 30, 31, 1725, 1726, 1735, 1737, 1794, 1812,  ## EVENT_GOT_A_POKEMON_FROM_ELM, _MYSTERY_EGG_ twice, the two rivals, MOM_1, Oak, the cop, ROUTE_30_BATTLE
]
const OPENING_CLEARED: Array[int] = [1736, 1813]  ## EVENT_PLAYERS_HOUSE_MOM_2, EVENT_ROUTE_30_YOUNGSTER_JOEY
const OPENING_SCENES: Dictionary = {"24:6": 1, "24:4": 1, "24:5": 2, "26:10": 1, "24:3": 1}  ## the house, town, lab, Mr. Pokémon; ROUTE_29's tutorial to come
const OPENING_ENGINE: Array[int] = [2, 4, 11]  ## ENGINE_PHONE_CARD, ENGINE_POKEGEAR, ENGINE_POKEDEX
const OPENING_PHONE: Array[int] = [1, 4]  ## PHONE_MOM, PHONE_ELM
const OPENING_ITEMS: Dictionary = {5: 5, 18: 1}  ## the aide's five POKE_BALLs and POTION
const INTRO_COMMIT: String = "intro:johto"
const OWN_GIFTS: Dictionary = {  ## each player's own (D61, D131, D132), and the engine flags the team shares beside the badges
	"event_flags": [
		27, 28, 29, 1600, 1601, 1602, 1790, 1791, 118, 64,  ## the starter, the stolen ball, the Guide Gent's tour, Mom's bank
		44, 45, 84, 85, 86, 119, 1792, 1793,  ## the TOGEPI egg: its aide, hatching, Elm's call and Everstone
		69, 70, 79, 80, 81, 97,  ## SHUCKLE (EVENT_GOT_SHUCKIE, _MANIA_TOOK_), EEVEE, SPEAROW's mail (_GOT_KENYA, _GAVE_KENYA), TYROGUE
		1765, 1766, 1767, 1768,  ## DAY_CARE_FLAGS: the day care's man and pen (D135)
		0, 1, 2, 3, 4, 5, 6, 7, 0x309, 0x30B, 0x30D, 0x30F, 0x311, 0x75F,  ## a map load's, the League's shut doors, LANCE's room
	],
	"map_scenes": [  ## the opening's (New Bark Town, the house, Elm's lab, Route 29, Mr. Pokémon), the link rooms, the Fast Ship and
		"24:4", "24:6", "24:5", "24:3", "26:10", "20:1", "20:2", "20:3", "20:4", "15:1", "15:2", "15:3", "15:7",  ## its ports,
		"11:7", "25:9", "10:15", "10:17", "16:2", "16:3", "16:4", "16:5", "16:6", "16:7", "16:8",  ## the Magnet Train, contest, League,
		"21:24", "21:26", "23:7", "3:22", "3:28", "9:4",  ## bike gates, Trainer House, Unown dex, Route 43's toll each walk
	],
	PokeCoopOwnership.TEAM_ENGINE_FLAGS: [14, 18, 22, 42, 43, 44, 45],  ## ROCKET_SIGNAL_ON_CH20, ROCKETS_IN_*, UNLOCKED_UNOWNS_*
}
const OWN_WALKS: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]  ## EVENT_TEMPORARY_UNTIL_MAP_RELOAD_*, which an older save may hold
const SHARED_ITEMS: Array[int] = [  ## kept for good, so everyone gets one: BICYCLE, COIN_CASE, ITEMFINDER, rods, keys, tickets, SQUIRTBOTTLE, HMs
	7, 54, 55, 58, 59, 61, 68, 127, 133, 134, 175, 243, 244, 245, 246, 247, 248, 249,
]
const GIFT_TMS: Dictionary = {  ## EVENT_GOT_TMxx (and _SUNNY_DAY_FROM_RADIO_TOWER) and the TM that person hands over
	8: 223, 9: 241, 10: 191, 11: 237, 12: 222, 13: 214, 14: 207, 15: 215, 62: 204, 71: 202, 75: 199, 78: 196, 83: 242,
	88: 201, 89: 228, 95: 192, 116: 239, 117: 229, 122: 203, 218: 193, 220: 210, 221: 197, 223: 198, 224: 234, 227: 221,
}
const OWN_FOSSILS: Array[int] = []  ## Johto revives none
const TIME_SLOTS: int = 7  ## a grass table's slots per time of day; the wild tables flatten morning, day and night
const DAY_CARE_FLAGS: Array[int] = [1765, 1766, 1767, 1768]  ## EVENT_DAY_CARE_MAN_IN_DAY_CARE, _ON_ROUTE_34, EVENT_DAY_CARE_MON_1, _2 (D135)
const STORY_SCENES: Dictionary = {  ## The contested scenes the first player in drives (D72), with the scenes whose events run them.
	Vector2i(8, 7): [1],  # AZALEA_TOWN, the rival after Slowpoke Well
	Vector2i(3, 3): [0],  # SPROUT_TOWER_3F
	Vector2i(3, 13): [0],  # BURNED_TOWER_1F
	Vector2i(1, 14): [0],  # OLIVINE_CITY
	Vector2i(3, 40): [1],  # MAHOGANY_MART_1F, LANCE after the Lake of Rage
	Vector2i(3, 42): [0, 1, 2],  # TEAM_ROCKET_BASE_B2F
	Vector2i(3, 43): [0, 1, 2],  # TEAM_ROCKET_BASE_B3F
	Vector2i(3, 21): [0, 1],  # RADIO_TOWER_5F
	Vector2i(3, 46): [0],  # GOLDENROD_UNDERGROUND_SWITCH_ROOM_ENTRANCES
	Vector2i(3, 82): [0],  # VICTORY_ROAD
	Vector2i(3, 76): [0],  # MOUNT_MOON
}
const STORY_OBJECTS: Dictionary = {  ## The contested scenes a talk starts, by the hide flag of whom the player talks to.
	Vector2i(3, 32): [0x6FC, 0x740],  # SLOWPOKE_WELL_B1F, Team Rocket and KURT
	Vector2i(9, 6): [0x6D4],  # LAKE_OF_RAGE, LANCE
	Vector2i(3, 73): [0x6A8],  # DRAGONS_DEN_B1F, the DRAGON FANG and CLAIR
}
const ELITE_FOUR_RUN: Array[int] = [0x5B8, 0x5B9, 0x5BA, 0x5BB, 0x5BC, 0x30A, 0x30C, 0x30E, 0x310, 0x312]  ## beaten, exits open
const LEAGUE_MAPS: Array[Vector2i] = [
	Vector2i(16, 3), Vector2i(16, 4), Vector2i(16, 5), Vector2i(16, 6), Vector2i(16, 7), Vector2i(16, 8),
]
const EVENT_BEAT_CHAMPION: int = 0x5BC
const LEAGUE_TRAINER_CLASSES: Array[int] = [11, 13, 14, 15, 16]  ## WILL, BRUNO, KAREN, KOGA, CHAMPION
const REDRAWN_BY_FLAG: Dictionary = {  ## The team's win and the map whose tiles callback it redraws in a window standing there.
	0x30A: Vector2i(16, 3), 0x30C: Vector2i(16, 4), 0x30E: Vector2i(16, 5), 0x310: Vector2i(16, 6), 0x312: Vector2i(16, 7),
	0x2A0: Vector2i(3, 23), 0x2A1: Vector2i(3, 24), 0x2A2: Vector2i(3, 25), 0x2A3: Vector2i(3, 26),  ## EVENT_SOLVED_*_PUZZLE
}



static func plays(data: GameData) -> bool:
	return data != null and data.generation == RomRegistry.GEN2


static func is_game(game_id: StringName) -> bool:
	return RomRegistry.generation_for(game_id) == RomRegistry.GEN2


const DAY_SECONDS: int = 86400
const CLOCK_CYCLE: float = DAY_SECONDS * Gen2WorldClock.CUR_DAY_WRAP  ## `wCurDay`'s twenty weeks, a whole number of them
static var first_reading: Dictionary = {}  ## where a new campaign's clock starts in place of the host's own time: a tool's `clock=HH:MM[:D]`


static func wind(clock: Dictionary, now: float) -> Dictionary:  ## the campaign's one clock (D128, D133), held where it was if the host's clock went back
	if clock.is_empty():
		return set_to(first_reading if not first_reading.is_empty() else wall_reading(), now)
	return set_to(clock, minf(float(clock.get("stamp", now)), now))


static func wall_reading() -> Dictionary:
	var local: Dictionary = Time.get_datetime_dict_from_system()
	return {"day": int(local["weekday"]), "hour": int(local["hour"]), "minute": int(local["minute"]), "second": int(local["second"])}


static func set_to(reading_now: Dictionary, now: float) -> Dictionary:  ## whole seconds, so a saved clock reads back the same
	var out: Dictionary = moved(reading_now, 0.0)
	out["second"] = int(out["second"])
	out["stamp"] = floorf(now)
	return out


static func reading(clock: Dictionary, now: float) -> Dictionary:
	return moved(clock, now - float(clock.get("stamp", now)))


static func moved(from: Dictionary, seconds: float) -> Dictionary:  ## the reading [param seconds] later; never earlier
	var day: int = int(from.get("day", 0))
	var total: float = fposmod(_seconds(from) + maxf(seconds, 0.0), CLOCK_CYCLE)
	var days: int = int(total / DAY_SECONDS)
	var within: float = total - days * DAY_SECONDS
	return {
		"day": posmod(day - int(from.get("cur_day", day)) + days, Gen2WorldClock.DAYS_PER_WEEK), "hour": int(within / 3600.0),
		"minute": int(within / 60.0) % Gen2WorldClock.MINUTES_PER_HOUR, "cur_day": days, "second": fmod(within, 60.0),
	}


static func behind(shown: Dictionary, told: Dictionary) -> float:  ## how far [param told] is ahead of [param shown], the short way round
	var gap: float = fposmod(_seconds(told) - _seconds(shown), CLOCK_CYCLE)
	return gap - CLOCK_CYCLE if gap > CLOCK_CYCLE / 2.0 else gap


static func same_week(first: Dictionary, second: Dictionary) -> bool:  ## whether both name the same weekday for the same `wCurDay`
	return posmod(int(first.get("day", 0)) - int(first.get("cur_day", 0)), Gen2WorldClock.DAYS_PER_WEEK) \
		== posmod(int(second.get("day", 0)) - int(second.get("cur_day", 0)), Gen2WorldClock.DAYS_PER_WEEK)


static func _seconds(from: Dictionary) -> float:
	var day: int = int(from.get("day", 0))
	return posmod(int(from.get("cur_day", day)), Gen2WorldClock.CUR_DAY_WRAP) * DAY_SECONDS + int(from.get("hour", 0)) * 3600 \
		+ int(from.get("minute", 0)) * 60 + clampf(float(from.get("second", 0.0)), 0.0, 59.999)


static func sane_clock(raw: Variant) -> Dictionary:  ## a saved clock in its own types, or none
	if not raw is Dictionary or not (raw as Dictionary).has("stamp") or not ["day", "hour", "minute"].all(
			func(key: String) -> bool: return (raw as Dictionary).get(key) is int or (raw as Dictionary).get(key) is float):
		return {}
	return set_to(raw, float(raw["stamp"]))


static func opening_over(story: Dictionary, map: Vector2i) -> bool:
	return map != ELMS_LAB and (story.get("event_flags", {}) as Dictionary).has(EVENT_GAVE_MYSTERY_EGG_TO_ELM)


static func spared(trainer_class: int, map: Vector2i) -> bool:
	return trainer_class == RIVAL1_CLASS and map == CHERRYGROVE_CITY


static func opening_world(data: GameData, starter: int) -> Dictionary:  ## halves of the world after the opening, `InitializeEventsScript`'s facts too
	var flags: Dictionary = {}
	var story: Gen2WorldStory = data.catalog().story() if data != null and data.catalog() != null else null
	var initial: Array = story.initial if story != null else []
	for fact: String in initial.filter(func(fact: String) -> bool: return fact.begins_with("e:")):
		flags[fact.substr(2).to_int()] = true
	for flag: int in OPENING_FLAGS + (STARTER_FLAGS.get(starter, []) as Array):
		flags[flag] = true
	for flag: int in OPENING_CLEARED:
		flags.erase(flag)
	var phone: Dictionary = {}
	for contact: int in OPENING_PHONE:
		phone[contact] = true
	var state := Gen2WorldState.new(flags, OPENING_SCENES, OPENING_ITEMS, {0: PokeCoopPolicy.NEW_PLAYER_MONEY}, 0, phone)
	for fact: String in initial.filter(func(fact: String) -> bool: return fact.begins_with("f:")):
		state.set_engine_flag(fact.substr(2).to_int())
	for flag: int in OPENING_ENGINE:
		state.set_engine_flag(flag)
	if starter > 0:
		state.set_species_seen(starter)
		state.set_species_caught(starter)
	Gen2WorldSpawn.apply_initial_decorations(state)
	return PokeCoopOwnership.route(PokeCoopOwnership.patch({}, state.to_dict()), PokeCoopOwnership.badge_flags(data), OWN_GIFTS)


static func start_campaign(campaign: PokeCoopCampaign, data: GameData) -> void:  ## where a played opening ends, once
	if not is_game(campaign.game_id) or not campaign.commit(INTRO_COMMIT, {}):
		return
	var story: Dictionary = opening_world(data, 0)[PokeCoopOwnership.CAMPAIGN]
	campaign.apply_world_patch({"event_flags": story.get("event_flags", {}), "map_scenes": story.get("map_scenes", {})},
		PokeCoopOwnership.badge_flags(data))


static func set_up_new_player(data: GameData, player: PokeCoopPlayer, starter: int) -> void:  ## what the opening hands a player
	player.apply_world_patch(opening_world(data, starter)[PokeCoopOwnership.PLAYER])


static func wild_place(context: Dictionary, grass: bool) -> Vector2i:  ## `group * 256 + number`, and the slot by time of day
	var slot: int = int(context.get("slot", -1))
	var time: int = clampi(int(context.get("time_of_day", 0)), 0, 2) if grass else 0
	return Vector2i(int(context.get("map_group", -1)) * 256 + int(context.get("map_number", -1)), time * TIME_SLOTS + slot if slot >= 0 else -1)


static func wild_tables(data: GameData) -> Dictionary:
	var out: Dictionary = {}
	for table: String in PokeCoopPolicy.WILD_TABLES:
		var maps: Dictionary = {}
		for region: String in ["johto", "kanto"]:
			for row: Dictionary in data.world_encounter_region_rows(PokeCoopPolicy.WILD_TABLES[table], region):
				var pair: PackedStringArray = String(row.get("map", "")).split(":")
				var slots: Array = []
				for entry: Variant in row.get("slots", []):
					slots += entry if entry is Array else [entry]
				if pair.size() == 2 and not slots.is_empty():
					maps[str(pair[0].to_int() * 256 + pair[1].to_int())] = slots.map(
						func(slot: Dictionary) -> Array: return [int(slot["species"]), int(slot["level"])])
		out[table] = maps
	return out


static func scene_playing(world: Gen2WorldAPI) -> bool:  ## a contested scene its coordinate events, its entry or a talk started
	var runner: Object = world.get("_active_script") if world != null else null
	return runner != null and scene_request(runner.get("_request"))


static func scene_request(request: Variant) -> bool:
	var row: Dictionary = request if request is Dictionary else {}
	var map := Vector2i(int(row.get("map_group", -1)), int(row.get("map_number", -1)))
	var event: Dictionary = row.get("event", {})
	match StringName(row.get("kind", &"")):
		&"scene":
			return (STORY_SCENES.get(map, []) as Array).has(int(row.get("scene", -1)))
		&"coord_events":
			return (STORY_SCENES.get(map, []) as Array).has(int(event.get("scene", -1)))
		&"objects":
			return (STORY_OBJECTS.get(map, []) as Array).has(int(event.get("event_flag", -1)))
	return false


static func prize_shares(battle: Gen2Battle, participants: Array) -> Dictionary:  ## D61, D134: one Amulet Coin doubles every share
	var out: Dictionary = {}
	var amulet: bool = battle.amulet_coin
	for player_id: Variant in participants:
		var paid: int = int(Gen2Battle.prize_money_split(battle.battle_reward, amulet, 0, 0, Gen2WorldInventory.MAX_MONEY)["wallet"]) \
			if battle.battle_reward > 0 else 0
		paid += Gen2Battle.double_reward(battle.pay_day_money) if amulet else battle.pay_day_money
		if paid > 0:
			out[String(player_id)] = paid
	return out


static func mystery_gift(data: GameData, pair: Array, day: int, random: RandomNumberGenerator) -> void:  ## two Game Boy Colors face to face (D128, D137)
	var blocks: Array = []
	for member: PokeCoopPlayer in pair:
		Gen2MysteryGift.begin_session(member.mystery_gift, day)
		var trainer := Gen2SaveData.new()
		trainer.player_id = member.trainer_id
		trainer.player_name = member.name
		blocks.append(Gen2MysteryGift.stage_player_data(trainer, member.mystery_gift, 0, random))
	var tables: Dictionary = {"items": data.mystery_gift_table(false), "decos": data.mystery_gift_table(true)}
	for side: int in 2:
		var window := Gen2MysteryGiftTransport.new()
		window.peer = blocks[1 - side]
		var member: PokeCoopPlayer = pair[side]
		var told: Dictionary = Gen2MysteryGift.exchange(member.mystery_gift, window, blocks[side], tables, data)
		Gen2MysteryGift.restore(member.mystery_gift)  ## the box a Continue would open the world on
		member.gift_round = {"serial": int(member.gift_round.get("serial", 0)) + 1, "outcome": String(told["outcome"]),
			"gift": String(told["name"]), "partner": (pair[1 - side] as PokeCoopPlayer).name}


static func gift_ready(member: PokeCoopPlayer) -> bool:  ## `MainMenu_GetWhichMenu`: Carrie has explained the machine
	return member != null and Gen2MysteryGift.menu_row_unlocked(member.mystery_gift)


static func note_mystery_gift(member: PokeCoopPlayer, message: Dictionary) -> StringName:  ## what a window may change: Carrie's unlock, a gift taken
	var section: Dictionary = member.mystery_gift
	if PokeCoopTransport.number(message.get("unlocked"), -1) == 0 and not gift_ready(member):
		section["daily_partners"] = 0
	elif PokeCoopTransport.number(message.get("taken")) <= 0 or PokeCoopTransport.number(message.get("taken")) != int(section["backup_item"]):
		return &"invalid_mystery_gift"
	section["backup_item"] = 0
	Gen2MysteryGift.restore(section)
	return &""
