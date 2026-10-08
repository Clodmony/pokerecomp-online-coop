class_name PokeCoopEnetTransport
extends PokeCoopTransport

## [PokeCoopTransport] over ENet for LAN and direct-IP play: one reliable channel of encoded Dictionaries, no relay or service.

const DEFAULT_PORT: int = 24680
const MAX_CLIENTS: int = 4
## How long a silent peer is waited for, in milliseconds, before it is let go.
const PEER_TIMEOUT_MIN: int = 2000
const PEER_TIMEOUT_MAX: int = 6000

var _peer: ENetMultiplayerPeer = null
var _live: Dictionary = {}


static func listen(port: int = DEFAULT_PORT, max_clients: int = MAX_CLIENTS) -> PokeCoopEnetTransport:
	var out := PokeCoopEnetTransport.new()
	out._peer = ENetMultiplayerPeer.new()
	if out._peer.create_server(port, max_clients) != OK:
		return null
	out._watch()
	return out


static func dial(address: String, port: int = DEFAULT_PORT) -> PokeCoopEnetTransport:
	var out := PokeCoopEnetTransport.new()
	out._peer = ENetMultiplayerPeer.new()
	if out._peer.create_client(address, port) != OK:
		return null
	out._watch()
	return out


func _watch() -> void:
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)


func _on_peer_connected(peer: int) -> void:
	_live[peer] = true
	var packet_peer: ENetPacketPeer = _peer.get_peer(peer)
	if packet_peer != null:
		packet_peer.set_timeout(0, PEER_TIMEOUT_MIN, PEER_TIMEOUT_MAX)
	_inbox.append({"kind": CONNECTED, "peer": peer})


func _on_peer_disconnected(peer: int) -> void:
	_live.erase(peer)
	_inbox.append({"kind": DISCONNECTED, "peer": peer})


func send(peer: int, message: Dictionary) -> void:
	if _peer == null or not _live.has(peer):
		return
	_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	_peer.set_target_peer(peer)
	_peer.put_packet(encode(message))


func poll() -> Array:
	if _peer != null and _peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		_peer.poll()
		while _peer != null and _peer.get_available_packet_count() > 0:
			var sender: int = _peer.get_packet_peer()
			var decoded: Variant = decode(_peer.get_packet())
			if decoded != null:
				_inbox.append({"kind": MESSAGE, "peer": sender, "message": decoded})
	return super.poll()


func drop(peer: int) -> void:
	if _peer != null:
		_peer.disconnect_peer(peer)


## Closing disconnects every peer on this end too, as the in-memory link does.
func close() -> void:
	if _peer == null:
		return
	if _peer.host != null:
		_peer.host.flush()
	_peer.close()
	_peer = null
	for peer: int in _live.keys():
		_inbox.append({"kind": DISCONNECTED, "peer": peer})
	_live.clear()
