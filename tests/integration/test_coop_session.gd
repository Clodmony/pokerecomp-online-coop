extends GutTest

## A co-op host and two clients over the in-memory transport, driven only through
## what a client can send: the first co-op slice end to end. The ENet transport
## carries the same packets; `tools/coop_session.gd demo` runs this over sockets.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const SAVE_PATH: String = "user://coop_session_test.json"
const PALLET: Vector2i = Vector2i(0, 0)
const ROUTE_1: Vector2i = Vector2i(0, 12)
const BEAT_LEADER: int = 0x77
const ROUTE_12_SNORLAX_TOGGLE: int = 29

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
	for path: String in [SAVE_PATH, SAVE_PATH + PokeCoopSave.BACKUP_SUFFIX, SAVE_PATH + PokeCoopSave.JOURNAL_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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


func _stand(link: PokeCoopWorldLink, map_id: Vector2i) -> void:
	var map := Gen2WorldMap.new()
	map.number = map_id.y
	link.world = Gen2WorldAPI.new(_data, map, null, Vector2i.ZERO, link.state)


func _first_locks(red: PokeCoopWorldLink, blue: PokeCoopWorldLink) -> Array:
	var shared: Dictionary = _host.campaign.world.get("gen1_bytes", {})
	var lock: String = Gen2WorldAPI.GEN1_FIRST_LOCK
	return [red.state.gen1_byte(lock), blue.state.gen1_byte(lock), int(shared.get(lock, 0))]


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


func test_a_save_from_either_menu_is_confirmed_to_everyone() -> void:
	var red_seen: int = int(_red.state["saved"]["count"])
	var blue_seen: int = int(_blue.state["saved"]["count"])
	assert_eq(PokeCoopBattlePanel.last_saved(_red).begins_with("Saved") or PokeCoopBattlePanel.last_saved(_red) == "Not saved yet.", true)
	_send(func() -> void: _blue.request_save())

	assert_eq(PokeCoopSession.save_news(blue_seen, _blue), "Campaign saved.")
	var blue: String = String(_red.state["players"][_blue.player_id]["name"])
	assert_eq(PokeCoopSession.save_news(red_seen, _red), "%s saved the campaign." % blue)
	assert_eq(PokeCoopBattlePanel.last_saved(_red), "Saved just now.")
	assert_eq(PokeCoopSession.save_news(int(_red.state["saved"]["count"]), _red), "", "said once")


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
	var opened: Dictionary = _opened_by_world(red, leader.call(), Fixture.GEN1_LEADER)
	(opened["summary"] as Dictionary).merge({"trainer_name": "GARY", "win_text": {"text": "I lost!"}, "lone_attack": 1})
	var red_bridge: Node = _take_over(_red, opened, red_results)
	var blue_bridge: Node = _take_over(_blue, _opened_by_world(blue, leader.call(), Fixture.GEN1_LEADER), blue_results)

	var battle_id: String = _battle_of(_red)
	assert_eq(_host.battles.size(), 1, "the second window joined instead of starting another")
	_send(func() -> void: _blue.leave_battle(battle_id))
	assert_eq(_blue.last_rejection(), &"attached", "a window waiting on the trainer stays in the fight")
	assert_true((_blue.battle(battle_id).get("participants", []) as Array).has(_blue.player_id))
	var view: Dictionary = _blue.battle(battle_id)
	assert_eq([view["trainer_name"], view["win_text"], view["gym"]], ["GARY", "I lost!", true],
		"the opening window's names and lines reach the partner")
	_fight_out(battle_id)
	red_bridge.call("_process", 0.0)
	blue_bridge.call("_process", 0.0)

	assert_eq(red_results, [{"outcome": &"won"}])
	assert_eq(blue_results, [{"outcome": &"won"}])
	var prizes: Dictionary = _blue.battle(battle_id)["prizes"]
	assert_eq(prizes.keys().size(), 2, "each player is told their own share")
	assert_eq(int(prizes[_red.player_id]) + int(prizes[_blue.player_id]) + PokeCoopPolicy.NEW_PLAYER_MONEY * 2,
		int(_red.me()["money"]) + int(_blue.me()["money"]))
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
	_settle()
	assert_eq(red.save_seq, -1, "a battle putting back a copy of the last snapshot is no SAVE")

	var saved := Gen2WorldSnapshot.new()
	saved.frame_number = 1234
	red.save.world = saved
	_settle()

	assert_ne(red.save_seq, -1, "a snapshot of the live world is the world's SAVE")
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


func test_a_turns_animations_play_through_on_a_cache_without_them() -> void:
	_send(func() -> void: _red.start_battle("wild:stall"))
	var battle_id: String = _battle_of(_red)
	_send(func() -> void: _red.act(battle_id, {"type": "move", "slot": 0}))
	var view: Dictionary = _red.battle(battle_id)
	assert_true((view["events"] as Array).any(func(event: Dictionary) -> bool:
		return StringName(event["type"]) == Gen2Battle.ANIMATION), "the turn asks for its animations")

	var field: PokeCoopBattleField = add_child_autofree(
		PokeCoopBattleField.over(autofree(PokeCoopBattlePanel.over(_red, _data)), _data))
	field.visible = true
	field._take_events(view)
	assert_true(field.is_playing())
	for frame: int in 3000:
		field._advance_text()
	assert_false(field.is_playing(), "no hit sound or blink is left waiting on an animation never made")


func test_a_thrown_ball_plays_the_cartridges_toss_shakes_and_break_out() -> void:
	var rows: Callable = func(event: Dictionary) -> Array:
		return PokeCoopBattleField.toss_steps(event).map(func(step: Dictionary) -> Array: return [step["anim"], step["shakes"]])
	assert_eq(rows.call({"ball": Gen1Layout.ITEM_POKE_BALL, "wobbles": 0, "caught": false}),
		[[Gen1Layout.ANIM_ID_TOSS, 0], [Gen1Layout.ANIM_ID_POOF, 0]], "missed: the poof and nothing inside")
	assert_eq(rows.call({"ball": Gen1Layout.ITEM_GREAT_BALL, "wobbles": 2, "caught": false}), [
		[Gen1Layout.ANIM_ID_GREATTOSS, 0], [Gen1Layout.ANIM_ID_POOF, 0], [Gen1Layout.ANIM_ID_HIDEPIC, 0],
		[Gen1Layout.ANIM_ID_SHAKE, 2], [Gen1Layout.ANIM_ID_POOF, 0], [Gen1Layout.ANIM_ID_SHOWPIC, 0],
	], "two shakes, then out again")
	assert_eq(rows.call({"ball": Gen1Layout.ITEM_MASTER_BALL, "wobbles": 3, "caught": true}), [
		[Gen1Layout.ANIM_ID_ULTRATOSS, 0], [Gen1Layout.ANIM_ID_POOF, 0], [Gen1Layout.ANIM_ID_HIDEPIC, 0],
		[Gen1Layout.ANIM_ID_SHAKE, 3],
	], "caught: it stays in the ball")


func test_a_trainers_next_pokemon_comes_out_after_the_last_one_has_fainted() -> void:
	var field: PokeCoopBattleField = add_child_autofree(
		PokeCoopBattleField.over(autofree(PokeCoopBattlePanel.over(_red, _data)), _data))
	var view: Dictionary = {
		"battle": "b9", "revision": 3, "trainer": true, "trainer_class": 1, "active": 0,
		"allies": [{"species": Fixture.CHARMANDER, "level": 12, "hp": 30, "max_hp": 34}],
		"enemy": {"species": Fixture.PIKACHU, "level": 14, "hp": 40, "max_hp": 40},
		"enemy_party": [Fixture.GEODUDE, Fixture.PIKACHU],
		"events": [
			{"type": Gen2Battle.FAINTED, "side": Gen2Battle.ENEMY},
			{"type": Gen2Battle.SENT_OUT, "side": Gen2Battle.ENEMY, "index": 1, "species": Fixture.PIKACHU,
				"level": 14, "hp": 40, "max_hp": 40},
			{"type": Gen2Battle.ANIMATION, "index": Gen2Battle.ANIM_SEND_OUT_MON, "enemy_turn": true},
			{"type": Gen2Battle.CRY, "side": Gen2Battle.ENEMY, "species": Fixture.PIKACHU},
		],
	}
	field._take_events(view)

	var kinds: Array = field._messages.map(func(step: Dictionary) -> String: return step.keys()[0])
	assert_eq(kinds, ["stage", "sound", "sound", "text", "enter", "text", "stage", "cry"],
		"the picture sinks and lands before its line, and the next one grows out after the trainer's")
	assert_eq([field._messages[1]["sound"], field._messages[2]["sound"]], [Gen1Sfx.SFX_FAINT_FALL, Gen1Sfx.SFX_FAINT_THUD])
	assert_eq(PokeCoopBattleField.faint_sounds(Gen2Battle.ENEMY, Fixture.GEODUDE, false), [], "a wild faint is silent")
	assert_eq(PokeCoopBattleField.faint_sounds(Gen2Battle.PLAYER, Fixture.CHARMANDER, false), [{"cry": Fixture.CHARMANDER}])
	var trainer: String = _data.trainer_name(1)
	assert_eq(field._messages[5]["text"], "%s sent\nout %s!" % [trainer, _data.species(Fixture.PIKACHU)["name"]])
	assert_eq(PokeCoopBattleField.message({"type": Gen2Battle.WITHDREW, "side": Gen2Battle.PLAYER, "name": "SPARKY",
		"line": 2}, {}, _data), "SPARKY OK!\nCome back!")


func test_a_level_up_shows_on_the_panel_and_a_full_moveset_asks_what_to_forget() -> void:
	var field: PokeCoopBattleField = add_child_autofree(
		PokeCoopBattleField.over(autofree(PokeCoopBattlePanel.over(_red, _data)), _data))
	var view: Dictionary = {
		"battle": "b7", "revision": 2, "active": 0, "controller": _red.player_id,
		"phase": PokeCoopBattleSession.AWAITING_LEARN,
		"allies": [{"species": Fixture.CHARMANDER, "level": 15, "hp": 41, "max_hp": 41}],
		"enemy": {"species": Fixture.GEODUDE, "level": 5, "hp": 0, "max_hp": 20},
		"events": [{"type": Gen2Battle.GREW_LEVEL, "side": Gen2Battle.PLAYER, "index": 0, "name": "CHARMANDER",
			"old_level": 14, "new_level": 15, "new_stats": {"hp": 41}}],
	}
	field._take_events(view)

	assert_eq(field._messages[0], {"grew": 15, "max_hp": 41}, "the panel takes the new level with the line")
	assert_eq(field._waiting_text(view), "Which move should\nbe forgotten?")
	assert_eq(PokeCoopBattleField.pages("CHARMANDER is trying\nto learn LEER!"),
		PackedStringArray(["CHARMANDER is\ntrying", "to learn LEER!"]), "a row wider than the box wraps onto the next")


func test_a_line_the_field_has_no_words_for_is_the_battle_screens_own() -> void:
	_send(func() -> void: _red.start_battle("wild:stall"))
	var battle_id: String = _battle_of(_red)
	_send(func() -> void: _red.act(battle_id, {"type": "move", "slot": 0}))
	var view: Dictionary = _red.battle(battle_id)
	assert_true((view["events"] as Array).any(func(event: Dictionary) -> bool:
		return StringName(event["type"]) == Gen2Battle.STAT_CHANGED), "GROWL lowers a stat")

	var field: PokeCoopBattleField = add_child_autofree(
		PokeCoopBattleField.over(autofree(PokeCoopBattlePanel.over(_red, _data)), _data))
	field._take_events(view)
	var texts: Array = field._messages.filter(func(step: Dictionary) -> bool: return step.has("text")) \
		.map(func(step: Dictionary) -> String: return step["text"])
	var charmander: String = String(_data.species(Fixture.CHARMANDER)["name"])
	assert_true(texts.has("%s's\nATTACK fell!" % charmander), "worded as the single-player screen words it: %s" % [texts])


func test_every_participant_has_seen_the_pokemon_they_fought() -> void:
	_send(func() -> void: _red.start_battle("wild:stall"))
	var battle_id: String = _battle_of(_red)
	_send(func() -> void: _blue.join_battle(battle_id))
	_send(func() -> void: _red.act(battle_id, {"type": "run"}))
	_pump()
	assert_false(_host.battles.has(battle_id), "the battle is over")

	for client: PokeCoopClient in [_red, _blue]:
		var seen: Dictionary = _host.player(client.player_id).world_part().get("seen_species", {})
		assert_true(seen.has(Fixture.GEODUDE), "%s's Pokédex has seen the wild one" % client.player_id)


func test_a_player_hears_when_the_partner_arrives_leaves_or_starts_a_battle() -> void:
	var before: Dictionary = PokeCoopSession.partner_states(_red)
	_send(func() -> void: _blue.start_battle("wild:stall"))
	var blue: String = String(_red.state["players"][_blue.player_id]["name"])
	var geodude: String = String(_data.species(Fixture.GEODUDE)["name"])
	assert_eq(PokeCoopSession.partner_news(before, PokeCoopSession.partner_states(_red), _red, _data),
		"%s is in a battle against wild %s. SELECT to join." % [blue, geodude])

	var gone: Dictionary = {_blue.player_id: {"name": blue, "connected": false, "battle": ""}}
	var back: Dictionary = {_blue.player_id: {"name": blue, "connected": true, "battle": ""}}
	assert_eq(PokeCoopSession.partner_news(back, gone, _red, _data), "%s left the session." % blue)
	assert_eq(PokeCoopSession.partner_news(gone, back, _red, _data), "%s joined the session." % blue)


func test_a_tap_on_a_row_moves_the_cursor_and_a_second_tap_chooses_it() -> void:
	_send(func() -> void: _red.start_battle("wild:stall"))
	var battle_id: String = _battle_of(_red)
	var panel: PokeCoopBattlePanel = add_child_autofree(PokeCoopBattlePanel.over(_red, _data))
	panel._process(0.0)
	var growl: int = panel._rows.find_custom(func(row: Dictionary) -> bool: return String(row.get("section", "")) == "FIGHT" \
		and int((row["command"] as Dictionary)["slot"]) == 1)
	assert_gt(growl, 0, "the moves sit under FIGHT")
	assert_string_contains(panel._battle_text(_red.battle(battle_id)), "[url=%d]" % growl)

	panel._on_row_clicked(str(growl))
	assert_eq(panel._cursor, growl, "the first tap only moves the cursor")
	var revision: int = int(_red.battle(battle_id)["revision"])
	panel._on_row_clicked(str(growl))
	_pump()
	assert_eq(int(_red.battle(battle_id)["revision"]), revision + 1, "the second tap chooses the move")


func test_review_fixes_for_the_field_and_the_client() -> void:
	var field: PokeCoopBattleField = add_child_autofree(
		PokeCoopBattleField.over(autofree(PokeCoopBattlePanel.over(_red, _data)), _data))
	var pikachu: String = String(_data.species(Fixture.PIKACHU)["name"])
	assert_eq(PokeCoopBattleField.message({"type": Gen2Battle.SENT_OUT, "side": Gen2Battle.PLAYER, "line": 3},
		{Gen2Battle.PLAYER: Fixture.PIKACHU}, _data), "The enemy's weak!\nGet'm! %s!" % pikachu, "the cartridge's own send-out line")

	var view: Dictionary = {"battle": "b5", "revision": 3, "active": 0, "trainer": true, "trainer_class": Gen1Layout.RIVAL3_CLASS,
		"allies": [{"species": Fixture.PIKACHU, "level": 9, "hp": 20, "max_hp": 20}],
		"enemy": {"species": Fixture.GEODUDE, "level": 9, "hp": 0, "max_hp": 20},
		"events": [{"type": Gen2Battle.MISSED, "side": Gen2Battle.ENEMY}]}
	field._take_events(view)
	var queued: int = field._messages.size()
	var fled: Dictionary = view.duplicate()
	fled["outcome"] = "fled"
	field._take_events(fled)
	assert_eq(field._messages.size(), queued, "an outcome on the same turn replays nothing")
	field._queue_victory(view)
	assert_true(field._messages.has({"fanfare": true, "gym": true}), "the champion gets the gym leader's fanfare")

	field._box.visible = true
	var next: Dictionary = view.duplicate()
	next["battle"] = "b6"
	next["events"] = []
	field._take_events(next)
	assert_false(field._box.visible, "a new battle does not open on the last one's line")
	assert_true(field._messages.is_empty())

	var board := PokeCoopBattleStage.new()
	board.reset(_data, true)
	var cleared: PackedByteArray = board.map.duplicate()
	Gen2BattleScreenMap.clear_battler(cleared, false, _data.generation)
	board.enter({"side": Gen2Battle.ENEMY, "species": Fixture.PIKACHU}, _data)
	assert_eq(board.map, cleared, "a trainer's switch empties the square before the next one grows")

	_red._fresh.clear()
	_red._receive({"type": "battle", "view": {"battle": "b8", "revision": 1, "events": [{"type": "a"}]}})
	_red._receive({"type": "battle", "view": {"battle": "b8", "revision": 2, "events": [{"type": "b"}]}})
	assert_eq(_red.battles["b8"]["events"], [{"type": "a"}, {"type": "b"}], "two revisions in one poll keep both turns")


func test_a_battles_last_line_stands_its_hold_before_a_can_close_it() -> void:
	var field: PokeCoopBattleField = add_child_autofree(
		PokeCoopBattleField.over(autofree(PokeCoopBattlePanel.over(_red, _data)), _data))
	field.visible = true
	field._messages.append({"text": "PIDGEY\nfainted!"})
	field._advance_text()
	var frames: int = 0
	while field._box.is_revealing() and frames < 600:
		field._advance_text()
		frames += 1
	assert_true(field.is_playing(), "the line is up, but its hold is not over")
	for frame: int in PokeCoopBattleField.HOLD_FRAMES + 1:
		field._advance_text()
	assert_false(field.is_playing())


func test_a_view_the_field_has_not_played_yet_keeps_a_from_closing_the_battle() -> void:
	_send(func() -> void: _red.start_battle("wild:stall"))
	var panel: PokeCoopBattlePanel = autofree(PokeCoopBattlePanel.over(_red, _data))
	var field: PokeCoopBattleField = add_child_autofree(PokeCoopBattleField.over(panel, _data))
	field.visible = true
	assert_true(field.is_playing(), "the battle's view has come in, but the field has not read it")
	field._take_events(panel.battle_view())
	field._messages.clear()
	assert_false(field.is_playing())


func test_a_trainer_win_closes_with_the_defeat_the_trainers_line_and_the_prize() -> void:
	var field: PokeCoopBattleField = add_child_autofree(
		PokeCoopBattleField.over(autofree(PokeCoopBattlePanel.over(_red, _data)), _data))
	var me: String = String(_red.state["players"][_red.player_id]["name"])
	field._queue_victory({
		"trainer": true, "trainer_name": "GARY", "trainer_class": 1, "gym": true, "prizes": {_red.player_id: 120, "p9": 119},
		"win_text": "I lost!%sOh well.%sNext time." % [Gen2TextStream.PAGE_BREAK, Gen2TextStream.SCROLL_BREAK],
	})

	assert_eq(field._messages, [
		{"fanfare": true, "gym": true}, {"text": "%s defeated\nGARY!" % me},
		{"stage": PokeCoopBattleStage.RESULT, "side": Gen2Battle.ENEMY, "trainer": 1}, {"text": "I lost!\nOh well."},
		{"text": "Next time."}, {"text": "%s got ¥120\nfor winning!" % me},
	])


func test_a_fainted_side_stays_blank_until_its_send_out() -> void:
	var board := PokeCoopBattleStage.new()
	board.reset(_data, true)
	var seeded: PackedByteArray = board.map.duplicate()
	board.begin(PokeCoopBattleStage.FAINT, Gen2Battle.ENEMY)
	while board.busy():
		board.advance()
	assert_true(board.hidden.has(Gen2Battle.ENEMY), "the panel goes with the picture")
	assert_ne(board.map, seeded)
	board.settle({"enemy_hp": 0})
	assert_true(board.hidden.has(Gen2Battle.ENEMY), "a fainted Pokémon is not stamped back")

	board.begin(PokeCoopBattleStage.SEND_OUT, Gen2Battle.ENEMY)
	while board.busy():
		board.advance()
	assert_eq(board.map, seeded, "grown back to the whole picture")
	assert_false(board.hidden.has(Gen2Battle.ENEMY))


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
	assert_eq([bool(_blue.battle(battle_id)["paused"]), bool(_blue.battle(battle_id)["stand_in_due"])], [true, true],
		"Blue is asked, and nothing moves until they answer")
	var panel: PokeCoopBattlePanel = add_child_autofree(PokeCoopBattlePanel.over(_blue, _data))
	panel._process(0.0)
	assert_eq(panel._rows.map(func(row: Dictionary) -> String: return String(row["session"])), ["stand_in", "wait", "leave"])
	panel._choose()
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


func test_a_win_and_a_gift_while_another_battle_runs_survive_a_crash_of_the_host() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	assert_eq(_host.save_checkpoint(), &"")
	_send(func() -> void: _blue.start_battle("wild:stall"))
	_send(func() -> void: _red.start_battle("trainer:leader"))
	_fight_out(_battle_of(_red))
	red.state.apply_changes({}, {}, {"items": {HM01: 1}})
	_pump()
	assert_eq(_host.battles.size(), 1, "Blue's battle holds every checkpoint off")

	var checkpoint: Dictionary = PokeCoopSave.from_dict(JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH)))
	assert_false((checkpoint["campaign"] as PokeCoopCampaign).has_flag(BEAT_LEADER))
	var recovered: Dictionary = PokeCoopSave.read(SAVE_PATH)
	var story: PokeCoopCampaign = recovered["campaign"]
	assert_true(story.has_flag(BEAT_LEADER) and story.has_badge(0), "what a restarted host reads keeps the win")
	assert_eq(story.encounter_state("trainer:leader"), PokeCoopCampaign.ENCOUNTER_DONE)
	var kept: Dictionary = {}
	for member: PokeCoopPlayer in recovered["players"]:
		kept[member.player_id] = member
	assert_eq((kept[_red.player_id] as PokeCoopPlayer).money, _host.player(_red.player_id).money, "with the prize")
	assert_eq((kept[_blue.player_id] as PokeCoopPlayer).item_count(HM01), 1, "and the HM handed to the partner")

	_host.shutdown("host_shutdown", 0)
	assert_false(FileAccess.file_exists(SAVE_PATH + PokeCoopSave.JOURNAL_SUFFIX), "the closing checkpoint takes its place")
	assert_true((PokeCoopSave.read(SAVE_PATH)["campaign"] as PokeCoopCampaign).has_flag(BEAT_LEADER))


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


