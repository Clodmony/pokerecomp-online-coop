extends GutTest

## Co-op battles on Gold's synthetic Generation 2 fixture (#176): held items,
## the pack's pockets, the prize and what the field draws for a joined battle.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const SAVE_PATH: String = "user://coop_johto_battles_test.json"
const NEW_BARK: Vector2i = Vector2i(24, 4)

var _directory: String = ""
var _data: GameData = null
var _host: PokeCoopHost = null
var _clients: Array = []
var _gold: PokeCoopClient = null
var _silver: PokeCoopClient = null


func before_each() -> void:
	_directory = RomCache.directory_for(&"coopjohtobattles", "0123456789abcdef")
	_data = Fixture.build(_directory, String(RomRegistry.GOLD), RomRegistry.GEN2)
	_data.sha1 = RomRegistry.sha1_for(RomRegistry.GOLD)
	_host = PokeCoopHost.create(_data, PokeCoopCampaign.create("gold1", _data.id, _data.sha1), PokeCoopTransport.new())
	_host.save_path = SAVE_PATH
	_host.seeds.seed = 176
	var gold: PokeCoopPlayer = _host.add_player("GOLD", 100)
	gold.place(NEW_BARK, Vector2i(13, 6), 0)
	gold.add_mon(_saved(Fixture.CHARMANDER, 30, [Fixture.TACKLE, Fixture.GROWL], 100))
	var silver: PokeCoopPlayer = _host.add_player("SILVER", 200)
	silver.place(NEW_BARK, Vector2i(12, 6), 0)
	silver.add_mon(_saved(Fixture.PIKACHU, 30, [Fixture.TACKLE], 200))
	_host.register_encounter("wild:stall", {"species": Fixture.GEODUDE, "level": 30, "moves": [Fixture.GROWL]})
	_host.register_encounter("trainer:leader", {"kind": "trainer", "trainer_class": Fixture.GEN1_LEADER, "trainer_index": 0})
	_clients = []
	_gold = _connect(1, gold.player_id)
	_silver = _connect(2, silver.player_id)


