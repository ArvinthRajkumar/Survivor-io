class_name Projectile
extends Area2D
## One pooled, fully data-driven projectile.
##
## Every weapon in the game reuses this scene; the differences (homing, orbiting,
## bouncing, returning, exploding, chaining, slowing) are switches in the config
## dictionary handed to configure(). That keeps the pool warm and the scene count
## low, which matters a lot on mobile.

enum Motion { LINEAR, HOMING, ORBIT, BOOMERANG, BOUNCE, SPIRAL }
enum OnHit { NONE, EXPLODE, CHAIN, SLOW, FREEZE }

const BOUNCE_HALF_EXTENTS := Vector2(520.0, 950.0)

@onready var _shape: CollisionShape2D = $Shape

var damage: float = 10.0
var crit_chance: float = 0.05
var crit_damage: float = 1.6
var knockback: float = 100.0
var pierce_left: int = 0
var lifetime: float = 2.0
var speed: float = 700.0
var direction: Vector2 = Vector2.RIGHT
var radius: float = 12.0
var color: Color = Palette.ACCENT
var color2: Color = Color.WHITE
var shape_id: int = 0
var hit_interval: float = 0.25
var source_id: int = 0
var motion: int = Motion.LINEAR
var on_hit: int = OnHit.NONE

var homing_strength: float = 6.0
var orbit_target: Node2D
var orbit_radius: float = 120.0
var orbit_speed: float = 2.2
var orbit_angle: float = 0.0
var return_target: Node2D
var explode_radius: float = 120.0
var explode_damage_mult: float = 0.8
var chain_count: int = 3
var chain_range: float = 260.0
var slow_factor: float = 0.55
var slow_duration: float = 2.0
var scale_growth: float = 0.0
var spin: float = 6.0
## Distance ramp. A projectile with `ramp_to` above zero deals `ramp_near_mult`
## of its damage at `ramp_from` and full damage from `ramp_to` outward, which is
## what makes a bow a weapon for someone keeping their distance rather than a
## slower bullet.
var ramp_from: float = 0.0
var ramp_to: float = 0.0
var ramp_near_mult: float = 1.0

var _age: float = 0.0
var _alive: bool = false
var _homing_target: Enemy
var _retarget_timer: float = 0.0
var _returning: bool = false
var _hit_set: Dictionary = {}
var _sweep_timer: float = 0.0
var _origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	collision_layer = Layers.PLAYER_ATTACK
	collision_mask = Layers.ENEMY
	set_deferred("monitoring", true)
	set_deferred("monitorable", false)
	area_entered.connect(_on_area_entered)
	add_to_group(&"projectiles")


func pool_reset() -> void:
	_age = 0.0
	_alive = true
	_returning = false
	_homing_target = null
	_retarget_timer = 0.0
	_sweep_timer = 0.0
	_hit_set.clear()
	scale = Vector2.ONE
	rotation = 0.0
	set_deferred("monitoring", true)


func pool_sleep() -> void:
	_alive = false
	set_deferred("monitoring", false)


