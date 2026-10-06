class_name PokeCoopBattleField
extends Control

## The panel's battle drawn as the cartridge draws one, through [Gen2BattleRenderer]
## and the game's text box, from the host's view alone; commands stay with the
## panel beside it.

const HOLD_FRAMES: int = 50
const GAP: int = 16

var panel: PokeCoopBattlePanel = null
var data: GameData = null
## The world's own player, which the field's sounds and cries go through, and
## what puts the map's music back once a battle closes.
var audio: Gen2AudioPlayer = null
var restore_music: Callable = Callable()
var _music_for: String = ""
var _stage: Control = null
var _renderer: Gen2BattleRenderer = null
var _box: Gen2TextBox = null
## Each `{text}`, `{anim, enemy, after, effectiveness, species}`, `{bar, hp,
## max_hp, snap}` (where an HP bar drains to), `{cry}` or `{fanfare}`, in order.
var _messages: Array = []
## The HP each side's bar shows while the turn plays, and where one is going.
var _drawn_hp: Dictionary = {}
var _bar_goal: Dictionary = {}
var _hp_before: Dictionary = {}
var _hp_seen: Dictionary = {}
var _anim_after: Dictionary = {}
var _anim_data: Gen2BattleAnimData = null
var _anim: Gen2BattleAnimPlayer = null
var _sounding: Dictionary = {}
var _hold: int = 0
var _revision_key: String = ""
var _idle_text: String = ""
var _idle_seen: String = ""
## Who was out on each side when the last view was taken, by species.
var _out: Dictionary = {}
var _frames: float = 0.0


static func over(battle_panel: PokeCoopBattlePanel, game_data: GameData) -> PokeCoopBattleField:
	var out := PokeCoopBattleField.new()
	out.panel = battle_panel
	out.data = game_data
	return out


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.03, 0.05)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_stage = Control.new()
	_stage.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	_stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stage.clip_contents = true
	add_child(_stage)
	_renderer = Gen2BattleRenderer.new()
	_renderer.size = _stage.size
	_stage.add_child(_renderer)
	if not _renderer.set_battle_data(data):
		_renderer.visible = false
	_box = Gen2TextBox.for_screen(data)
	_stage.add_child(_box)
	visible = false


func _process(delta: float) -> void:
	if panel == null:
		return
	var view: Dictionary = panel.battle_view()
	visible = not view.is_empty()
	_follow_music(String(view.get("battle", "")), String(view.get("encounter", "")))
	if not visible:
		panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		panel.position = Vector2(get_viewport_rect().size.x - panel.size.x - GAP, GAP)
		_revision_key = ""
		_idle_seen = ""
		_out = {}
		_hp_seen = {}
		_drawn_hp.clear()
		_bar_goal = {}
		_messages.clear()
		_anim_after = {}
		_anim = null
		return
	_place()
	_take_events(view)
	_renderer.set_view(_with_animation(scene_view(view, data)))
	_frames += delta * 60.0
	while _frames >= 1.0:
		_frames -= 1.0
		_advance_text()


## Whether the last turn is still being shown: its lines, animations or bars.
func is_playing() -> bool:
	return visible and (not _messages.is_empty() or _anim != null or not _bar_goal.is_empty() \
		or not _anim_after.is_empty() or _box.is_revealing())


## `PlayBattleMusic` for a battle as it opens, a trainer's by the class and index
## its encounter id names, and the map's music back once it is closed.
func _follow_music(battle_id: String, encounter: String) -> void:
	if battle_id == _music_for or audio == null:
		return
	_music_for = battle_id
	if battle_id.is_empty():
		if restore_music.is_valid():
			restore_music.call()
		return
	var parts: PackedStringArray = encounter.split(":")
	var trainer: bool = parts.size() == 3 and parts[0] == "trainer"
	var record: Dictionary = data.world_audio(&"music", Gen2Battle.battle_music(
		Gen2Battle.BATTLETYPE_NORMAL, int(parts[1]) if trainer else 0, int(parts[2]) if trainer else 0,
		Gen2WorldRadio.LANDMARK_SPECIAL, 0, false
	))
	if not record.is_empty():
		audio.play_record(record, &"battle_music", data.audio_assets())


