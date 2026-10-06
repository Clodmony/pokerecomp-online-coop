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


func test_a_fresh_campaign_begins_after_oaks_intro() -> void:
	var campaign := PokeCoopCampaign.create("c1", &"red", "sha")
	PokeCoopPolicy.start_campaign(campaign)

	assert_true(campaign.has_flag(0x00), "EVENT_FOLLOWED_OAK_INTO_LAB: the north exit stays open")
	assert_true(campaign.has_flag(0x22), "EVENT_GOT_STARTER: the lab hands out no second one")


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
	blue.current_box = 4
	blue.store_mon(_saved(Fixture.PIKACHU, 3))

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


func test_a_pc_fills_the_current_box_then_the_next_with_room() -> void:
	var red := PokeCoopPlayer.create("p1", "RED", 100)
	red.current_box = PokeCoopPlayer.BOXES - 1
	for _mon: int in PokeCoopPlayer.BOX_CAPACITY + 1:
		red.store_mon(_saved(Fixture.PIKACHU, 3))
	assert_eq(int(red.box[0]["box"]), PokeCoopPlayer.BOXES - 1)
	assert_eq(int(red.box[-1]["box"]), 0, "a full current box sends the next one to the first with room")

	var older: Dictionary = red.to_dict()
	for row: Dictionary in older["box"]:
		row.erase("box")
	older["current_box"] = 2
	var loaded: PokeCoopPlayer = PokeCoopPlayer.from_dict(older)
	assert_eq(int(loaded.box[0]["box"]), 2, "a save from before boxes puts its PC in the current box")
	assert_eq(int(loaded.box[-1]["box"]), 3, "and spills what does not fit")


func test_pokemon_that_share_a_fingerprint_keep_their_own_uids_through_a_deposit() -> void:
	var blue := PokeCoopPlayer.create("p2", "BLUE", 200)
	var first: Gen2SaveMon = _saved(Fixture.CHARMANDER, 12)
	var second: Gen2SaveMon = _saved(Fixture.PIKACHU, 9)
	second.dvs = first.dvs
	assert_eq(PokeCoopPlayer.fingerprint(first), PokeCoopPlayer.fingerprint(second))
	var first_uid: String = blue.add_mon(first)
	var second_uid: String = blue.add_mon(second)

	var taken: StringName = blue.replace_holdings(
		[{"uid": first_uid, "mon": second.to_dict()}],
		[{"uid": "", "mon": first.to_dict(), "box": 0}], 0, blue.holdings_rev
	)

	assert_eq(taken, &"")
	assert_eq(String(blue.team[0]["uid"]), second_uid, "a stale hint does not move a uid onto another Pokémon")
	assert_eq(String(blue.box[0]["uid"]), first_uid)


func test_a_trainer_brought_from_a_save_stands_where_they_saved() -> void:
	var save := Gen2SaveData.new()
	save.world = Gen2WorldSnapshot.new()
	save.world.map_id = ROUTE_1
	save.world.player_cell = Vector2i(4, 9)
	save.world.player_facing = Gen2WorldSprite.FACING_UP
	save.party.append(_saved(Fixture.CHARMANDER, 12))
	var red := PokeCoopPlayer.create("p1", "RED", 100)

	PokeCoopPolicy.import_save(save, red, null, [])

	assert_eq([red.map, red.cell, red.facing], [ROUTE_1, Vector2i(4, 9), Gen2WorldSprite.FACING_UP])
	assert_eq(red.team.size(), 1)
