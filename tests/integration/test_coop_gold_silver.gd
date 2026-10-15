extends GutTest

## A Gold campaign on the synthetic Generation 2 fixture (#172): a Silver player
## joins it, both stand in New Bark Town, fight, save and come back to it.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const SAVE_PATH: String = "user://coop_gold_silver_test.json"
const NEW_BARK: Vector2i = Vector2i(24, 4)
const CHIKORITA: int = 152
const CYNDAQUIL: int = 155
const TOTODILE: int = 158
## `event_flags.asm`, `item_constants.asm`, `engine_flags.asm` and the maps at the pinned pokegold.
const ELMS_LAB: Vector2i = Vector2i(24, 5)
const MR_POKEMONS_HOUSE: Vector2i = Vector2i(26, 10)
const EVENT_GOT_A_POKEMON_FROM_ELM: int = 26
const EVENT_GOT_CYNDAQUIL_FROM_ELM: int = 27
const EVENT_GOT_TOTODILE_FROM_ELM: int = 28
const EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON: int = 30
const EVENT_GAVE_MYSTERY_EGG_TO_ELM: int = 31
const EVENT_GOT_EEVEE: int = 79
const EVENT_GOT_TM31_MUD_SLAP: int = 8
const EVENT_CYNDAQUIL_POKEBALL_IN_ELMS_LAB: int = 1600
const EVENT_TOTODILE_POKEBALL_IN_ELMS_LAB: int = 1601
const EVENT_CHIKORITA_POKEBALL_IN_ELMS_LAB: int = 1602
const SCENE_ELMSLAB_NOOP: int = 2
const ENGINE_POKEGEAR: int = 4
const ENGINE_POKEDEX: int = 11
const POKE_BALL: int = 5
const MYSTERY_EGG: int = 69
const BICYCLE: int = 7
const TM_MUD_SLAP: int = 223
const MAX_REPEL: int = 43

var _directory: String = ""
var _data: GameData = null
var _host: PokeCoopHost = null
var _clients: Array = []


func before_each() -> void:
	_directory = RomCache.directory_for(&"coopgoldsilvertest", "0123456789abcdef")
	_data = Fixture.build(_directory, String(RomRegistry.GOLD), RomRegistry.GEN2)
	_data.sha1 = RomRegistry.sha1_for(RomRegistry.GOLD)
	_clients = []
	_host = _hosting(PokeCoopCampaign.create("gold1", _data.id, _data.sha1))
	PokeCoopPolicy.start_campaign(_host.campaign, _data)


func after_each() -> void:
	RomCache.clear(_directory)
	for path: String in [SAVE_PATH, SAVE_PATH + PokeCoopSave.BACKUP_SUFFIX, SAVE_PATH + PokeCoopSave.JOURNAL_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _hosting(campaign: PokeCoopCampaign) -> PokeCoopHost:
	var host: PokeCoopHost = PokeCoopHost.create(_data, campaign, PokeCoopTransport.new())
	host.save_path = SAVE_PATH
	host.seeds.seed = 172
	host.allow_new_players = true
	host.register_encounter("wild:weak", {"species": Fixture.HOOTHOOT, "level": 2, "moves": [Fixture.GROWL]})
	return host


func _join(peer: int, player_name: String, game: StringName, id: String = "") -> PokeCoopClient:
	var link := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, link, peer)
	var client: PokeCoopClient = PokeCoopClient.over(link)
	client.greet(player_name, game, RomRegistry.sha1_for(game), id)
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


func _fight_out(battle_id: String) -> void:
	for _turn: int in 60:
		var client: PokeCoopClient = null
		for each: PokeCoopClient in _clients:
			client = each if each.is_controller(battle_id) else client
		if client == null or String(client.battle(battle_id).get("outcome", "")) != "":
			return
		client.act(battle_id, {"type": "move", "slot": 0})
		_pump()


func test_gold_and_silver_are_one_story_and_crystal_plays_alone() -> void:
	assert_true(PokeCoopLobby.GAMES.has(RomRegistry.GOLD))
	assert_true(PokeCoopLobby.GAMES.has(RomRegistry.SILVER))
	assert_false(PokeCoopLobby.GAMES.has(RomRegistry.CRYSTAL), "Crystal waits for #185")
	assert_eq(PokeCoopLobby.partners(RomRegistry.SILVER), [RomRegistry.GOLD, RomRegistry.SILVER])
	assert_eq(PokeCoopPolicy.other_version(RomRegistry.GOLD), RomRegistry.SILVER)
	assert_false(PokeCoopPolicy.same_story(RomRegistry.GOLD, RomRegistry.CRYSTAL))
	assert_false(PokeCoopPolicy.same_story(RomRegistry.SILVER, RomRegistry.RED))


