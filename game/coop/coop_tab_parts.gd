class_name PokeCoopTabParts
extends RefCounted

## The Co-op tab's own pieces in the launcher's palette: cards that are buttons, chips, dots, steps and its sheet.

const LONG_PRESS_MSEC: int = 550
const SHEET_WIDTH: float = 640.0
const SHEET_MARGIN: float = 24.0
const NAME_KEYS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-."
const ADDRESS_KEYS: String = "123456789.0:"


static func text(theme: Gen2LauncherTheme, words: String, size: int = Gen2LauncherTheme.FONT_BODY,
		colour: Color = Color(0, 0, 0, 0), wraps: bool = false) -> Label:
	var label := Label.new()
	label.text = words
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour if colour.a > 0.0 else theme.text)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wraps:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		label.clip_text = true
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


static func whole(label: Label) -> Label:
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return label


static func dot(colour: Color, side: float = 10.0) -> Control:
	var out := Panel.new()
	var round := StyleBoxFlat.new()
	round.bg_color = colour
	round.set_corner_radius_all(int(side))
	out.add_theme_stylebox_override("panel", round)
	out.custom_minimum_size = Vector2(side, side)
	out.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return out


static func chip(theme: Gen2LauncherTheme, words: String, colour: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var out := PanelContainer.new()
	out.add_theme_stylebox_override("panel", theme.padded(theme.box(theme.surface_alt, Gen2LauncherTheme.RADIUS_PILL), 10, 3))
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	out.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row: HBoxContainer = Gen2LauncherUI.row(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	out.add_child(row)
	if colour.a > 0.0:
		row.add_child(dot(colour, 9.0))
	var label: Label = text(theme, words, Gen2LauncherTheme.FONT_SMALL)
	whole(label)
	row.add_child(label)
	return out


static func state(theme: Gen2LauncherTheme, words: String, colour: Color) -> PanelContainer:
	var out := PanelContainer.new()
	out.add_theme_stylebox_override("panel", theme.padded(theme.box(theme.with_alpha(colour, 0.16), Gen2LauncherTheme.RADIUS_PILL), 10, 2))
	out.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = text(theme, words, Gen2LauncherTheme.FONT_SMALL, colour)
	whole(label)
	out.add_child(label)
	return out


static func flow(gap: int = Gen2LauncherUI.GAP_SM) -> HFlowContainer:
	var out := HFlowContainer.new()
	out.add_theme_constant_override("h_separation", gap)
	out.add_theme_constant_override("v_separation", gap)
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return out


static func step(theme: Gen2LauncherTheme, mark: String, kind: StringName, words: String, detail: String = "") -> HBoxContainer:
	var row: HBoxContainer = Gen2LauncherUI.row(Gen2LauncherUI.GAP_SM + 2)
	var fills: Dictionary = {&"done": theme.success, &"now": theme.accent, &"bad": theme.error, &"todo": theme.line}
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", theme.box(fills.get(kind, theme.line), Gen2LauncherTheme.RADIUS_PILL))
	badge.custom_minimum_size = Vector2(24, 24)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var sign: Label = text(theme, mark, Gen2LauncherTheme.FONT_SMALL, theme.muted if kind == &"todo" else theme.on_accent)
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	whole(sign).size_flags_horizontal = Control.SIZE_FILL
	badge.add_child(sign)
	row.add_child(badge)
	var words_column: VBoxContainer = Gen2LauncherUI.column(1)
	words_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words_column.add_child(text(theme, words, Gen2LauncherTheme.FONT_BODY, theme.text, true))
	if not detail.is_empty():
		words_column.add_child(text(theme, detail, Gen2LauncherTheme.FONT_SMALL, theme.muted, true))
	row.add_child(words_column)
	return row


static func radio(theme: Gen2LauncherTheme, on: bool) -> Control:
	var ring := Panel.new()
	ring.add_theme_stylebox_override("panel", theme.box(theme.panel, Gen2LauncherTheme.RADIUS_PILL,
		theme.accent if on else theme.faint, 6 if on else 2))
	ring.custom_minimum_size = Vector2(20, 20)
	ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ring


static func badge(theme: Gen2LauncherTheme, glyph: StringName, fill: Color, ink: Color, side: float = 54.0) -> Control:
	var out := PanelContainer.new()
	out.add_theme_stylebox_override("panel", theme.box(fill, Gen2LauncherTheme.RADIUS_MD))
	out.custom_minimum_size = Vector2(side, side)
	out.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark: PokeLauncherIcon = PokeLauncherIcon.create(glyph, side * 0.46, ink)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	out.add_child(mark)
	return out


static func keys(theme: Gen2LauncherTheme, field: LineEdit, address: bool, from_bottom: bool) -> Sheet:
	var sheet: Sheet = Sheet.make(theme, from_bottom)
	var shown: Label = text(theme, field.text + "_", Gen2LauncherTheme.FONT_TITLE + 3)
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sheet.body().add_child(shown)
	var put := func(value: String) -> void:
		if field.max_length > 0 and value.length() > field.max_length:
			return
		field.text = value
		field.caret_column = value.length()
		field.text_changed.emit(value)
		shown.text = value + "_"
	var grid := GridContainer.new()
	grid.columns = 3 if address else (5 if from_bottom else 8)
	grid.add_theme_constant_override("h_separation", Gen2LauncherUI.GAP_SM)
	grid.add_theme_constant_override("v_separation", Gen2LauncherUI.GAP_SM)
	sheet.body().add_child(grid)
	for letter: String in (ADDRESS_KEYS if address else NAME_KEYS).split(""):
		grid.add_child(_key(theme, letter, func() -> void: put.call(field.text + letter)))
	var row: BoxContainer = sheet.actions()
	if not address:
		row.add_child(_key(theme, "Space", func() -> void: put.call(field.text + " ")))
	row.add_child(_key(theme, "Delete", func() -> void: put.call(field.text.left(-1))))
	row.add_child(_key(theme, "Done", sheet.close, Gen2LauncherButton.Variant.PRIMARY))
	sheet.dismissed.connect(sheet.close)
	field.tree_exiting.connect(sheet.queue_free)
	return sheet


static func _key(theme: Gen2LauncherTheme, label: String, run: Callable,
		kind: Gen2LauncherButton.Variant = Gen2LauncherButton.Variant.NEUTRAL) -> Gen2LauncherButton:
	var out: Gen2LauncherButton = Gen2LauncherButton.create(theme, label, kind)
	out.custom_minimum_size = Vector2(Gen2LauncherUI.TOUCH_TARGET - 4.0, Gen2LauncherUI.TOUCH_TARGET - 4.0)
	out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	out.pressed.connect(run)
	return out


class Tile extends Button:
	signal chosen
	signal secondary

	enum Look { PANEL, PRIMARY, DASHED, WELL }

	var look: Look = Look.PANEL
	var selected: bool = false
	var least_width: float = 0.0
	var _theme: Gen2LauncherTheme = null
	var _box: BoxContainer = null
	var _radius: float = Gen2LauncherTheme.RADIUS_MD
	var _pad: Vector2i = Vector2i(18, 14)
	var _down_at: int = -1
	var _long: bool = false

	static func make(palette: Gen2LauncherTheme, kind: Look = Look.PANEL, across: bool = false,
			radius: float = Gen2LauncherTheme.RADIUS_MD, pad: Vector2i = Vector2i(18, 14)) -> Tile:
		var out := Tile.new()
		out._theme = palette
		out.look = kind
		out._radius = radius
		out._pad = pad
		out._box = Gen2LauncherUI.row(Gen2LauncherUI.GAP_MD) if across else Gen2LauncherUI.column(6)
		out._box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		out._box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		out.add_child(out._box)
		out.focus_mode = Control.FOCUS_ALL
		out.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		out.set_process(false)
		out.pressed.connect(out._on_pressed)
		for change: Signal in [out.focus_entered, out.focus_exited, out.mouse_entered, out.mouse_exited]:
			change.connect(out._repaint)
		out._box.minimum_size_changed.connect(out._measure)
		out.resized.connect(out._measure)
		out._repaint()
		return out

	func content() -> BoxContainer:
		return _box

	func set_selected(on: bool) -> void:
		selected = on
		_repaint()

	func _on_pressed() -> void:
		if _long:
			_long = false
			return
		Gen2LauncherAudio.play(&"click")
		chosen.emit()

	func _gui_input(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click == null:
			return
		if click.button_index == MOUSE_BUTTON_RIGHT and click.pressed and secondary.has_connections():
			accept_event()
			secondary.emit()
		elif click.button_index == MOUSE_BUTTON_LEFT:
			_down_at = Time.get_ticks_msec() if click.pressed else -1
			set_process(click.pressed and secondary.has_connections())

	func _process(_delta: float) -> void:
		if _down_at >= 0 and Time.get_ticks_msec() - _down_at >= PokeCoopTabParts.LONG_PRESS_MSEC:
			_down_at = -1
			_long = true
			set_process(false)
			secondary.emit()

	func _repaint() -> void:
		if _theme == null:
			return
		var reached: bool = has_focus() or is_hovered()
		var fill: Color = _theme.accent_wash(0.08) if reached and not selected else _theme.panel
		var border: Color = _theme.accent if selected else _theme.line
		match look:
			Look.PRIMARY:
				fill = _theme.accent.lerp(_theme.text, 0.12) if reached else _theme.accent
				border = fill
			Look.DASHED:
				fill = _theme.accent_wash(0.10 if reached else 0.04)
				border = _theme.accent_wash(0.5)
			Look.WELL:
				fill = _theme.accent_wash(0.10) if reached else _theme.surface_alt
				border = _theme.accent if selected else Color(0, 0, 0, 0)
		for paint: String in ["normal", "hover", "pressed", "disabled"]:
			add_theme_stylebox_override(paint, _theme.padded(_theme.box(fill, _radius, border, 3 if selected else 1), _pad.x, _pad.y))
		add_theme_stylebox_override("focus", _theme.padded(_theme.focus_ring(_radius, 3), _pad.x, _pad.y))
		modulate.a = 0.55 if disabled else 1.0
		_measure()

	func _measure() -> void:
		var chrome: StyleBox = get_theme_stylebox(&"normal")
		if chrome == null or _box == null:
			return
		var wanted: Vector2 = _box.get_combined_minimum_size() + chrome.get_minimum_size()
		custom_minimum_size = Vector2(maxf(least_width, minf(wanted.x, 220.0)), maxf(wanted.y, Gen2LauncherUI.TOUCH_TARGET))
		_box.offset_left = chrome.get_margin(SIDE_LEFT)
		_box.offset_top = chrome.get_margin(SIDE_TOP)
		_box.offset_right = -chrome.get_margin(SIDE_RIGHT)
		_box.offset_bottom = -chrome.get_margin(SIDE_BOTTOM)


class Sheet extends Control:
	signal dismissed
	signal heard(event: InputEvent)

	var listens: bool = false

	var _theme: Gen2LauncherTheme = null
	var _bottom: bool = false
	var _card: PanelContainer = null
	var _scroll: Gen2LauncherScroll = null
	var _body: VBoxContainer = null
	var _actions: BoxContainer = null
	var _restore_focus: Control = null

	static func make(palette: Gen2LauncherTheme, from_bottom: bool) -> Sheet:
		var out := Sheet.new()
		out._theme = palette
		out._bottom = from_bottom
		out._build()
		return out

	func _build() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		add_to_group(Gen2FocusGuard.MODAL_GROUP)
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.38 if not _theme.is_dark() else 0.6)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(dim)
		_card = PanelContainer.new()
		var style: StyleBoxFlat = _theme.padded(_theme.floating(_theme.panel, Gen2LauncherTheme.RADIUS_LG, 26), 26, 22)
		if _bottom:
			style.corner_radius_bottom_left = 0
			style.corner_radius_bottom_right = 0
		_card.add_theme_stylebox_override("panel", style)
		add_child(_card)
		var column: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_MD)
		_card.add_child(column)
		_scroll = Gen2LauncherScroll.create()
		_scroll.size_flags_vertical = Control.SIZE_FILL
		column.add_child(_scroll)
		_body = Gen2LauncherUI.column(Gen2LauncherUI.GAP_MD)
		_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scroll.content().add_child(_body)
		_actions = Gen2LauncherUI.column(Gen2LauncherUI.GAP_SM) if _bottom else Gen2LauncherUI.row(Gen2LauncherUI.GAP_SM)
		column.add_child(_actions)
		resized.connect(_fit)
		_scroll.content().minimum_size_changed.connect(_fit.call_deferred)
		_actions.minimum_size_changed.connect(_fit.call_deferred)

	func body() -> VBoxContainer:
		return _body

	func actions() -> BoxContainer:
		return _actions

	func open(host: Node) -> void:
		var viewport: Viewport = host.get_viewport()
		_restore_focus = viewport.gui_get_focus_owner() if viewport != null else null
		host.add_child(self)
		_fit()

	func close() -> void:
		if _restore_focus != null and is_instance_valid(_restore_focus) and _restore_focus.is_visible_in_tree():
			_restore_focus.grab_focus()
		Gen2Screen.drop(self)

	func _fit() -> void:
		if _card == null or size == Vector2.ZERO:
			return
		var inset: float = float(Gen2LauncherUI.safe_area_insets(get_window())["bottom"]) if is_inside_tree() else 0.0
		var width: float = size.x if _bottom else minf(PokeCoopTabParts.SHEET_WIDTH, size.x - PokeCoopTabParts.SHEET_MARGIN * 2.0)
		var chrome: float = _card.get_combined_minimum_size().y - _scroll.custom_minimum_size.y
		var room: float = size.y - PokeCoopTabParts.SHEET_MARGIN * 2.0 - chrome - inset
		_scroll.custom_minimum_size.y = maxf(minf(_scroll.content().get_combined_minimum_size().y, room), 0.0)
		var tall: float = _card.get_combined_minimum_size().y + (inset if _bottom else 0.0)
		_card.size = Vector2(width, tall)
		_card.position = Vector2((size.x - width) * 0.5, size.y - tall if _bottom else (size.y - tall) * 0.5)

	func _input(event: InputEvent) -> void:
		if listens and event.is_pressed() and not event.is_echo():
			heard.emit(event)

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			dismissed.emit()
