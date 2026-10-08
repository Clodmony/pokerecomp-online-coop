class_name PokeCoopBattlePanel
extends PanelContainer

## The session menu on SELECT and, in a shared battle, the allies, who decides and the suggestions; it decides nothing.

signal leave_requested

const WIDTH: int = 420
const FONT_SIZE: int = 15
const MUTED: String = "#8a93b8"
const REFUSAL_MSEC: int = 4000
const REFUSALS: Dictionary = {
	&"not_controller": "It is not your turn.", &"stale_revision": "The battle moved on; try again.",
	&"paused": "The battle is waiting for a player to come back.", &"box_full": "No room left for a catch.",
	&"trainer_pokemon": "You can't catch a trainer's POKéMON!", &"battle_in_progress": "Not saved: a battle is running.",
	&"already_in_battle": "You are already in a battle.", &"roster_full": "No room for more POKéMON in that battle.",
	&"encounter_taken": "Someone is already fighting that.", &"battle_over": "That battle is over.",
	&"item_has_no_effect": "It won't have any effect.", &"no_fit_pokemon": "None of your POKéMON can fight.",
	&"save_failed": "The campaign could not be saved.", &"encounter_done": "Beaten already in this campaign: it counts as won.",
	&"attached": "Your own world started this battle: you stay in it.",
	&"in_battle": "Your POKéMON are still in a battle.", &"invalid_move": "That move can't be used now.",
	&"scene_taken": "A partner met the rival first: the battle is one for both.",
}

var client: PokeCoopClient = null
var data: GameData = null
## Whatever is still playing the last turn out; a choice waits for it.
var busy: Callable = Callable()
var _label: RichTextLabel = null
var _rows: Array = []
var _cursor: int = 0
var _menu_open: bool = false
var _dismissed: Dictionary = {}
var _recalled: Dictionary = {}
var _kept_waiting: Dictionary = {}
var _shown: String = ""
var _turn_key: String = ""
var _refusals_seen: int = 0
var _refused_until: int = 0


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
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	for font_size: String in ["normal_font_size", "bold_font_size"]:
		_label.add_theme_font_size_override(font_size, FONT_SIZE)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(WIDTH - 24, 0)
	_label.meta_underlined = false
	_label.meta_clicked.connect(_on_row_clicked)
	add_child(_label)
	visible = false


func is_open() -> bool:
	return _menu_open or not battle_view().is_empty()


## The battle this player is in, or the last one they have not closed yet; one they left only when recalled.
func battle_view() -> Dictionary:
	var finished: Dictionary = {}
	for battle_id: String in client.battles:
		var view: Dictionary = client.battles[battle_id]
		if _dismissed.has(battle_id) or not _involves_me(view) or (_has_left(view) and not _recalled.has(battle_id)):
			continue
		if String(view.get("outcome", "")).is_empty():
			return view
		finished = view
	return finished


func _involves_me(view: Dictionary) -> bool:
	return (view.get("participants", []) as Array).has(client.player_id) \
		or (view.get("pending", []) as Array).has(client.player_id)


func _has_left(view: Dictionary) -> bool:
	return (view.get("left", []) as Array).has(client.player_id)


func dismiss_finished() -> void:
	for battle_id: String in client.battles:
		if not String((client.battles[battle_id] as Dictionary).get("outcome", "")).is_empty():
			_dismissed[battle_id] = true


func recall(battle_id: String) -> void:
	_recalled[battle_id] = true
	_dismissed.erase(battle_id)


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
			if battle_view().is_empty() or not busy.is_valid() or not bool(busy.call()):
				_choose()
		PokeButton.B, PokeButton.SELECT:
			_menu_open = false


func _move_cursor(by: int) -> void:
	if not _rows.is_empty():
		_set_cursor(posmod(_cursor + by, _rows.size()))


## A tap or a click on a row: the first puts the cursor there, the second chooses it.
func _on_row_clicked(meta: Variant) -> void:
	var index: int = int(String(meta))
	if index < 0 or index >= _rows.size():
		return
	if index != _cursor:
		_set_cursor(index)
	else:
		_press(PokeButton.A)


