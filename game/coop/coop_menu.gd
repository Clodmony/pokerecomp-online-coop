class_name PokeCoopMenu
extends Node

signal leave_requested
signal acted

const MENU_ID: StringName = &"coop_menu"
const LABEL: String = "CO-OP"
const COLUMNS: int = Gen2Screen.WIDTH / Gen2Font.TILE
const ROWS: int = Gen2Screen.HEIGHT / Gen2Font.TILE
const HEADER_LINES: int = 5
const LIST_FLAGS: int = Gen2MenuBox.STATICMENU_CURSOR | Gen2MenuBox.STATICMENU_NO_TOP_SPACING
const QUESTION_TOP: int = 12

var client: PokeCoopClient = null
var data: GameData = null
var hardware: Gen2Screen = null
var blocked: Callable = Callable()
var select_allowed: Callable = Callable()
var _rows: Array = []
var _cursor: int = 0
var _scroll: int = 0
var _open: bool = false
var _asking: bool = false
var _no: bool = false
var _page: Gen2MenuPage = null
var _picture: TextureRect = null
var _shown: String = ""


static func over(session: PokeCoopClient, game_data: GameData) -> PokeCoopMenu:
	var out := PokeCoopMenu.new()
	out.client = session
	out.data = game_data
	return out


static func claim_start_entry() -> void:
	Gen2ModHost.instance().register_menu_entry(Gen2ModHost.MENU_START, MENU_ID, {
		"label": LABEL,
		"handler": func() -> void: _open_listed(),
		"visible": func(_context: Dictionary) -> bool: return listed(),
	})


static func listed() -> bool:
	return _session_menu() != null


static func _open_listed() -> void:
	if listed():
		_session_menu().open()


static func _session_menu() -> PokeCoopMenu:
	var runtime: Gen2GameRuntime = Gen2GameRuntime.instance()
	var coop: PokeCoopSession = runtime.coop if runtime != null else null
	return coop.menu if coop != null and coop.menu != null and is_instance_valid(coop.menu) else null


func is_open() -> bool:
	return _open


func open() -> void:
	if _open or client == null or (blocked.is_valid() and bool(blocked.call())):
		return
	_open = true
	_asking = false
	_cursor = 0
	_scroll = 0
	_shown = ""
	if hardware != null and is_instance_valid(hardware) and data != null:
		_page = _page if _page != null else Gen2MenuPage.from_data(data)
		_picture = TextureRect.new()
		_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_picture.z_index = 50
		hardware.display(_picture)
	_refresh()


func close() -> void:
	_open = false
	_asking = false
	Gen2Screen.drop(_picture)
	_picture = null


func _exit_tree() -> void:
	if _picture != null:
		Gen2Screen.drop_on_exit(_picture)
		_picture = null


func _process(_delta: float) -> void:
	if not _open:
		return
	if blocked.is_valid() and bool(blocked.call()):
		close()
		return
	_refresh()


func _input(event: InputEvent) -> void:
	var button: int = PokeButton.pressed_in(event)
	if button == PokeButton.NONE or client == null:
		return
	if not _open:
		if button == PokeButton.SELECT and (not select_allowed.is_valid() or bool(select_allowed.call())) \
				and not (blocked.is_valid() and bool(blocked.call())):
			open()
			get_viewport().set_input_as_handled()
		return
	press(button)
	get_viewport().set_input_as_handled()


func press(button: int) -> void:
	if _asking:
		match button:
			PokeButton.UP, PokeButton.DOWN:
				_no = not _no
			PokeButton.A:
				_answer(not _no)
			PokeButton.B:
				_answer(false)
		_refresh()
		return
	match button:
		PokeButton.UP, PokeButton.DOWN:
			if not _rows.is_empty():
				_set_cursor(posmod(_cursor + (-1 if button == PokeButton.UP else 1), _rows.size()))
		PokeButton.A:
			_choose()
		PokeButton.B, PokeButton.SELECT, PokeButton.START:
			close()


