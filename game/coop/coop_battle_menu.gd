class_name PokeCoopBattleMenu
extends RefCounted

## The panel's battle rows as `BattleMenu`'s FIGHT, <PKMN>, ITEM and RUN, the move, party and bag lists and YES/NO boxes.

const NONE: StringName = &""
const MAIN: StringName = &"main"
const MOVES: StringName = &"moves"
const PARTY: StringName = &"party"
const BAG: StringName = &"bag"
const RECIPIENT: StringName = &"recipient"
const ASK: StringName = &"ask"
const LEARN: StringName = &"learn"
const MIMIC: StringName = &"mimic"
const FIGHT: int = 0
const PKMN: int = 1
const ITEM: int = 2
const RUN: int = 3
const PARTY_ROWS: int = 6
const MAIN_OF: Dictionary = {"move": FIGHT, "switch": PKMN, "send_out": PKMN, "item": ITEM, "run": RUN}
const BOX_LINES: Array[Vector2i] = [Vector2i(1, 14), Vector2i(1, 16)]
const HOLLOW: String = "▷"
const SPELL_FRAMES: int = 100

var client: PokeCoopClient = null
var data: GameData = null
var page: StringName = NONE
var cursor: int = 0
var clicks: int = 0
var _main: int = FIGHT
var _moved: int = 0
var _view: Dictionary = {}
var _rows: Array = []
var _idle: int = 0
var _key: String = ""
var _turn: int = -1
var _ask: Dictionary = {}
var _ball: int = 0
var _scroll: int = 0
var _note: String = ""
var _menu_page: Gen2MenuPage = null
var _party_page: Gen2PartyMenuPage = null
var _mart_page: Gen2MartPage = null
var _party_shown: Array = []


static func over(session: PokeCoopClient, game: GameData) -> PokeCoopBattleMenu:
	var out := PokeCoopBattleMenu.new()
	out.client = session
	out.data = game
	return out


## Asks again on a new turn; a partner's lock-in or a join moves the revision on with no events and keeps the open list.
func update(view: Dictionary, rows: Array) -> void:
	_view = view
	_rows = rows
	var battle_id: String = String(view.get("battle", ""))
	var fresh: bool = _key.get_slice("/", 0) != battle_id
	if fresh or not (view.get("events", []) as Array).is_empty():
		_turn = int(view.get("revision", 0))
	var kinds: PackedStringArray = []
	for row: Dictionary in rows:
		if row.has("session"):
			kinds.append(String(row["session"]))
	var key: String = "%s/%d/%s/%s/%s/%s/%s" % [battle_id, _turn, view.get("phase", ""),
		view.get("controller", ""), view.get("outcome", ""), view.get("paused", false), ",".join(kinds)]
	if key == _key:
		cursor = clampi(cursor, 0, maxi(_count() - 1, 0))
		return
	if fresh:
		_main = FIGHT
		_moved = 0
	_key = key
	reopen()


func reopen() -> void:
	_note = ""
	_ask = {}
	_go(NONE, 0)
	if _view.is_empty() or not String(_view.get("outcome", "")).is_empty():
		return
	var rejoin: int = _session("rejoin")
	var stand_in: int = _session("stand_in")
	if rejoin >= 0:
		_question(_de("Rejoin the\nbattle?"), {"choose": rejoin}, {})
	elif stand_in >= 0 and _session("wait") >= 0:
		_question(_take_over_text(), {"choose": stand_in}, {"choose": _session("wait")})
	elif stand_in < 0:
		_open_phase()


func _open_phase() -> void:
	match String(_view.get("phase", "")):
		"action":
			_go(NONE if bool(_view.get("paused", false)) else MAIN, _main)
		"send_out":
			if bool(_view.get("trainer", false)):
				_go(PARTY, 0)
			else:
				_question(Gen2BattleSwitchMenu.use_next_text(), {"page": PARTY},
					_run_or_leave() if _controls() else {"choose": _command("run")}, true)
		"learn":
			_ask_forget()
		"mimic":
			_go(MIMIC, 0)
		"offer":
			_question(_offer_text(), {"page": PARTY}, {"choose": _command("stay")}, true)


func press(button: int) -> Dictionary:
	_note = ""
	var spelling: bool = _spelling() >= 0
	_idle = 0
	if spelling:
		return {}
	match page:
		MAIN:
			return _press_main(button)
		ASK:
			return _press_ask(button)
		NONE:
			return _press_none(button)
	return _press_list(button)


