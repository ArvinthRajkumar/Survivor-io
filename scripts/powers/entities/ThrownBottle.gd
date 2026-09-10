class_name ThrownBottle
extends Node2D
## A Molotov in flight.
##
## The bottle travels along a straight ground path while a separate visual
## height offset arcs it through the air, which reads as a real throw in a
## top-down view. On landing it shatters and leaves a burning patch.

const SPIN_RATE := 9.0

var start_position: Vector2 = Vector2.ZERO
var land_position: Vector2 = Vector2.ZERO
var flight_time: float = 0.55
var arc_height: float = 120.0
var bottle_radius: float = 15.0
var color: Color = Palette.ACCENT_WARM
var color_secondary: Color = Color(1.0, 0.85, 0.35)

var fire_damage: float = 8.0
var fire_radius: float = 110.0
var fire_duration: float = 4.0
var tick_interval: float = 0.4
var crit_chance: float = 0.0
var crit_damage: float = 1.6
var source_id: int = 0

var _t: float = 0.0
var _spin: float = 0.0
var _alive: bool = false


func _ready() -> void:
	add_to_group(&"bottles")
	z_index = 16


func pool_reset() -> void:
	_t = 0.0
	_spin = RunManager.rng.randf() * TAU
	_alive = true
	scale = Vector2.ONE


func pool_sleep() -> void:
	_alive = false


func configure(cfg: Dictionary) -> void:
	start_position = cfg.get("from", global_position)
	land_position = cfg.get("to", global_position)
	flight_time = maxf(0.15, float(cfg.get("flight_time", 0.55)))
	arc_height = float(cfg.get("arc_height", 120.0))
	bottle_radius = float(cfg.get("bottle_radius", 15.0))
	color = cfg.get("color", Palette.ACCENT_WARM)
	color_secondary = cfg.get("color2", Color(1.0, 0.85, 0.35))
	fire_damage = float(cfg.get("fire_damage", 8.0))
	fire_radius = float(cfg.get("fire_radius", 110.0))
	fire_duration = float(cfg.get("fire_duration", 4.0))
	tick_interval = float(cfg.get("tick_interval", 0.4))
	crit_chance = float(cfg.get("crit_chance", 0.0))
	crit_damage = float(cfg.get("crit_damage", 1.6))
	source_id = int(cfg.get("source_id", get_instance_id()))
	global_position = start_position
	_t = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if not _alive:
		return
	_t += delta / flight_time
	_spin += delta * SPIN_RATE
	if _t >= 1.0:
		_land()
		return
	global_position = start_position.lerp(land_position, _t)
	queue_redraw()


func _land() -> void:
	_alive = false
	var pos := land_position
	if ProjectileSystem.instance != null:
		ProjectileSystem.instance.spawn_zone({
			"position": pos,
			"damage": fire_damage,
			"tick_interval": tick_interval,
			"radius": fire_radius,
			"lifetime": fire_duration,
			"color": color,
			"color2": color_secondary,
			"style": DamageZone.Style.FIRE_PATCH,
			"knockback": 0.0,
			"source_id": source_id,
			"crit_chance": crit_chance,
			"crit_damage": crit_damage,
			"max_targets": 40,
		})
	if EffectSpawner.instance != null:
		EffectSpawner.instance.spawn_death_burst(pos, color_secondary, fire_radius * 0.35)
	AudioManager.play_sfx(&"explosion", 0.18, -14.0)
	PoolManager.release(self)


func _draw() -> void:
	if not _alive:
		return
	# Parabolic visual height, plus a shadow that stays on the ground.
	var height := sin(_t * PI) * arc_height
	var shadow_scale := 1.0 - 0.35 * sin(_t * PI)
	draw_circle(Vector2(0.0, 0.0), bottle_radius * 0.55 * shadow_scale, Color(0, 0, 0, 0.30))

	var lift := Vector2(0.0, -height)
	# Trailing embers from the burning rag.
	for i in 4:
		var t := float(i) / 4.0
		var back := lift + Vector2(0.0, height * t * 0.35)
		draw_circle(back, 3.0 * (1.0 - t),
			Color(color_secondary.r, color_secondary.g, color_secondary.b, 0.55 * (1.0 - t)))

	draw_set_transform(lift, _spin, Vector2.ONE)
	PowerArt.draw_molotov(self, Vector2.ZERO, bottle_radius, color, color_secondary, _spin)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
