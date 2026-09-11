class_name UltimateController
extends Node2D
## Charges and executes hero ultimates.
##
## Each hero's ultimate is one branch here rather than a scene per hero: they all
## reuse the same pooled projectiles and damage zones, so the differences are
## small enough to read side by side.

## Baby's Standstill. A hard slow over most of the screen, refreshed often
## enough that enemies arriving mid-ultimate are caught by it too.
const STANDSTILL_FACTOR := 0.22
const STANDSTILL_RANGE := 900.0
const STANDSTILL_REFRESH := 0.35

signal charge_changed(ratio: float)
signal activated(hero_id: StringName)
signal ended

var player: Player
var hero: HeroData
var cooldown: float = 40.0
var duration: float = 8.0

var _charge: float = 0.0
var _active_time: float = 0.0
var _standstill_timer: float = 0.0
var _active: bool = false
var _reflect: bool = false
var _drones: Array[Projectile] = []
var _flame_wall: DamageZone
var _last_ratio: float = -1.0


func setup(owner_player: Player, hero_data: HeroData) -> void:
	player = owner_player
	hero = hero_data
	if hero != null:
		cooldown = maxf(5.0, hero.ultimate_cooldown)
		duration = hero.ultimate_duration
	_charge = cooldown * 0.35  # start part-charged so it is usable early
	set_process(true)


func _process(delta: float) -> void:
	if player == null or player.is_dead:
		return
	if _active:
		_active_time -= delta
		_tick_active(delta)
		if _active_time <= 0.0:
			_end()
	elif _charge < cooldown:
		# Cooldown reduction shortens the wait, same as it does for weapons.
		var rate := 1.0
		if player.stats != null:
			rate = 2.0 - clampf(player.stats.get_stat(&"cooldown_mult"), 0.35, 1.6)
		_charge = minf(cooldown, _charge + delta * maxf(0.35, rate))
	var ratio := get_charge_ratio()
	if not is_equal_approx(ratio, _last_ratio):
		_last_ratio = ratio
		charge_changed.emit(ratio)

	if Input.is_action_just_pressed("use_ultimate"):
		activate()


func get_charge_ratio() -> float:
	if _active:
		return 1.0
	return clampf(_charge / maxf(0.01, cooldown), 0.0, 1.0)


func is_ready() -> bool:
	return not _active and _charge >= cooldown


func is_active() -> bool:
	return _active


func is_reflecting() -> bool:
	return _active and _reflect


func activate() -> bool:
	if not is_ready() or player == null or player.is_dead:
		return false
	if ProjectileSystem.instance == null:
		return false
	_charge = 0.0
	_active = true
	_active_time = duration
	AudioManager.play_sfx(&"ultimate")
	AudioManager.vibrate(60)
	match hero.ultimate_id:
		&"plasma_drones":
			_start_plasma_drones()
		&"thorn_maze":
			_start_thorn_maze()
		&"rift_walk":
			_start_rift_walk()
		&"aegis_bulwark":
			_start_aegis()
		&"flame_wall":
			_start_flame_wall()
		&"standstill":
			_start_standstill()
		_:
			_start_plasma_drones()
	activated.emit(hero.ultimate_id)
	return true


func _tick_active(delta: float) -> void:
	match hero.ultimate_id:
		&"rift_walk":
			_tick_rift_walk(delta)
		&"standstill":
			_tick_standstill(delta)
		_:
			pass


## Baby's Standstill: everything on the field crawls while she keeps moving.
##
## Re-applied on a timer rather than once, because enemies that spawn during the
## ultimate have to be caught too - otherwise the wave arriving halfway through
## walks straight past it.
func _start_standstill() -> void:
	_standstill_timer = 0.0
	_apply_standstill()


func _tick_standstill(delta: float) -> void:
	_standstill_timer -= delta
	if _standstill_timer > 0.0:
		return
	_apply_standstill()


func _apply_standstill() -> void:
	_standstill_timer = STANDSTILL_REFRESH
	if EnemyDirector.instance == null or player == null:
		return
	for enemy in EnemyDirector.instance.get_in_radius(player.global_position,
			STANDSTILL_RANGE, 200):
		enemy.apply_slow(STANDSTILL_FACTOR, STANDSTILL_REFRESH * 2.0)
	if EffectSpawner.instance != null:
		EffectSpawner.instance.spawn_death_burst(player.global_position,
			hero.accent_secondary, 150.0)


func _end() -> void:
	_active = false
	_reflect = false
	for drone in _drones:
		if drone != null and is_instance_valid(drone):
			drone.expire()
	_drones.clear()
	if _flame_wall != null and is_instance_valid(_flame_wall):
		_flame_wall.expire()
		_flame_wall = null
	ended.emit()


func _power() -> float:
	# Ultimates scale with the same damage stat as weapons so builds matter.
	var mult := 1.0
	if player != null and player.stats != null:
		mult = player.stats.get_stat(&"damage_mult")
	return mult


