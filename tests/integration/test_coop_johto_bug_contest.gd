extends GutTest

## The Bug-Catching Contest for two (#179, D128, D140): both players enter the same contest, each with their own
## contestants, timer, PARK BALLs and kept party, and each is judged on their own catch for their own prize. Two
## windows' worlds on the synthetic Generation 2 fixture, kept in step with a Gold host by their links; the gate
## scripts' effects are played on each window's state as the cartridge's scripts write them.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const Seed := preload("res://tools/coop_seed.gd")
const SAVE_PATH: String = "user://coop_johto_bug_contest_test.json"
const ROUTE_35_NATIONAL_PARK_GATE: Vector2i = Vector2i(10, 15)
## pokegold's event flags the contest's scripts write.
const EVENT_WARPED_FROM_ROUTE_35_NATIONAL_PARK_GATE: int = 722
const EVENT_LEFT_MONS_WITH_CONTEST_OFFICER: int = 776
const EVENT_CONTEST_OFFICER_HAS_SUN_STONE: int = 787
const EVENT_ROUTE_36_NATIONAL_PARK_GATE_OFFICER_CONTEST_DAY: int = 1863
const EVENT_ROUTE_36_NATIONAL_PARK_GATE_OFFICER_NOT_CONTEST_DAY: int = 1864
const EVENT_BUG_CATCHING_CONTESTANT_1B: int = 1824
const CONTEST_FLAGS: Array[int] = [722, 776, 787, 788, 789, 790, 1814, 1824, 1844, 1861, 1862, 1863, 1864]
## `BugContestResultsScript`'s prizes, first to third, and everyone else's.
const SUN_STONE: int = 169
const EVERSTONE: int = 112
const GOLD_BERRY: int = 174
const BERRY: int = 173

var _directory: String = ""
var _data: GameData = null
var _host: PokeCoopHost = null
var _clients: Array = []
var _links: Array = []


func before_each() -> void:
	_directory = RomCache.directory_for(&"coopjohtobugcontesttest", "0123456789abcdef")
	_data = Fixture.build(_directory, String(RomRegistry.GOLD), RomRegistry.GEN2)
	_data.sha1 = RomRegistry.sha1_for(RomRegistry.GOLD)
	_data.bug_contestants()
	var contestants: Array = []
	for index: int in Gen2WorldBugContest.NUM_CONTESTANTS:
		contestants.append({"trainer_class": 1, "trainer": index + 1, "placings": [
			{"species": Fixture.HOOTHOOT, "score": 60 - index}, {"species": Fixture.HOOTHOOT, "score": 50 - index},
			{"species": Fixture.HOOTHOOT, "score": 40 - index},
		]})
	_data._world_encounters["bug_contest"] = {"mons": [], "contestants": contestants}
	_clients = []
	_links = []
	_host = _hosting(PokeCoopCampaign.create("gold1", _data.id, _data.sha1))
	PokeCoopPolicy.start_campaign(_host.campaign)


func after_each() -> void:
	RomCache.clear(_directory)
	for path: String in [SAVE_PATH, SAVE_PATH + PokeCoopSave.BACKUP_SUFFIX, SAVE_PATH + PokeCoopSave.JOURNAL_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _hosting(campaign: PokeCoopCampaign) -> PokeCoopHost:
	var host: PokeCoopHost = PokeCoopHost.create(_data, campaign, PokeCoopTransport.new())
	host.save_path = SAVE_PATH
	host.seeds.seed = 179
	host.allow_new_players = true
	return host


func _join(peer: int, player_name: String, game: StringName, player_id: String = "") -> PokeCoopClient:
	var link := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, link, peer)
	var client: PokeCoopClient = PokeCoopClient.over(link)
	client.greet(player_name, game, RomRegistry.sha1_for(game), player_id)
	_clients.append(client)
	_pump()
	return client


## [param client]'s window in the Route 35 gate: its own world state and save.
func _window(client: PokeCoopClient, state: Gen2WorldState = Gen2WorldState.new()) -> PokeCoopWorldLink:
	var link: PokeCoopWorldLink = PokeCoopWorldLink.over(client, state, PokeCoopWorldLink.local_save(client, _data), _data)
	var map := Gen2WorldMap.new()
	map.group = ROUTE_35_NATIONAL_PARK_GATE.x
	map.number = ROUTE_35_NATIONAL_PARK_GATE.y
	link.world = Gen2WorldAPI.new(_data, map, null, Vector2i(2, 2), state)
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


