extends GutTest

## Gold and Silver's day care (#178, D128, D135): each player's two places, steps
## and egg are their own, the Day-Care man hands an egg to his own player only, and
## the egg hatches in its owner's party by its owner's steps. Two windows' worlds on
## the synthetic Generation 2 fixture, kept in step with a Gold host by their links.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const Seed := preload("res://tools/coop_seed.gd")
const SAVE_PATH: String = "user://coop_johto_day_care_test.json"
const ROUTE_34: Vector2i = Vector2i(11, 1)
## Route 34's `MAPCALLBACK_OBJECTS` writes these four on every load of the map, from the player's own day care.
const EVENT_DAY_CARE_MAN_IN_DAY_CARE: int = 1765
const EVENT_DAY_CARE_MAN_ON_ROUTE_34: int = 1766
const EVENT_DAY_CARE_MON_1: int = 1767
const EVENT_DAY_CARE_MON_2: int = 1768
## Opposite genders at GENDER_F50 whose Defense and Special DVs differ, as test_world_day_care's.
const MALE_DVS: int = 0xF3FE
const FEMALE_DVS: int = 0x0A05

var _directory: String = ""
var _data: GameData = null
var _host: PokeCoopHost = null
var _clients: Array = []
var _links: Array = []


func before_each() -> void:
	_directory = RomCache.directory_for(&"coopjohtodaycaretest", "0123456789abcdef")
	_data = Fixture.build(_directory, String(RomRegistry.GOLD), RomRegistry.GEN2)
	_data.sha1 = RomRegistry.sha1_for(RomRegistry.GOLD)
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
	host.seeds.seed = 178
	host.allow_new_players = true
	return host


func _join(peer: int, player_name: String, game: StringName) -> PokeCoopClient:
	var link := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, link, peer)
	var client: PokeCoopClient = PokeCoopClient.over(link)
	client.greet(player_name, game, RomRegistry.sha1_for(game))
	_clients.append(client)
	_pump()
	return client


## [param client]'s window: its own world state and save, standing on Route 34.
func _window(client: PokeCoopClient, state: Gen2WorldState = Gen2WorldState.new()) -> PokeCoopWorldLink:
	var link: PokeCoopWorldLink = PokeCoopWorldLink.over(client, state, PokeCoopWorldLink.local_save(client, _data), _data)
	var map := Gen2WorldMap.new()
	map.group = ROUTE_34.x
	map.number = ROUTE_34.y
	link.world = Gen2WorldAPI.new(_data, map, null, Vector2i(15, 17), state)
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


func _mon(species: int, dvs: int, owner: PokeCoopWorldLink) -> Gen2SaveMon:
	var mon := Gen2SaveMon.new()
	mon.species = species
	mon.dvs = dvs
	mon.ot_id = owner.save.player_id
	mon.original_trainer = owner.save.player_name
	mon.level = 10
	mon.exp = Gen2Experience.total_exp_at(int(_data.species(species).get("growth_rate", 0)), 10)
	mon.nickname = String(_data.species(species).get("name", ""))
	mon.calc_stats(_data)
	mon.hp = mon.max_hp(_data)
	return mon


## What the window's Day-Care man and lady do with a party member the player hands over.
func _deposit(link: PokeCoopWorldLink, slot: int, mon: Gen2SaveMon) -> void:
	link.save.party.append(mon)
	link.push_party()
	_pump()
	assert_true(Gen2WorldDayCare.deposit(link.state, link.save, slot, link.save.party.size() - 1))
	link.push_party()
	_pump()


