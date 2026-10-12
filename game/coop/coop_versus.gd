class_name PokeCoopVersus
extends PokeCoopBattleSession


const WAITING: StringName = &"wait"
const BOTH: int = 2

var sides: Dictionary = {}
var _ids: Array = ["", ""]
var _uids: Array = [[], []]
var _chosen: Dictionary = {}
var _round: int = 0
var _learn_round: Array = [0, 0]
var _forced_at: int = 0
var _faced: Array = [{}, {}]
var _forfeit: int = -1
var _awards: Array = []
var _side_events: Array = [[], []]


static func pit(data: GameData, battle_id: String, seed_value: int, first: PokeCoopPlayer, second: PokeCoopPlayer) -> PokeCoopVersus:
	if data == null or first == null or second == null or first == second or not first.is_free() or not second.is_free():
		return null
	var teams: Array = [fighters_of(data, first), fighters_of(data, second)]
	if teams.any(func(team: Dictionary) -> bool: return fit_count(team) <= 0):
		return null
	var out := PokeCoopVersus.new()
	out.id = battle_id
	out.initiator = first.player_id
	out.encounter = {"id": "versus:" + battle_id, "kind": "versus", "private": true, "trainer_class": Gen1Layout.LINK_TRAINER_CLASS}
	out.rng.seed = seed_value
	var foes: Gen2Party = Gen2Party.create(teams[1]["mons"])
	foes.active = foes.first_healthy()
	out.battle = Gen2Battle.create_parties(data, Gen2Party.create(teams[0]["mons"]), foes, out.rng, true, 0)
	if out.battle == null:
		return null
	out.battle.is_link_battle = true
	out.battle.battle_style_set = true
	for side: int in 2:
		var member: PokeCoopPlayer = first if side == Gen2Battle.PLAYER else second
		out._seat(member, side, teams[side])
	out._note_faced()
	return out


func _seat(member: PokeCoopPlayer, side: int, team: Dictionary) -> void:
	sides[member.player_id] = side
	_ids[side] = member.player_id
	_uids[side] = team["uids"]
	for mon: Gen2BattleMon in team["mons"]:
		battle.owner_trainer_ids[mon] = member.trainer_id
		seen[mon.species] = true
	participants.append(member.player_id)
	_members[member.player_id] = member
	_attached[member.player_id] = true
	member.battle_id = id


func fight_over() -> bool:
	return _abandoned or _forfeit >= 0 or battle.is_over()


func phase() -> StringName:
	if not fight_over():
		return AWAITING_ACTION
	return AWAITING_LEARN if _awards.any(_learning) else OVER


static func _learning(award: Gen2Battle) -> bool:
	return award.must_learn_move(Gen2Battle.PLAYER)


func phase_for(side: int) -> StringName:
	if phase() == OVER:
		return OVER
	if fight_over():
		return AWAITING_LEARN if _learning(_awards[side]) else WAITING
	if battle.awaiting_mimic() >= 0:
		return AWAITING_MIMIC if battle.awaiting_mimic() == side else WAITING
	if _chosen.has(side) or not _due().has(side):
		return WAITING
	return AWAITING_SEND_OUT if battle.must_replace(side) else AWAITING_ACTION


func _due() -> Array:
	if battle.awaiting_replacement():
		return [Gen2Battle.PLAYER, Gen2Battle.ENEMY].filter(battle.must_replace)
	return [Gen2Battle.PLAYER, Gen2Battle.ENEMY].filter(func(side: int) -> bool: return not _menu_skipped(side))


func advance() -> bool:
	if fight_over() or not _absent.is_empty() or battle.awaiting_mimic() >= 0 or not _due().is_empty() \
			or Time.get_ticks_msec() - _forced_at < 200:
		return false
	var events: Array = _resolve()
	_step(events, events)
	_forced_at = Time.get_ticks_msec()
	return true


