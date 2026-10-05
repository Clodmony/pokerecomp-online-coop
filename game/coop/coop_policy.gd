class_name PokeCoopPolicy
extends RefCounted

## Provisional rules for what the original games never had to decide. Kept apart
## from the simulation so each can change without touching it; see
## `docs/coop/design.md` for the open questions behind them.

const NEW_PLAYER_MONEY: int = 3000
## Red and Blue's three starters, and the level Oak's lab hands one out at.
const STARTERS: Array[int] = [1, 4, 7]
const STARTER_LEVEL: int = 5
## Pallet Town, and where each joining player stands in it: the two doorsteps first.
const START_MAP: Vector2i = Vector2i(0, 0)
const START_CELLS: Array[Vector2i] = [
	Vector2i(5, 6), Vector2i(13, 6), Vector2i(6, 6), Vector2i(12, 6),
]
## A co-op run hands out starters itself, so Oak's intro counts as done:
## EVENT_FOLLOWED_OAK_INTO_LAB, _2, OAK_ASKED_TO_CHOOSE_MON, GOT_STARTER and
## BATTLED_RIVAL_IN_OAKS_LAB at the pinned pokered.
const INTRO_DONE_FLAGS: Array[int] = [0x00, 0x20, 0x21, 0x22, 0x23]


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


## A late joiner starts with shared progress, no Pokémon and starting money.
static func new_player_money() -> int:
	return NEW_PLAYER_MONEY


## A new campaign begins after Oak's intro, which its players never see.
static func start_campaign(campaign: PokeCoopCampaign) -> void:
	campaign.commit("intro:starters_given", {"flags": INTRO_DONE_FLAGS})


## A player new to the campaign: [param starter] if it is one of the three, at
## Oak's level and with the player as its trainer, standing in Pallet Town.
static func set_up_new_player(
	data: GameData, player: PokeCoopPlayer, starter: int, joined_before: int
) -> void:
	var species: int = starter if STARTERS.has(starter) else STARTERS[joined_before % STARTERS.size()]
	var mon: Gen2BattleMon = Gen2BattleMon.create(
		data, species, STARTER_LEVEL, data.moves_at_level(species, STARTER_LEVEL)
	)
	if mon != null:
		var saved: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(mon)
		saved.ot_id = player.trainer_id
		saved.original_trainer = player.name
		saved.caught_level = STARTER_LEVEL
		player.add_mon(saved)
	player.place(START_MAP, START_CELLS[joined_before % START_CELLS.size()], 0)


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