func _set_cursor(index: int) -> void:
	_cursor = index
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
	if not view.is_empty() and row.has("session"):
		_run_battle_row(String(view["battle"]), String(row["session"]))
	elif view.is_empty():
		_run_menu_row(row)
	elif _controls(view) and row.has("command"):
		client.act(String(view["battle"]), row["command"])
	elif row.has("suggest"):
		client.suggest(String(view["battle"]), String(row["suggest"]), int(row["value"]))


func _controls(view: Dictionary) -> bool:
	return String(view.get("controller", "")) == client.player_id


func _run_battle_row(battle_id: String, kind: String) -> void:
	match kind:
		"leave":
			client.leave_battle(battle_id)
		"rejoin":
			client.join_battle(battle_id)
		"stand_in":
			client.stand_in(battle_id)
		"wait":
			_kept_waiting[battle_id] = true


func _run_menu_row(row: Dictionary) -> void:
	match String(row.get("action", "")):
		"fight":
			client.start_battle(String(row["id"]))
		"join":
			client.join_battle(String(row["id"]))
		"save":
			client.request_save()
		"leave":
			leave_requested.emit()
	_menu_open = false


func _menu_rows() -> Array:
	var rows: Array = []
	for offer: Dictionary in client.state.get("encounters", []):
		rows.append({"text": "FIGHT %s" % offer["label"], "label": "Fight %s" % offer["label"], "action": "fight", "id": offer["id"]})
	for running: Dictionary in client.state.get("battles", []):
		if (running.get("left", []) as Array).has(client.player_id):
			rows.append({"text": "REJOIN %s" % running["battle"], "label": "Rejoin the battle against %s" % _foe(running),
				"action": "join", "id": running["battle"]})
		elif not (running["participants"] as Array).has(client.player_id) and not bool(running.get("private", false)):
			rows.append({
				"text": "JOIN %s (%s)" % [running["battle"], _names(running["participants"])],
				"label": "Join %s against %s" % [_names_bb(running["participants"]), _foe(running)],
				"action": "join", "id": running["battle"],
			})
	rows.append({"text": "SAVE CAMPAIGN", "label": "Save the campaign (same as START > SAVE)", "action": "save", "section": " "})
	rows.append({"text": "LEAVE SESSION", "label": "Leave the session", "action": "leave"})
	rows.append({"text": "CLOSE", "label": "Close", "action": "close"})
	return rows


static func last_saved(session: PokeCoopClient) -> String:
	var ago: float = float((session.state.get("saved", {}) as Dictionary).get("ago", -1.0))
	if ago < 0.0:
		return "Not saved yet."
	var seconds: int = int(ago) + (Time.get_ticks_msec() - session.state_at) / 1000
	if seconds < 60:
		return "Saved %d seconds ago." % seconds if seconds > 1 else "Saved just now."
	return "Saved %d minutes ago." % (seconds / 60) if seconds >= 120 else "Saved a minute ago."


func _foe(running: Dictionary) -> String:
	var trainer: int = int(running.get("trainer_class", 0))
	var species: String = _species_name(int(running.get("enemy", 0)))
	return data.trainer_name(trainer) if trainer > 0 and data != null else "wild %s" % species


func _place(map: Variant) -> String:
	if not map is Vector2i or data == null or data.generation != RomRegistry.GEN1:
		return ""
	return data.landmark_name(data.area_landmark((map as Vector2i).y)).strip_edges()


func _menu_text() -> String:
	var title: String = PokeCoopTransport.text((client.state.get("campaign", {}) as Dictionary).get("title")).left(24)
	var lines: PackedStringArray = ["[b]CO-OP SESSION[/b]%s   you are %s" % [
		"  " + _escaped(title) if not title.is_empty() else "", _name_bb(client.player_id)]]
	var others: PackedStringArray = []
	var everyone: Dictionary = client.state.get("players", {})
	for player_id: String in everyone:
		var view: Dictionary = everyone[player_id]
		if player_id != client.player_id and bool(view.get("connected", true)):
			var place: String = _place(view.get("map"))
			others.append(_name_bb(player_id) + (" (in a battle)" if not String(view.get("battle", "")).is_empty() \
				else " (in the opening)" if view.get("opening") == true \
				else (" (%s)" % _escaped(place) if not place.is_empty() else "")))
	lines.append("[color=%s]With %s[/color]" % [MUTED, ", ".join(others) if not others.is_empty() else "nobody yet"])
	lines.append("[color=%s]%s It also saves itself after battles and every thirty seconds of changes.[/color]" % [
		MUTED, last_saved(client)])
	lines.append("")
	lines.append_array(_row_lines({}))
	lines.append(_status_line())
	return "\n".join(lines)


