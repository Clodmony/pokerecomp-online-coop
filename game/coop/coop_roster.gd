class_name PokeCoopRoster
extends RefCounted

## Who owns each Pokémon on the allied side of a co-op battle, index for index with its player party; entries are only appended.

var _entries: Array = []


func add(player_id: String, uid: String) -> int:
	_entries.append({"player_id": player_id, "uid": uid})
	return _entries.size() - 1


func size() -> int:
	return _entries.size()


func owner_at(index: int) -> String:
	return String((_entries[index] as Dictionary)["player_id"]) if _has(index) else ""


func uid_at(index: int) -> String:
	return String((_entries[index] as Dictionary)["uid"]) if _has(index) else ""


func indices_of(player_id: String) -> Array[int]:
	var out: Array[int] = []
	for index: int in _entries.size():
		if owner_at(index) == player_id:
			out.append(index)
	return out


func index_of_uid(uid: String) -> int:
	for index: int in _entries.size():
		if uid_at(index) == uid:
			return index
	return -1


func _has(index: int) -> bool:
	return index >= 0 and index < _entries.size()