func _set_cursor(index: int) -> void:
	_cursor = index
	var shown: int = _window(_header().size())
	_scroll = clampi(clampi(_scroll, _cursor - shown + 1, _cursor), 0, maxi(_rows.size() - shown, 0))
	_refresh()


func _choose() -> void:
	if _rows.is_empty():
		return
	var row: Dictionary = _rows[_cursor]
	match String(row.get("action", "")):
		"fight":
			client.start_battle(String(row["id"]))
		"join":
			client.join_battle(String(row["id"]))
		"leave":
			_asking = true
			_no = false
			_refresh()
			return
	if row.has("id"):
		acted.emit()
	close()


func _answer(yes: bool) -> void:
	_asking = false
	if not yes:
		return
	close()
	acted.emit()
	leave_requested.emit()


func rows() -> Array:
	var out: Array = []
	for offer: Dictionary in client.state.get("encounters", []):
		out.append({"text": "FIGHT %s" % offer["label"], "label": _ui("FIGHT"), "detail": String(offer["label"]),
			"action": "fight", "id": offer["id"]})
	for running: Dictionary in client.state.get("battles", []):
		var against: String = _ui("VS %s") % _foe(running)
		if (running.get("left", []) as Array).has(client.player_id):
			out.append({"text": "REJOIN %s" % running["battle"], "label": _ui("REJOIN"), "detail": against,
				"action": "join", "id": running["battle"]})
		elif not (running["participants"] as Array).has(client.player_id) and not bool(running.get("private", false)):
			var names: String = ", ".join(PackedStringArray((running["participants"] as Array).map(_name)))
			out.append({"text": "JOIN %s (%s)" % [running["battle"], names], "label": _ui("JOIN %s") % names,
				"detail": against, "action": "join", "id": running["battle"]})
	out.append({"text": "LEAVE SESSION", "label": _ui("LEAVE SESSION"), "action": "leave"})
	out.append({"text": "CANCEL", "label": _ui("CANCEL"), "action": "cancel"})
	return out


func _header() -> PackedStringArray:
	var title: String = PokeCoopTransport.text((client.state.get("campaign", {}) as Dictionary).get("title"))
	var lines: PackedStringArray = [title] if not title.is_empty() else []
	var titled: int = lines.size()
	var everyone: Dictionary = client.state.get("players", {})
	for player_id: String in everyone:
		var view: Dictionary = everyone[player_id]
		if player_id == client.player_id or not bool(view.get("connected", true)):
			continue
		var name: String = String(view.get("name", player_id))
		var where: String = _ui("IN A BATTLE") if not String(view.get("battle", "")).is_empty() \
			else _ui("IN THE OPENING") if view.get("opening") == true else _place(view.get("map"))
		if ("%s %s" % [name, where]).length() <= COLUMNS - 2:
			lines.append(("%s %s" % [name, where]).strip_edges())
		else:
			lines.append_array([name, " " + where])
	if lines.size() == titled:
		lines.append(_ui("NO PARTNER YET"))
	lines = lines.slice(0, HEADER_LINES - 1)
	lines.append(last_saved(client, data.id if data != null else &""))
	return lines


static func last_saved(session: PokeCoopClient, game_id: StringName = &"") -> String:
	var ago: float = float((session.state.get("saved", {}) as Dictionary).get("ago", -1.0))
	if ago < 0.0:
		return Gen1LayoutDe.ui(game_id, "NOT SAVED YET")
	var seconds: int = int(ago) + (Time.get_ticks_msec() - session.state_at) / 1000
	if seconds <= 1:
		return Gen1LayoutDe.ui(game_id, "SAVED JUST NOW")
	if seconds < 60:
		return Gen1LayoutDe.ui(game_id, "SAVED %d SEC. AGO") % seconds
	return Gen1LayoutDe.ui(game_id, "SAVED %d MIN. AGO") % (seconds / 60)


