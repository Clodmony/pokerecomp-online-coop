extends GutTest

## Co-op battle sessions: who decides, what a suggestion may not touch, when a
## second team joins and whose Pokémon a result lands on. Fought under Generation
## 1 rules on the synthetic cache, which is the Red and Blue path. An enemy that
## only knows Growl keeps a battle open for as long as a test needs it.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const RED_ID: int = 100
const BLUE_ID: int = 200

var _directory: String = ""
var _data: GameData = null


func before_each() -> void:
	_directory = RomCache.directory_for(&"coopbattletest", "0123456789abcdef")
	_data = Fixture.build(_directory, "testgame", RomRegistry.GEN1)


func after_each() -> void:
	RomCache.clear(_directory)


func _saved(species: int, level: int, moves: Array, ot: int) -> Gen2SaveMon:
	var out: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(
		Gen2BattleMon.create(_data, species, level, moves)
	)
	out.ot_id = ot
	return out


func _player(id: String, trainer: int, team: Array) -> PokeCoopPlayer:
	var out := PokeCoopPlayer.create(id, id.to_upper(), trainer)
	out.connected = true
	for saved: Gen2SaveMon in team:
		out.add_mon(saved)
	return out


func _red(team_size: int = 1) -> PokeCoopPlayer:
	var team: Array = []
	for _slot: int in team_size:
		team.append(_saved(Fixture.PIKACHU, 20, [Fixture.GROWL, Fixture.TACKLE], RED_ID))
	return _player("red", RED_ID, team)


func _blue(team_size: int = 1, ot: int = BLUE_ID) -> PokeCoopPlayer:
	var team: Array = []
	for _slot: int in team_size:
		team.append(_saved(Fixture.CHARMANDER, 20, [Fixture.GROWL, Fixture.TACKLE], ot))
	return _player("blue", BLUE_ID, team)


func _enemy(species: int = Fixture.GEODUDE, level: int = 50, moves: Array = [Fixture.GROWL]) -> Gen2Party:
	return Gen2Party.of(Gen2BattleMon.create(_data, species, level, moves))


func _start(lead: PokeCoopPlayer, enemy: Gen2Party, seed_value: int = 1, id: String = "b1") -> PokeCoopBattleSession:
	return PokeCoopBattleSession.start(_data, id, seed_value, lead, enemy, {"id": "wild:test"})


func _act(session: PokeCoopBattleSession, by: PokeCoopPlayer, command: Dictionary) -> Dictionary:
	var sent: Dictionary = command.duplicate()
	sent["revision"] = session.revision
	return session.submit(by, sent)


## Everything a command could move, so a refusal can be shown to have moved none of it.
func _snapshot(session: PokeCoopBattleSession) -> Dictionary:
	return {
		"revision": session.revision, "rng": session.rng.state,
		"active": session.battle.party(Gen2Battle.PLAYER).active,
		"hp": [session.battle.mon(Gen2Battle.PLAYER).hp, session.battle.mon(Gen2Battle.ENEMY).hp],
		"pp": session.battle.mon(Gen2Battle.PLAYER).pp.duplicate(),
		"turn_begun": session.battle.turn_begun(),
	}


func _fight_out(session: PokeCoopBattleSession, players: Dictionary, slot: int = 1) -> void:
	for _turn: int in 40:
		if session.phase() == PokeCoopBattleSession.OVER:
			return
		_act(session, players[session.controller()], {"type": "move", "slot": slot})


func test_two_full_teams_fill_a_roster_of_twelve_and_each_team_stays_at_six() -> void:
	var red: PokeCoopPlayer = _red(6)
	var blue: PokeCoopPlayer = _blue(6)
	var session: PokeCoopBattleSession = _start(red, _enemy())

	assert_eq(session.request_join(_data, blue), &"")

	var blue_rows: Array[int] = [6, 7, 8, 9, 10, 11]
	assert_eq(session.battle.party(Gen2Battle.PLAYER).size(), Gen2Party.MAX_ALLIED_SIZE)
	assert_eq(session.roster.indices_of("blue"), blue_rows)
	assert_eq(red.team.size(), 6)
	assert_eq(blue.team.size(), 6)
	assert_null(Gen2Party.create(session.battle.party(Gen2Battle.PLAYER).mons.slice(0, 7)),
		"one trainer's party is still refused at seven")