func test_a_silver_player_joins_a_gold_campaign_in_new_bark_town() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)

	assert_ne(silver.player_id, "", "Silver is let in: %s" % silver.ended_reason)
	var first: PokeCoopPlayer = _host.player(gold.player_id)
	var second: PokeCoopPlayer = _host.player(silver.player_id)
	assert_eq([first.map, second.map], [NEW_BARK, NEW_BARK])
	assert_eq([first.cell, second.cell], PokeCoopPolicy.start_cells(_data).slice(0, 2), "the doorstep of the house, then beside it")
	assert_ne(first.cell, second.cell)
	assert_true(gold.nearby().has(silver.player_id), "Gold sees Silver")
	assert_true(silver.nearby().has(gold.player_id), "Silver sees Gold")
	assert_eq([(first.team[0]["mon"] as Gen2SaveMon).species, (second.team[0]["mon"] as Gen2SaveMon).species],
		[CHIKORITA, CYNDAQUIL], "Johto's starters, one each in turn")


func test_a_new_player_picks_one_of_johtos_starters() -> void:
	var link := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, link, 1)
	var client: PokeCoopClient = PokeCoopClient.over(link)
	client.greet("GOLD", RomRegistry.GOLD, _data.sha1, "", TOTODILE)
	_clients.append(client)
	_pump()

	assert_eq((_host.player(client.player_id).team[0]["mon"] as Gen2SaveMon).species, TOTODILE)
	assert_eq(PokeCoopPolicy.starters(_data), [CHIKORITA, CYNDAQUIL, TOTODILE])


func test_crystal_red_and_another_gold_are_told_why() -> void:
	for other: Array in [[RomRegistry.CRYSTAL, RomRegistry.sha1_for(RomRegistry.CRYSTAL)],
			[RomRegistry.RED, RomRegistry.sha1_for(RomRegistry.RED)], [RomRegistry.GOLD, "not-this-cartridge"]]:
		var link := PokeCoopTransport.new()
		PokeCoopTransport.link(_host.transport, link, 3)
		var stranger: PokeCoopClient = PokeCoopClient.over(link)
		stranger.greet("", other[0], other[1])
		_clients.append(stranger)
		_pump()
		assert_eq(stranger.last_rejection(), &"content_mismatch", String(other[0]))
	assert_eq(_host.players.size(), 0)


func test_a_gold_campaign_starts_without_red_and_blues_intro() -> void:
	assert_false(_host.campaign.has_flag(0x22), "Red and Blue's intro flags are other events in Johto")
	assert_eq(_host.campaign.world.get("gen1_map_scripts", {}), {})


func test_a_gold_campaign_fights_saves_and_reopens_with_both_in_new_bark_town() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)
	gold.start_battle("wild:weak")
	_pump()
	var battle_id: String = String(gold.current_battle().get("battle", ""))
	assert_ne(battle_id, "")
	_fight_out(battle_id)
	assert_eq(String(gold.battle(battle_id).get("outcome", "")), "won")
	silver.request_save()
	_pump()

	var loaded: Dictionary = PokeCoopSave.read(SAVE_PATH)
	assert_false(loaded.is_empty(), "the Gold campaign is written")
	assert_eq((loaded["campaign"] as PokeCoopCampaign).game_id, RomRegistry.GOLD)
	assert_eq((loaded["players"] as Array).map(func(member: PokeCoopPlayer) -> Vector2i: return member.map), [NEW_BARK, NEW_BARK])

	var ids: Array = [gold.player_id, silver.player_id]
	_host.shutdown()
	_pump()
	_clients = []
	_host = _hosting(loaded["campaign"])
	_host.adopt_players(loaded["players"])
	var back_gold: PokeCoopClient = _join(1, "", RomRegistry.GOLD, ids[0])
	var back_silver: PokeCoopClient = _join(2, "", RomRegistry.SILVER, ids[1])
	assert_eq([back_gold.player_id, back_silver.player_id], ids, "both come back as themselves")
	assert_true(back_gold.nearby().has(back_silver.player_id), "and see each other in New Bark Town again")


