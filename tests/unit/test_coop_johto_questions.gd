extends GutTest

## Gold and Silver's battle questions in a co-op session (#149): Baton Pass,
## SHIFT's offer, Mimic and a move to learn go to the owner of the Pokémon they
## are about, as Red and Blue's do (D121), and a trainer picks its moves as the
## battle screen's does. Fought on the synthetic Generation 2 cache.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const GOLD_ID: int = 100
const SILVER_ID: int = 200

var _directory: String = ""
var _data: GameData = null


func before_each() -> void:
	_directory = RomCache.directory_for(&"coopjohtoquestions", "0123456789abcdef")
	_data = Fixture.build(_directory, String(RomRegistry.GOLD), RomRegistry.GEN2)


func after_each() -> void:
	RomCache.clear(_directory)


func _saved(species: int, level: int, moves: Array, ot: int, item: int = 0) -> Gen2SaveMon:
	var out: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(Gen2BattleMon.create(_data, species, level, moves))
	out.ot_id = ot
	out.item = item
	return out


func _player(id: String, trainer: int, team: Array) -> PokeCoopPlayer:
	var out := PokeCoopPlayer.create(id, id.to_upper(), trainer)
	out.connected = true
	for saved: Gen2SaveMon in team:
		out.add_mon(saved)
	return out


func _gold(moves: Array = [Fixture.TACKLE, Fixture.GROWL], level: int = 20) -> PokeCoopPlayer:
	return _player("gold", GOLD_ID, [_saved(Fixture.PIKACHU, level, moves, GOLD_ID)])


func _silver(team: Array) -> PokeCoopPlayer:
	return _player("silver", SILVER_ID, team)


func _enemy(species: int = Fixture.GEODUDE, level: int = 5, moves: Array = [Fixture.TACKLE]) -> Gen2Party:
	return Gen2Party.of(Gen2BattleMon.create(_data, species, level, moves))


func _act(session: PokeCoopBattleSession, by: PokeCoopPlayer, command: Dictionary) -> Dictionary:
	var sent: Dictionary = command.duplicate()
	sent["revision"] = session.revision
	return session.submit(by, sent)


func _refusal(session: PokeCoopBattleSession, by: PokeCoopPlayer, command: Dictionary) -> StringName:
	return StringName(_act(session, by, command).get("reason", &""))


## Gold's PIKACHU leads; Silver joins and Gold sends out Silver's [param lead].
func _silver_sent_out(lead: Gen2SaveMon, enemy: Gen2Party, encounter: Dictionary = {"id": "wild:test"}) -> PokeCoopBattleSession:
	var gold: PokeCoopPlayer = _gold()
	var session: PokeCoopBattleSession = PokeCoopBattleSession.start(_data, "b1", 1, gold, enemy, encounter)
	session.request_join(_data, _silver([lead]))
	_act(session, gold, {"type": "switch", "index": 1})
	return session


func _client(player_id: String) -> PokeCoopClient:
	var out: PokeCoopClient = PokeCoopClient.over(PokeCoopTransport.new())
	out.player_id = player_id
	return out


func _menu_for(player_id: String, view: Dictionary) -> PokeCoopBattleMenu:
	var menu: PokeCoopBattleMenu = PokeCoopBattleMenu.over(_client(player_id), _data)
	menu.update(view, [])
	return menu


func _row_texts(player_id: String, view: Dictionary) -> Array:
	var panel: PokeCoopBattlePanel = autofree(PokeCoopBattlePanel.over(_client(player_id), _data))
	return panel._battle_rows(view).map(func(row: Dictionary) -> String: return String(row["text"]))


func test_baton_pass_asks_the_passers_owner_and_the_partner_may_suggest_the_receiver() -> void:
	var session: PokeCoopBattleSession = _silver_sent_out(
		_saved(Fixture.CHARMANDER, 20, [Fixture.SWORDS_DANCE, Fixture.BATON_PASS], SILVER_ID), _enemy())
	var gold: PokeCoopPlayer = session._members["gold"]
	var silver: PokeCoopPlayer = session._members["silver"]
	_act(session, silver, {"type": "move", "slot": 0})
	_act(session, silver, {"type": "move", "slot": 1})

	assert_eq([session.phase(), session.controller(), session.battle.awaiting_baton_pass()],
		[PokeCoopBattleSession.AWAITING_SEND_OUT, "silver", Gen2Battle.PLAYER], "Silver's CHARMANDER passed: Silver picks")
	assert_eq(_refusal(session, gold, {"type": "send_out", "index": 0}), &"not_controller")
	assert_eq(session.suggest("gold", {"type": "send_out", "value": 0}), &"", "Gold may suggest the receiver")
	assert_eq(_refusal(session, silver, {"type": "run"}), &"invalid_send_out", "a pass is no place to run")
	assert_eq(_refusal(session, silver, {"type": "send_out", "index": 1}), &"invalid_send_out", "nor to pass to itself")

	assert_true(bool(_act(session, silver, {"type": "send_out", "index": 0})["ok"]))
	assert_eq([session.phase(), session.controller(), session.battle.party(Gen2Battle.PLAYER).active],
		[PokeCoopBattleSession.AWAITING_ACTION, "gold", 0], "Gold's PIKACHU takes the pass and the next turn")
	assert_eq(session.battle.mon(Gen2Battle.PLAYER).stage("attack"), 2, "SWORDS DANCE's two stages came with it")


