extends GutTest

## Which state a co-op campaign shares and which each player keeps: every field
## upstream saves has an owner, badges travel with the campaign, and a patch
## reproduces the change it was taken from.


func _assert_classified(table: Dictionary, keys: Array, subject: String) -> void:
	var missing: Array = keys.filter(func(key: Variant) -> bool: return not table.has(String(key)))
	var stale: Array = table.keys().filter(func(key: Variant) -> bool: return not keys.has(key))
	assert_eq(missing, [], "%s fields with no owner in PokeCoopOwnership" % subject)
	assert_eq(stale, [], "%s owners naming no field" % subject)


func test_every_world_state_field_has_an_owner() -> void:
	_assert_classified(
		PokeCoopOwnership.WORLD_STATE, Gen2WorldState.new().to_dict().keys(), "Gen2WorldState"
	)


func test_every_snapshot_and_save_field_has_an_owner() -> void:
	_assert_classified(
		PokeCoopOwnership.WORLD_SNAPSHOT, Gen2WorldSnapshot.new().to_dict().keys(),
		"Gen2WorldSnapshot"
	)
	_assert_classified(PokeCoopOwnership.SAVE_DATA, Gen2SaveData.new().to_dict().keys(), "Gen2SaveData")


func test_every_runtime_variable_has_an_owner() -> void:
	var runtime := Gen2GameRuntime.new()
	var names: Array = []
	for row: Dictionary in runtime.get_property_list():
		if int(row["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(String(row["name"]))
	runtime.free()
	_assert_classified(PokeCoopOwnership.GAME_RUNTIME, names, "Gen2GameRuntime")


func test_badges_go_to_the_campaign_and_other_engine_flags_to_the_player() -> void:
	var badges: Array[int] = PokeCoopOwnership.badge_flags(null)
	var before: Dictionary = {"engine_flags": {}, "event_flags": {}, "items": {}}
	var after: Dictionary = {
		"engine_flags": {badges[0]: true, 1: true}, "event_flags": {0x77: true},
		"items": {0x14: 2}, "map_music": 5,
	}

	var halves: Dictionary = PokeCoopOwnership.route(PokeCoopOwnership.patch(before, after), badges)

	var shared: Dictionary = halves[PokeCoopOwnership.CAMPAIGN]
	var own: Dictionary = halves[PokeCoopOwnership.PLAYER]
	assert_eq((shared["engine_flags"]["set"] as Dictionary).keys(), [badges[0]])
	assert_eq((own["engine_flags"]["set"] as Dictionary).keys(), [1])
	assert_true(shared.has("event_flags"))
	assert_true(own.has("items"))
	assert_false(shared.has("map_music") or own.has("map_music"), "music is this window's own")


func test_saffrons_gate_drink_is_the_campaigns_and_the_other_status_bits_each_players() -> void:
	var drink: int = Gen1Layout.status_flag_1(PokeCoopOwnership.SAFFRON_DRINK_BIT)
	var strength: int = Gen1Layout.status_flag_1(Gen1Layout.STRENGTH_ACTIVE_BIT)
	var surf: int = Gen1Layout.status_flag_1(Gen1Layout.SURF_ALLOWED_BIT)
	var changes: Dictionary = {"engine_flags": {"set": {drink: true, strength: true, surf: true}, "erase": []}}

	var halves: Dictionary = PokeCoopOwnership.route(changes, PokeCoopOwnership.badge_flags(null))

	assert_eq(halves[PokeCoopOwnership.CAMPAIGN], {"engine_flags": {"set": {drink: true}, "erase": []}})
	assert_eq(halves[PokeCoopOwnership.PLAYER], {"engine_flags": {"set": {strength: true, surf: true}, "erase": []}})


func test_a_patch_reproduces_the_change_and_keeps_what_it_did_not_touch() -> void:
	var before: Dictionary = {
		"event_flags": {1: true, 2: true}, "items": {0x14: 1}, "coins": 5, "map_music": 1,
	}
	var after: Dictionary = {
		"event_flags": {2: true, 3: true}, "items": {0x14: 1}, "coins": 9, "map_music": 7,
	}
	var target: Dictionary = before.duplicate(true)
	target["event_flags"][4] = true

	PokeCoopOwnership.apply_patch(target, PokeCoopOwnership.patch(before, after))

	assert_eq(target["event_flags"], {2: true, 3: true, 4: true}, "an entry set elsewhere survives")
	assert_eq(target["coins"], 9)
	assert_eq(target["map_music"], 1, "an unsynced key never travels")


func test_a_world_read_back_from_json_has_its_in_memory_key_types() -> void:
	var state := Gen2WorldState.new()
	state.set_event_flag(0x77)
	state.apply_changes({}, {}, {"items": {0x14: 3}})
	var synced: Dictionary = PokeCoopOwnership.canonical(state.to_dict(), PokeCoopOwnership.PLAYER)

	var reread: Dictionary = PokeCoopOwnership.canonical(
		JSON.parse_string(JSON.stringify(state.to_dict())), PokeCoopOwnership.PLAYER
	)

	assert_eq(reread, synced)
	assert_eq((reread["items"] as Dictionary).keys(), [0x14], "an item number, not the string \"20\"")


func test_each_players_own_gift_flags_and_objects_stay_with_them() -> void:
	var own: Dictionary = PokeCoopPolicy.OWN_GIFTS
	var changes: Dictionary = {
		"event_flags": {"set": {0x356: true, 0x350: true}, "erase": []},
		"toggled_objects": {"set": {0x45: true, 0x30: true}, "erase": []},
	}

	var halves: Dictionary = PokeCoopOwnership.route(changes, PokeCoopOwnership.badge_flags(null), own)

	assert_eq(halves[PokeCoopOwnership.PLAYER], {
		"event_flags": {"set": {0x356: true}, "erase": []}, "toggled_objects": {"set": {0x45: true}, "erase": []},
	})
	assert_eq(halves[PokeCoopOwnership.CAMPAIGN], {
		"event_flags": {"set": {0x350: true}, "erase": []}, "toggled_objects": {"set": {0x30: true}, "erase": []},
	})
	assert_eq((PokeCoopOwnership.route(changes, []) [PokeCoopOwnership.CAMPAIGN] as Dictionary).size(), 2,
		"a game with no such gifts shares them all")


func test_johtos_map_scenes_travel_by_name_and_a_walks_own_stay_with_its_player() -> void:
	var changes: Dictionary = PokeCoopOwnership.well_formed({
		"map_scenes": {"set": {"24:4": 1, "20:1": 1, "3:27": 1}, "erase": ["16:3"]},
	})

	var halves: Dictionary = PokeCoopOwnership.route(changes, [], PokeCoopJohto.OWN_ENTRIES)

	assert_eq(halves[PokeCoopOwnership.CAMPAIGN], {"map_scenes": {"set": {"24:4": 1, "3:27": 1}, "erase": []}},
		"New Bark Town's teacher and the Ruins' inner chamber are the team's")
	assert_eq(halves[PokeCoopOwnership.PLAYER], {"map_scenes": {"set": {"20:1": 1}, "erase": ["16:3"]}},
		"the Pokémon Center's link floor and WILL's room are each walk's")


func test_johtos_unlocked_unown_and_the_rockets_hold_are_the_teams_and_its_walk_flags_each_players() -> void:
	var crystal: bool = false
	var badges: Array[int] = []
	for badge: int in Gen2WorldState.BADGE_ENGINE_FLAGS_GOLD_SILVER.size():
		badges.append(Gen2WorldState.badge_flag(badge, crystal))
	var unown: int = Gen2WorldState.engine_flag(Gen2WorldState.ENGINE_UNLOCKED_UNOWNS_FIRST, crystal)
	var radio: int = Gen2WorldState.ENGINE_ROCKETS_IN_RADIO_TOWER_GOLD_SILVER
	var pokegear: int = 4
	var changes: Dictionary = {
		"engine_flags": {"set": {unown: true, radio: true, pokegear: true, badges[0]: true}, "erase": []},
		"event_flags": {"set": {3: true, 0x309: true, 0x30A: true, 0x2A1: true}, "erase": []},
	}

	var halves: Dictionary = PokeCoopOwnership.route(changes, badges, PokeCoopJohto.OWN_ENTRIES)

	assert_eq(halves[PokeCoopOwnership.CAMPAIGN], {
		"engine_flags": {"set": {unown: true, radio: true, badges[0]: true}, "erase": []},
		"event_flags": {"set": {0x30A: true, 0x2A1: true}, "erase": []},
	}, "the Kabuto puzzle's Unown, the Radio Tower's Rockets, a badge, a League exit and a solved puzzle")
	assert_eq(halves[PokeCoopOwnership.PLAYER], {
		"engine_flags": {"set": {pokegear: true}, "erase": []},
		"event_flags": {"set": {3: true, 0x309: true}, "erase": []},
	}, "the POKéGEAR, a flag a map load clears and the door shut behind one player")
	assert_eq(unown, 42, "ENGINE_UNLOCKED_UNOWNS_A_TO_K at the pinned pokegold")


func test_red_and_blues_routing_is_unchanged_by_johtos_tables() -> void:
	var changes: Dictionary = {"map_scenes": {"set": {"0:1": 2}, "erase": []}, "event_flags": {"set": {3: true}, "erase": []}}

	var halves: Dictionary = PokeCoopOwnership.route(changes, PokeCoopOwnership.badge_flags(null), PokeCoopPolicy.OWN_GIFTS)

	assert_eq(halves[PokeCoopOwnership.CAMPAIGN], changes, "a Generation 1 world shares both, as before")
	assert_eq(halves[PokeCoopOwnership.PLAYER], {})