# --- Nova ------------------------------------------------------------------

func _start_plasma_drones() -> void:
	var count := 5
	for i in count:
		var drone := ProjectileSystem.instance.spawn_projectile({
			"position": player.global_position,
			"direction": Vector2.RIGHT,
			"motion": Projectile.Motion.ORBIT,
			"orbit_target": player,
			"orbit_radius": 165.0,
			"orbit_speed": 3.1,
			"orbit_angle": TAU * float(i) / float(count),
			"lifetime": duration,
			"damage": 34.0 * _power(),
			"radius": 24.0,
			"shape": 3,
			"color": hero.accent,
			"color2": hero.accent_secondary,
			"hit_interval": 0.28,
			"knockback": 180.0,
			"crit_chance": player.stats.get_stat(&"crit_chance"),
			"crit_damage": player.stats.get_stat(&"crit_damage_mult"),
			"source_id": get_instance_id(),
		})
		if drone != null:
			_drones.append(drone)


# --- Bramble ---------------------------------------------------------------

func _start_thorn_maze() -> void:
	# A lattice of thorn patches that slow anything walking through it.
	for i in 7:
		var offset := MathUtil.random_point_in_ring(RunManager.rng, 90.0, 420.0)
		ProjectileSystem.instance.spawn_zone({
			"position": player.global_position + offset,
			"damage": 16.0 * _power(),
			"tick_interval": 0.45,
			"radius": 130.0,
			"lifetime": duration,
			"color": hero.accent,
			"color2": hero.accent_secondary,
			"style": DamageZone.Style.THORNS,
			"slow_factor": 0.35,
			"slow_duration": 1.2,
			"source_id": get_instance_id(),
			"max_targets": 30,
		})


# --- Rift ------------------------------------------------------------------

var _rift_timer: float = 0.0

func _start_rift_walk() -> void:
	_rift_timer = 0.0
	_blink()


func _tick_rift_walk(delta: float) -> void:
	_rift_timer -= delta
	if _rift_timer <= 0.0:
		_rift_timer = 1.1
		_blink()


## Leaves a damaging tear behind, then teleports toward the densest cluster.
func _blink() -> void:
	var from := player.global_position
	ProjectileSystem.instance.spawn_zone({
		"position": from,
		"damage": 30.0 * _power(),
		"tick_interval": 0.35,
		"radius": 150.0,
		"lifetime": 3.2,
		"color": hero.accent,
		"color2": hero.accent_secondary,
		"style": DamageZone.Style.RIFT,
		"pull_force": 120.0,
		"source_id": get_instance_id(),
	})
	var target := _find_cluster(from)
	player.global_position = target
	player.grant_invulnerability(0.6)
	if EffectSpawner.instance != null:
		EffectSpawner.instance.spawn_death_burst(target, hero.accent, 60.0)


func _find_cluster(from: Vector2) -> Vector2:
	if EnemyDirector.instance == null:
		return from + MathUtil.random_point_on_circle(RunManager.rng, 300.0)
	var best := from
	var best_count := -1
	for i in 6:
		var candidate := from + MathUtil.random_point_in_ring(RunManager.rng, 220.0, 520.0)
		var count := EnemyDirector.instance.get_in_radius(candidate, 200.0, 24).size()
		if count > best_count:
			best_count = count
			best = candidate
	return best


# --- Aegis -----------------------------------------------------------------

func _start_aegis() -> void:
	_reflect = true
	player.grant_invulnerability(duration)
	ProjectileSystem.instance.spawn_zone({
		"position": player.global_position,
		"damage": 10.0 * _power(),
		"tick_interval": 0.5,
		"radius": 150.0,
		"lifetime": duration,
		"color": hero.accent,
		"color2": hero.accent_secondary,
		"style": DamageZone.Style.FIELD,
		"knockback": 260.0,
		"follow": player,
		"source_id": get_instance_id(),
	})


## Called by Player when a hit lands during the bulwark.
func reflect_damage(amount: float, source_position: Vector2) -> void:
	if EnemyDirector.instance == null:
		return
	for enemy in EnemyDirector.instance.get_in_radius(source_position, 180.0, 20):
		enemy.apply_hit(amount * 2.5, true, Vector2.ZERO, get_instance_id(), 0.0)


# --- Ember -----------------------------------------------------------------

func _start_flame_wall() -> void:
	var dir := player.facing
	if dir.length_squared() < 0.01:
		dir = Vector2.UP
	_flame_wall = ProjectileSystem.instance.spawn_zone({
		"position": player.global_position + dir * 120.0,
		"damage": 26.0 * _power(),
		"tick_interval": 0.28,
		"radius": 190.0,
		"lifetime": duration,
		"color": hero.accent,
		"color2": hero.accent_secondary,
		"style": DamageZone.Style.FLAME,
		"move_dir": dir,
		"move_speed": 130.0,
		"knockback": 90.0,
		"growth": 14.0,
		"source_id": get_instance_id(),
		"max_targets": 50,
	})
