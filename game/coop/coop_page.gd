class_name PokeCoopPage
extends VBoxContainer

## The launcher's Co-op tab: a cartridge, then Host (a campaign, its addresses) or Join (nearby or by address, asked first).

signal hints_changed

const START: StringName = &"start"
const HOST: StringName = &"host"
const NEW_CAMPAIGN: StringName = &"new_campaign"
const HOSTING: StringName = &"hosting"
const JOIN: StringName = &"join"
const NEW_PLAYER: StringName = &"new_player"
const BACK: Dictionary = {HOST: START, NEW_CAMPAIGN: HOST, JOIN: START}
const DEFAULT_NAME: String = "RED"
const MAX_TITLE: int = 24
const MAX_NAME: int = 7
const REFRESH_MSEC: int = 400
const OPENING: StringName = &"opening"
const PALLET: StringName = &"pallet"
const BRING: StringName = &"bring"
const WIDE_CARTRIDGE: float = 150.0

static var host_port: int = PokeCoopEnetTransport.DEFAULT_PORT
static var _kept: Dictionary = {}
static var _dial: PokeCoopLobby.Dial = null
static var _waiting: PokeCoopSession = null
static var _listener: PokeCoopLobby.Listener = PokeCoopLobby.Listener.new()

var _theme: Gen2LauncherTheme = null
var _host_control: Control = null
var _compact: bool = false
var _screen: StringName = START
var _cartridges: Array = []
var _game: StringName = &""
var _head: BoxContainer = null
var _tail: Control = null
var _title: Label = null
var _crumb: Label = null
var _body: VBoxContainer = null
var _bar: BoxContainer = null
var _sheet: PokeCoopTabParts.Sheet = null
var _sheet_kind: StringName = &""
var _sheet_key: String = ""
var _sheet_again: Callable = Callable()
var _landing: Control = null
var _form: Dictionary = {}
var _campaigns: Array = []
var _picked: int = 0
var _target: Dictionary = {}
var _live: Dictionary = {}
var _opening: bool = false
var _refreshed_at: int = 0



static func create(palette: Gen2LauncherTheme, host: Control = null) -> PokeCoopPage:
	var page := PokeCoopPage.new()
	page._theme = palette
	page._host_control = host
	page._build()
	return page


func _build() -> void:
	add_theme_constant_override("separation", Gen2LauncherUI.GAP_MD)
	_head = BoxContainer.new()
	_head.add_theme_constant_override("separation", Gen2LauncherUI.GAP_MD)
	_title = Gen2LauncherUI.title(_theme, "Co-op", Gen2LauncherTheme.FONT_DISPLAY)
	_head.add_child(_title)
	_crumb = PokeCoopTabParts.text(_theme, "", Gen2LauncherTheme.FONT_SMALL, _theme.faint)
	_crumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_head.add_child(_crumb)
	add_child(_head)
	_body = Gen2LauncherUI.column(Gen2LauncherUI.GAP_MD)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_body)
	_bar = BoxContainer.new()
	_bar.add_theme_constant_override("separation", Gen2LauncherUI.GAP_SM)
	add_child(_bar)
	_tail = Control.new()
	add_child(_tail)
	add_child(Gen2LauncherUI.bottom_safe_space())
	_cartridges = PokeCoopLobby.cartridges()
	_game = _first_game()
	tree_exiting.connect(_on_leaving)
	var ended: String = PokeCoopSession.ended_note
	PokeCoopSession.ended_note = ""
	if not ended.is_empty():
		forget()
		_tell_ended.call_deferred("You left the session." if ended == "left" else why_not(ended))
	_show(_restored())


static func forget() -> void:
	_kept = {}
	if _dial != null:
		_dial.close()
	_dial = null
	_waiting = null


static func dialling() -> PokeCoopLobby.Dial:
	return _dial


static func nearby() -> Array:
	return _listener.hosts()


func _first_game() -> StringName:
	var wanted: StringName = StringName(_kept.get("game", PokeCoopLobby.remembered().get("game", "")))
	var ready: Array = _cartridges.filter(func(row: Dictionary) -> bool: return row["status"] == PokeCoopLobby.READY)
	if _cartridges.any(func(row: Dictionary) -> bool: return row["id"] == wanted and row["status"] == PokeCoopLobby.READY):
		return wanted
	return StringName((ready[0] if not ready.is_empty() else _cartridges[0])["id"])


func _restored() -> StringName:
	var coop: PokeCoopSession = Gen2GameRuntime.instance().coop
	if coop != null and coop.host != null and not coop.closing() and not is_instance_valid(coop.screen) \
			and not is_instance_valid(coop.opening_screen):
		_target = _kept.get("target", {})
		return HOSTING
	var kept: StringName = StringName(_kept.get("screen", START))
	_target = _kept.get("target", {})
	_form = _kept.get("form", {})
	if kept == NEW_PLAYER and (_dial != null or bool(_form.get("hosting", false))):
		return NEW_PLAYER
	if _dial != null and _dial.step != PokeCoopLobby.Dial.Step.CLOSED:
		_open_connecting.call_deferred()
		return JOIN
	return kept if kept in [START, HOST, JOIN, NEW_CAMPAIGN] else START


func _tell_ended(text: String) -> void:
	var shell: Node = get_parent()
	while shell != null and not shell is Gen2LauncherShell:
		shell = shell.get_parent()
	if shell != null:
		(shell as Gen2LauncherShell).select(&"coop")
		(shell as Gen2LauncherShell).toast().show_message(&"info", text, "")


func _toast(text: String, detail: String = "") -> void:
	var shell: Node = get_parent()
	while shell != null and not shell is Gen2LauncherShell:
		shell = shell.get_parent()
	if shell != null:
		(shell as Gen2LauncherShell).toast().show_message(&"info", text, detail)


func _on_leaving() -> void:
	_listener.close()
	if _sheet != null and is_instance_valid(_sheet):
		_sheet.queue_free()
	_sheet = null


func set_compact(compact: bool) -> void:
	if compact == _compact:
		return
	_compact = compact
	var again: Callable = _sheet_again if _sheet != null else Callable()
	if _title != null:
		_close_sheet()
		_show(_screen)
	if again.is_valid():
		again.call()


func is_compact() -> bool:
	return _compact


func screen() -> StringName:
	return _screen


func focus_target() -> Control:
	return _landing if _landing != null and is_instance_valid(_landing) else Gen2FocusGuard.first_focusable(self)


func hints() -> Array:
	var out: Array = [{"action": &"ui_accept", "label": "Select"}]
	match _screen:
		START:
			out.append({"action": &"ui_menu", "label": "Troubleshooting", "run": _open_troubleshooting})
		HOST when not _campaigns.is_empty():
			out.append({"action": &"ui_menu", "label": "Rename or delete", "run": _edit_focused})
		HOSTING:
			out.append({"action": &"ui_menu", "label": "Copy address", "run": _copy_best})
	if _screen != START:
		out.append({"action": &"ui_cancel", "label": "Stop" if _screen == HOSTING else "Back", "run": back})
	return out


func back() -> void:
	match _screen:
		HOSTING:
			_ask_stop_hosting()
		NEW_PLAYER:
			_cancel_join()
			_show(HOST if _form.get("hosting", false) else JOIN)
		_:
			_show(BACK.get(_screen, START))


func _show(screen_id: StringName) -> void:
	_screen = screen_id
	_kept["screen"] = screen_id
	_kept["game"] = _game
	_kept["target"] = _target
	_kept["form"] = _form
	if _sheet_kind != &"connecting":
		_close_sheet()
	Gen2LauncherUI.clear(_body)
	Gen2LauncherUI.clear(_bar)
	_bar.vertical = _compact
	_head.vertical = _compact
	_tail.custom_minimum_size.y = Gen2LauncherShell.BAR_FADE_TOP if _compact else 0.0
	_head.add_theme_constant_override("separation", 2 if _compact else Gen2LauncherUI.GAP_MD)
	_live.clear()
	_landing = null
	match screen_id:
		HOST:
			_build_host()
		NEW_CAMPAIGN:
			_build_new_campaign()
		HOSTING:
			_build_hosting()
		JOIN:
			_build_join()
		NEW_PLAYER:
			_build_new_player()
		_:
			_build_start()
	_refresh_live(true)
	hints_changed.emit()
	_land.call_deferred()


func _land() -> void:
	if _sheet != null or _landing == null or not is_instance_valid(_landing) or not _landing.is_visible_in_tree():
		return
	if not PokeInputDevice.is_pointer(Gen2InputRuntime.instance().device()):
		_grab(_landing)


static func _grab(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()


func _heading(title_text: String, crumb: String) -> void:
	_title.text = title_text
	_crumb.text = crumb


func _pane() -> VBoxContainer:
	var scroll: Gen2LauncherScroll = Gen2LauncherScroll.create()
	_body.add_child(scroll)
	var column: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_MD)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.content().add_child(column)
	return column


func _side_by_side(host: Container, weights: Array) -> Array:
	var out: Array = []
	var box: BoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_MD) if _compact else Gen2LauncherUI.row(Gen2LauncherUI.GAP_MD + 4)
	host.add_child(box)
	for weight: float in weights:
		var card: Gen2LauncherCard = Gen2LauncherCard.create(_theme, Gen2LauncherTheme.RADIUS_LG, 22, 18)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_stretch_ratio = weight
		box.add_child(card)
		var column: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_SM + 2)
		card.add_child(column)
		out.append(column)
	return out


