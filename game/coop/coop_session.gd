class_name PokeCoopSession
extends RefCounted

## One co-op run on this device: the client, the host when this device hosts,
## and the world screen with the partner actor, battle takeover, sync link and
## panel. [Gen2GameRuntime] drives it once a frame. The actor and the takeover
## are registered with the mod host once and follow whichever session is live.

const ACTOR_ID: StringName = &"coop_players"
const TAKEOVER_ID: StringName = &"coop_battles"
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
var _identity_key: String = ""
var _identity_saved: String = ""
var _greeting: Dictionary = {}
var _retry_as_new: bool = false


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


func is_ready() -> bool:
	return not client.me().is_empty()


## Why the session ended or was refused, or empty while it runs.
func ended_reason() -> String:
	return client.ended_reason


func process() -> void:
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
	if link != null:
		link.advance()
	if not client.player_id.is_empty() and client.player_id != _identity_saved:
		_identity_saved = client.player_id
		_remember(_identity_key, client.player_id)
	if screen != null and is_instance_valid(screen) and panel != null:
		var mode: Node.ProcessMode = Node.PROCESS_MODE_DISABLED if panel.is_open() \
			else Node.PROCESS_MODE_INHERIT
		if screen.process_mode != mode:
			screen.process_mode = mode


## The world screen for this player, built once the host has said who they are.
## The caller puts it in the tree; the panel rides on it.
func open_world() -> Gen2WorldScreen:
	if not is_ready() or screen != null:
		return screen
	_claim_seams()
	var view: Dictionary = (client.state.get("players", {}) as Dictionary).get(client.player_id, {})
	var save: Gen2SaveData = _local_save(client.me())
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
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.add_child(layer)
	panel = PokeCoopBattlePanel.over(client, data)
	layer.add_child(panel)


func _claim_seams() -> void:
	if _actor == null:
		_actor = PokeCoopRemoteActor.new()
		_takeover = PokeCoopBattleTakeover.new()
		Gen2ModHost.instance().register_world_actor(ACTOR_ID, _actor)
		Gen2ModHost.instance().register_battle_takeover(TAKEOVER_ID, _takeover)
	_actor.client = client
	_takeover.client = client
	_takeover.data = data


## The world explores on a save of its own, built from this player's record and
## kept in step with it by the link.
func _local_save(me: Dictionary) -> Gen2SaveData:
	var save := Gen2SaveData.new()
	save.game_id = data.id
	save.rom_sha1 = data.sha1
	save.player_name = String(me.get("name", ""))
	save.player_id = int(me.get("trainer_id", 0))
	save.run_rules = Gen2Rules.new()
	for row: Dictionary in me.get("party", []):
		var mon: Gen2SaveMon = Gen2SaveMon.from_dict(row["mon"])
		if mon != null:
			save.party.append(mon)
	return save


## Ends the run: the host, when this device is it, tells everyone first.
func close() -> void:
	if host != null:
		host.shutdown("host_shutdown", 0)
	client.transport.close()
	if _actor != null and _actor.client == client:
		_actor.client = null
		_takeover.client = null


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