func test_the_turn_belongs_to_the_owner_of_the_pokemon_that_is_out() -> void:
	var red: PokeCoopPlayer = _red()
	var blue: PokeCoopPlayer = _blue()
	var session: PokeCoopBattleSession = _start(red, _enemy())
	session.request_join(_data, blue)
	assert_eq(session.controller(), "red")

	var before: Dictionary = _snapshot(session)
	assert_eq(StringName(_act(session, blue, {"type": "move", "slot": 0})["reason"]), &"not_controller")
	assert_eq(_snapshot(session), before, "a refused command moves nothing")

	assert_true(bool(_act(session, red, {"type": "switch", "index": 1})["ok"]))
	assert_eq(session.controller(), "blue", "sending out the partner's Pokémon hands the turn over")
	assert_eq(StringName(_act(session, red, {"type": "move", "slot": 0})["reason"]), &"not_controller")
	assert_true(bool(_act(session, blue, {"type": "move", "slot": 0})["ok"]))


func test_a_command_for_an_old_revision_is_refused() -> void:
	var red: PokeCoopPlayer = _red()
	var session: PokeCoopBattleSession = _start(red, _enemy())
	var command: Dictionary = {"type": "move", "slot": 0, "revision": session.revision}
	assert_true(bool(session.submit(red, command)["ok"]))

	var before: Dictionary = _snapshot(session)
	assert_eq(StringName(session.submit(red, command)["reason"]), &"stale_revision")
	assert_eq(_snapshot(session), before)


func test_a_locked_in_turn_is_taken_with_no_second_command() -> void:
	var red: PokeCoopPlayer = _player("red", RED_ID, [_saved(Fixture.PIKACHU, 20, [Fixture.TACKLE, Fixture.DIG], RED_ID)])
	var session: PokeCoopBattleSession = _start(red, _enemy())
	assert_false(session.advance(), "a free turn waits for its command")
	assert_true(bool(_act(session, red, {"type": "move", "slot": 1})["ok"]))
	assert_true(session.battle.player_menu_skipped(), "dug in")
	var pp: int = session.battle.mon(Gen2Battle.PLAYER).pp[1]
	var revision: int = session.revision
	session.set_absent(red.player_id, true)
	assert_false(session.advance(), "nobody fights a paused battle")
	session.set_absent(red.player_id, false)
	assert_true(session.advance())
	assert_eq(session.revision, revision + 1)
	assert_eq(session.battle.mon(Gen2Battle.PLAYER).charged_move, 0, "DIG came up and hit")
	assert_eq(session.battle.mon(Gen2Battle.PLAYER).pp[1], pp, "the second turn spends no PP")
	assert_false(session.advance(), "and the next turn is asked again")

	var hyper: PokeCoopPlayer = _player("blue", BLUE_ID, [_saved(Fixture.PIKACHU, 20, [Fixture.HYPER_BEAM], BLUE_ID)])
	var recharging: PokeCoopBattleSession = _start(hyper, _enemy(), 1, "b2")
	assert_true(bool(_act(recharging, hyper, {"type": "move", "slot": 0})["ok"]))
	assert_true(recharging.advance(), "HYPER BEAM's recharge takes its turn")
	assert_false(recharging.advance())


func test_a_suggestion_never_acts_and_is_gone_after_the_next_command() -> void:
	var red: PokeCoopPlayer = _red()
	var blue: PokeCoopPlayer = _blue()
	var session: PokeCoopBattleSession = _start(red, _enemy())
	session.request_join(_data, blue)

	var before: Dictionary = _snapshot(session)
	assert_eq(session.suggest("blue", {"type": "switch", "value": 1}), &"")
	assert_eq(_snapshot(session), before, "nothing in the battle moved")
	assert_eq(int((session.view()["suggestions"] as Dictionary)["blue"]["value"]), 1)
	assert_eq(session.suggest("red", {"type": "move", "value": 0}), &"controller_acts")
	assert_eq(session.suggest("green", {"type": "move", "value": 0}), &"not_a_participant")

	_act(session, red, {"type": "move", "slot": 0})
	assert_true(session.suggestions.is_empty())


func test_a_join_asked_during_a_forced_replacement_waits_for_the_turn_boundary() -> void:
	var red: PokeCoopPlayer = _player("red", RED_ID, [
		_saved(Fixture.PIKACHU, 5, [Fixture.GROWL], RED_ID),
		_saved(Fixture.PIKACHU, 5, [Fixture.GROWL], RED_ID),
	])
	var blue: PokeCoopPlayer = _blue()
	var session: PokeCoopBattleSession = _start(red, _enemy(Fixture.GEODUDE, 50, [Fixture.SLASH]))
	for _turn: int in 10:
		if session.phase() != PokeCoopBattleSession.AWAITING_ACTION:
			break
		_act(session, red, {"type": "move", "slot": 0})
	assert_eq(session.phase(), PokeCoopBattleSession.AWAITING_SEND_OUT)

	assert_eq(session.request_join(_data, blue), &"")
	assert_false(session.participants.has("blue"), "not in the middle of a replacement")
	assert_true(session.pending_players().has("blue"))

	assert_true(bool(_act(session, red, {"type": "send_out", "index": 1})["ok"]))
	var blue_rows: Array[int] = [2]
	assert_true(session.participants.has("blue"), "in once the battle waits for a move again")
	assert_eq(session.roster.indices_of("blue"), blue_rows)


