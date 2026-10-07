class_name PokeCoopSession
extends RefCounted

## One co-op run on this device, driven each frame by [Gen2GameRuntime]: the client, the host when it hosts, and the
## world screen with the actor and takeover (which follow the live session), the sync link and the panel.

const ACTOR_ID: StringName = &"coop_players"
const TAKEOVER_ID: StringName = &"coop_battles"
const NOTICE_MSEC: int = 4000
const LEAVE_MSEC: int = 3000
const RECONNECT_MSEC: int = 2000
const JOIN_TIMEOUT_MSEC: int = 15000
const RECONNECT_ATTEMPTS: int = 60
const RESUME_REDIAL_MSEC: int = 3000
const LAUNCHER_SCENE: String = "res://game/main/main.tscn"
const INTRO_SCENE: String = "res://game/world/intro_screen.tscn"
## A scratch root for the window's own saves; the campaign is the host's.
const WINDOW_SAVES: String = "user://coop_window"
const CAMPAIGNS_DIR: String = "user://coop_campaigns"
## Which player this device was on each host (by cartridge, address and port) in each campaign.
static var identity_path: String = "user://coop_identity.json"
## Why the last [method hosting] gave nothing back, for the launcher to say.
static var last_failure: String = ""

static var _actor: PokeCoopRemoteActor = null
static var _takeover: PokeCoopBattleTakeover = null

var data: GameData = null
var client: PokeCoopClient = null
var host: PokeCoopHost = null
var screen: Gen2WorldScreen = null
var opening_screen: Gen2IntroScreen = null
var panel: PokeCoopBattlePanel = null
var link: PokeCoopWorldLink = null
var cable: PokeCoopLinkTransport = null
var journal: PokeCoopLog = PokeCoopLog.new()
var _stage_seen: String = ""
var _cable_state: Dictionary = {}
var _identity_key: String = ""
var _identity_saved: String = ""
var _greeting: Dictionary = {}
var _retry_as_new: bool = false
var _known: Dictionary = {}
var _campaign_saved: String = ""
var _settled_battles: Dictionary = {}
var _evolving: Array = []
var _whiteout_due: bool = false
var _was_ready: bool = false
var _closed: bool = false
var _reconnect_attempts: int = 0
var _reconnect_at: int = 0
var _leaving_at: int = -1
var _welcomes_seen: int = 0
var _notice: Label = null
var _notice_until: int = 0
var _noticed_save: int = -1
var _partners_seen: Dictionary = {}
var _saves_seen: int = -1
var _paused: bool = false
var _dialled_at: int = 0
var _paused_at: int = 0


static func campaign_path(game: GameData, id: String = "") -> String:
	return "%s/%s/%s.json" % [CAMPAIGNS_DIR, String(game.id), id if not id.is_empty() else String(game.id)]


static func new_campaign_id(game: GameData) -> String:
	return "%s-%d-%04x" % [String(game.id), int(Time.get_unix_time_from_system()), randi() & 0xFFFF]


## This device's campaigns for [param game], the latest saved first.
static func campaigns(game: GameData) -> Array:
	move_legacy(game)
	var folder: String = campaign_path(game).get_base_dir()
	var out: Array = []
	for name: String in DirAccess.get_files_at(folder):
		if not name.ends_with(".json"):
			continue
		var path: String = "%s/%s" % [folder, name]
		var loaded: Dictionary = PokeCoopSave.read(path)
		var campaign: PokeCoopCampaign = loaded.get("campaign", null)
		out.append({
			"id": name.get_basename(), "saved": FileAccess.get_modified_time(path),
			"title": campaign.title if campaign != null and not campaign.title.is_empty() \
				else "FIRST CAMPAIGN" if name.get_basename() == String(game.id) else name.get_basename(),
			"players": (loaded.get("players", []) as Array).map(func(member: PokeCoopPlayer) -> String: return member.name),
			"badges": String.num_int64(campaign.badges, 2).count("1") if campaign != null else 0, "readable": campaign != null,
		})
	out.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return int(first["saved"]) > int(second["saved"]))
	return out


