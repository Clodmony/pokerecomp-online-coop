extends GutTest

## A Gold campaign on the synthetic Generation 2 fixture (#172): a Silver player
## joins it, both stand in New Bark Town, fight, save and come back to it.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const SAVE_PATH: String = "user://coop_gold_silver_test.json"
const NEW_BARK: Vector2i = Vector2i(24, 4)
const CHIKORITA: int = 152
const CYNDAQUIL: int = 155
const TOTODILE: int = 158

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
	PokeCoopPolicy.start_campaign(_host.campaign)


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
	assert_eq(_host.campaign.flags, {}, "Red and Blue's intro flags are other events in Johto")
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
