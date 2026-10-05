class_name PokeCoopPlayer
extends RefCounted

## One player of a co-op run: their own team, box, bag, money and position. Every
## Pokémon carries a uid that outlives its slot, which is what a battle, a reward
## and a save name it by.

const MAX_TEAM: int = Gen2Party.MAX_SIZE
const MAX_MONEY: int = 999999
const MAX_ITEM_COUNT: int = 99

var player_id: String = ""
var name: String = ""
var trainer_id: int = 0
var team: Array = []
var box: Array = []
var items: Dictionary = {}
var money: int = 0
var map: Vector2i = Vector2i(-1, -1)
var cell: Vector2i = Vector2i.ZERO
var facing: int = 0
var return_point: Dictionary = {}
var battle_id: String = ""
var connected: bool = false
var next_mon_serial: int = 1


static func create(id: String, player_name: String, trainer: int) -> PokeCoopPlayer:
	var out := PokeCoopPlayer.new()
	out.player_id = id
	out.name = player_name
	out.trainer_id = trainer & 0xFFFF
	return out


func is_free() -> bool:
	return battle_id.is_empty()


func add_mon(mon: Gen2SaveMon) -> String:
	if mon == null or team.size() >= MAX_TEAM:
		return ""
	return _file(team, mon)


func store_mon(mon: Gen2SaveMon) -> String:
	return "" if mon == null else _file(box, mon)


func _file(into: Array, mon: Gen2SaveMon) -> String:
	var uid: String = "%s:%d" % [player_id, next_mon_serial]
	next_mon_serial += 1
	into.append({"uid": uid, "mon": mon})
	return uid


func team_index(uid: String) -> int:
	for index: int in team.size():
		if String((team[index] as Dictionary)["uid"]) == uid:
			return index
	return -1


func mon(uid: String) -> Gen2SaveMon:
	var index: int = team_index(uid)
	return null if index < 0 else (team[index] as Dictionary)["mon"]


## A fought Pokémon written back over its own row by uid; false when the uid is
## not on this team.
func absorb_battle_mon(uid: String, fought: Gen2BattleMon) -> bool:
	var index: int = team_index(uid)
	if index < 0 or fought == null:
		return false
	var previous: Gen2SaveMon = (team[index] as Dictionary)["mon"]
	var saved: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(fought)
	Gen2SaveBattleAdapter.keep_party_fields(saved, previous, fought.data)
	(team[index] as Dictionary)["mon"] = saved
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
		"box": box.size(), "items": items.duplicate(), "money": money,
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
		"next_mon_serial": next_mon_serial,
	}


static func _rows_to_dicts(rows: Array) -> Array:
	var out: Array = []
	for entry: Dictionary in rows:
		out.append({"uid": entry["uid"], "mon": (entry["mon"] as Gen2SaveMon).to_dict()})
	return out


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
	for row: Variant in source.get("items", []) as Array:
		if row is Array and (row as Array).size() == 2:
			out.give_item(int(row[0]), int(row[1]))
	out.money = clampi(int(source.get("money", 0)), 0, MAX_MONEY)
	out.map = _cell_from(source.get("map", []), Vector2i(-1, -1))
	out.cell = _cell_from(source.get("cell", []), Vector2i.ZERO)
	out.facing = int(source.get("facing", 0))
	out.next_mon_serial = maxi(int(source.get("next_mon_serial", 1)), 1)
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
		out.append({"uid": uid, "mon": saved})
	return out


static func _cell_from(raw: Variant, fallback: Vector2i) -> Vector2i:
	if raw is Array and (raw as Array).size() == 2:
		return Vector2i(int(raw[0]), int(raw[1]))
	return fallback