func _mon(species: int, level: int, owner: PokeCoopWorldLink) -> Gen2SaveMon:
	var mon := Gen2SaveMon.new()
	mon.species = species
	mon.dvs = 0xFAAA + level
	mon.ot_id = owner.save.player_id
	mon.original_trainer = owner.save.player_name
	mon.level = level
	mon.exp = Gen2Experience.total_exp_at(int(_data.species(species).get("growth_rate", 0)), level)
	mon.nickname = String(_data.species(species).get("name", ""))
	mon.calc_stats(_data)
	mon.hp = mon.max_hp(_data)
	return mon


func _joined_party(link: PokeCoopWorldLink, mon: Gen2SaveMon) -> void:
	link.save.party.append(mon)
	link.push_party()
	_pump()


func _uids(rows: Array) -> Array:
	return rows.map(func(row: Dictionary) -> String: return String(row["uid"]))


func _species(rows: Array) -> Array:
	return rows.map(func(row: Dictionary) -> int: return (row["mon"] as Gen2SaveMon).species)


func _timer() -> int:
	return Gen2WorldState.engine_flag(Gen2WorldState.ENGINE_BUG_CONTEST_TIMER, false)


func _daily() -> int:
	return Gen2WorldState.engine_flag(Gen2WorldState.ENGINE_DAILY_BUG_CONTEST, false)


## The officer's YES on a contest day: `ContestDropOffMons`, the kept-party flag, the timer, `GiveParkBalls` and
## `SelectRandomBugContestContestants` drawn from [param draw]; answers the contestants who stayed away.
func _enter(link: PokeCoopWorldLink, draw: int) -> Dictionary:
	var keeps: bool = link.save.party.size() > 1
	link.state.set_contest_second_party_species(Gen2WorldPartyHost.contest_drop_off_mons(link.save))
	link.state.set_event_flag(EVENT_LEFT_MONS_WITH_CONTEST_OFFICER, keeps)
	link.state.set_engine_flag(_timer())
	link.world.start_bug_contest()
	var random := RandomNumberGenerator.new()
	random.seed = draw
	var withdrawn: Dictionary = Gen2WorldBugContest.select_withdrawn(random)
	for index: int in Gen2WorldBugContest.NUM_CONTESTANTS:
		link.state.set_event_flag(Gen2WorldState.EVENT_BUG_CATCHING_CONTESTANT_FIRST + index, withdrawn.has(index))
	_pump()
	link.push_party()
	_pump()
	return withdrawn


## A PARK BALL's catch of [param species] at [param level].
func _catch(link: PokeCoopWorldLink, species: int, level: int) -> void:
	var wild: Gen2BattleMon = Gen2BattleMon.create(_data, species, level, _data.moves_at_level(species, level))
	link.state.set_contest_mon(Gen2WorldPartyHost.contest_mon_from(wild))
	link.state.set_park_balls(link.state.park_balls() - 1)
	_pump()