func test_nobody_fights_two_battles_at_once() -> void:
	var red: PokeCoopPlayer = _red()
	var blue: PokeCoopPlayer = _blue()
	var first: PokeCoopBattleSession = _start(red, _enemy(), 1, "b1")
	var second: PokeCoopBattleSession = _start(blue, _enemy(), 2, "b2")

	assert_eq(second.request_join(_data, red), &"already_in_battle")
	assert_null(_start(red, _enemy(), 3, "b3"))
	assert_eq(first.request_join(_data, red), &"already_joined")


func test_two_battles_interleaved_play_out_as_if_each_ran_alone() -> void:
	var red: PokeCoopPlayer = _red()
	var green: PokeCoopPlayer = _player("green", RED_ID, [
		_saved(Fixture.PIKACHU, 20, [Fixture.GROWL, Fixture.TACKLE], RED_ID),
	])
	var first: PokeCoopBattleSession = _start(red, _enemy(Fixture.GEODUDE, 30), 7, "b1")
	var second: PokeCoopBattleSession = _start(green, _enemy(Fixture.GEODUDE, 30), 7, "b2")
	var streams: Dictionary = {"b1": [], "b2": []}
	for _turn: int in 3:
		for pair: Array in [[first, red], [second, green]]:
			var session: PokeCoopBattleSession = pair[0]
			assert_true(bool(_act(session, pair[1], {"type": "move", "slot": 1})["ok"]))
			(streams[session.id] as Array).append(session.last_events.duplicate(true))

	assert_eq(streams["b1"], streams["b2"], "same seed and commands, same battle, whatever ran between")
	assert_eq(first.revision, 3)


func test_each_owner_keeps_the_experience_their_pokemon_earned() -> void:
	var red: PokeCoopPlayer = _red(2)
	var blue: PokeCoopPlayer = _blue()
	var session: PokeCoopBattleSession = _start(red, _enemy(Fixture.BULBASAUR, 2))
	session.request_join(_data, blue)
	_act(session, red, {"type": "switch", "index": 2})
	_fight_out(session, {"red": red, "blue": blue})
	assert_eq(session.outcome(), &"won")

	var results: Dictionary = session.results()
	var red_rows: Array = results["red"]
	var blue_rows: Array = results["blue"]
	assert_eq(red_rows.size(), 2)
	assert_eq(blue_rows.size(), 1)
	var red_lead: Gen2BattleMon = red_rows[0]["mon"]
	var red_bench: Gen2BattleMon = red_rows[1]["mon"]
	var blue_lead: Gen2BattleMon = blue_rows[0]["mon"]
	assert_gt(red_lead.exp, red.mon(String(red_rows[0]["uid"])).exp, "red's lead fought")
	assert_eq(red_bench.exp, red.mon(String(red_rows[1]["uid"])).exp, "red's bench did not")
	assert_gt(blue_lead.exp, blue.mon(String(blue_rows[0]["uid"])).exp, "blue's Pokémon fought")

	assert_true(blue.absorb_battle_mon(String(blue_rows[0]["uid"]), blue_lead))
	assert_eq(blue.mon(String(blue_rows[0]["uid"])).exp, blue_lead.exp)
	assert_false(red.absorb_battle_mon(String(blue_rows[0]["uid"]), blue_lead),
		"a uid only lands on its owner's team")


## Gains of a partner's Pokémon over one fight in which both teams' leads took part.
func _partner_gain(partner_ot: int) -> int:
	var red: PokeCoopPlayer = _red()
	var blue: PokeCoopPlayer = _blue(1, partner_ot)
	var session: PokeCoopBattleSession = _start(red, _enemy(Fixture.BULBASAUR, 2))
	session.request_join(_data, blue)
	_act(session, red, {"type": "switch", "index": 1})
	var before: int = session.battle.party(Gen2Battle.PLAYER).at(1).exp
	_fight_out(session, {"red": red, "blue": blue})
	return session.battle.party(Gen2Battle.PLAYER).at(1).exp - before


