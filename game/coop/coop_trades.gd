class_name PokeCoopTrades
extends RefCounted

## Trades between players at the Cable Club. Once both sides said TRADE the host
## swaps the two Pokémon itself, uids and all, evolving any that evolve by trade,
## so a trade can neither lose nor copy one. Windows wait on each player's round.

const TRADED: String = "traded"
const CANCELED: String = "canceled"

var data: GameData = null
## Every swap made, so the host can save the campaign after one.
var swaps: int = 0
var _offers: Dictionary = {}
var _rounds: Dictionary = {}


static func create(game: GameData) -> PokeCoopTrades:
	var out := PokeCoopTrades.new()
	out.data = game
	return out


## A `trade` message: `slot` offers, `answer` (1 or 0) settles, `leave` withdraws.
func handle(sender: PokeCoopPlayer, message: Dictionary, players: Dictionary) -> StringName:
	if bool(message.get("leave", false)):
		leave(sender.player_id, players)
		return &""
	var partner: PokeCoopPlayer = players.get(String(message.get("partner", "")), null)
	if partner == null or partner == sender:
		return &"unknown_player"
	if message.has("slot"):
		var slot: int = int(message["slot"])
		if not sender.is_free() or slot < 0 or slot >= sender.team.size():
			return &"invalid_trade"
		_offers[sender.player_id] = {"partner": partner.player_id, "slot": slot, "answer": -1}
		return &""
	var mine: Dictionary = _offers.get(sender.player_id, {})
	if mine.is_empty() or String(mine["partner"]) != partner.player_id:
		return &"no_trade"
	mine["answer"] = 1 if int(message.get("answer", 0)) == 1 else 0
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
		var round: Dictionary = _rounds.get(player_id, {"serial": 0})
		_rounds[player_id] = {"serial": int(round["serial"]) + 1, "outcome": TRADED if traded else CANCELED}


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


## What [param viewer]'s window waits on: its round and the partner's offer.
func view(viewer: String) -> Dictionary:
	var mine: Dictionary = _offers.get(viewer, {})
	var theirs: Dictionary = _offers.get(String(mine.get("partner", "")), {})
	var round: Dictionary = _rounds.get(viewer, {"serial": 0, "outcome": ""})
	return {
		"serial": int(round["serial"]), "outcome": String(round.get("outcome", "")),
		"partner_slot": int(theirs["slot"]) if String(theirs.get("partner", "")) == viewer else -1,
	}


## The partner of an offer either side made, else the first other free player.
func partner_for(viewer: PokeCoopPlayer, players: Dictionary) -> PokeCoopPlayer:
	var mine: String = String((_offers.get(viewer.player_id, {}) as Dictionary).get("partner", ""))
	if players.has(mine):
		return players[mine]
	var ids: Array = players.keys()
	ids.sort()
	for player_id: String in ids:
		if String((_offers.get(player_id, {}) as Dictionary).get("partner", "")) == viewer.player_id:
			return players[player_id]
	for player_id: String in ids:
		var other: PokeCoopPlayer = players[player_id]
		if other != viewer and other.connected and other.is_free():
			return other
	return null
