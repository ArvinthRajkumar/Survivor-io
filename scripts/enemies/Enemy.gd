class_name Enemy
extends Area2D
## A single pooled enemy, configured at spawn time from an EnemyData resource.
##
## Performance notes (this is the node the game has the most of):
##  * Enemies do not run their own _physics_process. EnemyDirector drives them
##    in one loop, which avoids hundreds of per-node callbacks per frame.
##  * They are `monitorable` but not `monitoring`: projectiles and the player's
##    hurtbox look for enemies, never the other way round.
##  * _draw() runs on a stagger at roughly 11Hz rather than every frame. The
##    creatures are animated now, so the old "only when the appearance changes"
##    rule no longer holds - but a limb cycle at 11Hz is the rate hand-drawn
##    animation runs at anyway, and redrawing 260 of these every frame is not
##    something a phone will do.

signal died(enemy: Enemy)

const ELITE_HEALTH_MULT := 6.5
const ELITE_DAMAGE_MULT := 1.6
const ELITE_SCALE := 1.45
const FLASH_TIME := 0.09
## Seconds between animation redraws. Staggered per enemy so the whole swarm
## never redraws on the same frame.
const REDRAW_INTERVAL := 0.09
## How close the player has to be before a melee body plan winds up a swing.
const MELEE_RANGE := 30.0
const WINDUP_TIME := 0.22
const STRIKE_TIME := 0.26
## How long the muzzle flash and recoil last after a shot.
const SHOOT_TIME := 0.24

@onready var health: HealthComponent = $Health
@onready var _shape: CollisionShape2D = $Shape

var data: EnemyData
var is_elite: bool = false
var is_boss: bool = false
var alive: bool = false

var velocity: Vector2 = Vector2.ZERO
## Crowd-avoidance force, written by EnemyDirector and read here. It is not
## cleared per tick: the director recomputes it on its own cadence and this
## enemy keeps pushing with the last value in between, which is what stops the
## swarm from collapsing on the frames the separation pass skips.
var separation: Vector2 = Vector2.ZERO
var radius: float = 22.0
var contact_damage: float = 8.0
var move_speed: float = 100.0
var xp_value: int = 1
var credit_value: int = 1

var _knockback: Vector2 = Vector2.ZERO
var _flash: float = 0.0
var _ai_timer: float = 0.0
var _charging: float = 0.0
var _slow_factor: float = 1.0
var _slow_timer: float = 0.0
## Per-spawn personality: which way this one prefers to peel off around the
## player, how it wanders, and a small speed offset. Together these are what
## turn a wave from one moving blob into a crowd.
var _flank: float = 1.0
var _wander_phase: float = 0.0
var _wander_rate: float = 1.0
var _wander_amount: float = 0.2
var _speed_jitter: float = 1.0
## A standing offset from the player that this enemy actually steers at, re-rolled
## slowly. Every enemy solving for the exact same point is what packs a chasing
## pack into one solid mass; aiming a little off it spreads them into a cloud.
var _target_offset: Vector2 = Vector2.ZERO
var _offset_timer: float = 0.0
var _fill: Color = Color.WHITE
var _outline: Color = Color.WHITE
var _accent: Color = Color.WHITE
## Which of EnemyArt's six body plans this archetype wears.
var _body: int = EnemyArt.Body.MAW
## Advanced by distance travelled rather than by time, so a slowed enemy's legs
## slow down with it instead of running on the spot.
var _gait: float = 0.0
var _facing_left: bool = false
## Per-archetype animation speed, taken from what used to be the spin rate.
var _gait_bias: float = 1.0
var _anim_state: int = EnemyArt.State.MOVE
var _anim_timer: float = 0.0
var _anim_span: float = 1.0
var _redraw_timer: float = 0.0
## Melee bodies re-arm after a swing so they do not chain-bite in place.
var _swing_cooldown: float = 0.0
## instance id of a damage source -> RunManager.elapsed at which it may hit again
var _hit_cooldowns: Dictionary = {}
var _time: float = 0.0


func _ready() -> void:
	set_deferred("monitoring", false)
	set_deferred("monitorable", true)
	collision_layer = Layers.ENEMY
	collision_mask = 0
	health.died.connect(_on_died)


# --- Pooling ---------------------------------------------------------------

