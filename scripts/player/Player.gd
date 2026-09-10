class_name Player
extends CharacterBody2D
## The player avatar. Movement is the only thing the player controls directly;
## everything else (aiming, firing, target selection) is automatic.

static var instance: Player

signal health_changed(current: float, maximum: float)
signal died
signal revived
signal ultimate_state_changed(ready_ratio: float, active: bool)

const CONTACT_TICK := 0.30
const DEATH_FADE := 0.4

@onready var health: HealthComponent = $Health
@onready var hurtbox: Area2D = $Hurtbox
@onready var magnet: Area2D = $Magnet
@onready var _magnet_shape: CollisionShape2D = $Magnet/Shape
@onready var visual: Node2D = $Visual
@onready var powers: PowerManager = $Powers
@onready var ultimate: UltimateController = $Ultimate

var stats: PlayerStats
var hero: HeroData
var move_input: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.DOWN
var is_dead: bool = false
var invulnerable_timer: float = 0.0

var _contact_timer: float = 0.0
var _regen_carry: float = 0.0
var _base_speed: float = 300.0
var _knockback: Vector2 = Vector2.ZERO


func _ready() -> void:
	instance = self
	add_to_group(&"player")
	collision_layer = Layers.PLAYER
	collision_mask = 0
	hurtbox.collision_layer = 0
	hurtbox.collision_mask = Layers.ENEMY | Layers.ENEMY_ATTACK | Layers.HAZARD
	magnet.collision_layer = 0
	magnet.collision_mask = Layers.PICKUP
	health.died.connect(_on_health_died)
	health.health_changed.connect(_on_health_changed)
	magnet.area_entered.connect(_on_magnet_area_entered)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(hero_data: HeroData, player_stats: PlayerStats) -> void:
	hero = hero_data
	stats = player_stats
	_base_speed = hero_data.move_speed if hero_data != null else 300.0
	health.setup(stats.get_stat(&"max_health"))
	health.armor = stats.get_stat(&"armor")
	health.damage_reduction = stats.get_stat(&"damage_reduction")
	health.invuln_time = 0.55
	visual.call("configure", hero_data)
	powers.setup(self, stats)
	ultimate.setup(self, hero_data)
	stats.changed.connect(_on_stats_changed)
	_refresh_from_stats()


func _on_stats_changed() -> void:
	_refresh_from_stats()


func _refresh_from_stats() -> void:
	if stats == null:
		return
	var new_max := stats.get_stat(&"max_health")
	if not is_equal_approx(new_max, health.max_health):
		var gained := new_max - health.max_health
		health.max_health = new_max
		if gained > 0.0:
			health.heal(gained)
		health_changed.emit(health.current_health, health.max_health)
	health.armor = stats.get_stat(&"armor")
	health.damage_reduction = stats.get_stat(&"damage_reduction")
	var shape := _magnet_shape.shape as CircleShape2D
	if shape != null:
		var base_radius := hero.pickup_radius if hero != null else 150.0
		shape.radius = base_radius * stats.get_stat(&"pickup_radius_mult")


# --- Input ------------------------------------------------------------------

## Called by the virtual joystick. Keyboard input is folded in for desktop testing.
func set_move_input(dir: Vector2) -> void:
	move_input = dir.limit_length(1.0)


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
		if invulnerable_timer <= 0.0:
			health.invulnerable = false
			visual.call("set_shielded", false)

	var dir := move_input
	if dir.length_squared() < 0.01:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := _base_speed * stats.get_stat(&"move_speed_mult") if stats != null else _base_speed
	velocity = dir * speed + _knockback
	_knockback = _knockback.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
	if dir.length_squared() > 0.02:
		facing = dir.normalized()
	move_and_slide()
	visual.call("set_motion", dir, delta)

	_tick_contact_damage(delta)
	_tick_regen(delta)


## Enemies deal damage by touching the player; sampling on a timer is far
## cheaper than giving every enemy its own attack logic.
func _tick_contact_damage(delta: float) -> void:
	_contact_timer -= delta
	if _contact_timer > 0.0:
		return
	_contact_timer = CONTACT_TICK
	var worst := 0.0
	var source := global_position
	for area in hurtbox.get_overlapping_areas():
		if area is Enemy:
			var enemy := area as Enemy
			if enemy.alive and enemy.contact_damage > worst:
				worst = enemy.contact_damage
				source = enemy.global_position
		elif area.is_in_group(&"enemy_projectiles"):
			var dmg := _damage_of(area)
			if dmg > worst:
				worst = dmg
				source = area.global_position
			area.call("consume")
		elif area.is_in_group(&"hazards"):
			var hazard_damage := _damage_of(area)
			if hazard_damage > worst:
				worst = hazard_damage
				source = area.global_position
	if worst > 0.0:
		take_damage(worst, source)


func _damage_of(area: Node) -> float:
	var value: Variant = area.get("damage")
	return float(value) if value != null else 0.0


func _tick_regen(delta: float) -> void:
	if stats == null:
		return
	var regen := stats.get_stat(&"health_regen")
	if regen <= 0.0:
		return
	_regen_carry += regen * delta
	if _regen_carry >= 1.0:
		var whole := floorf(_regen_carry)
		_regen_carry -= whole
		health.heal(whole)


# --- Damage -----------------------------------------------------------------

func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	# Reflection is checked against the incoming hit, not the damage taken, so
	# it still works while the Aegis bulwark is making the player invulnerable.
	if ultimate.is_reflecting():
		ultimate.reflect_damage(amount, source_position)
	var dealt := health.take_damage(amount, false, source_position)
	if dealt <= 0.0:
		return
	AudioManager.play_sfx(&"hurt", 0.1, -3.0)
	AudioManager.vibrate(24)
	visual.call("flash_hurt")
	if source_position != Vector2.ZERO:
		_knockback += (global_position - source_position).normalized() * 140.0


func heal(amount: float) -> void:
	health.heal(amount)


func grant_invulnerability(duration: float) -> void:
	invulnerable_timer = maxf(invulnerable_timer, duration)
	health.invulnerable = true
	visual.call("set_shielded", true)


func apply_knockback(force: Vector2) -> void:
	_knockback += force


func _on_health_changed(current: float, maximum: float) -> void:
	health_changed.emit(current, maximum)


func _on_health_died() -> void:
	if is_dead:
		return
	is_dead = true
	powers.set_firing(false)
	visual.call("set_dead", true)
	died.emit()


## Called by the revive flow: refills health and grants a safety window.
func revive(health_ratio: float = 0.6, clear_radius: float = 520.0) -> void:
	is_dead = false
	health.revive(health_ratio)
	powers.set_firing(true)
	visual.call("set_dead", false)
	grant_invulnerability(3.0)
	if EnemyDirector.instance != null:
		for enemy in EnemyDirector.instance.get_in_radius(global_position, clear_radius, 200):
			enemy.apply_hit(9999.0, false, Vector2.ZERO, get_instance_id(), 0.0)
	revived.emit()


# --- Pickups ----------------------------------------------------------------

func _on_magnet_area_entered(area: Area2D) -> void:
	if area.has_method("attract_to"):
		area.call("attract_to", self)


func get_pickup_radius() -> float:
	var shape := _magnet_shape.shape as CircleShape2D
	return shape.radius if shape != null else 150.0
