class_name PokeCoopTrades
extends RefCounted

## Trades between players at the Cable Club: once both said TRADE the host swaps the
## two Pokémon itself, uids and all, evolving trade evolvers, so none is lost or copied.

const TRADED: String = "traded"
const CANCELED: String = "canceled"
const LINK_ROOMS: Array[Vector2i] = [Vector2i(0, Gen1Layout.TRADE_CENTER), Vector2i(0, Gen1Layout.COLOSSEUM)]

var data: GameData = null
## Every swap made, so the host can save the campaign after one.
var swaps: int = 0
var _offers: Dictionary = {}
var _rounds: Dictionary = {}
var _mates: Dictionary = {}
var _direct: Dictionary = {}
var _direct_serial: int = 0


static func create(game: GameData) -> PokeCoopTrades:
	var out := PokeCoopTrades.new()
	out.data = game
	return out


## A `trade` message: `slot` offers, `answer` (1 or 0) settles, `leave` withdraws.
func handle(sender: PokeCoopPlayer, message: Dictionary, players: Dictionary) -> StringName:
	if PokeCoopTransport.number(message.get("leave")) == 1:
		leave(sender.player_id, players)
		return &""
	if PokeCoopTransport.number(message.get("end")) == 1:
		leave(sender.player_id, players)
		unpair(sender.player_id)
		return &""
	var partner: PokeCoopPlayer = players.get(PokeCoopTransport.text(message.get("partner")), null)
	if is_direct(sender.player_id) and String(_direct[sender.player_id]["mate"]) != PokeCoopTransport.text(message.get("partner")):
		return &"invalid_trade"
	if partner == null or partner == sender:
		return &"unknown_player"
	if is_direct(partner.player_id) and String(_direct[partner.player_id]["mate"]) != sender.player_id:
		return &"invalid_trade"
	if message.has("slot"):
		var slot: int = PokeCoopTransport.number(message["slot"], -1)
		if not sender.is_free() or slot < 0 or slot >= sender.team.size():
			return &"invalid_trade"
		_offers[sender.player_id] = {"partner": partner.player_id, "slot": slot, "answer": -1}
		return &""
	var mine: Dictionary = _offers.get(sender.player_id, {})
	if mine.is_empty() or String(mine["partner"]) != partner.player_id:
		return &"no_trade"
	mine["answer"] = 1 if PokeCoopTransport.number(message.get("answer")) == 1 else 0
	_settle(sender, partner)
	return &""


func _settle(sender: PokeCoopPlayer, partner: PokeCoopPlayer) -> void:
	var mine: Dictionary = _offers[sender.player_id]
	var theirs: Dictionary = _offers.get(partner.player_id, {})
	var mutual: bool = String(theirs.get("partner", "")) == sender.player_id
	if int(mine["answer"]) == 0:
		_close([sender.player_id] + ([partner.player_id] if mutual else []), false)
	elif mutual and int(theirs["answer"]) == 0:
		_close([sender.player_id, partner.player_id], false)
	elif mutual and int(theirs["answer"]) == 1:
		var traded: bool = _swap(sender, int(mine["slot"]), partner, int(theirs["slot"]))
		_close([sender.player_id, partner.player_id], traded)


func leave(player_id: String, players: Dictionary) -> void:
	var mine: Dictionary = _offers.get(player_id, {})
	if mine.is_empty():
		return
	var partner: String = String(mine["partner"])
	var mutual: bool = String((_offers.get(partner, {}) as Dictionary).get("partner", "")) == player_id
	_close([player_id] + ([partner] if mutual and players.has(partner) else []), false)


func _close(player_ids: Array, traded: bool) -> void:
	for player_id: String in player_ids:
		_offers.erase(player_id)
		var trade_round: Dictionary = _rounds.get(player_id, {"serial": 0})
		_rounds[player_id] = {"serial": int(trade_round["serial"]) + 1, "outcome": TRADED if traded else CANCELED}


func _swap(first: PokeCoopPlayer, first_slot: int, second: PokeCoopPlayer, second_slot: int) -> bool:
	if not first.is_free() or not second.is_free() \
			or first_slot >= first.team.size() or second_slot >= second.team.size():
		return false
	var given: Dictionary = first.team.pop_at(first_slot)
	var taken: Dictionary = second.team.pop_at(second_slot)
	first.team.append({"uid": taken["uid"], "mon": _arrived(taken["mon"])})
	second.team.append({"uid": given["uid"], "mon": _arrived(given["mon"])})
	first.holdings_rev += 1
	second.holdings_rev += 1
	swaps += 1
	return true