## At a whole multiple: left of the panel on a wide window, above it on a tall one.
func _place() -> void:
	var room: Vector2 = get_viewport_rect().size
	var tall: bool = room.y > room.x
	var across: float = room.x - GAP * 2 - (0.0 if tall else PokeCoopBattlePanel.WIDTH + GAP)
	var down: float = (room.y * 0.6 if tall else room.y) - GAP * 2
	var factor: int = maxi(1, int(minf(across / Gen2Screen.WIDTH, down / Gen2Screen.HEIGHT)))
	_stage.scale = Vector2(factor, factor)
	var shown: Vector2 = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT) * factor
	_stage.position = (Vector2((room.x - shown.x) / 2.0, GAP) if tall \
		else Vector2(GAP, (room.y - shown.y) / 2.0)).floor()
	if tall:
		panel.position = Vector2(maxf(GAP, (room.x - panel.size.x) / 2.0), GAP * 2 + shown.y).floor()


## What [Gen2BattleRenderer] draws for [param view]: the enemy and the ally out.
static func scene_view(view: Dictionary, game: GameData) -> Dictionary:
	var enemy: Dictionary = view.get("enemy", {})
	var allies: Array = view.get("allies", [])
	var active: int = int(view.get("active", 0))
	var ally: Dictionary = allies[active] if active >= 0 and active < allies.size() else {}
	var out: Dictionary = {"enemy_hud_visible": true, "player_hud_visible": not ally.is_empty()}
	for side: Array in [["enemy", enemy], ["player", ally]]:
		var mon: Dictionary = side[1]
		var prefix: String = side[0]
		out[prefix + "_species"] = int(mon.get("species", 0))
		out[prefix + "_name"] = _species_name(game, int(mon.get("species", 0)))
		out[prefix + "_level"] = int(mon.get("level", 0))
		out[prefix + "_hp"] = int(mon.get("hp", 0))
		out[prefix + "_max_hp"] = int(mon.get("max_hp", 0))
		out[prefix + "_status"] = int(mon.get("status", 0))
	return out


static func _species_name(game: GameData, species: int) -> String:
	return String(game.species(species).get("name", "")) if game != null and species > 0 else ""


## A new revision's events become the messages the box plays in order.
func _take_events(view: Dictionary) -> void:
	var idle: String = _waiting_text(view)
	if idle != _idle_seen:
		_idle_seen = idle
		_idle_text = idle
	var key: String = "%s/%d/%s" % [view.get("battle", ""), int(view.get("revision", 0)), view.get("outcome", "")]
	if key == _revision_key:
		return
	_revision_key = key
	if int(view.get("revision", 0)) == 0:
		_open(view)
	_hp_before = _hp_seen
	if _drawn_hp.is_empty() and not (view.get("events", []) as Array).is_empty():
		for side: int in _hp_before:
			_drawn_hp[side] = float(_hp_before[side])
	var out: Dictionary = _out if not _out.is_empty() else out_now(view)
	for event: Dictionary in view.get("events", []):
		if StringName(event.get("type", &"")) == Gen2Battle.HP_BAR:
			_messages.append({
				"bar": int(event.get("side", 0)), "hp": int(event.get("hp", 0)),
				"max_hp": int(event.get("max_hp", 1)), "snap": bool(event.get("snap", false)),
			})
		if StringName(event.get("type", &"")) == Gen2Battle.SENT_OUT:
			out[int(event.get("side", 0))] = species_at(view, int(event.get("side", 0)), int(event.get("index", 0)))
		if StringName(event.get("type", &"")) == Gen2Battle.ANIMATION:
			var enemy_turn: bool = bool(event.get("enemy_turn", false))
			_messages.append({
				"anim": int(event.get("index", 0)), "enemy": enemy_turn,
				"after": int(event.get("after_anim", 0)),
				"effectiveness": int(event.get("effectiveness", Gen2Layout.MATCHUP_EFFECTIVE)),
				"species": int(out.get(Gen2Battle.ENEMY if enemy_turn else Gen2Battle.PLAYER, 0)),
			})
		var line: String = message(event, out, data, _player_names())
		var sent: bool = StringName(event.get("type", &"")) == Gen2Battle.SENT_OUT
		var rows: PackedStringArray = line.split("\n", false)
		for page: int in range(0, rows.size(), 2):
			_messages.append({"text": "\n".join(rows.slice(page, page + 2))})
		if sent:
			_messages.append({"cry": int(out.get(int(event.get("side", 0)), 0))})
	if String(view.get("outcome", "")) == "won":
		_messages.append({"fanfare": bool(view.get("trainer", false))})
	_out = out_now(view)
	_idle_text = idle
	var allies: Array = view.get("allies", [])
	var active: int = int(view.get("active", 0))
	_hp_seen = {
		Gen2Battle.ENEMY: int((view.get("enemy", {}) as Dictionary).get("hp", 0)),
		Gen2Battle.PLAYER: int((allies[active] as Dictionary).get("hp", 0)) if active < allies.size() else 0,
	}


