class_name GenRelics
extends RefCounted
## Authoring source for relics: permanent equipment that slants a run rather
## than simply strengthening it. Most carry a real drawback.

const DIR := "res://resources/relics/"


static func run() -> void:
	for relic in _relics():
		_save(relic)


static func _save(relic: RelicData) -> void:
	var path := DIR + String(relic.id) + ".tres"
	var err := ResourceSaver.save(relic, path)
	if err != OK:
		push_error("GenRelics: failed to save %s (%d)" % [path, err])
	else:
		print("  relic  ", path)


static func _make(id: StringName, name: String, description: String, rarity: int,
		color: Color, shape: int, credits: int, research: int) -> RelicData:
	var relic := RelicData.new()
	relic.id = id
	relic.display_name = name
	relic.description = description
	relic.rarity = rarity
	relic.color = color
	relic.icon_shape = shape
	relic.credit_cost = credits
	relic.research_cost = research
	return relic


static func _relics() -> Array[RelicData]:
	var out: Array[RelicData] = []

	var glass := _make(&"glass_lattice", "Glass Lattice",
		"+35% damage, but you have 30% less health.", 2,
		Color(1.00, 0.40, 0.45), 6, 900, 8)
	glass.stat_multipliers = {"damage_mult": 0.35}
	glass.stat_penalties = {}
	glass.stat_flats = {"max_health": -30.0}
	out.append(glass)

	var ballast := _make(&"ballast_core", "Ballast Core",
		"+60 health and +5 armour, but you move 12% slower.", 1,
		Color(0.70, 0.80, 0.95), 5, 700, 6)
	ballast.stat_flats = {"max_health": 60.0, "armor": 5.0}
	ballast.stat_penalties = {"move_speed_mult": 0.12}
	out.append(ballast)

	var siphon := _make(&"scholars_siphon", "Scholar's Siphon",
		"+30% experience, but upgrades cost you 10% attack rate.", 1,
		Color(0.55, 0.72, 1.00), 7, 800, 7)
	siphon.stat_multipliers = {"xp_gain_mult": 0.30}
	siphon.stat_penalties = {"cooldown_mult": -0.10}
	out.append(siphon)

	var scatter := _make(&"split_prism", "Split Prism",
		"+1 projectile on every weapon, but each hit lands 15% softer.", 2,
		Color(1.00, 0.72, 0.30), 1, 1400, 14)
	scatter.stat_flats = {"projectile_count_bonus": 1.0}
	scatter.stat_penalties = {"damage_mult": 0.15}
	out.append(scatter)

	var reroll := _make(&"forecast_module", "Forecast Module",
		"Two rerolls per level-up choice.", 2,
		Color(0.45, 0.90, 1.00), 3, 1600, 16)
	reroll.special = &"reroll"
	reroll.special_value = 2.0
	out.append(reroll)

	var choice := _make(&"branching_matrix", "Branching Matrix",
		"Level-ups offer a fourth option.", 3,
		Color(0.78, 0.55, 1.00), 7, 2600, 30)
	choice.special = &"extra_choice"
	choice.special_value = 1.0
	out.append(choice)

	var magnet := _make(&"harvest_coil", "Harvest Coil",
		"+55% pickup radius and a little regeneration.", 0,
		Color(0.55, 1.00, 0.75), 2, 600, 5)
	magnet.stat_multipliers = {"pickup_radius_mult": 0.55}
	magnet.stat_flats = {"health_regen": 0.8}
	out.append(magnet)

	var hunter := _make(&"marksmans_eye", "Marksman's Eye",
		"+10% critical chance and +40% critical damage.", 2,
		Color(1.00, 0.85, 0.40), 6, 1500, 15)
	hunter.stat_flats = {"crit_chance": 0.10}
	hunter.stat_multipliers = {"crit_damage_mult": 0.40}
	out.append(hunter)

	return out
