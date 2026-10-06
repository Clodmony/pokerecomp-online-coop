extends GutTest

## A co-op host and two clients over the in-memory transport, driven only through
## what a client can send: the first co-op slice end to end. The ENet transport
## carries the same packets; `tools/coop_session.gd demo` runs this over sockets.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const SAVE_PATH: String = "user://coop_session_test.json"
const PALLET: Vector2i = Vector2i(0, 0)
const ROUTE_1: Vector2i = Vector2i(0, 12)
const BEAT_LEADER: int = 0x77

var _directory: String = ""
var _data: GameData = null
var _host: PokeCoopHost = null
var _clients: Array = []
var _links: Array = []
var _red: PokeCoopClient = null
var _blue: PokeCoopClient = null


func before_each() -> void:
	_directory = RomCache.directory_for(&"coopsessiontest", "0123456789abcdef")
	_data = Fixture.build(_directory, "testgame", RomRegistry.GEN1)
	_host = PokeCoopHost.create(
		_data, PokeCoopCampaign.create("c1", _data.id, _data.sha1), PokeCoopTransport.new()
	)
	_host.save_path = SAVE_PATH
	_host.seeds.seed = 99
	var red: PokeCoopPlayer = _host.add_player("RED", 100)
	red.place(PALLET, Vector2i(5, 5), 0)
	red.add_mon(_saved(Fixture.CHARMANDER, 60, [Fixture.SLASH, Fixture.GROWL], 100))
	red.add_mon(_saved(Fixture.PIKACHU, 20, [Fixture.TACKLE], 100))
	var blue: PokeCoopPlayer = _host.add_player("BLUE", 200)
	blue.place(PALLET, Vector2i(6, 5), 0)
	blue.add_mon(_saved(Fixture.CHARMANDER, 20, [Fixture.TACKLE, Fixture.GROWL], 200))
	blue.add_mon(_saved(Fixture.BULBASAUR, 20, [Fixture.TACKLE], 200))
	_host.register_encounter("wild:stall", {"species": Fixture.GEODUDE, "level": 50, "moves": [Fixture.GROWL]})
	_host.register_encounter("wild:weak", {"species": Fixture.BULBASAUR, "level": 2, "moves": [Fixture.GROWL]})
	_host.register_encounter("trainer:leader", {
		"kind": "trainer", "trainer_class": Fixture.GEN1_LEADER, "trainer_index": 0,
		"victory_flags": [BEAT_LEADER], "badge": 0,
	})
	_clients = []
	_links = []
	_red = _connect(1, red.player_id)
	_blue = _connect(2, blue.player_id)


func after_each() -> void:
	RomCache.clear(_directory)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _saved(species: int, level: int, moves: Array, ot: int) -> Gen2SaveMon:
	var out: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(
		Gen2BattleMon.create(_data, species, level, moves)
	)
	out.ot_id = ot
	return out


func _connect(peer: int, player_id: String) -> PokeCoopClient:
	var link := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, link, peer)
	var client: PokeCoopClient = PokeCoopClient.over(link)
	client.greet("", _data.id, _data.sha1, player_id)
	_clients.append(client)
	_pump()
	return client


func _pump() -> void:
	for _round: int in 4:
		for client: PokeCoopClient in _clients:
			client.poll()
		for link: PokeCoopWorldLink in _links:
			link.advance()
		_host.poll()
	for client: PokeCoopClient in _clients:
		client.poll()


## A window's own world for [param client]: a world state and a save built from
## its player's record, kept in step by a link.
func _window(client: PokeCoopClient) -> PokeCoopWorldLink:
	var state := Gen2WorldState.new()
	state.gen1 = true
	var save: Gen2SaveData = PokeCoopWorldLink.local_save(client, _data)
	var link: PokeCoopWorldLink = PokeCoopWorldLink.over(client, state, save, _data)
	_links.append(link)
	_pump()
	return link


func _send(call: Callable) -> void:
	call.call()
	_pump()


func _battle_of(client: PokeCoopClient) -> String:
	return String(client.current_battle().get("battle", ""))


func _controller_of(battle_id: String) -> PokeCoopClient:
	for client: PokeCoopClient in _clients:
		if client.is_controller(battle_id):
			return client
	return null


## Plays [param battle_id] to its end with whoever controls it using [param slot],
## sending out the next standing ally when one is needed.
func _fight_out(battle_id: String, slot: int = 0) -> void:
	for _turn: int in 60:
		var controller: PokeCoopClient = _controller_of(battle_id)
		if controller == null:
			return
		var view: Dictionary = controller.battle(battle_id)
		if String(view.get("outcome", "")) != "":
			return
		if String(view["phase"]) == String(PokeCoopBattleSession.AWAITING_SEND_OUT):
			controller.act(battle_id, {"type": "send_out", "index": _next_ally(view)})
		else:
			controller.act(battle_id, {"type": "move", "slot": slot})
		_pump()


static func _next_ally(view: Dictionary) -> int:
	for ally: Dictionary in view["allies"]:
		if int(ally["hp"]) > 0 and int(ally["index"]) != int(view["active"]):
			return int(ally["index"])
	return -1


func test_two_clients_each_move_their_own_player_and_see_each_other_on_one_map() -> void:
	assert_ne(_red.player_id, "")
	assert_ne(_red.player_id, _blue.player_id)
	assert_true(_red.nearby().has(_blue.player_id), "both start in Pallet Town")

	_send(func() -> void: _blue.step(ROUTE_1, Vector2i(3, 3), 1))
	assert_false(_red.nearby().has(_blue.player_id), "Blue left for Route 1")
	assert_eq(_host.player(_red.player_id).map, PALLET, "Red stayed where Red was")

	_send(func() -> void: _red.step(PALLET, Vector2i(5, 8), 0))
	assert_eq(_red.last_rejection(), &"not_adjacent", "three cells is neither a step nor a hop")