func _battle_rows(view: Dictionary) -> Array:
	if _has_left(view):
		return [{"text": "REJOIN", "label": "Rejoin the battle", "session": "rejoin"}]
	if bool(view.get("stand_in_due", false)) and (view.get("participants", []) as Array).has(client.player_id):
		var owner: String = String(view.get("owner", ""))
		var rows: Array = [{"text": "TAKE OVER for %s" % _name(owner), "label": "Take over for %s" % _name_bb(owner), "session": "stand_in"}]
		if not _kept_waiting.has(String(view["battle"])):
			rows.append({"text": "KEEP WAITING", "label": "Keep waiting", "session": "wait"})
		return rows + _leave_rows(view)
	match String(view.get("phase", "")):
		"action":
			return _move_rows(view) + _switch_rows(view, "switch") + _item_rows(view) + [
				{"text": "RUN", "label": "Run", "section": " ", "command": {"type": "run"}, "suggest": "run", "value": 0},
			] + _leave_rows(view)
		"send_out":
			return _switch_rows(view, "send_out") + [{"text": "RUN", "label": "Run", "section": " ", "command": {"type": "run"}}] \
				+ _leave_rows(view)
		"learn":
			return _learn_rows(view)
		"mimic":
			return _mimic_rows(view)
	return _leave_rows(view)


func _leave_rows(view: Dictionary) -> Array:
	if (view.get("attached", []) as Array).has(client.player_id) or not String(view.get("outcome", "")).is_empty():
		return []
	if (view.get("pending", []) as Array).has(client.player_id):
		return [{"text": "CANCEL JOIN", "label": "Don't join after all", "section": " ", "session": "leave"}]
	if not (view.get("participants", []) as Array).has(client.player_id):
		return []
	return [{"text": "LEAVE BATTLE", "label": "Leave the battle (your POKéMON fight on)", "section": " ", "session": "leave"}]


func _active(view: Dictionary) -> Dictionary:
	for ally: Dictionary in view.get("allies", []):
		if int(ally["index"]) == int(view["active"]):
			return ally
	return {}


func _move_rows(view: Dictionary) -> Array:
	var rows: Array = []
	var active: Dictionary = _active(view)
	var moves: Array = active.get("moves", [])
	for slot: int in moves.size():
		if int(moves[slot]) != 0:
			var move: String = _move_name(int(moves[slot])) + _move_state(active, slot)
			rows.append({
				"text": "FIGHT  %s" % move, "label": move, "section": "FIGHT",
				"command": {"type": "move", "slot": slot}, "suggest": "move", "value": slot,
			})
	return rows


static func _move_state(mon: Dictionary, slot: int) -> String:
	if int(mon.get("disabled", -1)) == slot:
		return " (DISABLED)"
	var pp: Array = mon.get("pp", [])
	return " (NO PP)" if slot < pp.size() and int(pp[slot]) <= 0 else ""


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
			"label": "%s   %s" % [_mon_line(ally), _name_bb(ally["owner"])],
			"section": "POKéMON" if kind == "switch" else "SEND OUT WHICH POKéMON?",
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
				"label": "%s on %s" % [held, _mon_line(_active(view))], "section": "BAG",
				"command": {"type": "item", "item": int(item), "target": int(view["active"])},
				"suggest": "item", "value": int(item),
			})
	return rows


func _ball_rows(view: Dictionary, ball: int, held: String) -> Array:
	var rows: Array = []
	for player_id: Variant in view.get("participants", []):
		rows.append({
			"text": "THROW %s for %s" % [held, _name(player_id)],
			"label": "%s, catch for %s" % [held, _name_bb(player_id)], "section": "BAG",
			"command": {"type": "item", "item": ball, "recipient": String(player_id)},
			"suggest": "item", "value": ball,
		})
	return rows


func _item_name(item: int) -> String:
	return String(data.item(item).get("name", "ITEM %d" % item)) if data != null else "ITEM %d" % item


