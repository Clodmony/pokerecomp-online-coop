extends GutTest

## A picked controller is the only pad that plays, under whatever device number it comes back as;
## every other pad is ignored, the keyboard never is, and the pick survives the options file.

const PAD: Dictionary = {"guid": "030000005e0400008e02000010010000", "name": "Xbox 360 Controller", "serial": "", "nth": 0}
const STEAM: Dictionary = {"guid": "03000000de2800000512000011010000", "name": "Steam Virtual Gamepad", "serial": "", "nth": 0}


func after_each() -> void:
	PokePadChoice.apply({}, [])


func _press(device: int, button: JoyButton = JOY_BUTTON_A) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = true
	return event


func test_only_the_picked_pad_presses_buttons_and_finds_it_again_under_a_new_number() -> void:
	var action: StringName = PokeButton.action(PokeButton.A)
	PokePadChoice.apply(PAD, [STEAM.merged({"device": 0}), PAD.merged({"device": 1})])

	assert_false(_press(0).is_action_pressed(action), "the other pad is ignored")
	assert_true(_press(1).is_action_pressed(action))
	assert_false(_press(0, JOY_BUTTON_DPAD_UP).is_action_pressed(&"ui_up"), "in the launcher too")
	assert_false(PokePadChoice.heard(_press(0)))
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Z
	key.pressed = true
	assert_true(key.is_action_pressed(action) and PokePadChoice.heard(key), "the keyboard always plays")

	PokePadChoice.apply(PAD, [STEAM.merged({"device": 0})])
	assert_eq(PokePadChoice.device(), PokePadChoice.AWAY, "unplugged: no other pad takes over")
	assert_false(_press(0).is_action_pressed(action))
	assert_eq(PokePadChoice.choices(PAD, [STEAM.merged({"device": 0})]).back()["label"], "Xbox 360 Controller (unplugged)")

	PokePadChoice.apply(PAD, [STEAM.merged({"device": 0}), PAD.merged({"device": 3})])
	assert_true(_press(3).is_action_pressed(action), "plugged back in as device 3")
	PokePadChoice.apply({}, [STEAM.merged({"device": 0}), PAD.merged({"device": 3})])
	assert_true(_press(0).is_action_pressed(action), "Every controller plays again")


func test_the_pick_survives_the_options_file() -> void:
	var options := Gen2Options.new()
	options.pad = PAD.duplicate()

	assert_eq(Gen2Options.parse(JSON.parse_string(JSON.stringify(options.to_dict()))).pad, PAD)
	assert_eq(Gen2Options.parse({"pad": {"guid": ""}}).pad, {}, "a damaged entry plays every pad")


func test_two_pads_of_one_model_are_told_apart_by_their_order() -> void:
	var second: Dictionary = PAD.merged({"nth": 1}, true)
	var pads: Array = [STEAM.merged({"device": 0}), PAD.merged({"device": 1}), second.merged({"device": 2})]

	var rows: Array = PokePadChoice.choices(second, pads)

	assert_eq(rows.map(func(row: Dictionary) -> String: return row["label"]),
		["Every controller", "Steam Virtual Gamepad", "Xbox 360 Controller (1)", "Xbox 360 Controller (2)"])
	assert_eq(rows.map(func(row: Dictionary) -> bool: return row["picked"]), [false, false, false, true])
	assert_eq(PokePadChoice.device_for(second, pads), 2)
	assert_eq(PokePadChoice.device_for(second, [PAD.merged({"device": 4})]), 4, "the one left, if the other stays away")


func test_the_pick_stays_on_the_pad_it_found_while_look_alikes_come_and_go() -> void:
	var action: StringName = PokeButton.action(PokeButton.A)
	var twins: Array = [PAD.merged({"device": 0}), PAD.merged({"device": 1, "nth": 1}, true), PAD.merged({"device": 2, "nth": 2}, true)]
	PokePadChoice.apply(PAD, [PAD.merged({"device": 1})])
	assert_eq(PokePadChoice.device(), 1)

	PokePadChoice.apply(PAD, twins)

	assert_eq(PokePadChoice.device(), 1, "two virtual twins, one under the free number 0: the pick stays on the pad it found")
	assert_true(_press(1).is_action_pressed(action))
	assert_false(_press(0).is_action_pressed(action), "the twin that took its place in the order does not play")
	assert_eq(PokePadChoice.choices(PAD, twins).map(func(row: Dictionary) -> bool: return row["picked"]), [false, false, true, false],
		"Settings marks the pad that plays")
	PokePadChoice.apply(PAD, [twins[0], twins[2]])
	assert_eq(PokePadChoice.device(), 0, "unplugged: the twin left first plays, as before")
	PokePadChoice.apply(PAD, twins)
	assert_eq(PokePadChoice.device(), 0, "and keeps playing when the pick comes back under a number nothing tells apart")

	var mine: Dictionary = PAD.merged({"serial": "A1"}, true)
	var other: Dictionary = PAD.merged({"serial": "B2"}, true)
	PokePadChoice.apply(mine, [other.merged({"device": 0}), mine.merged({"device": 1, "nth": 1}, true)])
	assert_eq(PokePadChoice.device(), 1)
	PokePadChoice.apply(mine, [other.merged({"device": 0})])
	assert_eq(PokePadChoice.device(), 0, "the one left")
	PokePadChoice.apply(mine, [other.merged({"device": 0}), mine.merged({"device": 2, "nth": 1}, true)])
	assert_eq(PokePadChoice.device(), 2, "a serial finds the pick again, over the twin kept meanwhile")
	PokePadChoice.held = other
	PokePadChoice.apply(mine, [other.merged({"device": 0}), mine.merged({"device": 2, "nth": 1}, true)])
	assert_eq(PokePadChoice.device(), 0, "a split half's own pad is a new want, not the one kept")
	PokePadChoice.held = {}
