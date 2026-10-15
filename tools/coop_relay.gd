extends SceneTree

const ADDRESS: String = "127.0.0.1"
const ENET_SENT_TIME: int = 0x8000
const ENET_COMPRESSED: int = 0x4000
const ENET_NEEDS_ACK: int = 0x80
const ENET_ACKNOWLEDGE: int = 1
const ENET_FIXED_SIZES: Dictionary = {1: 8, 2: 48, 3: 44, 4: 8, 5: 4, 10: 12, 11: 16}
const ENET_LENGTH_AT: Dictionary = {6: [4, 6], 7: [6, 8], 8: [6, 24], 9: [6, 8], 12: [6, 24]}

var _listen := PacketPeerUDP.new()
var _host_port: int = 0
var _upstreams: Dictionary = {}
var _headers: Dictionary = {}
var _cuts: Array = []
var _first_packet_msec: int = -1
var _cut: bool = false
var _hold: bool = false
var _stale: Array = []
var _dropped: int = 0
var _answered: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2 or not args[0].is_valid_int() or not args[1].is_valid_int():
		push_error("usage: Godot --headless --path . -s res://tools/coop_relay.gd -- <listen port> <host port> [cuts=<second>:<seconds>[:hold],...]")
		quit(2)
		return
	_host_port = int(args[1])
	for arg: String in args.slice(2):
		if arg.begins_with("cuts="):
			for cut: String in arg.trim_prefix("cuts=").split(",", false):
				_cuts.append([float(cut.get_slice(":", 0)), float(cut.get_slice(":", 1)), cut.get_slice(":", 2) == "hold"])
	var bound: Error = _listen.bind(int(args[0]), ADDRESS)
	if bound != OK:
		push_error("coop relay: cannot listen on %s (%s)" % [args[0], error_string(bound)])
		quit(1)
		return
	print("coop relay: %s to %d, cuts %s" % [args[0], _host_port, _cuts])


func _process(_delta: float) -> bool:
	_note_cut()
	while _listen.get_available_packet_count() > 0:
		var packet: PackedByteArray = _listen.get_packet()
		var from := "%s:%d" % [_listen.get_packet_ip(), _listen.get_packet_port()]
		if _first_packet_msec < 0:
			_first_packet_msec = Time.get_ticks_msec()
			print("coop relay: first packet from %s, the cuts count from here" % from)
		if packet.size() >= 2:
			_headers[from] = _be16(packet, 0) & ~(ENET_SENT_TIME | ENET_COMPRESSED)
		if _cut and not _hold:
			_dropped += 1
		else:
			_upstream(from).put_packet(packet)
	for from: String in _upstreams:
		var upstream: PacketPeerUDP = _upstreams[from]
		while upstream.get_available_packet_count() > 0:
			var packet: PackedByteArray = upstream.get_packet()
			if _cut and (not _hold or _stale.has(from)):
				_dropped += 1
				if _hold:
					_answered += _acknowledge(from, packet)
				continue
			_listen.set_dest_address(from.get_slice(":", 0), int(from.get_slice(":", 1)))
			_listen.put_packet(packet)
	OS.delay_usec(1000)
	return false


func _upstream(from: String) -> PacketPeerUDP:
	if not _upstreams.has(from):
		var upstream := PacketPeerUDP.new()
		upstream.bind(0, ADDRESS)
		upstream.set_dest_address(ADDRESS, _host_port)
		_upstreams[from] = upstream
		print("coop relay: %s joins through port %d" % [from, upstream.get_local_port()])
	return _upstreams[from]


func _acknowledge(from: String, packet: PackedByteArray) -> int:
	if not _headers.has(from) or packet.size() < 2 or _be16(packet, 0) & ENET_COMPRESSED:
		return 0
	var sent_time: int = _be16(packet, 2) if _be16(packet, 0) & ENET_SENT_TIME else 0
	var at: int = 4 if _be16(packet, 0) & ENET_SENT_TIME else 2
	var answer := PackedByteArray([_headers[from] >> 8, _headers[from] & 0xFF])
	while at + 4 <= packet.size():
		var command: int = packet[at]
		var kind: int = command & 0x0F
		var size: int = ENET_FIXED_SIZES.get(kind, 0)
		if ENET_LENGTH_AT.has(kind) and at + ENET_LENGTH_AT[kind][0] + 2 <= packet.size():
			size = ENET_LENGTH_AT[kind][1] + _be16(packet, at + ENET_LENGTH_AT[kind][0])
		if size <= 0:
			break
		if command & ENET_NEEDS_ACK:
			answer.append_array([ENET_ACKNOWLEDGE, packet[at + 1], packet[at + 2], packet[at + 3],
				packet[at + 2], packet[at + 3], sent_time >> 8, sent_time & 0xFF])
		at += size
	if answer.size() <= 2:
		return 0
	(_upstreams[from] as PacketPeerUDP).put_packet(answer)
	return (answer.size() - 2) / 8


static func _be16(bytes: PackedByteArray, at: int) -> int:
	return (bytes[at] << 8) | bytes[at + 1] if at + 1 < bytes.size() else 0


func _note_cut() -> void:
	if _first_packet_msec < 0:
		return
	var at: float = (Time.get_ticks_msec() - _first_packet_msec) / 1000.0
	var spans: Array = _cuts.filter(func(span: Array) -> bool: return at >= span[0] and at < span[0] + span[1])
	var cut: bool = not spans.is_empty()
	if cut == _cut:
		return
	_cut = cut
	if cut:
		_dropped = 0
		_answered = 0
		_hold = bool(spans[0][2])
		_stale = _upstreams.keys()
		print("coop relay: link cut at %.1f s%s" % [at, ", the host held for %s" % ", ".join(_stale) if _hold else ""])
	else:
		print("coop relay: link back at %.1f s, %d packets dropped, %d answered" % [at, _dropped, _answered])
