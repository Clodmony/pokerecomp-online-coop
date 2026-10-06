class_name PokeCoopPage
extends VBoxContainer

## The launcher's Co-op tab: host the cartridge's campaign on this device or join
## one on the network by address. A new player picks a starter; the device
## remembers who it was for each host. The world opens once the host answers.

const GAMES: Array[StringName] = [&"red", &"blue"]
const STARTER_NAMES: Array[String] = ["BULBASAUR", "CHARMANDER", "SQUIRTLE"]
const DEFAULT_NAME: String = "RED"

var _theme: Gen2LauncherTheme = null
var _host_control: Control = null
var _games: Array[StringName] = []
var _game: int = 0
var _starter: int = 1
var _name: LineEdit = null
var _address: LineEdit = null
var _status: Label = null
var _host_button: Gen2LauncherButton = null
var _session: PokeCoopSession = null
var _opening: bool = false
## 0 brings a new trainer; above it, that row of [member _slots].
var _bring: int = 0
var _slots: Array = []
var _bring_row: VBoxContainer = null


static func create(palette: Gen2LauncherTheme, host: Control = null) -> PokeCoopPage:
	var page := PokeCoopPage.new()
	page._theme = palette
	page._host_control = host
	page._build()
	return page


func _build() -> void:
	add_theme_constant_override("separation", Gen2LauncherUI.GAP_LG)
	add_child(Gen2LauncherUI.title(_theme, "Co-op", Gen2LauncherTheme.FONT_DISPLAY))
	var scroll: Gen2LauncherScroll = Gen2LauncherScroll.create()
	add_child(scroll)
	var column: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_LG)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.content().add_child(column)
	_games = GAMES.filter(func(game: StringName) -> bool: return GameData.open(game) != null)
	_build_player(_card(column, "You"))
	_build_host(_card(column, "Host a campaign"))
	_build_join(_card(column, "Join a campaign"))
	_status = Gen2LauncherUI.muted(_theme, "" if not _games.is_empty() \
		else "Import Red or Blue on the Play tab first: co-op plays them.")
	column.add_child(_status)


func _card(host: VBoxContainer, title: String) -> VBoxContainer:
	var panel: Gen2LauncherCard = Gen2LauncherCard.create(_theme, Gen2LauncherTheme.RADIUS_MD, 22)
	host.add_child(panel)
	var column: VBoxContainer = Gen2LauncherUI.column(Gen2LauncherUI.GAP_MD)
	panel.add_child(column)
	column.add_child(Gen2LauncherUI.caption(_theme, title))
	return column


func _build_player(card: VBoxContainer) -> void:
	if _games.size() > 1:
		card.add_child(Gen2LauncherUI.choice(
			_theme, &"play", "Cartridge", _game_titles(), _game,
			func(index: int) -> void:
				_game = index
				_build_bring(), _host_control
		))
	_name = _field(DEFAULT_NAME, "Your name")
	_name.max_length = Gen2SaveData.MAX_PLAYER_NAME
	card.add_child(Gen2LauncherUI.stacked(_theme, "Name", _name))
	card.add_child(Gen2LauncherUI.choice(
		_theme, &"sparkle", "Starter, if you are new to the campaign", STARTER_NAMES, _starter,
		func(index: int) -> void: _starter = index, _host_control
	))
	_bring_row = Gen2LauncherUI.column(Gen2LauncherUI.GAP_MD)
	card.add_child(_bring_row)
	_build_bring()


## A new player can bring a trainer from one of this cartridge's own save slots
## instead of a starter; a new campaign hosted that way starts from its story.
func _build_bring() -> void:
	Gen2Screen.drop_children(_bring_row)
	_bring = 0
	var data: GameData = _data()
	_slots = [] if data == null else Gen2SaveStore.slots_for(data.id, data.sha1, data).filter(
		func(row: Dictionary) -> bool: return bool(row["valid"]))
	if _slots.is_empty():
		return
	var labels: Array = ["A new trainer with that starter"]
	for row: Dictionary in _slots:
		labels.append("Slot %d: %s" % [int(row["slot"]) + 1, row["player_name"]])
	_bring_row.add_child(Gen2LauncherUI.choice(
		_theme, &"save", "Bring, if you are new to the campaign", labels, 0,
		func(index: int) -> void: _bring = index, _host_control
	))


func _brought() -> Gen2SaveData:
	var data: GameData = _data()
	if _bring <= 0 or _bring > _slots.size() or data == null:
		return null
	var loaded: Dictionary = Gen2SaveStore.load_result(
		data.id, data.sha1, int((_slots[_bring - 1] as Dictionary)["slot"]), data
	)
	return loaded["save"] if bool(loaded.get("ok", false)) else null


