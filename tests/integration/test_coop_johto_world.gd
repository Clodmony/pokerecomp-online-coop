extends GutTest

## Sharing Johto's world (#174, D132) on the synthetic Generation 2 fixture: a GOLD
## and a SILVER player in one Gold campaign, with the story moved by world patches as
## a window sends them at rest points.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const MAHOGANY_MART_SCENE: String = "3:40"  ## SCENE_MAHOGANYMART1F_LANCE_UNCOVERS_STAIRS, which LANCE at the Lake of Rage sets
const LANCE_UNCOVERS_STAIRS: int = 1
const OPENING_SCENES: Array[String] = ["24:4", "24:5", "24:6", "26:10"]  ## New Bark Town's teacher, Elm's lab, Mom, Mr. Pokémon
const INNER_CHAMBER_SCENE: String = "3:27"
const STRANGE_PRESENCE: int = 1
const EVENT_SOLVED_KABUTO_PUZZLE: int = 0x2A1
const UNLOCKED_UNOWNS_A_TO_K: int = 42
const POKECENTER_2F_SCENE: String = "20:1"
const LEAVE_TRADE_CENTER: int = 1
const TEMPORARY_FLAG: int = 3
const WILLS_ROOM: Vector2i = Vector2i(16, 3)
const INDIGO_LOBBY: Vector2i = Vector2i(16, 2)
const EVENT_BEAT_ELITE_4_WILL: int = 0x5B8
const EVENT_WILLS_ROOM_ENTRANCE_CLOSED: int = 0x309
const EVENT_WILLS_ROOM_EXIT_OPEN: int = 0x30A
const AZALEA: Vector2i = Vector2i(8, 7)
const LAKE_OF_RAGE: Vector2i = Vector2i(9, 6)
const EVENT_LAKE_OF_RAGE_LANCE: int = 0x6D4
const ROUTE_22: Vector2i = Vector2i(0, 0x21)
const POKE_BALL: int = 5
const BICYCLE: int = 7
const RED_GIFT_TM_FLAG: int = 41
const RED_GIFT_TM: int = 242
const SNORLAX: int = 143

var _directory: String = ""
var _data: GameData = null
var _host: PokeCoopHost = null
var _clients: Array = []


func before_each() -> void:
	_directory = RomCache.directory_for(&"coopjohtoworldtest", "0123456789abcdef")
	_data = Fixture.build(_directory, String(RomRegistry.GOLD), RomRegistry.GEN2)
	_data.sha1 = RomRegistry.sha1_for(RomRegistry.GOLD)
	_clients = []
	_host = PokeCoopHost.create(_data, PokeCoopCampaign.create("johto1", _data.id, _data.sha1), PokeCoopTransport.new())
	_host.allow_new_players = true
	PokeCoopPolicy.start_campaign(_host.campaign, _data)


func after_each() -> void:
	RomCache.clear(_directory)


func _join(peer: int, player_name: String, game: StringName) -> PokeCoopClient:
	var link := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, link, peer)
	var client: PokeCoopClient = PokeCoopClient.over(link)
	client.greet(player_name, game, RomRegistry.sha1_for(game))
	_clients.append(client)
	_pump()
	return client


func _pump() -> void:
	for _round: int in 4:
		for client: PokeCoopClient in _clients:
			client.poll()
		_host.poll()
	for client: PokeCoopClient in _clients:
		client.poll()


func _send_world(client: PokeCoopClient, patch: Dictionary) -> void:
	client.send({"type": "world", "patch": patch})
	_pump()


static func _setting(entries: Dictionary) -> Dictionary:
	return {"set": entries, "erase": []}


func _seen(client: PokeCoopClient, key: String) -> Dictionary:
	return PokeCoopWorldLink._host_world(client).get(key, {})


