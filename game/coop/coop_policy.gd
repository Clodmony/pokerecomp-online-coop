class_name PokeCoopPolicy
extends RefCounted

## Provisional rules for what the original games never had to decide. Kept apart
## from the simulation so each can change without touching it; see
## `docs/coop/design.md` for the open questions behind them.

const NEW_PLAYER_MONEY: int = 3000


## Prize money: an even split among participants, the remainder to the initiator.
static func prize_split(total: int, participants: Array, initiator: String) -> Dictionary:
	var out: Dictionary = {}
	if total <= 0 or participants.is_empty():
		return out
	var share: int = total / participants.size()
	for player_id: Variant in participants:
		out[String(player_id)] = share
	var holder: String = initiator if out.has(initiator) else String(participants[0])
	out[holder] = int(out[holder]) + total - share * participants.size()
	return out


## Losing costs each participant half of their own money, as a blackout does.
static func blackout_cost(money: int) -> int:
	return money / 2


## A late joiner starts with shared progress, no Pokémon and starting money.
static func new_player_money() -> int:
	return NEW_PLAYER_MONEY


## Joining needs a free, connected player with somebody able to fight.
static func may_join(player: PokeCoopPlayer, fit_count: int) -> StringName:
	if player == null:
		return &"unknown_player"
	if not player.is_free():
		return &"already_in_battle"
	if not player.connected:
		return &"not_connected"
	if fit_count <= 0:
		return &"no_fit_pokemon"
	return &""
