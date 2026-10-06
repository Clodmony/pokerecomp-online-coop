class_name PokeCoopBattleField
extends Control

## The panel's battle drawn as the cartridge draws one, through [Gen2BattleRenderer]
## and the game's text box, from the host's view alone; commands stay with the
## panel beside it.

const HOLD_FRAMES: int = 50
const GAP: int = 16

var panel: PokeCoopBattlePanel = null
var data: GameData = null
var _stage: Control = null
var _renderer: Gen2BattleRenderer = null
var _box: Gen2TextBox = null
## Each `{text, move, enemy}`: a line and the move whose animation follows it.
var _messages: Array = []
var _queued_move: Dictionary = {}
var _anim_data: Gen2BattleAnimData = null
var _anim: Gen2BattleAnimPlayer = null
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
	if not visible:
		panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		panel.position = Vector2(get_viewport_rect().size.x - panel.size.x - GAP, GAP)
		_revision_key = ""
		_idle_seen = ""
		_out = {}
		_messages.clear()
		_queued_move = {}
		_anim = null
		return
	_place()
	_renderer.set_view(_with_animation(scene_view(view, data)))
	_take_events(view)
	_frames += delta * 60.0
	while _frames >= 1.0:
		_frames -= 1.0
		_advance_text()


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
	var out: Dictionary = _out if not _out.is_empty() else out_now(view)
	for event: Dictionary in view.get("events", []):
		if StringName(event.get("type", &"")) == Gen2Battle.SENT_OUT:
			out[int(event.get("side", 0))] = species_at(view, int(event.get("side", 0)), int(event.get("index", 0)))
		var line: String = message(event, out, data)
		if not line.is_empty():
			var used: bool = StringName(event.get("type", &"")) == Gen2Battle.USED_MOVE
			_messages.append({
				"text": line, "move": int(event.get("move", 0)) if used else 0,
				"enemy": int(event.get("side", 0)) == Gen2Battle.ENEMY,
			})
	_out = out_now(view)
	_idle_text = idle


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
		if _anim.finished() or _anim.failed():
			_anim = null
		return
	if _box.visible and _box.is_revealing():
		return
	if not _queued_move.is_empty():
		_anim = _move_animation(int(_queued_move["move"]), bool(_queued_move["enemy"]))
		_queued_move = {}
		return
	if _hold > 0:
		_hold -= 1
		return
	if not _messages.is_empty():
		var next: Dictionary = _messages.pop_front()
		_show(String(next["text"]))
		_queued_move = next if int(next["move"]) > 0 else {}
		_hold = HOLD_FRAMES
	elif not _idle_text.is_empty():
		_show(_idle_text)
		_idle_text = ""


## The cartridge's own animation for [param move], over both pictures, or null
## for a cartridge whose cache holds none.
func _move_animation(move: int, enemy_turn: bool) -> Gen2BattleAnimPlayer:
	if _anim_data == null:
		_anim_data = Gen2BattleAnimData.from_game_data(data)
	var player: Gen2BattleAnimPlayer = Gen2BattleAnimPlayer.create_gen1(_anim_data, move - 1, enemy_turn) \
		if _anim_data != null and _anim_data.gen1() else null
	if player != null:
		player.background().set_bg_map(Gen2BattleScreenMap.seeded())
	return player


## The running animation's tilemap and objects over [param view].
func _with_animation(view: Dictionary) -> Dictionary:
	if _anim == null:
		return view
	view["bg_map"] = _anim.background().bg_map
	view["anim_sprites"] = _anim.sprites()
	view["anim_tiles"] = _anim.tiles()
	view["anim_obp0"] = _anim.background().obp0
	return view


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
static func message(event: Dictionary, out: Dictionary, game: GameData) -> String:
	var side: int = int(event.get("side", Gen2Battle.PLAYER))
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
	return ""