## A CUBONE pair in [param link]'s day care with their egg waiting at the man's, one step cycle from hatching.
func _egg_waiting(link: PokeCoopWorldLink) -> Gen2SaveMon:
	_deposit(link, Gen2WorldDayCare.SLOT_MAN, _mon(Fixture.CUBONE, MALE_DVS, link))
	_deposit(link, Gen2WorldDayCare.SLOT_LADY, _mon(Fixture.CUBONE, FEMALE_DVS, link))
	var random := RandomNumberGenerator.new()
	random.seed = 178
	assert_true(Gen2WorldDayCare.init_breeding(link.state, _data, link.save.player_name, link.save.player_id, random))
	link.state.set_day_care_man_flags(link.state.day_care_man_flags() & ~Gen2WorldDayCare.MAN_MONS_COMPATIBLE | Gen2WorldDayCare.MAN_HAS_EGG)
	var egg: Gen2SaveMon = link.state.day_care_egg()
	egg.happiness = 1
	link.state.set_day_care_egg(egg)
	_pump()
	return egg


## [param mon] into [param link]'s party, and the uid the host gives it.
func _joined_party(link: PokeCoopWorldLink, mon: Gen2SaveMon) -> String:
	link.save.party.append(mon)
	link.push_party()
	_pump()
	return _uid_of(link, mon)


func _uid_of(link: PokeCoopWorldLink, mon: Gen2SaveMon) -> String:
	for entry: Dictionary in _host.player(link.client.player_id).team + _host.player(link.client.player_id).box:
		if PokeCoopPlayer.fingerprint(entry["mon"]) == PokeCoopPlayer.fingerprint(mon):
			return String(entry["uid"])
	return ""


## The uids the host keeps with [param link]'s player's day care.
func _kept(link: PokeCoopWorldLink) -> Array:
	var kept: Variant = _host.player(link.client.player_id).get("day_care")
	return (kept as Array).map(func(entry: Dictionary) -> String: return entry["uid"]) if kept is Array else []


## A day care's hand-over: the world's patch first, as a window sends both when its scene ends, or the party first.
func _handed_over(link: PokeCoopWorldLink, party_first: bool) -> void:
	if party_first:
		link.push_party()
	_pump()
	link.push_party()
	_pump()


func _species(rows: Array) -> Array:
	return rows.map(func(row: Dictionary) -> int: return (row["mon"] as Gen2SaveMon).species)


func _slots(world: Dictionary) -> Array:
	return (world.get("day_care_mons", []) as Array).map(func(row: Dictionary) -> int: return int(row.get("species", 0)))


## Route 34's callback on a load of the map, from [param link]'s own day care.
func _load_route_34(link: PokeCoopWorldLink) -> void:
	var state: Gen2WorldState = link.state
	var man: int = state.day_care_man_flags()
	var egg: bool = man & Gen2WorldDayCare.MAN_HAS_EGG != 0
	var shown: Dictionary = {
		EVENT_DAY_CARE_MAN_IN_DAY_CARE: egg, EVENT_DAY_CARE_MAN_ON_ROUTE_34: not egg,
		EVENT_DAY_CARE_MON_1: man & Gen2WorldDayCare.MAN_HAS_MON == 0,
		EVENT_DAY_CARE_MON_2: state.day_care_lady_flags() & Gen2WorldDayCare.LADY_HAS_MON == 0,
	}
	for flag: int in shown:
		if shown[flag]:
			state.set_event_flag(flag)
		else:
			state.clear_event_flag(flag)
	_pump()


func _hidden(link: PokeCoopWorldLink) -> Array:
	return [EVENT_DAY_CARE_MAN_IN_DAY_CARE, EVENT_DAY_CARE_MAN_ON_ROUTE_34, EVENT_DAY_CARE_MON_1, EVENT_DAY_CARE_MON_2].map(
		func(flag: int) -> bool: return link.state.is_event_flag_active(flag))