func _press_main(button: int) -> Dictionary:
	if button == PokeButton.A:
		clicks += 1
		_main = cursor
		match cursor:
			FIGHT:
				return _go(MOVES, _moved)
			PKMN:
				return _go(PARTY, 0)
			ITEM:
				if bool(_view.get("versus", false)):
					return {"say": _de("Items cannot be\nused here.")}
				return _go(BAG, 0)
		return _run()
	if not PokeButton.is_direction(button):
		return {}
	var moved: int = Gen2BattleMenu.main_moved(cursor + 1, button) - 1
	if moved == cursor:
		return {}
	cursor = moved
	_main = moved
	return {"point": _pointed()}


func _run() -> Dictionary:
	var leave: int = _session("leave")
	if leave >= 0:
		var cancel: bool = String(_rows[leave].get("text", "")) == "CANCEL JOIN"
		return _question(_de("Cancel joining\nthe battle?" if cancel else "Leave the battle?\nYour team stays."),
			{"choose": leave}, {"reopen": true})
	return _chosen(_command("run"))


func _run_or_leave() -> Dictionary:
	return {"ask": "leave"} if _session("leave") >= 0 else {"choose": _command("run")}


func _press_ask(button: int) -> Dictionary:
	match button:
		PokeButton.UP, PokeButton.DOWN:
			cursor = 1 - cursor
			return {"point": _pointed()}
		PokeButton.A:
			clicks += 1
			return _act(_ask["yes"] if cursor == 0 else _ask["no"])
		PokeButton.B:
			return _act(_ask["no"])
	return {}


func _act(action: Dictionary) -> Dictionary:
	if action.has("choose"):
		return _chosen(int(action["choose"]))
	if action.has("page"):
		return _go(StringName(action["page"]), _main if StringName(action["page"]) == MAIN else 0)
	if action.has("ask"):
		return _run()
	if action.has("learn_stop"):
		return _stop_learning()
	if action.has("forget_ask"):
		return _ask_forget()
	if action.has("reopen"):
		reopen()
		return {}
	return _go(NONE, 0)


func _press_none(button: int) -> Dictionary:
	if button == PokeButton.A and _session("stand_in") >= 0:
		return _question(_take_over_text(), {"choose": _session("stand_in")}, {})
	if button == PokeButton.B and _session("leave") >= 0:
		return _run()
	return {}


func _press_list(button: int) -> Dictionary:
	var count: int = _count()
	match button:
		PokeButton.UP, PokeButton.DOWN:
			var step: int = -1 if button == PokeButton.UP else 1
			cursor = clampi(cursor + step, 0, count - 1) if page == BAG else posmod(cursor + step, maxi(count, 1))
			if page == MOVES:
				_moved = cursor
			return {"point": _pointed()}
		PokeButton.B:
			return _back()
		PokeButton.A:
			clicks += 1
			return _pick()
	return {}


func _back() -> Dictionary:
	match page:
		RECIPIENT:
			return _go(BAG, _entry_of(_ball))
		LEARN:
			return _stop_learning()
		MIMIC:
			return {}
		PARTY:
			if String(_view.get("phase", "")) in ["send_out", "offer"]:
				reopen()
				return {}
	return _go(MAIN, _main)


func _pick() -> Dictionary:
	match page:
		MOVES:
			return _pick_move()
		PARTY:
			return _pick_ally()
		BAG:
			var entries: Array = _entries()
			if cursor >= entries.size():
				return _go(MAIN, _main)
			var entry: Dictionary = entries[cursor]
			if (entry["rows"] as Array).size() > 1:
				_ball = int(entry["item"])
				return _go(RECIPIENT, maxi(0, _list(RECIPIENT).find_custom(_mine)))
			return _chosen(int(entry["rows"][0]))
	return _chosen(current())


## `.use_move`'s two refusals, said and then the list again.
func _pick_move() -> Dictionary:
	var row: int = current()
	var slot: int = int((_rows[row]["command"] as Dictionary).get("slot", 0)) if row >= 0 else -1
	var active: Dictionary = _active()
	if slot == int(active.get("disabled", -1)):
		return {"say": _de("The move is\ndisabled!")}
	var pp: Array = active.get("pp", [])
	if slot >= 0 and slot < pp.size() and int(pp[slot]) <= 0:
		return {"say": _de("No PP left for\nthis move!")}
	return _chosen(row)


