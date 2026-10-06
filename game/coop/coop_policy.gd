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
## Red and Blue's unique items kept for good, most needed to get on: the map,
## bicycle, keys, ticket, coin case, itemfinder, scope, flute, Exp. All, rods, HMs.
const SHARED_ITEMS: Array[int] = [
	5, 6, 43, 48, 63, 69, 71, 72, 73, 74, 75, 76, 77, 78, 196, 197, 198, 199, 200,
]
## EVENT_GOT_TMxx at the pinned pokered and the TM each person hands over.
const GIFT_TMS: Dictionary = {
	41: 242, 80: 227, 118: 234, 190: 211, 358: 224, 384: 241, 396: 213, 397: 248,
	398: 249, 399: 218, 424: 221, 600: 206, 664: 238, 727: 235, 832: 231, 864: 246,
	944: 229, 1152: 239, 1791: 236,
}
const GIFT_COMMIT_PREFIX: String = "gift:"
## How long a battle waits for a controller who dropped before another
## participant decides for their Pokémon, which stay theirs.
const STAND_IN_MSEC: int = 30000


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


## A story gift reaches every player, committed once: the shared items
## [param receiver] just gained and the TMs behind gift flags just set.
static func share_gifts(
	campaign: PokeCoopCampaign, receiver: PokeCoopPlayer, others: Array,
	flags_before: Dictionary, held_before: Dictionary,
) -> void:
	var gifts: Array[int] = []
	for item: int in SHARED_ITEMS:
		if int(held_before.get(item, 0)) == 0 and receiver.item_count(item) > 0:
			gifts.append(item)
	for flag: int in GIFT_TMS:
		if not flags_before.has(flag) and campaign.has_flag(flag):
			gifts.append(int(GIFT_TMS[flag]))
	for item: int in gifts:
		if campaign.commit(GIFT_COMMIT_PREFIX + str(item), {}):
			for other: PokeCoopPlayer in others:
				if other != receiver:
					hand_over(other, item)


## Everything the campaign's players were given before [param player] joined.
static func hand_over_gifts(campaign: PokeCoopCampaign, player: PokeCoopPlayer) -> void:
	for commit_id: String in campaign.commit_ids(GIFT_COMMIT_PREFIX):
		hand_over(player, int(commit_id.trim_prefix(GIFT_COMMIT_PREFIX)))


## Into the bag, or the PC's items when the bag's twenty rows are taken.
static func hand_over(player: PokeCoopPlayer, item: int) -> void:
	var stored: Dictionary = player.world.get("pc_items", {})
	if player.item_count(item) > 0 or int(stored.get(item, 0)) > 0:
		return
	if player.items.size() < Gen1Layout.BAG_ITEM_CAPACITY:
		player.give_item(item)
		return
	stored[item] = 1
	player.world["pc_items"] = stored


## A trainer brought from a single-player save: their team, PC, bag, money, place
## and own world keys, and with [param story] that campaign's flags, badges and
## world too. Only a campaign's first player brings the story.
static func import_save(
	save: Gen2SaveData, player: PokeCoopPlayer, story: PokeCoopCampaign, badge_flags: Array[int]
) -> void:
	var snapshot: Gen2WorldSnapshot = save.world
	if snapshot != null:
		var halves: Dictionary = PokeCoopOwnership.route(
			PokeCoopOwnership.patch({}, snapshot.world_state.to_dict()), badge_flags
		)
		if story != null:
			story.apply_world_patch(halves[PokeCoopOwnership.CAMPAIGN], badge_flags)
		player.apply_world_patch(halves[PokeCoopOwnership.PLAYER])
		if snapshot.map_id.x >= 0:
			player.place(snapshot.map_id, snapshot.player_cell, snapshot.player_facing)
	for mon: Gen2SaveMon in save.party:
		player.add_mon(mon)
	for at: int in mini(save.boxes.size(), PokeCoopPlayer.BOXES):
		for mon: Variant in (save.boxes[at] as Gen2SaveBox).slots:
			if mon != null:
				player.store_mon_at(mon, at)
	player.current_box = clampi(save.current_box, 0, PokeCoopPlayer.BOXES - 1)
