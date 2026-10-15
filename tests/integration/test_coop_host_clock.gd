extends GutTest

## The host's clock for every window (#175, D133): a Gold campaign keeps one clock, every
## window opens on it and follows it, it runs on while the campaign is closed, and only
## the hosting player sets it. Sessions on the synthetic Generation 2 fixture over the
## in-memory transport; world screens on the synthetic world cache.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const WorldFixture := preload("res://tests/integration/world_trainer_fixture.gd")
const SAVE_PATH: String = "user://coop_host_clock_test.json"
const WORLD_GAME: StringName = &"coophostclock"
const T0: float = 1_800_000_000.0
const FRIDAY: int = 5
const NIGHT: Dictionary = {"day": FRIDAY, "hour": 21, "minute": 30, "second": 20}

var _directory: String = ""
var _data: GameData = null
var _host: PokeCoopHost = null
var _clients: Array = []
var _screens: Array = []


func before_each() -> void:
	Gen2WorldClock.host_seconds_override = T0
	PokeCoopJohto.first_reading = NIGHT
	_directory = RomCache.directory_for(&"coophostclocktest", "0123456789abcdef")
	_data = Fixture.build(_directory, String(RomRegistry.GOLD), RomRegistry.GEN2)
	_data.sha1 = RomRegistry.sha1_for(RomRegistry.GOLD)
	_clients = []
	_screens = []
	_host = _hosting(PokeCoopCampaign.create("gold1", _data.id, _data.sha1))


func after_each() -> void:
	for screen: Gen2WorldScreen in _screens:
		if is_instance_valid(screen):
			screen.free()
	Gen2WorldClock.host_seconds_override = -1.0
	PokeCoopJohto.first_reading = {}
	RomCache.clear(WorldFixture.directory(WORLD_GAME))
	RomCache.clear(_directory)
	for path: String in [SAVE_PATH, SAVE_PATH + PokeCoopSave.BACKUP_SUFFIX, SAVE_PATH + PokeCoopSave.JOURNAL_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _hosting(campaign: PokeCoopCampaign, data: GameData = _data) -> PokeCoopHost:
	var host: PokeCoopHost = PokeCoopHost.create(data, campaign, PokeCoopTransport.new())
	host.save_path = SAVE_PATH
	host.allow_new_players = true
	return host


func _join(peer: int, player_name: String, game: StringName, id: String = "") -> PokeCoopClient:
	var link := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, link, peer)
	var client: PokeCoopClient = PokeCoopClient.over(link)
	client.greet(player_name, game, RomRegistry.sha1_for(game), id)
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


## The host's second moves on to [param seconds] after T0, and every window is told.
func _at(seconds: float) -> void:
	Gen2WorldClock.host_seconds_override = T0 + seconds
	_host.broadcast()
	_pump()


static func _time(reading: Dictionary) -> Array:
	return [int(reading.get("day", -1)), int(reading.get("hour", -1)), int(reading.get("minute", -1))]


func _pair() -> Array:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)
	_host.host_player_id = gold.player_id
	return [gold, silver]


func _reopen(ids: Array, seconds: float) -> Array:
	_host.shutdown()
	_pump()
	_clients = []
	var loaded: Dictionary = PokeCoopSave.read(SAVE_PATH)
	assert_false(loaded.is_empty(), "the campaign was written")
	Gen2WorldClock.host_seconds_override = T0 + seconds
	_host = _hosting(loaded["campaign"])
	_host.adopt_players(loaded["players"])
	var gold: PokeCoopClient = _join(1, "", RomRegistry.GOLD, ids[0])
	var silver: PokeCoopClient = _join(2, "", RomRegistry.SILVER, ids[1])
	_host.host_player_id = gold.player_id
	return [gold, silver]


## A window as the session opens one: the world's snapshot on the host's clock, a link following it.
func _window(client: PokeCoopClient) -> Array:
	var world_data: GameData = WorldFixture.build(WORLD_GAME)
	var world := Gen2WorldAPI.open(
		world_data, WorldFixture.MAP_GROUP, WorldFixture.MAP_NUMBER, Vector2i(7, 6), Gen2WorldState.new()
	)
	var save := Gen2SaveStore.create_development_save(world_data, 0)
	save.world = world.snapshot()
	PokeCoopWorldLink.on_host_clock(save.world, client)
	var screen: Gen2WorldScreen = (load("res://game/world/world_screen.tscn") as PackedScene).instantiate() as Gen2WorldScreen
	screen.map_group = WorldFixture.MAP_GROUP
	screen.map_number = WorldFixture.MAP_NUMBER
	screen.start_cell = Vector2i(7, 6)
	screen.set_data(world_data)
	screen.set_save(save)
	add_child(screen)
	_screens.append(screen)
	var opened: Gen2WorldAPI = screen.get("_world")
	var link: PokeCoopWorldLink = PokeCoopWorldLink.over(client, opened.state, save, _data)
	link.world = opened
	return [screen, link]


