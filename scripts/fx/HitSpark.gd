extends Node2D
## Small radial flash when a projectile connects. Pure _draw, no particle nodes:
## a GPUParticles2D per hit would be far more expensive at these spawn rates.

signal finished

const LIFETIME := 0.18

var _age: float = 0.0
var _alive: bool = false
var _color: Color = Palette.ACCENT
var _scale: float = 1.0
var _seed: float = 0.0


func _ready() -> void:
	z_index = 20


func pool_reset() -> void:
	_age = 0.0
	_alive = true


func pool_sleep() -> void:
	_alive = false


func play(color: Color, spark_scale: float) -> void:
	_color = color
	_scale = spark_scale
	_age = 0.0
	_alive = true
	_seed = RunManager.rng.randf() * TAU
	rotation = _seed
	queue_redraw()


func _process(delta: float) -> void:
	if not _alive:
		return
	_age += delta
	queue_redraw()
	if _age >= LIFETIME:
		_alive = false
		finished.emit()
		PoolManager.release(self)


func _draw() -> void:
	var t := clampf(_age / LIFETIME, 0.0, 1.0)
	var alpha := 1.0 - t
	var radius := (10.0 + 26.0 * t) * _scale
	var c := _color
	c.a = alpha
	draw_circle(Vector2.ZERO, radius * 0.35, Color(1, 1, 1, alpha * 0.8))
	for i in 5:
		var a := TAU * float(i) / 5.0
		var dir := Vector2(cos(a), sin(a))
		draw_line(dir * radius * 0.4, dir * radius, c, 2.5 * _scale, true)
