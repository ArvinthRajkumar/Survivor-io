class_name HeroData
extends Resource
## Designer-facing definition of a playable hero.
##
## Portraits are generated procedurally from portrait_shape + accent colours so
## the project needs no imported artwork.

@export var id: StringName = &""
@export var display_name: String = "Hero"
@export var role: String = ""
@export_multiline var description: String = ""

@export_group("Base Stats")
@export var max_health: float = 100.0
@export var move_speed: float = 300.0
@export var armor: float = 0.0
@export var damage_mult: float = 1.0
@export var cooldown_mult: float = 1.0
@export var area_mult: float = 1.0
@export var pickup_radius: float = 150.0
@export var crit_chance: float = 0.05
@export var crit_damage: float = 1.6
@export var luck: float = 0.0

@export_group("Loadout")
## The weapon every operative carries in. It is granted before the run starts
## and does not spend one of the six choosable slots.
@export var starting_power_id: StringName = &"katana"

@export_group("Skills")
@export var passive_id: StringName = &""
@export var passive_name: String = ""
@export_multiline var passive_description: String = ""
@export var ultimate_id: StringName = &""
@export var ultimate_name: String = ""
@export_multiline var ultimate_description: String = ""
@export var ultimate_cooldown: float = 40.0
@export var ultimate_duration: float = 8.0

@export_group("Presentation")
@export var accent: Color = Color(0.35, 0.9, 1.0)
@export var accent_secondary: Color = Color(1.0, 0.66, 0.28)
## 0=triangle 1=diamond 2=pentagon 3=hexagon 4=star
@export_range(0, 4) var portrait_shape: int = 2

@export_group("Unlocking")
@export var unlocked_by_default: bool = false
@export var unlock_credit_cost: int = 1500
@export var unlock_research_cost: int = 20

@export_group("Ranks")
## Permanent per-hero levels bought on the roster screen. Each rank is a small
## across-the-board bump, so investing in a favourite hero is worthwhile without
## making the others obsolete.
@export var max_rank: int = 5
@export var rank_cost_credits: int = 700
@export var rank_cost_research: int = 6
@export var rank_cost_growth: float = 1.8
@export var rank_health_bonus: float = 0.06
@export var rank_damage_bonus: float = 0.05


## Price of the next rank.
func rank_cost_at(rank: int) -> Vector2i:
	var scale := pow(rank_cost_growth, float(max(0, rank)))
	return Vector2i(int(round(float(rank_cost_credits) * scale)),
		int(round(float(rank_cost_research) * scale)))


func describe_rank_step() -> String:
	return "+%d%% health, +%d%% damage per rank" % [
		int(round(rank_health_bonus * 100.0)), int(round(rank_damage_bonus * 100.0))]