func _build_host(card: VBoxContainer) -> void:
	card.add_child(Gen2LauncherUI.muted(
		_theme, "Plays the campaign saved on this device and lets others on your network "
		+ "join it at %s, port %d." % [", ".join(local_addresses()), PokeCoopEnetTransport.DEFAULT_PORT],
	))
	_host_button = Gen2LauncherButton.create(
		_theme, "Host", Gen2LauncherButton.Variant.PRIMARY, &"play"
	)
	_host_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_host_button.pressed.connect(func() -> void: host_campaign())
	card.add_child(_host_button)


func _build_join(card: VBoxContainer) -> void:
	_address = _field("", "The host's address, for example 192.168.1.20")
	card.add_child(Gen2LauncherUI.stacked(_theme, "Address", _address))
	var join: Gen2LauncherButton = Gen2LauncherButton.create(
		_theme, "Join", Gen2LauncherButton.Variant.NEUTRAL, &"chevron"
	)
	join.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	join.pressed.connect(func() -> void: join_campaign(_address.text.strip_edges()))
	card.add_child(join)


func _game_titles() -> Array:
	var out: Array = []
	for game: StringName in _games:
		out.append(RomRegistry.title_for(game))
	return out


func _field(text: String, hint: String) -> LineEdit:
	var out := LineEdit.new()
	out.text = text
	out.placeholder_text = hint
	out.custom_minimum_size = Vector2(320, 0)
	return out


func focus_target() -> Control:
	return _host_button


## This device's addresses others on the network can reach it at.
static func local_addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for address: String in IP.get_local_addresses():
		if address.count(".") == 3 and not address.begins_with("127.") \
				and not address.begins_with("169.254."):
			out.append(address)
	return out if not out.is_empty() else PackedStringArray(["this device's address"])


func host_campaign(port: int = PokeCoopEnetTransport.DEFAULT_PORT) -> void:
	var session: PokeCoopSession = PokeCoopSession.hosting(
		_data(), port, _player_name(), _starter_species(), _brought()
	)
	var kept: String = PokeCoopSession.campaign_path(_data()).get_file() + PokeCoopSave.BACKUP_SUFFIX \
		if _data() != null else ""
	_begin(session, "Could not host on port %d: is another host running?" % port \
		if PokeCoopSession.last_failure.is_empty() \
		else "This device's campaign file could not be read, so it was left as it is. The checkpoint before it is %s." % kept)


func join_campaign(address: String, port: int = PokeCoopEnetTransport.DEFAULT_PORT) -> void:
	if address.is_empty():
		_say("Type the host's address first.")
		return
	_begin(PokeCoopSession.joining(_data(), address, port, _player_name(), _starter_species(), "", _brought()),
		"Could not reach %s." % address)


func _begin(session: PokeCoopSession, failure: String) -> void:
	if _session != null or _games.is_empty():
		return
	if session == null:
		_say(failure)
		return
	_session = session
	Gen2GameRuntime.instance().coop = session
	_say("Waiting for the host...")


func _process(_delta: float) -> void:
	if _session == null or _opening:
		return
	if not _session.ended_reason().is_empty():
		_say(why_not(_session.ended_reason()))
		_session.close()
		Gen2GameRuntime.instance().coop = null
		_session = null
		return
	if _session.is_ready():
		_opening = true
		Gen2GameRuntime.instance().select_game(_data().id)
		get_tree().change_scene_to_node(_session.open_world())


static func why_not(reason: String) -> String:
	match reason:
		"refused: content_mismatch":
			return "The host plays a different cartridge. Both players need the same game file: Red and Blue, or two revisions of one, cannot play together."
		"refused: protocol_mismatch":
			return "The host runs a different version of the game. Both players need builds made from the same version."
		"host_unreachable":
			return "Could not reach the host. Check the address, that the host pressed Host, and that UDP port %d reaches their device (a shared VPN such as Tailscale avoids router setup)." % PokeCoopEnetTransport.DEFAULT_PORT
		"host_shutdown":
			return "The host closed the session."
	return "The host said no: %s." % reason


func _data() -> GameData:
	return GameData.open(_games[clampi(_game, 0, _games.size() - 1)]) if not _games.is_empty() else null


func _player_name() -> String:
	var typed: String = _name.text.strip_edges().to_upper()
	return typed if not typed.is_empty() else DEFAULT_NAME


func _starter_species() -> int:
	return PokeCoopPolicy.STARTERS[clampi(_starter, 0, PokeCoopPolicy.STARTERS.size() - 1)]


func _say(text: String) -> void:
	_status.text = text