static func move_legacy(game: GameData) -> void:
	var old: String = "user://coop_%s_campaign.json" % String(game.id)
	var target: String = campaign_path(game)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
	for suffix: String in ["", PokeCoopSave.BACKUP_SUFFIX]:
		if FileAccess.file_exists(old + suffix) and not FileAccess.file_exists(target + suffix):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(old + suffix), ProjectSettings.globalize_path(target + suffix))


## This device hosts on [param port] as [param player_name], loading or starting the campaign; [param brought]
## is a new player's save in place of a starter, [param session_log] an unopened log the session writes.
static func hosting(
	game: GameData, port: int, player_name: String, starter: int, brought: Gen2SaveData = null,
	campaign_id: String = "", title: String = "", session_log: PokeCoopLog = null
) -> PokeCoopSession:
	last_failure = ""
	if game == null:
		return null
	move_legacy(game)
	var path: String = campaign_path(game, campaign_id)
	var link_out: PokeCoopEnetTransport = PokeCoopEnetTransport.listen(port)
	if link_out == null:
		return null
	var loaded: Dictionary = PokeCoopSave.read(path)
	if loaded.is_empty() and FileAccess.file_exists(path):
		## Newer, foreign or damaged: never written over with a new campaign.
		last_failure = "campaign_unreadable"
		link_out.close()
		return null
	var campaign: PokeCoopCampaign = loaded.get("campaign", null)
	if campaign == null:
		campaign = PokeCoopCampaign.create(path.get_file().get_basename(), game.id, game.sha1)
		campaign.title = title
		PokeCoopPolicy.start_campaign(campaign)
	var serving: PokeCoopHost = PokeCoopHost.create(game, campaign, link_out)
	serving.save_path = path
	serving.allow_new_players = true
	serving.adopt_players(loaded.get("players", []))
	serving.journal = _opened(session_log, "host", player_name, game, {
		"port": port, "addresses": PokeCoopPage.local_addresses(), "campaign_id": campaign.campaign_id,
		"campaign_title": campaign.title, "campaign_path": path,
	})
	var out: PokeCoopSession = _connect(
		game, "127.0.0.1", port, player_name, starter, "", "%s/host:%d" % [String(game.id), port], brought, serving.journal
	)
	if out == null:
		serving.journal.close()
		link_out.close()
		return null
	out.host = serving
	out.client.streams_log = false
	return out


## [param player_id] reclaims a player; empty is this device's player in the host's campaign, or a new one.
static func joining(
	game: GameData, address: String, port: int, player_name: String, starter: int,
	player_id: String = "", brought: Gen2SaveData = null, session_log: PokeCoopLog = null
) -> PokeCoopSession:
	if game == null:
		return null
	var opened: PokeCoopLog = _opened(session_log, "join", player_name, game, {"address": address, "port": port})
	var out: PokeCoopSession = _connect(
		game, address, port, player_name, starter, player_id, "%s/%s:%d" % [String(game.id), address, port], brought, opened
	)
	if out == null:
		opened.close()
	return out


static func _opened(session_log: PokeCoopLog, role: String, player_name: String, game: GameData, fields: Dictionary) -> PokeCoopLog:
	var out: PokeCoopLog = session_log if session_log != null else PokeCoopLog.new()
	out.open(role, player_name, fields.merged({"game_id": String(game.id), "rom_sha1": game.sha1}))
	return out


static func _connect(
	game: GameData, address: String, port: int, player_name: String, starter: int,
	player_id: String, identity_key: String, brought: Gen2SaveData, session_log: PokeCoopLog
) -> PokeCoopSession:
	if game == null:
		return null
	var out := PokeCoopSession.new()
	out.journal = session_log
	out.data = game
	out._identity_key = identity_key
	out._identity_saved = player_id
	out._known = {} if not player_id.is_empty() else _remembered(identity_key)
	out._retry_as_new = player_id.is_empty() and not out._known.is_empty()
	out._greeting = {
		"address": address, "port": port, "name": player_name, "starter": starter,
		"save": brought.to_dict() if brought != null else {},
	}
	out._dialled_at = Time.get_ticks_msec()
	return out if out._dial(out._identity_saved) else null