func test_one_player_battles_while_the_other_explores_and_starts_their_own() -> void:
	_send(func() -> void: _red.start_battle("wild:stall"))
	var red_battle: String = _battle_of(_red)
	assert_ne(red_battle, "")
	var revision: int = int(_red.battle(red_battle)["revision"])

	_send(func() -> void: _blue.step(PALLET, Vector2i(6, 6), 0))
	assert_eq(_host.player(_blue.player_id).cell, Vector2i(6, 6), "Blue keeps exploring")
	_send(func() -> void: _blue.start_battle("wild:weak"))
	var blue_battle: String = _battle_of(_blue)
	assert_ne(blue_battle, "")
	assert_ne(blue_battle, red_battle, "a battle of Blue's own")

	_fight_out(blue_battle)
	assert_eq(int(_red.battle(red_battle)["revision"]), revision, "Red's battle did not move")
	assert_eq(_host.battles.size(), 1)


func test_a_free_player_joins_and_the_turn_follows_the_pokemon_that_is_out() -> void:
	_send(func() -> void: _red.start_battle("wild:stall"))
	var battle_id: String = _battle_of(_red)
	_send(func() -> void: _blue.join_battle(battle_id))

	var view: Dictionary = _red.battle(battle_id)
	assert_true((view["participants"] as Array).has(_blue.player_id), "joined at the boundary")
	assert_eq((view["allies"] as Array).size(), 4, "both owners' Pokémon in one roster")
	assert_eq(String(view["controller"]), _red.player_id)

	_send(func() -> void: _blue.act(battle_id, {"type": "move", "slot": 0}))
	assert_eq(_blue.last_rejection(), &"not_controller")
	_send(func() -> void: _blue.suggest(battle_id, "switch", 2))
	view = _red.battle(battle_id)
	assert_eq(int(view["suggestions"][_blue.player_id]["value"]), 2, "Red sees Blue's pointer")
	assert_eq(int(view["revision"]), int(_blue.battle(battle_id)["revision"]))

	_send(func() -> void: _red.act(battle_id, {"type": "switch", "index": 2}))
	assert_eq(String(_blue.battle(battle_id)["controller"]), _blue.player_id,
		"Blue's Pokémon is out, so Blue decides")
	_send(func() -> void: _blue.join_battle(battle_id))
	assert_eq(_blue.last_rejection(), &"already_joined")


func test_battle_results_land_on_each_owners_own_pokemon() -> void:
	var red_before: Array = (_red.me()["team"] as Array).duplicate(true)
	var blue_before: Array = (_blue.me()["team"] as Array).duplicate(true)
	_send(func() -> void: _red.start_battle("wild:weak"))
	var battle_id: String = _battle_of(_red)
	_send(func() -> void: _blue.join_battle(battle_id))
	_send(func() -> void: _red.act(battle_id, {"type": "switch", "index": 2}))
	_fight_out(battle_id)
	assert_eq(String(_red.battle(battle_id)["outcome"]), "won")

	var red_after: Array = _red.me()["team"]
	var blue_after: Array = _blue.me()["team"]
	assert_gt(int(red_after[0]["exp"]), int(red_before[0]["exp"]), "Red's lead was out first")
	assert_eq(int(red_after[1]["exp"]), int(red_before[1]["exp"]), "Red's bench never fought")
	assert_gt(int(blue_after[0]["exp"]), int(blue_before[0]["exp"]), "Blue's Pokémon finished it")
	assert_eq(int(blue_after[1]["exp"]), int(blue_before[1]["exp"]))
	var tackle_pp: int = _host.player(_blue.player_id).mon(String(blue_after[0]["uid"])).pp[0]
	assert_lt(tackle_pp, int(_saved(Fixture.CHARMANDER, 20, [Fixture.TACKLE], 200).pp[0]),
		"the PP Blue spent is gone from Blue's record")
	assert_true(_host.player(_red.player_id).is_free())
	assert_true(_host.player(_blue.player_id).is_free())
	assert_eq(
		int((PokeCoopSave.read(SAVE_PATH)["players"] as Array).size()), 2,
		"the campaign saved itself once no battle was left running"
	)


func test_a_trainer_victory_sets_the_shared_flag_once_for_both_players() -> void:
	_send(func() -> void: _blue.step(ROUTE_1, Vector2i(3, 3), 1))
	_send(func() -> void: _red.start_battle("trainer:leader"))
	var battle_id: String = _battle_of(_red)
	_send(func() -> void: _blue.start_battle("trainer:leader"))
	assert_eq(_blue.last_rejection(), &"encounter_taken", "one leader, one fight at a time")

	_fight_out(battle_id)
	assert_eq(String(_red.battle(battle_id)["outcome"]), "won")
	assert_true((_blue.state["campaign"]["flags"] as Array).has(BEAT_LEADER), "Blue shares the flag")
	assert_eq(int(_blue.state["campaign"]["badges"]), 1)
	assert_eq(_host.player(_blue.player_id).map, ROUTE_1, "without being moved")
	assert_gt(int(_red.me()["money"]), PokeCoopPolicy.NEW_PLAYER_MONEY, "Red took the prize")
	assert_eq(int(_blue.me()["money"]), PokeCoopPolicy.NEW_PLAYER_MONEY)

	var revision: int = _host.campaign.revision
	assert_false(_host.campaign.commit("victory:trainer:leader", {"flags": [BEAT_LEADER]}))
	assert_eq(_host.campaign.revision, revision)
	_send(func() -> void: _red.start_battle("trainer:leader"))
	assert_eq(_red.last_rejection(), &"encounter_taken", "and stays beaten")


