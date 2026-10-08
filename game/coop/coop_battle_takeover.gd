class_name PokeCoopBattleTakeover
extends RefCounted

## A window's own battles, fought on the host as joinable sessions: the world keeps the trigger, the script's
## branches, the party and the whiteout, the host the fight and the prize, so the world's prize is zeroed.

var client: PokeCoopClient = null
var data: GameData = null
## The battles the world opened itself, whose evolutions it runs itself.
var claimed: Dictionary = {}


static func over(session: PokeCoopClient, game_data: GameData) -> PokeCoopBattleTakeover:
	var out := PokeCoopBattleTakeover.new()
	out.client = session
	out.data = game_data
	return out


func takes_battle(context: Dictionary) -> bool:
	return client != null and client.connected and not client.me().is_empty() \
		and StringName(context.get("battle_kind", &"")) in [&"wild", &"trainer"]


func create_battle() -> Node:
	return Bridge.new(self)


static func win_line(game: GameData, pointer: Variant) -> String:
	if not pointer is Dictionary:
		return ""
	var text: String = String((pointer as Dictionary).get("text", ""))
	var address: int = int((pointer as Dictionary).get("address", 0))
	if text.is_empty() and address > 0 and game != null:
		text = String(game.world_text_string(int((pointer as Dictionary).get("bank", 0)), address).get("text", ""))
	return text


## The world's battle Node: asks the host for the fight, then takes the host's party before saying how it went.
class Bridge extends Node:
	signal finished(result: Dictionary)

	var client: PokeCoopClient = null
	var data: GameData = null
	var _owner: PokeCoopBattleTakeover = null
	var _context: Dictionary = {}
	var _known: Array = []
	var _battle_id: String = ""
	var _seq: int = -1
	var _done: bool = false

	func _init(takeover: PokeCoopBattleTakeover) -> void:
		_owner = takeover
		client = takeover.client
		data = takeover.data
		process_mode = Node.PROCESS_MODE_ALWAYS

	func start(context: Dictionary) -> void:
		_context = context
		var battle: Gen2Battle = context["battle"]
		battle.battle_reward = 0
		battle.pay_day_money = 0
		var enemies: Array = []
		for member: Gen2BattleMon in (context["enemy_party"] as Gen2Party).mons:
			enemies.append(Gen2SaveBattleAdapter.from_battle_mon(member).to_dict())
		var summary: Dictionary = context.get("summary", {})
		_known = client.battles.keys()
		client.journal.add(PokeCoopLog.WORLD, "takeover_start", {"summary": summary, "enemy": enemies.size()}, client.player_id)
		_seq = client.send({
			"type": "window_battle", "kind": String(summary.get("battle_kind", "wild")),
			"trainer_class": int(summary.get("trainer_class", 0)),
			"trainer_index": int(summary.get("trainer_index", 0)), "enemy": enemies,
			"trainer_name": String(summary.get("trainer_name", "")), "win_text": PokeCoopBattleTakeover.win_line(data, summary.get("win_text")),
			"gym": int(summary.get("lone_attack", 0)) != 0,
			"map": [int(summary.get("map_group", -1)), int(summary.get("map_number", -1))],
		})

	func advance_frame() -> void:
		pass

	func handle_button(_button: int) -> void:
		pass

	func _process(_delta: float) -> void:
		if _done:
			return
		var refusal: StringName = _refusal()
		if refusal != &"":
			_finish(&"won" if refusal == &"encounter_done" else &"ran")
			return
		if _battle_id.is_empty():
			_battle_id = _new_battle()
			if not _battle_id.is_empty():
				_owner.claimed[_battle_id] = true
		var outcome: String = String(client.battle(_battle_id).get("outcome", ""))
		if not _battle_id.is_empty() and not outcome.is_empty():
			_take_party()
			## A catch ends a scripted battle as a win does: the object is gone.
			_finish(&"won" if outcome in ["won", "caught"] else (&"lost" if outcome == "lost" else &"ran"))

	## Why the host refused this fight, or empty; a trainer the campaign has beaten counts as beaten here.
	func _refusal() -> StringName:
		for rejection: Dictionary in client.rejections:
			if int(rejection.get("seq", -1)) == _seq:
				return StringName(rejection.get("reason", &"refused"))
		return &""

	func _new_battle() -> String:
		for battle_id: String in client.battles:
			if not _known.has(battle_id):
				return battle_id
		return ""

	func _take_party() -> void:
		var party: Gen2Party = _context["player_party"]
		var rows: Array = client.me().get("party", [])
		for index: int in mini(party.mons.size(), rows.size()):
			var fought: Gen2BattleMon = Gen2SaveBattleAdapter.to_battle_mon(
				data, Gen2SaveMon.from_dict((rows[index] as Dictionary)["mon"])
			)
			if fought != null:
				party.mons[index] = fought

	func _finish(outcome: StringName) -> void:
		client.journal.add(PokeCoopLog.WORLD, "takeover_end", {"battle": _battle_id, "outcome": outcome}, client.player_id)
		_done = true
		finished.emit({"outcome": outcome})
