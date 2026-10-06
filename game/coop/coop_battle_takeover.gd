class_name PokeCoopBattleTakeover
extends RefCounted

## A co-op window's own wild and trainer battles, taken over through the mod
## seam and fought on the host as joinable sessions. The world keeps the trigger,
## the script's branches, the party commit and the whiteout; the host keeps the
## fight and the prize, so the world's prize is zeroed.

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


## The world's battle Node: asks the host for the fight, waits for its outcome,
## then puts the host's party into the world's before it says how it went.
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
		_seq = client.send({
			"type": "window_battle", "kind": String(summary.get("battle_kind", "wild")),
			"trainer_class": int(summary.get("trainer_class", 0)),
			"trainer_index": int(summary.get("trainer_index", 0)), "enemy": enemies,
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
			_finish(StringName(outcome) if outcome in ["won", "lost"] else &"ran")

	## Why the host refused this fight, or empty. A trainer the campaign has
	## already beaten counts as beaten here too.
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
		_done = true
		finished.emit({"outcome": outcome})
