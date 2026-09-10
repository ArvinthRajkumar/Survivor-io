class_name Boss
extends Enemy
## Level boss. Extends the pooled Enemy with health phases and a small attack
## rotation, and reports its state so the HUD can show a boss bar.

signal boss_spawned(title: String, display_name: String)
signal boss_health_changed(ratio: float)
signal boss_defeated

enum Attack { RADIAL, CHARGE, SUMMON, SLAM }

const BOSS_SCALE := 2.6

var phase: int = 0
var boss_title: String = ""

var _attack_timer: float = 2.5
var _attack_index: int = 0
var _charge_time: float = 0.0
var _charge_dir: Vector2 = Vector2.ZERO
var _thresholds: PackedFloat32Array = PackedFloat32Array()


func configure(enemy_data: EnemyData, elite: bool, health_scale: float, damage_scale: float) -> void:
	super.configure(enemy_data, false, health_scale, damage_scale)
	is_boss = true
	is_elite = false
	radius = enemy_data.radius * BOSS_SCALE
	move_speed = enemy_data.move_speed
	phase = 0
	_thresholds = enemy_data.boss_phase_thresholds
	boss_title = enemy_data.boss_title
	_attack_timer = 3.0
	_attack_index = 0
	_charge_time = 0.0
	var circle := ($Shape as CollisionShape2D).shape as CircleShape2D
	if circle != null:
		circle.radius = radius
	_build_visual()
	if not health.health_changed.is_connected(_on_boss_health_changed):
		health.health_changed.connect(_on_boss_health_changed)
	boss_spawned.emit(boss_title, enemy_data.display_name)
	boss_health_changed.emit(1.0)


func _on_boss_health_changed(current: float, maximum: float) -> void:
	var ratio := clampf(current / maxf(1.0, maximum), 0.0, 1.0)
	boss_health_changed.emit(ratio)
	_check_phase(ratio)


func _check_phase(ratio: float) -> void:
	var target_phase := 0
	for threshold in _thresholds:
		if ratio <= threshold:
			target_phase += 1
	if target_phase == phase:
		return
	phase = target_phase
	_on_phase_started()


## Each phase makes the boss faster and shortens the gap between attacks.
func _on_phase_started() -> void:
	move_speed = data.move_speed * (1.0 + 0.25 * float(phase))
	_attack_timer = 0.8
	AudioManager.play_sfx(&"boss_warning", 0.05, -6.0)
	if EffectSpawner.instance != null:
		EffectSpawner.instance.spawn_explosion(global_position, data.color, radius * 2.0)
	# Every phase change clears space with a shockwave.
	if EnemyDirector.instance != null:
		for enemy in EnemyDirector.instance.get_in_radius(global_position, radius * 3.0, 40):
			if enemy != self:
				enemy.apply_hit(0.0, false,
					(enemy.global_position - global_position).normalized() * 420.0,
					get_instance_id(), 0.0)


func update_ai(delta: float, player_pos: Vector2) -> void:
	if not alive:
		return
	if _charge_time > 0.0:
		# A committed dash: the boss ignores steering until the charge ends.
		_charge_time -= delta
		global_position += _charge_dir * move_speed * 3.4 * delta
		rotation += delta * 6.0
		return
	super.update_ai(delta, player_pos)
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = maxf(1.4, 4.2 - 0.7 * float(phase))
		_do_attack(player_pos)


func _do_attack(player_pos: Vector2) -> void:
	var attacks := [Attack.RADIAL, Attack.CHARGE, Attack.SUMMON, Attack.SLAM]
	var attack: int = attacks[_attack_index % attacks.size()]
	_attack_index += 1
	match attack:
		Attack.RADIAL:
			_attack_radial()
		Attack.CHARGE:
			_attack_charge(player_pos)
		Attack.SUMMON:
			_attack_summon()
		_:
			_attack_slam()


func _attack_radial() -> void:
	if EffectSpawner.instance == null:
		return
	var count := 12 + 4 * phase
	for i in count:
		var a := TAU * float(i) / float(count) + RunManager.rng.randf() * 0.2
		EffectSpawner.instance.spawn_enemy_projectile(global_position,
			Vector2(cos(a), sin(a)), data.projectile_speed,
			data.projectile_damage * RunManager.enemy_damage_scale(), data.color)
	AudioManager.play_sfx(&"explosion", 0.1, -8.0)


func _attack_charge(player_pos: Vector2) -> void:
	_charge_dir = (player_pos - global_position).normalized()
	_charge_time = 0.85


func _attack_summon() -> void:
	if EnemyDirector.instance == null or RunManager.level_data == null:
		return
	var pool := RunManager.level_data.enemy_pool
	if pool.is_empty():
		return
	var minion: EnemyData = pool[RunManager.rng.randi() % pool.size()]
	var count := 4 + 2 * phase
	for i in count:
		var offset := MathUtil.random_point_in_ring(RunManager.rng, radius * 1.2, radius * 2.4)
		EnemyDirector.instance.spawn_at(minion, global_position + offset, false)


func _attack_slam() -> void:
	if ProjectileSystem.instance == null:
		return
	ProjectileSystem.instance.spawn_zone({
		"position": global_position,
		"damage": 0.0,
		"tick_interval": 999.0,
		"radius": radius * 3.2,
		"lifetime": 0.9,
		"color": data.color,
		"style": DamageZone.Style.SHOCK,
	})
	var timer := get_tree().create_timer(0.9, false)
	timer.timeout.connect(_slam_land.bind(global_position))


func _slam_land(pos: Vector2) -> void:
	if not alive:
		return
	var player := Player.instance
	if player != null and player.global_position.distance_to(pos) < radius * 3.2:
		player.take_damage(contact_damage * 1.8, pos)
		player.apply_knockback((player.global_position - pos).normalized() * 420.0)
	if EffectSpawner.instance != null:
		EffectSpawner.instance.spawn_explosion(pos, data.color, radius * 3.2)


func _on_died() -> void:
	if not alive:
		return
	alive = false
	RunManager.register_kill(false, true)
	if EffectSpawner.instance != null:
		EffectSpawner.instance.spawn_explosion(global_position, data.color, radius * 3.0)
		EffectSpawner.instance.spawn_boss_drop(global_position)
	boss_defeated.emit()
	died.emit(self)
	PoolManager.release(self)


func _draw() -> void:
	super._draw()
	# Phase pips orbiting the boss so its state reads at a glance.
	for i in _thresholds.size() + 1:
		var a := TAU * float(i) / float(_thresholds.size() + 1) + float(phase) * 0.4
		var p := Vector2(cos(a), sin(a)) * (radius * 1.25)
		var lit := i >= phase
		draw_circle(p, 7.0, Color(1.0, 0.85, 0.35, 0.95) if lit else Color(0.3, 0.3, 0.35, 0.6))