## `BugContestResultsWarpScript` and `BugContestResultsScript`: the contestants who came walk into the Route 36 gate,
## the timer and balls go, the judging draws from [param judging], the prize goes to the bag, the kept party comes
## back, and every contestant flag is set again with the day's contest done. Answers the player's place.
func _results(link: PokeCoopWorldLink, judging: int) -> int:
	var state: Gen2WorldState = link.state
	for index: int in Gen2WorldBugContest.NUM_CONTESTANTS:
		if not state.is_event_flag_active(Gen2WorldState.EVENT_BUG_CATCHING_CONTESTANT_FIRST + index):
			state.set_event_flag(EVENT_BUG_CATCHING_CONTESTANT_1B + index, false)
	state.set_event_flag(EVENT_ROUTE_36_NATIONAL_PARK_GATE_OFFICER_CONTEST_DAY)
	state.set_event_flag(EVENT_ROUTE_36_NATIONAL_PARK_GATE_OFFICER_NOT_CONTEST_DAY, false)
	state.set_event_flag(EVENT_WARPED_FROM_ROUTE_35_NATIONAL_PARK_GATE)
	link.world.end_bug_contest()
	state.set_event_flag(EVENT_WARPED_FROM_ROUTE_35_NATIONAL_PARK_GATE, false)
	var caught: Dictionary = state.contest_mon()
	var random := RandomNumberGenerator.new()
	random.seed = judging
	var place: int = int(Gen2WorldBugContest.judge(int(caught.get("species", 0)), Gen2WorldBugContest.score(caught),
		_data.bug_contestants(), state.withdrawn_bug_contestants(), random)["player_place"])
	var prize: int = [BERRY, SUN_STONE, EVERSTONE, GOLD_BERRY][place]
	state.apply_changes({}, {}, {"items": {prize: state.item_quantity(prize) + 1}})
	if state.is_event_flag_active(EVENT_LEFT_MONS_WITH_CONTEST_OFFICER):
		Gen2WorldPartyHost.contest_return_mons(link.save)
		state.set_contest_second_party_species(0)
	state.set_contest_mon({})
	for index: int in Gen2WorldBugContest.NUM_CONTESTANTS * 2:
		state.set_event_flag(Gen2WorldState.EVENT_BUG_CATCHING_CONTESTANT_FIRST + index)
	state.set_engine_flag(_daily())
	_pump()
	link.push_party()
	_pump()
	return place


func test_both_players_enter_one_contest_and_each_is_judged_on_their_own_catch() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)
	var gold_window: PokeCoopWorldLink = _window(gold)
	var silver_window: PokeCoopWorldLink = _window(silver)
	_joined_party(gold_window, _mon(Fixture.CUBONE, 12, gold_window))
	_joined_party(gold_window, _mon(Fixture.HOOTHOOT, 9, gold_window))
	var gold_team: Array = _uids(_host.player(gold.player_id).team)

	var gold_draw: Dictionary = _enter(gold_window, 1)
	var silver_draw: Dictionary = _enter(silver_window, 4)
	assert_ne(gold_draw.keys(), silver_draw.keys(), "two draws")
	assert_eq(gold_window.state.withdrawn_bug_contestants(), gold_draw, "GOLD's park keeps GOLD's contestants")
	assert_eq(silver_window.state.withdrawn_bug_contestants(), silver_draw, "SILVER's park its own")
	assert_true(gold_window.state.is_event_flag_active(EVENT_LEFT_MONS_WITH_CONTEST_OFFICER),
		"SILVER entering alone does not clear the officer's hold on GOLD's party")
	assert_false(silver_window.state.is_event_flag_active(EVENT_LEFT_MONS_WITH_CONTEST_OFFICER))
	assert_eq([gold_window.state.park_balls(), silver_window.state.park_balls()], [20, 20])
	for flag: int in CONTEST_FLAGS:
		assert_false(_host.campaign.flags.has(flag), "the contest's flag %d is no campaign flag" % flag)

	_catch(gold_window, Fixture.CUBONE, 20)
	assert_eq(silver_window.state.park_balls(), 20, "GOLD's ball is GOLD's")
	assert_true(silver_window.state.contest_mon().is_empty(), "GOLD's catch is not SILVER's")
	assert_eq(_results(gold_window, 7), 1, "GOLD's CUBONE beats GOLD's contestants")
	assert_true(silver_window.state.is_engine_flag_active(_timer()), "SILVER's contest runs on")
	assert_eq(silver_window.state.withdrawn_bug_contestants(), silver_draw, "GOLD's results leave SILVER's contestants in the park")
	assert_false(silver_window.state.is_engine_flag_active(_daily()), "SILVER may still be judged today")

	assert_eq(_results(silver_window, 8), 0, "SILVER caught nothing and places behind SILVER's own contestants")
	assert_eq([gold_window.state.item_quantity(SUN_STONE), gold_window.state.item_quantity(BERRY)], [1, 0], "GOLD's prize")
	assert_eq([silver_window.state.item_quantity(SUN_STONE), silver_window.state.item_quantity(BERRY)], [0, 1], "SILVER's prize")
	assert_eq([_host.player(gold.player_id).item_count(SUN_STONE), _host.player(silver.player_id).item_count(BERRY)], [1, 1])
	assert_eq(_uids(_host.player(gold.player_id).team), gold_team, "GOLD's whole party is back under its own uids")
	assert_eq(_host.player(silver.player_id).team.size(), 1)


