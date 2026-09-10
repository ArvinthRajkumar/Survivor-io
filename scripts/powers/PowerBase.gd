class_name PowerBase
extends Node2D
## Base class for every active Power.
##
## Subclasses implement _fire() (and optionally _on_tick / _on_setup); cooldowns,
## stat scaling, crit rolls and the "is this at max level" question all live here
## so the seven behaviours stay short and comparable.

signal fired

var data: PowerData
var level: int = 1
var player: Player
var stats: PlayerStats
var firing: bool = true

var _cooldown_left: float = 0.0


func setup(power_data: PowerData, power_level: int, owner_player: Player, owner_stats: PlayerStats) -> void:
	data = power_data
	level = power_level
	player = owner_player
	stats = owner_stats
	# Stagger the first shot so a full loadout does not fire in lockstep.
	_cooldown_left = RunManager.rng.randf() * 0.5
	_on_setup()


func set_level(value: int) -> void:
	var was_max := is_max_level()
	level = value
	_on_level_changed()
	if is_max_level() and not was_max:
		_on_reached_max_level()


func set_firing(value: bool) -> void:
	firing = value


func _process(delta: float) -> void:
	if data == null or player == null:
		return
	_on_tick(delta)
	if not firing or player.is_dead:
		return
	_cooldown_left -= delta
	if _cooldown_left <= 0.0:
		_cooldown_left = maxf(0.08, get_cooldown())
		_fire()
		fired.emit()


## Fraction of the current cooldown already elapsed, for HUD readouts.
func get_charge_ratio() -> float:
	var total := maxf(0.08, get_cooldown())
	return clampf(1.0 - _cooldown_left / total, 0.0, 1.0)


# --- Hooks ------------------------------------------------------------------

func _on_setup() -> void:
	pass


func _on_level_changed() -> void:
	pass


## Called once, the moment this power reaches its final level. Several powers
## change behaviour outright here rather than just scaling.
func _on_reached_max_level() -> void:
	pass


func _on_tick(_delta: float) -> void:
	pass


func _fire() -> void:
	pass


# --- Derived stats ----------------------------------------------------------

func is_max_level() -> bool:
	return data != null and level >= data.max_level


func get_damage() -> float:
	return data.damage_at(level) * stats.get_stat(&"damage_mult")


func get_cooldown() -> float:
	return data.cooldown_at(level) * stats.get_stat(&"cooldown_mult")


func get_area() -> float:
	return data.area_at(level) * stats.get_stat(&"area_mult")


func get_count() -> int:
	# projectile_count_bonus is fractional so a passive can grant half a
	# projectile per level and pay out every second one.
	var bonus := 0
	if stats != null:
		bonus = int(floor(stats.get_stat(&"projectile_count_bonus")))
	return maxi(1, data.count_at(level) + bonus)


func get_speed() -> float:
	return data.projectile_speed * stats.get_stat(&"projectile_speed_mult")


func get_duration() -> float:
	return data.duration_at(level) * stats.get_stat(&"duration_mult")


func get_knockback() -> float:
	return data.knockback * stats.get_stat(&"knockback_mult")


func get_crit_chance() -> float:
	return clampf(stats.get_stat(&"crit_chance"), 0.0, 0.95)


func get_crit_damage() -> float:
	return stats.get_stat(&"crit_damage_mult")


func base_config() -> Dictionary:
	return {
		"damage": get_damage(),
		"crit_chance": get_crit_chance(),
		"crit_damage": get_crit_damage(),
		"knockback": get_knockback(),
		"pierce": data.pierce,
		"lifetime": get_duration(),
		"speed": get_speed(),
		"radius": 12.0 * get_area(),
		"color": data.color,
		"color2": data.color_secondary,
		"hit_interval": data.hit_interval,
		"source_id": get_instance_id(),
	}


func find_target(max_dist: float = 900.0) -> Enemy:
	if EnemyDirector.instance == null:
		return null
	return EnemyDirector.instance.get_nearest(player.global_position, max_dist)


func aim_direction(fallback: Vector2 = Vector2.RIGHT) -> Vector2:
	var target := find_target()
	if target != null:
		return (target.global_position - player.global_position).normalized()
	if player.facing.length_squared() > 0.01:
		return player.facing
	return fallback


func play_sound(id: StringName, volume_db: float = -10.0) -> void:
	AudioManager.play_sfx(id, 0.1, volume_db)


# --- Null-safe spawn helpers ------------------------------------------------

func spawn_projectile(cfg: Dictionary) -> Projectile:
	if ProjectileSystem.instance == null:
		return null
	return ProjectileSystem.instance.spawn_projectile(cfg)


func spawn_zone(cfg: Dictionary) -> DamageZone:
	if ProjectileSystem.instance == null:
		return null
	return ProjectileSystem.instance.spawn_zone(cfg)


## Direct area damage, used by the powers that hit without a travelling body.
func damage_area(center: Vector2, radius: float, amount: float, knockback_force: float = 0.0,
		limit: int = 40) -> int:
	if EnemyDirector.instance == null:
		return 0
	var hit := 0
	for enemy in EnemyDirector.instance.get_in_radius(center, radius, limit):
		var is_crit := RunManager.rng.randf() < get_crit_chance()
		var dealt := amount * (get_crit_damage() if is_crit else 1.0)
		var push := Vector2.ZERO
		if knockback_force != 0.0:
			push = (enemy.global_position - center).normalized() * knockback_force
		if enemy.apply_hit(dealt, is_crit, push, get_instance_id(), 0.0):
			hit += 1
	return hit
