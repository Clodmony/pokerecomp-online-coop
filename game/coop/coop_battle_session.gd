class_name PokeCoopBattleSession
extends RefCounted

## One battle of a co-op run with its own rng, participants, allied roster and
## revision. The owner of the Pokémon that is out decides; everybody else in the
## battle may only suggest. Joins land at a turn boundary; a team the roster has no
## room for brings its first fit Pokémon in party order, the rest sitting it out.

const AWAITING_ACTION: StringName = &"action"
const AWAITING_SEND_OUT: StringName = &"send_out"
const AWAITING_LEARN: StringName = &"learn"
const AWAITING_MIMIC: StringName = &"mimic"
const AWAITING_OFFER: StringName = &"offer"
const OVER: StringName = &"over"

const JOINED: StringName = &"coop_joined"
const ITEM_USED: StringName = &"coop_item_used"
const BALL_THROWN: StringName = &"coop_ball_thrown"
const CAUGHT: StringName = &"caught"
const SUGGESTION_TYPES: Array[String] = ["move", "switch", "item", "run", "send_out", "stay", "learn", "decline", "mimic"]

var id: String = ""
var encounter: Dictionary = {}
var initiator: String = ""
var participants: Array[String] = []
var roster: PokeCoopRoster = PokeCoopRoster.new()
var battle: Gen2Battle = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var revision: int = 0
var suggestions: Dictionary = {}
var last_events: Array = []
var seen: Dictionary = {}
## Who a caught wild goes to and the wild itself, once a ball has held.
var catch: Dictionary = {}
var _pending_joins: Array = []
var _absent: Dictionary = {}
var _left: Dictionary = {}
var _stand_ins: Dictionary = {}
var _attached: Dictionary = {}
var _abandoned: bool = false
var _members: Dictionary = {}
var _last_slot: int = 0


static func start(
	data: GameData, battle_id: String, seed_value: int, player: PokeCoopPlayer,
	enemy: Gen2Party, encounter_info: Dictionary, badge_mask: int = 0
) -> PokeCoopBattleSession:
	if data == null or player == null or enemy == null or not player.is_free():
		return null
	var fighters: Dictionary = fighters_of(data, player)
	if fit_count(fighters) <= 0:
		return null
	var out := PokeCoopBattleSession.new()
	out.id = battle_id
	out.encounter = encounter_info.duplicate(true)
	out.initiator = player.player_id
	out.rng.seed = seed_value
	var trainer_class: int = int(encounter_info.get("trainer_class", 0))
	out.battle = Gen2Battle.create_parties(
		data, Gen2Party.create(fighters["mons"]), enemy, out.rng, trainer_class > 0, badge_mask
	)
	if out.battle == null:
		return null
	out.battle.battle_style_set = true
	out.seen[out.battle.mon(Gen2Battle.ENEMY).species] = true
	if trainer_class > 0:
		out.battle.init_enemy_trainer(trainer_class)
	out._enlist(player, fighters)
	out._attached[player.player_id] = true
	return out


## The player's team as battlers, eggs left out, with the uid of each.
static func fighters_of(data: GameData, player: PokeCoopPlayer) -> Dictionary:
	var mons: Array = []
	var uids: Array = []
	for entry: Dictionary in player.team:
		var saved: Gen2SaveMon = entry["mon"]
		var fighter: Gen2BattleMon = Gen2SaveBattleAdapter.to_battle_mon(data, saved)
		if fighter != null:
			mons.append(fighter)
			uids.append(String(entry["uid"]))
	return {"mons": mons, "uids": uids}


static func fit_count(fighters: Dictionary) -> int:
	var out: int = 0
	for fighter: Gen2BattleMon in fighters["mons"]:
		if not fighter.is_fainted():
			out += 1
	return out


func _enlist(player: PokeCoopPlayer, fighters: Dictionary) -> Array[int]:
	var added: Array[int] = []
	var mons: Array = fighters["mons"]
	for index: int in mons.size():
		added.append(roster.add(player.player_id, String((fighters["uids"] as Array)[index])))
		battle.owner_trainer_ids[mons[index]] = player.trainer_id
	participants.append(player.player_id)
	_members[player.player_id] = player
	player.battle_id = id
	_share_exp_all()
	return added