func _menu_skipped(side: int) -> bool:
	var out: Gen2BattleMon = battle.mon(side)
	return Gen2Substatus.has(out.substatus, Gen2Substatus.RECHARGING | Gen2Substatus.RAMPAGING | Gen2Substatus.RAGE) \
		or out.charged_move != 0


func controller() -> String:
	return ""


func stand_in_due() -> bool:
	return false


func submit(player: PokeCoopPlayer, command: Dictionary) -> Dictionary:
	var side: int = int(sides.get(player.player_id, -1))
	if side < 0:
		return _refused(&"not_a_participant")
	if phase() == OVER:
		return _refused(&"battle_over")
	var earliest: int = int(_learn_round[side]) if not _awards.is_empty() else _round
	if PokeCoopTransport.number(command.get("revision"), -1) < earliest or PokeCoopTransport.number(command.get("revision"), -1) > revision:
		return _refused(&"stale_revision")
	var kind: String = PokeCoopTransport.text(command.get("type"))
	match phase_for(side):
		AWAITING_ACTION:
			return _choose(side, _action(side, kind, command))
		AWAITING_SEND_OUT:
			if kind == "run":
				_forfeit = side
				_step([], [])
				return _done([])
			var index: int = PokeCoopTransport.number(command.get("index"), -1)
			return _choose(side, {"index": index} if kind == "send_out" and battle.party(side).can_send_out(index) else {})
		AWAITING_MIMIC:
			if kind != "mimic":
				return _refused(&"invalid_command")
			var events: Array = battle.answer_mimic(PokeCoopTransport.number(command.get("choice"), -1))
			if battle.awaiting_mimic() == side:
				return _refused(&"invalid_command")
			_step(events, events)
			return _done(events)
		AWAITING_LEARN:
			return _learn_for(side, kind, PokeCoopTransport.number(command.get("forget_slot"), -1))
	return _refused(&"not_controller")


func _action(side: int, kind: String, command: Dictionary) -> Dictionary:
	match kind:
		"move":
			var slot: int = PokeCoopTransport.number(command.get("slot"), -1)
			var out: Gen2BattleMon = battle.mon(side)
			var usable: bool = slot >= 0 and slot < out.moves.size() and (out.can_use(slot) or out.is_out_of_pp() or out.encored_slot >= 0)
			return Gen2Battle.use_move(slot) if usable else {}
		"switch":
			var index: int = PokeCoopTransport.number(command.get("index"), -1)
			return Gen2Battle.switch_to(index) if battle.party(side).can_send_out(index) else {}
		"run":
			return Gen2Battle.run_away()
	return {}


func _choose(side: int, choice: Dictionary) -> Dictionary:
	if choice.is_empty():
		return _refused(&"invalid_command")
	_chosen[side] = choice
	var events: Array = []
	for _turn: int in Gen2Party.MAX_ALLIED_SIZE:
		if fight_over() or battle.awaiting_mimic() >= 0 or not _due().all(func(due_side: int) -> bool: return _chosen.has(due_side)):
			break
		events.append_array(_resolve())
	_step(events, events)
	return _done(events)


func _resolve() -> Array:
	var chosen: Dictionary = _chosen
	_chosen = {}
	if battle.awaiting_replacement():
		return _send_outs(chosen)
	var runners: Array = [Gen2Battle.PLAYER, Gen2Battle.ENEMY].filter(func(side: int) -> bool:
		return StringName((chosen.get(side, {}) as Dictionary).get("type", &"")) == Gen2Battle.ACTION_RUN)
	if not runners.is_empty():
		_forfeit = BOTH if runners.size() == 2 else int(runners[0])
		return [{"type": Gen2Battle.FLED, "side": runners[0], "forfeit": true, "how": &"forfeit"}]
	var events: Array = battle.take_actions(chosen.get(Gen2Battle.PLAYER, Gen2Battle.use_move(0)),
		chosen.get(Gen2Battle.ENEMY, Gen2Battle.use_move(0)))
	_note_faced()
	return events