## A battle seen from its start opens the way the cartridge's does: the wild
## Pokémon appears with its cry, then the first ally is sent out with its own.
func _open(view: Dictionary) -> void:
	var opening: Dictionary = out_now(view)
	if not bool(view.get("trainer", false)):
		var wild: int = int(opening[Gen2Battle.ENEMY])
		_messages.append({"text": "Wild %s\nappeared!" % _species_name(data, wild)})
		_messages.append({"cry": wild})
	var ally: int = int(opening[Gen2Battle.PLAYER])
	_messages.append({"text": "Go! %s!" % _species_name(data, ally)})
	_messages.append({"cry": ally})


## The species out on each side in [param view].
static func out_now(view: Dictionary) -> Dictionary:
	return {
		Gen2Battle.PLAYER: species_at(view, Gen2Battle.PLAYER, int(view.get("active", 0))),
		Gen2Battle.ENEMY: int((view.get("enemy", {}) as Dictionary).get("species", 0)),
	}


static func species_at(view: Dictionary, side: int, index: int) -> int:
	var rows: Array = view.get("enemy_party", []) if side == Gen2Battle.ENEMY else \
		(view.get("allies", []) as Array).map(func(ally: Dictionary) -> int: return int(ally["species"]))
	return int(rows[index]) if index >= 0 and index < rows.size() else 0


func _advance_text() -> void:
	_box.advance_frame()
	if _anim != null:
		_anim.advance_frame()
		_play_sounds()
		if _anim.finished() or _anim.failed():
			_anim = _applying()
		return
	if not _bar_goal.is_empty():
		_drain_bar()
		return
	if _box.visible and _box.is_revealing():
		return
	if _hold > 0:
		_hold -= 1
		return
	if not _messages.is_empty():
		_take_step(_messages.pop_front())
	elif not _idle_text.is_empty():
		_show(_idle_text)
		_idle_text = ""
	if _messages.is_empty() and _bar_goal.is_empty() and _anim == null:
		_drawn_hp.clear()


func _take_step(step: Dictionary) -> void:
	if step.has("text"):
		_show(String(step["text"]))
		_hold = HOLD_FRAMES if _messages.is_empty() or not (_messages[0] as Dictionary).has("anim") else 0
	elif step.has("anim"):
		_sounding = step
		_anim_after = step if int(step["after"]) != 0 and int(step["anim"]) < Gen2BattleScreen.ANIM_MOVE_LIMIT else {}
		_anim = _animation(step)
		if _anim == null:
			_anim = _applying()
		_play_sounds()
	elif step.has("bar"):
		var side: int = int(step["bar"])
		_drawn_hp[side] = float(_drawn_hp.get(side, _hp_before.get(side, step["hp"])))
		_bar_goal = {} if bool(step["snap"]) else step
		if bool(step["snap"]):
			_drawn_hp[side] = float(step["hp"])
	else:
		_play_cue(step)
		_hold = HOLD_FRAMES


