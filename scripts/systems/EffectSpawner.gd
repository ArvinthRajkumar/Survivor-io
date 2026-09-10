class_name EffectSpawner
extends Node2D
## Single entry point for every cosmetic and pickup spawn during a run.
##
## Keeping it in one place means gameplay code never touches PackedScenes or the
## pool directly, and lets quality settings throttle effects globally.

static var instance: EffectSpawner

const DAMAGE_NUMBER_SCENE := preload("res://scenes/fx/DamageNumber.tscn")
const HIT_SPARK_SCENE := preload("res://scenes/fx/HitSpark.tscn")
const BURST_SCENE := preload("res://scenes/fx/Burst.tscn")
const XP_SHARD_SCENE := preload("res://scenes/pickups/XPShard.tscn")
const PICKUP_SCENE := preload("res://scenes/pickups/Pickup.tscn")
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/combat/EnemyProjectile.tscn")

## Effects above this many simultaneous instances are dropped rather than queued.
const MAX_NUMBERS := 40
const MAX_SPARKS := 60

@export var effects_root_path: NodePath
@export var pickups_root_path: NodePath

var _effects_root: Node2D
var _pickups_root: Node2D
var _numbers_live: int = 0
var _sparks_live: int = 0
var _show_numbers: bool = true
var _budget: float = 1.0


func _ready() -> void:
	instance = self
	_effects_root = get_node_or_null(effects_root_path) as Node2D
	_pickups_root = get_node_or_null(pickups_root_path) as Node2D
	if _effects_root == null:
		_effects_root = self
	if _pickups_root == null:
		_pickups_root = self
	_show_numbers = bool(SaveManager.get_setting("show_damage_numbers", true))
	_budget = GameManager.particle_budget_scale()
	PoolManager.register(DAMAGE_NUMBER_SCENE, _effects_root, 56)
	PoolManager.register(HIT_SPARK_SCENE, _effects_root, 72)
	PoolManager.register(BURST_SCENE, _effects_root, 96)
	PoolManager.register(XP_SHARD_SCENE, _pickups_root, 160)
	PoolManager.register(PICKUP_SCENE, _pickups_root, 12)
	PoolManager.register(ENEMY_PROJECTILE_SCENE, _effects_root, 48)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func spawn_damage_number(pos: Vector2, amount: float, is_crit: bool) -> void:
	if not _show_numbers or _numbers_live >= MAX_NUMBERS:
		return
	# At low quality only crits and big hits are worth the draw call.
	if _budget < 0.5 and not is_crit and amount < 25.0:
		return
	var node := PoolManager.acquire(DAMAGE_NUMBER_SCENE)
	if node == null:
		return
	_numbers_live += 1
	node.global_position = pos + Vector2(RunManager.rng.randf_range(-14.0, 14.0), -18.0)
	node.call("show_damage", amount, is_crit)
	if not node.is_connected("finished", _on_number_finished):
		node.connect("finished", _on_number_finished)


func _on_number_finished() -> void:
	_numbers_live = maxi(0, _numbers_live - 1)


func spawn_hit_spark(pos: Vector2, color: Color) -> void:
	if _sparks_live >= int(MAX_SPARKS * _budget):
		return
	var node := PoolManager.acquire(HIT_SPARK_SCENE)
	if node == null:
		return
	_sparks_live += 1
	node.global_position = pos
	node.call("play", color, 1.0)
	if not node.is_connected("finished", _on_spark_finished):
		node.connect("finished", _on_spark_finished)


func _on_spark_finished() -> void:
	_sparks_live = maxi(0, _sparks_live - 1)


func spawn_death_burst(pos: Vector2, color: Color, radius: float) -> void:
	var node := PoolManager.acquire(BURST_SCENE)
	if node == null:
		return
	node.global_position = pos
	node.call("play", color, radius, _budget)


func spawn_explosion(pos: Vector2, color: Color, radius: float) -> void:
	spawn_death_burst(pos, color, radius)
	AudioManager.play_sfx(&"explosion", 0.12, -4.0)


func spawn_xp(pos: Vector2, value: int) -> void:
	if value <= 0:
		return
	var node := PoolManager.acquire(XP_SHARD_SCENE)
	if node == null:
		return
	node.global_position = pos
	node.call("setup", value)


func spawn_pickup(pos: Vector2, kind: int) -> void:
	var node := PoolManager.acquire(PICKUP_SCENE)
	if node == null:
		return
	node.global_position = pos
	node.call("setup", kind)


## Elites drop something useful on top of their extra XP.
func spawn_elite_drop(pos: Vector2) -> void:
	var roll := RunManager.rng.randf()
	if roll < 0.45:
		spawn_pickup(pos, Pickup.Kind.HEALTH)
	elif roll < 0.75:
		spawn_pickup(pos, Pickup.Kind.MAGNET)
	else:
		spawn_pickup(pos, Pickup.Kind.BOMB)


func spawn_boss_drop(pos: Vector2) -> void:
	spawn_pickup(pos, Pickup.Kind.CHEST)
	for i in 12:
		var offset := MathUtil.random_point_in_ring(RunManager.rng, 30.0, 140.0)
		spawn_xp(pos + offset, 12)


func spawn_enemy_projectile(pos: Vector2, dir: Vector2, speed: float, damage: float, color: Color) -> void:
	var node := PoolManager.acquire(ENEMY_PROJECTILE_SCENE)
	if node == null:
		return
	node.global_position = pos
	node.call("launch", dir, speed, damage, color)


func set_show_numbers(value: bool) -> void:
	_show_numbers = value