## `SwitchMonAlreadyOut` and `HasMonFainted`, told on the list's own box.
func _pick_ally() -> Dictionary:
	var allies: Array = _view.get("allies", [])
	if cursor >= allies.size():
		return {}
	var ally: Dictionary = allies[cursor]
	var name: String = _ally_name(ally)
	if int(ally.get("hp", 0)) <= 0:
		_note = Gen2BattleSwitchMenu.no_energy_text(true)
	elif int(ally["index"]) == int(_view.get("active", -1)):
		_note = Gen2BattleSwitchMenu.already_out_text(name, true)
	else:
		return _chosen(current())
	return {}


func _chosen(row: int) -> Dictionary:
	if row < 0:
		return {}
	if _controls() or _rows[row].has("session"):
		_go(NONE, 0)
	return {"choose": row}


func _go(to: StringName, at: int) -> Dictionary:
	page = to
	cursor = at
	_scroll = 0
	return {"point": _pointed()} if to != NONE else {}


func _ask_forget() -> Dictionary:
	var learning: Dictionary = _view.get("learning", {})
	return _question(PokeCoopBattleField.forget_ask(String(learning.get("name", _learner().get("name", ""))),
		_move_name(int(learning.get("move", 0))), data, true), {"page": LEARN}, {"learn_stop": true})


func _stop_learning() -> Dictionary:
	var move: String = _move_name(int((_view.get("learning", {}) as Dictionary).get("move", 0)))
	return _question(Gen2MoveForget.stop_text(move, RomRegistry.GEN1), {"choose": _command("decline")}, {"forget_ask": true})


func _question(text: String, yes: Dictionary, no: Dictionary, battle_box: bool = false) -> Dictionary:
	_ask = {"text": text, "yes": yes, "no": no, "battle_box": battle_box}
	return _go(ASK, 0)


func current() -> int:
	match page:
		MAIN:
			return _command("run") if cursor == RUN and _session("leave") < 0 else -1
		ASK:
			return int((_ask["yes"] if cursor == 0 else _ask["no"]).get("choose", -1))
		PARTY:
			var allies: Array = _view.get("allies", [])
			return _ally_row(int(allies[cursor]["index"])) if cursor < allies.size() else -1
		BAG:
			var entries: Array = _entries()
			return int(entries[cursor]["rows"][0]) if cursor < entries.size() and entries[cursor]["rows"].size() == 1 else -1
		NONE:
			return -1
	var rows: Array = _list(page)
	return int(rows[cursor]) if cursor < rows.size() else -1


func _pointed() -> int:
	var entries: Array = _entries() if page == BAG else []
	return int(entries[cursor]["rows"][0]) if cursor < entries.size() else current()


func _count() -> int:
	match page:
		MAIN:
			return 4
		ASK:
			return 2
		PARTY:
			return (_view.get("allies", []) as Array).size()
		BAG:
			return _entries().size() + 1
	return _list(page).size()


func _list(of: StringName) -> Array:
	var kind: String = {MOVES: "move", LEARN: "learn", MIMIC: "mimic", RECIPIENT: "item"}.get(of, "")
	var out: Array = []
	for index: int in _rows.size():
		var command: Dictionary = (_rows[index] as Dictionary).get("command", {})
		if String(command.get("type", "")) == kind and (of != RECIPIENT or int(command.get("item", 0)) == _ball):
			out.append(index)
	return out


func _entries() -> Array:
	var out: Array = []
	for index: int in _rows.size():
		var command: Dictionary = (_rows[index] as Dictionary).get("command", {})
		if String(command.get("type", "")) != "item":
			continue
		var at: int = out.find_custom(func(entry: Dictionary) -> bool: return int(entry["item"]) == int(command["item"]))
		if at < 0:
			out.append({"item": int(command["item"]), "rows": [index]})
		else:
			(out[at]["rows"] as Array).append(index)
	return out


func _entry_of(item: int) -> int:
	return maxi(0, _entries().find_custom(func(entry: Dictionary) -> bool: return int(entry["item"]) == item))


func _mine(row: int) -> bool:
	return String((_rows[row]["command"] as Dictionary).get("recipient", "")) == client.player_id