func test_a_join_still_queued_when_the_battle_ends_is_let_go() -> void:
	_host.register_encounter("wild:hitter", {"species": Fixture.GEODUDE, "level": 50, "moves": [Fixture.TACKLE]})
	_send(func() -> void: _red.start_battle("wild:hitter"))
	var battle_id: String = _battle_of(_red)
	var session: PokeCoopBattleSession = _host.battles[battle_id]
	session.battle.player.hp = 1
	_send(func() -> void: _red.act(battle_id, {"type": "move", "slot": 1}))
	assert_eq(session.phase(), PokeCoopBattleSession.AWAITING_SEND_OUT, "Charmander fainted")
	_send(func() -> void: _blue.join_battle(battle_id))
	assert_true(session.pending_players().has(_blue.player_id), "queued behind the send-out")

	_host.transport.drop(1)
	_pump()
	session.set_absent(_red.player_id, true, Time.get_ticks_msec() - PokeCoopPolicy.ABANDON_MSEC)
	_host.poll()
	_pump()

	assert_false(_host.battles.has(battle_id), "nobody was left to fight it")
	assert_true(_host.player(_blue.player_id).is_free(), "Blue is out of a battle that never took them in")
	assert_eq(String(_blue.battle(battle_id).get("outcome", "")), "fled", "and was told it ended")


