class_name PokeCoopLobby
extends RefCounted

## Before a session: the LAN beacon, a dial that retries and asks first, this device's addresses and what the tab remembers.

const KIND: String = "pokerecomp-coop"
const BEACON_PORT: int = 24681
const BEACON_MSEC: int = 1000
const SEEN_MSEC: int = 4000
const RETRY_MSEC: int = 3000
const DIAL_MSEC: int = 60000
const MAX_BEACON_BYTES: int = 1400
const GAMES: Array[StringName] = [&"red", &"blue", &"red_de", &"blue_de"]
const READY: StringName = &"ready"
const STALE: StringName = &"stale"
const MISSING: StringName = &"missing"
const THIS_DEVICE: StringName = &"this"
const VPN: StringName = &"vpn"
const HOME: StringName = &"home"
const PUBLIC: StringName = &"public"
const HIDDEN_NETWORKS: Array[String] = ["lo", "docker", "br-", "veth", "virbr", "vmnet", "vboxnet", "vEthernet"]
const VPN_NETWORKS: Array[String] = ["wg", "tun", "tap", "utun", "tailscale", "zt", "ppp", "ipsec", "nordlynx", "proton"]
const MAX_RECENT: int = 4
const MONTHS: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

static var beacon_port: int = BEACON_PORT
static var memory_path: String = "user://coop_tab.json"
static var open_game: Callable = Callable()


static func build() -> String:
	return String(ProjectSettings.get_setting("application/config/version", ""))


static func title(game_id: StringName) -> String:
	var named: String = RomRegistry.title_for(game_id)
	return named if not named.is_empty() else String(game_id).to_upper()


static func short_title(game_id: StringName) -> String:
	return title(game_id).trim_suffix(" Edition")


static func cartridges(ids: Array[StringName] = GAMES) -> Array:
	var out: Array = []
	for id: StringName in ids:
		var data: GameData = open_game.call(id) if open_game.is_valid() else GameData.open(id)
		var cache: StringName = RomCache.state(RomCache.directory_for(id, RomRegistry.sha1_for(id)))
		out.append({"id": id, "title": title(id), "data": data,
			"status": READY if data != null else MISSING if cache == RomCache.STATE_MISSING else STALE})
	return out


static func partners(game_id: StringName) -> Array[StringName]:
	for pair: Array in PokeCoopPolicy.VERSION_PAIRS:
		if pair.has(game_id):
			return [StringName(pair[0]), StringName(pair[1])]
	return [game_id]


static func fitting(rows: Array, game_id: StringName, rom_sha1: String) -> Array:
	return rows.filter(func(row: Dictionary) -> bool:
		var data: GameData = row["data"]
		return data != null and PokeCoopPolicy.plays_with(data.id, data.sha1, game_id, rom_sha1))


static func place(data: GameData, map: Vector2i) -> String:
	if data == null or data.generation != RomRegistry.GEN1 or map.x < 0 or map.y < 0:
		return ""
	return data.landmark_name(data.area_landmark(map.y)).strip_edges().capitalize()


static func when(unix: int) -> String:
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var then: Dictionary = Time.get_datetime_dict_from_unix_time(unix + bias)
	var days: int = int((Time.get_unix_time_from_system() + bias) / 86400.0) - int((unix + bias) / 86400.0)
	var clock: String = "%02d:%02d" % [int(then["hour"]), int(then["minute"])]
	if days <= 0:
		return "today " + clock
	if days == 1:
		return "yesterday " + clock
	return "%d %s %s" % [int(then["day"]), MONTHS[clampi(int(then["month"]) - 1, 0, 11)], clock]


static func local_addresses() -> Array:
	var out: Array = []
	for network: Dictionary in IP.get_local_interfaces():
		var named: String = String(network.get("friendly", network.get("name", "")))
		var system: String = String(network.get("name", ""))
		if HIDDEN_NETWORKS.any(func(prefix: String) -> bool: return system.begins_with(prefix) or named.begins_with(prefix)):
			continue
		var tunnel: bool = VPN_NETWORKS.any(func(prefix: String) -> bool:
			return system.to_lower().begins_with(prefix) or named.to_lower().begins_with(prefix))
		for address: String in network.get("addresses", []):
			if address.count(".") == 3 and not address.begins_with("127.") and not address.begins_with("169.254."):
				out.append({"address": address, "network": named, "kind": VPN if tunnel else _kind_of(address)})
	out.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return int(first["kind"] == VPN) > int(second["kind"] == VPN))
	return out