func test_a_partners_own_pokemon_earns_no_traded_bonus_and_a_traded_one_does() -> void:
	var own: int = _partner_gain(BLUE_ID)
	var traded: int = _partner_gain(RED_ID)
	assert_gt(own, 0)
	assert_eq(traded, own * 3 / 2, "only a Pokémon from another trainer is paid as traded")


func test_a_ball_catches_the_wild_for_the_player_the_thrower_names() -> void:
	var red: PokeCoopPlayer = _red()
	var blue: PokeCoopPlayer = _blue()
	red.give_item(Gen2WorldPartyHost.ITEM_MASTER_BALL, 2)
	var session: PokeCoopBattleSession = _start(red, _enemy(Fixture.BULBASAUR, 2))
	session.request_join(_data, blue)

	var thrown: Dictionary = _act(session, red, {
		"type": "item", "item": Gen2WorldPartyHost.ITEM_MASTER_BALL, "recipient": "blue",
	})

	assert_true(bool(thrown["ok"]))
	assert_eq(session.outcome(), PokeCoopBattleSession.CAUGHT)
	assert_eq(String(session.catch["recipient"]), "blue")
	assert_eq(red.item_count(Gen2WorldPartyHost.ITEM_MASTER_BALL), 1, "the thrower's ball")
	assert_eq(StringName(_act(session, red, {"type": "move", "slot": 0})["reason"]), &"battle_over")


func test_a_trainers_pokemon_cannot_be_caught_and_the_ball_is_kept() -> void:
	var red: PokeCoopPlayer = _red()
	red.give_item(Gen2WorldPartyHost.ITEM_MASTER_BALL, 1)
	var session: PokeCoopBattleSession = PokeCoopBattleSession.start(
		_data, "b1", 1, red, Gen2TrainerParty.build(_data, Fixture.GEN1_LEADER, 0),
		{"id": "trainer:leader", "trainer_class": Fixture.GEN1_LEADER}
	)

	var thrown: Dictionary = _act(session, red, {
		"type": "item", "item": Gen2WorldPartyHost.ITEM_MASTER_BALL, "recipient": "red",
	})

	assert_eq(StringName(thrown["reason"]), &"trainer_pokemon")
	assert_eq(red.item_count(Gen2WorldPartyHost.ITEM_MASTER_BALL), 1)


func test_an_item_comes_out_of_the_acting_players_bag_only() -> void:
	_data.generation = RomRegistry.GEN2
	var red: PokeCoopPlayer = _red()
	var blue: PokeCoopPlayer = _blue()
	red.give_item(Fixture.POTION, 1)
	blue.give_item(Fixture.POTION, 3)
	var session: PokeCoopBattleSession = _start(red, _enemy())
	session.request_join(_data, blue)
	session.battle.mon(Gen2Battle.PLAYER).hp -= 10

	assert_true(bool(_act(session, red, {"type": "item", "item": Fixture.POTION, "target": 0})["ok"]))
	assert_eq(red.item_count(Fixture.POTION), 0)
	assert_eq(blue.item_count(Fixture.POTION), 3, "the partner's bag is not touched")
	assert_eq(
		StringName(_act(session, red, {"type": "item", "item": Fixture.POTION, "target": 0})["reason"]),
		&"item_not_held"
	)


## What each allied Pokémon gained in a fight Red's lead wins alone against a level 2 BULBASAUR.
func _gains(red: PokeCoopPlayer, blue: PokeCoopPlayer) -> Array:
	var session: PokeCoopBattleSession = _start(red, _enemy(Fixture.BULBASAUR, 2))
	if blue != null:
		session.request_join(_data, blue)
	var party: Gen2Party = session.battle.party(Gen2Battle.PLAYER)
	var before: Array = party.mons.map(func(mon: Gen2BattleMon) -> int: return mon.exp)
	_fight_out(session, {"red": red, "blue": blue})
	assert_eq(session.outcome(), &"won")
	return range(party.size()).map(func(index: int) -> int: return party.at(index).exp - int(before[index]))


func test_one_exp_all_pays_every_team_as_it_would_pay_one_team_alone() -> void:
	var holder: PokeCoopPlayer = _red(2)
	holder.give_item(Gen1Layout.ITEM_EXP_ALL)
	var alone: Array = _gains(holder, null)
	var red: PokeCoopPlayer = _red(2)
	red.give_item(Gen1Layout.ITEM_EXP_ALL)
	var together: Array = _gains(red, _blue(2))

	assert_gt(int(alone[1]), 0, "EXP.ALL pays Red's bench")
	assert_eq(together.slice(0, 2), alone, "Red's team gains what it would alone")
	assert_eq(together.slice(2), [alone[1], alone[1]], "Blue's team is split over its own two, not over four")
	var carrier: PokeCoopPlayer = _blue(2)
	carrier.give_item(Gen1Layout.ITEM_EXP_ALL)
	assert_eq(_gains(_red(2), carrier), together, "the joiner's EXP.ALL counts for everyone")
	assert_eq(_gains(_red(2), _blue(2)).slice(1), [0, 0, 0], "without one only the Pokémon that fought gain")