func _opening(peer: int, player_name: String, game: StringName) -> PokeCoopClient:
	var link := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, link, peer)
	var client: PokeCoopClient = PokeCoopClient.over(link)
	client.greet(player_name, game, RomRegistry.sha1_for(game), "", PokeCoopPolicy.PLAY_OPENING)
	_clients.append(client)
	_pump()
	client.send({"type": "opening", "rival": ""})
	_pump()
	return client


func _flags(client: PokeCoopClient, sets: Array, erases: Array = []) -> void:
	var set_entries: Dictionary = {}
	for flag: int in sets:
		set_entries[flag] = true
	client.send({"type": "world", "patch": {"event_flags": {"set": set_entries, "erase": erases}}})
	_pump()


## Elm's starter, Mr. Pokémon's house, where the rival steals the ball strong against it, and the egg to Elm.
func _play_opening(client: PokeCoopClient, picked: Array, stolen: int) -> void:
	client.step(ELMS_LAB, Vector2i(4, 7), 0, true)
	_flags(client, picked + [EVENT_GOT_A_POKEMON_FROM_ELM])
	client.step(MR_POKEMONS_HOUSE, Vector2i(3, 6), 0, true)
	_flags(client, [EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON, stolen])
	client.step(ELMS_LAB, Vector2i(4, 7), 0, true)
	_flags(client, [EVENT_GAVE_MYSTERY_EGG_TO_ELM])


func _world(client: PokeCoopClient) -> Dictionary:
	var view: Dictionary = (client.state.get("campaign", {}) as Dictionary).get("world", {})
	var mine: Dictionary = client.me().get("world", {})
	var flags: Dictionary = (view.get("event_flags", {}) as Dictionary).duplicate()
	flags.merge(mine.get("event_flags", {}), true)
	return {"event_flags": flags, "map_scenes": view.get("map_scenes", {}), "engine_flags": mine.get("engine_flags", {})}


func test_a_gold_opening_ends_once_the_egg_is_with_elm_and_the_lab_is_left() -> void:
	var gold: PokeCoopClient = _opening(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)
	assert_eq(String((gold.me().get("opening", {}) as Dictionary).get("stage", "")), PokeCoopPolicy.OPENING_PLAYING)

	_play_opening(gold, [EVENT_GOT_CYNDAQUIL_FROM_ELM, EVENT_CYNDAQUIL_POKEBALL_IN_ELMS_LAB], EVENT_TOTODILE_POKEBALL_IN_ELMS_LAB)
	assert_false((gold.me().get("opening", {}) as Dictionary).is_empty(), "still in Elm's lab: the opening goes on")
	gold.step(NEW_BARK, Vector2i(6, 4), 0, true)
	_pump()

	assert_true((gold.me().get("opening", {}) as Dictionary).is_empty(), "the lab left with the egg given: Gold joins the campaign")
	assert_true(silver.nearby().has(gold.player_id), "and is drawn for Silver")


