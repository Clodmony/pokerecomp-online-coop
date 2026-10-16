extends GutTest

## Gold and Silver's Cable Club between players (#181): the Trade Center's cable,
## held items and trade evolutions, on the synthetic Generation 2 fixture.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const SAVE_PATH: String = "user://coop_johto_cable_club_test.json"
const NEW_BARK: Vector2i = Vector2i(24, 4)
const TRADE_CENTER: Vector2i = Vector2i(20, 2)
const COLOSSEUM: Vector2i = Vector2i(20, 3)
const METAL_COAT: int = 0x8F

var _directory: String = ""
var _data: GameData = null
var _host: PokeCoopHost = null
var _clients: Array = []
var _links: Array = []
var _gold: PokeCoopClient = null
var _silver: PokeCoopClient = null


func before_each() -> void:
	_directory = RomCache.directory_for(&"coopjohtocable", "0123456789abcdef")
	_data = Fixture.build(_directory, String(RomRegistry.GOLD), RomRegistry.GEN2)
	_data.sha1 = RomRegistry.sha1_for(RomRegistry.GOLD)
	_host = PokeCoopHost.create(_data, PokeCoopCampaign.create("gold1", _data.id, _data.sha1), PokeCoopTransport.new())
	_host.save_path = SAVE_PATH
	_host.seeds.seed = 181
	var gold: PokeCoopPlayer = _host.add_player("GOLD", 100)
	gold.place(NEW_BARK, Vector2i(13, 6), 0)
	gold.add_mon(_saved(Fixture.CHARMANDER, 30, 100, Fixture.BERRY_ITEM))
	gold.add_mon(_saved(Fixture.GEODUDE, 30, 100, METAL_COAT))
	var silver: PokeCoopPlayer = _host.add_player("SILVER", 200)
	silver.place(NEW_BARK, Vector2i(12, 6), 0)
	silver.add_mon(_saved(Fixture.PIKACHU, 30, 200, 0))
	silver.add_mon(_saved(Fixture.BULBASAUR, 30, 200, 0))
	_clients = []
	_links = []
	_gold = _connect(1, gold.player_id)
	_silver = _connect(2, silver.player_id)


func after_each() -> void:
	RomCache.clear(_directory)
	for path: String in [SAVE_PATH, SAVE_PATH + PokeCoopSave.BACKUP_SUFFIX, SAVE_PATH + PokeCoopSave.JOURNAL_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _saved(species: int, level: int, ot: int, item: int) -> Gen2SaveMon:
	var out: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(Gen2BattleMon.create(_data, species, level, [Fixture.TACKLE]))
	out.ot_id = ot
	out.item = item
	return out


func _connect(peer: int, player_id: String) -> PokeCoopClient:
	var link := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, link, peer)
	var client: PokeCoopClient = PokeCoopClient.over(link)
	client.greet("", _data.id, _data.sha1, player_id)
	_clients.append(client)
	_pump()
	return client


func _window(client: PokeCoopClient) -> PokeCoopWorldLink:
	var state := Gen2WorldState.new()
	var link: PokeCoopWorldLink = PokeCoopWorldLink.over(client, state, PokeCoopWorldLink.local_save(client, _data), _data)
	var map := Gen2WorldMap.new()
	map.group = NEW_BARK.x
	map.number = NEW_BARK.y
	link.world = Gen2WorldAPI.new(_data, map, null, Vector2i(13, 6), state)
	_links.append(link)
	_pump()
	return link


func _pump() -> void:
	for _round: int in 4:
		for client: PokeCoopClient in _clients:
			client.poll()
		for link: PokeCoopWorldLink in _links:
			link.advance()
		_host.poll()
	for client: PokeCoopClient in _clients:
		client.poll()


func _send(callback: Callable) -> void:
	callback.call()
	_pump()


func _cables() -> Array:
	var cables: Array = []
	for client: PokeCoopClient in [_gold, _silver]:
		var cable: PokeCoopLinkTransport = PokeCoopLinkTransport.over(client)
		cable.refresh()
		cables.append(cable)
	return cables