func test_a_caught_pokemon_is_filed_once_with_the_player_it_was_caught_for() -> void:
	_host.player(_red.player_id).give_item(Gen2WorldPartyHost.ITEM_MASTER_BALL, 1)
	_send(func() -> void: _red.start_battle("wild:weak"))
	var battle_id: String = _battle_of(_red)
	_send(func() -> void: _blue.join_battle(battle_id))
	var throw: Dictionary = {
		"type": "command", "battle": battle_id, "seq": 50,
		"command": {
			"type": "item", "item": Gen2WorldPartyHost.ITEM_MASTER_BALL,
			"recipient": _blue.player_id, "revision": int(_red.battle(battle_id)["revision"]),
		},
	}
	_send(func() -> void: _red.transport.send(PokeCoopTransport.HOST_PEER, throw))
	_send(func() -> void: _red.transport.send(PokeCoopTransport.HOST_PEER, throw))

	var blue: PokeCoopPlayer = _host.player(_blue.player_id)
	assert_eq(String(_red.battle(battle_id)["outcome"]), "caught")
	assert_eq(blue.team.size(), 3, "one catch, delivered once")
	var caught: Gen2SaveMon = blue.team[2]["mon"]
	assert_eq(caught.species, Fixture.BULBASAUR)
	assert_eq(caught.ot_id, blue.trainer_id, "Blue is its trainer")
	assert_true((blue.world_part()["caught_species"] as Dictionary).has(Fixture.BULBASAUR))
	assert_eq(_host.player(_red.player_id).team.size(), 2)
	assert_eq(_host.player(_red.player_id).item_count(Gen2WorldPartyHost.ITEM_MASTER_BALL), 0)


func test_a_message_delivered_twice_is_applied_once() -> void:
	_send(func() -> void: _red.start_battle("wild:stall"))
	var battle_id: String = _battle_of(_red)
	var revision: int = int(_red.battle(battle_id)["revision"])
	var message: Dictionary = {
		"type": "command", "battle": battle_id, "seq": 100,
		"command": {"type": "move", "slot": 0, "revision": revision},
	}
	_send(func() -> void: _red.transport.send(PokeCoopTransport.HOST_PEER, message))
	_send(func() -> void: _red.transport.send(PokeCoopTransport.HOST_PEER, message))

	assert_eq(int(_red.battle(battle_id)["revision"]), revision + 1)
	assert_eq(_red.last_rejection(), &"duplicate")


func test_a_save_waits_for_a_safe_checkpoint_and_reloads_everyone() -> void:
	_send(func() -> void: _red.start_battle("wild:weak"))
	_send(func() -> void: _blue.request_save())
	assert_eq(_blue.last_rejection(), &"battle_in_progress")
	_fight_out(_battle_of(_red))
	_send(func() -> void: _blue.step(ROUTE_1, Vector2i(3, 3), 1))

	var rejected: int = _blue.rejections.size()
	_send(func() -> void: _blue.request_save())
	assert_eq(_blue.rejections.size(), rejected, "saved between battles")

	var loaded: Dictionary = PokeCoopSave.read(SAVE_PATH)
	assert_false(loaded.is_empty())
	assert_eq(
		PokeCoopSave.to_dict(loaded["campaign"], loaded["players"]),
		PokeCoopSave.to_dict(_host.campaign, _host.players.values())
	)


func test_a_lost_controller_pauses_only_their_battle() -> void:
	_send(func() -> void: _red.start_battle("wild:stall"))
	var battle_id: String = _battle_of(_red)
	var revision: int = int(_red.battle(battle_id)["revision"])
	_host.transport.drop(1)
	_pump()

	assert_true(bool(_host.battles[battle_id].is_paused()))
	assert_false(_blue.nearby().has(_red.player_id), "nobody is drawn for a player who left")
	_send(func() -> void: _blue.step(PALLET, Vector2i(6, 6), 0))
	assert_eq(_host.player(_blue.player_id).cell, Vector2i(6, 6), "Blue's exploration goes on")

	_clients.erase(_red)
	_red = _connect(1, _red.player_id)
	var view: Dictionary = _red.battle(battle_id)
	assert_false(bool(view["paused"]), "back where it stopped")
	assert_eq(int(view["revision"]), revision)
	_send(func() -> void: _red.act(battle_id, {"type": "move", "slot": 1}))
	assert_eq(int(_red.battle(battle_id)["revision"]), revision + 1)


func test_a_new_player_joins_with_the_starter_they_chose_in_pallet_town() -> void:
	_host.allow_new_players = true
	var link := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, link, 3)
	var green: PokeCoopClient = PokeCoopClient.over(link)
	green.greet("GREEN", _data.id, _data.sha1, "", Fixture.CHARMANDER)
	_clients.append(green)
	_pump()

	var player: PokeCoopPlayer = _host.player(green.player_id)
	assert_eq(player.name, "GREEN")
	assert_eq(player.team.size(), 1)
	var starter: Gen2SaveMon = player.team[0]["mon"]
	assert_eq([starter.species, starter.level], [Fixture.CHARMANDER, PokeCoopPolicy.STARTER_LEVEL])
	assert_eq(starter.ot_id, player.trainer_id, "the player is its trainer, not a trade")
	assert_eq(player.map, PokeCoopPolicy.START_MAP)
	assert_eq(player.cell, PokeCoopPolicy.START_CELLS[2], "a third player takes the third spot")


func test_a_client_with_another_cartridge_is_told_why_and_let_go() -> void:
	var link := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, link, 3)
	var stranger: PokeCoopClient = PokeCoopClient.over(link)
	stranger.greet("", &"blue", "not-this-cartridge")
	_clients.append(stranger)
	_pump()

	assert_eq(stranger.last_rejection(), &"content_mismatch")
	assert_eq(stranger.ended_reason, "refused: content_mismatch")
	assert_eq(stranger.player_id, "", "no player was handed out")
	assert_eq(_host.players.size(), 2)


func test_only_plain_data_crosses_the_wire() -> void:
	var stripped: Dictionary = PokeCoopTransport.decode(PokeCoopTransport.encode({
		"type": "state", "object": RefCounted.new(), "nested": [Node2D, {"cell": Vector2i(1, 2)}],
	}))
	assert_null(stripped["object"], "objects are never encoded")
	assert_null(stripped["nested"][0])
	assert_eq(stripped["nested"][1]["cell"], Vector2i(1, 2))
	assert_null(PokeCoopTransport.decode(var_to_bytes([1, 2])), "only a Dictionary is a message")
	var oversized := PackedByteArray()
	oversized.resize(PokeCoopTransport.MAX_PACKET_BYTES + 1)
	assert_null(PokeCoopTransport.decode(oversized), "too large to trust")