func test_each_player_leaves_pokemon_in_their_own_day_care() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)
	var gold_window: PokeCoopWorldLink = _window(gold)
	var silver_window: PokeCoopWorldLink = _window(silver)

	_deposit(gold_window, Gen2WorldDayCare.SLOT_MAN, _mon(Fixture.CUBONE, MALE_DVS, gold_window))
	_deposit(gold_window, Gen2WorldDayCare.SLOT_LADY, _mon(Fixture.CUBONE, FEMALE_DVS, gold_window))
	_deposit(silver_window, Gen2WorldDayCare.SLOT_MAN, _mon(Fixture.HOOTHOOT, MALE_DVS, silver_window))

	assert_eq(_slots(_host.player(gold.player_id).world), [Fixture.CUBONE, Fixture.CUBONE], "GOLD's two places")
	assert_eq(_slots(_host.player(silver.player_id).world), [Fixture.HOOTHOOT, 0], "SILVER's man holds one, the lady none")
	assert_false(_host.campaign.world.has("day_care_mons"), "no day care is the campaign's")
	assert_eq(silver_window.state.day_care_mon(Gen2WorldDayCare.SLOT_MAN).species, Fixture.HOOTHOOT)
	assert_null(silver_window.state.day_care_mon(Gen2WorldDayCare.SLOT_LADY), "GOLD's CUBONE never reaches SILVER's lady")
	assert_eq(gold_window.state.day_care_mon(Gen2WorldDayCare.SLOT_MAN).species, Fixture.CUBONE)
	assert_eq(_species(_host.player(gold.player_id).team), [_species(_host.player(gold.player_id).team)[0]], "the two left GOLD's team")
	assert_eq(_host.player(silver.player_id).team.size(), 1)


func test_the_route_34_pen_shows_each_player_their_own_day_care() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)
	var gold_window: PokeCoopWorldLink = _window(gold)
	var silver_window: PokeCoopWorldLink = _window(silver)
	_egg_waiting(gold_window)
	_deposit(silver_window, Gen2WorldDayCare.SLOT_MAN, _mon(Fixture.HOOTHOOT, MALE_DVS, silver_window))

	_load_route_34(gold_window)
	_load_route_34(silver_window)
	_pump()

	assert_eq(_hidden(gold_window), [true, false, false, false], "GOLD's man waits outside with the egg, both of GOLD's in the pen")
	assert_eq(_hidden(silver_window), [false, true, false, true], "SILVER's man stays indoors, one of SILVER's in the pen")
	for flag: int in [EVENT_DAY_CARE_MAN_IN_DAY_CARE, EVENT_DAY_CARE_MAN_ON_ROUTE_34, EVENT_DAY_CARE_MON_1, EVENT_DAY_CARE_MON_2]:
		assert_false(_host.campaign.has_flag(flag), "flag %d is no story the team shares" % flag)


func test_the_day_care_man_hands_the_egg_to_his_own_player_only() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)
	var gold_window: PokeCoopWorldLink = _window(gold)
	var silver_window: PokeCoopWorldLink = _window(silver)
	var waiting: Gen2SaveMon = _egg_waiting(gold_window)

	assert_eq(silver_window.state.day_care_man_flags() & Gen2WorldDayCare.MAN_HAS_EGG, 0, "SILVER's man has no egg")
	assert_eq(Gen2WorldDayCare.give_egg(silver_window.state, silver_window.save), {})
	var given: Dictionary = Gen2WorldDayCare.give_egg(gold_window.state, gold_window.save)
	assert_eq(int(given.get("species", 0)), waiting.species)
	gold_window.push_party()
	_pump()

	var gold_team: Array = _host.player(gold.player_id).team
	assert_eq(gold_team.size(), 2)
	assert_true((gold_team[1]["mon"] as Gen2SaveMon).is_egg, "the egg is in GOLD's team on the host")
	assert_eq((gold_team[1]["mon"] as Gen2SaveMon).original_trainer, "GOLD")
	assert_false(_host.player(silver.player_id).team.any(func(row: Dictionary) -> bool: return (row["mon"] as Gen2SaveMon).is_egg))
	assert_eq(int(_host.player(gold.player_id).world.get("day_care_man", 0)) & Gen2WorldDayCare.MAN_HAS_EGG, 0, "handed over")