func _dial(player_id: String) -> bool:
	var link_in: PokeCoopEnetTransport = PokeCoopEnetTransport.dial(
		String(_greeting["address"]), int(_greeting["port"])
	)
	journal.add(PokeCoopLog.CLIENT, "dial", {"address": _greeting["address"], "port": _greeting["port"],
		"player_id": player_id, "known": _known, "ok": link_in != null})
	if link_in == null:
		return false
	client = PokeCoopClient.over(link_in)
	client.journal = journal
	client.streams_log = host == null
	client.greet(
		String(_greeting["name"]), data.id, data.sha1, player_id, int(_greeting["starter"]),
		_greeting["save"] if player_id.is_empty() else {}, _known
	)
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
	## Another window here plays as the remembered player, so this one joins as somebody new.
	if _retry_as_new and client.ended_reason == "refused: already_connected":
		journal.add(PokeCoopLog.CLIENT, "retry_as_new", {"known": _known})
		_retry_as_new = false
		_known = {}
		client.transport.close()
		_dial("")
		return
	_was_ready = _was_ready or is_ready()
	if not _was_ready and client.ended_reason.is_empty() and Time.get_ticks_msec() - _dialled_at > JOIN_TIMEOUT_MSEC:
		client.ended_reason = "host_unreachable"
		journal.add(PokeCoopLog.CLIENT, "unreachable", {"waited_msec": Time.get_ticks_msec() - _dialled_at})
	_keep_connected()
	_note_opening()
	_follow_session_end()
	_advance_links()
	if not client.player_id.is_empty() and (client.player_id != _identity_saved or client.campaign_id != _campaign_saved):
		_identity_saved = client.player_id
		_campaign_saved = client.campaign_id
		_remember(_identity_key, client.campaign_id, client.player_id)
	if screen != null and is_instance_valid(screen) and panel != null:
		_tend_world()


func _note_opening() -> void:
	var stage: String = String((client.me().get("opening", {}) as Dictionary).get("stage", ""))
	if stage != _stage_seen:
		_stage_seen = stage
		journal.add(PokeCoopLog.WORLD, "opening_stage", {"stage": stage}, client.player_id)


func _advance_links() -> void:
	if link != null:
		link.hold_holdings = screen != null and is_instance_valid(screen) and screen.get("_link_host") != null
		link.advance()
	if cable != null and not is_same(client.state, _cable_state):
		_cable_state = client.state
		cable.refresh()


## The world stands still under the panel and settles its player once it closes.
func _tend_world() -> void:
	if (screen.process_mode == Node.PROCESS_MODE_DISABLED) != panel.is_open():
		hold_world(screen, screen.get("_audio_player"), panel.is_open())
	var world: Gen2WorldAPI = screen.get("_world")
	if world != null and not rival_name().is_empty() and world.rival_name != rival_name():
		world.rival_name = rival_name()
	_collect_evolutions()
	_tell_refused_save()
	_tell_partners()
	_tell_saves()
	if not panel.is_open() and _whiteout_due:
		_whiteout_due = false
		journal.add(PokeCoopLog.WORLD, "whiteout", {}, client.player_id)
		screen.white_out()
	elif not panel.is_open() and not _evolving.is_empty():
		journal.add(PokeCoopLog.WORLD, "evolve", {"party_indices": _evolving}, client.player_id)
		screen.evolve_after_battle(_evolving)
		_evolving = []


## A held world's audio player goes on: the battle's music and sounds play through it.
static func hold_world(world: Node, audio: Node, frozen: bool) -> void:
	world.process_mode = Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT
	if audio != null:
		audio.process_mode = Node.PROCESS_MODE_ALWAYS if frozen else Node.PROCESS_MODE_INHERIT


