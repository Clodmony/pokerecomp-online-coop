class_name PokeCoopJohto  ## Gold and Silver's own co-op rules (D130): the core asks here; Red and Blue's stay in PokeCoopPolicy.
extends RefCounted

const STARTERS: Array[int] = [152, 155, 158]  ## CHIKORITA, CYNDAQUIL, TOTODILE
const START_MAP: Vector2i = Vector2i(24, 4)  ## NEW_BARK_TOWN
const TOWN: String = "New Bark Town"
const START_CELLS: Array[Vector2i] = [Vector2i(13, 6), Vector2i(12, 6), Vector2i(14, 6), Vector2i(11, 6)]  ## the house's doorstep first


static func plays(data: GameData) -> bool:
	return data != null and data.generation == RomRegistry.GEN2


static func is_game(game_id: StringName) -> bool:
	return RomRegistry.generation_for(game_id) == RomRegistry.GEN2