func test_the_rival_steals_in_each_window_the_starter_strong_against_its_pick() -> void:
	var gold: PokeCoopClient = _opening(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _opening(2, "SILVER", RomRegistry.SILVER)
	_play_opening(gold, [EVENT_GOT_CYNDAQUIL_FROM_ELM, EVENT_CYNDAQUIL_POKEBALL_IN_ELMS_LAB], EVENT_TOTODILE_POKEBALL_IN_ELMS_LAB)
	_play_opening(silver, [EVENT_GOT_TOTODILE_FROM_ELM, EVENT_TOTODILE_POKEBALL_IN_ELMS_LAB], EVENT_CHIKORITA_POKEBALL_IN_ELMS_LAB)
	for client: PokeCoopClient in [gold, silver]:
		client.step(NEW_BARK, Vector2i(6, 4), 0, true)
	_pump()

	var gold_flags: Dictionary = _world(gold)["event_flags"]
	var silver_flags: Dictionary = _world(silver)["event_flags"]
	assert_true(gold_flags.has(EVENT_GOT_CYNDAQUIL_FROM_ELM) and not gold_flags.has(EVENT_GOT_TOTODILE_FROM_ELM),
		"Gold's rival fights with TOTODILE's line everywhere after")
	assert_true(silver_flags.has(EVENT_GOT_TOTODILE_FROM_ELM) and not silver_flags.has(EVENT_GOT_CYNDAQUIL_FROM_ELM),
		"Silver's with CHIKORITA's")
	assert_eq([gold_flags.has(EVENT_TOTODILE_POKEBALL_IN_ELMS_LAB), gold_flags.has(EVENT_CHIKORITA_POKEBALL_IN_ELMS_LAB)], [true, false],
		"Gold's lab lacks its own ball and the stolen one, CHIKORITA's stays")
	assert_eq([silver_flags.has(EVENT_CHIKORITA_POKEBALL_IN_ELMS_LAB), silver_flags.has(EVENT_CYNDAQUIL_POKEBALL_IN_ELMS_LAB)], [true, false])
	assert_true(_host.campaign.has_flag(EVENT_GAVE_MYSTERY_EGG_TO_ELM), "the story after the opening is the campaign's")
	assert_false(_host.campaign.has_flag(EVENT_GOT_CYNDAQUIL_FROM_ELM) or _host.campaign.has_flag(EVENT_CYNDAQUIL_POKEBALL_IN_ELMS_LAB))


func test_the_officer_names_the_rival_for_the_campaign_once() -> void:
	var gold: PokeCoopClient = _opening(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _opening(2, "SILVER", RomRegistry.SILVER)
	gold.send({"type": "opening", "rival": "KAMON"})
	_pump()
	silver.send({"type": "opening", "rival": "OTHER"})
	_pump()

	assert_eq(_host.campaign.rival_name, "KAMON", "the first answer to the officer names him for everyone")
	assert_eq(String((silver.state.get("campaign", {}) as Dictionary).get("rival_name", "")), "KAMON")


func test_a_late_joiner_in_new_bark_town_starts_where_the_opening_ends() -> void:
	var link := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, link, 1)
	var gold: PokeCoopClient = PokeCoopClient.over(link)
	gold.greet("GOLD", RomRegistry.GOLD, _data.sha1, "", TOTODILE)
	_clients.append(gold)
	_pump()

	var seen: Dictionary = _world(gold)
	assert_eq(int((seen["map_scenes"] as Dictionary).get(Gen2WorldState.map_scene_key(ELMS_LAB.x, ELMS_LAB.y), 0)), SCENE_ELMSLAB_NOOP,
		"Elm's lab past its walk-up, the officer and the aide")
	assert_true((seen["event_flags"] as Dictionary).has(EVENT_GAVE_MYSTERY_EGG_TO_ELM), "the errand to Mr. Pokémon done")
	assert_true((seen["event_flags"] as Dictionary).has(EVENT_GOT_TOTODILE_FROM_ELM), "the rival's later teams answer TOTODILE")
	assert_true((seen["event_flags"] as Dictionary).has(EVENT_CHIKORITA_POKEBALL_IN_ELMS_LAB), "and he took CHIKORITA")
	assert_false((seen["event_flags"] as Dictionary).has(EVENT_CYNDAQUIL_POKEBALL_IN_ELMS_LAB))
	assert_true((seen["engine_flags"] as Dictionary).has(ENGINE_POKEGEAR) and (seen["engine_flags"] as Dictionary).has(ENGINE_POKEDEX),
		"Mom's Pokégear and Oak's Pokédex")
	var me: PokeCoopPlayer = _host.player(gold.player_id)
	assert_eq([me.money, me.item_count(POKE_BALL)], [PokeCoopPolicy.NEW_PLAYER_MONEY, 5], "the aide's five Poké Balls")
	assert_false(_host.campaign.has_flag(EVENT_GOT_TOTODILE_FROM_ELM), "the starter's flag is the player's")


func test_a_gift_pokemon_is_taken_by_both_players() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)
	_flags(gold, [EVENT_GOT_EEVEE])

	assert_false((_world(silver)["event_flags"] as Dictionary).has(EVENT_GOT_EEVEE), "Bill still has an EEVEE for Silver")
	_flags(silver, [EVENT_GOT_EEVEE])
	assert_true((_world(gold)["event_flags"] as Dictionary).has(EVENT_GOT_EEVEE))
	assert_true((_world(silver)["event_flags"] as Dictionary).has(EVENT_GOT_EEVEE), "one each")
	assert_false(_host.campaign.has_flag(EVENT_GOT_EEVEE))