func test_an_egg_hatches_in_its_owners_party_by_its_owners_steps() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)
	var gold_window: PokeCoopWorldLink = _window(gold)
	var silver_window: PokeCoopWorldLink = _window(silver)
	_egg_waiting(gold_window)
	Gen2WorldDayCare.give_egg(gold_window.state, gold_window.save)
	gold_window.push_party()
	_pump()

	for _step: int in 512:
		silver_window.state.count_step()
	_pump()
	assert_eq(silver_window.state.take_pending_egg_steps(), 2, "SILVER walked two egg cycles")
	assert_true((gold_window.save.party[1] as Gen2SaveMon).is_egg, "SILVER's steps hatch nothing of GOLD's")
	assert_eq((gold_window.save.party[1] as Gen2SaveMon).happiness, 1)

	var cycles: int = 0
	for _step: int in 256:
		gold_window.state.count_step()
		cycles = gold_window.state.take_pending_egg_steps()
		if cycles > 0:
			break
	assert_eq(Gen2WorldPartyHost.apply_egg_steps(gold_window.save, cycles), 1, "GOLD's own walk drains the egg")
	var hatched: Dictionary = Gen2WorldPartyHost.hatch_egg(gold_window.world, gold_window.save, 1)
	assert_eq(int(hatched.get("species", 0)), Fixture.CUBONE)
	gold_window.push_party()
	_pump()

	var mon: Gen2SaveMon = _host.player(gold.player_id).team[1]["mon"]
	assert_false(mon.is_egg, "hatched in GOLD's team on the host")
	assert_eq([mon.species, mon.original_trainer, mon.ot_id], [Fixture.CUBONE, "GOLD", gold_window.save.player_id])
	assert_true(bool((_host.player(gold.player_id).world.get("caught_species", {}) as Dictionary).get(Fixture.CUBONE, false)),
		"GOLD's dex learns it")
	assert_false(silver_window.state.has_caught_species(Fixture.CUBONE), "SILVER's does not")
	assert_eq(_host.player(silver.player_id).team.size(), 1)


func test_each_day_care_survives_a_checkpoint_and_a_new_host() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)
	var gold_window: PokeCoopWorldLink = _window(gold)
	var silver_window: PokeCoopWorldLink = _window(silver)
	var waiting: Gen2SaveMon = _egg_waiting(gold_window)
	_deposit(silver_window, Gen2WorldDayCare.SLOT_LADY, _mon(Fixture.HOOTHOOT, FEMALE_DVS, silver_window))
	silver.request_save()
	_pump()

	var loaded: Dictionary = PokeCoopSave.read(SAVE_PATH)
	assert_false(loaded.is_empty(), "the campaign is written")
	var ids: Array = [gold.player_id, silver.player_id]
	_host.shutdown()
	_pump()
	_clients = []
	_links = []
	_host = _hosting(loaded["campaign"])
	_host.adopt_players(loaded["players"])
	for index: int in 2:
		var game: StringName = [RomRegistry.GOLD, RomRegistry.SILVER][index]
		var link := PokeCoopTransport.new()
		PokeCoopTransport.link(_host.transport, link, index + 1)
		var client: PokeCoopClient = PokeCoopClient.over(link)
		client.greet("", game, RomRegistry.sha1_for(game), ids[index])
		_clients.append(client)
		_pump()

	var gold_world: Gen2WorldState = PokeCoopWorldLink.continued_world(_clients[0]).world_state
	var silver_world: Gen2WorldState = PokeCoopWorldLink.continued_world(_clients[1]).world_state
	assert_eq(gold_world.day_care_egg().species, waiting.species, "GOLD's egg still waits for GOLD")
	assert_eq(gold_world.day_care_man_flags() & Gen2WorldDayCare.MAN_HAS_EGG, Gen2WorldDayCare.MAN_HAS_EGG)
	assert_eq([gold_world.day_care_mon(Gen2WorldDayCare.SLOT_MAN).species, gold_world.day_care_mon(Gen2WorldDayCare.SLOT_LADY).species],
		[Fixture.CUBONE, Fixture.CUBONE])
	assert_null(silver_world.day_care_egg(), "SILVER has none")
	assert_null(silver_world.day_care_mon(Gen2WorldDayCare.SLOT_MAN))
	assert_eq(silver_world.day_care_mon(Gen2WorldDayCare.SLOT_LADY).species, Fixture.HOOTHOOT)