func test_a_story_flag_set_in_one_window_reaches_the_other() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var blue: PokeCoopWorldLink = _window(_blue)

	red.state.set_event_flag(BEAT_LEADER)
	_pump()

	assert_true(blue.state.is_event_flag_active(BEAT_LEADER))
	assert_true(_host.campaign.has_flag(BEAT_LEADER))


func test_flags_set_in_both_windows_at_once_both_survive() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var blue: PokeCoopWorldLink = _window(_blue)

	red.state.set_event_flag(1)
	blue.state.set_event_flag(2)
	_pump()

	for link: PokeCoopWorldLink in [red, blue]:
		assert_true(link.state.is_event_flag_active(1) and link.state.is_event_flag_active(2))


func test_a_window_opened_late_takes_the_campaign_and_overwrites_nothing() -> void:
	_host.campaign.commit("story:early", {"flags": [BEAT_LEADER]})
	_host.broadcast()
	var blue: PokeCoopWorldLink = _window(_blue)
	_pump()

	assert_true(blue.state.is_event_flag_active(BEAT_LEADER), "the window took the flag")
	assert_true(_host.campaign.has_flag(BEAT_LEADER), "and its blank state erased nothing")
	assert_eq(blue.state.money(), PokeCoopPolicy.NEW_PLAYER_MONEY, "the wallet is the player's")


func test_a_bag_change_stays_with_its_own_player() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var blue: PokeCoopWorldLink = _window(_blue)

	red.state.apply_changes({}, {}, {"items": {Fixture.POTION: 2}})
	_pump()

	assert_eq(_host.player(_red.player_id).item_count(Fixture.POTION), 2)
	assert_eq(_host.player(_blue.player_id).item_count(Fixture.POTION), 0)
	assert_eq(blue.state.item_quantity(Fixture.POTION), 0)


const HM01: int = 196
const TM34: int = 234
const EVENT_GOT_TM34: int = 118


func test_a_key_item_one_player_is_given_reaches_every_player_once() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var blue: PokeCoopWorldLink = _window(_blue)

	red.state.apply_changes({}, {}, {"items": {HM01: 1}})
	_pump()
	red.state.apply_changes({}, {}, {"items": {Fixture.POTION: 1}})
	_pump()

	assert_eq(blue.state.item_quantity(HM01), 1, "the captain's HM01 is Blue's too")
	assert_eq(red.state.item_quantity(HM01), 1, "and Red keeps one, not two")
	assert_eq(_host.player(_blue.player_id).item_count(Fixture.POTION), 0, "a potion is not a story gift")


func test_a_gym_leaders_tm_reaches_the_player_who_was_not_there() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var blue: PokeCoopWorldLink = _window(_blue)

	red.state.set_event_flag(EVENT_GOT_TM34)
	red.state.apply_changes({}, {}, {"items": {TM34: 1}})
	_pump()

	assert_eq(blue.state.item_quantity(TM34), 1)
	assert_eq(red.state.item_quantity(TM34), 1)


func test_a_late_joiner_is_handed_the_gifts_given_before_and_a_full_bag_spills_to_the_pc() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	red.state.apply_changes({}, {}, {"items": {HM01: 1}})
	_pump()
	var blue: PokeCoopPlayer = _host.player(_blue.player_id)
	for item: int in range(10, 10 + Gen1Layout.BAG_ITEM_CAPACITY):
		blue.give_item(item)
	blue.items.erase(HM01)
	red.state.set_event_flag(EVENT_GOT_TM34)
	_pump()
	assert_eq(int((blue.world["pc_items"] as Dictionary).get(TM34, 0)), 1, "a full bag sends the gift to the PC")

	_host.allow_new_players = true
	var link := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, link, 3)
	var green: PokeCoopClient = PokeCoopClient.over(link)
	green.greet("GREEN", _data.id, _data.sha1, "", Fixture.CHARMANDER)
	_clients.append(green)
	_pump()

	var player: PokeCoopPlayer = _host.player(green.player_id)
	assert_eq([player.item_count(HM01), player.item_count(TM34)], [1, 1])


func test_a_badge_won_in_a_battle_reaches_both_windows() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var blue: PokeCoopWorldLink = _window(_blue)
	_send(func() -> void: _red.start_battle("trainer:leader"))
	_fight_out(_battle_of(_red))

	var boulder: int = Gen2WorldState.gen1_badge_flag(0)
	assert_true(red.state.is_engine_flag_active(boulder))
	assert_true(blue.state.is_engine_flag_active(boulder))
	assert_true(blue.state.is_event_flag_active(BEAT_LEADER))


func test_battle_results_come_back_into_the_window_party() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var before: int = red.save.party[0].exp
	_send(func() -> void: _red.start_battle("wild:weak"))
	_fight_out(_battle_of(_red))

	assert_gt(red.save.party[0].exp, before)
	assert_eq(red.save.party[0].exp, _host.player(_red.player_id).team[0]["mon"].exp)


func test_a_heal_and_a_deposit_made_in_a_window_reach_the_host() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var player: PokeCoopPlayer = _host.player(_red.player_id)
	var bench_uid: String = String(player.team[1]["uid"])

	red.save.party[0].hp = 1
	red.save.current_box = 3
	(red.save.boxes[3] as Gen2SaveBox).put(red.save.party.pop_at(1))
	_settle()

	assert_eq(player.team.size(), 1)
	assert_eq(player.team[0]["mon"].hp, 1)
	assert_eq(String(player.box[0]["uid"]), bench_uid, "the deposited Pokémon kept its uid")
	assert_eq(int(player.box[0]["box"]), 3, "in the box it was put in")


func _settle() -> void:
	for _wait: int in PokeCoopWorldLink.PARTY_CHECK_FRAMES:
		_pump()


