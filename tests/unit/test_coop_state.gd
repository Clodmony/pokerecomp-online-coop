extends GutTest

## Co-op campaign and player state: what is shared, what each player keeps for
## themselves, and how both survive a save.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const SAVE_PATH: String = "user://coop_state_test.json"
const STORY_FLAG: int = 0x77
const PALLET: Vector2i = Vector2i(0, 0)
const ROUTE_1: Vector2i = Vector2i(0, 12)

var _directory: String = ""
var _data: GameData = null


func before_each() -> void:
	_directory = RomCache.directory_for(&"coopstatetest", "0123456789abcdef")
	_data = Fixture.build(_directory, "testgame", RomRegistry.GEN1)


func after_each() -> void:
	RomCache.clear(_directory)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _saved(species: int, level: int) -> Gen2SaveMon:
	return Gen2SaveBattleAdapter.from_battle_mon(
		Gen2BattleMon.create(_data, species, level, [Fixture.TACKLE])
	)


func test_a_progress_commit_applies_once_however_often_it_arrives() -> void:
	var campaign := PokeCoopCampaign.create("c1", &"testgame", "sha")
	var changes: Dictionary = {"flags": [STORY_FLAG], "badges": 1, "defeated": ["trainer:brock"]}

	assert_true(campaign.commit("victory:trainer:brock", changes))
	var revision: int = campaign.revision
	assert_false(campaign.commit("victory:trainer:brock", changes), "a repeat is refused")
	assert_eq(campaign.revision, revision, "and moves nothing")
	assert_true(campaign.has_flag(STORY_FLAG))
	assert_true(campaign.has_badge(0))
	assert_eq(campaign.encounter_state("trainer:brock"), PokeCoopCampaign.ENCOUNTER_DONE)


func test_a_unique_encounter_has_one_active_instance_per_campaign() -> void:
	var campaign := PokeCoopCampaign.create("c1", &"testgame", "sha")
	assert_true(campaign.claim_encounter("trainer:brock", "b1"))
	assert_false(campaign.claim_encounter("trainer:brock", "b2"), "taken while b1 fights it")
	campaign.release_encounter("trainer:brock", "b2")
	assert_eq(campaign.encounter_state("trainer:brock"), PokeCoopCampaign.ENCOUNTER_ACTIVE,
		"only the battle holding it lets it go")
	campaign.release_encounter("trainer:brock", "b1")
	assert_true(campaign.claim_encounter("trainer:brock", "b3"), "free again after a loss")
	campaign.commit("victory:trainer:brock", {"defeated": ["trainer:brock"]})
	assert_false(campaign.claim_encounter("trainer:brock", "b4"), "beaten for good")


func test_a_team_holds_six_and_a_uid_is_never_handed_out_twice() -> void:
	var player := PokeCoopPlayer.create("p1", "RED", 100)
	var uids: Dictionary = {}
	for _slot: int in PokeCoopPlayer.MAX_TEAM:
		uids[player.add_mon(_saved(Fixture.PIKACHU, 5))] = true
	assert_eq(player.add_mon(_saved(Fixture.PIKACHU, 5)), "", "a seventh is refused")
	uids[player.store_mon(_saved(Fixture.PIKACHU, 5))] = true

	var reloaded: PokeCoopPlayer = PokeCoopPlayer.from_dict(player.to_dict())
	uids[reloaded.store_mon(_saved(Fixture.PIKACHU, 5))] = true

	assert_eq(uids.size(), PokeCoopPlayer.MAX_TEAM + 2, "every uid distinct, across a reload")
	assert_false(uids.has(""))


func test_players_share_story_flags_but_not_their_places_bags_or_money() -> void:
	var campaign := PokeCoopCampaign.create("c1", &"testgame", "sha")
	var red := PokeCoopPlayer.create("p1", "RED", 100)
	var blue := PokeCoopPlayer.create("p2", "BLUE", 200)
	red.place(PALLET, Vector2i(5, 6), 0)
	blue.place(ROUTE_1, Vector2i(9, 3), 1)
	red.give_item(Fixture.POTION, 2)

	campaign.commit("victory:trainer:rival", {"flags": [STORY_FLAG]})
	red.add_money(500)

	assert_true(campaign.has_flag(STORY_FLAG), "one campaign flag for both")
	assert_eq(blue.map, ROUTE_1, "neither player moved the other")
	assert_eq(red.map, PALLET)
	assert_eq(blue.item_count(Fixture.POTION), 0)
	assert_eq(blue.money, 0)


func test_a_campaign_save_brings_back_both_players_and_the_shared_progress() -> void:
	var campaign := PokeCoopCampaign.create("c1", _data.id, _data.sha1)
	campaign.commit("victory:trainer:brock", {"flags": [STORY_FLAG], "badges": 1,
		"defeated": ["trainer:brock"]})
	var red := PokeCoopPlayer.create("p1", "RED", 100)
	red.add_mon(_saved(Fixture.CHARMANDER, 12))
	red.give_item(Fixture.POTION, 3)
	red.add_money(1234)
	red.place(PALLET, Vector2i(5, 6), 2)
	var blue := PokeCoopPlayer.create("p2", "BLUE", 200)
	blue.add_mon(_saved(Fixture.BULBASAUR, 7))
	blue.place(ROUTE_1, Vector2i(9, 3), 1)

	assert_eq(PokeCoopSave.write(SAVE_PATH, campaign, [blue, red]), OK)
	var loaded: Dictionary = PokeCoopSave.read(SAVE_PATH)

	assert_false(loaded.is_empty())
	assert_eq(
		PokeCoopSave.to_dict(loaded["campaign"], loaded["players"]),
		PokeCoopSave.to_dict(campaign, [red, blue])
	)


func test_a_save_from_a_newer_format_or_another_program_is_refused() -> void:
	var campaign := PokeCoopCampaign.create("c1", &"testgame", "sha")
	var newer: Dictionary = PokeCoopSave.to_dict(campaign, [])
	newer["format_version"] = PokeCoopSave.FORMAT_VERSION + 1
	var foreign: Dictionary = PokeCoopSave.to_dict(campaign, [])
	foreign["kind"] = "something-else"

	assert_true(PokeCoopSave.from_dict(newer).is_empty())
	assert_true(PokeCoopSave.from_dict(foreign).is_empty())