func test_a_gate_one_player_opens_is_open_in_the_other_window() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)

	_send_world(gold, {"map_scenes": _setting({MAHOGANY_MART_SCENE: LANCE_UNCOVERS_STAIRS})})

	assert_eq(_seen(silver, "map_scenes").get(MAHOGANY_MART_SCENE), LANCE_UNCOVERS_STAIRS, "LANCE waits in SILVER's mart too")
	assert_eq(Gen2WorldState.from_dict(PokeCoopWorldLink._host_world(silver)).map_scene(3, 40), LANCE_UNCOVERS_STAIRS)


func test_the_openings_scenes_are_each_players_own() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)
	var moved: Dictionary = {}
	for scene: String in OPENING_SCENES:
		moved[scene] = 7

	_send_world(gold, {"map_scenes": _setting(moved)})

	for scene: String in OPENING_SCENES:
		assert_eq(_seen(gold, "map_scenes").get(scene), 7, scene)
		assert_ne(_seen(silver, "map_scenes").get(scene), 7, "every player meets the teacher, Elm, Mom and Mr. Pokémon: " + scene)


func test_a_ruins_puzzle_one_player_solves_is_solved_for_both_and_the_unown_stay_each_players() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)

	_send_world(gold, {
		"event_flags": _setting({EVENT_SOLVED_KABUTO_PUZZLE: true}),
		"engine_flags": _setting({UNLOCKED_UNOWNS_A_TO_K: true}),
		"map_scenes": _setting({INNER_CHAMBER_SCENE: STRANGE_PRESENCE}),
		"unown_dex": {"value": [1, 2]},
	})

	var world: Gen2WorldState = Gen2WorldState.from_dict(PokeCoopWorldLink._host_world(silver))
	assert_true(world.is_event_flag_active(EVENT_SOLVED_KABUTO_PUZZLE), "the puzzle is solved in SILVER's world")
	assert_eq(world.unlocked_unowns(false), 1, "A to K appear in SILVER's Ruins too")
	assert_eq(world.map_scene(3, 27), STRANGE_PRESENCE)
	assert_eq(world.unown_dex(), [], "the Unown GOLD caught are GOLD's")
	assert_eq(Gen2WorldState.from_dict(PokeCoopWorldLink._host_world(gold)).unown_dex(), [1, 2])


func test_a_walks_own_scenes_and_flags_stay_with_its_player() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)

	_send_world(gold, {
		"map_scenes": _setting({POKECENTER_2F_SCENE: LEAVE_TRADE_CENTER}),
		"event_flags": _setting({TEMPORARY_FLAG: true}),
	})

	assert_false(_seen(silver, "map_scenes").has(POKECENTER_2F_SCENE), "GOLD's way out of the Trade Center is GOLD's")
	assert_false(_seen(silver, "event_flags").has(TEMPORARY_FLAG), "a flag a map load clears is each window's")
	assert_eq(_seen(gold, "map_scenes").get(POKECENTER_2F_SCENE), LEAVE_TRADE_CENTER)
	assert_true(bool(_seen(gold, "event_flags").get(TEMPORARY_FLAG, false)))


func test_the_elite_four_is_one_run_for_the_team() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)
	gold.step(WILLS_ROOM, Vector2i(5, 10), 0, true)
	silver.step(INDIGO_LOBBY, Vector2i(5, 10), 0, true)
	_pump()

	_send_world(gold, {"event_flags": _setting({
		EVENT_BEAT_ELITE_4_WILL: true, EVENT_WILLS_ROOM_EXIT_OPEN: true, EVENT_WILLS_ROOM_ENTRANCE_CLOSED: true,
	})})
	var shared: Dictionary = _seen(silver, "event_flags")
	assert_true(bool(shared.get(EVENT_BEAT_ELITE_4_WILL, false)), "WILL beaten by GOLD is beaten for SILVER")
	assert_true(bool(shared.get(EVENT_WILLS_ROOM_EXIT_OPEN, false)), "and his room's exit is open for SILVER")
	assert_false(shared.has(EVENT_WILLS_ROOM_ENTRANCE_CLOSED), "the door that shut behind GOLD is GOLD's")

	_send_world(silver, {"event_flags": {"set": {}, "erase": [EVENT_BEAT_ELITE_4_WILL, EVENT_WILLS_ROOM_EXIT_OPEN]}})
	assert_true(_host.campaign.has_flag(EVENT_BEAT_ELITE_4_WILL), "the lobby's clear waits while GOLD is in the League")