func test_a_window_save_passes_the_games_own_checks_so_its_services_work() -> void:
	var red: PokeCoopWorldLink = _window(_red)

	assert_true(bool(Gen2SaveValidator.validate(red.save, _data)["ok"]))
	var deposited: Dictionary = Gen2SaveStorage.deposit_party_to_box(red.save, _data, 1, 0, -1, false)
	assert_true(bool(deposited["ok"]), "Bill's PC takes the deposit")
	_settle()
	assert_eq(_host.player(_red.player_id).box.size(), 1)


func test_a_window_opened_later_finds_its_pc_as_it_left_it() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	red.save.current_box = 3
	(red.save.boxes[3] as Gen2SaveBox).put(red.save.party.pop_at(1))
	_settle()

	var again: PokeCoopWorldLink = _window(_red)

	assert_eq(again.save.party.size(), 1)
	assert_eq((again.save.boxes[3] as Gen2SaveBox).occupied_count(), 1)
	assert_eq((again.save.boxes[3] as Gen2SaveBox).slots[0].species, Fixture.PIKACHU)
	assert_eq(again.save.current_box, 3)


func test_a_pokemon_released_from_the_pc_is_gone_for_good() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	(red.save.boxes[0] as Gen2SaveBox).put(red.save.party.pop_at(1))
	_settle()
	(red.save.boxes[0] as Gen2SaveBox).take(0)
	_settle()

	var player: PokeCoopPlayer = _host.player(_red.player_id)
	assert_eq(player.team.size(), 1)
	assert_eq(player.box.size(), 0, "released, not kept back")


func test_a_catch_for_a_full_team_lands_in_the_window_pc() -> void:
	var blue_window: PokeCoopWorldLink = _window(_blue)
	var blue: PokeCoopPlayer = _host.player(_blue.player_id)
	for _extra: int in 4:
		blue.add_mon(_saved(Fixture.PIKACHU, 5, [Fixture.TACKLE], 200))
	_pump()
	_host.player(_red.player_id).give_item(Gen2WorldPartyHost.ITEM_MASTER_BALL, 1)
	_send(func() -> void: _red.start_battle("wild:weak"))
	var battle_id: String = _battle_of(_red)
	_send(func() -> void: _blue.join_battle(battle_id))
	_send(func() -> void: _red.act(battle_id, {
		"type": "item", "item": Gen2WorldPartyHost.ITEM_MASTER_BALL, "recipient": _blue.player_id,
	}))

	assert_eq(blue_window.save.party.size(), 6)
	var stored: Gen2SaveBox = blue_window.save.boxes[0]
	assert_eq(stored.occupied_count(), 1, "the catch is in Blue's PC")
	assert_eq(stored.slots[0].species, Fixture.BULBASAUR)


func test_a_pc_change_made_before_the_hosts_latest_is_refused_and_replaced() -> void:
	var blue_window: PokeCoopWorldLink = _window(_blue)
	var blue: PokeCoopPlayer = _host.player(_blue.player_id)
	var stale: int = blue.holdings_rev
	blue.store_mon(_saved(Fixture.GEODUDE, 9, [Fixture.TACKLE], 200))

	var refused: StringName = _host.apply_party(blue, {
		"rows": [], "boxes": [], "current_box": 0, "rev": stale,
	})

	assert_eq(refused, &"outdated")
	assert_eq(blue.team.size(), 2, "nobody was released by a copy that never saw the catch")
	assert_eq(blue.box.size(), 1)
	_host.broadcast()
	_pump()
	assert_eq((blue_window.save.boxes[0] as Gen2SaveBox).occupied_count(), 1, "the window took the host's PC")


## What the world hands a takeover when it opens a battle of its own; a
## [param trainer_class] above zero makes it that class's first trainer.
func _opened_by_world(link: PokeCoopWorldLink, enemy: Gen2Party, trainer_class: int = 0) -> Dictionary:
	var party: Gen2Party = Gen2SaveBattleAdapter.to_battle_party(_data, link.save)
	var battle: Gen2Battle = Gen2Battle.create_parties(
		_data, party, enemy, RandomNumberGenerator.new(), trainer_class > 0
	)
	battle.battle_reward = 50
	return {
		"battle": battle, "player_party": party, "enemy_party": enemy, "data": _data,
		"summary": {
			"battle_kind": &"trainer" if trainer_class > 0 else &"wild",
			"trainer_class": trainer_class, "trainer_index": 0,
		},
	}


func _take_over(client: PokeCoopClient, context: Dictionary, results: Array) -> Node:
	var bridge: Node = PokeCoopBattleTakeover.over(client, _data).create_battle()
	add_child_autofree(bridge)
	bridge.connect("finished", func(result: Dictionary) -> void: results.append(result))
	bridge.call("start", context)
	_pump()
	return bridge


func test_a_battle_the_world_opens_is_fought_on_the_host_and_hands_back_the_party() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var context: Dictionary = _opened_by_world(red, Gen2Party.of(
		Gen2BattleMon.create(_data, Fixture.BULBASAUR, 2, [Fixture.GROWL])
	))
	var results: Array = []
	var bridge: Node = _take_over(_red, context, results)
	var battle_id: String = _battle_of(_red)
	assert_ne(battle_id, "", "the host runs the fight")
	assert_eq((context["battle"] as Gen2Battle).battle_reward, 0, "the host pays, not the world")

	_fight_out(battle_id)
	bridge.call("_process", 0.0)

	assert_eq(results, [{"outcome": &"won"}])
	assert_eq(
		(context["player_party"] as Gen2Party).mons[0].exp,
		_host.player(_red.player_id).team[0]["mon"].exp,
		"the world commits the host's result"
	)


func test_the_world_whites_out_its_own_player_and_the_host_does_not_charge_twice() -> void:
	var blue: PokeCoopWorldLink = _window(_blue)
	var context: Dictionary = _opened_by_world(blue, Gen2Party.of(
		Gen2BattleMon.create(_data, Fixture.GEODUDE, 90, [Fixture.SLASH])
	))
	var results: Array = []
	var bridge: Node = _take_over(_blue, context, results)

	_fight_out(_battle_of(_blue))
	bridge.call("_process", 0.0)

	assert_eq(results, [{"outcome": &"lost"}])
	assert_eq(_host.player(_blue.player_id).money, PokeCoopPolicy.NEW_PLAYER_MONEY)