## Gold offers [param gold_slot] and Silver [param silver_slot]; both say TRADE.
func _trade(gold_slot: int, silver_slot: int) -> Array:
	var cables: Array = _cables()
	cables[0].choose_trade_slot({"slot": gold_slot})
	_pump()
	cables[1].refresh()
	cables[1].choose_trade_slot({"slot": silver_slot})
	_pump()
	cables[0].choose_trade_slot({})
	cables[1].choose_trade_slot({})
	cables[0].answer_trade(true)
	cables[1].answer_trade(true)
	_pump()
	return [cables[0].trade_answer(), cables[1].trade_answer()]


func test_the_receptionist_finds_a_game_boy_color_on_the_other_end_of_a_gold_cable() -> void:
	var session := Gen2LinkSession.new()
	var cable: PokeCoopLinkTransport = _cables()[0]

	assert_eq(session.check_link_timeout(cable), 1, "the link holds")
	assert_eq(session.other_player_link_mode, 1, "not \"You can't link to the past here.\"")
	assert_eq(int(cable.peer_block({})["generation"]), Gen2LinkTransport.GENERATION_2)


func test_held_items_travel_and_a_pokemon_holding_its_trade_item_arrives_evolved() -> void:
	(_data.species(Fixture.GEODUDE) as Dictionary)["evolutions"] = [{
		"method": Gen2Layout.EVOLVE_TRADE, "parameter": METAL_COAT, "condition": 0, "target": Fixture.MAGCARGO,
	}]
	_host.player(_silver.player_id).team[0]["mon"].item = Fixture.BERRY_ITEM
	var geodude_uid: String = String(_host.player(_gold.player_id).team[1]["uid"])

	assert_eq(_trade(1, 0), [1, 1])
	var to_silver: Dictionary = _host.player(_silver.player_id).team[-1]
	assert_eq(String(to_silver["uid"]), geodude_uid)
	assert_eq((to_silver["mon"] as Gen2SaveMon).species, Fixture.MAGCARGO, "evolved on arrival, as METAL COAT makes STEELIX")
	assert_eq((to_silver["mon"] as Gen2SaveMon).item, 0, "the METAL COAT was spent")
	var to_gold: Gen2SaveMon = _host.player(_gold.player_id).team[-1]["mon"]
	assert_eq([to_gold.species, to_gold.item], [Fixture.PIKACHU, Fixture.BERRY_ITEM], "the BERRY came along")


func test_two_gold_players_in_the_trade_center_are_cabled_to_each_other() -> void:
	var third: PokeCoopPlayer = _host.add_player("HIRO", 300)
	third.place(NEW_BARK, Vector2i(14, 6), 0)
	third.add_mon(_saved(Fixture.CUBONE, 30, 300, 0))
	var hiro: PokeCoopClient = _connect(3, third.player_id)
	_send(func() -> void: _gold.step(TRADE_CENTER, Vector2i(4, 4), 0, true))
	_send(func() -> void: hiro.step(TRADE_CENTER, Vector2i(5, 4), 0, true))

	assert_eq(String(_gold.me()["trade_partner"]["player_id"]), hiro.player_id, "the mate in the room, not the first by id")
	assert_eq(String(hiro.me()["trade_partner"]["player_id"]), _gold.player_id)
	assert_false(_silver.me().has("trade_partner"), "outside, and both are taken")


## Both players unlocked at Carrie's, Gold asks Silver for a Mystery Gift and Silver says YES.
func _gift() -> Array:
	_send(func() -> void: _gold.challenge(_silver.player_id, PokeCoopPolicy.CHALLENGE_GIFT))
	_send(func() -> void: _silver.answer_challenge(String(_silver.me()["challenge"]["incoming"]["id"]), true))
	return [_gold, _silver].map(func(client: PokeCoopClient) -> String: return String(client.me()["mystery_gift"]["round"].get("outcome", "")))


func _set_day(day: int) -> void:
	_host.campaign.clock = PokeCoopJohto.set_to({"day": day, "cur_day": day, "hour": 10, "minute": 0, "second": 0}, Gen2WorldClock.host_seconds())


