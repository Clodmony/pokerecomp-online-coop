class_name PokeCoopPlayer
extends RefCounted

## One player of a co-op run: their own team, box, bag, money and position. Every
## Pokémon carries a uid that outlives its slot, which is what a battle, a reward
## and a save name it by.

const MAX_TEAM: int = Gen2Party.MAX_SIZE
const MAX_MONEY: int = 999999
const MAX_ITEM_COUNT: int = 99
const BOXES: int = 12
const BOX_CAPACITY: int = Gen2SaveBox.CAPACITY

var player_id: String = ""
var name: String = ""
var trainer_id: int = 0
var team: Array = []
## PC rows in each box's order, each `{uid, mon, box}`.
var box: Array = []
var current_box: int = 0
## Raised by the host's own team and PC changes; a window's older copy is refused.
var holdings_rev: int = 0
var box_rev: int = 0
var items: Dictionary = {}
var money: int = 0
var map: Vector2i = Vector2i(-1, -1)
var cell: Vector2i = Vector2i.ZERO
var facing: int = 0
var return_point: Dictionary = {}
var battle_id: String = ""
var connected: bool = false
var next_mon_serial: int = 1
## While the player plays the opening: its stage, the story it runs on and the rival's name.
var opening: Dictionary = {}
## The player's keys of the world state other than the bag and the wallet,
## which [member items] and [member money] hold. See [PokeCoopOwnership].
var world: Dictionary = {}


static func create(id: String, player_name: String, trainer: int) -> PokeCoopPlayer:
	var out := PokeCoopPlayer.new()
	out.player_id = id
	out.name = player_name
	out.trainer_id = trainer & 0xFFFF
	return out


func is_free() -> bool:
	return battle_id.is_empty()


func is_hidden() -> bool:
	return not opening.is_empty()


func add_mon(mon: Gen2SaveMon) -> String:
	if mon == null or team.size() >= MAX_TEAM:
		return ""
	return _file(team, mon)


## Into the current box, or the first with room, as `SendNewMonToBox` would.
func store_mon(mon: Gen2SaveMon) -> String:
	var at: int = _box_with_room()
	if mon == null or at < 0:
		return ""
	box_rev += 1
	return _file(box, mon, at)


func store_mon_at(mon: Gen2SaveMon, at_box: int) -> String:
	box_rev += 1
	return _file(box, mon, clampi(at_box, 0, BOXES - 1))


## Room for one more Pokémon, in the team or the PC: `ItemUseBall`'s full-box refusal.
func has_room() -> bool:
	return team.size() < MAX_TEAM or _box_with_room() >= 0


func _box_with_room() -> int:
	var counts: Array = _box_counts(box)
	if int(counts[current_box]) < BOX_CAPACITY:
		return current_box
	for at: int in BOXES:
		if int(counts[at]) < BOX_CAPACITY:
			return at
	return -1


func _file(into: Array, mon: Gen2SaveMon, at_box: int = -1) -> String:
	var uid: String = "%s:%d" % [player_id, next_mon_serial]
	next_mon_serial += 1
	var entry: Dictionary = {"uid": uid, "mon": mon}
	if at_box >= 0:
		entry["box"] = at_box
	into.append(entry)
	holdings_rev += 1
	return uid


static func _box_counts(rows: Array) -> Array:
	var out: Array = []
	out.resize(BOXES)
	out.fill(0)
	for entry: Dictionary in rows:
		var at: int = int(entry.get("box", 0))
		if at >= 0 and at < BOXES:
			out[at] = int(out[at]) + 1
	return out


func team_index(uid: String) -> int:
	for index: int in team.size():
		if String((team[index] as Dictionary)["uid"]) == uid:
			return index
	return -1


func mon(uid: String) -> Gen2SaveMon:
	var index: int = team_index(uid)
	return null if index < 0 else (team[index] as Dictionary)["mon"]


## A fought Pokémon written back over its own row by uid; false when the uid is not on this team.
func absorb_battle_mon(uid: String, fought: Gen2BattleMon) -> bool:
	var index: int = team_index(uid)
	if index < 0 or fought == null:
		return false
	var previous: Gen2SaveMon = (team[index] as Dictionary)["mon"]
	var saved: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(fought)
	Gen2SaveBattleAdapter.keep_party_fields(saved, previous, fought.data)
	(team[index] as Dictionary)["mon"] = saved
	holdings_rev += 1
	return true