## A pixel of the bar's forty-eight a frame, the way `UpdateHPBar` drains it.
func _drain_bar() -> void:
	var side: int = int(_bar_goal["bar"])
	var goal: float = float(_bar_goal["hp"])
	var now: float = float(_drawn_hp[side])
	_drawn_hp[side] = move_toward(now, goal, maxf(1.0, float(_bar_goal["max_hp"]) / 48.0))
	if is_equal_approx(float(_drawn_hp[side]), goal):
		_bar_goal = {}


## The cartridge's animation for an `ANIMATION` step, a move's or a status's; null
## for a send-out, a ball, the battle scene off or a cache without animations.
func _animation(step: Dictionary) -> Gen2BattleAnimPlayer:
	if _anim_data == null:
		_anim_data = Gen2BattleAnimData.from_game_data(data)
	var index: int = int(step["anim"])
	if _anim_data == null or not _anim_data.gen1() \
			or (index < Gen2BattleScreen.ANIM_MOVE_LIMIT and not Gen2OptionsStore.current().battle_scene):
		return null
	var enemy_turn: bool = bool(step["enemy"])
	var row: int = index - 1
	if index >= Gen2BattleScreen.ANIM_MOVE_LIMIT:
		var pair: Variant = Gen2BattleScreen.GEN1_ANIM_IDS.get(index, null)
		row = int((pair as Array)[1 if enemy_turn else 0]) - 1 if pair is Array else -1
	return _seeded(Gen2BattleAnimPlayer.create_gen1(_anim_data, row, enemy_turn) if row >= 0 else null)


## `PlayHitSound`, then the move's shake or blink from `AnimationTypePointerTable`.
func _applying() -> Gen2BattleAnimPlayer:
	var step: Dictionary = _anim_after
	_anim_after = {}
	if step.is_empty():
		return null
	var after: int = int(step["after"])
	var effectiveness: int = int(step["effectiveness"])
	var damage: bool = after in [Gen2BattleAnimPlayer.AFTER_ANIM_ENEMY_DAMAGE, Gen2BattleAnimPlayer.AFTER_ANIM_PLAYER_DAMAGE]
	if damage and effectiveness != 0 and audio != null:
		var sfx: int = Gen2Sfx.SFX_SUPER_EFFECTIVE if effectiveness > Gen2Layout.MATCHUP_EFFECTIVE else \
			(Gen2Sfx.SFX_NOT_VERY_EFFECTIVE if effectiveness < Gen2Layout.MATCHUP_EFFECTIVE else Gen2Sfx.SFX_DAMAGE)
		var record: Dictionary = data.world_audio(&"sfx", sfx)
		if not record.is_empty():
			audio.play_record(record, &"waited_sfx", data.audio_assets())
	var pair: Variant = Gen2BattleScreen.GEN1_APPLYING_TYPES.get(after, null)
	if not pair is Array:
		return null
	var effect: int = int(data.move(int(step["anim"])).get("effect", 0))
	var kind: int = int((pair as Array)[1 if effect != 0 else 0])
	return _seeded(Gen2BattleAnimPlayer.create_gen1_applying(_anim_data, kind, bool(step["enemy"])))


static func _seeded(player: Gen2BattleAnimPlayer) -> Gen2BattleAnimPlayer:
	if player != null:
		player.background().set_bg_map(Gen2BattleScreenMap.seeded())
	return player


## What the animation's last frame asked to hear: `GetMoveSound`'s row, a
## `IsCryMove` being the attacker's own cry with the row's offsets.
func _play_sounds() -> void:
	if audio == null or _anim == null:
		return
	for command: Dictionary in _anim.frame_commands():
		var operands: Array = command.get("operands", [])
		var record: Dictionary = {}
		match StringName(command["name"]):
			Gen2BattleAnimPlayer.GEN1_SOUND:
				record = data.gen1_sound(-1, int(operands[0]))
			Gen2BattleAnimPlayer.GEN1_MOVE_SOUND:
				record = _move_sound(int(operands[0]))
		if not record.is_empty():
			audio.play_record(record, &"sound", data.audio_assets())