## `TryEvolvingMon` after `.doTrade`, as [method Gen2WorldPartyHost.commit_link_trade] runs it.
func _arrived(mon: Gen2SaveMon) -> Gen2SaveMon:
	var fought: Gen2BattleMon = Gen2SaveBattleAdapter.to_battle_mon(data, mon) if not mon.is_egg else null
	if fought != null:
		var row: Dictionary = Gen2Evolution.trade_evolution(data, fought)
		if not row.is_empty():
			Gen2WorldPartyHost.apply_evolution(data, mon, row)
	return mon


func pair(first: PokeCoopPlayer, second: PokeCoopPlayer) -> void:
	unpair(first.player_id)
	unpair(second.player_id)
	_direct_serial += 1
	_direct[first.player_id] = {"mate": second.player_id, "serial": _direct_serial}
	_direct[second.player_id] = {"mate": first.player_id, "serial": _direct_serial}


func is_direct(player_id: String) -> bool:
	return _direct.has(player_id)


func unpair(player_id: String) -> void:
	var mine: Dictionary = _direct.get(player_id, {})
	_direct.erase(player_id)
	_direct.erase(String(mine.get("mate", "")))


## What [param viewer]'s window waits on: its round and the partner's offer.
func view(viewer: String) -> Dictionary:
	var mine: Dictionary = _offers.get(viewer, {})
	var theirs: Dictionary = _offers.get(String(mine.get("partner", "")), {})
	var trade_round: Dictionary = _rounds.get(viewer, {"serial": 0, "outcome": ""})
	return {
		"serial": int(trade_round["serial"]), "outcome": String(trade_round.get("outcome", "")),
		"partner_slot": int(theirs["slot"]) if String(theirs.get("partner", "")) == viewer else -1,
		"direct": (_direct.get(viewer, {}) as Dictionary).duplicate(),
	}


## An offer's partner; else the player's mate in a link room, paired in id order and kept
## while both stay; else, from outside, one alone in a room, then the first free one untaken.
func partner_for(viewer: PokeCoopPlayer, players: Dictionary) -> PokeCoopPlayer:
	var ids: Array = players.keys()
	ids.sort()
	var offered: String = _offer_partner(viewer.player_id, ids)
	if not offered.is_empty():
		return players[offered]
	if players.has(String((_direct.get(viewer.player_id, {}) as Dictionary).get("mate", ""))):
		return players[_direct[viewer.player_id]["mate"]]
	_pair_rooms(players, ids)
	if _mates.has(viewer.player_id):
		return players[_mates[viewer.player_id]]
	var first: PokeCoopPlayer = null
	for player_id: String in ids:
		var other: PokeCoopPlayer = players[player_id]
		if other == viewer or not other.connected or not other.is_free() or _mates.has(player_id) or _direct.has(player_id) \
				or not _offer_partner(player_id, ids).is_empty():
			continue
		if _in_room(other) and not _in_room(viewer):
			return other
		first = other if first == null else first
	return first


func _offer_partner(player_id: String, ids: Array) -> String:
	var mine: String = String((_offers.get(player_id, {}) as Dictionary).get("partner", ""))
	if ids.has(mine):
		return mine
	for other: String in ids:
		if String((_offers.get(other, {}) as Dictionary).get("partner", "")) == player_id:
			return other
	return ""


func _pair_rooms(players: Dictionary, ids: Array) -> void:
	for player_id: String in _mates.keys():
		var member: PokeCoopPlayer = players.get(player_id)
		var mate: PokeCoopPlayer = players.get(String(_mates[player_id]))
		if not _in_room(member) or not _in_room(mate) or member.map != mate.map:
			_mates.erase(player_id)
	var waiting: Dictionary = {}
	for player_id: String in ids:
		var member: PokeCoopPlayer = players[player_id]
		if _mates.has(player_id) or is_direct(player_id) or not _in_room(member) or not _offer_partner(player_id, ids).is_empty():
			continue
		if waiting.has(member.map):
			_mates[player_id] = waiting[member.map]
			_mates[waiting[member.map]] = player_id
			waiting.erase(member.map)
		else:
			waiting[member.map] = player_id


static func _in_room(member: PokeCoopPlayer) -> bool:
	return member != null and member.connected and member.is_free() and LINK_ROOMS.has(member.map)