func _share_exp_all() -> void:
	var teams: Dictionary = {}
	for index: int in roster.size():
		(teams.get_or_add(roster.owner_at(index), []) as Array).append(index)
	battle.exp_all_groups = teams.values()
	battle.exp_all_in_bag = battle.is_gen1() and participants.any(func(player_id: String) -> bool:
		return (_members[player_id] as PokeCoopPlayer).item_count(Gen1Layout.ITEM_EXP_ALL) > 0)


## A move offered on the last knockout is still asked before the battle ends.
func phase() -> StringName:
	if _abandoned:
		return OVER
	if battle.must_learn_move(Gen2Battle.PLAYER) and catch.is_empty():
		return AWAITING_LEARN
	if battle.is_over() or not catch.is_empty():
		return OVER
	if battle.awaiting_mimic() == Gen2Battle.PLAYER:
		return AWAITING_MIMIC
	if battle.awaiting_switch_offer() >= 0:
		return AWAITING_OFFER
	if battle.awaiting_baton_pass() == Gen2Battle.PLAYER or battle.must_replace(Gen2Battle.PLAYER):
		return AWAITING_SEND_OUT
	return AWAITING_ACTION


## `CheckPlayerLockedIn`: a charged, recharging, rampaging or raging Pokémon takes its turn with no command.
func advance() -> bool:
	if phase() != AWAITING_ACTION or is_paused() or not battle.player_menu_skipped():
		return false
	var events: Array = battle.take_actions(Gen2Battle.use_move(_last_slot), _enemy_action())
	_settle(events)
	_advance(events)
	return true


## The active Pokémon's owner, or while they are away whoever stands in for them (D61).
func controller() -> String:
	var owner: String = owner_deciding()
	if is_present(owner):
		return owner
	var chosen: String = _stands_in_for(owner)
	if is_present(chosen):
		return chosen
	if _left.has(owner) or not chosen.is_empty():
		for player_id: String in participants:
			if is_present(player_id):
				return player_id
	return owner


func _stands_in_for(owner: String) -> String:
	return String(_stand_ins.get(owner, ""))


func is_present(player_id: String) -> bool:
	return participants.has(player_id) and not _absent.has(player_id)


func has_left(player_id: String) -> bool:
	return _left.has(player_id)


func stand_in_due() -> bool:
	var owner: String = owner_deciding()
	return phase() != OVER and _absent.has(owner) and not _left.has(owner) \
		and not is_present(_stands_in_for(owner)) \
		and Time.get_ticks_msec() - int(_absent[owner]) >= PokeCoopPolicy.STAND_IN_MSEC


func stand_in(player_id: String) -> StringName:
	if not is_present(player_id):
		return &"not_a_participant"
	if not stand_in_due():
		return &"no_stand_in_due"
	_stand_ins[owner_deciding()] = player_id
	return &""


func owner_deciding() -> String:
	if phase() == AWAITING_LEARN:
		return roster.owner_at(int(battle.pending_learn(Gen2Battle.PLAYER).get("index", -1)))
	return roster.owner_at(battle.party(Gen2Battle.PLAYER).active)


func is_paused() -> bool:
	return phase() != OVER and _absent.has(controller())


## [param since_msec] is when they went, by `Time.get_ticks_msec`; one who left stays away until they rejoin.
func set_absent(player_id: String, absent: bool, since_msec: int = Time.get_ticks_msec()) -> void:
	if absent:
		_absent[player_id] = since_msec
	elif not _left.has(player_id):
		_absent.erase(player_id)
		_stand_ins.erase(player_id)


func attach(player_id: String) -> void:
	_attached[player_id] = true


func leave(player: PokeCoopPlayer) -> StringName:
	if _attached.has(player.player_id):
		return &"attached"
	var queued: int = pending_players().find(player.player_id)
	if queued >= 0:
		_pending_joins.remove_at(queued)
		player.battle_id = ""
		player.resume_exploration()
		return &""
	if not participants.has(player.player_id):
		return &"not_a_participant"
	if phase() == OVER:
		return &"battle_over"
	if _left.has(player.player_id):
		return &"already_left"
	_left[player.player_id] = true
	_absent[player.player_id] = Time.get_ticks_msec()
	suggestions.erase(player.player_id)
	player.resume_exploration()
	return &""