func test_a_participant_away_when_the_battle_ended_hears_how_on_coming_back() -> void:
	_send(func() -> void: _red.start_battle("wild:weak"))
	var battle_id: String = _battle_of(_red)
	_send(func() -> void: _blue.join_battle(battle_id))
	_host.transport.drop(2)
	_pump()
	_fight_out(battle_id)
	assert_false(_host.battles.has(battle_id), "Red finished it alone")

	_clients.erase(_blue)
	_blue = _connect(2, _blue.player_id)

	assert_eq(String(_blue.battle(battle_id).get("outcome", "")), "won", "Blue's window is told the result")


func test_a_move_offered_on_the_last_knockout_is_asked_before_the_battle_ends() -> void:
	var red: PokeCoopPlayer = _host.player(_red.player_id)
	red.team.clear()
	red.add_mon(_saved(Fixture.GEODUDE, 5, [Fixture.TACKLE, Fixture.EMBER, Fixture.THUNDERBOLT, Fixture.GROWL], 100))
	_host.register_encounter("wild:magcargo", {"species": Fixture.MAGCARGO, "level": 33, "moves": [Fixture.GROWL]})
	_send(func() -> void: _red.start_battle("wild:magcargo"))
	var battle_id: String = _battle_of(_red)
	(_host.battles[battle_id] as PokeCoopBattleSession).battle.enemy.hp = 1
	_send(func() -> void: _red.act(battle_id, {"type": "move", "slot": 0}))

	var view: Dictionary = _red.battle(battle_id)
	assert_eq(String(view["phase"]), String(PokeCoopBattleSession.AWAITING_LEARN))
	assert_eq(String(view["outcome"]), "", "not over while the question stands")
	assert_eq(int((view["learning"] as Dictionary)["move"]), Fixture.SLASH)
	_send(func() -> void: _red.act(battle_id, {"type": "learn", "forget_slot": 1}))

	assert_eq(String(_red.battle(battle_id)["outcome"]), "won")
	assert_true((red.team[0]["mon"] as Gen2SaveMon).moves.has(Fixture.SLASH), "Geodude kept the move it learned")


