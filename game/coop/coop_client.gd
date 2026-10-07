class_name PokeCoopClient
extends RefCounted

## A player's end of a co-op session, deciding nothing: numbered intentions out, the authoritative state and battle views in.

## ENet drops data that arrives with a disconnect, so the last log batch is given a moment.
const LAST_LOG_MSEC: int = 500

var transport: PokeCoopTransport = null
var player_id: String = ""
var connected: bool = false
var state: Dictionary = {}
var battles: Dictionary = {}
var box: Dictionary = {}
var rejections: Array = []
var ended_reason: String = ""
## How many times the host has welcomed this player, a reconnection included.
var welcomes: int = 0
var _seq: int = 0
var _greeting: Dictionary = {}
## Battles a view arrived for in this poll: a later revision there adds its events.
var _fresh: Dictionary = {}
var campaign_id: String = ""
var state_at: int = 0
var journal: PokeCoopLog = PokeCoopLog.new()
## Off for a hosting device's own client: the host sends that device's lines itself.
var streams_log: bool = true
var _streamed_at: int = 0
var _welcomed: bool = false
var _close_at: int = -1


static func over(link: PokeCoopTransport) -> PokeCoopClient:
	var out := PokeCoopClient.new()
	out.transport = link
	return out


## Sent once connected; [param id] reclaims a player, a new one brings [param starter] or the save [param brought].
func greet(
	player_name: String, game_id: StringName, rom_sha1: String, id: String = "", starter: int = 0,
	brought: Dictionary = {}, known: Dictionary = {}
) -> void:
	_greeting = {
		"type": "hello", "protocol": PokeCoopHost.PROTOCOL, "name": player_name,
		"game_id": String(game_id), "rom_sha1": rom_sha1, "player_id": id, "starter": starter,
		"known": known, "logs": {"device": journal.device, "share": journal.share},
	}
	if not brought.is_empty():
		_greeting["save"] = brought
	elif starter == PokeCoopPolicy.PLAY_OPENING:
		_greeting["opening"] = true
	if connected:
		_say_hello()


func _say_hello() -> void:
	journal.add(PokeCoopLog.CLIENT, "hello", _greeting, player_id)
	transport.send(PokeCoopTransport.HOST_PEER, _greeting)


func poll() -> void:
	_fresh.clear()
	for event: Dictionary in transport.poll():
		var kind: StringName = StringName(event["kind"])
		if kind == PokeCoopTransport.MESSAGE:
			_receive(event["message"])
			continue
		connected = kind == PokeCoopTransport.CONNECTED
		_welcomed = false
		journal.add(PokeCoopLog.CLIENT, String(kind), {}, player_id)
		if connected and not _greeting.is_empty():
			_say_hello()
	share_log()
	journal.poll()
	if _close_at >= 0 and Time.get_ticks_msec() >= _close_at:
		_close_at = -1
		transport.close()


## [param now] sends what is left at once, as before leaving; true when there was something.
func share_log(now: bool = false) -> bool:
	if not journal.share or not streams_log or not _welcomed or (not now and Time.get_ticks_msec() - _streamed_at < journal.stream_msec):
		return false
	_streamed_at = Time.get_ticks_msec()
	var lines: Array = journal.take_stream()
	if not lines.is_empty():
		transport.send(PokeCoopTransport.HOST_PEER, {"type": "log", "lines": lines})
	return not lines.is_empty()


