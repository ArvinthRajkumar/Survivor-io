class_name PowerData
extends Resource
## One entry in the upgrade pool — either an active Power or a Passive Ability.
##
## Both categories share this resource so the loadout, the offer generator and
## the HUD can treat them uniformly; the only real difference is that a Power
## spawns a behaviour node while a Passive just adds stat modifiers.
##
## The player may own at most PowerLoadout.MAX_SLOTS entries in total, so every
## level of every entry has to feel worth the slot.

enum Category { POWER, PASSIVE }

## Selects the behaviour script for a Power (see PowerManager.BEHAVIORS).
## Ignored for Passives.
enum Behavior {
	NONE,
	DRONE,          ## orbiting gun drone, radial fire then targeted at max level
	DOMAIN,         ## expanding force field pinned to the player
	MOLOTOV,        ## thrown bottles that leave burning ground
	DRILL,          ## drills that ricochet around the play area
	HEALING_DRONE,  ## drone that drops healing circles near the player
	LASER,          ## orbital strikes called down in patterns
	SPINNERS,       ## saw blades orbiting the player
	# Appended rather than inserted: the numeric values are what the .tres files
	# on disk store, so the existing entries must keep the indices they have.
	KATANA,         ## melee sweep along the direction the player is moving
}

@export var id: StringName = &""
@export var display_name: String = "Power"
@export var category: Category = Category.POWER
@export var behavior: Behavior = Behavior.NONE
@export var max_level: int = 5
@export var order: int = 0

@export_group("Copy")
## One line shown on the upgrade card.
@export_multiline var description: String = ""
## Very short line shown in the HUD tooltip. Keep it under ~60 characters.
@export var tooltip: String = ""
## Per-level text, index 0 describing the step from level 1 to 2.
@export var level_notes: PackedStringArray = PackedStringArray()

@export_group("Power Stats")
@export var damage: float = 10.0
@export var cooldown: float = 1.0
@export var area: float = 1.0
@export var count: int = 1
@export var projectile_speed: float = 600.0
@export var duration: float = 2.0
@export var knockback: float = 100.0
@export var pierce: int = 0
## Seconds an enemy must wait before this power can hit it again.
@export var hit_interval: float = 0.25

@export_group("Power Growth")
@export var damage_per_level: float = 5.0
@export var cooldown_mult_per_level: float = 0.94
@export var area_per_level: float = 0.10
@export var duration_per_level: float = 0.0
## Levels at which the instance count goes up by one.
@export var count_at_levels: PackedInt32Array = PackedInt32Array()

@export_group("Passive Effects")
## PlayerStats keys added as multipliers (on top of a 1.0 base), per level.
@export var stat_multipliers: Dictionary = {}
## PlayerStats keys added flatly, per level.
@export var stat_flats: Dictionary = {}

@export_group("Presentation")
@export var color: Color = Color(0.4, 0.85, 1.0)
@export var color_secondary: Color = Color(1.0, 1.0, 1.0)
## Art id understood by PowerArt.draw_icon(). Usually the same as `id`.
@export var art: StringName = &""
@export_range(0, 3) var rarity: int = 1
## Relative chance of being offered while it is not yet owned.
@export var weight: float = 1.0


func is_power() -> bool:
	return category == Category.POWER


func is_passive() -> bool:
	return category == Category.PASSIVE


func art_id() -> StringName:
	return art if not String(art).is_empty() else id


# --- Level curves ----------------------------------------------------------

func damage_at(level: int) -> float:
	return damage + damage_per_level * float(max(0, level - 1))


func cooldown_at(level: int) -> float:
	return cooldown * pow(cooldown_mult_per_level, float(max(0, level - 1)))


func area_at(level: int) -> float:
	return area * (1.0 + area_per_level * float(max(0, level - 1)))


func duration_at(level: int) -> float:
	return duration + duration_per_level * float(max(0, level - 1))


func count_at(level: int) -> int:
	var total := count
	for lv in count_at_levels:
		if level >= lv:
			total += 1
	return total


func is_max_level(level: int) -> bool:
	return level >= max_level


## Human readable summary of the jump from `level - 1` to `level`.
func note_for_level(level: int) -> String:
	var index := level - 2
	if index >= 0 and index < level_notes.size():
		return level_notes[index]
	if is_passive():
		return describe_passive_step()
	return "+%d damage" % int(damage_per_level)


## Reads the stat dictionaries back into a short sentence, so passive copy never
## drifts away from the numbers it actually applies.
func describe_passive_step() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for key in stat_multipliers:
		parts.append("+%d%% %s" % [
			int(round(float(stat_multipliers[key]) * 100.0)), _stat_label(key)])
	for key in stat_flats:
		parts.append("+%s %s" % [_trim(float(stat_flats[key])), _stat_label(key)])
	return ", ".join(parts) if parts.size() > 0 else description


static func _trim(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return str(snappedf(value, 0.01))


static func _stat_label(key: Variant) -> String:
	match StringName(key):
		&"damage_mult":
			return "damage"
		&"cooldown_mult":
			return "attack rate"
		&"area_mult":
			return "effect size"
		&"move_speed_mult":
			return "move speed"
		&"projectile_speed_mult":
			return "projectile speed"
		&"xp_gain_mult":
			return "experience"
		&"pickup_radius_mult":
			return "pickup radius"
		&"crit_damage_mult":
			return "critical damage"
		&"duration_mult":
			return "effect duration"
		&"knockback_mult":
			return "knockback"
		&"max_health":
			return "max health"
		&"armor":
			return "armour"
		&"crit_chance":
			return "critical chance"
		&"health_regen":
			return "health regen"
		&"damage_reduction":
			return "damage reduction"
		&"revives":
			return "revive"
		&"luck":
			return "luck"
		_:
			return String(key)
