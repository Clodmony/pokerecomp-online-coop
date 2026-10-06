class_name PokeCoopSession
extends RefCounted

## One co-op run on this device: the client, the host when this device hosts,
## and the world screen with the partner actor, battle takeover, sync link and
## panel. [Gen2GameRuntime] drives it once a frame. The actor and the takeover
## are registered with the mod host once and follow whichever session is live.

const ACTOR_ID: StringName = &"coop_players"
const TAKEOVER_ID: StringName = &"coop_battles"
const NOTICE_FRAMES: int = 240
const LEAVE_FRAMES: int = 180
const RECONNECT_FRAMES: int = 120
const RECONNECT_ATTEMPTS: int = 10
const LAUNCHER_SCENE: String = "res://game/main/main.tscn"
## A scratch root for the window's own saves; the campaign is the host's.
const WINDOW_SAVES: String = "user://coop_window"
## Which player this device was on each host, by cartridge, address and port.
static var identity_path: String = "user://coop_identity.json"

static var _actor: PokeCoopRemoteActor = null
static var _takeover: PokeCoopBattleTakeover = null

var data: GameData = null
var client: PokeCoopClient = null
var host: PokeCoopHost = null
var screen: Gen2WorldScreen = null
var panel: PokeCoopBattlePanel = null
var link: PokeCoopWorldLink = null
var cable: PokeCoopLinkTransport = null
var _cable_state: Dictionary = {}
var _identity_key: String = ""
var _identity_saved: String = ""
var _greeting: Dictionary = {}
var _retry_as_new: bool = false
var _settled_battles: Dictionary = {}
var _evolving: Array = []
var _whiteout_due: bool = false
var _was_ready: bool = false
var _closed: bool = false
var _reconnect_attempts: int = 0
var _reconnect_in: int = 0
var _leaving_in: int = -1
var _notice: Label = null
var _notice_frames: int = 0
var _noticed_save: int = -1


static func campaign_path(game: GameData) -> String:
	return "user://coop_%s_campaign.json" % String(game.id)


## This device hosts on [param port] and plays as [param player_name], loading
## the cartridge's campaign file or starting one.
static func hosting(
	game: GameData, port: int, player_name: String, starter: int
) -> PokeCoopSession:
	var link_out: PokeCoopEnetTransport = PokeCoopEnetTransport.listen(port)
	if game == null or link_out == null:
		return null
	var loaded: Dictionary = PokeCoopSave.read(campaign_path(game))
	var campaign: PokeCoopCampaign = loaded.get("campaign", null)
	if campaign == null:
		campaign = PokeCoopCampaign.create(String(game.id), game.id, game.sha1)
		PokeCoopPolicy.start_campaign(campaign)
	var serving: PokeCoopHost = PokeCoopHost.create(game, campaign, link_out)
	serving.save_path = campaign_path(game)
	serving.allow_new_players = true
	serving.adopt_players(loaded.get("players", []))
	var out: PokeCoopSession = _connect(
		game, "127.0.0.1", port, player_name, starter, "", "%s/host:%d" % [String(game.id), port]
	)
	if out == null:
		link_out.close()
		return null
	out.host = serving
	return out


## [param player_id] reclaims a known player; empty uses the one this device
## last played as on that host, or asks for a new one.
static func joining(
	game: GameData, address: String, port: int, player_name: String, starter: int,
	player_id: String = ""
) -> PokeCoopSession:
	return _connect(
		game, address, port, player_name, starter, player_id,
		"%s/%s:%d" % [String(game.id) if game != null else "", address, port]
	)


static func _connect(
	game: GameData, address: String, port: int, player_name: String, starter: int,
	player_id: String, identity_key: String
) -> PokeCoopSession:
	if game == null:
		return null
	var out := PokeCoopSession.new()
	out.data = game
	out._identity_key = identity_key
	out._identity_saved = player_id if not player_id.is_empty() else _remembered(identity_key)
	out._retry_as_new = player_id.is_empty() and not out._identity_saved.is_empty()
	out._greeting = {"address": address, "port": port, "name": player_name, "starter": starter}
	return out if out._dial(out._identity_saved) else null


func _dial(player_id: String) -> bool:
	var link_in: PokeCoopEnetTransport = PokeCoopEnetTransport.dial(
		String(_greeting["address"]), int(_greeting["port"])
	)
	if link_in == null:
		return false
	client = PokeCoopClient.over(link_in)
	client.greet(String(_greeting["name"]), data.id, data.sha1, player_id, int(_greeting["starter"]))
	return true


