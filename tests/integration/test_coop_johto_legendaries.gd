extends GutTest

## Johto's roaming beasts and story legendaries, one per player (#180, D128, D138), on the synthetic Generation 2
## fixture: a GOLD and a SILVER player in one Gold campaign, the world moved by patches as a window sends them.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const EVENT_RELEASED_THE_BEASTS: int = 123
const EVENT_BURNED_TOWER_B1F_BEASTS_1: int = 1866
const EVENT_BURNED_TOWER_B1F_BEASTS_2: int = 1867
const BURNED_TOWER_B1F_SCENE: String = "3:14"
const RELEASED: int = 1  ## SCENE_BURNEDTOWERB1F_NOOP
const RAIKOU: int = 243
const ENTEI: int = 244
const SUICUNE: int = 245
const EVENT_FOUGHT_SUDOWOODO: int = 42
const EVENT_ROUTE_36_SUDOWOODO: int = 1784
const SPRITE_WEIRD_TREE: int = 0xF4
const SPRITE_SUDOWOODO: int = 0x52
const SPRITE_TWIN: int = 0x26
const LEGENDARIES: Dictionary = {  ## each one-off's fought flag and the flag that hides it
	"HO-OH": [791, 1852], "LUGIA": [792, 1853], "SNORLAX": [1872, 1904], "red GYARADOS": [1873], "LAPRAS": [1888],
}
const EVENT_LAKE_OF_RAGE_RED_GYARADOS: int = 1873
const EVENT_LAKE_OF_RAGE_LANCE: int = 0x6D4
const EVENT_DECIDED_TO_HELP_LANCE: int = 96
const RED_SCALE: int = 66

var _directory: String = ""
var _data: GameData = null
var _host: PokeCoopHost = null
var _clients: Array = []


func before_each() -> void:
	_directory = RomCache.directory_for(&"coopjohtolegendtest", "0123456789abcdef")
	_data = Fixture.build(_directory, String(RomRegistry.GOLD), RomRegistry.GEN2)
	_data.sha1 = RomRegistry.sha1_for(RomRegistry.GOLD)
	_clients = []
	_host = PokeCoopHost.create(_data, PokeCoopCampaign.create("johto1", _data.id, _data.sha1), PokeCoopTransport.new())
	_host.allow_new_players = true
	PokeCoopPolicy.start_campaign(_host.campaign, _data)


func after_each() -> void:
	RomCache.clear(_directory)


func _join(peer: int, player_name: String, game: StringName) -> PokeCoopClient:
	var link := PokeCoopTransport.new()
	PokeCoopTransport.link(_host.transport, link, peer)
	var client: PokeCoopClient = PokeCoopClient.over(link)
	client.greet(player_name, game, RomRegistry.sha1_for(game))
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


static func _setting(entries: Dictionary) -> Dictionary:
	return {"set": entries, "erase": []}


func _world(client: PokeCoopClient) -> Gen2WorldState:
	return Gen2WorldState.from_dict(PokeCoopWorldLink._host_world(client))


func _roamers(client: PokeCoopClient) -> Array:
	return _world(client).roaming_mons().map(func(mon: Dictionary) -> int: return int(mon.get("species", 0)))


## What a window sends after `ReleaseTheBeasts`: the scene, its flags and `InitRoamMons`' three beasts.
func _release(client: PokeCoopClient, map: Vector2i) -> void:
	var beasts: Array = [RAIKOU, ENTEI, SUICUNE].map(func(species: int) -> Dictionary:
		return {"species": species, "level": 40, "map_group": map.x, "map_number": map.y, "hp": 0, "dvs": 0})
	_send_world(client, {
		"event_flags": _setting({EVENT_RELEASED_THE_BEASTS: true, EVENT_BURNED_TOWER_B1F_BEASTS_1: true,
			EVENT_BURNED_TOWER_B1F_BEASTS_2: true}),
		"map_scenes": _setting({BURNED_TOWER_B1F_SCENE: RELEASED}),
		"roaming_mons": {"value": beasts},
	})