func test_a_mystery_gift_goes_both_ways_once_a_day_per_partner_on_the_campaigns_clock() -> void:
	_set_day(3)
	var windows: Array = [_window(_gold), _window(_silver)]
	_send(func() -> void: _gold.challenge(_silver.player_id, PokeCoopPolicy.CHALLENGE_GIFT))
	assert_false(_silver.me()["challenge"].has("incoming"), "nobody has talked to Carrie yet")
	for window: PokeCoopWorldLink in windows:
		Gen2MysteryGift.unlock(window.state.mystery_gift())
	_pump()
	assert_true(_host.player(_gold.player_id).public_view()["gift"], "Carrie's unlock reached the host")

	var first: Array = _gift()
	assert_true(first.all(func(outcome: String) -> bool: return outcome in ["sent", "sent_home"]), str(first))
	for window: PokeCoopWorldLink in windows:
		var section: Dictionary = window.state.mystery_gift()
		var partner: PokeCoopPlayer = _host.player(_silver.player_id if window.client == _gold else _gold.player_id)
		assert_has(section["partner_ids"], partner.trainer_id, "each counted the other")
		assert_eq(int(section["item"]), int(section["backup_item"]), "the gift waits at the counter as after a Continue")
	assert_eq(_gift(), ["one_a_day", "one_a_day"], "the same partner the same day")

	for window: PokeCoopWorldLink in windows:
		Gen2MysteryGift.clear_item(window.state.mystery_gift())
	_pump()
	assert_eq([_gold, _silver].map(func(client: PokeCoopClient) -> int: return int(_host.player(client.player_id).mystery_gift["backup_item"])),
		[0, 0], "the delivery man's gifts were taken")
	_set_day(4)
	var next_day: Array = _gift()
	assert_true(next_day.all(func(outcome: String) -> bool: return outcome in ["sent", "sent_home"]), str(next_day))
	assert_eq(int(windows[0].state.mystery_gift()["daily_partners"]), 1, "a new day's first partner")


func test_a_colosseum_battle_pits_the_two_players_and_leaves_both_parties_as_they_were() -> void:
	var before: Array = [_gold, _silver].map(func(client: PokeCoopClient) -> Array: return _host.player(client.player_id).team_rows())
	for client: PokeCoopClient in [_gold, _silver]:
		_send(func() -> void: client.step(COLOSSEUM, Vector2i(4, 4), 0, true))
	_send(func() -> void: _gold.send({"type": "trade", "colosseum": 1, "partner": _silver.player_id}))
	assert_true(_host.battles.is_empty(), "Gold waits at the table for Silver")
	_send(func() -> void: _silver.send({"type": "trade", "colosseum": 1, "partner": _gold.player_id}))

	var id: String = String(_gold.current_battle().get("battle", ""))
	assert_true((_host.battles[id] as PokeCoopVersus).colosseum, "a link battle, both sides human")
	assert_eq(_silver.battle(id)["trainer_name"], "GOLD")
	for _turn: int in 200:
		if not String(_gold.battle(id).get("outcome", "")).is_empty():
			break
		for client: PokeCoopClient in [_gold, _silver]:
			var view: Dictionary = client.battle(id)
			if String(view["phase"]) == String(PokeCoopBattleSession.AWAITING_SEND_OUT):
				var standing: Array = (view["allies"] as Array).filter(func(ally: Dictionary) -> bool: return int(ally["hp"]) > 0)
				client.act(id, {"type": "send_out", "index": int(standing[0]["index"])})
			elif client.is_controller(id):
				client.act(id, {"type": "move", "slot": 0})
		_pump()
	var outcomes: Array = [String(_gold.battle(id)["outcome"]), String(_silver.battle(id)["outcome"])]
	outcomes.sort()
	assert_eq(outcomes, ["lost", "won"])
	var after: Array = [_gold, _silver].map(func(client: PokeCoopClient) -> Array: return _host.player(client.player_id).team_rows())
	assert_eq(after, before, "`LoadPokemonData`: HP, PP and experience as saved before the link")