func _send_outs(chosen: Dictionary) -> Array:
	var events: Array = []
	if chosen.has(Gen2Battle.PLAYER):
		var index: int = int(chosen[Gen2Battle.PLAYER]["index"])
		events.append_array(battle.send_out(Gen2Battle.PLAYER, index))
	if chosen.has(Gen2Battle.ENEMY):
		events.append_array(battle.send_out(Gen2Battle.ENEMY, int(chosen[Gen2Battle.ENEMY]["index"])))
	_note_faced()
	return events


func _note_faced() -> void:
	var out: Array = [battle.party(Gen2Battle.PLAYER).active, battle.party(Gen2Battle.ENEMY).active]
	for side: int in 2:
		var met: Dictionary = (_faced[side] as Dictionary).get_or_add(out[side], {})
		met[out[1 - side]] = true


func _learn_for(side: int, kind: String, forget_slot: int) -> Dictionary:
	var award: Gen2Battle = _awards[side]
	var offer: Dictionary = award.pending_learn(Gen2Battle.PLAYER)
	var events: Array = award.learn_move(Gen2Battle.PLAYER, forget_slot) if kind == "learn" \
		else award.decline_move(Gen2Battle.PLAYER) if kind == "decline" else []
	if award.pending_learn(Gen2Battle.PLAYER) == offer:
		return _refused(&"invalid_learn")
	var none: Array = []
	_step(events if side == Gen2Battle.PLAYER else none, none if side == Gen2Battle.PLAYER else events, false)
	_learn_round[side] = revision
	return _done(events)


func _step(fight: Array, mine: Array, mirror: bool = true) -> void:
	revision += 1
	_side_events = [fight, mirrored(mine) if mirror else mine]
	last_events = fight
	if fight_over() and _awards.is_empty():
		_award()
	if fight_over() or _chosen.is_empty():
		_round = revision


func _award() -> void:
	for side: int in 2:
		_learn_round[side] = revision
		var member: PokeCoopPlayer = _members[_ids[side]]
		var mine: Dictionary = fighters_of(battle.data, member)
		var foes: Dictionary = fighters_of(battle.data, _members[_ids[1 - side]])
		for mon: Gen2BattleMon in mine["mons"] + foes["mons"]:
			mon.restore_health()
		var award: Gen2Battle = Gen2Battle.create_parties(battle.data, Gen2Party.create(mine["mons"]),
			Gen2Party.create(foes["mons"]), RandomNumberGenerator.new(), true, 0)
		award.player_id = member.trainer_id
		_awards.append(award)
		_side_events[side] = (_side_events[side] as Array) + PokeCoopPolicy.versus_experience(award, _faced[side], foes["mons"])


func abandon() -> void:
	super.abandon()
	if _awards.is_empty():
		_award()
	for award: Gen2Battle in _awards:
		while _learning(award):
			award.decline_move(Gen2Battle.PLAYER)


static func mirrored(events: Array) -> Array:
	var swapped: Dictionary = {Gen2BattleAnimPlayer.AFTER_ANIM_ENEMY_DAMAGE: Gen2BattleAnimPlayer.AFTER_ANIM_PLAYER_DAMAGE,
		Gen2BattleAnimPlayer.AFTER_ANIM_PLAYER_DAMAGE: Gen2BattleAnimPlayer.AFTER_ANIM_ENEMY_DAMAGE}
	return events.map(func(event: Dictionary) -> Dictionary:
		var out: Dictionary = event.duplicate(true)
		for key: String in ["side", "target", "to", "from", "winner"]:
			if out.get(key) is int and int(out[key]) in [Gen2Battle.PLAYER, Gen2Battle.ENEMY]:
				out[key] = 1 - int(out[key])
		if out.has("enemy_turn"):
			out["enemy_turn"] = not bool(out["enemy_turn"])
		if out.has("after_anim"):
			out["after_anim"] = swapped.get(int(out["after_anim"]), int(out["after_anim"]))
		if out.get("statuses") is Array and (out["statuses"] as Array).size() == 2:
			out["statuses"] = [out["statuses"][1], out["statuses"][0]]
		return out)