func test_a_battle_everyone_left_ends_and_stops_holding_up_saves() -> void:
	_send(func() -> void: _red.start_battle("wild:stall"))
	var battle_id: String = _battle_of(_red)
	_host.transport.drop(1)
	_pump()
	var session: PokeCoopBattleSession = _host.battles[battle_id]
	session.set_absent(_red.player_id, true, Time.get_ticks_msec() - PokeCoopPolicy.STAND_IN_MSEC)
	_host.poll()
	assert_true(_host.battles.has(battle_id), "kept for as long as Red's window may still be redialling")
	assert_eq(PokeCoopPolicy.ABANDON_MSEC, PokeCoopSession.RECONNECT_ATTEMPTS * PokeCoopSession.RECONNECT_MSEC)

	session.set_absent(_red.player_id, true, Time.get_ticks_msec() - PokeCoopPolicy.ABANDON_MSEC)
	_host.poll()
	assert_false(_host.battles.has(battle_id))
	assert_true(_host.player(_red.player_id).is_free())
	assert_eq(_host.save_checkpoint(), &"", "a SAVE goes through again")


func test_closing_the_host_ends_a_running_battle_before_saving() -> void:
	_send(func() -> void: _red.start_battle("wild:stall"))
	var battle_id: String = _battle_of(_red)

	_host.shutdown("host_shutdown", 0)

	assert_false(_host.battles.has(battle_id), "no battle is left half fought in the saved campaign")
	assert_true(_host.player(_red.player_id).is_free())
	assert_true(FileAccess.file_exists(SAVE_PATH))


func test_a_deposit_made_while_the_link_was_down_reaches_the_host_once_it_is_back() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var player: PokeCoopPlayer = _host.player(_red.player_id)
	var bench_uid: String = String(player.team[1]["uid"])
	_host.transport.drop(1)
	_pump()
	assert_false(_red.connected)

	(red.save.boxes[0] as Gen2SaveBox).put(red.save.party.pop_at(1))
	_settle()
	red.save.party[0].hp = 1
	_settle()
	PokeCoopTransport.link(_host.transport, _red.transport, 1)
	_settle()

	assert_eq(player.team.size(), 1)
	assert_eq(player.team[0]["mon"].hp, 1, "the heal made after the deposit")
	assert_eq(player.box.size(), 1, "the deposit was neither lost nor copied")
	assert_eq(String(player.box[0]["uid"]), bench_uid)


func test_a_ball_for_a_player_with_no_room_left_is_refused_and_kept() -> void:
	var blue: PokeCoopPlayer = _host.player(_blue.player_id)
	while blue.add_mon(_saved(Fixture.PIKACHU, 5, [Fixture.TACKLE], 200)) != "":
		pass
	while blue.store_mon(_saved(Fixture.PIKACHU, 5, [Fixture.TACKLE], 200)) != "":
		pass
	_host.player(_red.player_id).give_item(Gen2WorldPartyHost.ITEM_MASTER_BALL, 1)
	_send(func() -> void: _red.start_battle("wild:weak"))
	var battle_id: String = _battle_of(_red)
	_send(func() -> void: _blue.join_battle(battle_id))
	_send(func() -> void: _red.act(battle_id, {
		"type": "item", "item": Gen2WorldPartyHost.ITEM_MASTER_BALL, "recipient": _blue.player_id,
	}))

	assert_eq(_red.last_rejection(), &"box_full", "the cartridge will not throw with nowhere to put it")
	assert_eq(_host.player(_red.player_id).item_count(Gen2WorldPartyHost.ITEM_MASTER_BALL), 1, "the ball is kept")