## Ends the battle as fled: everybody left it, or the host is closing.
func abandon() -> void:
	_abandoned = true


## How long nobody in the battle has been connected, in milliseconds, or -1.
func everyone_away_for() -> int:
	var latest: int = -(1 << 62)
	for player_id: String in participants:
		if not _absent.has(player_id):
			return -1
		latest = maxi(latest, int(_absent[player_id]))
	return Time.get_ticks_msec() - latest if not participants.is_empty() else -1


func pending_players() -> Array[String]:
	var out: Array[String] = []
	for join: Dictionary in _pending_joins:
		out.append((join["player"] as PokeCoopPlayer).player_id)
	return out


func involves(player_id: String) -> bool:
	return participants.has(player_id) or pending_players().has(player_id)


func submit(player: PokeCoopPlayer, command: Dictionary) -> Dictionary:
	var refusal: StringName = _refusal(player.player_id, PokeCoopTransport.number(command.get("revision"), -1))
	if refusal != &"":
		return {"ok": false, "reason": refusal}
	var applied: Dictionary = _apply(player, command)
	if not bool(applied.get("ok", false)):
		return applied
	var events: Array = applied["events"]
	_settle(events)
	_advance(events)
	return {"ok": true, "events": events}


func _refusal(player_id: String, at_revision: int) -> StringName:
	if not participants.has(player_id):
		return &"not_a_participant"
	if phase() == OVER:
		return &"battle_over"
	if at_revision != revision:
		return &"stale_revision"
	if player_id != controller():
		return &"not_controller"
	return &"paused" if is_paused() else &""


func _apply(player: PokeCoopPlayer, command: Dictionary) -> Dictionary:
	var kind: String = PokeCoopTransport.text(command.get("type"))
	match phase():
		AWAITING_ACTION:
			return _act(player, kind, command)
		AWAITING_SEND_OUT:
			return _send_out(kind, PokeCoopTransport.number(command.get("index"), -1))
		AWAITING_LEARN:
			return _learn(kind, PokeCoopTransport.number(command.get("forget_slot"), -1))
		AWAITING_MIMIC:
			if kind == "mimic":
				var before: int = battle.awaiting_mimic()
				var events: Array = battle.answer_mimic(PokeCoopTransport.number(command.get("choice"), -1))
				if battle.awaiting_mimic() != before:
					return _done(events)
		AWAITING_OFFER:
			return _answer_offer(kind, PokeCoopTransport.number(command.get("index"), -1))
	return _refused(&"invalid_command")


func _act(player: PokeCoopPlayer, kind: String, command: Dictionary) -> Dictionary:
	match kind:
		"move":
			var slot: int = PokeCoopTransport.number(command.get("slot"), -1)
			if not _move_allowed(slot):
				return _refused(&"invalid_move")
			_last_slot = slot
			return _done(battle.take_actions(Gen2Battle.use_move(slot), _enemy_action()))
		"switch":
			var index: int = PokeCoopTransport.number(command.get("index"), -1)
			if not battle.party(Gen2Battle.PLAYER).can_send_out(index):
				return _refused(&"invalid_switch")
			return _done(battle.take_actions(Gen2Battle.switch_to(index), _enemy_action()))
		"item":
			return _use_item(player, command)
		"run":
			return _done(battle.take_actions(Gen2Battle.run_away(), _enemy_action()))
	return _refused(&"invalid_command")


func _move_allowed(slot: int) -> bool:
	if slot < 0 or slot >= Gen2BattleMon.MAX_MOVES:
		return false
	var out_mon: Gen2BattleMon = battle.mon(Gen2Battle.PLAYER)
	return out_mon.can_use(slot) or out_mon.is_out_of_pp() \
		or battle.player_menu_skipped() or battle.player_move_menu_skipped()