func _refresh() -> void:
	_rows = rows()
	_cursor = clampi(_cursor, 0, maxi(_rows.size() - 1, 0))
	var header: PackedStringArray = _header()
	var key: String = "%s|%s|%d|%d|%s|%s" % [header, _rows.map(func(row: Dictionary) -> String: return row["text"]),
		_cursor, _scroll, _asking, _no]
	if key == _shown or _picture == null or _page == null:
		return
	_shown = key
	var indices := PackedByteArray()
	indices.resize(Gen2Screen.WIDTH * Gen2Screen.HEIGHT)
	var extras: Array = []
	for line: int in header.size():
		extras.append({"text": header[line], "at": Vector2i(1, 1 + line), "max_tiles": COLUMNS - 2})
	var info: Gen2MenuBox = Gen2MenuBox.from_coords(0, 0, COLUMNS - 1, header.size() + 1, Gen2MenuBox.STATICMENU_PLACE_TITLE)
	_page.draw(info, [], -1, indices, Gen2Screen.WIDTH, LABEL, 1, extras)
	if _asking:
		_page.draw(Gen2MenuBox.from_coords(0, QUESTION_TOP, COLUMNS - 1, ROWS - 1, 0), [], -1, indices, Gen2Screen.WIDTH, "", 0, [
			{"text": _ui("Leave the co-op"), "at": Vector2i(1, QUESTION_TOP + 2)},
			{"text": _ui("session?"), "at": Vector2i(1, QUESTION_TOP + 4)},
		])
		_page.draw(Gen2MenuBox.yes_no(), [_ui("YES"), _ui("NO")], 1 if _no else 0, indices, Gen2Screen.WIDTH)
	else:
		_draw_rows(indices, header.size() + 2)
	Gen2PicImage.show(_picture, Gen2PicImage.from_indices(indices, Gen2Screen.WIDTH, Gen2Screen.HEIGHT,
		PokePalette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK]))))


func _draw_rows(indices: PackedByteArray, top: int) -> void:
	var box: Gen2MenuBox = Gen2MenuBox.from_coords(0, top, COLUMNS - 1, ROWS - 1, LIST_FLAGS)
	var shown: int = _window(top - 2)
	if _rows.size() > shown:
		box.show_scroll(_scroll, _rows.size() - 1, shown)
	var labels: Array = []
	var extras: Array = []
	for index: int in range(_scroll, mini(_scroll + shown, _rows.size())):
		labels.append(String(_rows[index]["label"]))
		if not String(_rows[index].get("detail", "")).is_empty():
			extras.append({"text": String(_rows[index]["detail"]), "at": box.item_position(index - _scroll) + Vector2i(1, 1),
				"max_tiles": COLUMNS - 4})
	_page.draw(box, labels, _cursor - _scroll, indices, Gen2Screen.WIDTH, "", 0, extras)


static func _window(lines: int) -> int:
	return (ROWS - 4 - (lines + 2)) / 2 + 1


func _foe(running: Dictionary) -> String:
	var trainer: int = int(running.get("trainer_class", 0))
	if data == null:
		return "#%d" % int(running.get("enemy", 0))
	return data.trainer_name(trainer) if trainer > 0 else String(data.species(int(running.get("enemy", 0))).get("name", ""))


func _place(map: Variant) -> String:
	if not map is Vector2i or data == null or data.generation != RomRegistry.GEN1:
		return ""
	return data.landmark_name(data.area_landmark((map as Vector2i).y)).strip_edges()


func _name(player_id: Variant) -> String:
	var view: Dictionary = (client.state.get("players", {}) as Dictionary).get(String(player_id), {})
	return String(view.get("name", player_id))


func _ui(english: String) -> String:
	return Gen1LayoutDe.ui(data.id if data != null else &"", english)