func test_the_move_question_lists_the_learners_own_moves_and_the_new_one() -> void:
	var panel: PokeCoopBattlePanel = PokeCoopBattlePanel.over(_red, _data)
	var view: Dictionary = {
		"active": 0, "learning": {"index": 1, "move": Fixture.SLASH},
		"allies": [
			{"index": 0, "species": Fixture.PIKACHU, "level": 9, "moves": [Fixture.TACKLE]},
			{"index": 1, "species": Fixture.CHARMANDER, "level": 12, "moves": [Fixture.EMBER, Fixture.GROWL]},
		],
	}

	var rows: Array = panel._learn_rows(view)

	var slash: String = String(_data.move(Fixture.SLASH)["name"])
	assert_eq(rows.size(), 3, "the benched learner's two moves and keeping them")
	assert_string_contains(String(rows[0]["text"]), String(_data.move(Fixture.EMBER)["name"]))
	assert_string_contains(String(rows[0]["text"]), slash)
	panel.free()


func _new_player(peer: int, player_name: String, starter: int) -> PokeCoopClient:
	_host.allow_new_players = true
	var link := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, link, peer)
	var client: PokeCoopClient = PokeCoopClient.over(link)
	client.greet(player_name, _data.id, _data.sha1, "", starter)
	_clients.append(client)
	_pump()
	return client


func test_a_player_who_plays_the_opening_has_a_story_of_their_own_until_oaks_lab_is_behind_them() -> void:
	_host.campaign.commit("story:early", {"flags": [BEAT_LEADER]})
	var red: PokeCoopWorldLink = _window(_red)
	var green_client: PokeCoopClient = _new_player(3, "GREEN", PokeCoopPolicy.PLAY_OPENING)
	var green: PokeCoopPlayer = _host.player(green_client.player_id)
	var house: Vector2i = PokeCoopPolicy.OPENING_BEDROOM
	assert_eq([green.team.size(), green.map, green.cell], [0, house, PokeCoopPolicy.OPENING_BEDROOM_CELL], "Oak hands the starter over")
	assert_eq(String(green_client.me()["opening"]["stage"]), PokeCoopPolicy.OPENING_SPEECH)
	var window: PokeCoopWorldLink = _window(green_client)
	assert_false(window.state.is_event_flag_active(BEAT_LEADER), "the campaign's story is not theirs yet")

	_host.player(_red.player_id).place(house, Vector2i(2, 2), 0)
	assert_false(_host.nearby(_host.player(_red.player_id)).has(green.player_id), "nobody is drawn in the house")
	_send(func() -> void: green_client.send({"type": "opening", "rival": "GARY"}))
	assert_eq([String(green.opening["stage"]), _host.campaign.rival_name], [PokeCoopPolicy.OPENING_PLAYING, "GARY"])
	_host.player(_red.player_id).place(PALLET, Vector2i(6, 6), 0)
	_send(func() -> void: green_client.step(PALLET, Vector2i(5, 6), 0, true))
	assert_false(_host.nearby(_host.player(_red.player_id)).has(green.player_id), "nor in Pallet Town during the opening")
	assert_true(_host.nearby(green).is_empty(), "and they see nobody either")

	window.state.set_event_flag(0x100)
	_pump()
	assert_false(_host.campaign.has_flag(0x100), "the opening's story stays the player's")
	assert_false(red.state.is_event_flag_active(0x100))
	window.state.set_event_flag(PokeCoopPolicy.OPENING_DONE_FLAG)
	_send(func() -> void: green_client.step(PokeCoopPolicy.OPENING_LAB, Vector2i(4, 4), 0, true))
	assert_false(green.opening.is_empty(), "still in Oak's lab")
	_send(func() -> void: green_client.step(PALLET, Vector2i(12, 11), 0, true))

	assert_true(green.opening.is_empty(), "the lab is behind them")
	assert_true(_host.nearby(_host.player(_red.player_id)).has(green.player_id), "out of the lab they meet")
	assert_true(window.state.is_event_flag_active(BEAT_LEADER), "the campaign's story is theirs now")
	assert_false(window.state.is_event_flag_active(0x100))
	assert_false(_host.campaign.has_flag(0x100))


func test_the_session_menu_says_a_partner_is_in_the_opening_rather_than_where_they_stand() -> void:
	var green_client: PokeCoopClient = _new_player(3, "GREEN", PokeCoopPolicy.PLAY_OPENING)
	var panel: PokeCoopBattlePanel = autofree(PokeCoopBattlePanel.over(_red, _data))

	var menu: String = panel._menu_text()
	assert_string_contains(menu, "GREEN[/color] (in the opening)", "nobody sees GREEN where the host places them")
	assert_eq(menu.count("(in the opening)"), 1, "BLUE is out exploring")
	_host.player(green_client.player_id).opening = {}
	_host.broadcast()
	_pump()
	assert_false(panel._menu_text().contains("(in the opening)"))


func test_the_rival_fight_of_an_opening_is_the_players_own() -> void:
	var green_client: PokeCoopClient = _new_player(3, "GREEN", PokeCoopPolicy.PLAY_OPENING)
	_host.player(green_client.player_id).add_mon(_saved(Fixture.CHARMANDER, 60, [Fixture.SLASH], 300))
	_host.broadcast()
	var window: PokeCoopWorldLink = _window(green_client)
	var results: Array = []
	var bridge: Node = _take_over(green_client, _opened_by_world(
		window, Gen2TrainerParty.build(_data, Fixture.GEN1_LEADER, 0), Fixture.GEN1_LEADER
	), results)
	var battle_id: String = _battle_of(green_client)

	assert_ne(battle_id, "")
	assert_eq(_host.join_battle(_host.player(_blue.player_id), battle_id), &"private_battle")
	assert_false(_blue.state["battles"].any(func(running: Dictionary) -> bool: return not bool(running["private"])))
	_fight_out(battle_id)
	bridge.call("_process", 0.0)
	assert_eq(results, [{"outcome": &"won"}])
	var encounter_id: String = "trainer:%d:0" % Fixture.GEN1_LEADER
	assert_eq(_host.campaign.encounter_state(encounter_id), PokeCoopCampaign.ENCOUNTER_FREE,
		"the campaign's own fight with that trainer is still to come")


func test_a_player_who_skips_the_opening_is_given_their_starter_in_pallet_town() -> void:
	var green_client: PokeCoopClient = _new_player(3, "GREEN", Fixture.BULBASAUR)

	assert_eq(green_client.me()["opening"], {})
	assert_eq(_host.player(green_client.player_id).team.size(), 1)


func test_the_hosts_echo_of_an_older_change_does_not_rewind_a_newer_one() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	red.state.set_gen1_map_script(0x28, 3)
	red.advance()
	_host.poll()
	red.state.set_gen1_map_script(0x28, 4)
	red.advance()
	_red.poll()
	red.advance()

	assert_eq(red.state.gen1_map_script(0x28), 4, "the host's copy still says 3 when it arrives")
	_pump()
	assert_eq([red.state.gen1_map_script(0x28), int((_host.campaign.world["gen1_map_scripts"] as Dictionary)[0x28])], [4, 4])