func _use_item(player: PokeCoopPlayer, command: Dictionary) -> Dictionary:
	var item: int = PokeCoopTransport.number(command.get("item"), 0)
	if player.item_count(item) <= 0:
		return _refused(&"item_not_held")
	if Gen2WorldPartyHost.is_ball(battle.data, item):
		return _throw_ball(player, item, PokeCoopTransport.text(command.get("recipient"), player.player_id))
	var used: Dictionary = battle.use_bag_item(
		item, PokeCoopTransport.number(command.get("target"), -1), PokeCoopTransport.number(command.get("move_slot"), -1)
	)
	if not bool(used.get("ok", false)):
		return _refused(StringName(used.get("reason", &"item_has_no_effect")))
	if Gen2WorldPack.can_toss(battle.data, item):
		player.take_item(item)
	var events: Array = [_item_shown(used).merged({"type": ITEM_USED, "player": player.player_id, "item": item}, true)]
	events.append_array(used.get("events", []) as Array)
	if not battle.is_over():
		events.append_array(battle.take_actions(Gen2Battle.use_item(item), _enemy_action()))
	return _done(events)


func _item_shown(used: Dictionary) -> Dictionary:
	var out: Dictionary = {"kind": String(used.get("kind", "")), "effect": (used.get("effect", {}) as Dictionary).duplicate(),
		"woken": int(used.get("woken", 0)), "statuses": [battle.mon(Gen2Battle.PLAYER).status, battle.mon(Gen2Battle.ENEMY).status]}
	var target: Gen2BattleMon = battle.party(Gen2Battle.PLAYER).at(int(used.get("target", -1)))
	if target != null:
		out.merge({"target": int(used["target"]), "hp": target.hp, "max_hp": target.max_hp(), "name": target.display_name()})
	return out


## `ItemUseBall` with the catch rolled on the host. The thrower names who the
## catch is for, one of the participants; a held ball ends the battle.
func _throw_ball(player: PokeCoopPlayer, ball: int, recipient: String) -> Dictionary:
	if battle.is_trainer_battle:
		return _refused(&"trainer_pokemon")
	if not participants.has(recipient):
		return _refused(&"invalid_recipient")
	if not (_members[recipient] as PokeCoopPlayer).has_room():
		return _refused(&"box_full")
	var wild: Gen2BattleMon = battle.mon(Gen2Battle.ENEMY)
	var roll: Dictionary = Gen2WorldPartyHost.roll_capture(
		battle.data, wild, ball, rng, battle.battle_type, battle.mon(Gen2Battle.PLAYER)
	)
	player.take_item(ball)
	var events: Array = [{
		"type": BALL_THROWN, "player": player.player_id, "ball": ball, "recipient": recipient,
		"caught": bool(roll.get("caught", false)), "wobbles": int(roll.get("wobbles", 0)),
	}]
	if bool(roll.get("caught", false)):
		catch = {"recipient": recipient, "mon": wild}
		var receiving: PokeCoopPlayer = _members[recipient]
		var dex: Dictionary = receiving.world_part().get("caught_species", {})
		events[0].merge({"species": wild.persistent_species(), "boxed": receiving.team.size() >= PokeCoopPlayer.MAX_TEAM,
			"new_dex": not (dex.has(wild.persistent_species()) or dex.has(str(wild.persistent_species())))})
		return _done(events)
	events.append_array(battle.take_actions(Gen2Battle.use_item(ball), _enemy_action()))
	return _done(events)


func _send_out(kind: String, index: int) -> Dictionary:
	if kind == "run" and battle.asking_use_next():
		return _done(battle.answer_use_next(false))
	if kind != "send_out" or not battle.party(Gen2Battle.PLAYER).can_send_out(index):
		return _refused(&"invalid_send_out")
	if battle.awaiting_baton_pass() == Gen2Battle.PLAYER:
		return _done(battle.pass_to(index))
	var events: Array = []
	if battle.asking_use_next():
		events.append_array(battle.answer_use_next(true))
	events.append_array(battle.replace_fallen(index))
	return _done(events)


func _answer_offer(kind: String, index: int) -> Dictionary:
	if kind == "stay":
		return _done(battle.answer_switch_offer(-1))
	if kind != "switch" or not battle.party(Gen2Battle.PLAYER).can_send_out(index):
		return _refused(&"invalid_switch")
	return _done(battle.answer_switch_offer(index))


