class_name EnemyData
extends Resource
## One enemy archetype. Enemy.tscn is a single reusable, pooled scene that is
## reconfigured from this resource, so new enemies never need new scenes.

enum AI { CHASER, DRIFTER, CHARGER, SHOOTER, SPLITTER, ORBITER }

@export var id: StringName = &""
@export var display_name: String = "Enemy"
@export var ai: AI = AI.CHASER

@export_group("Stats")
@export var max_health: float = 12.0
@export var move_speed: float = 105.0
@export var contact_damage: float = 8.0
@export_range(0.0, 1.0) var knockback_resist: float = 0.0
@export var xp_value: int = 1
@export var credit_value: int = 1
@export var radius: float = 22.0
@export var mass: float = 1.0

@export_group("Behaviour")
@export var charge_interval: float = 3.0
@export var charge_speed_mult: float = 3.2
@export var shoot_interval: float = 2.4
@export var projectile_speed: float = 260.0
@export var projectile_damage: float = 7.0
@export var split_into_id: StringName = &""
@export var split_count: int = 2
@export var orbit_radius: float = 200.0

@export_group("Presentation")
@export var color: Color = Color(1.0, 0.35, 0.45)
@export var color_secondary: Color = Color(0.25, 0.05, 0.12)
## 0=triangle 1=diamond 2=pentagon 3=hexagon 4=star 5=blob
@export_range(0, 5) var shape: int = 3
@export var spin_speed: float = 0.0

@export_group("Elite / Boss")
@export var is_boss: bool = false
@export var can_be_elite: bool = true
@export var boss_title: String = ""
@export var boss_phase_thresholds: PackedFloat32Array = PackedFloat32Array([0.66, 0.33])