func after_each() -> void:
	RomCache.clear(_directory)
	for path: String in [SAVE_PATH, SAVE_PATH + PokeCoopSave.BACKUP_SUFFIX, SAVE_PATH + PokeCoopSave.JOURNAL_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _saved(species: int, level: int, moves: Array, ot: int) -> Gen2SaveMon:
	var out: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(Gen2BattleMon.create(_data, species, level, moves))
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


func _send(callback: Callable) -> void:
	callback.call()
	_pump()


func _battle_of(client: PokeCoopClient) -> String:
	return String(client.current_battle().get("battle", ""))


## Gold's fight, Silver joined and Silver's Pokémon sent out, so Silver decides.
func _joined(encounter: String) -> String:
	_send(func() -> void: _gold.start_battle(encounter))
	var battle_id: String = _battle_of(_gold)
	_send(func() -> void: _silver.join_battle(battle_id))
	_send(func() -> void: _gold.act(battle_id, {"type": "switch", "index": 1}))
	return battle_id


func _fight_out(battle_id: String) -> void:
	for _turn: int in 80:
		var view: Dictionary = _gold.battle(battle_id)
		if String(view.get("outcome", "")) != "":
			return
		var controller: PokeCoopClient = _gold if _gold.is_controller(battle_id) else _silver
		if String(view["phase"]) == String(PokeCoopBattleSession.AWAITING_SEND_OUT):
			var standing: Array = (view["allies"] as Array).filter(func(ally: Dictionary) -> bool: return int(ally["hp"]) > 0)
			controller.act(battle_id, {"type": "send_out", "index": int(standing[0]["index"])})
		else:
			controller.act(battle_id, {"type": "move", "slot": 0})
		_pump()


func _ally(view: Dictionary, owner: String) -> Dictionary:
	return (view["allies"] as Array).filter(func(ally: Dictionary) -> bool: return String(ally["owner"]) == owner)[0]


func test_a_partners_held_berry_heals_in_a_joined_battle_and_stays_eaten() -> void:
	var pikachu: Gen2SaveMon = _host.player(_silver.player_id).team[0]["mon"]
	pikachu.item = Fixture.BERRY_ITEM
	pikachu.hp = 5
	_send(func() -> void: _gold.start_battle("wild:stall"))
	var battle_id: String = _battle_of(_gold)
	_send(func() -> void: _silver.join_battle(battle_id))
	assert_eq(int(_ally(_gold.battle(battle_id), _silver.player_id)["item"]), Fixture.BERRY_ITEM, "the party list shows it held")

	_send(func() -> void: _gold.act(battle_id, {"type": "switch", "index": 1}))
	var view: Dictionary = _gold.battle(battle_id)
	assert_true((view["events"] as Array).any(func(event: Dictionary) -> bool:
		return StringName(event["type"]) == Gen2Battle.RECOVERED_USING_ITEM), "the BERRY works for SILVER's PIKACHU")
	assert_eq(int(_ally(view, _silver.player_id)["hp"]), 15)
	assert_eq(int(_ally(view, _silver.player_id)["item"]), 0)

	_fight_out(battle_id)
	var after: Gen2SaveMon = _host.player(_silver.player_id).team[0]["mon"]
	assert_eq(after.item, 0, "an eaten BERRY is gone from SILVER's own record, as on the cartridge")


func test_a_partner_uses_a_potion_from_their_items_pocket_on_their_own_pokemon() -> void:
	var silver: PokeCoopPlayer = _host.player(_silver.player_id)
	(silver.team[0]["mon"] as Gen2SaveMon).hp = 10
	silver.give_item(Fixture.POTION, 2)
	silver.give_item(Fixture.KEY_ITEMS[0], 1)
	var battle_id: String = _joined("wild:stall")
	assert_true(_silver.is_controller(battle_id))

	var panel: PokeCoopBattlePanel = add_child_autofree(PokeCoopBattlePanel.over(_silver, _data))
	var used: Array = panel._item_rows(_silver.battle(battle_id)).map(func(row: Dictionary) -> int: return int(row["command"]["item"]))
	assert_eq(used, [Fixture.POTION], "a key item is not used in a battle")
	_send(func() -> void: _silver.act(battle_id, {"type": "item", "item": Fixture.POTION, "target": 1}))
	assert_eq(_silver.last_rejection(), &"")
	assert_eq(silver.item_count(Fixture.POTION), 1, "the POTION comes out of SILVER's own pack")
	assert_eq(int(_ally(_gold.battle(battle_id), _silver.player_id)["hp"]), 30)


func test_the_pack_lists_the_pockets_and_left_and_right_turn_them() -> void:
	var silver: PokeCoopPlayer = _host.player(_silver.player_id)
	silver.give_item(Fixture.POTION, 2)
	silver.give_item(Fixture.POKE_BALL, 3)
	var battle_id: String = _joined("wild:stall")
	var panel: PokeCoopBattlePanel = add_child_autofree(PokeCoopBattlePanel.over(_silver, _data))
	panel._process(0.0)
	var menu: PokeCoopBattleMenu = panel.menu
	menu.cursor = PokeCoopBattleMenu.ITEM
	menu.press(PokeButton.A)
	assert_eq(menu.page, PokeCoopBattleMenu.BAG)
	assert_eq(menu.pocket(), Gen2WorldPack.TYPE_ITEM, "BattlePack opens on the ITEMS pocket")
	assert_eq(menu._entries().map(func(entry: Dictionary) -> int: return int(entry["item"])), [Fixture.POTION])
	menu.press(PokeButton.RIGHT)
	assert_eq(menu.pocket(), Gen2WorldPack.TYPE_BALL)
	assert_eq(menu._entries().map(func(entry: Dictionary) -> int: return int(entry["item"])), [Fixture.POKE_BALL])
	menu.press(PokeButton.LEFT)
	menu.press(PokeButton.LEFT)
	assert_eq(menu.pocket(), Gen2WorldPack.TYPE_TM_HM, "the cycle wraps, as `.ItemsPocketMenu`'s does")
	assert_not_null(menu.image())
	assert_true(menu.point_at(menu._rows.find_custom(func(row: Dictionary) -> bool:
		return int((row.get("command", {}) as Dictionary).get("item", 0)) == Fixture.POKE_BALL)), "a scripted press finds a ball's pocket")
	assert_eq(menu.pocket(), Gen2WorldPack.TYPE_BALL)


func test_the_party_list_shows_each_pokemons_held_item() -> void:
	(_host.player(_silver.player_id).team[0]["mon"] as Gen2SaveMon).item = Fixture.BERRY_ITEM
	var battle_id: String = _joined("wild:stall")
	var panel: PokeCoopBattlePanel = add_child_autofree(PokeCoopBattlePanel.over(_gold, _data))
	var rows: Array = (_gold.battle(battle_id)["allies"] as Array).map(panel.menu._party_row)
	assert_eq(rows.map(func(row: Dictionary) -> int: return int(row["item"])), [0, Fixture.BERRY_ITEM])


func test_a_won_trainer_battle_pays_every_participant_the_cartridges_whole_prize() -> void:
	var before: Array = [_host.player(_gold.player_id).money, _host.player(_silver.player_id).money]
	var battle_id: String = _joined("trainer:leader")
	var quarter: int = 99 * 14
	_fight_out(battle_id)
	assert_eq(String(_gold.battle(battle_id).get("outcome", "")), "won")
	assert_eq([_host.player(_gold.player_id).money - int(before[0]), _host.player(_silver.player_id).money - int(before[1])],
		[quarter * 4, quarter * 4], "`BattleWon.give_money` pays four quarters to each (D61)")


func test_an_amulet_coin_doubles_the_prize_of_its_holders_player_only() -> void:
	(_host.player(_silver.player_id).team[0]["mon"] as Gen2SaveMon).item = Fixture.AMULET_COIN
	var before: Array = [_host.player(_gold.player_id).money, _host.player(_silver.player_id).money]
	var battle_id: String = _joined("trainer:leader")
	var quarter: int = 99 * 14
	_fight_out(battle_id)
	assert_eq([_host.player(_gold.player_id).money - int(before[0]), _host.player(_silver.player_id).money - int(before[1])],
		[quarter * 4, quarter * 8], "the coin SILVER's PIKACHU carried in pays SILVER double (D134)")


func test_the_field_draws_gender_shininess_and_the_exp_bar() -> void:
	var pikachu: Gen2SaveMon = _host.player(_silver.player_id).team[0]["mon"]
	pikachu.dvs = Gen2Stats.SHINY_DVS
	var battle_id: String = _joined("wild:stall")
	var view: Dictionary = _gold.battle(battle_id)
	var scene: Dictionary = PokeCoopBattleField.scene_view(view, _data)

	assert_true(bool(scene["player_shiny"]), "SILVER's shiny PIKACHU is out")
	assert_false(bool(scene["enemy_shiny"]))
	assert_eq(StringName(scene["player_gender"]), Gen2BattleMon.gender_for(_data, Fixture.PIKACHU, Gen2Stats.SHINY_DVS))
	assert_ne(StringName(scene["enemy_gender"]), &"")
	var ally: Dictionary = _ally(view, _silver.player_id)
	assert_eq(int(scene["exp_pixels"]), Gen2ExpBarAnimation.pixels_for(
		int(_data.species(Fixture.PIKACHU).get("growth_rate", Gen2Experience.GROWTH_MEDIUM_FAST)), int(ally["level"]), int(ally["exp"])))
	assert_eq(PokeCoopBattleStage.backpic(_data), "chris", "Gold's player turns their back, not RED")


func test_the_field_plays_gold_and_silvers_send_out_toss_and_trainer_lines() -> void:
	var steps: Array = PokeCoopBattleField.send_out_steps(Gen2Battle.PLAYER, _data, true)
	assert_eq(steps.map(func(step: Dictionary) -> Variant: return step.get("param", step.get("stage"))),
		[Gen2Battle.SEND_OUT_ANIM_NORMAL, Gen2Battle.SEND_OUT_ANIM_SHINY, PokeCoopBattleStage.APPEAR],
		"`ANIM_SEND_OUT_MON`, its shiny pass, then the panel; no Generation 1 poof")
	var toss: Array = PokeCoopBattleField.toss_steps({"ball": Fixture.POKE_BALL, "wobbles": 2, "caught": false}, _data)
	assert_eq([int(toss[0]["anim"]), toss[0]["wobbles"]], [Gen2BattleScreen.ANIM_THROW_POKE_BALL,
		[Gen2BattleAnimScript.WOBBLE_NEXT, Gen2BattleAnimScript.WOBBLE_NEXT, Gen2BattleAnimScript.WOBBLE_ESCAPED]])

	_send(func() -> void: _gold.start_battle("trainer:leader"))
	var view: Dictionary = _gold.battle(_battle_of(_gold))
	var field: PokeCoopBattleField = add_child_autofree(PokeCoopBattleField.over(autofree(PokeCoopBattlePanel.over(_gold, _data)), _data))
	field._open(view)
	var lines: Array = field._messages.map(func(step: Dictionary) -> String: return String(step.get("text", "")))
	assert_has(lines, "LEADER\nwants to battle!", "`WantsToBattleText`, not Red and Blue's \"wants to fight\"")
	assert_true(field._messages.any(func(step: Dictionary) -> bool: return step.get("stage") == PokeCoopBattleStage.APPEAR))