func _ally_row(index: int) -> int:
	return _rows.find_custom(func(row: Dictionary) -> bool:
		var command: Dictionary = row.get("command", {})
		return String(command.get("type", "")) in ["switch", "send_out"] and int(command.get("index", -1)) == index)


func _command(kind: String) -> int:
	return _rows.find_custom(func(row: Dictionary) -> bool: return String(row.get("command", {}).get("type", "")) == kind)


func _session(kind: String) -> int:
	return _rows.find_custom(func(row: Dictionary) -> bool: return String(row.get("session", "")) == kind)


func _controls() -> bool:
	return String(_view.get("controller", "")) == client.player_id


static func starts(view: Dictionary, player_id: String) -> bool:
	var attached: Array = view.get("attached", [])
	var participants: Array = view.get("participants", [])
	return attached.has(player_id) or (attached.is_empty() and not participants.is_empty()
		and String(participants[0]) == player_id)


func _active() -> Dictionary:
	for ally: Dictionary in _view.get("allies", []):
		if int(ally["index"]) == int(_view.get("active", -1)):
			return ally
	return {}


func button_toward(target: int) -> int:
	if target < 0 or target >= _rows.size():
		return PokeButton.NONE
	if current() == target:
		return PokeButton.A
	var place: Dictionary = _place_of(target)
	match page:
		MAIN:
			return _main_toward(int(place.get("main", -1)))
		ASK:
			return _ask_toward(place, target)
		NONE:
			return PokeButton.A if place.get("page") == ASK and _session("stand_in") >= 0 else (
				PokeButton.B if place.get("main") == RUN else PokeButton.NONE)
	if page == BAG and place.get("page") == RECIPIENT:
		return _step_toward(int(place["entry"]))
	if page == place.get("page") and place.has("at"):
		return _step_toward(int(place["at"]))
	if page == LEARN and place.get("page") == ASK:
		return PokeButton.B
	return PokeButton.B if page != MIMIC else PokeButton.NONE


func _main_toward(option: int) -> int:
	if option < 0:
		return PokeButton.NONE
	if option == cursor:
		return PokeButton.A
	if (option >= ITEM) != (cursor >= ITEM):
		return PokeButton.DOWN if option > cursor else PokeButton.UP
	return PokeButton.RIGHT if option > cursor else PokeButton.LEFT


func _ask_toward(place: Dictionary, target: int) -> int:
	for option: int in 2:
		var action: Dictionary = _ask["yes"] if option == 0 else _ask["no"]
		var leads: bool = int(action.get("choose", -1)) == target or (action.has("page") and action["page"] == place.get("page")) \
			or (action.has("ask") and place.get("main") == RUN) or (action.has("learn_stop") and place.get("page") == ASK) \
			or (action.has("forget_ask") and place.get("page") == LEARN)
		if leads:
			return PokeButton.A if option == cursor else (PokeButton.DOWN if option > cursor else PokeButton.UP)
	return PokeButton.B


func _step_toward(at: int) -> int:
	return PokeButton.A if at == cursor else (PokeButton.DOWN if at > cursor else PokeButton.UP)


func _place_of(target: int) -> Dictionary:
	var row: Dictionary = _rows[target]
	var command: Dictionary = row.get("command", {})
	var kind: String = String(command.get("type", row.get("session", "")))
	match kind:
		"move":
			return {"page": MOVES, "at": _list(MOVES).find(target), "main": FIGHT}
		"switch", "send_out":
			var allies: Array = _view.get("allies", [])
			return {"page": PARTY, "main": PKMN,
				"at": allies.find_custom(func(ally: Dictionary) -> bool: return int(ally["index"]) == int(command["index"]))}
		"item":
			var entry: int = _entry_of(int(command["item"]))
			var rows: Array = _entries()[entry]["rows"] if not _entries().is_empty() else []
			if rows.size() > 1:
				return {"page": RECIPIENT, "entry": entry, "at": rows.find(target), "main": ITEM}
			return {"page": BAG, "at": entry, "main": ITEM}
		"learn":
			return {"page": LEARN, "at": _list(LEARN).find(target)}
		"mimic":
			return {"page": MIMIC, "at": _list(MIMIC).find(target)}
		"run", "leave":
			return {"page": ASK, "main": RUN}
	return {"page": ASK}