func pool_reset() -> void:
	alive = false
	velocity = Vector2.ZERO
	separation = Vector2.ZERO
	_knockback = Vector2.ZERO
	_flash = 0.0
	_ai_timer = 0.0
	_charging = 0.0
	_slow_factor = 1.0
	_slow_timer = 0.0
	_hit_cooldowns.clear()
	modulate = Color.WHITE
	set_deferred("monitorable", true)
	_roll_personality()


## Re-rolled on every spawn, so a recycled node never inherits the approach of
## the enemy that used it last.
func _roll_personality() -> void:
	var rng := RunManager.rng
	_flank = 1.0 if rng.randf() < 0.5 else -1.0
	_wander_phase = rng.randf() * TAU
	_wander_rate = rng.randf_range(0.7, 1.9)
	_wander_amount = rng.randf_range(0.16, 0.42)
	# A wide speed spread is what strings a chasing pack out into a column with
	# stragglers, instead of a rigid body moving as one.
	_speed_jitter = rng.randf_range(0.80, 1.24)
	_offset_timer = rng.randf_range(1.0, 4.0)
	_reroll_target_offset()


func _reroll_target_offset() -> void:
	var rng := RunManager.rng
	_target_offset = MathUtil.random_point_on_circle(rng, 1.0) * rng.randf_range(30.0, 170.0)


func pool_sleep() -> void:
	alive = false
	set_deferred("monitorable", false)
	if is_in_group(&"enemies"):
		remove_from_group(&"enemies")


## Applies an EnemyData plus the current run scaling.
func configure(enemy_data: EnemyData, elite: bool, health_scale: float, damage_scale: float) -> void:
	data = enemy_data
	is_elite = elite and enemy_data.can_be_elite
	is_boss = enemy_data.is_boss
	radius = enemy_data.radius * (ELITE_SCALE if is_elite else 1.0)
	move_speed = enemy_data.move_speed * (0.86 if is_elite else 1.0) * _speed_jitter
	contact_damage = enemy_data.contact_damage * damage_scale * (ELITE_DAMAGE_MULT if is_elite else 1.0)
	xp_value = enemy_data.xp_value * (5 if is_elite else 1)
	credit_value = enemy_data.credit_value * (4 if is_elite else 1)
	# EnemyData.spin_speed used to rotate the polygon body. The creatures are
	# drawn front-facing now, so a spinning one would read as tumbling; the
	# field feeds the gait instead, which is where a "restless" archetype should
	# show anyway.
	_gait_bias = 1.0 + absf(enemy_data.spin_speed) * 0.20

	var hp := enemy_data.max_health * health_scale * (ELITE_HEALTH_MULT if is_elite else 1.0)
	health.setup(hp)
	health.armor = 0.0

	var circle := _shape.shape as CircleShape2D
	if circle != null:
		circle.radius = radius
	_build_visual()
	alive = true
	rotation = 0.0
	if not is_in_group(&"enemies"):
		add_to_group(&"enemies")


func _build_visual() -> void:
	_fill = data.color_secondary
	_outline = data.color
	_accent = data.color.lerp(Color.WHITE, 0.35)
	if is_elite:
		_outline = _outline.lerp(Color(1.0, 0.86, 0.35), 0.55)
		_fill = _fill.lerp(Color(0.25, 0.18, 0.02), 0.5)
		_accent = Color(1.0, 0.90, 0.45)
	# EnemyData.shape is what the roster on disk already stores, so the six body
	# plans are keyed to it directly rather than re-authoring 28 resources.
	_body = clampi(data.shape, 0, 5)
	_gait = RunManager.rng.randf() * TAU
	_anim_state = EnemyArt.State.MOVE
	_anim_timer = 0.0
	_redraw_timer = RunManager.rng.randf() * REDRAW_INTERVAL
	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	if is_elite:
		Draw2D.ring(self, Vector2.ZERO, radius * 1.45, Color(1.0, 0.86, 0.35, 0.45), 2.5)
	var t := 0.0
	if _anim_span > 0.0:
		t = clampf(1.0 - _anim_timer / _anim_span, 0.0, 1.0)
	EnemyArt.draw_body(self, _body, radius, _fill, _outline, _accent,
		_gait, _anim_state, t, _facing_left)


# --- Simulation (driven by EnemyDirector) ----------------------------------

