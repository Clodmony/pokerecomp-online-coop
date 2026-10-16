class_name PokeCoopBattlePanel
extends Node

## A shared battle's rows, walked by [PokeCoopBattleMenu] on the world's screen; it decides nothing. The session menu is [PokeCoopMenu].

const FONT_SIZE: int = 15
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
var hand_over: Callable = Callable()
var say: Callable = Callable()
var menu: PokeCoopBattleMenu = null
var _rows: Array = []
var _cursor: int = 0
var _dismissed: Dictionary = {}
var _recalled: Dictionary = {}
var _kept_waiting: Dictionary = {}
var _turn_key: String = ""
var _said: int = 0


static func over(session: PokeCoopClient, game_data: GameData) -> PokeCoopBattlePanel:
	var out := PokeCoopBattlePanel.new()
	out.client = session
	out.data = game_data
	out.menu = PokeCoopBattleMenu.over(session, game_data)
	return out


func is_open() -> bool:
	return not battle_view().is_empty()


## The battle this player is in, or the last one until its lines have played; one they left only when recalled.
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
	var turn_key: String = "%s/%s" % [view.get("battle", ""), view.get("controller", "")]
	if turn_key != _turn_key:
		_turn_key = turn_key
		_cursor = 0
	_rows = _battle_rows(view) if not view.is_empty() else []
	_cursor = clampi(_cursor, 0, maxi(_rows.size() - 1, 0))
	_follow_battle(view)


func _follow_battle(view: Dictionary) -> void:
	menu.update(view, _rows)
	if view.is_empty():
		_said = client.rejections.size()
		return
	if client.rejections.size() != _said:
		_said = client.rejections.size()
		var refused: StringName = client.last_rejection()
		if refused != &"duplicate" and refused != &"":
			if menu.page == PokeCoopBattleMenu.NONE:
				menu.reopen()
			var line: String = Gen1LayoutDe.ui(data.id if data != null else &"", String(REFUSALS.get(refused, "Refused: %s")))
			_say(line if REFUSALS.has(refused) else line % refused)
	if not String(view.get("outcome", "")).is_empty() and (not busy.is_valid() or not bool(busy.call())):
		_dismissed[String(view["battle"])] = true


func _say(line: String) -> void:
	if say.is_valid():
		say.call(line)


func _unhandled_input(event: InputEvent) -> void:
	var button: int = PokeButton.pressed_in(event)
	if button == PokeButton.NONE or client == null or not is_open():
		return
	_press(button)
	get_viewport().set_input_as_handled()


func _press(button: int) -> void:
	if hand_over.is_valid() and bool(hand_over.call(button)):
		return
	if not battle_view().is_empty() and (not busy.is_valid() or not bool(busy.call())):
		_take(menu.press(button))


func _take(picked: Dictionary) -> void:
	if picked.has("say"):
		_say(String(picked["say"]))
	if int(picked.get("point", -1)) >= 0:
		_set_cursor(int(picked["point"]))
	if picked.has("choose"):
		_cursor = int(picked["choose"])
		_choose()


func point_at(index: int) -> void:
	if not battle_view().is_empty() and menu.point_at(index):
		_set_cursor(index)


func _set_cursor(index: int) -> void:
	_cursor = index
	var view: Dictionary = battle_view()
	var row: Dictionary = _rows[_cursor]
	if not view.is_empty() and not _controls(view) and row.has("suggest"):
		_suggest(view, row)


func _choose() -> void:
	var view: Dictionary = battle_view()
	if not view.is_empty() and not String(view.get("outcome", "")).is_empty():
		_dismissed[String(view["battle"])] = true
		return
	if _rows.is_empty():
		return
	var row: Dictionary = _rows[_cursor]
	if view.is_empty():
		return
	if row.has("session"):
		_run_battle_row(String(view["battle"]), String(row["session"]))
	elif _controls(view) and row.has("command"):
		client.act(String(view["battle"]), row["command"])
	elif row.has("suggest"):
		_suggest(view, row)


func _suggest(view: Dictionary, row: Dictionary) -> void:
	var recipient: String = String((row.get("command", {}) as Dictionary).get("recipient", ""))
	client.suggest(String(view["battle"]), String(row["suggest"]), int(row["value"]), recipient)


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


func _battle_rows(view: Dictionary) -> Array:
	if _has_left(view):
		return [{"text": "REJOIN", "label": "Rejoin the battle", "session": "rejoin"}]
	if bool(view.get("stand_in_due", false)) and (view.get("participants", []) as Array).has(client.player_id):
		var owner_id: String = String(view.get("owner", ""))
		var rows: Array = [{"text": "TAKE OVER for %s" % _name(owner_id), "label": "Take over for %s" % _name_bb(owner_id), "session": "stand_in"}]
		if not _kept_waiting.has(String(view["battle"])):
			rows.append({"text": "KEEP WAITING", "label": "Keep waiting", "session": "wait"})
		return rows + _leave_rows(view)
	match String(view.get("phase", "")):
		"action":
			return _move_rows(view) + _switch_rows(view, "switch") + _item_rows(view) + [
				{"text": "RUN", "label": "Run", "section": " ", "command": {"type": "run"}, "suggest": "run", "value": 0},
			] + _leave_rows(view)
		"send_out":
			return _switch_rows(view, "send_out") + ([
				{"text": "RUN", "label": "Run", "section": " ", "command": {"type": "run"}, "suggest": "run", "value": 0},
			] if bool(view.get("use_next", true)) else []) + _leave_rows(view)
		"learn":
			return _learn_rows(view)
		"mimic":
			return _mimic_rows(view)
		"offer":
			return _switch_rows(view, "switch") + [{"text": "STAY", "label": "Stay in", "section": " ",
				"command": {"type": "stay"}, "suggest": "stay", "value": 0}]
	return _leave_rows(view)


func _leave_rows(view: Dictionary) -> Array:
	if PokeCoopBattleMenu.starts(view, client.player_id) or not String(view.get("outcome", "")).is_empty():
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
	if bool(view.get("versus", false)):
		return []
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
			"command": {"type": "learn", "forget_slot": slot}, "suggest": "learn", "value": slot,
		})
	rows.append({"text": "KEEP OLD MOVES (NOT %s)" % taught, "label": "Keep the old moves", "section": " ",
		"command": {"type": "decline"}, "suggest": "decline", "value": 0})
	return rows


func _mimic_rows(view: Dictionary) -> Array:
	var rows: Array = []
	var moves: Array = (view.get("enemy", {}) as Dictionary).get("moves", [])
	for slot: int in moves.size():
		if int(moves[slot]) != 0:
			rows.append({
				"text": "MIMIC %s" % _move_name(int(moves[slot])), "label": _move_name(int(moves[slot])), "section": "MIMIC WHICH MOVE?",
				"command": {"type": "mimic", "choice": slot}, "suggest": "mimic", "value": slot,
			})
	return rows


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


func _names_bb(player_ids: Variant) -> String:
	var out: PackedStringArray = []
	for player_id: Variant in player_ids as Array:
		out.append(_name_bb(player_id))
	return " and ".join(out) if out.size() < 3 else "%s and %s" % [", ".join(out.slice(0, -1)), out[-1]]


static func _escaped(text: String) -> String:
	return text.replace("[", "[lb]")