## A send-out's cry, or `PlayVictoryMusic`: the wild or the trainer fanfare.
func _play_cue(cue: Dictionary) -> void:
	if audio == null:
		return
	if cue.has("cry"):
		var cry: Dictionary = data.species_cry(int(cue["cry"]))
		if not cry.is_empty():
			audio.play_record(cry, &"cry", data.audio_assets())
		return
	var music: int = Gen1Layout.MUSIC_DEFEATED_TRAINER if bool(cue["fanfare"]) else Gen1Layout.MUSIC_DEFEATED_WILD_MON
	var record: Dictionary = data.gen1_sound(Gen1Layout.VICTORY_MUSIC_BANK, music)
	if not record.is_empty():
		audio.play_record(record, &"map_music", data.audio_assets(), true)


func _move_sound(move: int) -> Dictionary:
	var row: Dictionary = _anim.data().gen1_move_sound(move)
	if row.is_empty():
		return {}
	var cry: bool = Gen1Layout.CRY_MOVES.has(move)
	var record: Dictionary = data.species_cry(int(_sounding.get("species", 0))) if cry \
		else data.gen1_sound(-1, int(row["sound_id"]))
	if record.is_empty():
		return {}
	record["cry_pitch"] = ((int(record["cry_pitch"]) if cry else 0) + int(row["pitch"])) & 0xFF
	record["cry_length"] = ((int(record["cry_length"]) if cry else 0) + int(row["tempo"])) & 0xFF
	return record


## The running animation's tilemap and objects, and the bars as far as they
## have drained, over [param view].
func _with_animation(view: Dictionary) -> Dictionary:
	for side: int in _drawn_hp:
		view["enemy_hp" if side == Gen2Battle.ENEMY else "player_hp"] = roundi(float(_drawn_hp[side]))
	if _anim == null:
		return view
	var background: Gen2BattleAnimBackground = _anim.background()
	view["bg_map"] = background.bg_map
	view["anim_sprites"] = _anim.sprites()
	view["anim_tiles"] = _anim.tiles()
	view["anim_obp0"] = background.obp0
	view["bg_palette_maps"] = background.bg_palette_maps
	view["ob_palette_maps"] = background.ob_palette_maps
	view["raster_scx"] = _raster(background, Gen2BattleAnimBackground.LCDC_SCX)
	view["raster_scy"] = _raster(background, Gen2BattleAnimBackground.LCDC_SCY)
	return view