func update_ai(delta: float, player_pos: Vector2) -> void:
	if not alive:
		return
	_time += delta
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			modulate = Color.WHITE
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_factor = 1.0

	_advance_animation(delta, player_pos)

	_offset_timer -= delta
	if _offset_timer <= 0.0:
		_offset_timer = RunManager.rng.randf_range(2.5, 6.0)
		_reroll_target_offset()

	# The standing offset spreads the *approach*; it is faded out at close range
	# so the swarm still converges and can actually touch the player. Left at
	# full strength it parks everything in a ring and the game stops biting.
	var raw_distance := player_pos.distance_to(global_position)
	var offset_scale := clampf((raw_distance - 120.0) / 400.0, 0.0, 1.0)
	var to_player := player_pos + _target_offset * offset_scale - global_position
	var dir := to_player.normalized()
	var desired := Vector2.ZERO

	match data.ai:
		EnemyData.AI.CHASER:
			desired = _approach(dir, raw_distance) * move_speed
		EnemyData.AI.DRIFTER:
			# Weaves instead of beelining, which spreads the swarm out.
			var wobble := dir.orthogonal() * sin(_time * 2.2 + _wander_phase) * 0.55
			desired = (_approach(dir, raw_distance) + wobble).normalized() * move_speed
		EnemyData.AI.CHARGER:
			_ai_timer -= delta
			if _charging > 0.0:
				_charging -= delta
				desired = velocity.normalized() * move_speed * data.charge_speed_mult
			elif _ai_timer <= 0.0 and raw_distance < 620.0:
				_charging = 0.55
				_ai_timer = data.charge_interval
				desired = dir * move_speed * data.charge_speed_mult
			else:
				desired = dir * move_speed * 0.55
		EnemyData.AI.SHOOTER:
			_ai_timer -= delta
			var range_target := 340.0
			var gap := raw_distance - range_target
			desired = _approach(dir, raw_distance) * move_speed * clampf(gap / 120.0, -0.8, 1.0)
			if _ai_timer <= 0.0 and raw_distance < 720.0:
				_ai_timer = data.shoot_interval
				_shoot(dir)
		EnemyData.AI.SPLITTER:
			desired = _approach(dir, raw_distance) * move_speed
		EnemyData.AI.ORBITER:
			var tangent := dir.orthogonal()
			var radial := raw_distance - data.orbit_radius
			desired = (tangent + dir * clampf(radial / 160.0, -1.0, 1.0)).normalized() * move_speed

	desired += separation
	velocity = velocity.lerp(desired * _slow_factor, clampf(delta * 8.0, 0.0, 1.0))
	if _knockback.length_squared() > 1.0:
		global_position += _knockback * delta
		_knockback = _knockback.lerp(Vector2.ZERO, clampf(delta * 7.0, 0.0, 1.0))
	global_position += velocity * delta


## Drives the creature sprite: which way it is facing, how far through its walk
## cycle it is, and whether it is mid-attack.
##
## The gait advances with distance covered rather than with time, so a slowed or
## knocked-back enemy visibly slows its legs instead of running on the spot.
func _advance_animation(delta: float, player_pos: Vector2) -> void:
	var speed := velocity.length()
	_gait += delta * (2.0 + speed * 0.035) * _gait_bias
	# A creature barely moving keeps its last facing rather than flickering
	# between them every time the separation force jitters sideways.
	if absf(velocity.x) > 12.0:
		_facing_left = velocity.x < 0.0

	if _swing_cooldown > 0.0:
		_swing_cooldown -= delta

	if _anim_state != EnemyArt.State.MOVE:
		_anim_timer -= delta
		if _anim_timer > 0.0:
			# Wind-up rolls straight into the strike; everything else returns to
			# walking.
			return
		if _anim_state == EnemyArt.State.WINDUP:
			_set_anim(EnemyArt.State.STRIKE, STRIKE_TIME)
		else:
			_set_anim(EnemyArt.State.MOVE, 0.0)
			_swing_cooldown = 0.6
		return

	# Melee bodies wind up once the player is within reach. Shooters get their
	# animation from _shoot() instead, at the moment they actually fire.
	if data.ai != EnemyData.AI.SHOOTER and _swing_cooldown <= 0.0:
		var reach := radius + MELEE_RANGE
		if player_pos.distance_squared_to(global_position) < reach * reach:
			_set_anim(EnemyArt.State.WINDUP, WINDUP_TIME)


