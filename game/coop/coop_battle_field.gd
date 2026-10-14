class_name PokeCoopBattleField
extends Control

## The panel's battle drawn on the world's own screen through [Gen2BattleRenderer], the text box and [PokeCoopBattleMenu].

const HOLD_FRAMES: int = 50
const BOX_COLUMNS: int = 18
const WORDED: Array[StringName] = [
	Gen2Battle.CAUGHT, Gen2Battle.MOVE_OFFERED, PokeCoopBattleSession.JOINED,
	PokeCoopBattleSession.ITEM_USED, PokeCoopBattleSession.BALL_THROWN, Gen2Battle.SWITCH_OFFERED,
]

var panel: PokeCoopBattlePanel = null
var data: GameData = null
var audio: Gen2AudioPlayer = null
var restore_music: Callable = Callable()
var _music_for: String = ""
var _renderer: Gen2BattleRenderer = null
var _box: Gen2TextBox = null
var _messages: Array = []
var _drawn_hp: Dictionary = {}
var _bar_goal: Dictionary = {}
var _hp_before: Dictionary = {}
var _hp_seen: Dictionary = {}
var _anim_after: Dictionary = {}
var _board := PokeCoopBattleStage.new()
var _words: Gen2BattleScreen = null
var _offered: bool = false
var _scene_seen: Dictionary = {}
var _anim_data: Gen2BattleAnimData = null
var _anim: Gen2BattleAnimPlayer = null
var _sounding: Dictionary = {}
var _sound_watch: Dictionary = {}
var _sound_wait: bool = false
var _hold: int = 0
var _revision_key: String = ""
var _idle_text: String = ""
var _idle_seen: String = ""
var _out: Dictionary = {}
var _frames: float = 0.0
var _menu_layer: TextureRect = null
var _menu_drawn: String = ""
var _clicks: int = 0
var _screen: Gen2Screen = null
var _masked: bool = false
var _fanfared: bool = false
var _enemy_down: bool = false
var _dot_staged: bool = false


static func over(battle_panel: PokeCoopBattlePanel, game_data: GameData) -> PokeCoopBattleField:
	var out := PokeCoopBattleField.new()
	out.panel = battle_panel
	out.data = game_data
	return out


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	_renderer = Gen2BattleRenderer.new()
	_renderer.size = size
	add_child(_renderer)
	if not _renderer.set_battle_data(data):
		_renderer.visible = false
	_box = Gen2TextBox.for_screen(data)
	add_child(_box)
	_menu_layer = TextureRect.new()
	_menu_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_menu_layer.visible = false
	add_child(_menu_layer)
	visible = false


func _process(delta: float) -> void:
	if panel == null:
		return
	var view: Dictionary = panel.battle_view()
	_stand(not view.is_empty())
	_follow_music(view)
	if not visible:
		_revision_key = ""
		_idle_seen = ""
		_scene_seen = {}
		_box.visible = false
		_out = {}
		_hp_seen = {}
		_drawn_hp.clear()
		_bar_goal = {}
		_messages.clear()
		_anim_after = {}
		_anim = null
		return
	if _screen != null:
		_screen.set_white(false)
	_take_events(view)
	var scene: Dictionary = scene_view(view, data)
	_renderer.set_view(_with_animation(scene.duplicate()))
	_frames += delta * 60.0
	while _frames >= 1.0:
		_frames -= 1.0
		_advance_text()
		if _menu_layer.visible:
			panel.menu.advance()
	if not is_playing():
		_board.settle(scene)
	_draw_menu()


func _stand(up: bool) -> void:
	if up == visible:
		return
	visible = up
	_screen = Gen2Screen.owner_of(self) if up else _screen
	if _screen == null:
		return
	if up:
		get_parent().move_child(self, -1)
		_masked = _screen.interface_masked
		_screen.interface_masked = true
		return
	_screen.interface_masked = _masked
	_screen.clear_field()