static func used_by(rows: Array, members: Array) -> Dictionary:
	var out: Dictionary = {}
	var earlier: Dictionary = remembered().get("used", {}) if remembered().get("used", {}) is Dictionary else {}
	for row: Dictionary in rows:
		var address: String = row["address"]
		for member: PokeCoopPlayer in members:
			if member.via == address:
				out[address] = member.name
		if not out.has(address) and earlier.has(address):
			out[address] = String(earlier[address])
	return out


static func note_used(rows: Array, members: Array) -> void:
	var used: Dictionary = used_by(rows, members)
	var earlier: Variant = remembered().get("used", {})
	if earlier is Dictionary and not used.is_empty() and (earlier as Dictionary).merged(used, true) != earlier:
		remember({"used": (earlier as Dictionary).merged(used, true)})


static func best_address(rows: Array, members: Array) -> String:
	var used: Dictionary = used_by(rows, members)
	for row: Dictionary in rows:
		if used.has(row["address"]):
			return row["address"]
	return String(rows[0]["address"]) if not rows.is_empty() else ""


static func _kind_of(address: String) -> StringName:
	var parts: PackedInt32Array = PackedInt32Array(Array(address.split(".")).map(func(part: String) -> int: return part.to_int()))
	if parts.size() != 4:
		return PUBLIC
	if parts[0] == 127:
		return THIS_DEVICE
	if parts[0] == 100 and parts[1] >= 64 and parts[1] < 128:
		return VPN
	if parts[0] == 10 or (parts[0] == 172 and parts[1] >= 16 and parts[1] < 32) or (parts[0] == 192 and parts[1] == 168):
		return HOME
	return PUBLIC


static func _prefix(address: String) -> String:
	return address.substr(0, address.rfind("."))


static func address_kind(address: String, mine: Array = local_addresses()) -> StringName:
	for row: Dictionary in mine:
		if _prefix(String(row["address"])) == _prefix(address):
			return StringName(row["kind"])
	var kind: StringName = _kind_of(address)
	return VPN if kind == HOME and address.begins_with("10.") and mine.any(func(row: Dictionary) -> bool: return row["kind"] == VPN) \
		else kind


static func advice(address: String, port: int, host_name: String, mine: Array = local_addresses()) -> PackedStringArray:
	var who: String = host_name if not host_name.is_empty() else "The host"
	var out := PackedStringArray(["%s has pressed Host and sees the Hosting screen" % who])
	match address_kind(address, mine):
		THIS_DEVICE:
			out.append("This device hosts it: Host on the other window first")
		VPN:
			out.append("You are both on the VPN: %s only works through it" % address)
		HOME:
			var here: Array = mine.filter(func(row: Dictionary) -> bool: return row["kind"] == HOME)
			out.append("You are both on the same Wi-Fi or network%s" % (
				" (this device is on %s.x)" % _prefix(String(here[0]["address"])) if not here.is_empty() else ""))
		PUBLIC:
			out.append("The host forwards UDP port %d on the router to their device" % port)
	out.append("Windows: allow pokerecomp when the firewall asks, on the host")
	if not address_kind(address, mine) in [PUBLIC, THIS_DEVICE]:
		out.append("Not on the same network? A shared VPN (WireGuard, Tailscale) avoids router setup")
	return out


static func remembered() -> Dictionary:
	var known: Variant = JSON.parse_string(FileAccess.get_file_as_string(memory_path)) \
		if FileAccess.file_exists(memory_path) else {}
	return known if known is Dictionary else {}


static func remember(changes: Dictionary) -> void:
	var kept: Dictionary = remembered()
	kept.merge(changes, true)
	var file: FileAccess = FileAccess.open(memory_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(kept, "\t"))


static func add_recent(entry: Dictionary) -> void:
	var key: String = "%s:%d" % [entry.get("address", ""), int(entry.get("port", 0))]
	var recent: Array = (remembered().get("recent", []) as Array).filter(func(row: Variant) -> bool:
		return row is Dictionary and "%s:%d" % [row.get("address", ""), int(row.get("port", 0))] != key)
	recent.push_front(entry)
	remember({"recent": recent.slice(0, MAX_RECENT)})


static func recent() -> Array:
	return (remembered().get("recent", []) as Array).filter(func(row: Variant) -> bool:
		return row is Dictionary and not String(row.get("address", "")).is_empty())


static func split_address(typed: String, port: int) -> Array:
	var text: String = typed.strip_edges()
	if text.count(":") == 1 and text.get_slice(":", 1).is_valid_int():
		return [text.get_slice(":", 0), clampi(text.get_slice(":", 1).to_int(), 1, 65535)]
	return [text, port]