func test_the_party_the_officer_keeps_stays_with_its_player_through_a_save_and_a_new_host() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var gold_window: PokeCoopWorldLink = _window(gold)
	_joined_party(gold_window, _mon(Fixture.CUBONE, 12, gold_window))
	_joined_party(gold_window, _mon(Fixture.HOOTHOOT, 9, gold_window))
	var team: Array = _host.player(gold.player_id).team.duplicate()
	_enter(gold_window, 1)
	gold_window.save.party[0].hp -= 1
	gold_window.push_party()
	_pump()
	assert_eq(_uids(_host.player(gold.player_id).team), [team[0]["uid"]], "the lead competes")
	gold.request_save()
	_pump()

	var loaded: Dictionary = PokeCoopSave.read(SAVE_PATH)
	assert_false(loaded.is_empty(), "the campaign is written")
	var id: String = gold.player_id
	_host.shutdown()
	_pump()
	_clients = []
	_links = []
	_host = _hosting(loaded["campaign"])
	_host.adopt_players(loaded["players"])
	var client: PokeCoopClient = _join(1, "", RomRegistry.GOLD, id)
	var window: PokeCoopWorldLink = _window(client, PokeCoopWorldLink.continued_world(client).world_state)
	assert_eq(window.save.contest_stashed_party.map(func(mon: Gen2SaveMon) -> int: return mon.species),
		_species(team.slice(1)), "the officer still holds GOLD's other two")
	assert_true(window.state.is_engine_flag_active(_timer()), "GOLD is still in the contest")

	_results(window, 7)
	assert_eq(_uids(_host.player(id).team), _uids(team), "back under their own uids")
	assert_eq(_species(_host.player(id).team), _species(team))


func test_one_player_in_the_contest_holds_nobody_at_the_gate() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)
	var gold_window: PokeCoopWorldLink = _window(gold)
	var silver_window: PokeCoopWorldLink = _window(silver)
	_enter(gold_window, 1)
	gold_window.state.apply_changes({}, {"%d:%d" % [ROUTE_35_NATIONAL_PARK_GATE.x, ROUTE_35_NATIONAL_PARK_GATE.y]: 2})
	_pump()
	assert_eq(silver_window.state.map_scene(ROUTE_35_NATIONAL_PARK_GATE.x, ROUTE_35_NATIONAL_PARK_GATE.y), 0,
		"GOLD's leave-early scene is GOLD's")
	assert_false(silver_window.state.is_engine_flag_active(_timer()), "SILVER's timer is not running")
	assert_eq(silver_window.state.park_balls(), 0)
	gold_window.state.set_event_flag(EVENT_CONTEST_OFFICER_HAS_SUN_STONE)
	_pump()
	assert_false(silver_window.state.is_event_flag_active(EVENT_CONTEST_OFFICER_HAS_SUN_STONE),
		"the SUN STONE the officer holds for GOLD is not SILVER's to take")


func test_a_seed_adds_a_pokemon_to_one_players_party() -> void:
	var player := PokeCoopPlayer.create("p1", "GOLD", 17800)
	var saved: Gen2SaveMon = Seed._johto_mon(_data, player, String(_data.species(Fixture.HOOTHOOT).get("name", "")), 4)
	assert_eq([saved.species, saved.level, saved.original_trainer, saved.ot_id], [Fixture.HOOTHOOT, 4, "GOLD", 17800])
	assert_null(Seed._johto_mon(_data, player, "NOBODY", 5), "an unknown species is refused")
	var campaign := PokeCoopCampaign.create("gold9", _data.id, _data.sha1)
	var players: Array = [player, PokeCoopPlayer.create("p2", "SILVER", 17801)]
	assert_true(Seed._johto_option(_data, campaign, players, "mon=p2:%s:6" % _data.species(Fixture.CUBONE).get("name", "")))
	assert_eq([player.team.size(), (players[1] as PokeCoopPlayer).team.size()], [0, 1], "mon=p2 joins SILVER's party")
	assert_true(Seed._johto_option(_data, campaign, players, "clock=10:00:2"))
	assert_eq([campaign.clock["day"], campaign.clock["hour"], campaign.clock["minute"]], [2, 10, 0], "a TUESDAY morning")