## A dropped link: redial as the same player until the host takes them back, waiting out `already_connected`.
func _keep_connected() -> void:
	if client.welcomes != _welcomes_seen:
		_welcomes_seen = client.welcomes
		if _reconnect_attempts > 0:
			say("Back in the session.")
		_reconnect_attempts = 0
	if not _was_ready or client.connected or _leaving_at >= 0 or _closed:
		return
	if client.ended_reason == "refused: already_connected":
		client.ended_reason = ""
	if not client.ended_reason.is_empty():
		return
	if Time.get_ticks_msec() < _reconnect_at:
		return
	_reconnect_at = Time.get_ticks_msec() + RECONNECT_MSEC
	_reconnect_attempts += 1
	if _reconnect_attempts > RECONNECT_ATTEMPTS:
		client.ended_reason = "host_unreachable"
		journal.add(PokeCoopLog.CLIENT, "unreachable", {"attempts": RECONNECT_ATTEMPTS})
		return
	say("Lost the host: reconnecting...")
	var link_again: PokeCoopEnetTransport = PokeCoopEnetTransport.dial(
		String(_greeting["address"]), int(_greeting["port"])
	)
	journal.add(PokeCoopLog.CLIENT, "redial", {"attempt": _reconnect_attempts, "ok": link_again != null})
	if link_again != null:
		client.transport = link_again
		client.greet(String(_greeting["name"]), data.id, data.sha1, client.player_id)


## The host ended the session or turned this player away: say so, then leave.
func _follow_session_end() -> void:
	if screen == null or not is_instance_valid(screen):
		return
	if _leaving_at < 0 and not client.ended_reason.is_empty():
		journal.add(PokeCoopLog.WORLD, "leaving", {"reason": client.ended_reason}, client.player_id)
		say("The session ended: %s." % client.ended_reason.replace("_", " "))
		_leaving_at = Time.get_ticks_msec() + LEAVE_MSEC
	if _leaving_at > 0 and Time.get_ticks_msec() >= _leaving_at:
		leave()


## Back to the launcher; a hosting device first tells every client the run ended.
func leave() -> void:
	journal.add(PokeCoopLog.WORLD, "leave", {}, client.player_id)
	_leaving_at = 0
	_closed = true
	if host != null and not host.ended:
		host.shutdown()
	else:
		client.share_log(true)
		client.transport.close()
	if screen != null and is_instance_valid(screen):
		screen.get_tree().change_scene_to_file.call_deferred(LAUNCHER_SCENE)
	_finish_closing()


func _finish_closing() -> void:
	if host != null and not host.ended:
		host.poll()
		return
	_release_seams()
	journal.close()
	var runtime: Gen2GameRuntime = Gen2GameRuntime.instance()
	if runtime != null and runtime.coop == self:
		runtime.coop = null


## A SAVE the host refused after all (a battle began on the way) says so over the "saved" line.
func _tell_refused_save() -> void:
	if _notice != null and _notice.visible and Time.get_ticks_msec() >= _notice_until:
		_notice.visible = false
	if link == null or link.save_seq < 0 or link.save_seq == _noticed_save:
		return
	for rejection: Dictionary in client.rejections:
		if int(rejection.get("seq", -1)) == link.save_seq:
			_noticed_save = link.save_seq
			journal.add(PokeCoopLog.WORLD, "save_refused", rejection, client.player_id)
			say("The campaign was not saved: %s." % String(rejection.get("reason", "")).replace("_", " "))


## A partner arriving, leaving, or starting a battle this player is free to join.
func _tell_partners() -> void:
	var now: Dictionary = partner_states(client)
	if not _partners_seen.is_empty():
		var line: String = partner_news(_partners_seen, now, client, data)
		if not line.is_empty():
			say(line)
	_partners_seen = now


static func partner_states(session: PokeCoopClient) -> Dictionary:
	var out: Dictionary = {}
	var everyone: Dictionary = session.state.get("players", {})
	for player_id: String in everyone:
		if player_id != session.player_id:
			var view: Dictionary = everyone[player_id]
			out[player_id] = {"name": String(view.get("name", player_id)), "connected": bool(view.get("connected", false)),
				"battle": String(view.get("battle", ""))}
	return out