func test_an_item_found_along_the_story_reaches_every_player_and_a_purchase_does_not() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var blue: PokeCoopWorldLink = _window(_blue)

	red.state.set_event_flag(0x301)
	red.state.apply_changes({}, {}, {"items": {Fixture.POTION: 3}})
	_pump()
	assert_eq([red.state.item_quantity(Fixture.POTION), blue.state.item_quantity(Fixture.POTION)], [3, 3],
		"the item ball is gone for both, so both have its potions")

	red.state.apply_changes({}, {}, {"items": {Fixture.SMOKE_BALL: 2}})
	_pump()
	assert_gt(red.state.item_quantity(Fixture.SMOKE_BALL), 0)
	assert_eq(blue.state.item_quantity(Fixture.SMOKE_BALL), 0, "an item bought at the Mart stays the buyer's")


func test_a_key_item_the_story_takes_is_taken_from_everyone_but_a_fossil_is_not() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var blue: PokeCoopWorldLink = _window(_blue)
	const PARCEL: int = 0x46
	const DOME_FOSSIL: int = 0x29
	red.state.set_event_flag(0x302)
	red.state.apply_changes({}, {}, {"items": {PARCEL: 1, DOME_FOSSIL: 1}})
	_pump()
	assert_eq([blue.state.item_quantity(PARCEL), blue.state.item_quantity(DOME_FOSSIL)], [1, 1])

	var held: Dictionary = red.state.items().duplicate()
	held.erase(PARCEL)
	held.erase(DOME_FOSSIL)
	red.state.set_event_flag(0x303)
	var restored: Dictionary = red.state.to_dict()
	restored["items"] = held
	red.state.restore_from_dict(restored)
	_pump()

	assert_eq(red.state.item_quantity(PARCEL), 0)
	assert_eq(blue.state.item_quantity(PARCEL), 0, "Oak has the parcel: nobody carries it on")
	assert_eq(blue.state.item_quantity(DOME_FOSSIL), 1, "Blue revives their own fossil")


func test_a_partner_on_the_map_blocks_the_way_like_a_person_does() -> void:
	var world := Gen2WorldAPI.new(_data, Gen2WorldMap.new(), null)
	var actor: PokeCoopRemoteActor = PokeCoopRemoteActor.over(_red)
	actor.set_world(world)
	_red.state["nearby"] = [_blue.player_id]
	(_red.state["players"][_blue.player_id] as Dictionary)["map"] = world.map_id()

	var drawn: Array = actor.sprites()

	assert_eq(drawn.size(), 1)
	assert_true(bool((drawn[0] as Dictionary).get("solid", false)))


const CERULEAN_CITY: int = 3


func test_a_window_opened_again_inside_a_building_leaves_by_its_own_door() -> void:
	var world := Gen2WorldAPI.new(_data, Gen2WorldMap.new(), null)
	world._gen1_last_map = CERULEAN_CITY
	world._gen1_last_blackout_map = CERULEAN_CITY
	var actor: PokeCoopRemoteActor = PokeCoopRemoteActor.over(_red)
	actor.set_world(world)
	actor.advance_frame()
	_pump()
	_send(func() -> void: _red.request_save())
	var saved: Array = (PokeCoopSave.read(SAVE_PATH)["players"] as Array).filter(
		func(player: PokeCoopPlayer) -> bool: return player.player_id == _red.player_id)

	var reopened: Gen2WorldSnapshot = PokeCoopWorldLink.continued_world(_red)

	assert_eq((saved[0] as PokeCoopPlayer).places, {"gen1_last_map": CERULEAN_CITY, "gen1_last_blackout_map": CERULEAN_CITY})
	assert_eq(reopened.gen1_last_map, CERULEAN_CITY, "a LAST_MAP door leads back out to the town it is in")
	assert_eq(reopened.gen1_last_blackout_map, CERULEAN_CITY, "a whiteout still ends at the last Pokémon Center")


func test_a_window_opens_its_world_on_the_campaigns_story_and_its_own_place() -> void:
	_host.campaign.commit("story:early", {"flags": [BEAT_LEADER]})
	_host.broadcast()
	_send(func() -> void: _red.step(PALLET, Vector2i(5, 6), Gen2WorldSprite.FACING_LEFT))

	var opened: Gen2WorldSnapshot = PokeCoopWorldLink.continued_world(_red)

	assert_true(opened.world_state.is_event_flag_active(BEAT_LEADER), "a map's load scripts read the campaign")
	assert_eq(opened.world_state.money(), _host.player(_red.player_id).money, "and the player's own wallet")
	assert_eq([opened.map_id, opened.player_cell, opened.player_facing], [PALLET, Vector2i(5, 6), Gen2WorldSprite.FACING_LEFT])


func test_a_joiner_who_leaves_walks_on_while_their_pokemon_fight_and_keep_what_they_earn() -> void:
	_send(func() -> void: _red.start_battle("wild:weak"))
	var battle_id: String = _battle_of(_red)
	_send(func() -> void: _blue.join_battle(battle_id))
	_send(func() -> void: _red.act(battle_id, {"type": "switch", "index": 2}))
	assert_true(_blue.is_controller(battle_id), "Blue's Charmander is out")
	var blue: PokeCoopPlayer = _host.player(_blue.player_id)
	var exp_before: int = int(blue.team[0]["mon"].exp)

	var panel: PokeCoopBattlePanel = add_child_autofree(PokeCoopBattlePanel.over(_blue, _data))
	panel._process(0.0)
	panel._cursor = panel._rows.size() - 1
	assert_eq(String(panel._rows[panel._cursor]["text"]), "LEAVE BATTLE")
	panel._choose()
	_pump()
	panel._process(0.0)
	assert_false(panel.is_open(), "Blue's world goes on")
	assert_eq(_red.battle(battle_id)["left"], [_blue.player_id])
	assert_true(_red.is_controller(battle_id), "Red decides for the Charmander Blue left behind")
	_send(func() -> void: _blue.step(PALLET, Vector2i(6, 6), 0))
	assert_eq(blue.cell, Vector2i(6, 6), "Blue walks on")
	assert_true(_red.nearby().has(_blue.player_id), "and is seen again")
	_send(func() -> void: _blue.start_battle("wild:stall"))
	assert_eq(_blue.last_rejection(), &"already_in_battle", "Blue's Pokémon are still busy")
	var red_panel: PokeCoopBattlePanel = add_child_autofree(PokeCoopBattlePanel.over(_red, _data))
	red_panel._process(0.0)
	assert_false(red_panel._rows.any(func(row: Dictionary) -> bool: return row.has("session")), "Red's own fight offers no way out")

	_fight_out(battle_id)
	assert_eq(String(_blue.battle(battle_id)["outcome"]), "won")
	assert_gt(int(blue.team[0]["mon"].exp), exp_before, "Blue's Charmander keeps what it earned")
	assert_eq([blue.is_free(), blue.cell], [true, Vector2i(6, 6)], "and Blue stays where they walked")


func test_a_player_who_left_rejoins_from_the_session_menu() -> void:
	_send(func() -> void: _red.start_battle("wild:stall"))
	var battle_id: String = _battle_of(_red)
	_send(func() -> void: _blue.join_battle(battle_id))
	_send(func() -> void: _blue.leave_battle(battle_id))
	_send(func() -> void: _blue.step(PALLET, Vector2i(6, 6), 0))
	var panel: PokeCoopBattlePanel = add_child_autofree(PokeCoopBattlePanel.over(_blue, _data))
	panel._menu_open = true
	panel._process(0.0)
	panel._cursor = panel._rows.find_custom(func(row: Dictionary) -> bool: return String(row["text"]) == "REJOIN %s" % battle_id)
	assert_gt(panel._cursor, -1, "the session menu offers the way back in")

	panel._choose()
	_pump()
	var view: Dictionary = _blue.battle(battle_id)
	assert_eq([view["left"], (view["participants"] as Array).count(_blue.player_id)], [[], 1], "back in, once")
	_send(func() -> void: _blue.step(PALLET, Vector2i(6, 7), 0))
	assert_eq(_blue.last_rejection(), &"in_battle", "and held there again")