func test_a_joiner_who_leaves_hands_their_pokemon_to_whoever_is_left() -> void:
	var red: PokeCoopPlayer = _red()
	var blue: PokeCoopPlayer = _blue()
	red.place(Vector2i(0, 0), Vector2i(1, 1), 0)
	blue.place(Vector2i(0, 12), Vector2i(4, 4), 0)
	var session: PokeCoopBattleSession = _start(red, _enemy())
	session.request_join(_data, blue)
	_act(session, red, {"type": "switch", "index": 1})
	assert_eq(session.controller(), "blue")

	assert_eq(session.leave(red), &"attached", "the player whose fight it is stays in it")
	assert_eq(session.leave(blue), &"")
	assert_eq(session.controller(), "red", "Red decides at once for the Pokémon Blue left behind")
	assert_false(session.is_paused())
	assert_eq([blue.map, blue.cell, blue.return_point], [Vector2i(0, 12), Vector2i(4, 4), {}], "Blue is back where they were")
	assert_eq(session.roster.owner_at(1), "blue", "and their Pokémon stay theirs")
	session.set_absent("blue", false)
	assert_true(session.has_left("blue"), "coming back to the session is not rejoining the battle")

	assert_eq(session.request_join(_data, blue), &"")
	assert_eq([session.has_left("blue"), session.controller(), session.participants.count("blue")], [false, "blue", 1])


func test_a_queued_join_can_be_called_off() -> void:
	var red: PokeCoopPlayer = _player("red", RED_ID, [_saved(Fixture.PIKACHU, 5, [Fixture.GROWL], RED_ID),
		_saved(Fixture.PIKACHU, 5, [Fixture.GROWL], RED_ID)])
	var blue: PokeCoopPlayer = _blue()
	var session: PokeCoopBattleSession = _start(red, _enemy(Fixture.GEODUDE, 50, [Fixture.SLASH]))
	for _turn: int in 10:
		if session.phase() == PokeCoopBattleSession.AWAITING_SEND_OUT:
			break
		_act(session, red, {"type": "move", "slot": 0})
	session.request_join(_data, blue)

	assert_eq(session.leave(blue), &"")
	assert_true(blue.is_free())
	assert_eq(session.pending_players(), [] as Array[String])
	_act(session, red, {"type": "send_out", "index": 1})
	assert_false(session.participants.has("blue"), "nobody joins after calling it off")


func test_a_partner_stands_in_for_a_dropped_controller_only_once_asked() -> void:
	var red: PokeCoopPlayer = _red()
	var blue: PokeCoopPlayer = _blue()
	var session: PokeCoopBattleSession = _start(red, _enemy())
	session.request_join(_data, blue)
	session.set_absent("red", true)
	assert_eq([session.is_paused(), session.stand_in_due()], [true, false])
	assert_eq(session.stand_in("blue"), &"no_stand_in_due", "not before the owner has been away a while")

	session.set_absent("red", true, Time.get_ticks_msec() - PokeCoopPolicy.STAND_IN_MSEC)
	assert_eq([session.stand_in_due(), session.controller()], [true, "red"], "the battle waits until somebody takes over")
	assert_eq(session.stand_in("red"), &"not_a_participant", "the one who is away cannot")
	assert_eq(session.stand_in("blue"), &"")
	assert_eq([session.controller(), session.owner_deciding(), session.stand_in_due()], ["blue", "red", false])

	session.set_absent("red", false)
	assert_eq(session.controller(), "red", "the owner takes their Pokémon back")
	session.set_absent("red", true)
	assert_true(session.is_paused(), "and is waited for again the next time")


func test_the_view_carries_each_enemy_members_hp_and_status_for_its_balls() -> void:
	var session: PokeCoopBattleSession = _start(_red(), _enemy())
	var foe: Gen2BattleMon = session.battle.mon(Gen2Battle.ENEMY)
	foe.status = 8
	assert_eq(session.view()["enemy_states"], [{"hp": foe.hp, "status": 8}])


