class_name PokeCoopClient
extends RefCounted

## A player's end of a co-op session: sends intentions with a sequence number and
## keeps the last authoritative state and battle views it was sent. It decides
## nothing; a local menu cursor stays here until it is sent as a suggestion.

var transport: PokeCoopTransport = null
var player_id: String = ""
var connected: bool = false
var state: Dictionary = {}
var battles: Dictionary = {}
var rejections: Array = []
var ended_reason: String = ""
var _seq: int = 0
var _greeting: Dictionary = {}


static func over(link: PokeCoopTransport) -> PokeCoopClient:
	var out := PokeCoopClient.new()
	out.transport = link
	return out


## Sent as soon as the transport is connected; [param id] reclaims a player.
func greet(player_name: String, game_id: StringName, rom_sha1: String, id: String = "") -> void:
	_greeting = {
		"type": "hello", "protocol": PokeCoopHost.PROTOCOL, "name": player_name,
		"game_id": String(game_id), "rom_sha1": rom_sha1, "player_id": id,
	}
	if connected:
		transport.send(PokeCoopTransport.HOST_PEER, _greeting)


func poll() -> void:
	for event: Dictionary in transport.poll():
		var kind: StringName = StringName(event["kind"])
		if kind == PokeCoopTransport.CONNECTED:
			connected = true
			if not _greeting.is_empty():
				transport.send(PokeCoopTransport.HOST_PEER, _greeting)
		elif kind == PokeCoopTransport.DISCONNECTED:
			connected = false
		elif kind == PokeCoopTransport.MESSAGE:
			_receive(event["message"])


func _receive(message: Dictionary) -> void:
	match String(message.get("type", "")):
		"welcome":
			player_id = String(message.get("player_id", ""))
			_seq = maxi(_seq, int(message.get("last_seq", 0)))
		"state":
			state = message
		"battle":
			var view: Dictionary = message.get("view", {})
			battles[String(view.get("battle", ""))] = view
		"rejected":
			rejections.append(message)
		"ended":
			ended_reason = String(message.get("reason", "ended"))
			connected = false
			transport.close()


func step(map: Vector2i, cell: Vector2i, facing: int) -> int:
	return send({"type": "move", "map": map, "cell": cell, "facing": facing})


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


func request_save() -> int:
	return send({"type": "save"})


func send(message: Dictionary) -> int:
	_seq += 1
	var numbered: Dictionary = message.duplicate()
	numbered["seq"] = _seq
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
