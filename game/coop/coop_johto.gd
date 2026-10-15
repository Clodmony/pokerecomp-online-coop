class_name PokeCoopJohto  ## Gold and Silver's own co-op rules (D130): the core asks here; Red and Blue's stay in PokeCoopPolicy.
extends RefCounted

const STARTERS: Array[int] = [152, 155, 158]  ## CHIKORITA, CYNDAQUIL, TOTODILE
const START_MAP: Vector2i = Vector2i(24, 4)  ## NEW_BARK_TOWN
const TOWN: String = "New Bark Town"
const START_CELLS: Array[Vector2i] = [Vector2i(13, 6), Vector2i(12, 6), Vector2i(14, 6), Vector2i(11, 6)]  ## the house's doorstep first
const OWN_ENTRIES: Dictionary = {  ## What each player keeps, and the engine flags the team shares beside the badges (D132).
	"event_flags": [0, 1, 2, 3, 4, 5, 6, 7, 0x309, 0x30B, 0x30D, 0x30F, 0x311, 0x75F],  ## a map load's, the League's shut doors, LANCE's room
	"map_scenes": [  ## the link rooms, the Fast Ship and its ports, the Magnet Train, the contest's gates, the League, the bike gates
		"20:1", "20:2", "20:3", "20:4", "15:1", "15:2", "15:3", "15:7", "11:7", "25:9", "10:15", "10:17",
		"16:2", "16:3", "16:4", "16:5", "16:6", "16:7", "16:8", "21:24", "21:26", "23:7", "3:22", "3:28",  ## Trainer House, Unown dex
	],
	PokeCoopOwnership.TEAM_ENGINE_FLAGS: [14, 18, 22, 42, 43, 44, 45],  ## ROCKET_SIGNAL_ON_CH20, ROCKETS_IN_*, UNLOCKED_UNOWNS_*
}
const OWN_WALKS: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]  ## EVENT_TEMPORARY_UNTIL_MAP_RELOAD_*, which an older save may hold
const SHARED_ITEMS: Array[int] = [  ## kept for good and given every player once (D52): BICYCLE, COIN CASE, ITEMFINDER, the rods,
	7, 54, 55, 58, 59, 61, 68, 127, 133, 134, 175, 243, 244, 245, 246, 247, 248, 249,  ## S.S. TICKET, keys, PASS, SQUIRTBOTTLE, HMs
]
const STORY_SCENES: Dictionary = {  ## The contested scenes the first player in drives (D72), with the scenes whose events run them.
	Vector2i(26, 3): [1],  # CHERRYGROVE_CITY, the rival
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
