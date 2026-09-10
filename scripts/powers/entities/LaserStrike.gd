class_name LaserStrike
extends Node2D
## One orbital laser strike: telegraph, beam, scorch.
##
## The three phases are deliberately separate so the strike is fair — the
## shrinking targeting ring gives the player time to read it before anything is
## dealt, and the scorch afterwards leaves a readable record of where it landed.

enum Phase { TELEGRAPH, BEAM, SCORCH }

const TELEGRAPH_TIME := 0.55
const BEAM_TIME := 0.22
const SCORCH_TIME := 0.45
## How far above the impact point the beam appears to come from.
const SKY_HEIGHT := 1400.0

var radius: float = 80.0
var damage: float = 30.0
var crit_chance: float = 0.05
var crit_damage: float = 1.6
var knockback: float = 200.0
var color: Color = Color(0.55, 0.85, 1.0)
var color_secondary: Color = Color(1.0, 1.0, 1.0)
var source_id: int = 0

var _phase: int = Phase.TELEGRAPH
var _timer: float = 0.0
var _age: float = 0.0
var _alive: bool = false


func _ready() -> void:
	add_to_group(&"laser_strikes")
	z_index = 18


func pool_reset() -> void:
	_phase = Phase.TELEGRAPH
	_timer = TELEGRAPH_TIME
	_age = 0.0
	_alive = true


func pool_sleep() -> void:
	_alive = false


func configure(cfg: Dictionary) -> void:
	radius = float(cfg.get("radius", 80.0))
	damage = float(cfg.get("damage", 30.0))
	crit_chance = float(cfg.get("crit_chance", 0.05))
	crit_damage = float(cfg.get("crit_damage", 1.6))
	knockback = float(cfg.get("knockback", 200.0))
	color = cfg.get("color", Color(0.55, 0.85, 1.0))
	color_secondary = cfg.get("color2", Color(1.0, 1.0, 1.0))
	source_id = int(cfg.get("source_id", get_instance_id()))
	# A small delay lets a pattern of strikes land in sequence rather than at once.
	_timer = TELEGRAPH_TIME + float(cfg.get("delay", 0.0))
	_phase = Phase.TELEGRAPH
	_age = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if not _alive:
		return
	_age += delta
	_timer -= delta
	queue_redraw()
	if _timer > 0.0:
		return
	match _phase:
		Phase.TELEGRAPH:
			_phase = Phase.BEAM
			_timer = BEAM_TIME
			_strike()
		Phase.BEAM:
			_phase = Phase.SCORCH
			_timer = SCORCH_TIME
		_:
			_alive = false
			PoolManager.release(self)


func _strike() -> void:
	if EnemyDirector.instance != null:
		for enemy in EnemyDirector.instance.get_in_radius(global_position, radius, 40):
			var is_crit := RunManager.rng.randf() < crit_chance
			var amount := damage * (crit_damage if is_crit else 1.0)
			var push := (enemy.global_position - global_position).normalized() * knockback
			enemy.apply_hit(amount, is_crit, push, source_id, 0.0)
	if EffectSpawner.instance != null:
		EffectSpawner.instance.spawn_death_burst(global_position, color_secondary, radius * 0.8)
	AudioManager.play_sfx(&"explosion", 0.1, -12.0)


func _draw() -> void:
	if not _alive:
		return
	match _phase:
		Phase.TELEGRAPH:
			_draw_telegraph()
		Phase.BEAM:
			_draw_beam()
		_:
			_draw_scorch()


func _draw_telegraph() -> void:
	var t := 1.0 - clampf(_timer / TELEGRAPH_TIME, 0.0, 1.0)
	var ring := Color(color.r, color.g, color.b, 0.85)
	# Outer ring holds still; an inner ring closes in as a countdown.
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(color.r, color.g, color.b, 0.45), 3.0, true)
	draw_arc(Vector2.ZERO, radius * (1.5 - 0.5 * t), 0.0, TAU, 28, ring, 4.0, true)
	draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.08 + 0.10 * t))
	# Crosshair ticks.
	for i in 4:
		var a := TAU * float(i) / 4.0 + t * 1.2
		var dir := Vector2(cos(a), sin(a))
		draw_line(dir * radius * 0.55, dir * radius * 0.95, ring, 3.0, true)


func _draw_beam() -> void:
	var t := clampf(_timer / BEAM_TIME, 0.0, 1.0)
	var width := radius * (0.35 + 0.65 * t)
	var top := Vector2(0.0, -SKY_HEIGHT)
	var beam := PackedVector2Array([
		top + Vector2(-width * 0.30, 0.0),
		top + Vector2(width * 0.30, 0.0),
		Vector2(width, 0.0),
		Vector2(-width, 0.0),
	])
	draw_colored_polygon(beam, Color(color.r, color.g, color.b, 0.35 * t))
	draw_line(top, Vector2.ZERO, Color(1, 1, 1, 0.95 * t), width * 0.42, true)
	draw_line(top, Vector2.ZERO, Color(color.r, color.g, color.b, 0.8 * t), width * 0.18, true)

	# Ground flash and shockwave.
	draw_circle(Vector2.ZERO, radius * (1.0 + 0.6 * (1.0 - t)), Color(1, 1, 1, 0.45 * t))
	draw_arc(Vector2.ZERO, radius * (1.0 + 1.1 * (1.0 - t)), 0.0, TAU, 28,
		Color(color_secondary.r, color_secondary.g, color_secondary.b, 0.8 * t), 5.0 * t + 1.0, true)


func _draw_scorch() -> void:
	var t := clampf(_timer / SCORCH_TIME, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius * 0.9, Color(0.12, 0.10, 0.14, 0.35 * t))
	draw_arc(Vector2.ZERO, radius * 0.9, 0.0, TAU, 24,
		Color(color.r, color.g, color.b, 0.4 * t), 2.5, true)
	for i in 5:
		var a := TAU * float(i) / 5.0 + _age
		var dir := Vector2(cos(a), sin(a))
		draw_line(dir * radius * 0.3, dir * radius * 0.8,
			Color(color_secondary.r, color_secondary.g, color_secondary.b, 0.35 * t), 2.0, true)