static func partner_news(before: Dictionary, now: Dictionary, session: PokeCoopClient, game: GameData) -> String:
	var mine: String = String(((session.state.get("players", {}) as Dictionary).get(session.player_id, {}) as Dictionary).get("battle", ""))
	for player_id: String in now:
		var was: Dictionary = before.get(player_id, {})
		var is_now: Dictionary = now[player_id]
		if bool(is_now["connected"]) and not bool(was.get("connected", false)):
			return "%s joined the session." % is_now["name"]
		if bool(was.get("connected", false)) and not bool(is_now["connected"]):
			return "%s left the session." % is_now["name"]
		var battle: String = String(is_now["battle"])
		if not battle.is_empty() and battle != String(was.get("battle", "")) and battle != mine and mine.is_empty():
			return "%s is in a battle%s.%s" % [is_now["name"], _against(session, battle, game),
				"" if _is_private(session, battle) else " SELECT to join."]
	return ""


static func _is_private(session: PokeCoopClient, battle_id: String) -> bool:
	return (session.state.get("battles", []) as Array).any(func(running: Dictionary) -> bool:
		return String(running.get("battle", "")) == battle_id and bool(running.get("private", false)))


static func _against(session: PokeCoopClient, battle_id: String, game: GameData) -> String:
	for running: Dictionary in session.state.get("battles", []):
		if String(running.get("battle", "")) != battle_id or game == null:
			continue
		var trainer: int = int(running.get("trainer_class", 0))
		return " against %s" % (game.trainer_name(trainer) if trainer > 0 \
			else "wild %s" % String(game.species(int(running.get("enemy", 0))).get("name", "")))
	return ""


func _tell_saves() -> void:
	if client.state.is_empty():
		return
	var line: String = save_news(_saves_seen, client)
	if not line.is_empty():
		say(line)
	_saves_seen = int((client.state.get("saved", {}) as Dictionary).get("count", 0))


static func save_news(seen: int, session: PokeCoopClient) -> String:
	var saved: Dictionary = session.state.get("saved", {})
	if seen < 0 or int(saved.get("count", 0)) <= seen:
		return ""
	var by: String = String(saved.get("by", ""))
	if by == session.player_id:
		return "Campaign saved."
	var view: Dictionary = (session.state.get("players", {}) as Dictionary).get(by, {})
	return "%s saved the campaign." % String(view.get("name", by))


## A line over the world for a few seconds.
func say(text: String) -> void:
	journal.add(PokeCoopLog.WORLD, "say", {"text": text, "shown": _notice != null}, client.player_id)
	if _notice == null:
		return
	_notice.text = text
	_notice.visible = true
	_notice_until = Time.get_ticks_msec() + NOTICE_MSEC


## Evolutions and a whiteout a host battle owes this window; one the world opened itself is the world's to settle.
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


## Oak's speech first for a new player who plays the opening; it opens the world.
func open_start() -> Control:
	var opening: Dictionary = client.me().get("opening", {}) if is_ready() else {}
	if String(opening.get("stage", "")) != PokeCoopPolicy.OPENING_SPEECH or screen != null:
		return open_world()
	if opening_screen == null:
		journal.add(PokeCoopLog.WORLD, "opening_speech", {"stage": opening.get("stage", "")}, client.player_id)
		opening_screen = (load(INTRO_SCENE) as PackedScene).instantiate() as Gen2IntroScreen
		opening_screen.writes_save = false
		opening_screen.preset_names = {
			Gen2OakSpeech.NAME_PLAYER: String(client.me().get("name", "")),
			Gen2OakSpeech.NAME_RIVAL: String((client.state.get("campaign", {}) as Dictionary).get("rival_name", "")),
		}
		opening_screen.spoken.connect(_on_spoken)
		opening_screen.begin(data, 0, "", false)
	return opening_screen


func _on_spoken(_player_name: String, rival: String) -> void:
	journal.add(PokeCoopLog.WORLD, "opening_spoken", {"rival": rival}, client.player_id)
	client.send({"type": "opening", "rival": rival})
	var tree: SceneTree = opening_screen.get_tree()
	opening_screen = null
	tree.change_scene_to_node(open_world())


