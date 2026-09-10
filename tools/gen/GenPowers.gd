class_name GenPowers
extends RefCounted
## Authoring source for the katana every operative carries plus the twelve
## choosable upgrades: seven Powers and five Passives. The player may
## own six of the twelve in total, so each one has to be worth a permanent slot
## rather than a filler pick. The katana is granted and spends none of them.
##
## Run tools/generate_content.gd to rewrite resources/powers/*.tres from here.

const DIR := "res://resources/powers/"


static func run() -> void:
	for group in [_innate(), _powers(), _passives()]:
		for power in group:
			_save(power)


static func _save(power: PowerData) -> void:
	var path := DIR + String(power.id) + ".tres"
	var err := ResourceSaver.save(power, path)
	if err != OK:
		push_error("GenPowers: failed to save %s (%d)" % [path, err])
	else:
		print("  power  ", path)


static func _base(id: StringName, name: String, order: int) -> PowerData:
	var power := PowerData.new()
	power.id = id
	power.display_name = name
	power.order = order
	power.max_level = 5
	power.art = id
	power.category = PowerData.Category.POWER
	return power


# --- Innate weapon ----------------------------------------------------------

## Granted at the start of every run. PowerLoadout.can_offer() is what stops it
## being offered as a *new* pick, so its weight is an ordinary one: it still has
## to compete for level-ups like everything else.
static func _innate() -> Array[PowerData]:
	var katana := _base(&"katana", "Katana", -1)
	katana.behavior = PowerData.Behavior.KATANA
	katana.description = "The blade you carry in. It cuts along the direction you are moving."
	katana.tooltip = "Cuts where you move. Levels add reach and damage."
	katana.damage = 22.0
	katana.damage_per_level = 14.0
	katana.cooldown = 0.72
	# Levelling buys reach and damage only. Swinging faster is what a cooldown
	# passive is for; making the base weapon also do it turned every level-up
	# into the same "more swings per second" and left the blade feeling short.
	katana.cooldown_mult_per_level = 1.0
	katana.count = 1
	katana.count_at_levels = PackedInt32Array()
	katana.area_per_level = 0.22
	katana.knockback = 190.0
	katana.hit_interval = 0.0
	katana.level_notes = PackedStringArray([
		"+14 damage, longer reach",
		"+14 damage, longer reach and a wider arc",
		"+14 damage, longer reach",
		"+14 damage, and the outward pulse hits at full force",
	])
	katana.color = Color(0.78, 0.88, 1.00)
	katana.color_secondary = Color(1.00, 0.78, 0.36)
	katana.rarity = 2
	katana.weight = 1.1
	var out: Array[PowerData] = [katana]
	return out


# --- Powers -----------------------------------------------------------------