static func beacon_bytes(view: Dictionary, port: int) -> PackedByteArray:
	var sent: Dictionary = view.duplicate(true)
	sent["port"] = port
	sent["players"] = (sent.get("players", []) as Array).slice(0, PokeCoopEnetTransport.MAX_CLIENTS)
	return JSON.stringify(sent).to_utf8_buffer()


static func read_beacon(bytes: PackedByteArray, from: String) -> Dictionary:
	if bytes.size() > MAX_BEACON_BYTES:
		return {}
	var json := JSON.new()
	var raw: Variant = json.data if json.parse(bytes.get_string_from_utf8()) == OK else null
	if not raw is Dictionary or (raw as Dictionary).get("kind") != KIND:
		return {}
	var port: int = PokeCoopTransport.number(raw.get("port"), 0)
	var members: Array = []
	for member: Variant in raw.get("players") if raw.get("players") is Array else []:
		if member is Dictionary:
			members.append({"name": PokeCoopTransport.text(member.get("name")).left(16),
				"game": PokeCoopTransport.text(member.get("game")), "connected": member.get("connected") == true})
	if port <= 0 or port > 65535 or from.is_empty():
		return {}
	return {
		"address": from, "port": port, "protocol": PokeCoopTransport.number(raw.get("protocol"), -1),
		"build": PokeCoopTransport.text(raw.get("build")), "game_id": PokeCoopTransport.text(raw.get("game_id")),
		"rom_sha1": PokeCoopTransport.text(raw.get("rom_sha1")), "campaign": PokeCoopTransport.text(raw.get("campaign")),
		"title": PokeCoopTransport.text(raw.get("title")).left(32), "host": PokeCoopTransport.text(raw.get("host")).left(16),
		"players": members, "badges": PokeCoopTransport.number(raw.get("badges")),
		"place": PokeCoopTransport.text(raw.get("place")).left(32),
	}


static func beacon_targets() -> PackedStringArray:
	var out := PackedStringArray(["255.255.255.255", "127.0.0.1"])
	for row: Dictionary in local_addresses():
		out.append(_prefix(String(row["address"])) + ".255")
	return out


## A hosting device's beacon, once a second; failures are silent, so a platform without broadcast still hosts.
class Beacon extends RefCounted:
	var _udp: PacketPeerUDP = null
	var _sent_at: int = -BEACON_MSEC
	var _targets: PackedStringArray = []

	func tick(view: Dictionary, port: int, now: int = Time.get_ticks_msec()) -> void:
		if now - _sent_at < BEACON_MSEC:
			return
		_sent_at = now
		if _udp == null:
			_udp = PacketPeerUDP.new()
			_udp.set_broadcast_enabled(true)
			_targets = PokeCoopLobby.beacon_targets()
		var bytes: PackedByteArray = PokeCoopLobby.beacon_bytes(view, port)
		for target: String in _targets:
			_udp.set_dest_address(target, PokeCoopLobby.beacon_port)
			_udp.put_packet(bytes)

	func close() -> void:
		if _udp != null:
			_udp.close()
		_udp = null


## The hosts whose beacon arrived lately. A second listener on the device finds the port taken and tries again later.
class Listener extends RefCounted:
	var _udp: PacketPeerUDP = null
	var _tried_at: int = -RETRY_MSEC
	var _seen: Dictionary = {}

	func listening() -> bool:
		return _udp != null

	func poll(now: int = Time.get_ticks_msec()) -> void:
		if _udp == null and now - _tried_at >= PokeCoopLobby.RETRY_MSEC:
			_tried_at = now
			_udp = PacketPeerUDP.new()
			if _udp.bind(PokeCoopLobby.beacon_port) != OK:
				_udp = null
		while _udp != null and _udp.get_available_packet_count() > 0:
			var bytes: PackedByteArray = _udp.get_packet()
			hear(PokeCoopLobby.read_beacon(bytes, _udp.get_packet_ip()), now)

	func hear(row: Dictionary, now: int = Time.get_ticks_msec()) -> void:
		if row.is_empty():
			return
		var key: String = "%s/%d" % [row["campaign"], int(row["port"])]
		var kept: Dictionary = _seen.get(key, {})
		if not kept.is_empty() and String(row["address"]).begins_with("127.") and now - int(kept["at"]) < PokeCoopLobby.SEEN_MSEC:
			row["address"] = (kept["row"] as Dictionary)["address"]
		_seen[key] = {"row": row, "at": now}

	func hosts(now: int = Time.get_ticks_msec()) -> Array:
		var out: Array = []
		for key: String in _seen.keys():
			if now - int(_seen[key]["at"]) > PokeCoopLobby.SEEN_MSEC:
				_seen.erase(key)
			else:
				out.append(_seen[key]["row"])
		out.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
			return "%s %s" % [first["host"], first["title"]] < "%s %s" % [second["host"], second["title"]])
		return out

	func close() -> void:
		if _udp != null:
			_udp.close()
		_udp = null
		_tried_at = -PokeCoopLobby.RETRY_MSEC


