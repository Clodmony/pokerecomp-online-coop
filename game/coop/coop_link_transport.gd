class_name PokeCoopLinkTransport
extends Gen2LinkTransport

## The Cable Club's cable to the partner the host names, with their party as the
## host holds it; offers and answers go to the host, which swaps ([PokeCoopTrades]).

## How long an offer waits for the partner's, and an answer for theirs, before
## the screen is let go: a partner who never sits down cannot strand anyone.
var offer_wait_msec: int = 30000
var answer_wait_msec: int = 60000
var client: PokeCoopClient = null
var _offered: bool = false
var _offer_serial: int = -1
var _since_msec: int = 0


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
		_since_msec = Time.get_ticks_msec()
		client.send({"type": "trade", "partner": peer["player_id"], "slot": int(context.get("slot", 0))})
		return PENDING
	var slot: int = int(_round().get("partner_slot", -1))
	if int(_round().get("serial", 0)) > _offer_serial or (slot < 0 and _waited(offer_wait_msec)):
		_give_up()
		return -1
	_since_msec = Time.get_ticks_msec() if slot >= 0 else _since_msec
	return slot if slot >= 0 else PENDING


func answer_trade(accepted: bool) -> void:
	if _offered and connected():
		client.send({"type": "trade", "partner": peer["player_id"], "answer": 1 if accepted else 0})
	_offered = _offered and accepted
	_since_msec = Time.get_ticks_msec()


func trade_answer() -> int:
	if not connected():
		_offered = false
		return 0
	if int(_round().get("serial", 0)) <= _offer_serial:
		if not _waited(answer_wait_msec):
			return PENDING
		_give_up()
		return 0
	_offered = false
	return 1 if String(_round().get("outcome", "")) == PokeCoopTrades.TRADED else 0


func close() -> void:
	super.close()
	if _offered:
		_give_up()


func _waited(limit: int) -> bool:
	return Time.get_ticks_msec() - _since_msec >= limit


func _give_up() -> void:
	_offered = false
	client.send({"type": "trade", "leave": true})