func test_the_panel_names_a_move_that_is_disabled_or_out_of_pp() -> void:
	var red: PokeCoopPlayer = _red()
	var session: PokeCoopBattleSession = _start(red, _enemy())
	var out: Gen2BattleMon = session.battle.mon(Gen2Battle.PLAYER)
	out.disabled_slot = 1
	assert_eq(StringName(_act(session, red, {"type": "move", "slot": 1})["reason"]), &"invalid_move")
	out.pp[0] = 0

	var view: Dictionary = session.view()
	assert_eq(int(view["allies"][0]["disabled"]), 1, "the view says which slot DISABLE locked")
	var panel: PokeCoopBattlePanel = autofree(PokeCoopBattlePanel.over(null, _data))
	var labels: Array = panel._move_rows(view).map(func(row: Dictionary) -> String: return String(row["label"]))
	assert_eq(labels, ["%s (NO PP)" % _data.move(Fixture.GROWL)["name"], "%s (DISABLED)" % _data.move(Fixture.TACKLE)["name"]])
	assert_true(PokeCoopBattlePanel.REFUSALS.has(&"invalid_move"), "a refused move is told in words")


## The enemy's moves over one opening turn per seed, against a paralysed PIKACHU.
func _enemy_moves_used(encounter: Dictionary) -> Dictionary:
	var used: Dictionary = {}
	for seed_value: int in 64:
		var red: PokeCoopPlayer = _red()
		var enemy: Gen2Party = _enemy(Fixture.GEODUDE, 50, [Fixture.TACKLE, Fixture.THUNDER_WAVE, Fixture.SLEEP_POWDER])
		var session: PokeCoopBattleSession = PokeCoopBattleSession.start(_data, "b1", seed_value, red, enemy, encounter)
		session.battle.mon(Gen2Battle.PLAYER).status = Gen2Status.PARALYSIS
		for event: Dictionary in _act(session, red, {"type": "move", "slot": 0}).get("events", []):
			if StringName(event.get("type", &"")) == Gen2Battle.USED_MOVE and int(event.get("side", -1)) == Gen2Battle.ENEMY:
				used[int(event.get("move", 0))] = true
	return used


## #27: a session's trainer scores its moves with the class's layers, as the battle screen does.
func test_a_trainer_in_a_session_chooses_its_moves_with_the_cartridges_trainer_ai() -> void:
	var wild: Dictionary = _enemy_moves_used({"id": "wild:test"})
	assert_true(wild.has(Fixture.THUNDER_WAVE) or wild.has(Fixture.SLEEP_POWDER), "a wild rolls any slot")
	var trainer: Dictionary = _enemy_moves_used({"id": "trainer:leader", "trainer_class": Fixture.GEN1_LEADER})
	assert_eq(trainer.keys(), [Fixture.TACKLE], "layer 1 leaves a status move to a healthy player only")


func test_a_trainer_in_a_session_spends_its_items_as_its_class_does() -> void:
	var red: PokeCoopPlayer = _red()
	var session: PokeCoopBattleSession = PokeCoopBattleSession.start(_data, "b1", 1, red, _enemy(Fixture.GEODUDE, 50, [Fixture.TACKLE]),
		{"id": "trainer:leader", "trainer_class": Fixture.GEN1_LEADER})
	session.battle.mon(Gen2Battle.ENEMY).status = Gen2Status.BURN
	var items: Array = []
	for event: Dictionary in _act(session, red, {"type": "move", "slot": 0}).get("events", []):
		if StringName(event.get("type", &"")) == Gen2Battle.TRAINER_USED_ITEM:
			items.append(int(event.get("item", 0)))
	assert_eq(items, [Gen1TrainerAI.FULL_HEAL], "BROCK's routine cures the burn")
	assert_eq(session.battle.mon(Gen2Battle.ENEMY).status, Gen2Status.NONE)
	assert_eq(session.battle.gen1_ai_count, Fixture.GEN1_LEADER_COUNT - 1, "one use spent")


func _leader(lead: PokeCoopPlayer) -> PokeCoopBattleSession:
	return PokeCoopBattleSession.start(_data, "b1", 1, lead, Gen2TrainerParty.build(_data, Fixture.GEN1_LEADER, 0),
		{"id": "trainer:leader", "trainer_class": Fixture.GEN1_LEADER})


## TACKLE from whoever decides until the trainer's first Pokémon, left on one HP, is down.
func _knock_out_lead(session: PokeCoopBattleSession, players: Dictionary) -> void:
	session.battle.mon(Gen2Battle.ENEMY).hp = 1
	for _turn: int in 20:
		if session.battle.mon(Gen2Battle.ENEMY).is_fainted() or session.battle.party(Gen2Battle.ENEMY).active != 0:
			return
		_act(session, players[session.controller()], {"type": "move", "slot": 1})