func point_at(target: int) -> bool:
	for _step: int in 64:
		if current() == target:
			return true
		var button: int = button_toward(target)
		if button == PokeButton.NONE or button == PokeButton.A and page in [MOVES, PARTY, LEARN, MIMIC]:
			return false
		press(button)
	return false


func marks() -> Dictionary:
	var out: Dictionary = {}
	for player_id: String in _partners():
		var at: int = _mark_at(_view["suggestions"][player_id])
		if at >= 0:
			(out.get_or_add(at, []) as Array).append(player_id)
	return out


func _partners() -> Array:
	var suggestions: Dictionary = _view.get("suggestions", {})
	return (_view.get("participants", []) as Array).map(func(player_id: Variant) -> String: return String(player_id)) \
		.filter(func(player_id: String) -> bool: return player_id != client.player_id and suggestions.has(player_id))


func _mark_at(said: Dictionary) -> int:
	if page == MAIN:
		return int(MAIN_OF.get(String(said.get("type", "")), -1))
	if page == ASK:
		if (_ask["yes"] as Dictionary).get("page") == PARTY and String(said.get("type", "")) in ["switch", "send_out"]:
			return 0
		for at: int in 2:
			var row: int = int((_ask["no"] if at == 1 else _ask["yes"]).get("choose", -1))
			if row >= 0 and _says(_rows[row], said):
				return at
		return -1
	if not page in [MOVES, PARTY, BAG, RECIPIENT, LEARN, MIMIC]:
		return -1
	for at: int in _count():
		var row: int = _row_at(at)
		if row >= 0 and _says(_rows[row], said):
			return at
	return -1


func _says(row: Dictionary, said: Dictionary) -> bool:
	if String(row.get("suggest", "")) != String(said.get("type", "")) or int(row.get("value", -1)) != int(said.get("value", -2)):
		return false
	return page != RECIPIENT or String((row["command"] as Dictionary).get("recipient", "")) == String(said.get("recipient", ""))


## `.battle_player_moves`' hollow `▷`, or with several partners each one's initial on the row they point at.
func _glyph(players: Array) -> String:
	if players.size() > 1 or (_view.get("participants", []) as Array).size() < 3:
		return HOLLOW
	return _name(String(players[0])).left(1)


func spelled() -> Array:
	var out: Array = []
	for player_id: String in _partners():
		var said: Dictionary = _view["suggestions"][player_id]
		out.append([_de("%s suggests") % _name(player_id), _suggestion_words(said)])
	return out


func _suggestion_words(said: Dictionary) -> String:
	var value: int = int(said.get("value", -1))
	match String(said.get("type", "")):
		"move":
			var moves: Array = _active().get("moves", [])
			return _move_name(int(moves[value])) if value >= 0 and value < moves.size() else ""
		"switch", "send_out":
			var allies: Array = _view.get("allies", [])
			var at: int = allies.find_custom(func(ally: Dictionary) -> bool: return int(ally["index"]) == value)
			return _ally_name(allies[at]) if at >= 0 else ""
		"item":
			var named: String = data.item_name(value) if data != null else ""
			var whom: String = _name(String(said.get("recipient", "")))
			var whole: String = _de("%s for %s") % [named, whom]
			return whole if not String(said.get("recipient", "")).is_empty() and whole.length() <= 18 else named
		"stay":
			return _de("NO")
	return _de("RUN")


func _spelling() -> int:
	if page != MAIN or not _controls():
		return -1
	var count: int = _partners().size()
	return (_idle / SPELL_FRAMES) % (count + 1) - 1 if count > 0 else -1


func _row_at(at: int) -> int:
	var keep: int = cursor
	cursor = at
	var row: int = _pointed()
	cursor = keep
	return row


func signature() -> String:
	return "%s|%d|%d|%s|%s|%s|%d|%s|%s|%s" % [page, cursor, _scroll, marks(), _note, _key, _spelling(), spelled(), _ask.get("text", ""),
		_party_page.animation_signature() if _party_page != null and page == PARTY else ""]


func advance() -> void:
	_idle += 1
	if page == PARTY and _party_page != null and not _party_shown.is_empty():
		_party_page.advance(_party_shown, cursor - _scroll)