## The Pokémon the offer is for, which need not be the one out, and its move.
func _learn_rows(view: Dictionary) -> Array:
	var offer: Dictionary = view.get("learning", {})
	var allies: Array = view.get("allies", [])
	var index: int = int(offer.get("index", -1))
	var learner: Dictionary = allies[index] if index >= 0 and index < allies.size() else _active(view)
	var taught: String = _move_name(int(offer.get("move", 0)))
	var rows: Array = []
	var moves: Array = learner.get("moves", [])
	for slot: int in moves.size():
		rows.append({
			"text": "%s: FORGET %s FOR %s" % [_mon_line(learner), _move_name(int(moves[slot])), taught],
			"label": _move_name(int(moves[slot])), "section": "%s: FORGET WHICH FOR %s?" % [_mon_line(learner), taught],
			"command": {"type": "learn", "forget_slot": slot},
		})
	rows.append({"text": "KEEP OLD MOVES (NOT %s)" % taught, "label": "Keep the old moves", "section": " ",
		"command": {"type": "decline"}})
	return rows


func _mimic_rows(view: Dictionary) -> Array:
	var rows: Array = []
	var moves: Array = (view.get("enemy", {}) as Dictionary).get("moves", [])
	for slot: int in moves.size():
		if int(moves[slot]) != 0:
			rows.append({
				"text": "MIMIC %s" % _move_name(int(moves[slot])), "label": _move_name(int(moves[slot])), "section": "MIMIC WHICH MOVE?",
				"command": {"type": "mimic", "choice": slot},
			})
	return rows


func _battle_text(view: Dictionary) -> String:
	var enemy: Dictionary = view.get("enemy", {})
	var trainer: String = String(view.get("trainer_name", ""))
	if trainer.is_empty() and int(view.get("trainer_class", 0)) > 0 and data != null:
		trainer = data.trainer_name(int(view["trainer_class"]))
	var lines: PackedStringArray = ["[b]%s %s[/b]   [color=%s]HP %d/%d[/color]" % [
		"%s's" % _escaped(trainer) if bool(view.get("trainer", false)) else "Wild", _mon_line(enemy), MUTED,
		int(enemy.get("hp", 0)), int(enemy.get("max_hp", 0)),
	]]
	lines.append_array(_ally_lines(view))
	lines.append("")
	lines.append("[b]%s[/b]" % _turn_line(view))
	if String(view.get("outcome", "")).is_empty():
		lines.append_array(_row_lines(view))
	else:
		lines.append(_outcome_line(view))
	lines.append(_status_line())
	return "\n".join(lines)


func _outcome_line(view: Dictionary) -> String:
	var closing: String = "   [color=%s](A to close)[/color]" % MUTED
	if not String(view.get("caught_for", "")).is_empty():
		return "Caught for %s!%s" % [_name_bb(view["caught_for"]), closing]
	match String(view["outcome"]):
		"won":
			return "You won!" + closing
		"lost":
			return "You lost." + closing
	return "The battle is over." + closing