static func _shown(screen: Gen2WorldScreen) -> Array:
	var clock: Gen2WorldClock = screen.get("_clock")
	return [clock.day, clock.hour, clock.minute]


func test_a_gold_campaign_keeps_one_clock_and_red_and_blue_none() -> void:
	assert_eq(_time(PokeCoopJohto.reading(_host.campaign.clock, T0)), _time(NIGHT), "started where the host's time is")
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	assert_eq(_time(gold.clock()), _time(NIGHT), "and told to every window")

	var red_directory: String = RomCache.directory_for(&"coophostclockred", "0123456789abcdef")
	var red_data: GameData = Fixture.build(red_directory, "testgame", RomRegistry.GEN1)
	_clients = []
	_host = _hosting(PokeCoopCampaign.create("red1", red_data.id, red_data.sha1), red_data)
	var link := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, link, 1)
	var red: PokeCoopClient = PokeCoopClient.over(link)
	red.greet("RED", red_data.id, red_data.sha1)
	_clients.append(red)
	_pump()
	assert_ne(red.player_id, "")
	assert_eq(_host.campaign.clock, {}, "Red and Blue have no clock")
	assert_false(red.state.has("clock"))
	assert_eq(red.clock(), {})
	assert_false(_host.campaign.to_dict().has("clock"), "nor does their campaign file")
	assert_eq(_time({"day": PokeCoopWorldLink.continued_world(red).world_day, "hour": PokeCoopWorldLink.continued_world(red).world_hour,
		"minute": PokeCoopWorldLink.continued_world(red).world_minute}), [0, 6, 0], "their window opens as it always did")
	RomCache.clear(red_directory)


func test_two_windows_join_on_the_hosts_weekday_and_time() -> void:
	var pair: Array = _pair()
	for client: PokeCoopClient in pair:
		var world: Gen2WorldSnapshot = PokeCoopWorldLink.continued_world(client)
		assert_eq([world.world_day, world.world_hour, world.world_minute], _time(NIGHT), "%s opens on FRIDAY 9:30 PM" % client.player_id)

	_at(5 * 3600.0)
	for client: PokeCoopClient in pair:
		assert_eq(_time(client.clock()), [FRIDAY + 1, 2, 30], "five hours on, both are past midnight into SATURDAY")
		assert_eq(int(client.clock()["cur_day"]), FRIDAY + 1, "a day has passed for both")


func test_two_world_screens_show_the_hosts_night_and_follow_it() -> void:
	var pair: Array = _pair()
	var windows: Array = [_window(pair[0]), _window(pair[1])]
	await get_tree().process_frame
	for window: Array in windows:
		(window[1] as PokeCoopWorldLink).follow_clock(window[0], window == windows[0])
		assert_eq(_shown(window[0]), _time(NIGHT))
		assert_eq((window[0] as Gen2WorldScreen).time_of_day, Gen2WorldPalette.TIME_NIGHT, "drawn at night")

	_at(61 * 60.0)
	for window: Array in windows:
		(window[1] as PokeCoopWorldLink).follow_clock(window[0], window == windows[0])
		assert_eq(_shown(window[0]), [FRIDAY, 22, 31], "an hour and a minute later in both")

	(pair[0] as PokeCoopClient).set_clock(-1, 8, 0)
	_pump()
	for window: Array in windows:
		(window[1] as PokeCoopWorldLink).follow_clock(window[0], window == windows[0])
		assert_eq(_shown(window[0]), [FRIDAY, 8, 0], "the host's player set the clock back to the morning")
		assert_eq((window[0] as Gen2WorldScreen).time_of_day, Gen2WorldPalette.TIME_MORNING)


func test_a_weekday_the_hosting_players_world_sets_reaches_the_other_window() -> void:
	var pair: Array = _pair()
	var windows: Array = [_window(pair[0]), _window(pair[1])]
	await get_tree().process_frame
	for window: Array in windows:
		(window[1] as PokeCoopWorldLink).follow_clock(window[0], window == windows[0])
	for at: int in 2:
		var screen: Gen2WorldScreen = windows[at][0]
		var world: Gen2WorldAPI = screen.get("_world")
		world.set_world_clock(2 + at, 21, 30, world.world_cur_day)
		screen.call(&"_sync_host_clock")

	(windows[1][1] as PokeCoopWorldLink).follow_clock(windows[1][0], false)
	assert_eq(_shown(windows[1][0]), _time(NIGHT), "a joiner's own SetDayOfWeek is put back")
	(windows[0][1] as PokeCoopWorldLink).follow_clock(windows[0][0], true)
	_pump()
	assert_eq(_time((pair[1] as PokeCoopClient).clock()), [2, 21, 30], "the hosting player's is the campaign's")
	for window: Array in windows:
		(window[1] as PokeCoopWorldLink).follow_clock(window[0], window == windows[0])
		assert_eq(_shown(window[0]), [2, 21, 30], "TUESDAY in both windows")