## `MenuClickSound` for each press that took.
func _draw_menu() -> void:
	var menu: PokeCoopBattleMenu = panel.menu
	if menu.clicks != _clicks:
		_clicks = menu.clicks
		_play_cue({"sound": Gen1Sfx.SFX_PRESS_AB})
	var shown: bool = not is_playing() and menu.page != PokeCoopBattleMenu.NONE
	_menu_layer.visible = shown
	var drawn: String = menu.signature() if shown else ""
	if drawn == _menu_drawn:
		return
	_menu_drawn = drawn
	if shown:
		_menu_layer.texture = Gen2PicImage.refreshed_texture(_menu_layer.texture as ImageTexture, menu.image())
		_menu_layer.size = size


func say(line: String) -> void:
	for page: String in pages(line):
		_messages.append({"text": page})


func is_playing() -> bool:
	var view: Dictionary = panel.battle_view() if panel != null else {}
	return visible and (not _messages.is_empty() or _anim != null or not _bar_goal.is_empty() \
		or not _anim_after.is_empty() or _board.busy() or _box.is_revealing() or _hold > 0 or _sound_wait \
		or (not view.is_empty() and _key_of(view) != _revision_key))


## `PlayBattleMusic` as a battle opens, a trainer's by class and index; the map's after.
func _follow_music(view: Dictionary) -> void:
	var battle_id: String = String(view.get("battle", ""))
	if battle_id == _music_for or audio == null:
		return
	_music_for = battle_id
	if battle_id.is_empty():
		if restore_music.is_valid():
			restore_music.call()
		return
	var record: Dictionary = data.world_audio(&"music", Gen2Battle.battle_music(
		Gen2Battle.BATTLETYPE_NORMAL, int(view.get("trainer_class", 0)), int(view.get("trainer_index", 0)),
		Gen2WorldRadio.LANDMARK_SPECIAL, 0, false
	))
	if not record.is_empty():
		audio.play_record(record, &"battle_music", data.audio_assets())


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
		out[prefix + "_name"] = String(mon.get("name", "")) if not String(mon.get("name", "")).is_empty() \
			else _species_name(game, int(mon.get("species", 0)))
		out[prefix + "_level"] = int(mon.get("level", 0))
		out[prefix + "_hp"] = int(mon.get("hp", 0))
		out[prefix + "_max_hp"] = int(mon.get("max_hp", 0))
		out[prefix + "_status"] = int(mon.get("status", 0))
		out[prefix + "_substitute"] = bool(mon.get("substitute", false))
		out[prefix + "_minimized"] = bool(mon.get("minimized", false))
	return out


static func _species_name(game: GameData, species: int) -> String:
	return String(game.species(species).get("name", "")) if game != null and species > 0 else ""


## A new revision's events become the messages the box plays in order.
func _take_events(view: Dictionary) -> void:
	var idle: String = _waiting_text(view)
	if idle != _idle_seen:
		_idle_seen = idle
		_idle_text = idle
	var key: String = _key_of(view)
	if key == _revision_key:
		return
	var same_turn: bool = _revision_key.get_slice("/", 0) == String(view.get("battle", "")) \
		and _revision_key.get_slice("/", 1) == str(int(view.get("revision", 0)))
	if _revision_key.get_slice("/", 0) != String(view.get("battle", "")):
		_begin_battle(view)
	_revision_key = key
	if same_turn:
		if String(view.get("outcome", "")) == "won":
			_queue_victory(view)
		return
	if int(view.get("revision", 0)) == 0:
		_open(view)
	_hp_before = _hp_seen
	var events: Array = view.get("events", [])
	if _drawn_hp.is_empty() and not events.is_empty():
		for side: int in _hp_before:
			_drawn_hp[side] = float(_hp_before[side])
	if not events.is_empty() and _messages.is_empty():
		_board.shown = _scene_seen.duplicate()
	var out: Dictionary = _out if not _out.is_empty() else out_now(view)
	var names: Dictionary = _player_names()
	for event: Dictionary in events:
		_queue(event, out, view)
		var paged: PackedStringArray = pages(_line_for(event, out, names, _trainer_name(view)))
		for page: int in paged.size():
			_messages.append({"text": paged[page]})
			if page == 0 and StringName(event.get("type", &"")) == PokeCoopBattleSession.BALL_THROWN:
				_messages.append_array(toss_steps(event))
	if String(view.get("outcome", "")) == "won":
		_queue_victory(view)
	_out = out_now(view)
	_scene_seen = _panels(scene_view(view, data))
	_idle_text = idle
	var allies: Array = view.get("allies", [])
	var active: int = int(view.get("active", 0))
	_hp_seen = {
		Gen2Battle.ENEMY: int((view.get("enemy", {}) as Dictionary).get("hp", 0)),
		Gen2Battle.PLAYER: int((allies[active] as Dictionary).get("hp", 0)) if active < allies.size() else 0,
	}