func _receive(message: Dictionary) -> void:
	match String(message.get("type", "")):
		"welcome":
			welcomes += 1
			_welcomed = true
			player_id = String(message.get("player_id", ""))
			campaign_id = PokeCoopTransport.text(message.get("campaign"))
			_seq = maxi(_seq, int(message.get("last_seq", 0)))
			journal.add(PokeCoopLog.CLIENT, "welcome", message, player_id)
			journal.want_full_state()
		"state":
			state = message
			state_at = Time.get_ticks_msec()
			journal.log_state(message, player_id)
		"box":
			box = {"rev": int(message.get("rev", 0)), "rows": message.get("rows", [])}
			journal.add(PokeCoopLog.CLIENT, "box", {"rev": box["rev"], "rows": (box["rows"] as Array).size()}, player_id)
		"log":
			journal.take_relayed(message.get("lines"), "host", "", journal.share)
		"battle":
			var view: Dictionary = message.get("view", {})
			var id: String = String(view.get("battle", ""))
			var earlier: Dictionary = battles.get(id, {})
			if _fresh.has(id) and int(view.get("revision", 0)) > int(earlier.get("revision", 0)):
				view["events"] = (earlier.get("events", []) as Array) + (view.get("events", []) as Array)
			_fresh[id] = true
			battles[id] = view
			journal.log_view(view, player_id)
		"rejected":
			rejections.append(message)
			journal.add(PokeCoopLog.CLIENT, "rejected", message, player_id)
			if int(message.get("seq", 0)) == -1:
				ended_reason = "refused: %s" % message.get("reason", "")
				connected = false
				transport.close()
		"ended":
			ended_reason = String(message.get("reason", "ended"))
			journal.add(PokeCoopLog.CLIENT, "ended", {"reason": ended_reason}, player_id)
			connected = false
			if share_log(true):
				_close_at = Time.get_ticks_msec() + LAST_LOG_MSEC
			else:
				transport.close()


func step(map: Vector2i, cell: Vector2i, facing: int, warp: bool = false, places: Dictionary = {}) -> int:
	var message: Dictionary = {"type": "move", "map": map, "cell": cell, "facing": facing, "warp": warp}
	if not places.is_empty():
		message["places"] = places
	return send(message)


func start_battle(encounter_id: String) -> int:
	return send({"type": "start_battle", "encounter": encounter_id})


## [param command] at the battle's last known revision unless it names one.
func act(battle_id: String, command: Dictionary) -> int:
	var sent: Dictionary = command.duplicate()
	if not sent.has("revision"):
		sent["revision"] = int(battle(battle_id).get("revision", -1))
	return send({"type": "command", "battle": battle_id, "command": sent})


func suggest(battle_id: String, kind: String, value: int) -> int:
	return send({"type": "suggest", "battle": battle_id, "suggestion": {"type": kind, "value": value}})


func join_battle(battle_id: String) -> int:
	return send({"type": "join", "battle": battle_id})


func leave_battle(battle_id: String) -> int:
	return send({"type": "leave_battle", "battle": battle_id})


func stand_in(battle_id: String) -> int:
	return send({"type": "stand_in", "battle": battle_id})


func request_save() -> int:
	return send({"type": "save"})


func send(message: Dictionary) -> int:
	_seq += 1
	var numbered: Dictionary = message.duplicate()
	numbered["seq"] = _seq
	journal.add(PokeCoopLog.CLIENT, "out", numbered, player_id)
	transport.send(PokeCoopTransport.HOST_PEER, numbered)
	return _seq


func battle(battle_id: String) -> Dictionary:
	return battles.get(battle_id, {})


## The battle this player is in or waiting to join, or empty.
func current_battle() -> Dictionary:
	for battle_id: String in battles:
		var view: Dictionary = battles[battle_id]
		var mine: bool = (view.get("participants", []) as Array).has(player_id) \
			or (view.get("pending", []) as Array).has(player_id)
		if mine and String(view.get("outcome", "")).is_empty():
			return view
	return {}


func is_controller(battle_id: String) -> bool:
	return String(battle(battle_id).get("controller", "")) == player_id


func me() -> Dictionary:
	return state.get("you", {})


func nearby() -> Array:
	return state.get("nearby", [])


func last_rejection() -> StringName:
	return &"" if rejections.is_empty() else StringName((rejections[-1] as Dictionary).get("reason", ""))