func _learn(kind: String, forget_slot: int) -> Dictionary:
	var offer: Dictionary = battle.pending_learn(Gen2Battle.PLAYER)
	var events: Array = []
	if kind == "learn":
		events = battle.learn_move(Gen2Battle.PLAYER, forget_slot)
	elif kind == "decline":
		events = battle.decline_move(Gen2Battle.PLAYER)
	if battle.pending_learn(Gen2Battle.PLAYER) == offer:
		return _refused(&"invalid_learn")
	return _done(events)


## The enemy's replacement after a faint, offered first as a switch to whoever decides if their own BATTLE STYLE is SHIFT.
func _settle(events: Array) -> void:
	while not battle.is_over() and battle.must_replace(Gen2Battle.ENEMY) \
			and not battle.must_replace(Gen2Battle.PLAYER) and battle.awaiting_switch_offer() < 0:
		var decider: PokeCoopPlayer = _members.get(controller(), null)
		battle.battle_style_set = decider == null or not decider.battle_shift
		var sent: Array = battle.replace_fallen()
		events.append_array(sent)
		if sent.is_empty():
			return


func _advance(events: Array) -> void:
	revision += 1
	for event: Dictionary in events:
		if StringName(event.get("type", &"")) == Gen2Battle.SENT_OUT and int(event.get("side", 0)) == Gen2Battle.ENEMY:
			seen[int(event.get("species", 0))] = true
	suggestions.clear()
	if phase() == AWAITING_ACTION:
		_apply_joins(events)
	last_events = events


func _enemy_action() -> Dictionary:
	if battle.is_gen1():
		return Gen2Battle.use_move(Gen1TrainerAI.select_slot(battle, rng))
	var foe: Gen2BattleMon = battle.mon(Gen2Battle.ENEMY)
	var usable: Array = []
	for slot: int in foe.moves.size():
		if foe.can_use(slot):
			usable.append(slot)
	return Gen2Battle.use_move(usable[rng.randi_range(0, usable.size() - 1)] if not usable.is_empty() else 0)


func request_join(data: GameData, player: PokeCoopPlayer) -> StringName:
	if phase() == OVER:
		return &"battle_over"
	if _left.has(player.player_id):
		_left.erase(player.player_id)
		set_absent(player.player_id, false)
		player.suspend_exploration()
		return &""
	if involves(player.player_id):
		return &"already_joined"
	var fighters: Dictionary = fighters_of(data, player)
	var refusal: StringName = PokeCoopPolicy.may_join(player, fit_count(fighters))
	if refusal != &"":
		return refusal
	var room: int = Gen2Party.MAX_ALLIED_SIZE - roster.size()
	for join: Dictionary in _pending_joins:
		room -= ((join["fighters"] as Dictionary)["mons"] as Array).size()
	if room <= 0:
		return &"roster_full"
	player.battle_id = id
	player.suspend_exploration()
	_pending_joins.append({"player": player, "fighters": _within(fighters, room)})
	if phase() == AWAITING_ACTION:
		var events: Array = []
		_advance(events)
	return &""


static func _within(fighters: Dictionary, room: int) -> Dictionary:
	var mons: Array = fighters["mons"]
	if mons.size() <= room:
		return fighters
	var out: Dictionary = {"mons": [], "uids": []}
	for index: int in mons.size():
		if (out["mons"] as Array).size() < room and not (mons[index] as Gen2BattleMon).is_fainted():
			(out["mons"] as Array).append(mons[index])
			(out["uids"] as Array).append((fighters["uids"] as Array)[index])
	return out


func _apply_joins(events: Array) -> void:
	for join: Dictionary in _pending_joins:
		var player: PokeCoopPlayer = join["player"]
		var fighters: Dictionary = join["fighters"]
		if not battle.party(Gen2Battle.PLAYER).add_members(fighters["mons"]):
			player.battle_id = ""
			player.resume_exploration()
			continue
		var indices: Array[int] = _enlist(player, fighters)
		events.append({"type": JOINED, "player": player.player_id, "indices": indices})
	_pending_joins.clear()


