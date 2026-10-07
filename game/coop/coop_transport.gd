class_name PokeCoopTransport
extends RefCounted

## Dictionaries between a co-op host and its clients. This base links endpoints in memory, which is what the tests
## use; [PokeCoopEnetTransport] carries the same packets over a LAN. Peer 1 is always the host.

const CONNECTED: StringName = &"connected"
const DISCONNECTED: StringName = &"disconnected"
const MESSAGE: StringName = &"message"
const HOST_PEER: int = 1
## A full PC of 240 Pokémon is about a quarter of a megabyte on the wire.
const MAX_PACKET_BYTES: int = 2 * 1024 * 1024
const WIRE_TYPES: Array[int] = [
	TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME,
	TYPE_VECTOR2I, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_STRING_ARRAY,
]

var _inbox: Array = []
var _links: Dictionary = {}


static func link(host: PokeCoopTransport, client: PokeCoopTransport, client_peer: int) -> void:
	host._links[client_peer] = {"to": client, "as": HOST_PEER}
	client._links[HOST_PEER] = {"to": host, "as": client_peer}
	host._inbox.append({"kind": CONNECTED, "peer": client_peer})
	client._inbox.append({"kind": CONNECTED, "peer": HOST_PEER})


func send(peer: int, message: Dictionary) -> void:
	var target: Dictionary = _links.get(peer, {})
	var decoded: Variant = decode(encode(message))
	if target.is_empty() or decoded == null:
		return
	(target["to"] as PokeCoopTransport)._inbox.append(
		{"kind": MESSAGE, "peer": int(target["as"]), "message": decoded}
	)


func drop(peer: int) -> void:
	var target: Dictionary = _links.get(peer, {})
	if target.is_empty():
		return
	_links.erase(peer)
	var other: PokeCoopTransport = target["to"]
	other._links.erase(int(target["as"]))
	_inbox.append({"kind": DISCONNECTED, "peer": peer})
	other._inbox.append({"kind": DISCONNECTED, "peer": int(target["as"])})


func close() -> void:
	for peer: int in _links.keys():
		drop(peer)


func poll() -> Array:
	var out: Array = _inbox
	_inbox = []
	return out


static func encode(message: Dictionary) -> PackedByteArray:
	return var_to_bytes(wire_value(message))


## Null for anything that is not a Dictionary or arrives too large to trust.
static func decode(bytes: PackedByteArray) -> Variant:
	if bytes.is_empty() or bytes.size() > MAX_PACKET_BYTES:
		return null
	var value: Variant = bytes_to_var(bytes)
	return value if value is Dictionary else null


## A client's field read as text, whatever it sent.
static func text(value: Variant, fallback: String = "") -> String:
	return String(value) if value is String or value is StringName else fallback


## A client's field read as a whole number, whatever it sent.
static func number(value: Variant, fallback: int = 0) -> int:
	return int(value) if value is int or value is float or value is bool else fallback


## [param value] with every object and engine type dropped, so only plain data reaches the wire.
static func wire_value(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in value as Dictionary:
			out[wire_value(key)] = wire_value((value as Dictionary)[key])
		return out
	if value is Array:
		var items: Array = []
		for item: Variant in value as Array:
			items.append(wire_value(item))
		return items
	return value if WIRE_TYPES.has(typeof(value)) else null
