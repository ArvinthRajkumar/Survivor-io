class_name RelicData
extends Resource
## Equipment modifier bought with meta currency and slotted before a run.
## Relics deliberately give small, build-slanting effects rather than raw power.

@export var id: StringName = &""
@export var display_name: String = "Relic"
@export_multiline var description: String = ""
@export_range(0, 3) var rarity: int = 1
@export var color: Color = Color(0.72, 0.55, 1.0)
@export_range(0, 7) var icon_shape: int = 7

@export_group("Cost")
@export var credit_cost: int = 800
@export var research_cost: int = 10

@export_group("Effects")
## PlayerStats keys to multiply, e.g. {"damage_mult": 0.15}. Added to the base 1.0.
@export var stat_multipliers: Dictionary = {}
## PlayerStats keys to add flatly, e.g. {"armor": 3.0}.
@export var stat_flats: Dictionary = {}
## Optional drawback so relics stay a trade-off, same format as stat_multipliers.
@export var stat_penalties: Dictionary = {}
## Special hook read by RunManager, e.g. "reroll", "extra_choice", "start_level".
@export var special: StringName = &""
@export var special_value: float = 0.0