func test_a_pokemon_keeps_its_uid_through_the_day_care() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var gold_window: PokeCoopWorldLink = _window(gold)
	for party_first: bool in [false, true]:
		var mon: Gen2SaveMon = _mon(Fixture.CUBONE, MALE_DVS if party_first else FEMALE_DVS, gold_window)
		var uid: String = _joined_party(gold_window, mon)
		assert_false(uid.is_empty(), "the host names it")
		assert_true(Gen2WorldDayCare.deposit(gold_window.state, gold_window.save, Gen2WorldDayCare.SLOT_MAN, 1))
		_handed_over(gold_window, party_first)
		assert_eq(_uid_of(gold_window, mon), "", "away from GOLD's team and PC")
		assert_eq(_kept(gold_window), [uid], "the host keeps its uid with GOLD's day care")

		assert_false(Gen2WorldDayCare.retrieve(gold_window.state, gold_window.save, _data, Gen2WorldDayCare.SLOT_MAN).is_empty())
		_handed_over(gold_window, party_first)
		var team: Array = _host.player(gold.player_id).team
		assert_eq([team.size(), String(team[1]["uid"]), (team[1]["mon"] as Gen2SaveMon).species], [2, uid, Fixture.CUBONE],
			"back under its own uid, the party's first: %s" % party_first)
		assert_eq(_kept(gold_window), [])
		gold_window.save.party.remove_at(1)
		gold_window.push_party()
		_pump()


func test_a_released_pokemon_is_not_kept_with_the_day_care() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var gold_window: PokeCoopWorldLink = _window(gold)
	var mon: Gen2SaveMon = _mon(Fixture.CUBONE, MALE_DVS, gold_window)
	_joined_party(gold_window, mon)
	gold_window.save.party.remove_at(1)
	gold_window.push_party()
	_pump()
	gold_window.save.party[0].hp -= 1
	gold_window.push_party()
	_pump()
	assert_eq(_kept(gold_window), [], "a Pokémon no day care holds is forgotten with the next party")


func test_a_pokemon_in_the_day_care_keeps_its_uid_across_a_save_and_a_new_host() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var gold_window: PokeCoopWorldLink = _window(gold)
	var mon: Gen2SaveMon = _mon(Fixture.CUBONE, MALE_DVS, gold_window)
	var uid: String = _joined_party(gold_window, mon)
	assert_true(Gen2WorldDayCare.deposit(gold_window.state, gold_window.save, Gen2WorldDayCare.SLOT_LADY, 1))
	_handed_over(gold_window, false)
	gold.request_save()
	_pump()

	var loaded: Dictionary = PokeCoopSave.read(SAVE_PATH)
	var id: String = gold.player_id
	_host.shutdown()
	_pump()
	_clients = []
	_links = []
	_host = _hosting(loaded["campaign"])
	_host.adopt_players(loaded["players"])
	var link := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, link, 1)
	var client: PokeCoopClient = PokeCoopClient.over(link)
	client.greet("", RomRegistry.GOLD, RomRegistry.sha1_for(RomRegistry.GOLD), id)
	_clients.append(client)
	_pump()
	var window: PokeCoopWorldLink = _window(client, PokeCoopWorldLink.continued_world(client).world_state)
	assert_eq(window.state.day_care_mon(Gen2WorldDayCare.SLOT_LADY).species, Fixture.CUBONE, "still with GOLD's lady")

	assert_false(Gen2WorldDayCare.retrieve(window.state, window.save, _data, Gen2WorldDayCare.SLOT_LADY).is_empty())
	_handed_over(window, false)
	assert_eq(_uid_of(window, mon), uid, "the uid came back with the saved campaign")