## Ready once the host has said who this player is, and not again after leaving.
func is_ready() -> bool:
	return not _closed and not client.me().is_empty()


## Why the session ended or was refused, or empty while it runs.
func ended_reason() -> String:
	return client.ended_reason


func process() -> void:
	if _closed:
		_finish_closing()
		return
	if host != null:
		host.poll()
	client.poll()
	## Another window on this device already plays as the remembered player, so
	## this one joins as somebody new.
	if _retry_as_new and client.ended_reason == "refused: already_connected":
		_retry_as_new = false
		client.transport.close()
		_dial("")
		return
	_was_ready = _was_ready or is_ready()
	_keep_connected()
	_follow_session_end()
	_advance_links()
	if not client.player_id.is_empty() and client.player_id != _identity_saved:
		_identity_saved = client.player_id
		_remember(_identity_key, client.player_id)
	if screen != null and is_instance_valid(screen) and panel != null:
		_tend_world()


func _advance_links() -> void:
	if link != null:
		link.hold_holdings = screen != null and is_instance_valid(screen) and screen.get("_link_host") != null
		link.advance()
	if cable != null and not is_same(client.state, _cable_state):
		_cable_state = client.state
		cable.refresh()


## The world stands still under the panel and settles its player once it closes.
func _tend_world() -> void:
	var mode: Node.ProcessMode = Node.PROCESS_MODE_DISABLED if panel.is_open() \
		else Node.PROCESS_MODE_INHERIT
	if screen.process_mode != mode:
		screen.process_mode = mode
	_collect_evolutions()
	_tell_refused_save()
	if not panel.is_open() and _whiteout_due:
		_whiteout_due = false
		screen.white_out()
	elif not panel.is_open() and not _evolving.is_empty():
		screen.evolve_after_battle(_evolving)
		_evolving = []


## A dropped link: dial again as the same player until the host takes them back,
## waiting out its refusal while it still counts them connected.
func _keep_connected() -> void:
	if not _was_ready or client.connected or _leaving_in >= 0 or _closed:
		return
	if client.ended_reason == "refused: already_connected":
		client.ended_reason = ""
	if not client.ended_reason.is_empty():
		return
	_reconnect_in -= 1
	if _reconnect_in > 0:
		return
	_reconnect_in = RECONNECT_FRAMES
	_reconnect_attempts += 1
	if _reconnect_attempts > RECONNECT_ATTEMPTS:
		client.ended_reason = "host_unreachable"
		return
	var link_again: PokeCoopEnetTransport = PokeCoopEnetTransport.dial(
		String(_greeting["address"]), int(_greeting["port"])
	)
	if link_again != null:
		client.transport = link_again
		client.greet(String(_greeting["name"]), data.id, data.sha1, client.player_id)


## The host ended the session or turned this player away: say so, then leave.
func _follow_session_end() -> void:
	if screen == null or not is_instance_valid(screen):
		return
	if _leaving_in < 0 and not client.ended_reason.is_empty():
		say("The session ended: %s." % client.ended_reason.replace("_", " "))
		_leaving_in = LEAVE_FRAMES
	if _leaving_in > 0:
		_leaving_in -= 1
		if _leaving_in == 0:
			leave()


## Back to the launcher; a hosting device first tells every client the run ended.
func leave() -> void:
	_leaving_in = 0
	_closed = true
	if host != null and not host.ended:
		host.shutdown()
	else:
		client.transport.close()
	if screen != null and is_instance_valid(screen):
		screen.get_tree().change_scene_to_file.call_deferred(LAUNCHER_SCENE)
	_finish_closing()


func _finish_closing() -> void:
	if host != null and not host.ended:
		host.poll()
		return
	_release_seams()
	var runtime: Gen2GameRuntime = Gen2GameRuntime.instance()
	if runtime != null and runtime.coop == self:
		runtime.coop = null


## The world printed its own "saved" line; a checkpoint the host refused says so.
func _tell_refused_save() -> void:
	_notice_frames -= 1
	if _notice != null and _notice_frames == 0:
		_notice.visible = false
	if link == null or link.save_seq < 0 or link.save_seq == _noticed_save:
		return
	for rejection: Dictionary in client.rejections:
		if int(rejection.get("seq", -1)) == link.save_seq:
			_noticed_save = link.save_seq
			say("The campaign was not saved: %s." % String(rejection.get("reason", "")).replace("_", " "))


