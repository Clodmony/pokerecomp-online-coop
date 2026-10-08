extends GutTest

## Co-op campaign and player state: what is shared, what each player keeps for
## themselves, and how both survive a save.

const Fixture := preload("res://tests/unit/battle_fixture.gd")
const Seed := preload("res://tools/coop_seed.gd")
const SAVE_PATH: String = "user://coop_state_test.json"
const SEED_DIR: String = "user://coop_seed_test"
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
	RomCache.clear(SEED_DIR)
	for path: String in [SAVE_PATH, SAVE_PATH + PokeCoopSave.BACKUP_SUFFIX, SAVE_PATH + PokeCoopSave.JOURNAL_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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


func test_the_teams_gate_drink_is_saved_with_the_campaign_and_a_drink_a_player_kept_moves_to_it() -> void:
	var drink: int = Gen1Layout.status_flag_1(PokeCoopOwnership.SAFFRON_DRINK_BIT)
	var strength: int = Gen1Layout.status_flag_1(Gen1Layout.STRENGTH_ACTIVE_BIT)
	var campaign := PokeCoopCampaign.create("c1", _data.id, _data.sha1)
	campaign.commit("victory:trainer:brock", {"badges": 1})
	var red := PokeCoopPlayer.create("p1", "RED", 100)
	red.world["engine_flags"] = {drink: true, strength: true}
	var blue := PokeCoopPlayer.create("p2", "BLUE", 200)

	var raw: Variant = JSON.parse_string(JSON.stringify(PokeCoopSave.to_dict(campaign, [red, blue])))
	var loaded: Dictionary = PokeCoopSave.from_dict(raw)

	var back: PokeCoopCampaign = loaded["campaign"]
	var badges: Array[int] = PokeCoopOwnership.badge_flags(_data)
	assert_eq(back.world_part(badges)["engine_flags"], {badges[0]: true, drink: true}, "a save from before D91")
	assert_eq((loaded["players"][0] as PokeCoopPlayer).world["engine_flags"], {strength: true})
	var again: Dictionary = PokeCoopSave.from_dict(JSON.parse_string(JSON.stringify(
		PokeCoopSave.to_dict(back, loaded["players"]))))
	assert_eq(PokeCoopSave.to_dict(again["campaign"], again["players"]), PokeCoopSave.to_dict(back, loaded["players"]))


func test_the_checkpoint_before_the_last_is_kept_and_never_replaced_by_a_damaged_one() -> void:
	var backup: String = SAVE_PATH + PokeCoopSave.BACKUP_SUFFIX
	var red := PokeCoopPlayer.create("p1", "RED", 100)
	var first := PokeCoopCampaign.create("first", _data.id, _data.sha1)
	assert_eq(PokeCoopSave.write(SAVE_PATH, first, [red]), OK)
	assert_false(FileAccess.file_exists(backup), "nothing before the first")
	assert_eq(PokeCoopSave.write(SAVE_PATH, PokeCoopCampaign.create("second", _data.id, _data.sha1), [red]), OK)
	assert_eq((PokeCoopSave.read(backup)["campaign"] as PokeCoopCampaign).campaign_id, "first")

	var damaged: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	damaged.store_string("{\"kind\": \"pokerecomp-coop-campaign\", \"campa")
	damaged.close()
	assert_eq(PokeCoopSave.write(SAVE_PATH, PokeCoopCampaign.create("third", _data.id, _data.sha1), [red]), OK)
	assert_eq((PokeCoopSave.read(backup)["campaign"] as PokeCoopCampaign).campaign_id, "first", "the damaged file is not kept")
	assert_eq((PokeCoopSave.read(SAVE_PATH)["campaign"] as PokeCoopCampaign).campaign_id, "third")


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


func test_a_story_seed_is_a_campaign_where_p1_and_p2_each_hold_their_own_copy_of_the_save() -> void:
	var save := Gen2SaveData.new()
	save.player_id = 0xFFFF
	save.party.append(_saved(Fixture.CHARMANDER, 12))
	save.world = Gen2WorldSnapshot.new()
	save.world.map_id = ROUTE_1
	save.world.player_cell = Vector2i(4, 9)
	save.world.rival_name = "GARY"
	save.world.world_state = Gen2WorldState.new({STORY_FLAG: true}, {}, {Fixture.POTION: 3}, {0: 1234})
	save.world.world_state.set_engine_flag(Gen2WorldState.gen1_badge_flag(0))

	assert_eq(Seed.write_seed(_data, save, SEED_DIR, Vector2i(5, 9)), OK)
	var loaded: Dictionary = PokeCoopSave.read(SEED_DIR.path_join(PokeCoopSession.campaign_path(_data).trim_prefix("user://")))

	var campaign: PokeCoopCampaign = loaded["campaign"]
	assert_eq([campaign.has_flag(STORY_FLAG), campaign.has_badge(0), campaign.rival_name], [true, true, "GARY"])
	var players: Array = loaded["players"]
	assert_eq(players.map(func(held: PokeCoopPlayer) -> Array:
		return [held.player_id, held.name, held.map, held.cell, held.item_count(Fixture.POTION), held.money]), [
		["p1", "P1", ROUTE_1, Vector2i(4, 9), 3, 1234], ["p2", "P2", ROUTE_1, Vector2i(5, 9), 3, 1234]],
		"the ids and names the scenario windows join as, side by side")
	for held: PokeCoopPlayer in players:
		var mon: Gen2SaveMon = held.mon(held.player_id + ":1")
		assert_eq([mon.species, mon.ot_id, mon.original_trainer], [Fixture.CHARMANDER, held.trainer_id, held.name],
			"a Pokémon of their own, so it obeys them")
	assert_ne(players[0].trainer_id, players[1].trainer_id)
	var known: Variant = JSON.parse_string(FileAccess.get_file_as_string(SEED_DIR.path_join("coop_identity.json")))
	assert_eq(known.get("testgame/127.0.0.1:%d" % PokeCoopEnetTransport.DEFAULT_PORT), {"testgame": "p2"})


func test_a_seed_with_a_full_party_gives_each_player_six_of_their_own_told_apart_the_same_each_time() -> void:
	var save := Gen2SaveData.new()
	save.player_id = 0xFFFF
	save.party.append(_saved(Fixture.CHARMANDER, 12))
	save.world = Gen2WorldSnapshot.new()
	var again: Gen2SaveData = Gen2SaveData.from_dict(save.to_dict())
	Seed.fill_party(_data, save, 9)
	Seed.fill_party(_data, again, 9)
	assert_eq(save.to_dict(), again.to_dict(), "the same party from the same save")

	assert_eq(Seed.write_seed(_data, save, SEED_DIR, Vector2i(5, 9)), OK)
	var loaded: Dictionary = PokeCoopSave.read(SEED_DIR.path_join(PokeCoopSession.campaign_path(_data).trim_prefix("user://")))

	for held: PokeCoopPlayer in loaded["players"]:
		assert_eq(held.team.map(func(entry: Dictionary) -> String: return entry["uid"]),
			range(1, 7).map(func(at: int) -> String: return "%s:%d" % [held.player_id, at]))
		var mons: Array = held.team.map(func(entry: Dictionary) -> Gen2SaveMon: return entry["mon"])
		assert_eq(mons.map(func(mon: Gen2SaveMon) -> Array: return [mon.species, mon.level, mon.ot_id, mon.hp > 0]),
			range(6).map(func(_at: int) -> Array: return [Fixture.CHARMANDER, 12, held.trainer_id, true]))
		var prints: Array = mons.map(PokeCoopPlayer.fingerprint)
		assert_eq(prints.filter(func(row: Array) -> bool: return prints.count(row) == 1).size(), 6,
			"the host tells every one apart")


func test_a_player_part_way_through_the_opening_is_saved_with_their_own_story() -> void:
	var campaign := PokeCoopCampaign.create("c1", _data.id, _data.sha1)
	campaign.title = "WITH BLUE"
	campaign.rival_name = "GARY"
	var red := PokeCoopPlayer.create("p1", "RED", 100)
	PokeCoopPolicy.set_up_opening_player(_data, red)
	(red.opening["world"]["event_flags"] as Dictionary)[0x20] = true

	assert_eq(PokeCoopSave.write(SAVE_PATH, campaign, [red]), OK)
	var loaded: Dictionary = PokeCoopSave.read(SAVE_PATH)

	assert_eq(PokeCoopSave.to_dict(loaded["campaign"], loaded["players"]), PokeCoopSave.to_dict(campaign, [red]))
	var back: PokeCoopPlayer = loaded["players"][0]
	assert_true((back.opening["world"]["event_flags"] as Dictionary).has(0x20), "the flag keeps its number")
	assert_eq([back.opening["stage"], back.money, (loaded["campaign"] as PokeCoopCampaign).rival_name],
		[PokeCoopPolicy.OPENING_SPEECH, PokeCoopPolicy.NEW_PLAYER_MONEY, "GARY"])


func test_a_campaign_begun_after_the_intro_has_the_intros_world_and_a_first_format_one_is_settled_once() -> void:
	var fresh := PokeCoopCampaign.create("c1", _data.id, _data.sha1)
	PokeCoopPolicy.start_campaign(fresh)
	assert_true(fresh.has_flag(0x27), "Oak has appeared in Pallet Town")
	assert_eq([int(fresh.world["gen1_map_scripts"][0]), int(fresh.world["gen1_map_scripts"][1])], [18, 5])
	assert_true(bool(fresh.world["toggled_objects"][0x2B]), "the rival has left the lab")

	var older := PokeCoopCampaign.create("c2", _data.id, _data.sha1)
	older.commit("intro:starters_given", {"flags": [0x00, 0x20, 0x21, 0x22, 0x23], "badges": 3})
	older.world["gen1_map_scripts"] = {0: 20}
	var settled: PokeCoopCampaign = _read_first_format(older)
	assert_true(settled.has_flag(0x27), "a campaign file from an earlier build is settled when read")
	assert_eq([int(settled.world["gen1_map_scripts"][0]), int(settled.world["gen1_map_scripts"][1])], [20, 5],
		"a script step the campaign already moved on is kept")
	assert_eq(settled.badges, 3)

	(settled.world["gen1_map_scripts"] as Dictionary).erase(28)
	assert_eq(PokeCoopSave.write(SAVE_PATH, settled, []), OK)
	var hosted: PokeCoopCampaign = PokeCoopSave.read(SAVE_PATH)["campaign"]
	PokeCoopHost.create(_data, hosted, PokeCoopTransport.new())
	assert_false((hosted.world["gen1_map_scripts"] as Dictionary).has(28),
		"settled once: a script step that went back to its start in play is not put back when hosted again")

	var blank := PokeCoopCampaign.create("c3", _data.id, _data.sha1)
	assert_false(_read_first_format(blank).has_flag(0x27), "a campaign that has not begun is left alone")


## [param campaign] as a build before format 2 wrote it, read back.
func _read_first_format(campaign: PokeCoopCampaign) -> PokeCoopCampaign:
	var raw: Dictionary = PokeCoopSave.to_dict(campaign, [])
	raw["format_version"] = 1
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw, "\t"))
	file.close()
	return PokeCoopSave.read(SAVE_PATH)["campaign"]