func image() -> Image:
	var out := Image.create_empty(Gen2Screen.WIDTH, Gen2Screen.HEIGHT, false, Image.FORMAT_RGBA8)
	if _menu_page == null:
		_menu_page = Gen2MenuPage.from_data(data) if data != null else null
	if _menu_page == null or page == NONE:
		return out
	match page:
		MAIN:
			var spelling: int = _spelling()
			if spelling >= 0:
				_text_box(out, spelled()[spelling])
				return out
			_text_box(out, _left_lines())
			_put(out, Gen2BattleMenu.main_box(), Gen2BattleMenu.main_options(false, data.generation), cursor)
		MOVES:
			_text_box(out, [])
			_draw_moves(out)
		PARTY:
			_draw_party(out)
		BAG, RECIPIENT:
			_draw_bag(out)
		ASK:
			_text_box(out, _box_lines(String(_ask["text"])))
			_put(out, _yes_no_box(), ["YES", "NO"], cursor)
		LEARN:
			_text_box(out, _box_lines(_de("Which move should\nbe forgotten?")))
			_put(out, Gen2BattleMenu.forget_box(true), _learner_moves(), cursor)
		MIMIC:
			_text_box(out, [])
			_put(out, Gen2BattleMenu.move_box(), _list(MIMIC).map(_row_move_name), cursor)
	_stamp_marks(out)
	return out


func _stamp_marks(out: Image) -> void:
	var shown: Dictionary = marks()
	for at: int in shown:
		var tile: Vector2i = _mark_tile(at)
		if at == cursor or tile.x < 0:
			continue
		var cell := PackedByteArray()
		cell.resize(Gen2Font.TILE * Gen2Font.TILE)
		_menu_page.font.draw_text(_glyph(shown[at]), cell, Gen2Font.TILE, 0, 0)
		var drawn: Image = Gen2PicImage.from_indices(cell, Gen2Font.TILE, Gen2Font.TILE,
			PokePalette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK])))
		out.blit_rect(drawn, Rect2i(Vector2i.ZERO, drawn.get_size()), tile * Gen2Font.TILE)


func _mark_tile(at: int) -> Vector2i:
	var hidden := Vector2i(-1, -1)
	match page:
		MAIN:
			return Gen2BattleMenu.main_box().cursor_position(at)
		ASK:
			return _yes_no_box().cursor_position(at)
		MOVES, MIMIC:
			return Gen2BattleMenu.move_box().cursor_position(at)
		LEARN:
			return Gen2BattleMenu.forget_box(true).cursor_position(at)
		RECIPIENT:
			return _recipient_box().cursor_position(at)
		PARTY:
			var row: int = at - _scroll
			return Vector2i(Gen2PartyMenuPage.CURSOR_COLUMN, Gen2PartyMenuPage.GEN1_CURSOR_ROW + row * Gen2PartyMenuPage.ROW_STEP) \
				if row >= 0 and row < PARTY_ROWS else hidden
		BAG:
			var row: int = at - _scroll
			return Vector2i(Gen2MartPage.GEN1_CURSOR_COLUMN, Gen2MartPage.GEN1_NAME_AT.y + row * Gen2MartPage.ROW_STEP) \
				if row >= 0 and row < Gen2MartPage.GEN1_CURSOR_ROWS else hidden
	return hidden


func _text_box(out: Image, lines: Array) -> void:
	var extras: Array = []
	for line: int in mini(lines.size(), BOX_LINES.size()):
		extras.append({"text": String(lines[line]), "at": BOX_LINES[line]})
	_put(out, Gen2MenuBox.from_coords(0, Gen2BattleMenu.MAIN_TOP, Gen2BattleMenu.MAIN_RIGHT, Gen2BattleMenu.MAIN_BOTTOM, 0),
		[], -1, extras)


static func _box_lines(text: String) -> Array:
	var paged: PackedStringArray = PokeCoopBattleField.pages(text)
	return Array(paged[0].split("\n")) if not paged.is_empty() else []


func _put(out: Image, box: Gen2MenuBox, options: Array, at: int, extras: Array = []) -> void:
	var drawn: Image = _menu_page.render(box, options, at, "", 0, extras)
	out.blit_rect(drawn, Rect2i(Vector2i.ZERO, drawn.get_size()), box.border_position() * Gen2Font.TILE)


func _left_lines() -> Array:
	var controller: String = String(_view.get("controller", ""))
	var owner: String = String(_view.get("owner", controller))
	if (_view.get("pending", []) as Array).has(client.player_id):
		return [_de("Joining"), _de("soon")]
	if controller != client.player_id:
		return [_name(controller), _de("decides")]
	return [_de("For"), _name(owner)] if owner != controller else []


