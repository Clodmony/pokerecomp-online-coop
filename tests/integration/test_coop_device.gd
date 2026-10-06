extends GutTest

## A co-op session as a device runs one, over real localhost sockets: hosting
## starts or loads the campaign and plays on it, a second device joins, and a
## device that comes back is the same player it was.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const PORT: int = 24791
const IDENTITY: String = "user://coop_device_test_identity.json"
const WAIT_MSEC: int = 3000

var _directory: String = ""
var _data: GameData = null
var _identity_before: String = ""
var _sessions: Array = []


func before_each() -> void:
	_directory = RomCache.directory_for(&"coopdevicetest", "0123456789abcdef")
	_data = Fixture.build(_directory, "testgame", RomRegistry.GEN1)
	_identity_before = PokeCoopSession.identity_path
	PokeCoopSession.identity_path = IDENTITY
	_sessions = []


func after_each() -> void:
	for session: PokeCoopSession in _sessions:
		session.close()
	PokeCoopSession.identity_path = _identity_before
	for path: String in [IDENTITY, PokeCoopSession.campaign_path(_data)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	RomCache.clear(_directory)


func _until_ready(wanted: Array) -> bool:
	var deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < deadline:
		for session: PokeCoopSession in _sessions:
			session.process()
		if wanted.all(func(session: PokeCoopSession) -> bool: return session.is_ready()):
			return true
		OS.delay_msec(5)
	return false


func test_a_device_hosts_and_another_joins_with_their_own_starters() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	_sessions.append(hosting)
	var joining: PokeCoopSession = PokeCoopSession.joining(
		_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR
	)
	_sessions.append(joining)

	assert_true(_until_ready([hosting, joining]), "both answered within %d ms" % WAIT_MSEC)
	assert_eq(int(hosting.client.me()["team"][0]["species"]), Fixture.CHARMANDER)
	assert_eq(int(joining.client.me()["team"][0]["species"]), Fixture.BULBASAUR)
	assert_true(hosting.host.campaign.has_flag(0x22), "a new campaign starts after Oak's intro")


func _until(condition: Callable, wait_msec: int) -> bool:
	var deadline: int = Time.get_ticks_msec() + wait_msec
	while Time.get_ticks_msec() < deadline:
		for session: PokeCoopSession in _sessions:
			session.process()
		if condition.call():
			return true
		OS.delay_msec(5)
	return false


func test_a_device_whose_link_drops_comes_back_on_its_own() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	_sessions.append(hosting)
	var joining: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR)
	_sessions.append(joining)
	assert_true(_until_ready([hosting, joining]))
	var blue_id: String = joining.client.player_id

	joining.client.transport.close()

	assert_true(_until(func() -> bool:
		return joining.client.connected and hosting.host.player(blue_id).connected, 10000
	), "the device dialled again and the host took the same player back")
	assert_eq(joining.client.player_id, blue_id)
	assert_eq(hosting.host.players.size(), 2)


func test_a_device_that_comes_back_is_the_same_player() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	_sessions.append(hosting)
	var first: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR)
	_sessions.append(first)
	assert_true(_until_ready([hosting, first]))
	var blue_id: String = first.client.player_id
	first.close()
	_sessions.erase(first)

	var again: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", 0)
	_sessions.append(again)
	assert_true(_until_ready([again]), "the host let the same player back in")

	assert_eq(again.client.player_id, blue_id)
	assert_eq(hosting.host.players.size(), 2, "nobody new was made")


func test_a_host_that_leaves_saves_the_campaign_and_tells_the_others() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	_sessions.append(hosting)
	var joining: PokeCoopSession = PokeCoopSession.joining(_data, "127.0.0.1", PORT, "BLUE", Fixture.BULBASAUR)
	_sessions.append(joining)
	assert_true(_until_ready([hosting, joining]))

	hosting.leave()

	assert_true(_until(func() -> bool:
		return hosting.host.ended and joining.ended_reason() == "host_shutdown", WAIT_MSEC
	), "the joining device heard why the session ended")
	assert_false(hosting.is_ready(), "a session that was left does not open its world again")
	var saved: Dictionary = PokeCoopSave.read(PokeCoopSession.campaign_path(_data))
	assert_eq((saved.get("players", []) as Array).size(), 2, "both players are in the saved campaign")


