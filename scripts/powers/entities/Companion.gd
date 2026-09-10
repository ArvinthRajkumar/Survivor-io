class_name Companion
extends Node2D
## A drone that orbits the player. Two modes share one body because they are the
## same machine with a different payload: a gun pod, or a medical dispenser.
##
## Damage and healing are resolved by querying EnemyDirector rather than with a
## physics area — companions run in _process, so they can safely spawn pooled
## bullets and zones without touching the physics server mid-query.

enum Mode { GUN, HEAL }

const DEPLOY_TIME := 0.45

var mode: int = Mode.GUN
var target: Node2D
var orbit_radius: float = 90.0
var orbit_speed: float = 1.6
var orbit_angle: float = 0.0
var body_radius: float = 18.0
var color: Color = Palette.ACCENT
var color_secondary: Color = Color.WHITE

var damage: float = 10.0
var crit_chance: float = 0.05
var crit_damage: float = 1.6
var bullet_speed: float = 520.0
var bullet_count: int = 6
var fire_interval: float = 1.4
var targeted: bool = false
var source_id: int = 0

var heal_amount: float = 6.0
var heal_radius: float = 110.0
var heal_duration: float = 5.0
var drop_range: float = 170.0

var _phase: float = 0.0
var _fire_timer: float = 0.0
var _recoil: float = 0.0
var _deploy: float = 0.0
var _alive: bool = false


func _ready() -> void:
	add_to_group(&"companions")
	z_index = 14


func pool_reset() -> void:
	_phase = 0.0
	_fire_timer = 0.6
	_recoil = 0.0
	_deploy = 0.0
	_alive = true
	scale = Vector2.ONE
	modulate = Color.WHITE


func pool_sleep() -> void:
	_alive = false
	target = null


func configure(cfg: Dictionary) -> void:
	mode = int(cfg.get("mode", Mode.GUN))
	target = cfg.get("target", null)
	orbit_radius = float(cfg.get("orbit_radius", 90.0))
	orbit_speed = float(cfg.get("orbit_speed", 1.6))
	orbit_angle = float(cfg.get("orbit_angle", 0.0))
	body_radius = float(cfg.get("body_radius", 18.0))
	color = cfg.get("color", Palette.ACCENT)
	color_secondary = cfg.get("color2", Color.WHITE)

	damage = float(cfg.get("damage", 10.0))
	crit_chance = float(cfg.get("crit_chance", 0.05))
	crit_damage = float(cfg.get("crit_damage", 1.6))
	bullet_speed = float(cfg.get("bullet_speed", 520.0))
	bullet_count = int(cfg.get("bullet_count", 6))
	fire_interval = float(cfg.get("fire_interval", 1.4))
	targeted = bool(cfg.get("targeted", false))
	source_id = int(cfg.get("source_id", get_instance_id()))

	heal_amount = float(cfg.get("heal_amount", 6.0))
	heal_radius = float(cfg.get("heal_radius", 110.0))
	heal_duration = float(cfg.get("heal_duration", 5.0))
	drop_range = float(cfg.get("drop_range", 170.0))
	_fire_timer = fire_interval * RunManager.rng.randf_range(0.2, 0.8)
	queue_redraw()


## Live re-tune when the owning power levels up, without popping the drone.
func retune(cfg: Dictionary) -> void:
	var keep_phase := _phase
	var keep_timer := _fire_timer
	configure(cfg)
	_phase = keep_phase
	_fire_timer = keep_timer
	_deploy = 1.0


func _process(delta: float) -> void:
	if not _alive:
		return
	if target == null or not is_instance_valid(target):
		expire()
		return
	_phase += delta
	_deploy = minf(1.0, _deploy + delta / DEPLOY_TIME)
	_recoil = maxf(0.0, _recoil - delta * 4.0)

	orbit_angle += orbit_speed * delta
	# Ease outward on deploy so the drone visibly flies out from the player.
	var eased := 1.0 - pow(1.0 - _deploy, 3.0)
	var offset := Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius * eased
	global_position = target.global_position + offset
	scale = Vector2.ONE * (0.4 + 0.6 * eased)

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = maxf(0.12, fire_interval)
		if mode == Mode.GUN:
			_fire_bullets()
		else:
			_drop_heal_zone()
	queue_redraw()


func _fire_bullets() -> void:
	if ProjectileSystem.instance == null:
		return
	_recoil = 1.0
	var cfg := {
		"damage": damage,
		"crit_chance": crit_chance,
		"crit_damage": crit_damage,
		"knockback": 60.0,
		"pierce": 0,
		"lifetime": 1.1,
		"speed": bullet_speed,
		"radius": 8.0,
		"color": color,
		"color2": color_secondary,
		"shape": 1,
		"hit_interval": 0.0,
		"source_id": source_id,
		"position": global_position,
	}
	if targeted and EnemyDirector.instance != null:
		# Max level: aimed bursts rather than a decorative ring.
		var fired := 0
		var seen: Dictionary = {}
		for i in bullet_count:
			var enemy := EnemyDirector.instance.get_nearest(global_position, 620.0)
			if enemy == null:
				break
			# Fan slightly so several bullets do not perfectly overlap.
			var dir := (enemy.global_position - global_position).normalized()
			var spread := deg_to_rad(7.0) * (float(i) - float(bullet_count - 1) * 0.5)
			cfg["direction"] = dir.rotated(spread)
			cfg["motion"] = Projectile.Motion.HOMING
			cfg["homing_strength"] = 6.0
			ProjectileSystem.instance.spawn_projectile(cfg)
			fired += 1
			seen[enemy.get_instance_id()] = true
		if fired == 0:
			_fire_radial(cfg)
	else:
		_fire_radial(cfg)
	AudioManager.play_sfx(&"shoot", 0.15, -18.0)


func _fire_radial(cfg: Dictionary) -> void:
	var base := _phase * 1.3
	for i in bullet_count:
		var a := base + TAU * float(i) / float(bullet_count)
		cfg["direction"] = Vector2(cos(a), sin(a))
		cfg["motion"] = Projectile.Motion.LINEAR
		ProjectileSystem.instance.spawn_projectile(cfg)


func _drop_heal_zone() -> void:
	if ProjectileSystem.instance == null or target == null:
		return
	_recoil = 1.0
	var offset := MathUtil.random_point_in_ring(RunManager.rng, drop_range * 0.25, drop_range)
	ProjectileSystem.instance.spawn_zone({
		"position": target.global_position + offset,
		"damage": 0.0,
		"heal_rate": heal_amount,
		"tick_interval": 0.5,
		"radius": heal_radius,
		"lifetime": heal_duration,
		"color": color,
		"color2": color_secondary,
		"style": DamageZone.Style.HEAL_CIRCLE,
		"source_id": source_id,
	})
	AudioManager.play_sfx(&"pickup", 0.2, -20.0)


func expire() -> void:
	if not _alive:
		return
	_alive = false
	PoolManager.release(self)


func _draw() -> void:
	if not _alive:
		return
	# Recoil kicks the drone back along its firing axis for a frame or two.
	var kick := Vector2(0.0, -body_radius * 0.25 * _recoil)
	PowerArt.draw(self, &"healing_drone" if mode == Mode.HEAL else &"drone",
		kick, body_radius, color, color_secondary, _phase)
	if _recoil > 0.05:
		var flash := Color(color_secondary.r, color_secondary.g, color_secondary.b, 0.5 * _recoil)
		draw_circle(kick, body_radius * (1.2 + 0.8 * (1.0 - _recoil)), flash)