func test_story_journaled_after_the_last_checkpoint_survives_a_crash_until_the_next_checkpoint() -> void:
	var journal: String = SAVE_PATH + PokeCoopSave.JOURNAL_SUFFIX
	var campaign := PokeCoopCampaign.create("c1", _data.id, _data.sha1)
	var red := PokeCoopPlayer.create("p1", "RED", 100)
	red.store_mon(_saved(Fixture.PIKACHU, 3))
	assert_eq(PokeCoopSave.write(SAVE_PATH, campaign, [red]), OK)
	var unchanged_pc: Dictionary = {red.player_id: red.box_rev}

	campaign.commit("victory:trainer:brock", {"flags": [STORY_FLAG], "badges": 1, "defeated": ["trainer:brock"]})
	red.give_item(Fixture.POTION, 2)
	assert_eq(PokeCoopSave.append(SAVE_PATH, campaign, [red], unchanged_pc), OK)
	var torn: FileAccess = FileAccess.open(journal, FileAccess.READ_WRITE)
	torn.seek_end()
	torn.store_string("\n{\"kind\": \"pokerecomp-coop-campaign\", \"campa")
	torn.close()

	var loaded: Dictionary = PokeCoopSave.read(SAVE_PATH)
	var back: PokeCoopCampaign = loaded["campaign"]
	assert_true(back.has_flag(STORY_FLAG) and back.has_badge(0), "a commit no checkpoint holds is kept, a torn line after it ignored")
	assert_eq(back.encounter_state("trainer:brock"), PokeCoopCampaign.ENCOUNTER_DONE)
	var back_red: PokeCoopPlayer = loaded["players"][0]
	assert_eq(back_red.item_count(Fixture.POTION), 2, "with the bag as it stood")
	assert_eq(back_red.box.size(), 1, "and the PC the line left to the checkpoint")

	campaign.commit("victory:trainer:misty", {"badges": 2, "defeated": ["trainer:misty"]})
	red.store_mon(_saved(Fixture.BULBASAUR, 5))
	assert_eq(PokeCoopSave.append(SAVE_PATH, campaign, [red], unchanged_pc), OK)
	var later: Dictionary = PokeCoopSave.read(SAVE_PATH)
	assert_true((later["campaign"] as PokeCoopCampaign).has_badge(1), "a line written after a torn one reads")
	assert_eq((later["players"][0] as PokeCoopPlayer).box.size(), 2, "with the PC it changed since the checkpoint")

	var stale: String = FileAccess.get_file_as_string(journal)
	red.give_item(Fixture.POTION, 1)
	assert_eq(PokeCoopSave.write(SAVE_PATH, campaign, [red]), OK)
	assert_false(FileAccess.file_exists(journal), "the next checkpoint empties the journal")
	var left: FileAccess = FileAccess.open(journal, FileAccess.WRITE)
	left.store_string(stale)
	left.close()
	assert_eq((PokeCoopSave.read(SAVE_PATH)["players"][0] as PokeCoopPlayer).item_count(Fixture.POTION), 3,
		"lines a crash left behind the checkpoint that holds them change nothing")
