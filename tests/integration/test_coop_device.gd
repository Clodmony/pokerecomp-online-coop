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
