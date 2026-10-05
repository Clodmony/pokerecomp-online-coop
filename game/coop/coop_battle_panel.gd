class_name PokeCoopBattlePanel
extends PanelContainer

## The co-op overlay over the world screen: the session menu on SELECT and, while
## this player is in a shared battle, the allied roster with its owners, who
## decides and the partner's advisory cursor. It sends intentions and decides
## nothing; while it is open the world gets no buttons.

const WIDTH: int = 420
const FONT_SIZE: int = 15

var client: PokeCoopClient = null
var data: GameData = null
var _label: Label = null
var _rows: Array = []
var _cursor: int = 0
var _menu_open: bool = false
var _dismissed: Dictionary = {}
var _shown: String = ""
var _turn_key: String = ""


static func over(session: PokeCoopClient, game_data: GameData) -> PokeCoopBattlePanel:
	var out := PokeCoopBattlePanel.new()
	out.client = session
	out.data = game_data
	return out


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.12, 0.92)
	style.set_content_margin_all(12)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	custom_minimum_size = Vector2(WIDTH, 0)
	position.x -= WIDTH + 16
	position.y += 16
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(WIDTH - 24, 0)
	add_child(_label)
	visible = false


func is_open() -> bool:
	return _menu_open or not battle_view().is_empty()


## The battle this player is in, or the last one they have not closed yet.
func battle_view() -> Dictionary:
	var finished: Dictionary = {}
	for battle_id: String in client.battles:
		var view: Dictionary = client.battles[battle_id]
		if _dismissed.has(battle_id) or not _involves_me(view):
			continue
		if String(view.get("outcome", "")).is_empty():
			return view
		finished = view
	return finished


func _involves_me(view: Dictionary) -> bool:
	return (view.get("participants", []) as Array).has(client.player_id) \
		or (view.get("pending", []) as Array).has(client.player_id)


func _process(_delta: float) -> void:
	if client == null:
		return
	var view: Dictionary = battle_view()
	if not view.is_empty():
		_menu_open = false
	var turn_key: String = "%s/%s" % [view.get("battle", ""), view.get("controller", "")]
	if turn_key != _turn_key:
		_turn_key = turn_key
		_cursor = 0
	_rows = _battle_rows(view) if not view.is_empty() else (_menu_rows() if _menu_open else [])
	_cursor = clampi(_cursor, 0, maxi(_rows.size() - 1, 0))
	var text: String = _battle_text(view) if not view.is_empty() else (_menu_text() if _menu_open else "")
	visible = not text.is_empty()
	if text != _shown:
		_shown = text
		_label.text = text


func _input(event: InputEvent) -> void:
	var button: int = PokeButton.pressed_in(event)
	if button == PokeButton.NONE or client == null:
		return
	if not is_open():
		if button == PokeButton.SELECT:
			_menu_open = true
			_cursor = 0
			get_viewport().set_input_as_handled()
		return
	_press(button)
	get_viewport().set_input_as_handled()


func _press(button: int) -> void:
	match button:
		PokeButton.UP, PokeButton.DOWN:
			_move_cursor(-1 if button == PokeButton.UP else 1)
		PokeButton.A:
			_choose()
		PokeButton.B, PokeButton.SELECT:
			_menu_open = false


func _move_cursor(by: int) -> void:
	if _rows.is_empty():
		return
	_cursor = posmod(_cursor + by, _rows.size())
	var view: Dictionary = battle_view()
	var row: Dictionary = _rows[_cursor]
	if not view.is_empty() and not _controls(view) and row.has("suggest"):
		client.suggest(String(view["battle"]), String(row["suggest"]), int(row["value"]))


func _choose() -> void:
	var view: Dictionary = battle_view()
	if not view.is_empty() and not String(view.get("outcome", "")).is_empty():
		_dismissed[String(view["battle"])] = true
		return
	if _rows.is_empty():
		return
	var row: Dictionary = _rows[_cursor]
	if view.is_empty():
		_run_menu_row(row)
	elif _controls(view) and row.has("command"):
		client.act(String(view["battle"]), row["command"])
	elif row.has("suggest"):
		client.suggest(String(view["battle"]), String(row["suggest"]), int(row["value"]))


func _controls(view: Dictionary) -> bool:
	return String(view.get("controller", "")) == client.player_id


