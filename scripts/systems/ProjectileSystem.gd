class_name ProjectileSystem
extends Node2D
## Owns every pooled thing a Power can put on the field and hands the behaviours
## a simple API. Powers never touch PackedScenes or PoolManager directly.

static var instance: ProjectileSystem

const PROJECTILE_SCENE := preload("res://scenes/combat/Projectile.tscn")
const ZONE_SCENE := preload("res://scenes/combat/DamageZone.tscn")
const COMPANION_SCENE := preload("res://scenes/powers/Companion.tscn")
const SAW_SCENE := preload("res://scenes/powers/SawBlade.tscn")
const DRILL_SCENE := preload("res://scenes/powers/DrillBody.tscn")
const BOTTLE_SCENE := preload("res://scenes/powers/ThrownBottle.tscn")
const LASER_SCENE := preload("res://scenes/powers/LaserStrike.tscn")
const SLASH_SCENE := preload("res://scenes/powers/SlashArc.tscn")

## Hard ceilings so a runaway build cannot tank the frame rate.
const MAX_PROJECTILES := 260
const MAX_ZONES := 56
const MAX_LASERS := 40
const MAX_SLASHES := 18


func _ready() -> void:
	instance = self
	PoolManager.register(PROJECTILE_SCENE, self, 90)
	PoolManager.register(ZONE_SCENE, self, 28)
	PoolManager.register(COMPANION_SCENE, self, 8)
	PoolManager.register(SAW_SCENE, self, 8)
	PoolManager.register(DRILL_SCENE, self, 10)
	PoolManager.register(BOTTLE_SCENE, self, 12)
	PoolManager.register(LASER_SCENE, self, 16)
	PoolManager.register(SLASH_SCENE, self, 10)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func spawn_projectile(cfg: Dictionary) -> Projectile:
	if PoolManager.active_count(PROJECTILE_SCENE) >= MAX_PROJECTILES:
		return null
	var node := PoolManager.acquire(PROJECTILE_SCENE) as Projectile
	if node == null:
		return null
	node.global_position = cfg.get("position", Vector2.ZERO)
	node.configure(cfg)
	return node


func spawn_zone(cfg: Dictionary) -> DamageZone:
	if PoolManager.active_count(ZONE_SCENE) >= MAX_ZONES:
		return null
	var node := PoolManager.acquire(ZONE_SCENE) as DamageZone
	if node == null:
		return null
	node.global_position = cfg.get("position", Vector2.ZERO)
	node.configure(cfg)
	return node


func spawn_companion(cfg: Dictionary) -> Companion:
	var node := PoolManager.acquire(COMPANION_SCENE) as Companion
	if node == null:
		return null
	node.global_position = cfg.get("position", Vector2.ZERO)
	node.configure(cfg)
	return node


func spawn_saw(cfg: Dictionary) -> SawBlade:
	var node := PoolManager.acquire(SAW_SCENE) as SawBlade
	if node == null:
		return null
	node.global_position = cfg.get("position", Vector2.ZERO)
	node.configure(cfg)
	return node


func spawn_drill(cfg: Dictionary) -> DrillBody:
	var node := PoolManager.acquire(DRILL_SCENE) as DrillBody
	if node == null:
		return null
	node.global_position = cfg.get("position", Vector2.ZERO)
	node.configure(cfg)
	return node


func spawn_bottle(cfg: Dictionary) -> ThrownBottle:
	var node := PoolManager.acquire(BOTTLE_SCENE) as ThrownBottle
	if node == null:
		return null
	node.global_position = cfg.get("from", Vector2.ZERO)
	node.configure(cfg)
	return node


func spawn_laser(cfg: Dictionary) -> LaserStrike:
	if PoolManager.active_count(LASER_SCENE) >= MAX_LASERS:
		return null
	var node := PoolManager.acquire(LASER_SCENE) as LaserStrike
	if node == null:
		return null
	node.global_position = cfg.get("position", Vector2.ZERO)
	node.configure(cfg)
	return node


func spawn_slash(cfg: Dictionary) -> SlashArc:
	if PoolManager.active_count(SLASH_SCENE) >= MAX_SLASHES:
		return null
	var node := PoolManager.acquire(SLASH_SCENE) as SlashArc
	if node == null:
		return null
	node.global_position = cfg.get("position", Vector2.ZERO)
	node.configure(cfg)
	return node


func clear_all() -> void:
	PoolManager.release_group(&"projectiles")
	PoolManager.release_group(&"damage_zones")
	for group in [&"companions", &"saw_blades", &"drills", &"bottles", &"laser_strikes", &"slashes"]:
		PoolManager.release_group(group)