func test_after_a_reopen_both_windows_are_on_the_clock_that_ran_while_it_was_closed() -> void:
	var pair: Array = _pair()
	assert_eq(_host.save_checkpoint(), &"")
	var later: float = 3 * 86400.0 + 4 * 3600.0 + 10 * 60.0
	var back: Array = _reopen([pair[0].player_id, pair[1].player_id], later)

	for client: PokeCoopClient in back:
		assert_eq(_time(client.clock()), [2, 1, 40], "FRIDAY 9:30 PM and three days, four hours and ten minutes: TUESDAY 1:40 AM")
		assert_eq(int(client.clock()["cur_day"]), FRIDAY + 4)
		var world: Gen2WorldSnapshot = PokeCoopWorldLink.continued_world(client)
		assert_eq([world.world_day, world.world_hour, world.world_minute], [2, 1, 40], "where %s's window opens" % client.player_id)
	var windows: Array = [_window(back[0]), _window(back[1])]
	await get_tree().process_frame
	for window: Array in windows:
		(window[1] as PokeCoopWorldLink).follow_clock(window[0], window == windows[0])
		assert_eq(_shown(window[0]), [2, 1, 40])
		assert_eq((window[0] as Gen2WorldScreen).time_of_day, Gen2WorldPalette.TIME_NIGHT)


func test_a_saved_clock_reads_back_as_the_host_holds_it() -> void:
	Gen2WorldClock.host_seconds_override = T0 + 0.123456789
	_host = _hosting(PokeCoopCampaign.create("gold2", _data.id, _data.sha1))
	_pair()
	_at(12.987654321)
	assert_eq(_host.save_checkpoint(), &"")
	_host.broadcast()
	var loaded: Dictionary = PokeCoopSave.read(SAVE_PATH)
	assert_eq(PokeCoopSave.to_dict(loaded["campaign"], loaded["players"]), PokeCoopSave.to_dict(_host.campaign, _host.players.values()),
		"the file is the host's campaign, clock and all (demo gold's last step)")


func test_a_host_clock_put_back_does_not_run_the_world_backwards() -> void:
	var pair: Array = _pair()
	assert_eq(_host.save_checkpoint(), &"")
	var back: Array = _reopen([pair[0].player_id, pair[1].player_id], -2 * 3600.0)
	for client: PokeCoopClient in back:
		assert_eq(_time(client.clock()), _time(NIGHT), "two hours before it was saved reads as no time at all")

	_at(-2 * 3600.0 + 10 * 60.0)
	for client: PokeCoopClient in back:
		assert_eq(_time(client.clock()), [FRIDAY, 21, 40], "and runs on from there")


func test_only_the_hosting_player_sets_the_clock() -> void:
	var pair: Array = _pair()
	var silver: PokeCoopClient = pair[1]
	silver.set_clock(-1, 8, 0)
	_pump()
	assert_eq(silver.last_rejection(), &"not_host")
	assert_eq(_time(silver.clock()), _time(NIGHT))

	(pair[0] as PokeCoopClient).set_clock(-1, 8, 15)
	_pump()
	assert_eq(_time(silver.clock()), [FRIDAY, 8, 15], "the opening's time keeps the weekday")
	(pair[0] as PokeCoopClient).set_clock(3, -1, -1)
	_pump()
	assert_eq(_time(silver.clock()), [3, 8, 15], "Mom's weekday keeps the time")
	assert_eq(int(silver.clock()["cur_day"]), FRIDAY, "and moves no day")


func test_a_joiners_opening_asks_no_time_and_the_hosts_tells_it() -> void:
	var told: Array = []
	for asks: bool in [false, true]:
		var intro := Gen2IntroScreen.new()
		intro.writes_save = false
		intro.asks_clock = asks
		intro.clock_set.connect(func(day: int, hour: int, minute: int) -> void: told.append([day, hour, minute]))
		add_child_autofree(intro)
		intro.begin(WorldFixture.build(WORLD_GAME), 0, "", false)
		_settle_splash(intro)
		intro.handle_button(PokeButton.A)
		_settle(intro)
		if not asks:
			assert_true(intro.current() is Gen2OakSpeechScreen, "a joiner goes from the gender question to Oak's speech")
			continue
		assert_true(intro.current() is Gen2ClockSetScreen, "the hosting player is asked the time")
		for _step: int in 12:
			_settle(intro)
			if not (intro.current() is Gen2ClockSetScreen):
				break
			intro.handle_button(PokeButton.A)
		assert_true(intro.current() is Gen2OakSpeechScreen)
	assert_eq(told, [[0, 10, 0]], "and the time set is told once")
	await get_tree().process_frame


static func _settle_splash(intro: Gen2IntroScreen) -> void:
	var splash: Gen2SplashScreen = intro.current() as Gen2SplashScreen
	for _frame: int in 800:
		if intro.current() != splash:
			return
		splash.advance_frames(1)


static func _settle(intro: Gen2IntroScreen) -> void:
	for _step: int in 40:
		var owed: int = intro.animation_frames_left()
		if owed == 0:
			return
		intro.advance_frames(owed)
