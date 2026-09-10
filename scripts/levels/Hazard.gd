class_name HazardZone
extends Area2D
## An environmental danger. Every level reuses this one pooled scene; the level's
## LevelData.hazard_type only changes the look, timing and side effect.
##
## Hazards telegraph before they arm so a fair player can always walk out.

enum Phase { TELEGRAPH, ACTIVE, FADE }

const TELEGRAPH_TIME := 1.1
const ACTIVE_TIME := 1.6
const FADE_TIME := 0.5

@onready var _shape: CollisionShape2D = $Shape

var damage: float = 0.0
var hazard_type: int = LevelData.Hazard.ELECTRIC_FLOOR
var radius: float = 130.0
var color: Color = Palette.ACCENT

var _phase: int = Phase.TELEGRAPH
var _timer: float = 0.0
var _alive: bool = false
var _armed_damage: float = 10.0


func _ready() -> void:
	collision_layer = Layers.HAZARD
	collision_mask = 0
	set_deferred("monitoring", false)
	set_deferred("monitorable", true)
	add_to_group(&"hazards")
	z_index = -5


func pool_reset() -> void:
	_phase = Phase.TELEGRAPH
	_timer = TELEGRAPH_TIME
	_alive = true
	damage = 0.0
	set_deferred("monitorable", false)


func pool_sleep() -> void:
	_alive = false
	damage = 0.0
	set_deferred("monitorable", false)


func setup(type: int, hazard_radius: float, hazard_damage: float, hazard_color: Color) -> void:
	hazard_type = type
	radius = hazard_radius
	_armed_damage = hazard_damage
	color = hazard_color
	var circle := _shape.shape as CircleShape2D
	if circle != null:
		circle.radius = radius
	_phase = Phase.TELEGRAPH
	_timer = TELEGRAPH_TIME
	damage = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if not _alive:
		return
	_timer -= delta
	queue_redraw()
	if _timer > 0.0:
		if _phase == Phase.ACTIVE:
			_apply_side_effects()
		return
	match _phase:
		Phase.TELEGRAPH:
			_phase = Phase.ACTIVE
			_timer = ACTIVE_TIME
			damage = _armed_damage
			set_deferred("monitorable", true)
			AudioManager.play_sfx(&"explosion", 0.2, -16.0)
		Phase.ACTIVE:
			_phase = Phase.FADE
			_timer = FADE_TIME
			damage = 0.0
			set_deferred("monitorable", false)
		_:
			_alive = false
			PoolManager.release(self)


## Slowing water and gravity anomalies also affect enemies, which makes hazards
## a tactical tool rather than pure punishment.
func _apply_side_effects() -> void:
	if EnemyDirector.instance == null:
		return
	match hazard_type:
		LevelData.Hazard.SLOW_WATER:
			for enemy in EnemyDirector.instance.get_in_radius(global_position, radius, 24):
				enemy.apply_slow(0.55, 0.4)
		LevelData.Hazard.GRAVITY_ANOMALY:
			for enemy in EnemyDirector.instance.get_in_radius(global_position, radius, 24):
				var pull := (global_position - enemy.global_position).normalized() * 60.0
				enemy.global_position += pull * get_process_delta_time()
		_:
			pass


func _draw() -> void:
	var t := 0.0
	match _phase:
		Phase.TELEGRAPH:
			t = 1.0 - clampf(_timer / TELEGRAPH_TIME, 0.0, 1.0)
			_draw_telegraph(t)
		Phase.ACTIVE:
			_draw_active(1.0 - clampf(_timer / ACTIVE_TIME, 0.0, 1.0))
		_:
			_draw_active(1.0)


func _draw_telegraph(t: float) -> void:
	var c := color
	c.a = 0.18 + 0.22 * sin(t * 18.0)
	draw_circle(Vector2.ZERO, radius, c)
	Draw2D.ring(self, Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.7), 3.0)
	Draw2D.ring(self, Vector2.ZERO, radius * t, Color(color.r, color.g, color.b, 0.9), 4.0)


func _draw_active(t: float) -> void:
	var fade := 1.0 - t * 0.5
	match hazard_type:
		LevelData.Hazard.FIRE_VENT:
			for i in 10:
				var a := TAU * float(i) / 10.0 + t * 3.0
				var r := radius * (0.55 + 0.45 * absf(sin(t * 9.0 + float(i))))
				draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * r,
					Color(1.0, 0.55, 0.2, 0.8 * fade), 7.0, true)
			draw_circle(Vector2.ZERO, radius * 0.35, Color(1.0, 0.85, 0.4, 0.6 * fade))
		LevelData.Hazard.SLOW_WATER:
			draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.28 * fade))
			for i in 3:
				Draw2D.ring(self, Vector2.ZERO, radius * (0.4 + 0.3 * float(i)),
					Color(color.r, color.g, color.b, 0.45 * fade), 2.0)
		LevelData.Hazard.GRAVITY_ANOMALY:
			draw_circle(Vector2.ZERO, radius, Color(0.05, 0.0, 0.12, 0.5 * fade))
			for i in 6:
				var a := TAU * float(i) / 6.0 - t * 5.0
				draw_arc(Vector2.ZERO, radius * (0.3 + 0.12 * float(i)), a, a + 1.6, 12,
					Color(color.r, color.g, color.b, 0.7 * fade), 2.5, true)
		_:
			# Electric floor.
			draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.16 * fade))
			for i in 8:
				var a := TAU * float(i) / 8.0 + t * 6.0
				var mid := Vector2(cos(a + 0.4), sin(a + 0.4)) * radius * 0.55
				var end := Vector2(cos(a), sin(a)) * radius
				draw_polyline(PackedVector2Array([Vector2.ZERO, mid, end]),
					Color(color.r, color.g, color.b, 0.85 * fade), 3.0, true)