## The field's own line for the events it words, the screen's for the rest and a trainer's switch.
func _line_for(event: Dictionary, out: Dictionary, names: Dictionary, trainer: String) -> String:
	if StringName(event.get("type", &"")) in WORDED:
		return message(event, out, data, names, trainer)
	return _screen_line(event, out, trainer)


func _screen_line(event: Dictionary, out: Dictionary, trainer: String) -> String:
	if _words == null:
		_words = Gen2BattleScreen.new()
		_words.set("_data", data)
		_words.set("_injected_rules", Gen2Rules.new())
	_words.set("_player", int(out.get(Gen2Battle.PLAYER, 0)))
	_words.set("_enemy", int(out.get(Gen2Battle.ENEMY, 0)))
	_words.set("_player_nick", String(out.get(name_key(Gen2Battle.PLAYER), "")))
	_words.set("_enemy_nick", String(out.get(name_key(Gen2Battle.ENEMY), "")))
	_words.set("_world_battle_request", {"trainer_name": trainer})
	var named: Dictionary = event.duplicate()
	named["type"] = StringName(event.get("type", &""))
	return String(_words.call("_describe", named))


func _exit_tree() -> void:
	if _words != null:
		_words.free()
		_words = null


static func _key_of(view: Dictionary) -> String:
	return "%s/%d/%s" % [view.get("battle", ""), int(view.get("revision", 0)), view.get("outcome", "")]


func _begin_battle(view: Dictionary) -> void:
	_board.reset(data, bool(view.get("trainer", false)))
	_messages.clear()
	_bar_goal = {}
	_drawn_hp.clear()
	_anim = null
	_anim_after = {}
	_hold = 0
	_sound_wait = false
	_fanfared = false
	_enemy_down = false
	_offered = false
	_box.visible = false


## The sliding intro, `BattleStartMessage` and `DoBattle`'s opening, for a battle seen from its start.
func _open(view: Dictionary) -> void:
	var opening: Dictionary = out_now(view)
	var enemy: int = int(opening[Gen2Battle.ENEMY])
	var mine: Array = ball_tiles(view, Gen2Battle.PLAYER, panel.client.player_id)
	_board.open(int(view.get("trainer_class", 0)))
	_messages.append({"stage": PokeCoopBattleStage.INTRO, "side": Gen2Battle.ENEMY})
	if bool(view.get("trainer", false)):
		_messages.append({"balls": {Gen2Battle.PLAYER: mine, Gen2Battle.ENEMY: ball_tiles(view, Gen2Battle.ENEMY, "")}})
		_messages.append({"text": _de(data, "%s wants\nto fight!") % _trainer_name(view)})
		_messages.append({"balls": {}})
		_messages.append({"stage": PokeCoopBattleStage.SLIDE, "side": Gen2Battle.ENEMY})
		_messages.append({"text": _de(data, "%s sent\nout %s!") % [_trainer_name(view), _species_name(data, enemy)]})
		_messages.append_array(send_out_steps(Gen2Battle.ENEMY))
		_messages.append({"cry": enemy})
	else:
		_messages.append({"cry": enemy})
		_messages.append({"balls": {Gen2Battle.PLAYER: mine}})
		_messages.append({"text": _de(data, "Wild %s\nappeared!") % _species_name(data, enemy)})
		_messages.append({"balls": {}})
		_messages.append({"stage": PokeCoopBattleStage.PANEL, "side": Gen2Battle.ENEMY})
	var ally: int = int(opening[Gen2Battle.PLAYER])
	_messages.append({"hold": Gen2BattleScreen.PLAYER_ENTRANCE_FRAMES})
	_messages.append({"stage": PokeCoopBattleStage.SLIDE, "side": Gen2Battle.PLAYER})
	_messages.append({"text": _de(data, "Go! %s!") % _species_name(data, ally)})
	_messages.append_array(send_out_steps(Gen2Battle.PLAYER))
	_messages.append({"cry": ally})


