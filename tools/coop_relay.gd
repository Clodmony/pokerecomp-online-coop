extends SceneTree

const ADDRESS: String = "127.0.0.1"

var _listen := PacketPeerUDP.new()
var _host_port: int = 0
var _upstreams: Dictionary = {}
var _cuts: Array[Vector2] = []
var _first_packet_msec: int = -1
var _cut: bool = false
var _dropped: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2 or not args[0].is_valid_int() or not args[1].is_valid_int():
		push_error("usage: Godot --headless --path . -s res://tools/coop_relay.gd -- <listen port> <host port> [cuts=<second>:<seconds>,...]")
		quit(2)
		return
	_host_port = int(args[1])
	for arg: String in args.slice(2):
		if arg.begins_with("cuts="):
			for cut: String in arg.trim_prefix("cuts=").split(",", false):
				_cuts.append(Vector2(float(cut.get_slice(":", 0)), float(cut.get_slice(":", 1))))
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
		if _cut:
			_dropped += 1
		else:
			_upstream(from).put_packet(packet)
	for from: String in _upstreams:
		var upstream: PacketPeerUDP = _upstreams[from]
		while upstream.get_available_packet_count() > 0:
			var packet: PackedByteArray = upstream.get_packet()
			if _cut:
				_dropped += 1
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


func _note_cut() -> void:
	if _first_packet_msec < 0:
		return
	var at: float = (Time.get_ticks_msec() - _first_packet_msec) / 1000.0
	var cut: bool = _cuts.any(func(span: Vector2) -> bool: return at >= span.x and at < span.x + span.y)
	if cut == _cut:
		return
	_cut = cut
	if cut:
		_dropped = 0
		print("coop relay: link cut at %.1f s" % at)
	else:
		print("coop relay: link back at %.1f s, %d packets dropped" % [at, _dropped])