func _ally_lines(view: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	var owners: Array = []
	for ally: Dictionary in view.get("allies", []):
		if not owners.has(String(ally["owner"])):
			owners.append(String(ally["owner"]))
	for owner: String in owners:
		lines.append(_name_bb(owner) + (" [color=%s](left)[/color]" % MUTED if (view.get("left", []) as Array).has(owner) else ""))
		for ally: Dictionary in view.get("allies", []):
			if String(ally["owner"]) != owner:
				continue
			var out: bool = int(ally["index"]) == int(view["active"])
			var line: String = "%s %s   %d/%d" % ["  ▶" if out else "   ", _mon_line(ally), int(ally["hp"]), int(ally["max_hp"])]
			lines.append("[b]%s[/b]" % line if out else ("[color=%s]%s[/color]" % [MUTED, line] if int(ally["hp"]) <= 0 else line))
	return lines


func _turn_line(view: Dictionary) -> String:
	var controller: String = String(view.get("controller", ""))
	if not String(view.get("outcome", "")).is_empty():
		return "Battle over"
	if _has_left(view):
		return "You left this battle; your POKéMON fight on in it."
	if (view.get("pending", []) as Array).has(client.player_id):
		return "You join at the start of the next turn."
	var owner: String = String(view.get("owner", controller))
	if bool(view.get("stand_in_due", false)):
		return ("Waiting for %s. You can still take over." if _kept_waiting.has(String(view.get("battle", ""))) \
			else "%s is still away. Take over their POKéMON, or keep waiting?") % _name_bb(owner)
	if bool(view.get("paused", false)):
		return "Waiting for %s to come back..." % _name_bb(controller)
	if controller == client.player_id and owner != controller:
		return "%s %s: you choose for their POKéMON." % [_name_bb(owner),
			"left" if (view.get("left", []) as Array).has(owner) else "is away"]
	if controller == client.player_id:
		return "Your turn" if String(view.get("phase", "")) == "action" else "Your choice"
	return "%s is choosing. Your cursor is a suggestion." % _name_bb(controller)


func _row_lines(view: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	var suggested: Dictionary = _suggesters(view)
	var section: String = ""
	for index: int in _rows.size():
		var row: Dictionary = _rows[index]
		var heading: String = String(row.get("section", ""))
		if heading != section and not heading.is_empty():
			lines.append("[color=%s]%s[/color]" % [MUTED, _escaped(heading.strip_edges())])
		section = heading
		var by: Array = suggested.get("%s:%d" % [row["suggest"], int(row["value"])], []) if row.has("suggest") else []
		var mark: String = "   ◀ %s" % ", ".join(PackedStringArray(by.map(_name_bb))) if not by.is_empty() else ""
		var label: String = String(row.get("label", _escaped(String(row["text"]))))
		lines.append("[url=%d]%s[/url]%s" % [index, ("[b]> %s[/b]" if index == _cursor else "   %s") % label, mark])
	return lines


func _suggesters(view: Dictionary) -> Dictionary:
	var suggestions: Dictionary = view.get("suggestions", {})
	var out: Dictionary = {}
	for player_id: Variant in view.get("participants", []):
		var suggestion: Dictionary = suggestions.get(String(player_id), {})
		if String(player_id) != client.player_id and not suggestion.is_empty():
			var row: String = "%s:%d" % [suggestion.get("type", ""), int(suggestion.get("value", -1))]
			(out.get_or_add(row, []) as Array).append(String(player_id))
	return out


func _status_line() -> String:
	if client.rejections.size() != _refusals_seen:
		_refusals_seen = client.rejections.size()
		_refused_until = Time.get_ticks_msec() + REFUSAL_MSEC
	var refused: StringName = client.last_rejection()
	if refused == &"" or Time.get_ticks_msec() > _refused_until or refused == &"duplicate":
		return ""
	return "\n[color=#f0a070]%s[/color]" % REFUSALS.get(refused, "Refused: %s" % refused)


func _mon_line(mon: Dictionary) -> String:
	return "%s L%d" % [_species_name(int(mon.get("species", 0))), int(mon.get("level", 0))]


func _species_name(species: int) -> String:
	return String(data.species(species).get("name", "#%d" % species)) if data != null else "#%d" % species


func _move_name(move: int) -> String:
	return String(data.move(move).get("name", "MOVE %d" % move)) if data != null else "MOVE %d" % move


func _name(player_id: Variant) -> String:
	var view: Dictionary = (client.state.get("players", {}) as Dictionary).get(String(player_id), {})
	return String(view.get("name", player_id))


func _name_bb(player_id: Variant) -> String:
	var shade: Color = PokeCoopRemoteActor.colors_of(client.state, String(player_id))[1]
	return "[color=#%s]%s[/color]" % [shade.to_html(false), _escaped(_name(player_id))]


func _names(player_ids: Variant) -> String:
	var out: PackedStringArray = []
	for player_id: Variant in player_ids as Array:
		out.append(_name(player_id))
	return ", ".join(out)


func _names_bb(player_ids: Variant) -> String:
	var out: PackedStringArray = []
	for player_id: Variant in player_ids as Array:
		out.append(_name_bb(player_id))
	return " and ".join(out) if out.size() < 3 else "%s and %s" % [", ".join(out.slice(0, -1)), out[-1]]


static func _escaped(text: String) -> String:
	return text.replace("[", "[lb]")