## Dials again every few seconds for a minute: a partner often presses Join before the host is up.
class Dial extends RefCounted:
	enum Step { DIALING, ANSWERED, REFUSED, GAVE_UP, CLOSED }

	var address: String = ""
	var port: int = PokeCoopEnetTransport.DEFAULT_PORT
	var data: GameData = null
	var player_name: String = ""
	var known: Dictionary = {}
	var step: Step = Step.DIALING
	var reason: String = ""
	var client: PokeCoopClient = null
	var attempts: int = 0
	var started_at: int = 0
	var _dialled_at: int = 0

	static func to(where: String, at_port: int, game: GameData, name: String, identity: Dictionary = {}) -> Dial:
		var out := Dial.new()
		out.address = where
		out.port = at_port
		out.data = game
		out.player_name = name
		out.known = identity
		out.started_at = Time.get_ticks_msec()
		out._redial(out.started_at)
		return out

	func answer() -> Dictionary:
		return client.probed if client != null else {}

	func connected() -> bool:
		return client != null and client.connected

	func seconds_left(now: int = Time.get_ticks_msec()) -> int:
		return maxi(0, ceili((PokeCoopLobby.DIAL_MSEC - (now - started_at)) / 1000.0))

	func process(now: int = Time.get_ticks_msec()) -> void:
		if step in [Step.REFUSED, Step.GAVE_UP, Step.CLOSED] or client == null:
			return
		client.poll()
		if step == Step.ANSWERED:
			return
		if not client.probed.is_empty():
			reason = String(client.probed.get("refused", ""))
			step = Step.ANSWERED if reason.is_empty() else Step.REFUSED
		elif not client.ended_reason.is_empty():
			reason = "older_host" if client.ended_reason == "refused: hello_first" else client.ended_reason.trim_prefix("refused: ")
			step = Step.REFUSED
		elif not client.connected and now - _dialled_at >= PokeCoopLobby.RETRY_MSEC:
			if now - started_at >= PokeCoopLobby.DIAL_MSEC:
				step = Step.GAVE_UP
				_drop()
			else:
				_redial(now)

	func retry_now(now: int = Time.get_ticks_msec()) -> void:
		started_at = now
		step = Step.DIALING
		reason = ""
		_redial(now)

	func close() -> void:
		step = Step.CLOSED
		_drop()

	func take() -> PokeCoopClient:
		var out: PokeCoopClient = client if connected() else null
		client = null if out != null else client
		close()
		return out

	func _redial(now: int) -> void:
		_drop()
		_dialled_at = now
		attempts += 1
		var link: PokeCoopEnetTransport = PokeCoopEnetTransport.dial(address, port)
		if link == null:
			step = Step.REFUSED
			reason = "bad_address"
			return
		client = PokeCoopClient.over(link)
		client.probe(player_name, data.id, data.sha1, known)

	func _drop() -> void:
		if client != null:
			client.transport.close()
		client = null


