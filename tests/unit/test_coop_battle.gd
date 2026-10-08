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
