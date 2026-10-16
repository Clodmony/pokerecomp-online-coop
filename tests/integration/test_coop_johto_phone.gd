extends GutTest

## Each Gold and Silver player's own Pokégear (#177, D139) on the synthetic Generation 2 fixture: phone numbers,
## rematch calls, a phone trainer's rematch fought by each player, and Mom's share of each player's prize.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const SAVE_PATH: String = "user://coop_johto_phone_test.json"
const CHERRYGROVE: Vector2i = Vector2i(26, 3)
const ROUTE_30: Vector2i = Vector2i(26, 1)
const JUGGLER: int = 1  ## the fixture's juggler in the phone list, standing on Route 30
const EVENT_JOEY_ASKED_FOR_PHONE_NUMBER: int = 0x273
const EVENT_JOEY_READY_FOR_REMATCH: int = 0x274
const MOM_SAVING_SOME_MONEY: int = 0x81  ## MOM_ACTIVE and the first tier her question sets

var _directory: String = ""
var _data: GameData = null
var _host: PokeCoopHost = null
var _clients: Array = []
var _gold: PokeCoopClient = null
var _silver: PokeCoopClient = null


func before_each() -> void:
	_directory = RomCache.directory_for(&"coopjohtophone", "0123456789abcdef")
	_data = Fixture.build(_directory, String(RomRegistry.GOLD), RomRegistry.GEN2)
	_data.sha1 = RomRegistry.sha1_for(RomRegistry.GOLD)
	RomCache.write_json(RomCache.world_phone_path(_directory), {"contacts": [
		{"index": 0, "trainer_class": 0, "trainer_number": 0, "map_group": -1, "map_number": -1, "callee_time": 0, "caller_time": 0},
		{"index": JUGGLER, "trainer_class": Fixture.GEN1_JUGGLER, "trainer_number": 1, "map_group": ROUTE_30.x,
			"map_number": ROUTE_30.y, "callee_time": 7, "caller_time": 7, "callee_script": {}, "caller_script": {"kind": "test"}},
	]})
	_host = PokeCoopHost.create(_data, PokeCoopCampaign.create("gold1", _data.id, _data.sha1), PokeCoopTransport.new())
	_host.save_path = SAVE_PATH
	_host.seeds.seed = 177
	var gold: PokeCoopPlayer = _host.add_player("GOLD", 100)
	gold.place(CHERRYGROVE, Vector2i(13, 6), 0)
	gold.add_mon(_saved(Fixture.CHARMANDER, 30, [Fixture.TACKLE, Fixture.GROWL], 100))
	var silver: PokeCoopPlayer = _host.add_player("SILVER", 200)
	silver.place(CHERRYGROVE, Vector2i(12, 6), 0)
	silver.add_mon(_saved(Fixture.PIKACHU, 30, [Fixture.TACKLE], 200))
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


func _send_world(client: PokeCoopClient, patch: Dictionary) -> void:
	client.send({"type": "world", "patch": patch})
	_pump()


func _world(client: PokeCoopClient) -> Gen2WorldState:
	return Gen2WorldState.from_dict(PokeCoopWorldLink._host_world(client))


func _callers(client: PokeCoopClient) -> Array:
	var map := Gen2WorldMap.new()
	map.group = CHERRYGROVE.x
	map.number = CHERRYGROVE.y
	return Gen2WorldPhoneHost.available_incoming_contacts(_data, _world(client), map, 12).map(
		func(contact: Dictionary) -> int: return int(contact["index"]))


## The juggler's party the world opened, as `PokeCoopBattleTakeover` asks the host for it: the seq, or -1.
func _rematch(client: PokeCoopClient) -> int:
	var enemy: Dictionary = Gen2SaveBattleAdapter.from_battle_mon(Gen2BattleMon.create(_data, Fixture.PIKACHU, 5, [Fixture.TACKLE])).to_dict()
	var seq: int = client.send({"type": "window_battle", "kind": "trainer", "trainer_class": Fixture.GEN1_JUGGLER,
		"trainer_index": 0, "enemy": [enemy], "map": [ROUTE_30.x, ROUTE_30.y]})
	_pump()
	return seq


func _refused(client: PokeCoopClient, seq: int) -> String:
	for rejection: Dictionary in client.rejections:
		if int(rejection.get("seq", -1)) == seq:
			return String(rejection.get("reason", ""))
	return ""


func _battle_of(client: PokeCoopClient) -> String:
	return String(client.current_battle().get("battle", ""))


func _fight_out(battle_id: String) -> void:
	for _turn: int in 80:
		var view: Dictionary = _gold.battle(battle_id) if not _gold.battle(battle_id).is_empty() else _silver.battle(battle_id)
		if String(view.get("outcome", "")) != "":
			return
		var controller: PokeCoopClient = _gold if _gold.is_controller(battle_id) else _silver
		if String(view["phase"]) == String(PokeCoopBattleSession.AWAITING_SEND_OUT):
			var standing: Array = (view["allies"] as Array).filter(func(ally: Dictionary) -> bool: return int(ally["hp"]) > 0)
			controller.act(battle_id, {"type": "send_out", "index": int(standing[0]["index"])})
		else:
			controller.act(battle_id, {"type": "move", "slot": 0})
		_pump()


