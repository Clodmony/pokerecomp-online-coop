class_name PokePadChoice
extends RefCounted

## The one controller that plays (Settings > Controls), found again by GUID and name after unplugging; keyboard, mouse and touch always play.

const AWAY: int = 1 << 20

static var _choice: Dictionary = {}
static var _device: int = PokeInputActions.ALL_DEVICES
static var held: Dictionary = {}


static func sanitize(raw: Variant) -> Dictionary:
	if not raw is Dictionary or String((raw as Dictionary).get("guid", "")).is_empty():
		return {}
	var row: Dictionary = raw
	return {"guid": String(row["guid"]).left(64), "name": String(row.get("name", "")).left(64),
		"serial": String(row.get("serial", "")).left(64), "nth": clampi(int(row.get("nth", 0)), 0, 15)}


static func connected() -> Array:
	var out: Array = []
	for device: int in Input.get_connected_joypads():
		var pad: Dictionary = {"guid": Input.get_joy_guid(device), "name": Input.get_joy_name(device),
			"serial": String(Input.get_joy_info(device).get("serial_number", ""))}
		pad["nth"] = out.filter(func(other: Dictionary) -> bool: return _same_model(other, pad)).size()
		out.append(pad.merged({"device": device}))
	return out


static func _same_model(first: Dictionary, second: Dictionary) -> bool:
	return first["guid"] == second["guid"] and first["name"] == second.get("name", "")


static func device_for(choice: Dictionary, pads: Array = connected()) -> int:
	if choice.is_empty():
		return PokeInputActions.ALL_DEVICES
	var same: Array = pads.filter(func(pad: Dictionary) -> bool: return pad["guid"] == choice["guid"])
	var exact: Array = same.filter(func(pad: Dictionary) -> bool:
		return pad["serial"] == choice.get("serial", "") if not String(pad["serial"]).is_empty() \
			else _same_model(pad, choice) and pad["nth"] == choice.get("nth", 0))
	same.sort_custom(func(first: Dictionary, _second: Dictionary) -> bool: return _same_model(first, choice))
	return int((exact + same)[0]["device"]) if not same.is_empty() else AWAY


static func apply(choice: Dictionary = _choice, pads: Array = connected()) -> void:
	_choice = choice
	_device = device_for(held if not held.is_empty() else choice, pads)
	for action: StringName in InputMap.get_actions():
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				event.device = _device


static func device() -> int:
	return _device


static func heard(event: InputEvent) -> bool:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return true
	return _device == PokeInputActions.ALL_DEVICES or event.device == _device


static func choices(choice: Dictionary, pads: Array = connected()) -> Array:
	var playing: int = device_for(choice, pads)
	var out: Array = [{"label": "Every controller", "choice": {}, "picked": choice.is_empty()}]
	for pad: Dictionary in pads:
		var twins: int = pads.filter(func(other: Dictionary) -> bool: return _same_model(other, pad)).size()
		out.append({"label": String(pad["name"]) + (" (%d)" % (int(pad["nth"]) + 1) if twins > 1 else ""),
			"choice": sanitize(pad), "picked": not choice.is_empty() and int(pad["device"]) == playing})
	if not choice.is_empty() and playing == AWAY:
		out.append({"label": "%s (unplugged)" % choice.get("name", "Controller"), "choice": choice, "picked": true})
	return out