## `MoveSelectionScreen`'s list and `MoveInfoBox` beside it.
func _draw_moves(out: Image) -> void:
	var box: Gen2MenuBox = Gen2BattleMenu.move_box()
	var rows: Array = _list(MOVES)
	_put(out, box, rows.map(_row_move_name), cursor)
	var active: Dictionary = _active()
	var slot: int = int((_rows[rows[cursor]]["command"] as Dictionary).get("slot", 0)) if cursor < rows.size() else -1
	var moves: Array = active.get("moves", [])
	if slot < 0 or slot >= moves.size():
		return
	var extras: Array = [{"text": Gen2BattleMenu.INFO_DISABLED, "at": Gen2BattleMenu.INFO_DISABLED_AT}]
	if slot != int(active.get("disabled", -1)):
		var full: Array = active.get("max_pp", [])
		var top: int = int(full[slot]) if slot < full.size() else int(data.move(int(moves[slot])).get("pp", 0))
		extras = [{"text": Gen2BattleMenu.INFO_TYPE_LABEL, "at": Gen2BattleMenu.INFO_TYPE_LABEL_AT},
			{"text": data.type_name(int(data.move(int(moves[slot])).get("type", 0))), "at": Gen2BattleMenu.INFO_TYPE_AT},
			{"text": "%2d/%2d" % [int((active.get("pp", []) as Array)[slot]), top], "at": Gen2BattleMenu.INFO_PP_AT}]
	_put(out, Gen2BattleMenu.info_box(), [], -1, extras)


func _draw_party(out: Image) -> void:
	if _party_page == null:
		_party_page = Gen2PartyMenuPage.from_data(data)
	if _party_page == null:
		return
	var allies: Array = _view.get("allies", [])
	_scroll = Gen2BattleMenu.list_scrolled(_scroll, cursor, allies.size(), PARTY_ROWS)
	var shown: Array = allies.slice(_scroll, _scroll + PARTY_ROWS).map(_party_row)
	if shown.map(_species_of) != _party_shown.map(_species_of):
		_party_page.reset(shown, cursor - _scroll)
	_party_shown = shown
	var drawn: Image = _party_page.render(shown, cursor - _scroll, _party_prompt(allies), false)
	out.blit_rect(drawn, Rect2i(Vector2i.ZERO, drawn.get_size()), Vector2i.ZERO)


func _party_prompt(allies: Array) -> String:
	if not _note.is_empty():
		return _note
	var first: String = Gen2BattleSwitchMenu.prompt_text(data, &"player" if String(_view.get("phase", "")) == "action" else &"")
	if not _controls():
		first = _de("%s decides.") % _name(String(_view.get("controller", "")))
	if first.contains("\n") or cursor >= allies.size():
		return first
	return first + "\n" + _de("%s's POKéMON") % _name(String(allies[cursor].get("owner", "")))


## `DisplayBagMenu`'s list, CANCEL last, and the players a ball could be thrown for over it.
func _draw_bag(out: Image) -> void:
	if _mart_page == null:
		_mart_page = Gen2MartPage.from_data(data)
	if _mart_page == null:
		return
	var entries: Array = _entries()
	var bag: Dictionary = client.me().get("items", {})
	var at: int = cursor if page == BAG else _entry_of(_ball)
	var listed: Array = entries.map(func(entry: Dictionary) -> Dictionary: return {"item": entry["item"],
		"name": data.item_name(int(entry["item"])), "quantity": int(bag.get(entry["item"], bag.get(str(entry["item"]), 1)))})
	var scroll: int = Gen2BattleMenu.list_scrolled(_scroll if page == BAG else 0, at, listed.size() + 1, Gen2MartPage.GEN1_CURSOR_ROWS)
	_scroll = scroll if page == BAG else _scroll
	if page == RECIPIENT:
		_text_box(out, _box_lines(_de("Who gets\n%s?") % _species_name(int((_view.get("enemy", {}) as Dictionary).get("species", 0)))))
	else:
		_text_box(out, _left_lines())
	var list: Image = _mart_page.render_gen1_pack({
		"rows": Gen2WorldPack.list_rows(data, Gen1Layout.BAG_POCKET, listed, scroll, true, Gen2MartPage.GEN1_LIST_HEIGHT),
		"cursor": at - scroll if page == BAG else -1,
		"held": at - scroll if page == RECIPIENT else -1,
	})
	out.blend_rect(list, Rect2i(Vector2i.ZERO, list.get_size()), Vector2i.ZERO)
	if page == RECIPIENT:
		_draw_recipients(out)