func _actions(note: String, quiet: Array, primary: Array = []) -> Gen2LauncherButton:
	var main: Gen2LauncherButton = null
	if not note.is_empty() and not _compact:
		var said: Label = PokeCoopTabParts.text(_theme, note, Gen2LauncherTheme.FONT_SMALL, _theme.muted)
		said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_bar.add_child(said)
	elif not _compact:
		_bar.add_child(Gen2LauncherUI.spacer())
	if not primary.is_empty():
		main = _button(String(primary[0]), Gen2LauncherButton.Variant.PRIMARY, primary[1], StringName(primary[2]) if primary.size() > 2 else &"")
		main.custom_minimum_size.y = 52.0 if _compact else 46.0
	if main != null and _compact:
		_bar.add_child(main)
	for entry: Array in quiet.filter(func(entry: Array) -> bool: return not (entry[0] in ["Back", "Cancel"] and (_compact or main == null))):
		var button: Gen2LauncherButton = _button(String(entry[0]), Gen2LauncherButton.Variant.QUIET, entry[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _compact else Control.SIZE_SHRINK_END
		_bar.add_child(button)
	if main != null and not _compact:
		_bar.add_child(main)
	return main


func _button(label: String, kind: Gen2LauncherButton.Variant, run: Callable, glyph: StringName = &"") -> Gen2LauncherButton:
	var out: Gen2LauncherButton = Gen2LauncherButton.create(_theme, label, kind, glyph)
	out.pressed.connect(run)
	out.custom_minimum_size.y = Gen2LauncherUI.TOUCH_TARGET - 4.0
	return out


func _field(id: String, text_value: String, hint: String, longest: int) -> LineEdit:
	var out := LineEdit.new()
	out.name = id
	out.text = text_value
	out.placeholder_text = hint
	out.max_length = longest
	out.custom_minimum_size = Vector2(0, Gen2LauncherUI.TOUCH_TARGET)
	out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	out.add_theme_font_size_override("font_size", Gen2LauncherTheme.FONT_TITLE)
	out.text_changed.connect(func(typed: String) -> void: _form[id] = typed)
	return out


func _caption(host: Container, words: String) -> void:
	host.add_child(Gen2LauncherUI.caption(_theme, words))


func _note(host: Container, words: String, colour: Color = Color(0, 0, 0, 0)) -> Label:
	var out: Label = PokeCoopTabParts.text(_theme, words, Gen2LauncherTheme.FONT_SMALL, colour if colour.a > 0.0 else _theme.faint, true)
	host.add_child(out)
	return out


func _row(id: StringName) -> Dictionary:
	for row: Dictionary in _cartridges:
		if row["id"] == id:
			return row
	return {}


func _data(id: StringName = _game) -> GameData:
	return _row(id).get("data", null)


func _short(game_id: Variant) -> String:
	return PokeCoopLobby.short_title(StringName(String(game_id))) if not String(game_id).is_empty() else "?"


func _tint(game_id: Variant) -> Color:
	return _theme.tint_for(StringName(String(game_id))) if not String(game_id).is_empty() else _theme.faint


func _name() -> String:
	var typed: String = String(_form.get("name", PokeCoopLobby.remembered().get("name", DEFAULT_NAME))).strip_edges().to_upper()
	return typed if not typed.is_empty() else DEFAULT_NAME


func _build_start() -> void:
	_heading("Co-op", "Your cartridge")
	var column: VBoxContainer = _pane()
	var strip: BoxContainer = Gen2LauncherUI.row(Gen2LauncherUI.GAP_MD)
	if _compact:
		var sideways := ScrollContainer.new()
		sideways.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sideways.follow_focus = true
		sideways.custom_minimum_size.y = 128.0
		column.add_child(sideways)
		var inset := MarginContainer.new()
		for side: String in ["left", "right", "top", "bottom"]:
			inset.add_theme_constant_override("margin_" + side, Gen2LauncherScroll.RING_INSET)
		sideways.add_child(inset)
		inset.add_child(strip)
	else:
		column.add_child(strip)
	var order: Array = _cartridges.duplicate()
	if _compact:
		order.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
			return _rank(first) < _rank(second))
	for row: Dictionary in order:
		strip.add_child(_cartridge_tile(row))
	_plays_line(column)
	_start_cards(column)
	_last_session(column)


func _rank(row: Dictionary) -> int:
	return (0 if row["id"] == _game else 4) + (0 if row["status"] == PokeCoopLobby.READY else 8) + _cartridges.find(row)


func _cartridge_tile(row: Dictionary) -> PokeCoopTabParts.Tile:
	var id: StringName = row["id"]
	var tile: PokeCoopTabParts.Tile = PokeCoopTabParts.Tile.make(_theme, PokeCoopTabParts.Tile.Look.PANEL, not _compact,
		Gen2LauncherTheme.RADIUS_MD, Vector2i(12, 10))
	tile.set_meta("label", row["title"])
	tile.set_selected(id == _game)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _compact:
		tile.least_width = WIDE_CARTRIDGE
	var colour: Color = _tint(id)
	var ready: bool = row["status"] == PokeCoopLobby.READY
	var mark := Panel.new()
	mark.add_theme_stylebox_override("panel", _theme.box(colour if ready else _theme.with_alpha(colour, 0.45), Gen2LauncherTheme.RADIUS_SM))
	mark.custom_minimum_size = Vector2(32, 38)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.content().add_child(mark)
	var words: VBoxContainer = Gen2LauncherUI.column(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(PokeCoopTabParts.text(_theme, row["title"], Gen2LauncherTheme.FONT_BODY, _theme.text if ready else _theme.muted))
	var status: String = {PokeCoopLobby.READY: "Ready", PokeCoopLobby.STALE: "Re-import on Play"}.get(row["status"], "Not imported")
	words.add_child(PokeCoopTabParts.text(_theme, status, Gen2LauncherTheme.FONT_SMALL, _theme.muted if ready else _theme.warning))
	tile.content().add_child(words)
	tile.chosen.connect(_choose_game.bind(id))
	if id == _game:
		_landing = tile
	return tile


func _choose_game(id: StringName) -> void:
	_game = id
	PokeCoopLobby.remember({"game": String(id)})
	_show(START)
	for tile: Node in _find(_body, func(node: Node) -> bool: return node is PokeCoopTabParts.Tile and node.get_meta("label", "") == _row(id)["title"]):
		_landing = tile


func _plays_line(column: VBoxContainer) -> void:
	var row: Dictionary = _row(_game)
	var line: HBoxContainer = Gen2LauncherUI.row(6)
	column.add_child(line)
	if row["status"] != PokeCoopLobby.READY:
		line.add_child(PokeCoopTabParts.text(_theme, "%s %s: import it again on the Play tab, then come back." % [
			row["title"], "cannot be read by this version" if row["status"] == PokeCoopLobby.STALE else "is not imported"],
			Gen2LauncherTheme.FONT_SMALL, _theme.warning, true))
		line.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return
	var partners: Array[StringName] = PokeCoopLobby.partners(_data().id)
	for id: StringName in partners:
		line.add_child(PokeCoopTabParts.dot(_tint(id), 9.0))
	var titles: Array = partners.map(func(id: StringName) -> String: return PokeCoopLobby.title(id))
	line.add_child(PokeCoopTabParts.text(_theme, "Plays together with %s" % " and ".join(titles), Gen2LauncherTheme.FONT_SMALL, _theme.muted, _compact))


func _start_cards(column: VBoxContainer) -> void:
	var data: GameData = _data()
	var cards: BoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_MD) if _compact else Gen2LauncherUI.row(Gen2LauncherUI.GAP_MD + 4)
	column.add_child(cards)
	var count: int = PokeCoopSession.pair_campaigns(data, host_port).size() if data != null else 0
	var hosting: PokeCoopTabParts.Tile = _big_card(cards, "HOST", "%d campaign%s on this device" % [count, "" if count == 1 else "s"],
		&"play", true)
	hosting.chosen.connect(_show.bind(HOST))
	var joining: PokeCoopTabParts.Tile = _big_card(cards, "JOIN", "Looking for games nearby", &"chevron", false)
	joining.chosen.connect(_show.bind(JOIN))
	_live["nearby_count"] = {"node": joining.content().get_child(1).get_child(1), "key": ""}
	for card: PokeCoopTabParts.Tile in [hosting, joining]:
		card.disabled = data == null
	if data != null:
		_landing = hosting


func _big_card(host: Container, word: String, detail: String, glyph: StringName, primary: bool) -> PokeCoopTabParts.Tile:
	var card: PokeCoopTabParts.Tile = PokeCoopTabParts.Tile.make(_theme,
		PokeCoopTabParts.Tile.Look.PRIMARY if primary else PokeCoopTabParts.Tile.Look.PANEL, true, Gen2LauncherTheme.RADIUS_LG,
		Vector2i(20, 18 if not _compact else 14))
	card.set_meta("label", word)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ink: Color = _theme.on_accent if primary else _theme.text
	card.content().add_child(PokeCoopTabParts.badge(_theme, glyph, _theme.with_alpha(_theme.on_accent, 0.18) if primary \
		else _theme.surface_alt, ink, 50.0 if _compact else 58.0))
	var words: VBoxContainer = Gen2LauncherUI.column(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(PokeCoopTabParts.text(_theme, word, Gen2LauncherTheme.FONT_DISPLAY - 4, ink))
	words.add_child(PokeCoopTabParts.text(_theme, detail, Gen2LauncherTheme.FONT_SMALL, _theme.with_alpha(ink, 0.85) if primary else _theme.muted))
	card.content().add_child(words)
	host.add_child(card)
	return card


func _last_session(column: VBoxContainer) -> void:
	var last: Dictionary = PokeCoopLobby.remembered().get("last", {}) if PokeCoopLobby.remembered().get("last", {}) is Dictionary else {}
	var data: GameData = _data(StringName(String(last.get("game", ""))))
	if last.is_empty() or data == null:
		return
	var summary: Dictionary = last.duplicate()
	if last.get("kind") == "host":
		var found: Array = PokeCoopSession.pair_campaigns(data, host_port).filter(func(row: Dictionary) -> bool:
			return row["id"] == last.get("campaign"))
		if found.is_empty() or not bool(found[0]["readable"]):
			return
		summary.merge({"title": found[0]["title"], "badges": found[0]["badges"], "members": found[0]["members"], "saved": found[0]["saved"]}, true)
	var card: Gen2LauncherCard = Gen2LauncherCard.create(_theme, Gen2LauncherTheme.RADIUS_MD, 18, 12)
	column.add_child(card)
	var line: BoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_SM) if _compact else Gen2LauncherUI.row(Gen2LauncherUI.GAP_MD)
	card.add_child(line)
	var words: VBoxContainer = Gen2LauncherUI.column(4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(words)
	_caption(words, "Last session")
	var facts: PackedStringArray = [String(summary.get("title", ""))]
	facts.append("%d badges" % int(summary.get("badges", 0)))
	if int(summary.get("saved", 0)) > 0:
		facts.append(PokeCoopLobby.when(int(summary["saved"])))
	if last.get("kind") == "join":
		facts.append("hosted by %s at %s" % [summary.get("host", "the host"), summary.get("address", "")])
	words.add_child(PokeCoopTabParts.text(_theme, " · ".join(facts), Gen2LauncherTheme.FONT_BODY))
	var chips: HFlowContainer = PokeCoopTabParts.flow(6)
	for member: Dictionary in summary.get("members", []):
		chips.add_child(PokeCoopTabParts.chip(_theme, String(member.get("name", "")), _tint(member.get("game", ""))))
	if chips.get_child_count() > 0:
		words.add_child(chips)
	var again: Gen2LauncherButton = _button("Host again" if last.get("kind") == "host" else "Join again",
		Gen2LauncherButton.Variant.NEUTRAL, _again.bind(last))
	again.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(again)


func _again(last: Dictionary) -> void:
	_game = StringName(String(last.get("game", _game)))
	if last.get("kind") == "host":
		_host_campaign(String(last.get("campaign", "")), String(last.get("name", _name())), 0, null,
			StringName(String(last.get("campaign_game", ""))))
	else:
		_join(String(last.get("address", "")), int(last.get("port", host_port)), _game, last)


func _build_host() -> void:
	var data: GameData = _data()
	_heading("Host", "Co-op › %s" % _row(_game)["title"])
	_campaigns = PokeCoopSession.pair_campaigns(data, host_port) if data != null else []
	_picked = clampi(_picked, 0, maxi(_campaigns.size() - 1, 0))
	var column: VBoxContainer = _pane()
	var grid := GridContainer.new()
	grid.columns = 1 if _compact else 3
	grid.add_theme_constant_override("h_separation", Gen2LauncherUI.GAP_MD + 2)
	grid.add_theme_constant_override("v_separation", Gen2LauncherUI.GAP_MD + 2)
	column.add_child(grid)
	for index: int in _campaigns.size():
		grid.add_child(_campaign_card(index))
	var fresh: PokeCoopTabParts.Tile = PokeCoopTabParts.Tile.make(_theme, PokeCoopTabParts.Tile.Look.DASHED, false, Gen2LauncherTheme.RADIUS_LG)
	fresh.set_meta("label", "+ New campaign")
	fresh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fresh.content().alignment = BoxContainer.ALIGNMENT_CENTER
	fresh.content().add_child(PokeCoopTabParts.text(_theme, "+ New campaign", Gen2LauncherTheme.FONT_TITLE, _theme.accent))
	fresh.content().add_child(PokeCoopTabParts.text(_theme, "Name it, then choose how you start", Gen2LauncherTheme.FONT_SMALL, _theme.muted))
	fresh.chosen.connect(_new_campaign)
	grid.add_child(fresh)
	if _campaigns.is_empty():
		_landing = fresh
	var picked: Dictionary = _campaigns[_picked] if not _campaigns.is_empty() else {}
	var main: Gen2LauncherButton = _actions("Friends can join at any time while you play.",
		[["Rename or delete", _edit_focused], ["Back", back]] if not picked.is_empty() else [["Back", back]],
		["Host %s" % picked.get("title", ""), _host_picked, &"play"] if not picked.is_empty() else [])
	if main != null:
		main.disabled = not bool(picked.get("readable", false))
		main.repaint()


func _campaign_card(index: int) -> PokeCoopTabParts.Tile:
	var row: Dictionary = _campaigns[index]
	var card: PokeCoopTabParts.Tile = PokeCoopTabParts.Tile.make(_theme, PokeCoopTabParts.Tile.Look.PANEL, false, Gen2LauncherTheme.RADIUS_LG)
	card.set_meta("label", row["title"])
	card.set_meta("campaign", row["id"])
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.set_selected(index == _picked)
	var box: BoxContainer = card.content()
	box.add_child(PokeCoopTabParts.text(_theme, row["title"], Gen2LauncherTheme.FONT_TITLE))
	var game: HBoxContainer = Gen2LauncherUI.row(6)
	game.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.add_child(PokeCoopTabParts.dot(_tint(row["game"]), 8.0))
	game.add_child(PokeCoopTabParts.text(_theme, "%s campaign" % _short(row["game"]), Gen2LauncherTheme.FONT_SMALL, _theme.muted))
	box.add_child(game)
	if bool(row.get("both_versions", false)):
		box.add_child(PokeCoopTabParts.text(_theme, "Wild Pokémon from both versions", Gen2LauncherTheme.FONT_SMALL, _theme.muted))
	if not bool(row["readable"]):
		_note(box, "This version cannot read this campaign. It is left as it is.", _theme.warning)
	var chips: HFlowContainer = PokeCoopTabParts.flow(6)
	for member: Dictionary in row.get("members", []):
		var plays: String = String(member.get("game", ""))
		chips.add_child(PokeCoopTabParts.chip(_theme, "%s · %s" % [member["name"], _short(plays)] if not plays.is_empty() else String(member["name"]),
			_tint(plays)))
	if chips.get_child_count() == 0:
		chips.add_child(PokeCoopTabParts.chip(_theme, "Nobody yet"))
	box.add_child(chips)
	var facts: PackedStringArray = ["%d badge%s" % [int(row["badges"]), "" if int(row["badges"]) == 1 else "s"]]
	if not String(row.get("place", "")).is_empty():
		facts.append(String(row["place"]))
	facts.append("Saved " + PokeCoopLobby.when(int(row["saved"])))
	box.add_child(PokeCoopTabParts.text(_theme, "   ".join(facts), Gen2LauncherTheme.FONT_SMALL, _theme.muted))
	var you: String = _you_in(row)
	box.add_child(PokeCoopTabParts.text(_theme, "You are %s here" % you if not you.is_empty() else "You are new here",
		Gen2LauncherTheme.FONT_SMALL, _theme.muted))
	card.chosen.connect(_pick_campaign.bind(index))
	card.secondary.connect(_open_edit.bind(index))
	if index == _picked:
		_landing = card
	return card


func _you_in(row: Dictionary) -> String:
	var you: String = String(row.get("you", ""))
	var remembered: String = String(PokeCoopLobby.remembered().get("name", ""))
	return you if not you.is_empty() else remembered if (row.get("players", []) as Array).has(remembered) else ""


func _pick_campaign(index: int) -> void:
	var was: int = _picked
	_picked = index
	_show(HOST)
	if was == index or PokeInputDevice.is_pointer(Gen2InputRuntime.instance().device()):
		return
	for button: Node in _bar.get_children():
		if button is Gen2LauncherButton and (button as Gen2LauncherButton).variant == Gen2LauncherButton.Variant.PRIMARY:
			_landing = button


func _host_picked() -> void:
	if _campaigns.is_empty():
		return
	var row: Dictionary = _campaigns[_picked]
	var you: String = _you_in(row)
	if you.is_empty():
		_form = {"hosting": true, "campaign": row["id"], "campaign_game": String(row["game"]), "title": row["title"], "name": _name()}
		_show(NEW_PLAYER)
		return
	_host_campaign(String(row["id"]), you, 0, null, row["game"])


func _new_campaign() -> void:
	_form = {"title": "CAMPAIGN %d" % (_campaigns.size() + 1), "rival": "", "name": _name(), "start": OPENING, "starter": 1}
	_show(NEW_CAMPAIGN)


func _build_new_campaign() -> void:
	_heading("New campaign", "Co-op › Host › %s" % _row(_game)["title"])
	var columns: Array = _side_by_side(_pane(), [1.0, 1.25])
	var left: VBoxContainer = columns[0]
	_caption(left, "Campaign")
	var title: LineEdit = _field("title", String(_form.get("title", "")), "A name for the campaign", MAX_TITLE)
	left.add_child(title)
	_landing = title
	_caption(left, "Your rival")
	_rival_picker(left, "rival")
	_note(left, "The cartridge's own names, or type up to %d letters. Oak then skips the question for everyone." % MAX_NAME)
	_both_versions_switch(left, "both", _game_of(_data()))
	var right: VBoxContainer = columns[1]
	_caption(right, "You")
	right.add_child(_field("name", _name(), "Your name", MAX_NAME))
	_start_options(right)
	_actions("", [["Back", back]], ["Create and host", _create_campaign, &"play"])


func _rival_picker(host: VBoxContainer, key: String, ask: bool = true) -> void:
	var field: LineEdit = _field(key, String(_form.get(key, "")), "Asked in Oak's speech" if ask else "Rival", MAX_NAME)
	host.add_child(field)
	var chips: HFlowContainer = PokeCoopTabParts.flow(Gen2LauncherUI.GAP_SM)
	host.add_child(chips)
	var presets: Array = _rival_presets()
	if ask:
		presets.append("")
	for preset: String in presets:
		var pick: Gen2LauncherButton = Gen2LauncherButton.create(_theme, preset if not preset.is_empty() else "Ask in Oak's speech",
			Gen2LauncherButton.Variant.SEGMENT)
		pick.set_active(String(_form.get(key, "")).strip_edges().to_upper() == preset)
		pick.pressed.connect(func() -> void:
			_form[key] = preset
			field.text = preset
			for other: Node in chips.get_children():
				(other as Gen2LauncherButton).set_active(other == pick))
		chips.add_child(pick)
	field.text_changed.connect(func(typed: String) -> void:
		for other: Node in chips.get_children():
			var said: String = (other as Gen2LauncherButton).text
			(other as Gen2LauncherButton).set_active(typed.strip_edges().to_upper() == ("" if said == "Ask in Oak's speech" else said)))


func _game_of(data: GameData) -> StringName:
	return data.id if data != null else &""


func _both_versions_switch(host: VBoxContainer, key: String, game: StringName) -> void:
	var other: StringName = PokeCoopPolicy.other_version(game)
	if other.is_empty():
		return
	_caption(host, "Wild Pokémon")
	var row: Control = Gen2LauncherUI.switch(_theme, &"sparkle", "From both versions", bool(_form.get(key, false)),
		func(on: bool) -> void: _form[key] = on)
	row.set_meta("label", "Wild Pokémon from both versions")
	host.add_child(row)
	_note(host, "Pokémon only the other version has in the wild show up in its slots half the time (%s's in %s, %s's in %s); the rest keep their odds. Needs a player with each version." % [
		_short(other), _short(game), _short(game), _short(other)])


func _rival_presets() -> Array:
	var data: GameData = _data()
	var names: Array = data.gen1_default_names(true) if data != null and data.generation == RomRegistry.GEN1 else []
	return names.slice(1).filter(func(name: String) -> bool: return not name.strip_edges().is_empty())


func _start_options(host: VBoxContainer) -> void:
	var data: GameData = _data()
	var slots: Array = [] if data == null else Gen2SaveStore.slots_for(data.id, data.sha1, data).filter(
		func(row: Dictionary) -> bool: return bool(row["valid"]))
	var choice: StringName = StringName(_form.get("start", OPENING))
	var options: Array = [[OPENING, "Play Oak's opening", "Your room, Oak's lab, your own rival fight"],
		[PALLET, "Start in Pallet Town", "With a level %d starter and %d money" % [PokeCoopPolicy.STARTER_LEVEL, PokeCoopPolicy.NEW_PLAYER_MONEY]]]
	if not slots.is_empty():
		options.append([BRING, "Bring a trainer from a save", "Slot %d: %s · %s" % [int(slots[0]["slot"]) + 1, slots[0]["player_name"],
			_row(_game)["title"]]])
	for option: Array in options:
		var tile: PokeCoopTabParts.Tile = PokeCoopTabParts.Tile.make(_theme, PokeCoopTabParts.Tile.Look.PANEL, true,
			Gen2LauncherTheme.RADIUS_MD, Vector2i(14, 10))
		tile.set_meta("label", option[1])
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.set_selected(option[0] == choice)
		tile.content().add_child(PokeCoopTabParts.radio(_theme, option[0] == choice))
		var words: VBoxContainer = Gen2LauncherUI.column(1)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_child(PokeCoopTabParts.text(_theme, option[1]))
		words.add_child(PokeCoopTabParts.text(_theme, option[2], Gen2LauncherTheme.FONT_SMALL, _theme.muted, _compact))
		tile.content().add_child(words)
		tile.chosen.connect(_choose_start.bind(option[0], option[1]))
		host.add_child(tile)
		if option[0] == PALLET and choice == PALLET:
			host.add_child(_starter_chips(data))
		if option[0] == BRING and choice == BRING and slots.size() > 1:
			host.add_child(_slot_chips(slots))


func _choose_start(start: StringName, label: String) -> void:
	_form["start"] = start
	_show(_screen)
	for tile: Node in _find(_body, func(node: Node) -> bool: return node is PokeCoopTabParts.Tile and node.get_meta("label", "") == label):
		_landing = tile


func _starter_chips(data: GameData) -> Container:
	var chips := GridContainer.new()
	chips.columns = PokeCoopPolicy.STARTERS.size()
	chips.add_theme_constant_override("h_separation", Gen2LauncherUI.GAP_SM)
	for index: int in PokeCoopPolicy.STARTERS.size():
		var species: String = String(data.species(PokeCoopPolicy.STARTERS[index]).get("name", "#%d" % PokeCoopPolicy.STARTERS[index])) \
			if data != null else str(index)
		var pick: Gen2LauncherButton = Gen2LauncherButton.create(_theme, species, Gen2LauncherButton.Variant.SEGMENT)
		pick.set_active(int(_form.get("starter", 1)) == index)
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _compact else Control.SIZE_FILL
		if _compact:
			pick.clip_text = true
			pick.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			pick.add_theme_font_size_override("font_size", Gen2LauncherTheme.FONT_SMALL)
		pick.pressed.connect(func() -> void:
			_form["starter"] = index
			for other: Node in chips.get_children():
				(other as Gen2LauncherButton).set_active(other == pick))
		chips.add_child(pick)
	return chips


func _slot_chips(slots: Array) -> HFlowContainer:
	var chips: HFlowContainer = PokeCoopTabParts.flow(Gen2LauncherUI.GAP_SM)
	for row: Dictionary in slots:
		var slot: int = int(row["slot"])
		var pick: Gen2LauncherButton = Gen2LauncherButton.create(_theme, "Slot %d: %s" % [slot + 1, row["player_name"]],
			Gen2LauncherButton.Variant.SEGMENT)
		pick.set_active(int(_form.get("slot", int(slots[0]["slot"]))) == slot)
		pick.pressed.connect(func() -> void:
			_form["slot"] = slot
			for other: Node in chips.get_children():
				(other as Gen2LauncherButton).set_active(other == pick))
		chips.add_child(pick)
	return chips


func _starter() -> int:
	match StringName(_form.get("start", OPENING)):
		PALLET:
			return PokeCoopPolicy.STARTERS[clampi(int(_form.get("starter", 1)), 0, PokeCoopPolicy.STARTERS.size() - 1)]
		BRING:
			return 0
	return PokeCoopPolicy.PLAY_OPENING


func _brought() -> Gen2SaveData:
	var data: GameData = _data()
	if StringName(_form.get("start", OPENING)) != BRING or data == null:
		return null
	var slots: Array = Gen2SaveStore.slots_for(data.id, data.sha1, data).filter(func(row: Dictionary) -> bool: return bool(row["valid"]))
	if slots.is_empty():
		return null
	var loaded: Dictionary = Gen2SaveStore.load_result(data.id, data.sha1, int(_form.get("slot", int(slots[0]["slot"]))), data)
	return loaded["save"] if bool(loaded.get("ok", false)) else null


func _create_campaign() -> void:
	var data: GameData = _data()
	var title: String = String(_form.get("title", "")).strip_edges().to_upper()
	var id: String = PokeCoopSession.new_campaign(data, title if not title.is_empty() else "CAMPAIGN %d" % (_campaigns.size() + 1),
		String(_form.get("rival", "")).strip_edges().to_upper(), bool(_form.get("both", false)))
	if id.is_empty():
		_toast("The campaign could not be written.", "Check that this device has room to save.")
		return
	_host_campaign(id, _name(), _starter(), _brought())


func _host_campaign(id: String, player_name: String, starter: int = 0, brought: Gen2SaveData = null, folder: StringName = &"") -> void:
	var data: GameData = _data()
	if data == null:
		return
	if Gen2GameRuntime.instance().coop != null:
		_toast("The last session is still closing.", "Try again in a moment.")
		return
	_listener.close()
	var session: PokeCoopSession = PokeCoopSession.hosting(data, host_port, player_name, starter, brought, id, "",
		PokeCoopLog.create(PokeCoopLog.sharing()), folder)
	if session == null:
		_toast("Could not host on port %d" % host_port, "Is another host running on this device?" if PokeCoopSession.last_failure.is_empty() \
			else "This device's campaign file could not be read, so it was left as it is.")
		return
	Gen2GameRuntime.instance().coop = session
	PokeCoopLobby.remember({"name": player_name, "game": String(_game),
		"last": {"kind": "host", "game": String(_game), "campaign": id, "campaign_game": String(folder), "name": player_name}})
	_target = {"campaign": id}
	_show(HOSTING)


func _build_hosting() -> void:
	var session: PokeCoopSession = Gen2GameRuntime.instance().coop
	if session == null or session.host == null:
		_build_start()
		return
	var title: String = session.host.campaign.title
	_heading("Hosting %s" % title, "%s · port %d" % [PokeCoopLobby.title(session.data.id), session.port])
	var columns: Array = _side_by_side(_pane(), [1.35, 1.0])
	var left: VBoxContainer = columns[0]
	_caption(left, "Your friends join at")
	var rows: Array = PokeCoopLobby.local_addresses()
	var used: Dictionary = PokeCoopLobby.used_by(rows, session.host.players.values())
	var best: String = PokeCoopLobby.best_address(rows, session.host.players.values())
	for row: Dictionary in rows:
		left.add_child(_address_panel(row, used.get(row["address"], ""), rows.size() > 1 and row["address"] == best))
	if rows.is_empty():
		_note(left, "No network found. Connect to Wi-Fi or a VPN; a second window on this device joins at 127.0.0.1.", _theme.warning)
	_note(left, "Players on your network also see this session under Join, without typing.")
	var right: VBoxContainer = columns[1]
	_caption(right, "Players")
	var players: VBoxContainer = Gen2LauncherUI.column(0)
	right.add_child(players)
	_live["players"] = {"node": players, "key": ""}
	_landing = _actions("", [["Stop hosting", _ask_stop_hosting]], ["Enter the world", _enter_world, &"play"])


func _shown_address(address: String) -> String:
	return address if host_port == PokeCoopEnetTransport.DEFAULT_PORT else "%s:%d" % [address, host_port]


func _address_panel(row: Dictionary, used_by: String, best: bool) -> Control:
	var panel: Gen2LauncherCard = Gen2LauncherCard.well(_theme, Gen2LauncherTheme.RADIUS_MD, 16, 12)
	if best:
		panel.add_theme_stylebox_override("panel", _theme.padded(_theme.box(_theme.surface_alt, Gen2LauncherTheme.RADIUS_MD, _theme.accent, 2), 16, 12))
	var line: BoxContainer = Gen2LauncherUI.column(4) if _compact else Gen2LauncherUI.row(Gen2LauncherUI.GAP_MD)
	panel.add_child(line)
	var words: VBoxContainer = Gen2LauncherUI.column(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(words)
	var kind: StringName = row["kind"]
	var tag: String = {PokeCoopLobby.VPN: "VPN", PokeCoopLobby.HOME: "Home network", PokeCoopLobby.PUBLIC: "Internet"}.get(kind, "")
	if not used_by.is_empty():
		tag += " · %s used this" % used_by
	words.add_child(PokeCoopTabParts.text(_theme, tag.to_upper(), Gen2LauncherTheme.FONT_TINY, _theme.accent))
	var shown: String = _shown_address(row["address"])
	words.add_child(PokeCoopTabParts.text(_theme, shown, 34 if not _compact else 30 if shown.length() <= 13 else 24))
	var how: Dictionary = {PokeCoopLobby.VPN: "works from anywhere on the VPN", PokeCoopLobby.HOME: "same Wi-Fi or LAN",
		PokeCoopLobby.PUBLIC: "needs UDP %d forwarded on the router" % host_port}
	words.add_child(PokeCoopTabParts.text(_theme, "%s · %s" % [row["network"], how.get(kind, "")], Gen2LauncherTheme.FONT_SMALL, _theme.muted))
	var copy: Gen2LauncherButton = _button("Copy", Gen2LauncherButton.Variant.NEUTRAL, _copy.bind(shown))
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	copy.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	line.add_child(copy)
	return panel


func _copy(address: String) -> void:
	DisplayServer.clipboard_set(address)
	_toast("Copied %s" % address, "Send it to the friends who join.")


func _copy_best() -> void:
	var session: PokeCoopSession = Gen2GameRuntime.instance().coop
	var rows: Array = PokeCoopLobby.local_addresses()
	if session != null and session.host != null and not rows.is_empty():
		_copy(_shown_address(PokeCoopLobby.best_address(rows, session.host.players.values())))


func _fill_players(box: VBoxContainer, session: PokeCoopSession) -> void:
	var members: Array = session.host.players.values()
	members.sort_custom(func(first: PokeCoopPlayer, second: PokeCoopPlayer) -> bool: return first.player_id < second.player_id)
	for member: PokeCoopPlayer in members:
		var line: HBoxContainer = Gen2LauncherUI.row(Gen2LauncherUI.GAP_SM + 2)
		line.custom_minimum_size.y = 40.0
		line.add_child(PokeCoopTabParts.dot(_tint(member.game_id), 10.0))
		var named: Label = PokeCoopTabParts.text(_theme, member.name)
		PokeCoopTabParts.whole(named)
		line.add_child(named)
		var mine: bool = member.player_id == session.client.player_id
		var about: Label = PokeCoopTabParts.text(_theme, "you · %s" % _short(member.game_id) if mine else _short(member.game_id) \
			if not member.game_id.is_empty() else "", Gen2LauncherTheme.FONT_SMALL, _theme.faint)
		about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(about)
		line.add_child(PokeCoopTabParts.state(_theme, "Here" if mine else "Joined" if member.connected else "Away",
			_theme.success if member.connected else _theme.faint))
		box.add_child(line)
		box.add_child(HSeparator.new())
	if members.size() < PokeCoopEnetTransport.MAX_CLIENTS:
		_note(box, "Another player can join any time.")
	var missing: Array = session.host.wild_tables_missing()
	if session.host.campaign.both_versions:
		_note(box, "Wild Pokémon from both versions: on." if missing.is_empty() else
			"Wild Pokémon from both versions start once a player with %s is here." % " and ".join(missing.map(_short)),
			_theme.muted if missing.is_empty() else _theme.warning)


func _ask_stop_hosting() -> void:
	var session: PokeCoopSession = Gen2GameRuntime.instance().coop
	var partners: Array = [] if session == null or session.host == null else session.host.players.values().filter(
		func(member: PokeCoopPlayer) -> bool: return member.connected and member.player_id != session.client.player_id)
	if partners.is_empty():
		_stop_hosting()
		return
	var sheet: PokeCoopTabParts.Sheet = _open_sheet(&"stop", _ask_stop_hosting)
	sheet.body().add_child(Gen2LauncherUI.title(_theme, "Stop hosting?", Gen2LauncherTheme.FONT_TITLE + 3))
	_note(sheet.body(), "%s will be sent back to the launcher. The campaign is saved first." % ", ".join(
		partners.map(func(member: PokeCoopPlayer) -> String: return member.name)), _theme.muted)
	_sheet_buttons(sheet, [["Keep hosting", _close_sheet]], ["Stop hosting", _stop_hosting])


func _stop_hosting() -> void:
	_close_sheet()
	var session: PokeCoopSession = Gen2GameRuntime.instance().coop
	if session != null:
		session.leave()
		PokeCoopSession.ended_note = ""
	_show(START)


func _enter_world() -> void:
	var session: PokeCoopSession = Gen2GameRuntime.instance().coop
	if session == null or not session.is_ready() or _opening:
		return
	_opening = true
	forget()
	_close_sheet()
	Gen2GameRuntime.instance().select_game(session.data.id)
	get_tree().change_scene_to_node(session.open_start())


func _build_join() -> void:
	var ready: Array = _cartridges.filter(func(row: Dictionary) -> bool: return row["status"] == PokeCoopLobby.READY)
	_heading("Join", "Co-op › your cartridges: %s" % ", ".join(ready.map(func(row: Dictionary) -> String: return _short(row["id"]))))
	var column: VBoxContainer = _pane()
	var nearby: HBoxContainer = Gen2LauncherUI.row(Gen2LauncherUI.GAP_SM)
	nearby.add_child(Gen2LauncherUI.caption(_theme, "Nearby"))
	nearby.add_child(PokeCoopTabParts.dot(_theme.success, 9.0))
	var looking: Label = PokeCoopTabParts.text(_theme, "looking…", Gen2LauncherTheme.FONT_TINY, _theme.muted)
	nearby.add_child(looking)
	column.add_child(nearby)
	var hosts: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_SM + 2)
	column.add_child(hosts)
	_live["hosts"] = {"node": hosts, "key": ""}
	_live["looking"] = {"node": looking, "key": ""}
	_caption(column, "By address")
	var typed: BoxContainer = Gen2LauncherUI.row(Gen2LauncherUI.GAP_SM)
	column.add_child(typed)
	var address: LineEdit = _field("address", String(_form.get("address", PokeCoopLobby.remembered().get("address", ""))),
		"For example 192.168.1.20", 64)
	address.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	address.text_submitted.connect(func(_text: String) -> void: _join_typed())
	typed.add_child(address)
	var go: Gen2LauncherButton = _button("Join", Gen2LauncherButton.Variant.NEUTRAL, _join_typed, &"chevron")
	typed.add_child(go)
	_landing = address
	_recent_chips(column)
	_actions("", [["Back", back]])


func _recent_chips(column: VBoxContainer) -> void:
	var recent: Array = PokeCoopLobby.recent()
	if recent.is_empty():
		return
	var chips: HFlowContainer = PokeCoopTabParts.flow(Gen2LauncherUI.GAP_SM)
	chips.add_child(PokeCoopTabParts.text(_theme, "Recent", Gen2LauncherTheme.FONT_SMALL, _theme.muted))
	for entry: Dictionary in recent:
		var port: int = int(entry.get("port", host_port))
		var words: String = String(entry["address"]) + ("" if port == PokeCoopEnetTransport.DEFAULT_PORT else ":%d" % port)
		if not String(entry.get("title", "")).is_empty():
			words += " · " + String(entry["title"])
		var pick: Gen2LauncherButton = Gen2LauncherButton.create(_theme, words, Gen2LauncherButton.Variant.QUIET)
		var game: StringName = StringName(String(entry.get("game", _game)))
		pick.pressed.connect(_join.bind(String(entry["address"]), port, game if _data(game) != null else _game, entry))
		chips.add_child(pick)
	column.add_child(chips)


func _join_typed() -> void:
	var typed: String = String(_form.get("address", "")).strip_edges()
	if typed.is_empty():
		_toast("Type the host's address first.", "The host sees it on their Hosting screen.")
		return
	var parts: Array = PokeCoopLobby.split_address(typed, host_port)
	_join(parts[0], parts[1], _game)


func _fill_hosts(box: VBoxContainer, rows: Array) -> void:
	if rows.is_empty():
		_note(box, "No games found yet. A host on your Wi-Fi or LAN shows up here by itself; over a VPN, type the address below.")
		return
	for row: Dictionary in rows:
		box.add_child(_host_row(row))


func _host_row(row: Dictionary) -> Control:
	var fits: Array = PokeCoopLobby.fitting(_cartridges, StringName(row["game_id"]), row["rom_sha1"])
	var same: bool = int(row["protocol"]) == PokeCoopHost.PROTOCOL
	var card: Gen2LauncherCard = Gen2LauncherCard.create(_theme, Gen2LauncherTheme.RADIUS_MD, 18, 12)
	card.modulate.a = 1.0 if same and not fits.is_empty() else 0.6
	var line: BoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_SM) if _compact else Gen2LauncherUI.row(Gen2LauncherUI.GAP_MD)
	card.add_child(line)
	var words: VBoxContainer = Gen2LauncherUI.column(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(words)
	var host_name: String = String(row["host"]) if not String(row["host"]).is_empty() else "A host"
	words.add_child(PokeCoopTabParts.text(_theme, "%s · %s" % [host_name, row["title"]], Gen2LauncherTheme.FONT_TITLE))
	var here: int = (row["players"] as Array).filter(func(member: Dictionary) -> bool: return member["connected"]).size()
	var facts: PackedStringArray = [PokeCoopLobby.title(StringName(row["game_id"])), _shown_join(row), "%d of %d players here" % [
		here, (row["players"] as Array).size()], "%d badges" % int(row["badges"])]
	words.add_child(PokeCoopTabParts.text(_theme, " · ".join(facts), Gen2LauncherTheme.FONT_SMALL, _theme.muted, true))
	if not same:
		_note(words, "Needs the same version of the game: the host has %s, you have %s." % [row["build"], PokeCoopLobby.build()], _theme.warning)
	elif fits.is_empty():
		_note(words, "None of your cartridges fits: needs %s." % " or ".join(PokeCoopLobby.partners(StringName(row["game_id"])).map(
			func(id: StringName) -> String: return PokeCoopLobby.title(id))), _theme.warning)
	var buttons: BoxContainer = Gen2LauncherUI.row(Gen2LauncherUI.GAP_SM)
	line.add_child(buttons)
	fits.sort_custom(func(first: Dictionary, _second: Dictionary) -> bool: return first["id"] == _game)
	for fit: Dictionary in fits if same else []:
		var join: Gen2LauncherButton = _button("Join with %s" % _short(fit["id"]), Gen2LauncherButton.Variant.PRIMARY \
			if fit == fits[0] else Gen2LauncherButton.Variant.NEUTRAL, _join.bind(row["address"], int(row["port"]), fit["id"], row))
		join.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _compact else Control.SIZE_SHRINK_END
		join.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buttons.add_child(join)
	return card


func _shown_join(row: Dictionary) -> String:
	return String(row["address"]) + ("" if int(row["port"]) == PokeCoopEnetTransport.DEFAULT_PORT else ":%d" % int(row["port"]))


func _join(address: String, port: int, game: StringName, seen: Dictionary = {}) -> void:
	var data: GameData = _data(game)
	if data == null or address.is_empty():
		return
	if Gen2GameRuntime.instance().coop != null:
		_toast("The last session is still closing.", "Try again in a moment.")
		return
	_cancel_join()
	_game = game
	_target = {"address": address, "port": port, "game": String(game), "host": String(seen.get("host", "")),
		"title": String(seen.get("title", ""))}
	_kept["target"] = _target
	PokeCoopLobby.remember({"game": String(game), "address": address if port == PokeCoopEnetTransport.DEFAULT_PORT else "%s:%d" % [address, port]})
	_dial = PokeCoopLobby.Dial.to(address, port, data, String(PokeCoopLobby.remembered().get("name", "")),
		PokeCoopSession.known_at(data, address, port))
	_open_connecting()


func _cancel_join() -> void:
	if _dial != null:
		_dial.close()
	_dial = null
	if _waiting != null and Gen2GameRuntime.instance().coop == _waiting:
		_waiting.close()
		Gen2GameRuntime.instance().coop = null
	_waiting = null


func _open_connecting() -> void:
	if _dial == null:
		return
	_open_sheet(&"connecting", _open_connecting)
	_sheet_key = ""
	_refresh_connecting()


func _refresh_connecting() -> void:
	if _sheet == null or _sheet_kind != &"connecting" or _dial == null:
		return
	var answer: Dictionary = _dial.answer()
	var step: PokeCoopLobby.Dial.Step = _dial.step
	if step == PokeCoopLobby.Dial.Step.ANSWERED and (answer.get("you", {}) as Dictionary).is_empty() and _waiting == null:
		_close_sheet()
		_form = {"hosting": false, "title": answer.get("title", ""), "host": answer.get("host", ""), "name": _name(), "start": OPENING,
			"starter": 1}
		_show(NEW_PLAYER)
		return
	var key: String = "%d|%d|%s|%s|%d" % [step, _dial.seconds_left() if _dial.attempts > 1 else -1, _dial.reason, _waiting != null,
		answer.hash()]
	if key == _sheet_key:
		return
	_sheet_key = key
	Gen2LauncherUI.clear(_sheet.body())
	Gen2LauncherUI.clear(_sheet.actions())
	match step:
		PokeCoopLobby.Dial.Step.ANSWERED:
			_sheet_answered(answer)
		PokeCoopLobby.Dial.Step.REFUSED:
			_sheet_refused(answer)
		_:
			_sheet_looking(step == PokeCoopLobby.Dial.Step.GAVE_UP)


func _sheet_title(words: String) -> void:
	var title: Label = PokeCoopTabParts.text(_theme, words, Gen2LauncherTheme.FONT_TITLE + 3, _theme.text, true)
	_sheet.body().add_child(title)


func _sheet_looking(gave_up: bool) -> void:
	var address: String = _shown_join(_target)
	var first: bool = _dial.attempts <= 1 and not gave_up
	_sheet_title("Joining %s" % address if first else "Could not reach %s" % address if gave_up else "Still looking for %s" % address)
	var left: int = _dial.seconds_left()
	var used: int = PokeCoopLobby.DIAL_MSEC / 1000 - left
	var steps: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_SM)
	_sheet.body().add_child(steps)
	if first:
		steps.add_child(PokeCoopTabParts.step(_theme, "1", &"now", "Looking for the host at %s" % address))
		steps.add_child(PokeCoopTabParts.step(_theme, "2", &"todo", "Same game version"))
		steps.add_child(PokeCoopTabParts.step(_theme, "3", &"todo", "Cartridges fit"))
	elif gave_up:
		steps.add_child(PokeCoopTabParts.step(_theme, "!", &"bad", "No answer for a minute", "Nothing answered at %s." % address))
	else:
		steps.add_child(PokeCoopTabParts.step(_theme, "1", &"now", "Trying again every few seconds",
			"%d:%02d of 1:00 · the host may still be starting" % [used / 60, used % 60]))
	if not first:
		_caption(_sheet.body(), "If it does not connect")
		for line: String in PokeCoopLobby.advice(_target["address"], int(_target["port"]), String(_target.get("host", ""))):
			_sheet.body().add_child(PokeCoopTabParts.step(_theme, "•", &"todo", line))
	var quiet: Array = [["Open logs folder", open_logs_folder, "left"], ["Cancel", _cancel_and_close]] if not first else [["Cancel", _cancel_and_close]]
	_sheet_buttons(_sheet, quiet, [] if first else ["Try again" if gave_up else "Try now", _try_now])


func _try_now() -> void:
	if _dial != null:
		_dial.retry_now()
		_sheet_key = ""


func _cancel_and_close() -> void:
	_cancel_join()
	_close_sheet()
	if _screen == NEW_PLAYER:
		_show(JOIN)


func _sheet_refused(answer: Dictionary) -> void:
	var host_name: String = String(answer.get("host", _target.get("host", "")))
	_sheet_title("Can't join %s" % (host_name if not host_name.is_empty() else _shown_join(_target)))
	var steps: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_SM)
	_sheet.body().add_child(steps)
	var reason: String = _dial.reason
	if reason == "bad_address":
		steps.add_child(PokeCoopTabParts.step(_theme, "!", &"bad", "That address cannot be dialled",
			"Type the numbers the host's Hosting screen shows, such as 192.168.1.20."))
		_sheet_buttons(_sheet, [["Cancel", _cancel_and_close]])
		return
	steps.add_child(PokeCoopTabParts.step(_theme, "✓", &"done", "Host found at %s" % _shown_join(_target)))
	var version_bad: bool = reason in ["protocol_mismatch", "older_host"]
	steps.add_child(PokeCoopTabParts.step(_theme, "!" if version_bad else "✓", &"bad" if version_bad else &"done", "Same game version",
		_versions(answer, reason)))
	var fits: Array = []
	if reason == "content_mismatch":
		fits = PokeCoopLobby.fitting(_cartridges, StringName(String(answer.get("game_id", ""))), String(answer.get("rom_sha1", "")))
		steps.add_child(PokeCoopTabParts.step(_theme, "!", &"bad", "Cartridges fit", _misfit(answer, fits)))
	elif not version_bad:
		steps.add_child(PokeCoopTabParts.step(_theme, "!", &"bad", "The host said no", why_not("refused: " + reason)))
	var primary: Array = []
	if not fits.is_empty():
		primary = ["Join with %s" % _short(fits[0]["id"]), _join.bind(_target["address"], int(_target["port"]), fits[0]["id"], _target)]
	_sheet_buttons(_sheet, [["Cancel", _cancel_and_close]], primary)


