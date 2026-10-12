class_name PokeCoopBattleStage
extends RefCounted

## A co-op battle's tilemap and panels, kept as the battle screen keeps its own.

const FAINT: StringName = &"faint"
const SEND_OUT: StringName = &"send_out"
const RETREAT: StringName = &"retreat"
const INTRO: StringName = &"intro"
const SLIDE: StringName = &"slide"
const RESULT: StringName = &"result"
const PANEL: StringName = &"panel"
const RESULT_FRAMES: Array[int] = [4, 4, 4, 4, 4, 44]

var map: PackedByteArray = PackedByteArray()
var game: GameData = null
var trainer: bool = false
var shown: Dictionary = {}
var hidden: Dictionary = {}
var pictures: Dictionary = {}
var balls: Array = []
var border: Array = []
var _intro: Gen2BattleIntro = null
var _routine: Dictionary = {}


func reset(game_data: GameData, trainer_battle: bool) -> void:
	game = game_data
	trainer = trainer_battle
	map = Gen2BattleScreenMap.seeded(game.generation)
	shown = {}
	hidden = {}
	pictures = {}
	balls = []
	border = []
	_intro = null
	_routine = {}


## `InitBattleDisplay`: the back picture and the trainer or wild Pokémon, ready to slide in.
func open(trainer_class: int) -> void:
	Gen2BattleScreenMap.clear_intro_box(map)
	pictures = {"player_backpic": Gen1Layout.PLAYER_BACKPICS[0], "enemy_trainer_pic": trainer_class if trainer else 0}
	hidden = {Gen2Battle.PLAYER: true, Gen2Battle.ENEMY: true}


func party_balls(rows: Dictionary) -> void:
	balls = []
	border = []
	for side: int in rows:
		Gen2BattleScreen.add_trainer_hud(side == Gen2Battle.PLAYER, rows[side], game.generation == RomRegistry.GEN1, balls, border)


func busy() -> bool:
	return not _routine.is_empty()


func begin(kind: StringName, side: int, trainer_class: int = 0) -> void:
	var sizes: Array = []
	match kind:
		FAINT:
			sizes.resize(Gen2BattleScreenMap.FAINT_STEPS)
			sizes.fill(0)
		SEND_OUT:
			sizes.assign(Gen2BattleScreenMap.SEND_OUT_SIZES)
			hidden.erase(side)
			party_balls({})
		RETREAT:
			sizes.assign(Gen2BattleScreenMap.RETREAT_SIZES)
		INTRO:
			_intro = Gen2BattleIntro.for_data(game)
		SLIDE:
			sizes.resize(int(Gen2BattleScreenMap.SLIDE_STEPS[side == Gen2Battle.PLAYER]))
			sizes.fill(0)
		RESULT:
			sizes.assign(RESULT_FRAMES)
			pictures["enemy_trainer_pic"] = trainer_class
		PANEL:
			hidden.erase(side)
	_routine = {"kind": kind, "side": side, "sizes": sizes, "delay": 0, "step": 0}


## A frame of `MonFaintedAnimation`, `AnimateSendingOutMon` or `AnimateRetreatingPlayerMon`.
func advance() -> void:
	if _routine.is_empty():
		return
	if int(_routine["delay"]) > 0:
		_routine["delay"] = int(_routine["delay"]) - 1
		return
	if _intro != null:
		_advance_intro()
		return
	var side: int = int(_routine["side"])
	var sizes: Array = _routine["sizes"]
	if sizes.is_empty():
		_end_routine(StringName(_routine["kind"]), side)
		return
	var size: int = int(sizes.pop_front())
	match StringName(_routine["kind"]):
		FAINT:
			Gen2BattleScreenMap.faint_step(map, side == Gen2Battle.PLAYER)
			_routine["delay"] = Gen2BattleScreenMap.FAINT_STEP_FRAMES
		SEND_OUT:
			Gen2BattleScreenMap.send_out_step(map, side == Gen2Battle.PLAYER, game.generation, size, 2 if trainer else 1)
			_routine["delay"] = int(Gen2BattleScreenMap.SEND_OUT_FRAMES[size])
		RETREAT:
			Gen2BattleScreenMap.retreat_step(map, game.generation, size)
			_routine["delay"] = int(Gen2BattleScreenMap.RETREAT_FRAMES[size])
		SLIDE:
			Gen2BattleScreenMap.slide_step(map, side == Gen2Battle.PLAYER)
			_routine["delay"] = Gen2BattleScreenMap.SLIDE_STEP_FRAMES
		RESULT:
			_routine["step"] = int(_routine["step"]) + 1
			Gen2BattleScreenMap.result_trainer_step(map, int(_routine["step"]))
			_routine["delay"] = size


## `InitBattleDisplay`'s `PlaceGraphic` once the bands have met.
func _advance_intro() -> void:
	if _intro.advance_frame() and not _intro.finished():
		return
	_intro = null
	Gen2BattleScreenMap.stamp(map, true, game.generation)
	_routine = {}


func _end_routine(kind: StringName, side: int) -> void:
	if kind == FAINT:
		hidden[side] = true
	elif kind == SLIDE:
		pictures.erase("player_backpic" if side == Gen2Battle.PLAYER else "enemy_trainer_pic")
	_routine = {}


## The panel a `SENT_OUT` event names, drawn once its send-out starts.
func enter(event: Dictionary, game: GameData) -> void:
	var side: int = int(event.get("side", Gen2Battle.PLAYER))
	var prefix: String = "enemy_" if side == Gen2Battle.ENEMY else "player_"
	var species: int = int(event.get("species", 0))
	hidden[side] = true
	Gen2BattleScreenMap.clear_battler(map, side == Gen2Battle.PLAYER, game.generation)
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
			Gen2BattleScreenMap.stamp(map, side == Gen2Battle.PLAYER, game.generation)
			hidden.erase(side)


func over(scene: Dictionary) -> Dictionary:
	scene.merge(shown, true)
	scene.merge(pictures, true)
	scene["trainer_hud_balls"] = balls
	scene["trainer_hud_border"] = border
	if _intro != null:
		scene["raster_scx"] = _intro.offsets()
		scene["intro_sprites"] = _intro.sprites()
		scene["grayscale"] = true
	for side: int in hidden:
		scene["enemy_hud_visible" if side == Gen2Battle.ENEMY else "player_hud_visible"] = false
	if not map.is_empty():
		scene["bg_map"] = map
	return scene