func item_count(item: int) -> int:
	return int(items.get(item, 0))


func take_item(item: int, count: int = 1) -> bool:
	if count <= 0 or item_count(item) < count:
		return false
	items[item] = item_count(item) - count
	if item_count(item) == 0:
		items.erase(item)
	return true


func give_item(item: int, count: int = 1) -> void:
	if item > 0 and count > 0:
		items[item] = mini(item_count(item) + count, MAX_ITEM_COUNT)


## The player's half of a world state; the wallet is account 0 of `money`.
func world_part() -> Dictionary:
	var out: Dictionary = world.duplicate(true)
	out["items"] = items.duplicate()
	var accounts: Dictionary = (world.get("money", {}) as Dictionary).duplicate()
	if money > 0:
		accounts[0] = money
	else:
		accounts.erase(0)
	out["money"] = accounts
	return out


func apply_world_patch(changes: Dictionary) -> bool:
	var current: Dictionary = world_part()
	var before: Dictionary = current.duplicate(true)
	PokeCoopOwnership.apply_patch(current, changes)
	if current == before:
		return false
	items = {}
	for item: Variant in current["items"] as Dictionary:
		give_item(PokeCoopTransport.number(item), PokeCoopTransport.number((current["items"] as Dictionary)[item]))
	var accounts: Dictionary = (current["money"] as Dictionary).duplicate()
	money = clampi(PokeCoopTransport.number(accounts.get(0, 0)), 0, MAX_MONEY)
	accounts.erase(0)
	current["money"] = accounts
	current.erase("items")
	world = current
	return true


static var _mon_shape: Dictionary = {}


## A Pokémon a client sent, read only when each field has the type a save gives
## it, so a made-up one is no Pokémon rather than a broken read.
static func mon_from(raw: Variant) -> Gen2SaveMon:
	if not raw is Dictionary:
		return null
	if _mon_shape.is_empty():
		_mon_shape = Gen2SaveMon.new().to_dict()
	for key: Variant in raw:
		if not key is String or (_mon_shape.has(key) and not _fits((raw as Dictionary)[key], _mon_shape[key])):
			return null
	return Gen2SaveMon.from_dict(raw)


static func _fits(value: Variant, shape: Variant) -> bool:
	if shape is Array or shape is Dictionary:
		var entries: Array = (value as Array) if value is Array else ((value as Dictionary).values() if value is Dictionary else [])
		return typeof(value) == typeof(shape) and entries.all(func(entry: Variant) -> bool:
			return entry is int or entry is float or entry is String or entry is bool)
	return typeof(value) == typeof(shape) or (shape is int and value is float) or (shape is float and value is int)


## Who a Pokémon is, whatever happens to it: levels, moves and an evolution
## leave these alone. How a window's party row is matched to a uid.
static func fingerprint(mon: Gen2SaveMon) -> Array:
	return [
		mon.ot_id, mon.dvs, mon.original_trainer, mon.caught_level, mon.caught_location,
		mon.caught_time,
	]


## A window's party in its order, each row matched to a uid by its [param hint]
## or its fingerprint. Team members missing from it are kept in the box, so a
## deposit made in the window loses nobody; a row matching nobody is new.
func replace_team(rows: Array) -> bool:
	var pool: Array = team + box
	var used: Dictionary = {}
	var next_team: Variant = _matched(rows, pool, used)
	if rows.is_empty() or rows.size() > MAX_TEAM or next_team == null:
		return false
	var before: Array = _rows_to_dicts(box)
	box = pool.filter(func(entry: Dictionary) -> bool: return not used.has(entry["uid"]))
	team = next_team
	_settle_box()
	if _rows_to_dicts(box) != before:
		box_rev += 1
	return true