func test_one_trainer_opened_in_two_windows_is_one_battle_both_fight() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var blue: PokeCoopWorldLink = _window(_blue)
	var leader: Callable = func() -> Gen2Party:
		return Gen2TrainerParty.build(_data, Fixture.GEN1_LEADER, 0)
	var red_results: Array = []
	var blue_results: Array = []
	var red_bridge: Node = _take_over(_red, _opened_by_world(red, leader.call(), Fixture.GEN1_LEADER), red_results)
	var blue_bridge: Node = _take_over(_blue, _opened_by_world(blue, leader.call(), Fixture.GEN1_LEADER), blue_results)

	var battle_id: String = _battle_of(_red)
	assert_eq(_host.battles.size(), 1, "the second window joined instead of starting another")
	assert_true((_blue.battle(battle_id).get("participants", []) as Array).has(_blue.player_id))
	_fight_out(battle_id)
	red_bridge.call("_process", 0.0)
	blue_bridge.call("_process", 0.0)

	assert_eq(red_results, [{"outcome": &"won"}])
	assert_eq(blue_results, [{"outcome": &"won"}])
	var encounter_id: String = "trainer:%d:0" % Fixture.GEN1_LEADER
	assert_eq(_host.campaign.encounter_state(encounter_id), PokeCoopCampaign.ENCOUNTER_DONE)


func test_a_trainer_the_campaign_has_beaten_counts_as_beaten_without_a_fight() -> void:
	var encounter_id: String = "trainer:%d:0" % Fixture.GEN1_LEADER
	_host.campaign.commit("victory:" + encounter_id, {"defeated": [encounter_id]})
	var blue: PokeCoopWorldLink = _window(_blue)
	var results: Array = []
	var bridge: Node = _take_over(_blue, _opened_by_world(
		blue, Gen2TrainerParty.build(_data, Fixture.GEN1_LEADER, 0), Fixture.GEN1_LEADER
	), results)
	bridge.call("_process", 0.0)

	assert_eq(results, [{"outcome": &"won"}])
	assert_true(_host.battles.is_empty())


func test_the_worlds_own_save_asks_for_a_campaign_checkpoint() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	red.save.world = Gen2WorldSnapshot.new()
	_pump()

	assert_false(PokeCoopSave.read(SAVE_PATH).is_empty())


func test_shutting_the_host_down_ends_the_session_for_every_client() -> void:
	_host.shutdown()
	_pump()
	assert_eq(_red.ended_reason, "host_shutdown")
	assert_eq(_blue.ended_reason, "host_shutdown")
	assert_false(_red.connected)
	assert_true(_host.ended, "closed once both clients had left")


## Both windows' cables as the Cable Club's trade screen drives them.
func _cables() -> Array:
	var cables: Array = []
	for client: PokeCoopClient in [_red, _blue]:
		var cable: PokeCoopLinkTransport = PokeCoopLinkTransport.over(client)
		cable.refresh()
		cables.append(cable)
	return cables


func test_two_players_trade_at_the_cable_club_and_each_pokemon_keeps_its_uid() -> void:
	var red_window: PokeCoopWorldLink = _window(_red)
	var blue_window: PokeCoopWorldLink = _window(_blue)
	var red: PokeCoopPlayer = _host.player(_red.player_id)
	var blue: PokeCoopPlayer = _host.player(_blue.player_id)
	var pikachu_uid: String = String(red.team[1]["uid"])
	var bulbasaur_uid: String = String(blue.team[1]["uid"])
	var cables: Array = _cables()
	assert_true((cables[0] as PokeCoopLinkTransport).connected(), "Blue is on the other end of Red's cable")

	assert_eq(cables[0].choose_trade_slot({"slot": 1}), Gen2LinkTransport.PENDING, "Blue has not chosen")
	_pump()
	cables[1].refresh()
	assert_eq(cables[1].choose_trade_slot({"slot": 1}), Gen2LinkTransport.PENDING)
	_pump()
	assert_eq([cables[0].choose_trade_slot({}), cables[1].choose_trade_slot({})], [1, 1])
	cables[0].answer_trade(true)
	_pump()
	assert_eq(cables[0].trade_answer(), Gen2LinkTransport.PENDING, "Red waits on Blue's answer")
	cables[1].answer_trade(true)
	_pump()

	assert_eq([cables[0].trade_answer(), cables[1].trade_answer()], [1, 1])
	assert_eq(String(red.team[1]["uid"]), bulbasaur_uid, "Red has Blue's Bulbasaur, uid and all")
	assert_eq(String(blue.team[1]["uid"]), pikachu_uid)
	assert_eq(red_window.save.party[1].species, Fixture.BULBASAUR, "Red's window took the host's swap")
	assert_eq(blue_window.save.party[1].species, Fixture.PIKACHU)
	assert_eq(red.team.size() + blue.team.size(), 4, "nobody copied, nobody lost")


func test_a_trade_either_side_cancels_moves_nobody() -> void:
	var red: PokeCoopPlayer = _host.player(_red.player_id)
	var cables: Array = _cables()
	cables[0].choose_trade_slot({"slot": 0})
	cables[1].choose_trade_slot({"slot": 0})
	_pump()
	cables[0].choose_trade_slot({})
	cables[1].choose_trade_slot({})
	cables[0].answer_trade(true)
	cables[1].answer_trade(false)
	_pump()

	assert_eq(cables[0].trade_answer(), 0, "Red's screen hears Blue said no")
	assert_eq(red.team[0]["mon"].species, Fixture.CHARMANDER)