func test_shift_asks_the_owner_of_the_pokemon_out_before_the_trainer_sends_the_next() -> void:
	var red: PokeCoopPlayer = _red(2)
	red.battle_shift = true
	var session: PokeCoopBattleSession = _leader(red)
	_knock_out_lead(session, {"red": red})

	assert_eq(session.phase(), PokeCoopBattleSession.AWAITING_OFFER)
	assert_eq([session.controller(), int(session.view()["offer"]), session.battle.party(Gen2Battle.ENEMY).active],
		["red", 1, 0], "asked before the trainer's next Pokémon is out")
	assert_true(bool(_act(session, red, {"type": "stay"})["ok"]))
	assert_eq([session.phase(), session.battle.party(Gen2Battle.ENEMY).active, session.battle.party(Gen2Battle.PLAYER).active],
		[PokeCoopBattleSession.AWAITING_ACTION, 1, 0], "NO keeps the one out and the trainer sends the next")


func test_set_style_sends_the_trainers_next_pokemon_out_unasked() -> void:
	var red: PokeCoopPlayer = _red(2)
	var session: PokeCoopBattleSession = _leader(red)
	_knock_out_lead(session, {"red": red})

	assert_eq(session.phase(), PokeCoopBattleSession.AWAITING_ACTION)
	assert_eq([session.battle.party(Gen2Battle.ENEMY).active, int(session.view()["offer"])], [1, -1])


## Red's Pokémon out first, then Blue's: the offer reads the BATTLE STYLE of the player whose Pokémon is out.
func _offer_when_blue_is_out(red_shift: bool, blue_shift: bool) -> PokeCoopBattleSession:
	var red: PokeCoopPlayer = _red()
	var blue: PokeCoopPlayer = _blue()
	red.battle_shift = red_shift
	blue.battle_shift = blue_shift
	var session: PokeCoopBattleSession = _leader(red)
	session.request_join(_data, blue)
	_act(session, red, {"type": "switch", "index": 1})
	_knock_out_lead(session, {"red": red, "blue": blue})
	return session


func test_the_offer_goes_to_the_owner_of_the_pokemon_out_by_their_own_setting() -> void:
	assert_eq(_offer_when_blue_is_out(true, false).phase(), PokeCoopBattleSession.AWAITING_ACTION,
		"Red's SHIFT does not ask while Blue, on SET, has the Pokémon out")

	var session: PokeCoopBattleSession = _offer_when_blue_is_out(false, true)
	var red: PokeCoopPlayer = session._members["red"]
	var blue: PokeCoopPlayer = session._members["blue"]
	assert_eq([session.phase(), session.controller()], [PokeCoopBattleSession.AWAITING_OFFER, "blue"])
	assert_eq(StringName(_act(session, red, {"type": "stay"})["reason"]), &"not_controller")
	assert_eq(session.suggest("red", {"type": "stay", "value": 0}), &"", "the partner may suggest staying")
	assert_eq(StringName(_act(session, blue, {"type": "switch", "index": 1})["reason"]), &"invalid_switch",
		"the one already out is refused, the question still standing")

	assert_true(bool(_act(session, blue, {"type": "switch", "index": 0})["ok"]))
	assert_eq([session.controller(), session.battle.party(Gen2Battle.PLAYER).active, session.battle.party(Gen2Battle.ENEMY).active],
		["red", 0, 1], "YES on Red's Pokémon hands the next turn to Red as the trainer sends its next")


func test_the_trainers_question_is_worded_as_the_cartridge_words_it() -> void:
	var line: String = PokeCoopBattleField.message(
		{"type": Gen2Battle.SWITCH_OFFERED, "side": Gen2Battle.PLAYER, "index": 1, "species": Fixture.CHARMANDER},
		{Gen2Battle.PLAYER: Fixture.PIKACHU, Gen2Battle.ENEMY: Fixture.GEODUDE}, _data, {}, "LEADER")
	assert_eq(PokeCoopBattleField.pages(line), PackedStringArray([
		"LEADER is\nabout to use", PokeCoopBattleField._species_name(_data, Fixture.CHARMANDER) + "!",
	]))


## Red's PIKACHU leads; Blue joins and Red sends out Blue's [param lead].
func _blue_sent_out(lead: Gen2SaveMon, enemy: Gen2Party) -> PokeCoopBattleSession:
	var session: PokeCoopBattleSession = _start(_red(), enemy)
	session.request_join(_data, _player("blue", BLUE_ID, [lead]))
	_act(session, session._members["red"], {"type": "switch", "index": 1})
	return session