## An event's steps besides its line; a faint plays ahead of it, as `MonFaintedAnimation` does, a wild win's fanfare after it.
func _queue(event: Dictionary, out: Dictionary, view: Dictionary) -> void:
	var side: int = int(event.get("side", 0))
	var prefix: String = "enemy_" if side == Gen2Battle.ENEMY else "player_"
	if (event.get("statuses", []) as Array).size() == 2:
		_messages.append({"panel": {"player_status": int(event["statuses"][0]), "enemy_status": int(event["statuses"][1])}})
	match StringName(event.get("type", &"")):
		Gen2Battle.TRANSFORMED:
			out[side] = int(event.get("species", out.get(side, 0)))
			_messages.append({"panel": {prefix + "species": out[side]}})
		Gen2Battle.SUBSTITUTE_PIC:
			_messages.append({"panel": {prefix + "substitute": bool(event.get("raised", false))}})
		Gen2Battle.MINIMIZED:
			_messages.append({"panel": {prefix + "minimized": true}})
		Gen2Battle.HP_BAR:
			_messages.append({
				"bar": side, "hp": int(event.get("hp", 0)),
				"max_hp": int(event.get("max_hp", 1)), "snap": bool(event.get("snap", false)),
			})
		Gen2Battle.SENT_OUT:
			out[side] = int(event.get("species", species_at(view, side, int(event.get("index", 0)))))
			out[name_key(side)] = String(event.get("name", ""))
			if side == Gen2Battle.ENEMY and _enemy_down and bool(view.get("trainer", false)):
				_messages.append({"balls": {} if _offered else {Gen2Battle.ENEMY: ball_tiles(view, Gen2Battle.ENEMY, "")}})
			_enemy_down = false if side == Gen2Battle.ENEMY else _enemy_down
			_offered = _offered and side != Gen2Battle.ENEMY
			_messages.append({"enter": event})
		Gen2Battle.FAINTED:
			_enemy_down = _enemy_down or side == Gen2Battle.ENEMY
			_messages.append({"stage": PokeCoopBattleStage.FAINT, "side": side})
			_messages.append_array(faint_sounds(side, int(out.get(side, 0)), bool(view.get("trainer", false))))
			if side == Gen2Battle.ENEMY and not bool(view.get("trainer", false)) and String(view.get("outcome", "")) == "won":
				_messages.append({"fanfare": false, "gym": false})
				_fanfared = true
		Gen2Battle.SWITCH_OFFERED:
			_offered = true
			_messages.append({"balls": {Gen2Battle.ENEMY: ball_tiles(view, Gen2Battle.ENEMY, "")}})
		Gen2Battle.CRY:
			_messages.append({"cry": int(event.get("species", 0))})
		Gen2Battle.GREW_LEVEL:
			if int(event.get("index", -1)) == int(view.get("active", 0)):
				_messages.append({"grew": int(event.get("new_level", 0)),
					"max_hp": int((event.get("new_stats", {}) as Dictionary).get("hp", 0))})
		Gen2Battle.ANIMATION:
			_queue_animation(event, out)


func _queue_animation(event: Dictionary, out: Dictionary) -> void:
	var index: int = int(event.get("index", 0))
	var enemy_turn: bool = bool(event.get("enemy_turn", false))
	if index == Gen2Battle.ANIM_SEND_OUT_MON:
		if int(event.get("param", 0)) == Gen2Battle.SEND_OUT_ANIM_NORMAL:
			_messages.append_array(send_out_steps(Gen2Battle.ENEMY if enemy_turn else Gen2Battle.PLAYER))
		return
	if index == Gen2Battle.ANIM_RETURN_MON:
		if not enemy_turn:
			_messages.append({"stage": PokeCoopBattleStage.RETREAT, "side": Gen2Battle.PLAYER})
		return
	_messages.append({
		"anim": index, "enemy": enemy_turn, "after": int(event.get("after_anim", 0)),
		"effectiveness": int(event.get("effectiveness", Gen2Layout.MATCHUP_EFFECTIVE)),
		"species": int(out.get(Gen2Battle.ENEMY if enemy_turn else Gen2Battle.PLAYER, 0)),
		"restore": bool(event.get("restore_user_pic", false)),
	})