func test_a_pass_in_the_wild_opens_the_party_with_no_use_next_question() -> void:
	var session: PokeCoopBattleSession = _silver_sent_out(
		_saved(Fixture.CHARMANDER, 20, [Fixture.BATON_PASS], SILVER_ID), _enemy())
	_act(session, session._members["silver"], {"type": "move", "slot": 0})

	var view: Dictionary = session.view()
	assert_false(bool(view.get("use_next", true)), "the view says no \"Use next POKéMON?\" stands")
	assert_eq(_menu_for("silver", view).page, PokeCoopBattleMenu.PARTY, "Silver's window lists the party at once")
	assert_eq(_menu_for("gold", view).page, PokeCoopBattleMenu.PARTY, "Gold's list is for suggesting")
	assert_false(_row_texts("silver", view).has("RUN"), "and no RUN the host would refuse")


func test_a_fainted_pokemon_in_the_wild_still_asks_use_next_first() -> void:
	var session: PokeCoopBattleSession = _silver_sent_out(
		_saved(Fixture.CHARMANDER, 5, [Fixture.GROWL], SILVER_ID), _enemy(Fixture.GEODUDE, 50, [Fixture.SLASH]))
	for _turn: int in 10:
		if session.phase() == PokeCoopBattleSession.AWAITING_SEND_OUT:
			break
		_act(session, session._members["silver"], {"type": "move", "slot": 0})

	var view: Dictionary = session.view()
	assert_eq([String(view["phase"]), bool(view.get("use_next", false))], ["send_out", true])
	assert_eq(_menu_for("silver", view).page, PokeCoopBattleMenu.ASK)
	assert_true(_row_texts("silver", view).has("RUN"), "NO runs from the wild one")


func _falkner(gold_shift: bool, silver_shift: bool) -> PokeCoopBattleSession:
	var gold: PokeCoopPlayer = _gold([Fixture.TACKLE], 30)
	var silver: PokeCoopPlayer = _silver([_saved(Fixture.CHARMANDER, 30, [Fixture.TACKLE], SILVER_ID)])
	gold.battle_shift = gold_shift
	silver.battle_shift = silver_shift
	var enemy := Gen2Party.create([Gen2BattleMon.create(_data, Fixture.GEODUDE, 5, [Fixture.GROWL]),
		Gen2BattleMon.create(_data, Fixture.HOOTHOOT, 5, [Fixture.GROWL])])
	var session: PokeCoopBattleSession = PokeCoopBattleSession.start(_data, "b1", 1, gold, enemy,
		{"id": "trainer:falkner", "trainer_class": Fixture.FALKNER})
	session.request_join(_data, silver)
	_act(session, gold, {"type": "switch", "index": 1})
	session.battle.mon(Gen2Battle.ENEMY).hp = 1
	_act(session, silver, {"type": "move", "slot": 0})
	return session


func test_shift_asks_the_owner_of_the_pokemon_out_by_their_own_setting() -> void:
	assert_eq(_falkner(true, false).phase(), PokeCoopBattleSession.AWAITING_ACTION,
		"Gold's SHIFT does not ask while Silver, on SET, has the Pokémon out")

	var session: PokeCoopBattleSession = _falkner(false, true)
	assert_eq([session.phase(), session.controller(), int(session.view()["offer"])],
		[PokeCoopBattleSession.AWAITING_OFFER, "silver", 1])
	assert_eq(_refusal(session, session._members["gold"], {"type": "stay"}), &"not_controller")
	assert_eq(session.suggest("gold", {"type": "switch", "value": 0}), &"", "Gold may suggest switching to Gold's PIKACHU")
	assert_true(bool(_act(session, session._members["silver"], {"type": "switch", "index": 0})["ok"]))
	assert_eq([session.controller(), session.battle.party(Gen2Battle.ENEMY).active], ["gold", 1])


func test_the_trainers_question_is_worded_as_gold_and_silver_word_it() -> void:
	var line: String = PokeCoopBattleField.message(
		{"type": Gen2Battle.SWITCH_OFFERED, "side": Gen2Battle.PLAYER, "index": 1, "species": Fixture.HOOTHOOT},
		{Gen2Battle.PLAYER: Fixture.PIKACHU, Gen2Battle.ENEMY: Fixture.GEODUDE}, _data, {}, "FALKNER")
	assert_eq(PokeCoopBattleField.pages(line), PackedStringArray([
		"FALKNER\nis about to use", PokeCoopBattleField._species_name(_data, Fixture.HOOTHOOT) + ".",
	]), "`BattleText_EnemyIsAboutToUseWillPlayerChangeMon`, not Red and Blue's words")
	var menu: PokeCoopBattleMenu = PokeCoopBattleMenu.over(PokeCoopClient.over(PokeCoopTransport.new()), _data)
	assert_eq(menu._offer_text(), Gen2BattleSwitchMenu.offer_text("", "", "").get_slice(Gen2TextStream.PAGE_BREAK, 1))


