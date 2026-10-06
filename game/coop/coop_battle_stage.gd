class_name PokeCoopBattleStage
extends RefCounted

## A co-op battle's tilemap, kept as the battle screen keeps its own, and the
## panels each side shows while a turn plays.

const FAINT: StringName = &"faint"
const SEND_OUT: StringName = &"send_out"
const RETREAT: StringName = &"retreat"

var map: PackedByteArray = PackedByteArray()
var generation: int = RomRegistry.GEN1
var trainer: bool = false
## Panel keys shown over the host's view: who was out, until a send-out.
var shown: Dictionary = {}
var hidden: Dictionary = {}
var _routine: Dictionary = {}


func reset(game_generation: int, trainer_battle: bool) -> void:
	generation = game_generation
	trainer = trainer_battle
	map = Gen2BattleScreenMap.seeded(generation)
	shown = {}
	hidden = {}
	_routine = {}


## A battle seen from its start: the player's square empty, and a trainer's too.
func open() -> void:
	for side: int in [Gen2Battle.PLAYER, Gen2Battle.ENEMY] if trainer else [Gen2Battle.PLAYER]:
		Gen2BattleScreenMap.clear_battler(map, side == Gen2Battle.PLAYER, generation)
		hidden[side] = true


func busy() -> bool:
	return not _routine.is_empty()


func begin(kind: StringName, side: int) -> void:
	var sizes: Array = []
	match kind:
		FAINT:
			sizes.resize(Gen2BattleScreenMap.FAINT_STEPS)
			sizes.fill(0)
		SEND_OUT:
			sizes.assign(Gen2BattleScreenMap.SEND_OUT_SIZES)
			hidden.erase(side)
		RETREAT:
			sizes.assign(Gen2BattleScreenMap.RETREAT_SIZES)
	_routine = {"kind": kind, "side": side, "sizes": sizes, "delay": 0}


## A frame of `MonFaintedAnimation`, `AnimateSendingOutMon` or `AnimateRetreatingPlayerMon`.
func advance() -> void:
	if _routine.is_empty():
		return
	if int(_routine["delay"]) > 0:
		_routine["delay"] = int(_routine["delay"]) - 1
		return
	var side: int = int(_routine["side"])
	var sizes: Array = _routine["sizes"]
	if sizes.is_empty():
		if StringName(_routine["kind"]) == FAINT:
			hidden[side] = true
		_routine = {}
		return
	var size: int = int(sizes.pop_front())
	match StringName(_routine["kind"]):
		FAINT:
			Gen2BattleScreenMap.faint_step(map, side == Gen2Battle.PLAYER)
			_routine["delay"] = Gen2BattleScreenMap.FAINT_STEP_FRAMES
		SEND_OUT:
			Gen2BattleScreenMap.send_out_step(map, side == Gen2Battle.PLAYER, generation, size, 2 if trainer else 1)
			_routine["delay"] = int(Gen2BattleScreenMap.SEND_OUT_FRAMES[size])
		RETREAT:
			Gen2BattleScreenMap.retreat_step(map, generation, size)
			_routine["delay"] = int(Gen2BattleScreenMap.RETREAT_FRAMES[size])


## The panel a `SENT_OUT` event names, shown from then on.
func enter(event: Dictionary, game: GameData) -> void:
	var side: int = int(event.get("side", Gen2Battle.PLAYER))
	var prefix: String = "enemy_" if side == Gen2Battle.ENEMY else "player_"
	var species: int = int(event.get("species", 0))
	var statuses: Array = event.get("statuses", [0, 0])
	shown[prefix + "species"] = species
	shown[prefix + "name"] = String(game.species(species).get("name", "")) if species > 0 else ""
	shown[prefix + "level"] = int(event.get("level", 0))
	shown[prefix + "max_hp"] = int(event.get("max_hp", 0))
	shown[prefix + "status"] = int(statuses[0 if side == Gen2Battle.PLAYER else 1]) if statuses.size() == 2 else 0


## A turn played out: the host's view shows, and a blank side with a Pokémon up is stamped.
func settle(view: Dictionary) -> void:
	shown = {}
	for side: int in hidden.keys():
		var prefix: String = "enemy_" if side == Gen2Battle.ENEMY else "player_"
		if int(view.get(prefix + "hp", 0)) > 0 and not busy():
			Gen2BattleScreenMap.stamp(map, side == Gen2Battle.PLAYER, generation)
			hidden.erase(side)


func over(scene: Dictionary) -> Dictionary:
	scene.merge(shown, true)
	for side: int in hidden:
		scene["enemy_hud_visible" if side == Gen2Battle.ENEMY else "player_hud_visible"] = false
	if not map.is_empty():
		scene["bg_map"] = map
	return scene