func test_a_hosting_device_sent_to_the_background_keeps_the_campaign() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	_sessions.append(hosting)
	assert_true(_until_ready([hosting]))
	if FileAccess.file_exists(PokeCoopSession.campaign_path(_data)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PokeCoopSession.campaign_path(_data)))

	hosting.suspend()

	var saved: Dictionary = PokeCoopSave.read(PokeCoopSession.campaign_path(_data))
	assert_eq((saved.get("players", []) as Array).size(), 1, "the host's player is in the saved campaign")


## A single-player save of the fixture cartridge: [param species] in the party,
## a Pidgey in box 3, a story flag, two potions and 1234 money; the fixture has no maps to stand on.
func _single_player_save(trainer: String, species: int) -> Gen2SaveData:
	var save := Gen2SaveData.new()
	save.game_id = _data.id
	save.rom_sha1 = _data.sha1
	save.slot = 0
	save.player_name = trainer
	save.run_rules = Gen2Rules.new()
	for at: int in [species, Fixture.PIKACHU]:
		var mon: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(
			Gen2BattleMon.create(_data, at, 10, [Fixture.TACKLE])
		)
		if at == species:
			save.party.append(mon)
		else:
			(save.boxes[3] as Gen2SaveBox).put(mon)
	save.current_box = 3
	save.world = Gen2WorldSnapshot.new()
	save.world.world_state.set_event_flag(0x77)
	save.world.world_state.apply_changes({}, {}, {"items": {Fixture.POTION: 2}, "money": {0: 1234}})
	return save


func test_a_campaign_hosted_from_a_save_takes_its_story_and_its_trainer() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(
		_data, PORT, "RED", 0, _single_player_save("RED", Fixture.CHARMANDER)
	)
	_sessions.append(hosting)
	var joining: PokeCoopSession = PokeCoopSession.joining(
		_data, "127.0.0.1", PORT, "BLUE", 0, "", _single_player_save("BLUE", Fixture.BULBASAUR)
	)
	_sessions.append(joining)
	assert_true(_until_ready([hosting, joining]))

	var red: PokeCoopPlayer = hosting.host.player(hosting.client.player_id)
	assert_true(hosting.host.campaign.has_flag(0x77), "the first player's save brought the story")
	assert_eq(red.team[0]["mon"].species, Fixture.CHARMANDER)
	assert_eq([red.box.size(), int(red.box[0]["box"]), red.current_box], [1, 3, 3], "the PC came along")
	assert_eq([red.item_count(Fixture.POTION), red.money], [2, 1234])
	var blue: PokeCoopPlayer = hosting.host.player(joining.client.player_id)
	assert_eq(blue.team[0]["mon"].species, Fixture.BULBASAUR, "a later player brings their trainer only")
	assert_eq(blue.money, 1234)


func test_a_full_pc_reaches_its_window_over_real_sockets() -> void:
	var hosting: PokeCoopSession = PokeCoopSession.hosting(_data, PORT, "RED", Fixture.CHARMANDER)
	_sessions.append(hosting)
	assert_true(_until_ready([hosting]))
	var red: PokeCoopPlayer = hosting.host.player(hosting.client.player_id)
	for count: int in 200:
		red.store_mon(Gen2SaveBattleAdapter.from_battle_mon(
			Gen2BattleMon.create(_data, Fixture.PIKACHU, 5 + count % 40, [Fixture.TACKLE])
		))

	hosting.host.broadcast()

	assert_true(_until(func() -> bool:
		return (hosting.client.box.get("rows", []) as Array).size() == 200, WAIT_MSEC
	), "two hundred stored Pokémon arrived in one box message")