func configure(cfg: Dictionary) -> void:
	damage = float(cfg.get("damage", 10.0))
	crit_chance = float(cfg.get("crit_chance", 0.05))
	crit_damage = float(cfg.get("crit_damage", 1.6))
	knockback = float(cfg.get("knockback", 100.0))
	pierce_left = int(cfg.get("pierce", 0))
	lifetime = float(cfg.get("lifetime", 2.0))
	speed = float(cfg.get("speed", 700.0))
	direction = (cfg.get("direction", Vector2.RIGHT) as Vector2).normalized()
	radius = float(cfg.get("radius", 12.0))
	color = cfg.get("color", Palette.ACCENT)
	color2 = cfg.get("color2", Color.WHITE)
	shape_id = int(cfg.get("shape", 0))
	hit_interval = float(cfg.get("hit_interval", 0.25))
	source_id = int(cfg.get("source_id", get_instance_id()))
	motion = int(cfg.get("motion", Motion.LINEAR))
	on_hit = int(cfg.get("on_hit", OnHit.NONE))

	homing_strength = float(cfg.get("homing_strength", 6.0))
	orbit_target = cfg.get("orbit_target", null)
	orbit_radius = float(cfg.get("orbit_radius", 120.0))
	orbit_speed = float(cfg.get("orbit_speed", 2.2))
	orbit_angle = float(cfg.get("orbit_angle", 0.0))
	return_target = cfg.get("return_target", null)
	explode_radius = float(cfg.get("explode_radius", 120.0))
	explode_damage_mult = float(cfg.get("explode_damage_mult", 0.8))
	chain_count = int(cfg.get("chain_count", 3))
	chain_range = float(cfg.get("chain_range", 260.0))
	slow_factor = float(cfg.get("slow_factor", 0.55))
	slow_duration = float(cfg.get("slow_duration", 2.0))
	scale_growth = float(cfg.get("scale_growth", 0.0))
	spin = float(cfg.get("spin", 6.0))
	ramp_from = float(cfg.get("ramp_from", 0.0))
	ramp_to = float(cfg.get("ramp_to", 0.0))
	ramp_near_mult = float(cfg.get("ramp_near_mult", 1.0))
	_origin = cfg.get("position", global_position)

	var circle := _shape.shape as CircleShape2D
	if circle != null:
		circle.radius = radius
	if motion == Motion.ORBIT and orbit_target != null:
		global_position = orbit_target.global_position + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
	rotation = direction.angle()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	_age += delta
	if _age >= lifetime and motion != Motion.ORBIT:
		_expire()
		return

	match motion:
		Motion.LINEAR:
			global_position += direction * speed * delta
		Motion.HOMING:
			_update_homing(delta)
		Motion.ORBIT:
			_update_orbit(delta)
		Motion.BOOMERANG:
			_update_boomerang(delta)
		Motion.BOUNCE:
			_update_bounce(delta)
		Motion.SPIRAL:
			direction = direction.rotated(delta * 2.4)
			global_position += direction * speed * delta

	# Orbiting bodies and returning blades sit on top of enemies for many frames,
	# and area_entered only fires once, so they sweep for targets themselves.
	if motion == Motion.ORBIT or motion == Motion.BOOMERANG:
		_sweep_timer -= delta
		if _sweep_timer <= 0.0:
			_sweep_timer = 0.08
			_sweep_for_targets()

	if scale_growth != 0.0:
		var s := 1.0 + scale_growth * _age
		scale = Vector2(s, s)
	if spin != 0.0 and motion != Motion.LINEAR:
		rotation += spin * delta


func _update_homing(delta: float) -> void:
	_retarget_timer -= delta
	if _homing_target == null or not is_instance_valid(_homing_target) or not _homing_target.alive or _retarget_timer <= 0.0:
		_retarget_timer = 0.2
		if EnemyDirector.instance != null:
			_homing_target = EnemyDirector.instance.get_nearest(global_position, 700.0)
	if _homing_target != null and is_instance_valid(_homing_target) and _homing_target.alive:
		var want := (_homing_target.global_position - global_position).normalized()
		direction = direction.lerp(want, clampf(delta * homing_strength, 0.0, 1.0)).normalized()
		rotation = direction.angle()
	global_position += direction * speed * delta


func _update_orbit(delta: float) -> void:
	if orbit_target == null or not is_instance_valid(orbit_target):
		_expire()
		return
	orbit_angle += orbit_speed * delta
	global_position = orbit_target.global_position + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
	rotation += delta * 3.0
	# Orbit weapons live until their owner removes them.
	if lifetime > 0.0 and _age >= lifetime:
		_expire()


func _update_boomerang(delta: float) -> void:
	var half := lifetime * 0.45
	if not _returning and _age >= half:
		_returning = true
	if _returning and return_target != null and is_instance_valid(return_target):
		var want := (return_target.global_position - global_position)
		if want.length() < 40.0:
			_expire()
			return
		direction = direction.lerp(want.normalized(), clampf(delta * 4.0, 0.0, 1.0)).normalized()
		# Hitting an enemy on the way back should still count.
		_hit_set.clear()
	global_position += direction * speed * delta