func test_every_participant_is_paid_the_whole_prize() -> void:
	_send(func() -> void: _red.start_battle("trainer:leader"))
	var battle_id: String = _battle_of(_red)
	_send(func() -> void: _blue.join_battle(battle_id))
	var reward: int = (_host.battles[battle_id] as PokeCoopBattleSession).battle.battle_reward
	_fight_out(battle_id)

	assert_eq(String(_red.battle(battle_id)["outcome"]), "won")
	assert_gt(reward, 0)
	assert_eq(_red.battle(battle_id)["prizes"], {_red.player_id: reward, _blue.player_id: reward})
	assert_eq([int(_red.me()["money"]), int(_blue.me()["money"])],
		[PokeCoopPolicy.NEW_PLAYER_MONEY + reward, PokeCoopPolicy.NEW_PLAYER_MONEY + reward])


func test_a_fight_the_world_opens_waits_until_the_pokemon_it_left_are_back() -> void:
	_send(func() -> void: _red.start_battle("wild:weak"))
	var battle_id: String = _battle_of(_red)
	_send(func() -> void: _blue.join_battle(battle_id))
	_send(func() -> void: _blue.leave_battle(battle_id))
	var window: PokeCoopWorldLink = _window(_blue)
	var results: Array = []
	var takeover: PokeCoopBattleTakeover = PokeCoopBattleTakeover.over(_blue, _data)
	var bridge: Node = takeover.create_battle()
	add_child_autofree(bridge)
	bridge.connect("finished", func(result: Dictionary) -> void: results.append(result))
	bridge.call("start", _opened_by_world(window, Gen2Party.of(Gen2BattleMon.create(_data, Fixture.BULBASAUR, 2, [Fixture.GROWL]))))
	_pump()
	bridge.call("_process", 0.0)
	assert_eq([_host.battles.size(), takeover.waiting_on], [1, battle_id], "the new fight waits for Blue's Pokémon")

	_fight_out(battle_id)
	bridge.call("_process", 0.0)
	_pump()
	assert_eq(takeover.waiting_on, "")
	var fresh: String = _battle_of(_blue)
	assert_true(fresh != "" and fresh != battle_id, "then it starts on the host")
	_fight_out(fresh)
	bridge.call("_process", 0.0)
	assert_eq(results, [{"outcome": &"won"}])


func test_each_player_is_given_their_own_eevee_and_dojo_pokemon() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var blue: PokeCoopWorldLink = _window(_blue)
	const EEVEE_BALL: int = 0x45
	const GOT_HITMONLEE: int = 0x356
	const DEFEATED_DOJO: int = 0x350
	red.state.set_object_toggled(EEVEE_BALL, true)
	red.state.set_event_flag(GOT_HITMONLEE)
	red.state.set_event_flag(DEFEATED_DOJO)
	_pump()

	assert_true(blue.state.event_flags().has(DEFEATED_DOJO), "the Dojo is beaten for everyone")
	assert_false(blue.state.event_flags().has(GOT_HITMONLEE), "Blue may still take a Hitmon")
	assert_false(blue.state.is_object_toggled(EEVEE_BALL), "and still finds the EEVEE ball")
	assert_true(red.state.is_object_toggled(EEVEE_BALL) and red.state.event_flags().has(GOT_HITMONLEE), "Red keeps theirs")
	_host.save_checkpoint()
	var reloaded: Dictionary = PokeCoopSave.read(SAVE_PATH)
	var red_again: PokeCoopPlayer = (reloaded["players"] as Array).filter(
		func(member: PokeCoopPlayer) -> bool: return member.player_id == _red.player_id)[0]
	assert_eq([(red_again.world["toggled_objects"] as Dictionary).get(EEVEE_BALL), (red_again.world["event_flags"] as Dictionary).get(GOT_HITMONLEE)],
		[true, true], "and Red's are saved with Red")


func test_vermilion_gyms_locks_are_shared_and_a_surf_score_is_its_players_own() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var blue: PokeCoopWorldLink = _window(_blue)
	var surf_low: String = Gen1ScriptNodes.GEN1_SURF_HI_SCORE[0]
	red.state.set_gen1_byte(Gen2WorldAPI.GEN1_FIRST_LOCK, 6)
	red.state.set_gen1_byte(surf_low, 0x34)
	_pump()

	assert_eq(blue.state.gen1_byte(Gen2WorldAPI.GEN1_FIRST_LOCK), 6, "both windows hide the first switch in one can")
	assert_eq(blue.state.gen1_byte(surf_low), 0, "Red's high score is not Blue's")
	assert_eq(_host.save_checkpoint(), &"")
	var reloaded: Dictionary = PokeCoopSave.read(SAVE_PATH)
	_host = PokeCoopHost.create(_data, reloaded["campaign"], PokeCoopTransport.new())
	_host.adopt_players(reloaded["players"])
	_clients = []
	_links = []
	var again: PokeCoopWorldLink = _window(_connect(1, _red.player_id))

	assert_eq([again.state.gen1_byte(Gen2WorldAPI.GEN1_FIRST_LOCK), again.state.gen1_byte(surf_low)], [6, 0x34],
		"a window reopened on the saved campaign finds both")


func test_a_map_script_that_follows_one_players_walk_stays_in_their_window() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var blue: PokeCoopWorldLink = _window(_blue)
	var dock_check: int = PokeCoopOwnership.PLAYER_MAP_SCRIPTS["wVermilionCityCurScript"]
	var oaks_lab: int = 0
	red.state.set_gen1_map_script(dock_check, 4)
	red.state.set_gen1_map_script(oaks_lab, 18)
	_pump()

	assert_eq(blue.state.gen1_map_script(dock_check), 0, "Blue, elsewhere in the city, does not send Red back to the sailor")
	assert_eq(blue.state.gen1_map_script(oaks_lab), 18, "the lab's story step is the campaign's")
	assert_eq(red.state.gen1_map_script(dock_check), 4, "Red walks on past the ticket check")
	assert_eq(_host.save_checkpoint(), &"")
	var reloaded: Dictionary = PokeCoopSave.read(SAVE_PATH)
	_host = PokeCoopHost.create(_data, reloaded["campaign"], PokeCoopTransport.new())
	_host.adopt_players(reloaded["players"])
	_clients = []
	_links = []
	var again: PokeCoopWorldLink = _window(_connect(1, _red.player_id))

	assert_eq([again.state.gen1_map_script(dock_check), again.state.gen1_map_script(oaks_lab)], [4, 18])


func test_a_partners_second_switch_opens_vermilion_gyms_door_in_this_window_too() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var blue: PokeCoopWorldLink = _window(_blue)
	_stand(blue, PokeCoopWorldLink.VERMILION_GYM)
	var door_load: int = 1 << Gen1Layout.MAP_LOADED_2_BIT

	red.state.set_event_flag(Gen1Layout.LOCK_2ND_EVENT)
	_pump()

	assert_true(blue.state.is_event_flag_active(Gen1Layout.LOCK_2ND_EVENT))
	assert_eq(int(blue.world.get("_gen1_map_load_pending")) & door_load, door_load,
		"Blue's world redraws the door as the window that found the switch does")