func _versions(answer: Dictionary, reason: String) -> String:
	if reason == "older_host":
		return "The host runs an older version than yours (%s). Both need builds made from the same version." % PokeCoopLobby.build()
	var theirs: String = String(answer.get("build", "?"))
	if reason == "protocol_mismatch":
		return "The host has %s, you have %s. Both need builds made from the same version." % [theirs, PokeCoopLobby.build()]
	return "both %s" % theirs if theirs == PokeCoopLobby.build() else "host %s, you %s" % [theirs, PokeCoopLobby.build()]


func _misfit(answer: Dictionary, fits: Array) -> String:
	var theirs: String = PokeCoopLobby.title(StringName(String(answer.get("game_id", ""))))
	var said: String = "%s plays %s; your %s plays with %s only." % [String(answer.get("host", "The host")), theirs,
		_row(_game)["title"], " and ".join(PokeCoopLobby.partners(_data().id).map(func(id: StringName) -> String: return PokeCoopLobby.title(id)))]
	if fits.is_empty():
		return said + " None of your cartridges fits: German and English, or another revision, cannot play together."
	return said + " Your %s fits." % " or ".join(fits.map(func(fit: Dictionary) -> String: return fit["title"]))


func _sheet_answered(answer: Dictionary) -> void:
	var host_name: String = String(answer.get("host", ""))
	_sheet_title("Joining %s" % (host_name if not host_name.is_empty() else _shown_join(_target)))
	var steps: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_SM)
	_sheet.body().add_child(steps)
	steps.add_child(PokeCoopTabParts.step(_theme, "✓", &"done", "Host found at %s" % _shown_join(_target)))
	steps.add_child(PokeCoopTabParts.step(_theme, "✓", &"done", "Same game version", _versions(answer, "")))
	steps.add_child(PokeCoopTabParts.step(_theme, "✓", &"done", "Cartridges fit", "%s plays %s, you play %s" % [
		host_name if not host_name.is_empty() else "The host", PokeCoopLobby.title(StringName(String(answer.get("game_id", "")))),
		_row(_game)["title"]]))
	var you: String = String((answer.get("you", {}) as Dictionary).get("name", ""))
	steps.add_child(PokeCoopTabParts.step(_theme, "4", &"now", "Joining as %s…" % you if _waiting != null else "Ready to join"))
	var info: Gen2LauncherCard = Gen2LauncherCard.well(_theme, Gen2LauncherTheme.RADIUS_MD, 16, 12)
	_sheet.body().add_child(info)
	var line: BoxContainer = Gen2LauncherUI.column(6) if _compact else Gen2LauncherUI.row(Gen2LauncherUI.GAP_MD)
	info.add_child(line)
	var words: VBoxContainer = Gen2LauncherUI.column(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(words)
	words.add_child(PokeCoopTabParts.text(_theme, String(answer.get("title", "")), Gen2LauncherTheme.FONT_TITLE))
	words.add_child(PokeCoopTabParts.text(_theme, _campaign_facts(answer), Gen2LauncherTheme.FONT_SMALL, _theme.muted, true))
	var chip: PanelContainer = PokeCoopTabParts.chip(_theme, "You are %s" % you, _tint(_data().id))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(chip)
	_sheet_buttons(_sheet, [["Cancel", _cancel_and_close]], [] if _waiting != null else ["Join as %s" % you, _join_known])


func _campaign_facts(answer: Dictionary) -> String:
	var facts: PackedStringArray = ["%d badges" % int(answer.get("badges", 0))]
	if not String(answer.get("place", "")).is_empty():
		facts.append(String(answer["place"]))
	var host_name: String = String(answer.get("host", ""))
	var host_here: bool = (answer.get("players", []) as Array).any(func(member: Variant) -> bool:
		return member is Dictionary and member.get("name") == host_name and member.get("connected") == true)
	if not host_name.is_empty():
		facts.append("%s is %s" % [host_name, "in the world" if host_here else "away"])
	return " · ".join(facts)


func _join_known() -> void:
	var you: Dictionary = _dial.answer().get("you", {}) if _dial != null else {}
	_join_now(String(you.get("name", _name())), String(you.get("player_id", "")), 0, null)


func _join_now(player_name: String, player_id: String, starter: int, brought: Gen2SaveData) -> void:
	var data: GameData = _data()
	if data == null or _dial == null:
		return
	var answer: Dictionary = _dial.answer()
	var link: PokeCoopClient = _dial.take()
	_dial = null
	var session: PokeCoopSession = PokeCoopSession.joining(data, _target["address"], int(_target["port"]), player_name, starter,
		player_id, brought, PokeCoopLog.create(PokeCoopLog.sharing()), link)
	if session == null:
		_toast("Could not reach %s." % _shown_join(_target))
		return
	_waiting = session
	Gen2GameRuntime.instance().coop = session
	PokeCoopLobby.remember({"name": player_name, "game": String(_game), "last": {"kind": "join", "game": String(_game),
		"address": _target["address"], "port": int(_target["port"]), "title": answer.get("title", ""), "host": answer.get("host", ""),
		"badges": int(answer.get("badges", 0)), "members": (answer.get("players", []) as Array).filter(func(member: Variant) -> bool:
			return member is Dictionary and member.get("name") != player_name) + [{"name": player_name, "game": String(data.id)}]}})
	PokeCoopLobby.add_recent({"address": _target["address"], "port": int(_target["port"]), "title": answer.get("title", ""),
		"game": String(_game), "host": answer.get("host", "")})
	_open_sheet(&"joining")
	_sheet_title("Joining %s as %s…" % [answer.get("title", ""), player_name])
	_note(_sheet.body(), "The world opens as soon as the host lets you in.", _theme.muted)
	_sheet_buttons(_sheet, [["Cancel", _cancel_and_close]])


func _build_new_player() -> void:
	var hosting: bool = bool(_form.get("hosting", false))
	var title: String = String(_form.get("title", ""))
	_heading("New in %s" % title, "%s · you play %s" % ["Your campaign" if hosting else "%s's campaign" % _form.get("host", "The host"),
		_row(_game)["title"]])
	var columns: Array = _side_by_side(_pane(), [1.0, 1.25])
	var left: VBoxContainer = columns[0]
	_caption(left, "Your name")
	var name_field: LineEdit = _field("name", _name(), "Your name", MAX_NAME)
	left.add_child(name_field)
	_landing = name_field
	_note(left, "Up to %d letters, as on the cartridge. Played here before on another device? Type the same name and you get your trainer back."
		% MAX_NAME)
	var right: VBoxContainer = columns[1]
	_caption(right, "How you start")
	_start_options(right)
	var main: Gen2LauncherButton = _actions("", [["Cancel", back]], ["%s as %s" % ["Host" if hosting else "Join", _name()],
		_new_player_go, &"play"])
	name_field.text_changed.connect(func(_typed: String) -> void: main.text = "%s as %s" % ["Host" if hosting else "Join", _name()])


func _new_player_go() -> void:
	if bool(_form.get("hosting", false)):
		_host_campaign(String(_form.get("campaign", "")), _name(), _starter(), _brought(), StringName(String(_form.get("campaign_game", ""))))
	else:
		_join_now(_name(), "", _starter(), _brought())


func _open_sheet(kind: StringName, again: Callable = Callable()) -> PokeCoopTabParts.Sheet:
	_close_sheet()
	_sheet = PokeCoopTabParts.Sheet.make(_theme, _compact)
	_sheet_kind = kind
	_sheet_again = again
	_sheet.dismissed.connect(_dismiss_sheet)
	_sheet.open(_host_control if _host_control != null and _host_control.is_inside_tree() else get_tree().root)
	return _sheet


func _dismiss_sheet() -> void:
	if _sheet_kind in [&"connecting", &"joining"]:
		_cancel_and_close()
	else:
		_close_sheet()


func _close_sheet() -> void:
	if _sheet != null and is_instance_valid(_sheet):
		_sheet.close()
	_sheet = null
	_sheet_kind = &""
	_sheet_key = ""


func _sheet_buttons(sheet: PokeCoopTabParts.Sheet, quiet: Array, primary: Array = []) -> void:
	var row: BoxContainer = sheet.actions()
	var main: Gen2LauncherButton = null
	if not primary.is_empty():
		main = _button(String(primary[0]), Gen2LauncherButton.Variant.PRIMARY, primary[1])
	if main != null and _compact:
		row.add_child(main)
	for entry: Array in quiet:
		var button: Gen2LauncherButton = _button(String(entry[0]), Gen2LauncherButton.Variant.DANGER if entry.size() > 2 and entry[2] == "danger" \
			else Gen2LauncherButton.Variant.QUIET, entry[1])
		row.add_child(button)
		if entry.size() > 2 and not _compact:
			row.move_child(button, 0)
	if not _compact:
		var aside: int = quiet.filter(func(entry: Array) -> bool: return entry.size() > 2).size()
		row.add_child(Gen2LauncherUI.spacer())
		row.move_child(row.get_child(row.get_child_count() - 1), aside)
	if main != null and not _compact:
		row.add_child(main)
	var landing: Control = main if main != null else row.get_child(row.get_child_count() - 1) as Control
	if landing != null and not PokeInputDevice.is_pointer(Gen2InputRuntime.instance().device()):
		_grab.call_deferred(landing)


func _edit_focused() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	for index: int in _campaigns.size():
		if focused != null and focused.get_meta("campaign", "") == _campaigns[index]["id"]:
			_open_edit(index)
			return
	if not _campaigns.is_empty():
		_open_edit(_picked)


func _open_edit(index: int) -> void:
	var row: Dictionary = _campaigns[index]
	_form = {"edit_title": row["title"], "edit_rival": row.get("rival", ""), "editing": index,
		"edit_both": bool(row.get("both_versions", false))}
	var sheet: PokeCoopTabParts.Sheet = _open_sheet(&"edit", _open_edit.bind(index))
	sheet.body().add_child(Gen2LauncherUI.title(_theme, String(row["title"]), Gen2LauncherTheme.FONT_TITLE + 3))
	_caption(sheet.body(), "Campaign name")
	sheet.body().add_child(_field("edit_title", String(row["title"]), "A name for the campaign", MAX_TITLE))
	_caption(sheet.body(), "Rival")
	_rival_picker(sheet.body(), "edit_rival", false)
	_note(sheet.body(), "Takes effect for everyone the next time the campaign is hosted. His team and fights stay the same.")
	_both_versions_switch(sheet.body(), "edit_both", row["game"])
	_sheet_buttons(sheet, [["Delete campaign…", _ask_delete.bind(index), "danger"], ["Cancel", _close_sheet]], ["Save", _save_edit.bind(index)])


func _save_edit(index: int) -> void:
	var row: Dictionary = _campaigns[index]
	var title: String = String(_form.get("edit_title", row["title"])).strip_edges().to_upper()
	var rival: String = String(_form.get("edit_rival", "")).strip_edges().to_upper()
	if PokeCoopSession.edit_campaign(_data(), String(row["id"]), title if not title.is_empty() else String(row["title"]), rival,
			row["game"], bool(_form.get("edit_both", false))) != OK:
		_toast("The campaign could not be changed.", "This version cannot read it, or it could not be written.")
	_close_sheet()
	_show(HOST)


func _ask_delete(index: int) -> void:
	var row: Dictionary = _campaigns[index]
	var sheet: PokeCoopTabParts.Sheet = _open_sheet(&"delete", _ask_delete.bind(index))
	sheet.body().add_child(Gen2LauncherUI.title(_theme, "Delete %s?" % row["title"], Gen2LauncherTheme.FONT_TITLE + 3))
	_note(sheet.body(), "Its players and story leave this list. The last checkpoint stays in the campaigns folder as %s%s, in case you want it back." % [
		PokeCoopSession.campaign_path(_data(), String(row["id"]), row["game"]).get_file(), PokeCoopSave.BACKUP_SUFFIX], _theme.muted)
	_sheet_buttons(sheet, [["Keep it", _close_sheet]], ["Delete", _delete.bind(index)])


func _delete(index: int) -> void:
	PokeCoopSession.delete_campaign(_data(), String(_campaigns[index]["id"]), _campaigns[index]["game"])
	_picked = 0
	_close_sheet()
	_show(HOST)


func _open_troubleshooting() -> void:
	var sheet: PokeCoopTabParts.Sheet = _open_sheet(&"troubleshoot", _open_troubleshooting)
	sheet.body().add_child(Gen2LauncherUI.title(_theme, "Troubleshooting", Gen2LauncherTheme.FONT_TITLE + 3))
	sheet.body().add_child(Gen2LauncherUI.switch(_theme, &"bug", "Share debug logs", PokeCoopLog.sharing(),
		func(on: bool) -> void: PokeCoopLog.set_sharing(on)))
	_note(sheet.body(), "Every session is written to this device's logs folder. Shared, each player's file also holds the others' lines.",
		_theme.muted)
	_sheet_buttons(sheet, [["Open the logs folder", open_logs_folder, "left"], ["Close", _close_sheet]])


static func open_logs_folder() -> void:
	var folder: String = ProjectSettings.globalize_path(PokeCoopLog.DIRECTORY)
	DirAccess.make_dir_recursive_absolute(folder)
	OS.shell_open(folder)


func _process(_delta: float) -> void:
	if _opening:
		return
	var now: int = Time.get_ticks_msec()
	var listening: bool = is_visible_in_tree() and _screen in [START, JOIN]
	if listening:
		_listener.poll(now)
	elif _listener.listening():
		_listener.close()
	if _dial != null:
		_dial.process(now)
	_follow_waiting()
	if now - _refreshed_at >= REFRESH_MSEC:
		_refreshed_at = now
		_refresh_live(false)
		_refresh_connecting()


func _follow_waiting() -> void:
	if _waiting == null or _opening:
		return
	if not _waiting.ended_reason().is_empty():
		var reason: String = _waiting.ended_reason()
		_waiting.close()
		Gen2GameRuntime.instance().coop = null
		_waiting = null
		_close_sheet()
		_toast("Could not join", why_not(reason))
		_show(JOIN)
	elif _waiting.is_ready():
		_waiting = null
		_enter_world()


func _refresh_live(_now: bool) -> void:
	if _live.has("players"):
		var session: PokeCoopSession = Gen2GameRuntime.instance().coop
		if session != null and session.host != null:
			var members: Array = session.host.players.values()
			if Engine.get_process_frames() % 10 == 0:
				PokeCoopLobby.note_used(PokeCoopLobby.local_addresses(), members)
			_refill("players", str(members.map(func(member: PokeCoopPlayer) -> String:
				return "%s/%s/%s" % [member.name, member.game_id, member.connected])) + str(session.host.wild_tables.keys()),
				_fill_players.bind(session))
	var hosts: Array = _listener.hosts().filter(func(row: Dictionary) -> bool: return not _own_beacon(row))
	if _live.has("hosts"):
		_refill("hosts", str(hosts.map(func(row: Dictionary) -> String:
			return "%s|%s|%s|%s|%s" % [row["address"], row["port"], row["title"], row["players"], row["badges"]])), _fill_hosts.bind(hosts))
	if _live.has("looking"):
		(_live["looking"]["node"] as Label).text = "looking…" if _listener.listening() else "not listening here: type the address below"
	if _live.has("nearby_count"):
		(_live["nearby_count"]["node"] as Label).text = "%d game%s found nearby" % [hosts.size(), "" if hosts.size() == 1 else "s"] \
			if not hosts.is_empty() else "Looking for games nearby"


func _own_beacon(row: Dictionary) -> bool:
	var coop: PokeCoopSession = Gen2GameRuntime.instance().coop
	return coop != null and coop.host != null and coop.host.campaign.campaign_id == row["campaign"]


func _refill(key: String, signature: String, fill: Callable) -> void:
	var entry: Dictionary = _live[key]
	if entry["key"] == signature:
		return
	entry["key"] = signature
	var box: Container = entry["node"]
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var had_focus: bool = focused != null and box.is_ancestor_of(focused)
	Gen2LauncherUI.clear(box)
	fill.call(box)
	if had_focus:
		var first: Control = Gen2FocusGuard.first_focusable(box)
		if first != null:
			_grab.call_deferred(first)


static func why_not(reason: String) -> String:
	match reason:
		"refused: content_mismatch":
			return "The host plays a cartridge yours cannot join. Red plays with Red or Blue of the same language; German and English, Yellow, or other revisions cannot play together."
		"refused: protocol_mismatch":
			return "The host runs a different version of the game. Both players need builds made from the same version."
		"refused: already_connected":
			return "That trainer is already playing from another device."
		"refused: unknown_player":
			return "The host does not take new players in this campaign."
		"host_unreachable":
			return "Could not reach the host. Check the address, that the host pressed Host, and that UDP port %d reaches their device (a shared VPN such as WireGuard avoids router setup)." % PokeCoopEnetTransport.DEFAULT_PORT
		"host_shutdown":
			return "The host closed the session."
	return "The host said no: %s." % reason.trim_prefix("refused: ").replace("_", " ")


static func _find(node: Node, wanted: Callable) -> Array:
	var out: Array = []
	for child: Node in node.get_children():
		if wanted.call(child):
			out.append(child)
		out.append_array(_find(child, wanted))
	return out