func _run_menu_row(row: Dictionary) -> void:
	match String(row.get("action", "")):
		"fight":
			client.start_battle(String(row["id"]))
		"join":
			client.join_battle(String(row["id"]))
		"save":
			client.request_save()
	_menu_open = false


func _menu_rows() -> Array:
	var rows: Array = []
	for offer: Dictionary in client.state.get("encounters", []):
		rows.append({"text": "FIGHT %s" % offer["label"], "action": "fight", "id": offer["id"]})
	for running: Dictionary in client.state.get("battles", []):
		if not (running["participants"] as Array).has(client.player_id):
			rows.append({
				"text": "JOIN %s (%s)" % [running["battle"], _names(running["participants"])],
				"action": "join", "id": running["battle"],
			})
	rows.append({"text": "SAVE CAMPAIGN", "action": "save"})
	rows.append({"text": "CLOSE", "action": "close"})
	return rows


func _menu_text() -> String:
	var lines: PackedStringArray = ["CO-OP SESSION  (%s)" % _name(client.player_id)]
	lines.append_array(_row_lines({}))
	lines.append(_status_line())
	return "\n".join(lines)


func _battle_rows(view: Dictionary) -> Array:
	match String(view.get("phase", "")):
		"action":
			return _move_rows(view) + _switch_rows(view, "switch") + _item_rows(view) + [
				{"text": "RUN", "command": {"type": "run"}, "suggest": "run", "value": 0},
			]
		"send_out":
			return _switch_rows(view, "send_out") + [{"text": "RUN", "command": {"type": "run"}}]
		"learn":
			return _learn_rows(view)
		"mimic":
			return _mimic_rows(view)
	return []


func _active(view: Dictionary) -> Dictionary:
	for ally: Dictionary in view.get("allies", []):
		if int(ally["index"]) == int(view["active"]):
			return ally
	return {}


func _move_rows(view: Dictionary) -> Array:
	var rows: Array = []
	var moves: Array = _active(view).get("moves", [])
	for slot: int in moves.size():
		if int(moves[slot]) != 0:
			rows.append({
				"text": "FIGHT  %s" % _move_name(int(moves[slot])),
				"command": {"type": "move", "slot": slot}, "suggest": "move", "value": slot,
			})
	return rows


func _switch_rows(view: Dictionary, kind: String) -> Array:
	var rows: Array = []
	for ally: Dictionary in view.get("allies", []):
		var index: int = int(ally["index"])
		if index == int(view["active"]) or int(ally["hp"]) <= 0:
			continue
		rows.append({
			"text": "%s %s (%s)" % [
				"SWITCH TO" if kind == "switch" else "SEND OUT", _mon_line(ally), _name(ally["owner"]),
			],
			"command": {"type": kind, "index": index}, "suggest": kind, "value": index,
		})
	return rows


## This player's bag: a ball once per participant it could be caught for, which
## is how a catch names its recipient, and anything else usable on the one out.
func _item_rows(view: Dictionary) -> Array:
	var rows: Array = []
	var bag: Dictionary = client.me().get("items", {})
	var numbers: Array = bag.keys()
	numbers.sort()
	for item: Variant in numbers:
		var held: String = "%s x%d" % [_item_name(int(item)), int(bag[item])]
		if Gen2WorldPartyHost.is_ball(data, int(item)):
			if not bool(view.get("trainer", false)):
				rows.append_array(_ball_rows(view, int(item), held))
		elif int(data.item(int(item)).get("battle_menu", Gen2Layout.ITEMMENU_NOUSE)) != Gen2Layout.ITEMMENU_NOUSE:
			rows.append({
				"text": "USE %s on %s" % [held, _mon_line(_active(view))],
				"command": {"type": "item", "item": int(item), "target": int(view["active"])},
				"suggest": "item", "value": int(item),
			})
	return rows


func _ball_rows(view: Dictionary, ball: int, held: String) -> Array:
	var rows: Array = []
	for player_id: Variant in view.get("participants", []):
		rows.append({
			"text": "THROW %s for %s" % [held, _name(player_id)],
			"command": {"type": "item", "item": ball, "recipient": String(player_id)},
			"suggest": "item", "value": ball,
		})
	return rows


func _item_name(item: int) -> String:
	return String(data.item(item).get("name", "ITEM %d" % item)) if data != null else "ITEM %d" % item