func suggest(player_id: String, suggestion: Dictionary) -> StringName:
	if not participants.has(player_id):
		return &"not_a_participant"
	if phase() == OVER:
		return &"battle_over"
	if player_id == controller():
		return &"controller_acts"
	var kind: String = PokeCoopTransport.text(suggestion.get("type"))
	if not SUGGESTION_TYPES.has(kind):
		return &"invalid_suggestion"
	suggestions[player_id] = {"type": kind, "value": PokeCoopTransport.number(suggestion.get("value"), -1), "revision": revision,
		"recipient": PokeCoopTransport.text(suggestion.get("recipient")).left(32)}
	return &""


func outcome() -> StringName:
	if _abandoned:
		return &"fled"
	if phase() != OVER:
		return &""
	if not catch.is_empty():
		return CAUGHT
	if not battle.is_over():
		return &""
	if battle.is_draw():
		return &"fled" if battle.has_fled() else &"draw"
	return &"won" if battle.winner() == Gen2Battle.PLAYER else &"lost"


## Each allied Pokémon as the battle left it, grouped by owner: `{player_id: [{uid, mon}]}`.
func results() -> Dictionary:
	var out: Dictionary = {}
	var party: Gen2Party = battle.party(Gen2Battle.PLAYER)
	for index: int in roster.size():
		var owner: String = roster.owner_at(index)
		if not out.has(owner):
			out[owner] = []
		(out[owner] as Array).append({"uid": roster.uid_at(index), "mon": party.at(index)})
	return out


func evolvable_uids() -> Array[String]:
	var out: Array[String] = []
	for index: int in battle.evolvable_indices():
		out.append(roster.uid_at(index))
	return out


func view() -> Dictionary:
	var allies: Array = []
	var party: Gen2Party = battle.party(Gen2Battle.PLAYER)
	for index: int in party.size():
		allies.append(_battler_view(party.at(index)).merged(
			{"index": index, "owner": roster.owner_at(index), "uid": roster.uid_at(index)}
		))
	return {
		"battle": id, "encounter": String(encounter.get("id", "")), "revision": revision,
		"phase": phase(), "controller": controller(), "paused": is_paused(),
		"owner": owner_deciding(), "learning": battle.pending_learn(Gen2Battle.PLAYER).duplicate(),
		"participants": participants.duplicate(), "pending": pending_players(),
		"left": _left.keys(), "attached": _attached.keys(), "stand_in_due": stand_in_due(),
		"active": party.active, "allies": allies, "offer": battle.awaiting_switch_offer(),
		"enemy": _battler_view(battle.mon(Gen2Battle.ENEMY)),
		"enemy_party": battle.party(Gen2Battle.ENEMY).mons.map(func(mon: Gen2BattleMon) -> int: return mon.species),
		"enemy_states": party_states(battle.party(Gen2Battle.ENEMY)),
		"suggestions": suggestions.duplicate(true), "events": last_events, "outcome": outcome(),
		"trainer": battle.is_trainer_battle, "caught_for": String(catch.get("recipient", "")),
		"trainer_class": int(encounter.get("trainer_class", 0)), "trainer_index": int(encounter.get("trainer_index", 0)),
		"trainer_name": String(encounter.get("trainer_name", "")), "win_text": String(encounter.get("win_text", "")),
		"gym": bool(encounter.get("gym", false)), "loss_text": String(encounter.get("loss_text", "")),
		"spared": bool(encounter.get("spared", false)),
	}


func view_for(_viewer: String) -> Dictionary:
	return view()


static func party_states(party: Gen2Party) -> Array:
	return party.mons.map(func(mon: Gen2BattleMon) -> Dictionary: return {"hp": mon.hp, "status": mon.status})


static func _battler_view(member: Gen2BattleMon) -> Dictionary:
	return {
		"species": member.species, "name": member.display_name(), "level": member.level, "hp": member.hp,
		"max_hp": member.max_hp(), "status": member.status, "moves": member.moves.duplicate(),
		"pp": member.pp.duplicate(), "max_pp": range(member.moves.size()).map(member.max_pp), "disabled": member.disabled_slot,
		"substitute": Gen2Substatus.has(member.substatus, Gen2Substatus.SUBSTITUTE), "minimized": member.minimized,
	}


static func _done(events: Array) -> Dictionary:
	return {"ok": true, "events": events}


static func _refused(reason: StringName) -> Dictionary:
	return {"ok": false, "reason": reason}