func outcome() -> StringName:
	return &"" if phase() != OVER else &"versus"


func outcome_for(side: int) -> StringName:
	if phase() != OVER:
		return &""
	if _forfeit >= 0:
		return &"draw" if _forfeit == BOTH else &"fled" if _forfeit == side else &"won"
	if _abandoned and not battle.is_over():
		return &"fled"
	var winner: Variant = battle.winner()
	return &"draw" if winner == null else &"won" if int(winner) == side else &"lost"


func results() -> Dictionary:
	var out: Dictionary = {}
	for side: int in _awards.size():
		var party: Gen2Party = (_awards[side] as Gen2Battle).party(Gen2Battle.PLAYER)
		out[_ids[side]] = range(party.size()).map(func(index: int) -> Dictionary:
			return {"uid": _uids[side][index], "mon": party.at(index)})
	return out


func evolvable_uids() -> Array[String]:
	var out: Array[String] = []
	for side: int in _awards.size():
		for index: int in (_awards[side] as Gen2Battle).evolvable_indices():
			out.append(String(_uids[side][index]))
	return out


func everyone_away_for() -> int:
	var longest: int = -1
	for player_id: String in participants:
		if _absent.has(player_id):
			longest = maxi(longest, Time.get_ticks_msec() - int(_absent[player_id]))
	return longest


func suggest(_player_id: String, _suggestion: Dictionary) -> StringName:
	return &"versus"


func request_join(_data: GameData, _player: PokeCoopPlayer) -> StringName:
	return &"private_battle"


func view() -> Dictionary:
	return view_for(initiator)


func view_for(viewer: String) -> Dictionary:
	var side: int = int(sides.get(viewer, Gen2Battle.PLAYER))
	var other: String = _ids[1 - side]
	var asked: StringName = phase_for(side)
	var shown: Gen2Party = (_awards[side] as Gen2Battle).party(Gen2Battle.PLAYER) if not _awards.is_empty() else battle.party(side)
	var foes: Gen2Party = battle.party(1 - side)
	return {
		"battle": id, "encounter": String(encounter["id"]), "revision": revision, "phase": asked,
		"controller": viewer if asked in [AWAITING_ACTION, AWAITING_SEND_OUT, AWAITING_LEARN, AWAITING_MIMIC, OVER] else other,
		"paused": _absent.has(other) and asked == WAITING, "owner": viewer,
		"mimic": battle.mimic_choices() if battle.awaiting_mimic() == side else [],
		"learning": (_awards[side] as Gen2Battle).pending_learn(Gen2Battle.PLAYER).duplicate() if not _awards.is_empty() else {},
		"participants": participants.duplicate(), "pending": [], "left": [], "attached": participants.duplicate(),
		"stand_in_due": false, "active": battle.party(side).active,
		"allies": range(shown.size()).map(func(index: int) -> Dictionary: return _battler_view(shown.at(index)).merged(
			{"index": index, "owner": viewer, "uid": _uids[side][index]})),
		"enemy": _battler_view(foes.active_mon()), "enemy_party": foes.mons.map(func(mon: Gen2BattleMon) -> int: return mon.species),
		"enemy_states": PokeCoopBattleSession.party_states(foes), "suggestions": {}, "events": _side_events[side], "outcome": outcome_for(side), "trainer": true,
		"caught_for": "", "trainer_class": Gen1Layout.LINK_TRAINER_CLASS, "trainer_index": 0, "trainer_pic": Gen2BattleScreen.LINK_OPPONENT_PIC,
		"trainer_name": (_members[other] as PokeCoopPlayer).name, "win_text": "", "gym": false,
		"versus": true, "forfeit": _forfeit >= 0,
	}