static func _powers() -> Array[PowerData]:
	var out: Array[PowerData] = []

	var drone := _base(&"drone", "Drone", 0)
	drone.behavior = PowerData.Behavior.DRONE
	drone.description = "A gun drone orbits you and sprays bullets outward."
	drone.tooltip = "Orbiting drone. Sprays bullets; aims at max level."
	drone.damage = 12.0
	drone.damage_per_level = 5.0
	drone.cooldown = 1.10
	drone.cooldown_mult_per_level = 0.90
	drone.projectile_speed = 560.0
	drone.count = 1
	drone.count_at_levels = PackedInt32Array([3, 5])
	drone.area = 1.0
	drone.area_per_level = 0.06
	drone.hit_interval = 0.0
	drone.level_notes = PackedStringArray([
		"+5 damage, faster bursts",
		"+1 drone",
		"+5 damage, faster bursts",
		"+1 drone, and bullets now track enemies",
	])
	drone.color = Color(0.42, 0.86, 1.00)
	drone.color_secondary = Color(0.85, 0.98, 1.00)
	drone.rarity = 1
	out.append(drone)

	var domain := _base(&"domain", "Domain", 1)
	domain.behavior = PowerData.Behavior.DOMAIN
	domain.description = "A force field surrounds you, grinding down anything inside it."
	domain.tooltip = "Force field around you. Constant damage."
	domain.damage = 7.0
	domain.damage_per_level = 3.4
	domain.cooldown = 1.20
	domain.cooldown_mult_per_level = 0.93
	domain.area = 1.0
	domain.area_per_level = 0.15
	domain.knockback = 150.0
	domain.hit_interval = 0.3
	domain.level_notes = PackedStringArray([
		"+3.4 damage, +15% radius",
		"+3.4 damage, +15% radius",
		"+3.4 damage, +15% radius",
		"+3.4 damage, +15% radius",
	])
	domain.color = Color(0.55, 0.70, 1.00)
	domain.color_secondary = Color(0.90, 0.95, 1.00)
	domain.rarity = 1
	out.append(domain)

	var molotov := _base(&"molotov", "Molotov Cocktail", 2)
	molotov.behavior = PowerData.Behavior.MOLOTOV
	molotov.description = "Lob bottles around you that leave ground burning."
	molotov.tooltip = "Thrown bottles. Leaves burning ground."
	molotov.damage = 6.0
	molotov.damage_per_level = 2.6
	molotov.cooldown = 3.20
	molotov.cooldown_mult_per_level = 0.95
	molotov.duration = 4.0
	molotov.duration_per_level = 0.35
	molotov.count = 2
	molotov.count_at_levels = PackedInt32Array([2, 3, 4, 5])
	molotov.area = 1.0
	molotov.area_per_level = 0.08
	molotov.hit_interval = 0.4
	molotov.level_notes = PackedStringArray([
		"3 bottles, fires burn longer",
		"4 bottles, +2.6 damage",
		"5 bottles, fires burn longer",
		"6 bottles, +2.6 damage",
	])
	molotov.color = Color(1.00, 0.52, 0.18)
	molotov.color_secondary = Color(1.00, 0.85, 0.35)
	molotov.rarity = 1
	out.append(molotov)

	var drill := _base(&"drill", "Drill", 3)
	drill.behavior = PowerData.Behavior.DRILL
	drill.description = "Drills ricochet around the area, boring through the swarm."
	drill.tooltip = "Bouncing drills. Hits everything they cross."
	drill.damage = 14.0
	drill.damage_per_level = 7.0
	drill.cooldown = 2.50
	drill.projectile_speed = 340.0
	drill.count = 2
	drill.count_at_levels = PackedInt32Array([2, 4, 5])
	drill.area = 1.0
	drill.area_per_level = 0.07
	drill.knockback = 150.0
	drill.hit_interval = 0.45
	drill.level_notes = PackedStringArray([
		"+1 drill, +7 damage",
		"+7 damage, wider bit",
		"+1 drill, +7 damage",
		"+1 drill, +7 damage",
	])
	drill.color = Color(1.00, 0.78, 0.30)
	drill.color_secondary = Color(0.95, 0.97, 1.00)
	drill.rarity = 1
	out.append(drill)

	var healer := _base(&"healing_drone", "Healing Drone", 4)
	healer.behavior = PowerData.Behavior.HEALING_DRONE
	healer.description = "A support drone drops healing circles. Stand in one to recover."
	healer.tooltip = "Drops healing circles. Stand in them."
	healer.damage = 5.0            # health per second inside the circle
	healer.damage_per_level = 2.6
	healer.cooldown = 6.00
	healer.cooldown_mult_per_level = 0.92
	healer.duration = 5.0
	healer.duration_per_level = 0.6
	healer.area = 1.0
	healer.area_per_level = 0.16
	healer.hit_interval = 0.5
	healer.level_notes = PackedStringArray([
		"+2.6 health per second, wider circle",
		"+2.6 health per second, dropped more often",
		"+2.6 health per second, wider circle",
		"+2.6 health per second, dropped more often",
	])
	healer.color = Color(0.40, 0.95, 0.62)
	healer.color_secondary = Color(1.00, 0.45, 0.48)
	healer.rarity = 2
	out.append(healer)

	var laser := _base(&"laser", "Laser", 5)
	laser.behavior = PowerData.Behavior.LASER
	laser.description = "Orbital strikes rake the ground around you in rotating patterns."
	laser.tooltip = "Orbital strikes. Heavy burst damage."
	laser.damage = 34.0
	laser.damage_per_level = 20.0
	laser.cooldown = 4.20
	laser.cooldown_mult_per_level = 0.95
	laser.count = 3
	laser.count_at_levels = PackedInt32Array([3, 5])
	laser.area = 1.0
	laser.area_per_level = 0.08
	laser.knockback = 220.0
	laser.level_notes = PackedStringArray([
		"+20 damage",
		"+1 beam, +20 damage",
		"+20 damage, wider blast",
		"+1 beam, +20 damage",
	])
	laser.color = Color(0.60, 0.80, 1.00)
	laser.color_secondary = Color(1.00, 1.00, 1.00)
	laser.rarity = 2
	out.append(laser)

	var spinners := _base(&"spinners", "Spinners", 6)
	spinners.behavior = PowerData.Behavior.SPINNERS
	spinners.description = "Saw blades orbit you. They cut in bursts until you master them."
	spinners.tooltip = "Orbiting saw blades. Never stop at max level."
	spinners.damage = 10.0
	spinners.damage_per_level = 5.0
	spinners.cooldown = 3.00
	spinners.count = 2
	spinners.count_at_levels = PackedInt32Array([2, 3, 4, 5])
	spinners.area = 1.0
	spinners.area_per_level = 0.07
	spinners.knockback = 130.0
	spinners.hit_interval = 0.35
	spinners.level_notes = PackedStringArray([
		"3 blades, longer cutting window",
		"4 blades, +5 damage",
		"5 blades, longer cutting window",
		"6 blades, and they never stop spinning",
	])
	spinners.color = Color(0.85, 0.90, 1.00)
	spinners.color_secondary = Color(1.00, 0.55, 0.30)
	spinners.rarity = 1
	out.append(spinners)

	return out