func test_a_pokemon_that_evolves_by_trade_arrives_evolved() -> void:
	(_data.species(Fixture.PIKACHU) as Dictionary)["evolutions"] = [{
		"method": Gen2Layout.EVOLVE_TRADE, "parameter": Gen2Evolution.TRADE_NO_ITEM,
		"condition": 0, "target": Fixture.GEODUDE,
	}]
	var blue: PokeCoopPlayer = _host.player(_blue.player_id)
	var cables: Array = _cables()
	cables[0].choose_trade_slot({"slot": 1})
	cables[1].choose_trade_slot({"slot": 0})
	_pump()
	cables[0].choose_trade_slot({})
	cables[1].choose_trade_slot({})
	cables[0].answer_trade(true)
	cables[1].answer_trade(true)
	_pump()

	assert_eq(blue.team[-1]["mon"].species, Fixture.GEODUDE, "Pikachu evolved on arrival")


func test_the_battle_field_draws_the_hosts_view_and_names_who_was_out() -> void:
	_send(func() -> void: _red.start_battle("wild:stall"))
	var view: Dictionary = _red.battle(_battle_of(_red))

	var scene: Dictionary = PokeCoopBattleField.scene_view(view, _data)
	assert_eq([scene["player_species"], scene["enemy_species"]], [Fixture.CHARMANDER, Fixture.GEODUDE])
	assert_eq([scene["player_hp"], scene["player_max_hp"]], [view["allies"][0]["hp"], view["allies"][0]["max_hp"]])
	var out: Dictionary = PokeCoopBattleField.out_now(view)
	out[Gen2Battle.PLAYER] = PokeCoopBattleField.species_at(view, Gen2Battle.PLAYER, 1)
	var geodude: String = String(_data.species(Fixture.GEODUDE)["name"])
	var pikachu: String = String(_data.species(Fixture.PIKACHU)["name"])
	assert_eq(PokeCoopBattleField.message({"type": Gen2Battle.FAINTED, "side": Gen2Battle.ENEMY}, out, _data),
		"Enemy %s\nfainted!" % geodude)
	assert_eq(PokeCoopBattleField.message({"type": Gen2Battle.SENT_OUT, "side": Gen2Battle.PLAYER}, out, _data),
		"Go! %s!" % pikachu, "the name is whoever was sent out, not who is out at the end")


func test_a_partner_who_never_offers_lets_the_trade_screen_go() -> void:
	var cables: Array = _cables()
	cables[0].offer_wait_msec = 0
	assert_eq(cables[0].choose_trade_slot({"slot": 0}), Gen2LinkTransport.PENDING)
	_pump()

	assert_eq(cables[0].choose_trade_slot({}), -1, "back to the lists, from where CANCEL leaves")
	_pump()
	cables[1].refresh()
	assert_eq(cables[1].choose_trade_slot({"slot": 0}), Gen2LinkTransport.PENDING, "Blue's later offer waits on nobody stale")
	_pump()
	assert_eq(int(_blue.me()["trade"]["partner_slot"]), -1, "Red's offer was withdrawn")


func test_a_partner_stands_in_for_a_controller_who_stays_away() -> void:
	_send(func() -> void: _red.start_battle("wild:stall"))
	var battle_id: String = _battle_of(_red)
	_send(func() -> void: _blue.join_battle(battle_id))
	_host.transport.drop(1)
	_pump()
	var session: PokeCoopBattleSession = _host.battles[battle_id]
	assert_true(session.is_paused(), "paused while Red might come back")

	session.set_absent(_red.player_id, true, Time.get_ticks_msec() - PokeCoopPolicy.STAND_IN_MSEC)
	_pump()

	var view: Dictionary = _blue.battle(battle_id)
	assert_false(bool(view["paused"]))
	assert_eq([String(view["controller"]), String(view["owner"])], [_blue.player_id, _red.player_id],
		"Blue decides for Red's Charmander, which stays Red's")
	var revision: int = int(view["revision"])
	_send(func() -> void: _blue.act(battle_id, {"type": "move", "slot": 0}))
	assert_eq(int(_blue.battle(battle_id)["revision"]), revision + 1, "the battle went on")

	_clients.erase(_red)
	_red = _connect(1, _red.player_id)
	assert_eq(String(_red.battle(battle_id)["controller"]), _red.player_id, "Red has it back")


const FUZZ_TYPES: Array = [
	"move", "start_battle", "window_battle", "command", "suggest", "join", "world", "party",
	"save", "trade", "nonsense",
]
## Real ids and command words, so the fuzz reaches past the first lookup.
const FUZZ_WORDS: Array = [
	"b1", "b2", "p1", "p2", "wild:stall", "trainer:leader", "move", "switch", "item", "send_out",
	"run", "learn", "mimic", "trainer", "wild", "x",
]
const FUZZ_KEYS: Array = [
	"battle", "encounter", "command", "suggestion", "patch", "rows", "boxes", "rev", "current_box",
	"map", "cell", "facing", "warp", "partner", "slot", "answer", "leave", "kind", "enemy",
	"trainer_class", "trainer_index", "type", "value", "revision", "item", "recipient", "index",
]


static func _fuzz_value(rng: RandomNumberGenerator, depth: int = 0) -> Variant:
	match rng.randi_range(0, 9 if depth < 2 else 6):
		0: return null
		1: return rng.randi_range(-3, 300)
		2: return FUZZ_WORDS[rng.randi_range(0, FUZZ_WORDS.size() - 1)]
		3: return rng.randf() < 0.5
		4: return Vector2i(rng.randi_range(-2, 20), rng.randi_range(-2, 20))
		5: return -1
		6: return ""
		7, 8:
			var out: Dictionary = {}
			for _key: int in rng.randi_range(0, 4):
				out[FUZZ_KEYS[rng.randi_range(0, FUZZ_KEYS.size() - 1)]] = _fuzz_value(rng, depth + 1)
			return out
	var items: Array = []
	for _item: int in rng.randi_range(0, 3):
		items.append(_fuzz_value(rng, depth + 1))
	return items