func _learn_rows(view: Dictionary) -> Array:
	var rows: Array = []
	var moves: Array = _active(view).get("moves", [])
	for slot: int in moves.size():
		rows.append({
			"text": "FORGET %s" % _move_name(int(moves[slot])),
			"command": {"type": "learn", "forget_slot": slot},
		})
	rows.append({"text": "KEEP OLD MOVES", "command": {"type": "decline"}})
	return rows


func _mimic_rows(view: Dictionary) -> Array:
	var rows: Array = []
	var moves: Array = (view.get("enemy", {}) as Dictionary).get("moves", [])
	for slot: int in moves.size():
		if int(moves[slot]) != 0:
			rows.append({
				"text": "MIMIC %s" % _move_name(int(moves[slot])),
				"command": {"type": "mimic", "choice": slot},
			})
	return rows


func _battle_text(view: Dictionary) -> String:
	var enemy: Dictionary = view.get("enemy", {})
	var lines: PackedStringArray = [
		"CO-OP BATTLE %s   vs %s  HP %d/%d" % [
			view["battle"], _mon_line(enemy), int(enemy.get("hp", 0)), int(enemy.get("max_hp", 0)),
		],
	]
	lines.append_array(_ally_lines(view))
	lines.append(_turn_line(view))
	if String(view.get("outcome", "")).is_empty():
		lines.append_array(_row_lines(view))
	elif not String(view.get("caught_for", "")).is_empty():
		lines.append("Caught for %s! Press A to close." % _name(view["caught_for"]))
	else:
		lines.append("Battle over: %s. Press A to close." % String(view["outcome"]).to_upper())
	lines.append(_status_line())
	return "\n".join(lines)


func _ally_lines(view: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	for ally: Dictionary in view.get("allies", []):
		lines.append("%s %s  HP %d/%d  [%s]" % [
			"*" if int(ally["index"]) == int(view["active"]) else " ", _mon_line(ally),
			int(ally["hp"]), int(ally["max_hp"]), _name(ally["owner"]),
		])
	return lines


func _turn_line(view: Dictionary) -> String:
	var controller: String = String(view.get("controller", ""))
	if bool(view.get("paused", false)):
		return "PAUSED: waiting for %s to reconnect" % _name(controller)
	if controller == client.player_id:
		return "YOUR TURN (revision %d)" % int(view.get("revision", 0))
	return "%s DECIDES. Your cursor is a suggestion." % _name(controller)


func _row_lines(view: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	var suggested: Dictionary = _partner_suggestion(view)
	for index: int in _rows.size():
		var row: Dictionary = _rows[index]
		var mark: String = ""
		if not suggested.is_empty() and String(row.get("suggest", "")) == String(suggested["type"]) \
				and int(row.get("value", -1)) == int(suggested["value"]):
			mark = "   <- %s" % _name(suggested["player"])
		lines.append("%s %s%s" % [">" if index == _cursor else " ", row["text"], mark])
	return lines


func _partner_suggestion(view: Dictionary) -> Dictionary:
	var suggestions: Dictionary = view.get("suggestions", {})
	for player_id: String in suggestions:
		if player_id != client.player_id:
			var suggestion: Dictionary = (suggestions[player_id] as Dictionary).duplicate()
			suggestion["player"] = player_id
			return suggestion
	return {}


func _status_line() -> String:
	var refused: StringName = client.last_rejection()
	return "" if refused == &"" else "Last refused: %s" % refused


func _mon_line(mon: Dictionary) -> String:
	var species: int = int(mon.get("species", 0))
	var species_name: String = String(data.species(species).get("name", "#%d" % species)) \
		if data != null else "#%d" % species
	return "%s L%d" % [species_name, int(mon.get("level", 0))]


func _move_name(move: int) -> String:
	return String(data.move(move).get("name", "MOVE %d" % move)) if data != null else "MOVE %d" % move


func _name(player_id: Variant) -> String:
	var view: Dictionary = (client.state.get("players", {}) as Dictionary).get(String(player_id), {})
	return String(view.get("name", player_id))


func _names(player_ids: Variant) -> String:
	var out: PackedStringArray = []
	for player_id: Variant in player_ids as Array:
		out.append(_name(player_id))
	return ", ".join(out)
