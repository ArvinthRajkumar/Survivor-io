class_name UpgradeData
extends Resource
## A permanent Research Lab upgrade, bought with credits between runs.
##
## In-run offers — Powers and Passives alike — are built from PowerData
## instead; this resource only covers the meta progression.

enum Kind { PASSIVE_ITEM, HEAL, CREDITS }

@export var id: StringName = &""
@export var display_name: String = "Upgrade"
@export_multiline var description: String = ""
@export var kind: Kind = Kind.PASSIVE_ITEM
@export var max_level: int = 5
@export_range(0, 3) var rarity: int = 0
@export var weight: float = 1.0

@export_group("Effect")
## Key on PlayerStats, e.g. "damage_mult" or "max_health".
@export var stat_key: StringName = &""
@export var value_per_level: float = 0.1
## Multipliers are added to a 1.0 base; flat values are added directly.
@export var is_multiplier: bool = true

@export_group("Meta Progression")
## Meta-only entries are sold in the Research Lab and never offered mid-run.
@export var meta_only: bool = false
@export var meta_cost_credits: int = 300
@export var meta_cost_research: int = 2
## Each purchased level multiplies the price by this much.
@export var meta_cost_growth: float = 1.6

@export_group("Presentation")
@export var color: Color = Color(0.72, 0.78, 0.88)
## Reuses the weapon icon shape ids for a consistent look.
@export_range(0, 7) var icon_shape: int = 2


func value_at(level: int) -> float:
	return value_per_level * float(max(0, level))


func describe_step(_next_level: int) -> String:
	if is_multiplier:
		return "+%d%% %s" % [int(round(value_per_level * 100.0)), description]
	return "+%s %s" % [_trim_number(value_per_level), description]


## "3" rather than "3.0", but keeps "1.2" intact.
static func _trim_number(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return str(snappedf(value, 0.1))


## Price of the next permanent level in the Research Lab.
func meta_cost_at(level: int) -> Vector2i:
	var scale := pow(meta_cost_growth, float(max(0, level)))
	return Vector2i(int(round(float(meta_cost_credits) * scale)),
		int(round(float(meta_cost_research) * scale)))