## A window's team and, unless [param stored] is null, its PC. Taken only on the
## latest [member holdings_rev]: whoever is missing was released there.
func replace_holdings(rows: Array, stored: Variant, wanted_box: int, based_on: int) -> StringName:
	if based_on != holdings_rev:
		return &"outdated"
	var pool: Array = team + (box if stored != null else [])
	var used: Dictionary = {}
	var next_team: Variant = _matched(rows, pool, used)
	var next_box: Variant = _matched(stored, pool, used) if stored is Array else box
	if rows.is_empty() or rows.size() > MAX_TEAM or next_team == null or next_box == null \
			or _box_counts(next_box).any(func(count: int) -> bool: return count > BOX_CAPACITY):
		return &"invalid_party"
	if stored != null and _rows_to_dicts(next_box) != _rows_to_dicts(box):
		box_rev += 1
	team = next_team
	box = next_box
	current_box = clampi(wanted_box, 0, BOXES - 1)
	return &""


func _matched(rows: Array, pool: Array, used: Dictionary) -> Variant:
	var prints: Array = pool.map(func(entry: Dictionary) -> Array: return fingerprint(entry["mon"]))
	var out: Array = []
	for row: Variant in rows:
		var mon: Gen2SaveMon = mon_from((row as Dictionary).get("mon")) if row is Dictionary else null
		if mon == null:
			return null
		var uid: String = _match(pool, prints, PokeCoopTransport.text((row as Dictionary).get("uid")), mon, used)
		if uid.is_empty():
			uid = "%s:%d" % [player_id, next_mon_serial]
			next_mon_serial += 1
		used[uid] = true
		var entry: Dictionary = {"uid": uid, "mon": mon}
		if (row as Dictionary).has("box"):
			entry["box"] = clampi(PokeCoopTransport.number(row["box"]), 0, BOXES - 1)
		out.append(entry)
	return out


## An unchanged row first, then the hinted one: fingerprints can collide.
static func _match(pool: Array, prints: Array, hint: String, mon: Gen2SaveMon, used: Dictionary) -> String:
	var wanted: Array = fingerprint(mon)
	var found: Array = []
	for index: int in pool.size():
		if prints[index] == wanted and not used.has(pool[index]["uid"]):
			found.append(pool[index])
	if found.size() > 1:
		var exact: Dictionary = mon.to_dict()
		var same: Array = found.filter(func(entry: Dictionary) -> bool:
			return (entry["mon"] as Gen2SaveMon).to_dict() == exact)
		found = same if not same.is_empty() else found
	for entry: Dictionary in found:
		if String(entry["uid"]) == hint:
			return hint
	return "" if found.is_empty() else String(found[0]["uid"])


func add_money(amount: int) -> void:
	money = clampi(money + amount, 0, MAX_MONEY)


func place(at_map: Vector2i, at_cell: Vector2i, toward: int) -> void:
	map = at_map
	cell = at_cell
	facing = toward


func suspend_exploration() -> void:
	return_point = {"map": map, "cell": cell, "facing": facing}


func resume_exploration() -> void:
	if return_point.is_empty():
		return
	place(return_point["map"], return_point["cell"], int(return_point["facing"]))
	return_point = {}


func public_view() -> Dictionary:
	return {
		"player_id": player_id, "name": name, "map": map, "cell": cell, "facing": facing,
		"battle": battle_id, "connected": connected,
	}


func private_view() -> Dictionary:
	var rows: Array = []
	for entry: Dictionary in team:
		var saved: Gen2SaveMon = entry["mon"]
		rows.append({
			"uid": entry["uid"], "species": saved.species, "level": saved.level,
			"hp": saved.hp, "max_hp": int(saved.stats.get("hp", saved.hp)), "status": saved.status,
			"exp": saved.exp, "is_egg": saved.is_egg,
		})
	return {
		"name": name, "trainer_id": trainer_id, "team": rows, "party": _rows_to_dicts(team),
		"box": box.size(), "items": items.duplicate(), "money": money, "world": world_part(),
		"holdings_rev": holdings_rev, "box_rev": box_rev, "current_box": current_box,
		"opening": {"stage": opening.get("stage", ""), "rival": opening.get("rival", "")} if not opening.is_empty() else {},
	}