# --- Passives ------------------------------------------------------

static func _passive(id: StringName, name: String, order: int) -> PowerData:
	var power := _base(id, name, order)
	power.category = PowerData.Category.PASSIVE
	power.behavior = PowerData.Behavior.NONE
	return power


static func _passives() -> Array[PowerData]:
	var out: Array[PowerData] = []

	var core := _passive(&"overclock_core", "Overclock Core", 10)
	core.description = "Push every system past its rated limit. Everything fires sooner."
	core.tooltip = "Faster cooldowns and projectiles."
	core.stat_multipliers = {"cooldown_mult": 0.08, "projectile_speed_mult": 0.10}
	core.color = Color(0.45, 0.92, 1.00)
	core.color_secondary = Color(1.00, 0.90, 0.45)
	core.rarity = 1
	core.weight = 1.1
	out.append(core)

	var plating := _passive(&"alloy_plating", "Alloy Plating", 11)
	plating.description = "Layered armour welded over everything vital."
	plating.tooltip = "More health and armour."
	plating.stat_flats = {"max_health": 28.0, "armor": 3.0}
	plating.color = Color(0.72, 0.80, 0.92)
	plating.color_secondary = Color(1.00, 0.86, 0.45)
	plating.rarity = 0
	plating.weight = 1.2
	out.append(plating)

	var boots := _passive(&"kinetic_boots", "Kinetic Boots", 12)
	boots.description = "Reactive soles that turn a stumble into a stride."
	boots.tooltip = "Move faster, take less damage."
	boots.stat_multipliers = {"move_speed_mult": 0.08}
	boots.stat_flats = {"damage_reduction": 0.04}
	boots.color = Color(0.60, 1.00, 0.78)
	boots.color_secondary = Color(0.95, 1.00, 0.60)
	boots.rarity = 1
	out.append(boots)

	var lens := _passive(&"resonance_lens", "Resonance Lens", 13)
	lens.description = "Focuses every emission into a tighter, meaner beam."
	lens.tooltip = "More damage, bigger effects, more crits."
	lens.stat_multipliers = {"damage_mult": 0.10, "area_mult": 0.08}
	lens.stat_flats = {"crit_chance": 0.03}
	lens.color = Color(0.82, 0.55, 1.00)
	lens.color_secondary = Color(1.00, 0.95, 0.70)
	lens.rarity = 2
	lens.weight = 0.9
	out.append(lens)

	var magnet := _passive(&"salvage_magnet", "Salvage Magnet", 14)
	magnet.description = "Drags every loose shard on the field toward you."
	magnet.tooltip = "Wider pickup radius, more experience."
	# The base radius is deliberately tight (walk-over-it range), so this is
	# the passive that actually has to deliver "wider" — each level is worth
	# noticeably more than the old 0.22 was against the old, already-generous
	# base of 260.
	magnet.stat_multipliers = {"pickup_radius_mult": 0.40, "xp_gain_mult": 0.15}
	magnet.color = Color(1.00, 0.72, 0.35)
	magnet.color_secondary = Color(0.60, 0.85, 1.00)
	magnet.rarity = 1
	out.append(magnet)

	return out
