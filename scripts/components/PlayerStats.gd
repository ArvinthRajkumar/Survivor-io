class_name PlayerStats
extends RefCounted
## Runtime aggregation of every stat source acting on the player.
##
## Sources are layered: hero base -> meta (permanent) upgrades -> relics ->
## in-run passive items. Everything funnels through add_flat/add_mult so new
## sources never need new plumbing.

signal changed

## Stats treated as multipliers (stored as a bonus added to 1.0).
const MULT_KEYS: PackedStringArray = [
	"damage_mult", "cooldown_mult", "area_mult", "move_speed_mult",
	"projectile_speed_mult", "xp_gain_mult", "pickup_radius_mult",
	"crit_damage_mult", "duration_mult", "knockback_mult",
]

## Stats treated as flat additions.
const FLAT_KEYS: PackedStringArray = [
	"max_health", "armor", "crit_chance", "health_regen",
	"projectile_count_bonus", "luck", "revives", "damage_reduction",
]

var _base_flat: Dictionary = {}
var _base_mult: Dictionary = {}
var _flat: Dictionary = {}
var _mult: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	_base_flat = {
		"max_health": 100.0,
		"armor": 0.0,
		"crit_chance": 0.05,
		"health_regen": 0.0,
		"projectile_count_bonus": 0.0,
		"luck": 0.0,
		"revives": 0.0,
		"damage_reduction": 0.0,
	}
	_base_mult = {
		"damage_mult": 1.0,
		"cooldown_mult": 1.0,
		"area_mult": 1.0,
		"move_speed_mult": 1.0,
		"projectile_speed_mult": 1.0,
		"xp_gain_mult": 1.0,
		"pickup_radius_mult": 1.0,
		"crit_damage_mult": 1.6,
		"duration_mult": 1.0,
		"knockback_mult": 1.0,
	}
	_flat = {}
	_mult = {}


## Applies the hero's own stat line as the new baseline.
func apply_hero(hero: HeroData) -> void:
	if hero == null:
		return
	_base_flat["max_health"] = hero.max_health
	_base_flat["armor"] = hero.armor
	_base_flat["crit_chance"] = hero.crit_chance
	_base_flat["luck"] = hero.luck
	_base_mult["damage_mult"] = hero.damage_mult
	_base_mult["cooldown_mult"] = hero.cooldown_mult
	_base_mult["area_mult"] = hero.area_mult
	_base_mult["crit_damage_mult"] = hero.crit_damage
	changed.emit()


func add_flat(key: StringName, amount: float) -> void:
	_flat[key] = float(_flat.get(key, 0.0)) + amount
	changed.emit()


func add_mult(key: StringName, amount: float) -> void:
	_mult[key] = float(_mult.get(key, 0.0)) + amount
	changed.emit()


## Applies a {key: value} dictionary of multiplier bonuses.
func add_mult_dict(dict: Dictionary, sign_mult: float = 1.0) -> void:
	for key in dict:
		_mult[key] = float(_mult.get(key, 0.0)) + float(dict[key]) * sign_mult
	changed.emit()


func add_flat_dict(dict: Dictionary, sign_mult: float = 1.0) -> void:
	for key in dict:
		_flat[key] = float(_flat.get(key, 0.0)) + float(dict[key]) * sign_mult
	changed.emit()


func get_stat(key: StringName) -> float:
	if _base_mult.has(key):
		# Cooldown is the one stat where "more" means "faster", so bonuses subtract.
		if key == &"cooldown_mult":
			return maxf(0.35, float(_base_mult[key]) - float(_mult.get(key, 0.0)))
		return float(_base_mult[key]) + float(_mult.get(key, 0.0))
	return float(_base_flat.get(key, 0.0)) + float(_flat.get(key, 0.0))


func get_int(key: StringName) -> int:
	return int(round(get_stat(key)))


func to_dictionary() -> Dictionary:
	var out: Dictionary = {}
	for key in _base_flat:
		out[key] = get_stat(key)
	for key in _base_mult:
		out[key] = get_stat(key)
	return out
