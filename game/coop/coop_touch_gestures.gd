class_name PokeCoopTouchGestures
extends Node

## Over the game screen while a co-op menu or battle is up: a swipe is the d-pad, a row at a time, and a tap is A.

const ROW_PIXELS: float = 16.0
const TAP_SLOP: float = 0.5
const TAP_MSEC: int = 500
const HOLD_FRAMES: int = 2

var screen: Control = null
var active: Callable = Callable()
var _down: Dictionary = {}
var _index: int = -1
var _from: Vector2 = Vector2.ZERO
var _at_msec: int = 0
var _axis: int = -1
var _steps: int = 0
var _swiped: bool = false
var _queue: Array[int] = []
var _held: int = PokeButton.NONE
var _held_frames: int = 0


static func over(game_screen: Control, open: Callable) -> PokeCoopTouchGestures:
	var out := PokeCoopTouchGestures.new()
	out.screen = game_screen
	out.active = open
	return out


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		_touched(touch.index, touch.position, touch.pressed)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		_dragged(drag.index, drag.position)


func _touched(index: int, point: Vector2, pressed: bool) -> void:
	if pressed:
		_down[index] = true
		if _down.size() > 1:
			_index = -1
		elif _covers(point) and _is_active():
			_index = index
			_from = point
			_at_msec = Time.get_ticks_msec()
			_axis = -1
			_steps = 0
			_swiped = false
		return
	_down.erase(index)
	if index != _index:
		return
	_dragged(index, point)
	_index = -1
	if not _swiped and Time.get_ticks_msec() - _at_msec <= TAP_MSEC and _is_active():
		_queue.append(PokeButton.A)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_down.clear()
		_index = -1


func _dragged(index: int, point: Vector2) -> void:
	if index != _index or not _is_active():
		return
	var moved: Vector2 = point - _from
	var step: float = row_pixels()
	if _axis < 0:
		if moved.length() < step * TAP_SLOP:
			return
		_axis = 1 if absf(moved.y) >= absf(moved.x) else 0
		_swiped = true
	var steps: int = int(moved[_axis] / step)
	while _steps != steps:
		var forward: bool = steps > _steps
		_steps += 1 if forward else -1
		if _axis == 1:
			_queue.append(PokeButton.DOWN if forward else PokeButton.UP)
		else:
			_queue.append(PokeButton.RIGHT if forward else PokeButton.LEFT)


func _process(_delta: float) -> void:
	if _held != PokeButton.NONE:
		_held_frames += 1
		if _held_frames < HOLD_FRAMES:
			return
		_send(_held, false)
		_held = PokeButton.NONE
		return
	if _queue.is_empty():
		return
	_held = _queue.pop_front()
	_held_frames = 0
	_send(_held, true)


func row_pixels() -> float:
	var scale: float = screen.size.x / float(Gen2Screen.WIDTH) if screen != null else 1.0
	if screen is Gen2Screen and (screen as Gen2Screen).view_size().x > 0:
		scale = float((screen as Gen2Screen).native_size().x) / float((screen as Gen2Screen).view_size().x)
	return ROW_PIXELS * maxf(scale, 1.0) * _canvas_scale()


func _canvas_scale() -> float:
	return screen.get_global_transform_with_canvas().get_scale().x if screen != null and screen.is_inside_tree() else 1.0


func _covers(point: Vector2) -> bool:
	if screen == null or not is_instance_valid(screen) or not screen.is_visible_in_tree():
		return false
	var local: Vector2 = screen.get_global_transform_with_canvas().affine_inverse() * point
	if not Rect2(Vector2.ZERO, screen.size).has_point(local):
		return false
	var pad: Gen2TouchPad = Gen2InputRuntime.instance().active_touch_pad() as Gen2TouchPad
	if pad == null or not pad.is_visible_in_tree():
		return true
	return String(pad.action_at(pad.get_global_transform_with_canvas().affine_inverse() * point)).is_empty()


func _is_active() -> bool:
	return active.is_valid() and bool(active.call())


func _send(button: int, pressed: bool) -> void:
	if pressed:
		Gen2InputRuntime.instance().press(button)
	else:
		Gen2InputRuntime.instance().release(button)