func test_johtos_story_gifts_reach_everyone_by_johtos_own_items() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)
	var second: PokeCoopPlayer = _host.player(silver.player_id)
	gold.send({"type": "world", "patch": {"items": {"set": {MAX_REPEL: 1}, "erase": []}}})
	_pump()
	assert_eq(second.item_count(MAX_REPEL), 0, "a MAX_REPEL is no key item: Red's SECRET_KEY id means nothing here")
	gold.send({"type": "world", "patch": {"items": {"set": {BICYCLE: 1}, "erase": []},
		"event_flags": {"set": {EVENT_GOT_TM31_MUD_SLAP: true}, "erase": []}}})
	_pump()

	assert_eq(second.item_count(BICYCLE), 1, "the BICYCLE is kept for good, so everyone has one")
	assert_eq(second.item_count(TM_MUD_SLAP), 1, "FALKNER's TM reaches everyone once")


## Two Johto maps' grass by morning, day and night, and one's water: [species, level] per slot.
func _write_wild(data: GameData, morning: int, night: int, water: int) -> void:
	var day: Array = []
	for _slot: int in 7:
		day.append({"species": Fixture.HOOTHOOT, "level": 3})
	var grass: Array = [day.duplicate(true), day.duplicate(true), day.duplicate(true)]
	grass[0][2] = {"species": morning, "level": 4}
	grass[2][2] = {"species": night, "level": 5}
	RomCache.write_json(RomCache.world_encounters_path(data.directory), {
		"grass": {"24:3": {"map": "24:3", "region": "johto", "rate": 25, "slots": grass}},
		"water": {"26:1": {"map": "26:1", "region": "johto", "rate": 5,
			"slots": [{"species": water, "level": 20}, {"species": water, "level": 15}, {"species": water, "level": 20}]}},
	})


func test_a_wild_from_both_versions_takes_the_other_versions_slot_at_the_windows_time_of_day() -> void:
	var gold: GameData = Fixture.build(RomCache.directory_for(&"coopgoldwild", "0123456789abcdef"), String(RomRegistry.GOLD), RomRegistry.GEN2)
	var silver: GameData = Fixture.build(RomCache.directory_for(&"coopsilverwild", "0123456789abcdef"), String(RomRegistry.SILVER), RomRegistry.GEN2)
	_write_wild(gold, Fixture.CHARMANDER, Fixture.GEODUDE, Fixture.PIKACHU)
	_write_wild(silver, Fixture.HOOTHOOT, Fixture.HOOTHOOT, Fixture.HOOTHOOT)
	var gold_tables: Dictionary = PokeCoopPolicy.sane_wild_tables(JSON.parse_string(JSON.stringify(PokeCoopPolicy.wild_tables(gold))), false)
	var own: Dictionary = PokeCoopPolicy.wild_species(PokeCoopPolicy.wild_tables(silver))
	var grass: Dictionary = {"method": Gen2WorldEncounter.METHOD_GRASS, "generation": RomRegistry.GEN2, "map_group": 24, "map_number": 3,
		"slot": 2, "roll": 200, "time_of_day": 2}

	assert_eq(int(PokeCoopPolicy.other_wild(grass, gold_tables, own).get("species", 0)), Fixture.GEODUDE, "Gold's night slot at night")
	grass["time_of_day"] = 0
	assert_eq(int(PokeCoopPolicy.other_wild(grass, gold_tables, own).get("species", 0)), Fixture.CHARMANDER, "its morning slot by morning")
	grass["slot"] = 3
	assert_eq(PokeCoopPolicy.other_wild(grass, gold_tables, own), {}, "a slot both versions share keeps Silver's own")
	var water: Dictionary = {"method": Gen2WorldEncounter.METHOD_SURF, "generation": RomRegistry.GEN2, "map_group": 26, "map_number": 1,
		"slot": 1, "roll": 200}
	assert_eq(int(PokeCoopPolicy.other_wild(water, gold_tables, own).get("level", 0)), 15, "the water's slot, level and all")
	water["roll"] = 100
	assert_eq(PokeCoopPolicy.other_wild(water, gold_tables, own), {}, "the lower half of the roll is the cartridge's own")
	RomCache.clear(silver.directory)
	RomCache.clear(gold.directory)