## A line over the world for a few seconds.
func say(text: String) -> void:
	if _notice == null:
		return
	_notice.text = text
	_notice.visible = true
	_notice_frames = NOTICE_FRAMES


## What a finished host battle owes this window's world: its player's Pokémon
## due to evolve, or a whiteout after a loss, which costs them half their own
## money. A battle this window's world opened itself is that world's to settle.
func _collect_evolutions() -> void:
	if link == null:
		return
	for battle_id: String in client.battles:
		var view: Dictionary = client.battles[battle_id]
		if _settled_battles.has(battle_id) or String(view.get("outcome", "")).is_empty():
			continue
		_settled_battles[battle_id] = true
		if _takeover != null and _takeover.claimed.has(battle_id):
			continue
		if String(view["outcome"]) == "lost":
			_whiteout_due = true
		var uids: Array = link.uids()
		for uid: Variant in view.get("evolvable", []) as Array:
			var index: int = uids.find(String(uid))
			if index >= 0 and not _evolving.has(index):
				_evolving.append(index)


## The world screen for this player, built once the host has said who they are.
## The caller puts it in the tree; the panel rides on it.
func open_world() -> Gen2WorldScreen:
	if not is_ready() or screen != null:
		return screen
	_claim_seams()
	Gen2SaveStore.use_root("%s/%s" % [WINDOW_SAVES, client.player_id.validate_filename()])
	var view: Dictionary = (client.state.get("players", {}) as Dictionary).get(client.player_id, {})
	var save: Gen2SaveData = PokeCoopWorldLink.local_save(client, data)
	screen = (load("res://game/world/world_screen.tscn") as PackedScene).instantiate() as Gen2WorldScreen
	var map: Vector2i = view.get("map", PokeCoopPolicy.START_MAP)
	screen.map_group = map.x
	screen.map_number = map.y
	screen.start_cell = view.get("cell", Vector2i.ZERO)
	screen.set_data(data)
	screen.set_save(save)
	Gen2ModHost.instance().created_save(save)
	Gen2ModHost.instance().activate_save(save)
	screen.ready.connect(_on_world_ready.bind(save), CONNECT_ONE_SHOT)
	return screen


func _on_world_ready(save: Gen2SaveData) -> void:
	var world: Gen2WorldAPI = screen.get("_world")
	if world != null:
		link = PokeCoopWorldLink.over(client, world.state, save, data)
		cable = PokeCoopLinkTransport.over(client)
		world.state.set_link_transport(cable)
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.add_child(layer)
	panel = PokeCoopBattlePanel.over(client, data)
	panel.leave_requested.connect(leave)
	layer.add_child(panel)
	_notice = Label.new()
	_notice.add_theme_font_size_override("font_size", PokeCoopBattlePanel.FONT_SIZE)
	_notice.add_theme_color_override("font_outline_color", Color.BLACK)
	_notice.add_theme_constant_override("outline_size", 6)
	_notice.position = Vector2(24, 24)
	_notice.visible = false
	layer.add_child(_notice)


func _claim_seams() -> void:
	if _actor == null:
		_actor = PokeCoopRemoteActor.new()
		_takeover = PokeCoopBattleTakeover.new()
		Gen2ModHost.instance().register_world_actor(ACTOR_ID, _actor)
		Gen2ModHost.instance().register_battle_takeover(TAKEOVER_ID, _takeover)
	_actor.client = client
	_takeover.client = client
	_takeover.data = data


## Ends the run: the host, when this device is it, tells everyone first.
func close() -> void:
	_closed = true
	if host != null:
		host.shutdown("host_shutdown", 0)
	client.transport.close()
	_release_seams()


func _release_seams() -> void:
	if _actor != null and _actor.client == client:
		_actor.client = null
		_takeover.client = null
		Gen2SaveStore.use_root("")


static func _remembered(key: String) -> String:
	var known: Variant = JSON.parse_string(FileAccess.get_file_as_string(identity_path)) \
		if FileAccess.file_exists(identity_path) else {}
	return String((known as Dictionary).get(key, "")) if known is Dictionary else ""


static func _remember(key: String, player_id: String) -> void:
	var known: Variant = JSON.parse_string(FileAccess.get_file_as_string(identity_path)) \
		if FileAccess.file_exists(identity_path) else {}
	var table: Dictionary = known if known is Dictionary else {}
	table[key] = player_id
	var file: FileAccess = FileAccess.open(identity_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(table, "\t"))