func test_mimic_asks_the_owner_of_the_pokemon_that_used_it_and_the_partner_may_suggest() -> void:
	var session: PokeCoopBattleSession = _blue_sent_out(
		_saved(Fixture.CHARMANDER, 20, [Fixture.MIMIC, Fixture.TACKLE], BLUE_ID), _enemy(Fixture.GEODUDE, 5, [Fixture.GROWL, Fixture.SLASH]))
	var red: PokeCoopPlayer = session._members["red"]
	var blue: PokeCoopPlayer = session._members["blue"]
	_act(session, blue, {"type": "move", "slot": 0})

	assert_eq([session.phase(), session.controller()], [PokeCoopBattleSession.AWAITING_MIMIC, "blue"])
	assert_eq(StringName(_act(session, red, {"type": "mimic", "choice": 1})["reason"]), &"not_controller")
	assert_eq(session.suggest("red", {"type": "mimic", "value": 1}), &"", "the partner may suggest the move to copy")
	assert_true(bool(_act(session, blue, {"type": "mimic", "choice": 1})["ok"]))
	assert_eq([session.phase(), session.battle.mon(Gen2Battle.PLAYER).moves[0]], [PokeCoopBattleSession.AWAITING_ACTION, Fixture.SLASH])


func test_a_move_to_learn_is_asked_of_the_learners_owner_while_the_partners_pokemon_is_out() -> void:
	var blue: PokeCoopPlayer = _player("blue", BLUE_ID,
		[_saved(Fixture.GEODUDE, 10, [Fixture.TACKLE, Fixture.EMBER, Fixture.THUNDERBOLT, Fixture.GROWL], BLUE_ID)])
	var red: PokeCoopPlayer = _red()
	var session: PokeCoopBattleSession = _start(blue, _enemy(Fixture.MAGCARGO, 33))
	session.request_join(_data, red)
	_act(session, blue, {"type": "switch", "index": 1})
	session.battle.mon(Gen2Battle.ENEMY).hp = 1
	_act(session, red, {"type": "move", "slot": 1})

	assert_eq([session.phase(), session.owner_deciding(), session.controller()], [PokeCoopBattleSession.AWAITING_LEARN, "blue", "blue"],
		"Blue's GEODUDE, out earlier in the fight, learns while Red's PIKACHU is out")
	assert_eq(StringName(_act(session, red, {"type": "learn", "forget_slot": 1})["reason"]), &"not_controller")
	assert_eq(session.suggest("red", {"type": "learn", "value": 1}), &"", "the partner may suggest the move to forget")
	assert_eq(session.suggest("red", {"type": "decline", "value": 0}), &"", "or keeping the old moves")
	assert_true(bool(_act(session, blue, {"type": "learn", "forget_slot": 1})["ok"]))
	assert_eq(session.battle.party(Gen2Battle.PLAYER).mons[0].moves[1], Fixture.SLASH)


func test_a_fainted_pokemons_owner_sends_out_any_ally_or_runs_and_the_partner_may_suggest() -> void:
	var session: PokeCoopBattleSession = _blue_sent_out(
		_saved(Fixture.CHARMANDER, 5, [Fixture.GROWL], BLUE_ID), _enemy(Fixture.GEODUDE, 50, [Fixture.SLASH]))
	var red: PokeCoopPlayer = session._members["red"]
	var blue: PokeCoopPlayer = session._members["blue"]
	for _turn: int in 10:
		if session.phase() == PokeCoopBattleSession.AWAITING_SEND_OUT:
			break
		_act(session, blue, {"type": "move", "slot": 0})

	assert_eq([session.phase(), session.controller(), session.battle.asking_use_next()],
		[PokeCoopBattleSession.AWAITING_SEND_OUT, "blue", true], "Blue's fainted CHARMANDER is Blue's to replace")
	assert_eq(StringName(_act(session, red, {"type": "send_out", "index": 0})["reason"]), &"not_controller")
	assert_eq(StringName(_act(session, red, {"type": "run"})["reason"]), &"not_controller")
	assert_eq(session.suggest("red", {"type": "send_out", "value": 0}), &"")
	assert_eq(session.suggest("red", {"type": "run", "value": 0}), &"", "or running from the wild one")
	assert_true(bool(_act(session, blue, {"type": "send_out", "index": 0})["ok"]))
	assert_eq([session.controller(), session.battle.party(Gen2Battle.PLAYER).active], ["red", 0], "Red's PIKACHU is back out for Red")