static func _raster(background: Gen2BattleAnimBackground, register: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var base: int = background.scx if register == Gen2BattleAnimBackground.LCDC_SCX else background.scy
	var windowed: bool = background.lcdc_pointer == register
	if base == 0 and not windowed:
		return out
	out.resize(Gen2BattleAnimBackground.SCREEN_LINES)
	for line: int in Gen2BattleAnimBackground.SCREEN_LINES:
		out[line] = int(background.ly_overrides[line]) if windowed else base
	return out


func _show(text: String) -> void:
	_box.visible = true
	_box.show_text(text, false)


func _waiting_text(view: Dictionary) -> String:
	var outcome: String = String(view.get("outcome", ""))
	if not outcome.is_empty():
		return "" if outcome != "lost" else "%s is out of\nuseable #MON!" % _player_name(panel.client.player_id)
	var controller: String = String(view.get("controller", ""))
	var allies: Array = view.get("allies", [])
	var active: int = int(view.get("active", 0))
	var out_now: String = _species_name(data, int((allies[active] as Dictionary).get("species", 0))) \
		if active >= 0 and active < allies.size() else ""
	if bool(view.get("paused", false)):
		return "%s is away.\nWaiting..." % _player_name(controller)
	if controller == panel.client.player_id:
		return "What will\n%s do?" % out_now
	return "%s is\ndeciding..." % _player_name(controller)


func _player_name(player_id: String) -> String:
	var view: Dictionary = (panel.client.state.get("players", {}) as Dictionary).get(player_id, {})
	return String(view.get("name", player_id))


## An event's line in Red and Blue's words, [param out] being who is out on each side.
static func message(event: Dictionary, out: Dictionary, game: GameData, names: Dictionary = {}) -> String:
	var side: int = int(event.get("side", Gen2Battle.PLAYER))
	var who_acted: String = String(names.get(String(event.get("player", "")), ""))
	var who: String = ("Enemy " if side == Gen2Battle.ENEMY else "") + _species_name(game, int(out.get(side, 0)))
	match StringName(event.get("type", &"")):
		Gen2Battle.USED_MOVE:
			return "%s\nused %s!" % [who, String(game.move(int(event.get("move", 0))).get("name", ""))]
		Gen2Battle.MISSED:
			return "%s's\nattack missed!" % who
		Gen2Battle.CRITICAL_HIT:
			return "Critical hit!"
		Gen2Battle.EFFECTIVENESS:
			return "It's super\neffective!" if int(event.get("effectiveness", 0)) > Gen2Layout.MATCHUP_EFFECTIVE \
				else "It's not very\neffective..."
		Gen2Battle.FAINTED:
			return "%s\nfainted!" % who
		Gen2Battle.SENT_OUT:
			return "Go! %s!" % who if side == Gen2Battle.PLAYER else ""
		Gen2Battle.CAUGHT:
			return "All right!\n%s was caught!" % _species_name(game, int(out.get(Gen2Battle.ENEMY, 0)))
		Gen2Battle.FLED:
			return "Got away safely!"
		Gen2Battle.EXP_GAINED:
			return "%s gained\n%d EXP. Points!" % [event.get("name", ""), int(event.get("amount", 0))]
		Gen2Battle.GREW_LEVEL:
			return "%s grew\nto level %d!" % [event.get("name", ""), int(event.get("new_level", 0))]
		Gen2Battle.MOVE_LEARNED:
			return "%s learned\n%s!" % [event.get("name", ""), String(game.move(int(event.get("move", 0))).get("name", ""))]
		Gen2Battle.MOVE_OFFERED:
			return "%s is trying\nto learn %s!" % [event.get("name", ""), String(game.move(int(event.get("move", 0))).get("name", ""))]
		PokeCoopBattleSession.JOINED:
			return "%s joined\nthe battle!" % who_acted
		PokeCoopBattleSession.ITEM_USED:
			return "%s used\n%s!" % [who_acted, game.item_name(int(event.get("item", 0)))]
		PokeCoopBattleSession.BALL_THROWN:
			return _throw_line(event, who_acted, _species_name(game, int(out.get(Gen2Battle.ENEMY, 0))), game)
	return ""


## `ItemUseBall`'s lines: the throw, then the catch or how close it came.
static func _throw_line(event: Dictionary, thrower: String, wild: String, game: GameData) -> String:
	var thrown: String = "%s used\n%s!" % [thrower, game.item_name(int(event.get("ball", 0)))]
	if bool(event.get("caught", false)):
		return thrown + "\nAll right!\n%s was caught!" % wild
	var near: Array[String] = [
		"You missed the\nPOKéMON!", "Darn! The POKéMON\nbroke free!", "Aww! It appeared\nto be caught!",
		"Shoot! It was so\nclose too!",
	]
	return thrown + "\n" + near[clampi(int(event.get("wobbles", 0)), 0, near.size() - 1)]


func _player_names() -> Dictionary:
	var out: Dictionary = {}
	var everyone: Dictionary = panel.client.state.get("players", {}) if panel != null else {}
	for player_id: String in everyone:
		out[player_id] = String((everyone[player_id] as Dictionary).get("name", player_id))
	return out
