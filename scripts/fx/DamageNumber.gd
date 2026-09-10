extends Node2D
## Floating damage text. Drawn directly with the fallback font so the project
## needs no font asset, and pooled because hundreds appear per second.

signal finished

const LIFETIME := 0.65
const RISE := 90.0

var _amount: float = 0.0
var _crit: bool = false
var _age: float = 0.0
var _alive: bool = false
var _text: String = ""
var _font: Font
var _size: int = 30


func _ready() -> void:
	_font = ThemeDB.fallback_font
	z_index = 60


func pool_reset() -> void:
	_age = 0.0
	_alive = true


func pool_sleep() -> void:
	_alive = false


func show_damage(amount: float, is_crit: bool) -> void:
	_amount = amount
	_crit = is_crit
	_text = str(int(round(amount)))
	_size = 44 if is_crit else 30
	_age = 0.0
	_alive = true
	queue_redraw()


func _process(delta: float) -> void:
	if not _alive:
		return
	_age += delta
	position.y -= RISE * delta * (1.0 - _age / LIFETIME)
	queue_redraw()
	if _age >= LIFETIME:
		_alive = false
		finished.emit()
		PoolManager.release(self)


func _draw() -> void:
	if _font == null or _text.is_empty():
		return
	var t := clampf(_age / LIFETIME, 0.0, 1.0)
	var alpha := 1.0 - t * t
	var color := Palette.GOLD if _crit else Palette.TEXT
	color.a = alpha
	var outline := Color(0.0, 0.0, 0.0, alpha * 0.8)
	var width := _font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _size).x
	var origin := Vector2(-width * 0.5, 0.0)
	# Cheap outline: draw the text once offset in black, then on top in colour.
	draw_string(_font, origin + Vector2(2, 2), _text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _size, outline)
	draw_string(_font, origin, _text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _size, color)