func test_a_phone_number_one_player_registers_is_in_their_pokegear_only() -> void:
	_send_world(_gold, {
		"phone_contacts": {"set": {JUGGLER: true}, "erase": []},
		"event_flags": {"set": {EVENT_JOEY_ASKED_FOR_PHONE_NUMBER: true}, "erase": []},
	})

	assert_true(_world(_gold).has_phone_contact(JUGGLER), "GOLD took the number")
	assert_false(_world(_silver).has_phone_contact(JUGGLER), "SILVER's POKéGEAR lists only SILVER's numbers")
	assert_eq([_callers(_gold), _callers(_silver)], [[JUGGLER], []], "so the juggler can ring GOLD's window and never SILVER's")
	assert_false(_world(_silver).is_event_flag_active(EVENT_JOEY_ASKED_FOR_PHONE_NUMBER),
		"JOEY asks SILVER for the number as the first time, not as asked again")
	assert_false(_host.campaign.has_flag(EVENT_JOEY_ASKED_FOR_PHONE_NUMBER))


func test_a_rematch_call_readies_the_trainer_for_its_player_only() -> void:
	_send_world(_gold, {"event_flags": {"set": {EVENT_JOEY_READY_FOR_REMATCH: true}, "erase": []}})

	assert_true(_world(_gold).is_event_flag_active(EVENT_JOEY_READY_FOR_REMATCH), "JOEY called GOLD for a rematch")
	assert_false(_world(_silver).is_event_flag_active(EVENT_JOEY_READY_FOR_REMATCH), "SILVER's JOEY was never called")

	_send_world(_silver, {"event_flags": {"set": {}, "erase": [EVENT_JOEY_READY_FOR_REMATCH]}})
	assert_true(_world(_gold).is_event_flag_active(EVENT_JOEY_READY_FOR_REMATCH), "and SILVER's walk never clears GOLD's call")


func test_each_player_fights_a_phone_trainers_rematch_once_the_team_beat_them() -> void:
	var first: int = _rematch(_gold)
	var first_fight: String = _battle_of(_gold)
	assert_eq(_refused(_gold, first), "")
	assert_eq(String(_host.battles[first_fight].encounter["id"]), "trainer:%d:0" % Fixture.GEN1_JUGGLER,
		"the juggler's first fight is one for the team, as every trainer's")
	_fight_out(first_fight)
	assert_eq(_host.campaign.encounter_state("trainer:%d:0" % Fixture.GEN1_JUGGLER), PokeCoopCampaign.ENCOUNTER_DONE)

	var again: int = _rematch(_gold)
	assert_eq(_refused(_gold, again), "", "GOLD's rematch is fought, not skipped as a trainer the team beat")
	var gold_rematch: String = _battle_of(_gold)
	assert_false(gold_rematch.is_empty())
	_fight_out(gold_rematch)

	var silver_turn: int = _rematch(_silver)
	assert_eq(_refused(_silver, silver_turn), "", "SILVER fights the juggler's rematch too")
	assert_false(_battle_of(_silver).is_empty())
	assert_false(_host.battles[_battle_of(_silver)].encounter.get("unique", true), "a rematch is each player's, never one per campaign")


func test_moms_savings_take_their_share_of_each_players_own_prize() -> void:
	_send_world(_gold, {"mom_savings_flags": {"value": MOM_SAVING_SOME_MONEY}, "money": {"set": {1: 100}, "erase": []}})
	var before: Array = [_host.player(_gold.player_id).money, _host.player(_silver.player_id).money]
	_gold.start_battle("trainer:leader")
	_pump()
	var battle_id: String = _battle_of(_gold)
	_silver.join_battle(battle_id)
	_pump()
	var quarter: int = 99 * 14

	_fight_out(battle_id)

	assert_eq(String(_gold.battle(battle_id).get("outcome", "")), "won")
	assert_eq([_host.player(_gold.player_id).money - int(before[0]), _host.player(_silver.player_id).money - int(before[1])],
		[quarter * 3, quarter * 4], "GOLD's Mom keeps a quarter of GOLD's prize; SILVER's saves nothing")
	assert_eq([_world(_gold).money(1), _world(_silver).money(1)], [100 + quarter, 0], "into GOLD's Mom's account, which GOLD's window reads")
	var view: Dictionary = _gold.battle(battle_id)
	assert_eq(int((view["prizes"] as Dictionary)[_gold.player_id]), quarter * 4, "the field still says the whole prize")
	assert_eq((view.get("mom", {}) as Dictionary), {_gold.player_id: String(Gen2Battle.PRIZE_SENT_SOME_TO_MOM)})


func test_the_field_says_what_moms_savings_took() -> void:
	var field: PokeCoopBattleField = add_child_autofree(PokeCoopBattleField.over(autofree(PokeCoopBattlePanel.over(_gold, _data)), _data))
	field._queue_victory({"trainer": true, "trainer_class": Fixture.GEN1_LEADER, "prizes": {_gold.player_id: 400},
		"mom": {_gold.player_id: String(Gen2Battle.PRIZE_SENT_SOME_TO_MOM)}})

	var said: Array = field._messages.map(func(step: Dictionary) -> String: return String(step.get("text", "")))
	assert_true(said.any(func(line: String) -> bool: return line.contains("Sent some to MOM!")), str(said))
	assert_true(said.any(func(line: String) -> bool: return line.contains("¥400")), "the prize line first, as `.SentToMomTexts`")