func test_red_and_blues_items_tms_and_one_off_wilds_stay_out_of_a_gold_campaign() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)

	var other: PokeCoopPlayer = _host.player(silver.player_id)
	var balls: int = other.item_count(POKE_BALL)
	var held: int = _host.player(gold.player_id).item_count(POKE_BALL)
	_send_world(gold, {"event_flags": _setting({RED_GIFT_TM_FLAG: true}), "items": _setting({POKE_BALL: held + 1})})

	assert_eq(other.item_count(RED_GIFT_TM), 0, "Red's gift TM flag is another event in Johto")
	assert_eq(_host.campaign.commit_ids(PokeCoopPolicy.GIFT_COMMIT_PREFIX), [], "a POKé BALL is no unique item")
	assert_eq(other.item_count(POKE_BALL), balls + 1, "an item found with the story still reaches everyone (D52)")
	assert_eq(PokeCoopPolicy.unique_wild(_data), [], "SNORLAX and the like are each player's in Johto (D128)")
	assert_false(PokeCoopPolicy.unique_wild(null).is_empty(), "Red and Blue keep theirs")
	assert_eq(PokeCoopHost._window_encounter(false, 0, 0, SNORLAX, AZALEA, _data), "")


func test_a_johto_key_item_reaches_every_player_and_a_late_joiner() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)

	_send_world(gold, {"items": _setting({BICYCLE: 1})})
	var late: PokeCoopClient = _join(3, "KRIS", RomRegistry.SILVER)

	assert_eq(_host.player(silver.player_id).item_count(BICYCLE), 1)
	assert_eq(_host.player(late.player_id).item_count(BICYCLE), 1, "the BICYCLE reaches a player who joins later")


func test_the_first_player_into_a_johto_rival_scene_drives_it_and_cherrygroves_is_each_openings() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)

	assert_eq(_host.claim_scene(_host.player(gold.player_id), AZALEA, true), &"")
	assert_eq(_host.claim_scene(_host.player(silver.player_id), AZALEA, true), &"scene_taken")
	assert_eq(_host.claim_scene(_host.player(silver.player_id), ROUTE_22, true), &"not_a_scene", "Red's Route 22 is no Johto scene")
	assert_eq(_host.claim_scene(_host.player(silver.player_id), Vector2i(26, 3), true), &"not_a_scene",
		"Cherrygrove City's rival is in each player's own opening (D131)")


func test_a_johto_scene_plays_while_a_script_its_scene_or_its_story_talk_started_runs() -> void:
	var scenes: Dictionary = PokeCoopPolicy.rival_scenes(_data)
	assert_true(scenes.has(AZALEA) and scenes.has(LAKE_OF_RAGE), "Azalea's rival and the Lake of Rage are contested")
	var meet: Dictionary = {"kind": &"coord_events", "map_group": 8, "map_number": 7, "event": {"scene": 1}}
	var noop: Dictionary = {"kind": &"coord_events", "map_group": 8, "map_number": 7, "event": {"scene": 0}}
	var talk: Dictionary = {"kind": &"objects", "map_group": 8, "map_number": 7, "event": {"event_flag": -1}}
	var lance: Dictionary = {"kind": &"objects", "map_group": 9, "map_number": 6, "event": {"event_flag": EVENT_LAKE_OF_RAGE_LANCE}}
	assert_true(PokeCoopJohto.scene_request(meet))
	assert_false(PokeCoopJohto.scene_request(noop), "the town after the rival plays no scene")
	assert_false(PokeCoopJohto.scene_request(talk), "talking to someone in the town plays no scene")
	assert_true(PokeCoopJohto.scene_request(lance), "LANCE at the Lake of Rage does")
	assert_false(PokeCoopJohto.scene_request({}))
	assert_false(PokeCoopJohto.scene_playing(null))