func _update_bounce(delta: float) -> void:
	global_position += direction * speed * delta
	var anchor := Player.instance.global_position if Player.instance != null else Vector2.ZERO
	var local := global_position - anchor
	if absf(local.x) > BOUNCE_HALF_EXTENTS.x:
		direction.x = -direction.x
		global_position.x = anchor.x + signf(local.x) * BOUNCE_HALF_EXTENTS.x
	if absf(local.y) > BOUNCE_HALF_EXTENTS.y:
		direction.y = -direction.y
		global_position.y = anchor.y + signf(local.y) * BOUNCE_HALF_EXTENTS.y


# --- Hits -------------------------------------------------------------------

func _sweep_for_targets() -> void:
	if EnemyDirector.instance == null:
		return
	for enemy in EnemyDirector.instance.get_in_radius(global_position, radius * scale.x + 6.0, 8):
		_hit_enemy(enemy)


func _on_area_entered(area: Area2D) -> void:
	if not _alive or not (area is Enemy):
		return
	_hit_enemy(area as Enemy)


## 1.0 unless a ramp was configured, in which case it climbs from
## `ramp_near_mult` at `ramp_from` to full at `ramp_to`.
func _distance_scale() -> float:
	if ramp_to <= ramp_from:
		return 1.0
	var travelled := global_position.distance_to(_origin)
	var t := clampf((travelled - ramp_from) / (ramp_to - ramp_from), 0.0, 1.0)
	return lerpf(ramp_near_mult, 1.0, t)


func _hit_enemy(enemy: Enemy) -> void:
	if enemy == null or not enemy.alive:
		return
	var persistent := motion == Motion.ORBIT or motion == Motion.BOOMERANG
	var key := enemy.get_instance_id()
	if not persistent and _hit_set.has(key):
		return
	var is_crit := RunManager.rng.randf() < crit_chance
	var amount := damage * (crit_damage if is_crit else 1.0) * _distance_scale()
	var kb := direction * knockback
	# Transient projectiles already refuse repeat hits via _hit_set, so they bill
	# against their own id with no cooldown - otherwise every bolt from one
	# weapon would share a single rate limit and gut its damage. Persistent
	# shapes (orbits, boomerangs) genuinely need the shared interval.
	var hit_source := source_id if persistent else get_instance_id()
	var interval := hit_interval if persistent else 0.0
	if not enemy.apply_hit(amount, is_crit, kb, hit_source, interval):
		return
	if not persistent:
		_hit_set[key] = true
	AudioManager.play_sfx(&"hit", 0.2, -18.0)

	match on_hit:
		OnHit.EXPLODE:
			_explode(enemy.global_position, amount)
		OnHit.CHAIN:
			_chain(enemy, amount)
		OnHit.SLOW:
			enemy.apply_slow(slow_factor, slow_duration)
		OnHit.FREEZE:
			enemy.apply_slow(slow_factor * 0.4, slow_duration * 1.5)
		_:
			pass

	if persistent:
		# Orbiting bodies and returning blades keep going; the per-source hit
		# interval on the enemy is what limits their damage rate.
		return
	if pierce_left > 0:
		pierce_left -= 1
		return
	_expire()


func _explode(pos: Vector2, base_damage: float) -> void:
	if EnemyDirector.instance == null:
		return
	if EffectSpawner.instance != null:
		EffectSpawner.instance.spawn_explosion(pos, color, explode_radius)
	for enemy in EnemyDirector.instance.get_in_radius(pos, explode_radius, 40):
		enemy.apply_hit(base_damage * explode_damage_mult, false,
			(enemy.global_position - pos).normalized() * knockback * 1.4, source_id, 0.0)


func _chain(from_enemy: Enemy, base_damage: float) -> void:
	if EnemyDirector.instance == null:
		return
	var current := from_enemy
	var damage_left := base_damage * 0.8
	var hit := {current.get_instance_id(): true}
	for i in chain_count:
		var candidates := EnemyDirector.instance.get_in_radius(current.global_position, chain_range, 12)
		var next: Enemy = null
		for candidate in candidates:
			if hit.has(candidate.get_instance_id()) or not candidate.alive:
				continue
			next = candidate
			break
		if next == null:
			return
		hit[next.get_instance_id()] = true
		next.apply_hit(damage_left, false, Vector2.ZERO, source_id, 0.0)
		if EffectSpawner.instance != null:
			EffectSpawner.instance.spawn_hit_spark(next.global_position, color)
		current = next
		damage_left *= 0.8


