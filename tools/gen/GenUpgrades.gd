class_name GenUpgrades
extends RefCounted
## Authoring source for permanent Research Lab research.
##
## In-run upgrades live in GenPowers now (Powers and Passive Abilities share the
## six run slots); everything here is bought with meta currency between runs and
## folded into PlayerStats when a run is configured.

const DIR := "res://resources/upgrades/"


static func run() -> void:
	for item in _meta_items():
		_save(item)


static func _save(item: UpgradeData) -> void:
	var path := DIR + String(item.id) + ".tres"
	var err := ResourceSaver.save(item, path)
	if err != OK:
		push_error("GenUpgrades: failed to save %s (%d)" % [path, err])
	else:
		print("  upgrade  ", path)


static func _make(id: StringName, name: String, description: String, stat: StringName,
		value: float, multiplier: bool, max_level: int, rarity: int,
		color: Color, shape: int, weight: float = 1.0) -> UpgradeData:
	var item := UpgradeData.new()
	item.id = id
	item.display_name = name
	item.description = description
	item.stat_key = stat
	item.value_per_level = value
	item.is_multiplier = multiplier
	item.max_level = max_level
	item.rarity = rarity
	item.color = color
	item.icon_shape = shape
	item.weight = weight
	return item


static func _meta_items() -> Array[UpgradeData]:
	var items: Array[UpgradeData] = [
		_make(&"meta_power", "Munitions Research", "base weapon damage", &"damage_mult",
			0.04, true, 10, 1, Color(1.00, 0.45, 0.35), 4),
		_make(&"meta_vitality", "Reinforced Frames", "base maximum health", &"max_health",
			12.0, false, 10, 1, Color(0.45, 0.95, 0.55), 5),
		_make(&"meta_haste", "Cooling Loops", "base attack rate", &"cooldown_mult",
			0.025, true, 8, 1, Color(0.45, 0.90, 1.00), 0),
		_make(&"meta_armor", "Composite Plating", "base armour", &"armor",
			1.0, false, 8, 0, Color(0.75, 0.80, 0.90), 3),
		_make(&"meta_greed", "Field Analytics", "experience gained", &"xp_gain_mult",
			0.05, true, 6, 1, Color(0.55, 0.72, 1.00), 7),
		_make(&"meta_fortune", "Salvage Doctrine", "upgrade luck", &"luck",
			1.0, false, 5, 2, Color(1.00, 0.85, 0.40), 6),
		_make(&"meta_magnet", "Recovery Drones", "pickup radius", &"pickup_radius_mult",
			0.08, true, 5, 0, Color(0.72, 0.55, 1.00), 2),
		_make(&"meta_revive", "Emergency Stasis", "extra revive", &"revives",
			1.0, false, 2, 3, Color(1.00, 0.78, 0.35), 5),
	]
	var costs := {
		&"meta_power": Vector2i(420, 3),
		&"meta_vitality": Vector2i(380, 2),
		&"meta_haste": Vector2i(500, 4),
		&"meta_armor": Vector2i(340, 2),
		&"meta_greed": Vector2i(460, 4),
		&"meta_fortune": Vector2i(900, 8),
		&"meta_magnet": Vector2i(300, 2),
		&"meta_revive": Vector2i(2500, 30),
	}
	for item in items:
		item.meta_only = true
		var cost: Vector2i = costs.get(item.id, Vector2i(400, 3))
		item.meta_cost_credits = cost.x
		item.meta_cost_research = cost.y
		item.meta_cost_growth = 1.55
	return items
