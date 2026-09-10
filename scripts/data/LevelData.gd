class_name LevelData
extends Resource
## A playable stage: enemy pool, wave script, hazards, boss and palette.

enum Hazard { NONE, ELECTRIC_FLOOR, FIRE_VENT, SLOW_WATER, GRAVITY_ANOMALY }

@export var id: StringName = &""
@export var display_name: String = "Level"
@export_multiline var description: String = ""
@export var order: int = 0

@export_group("Run Shape")
## Runs are endless; this is how long you must survive to unlock the next
## sector, and the milestone the HUD counts toward.
@export var unlock_time: float = 480.0
## First boss, then one every boss_interval seconds for as long as you last.
@export var boss_time: float = 240.0
@export var boss_interval: float = 210.0
@export var mid_boss_time: float = 110.0
@export var mid_boss_interval: float = 150.0
@export var difficulty_scale: float = 1.0
## Extra enemy health/damage multiplier applied per minute survived.
@export var health_growth_per_minute: float = 0.16
@export var damage_growth_per_minute: float = 0.07

@export_group("Endless")
## Once the scripted waves run out, the director keeps drawing from the pool on
## this interval, which shortens as the run goes on.
@export var endless_interval: float = 1.5
@export var endless_batch: int = 6
@export var endless_elite_chance: float = 0.08

@export_group("Content")
@export var enemy_pool: Array[EnemyData] = []
@export var waves: Array[WaveData] = []
@export var boss_id: StringName = &""
@export var mid_boss_id: StringName = &""
@export var elite_tint: Color = Color(1.0, 0.85, 0.35)

@export_group("Hazards")
@export var hazard_type: Hazard = Hazard.NONE
@export var hazard_count: int = 6
@export var hazard_damage: float = 9.0
@export var hazard_radius: float = 130.0
@export var hazard_interval: float = 3.4
@export var hazard_start_time: float = 45.0

@export_group("Palette")
@export var bg_top: Color = Color(0.04, 0.05, 0.10)
@export var bg_bottom: Color = Color(0.02, 0.02, 0.05)
@export var grid_color: Color = Color(0.20, 0.55, 0.75, 0.30)
@export var accent: Color = Color(0.35, 0.90, 1.00)
@export var fog_color: Color = Color(0.10, 0.20, 0.35, 0.25)
## 0=neon grid 1=ash drifts 2=water caustics 3=lunar dust
@export_range(0, 3) var background_style: int = 0

@export_group("Unlocking")
@export var unlocked_by_default: bool = false
@export var required_level_id: StringName = &""
@export var reward_credits: int = 400
@export var reward_research: int = 6