func _expire() -> void:
	if not _alive:
		return
	_alive = false
	PoolManager.release(self)


## Lets an owning weapon retire persistent projectiles (orbit bodies).
func expire() -> void:
	_expire()


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	match shape_id:
		1:
			draw_circle(Vector2.ZERO, radius * 0.7, color)
			Draw2D.glow_circle(self, Vector2.ZERO, radius * 0.7, color, 2)
		2:
			Draw2D.ring(self, Vector2.ZERO, radius, color, 4.0)
			Draw2D.glow_circle(self, Vector2.ZERO, radius, color, 2)
		3:
			Draw2D.neon_polygon(self, Draw2D.polygon_points(4, radius, PI * 0.25), color2, color, 3.0)
			draw_circle(Vector2.ZERO, radius * 0.3, Color(1, 1, 1, 0.9))
		4:
			Draw2D.neon_polygon(self, Draw2D.polygon_points(6, radius, 0.0), color2, color, 3.0)
		5:
			draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.35))
			Draw2D.ring(self, Vector2.ZERO, radius, color, 3.0)
		6:
			Draw2D.neon_polygon(self, Draw2D.star_points(4, radius * 1.3, radius * 0.35, 0.0), color2, color, 3.0)
		7:
			Draw2D.neon_polygon(self, Draw2D.star_points(6, radius * 1.2, radius * 0.4, 0.0), color2, color, 2.5)
			draw_circle(Vector2.ZERO, radius * 0.4, Color(0, 0, 0, 0.7))
		8:
			# Arrow: a long shaft with a head and fletching, so a bow shot reads
			# as a different object from a bullet at the same size.
			ci_arrow(self, radius, color, color2)
		9:
			# Chakram: a ring with blades, spinning.
			Draw2D.ring(self, Vector2.ZERO, radius, color, 3.5)
			for i in 4:
				var a := TAU * float(i) / 4.0 + rotation * 0.0
				var base := Vector2(cos(a), sin(a)) * radius
				Draw2D.neon_polygon(self, PackedVector2Array([
					base * 0.72,
					base * 1.34 + Vector2(-sin(a), cos(a)) * radius * 0.22,
					base * 1.34 - Vector2(-sin(a), cos(a)) * radius * 0.10,
				]), color2, color, 2.0)
		10:
			# Slug: short, fat and bright - a heavy round rather than a dart.
			draw_circle(Vector2.ZERO, radius * 0.9, color2)
			Draw2D.ring(self, Vector2.ZERO, radius * 0.9, color, 3.0)
			draw_line(Vector2(-radius * 1.5, 0.0), Vector2(-radius * 0.6, 0.0),
				Color(color.r, color.g, color.b, 0.6), radius * 0.7, true)
		_:
			# Default bolt: a tapered dart pointing along its direction.
			var pts := PackedVector2Array([
				Vector2(radius * 1.6, 0.0),
				Vector2(-radius * 0.6, radius * 0.65),
				Vector2(-radius * 0.2, 0.0),
				Vector2(-radius * 0.6, -radius * 0.65),
			])
			Draw2D.neon_polygon(self, pts, color2, color, 2.5)
			Draw2D.glow_circle(self, Vector2.ZERO, radius * 0.8, color, 2)


## Arrow silhouette, drawn along +X so the projectile's own rotation aims it.
static func ci_arrow(ci: CanvasItem, radius: float, color: Color, color2: Color) -> void:
	var length := radius * 2.6
	ci.draw_line(Vector2(-length * 0.5, 0.0), Vector2(length * 0.36, 0.0), color, radius * 0.32, true)
	Draw2D.neon_polygon(ci, PackedVector2Array([
		Vector2(length * 0.5, 0.0),
		Vector2(length * 0.22, radius * 0.52),
		Vector2(length * 0.22, -radius * 0.52),
	]), color2, color, 2.0)
	# Fletching.
	for side in [-1.0, 1.0]:
		ci.draw_line(Vector2(-length * 0.5, 0.0),
			Vector2(-length * 0.28, side * radius * 0.46), color2, 2.0, true)