class SplitScreen extends RefCounted:
	const ARG: String = "coop-split="
	const NO_PAD: Dictionary = {"guid": "keyboard", "name": "Keyboard", "serial": "", "nth": 0}
	const MEMORY: String = "user://coop_tab_split.json"
	const QUIT_BOTH: int = 3

	static var partner_pid: int = 0
	static var quit_both: bool = false
	static var asked: Dictionary = {}
	static var tool_args: PackedStringArray = []
	static var _read: bool = false
	static var _before: Dictionary = {}

	static func available() -> bool:
		return OS.has_feature("pc") and DisplayServer.get_name() != "headless" and partner_pid == 0 and asked.is_empty()

	static func halves(pick: Dictionary, connected: Array) -> Array:
		if connected.is_empty():
			return [{}, {}]
		return [pick if not pick.is_empty() and PokePadChoice.device_for(pick, connected) != PokePadChoice.AWAY else null, null]

	static func choosing(event: InputEvent) -> bool:
		var key := event as InputEventKey
		var button := event as InputEventJoypadButton
		return event.is_pressed() and not event.is_echo() and (button != null and button.button_index == JOY_BUTTON_A
			or key != null and (key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode) in [KEY_ENTER, KEY_KP_ENTER])

	static func pressed(chosen: Array, event: InputEvent, connected: Array) -> Array:
		var button := event as InputEventJoypadButton
		var pad: Dictionary = NO_PAD if choosing(event) and event is InputEventKey else {}
		for row: Dictionary in connected if button != null and choosing(event) else []:
			pad = PokePadChoice.sanitize(row) if int(row["device"]) == button.device else pad
		var taken: bool = chosen.any(func(half: Variant) -> bool: return half != null and (half == pad
			or button != null and PokePadChoice.device_for(half, connected) == button.device))
		if pad.is_empty() or taken or not chosen.has(null):
			return chosen
		var out: Array = chosen.duplicate()
		out[out.find(null)] = pad
		return out

	static func half(area: Rect2i, side: int) -> Rect2i:
		var left: int = area.size.x / 2
		return Rect2i(area.position + Vector2i(left * side, 0), Vector2i(left if side == 0 else area.size.x - left, area.size.y))

	static func argument(port: int, game: StringName, pad: Dictionary, screen: int) -> String:
		return ARG + Marshalls.utf8_to_base64(JSON.stringify({"port": port, "game": String(game), "pad": pad, "screen": screen}))

	static func read(args: PackedStringArray) -> Dictionary:
		for arg: String in args:
			var parsed: Variant = JSON.parse_string(Marshalls.base64_to_utf8(arg.trim_prefix(ARG))) if arg.begins_with(ARG) else null
			if parsed is Dictionary and int((parsed as Dictionary).get("port", 0)) > 0:
				return {"port": clampi(int(parsed["port"]), 1, 65535), "game": StringName(String(parsed.get("game", ""))),
					"pad": PokePadChoice.sanitize(parsed.get("pad", {})), "screen": int(parsed.get("screen", 0))}
		return {}

	static func asked_once() -> Dictionary:
		if not _read:
			_read = true
			asked = read(OS.get_cmdline_user_args())
		return asked

	static func start(port: int, game: StringName, halves: Array) -> bool:
		var screen: int = DisplayServer.window_get_current_screen()
		var args: PackedStringArray = [] if OS.has_feature("template") else ["--path", ProjectSettings.globalize_path("res://")]
		args.append_array(tool_args)
		if not args.has("--"):
			args.append("--")
		args.append(argument(port, game, halves[1], screen))
		partner_pid = maxi(OS.create_process(OS.get_executable_path(), args), 0)
		if partner_pid > 0:
			take(0, halves[0], screen)
		return partner_pid > 0

	static func take(side: int, pad: Dictionary, screen: int) -> void:
		if _before.is_empty():
			_before = {"mode": DisplayServer.window_get_mode(), "borderless": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS),
				"on_top": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP),
				"rect": Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size()),
				"ignore": Input.ignore_joypad_on_unfocused_application}
		var whole := Rect2i(DisplayServer.screen_get_position(screen), DisplayServer.screen_get_size(screen))
		var rect: Rect2i = half(whole, side)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
		DisplayServer.window_set_position(rect.position)
		DisplayServer.window_set_size(rect.size)
		Input.ignore_joypad_on_unfocused_application = false
		PokePadChoice.held = pad
		PokePadChoice.apply()
		print("coop split: %s half at %s of screen %s, controller %s" % ["left" if side == 0 else "right", rect, whole, pad.get("name", "every")])

	static func active() -> bool:
		return partner_pid > 0 or not asked.is_empty()

	static func exit_code() -> int:
		return QUIT_BOTH if quit_both and not asked.is_empty() else 0

	static func watch() -> void:
		if partner_pid > 0 and not OS.is_process_running(partner_pid):
			quit_both = quit_both or OS.get_process_exit_code(partner_pid) == QUIT_BOTH
			end()

	static func end() -> void:
		partner_pid = 0
		if _before.is_empty():
			return
		var rect: Rect2i = _before["rect"]
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, bool(_before["borderless"]))
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, bool(_before["on_top"]))
		DisplayServer.window_set_position(rect.position)
		DisplayServer.window_set_size(rect.size)
		DisplayServer.window_set_mode(_before["mode"])
		Input.ignore_joypad_on_unfocused_application = bool(_before["ignore"])
		_before = {}
		PokePadChoice.held = {}
		PokePadChoice.apply()
		print("coop split: the window has the whole screen again")