func test_an_object_a_partners_scene_hid_leaves_this_windows_map_at_once() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var blue: PokeCoopWorldLink = _window(_blue)
	_stand(blue, Vector2i(0, Gen1Layout.ROUTE_12))
	var snorlax := Gen2WorldObject.new()
	snorlax.toggle_index = ROUTE_12_SNORLAX_TOGGLE
	snorlax.active = true
	blue.world.objects.append(snorlax)

	red.state.set_object_toggled(ROUTE_12_SNORLAX_TOGGLE, true)
	_pump()

	assert_true(blue.state.is_object_toggled(ROUTE_12_SNORLAX_TOGGLE))
	assert_false(snorlax.active, "Blue no longer sees, or bumps into, the SNORLAX Red's fight hid")
	assert_null(blue.world.object_at(snorlax.cell))


func test_a_safari_game_is_only_the_players_who_paid_for_it() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var blue: PokeCoopWorldLink = _window(_blue)
	_stand(blue, Vector2i(0, Gen1Layout.ROUTE_12))

	red.state.set_event_flag(Gen1Layout.IN_SAFARI_ZONE_EVENT)
	red.state.set_safari_balls(30)
	_pump()

	assert_false(blue.state.is_event_flag_active(Gen1Layout.IN_SAFARI_ZONE_EVENT),
		"Blue, with no SAFARI BALL, is not in Red's game")
	assert_true(blue.world.dispatch_sight_events().is_empty(), "so no game over sends Blue to the gate")
	assert_false(_host.campaign.has_flag(Gen1Layout.IN_SAFARI_ZONE_EVENT))
	assert_true(_host.player(_red.player_id).world_part().get("event_flags", {}).has(Gen1Layout.IN_SAFARI_ZONE_EVENT))

	red.state.set_event_flag(Gen1Layout.SAFARI_GAME_OVER_EVENT)
	red.state.clear_event_flag(Gen1Layout.IN_SAFARI_ZONE_EVENT)
	_pump()
	assert_false(blue.state.is_event_flag_active(Gen1Layout.SAFARI_GAME_OVER_EVENT), "nor does Red's game end Blue's")


func test_a_partner_entering_vermilion_city_leaves_the_switches_where_someone_searches() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var blue: PokeCoopWorldLink = _window(_blue)
	red.state.set_gen1_byte(Gen2WorldAPI.GEN1_FIRST_LOCK, 6)
	_send(func() -> void: _red.step(PokeCoopWorldLink.VERMILION_GYM, Vector2i(4, 16), 0, true))
	_stand(blue, PokeCoopWorldLink.VERMILION_CITY)
	blue.state.set_gen1_byte(Gen2WorldAPI.GEN1_FIRST_LOCK, 10)
	_pump()

	assert_eq(_first_locks(red, blue), [6, 6, 6], "Blue's arrival rolls no new first switch while Red searches the gym")

	red.state.set_event_flag(Gen1Layout.LOCK_1ST_EVENT)
	_pump()
	red.state.clear_event_flag(Gen1Layout.LOCK_1ST_EVENT)
	red.state.set_gen1_byte(Gen2WorldAPI.GEN1_FIRST_LOCK, 12)
	_pump()

	assert_eq(_first_locks(red, blue), [12, 12, 12], "a wrong second can still hides the first switch anew for both")
	assert_false(blue.state.is_event_flag_active(Gen1Layout.LOCK_1ST_EVENT))


func test_vermilion_city_rolls_a_new_first_lock_while_nobody_else_is_in_the_city_or_gym() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var blue: PokeCoopWorldLink = _window(_blue)
	red.state.set_gen1_byte(Gen2WorldAPI.GEN1_FIRST_LOCK, 6)
	_send(func() -> void: _red.step(PokeCoopWorldLink.VERMILION_GYM, Vector2i(4, 16), 0, true))
	_send(func() -> void: _red.step(PALLET, Vector2i(5, 5), 0, true))
	_stand(blue, PokeCoopWorldLink.VERMILION_CITY)
	blue.state.set_gen1_byte(Gen2WorldAPI.GEN1_FIRST_LOCK, 10)
	_pump()

	assert_eq(_first_locks(red, blue), [10, 10, 10], "with Red gone, Blue's arrival hides the switch afresh, as on the cartridge")


func test_a_gift_two_windows_hand_out_at_once_is_kept_once() -> void:
	var red: PokeCoopPlayer = _host.player(_red.player_id)
	var blue: PokeCoopPlayer = _host.player(_blue.player_id)
	var picked: Dictionary = {"toggled_objects": {"set": {0x30: true}, "erase": []}}
	_host.apply_world(red, picked.merged({"items": {"set": {Fixture.POTION: 1}, "erase": []}}))
	assert_eq(blue.item_count(Fixture.POTION), 1, "Blue is handed Red's find")

	_host.apply_world(blue, picked.merged({"items": {"set": {Fixture.POTION: 2}, "erase": []}}))
	assert_eq(blue.item_count(Fixture.POTION), 1, "Blue's window picked it up as well before it heard; one is kept")
	assert_eq(red.item_count(Fixture.POTION), 1)

	_host.apply_world(blue, picked.merged({
		"items": {"set": {Fixture.POTION: 1, Fixture.SMOKE_BALL: 1}, "erase": []}, "money": {"set": {0: blue.money - 10}, "erase": []},
	}))
	assert_eq(blue.item_count(Fixture.SMOKE_BALL), 1, "a purchase in the same change is not taken back")


func test_a_gift_given_before_its_scripts_flag_still_reaches_every_player() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var blue: PokeCoopWorldLink = _window(_blue)
	const DOME_FOSSIL: int = 0x29
	red.hold_world = true
	red.state.apply_changes({}, {}, {"items": {DOME_FOSSIL: 1}})
	_pump()
	red.state.set_event_flag(0x304)
	_pump()
	assert_eq(_host.player(_red.player_id).item_count(DOME_FOSSIL), 0, "nothing goes out while the script runs")

	red.hold_world = false
	_pump()
	assert_eq([red.state.item_quantity(DOME_FOSSIL), blue.state.item_quantity(DOME_FOSSIL)], [1, 1],
		"the fossil and the flag went out together, so the partner was given one too")


func test_a_window_in_a_script_takes_the_partners_story_once_the_script_ends() -> void:
	var red: PokeCoopWorldLink = _window(_red)
	var blue: PokeCoopWorldLink = _window(_blue)
	red.hold_world = true
	blue.state.set_event_flag(0x305)
	_pump()
	assert_false(red.state.event_flags().has(0x305), "a running script is not changed under it")

	red.hold_world = false
	_pump()
	assert_true(red.state.event_flags().has(0x305))
	red.hold_world = true
	red._held_since = Time.get_ticks_msec() - PokeCoopWorldLink.HOLD_MSEC
	blue.state.set_event_flag(0x306)
	_pump()
	assert_true(red.state.event_flags().has(0x306), "a script that runs on and on holds nothing back")


func test_a_ghost_nobody_can_see_is_left_to_the_windows_own_battle() -> void:
	var takeover: PokeCoopBattleTakeover = PokeCoopBattleTakeover.over(_red, _data)
	var met: Dictionary = {"battle_kind": &"wild"}
	assert_true(takeover.takes_battle(met))
	met["gen1_ghost"] = Gen1Layout.GHOST_UNIDENTIFIED
	assert_false(takeover.takes_battle(met), "a GHOST without the SILPH SCOPE can only be run from, as on the cartridge")
	met["gen1_ghost"] = Gen1Layout.GHOST_UNVEILED
	assert_true(takeover.takes_battle(met), "the SILPH SCOPE's MAROWAK is fought on the host like any other")
