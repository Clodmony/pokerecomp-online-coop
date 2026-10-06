class_name PokeCoopLinkTransport
extends Gen2LinkTransport

## The Cable Club's cable to the partner the host names, with their party as the
## host holds it; offers and answers go to the host, which swaps ([PokeCoopTrades]).

var client: PokeCoopClient = null
var _offered: bool = false
var _offer_serial: int = -1


static func over(session: PokeCoopClient) -> PokeCoopLinkTransport:
	var out := PokeCoopLinkTransport.new()
	out.client = session
	return out


## The partner's side as the host last sent it, or no cable without one.
func refresh() -> void:
	var partner: Dictionary = client.me().get("trade_partner", {})
	if partner.is_empty():
		peer = {}
		return
	## Not a save slot's catch rate in the item byte, which the arriving save refuses.
	var party: Array = (partner.get("party", []) as Array).map(
		func(row: Dictionary) -> Dictionary: return (row["mon"] as Dictionary).duplicate(true))
	peer = {
		"name": String(partner.get("name", "")), "id": int(partner.get("trainer_id", 0)),
		"generation": GENERATION_1, "party": party,
		"player_id": String(partner.get("player_id", "")),
	}


func _round() -> Dictionary:
	return client.me().get("trade", {})


func choose_trade_slot(context: Dictionary) -> int:
	if not connected():
		return -1
	if not _offered:
		_offered = true
		_offer_serial = int(_round().get("serial", 0))
		client.send({"type": "trade", "partner": peer["player_id"], "slot": int(context.get("slot", 0))})
		return PENDING
	if int(_round().get("serial", 0)) > _offer_serial:
		_offered = false
		return -1
	var slot: int = int(_round().get("partner_slot", -1))
	return slot if slot >= 0 else PENDING


func answer_trade(accepted: bool) -> void:
	if _offered and connected():
		client.send({"type": "trade", "partner": peer["player_id"], "answer": 1 if accepted else 0})
	_offered = _offered and accepted


func trade_answer() -> int:
	if not connected():
		_offered = false
		return 0
	if int(_round().get("serial", 0)) <= _offer_serial:
		return PENDING
	_offered = false
	return 1 if String(_round().get("outcome", "")) == PokeCoopTrades.TRADED else 0


func close() -> void:
	super.close()
	if _offered:
		_offered = false
		client.send({"type": "trade", "leave": true})