func _set_anim(state: int, span: float) -> void:
	_anim_state = state
	_anim_span = maxf(0.0001, span)
	_anim_timer = span
	queue_redraw()


## Called by EnemyDirector after update_ai, on its own reduced cadence.
func tick_visual(delta: float) -> void:
	if not alive:
		return
	_redraw_timer -= delta
	if _redraw_timer > 0.0:
		return
	_redraw_timer = REDRAW_INTERVAL
	queue_redraw()


## Heading for anything that closes on the player.
##
## Walking straight at the target is what makes a swarm pile into a single dot:
## every enemy solves for the same point and they end up stacked on it. Instead
## each one peels onto its own side as it closes, so the crowd wraps around the
## player and stays a crowd. A slow wander on top keeps neighbours from
## converging on identical curves.
func _approach(dir: Vector2, distance: float) -> Vector2:
	# The peel starts a long way out, not just at arm's reach: a pack that only
	# fans at the last moment has already arrived as a blob by then.
	var wrap := clampf(1.0 - distance / 520.0, 0.0, 1.0)
	var tangent := dir.orthogonal() * _flank
	var wander := dir.orthogonal() * sin(_time * _wander_rate + _wander_phase) * _wander_amount
	var heading := dir * (1.0 - 0.45 * wrap) + tangent * (0.85 * wrap) + wander
	return heading.normalized() if heading.length_squared() > 0.0001 else dir


func _shoot(dir: Vector2) -> void:
	_facing_left = dir.x < 0.0
	_set_anim(EnemyArt.State.SHOOT, SHOOT_TIME)
	if EffectSpawner.instance == null:
		return
	EffectSpawner.instance.spawn_enemy_projectile(
		global_position, dir, data.projectile_speed,
		data.projectile_damage, data.color)


# --- Damage ----------------------------------------------------------------

## Returns true if the hit landed (it may be refused by the per-source cooldown).
func apply_hit(amount: float, is_crit: bool, knockback: Vector2, source_id: int, hit_interval: float) -> bool:
	if not alive or health.is_dead():
		return false
	if hit_interval > 0.0:
		# Game time, not wall-clock: Time.get_ticks_msec() keeps running while
		# the game is paused and ignores any time scaling, which silently broke
		# every persistent weapon (auras, orbits, boomerangs).
		var now := RunManager.elapsed
		if now < float(_hit_cooldowns.get(source_id, -1.0)):
			return false
		_hit_cooldowns[source_id] = now + hit_interval
	var dealt := health.take_damage(amount, is_crit, global_position)
	if dealt <= 0.0:
		return false
	RunManager.register_damage(dealt)
	_flash = FLASH_TIME
	modulate = Color(2.4, 2.4, 2.4)
	var resist := 1.0 - clampf(data.knockback_resist, 0.0, 1.0)
	_knockback += knockback * resist / maxf(0.2, data.mass)
	if EffectSpawner.instance != null:
		EffectSpawner.instance.spawn_damage_number(global_position, dealt, is_crit)
		EffectSpawner.instance.spawn_hit_spark(global_position, data.color)
	return true


func apply_slow(factor: float, duration: float) -> void:
	_slow_factor = minf(_slow_factor, clampf(factor, 0.1, 1.0))
	_slow_timer = maxf(_slow_timer, duration)


func _on_died() -> void:
	if not alive:
		return
	alive = false
	RunManager.register_kill(is_elite, is_boss)
	AudioManager.play_sfx(&"kill", 0.16, -6.0)
	if EffectSpawner.instance != null:
		EffectSpawner.instance.spawn_death_burst(global_position, data.color, radius)
		EffectSpawner.instance.spawn_xp(global_position, xp_value)
		if is_elite:
			EffectSpawner.instance.spawn_elite_drop(global_position)
	if data.ai == EnemyData.AI.SPLITTER and not String(data.split_into_id).is_empty():
		_split()
	died.emit(self)
	PoolManager.release(self)


func _split() -> void:
	if EnemyDirector.instance == null:
		return
	var child := ContentDB.get_enemy(data.split_into_id)
	if child == null:
		return
	for i in data.split_count:
		var offset := MathUtil.random_point_on_circle(RunManager.rng, radius * 1.2)
		EnemyDirector.instance.spawn_at(child, global_position + offset, false)


## Used by bosses/hazards to remove an enemy without granting rewards.
func despawn() -> void:
	alive = false
	PoolManager.release(self)