func to_dict() -> Dictionary:
	var item_rows: Array = []
	var numbers: Array = items.keys()
	numbers.sort()
	for item: int in numbers:
		item_rows.append([item, items[item]])
	return {
		"player_id": player_id, "name": name, "trainer_id": trainer_id,
		"team": _rows_to_dicts(team), "box": _rows_to_dicts(box),
		"items": item_rows, "money": money,
		"map": [map.x, map.y], "cell": [cell.x, cell.y], "facing": facing,
		"next_mon_serial": next_mon_serial, "world": world.duplicate(true),
		"current_box": current_box, "opening": opening.duplicate(true),
	}


static func _rows_to_dicts(rows: Array) -> Array:
	var out: Array = []
	for entry: Dictionary in rows:
		var row: Dictionary = {"uid": entry["uid"], "mon": (entry["mon"] as Gen2SaveMon).to_dict()}
		if entry.has("box"):
			row["box"] = entry["box"]
		out.append(row)
	return out


func box_rows() -> Array:
	return _rows_to_dicts(box)


func team_rows() -> Array:
	return _rows_to_dicts(team)


static func from_dict(raw: Variant) -> PokeCoopPlayer:
	if not raw is Dictionary:
		return null
	var source: Dictionary = raw
	var out := PokeCoopPlayer.create(
		String(source.get("player_id", "")), String(source.get("name", "")),
		int(source.get("trainer_id", 0))
	)
	if out.player_id.is_empty():
		return null
	var team_rows: Variant = _rows_from_dicts(source.get("team", []))
	var box_rows: Variant = _rows_from_dicts(source.get("box", []))
	if team_rows == null or box_rows == null or (team_rows as Array).size() > MAX_TEAM:
		return null
	out.team = team_rows
	out.box = box_rows
	out.current_box = clampi(int(source.get("current_box", 0)), 0, BOXES - 1)
	out._settle_box()
	for row: Variant in source.get("items", []) as Array:
		if row is Array and (row as Array).size() == 2:
			out.give_item(int(row[0]), int(row[1]))
	out.money = clampi(int(source.get("money", 0)), 0, MAX_MONEY)
	out.map = _cell_from(source.get("map", []), Vector2i(-1, -1))
	out.cell = _cell_from(source.get("cell", []), Vector2i.ZERO)
	out.facing = int(source.get("facing", 0))
	out.next_mon_serial = maxi(int(source.get("next_mon_serial", 1)), 1)
	var raw_world: Variant = source.get("world", {})
	if raw_world is Dictionary:
		out.world = PokeCoopOwnership.canonical(raw_world, PokeCoopOwnership.PLAYER)
	var raw_opening: Variant = source.get("opening", {})
	if raw_opening is Dictionary and (raw_opening as Dictionary).get("world") is Dictionary:
		out.opening = {
			"stage": String(raw_opening.get("stage", PokeCoopPolicy.OPENING_PLAYING)),
			"rival": String(raw_opening.get("rival", "")),
			"world": PokeCoopOwnership.canonical(raw_opening["world"], PokeCoopOwnership.CAMPAIGN),
		}
	return out


static func _rows_from_dicts(raw: Variant) -> Variant:
	if not raw is Array:
		return null
	var out: Array = []
	for row: Variant in raw as Array:
		if not row is Dictionary:
			return null
		var saved: Gen2SaveMon = Gen2SaveMon.from_dict((row as Dictionary).get("mon", {}))
		var uid: String = String((row as Dictionary).get("uid", ""))
		if saved == null or uid.is_empty():
			return null
		var entry: Dictionary = {"uid": uid, "mon": saved}
		if (row as Dictionary).has("box"):
			entry["box"] = int(row["box"])
		out.append(entry)
	return out


## A row with no box goes to the current one; a full box spills into the next.
func _settle_box() -> void:
	var counts: Array = []
	counts.resize(BOXES)
	counts.fill(0)
	for entry: Dictionary in box:
		var at: int = clampi(int(entry.get("box", current_box)), 0, BOXES - 1)
		while at < BOXES - 1 and int(counts[at]) >= BOX_CAPACITY:
			at += 1
		entry["box"] = at
		counts[at] = int(counts[at]) + 1


static func _cell_from(raw: Variant, fallback: Vector2i) -> Vector2i:
	if raw is Array and (raw as Array).size() == 2:
		return Vector2i(int(raw[0]), int(raw[1]))
	return fallback
