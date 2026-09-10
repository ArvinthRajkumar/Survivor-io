class_name HazardSystem
extends Node2D
## Places the level's environmental hazards around the player on a timer.
##
## Hazards start appearing only after LevelData.hazard_start_time so the opening
## minute stays readable, and they always spawn on screen (never behind you).

const HAZARD_SCENE := preload("res://scenes/levels/Hazard.tscn")

var level: LevelData
var enabled: bool = true

var _timer: float = 0.0
var _live: int = 0


func _ready() -> void:
	PoolManager.register(HAZARD_SCENE, self, 10)


func setup(level_data: LevelData) -> void:
	level = level_data
	enabled = level != null and level.hazard_type != LevelData.Hazard.NONE
	_timer = level.hazard_start_time if level != null else 60.0


func _process(delta: float) -> void:
	if not enabled or level == null or Player.instance == null:
		return
	if RunManager.elapsed < level.hazard_start_time:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	# Hazards get denser as the endless run goes on, down to a floor so the
	# screen never becomes unreadable.
	var minutes := RunManager.elapsed / 60.0
	var pressure := clampf(1.0 - minutes * 0.07, 0.4, 1.0)
	_timer = level.hazard_interval * pressure
	_spawn_wave()


func _spawn_wave() -> void:
	var player := Player.instance
	if player == null:
		return
	var count := maxi(1, int(float(level.hazard_count) * 0.25))
	for i in count:
		var offset := MathUtil.random_point_in_ring(RunManager.rng, 120.0, 620.0)
		var hazard := PoolManager.acquire(HAZARD_SCENE) as HazardZone
		if hazard == null:
			return
		hazard.global_position = player.global_position + offset
		hazard.setup(level.hazard_type, level.hazard_radius,
			level.hazard_damage * RunManager.enemy_damage_scale(), level.accent)


func clear_all() -> void:
	PoolManager.release_group(&"hazards")