## `RemoveFaintedPlayerMon`'s cry, or a trainer's Pokémon's fall and thud; a wild one's is silent.
static func faint_sounds(side: int, species: int, trainer: bool) -> Array:
	if side == Gen2Battle.PLAYER:
		return [{"cry": species}]
	return [{"sound": Gen1Sfx.SFX_FAINT_FALL}, {"sound": Gen1Sfx.SFX_FAINT_THUD}] if trainer else []


## `SendOutMon`'s poof in front of the player's, then `AnimateSendingOutMon`.
static func send_out_steps(side: int) -> Array:
	var grow: Dictionary = {"stage": PokeCoopBattleStage.SEND_OUT, "side": side}
	if side == Gen2Battle.ENEMY:
		return [grow]
	return [{"anim": Gen1Layout.ANIM_ID_POOF, "enemy": true, "after": 0, "ball": true, "species": 0}, grow]


static func _panels(scene: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in scene:
		if key.get_slice("_", 1) in ["species", "name", "level", "max", "status", "substitute", "minimized"]:
			out[key] = scene[key]
	return out


func _trainer_name(view: Dictionary) -> String:
	var trainer_class: int = int(view.get("trainer_class", 0))
	var named: String = String(view.get("trainer_name", ""))
	return named if not named.is_empty() else (data.trainer_name(trainer_class) if trainer_class > 0 else "")


## `TrainerBattleVictory`: the fanfare, the defeat, the trainer's line and this player's prize.
func _queue_victory(view: Dictionary) -> void:
	var trainer: bool = bool(view.get("trainer", false))
	var me: String = _player_name(panel.client.player_id)
	var prize: int = int((view.get("prizes", {}) as Dictionary).get(panel.client.player_id, 0))
	if not _fanfared:
		_messages.append({"fanfare": trainer, "gym": bool(view.get("gym", false))
			or int(view.get("trainer_class", 0)) == Gen1Layout.RIVAL3_CLASS})
	_fanfared = true
	var said: String = Gen2TextStream.fill_context(String(view.get("win_text", "")), {"player": me,
		"rival": String((panel.client.state.get("campaign", {}) as Dictionary).get("rival_name", ""))})
	var lines: Array = [_de(data, "%s defeated\n%s!") % [me, _trainer_name(view)], said] if trainer else []
	if prize > 0:
		lines.append(_de(data, "%s got ¥%d\nfor winning!" if trainer else "%s picked up\n¥%d!") % [me, prize])
	for line: int in lines.size():
		for page: String in pages(lines[line]):
			_messages.append({"text": page})
		if line == 0 and trainer:
			_messages.append({"stage": PokeCoopBattleStage.RESULT, "side": Gen2Battle.ENEMY,
				"trainer": int(view.get("trainer_class", 0))})


## [param line] two rows a page, the cartridge's paragraph and scroll breaks as new rows.
static func pages(line: String) -> PackedStringArray:
	for mark: String in [Gen2TextStream.PAGE_BREAK, Gen2TextStream.SCROLL_BREAK,
			Gen2TextStream.SCROLL_NOWAIT_BREAK, Gen2TextStream.PROMPT_BREAK]:
		line = line.replace(mark, "\n")
	var rows := PackedStringArray()
	for row: String in line.split("\n", false):
		while row.length() > BOX_COLUMNS:
			var cut: int = row.rfind(" ", BOX_COLUMNS)
			cut = cut if cut > 0 else BOX_COLUMNS
			rows.append(row.left(cut))
			row = row.substr(cut).strip_edges(true, false)
		rows.append(row)
	var out := PackedStringArray()
	for page: int in range(0, rows.size(), 2):
		out.append("\n".join(rows.slice(page, page + 2)))
	return out


static func out_now(view: Dictionary) -> Dictionary:
	var allies: Array = view.get("allies", [])
	var active: int = int(view.get("active", 0))
	return {
		Gen2Battle.PLAYER: species_at(view, Gen2Battle.PLAYER, active),
		Gen2Battle.ENEMY: int((view.get("enemy", {}) as Dictionary).get("species", 0)),
		name_key(Gen2Battle.PLAYER): String((allies[active] as Dictionary).get("name", "")) if active >= 0 and active < allies.size() else "",
		name_key(Gen2Battle.ENEMY): String((view.get("enemy", {}) as Dictionary).get("name", "")),
	}


static func name_key(side: int) -> String:
	return "enemy_name" if side == Gen2Battle.ENEMY else "player_name"


## `DrawAllPokeballs`' `StageBallTilesData`: the enemy's party, or [param player_id]'s own Pokémon among the allies.
static func ball_tiles(view: Dictionary, side: int, player_id: String) -> Array:
	var rows: Array = view.get("enemy_states", []) if side == Gen2Battle.ENEMY else (view.get("allies", []) as Array).filter(
		func(ally: Dictionary) -> bool: return String(ally.get("owner", "")) == player_id)
	var out: Array = []
	for slot: int in Gen2Party.MAX_SIZE:
		var row: Dictionary = rows[slot] if slot < rows.size() else {}
		out.append(Gen2BattleScreen.HUD_BALL_EMPTY if row.is_empty() else Gen2BattleScreen.HUD_BALL_FAINTED
			if int(row.get("hp", 0)) <= 0 else Gen2BattleScreen.HUD_BALL_STATUSED if int(row.get("status", 0)) != 0
			else Gen2BattleScreen.HUD_BALL_NORMAL)
	return out


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
			_board.map = _anim.background().bg_map.duplicate()
			if bool(_sounding.get("restore", false)) and _anim_after.is_empty():
				Gen2BattleScreenMap.stamp(_board.map, not bool(_sounding["enemy"]), data.generation)
			_anim = _applying()
		return
	if _board.busy():
		_board.advance()
		return
	if not _bar_goal.is_empty():
		_drain_bar()
		return
	if _box.visible and _box.is_revealing():
		return
	if _hold > 0:
		_hold -= 1
		return
	if _sound_wait and audio != null and audio.still_waiting(_sound_watch):
		return
	_sound_wait = false
	if not _messages.is_empty():
		_take_step(_messages.pop_front())
	elif not _idle_text.is_empty():
		_show_idle()
	if _messages.is_empty() and _bar_goal.is_empty() and _anim == null and not _board.busy():
		_drawn_hp.clear()


func _show_idle() -> void:
	_show(_idle_text if panel.menu.page == PokeCoopBattleMenu.NONE else "")
	_idle_text = ""


func _take_step(step: Dictionary) -> void:
	if step.has("text"):
		_show(String(step["text"]))
		var next: Dictionary = {} if _messages.is_empty() else _messages[0]
		_hold = 0 if (next.has("anim") or next.has("stage")) and _board.balls.is_empty() else HOLD_FRAMES
	elif step.has("balls"):
		_board.party_balls(step["balls"])
	elif step.has("stage"):
		_board.begin(StringName(step["stage"]), int(step["side"]), int(step.get("trainer", 0)))
	elif step.has("hold"):
		_hold = int(step["hold"])
	elif step.has("panel"):
		_board.shown.merge(step["panel"], true)
	elif step.has("grew"):
		_board.shown.merge({"player_level": int(step["grew"]), "player_max_hp": int(step["max_hp"])}, true)
	elif step.has("enter"):
		_board.enter(step["enter"], data)
		_drawn_hp[int(step["enter"].get("side", 0))] = float(step["enter"].get("hp", 0))
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
		_hold = HOLD_FRAMES if step.has("fanfare") else 0
		_sound_watch = {}
		_sound_wait = not step.has("fanfare")


## A pixel of the bar's forty-eight a frame, the way `UpdateHPBar` drains it.
func _drain_bar() -> void:
	var side: int = int(_bar_goal["bar"])
	var goal: float = float(_bar_goal["hp"])
	var now: float = float(_drawn_hp[side])
	_drawn_hp[side] = move_toward(now, goal, maxf(1.0, float(_bar_goal["max_hp"]) / 48.0))
	if is_equal_approx(float(_drawn_hp[side]), goal):
		_bar_goal = {}


## The cartridge's animation for a step, a move's, a status's or a ball's; null for
## a send-out, a move with the battle scene off or a cache without animations.
func _animation(step: Dictionary) -> Gen2BattleAnimPlayer:
	if _anim_data == null:
		_anim_data = Gen2BattleAnimData.from_game_data(data)
	var index: int = int(step["anim"])
	var move: bool = index < Gen2BattleScreen.ANIM_MOVE_LIMIT and not bool(step.get("ball", false))
	if _anim_data == null or not _anim_data.gen1() or (move and not Gen2OptionsStore.current().battle_scene):
		return null
	var enemy_turn: bool = bool(step["enemy"])
	var row: int = index - 1
	if index >= Gen2BattleScreen.ANIM_MOVE_LIMIT:
		var pair: Variant = Gen2BattleScreen.GEN1_ANIM_IDS.get(index, null)
		row = int((pair as Array)[1 if enemy_turn else 0]) - 1 if pair is Array else -1
	return _seeded(Gen2BattleAnimPlayer.create_gen1(_anim_data, row, enemy_turn, int(step.get("shakes", 0))) \
		if row >= 0 else null)


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


func _seeded(player: Gen2BattleAnimPlayer) -> Gen2BattleAnimPlayer:
	if player != null:
		player.background().set_bg_map(_board.map)
	return player


## `TossBallAnimation`: the toss, the poof, a shake a wobble, and out unless caught.
static func toss_steps(event: Dictionary) -> Array:
	var wobbles: int = clampi(int(event.get("wobbles", 0)), 0, 3)
	var caught: bool = bool(event.get("caught", false))
	var rows: Array = [
		int(Gen2BattleScreen.GEN1_TOSS_ANIMS.get(int(event.get("ball", 0)), Gen1Layout.ANIM_ID_ULTRATOSS)),
		Gen1Layout.ANIM_ID_POOF,
	]
	if caught or wobbles > 0:
		rows.append_array([Gen1Layout.ANIM_ID_HIDEPIC, Gen1Layout.ANIM_ID_SHAKE])
	if not caught and wobbles > 0:
		rows.append_array([Gen1Layout.ANIM_ID_POOF, Gen1Layout.ANIM_ID_SHOWPIC])
	return rows.map(func(index: int) -> Dictionary: return {
		"anim": index, "enemy": false, "after": 0, "ball": true, "species": 0,
		"shakes": maxi(wobbles, 1) if index == Gen1Layout.ANIM_ID_SHAKE else 0,
	})


func _play_sounds() -> void:
	if _anim != null:
		_take_commands(_anim.frame_commands())


## The animation's last frame: `GetMoveSound`'s row, an `IsCryMove` being the attacker's cry, and the actor's doll or dot.
func _take_commands(commands: Array) -> void:
	var actor: String = "enemy_" if bool(_sounding.get("enemy", false)) else "player_"
	for command: Dictionary in commands:
		var operands: Array = command.get("operands", [])
		var record: Dictionary = {}
		match StringName(command["name"]):
			Gen2BattleAnimPlayer.GEN1_SOUND:
				record = data.gen1_sound(-1, int(operands[0]))
			Gen2BattleAnimPlayer.GEN1_MOVE_SOUND:
				record = _move_sound(int(operands[0]))
			Gen2BattleAnimScript.RAISE_SUB, Gen2BattleAnimScript.DROP_SUB:
				_board.shown[actor + "substitute"] = StringName(command["name"]) == Gen2BattleAnimScript.RAISE_SUB
			Gen2BattleAnimScript.MINIMIZE:
				_dot_staged = true
			Gen2BattleAnimScript.UPDATE_ACTOR_PIC:
				_board.shown[actor + "minimized"] = _dot_staged or bool(_board.shown.get(actor + "minimized", false))
				_dot_staged = false
			Gen2BattleAnimScript.MINIMIZE_OPP:
				_board.shown[actor + "minimized"] = true
		if not record.is_empty() and audio != null:
			audio.play_record(record, &"sound", data.audio_assets())


## A cry, a sound waited out, or `PlayVictoryMusic`'s wild or trainer fanfare.
func _play_cue(cue: Dictionary) -> void:
	if audio == null:
		return
	if cue.has("cry") or cue.has("sound"):
		var cue_record: Dictionary = data.species_cry(int(cue["cry"])) if cue.has("cry") else data.gen1_sound(-1, int(cue["sound"]))
		if not cue_record.is_empty():
			audio.play_record(cue_record, &"cry" if cue.has("cry") else &"sound", data.audio_assets())
		return
	var music: int = Gen1Layout.MUSIC_DEFEATED_GYM_LEADER if bool(cue.get("gym", false)) else \
		(Gen1Layout.MUSIC_DEFEATED_TRAINER if bool(cue["fanfare"]) else Gen1Layout.MUSIC_DEFEATED_WILD_MON)
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


func _with_animation(view: Dictionary) -> Dictionary:
	_board.over(view)
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
		return ""
	var controller: String = String(view.get("controller", ""))
	var allies: Array = view.get("allies", [])
	var active: int = int(view.get("active", 0))
	var species_name: String = _species_name(data, int((allies[active] as Dictionary).get("species", 0))) \
		if active >= 0 and active < allies.size() else ""
	if bool(view.get("paused", false)):
		return _de(data, "%s is away.\nWaiting...") % _player_name(controller)
	if controller == panel.client.player_id:
		match StringName(view.get("phase", &"")):
			PokeCoopBattleSession.AWAITING_SEND_OUT:
				return _de(data, "Bring out which\nPOKéMON?")
			PokeCoopBattleSession.AWAITING_LEARN:
				return _de(data, "Which move should\nbe forgotten?")
		return _de(data, "What will\n%s do?") % species_name
	return _de(data, "%s is\ndeciding...") % _player_name(controller)


func _player_name(player_id: String) -> String:
	var view: Dictionary = (panel.client.state.get("players", {}) as Dictionary).get(player_id, {})
	return String(view.get("name", player_id))


## An event's line in Red and Blue's words, [param out] being who is out on each side.
static func message(
	event: Dictionary, out: Dictionary, game: GameData, names: Dictionary = {}, trainer: String = ""
) -> String:
	var who_acted: String = String(names.get(String(event.get("player", "")), ""))
	match StringName(event.get("type", &"")):
		Gen2Battle.CAUGHT:
			return _de(game, "All right!\n%s was caught!") % _species_name(game, int(out.get(Gen2Battle.ENEMY, 0)))
		Gen2Battle.MOVE_OFFERED:
			return _de(game, "%s is\ntrying to learn\n%s!") % [event.get("name", ""), String(game.move(int(event.get("move", 0))).get("name", ""))]
		PokeCoopBattleSession.JOINED:
			return _de(game, "%s joined\nthe battle!") % who_acted
		PokeCoopBattleSession.ITEM_USED:
			return _de(game, "%s used\n%s!") % [who_acted, game.item_name(int(event.get("item", 0)))]
		PokeCoopBattleSession.BALL_THROWN:
			return _throw_line(event, who_acted, _species_name(game, int(out.get(Gen2Battle.ENEMY, 0))), game)
		Gen2Battle.SWITCH_OFFERED:
			return Gen2BattleSwitchMenu.offer_text(trainer, _species_name(game, int(event.get("species", 0))), "", true) \
				.get_slice(Gen2TextStream.PAGE_BREAK, 0)
	return ""


## `ItemUseBall`'s lines: the throw, then the catch or how close it came.
static func _throw_line(event: Dictionary, thrower: String, wild: String, game: GameData) -> String:
	var thrown: String = _de(game, "%s used\n%s!") % [thrower, game.item_name(int(event.get("ball", 0)))]
	if bool(event.get("caught", false)):
		var jingle: String = Gen2TextStream.sound_token(Gen1Sfx.SFX_CAUGHT_MON) if game.generation == RomRegistry.GEN1 else ""
		return thrown + "\n" + _de(game, "All right!\n%s was caught!") % wild + jingle
	var near: Array[String] = [
		"You missed the\nPOKéMON!", "Darn! The POKéMON\nbroke free!", "Aww! It appeared\nto be caught!",
		"Shoot! It was so\nclose too!",
	]
	return thrown + "\n" + _de(game, near[clampi(int(event.get("wobbles", 0)), 0, near.size() - 1)])


static func _de(game: GameData, english: String) -> String:
	return Gen1LayoutDe.ui(game.id if game != null else &"", english)


func _player_names() -> Dictionary:
	var out: Dictionary = {}
	var everyone: Dictionary = panel.client.state.get("players", {}) if panel != null else {}
	for player_id: String in everyone:
		out[player_id] = String((everyone[player_id] as Dictionary).get("name", player_id))
	return out
