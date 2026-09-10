class_name TouchJoystick
extends Control
## One-handed touch stick.
##
## In dynamic mode the stick appears wherever the thumb lands inside its zone,
## which is what makes the game comfortable to play with a single hand on a large
## phone. It also accepts mouse input so the game is testable on desktop.

signal moved(direction: Vector2)
signal released

const BASE_RADIUS := 130.0
const KNOB_RADIUS := 58.0
const DEAD_ZONE := 0.12

@export var dynamic: bool = true
@export var fixed_position: Vector2 = Vector2(240, 1500)

var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _active: bool = false
var _direction: Vector2 = Vector2.ZERO
var _fade: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	dynamic = bool(SaveManager.get_setting("joystick_dynamic", true))
	_origin = fixed_position
	set_process(true)


func _process(delta: float) -> void:
	var target := 1.0 if _active else 0.0
	if dynamic:
		_fade = move_toward(_fade, target, delta * 5.0)
	else:
		_fade = 1.0
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not _active:
			_begin(touch.position, touch.index)
			accept_event()
		elif not touch.pressed and touch.index == _touch_index:
			_end()
			accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update(drag.position)
			accept_event()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed and not _active:
				_begin(button.position, -2)
			elif not button.pressed and _touch_index == -2:
				_end()
			accept_event()
	elif event is InputEventMouseMotion and _touch_index == -2:
		_update((event as InputEventMouseMotion).position)
		accept_event()


func _begin(pos: Vector2, index: int) -> void:
	_touch_index = index
	_active = true
	_origin = pos if dynamic else fixed_position
	_knob = _origin
	_update(pos)


func _update(pos: Vector2) -> void:
	if not _active:
		return
	var offset := pos - _origin
	if offset.length() > BASE_RADIUS:
		offset = offset.normalized() * BASE_RADIUS
	_knob = _origin + offset
	var raw := offset / BASE_RADIUS
	_direction = Vector2.ZERO if raw.length() < DEAD_ZONE else raw
	moved.emit(_direction)


func _end() -> void:
	_active = false
	_touch_index = -1
	_direction = Vector2.ZERO
	moved.emit(Vector2.ZERO)
	released.emit()


func get_direction() -> Vector2:
	return _direction


func _draw() -> void:
	if _fade <= 0.01:
		return
	var alpha := _fade
	var center := _origin if (_active or not dynamic) else fixed_position
	Draw2D.ring(self, center, BASE_RADIUS, Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.28 * alpha), 3.0)
	draw_circle(center, BASE_RADIUS, Color(0.10, 0.16, 0.24, 0.22 * alpha))
	var knob := _knob if _active else center
	draw_circle(knob, KNOB_RADIUS, Color(0.16, 0.26, 0.38, 0.55 * alpha))
	Draw2D.ring(self, knob, KNOB_RADIUS, Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.75 * alpha), 3.0)
	if _direction.length() > 0.05:
		draw_line(center, center + _direction * BASE_RADIUS,
			Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.4 * alpha), 4.0, true)