func test_malformed_messages_are_refused_without_breaking_the_host(seed: int = use_parameters([2026, 7, 99])) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_send(func() -> void: _red.start_battle("wild:stall"))
	for round: int in 500:
		var message: Dictionary = {"type": FUZZ_TYPES[rng.randi_range(0, FUZZ_TYPES.size() - 1)]}
		for _key: int in rng.randi_range(0, 5):
			message[FUZZ_KEYS[rng.randi_range(0, FUZZ_KEYS.size() - 1)]] = _fuzz_value(rng)
		var sender: PokeCoopClient = _red if round % 2 == 0 else _blue
		sender.send(message)
		_pump()

	_fuzz_commands(rng)
	_fuzz_hellos(rng)
	_fuzz_holdings(rng)

	assert_eq(_host.players.size(), 2, "nobody was made or lost")
	assert_true(_host.player(_red.player_id).team.size() + _host.player(_blue.player_id).team.size() > 0)


## Commands at the battle's own revision, so their fields are read rather than
## the command turned away as stale.
func _fuzz_commands(rng: RandomNumberGenerator) -> void:
	_send(func() -> void: _red.start_battle("wild:stall"))
	var taken: int = 0
	for _round: int in 300:
		var battle_id: String = _battle_of(_red) if not _battle_of(_red).is_empty() else _battle_of(_blue)
		if battle_id.is_empty():
			_send(func() -> void: _red.start_battle("wild:stall"))
			continue
		var command: Dictionary = {"type": ["move", "switch", "item", "send_out", "run", "learn", "mimic"][rng.randi_range(0, 6)]}
		for _key: int in rng.randi_range(0, 4):
			command[FUZZ_KEYS[rng.randi_range(0, FUZZ_KEYS.size() - 1)]] = _fuzz_value(rng)
		var controller: PokeCoopClient = _controller_of(battle_id)
		if controller == null:
			controller = _red
		var revision: int = int(controller.battle(battle_id).get("revision", 0))
		command["revision"] = revision
		_send(func() -> void: controller.act(battle_id, command))
		taken += 1 if int(controller.battle(battle_id).get("revision", 0)) > revision else 0
	assert_gt(taken, 10, "the fuzz reached the battle itself")


## A hello is a newcomer's first word, so each comes over a link of its own.
func _fuzz_hellos(rng: RandomNumberGenerator) -> void:
	for round: int in 40:
		var link := PokeCoopTransport.new()
		PokeCoopTransport.link(_host.transport, link, 100 + round)
		var hello: Dictionary = {"type": "hello"}
		for key: String in ["protocol", "name", "game_id", "rom_sha1", "player_id", "starter", "save"]:
			if rng.randf() < 0.7:
				hello[key] = _fuzz_value(rng)
		link.send(PokeCoopTransport.HOST_PEER, hello)
		_pump()


## World patches on the real world-state keys, and party and PC rows, in
## shapes a window would never send.
func _fuzz_holdings(rng: RandomNumberGenerator) -> void:
	var keys: Array = PokeCoopOwnership.WORLD_STATE.keys()
	for round: int in 200:
		var sender: PokeCoopClient = _red if round % 2 == 0 else _blue
		var patch: Dictionary = {}
		for _key: int in rng.randi_range(1, 4):
			var change: Variant = {"set": _fuzz_value(rng), "erase": _fuzz_value(rng)} \
				if rng.randf() < 0.6 else {"value": _fuzz_value(rng)}
			patch[keys[rng.randi_range(0, keys.size() - 1)]] = change if rng.randf() < 0.9 else _fuzz_value(rng)
		sender.send({"type": "world", "patch": patch})
		var rows: Array = []
		for _row: int in rng.randi_range(0, 3):
			rows.append({"uid": _fuzz_value(rng), "mon": _fuzz_value(rng), "box": _fuzz_value(rng)})
		var party: Dictionary = {"type": "party", "rows": rows}
		if rng.randf() < 0.5:
			party["rev"] = _host.player(sender.player_id).holdings_rev
			party["boxes"] = rows.duplicate() if rng.randf() < 0.5 else _fuzz_value(rng)
		sender.send(party)
		_pump()


func test_a_change_between_battles_is_written_without_waiting_for_one() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	_host.autosave_msec = 0
	red.state.set_event_flag(BEAT_LEADER)
	_pump()

	var saved: Dictionary = PokeCoopSave.read(SAVE_PATH)
	assert_true((saved.get("campaign", null) as PokeCoopCampaign).has_flag(BEAT_LEADER),
		"the flag a window set is on disk before any battle or SAVE")


func test_red_and_blues_one_off_wild_pokemon_are_one_encounter_each() -> void:
	var snorlax: String = PokeCoopHost._window_encounter(false, 0, 0, 143, Vector2i(0, 23))
	assert_eq(snorlax, "static:143:0:23")
	assert_eq(PokeCoopHost._window_encounter(false, 0, 0, Fixture.PIKACHU, Vector2i(0, 12)), "",
		"a Pokémon met in the grass is no encounter of the campaign's")
	assert_eq(PokeCoopHost._window_encounter(true, 34, 0, 74, Vector2i(0, 54)), "trainer:34:0")


func test_a_unique_wild_pokemon_caught_stays_caught_for_the_campaign() -> void:
	_host.register_encounter("static:test", {
		"species": Fixture.BULBASAUR, "level": 2, "moves": [Fixture.GROWL], "unique": true,
	})
	_host.player(_red.player_id).give_item(Gen2WorldPartyHost.ITEM_MASTER_BALL, 1)
	_send(func() -> void: _red.start_battle("static:test"))
	var battle_id: String = _battle_of(_red)
	_send(func() -> void: _red.act(battle_id, {
		"type": "item", "item": Gen2WorldPartyHost.ITEM_MASTER_BALL, "recipient": _red.player_id,
	}))

	assert_eq(String(_red.battle(battle_id)["outcome"]), "caught")
	assert_eq(_host.campaign.encounter_state("static:test"), PokeCoopCampaign.ENCOUNTER_DONE,
		"a caught legend does not come back")
