extends GutTest

## Three players on one host over the in-memory transport: every partner's
## suggestion reaches the controller, the Cable Club pairs players by the room
## they stand in, and a third team joins a battle with what still fits.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const SAVE_PATH: String = "user://coop_three_players_test.json"
const PALLET: Vector2i = Vector2i(0, 0)
const TRADE_CENTER: Vector2i = Vector2i(0, Gen1Layout.TRADE_CENTER)

var _directory: String = ""
var _data: GameData = null
var _host: PokeCoopHost = null
var _clients: Array = []
var _red: PokeCoopClient = null
var _blue: PokeCoopClient = null
var _green: PokeCoopClient = null


func before_each() -> void:
	_directory = RomCache.directory_for(&"coopthreeplayerstest", "0123456789abcdef")
	_data = Fixture.build(_directory, "testgame", RomRegistry.GEN1)
	_host = PokeCoopHost.create(
		_data, PokeCoopCampaign.create("c3", _data.id, _data.sha1), PokeCoopTransport.new()
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
	var green: PokeCoopPlayer = _host.add_player("GREEN", 300)
	green.place(PALLET, Vector2i(7, 5), 0)
	green.add_mon(_saved(Fixture.PIKACHU, 20, [Fixture.TACKLE], 300))
	green.add_mon(_saved(Fixture.BULBASAUR, 20, [Fixture.TACKLE], 300))
	_host.register_encounter("wild:stall", {"species": Fixture.GEODUDE, "level": 50, "moves": [Fixture.GROWL]})
	_host.register_encounter("wild:weak", {"species": Fixture.BULBASAUR, "level": 2, "moves": [Fixture.GROWL]})
	_host.register_encounter("wild:slasher", {"species": Fixture.GEODUDE, "level": 50, "moves": [Fixture.SLASH]})
	_clients = []
	_red = _connect(1, red.player_id)
	_blue = _connect(2, blue.player_id)
	_green = _connect(3, green.player_id)


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
		_host.poll()
	for client: PokeCoopClient in _clients:
		client.poll()


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


func _fight_out(battle_id: String, slot: int = 0) -> void:
	for _turn: int in 60:
		var controller: PokeCoopClient = _controller_of(battle_id)
		if controller == null:
			return
		var view: Dictionary = controller.battle(battle_id)
		if String(view.get("outcome", "")) != "":
			return
		controller.act(battle_id, {"type": "move", "slot": slot})
		_pump()


## Red's battle with Blue and Green joined, everyone's two Pokémon in one roster.
func _three_way(encounter: String = "wild:stall") -> String:
	_send(func() -> void: _red.start_battle(encounter))
	var battle_id: String = _battle_of(_red)
	_send(func() -> void: _blue.join_battle(battle_id))
	_send(func() -> void: _green.join_battle(battle_id))
	return battle_id


func _panel(client: PokeCoopClient) -> PokeCoopBattlePanel:
	var panel: PokeCoopBattlePanel = add_child_autofree(PokeCoopBattlePanel.over(client, _data))
	panel._process(0.0)
	return panel


func _row(panel: PokeCoopBattlePanel, kind: String, key: String, value: int) -> int:
	for index: int in panel._rows.size():
		var command: Dictionary = (panel._rows[index] as Dictionary).get("command", {})
		if String(command.get("type", "")) == kind and int(command.get(key, -1)) == value:
			return index
	return -1


func _team_of(client: PokeCoopClient) -> Array:
	return (_host.player(client.player_id).team as Array).map(
		func(entry: Dictionary) -> Dictionary: return {"uid": entry["uid"], "mon": (entry["mon"] as Gen2SaveMon).to_dict()})


func test_every_partner_has_their_own_mark_and_line_on_the_controllers_menus() -> void:
	var battle_id: String = _three_way()
	assert_eq((_red.battle(battle_id)["participants"] as Array).size(), 3)
	assert_eq(String(_red.battle(battle_id)["controller"]), _red.player_id)
	_send(func() -> void: _blue.suggest(battle_id, "switch", 2))
	_send(func() -> void: _green.suggest(battle_id, "move", 1))

	var suggestions: Dictionary = _red.battle(battle_id)["suggestions"]
	assert_eq(int(suggestions[_blue.player_id]["value"]), 2, "Blue's is kept")
	assert_eq(int(suggestions[_green.player_id]["value"]), 1, "and Green's beside it")
	var panel: PokeCoopBattlePanel = _panel(_red)
	var menu: PokeCoopBattleMenu = panel.menu
	assert_eq(menu.marks(), {PokeCoopBattleMenu.PKMN: [_blue.player_id], PokeCoopBattleMenu.FIGHT: [_green.player_id]})
	var blue: String = String(_red.state["players"][_blue.player_id]["name"])
	var green: String = String(_red.state["players"][_green.player_id]["name"])
	assert_eq(menu.spelled().map(func(line: Array) -> String: return line[0]), ["%s suggests" % blue, "%s suggests" % green],
		"each partner spelled out by name, in the order they joined")
	assert_eq([menu._glyph([_blue.player_id]), menu._glyph([_green.player_id])], [blue.left(1), green.left(1)],
		"each partner's own initial where only they point")
	menu.press(PokeButton.A)
	assert_eq(menu.marks(), {1: [_green.player_id]}, "Green's move inside FIGHT")

	_send(func() -> void: _green.suggest(battle_id, "switch", 2))
	panel._process(0.0)
	menu.press(PokeButton.B)
	menu.press(PokeButton.RIGHT)
	menu.press(PokeButton.A)
	var at: int = (_red.battle(battle_id)["allies"] as Array).find_custom(func(ally: Dictionary) -> bool: return int(ally["index"]) == 2)
	assert_eq(menu.marks(), {at: [_blue.player_id, _green.player_id]}, "one row, both partners")
	assert_eq(menu._glyph(menu.marks()[at]), PokeCoopBattleMenu.HOLLOW, "and the shared ▷")

	var blue_panel: PokeCoopBattlePanel = _panel(_blue)
	assert_eq(blue_panel.menu.marks(), {PokeCoopBattleMenu.PKMN: [_green.player_id]},
		"a partner sees the other partner's pointer, not their own")
	assert_eq(panel._names_bb([_red.player_id, _blue.player_id, _green.player_id]),
		"%s, %s and %s" % [panel._name_bb(_red.player_id), panel._name_bb(_blue.player_id), panel._name_bb(_green.player_id)],
		"a fourth player's JOIN row")


func test_the_cable_joins_the_two_players_in_the_trade_center() -> void:
	_send(func() -> void: _red.step(TRADE_CENTER, Vector2i(3, 4), 0, true))
	_send(func() -> void: _green.step(TRADE_CENTER, Vector2i(6, 4), 0, true))

	assert_eq(String(_red.me()["trade_partner"]["player_id"]), _green.player_id)
	assert_eq(String(_green.me()["trade_partner"]["player_id"]), _red.player_id)
	assert_false(_blue.me().has("trade_partner"), "outside, and both are taken")

	_send(func() -> void: _blue.step(TRADE_CENTER, Vector2i(4, 4), 0, true))
	assert_eq(String(_red.me()["trade_partner"]["player_id"]), _green.player_id, "a third coming in parts nobody")
	assert_false(_blue.me().has("trade_partner"))

	_send(func() -> void: _green.step(PALLET, Vector2i(7, 5), 0, true))
	assert_eq(String(_red.me()["trade_partner"]["player_id"]), _blue.player_id, "the one left pairs with the newcomer")
	assert_eq(String(_blue.me()["trade_partner"]["player_id"]), _red.player_id)
	assert_false(_green.me().has("trade_partner"))


func test_a_player_outside_is_cabled_to_the_one_waiting_in_the_trade_center() -> void:
	_send(func() -> void: _green.step(TRADE_CENTER, Vector2i(6, 4), 0, true))

	assert_eq(String(_red.me()["trade_partner"]["player_id"]), _green.player_id)
	assert_eq(String(_blue.me()["trade_partner"]["player_id"]), _green.player_id)
	assert_eq(String(_green.me()["trade_partner"]["player_id"]), _red.player_id, "the first other free player, by id")


func test_three_arriving_together_pair_in_id_order() -> void:
	for client: PokeCoopClient in [_green, _blue, _red]:
		_host.player(client.player_id).place(TRADE_CENTER, Vector2i(3, 4), 0)
	_host.broadcast()
	_pump()

	assert_eq(String(_red.me()["trade_partner"]["player_id"]), _blue.player_id)
	assert_eq(String(_blue.me()["trade_partner"]["player_id"]), _red.player_id)
	assert_false(_green.me().has("trade_partner"))


func test_a_trade_in_a_full_trade_center_swaps_only_the_two_who_traded() -> void:
	for client: PokeCoopClient in [_red, _green, _blue]:
		_send(func() -> void: client.step(TRADE_CENTER, Vector2i(3, 4), 0, true))
	var blue_before: Array = _team_of(_blue)
	var pikachu_uid: String = String(_host.player(_red.player_id).team[1]["uid"])
	var bulbasaur_uid: String = String(_host.player(_green.player_id).team[1]["uid"])
	var red_cable: PokeCoopLinkTransport = PokeCoopLinkTransport.over(_red)
	var green_cable: PokeCoopLinkTransport = PokeCoopLinkTransport.over(_green)
	var blue_cable: PokeCoopLinkTransport = PokeCoopLinkTransport.over(_blue)
	for cable: PokeCoopLinkTransport in [red_cable, green_cable, blue_cable]:
		cable.refresh()
	assert_false(blue_cable.connected(), "the third has nobody on the other end")

	assert_eq(red_cable.choose_trade_slot({"slot": 1}), Gen2LinkTransport.PENDING)
	_pump()
	green_cable.refresh()
	assert_eq(green_cable.choose_trade_slot({"slot": 1}), Gen2LinkTransport.PENDING)
	_pump()
	assert_eq([red_cable.choose_trade_slot({}), green_cable.choose_trade_slot({})], [1, 1])
	red_cable.answer_trade(true)
	green_cable.answer_trade(true)
	_pump()

	assert_eq([red_cable.trade_answer(), green_cable.trade_answer()], [1, 1])
	assert_eq(String(_host.player(_red.player_id).team[1]["uid"]), bulbasaur_uid)
	assert_eq(String(_host.player(_green.player_id).team[1]["uid"]), pikachu_uid)
	assert_eq(_team_of(_blue), blue_before, "Blue's team is untouched")


func test_a_third_team_joins_with_the_first_fit_pokemon_that_still_fit() -> void:
	var red: PokeCoopPlayer = _host.player(_red.player_id)
	var blue: PokeCoopPlayer = _host.player(_blue.player_id)
	var green: PokeCoopPlayer = _host.player(_green.player_id)
	for _slot: int in 4:
		red.add_mon(_saved(Fixture.PIKACHU, 20, [Fixture.TACKLE], 100))
		green.add_mon(_saved(Fixture.PIKACHU, 20, [Fixture.TACKLE], 300))
	for _slot: int in 2:
		blue.add_mon(_saved(Fixture.PIKACHU, 20, [Fixture.TACKLE], 200))
	(green.team[0]["mon"] as Gen2SaveMon).hp = 0
	_send(func() -> void: _red.start_battle("wild:weak"))
	var battle_id: String = _battle_of(_red)
	_send(func() -> void: _blue.join_battle(battle_id))
	var green_before: Array = _team_of(_green)
	_send(func() -> void: _green.join_battle(battle_id))

	var session: PokeCoopBattleSession = _host.battles[battle_id]
	var green_rows: Array[int] = [10, 11]
	assert_true(session.participants.has(_green.player_id), "joined, not refused")
	assert_eq(session.roster.indices_of(_green.player_id), green_rows, "two places were left")
	assert_eq([session.roster.uid_at(10), session.roster.uid_at(11)], [green.team[1]["uid"], green.team[2]["uid"]],
		"the first two that can fight, in party order; the fainted lead stays out")
	assert_eq((_green.battle(battle_id)["allies"] as Array).size(), Gen2Party.MAX_ALLIED_SIZE)

	_send(func() -> void: _red.act(battle_id, {"type": "switch", "index": 10}))
	assert_eq(String(_green.battle(battle_id)["controller"]), _green.player_id)
	_fight_out(battle_id)
	assert_eq(String(_green.battle(battle_id)["outcome"]), "won")
	var green_after: Array = _team_of(_green)
	assert_eq(green_after.size(), 6)
	assert_gt(int(green_after[1]["mon"]["exp"]), int(green_before[1]["mon"]["exp"]), "the one Green sent out fought")
	for index: int in [0, 3, 4, 5]:
		assert_eq(green_after[index], green_before[index], "slot %d sat it out untouched" % index)
	assert_eq(blue.team.size(), 4)
	assert_true(green.is_free())


func test_a_team_with_no_room_left_is_refused_and_keeps_exploring() -> void:
	for player: PokeCoopPlayer in [_host.player(_red.player_id), _host.player(_blue.player_id)]:
		for _slot: int in 4:
			player.add_mon(_saved(Fixture.PIKACHU, 20, [Fixture.TACKLE], player.trainer_id))
	_send(func() -> void: _red.start_battle("wild:stall"))
	var battle_id: String = _battle_of(_red)
	_send(func() -> void: _blue.join_battle(battle_id))
	_send(func() -> void: _green.join_battle(battle_id))

	assert_eq(_green.last_rejection(), &"roster_full")
	var green: PokeCoopPlayer = _host.player(_green.player_id)
	assert_true(green.is_free())
	assert_true(green.return_point.is_empty(), "still exploring where Green stood")
	assert_false((_red.battle(battle_id)["participants"] as Array).has(_green.player_id))
	_send(func() -> void: _green.step(PALLET, Vector2i(7, 6), 0))
	assert_eq(green.cell, Vector2i(7, 6))


func test_joins_queued_behind_a_replacement_share_the_room_that_is_left() -> void:
	var red: PokeCoopPlayer = _host.player(_red.player_id)
	var blue: PokeCoopPlayer = _host.player(_blue.player_id)
	var green: PokeCoopPlayer = _host.player(_green.player_id)
	red.team.clear()
	red.add_mon(_saved(Fixture.PIKACHU, 5, [Fixture.GROWL], 100))
	for _slot: int in 5:
		red.add_mon(_saved(Fixture.PIKACHU, 20, [Fixture.TACKLE], 100))
	for _slot: int in 2:
		blue.add_mon(_saved(Fixture.PIKACHU, 20, [Fixture.TACKLE], 200))
	for _slot: int in 4:
		green.add_mon(_saved(Fixture.PIKACHU, 20, [Fixture.TACKLE], 300))
	_send(func() -> void: _red.start_battle("wild:slasher"))
	var battle_id: String = _battle_of(_red)
	for _turn: int in 10:
		if String(_red.battle(battle_id)["phase"]) != String(PokeCoopBattleSession.AWAITING_ACTION):
			break
		_send(func() -> void: _red.act(battle_id, {"type": "move", "slot": 0}))
	assert_eq(String(_red.battle(battle_id)["phase"]), String(PokeCoopBattleSession.AWAITING_SEND_OUT))

	_send(func() -> void: _blue.join_battle(battle_id))
	_send(func() -> void: _green.join_battle(battle_id))
	var session: PokeCoopBattleSession = _host.battles[battle_id]
	var waiting: Array[String] = [_blue.player_id, _green.player_id]
	assert_eq(session.pending_players(), waiting, "both wait for the boundary")

	_send(func() -> void: _red.act(battle_id, {"type": "send_out", "index": 1}))
	var blue_rows: Array[int] = [6, 7, 8, 9]
	var green_rows: Array[int] = [10, 11]
	assert_eq(session.roster.indices_of(_blue.player_id), blue_rows)
	assert_eq(session.roster.indices_of(_green.player_id), green_rows, "Green brings the two Blue left room for")
	assert_eq(session.battle.party(Gen2Battle.PLAYER).size(), Gen2Party.MAX_ALLIED_SIZE)