func rival_name() -> String:
	var mine: String = String((client.me().get("opening", {}) as Dictionary).get("rival", ""))
	var shared: String = String((client.state.get("campaign", {}) as Dictionary).get("rival_name", ""))
	var offered: Array = data.gen1_default_names(true) if data.generation == RomRegistry.GEN1 else []
	return mine if not mine.is_empty() else shared if not shared.is_empty() \
		else String(offered[1]) if offered.size() > 1 else ""


## This player's world screen, once the host has said who they are, for the caller to add.
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
	journal.add(PokeCoopLog.WORLD, "world_open", {"map": map, "cell": screen.start_cell, "party": save.party.size()}, client.player_id)
	Gen2ModHost.instance().created_save(save)
	Gen2ModHost.instance().activate_save(save)
	screen.ready.connect(_on_world_ready.bind(save), CONNECT_ONE_SHOT)
	return screen


func _on_world_ready(save: Gen2SaveData) -> void:
	var world: Gen2WorldAPI = screen.get("_world")
	if world != null:
		link = PokeCoopWorldLink.over(client, world.state, save, data)
		screen.save_gate = link.save_refusal
		cable = PokeCoopLinkTransport.over(client)
		world.state.set_link_transport(cable)
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.add_child(layer)
	panel = PokeCoopBattlePanel.over(client, data)
	panel.leave_requested.connect(leave)
	var field: PokeCoopBattleField = PokeCoopBattleField.over(panel, data)
	field.audio = screen.get("_audio_player")
	field.restore_music = Callable(screen, &"_play_current_map_music")
	panel.busy = field.is_playing
	layer.add_child(field)
	layer.add_child(panel)
	_notice = Label.new()
	_notice.add_theme_font_size_override("font_size", PokeCoopBattlePanel.FONT_SIZE + 1)
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color(0.06, 0.07, 0.12, 0.9)
	backdrop.set_content_margin_all(10)
	backdrop.set_corner_radius_all(6)
	_notice.add_theme_stylebox_override("normal", backdrop)
	_notice.position = Vector2(16, 16)
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


## Into the background, where a phone may end the app: a host saves between battles.
func suspend() -> void:
	_paused = true
	_paused_at = Time.get_ticks_msec()
	journal.add(PokeCoopLog.WORLD, "suspend", {}, client.player_id)
	if host != null and not host.ended:
		host.save_checkpoint("suspend")


## Back from a long pause, a joining device redials rather than wait out a dead link.
func resume() -> void:
	var away: int = Time.get_ticks_msec() - _paused_at if _paused else 0
	journal.add(PokeCoopLog.WORLD, "resume", {"away_msec": away}, client.player_id)
	_paused = false
	if host != null or _closed or away < RESUME_REDIAL_MSEC or not client.connected:
		return
	client.transport.close()
	client.connected = false
	_reconnect_at = 0
	_reconnect_attempts = 0


## Ends the run: the host, when this device is it, tells everyone first.
func close() -> void:
	journal.add(PokeCoopLog.WORLD, "close_session", {}, client.player_id)
	_closed = true
	if host != null:
		host.shutdown("host_shutdown", 0)
	client.share_log(true)
	client.transport.close()
	_release_seams()
	journal.close()


func _release_seams() -> void:
	if _actor != null and _actor.client == client:
		_actor.client = null
		_takeover.client = null
		Gen2SaveStore.use_root("")


static func _remembered(key: String) -> Dictionary:
	var known: Variant = JSON.parse_string(FileAccess.get_file_as_string(identity_path)) \
		if FileAccess.file_exists(identity_path) else {}
	var mine: Variant = (known as Dictionary).get(key, {}) if known is Dictionary else {}
	return mine if mine is Dictionary else {}


static func _remember(key: String, campaign_id: String, player_id: String) -> void:
	var known: Variant = JSON.parse_string(FileAccess.get_file_as_string(identity_path)) \
		if FileAccess.file_exists(identity_path) else {}
	var table: Dictionary = known if known is Dictionary else {}
	var mine: Dictionary = table.get(key, {}) if table.get(key, {}) is Dictionary else {}
	mine[campaign_id] = player_id
	table[key] = mine
	var file: FileAccess = FileAccess.open(identity_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(table, "\t"))