func test_mimic_copies_the_last_move_unasked_and_the_owner_keeps_mimic() -> void:
	var session: PokeCoopBattleSession = _silver_sent_out(
		_saved(Fixture.CHARMANDER, 20, [Fixture.MIMIC, Fixture.TACKLE], SILVER_ID), _enemy(Fixture.GEODUDE, 5, [Fixture.GROWL]))
	var silver: PokeCoopPlayer = session._members["silver"]
	_act(session, silver, {"type": "move", "slot": 1})
	_act(session, silver, {"type": "move", "slot": 0})

	assert_eq([session.phase(), session.controller()], [PokeCoopBattleSession.AWAITING_ACTION, "silver"],
		"Generation 2's MIMIC asks nobody")
	assert_eq(session.battle.mon(Gen2Battle.PLAYER).moves[0], Fixture.GROWL, "it copied the foe's last move")
	var fought: Gen2BattleMon = (session.results()["silver"] as Array)[0]["mon"]
	silver.absorb_battle_mon(String(silver.team[0]["uid"]), fought)
	assert_eq((silver.team[0]["mon"] as Gen2SaveMon).moves.slice(0, 2), [Fixture.MIMIC, Fixture.TACKLE],
		"Silver's CHARMANDER goes home knowing MIMIC")


func test_a_benched_exp_share_holder_learns_by_its_owners_answer_while_the_partners_pokemon_is_out() -> void:
	var gold: PokeCoopPlayer = _gold([Fixture.TACKLE], 30)
	var silver: PokeCoopPlayer = _silver([_saved(Fixture.GEODUDE, 10,
		[Fixture.TACKLE, Fixture.EMBER, Fixture.THUNDERBOLT, Fixture.GROWL], SILVER_ID, Fixture.EXP_SHARE)])
	var session: PokeCoopBattleSession = PokeCoopBattleSession.start(_data, "b1", 1, gold, _enemy(Fixture.MAGCARGO, 33), {"id": "wild:test"})
	session.request_join(_data, silver)
	_act(session, gold, {"type": "move", "slot": 0})
	session.battle.mon(Gen2Battle.ENEMY).hp = 1
	_act(session, gold, {"type": "move", "slot": 0})

	assert_eq([session.phase(), session.owner_deciding(), session.controller()], [PokeCoopBattleSession.AWAITING_LEARN, "silver", "silver"],
		"Silver's GEODUDE, holding EXP.SHARE on the bench, learns while Gold's PIKACHU is out")
	assert_eq(_refusal(session, gold, {"type": "learn", "forget_slot": 1}), &"not_controller")
	assert_eq(session.suggest("gold", {"type": "learn", "value": 1}), &"", "Gold may suggest the move to forget")
	assert_true(bool(_act(session, silver, {"type": "learn", "forget_slot": 1})["ok"]))
	assert_eq(session.battle.party(Gen2Battle.PLAYER).mons[1].moves[1], Fixture.SLASH)


## The enemy's moves over one opening turn per seed against a paralysed PIKACHU, the class scoring with every layer.
func _enemy_moves_used(encounter: Dictionary) -> Dictionary:
	var hard := Gen2Rules.new()
	hard.challenge = Gen2Rules.CHALLENGE_HARD
	var used: Dictionary = {}
	for seed_value: int in 64:
		var gold: PokeCoopPlayer = _gold()
		var enemy: Gen2Party = _enemy(Fixture.GEODUDE, 50, [Fixture.TACKLE, Fixture.THUNDER_WAVE, Fixture.SLEEP_POWDER])
		var session: PokeCoopBattleSession = PokeCoopBattleSession.start(_data, "b1", seed_value, gold, enemy, encounter)
		session.battle.rules = hard
		session.battle.mon(Gen2Battle.PLAYER).status = Gen2Status.PARALYSIS
		for event: Dictionary in _act(session, gold, {"type": "move", "slot": 1}).get("events", []):
			if StringName(event.get("type", &"")) == Gen2Battle.USED_MOVE and int(event.get("side", -1)) == Gen2Battle.ENEMY:
				used[int(event.get("move", 0))] = true
	return used


func test_a_trainer_in_a_session_scores_its_moves_with_the_classs_weights_as_the_screen_does() -> void:
	var wild: Dictionary = _enemy_moves_used({"id": "wild:test"})
	assert_true(wild.has(Fixture.THUNDER_WAVE) or wild.has(Fixture.SLEEP_POWDER), "a wild rolls any usable slot")
	var trainer: Dictionary = _enemy_moves_used({"id": "trainer:falkner", "trainer_class": Fixture.FALKNER})
	assert_eq(trainer.keys(), [Fixture.TACKLE], "`AI_Basic` leaves a status move to a healthy player only")
