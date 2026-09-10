extends Node2D
## Death / explosion burst: an expanding shockwave ring plus a handful of
## simulated shards. The shard count scales with the quality setting.

const LIFETIME := 0.42
const MAX_SHARDS := 12

var _age: float = 0.0
var _alive: bool = false
var _color: Color = Palette.DANGER
var _radius: float = 24.0
var _shards: Array[Vector2] = []
var _shard_speeds: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	z_index = 25


func pool_reset() -> void:
	_age = 0.0
	_alive = true


func pool_sleep() -> void:
	_alive = false


func play(color: Color, radius: float, budget: float = 1.0) -> void:
	_color = color
	_radius = maxf(12.0, radius)
	_age = 0.0
	_alive = true
	_shards.clear()
	_shard_speeds = PackedFloat32Array()
	var count := int(clampf(float(MAX_SHARDS) * budget, 3.0, float(MAX_SHARDS)))
	for i in count:
		var a := RunManager.rng.randf() * TAU
		_shards.append(Vector2(cos(a), sin(a)))
		_shard_speeds.append(RunManager.rng.randf_range(0.6, 1.4))
	queue_redraw()


func _process(delta: float) -> void:
	if not _alive:
		return
	_age += delta
	queue_redraw()
	if _age >= LIFETIME:
		_alive = false
		PoolManager.release(self)


func _draw() -> void:
	var t := clampf(_age / LIFETIME, 0.0, 1.0)
	var alpha := 1.0 - t
	var wave := _radius * (0.5 + 1.9 * t)
	var c := _color
	c.a = alpha * 0.9
	Draw2D.ring(self, Vector2.ZERO, wave, c, 4.0 * (1.0 - t) + 1.0)
	draw_circle(Vector2.ZERO, wave * 0.5, Color(_color.r, _color.g, _color.b, alpha * 0.18))
	for i in _shards.size():
		var dist := wave * 0.9 * _shard_speeds[i]
		var p := _shards[i] * dist
		draw_circle(p, maxf(1.5, 5.0 * (1.0 - t)), Color(_color.r, _color.g, _color.b, alpha))