func test_a_hatched_egg_gets_a_uid_of_its_own() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var gold_window: PokeCoopWorldLink = _window(gold)
	_egg_waiting(gold_window)
	var parents: Array = _kept(gold_window)
	assert_eq(parents.size(), 2, "both parents' uids are kept")
	Gen2WorldDayCare.give_egg(gold_window.state, gold_window.save)
	gold_window.push_party()
	_pump()
	var egg: String = String(_host.player(gold.player_id).team[1]["uid"])
	assert_false(egg in parents, "the egg is a new Pokémon")
	assert_eq(_kept(gold_window), parents, "its parents stay in the day care")


func test_red_and_blues_day_care_gives_the_uid_back_too() -> void:
	var red_directory: String = RomCache.directory_for(&"coopjohtodaycarered", "0123456789abcdef")
	_data = Fixture.build(red_directory, "testgame", RomRegistry.GEN1)
	_host = _hosting(PokeCoopCampaign.create("red1", _data.id, _data.sha1))
	var link := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, link, 1)
	var red: PokeCoopClient = PokeCoopClient.over(link)
	red.greet("RED", _data.id, _data.sha1)
	_clients.append(red)
	_pump()
	var red_window: PokeCoopWorldLink = _window(red)
	var mon: Gen2SaveMon = _mon(Fixture.CUBONE, MALE_DVS, red_window)
	var uid: String = _joined_party(red_window, mon)
	assert_true(Gen2WorldDayCare.deposit(red_window.state, red_window.save, Gen2WorldDayCare.SLOT_MAN, 1))
	_handed_over(red_window, false)
	assert_eq(_kept(red_window), [uid], "Route 5's day care keeps it")
	assert_false(Gen2WorldDayCare.retrieve(red_window.state, red_window.save, _data, Gen2WorldDayCare.SLOT_MAN).is_empty())
	_handed_over(red_window, false)
	assert_eq(_uid_of(red_window, mon), uid)
	RomCache.clear(red_directory)


func test_a_gold_host_leaves_johto_flags_alone_that_red_and_blues_walks_share_a_number_with() -> void:
	var campaign := PokeCoopCampaign.create("gold2", _data.id, _data.sha1)
	for flag: int in PokeCoopPolicy.OWN_WALKS:
		campaign.flags[flag] = true
	_hosting(campaign)
	for flag: int in PokeCoopPolicy.OWN_WALKS:
		assert_true(campaign.has_flag(flag), "Johto's event %d stands" % flag)


func test_a_seed_fills_one_players_day_care_with_its_egg_a_step_from_hatching() -> void:
	var player := PokeCoopPlayer.create("p1", "GOLD", 17800)
	var cubone: String = String(_data.species(Fixture.CUBONE).get("name", ""))
	assert_eq(Seed._day_care(_data, player, PackedStringArray([cubone, "10", cubone, "12", "egg"])), "")
	var world: Gen2WorldState = Gen2WorldState.from_dict(player.world)
	assert_eq([world.day_care_mon(0).species, world.day_care_mon(1).species, world.day_care_mon(1).level], [Fixture.CUBONE, Fixture.CUBONE, 12])
	assert_eq(world.day_care_mon(0).original_trainer, "GOLD")
	assert_eq(world.day_care_man_flags() & Gen2WorldDayCare.MAN_HAS_EGG, Gen2WorldDayCare.MAN_HAS_EGG)
	assert_eq([world.day_care_egg().species, world.day_care_egg().happiness, world.step_count()], [Fixture.CUBONE, 1, Gen2WorldState.EGG_STEP_PHASE - 1])
	assert_ne(Seed._day_care(_data, player, PackedStringArray(["NOBODY", "5"])), "", "an unknown species is refused")
