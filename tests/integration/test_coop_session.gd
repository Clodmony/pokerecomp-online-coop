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
	var save := Gen2SaveData.new()
	for row: Dictionary in client.me()["party"]:
		save.party.append(Gen2SaveMon.from_dict(row["mon"]))
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
	red.save.party.remove_at(1)
	for _wait: int in PokeCoopWorldLink.PARTY_CHECK_FRAMES:
		_pump()

	assert_eq(player.team.size(), 1)
	assert_eq(player.team[0]["mon"].hp, 1)
	assert_eq(String(player.box[0]["uid"]), bench_uid, "the deposited Pokémon kept its uid")


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
