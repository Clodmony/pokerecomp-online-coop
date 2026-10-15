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


const DAY_SECONDS: int = 86400
const CLOCK_CYCLE: float = DAY_SECONDS * Gen2WorldClock.CUR_DAY_WRAP  ## `wCurDay`'s twenty weeks, a whole number of them
static var first_reading: Dictionary = {}  ## where a new campaign's clock starts in place of the host's own time: a tool's `clock=HH:MM[:D]`


static func wind(clock: Dictionary, now: float) -> Dictionary:  ## the campaign's one clock (D128, D133), held where it was if the host's clock went back
	if clock.is_empty():
		return set_to(first_reading if not first_reading.is_empty() else wall_reading(), now)
	var out: Dictionary = moved(clock, 0.0)
	out["stamp"] = minf(float(clock.get("stamp", now)), now)
	return out


static func wall_reading() -> Dictionary:
	var local: Dictionary = Time.get_datetime_dict_from_system()
	return {"day": int(local["weekday"]), "hour": int(local["hour"]), "minute": int(local["minute"]), "second": int(local["second"])}


static func set_to(reading_now: Dictionary, now: float) -> Dictionary:
	var out: Dictionary = moved(reading_now, 0.0)
	out["stamp"] = now
	return out


static func reading(clock: Dictionary, now: float) -> Dictionary:
	return moved(clock, now - float(clock.get("stamp", now)))


static func moved(from: Dictionary, seconds: float) -> Dictionary:  ## the reading [param seconds] later; never earlier
	var day: int = int(from.get("day", 0))
	var total: float = fposmod(_seconds(from) + maxf(seconds, 0.0), CLOCK_CYCLE)
	var days: int = int(total / DAY_SECONDS)
	var within: float = total - days * DAY_SECONDS
	return {
		"day": posmod(day - int(from.get("cur_day", day)) + days, Gen2WorldClock.DAYS_PER_WEEK), "hour": int(within / 3600.0),
		"minute": int(within / 60.0) % Gen2WorldClock.MINUTES_PER_HOUR, "cur_day": days, "second": fmod(within, 60.0),
	}


static func behind(shown: Dictionary, told: Dictionary) -> float:  ## how far [param told] is ahead of [param shown], the short way round
	var gap: float = fposmod(_seconds(told) - _seconds(shown), CLOCK_CYCLE)
	return gap - CLOCK_CYCLE if gap > CLOCK_CYCLE / 2.0 else gap


static func same_week(first: Dictionary, second: Dictionary) -> bool:  ## whether both name the same weekday for the same `wCurDay`
	return posmod(int(first.get("day", 0)) - int(first.get("cur_day", 0)), Gen2WorldClock.DAYS_PER_WEEK) \
		== posmod(int(second.get("day", 0)) - int(second.get("cur_day", 0)), Gen2WorldClock.DAYS_PER_WEEK)


static func _seconds(from: Dictionary) -> float:
	var day: int = int(from.get("day", 0))
	return posmod(int(from.get("cur_day", day)), Gen2WorldClock.CUR_DAY_WRAP) * DAY_SECONDS + int(from.get("hour", 0)) * 3600 \
		+ int(from.get("minute", 0)) * 60 + clampf(float(from.get("second", 0.0)), 0.0, 59.999)


static func sane_clock(raw: Variant) -> Dictionary:  ## a saved clock in its own types, or none
	if not raw is Dictionary or not (raw as Dictionary).has("stamp") or not ["day", "hour", "minute"].all(
			func(key: String) -> bool: return (raw as Dictionary).get(key) is int or (raw as Dictionary).get(key) is float):
		return {}
	return set_to(raw, float(raw["stamp"]))