func test_each_player_releases_their_own_beasts_and_a_roamer_one_catches_still_roams_for_the_other() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)

	_release(gold, Vector2i(10, 1))
	var waiting: Gen2WorldState = _world(silver)
	assert_false(waiting.is_event_flag_active(EVENT_RELEASED_THE_BEASTS), "SILVER's beasts have not fled yet")
	assert_false(waiting.is_event_flag_active(EVENT_BURNED_TOWER_B1F_BEASTS_2), "they still stand in SILVER's Burned Tower")
	assert_ne(waiting.map_scene(3, 14), RELEASED, "and stepping in front of them releases them in SILVER's window")
	assert_eq(_roamers(silver).filter(func(species: int) -> bool: return species > 0), [], "GOLD's beasts roam GOLD's world only")
	assert_false(_host.campaign.world.has("roaming_mons"), "the campaign holds no roamer")

	_release(silver, Vector2i(10, 2))
	var gone: Array = _world(gold).roaming_mons()
	gone[0] = {"species": 0, "level": 0, "map_group": -1, "map_number": -1, "hp": 0, "dvs": 0}
	_send_world(gold, {"roaming_mons": {"value": gone}})

	assert_eq(_roamers(gold), [0, ENTEI, SUICUNE], "GOLD caught GOLD's RAIKOU")
	assert_eq(_roamers(silver), [RAIKOU, ENTEI, SUICUNE], "SILVER's RAIKOU still roams")
	assert_eq(int(_world(silver).roaming_mons()[0]["map_number"]), 2, "where SILVER's walk put it")


func test_a_story_legendary_one_player_fights_still_stands_in_the_others_world() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)

	_send_world(gold, {
		"event_flags": _setting({EVENT_FOUGHT_SUDOWOODO: true, EVENT_ROUTE_36_SUDOWOODO: true}),
		"variable_sprites": _setting({SPRITE_WEIRD_TREE: SPRITE_TWIN}),
	})
	var standing: Gen2WorldState = _world(silver)
	assert_false(standing.is_event_flag_active(EVENT_ROUTE_36_SUDOWOODO), "SUDOWOODO still blocks SILVER's Route 36")
	assert_false(standing.is_event_flag_active(EVENT_FOUGHT_SUDOWOODO))
	assert_eq(standing.variable_sprite(SPRITE_WEIRD_TREE), SPRITE_SUDOWOODO, "and is drawn as SUDOWOODO, not the TWIN")
	assert_true(_world(gold).is_event_flag_active(EVENT_ROUTE_36_SUDOWOODO), "GOLD's path is clear")
	assert_ne(int((_host.campaign.world.get("variable_sprites", {}) as Dictionary).get(SPRITE_WEIRD_TREE, 0)), SPRITE_TWIN,
		"the TWIN stands in only where the tree is gone")

	for one_off: String in LEGENDARIES:
		var flags: Dictionary = {}
		for flag: int in LEGENDARIES[one_off]:
			flags[flag] = true
		_send_world(gold, {"event_flags": _setting(flags)})
		for flag: int in LEGENDARIES[one_off]:
			assert_true(_world(gold).is_event_flag_active(flag), "%s: GOLD's %d" % [one_off, flag])
			assert_false(_world(silver).is_event_flag_active(flag), "%s waits for SILVER: %d" % [one_off, flag])
			assert_false(_host.campaign.has_flag(flag), "%s is no campaign flag: %d" % [one_off, flag])


func test_each_red_gyarados_hands_its_own_red_scale_and_lance_stays_gone_once_the_team_helped_him() -> void:
	var gold: PokeCoopClient = _join(1, "GOLD", RomRegistry.GOLD)
	var silver: PokeCoopClient = _join(2, "SILVER", RomRegistry.SILVER)
	_send_world(gold, {"event_flags": _setting({EVENT_LAKE_OF_RAGE_LANCE: true})})

	_send_world(gold, {
		"event_flags": {"set": {EVENT_LAKE_OF_RAGE_RED_GYARADOS: true}, "erase": [EVENT_LAKE_OF_RAGE_LANCE]},
		"items": _setting({RED_SCALE: 1}),
	})
	assert_false(_host.campaign.has_flag(EVENT_LAKE_OF_RAGE_LANCE), "LANCE comes to the lake for the team")
	assert_eq(_host.player(silver.player_id).item_count(RED_SCALE), 0, "the RED SCALE is the GYARADOS's, and SILVER's waits")

	_send_world(gold, {"event_flags": _setting({EVENT_LAKE_OF_RAGE_LANCE: true, EVENT_DECIDED_TO_HELP_LANCE: true})})
	_send_world(silver, {
		"event_flags": {"set": {EVENT_LAKE_OF_RAGE_RED_GYARADOS: true}, "erase": [EVENT_LAKE_OF_RAGE_LANCE]},
		"items": _setting({RED_SCALE: 1}),
	})
	assert_true(_host.campaign.has_flag(EVENT_LAKE_OF_RAGE_LANCE), "LANCE, gone to Mahogany, does not come back for SILVER's")
	assert_eq(_host.player(silver.player_id).item_count(RED_SCALE), 1, "SILVER's own GYARADOS's RED SCALE")
	assert_eq(_host.player(gold.player_id).item_count(RED_SCALE), 1, "and no second one for GOLD")