func _draw_recipients(out: Image) -> void:
	_put(out, _recipient_box(), _recipients(), cursor)


func _recipients() -> Array:
	return _list(RECIPIENT).map(func(row: int) -> String:
		return _name(String((_rows[row]["command"] as Dictionary).get("recipient", ""))))


func _recipient_box() -> Gen2MenuBox:
	var names: Array = _recipients()
	var widest: int = names.reduce(func(most: int, name: String) -> int: return maxi(most, name.length()), 0)
	var right: int = Gen2BattleMenu.MAIN_RIGHT
	var bottom: int = Gen2BattleMenu.MAIN_TOP - 1
	return Gen2MenuBox.from_coords(right - widest - 2, bottom - names.size() * 2, right, bottom,
		Gen2MenuBox.STATICMENU_CURSOR | Gen2MenuBox.STATICMENU_NO_TOP_SPACING)


static func _species_of(row: Dictionary) -> int:
	return int(row["species"])


func _learner_moves() -> Array:
	return _list(LEARN).map(func(row: int) -> String:
		var learner: Dictionary = _learner()
		var slot: int = int((_rows[row]["command"] as Dictionary).get("forget_slot", 0))
		var moves: Array = learner.get("moves", [])
		return _move_name(int(moves[slot])) if slot < moves.size() else "")


func _learner() -> Dictionary:
	var index: int = int((_view.get("learning", {}) as Dictionary).get("index", -1))
	var allies: Array = _view.get("allies", [])
	return allies[index] if index >= 0 and index < allies.size() else _active()


func _row_move_name(row: int) -> String:
	var command: Dictionary = _rows[row]["command"]
	if command.has("choice"):
		var moves: Array = (_view.get("enemy", {}) as Dictionary).get("moves", [])
		return _move_name(int(moves[int(command["choice"])]))
	return _move_name(int((_active().get("moves", []) as Array)[int(command.get("slot", 0))]))


func _yes_no_box() -> Gen2MenuBox:
	if not bool(_ask.get("battle_box", false)):
		return Gen2MenuBox.yes_no()
	var left: int = Gen2BattleScreen.YES_NO_LEFT
	var top: int = Gen2BattleScreen.YES_NO_TOP
	return Gen2MenuBox.from_coords(left, top, left + Gen2BattleScreen.YES_NO_SPAN.x + Gen1LayoutDe.yes_no_widened(),
		top + Gen2BattleScreen.YES_NO_SPAN.y, Gen2BattleScreen.YES_NO_FLAGS)


func _offer_text() -> String:
	return Gen2BattleSwitchMenu.offer_text("", "", _name(String(_view.get("controller", ""))), true) \
		.get_slice(Gen2TextStream.PAGE_BREAK, 1)


func _take_over_text() -> String:
	return _de("%s is away.\nTake over?") % _name(String(_view.get("owner", _view.get("controller", ""))))


func _name(player_id: String) -> String:
	var view: Dictionary = (client.state.get("players", {}) as Dictionary).get(player_id, {})
	return String(view.get("name", player_id))


func _party_row(ally: Dictionary) -> Dictionary:
	return {
		"index": int(ally["index"]), "species": int(ally["species"]), "name": _ally_name(ally),
		"level": int(ally["level"]), "hp": int(ally["hp"]), "max_hp": int(ally["max_hp"]),
		"status": int(ally.get("status", 0)), "fainted": int(ally["hp"]) <= 0,
	}


func _ally_name(ally: Dictionary) -> String:
	var named: String = String(ally.get("name", ""))
	return named if not named.is_empty() else _species_name(int(ally.get("species", 0)))


func _species_name(species: int) -> String:
	return String(data.species(species).get("name", "")) if data != null and species > 0 else ""


func _move_name(move: int) -> String:
	return String(data.move(move).get("name", "")) if data != null else ""


func _de(english: String) -> String:
	return Gen1LayoutDe.ui(data.id if data != null else &"", english)
