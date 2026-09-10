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
	for group in [_weapons(), _powers(), _passives()]:
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


# --- Starting weapons -------------------------------------------------------

## Offered three at a time before a run; exactly one is granted and it spends
## none of the six slots. PowerLoadout.can_offer() is what stops a weapon being
## offered as a *new* pick mid-run, so their weights are ordinary ones: the one
## the player took still has to compete for level-ups like everything else.
##
## They are meant to play differently rather than to be balanced against each
## other stat for stat. A revolver that fires twice as slowly as the pistol for
## twice the damage is the same weapon with different numbers; the revolver is
## worth carrying because it also pierces and throws what it hits.
static func _starting(id: StringName, name: String, order: int) -> PowerData:
	var power := _base(id, name, order)
	power.starting_weapon = true
	return power


static func _weapons() -> Array[PowerData]:
	var katana := _starting(&"katana", "Katana", -1)
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

	var revolver := _starting(&"revolver", "Heavy Revolver", -2)
	revolver.behavior = PowerData.Behavior.VOLLEY
	revolver.description = "One heavy round at a time, straight through whatever is in the way."
	revolver.tooltip = "Slow, huge damage, punches through a line."
	revolver.aim = PowerData.Aim.NEAREST
	revolver.projectile_shape = 10
	revolver.damage = 46.0
	revolver.damage_per_level = 24.0
	revolver.cooldown = 1.15
	revolver.cooldown_mult_per_level = 0.95
	revolver.projectile_speed = 900.0
	revolver.pierce = 2
	revolver.knockback = 420.0
	revolver.count_at_levels = PackedInt32Array([4])
	revolver.level_notes = PackedStringArray([
		"+24 damage",
		"+24 damage, faster reload",
		"+24 damage, a second round per shot",
		"+24 damage, faster reload",
	])
	revolver.color = Color(1.00, 0.74, 0.32)
	revolver.color_secondary = Color(1.00, 0.95, 0.80)
	revolver.rarity = 2
	revolver.weight = 1.0

	var pistol := _starting(&"machine_pistol", "Machine Pistol", -3)
	pistol.behavior = PowerData.Behavior.VOLLEY
	pistol.description = "Empties a magazine in the time anything else takes to aim."
	pistol.tooltip = "Very fast, weak rounds in a tight spread."
	pistol.aim = PowerData.Aim.NEAREST
	pistol.projectile_shape = 0
	pistol.damage = 9.0
	pistol.damage_per_level = 5.0
	pistol.cooldown = 0.26
	pistol.cooldown_mult_per_level = 0.93
	pistol.projectile_speed = 820.0
	pistol.spread = 0.22
	pistol.knockback = 60.0
	pistol.count = 1
	pistol.count_at_levels = PackedInt32Array([2, 4])
	pistol.level_notes = PackedStringArray([
		"+5 damage, +1 round",
		"+5 damage, faster fire",
		"+5 damage, +1 round",
		"+5 damage, faster fire",
	])
	pistol.color = Color(0.62, 0.92, 1.00)
	pistol.color_secondary = Color(1.00, 1.00, 0.90)
	pistol.rarity = 1
	pistol.weight = 1.0

	var bow := _starting(&"longbow", "Longbow", -4)
	bow.behavior = PowerData.Behavior.BOW
	bow.description = "An arrow through the whole line. It hits hardest at range."
	bow.tooltip = "Pierces everything. Weak up close, full damage far out."
	bow.damage = 30.0
	bow.damage_per_level = 16.0
	bow.cooldown = 0.72
	bow.cooldown_mult_per_level = 0.94
	bow.projectile_speed = 1150.0
	bow.pierce = 2
	bow.knockback = 110.0
	bow.count_at_levels = PackedInt32Array([5])
	bow.level_notes = PackedStringArray([
		"+16 damage, pierces one more",
		"+16 damage, faster draw",
		"+16 damage, pierces one more",
		"+16 damage, and a second arrow",
	])
	bow.color = Color(0.66, 1.00, 0.72)
	bow.color_secondary = Color(1.00, 0.96, 0.66)
	bow.rarity = 2
	bow.weight = 1.0

	var spear := _starting(&"spear", "Spear", -5)
	spear.behavior = PowerData.Behavior.SPEAR
	spear.description = "A long thrust along the way you are moving. Reach beats width."
	spear.tooltip = "Thrusts far ahead of you. Narrow, and very long."
	spear.damage = 26.0
	spear.damage_per_level = 15.0
	spear.cooldown = 0.60
	spear.cooldown_mult_per_level = 1.0
	spear.area_per_level = 0.20
	spear.knockback = 240.0
	spear.count_at_levels = PackedInt32Array()
	spear.level_notes = PackedStringArray([
		"+15 damage, longer reach",
		"+15 damage, longer reach",
		"+15 damage, longer reach",
		"+15 damage, and every thrust becomes a double-tap",
	])
	spear.color = Color(0.86, 0.92, 1.00)
	spear.color_secondary = Color(0.55, 0.85, 1.00)
	spear.rarity = 1
	spear.weight = 1.0

	var chakram := _starting(&"chakram", "Chakram", -6)
	chakram.behavior = PowerData.Behavior.VOLLEY
	chakram.description = "A thrown ring that cuts on the way out and again on the way back."
	chakram.tooltip = "Returns to you, hitting twice per throw."
	chakram.aim = PowerData.Aim.NEAREST
	chakram.motion = 3
	chakram.projectile_shape = 9
	chakram.damage = 20.0
	chakram.damage_per_level = 11.0
	chakram.cooldown = 0.90
	chakram.cooldown_mult_per_level = 0.94
	chakram.projectile_speed = 620.0
	chakram.pierce = 6
	chakram.duration = 1.6
	chakram.hit_interval = 0.35
	chakram.knockback = 130.0
	chakram.spread = 0.5
	chakram.count_at_levels = PackedInt32Array([3, 5])
	chakram.level_notes = PackedStringArray([
		"+11 damage, faster throws",
		"+11 damage, +1 ring",
		"+11 damage, faster throws",
		"+11 damage, +1 ring",
	])
	chakram.color = Color(0.75, 0.85, 1.00)
	chakram.color_secondary = Color(1.00, 0.80, 0.45)
	chakram.rarity = 2
	chakram.weight = 1.0

	var hammer := _starting(&"warhammer", "War Hammer", -7)
	hammer.behavior = PowerData.Behavior.HAMMER
	hammer.description = "One enormous smash at your feet. Everything near you leaves staggered."
	hammer.tooltip = "Very slow. Huge radial hit, big knockback, staggers."
	hammer.damage = 58.0
	hammer.damage_per_level = 30.0
	hammer.cooldown = 1.70
	hammer.cooldown_mult_per_level = 0.96
	hammer.area_per_level = 0.12
	hammer.knockback = 560.0
	hammer.count_at_levels = PackedInt32Array()
	hammer.level_notes = PackedStringArray([
		"+30 damage, wider smash",
		"+30 damage, wider smash",
		"+30 damage, wider smash",
		"+30 damage, and the impact sends out an aftershock",
	])
	hammer.color = Color(1.00, 0.62, 0.30)
	hammer.color_secondary = Color(1.00, 0.88, 0.52)
	hammer.rarity = 2
	hammer.weight = 1.0

	var flamer := _starting(&"flamethrower", "Flamethrower", -8)
	flamer.behavior = PowerData.Behavior.FLAMER
	flamer.description = "A short cone of burning air that keeps burning after it passes."
	flamer.tooltip = "Close range cone. Leaves the ground on fire."
	flamer.damage = 7.0
	flamer.damage_per_level = 4.2
	flamer.cooldown = 0.42
	flamer.cooldown_mult_per_level = 0.96
	flamer.area_per_level = 0.14
	flamer.duration = 1.1
	flamer.duration_per_level = 0.12
	flamer.knockback = 0.0
	flamer.hit_interval = 0.22
	flamer.count_at_levels = PackedInt32Array()
	flamer.level_notes = PackedStringArray([
		"+4.2 damage, wider cone, fire lasts longer",
		"+4.2 damage, wider cone, fire lasts longer",
		"+4.2 damage, wider cone, fire lasts longer",
		"+4.2 damage, and the fire burns for its full duration",
	])
	flamer.color = Color(1.00, 0.52, 0.22)
	flamer.color_secondary = Color(1.00, 0.86, 0.36)
	flamer.rarity = 1
	flamer.weight = 1.0

	var out: Array[PowerData] = [katana, revolver, pistol, bow, spear, chakram, hammer, flamer]
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


	# --- Second wave -------------------------------------------------------
	# Everything below is built on the two generic behaviours (VOLLEY and NOVA)
	# plus four one-off loops. A power earns its own script only when its loop
	# is genuinely different; "same loop, different numbers" is a data change,
	# which is why thirteen powers here cost six scripts between them.

	var coil := _base(&"arc_coil", "Arc Coil", 7)
	coil.behavior = PowerData.Behavior.VOLLEY
	coil.description = "A bolt that jumps from one body to the next until it runs out."
	coil.tooltip = "Chains between nearby enemies."
	coil.aim = PowerData.Aim.NEAREST
	coil.on_hit = 2
	coil.projectile_shape = 1
	coil.damage = 14.0
	coil.damage_per_level = 7.0
	coil.cooldown = 0.85
	coil.cooldown_mult_per_level = 0.93
	coil.projectile_speed = 780.0
	coil.effect_radius = 260.0
	coil.effect_value = 3.0
	coil.knockback = 40.0
	coil.level_notes = PackedStringArray([
		"+7 damage, faster arcs",
		"+7 damage, longer chains",
		"+7 damage, faster arcs",
		"+7 damage, longer chains",
	])
	coil.color = Color(0.55, 0.90, 1.00)
	coil.color_secondary = Color(1.00, 1.00, 0.72)
	coil.rarity = 2
	out.append(coil)

	var swarm := _base(&"seeker_swarm", "Seeker Swarm", 8)
	swarm.behavior = PowerData.Behavior.VOLLEY
	swarm.description = "Missiles that hunt on their own and burst where they land."
	swarm.tooltip = "Homing missiles. They explode on contact."
	swarm.aim = PowerData.Aim.RANDOM
	swarm.motion = 1
	swarm.on_hit = 1
	swarm.projectile_shape = 6
	swarm.damage = 16.0
	swarm.damage_per_level = 8.0
	swarm.cooldown = 1.25
	swarm.cooldown_mult_per_level = 0.93
	swarm.projectile_speed = 430.0
	swarm.effect_radius = 110.0
	swarm.spread = 0.9
	swarm.count = 2
	swarm.count_at_levels = PackedInt32Array([3, 5])
	swarm.level_notes = PackedStringArray([
		"+8 damage, faster launches",
		"+8 damage, +1 missile",
		"+8 damage, faster launches",
		"+8 damage, +1 missile",
	])
	swarm.color = Color(1.00, 0.66, 0.42)
	swarm.color_secondary = Color(1.00, 0.92, 0.60)
	swarm.rarity = 2
	out.append(swarm)

	var grenades := _base(&"grenade_volley", "Grenade Volley", 9)
	grenades.behavior = PowerData.Behavior.VOLLEY
	grenades.description = "A fan of charges thrown into the thick of it."
	grenades.tooltip = "Explosives lobbed at the crowd."
	grenades.aim = PowerData.Aim.DENSEST
	grenades.on_hit = 1
	grenades.projectile_shape = 4
	grenades.damage = 20.0
	grenades.damage_per_level = 11.0
	grenades.cooldown = 1.45
	grenades.cooldown_mult_per_level = 0.94
	grenades.projectile_speed = 480.0
	grenades.effect_radius = 150.0
	grenades.spread = 0.55
	grenades.knockback = 200.0
	grenades.count = 2
	grenades.count_at_levels = PackedInt32Array([3, 5])
	grenades.level_notes = PackedStringArray([
		"+11 damage, bigger blast",
		"+11 damage, +1 charge",
		"+11 damage, bigger blast",
		"+11 damage, +1 charge",
	])
	grenades.color = Color(0.92, 0.74, 0.36)
	grenades.color_secondary = Color(1.00, 0.50, 0.28)
	grenades.rarity = 1
	out.append(grenades)

	var fang := _base(&"boomerang_fang", "Boomerang Fang", 10)
	fang.behavior = PowerData.Behavior.VOLLEY
	fang.description = "Fanged blades thrown wide that come back through the same crowd."
	fang.tooltip = "Thrown blades return to you, cutting both ways."
	fang.aim = PowerData.Aim.NEAREST
	fang.motion = 3
	fang.projectile_shape = 7
	fang.damage = 15.0
	fang.damage_per_level = 8.0
	fang.cooldown = 1.05
	fang.cooldown_mult_per_level = 0.94
	fang.projectile_speed = 560.0
	fang.pierce = 8
	fang.duration = 1.7
	fang.hit_interval = 0.35
	fang.spread = 1.0
	fang.count = 2
	fang.count_at_levels = PackedInt32Array([3, 5])
	fang.level_notes = PackedStringArray([
		"+8 damage, faster throws",
		"+8 damage, +1 blade",
		"+8 damage, faster throws",
		"+8 damage, +1 blade",
	])
	fang.color = Color(0.80, 0.88, 1.00)
	fang.color_secondary = Color(1.00, 0.72, 0.86)
	fang.rarity = 1
	out.append(fang)

	var ricochet := _base(&"ricochet_orb", "Ricochet Orb", 11)
	ricochet.behavior = PowerData.Behavior.VOLLEY
	ricochet.description = "An orb that refuses to leave, bouncing off the edges of the field."
	ricochet.tooltip = "Bounces around the arena for a long time."
	ricochet.aim = PowerData.Aim.RADIAL
	ricochet.motion = 4
	ricochet.projectile_shape = 5
	ricochet.damage = 18.0
	ricochet.damage_per_level = 9.0
	ricochet.cooldown = 1.60
	ricochet.cooldown_mult_per_level = 0.95
	ricochet.projectile_speed = 520.0
	ricochet.pierce = 3
	ricochet.duration = 4.5
	ricochet.duration_per_level = 0.6
	ricochet.hit_interval = 0.4
	ricochet.count = 1
	ricochet.count_at_levels = PackedInt32Array([3, 5])
	ricochet.level_notes = PackedStringArray([
		"+9 damage, lasts longer",
		"+9 damage, +1 orb",
		"+9 damage, lasts longer",
		"+9 damage, +1 orb",
	])
	ricochet.color = Color(0.70, 0.60, 1.00)
	ricochet.color_secondary = Color(0.95, 0.90, 1.00)
	ricochet.rarity = 1
	out.append(ricochet)

	var lance := _base(&"rail_lance", "Rail Lance", 12)
	lance.behavior = PowerData.Behavior.VOLLEY
	lance.description = "A slug fired along the way you are running, through everything."
	lance.tooltip = "Fires where you move. Pierces the whole line."
	lance.aim = PowerData.Aim.MOVEMENT
	lance.projectile_shape = 10
	lance.damage = 40.0
	lance.damage_per_level = 22.0
	lance.cooldown = 1.30
	lance.cooldown_mult_per_level = 0.94
	lance.projectile_speed = 1400.0
	lance.pierce = 20
	lance.knockback = 260.0
	lance.level_notes = PackedStringArray([
		"+22 damage",
		"+22 damage, faster charge",
		"+22 damage",
		"+22 damage, faster charge",
	])
	lance.color = Color(0.50, 0.98, 1.00)
	lance.color_secondary = Color(1.00, 1.00, 1.00)
	lance.rarity = 2
	out.append(lance)

	var frost := _base(&"frost_nova", "Frost Nova", 13)
	frost.behavior = PowerData.Behavior.NOVA
	frost.description = "A ring of cold that leaves whatever it touches crawling."
	frost.tooltip = "Radial pulse. Slows everything it hits."
	frost.aim = PowerData.Aim.NEAREST
	frost.projectile_shape = 4
	frost.damage = 15.0
	frost.damage_per_level = 8.0
	frost.cooldown = 1.50
	frost.cooldown_mult_per_level = 0.93
	frost.area_per_level = 0.14
	frost.duration = 2.0
	frost.duration_per_level = 0.2
	frost.effect_value = 0.45
	frost.knockback = 60.0
	frost.level_notes = PackedStringArray([
		"+8 damage, wider ring",
		"+8 damage, the slow lasts longer",
		"+8 damage, wider ring",
		"+8 damage, the slow lasts longer",
	])
	frost.color = Color(0.60, 0.88, 1.00)
	frost.color_secondary = Color(0.90, 0.98, 1.00)
	frost.rarity = 1
	out.append(frost)

	var flare := _base(&"sun_flare", "Sun Flare", 14)
	flare.behavior = PowerData.Behavior.NOVA
	flare.description = "A column of light dropped on the thickest part of the crowd."
	flare.tooltip = "Lands where the swarm is densest."
	flare.aim = PowerData.Aim.DENSEST
	flare.projectile_shape = 5
	flare.damage = 34.0
	flare.damage_per_level = 18.0
	flare.cooldown = 1.80
	flare.cooldown_mult_per_level = 0.93
	flare.area_per_level = 0.12
	flare.duration = 0.4
	flare.knockback = 180.0
	flare.level_notes = PackedStringArray([
		"+18 damage, wider column",
		"+18 damage, falls sooner",
		"+18 damage, wider column",
		"+18 damage, falls sooner",
	])
	flare.color = Color(1.00, 0.86, 0.36)
	flare.color_secondary = Color(1.00, 0.98, 0.82)
	flare.rarity = 2
	out.append(flare)

	var thorns := _base(&"thorn_aura", "Thorn Aura", 15)
	thorns.behavior = PowerData.Behavior.NOVA
	thorns.description = "A thicket of barbs around you that never stops turning over."
	thorns.tooltip = "Permanent ring of damage around you."
	thorns.aim = PowerData.Aim.NEAREST
	thorns.projectile_shape = 3
	thorns.damage = 6.0
	thorns.damage_per_level = 3.2
	thorns.cooldown = 1.60
	thorns.cooldown_mult_per_level = 1.0
	thorns.area_per_level = 0.13
	thorns.duration = 1.7
	thorns.duration_per_level = 0.1
	thorns.hit_interval = 0.35
	thorns.effect_value = 1.0
	thorns.knockback = 0.0
	thorns.level_notes = PackedStringArray([
		"+3.2 damage, wider ring",
		"+3.2 damage, wider ring",
		"+3.2 damage, wider ring",
		"+3.2 damage, wider ring",
	])
	thorns.color = Color(0.55, 0.95, 0.55)
	thorns.color_secondary = Color(0.90, 1.00, 0.60)
	thorns.rarity = 1
	out.append(thorns)

	var mines := _base(&"mine_field", "Mine Field", 16)
	mines.behavior = PowerData.Behavior.MINES
	mines.description = "Charges laid in your wake for whatever is chasing you."
	mines.tooltip = "Drops mines behind you. They arm, then blow."
	mines.damage = 30.0
	mines.damage_per_level = 16.0
	mines.cooldown = 1.20
	mines.cooldown_mult_per_level = 0.94
	mines.area_per_level = 0.12
	mines.knockback = 300.0
	mines.count = 1
	mines.count_at_levels = PackedInt32Array([3, 5])
	mines.level_notes = PackedStringArray([
		"+16 damage, bigger blast",
		"+16 damage, +1 charge",
		"+16 damage, bigger blast",
		"+16 damage, +1 charge",
	])
	mines.color = Color(1.00, 0.55, 0.42)
	mines.color_secondary = Color(1.00, 0.86, 0.40)
	mines.rarity = 1
	out.append(mines)

	var turret := _base(&"shock_turret", "Shock Turret", 17)
	turret.behavior = PowerData.Behavior.TURRET
	turret.description = "An emplacement planted where you stand, holding that ground for you."
	turret.tooltip = "Deploys a turret that shoots on its own."
	turret.damage = 11.0
	turret.damage_per_level = 6.0
	turret.cooldown = 3.20
	turret.cooldown_mult_per_level = 0.92
	turret.projectile_speed = 640.0
	turret.duration = 5.0
	turret.duration_per_level = 0.7
	turret.hit_interval = 0.38
	turret.count = 1
	turret.count_at_levels = PackedInt32Array([4])
	turret.level_notes = PackedStringArray([
		"+6 damage, the turret lasts longer",
		"+6 damage, deploys sooner",
		"+6 damage, and it fires an extra round",
		"+6 damage, the turret lasts longer",
	])
	turret.color = Color(0.60, 0.82, 1.00)
	turret.color_secondary = Color(1.00, 0.90, 0.55)
	turret.rarity = 2
	out.append(turret)

	var storm := _base(&"blade_storm", "Blade Storm", 18)
	storm.behavior = PowerData.Behavior.BLADESTORM
	storm.description = "Four cuts chasing each other all the way around you."
	storm.tooltip = "A full circle of blades, one after another."
	storm.damage = 21.0
	storm.damage_per_level = 11.0
	storm.cooldown = 1.55
	storm.cooldown_mult_per_level = 0.93
	storm.area_per_level = 0.11
	storm.knockback = 170.0
	storm.level_notes = PackedStringArray([
		"+11 damage, wider sweep",
		"+11 damage, faster storms",
		"+11 damage, wider sweep",
		"+11 damage, and a second pass the other way",
	])
	storm.color = Color(0.88, 0.94, 1.00)
	storm.color_secondary = Color(1.00, 0.78, 0.50)
	storm.rarity = 2
	out.append(storm)

	var well := _base(&"void_well", "Void Well", 19)
	well.behavior = PowerData.Behavior.VOID_WELL
	well.description = "A well that drags the swarm into one place and holds it there."
	well.tooltip = "Pulls enemies together while it burns them."
	well.damage = 9.0
	well.damage_per_level = 5.0
	well.cooldown = 2.60
	well.cooldown_mult_per_level = 0.93
	well.area_per_level = 0.12
	well.duration = 2.4
	well.duration_per_level = 0.3
	well.hit_interval = 0.3
	well.level_notes = PackedStringArray([
		"+5 damage, stronger pull",
		"+5 damage, the well lasts longer",
		"+5 damage, stronger pull",
		"+5 damage, the well lasts longer",
	])
	well.color = Color(0.66, 0.44, 1.00)
	well.color_secondary = Color(1.00, 0.62, 0.92)
	well.rarity = 3
	out.append(well)

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


	# Each of these owns a different axis. A second passive that also bought
	# damage and area would just be a worse Resonance Lens, and picking between
	# them would be arithmetic rather than a decision.

	var hollow := _passive(&"hollow_point", "Hollow Point", 15)
	hollow.description = "Rounds that open up on the way in."
	hollow.tooltip = "More critical hits, and harder ones."
	hollow.stat_multipliers = {"crit_damage_mult": 0.15}
	hollow.stat_flats = {"crit_chance": 0.05}
	hollow.color = Color(1.00, 0.55, 0.55)
	hollow.color_secondary = Color(1.00, 0.88, 0.60)
	hollow.rarity = 2
	out.append(hollow)

	var weave := _passive(&"vital_weave", "Vital Weave", 16)
	weave.description = "Mesh that knits itself back together while you keep moving."
	weave.tooltip = "Regenerates health continuously."
	weave.stat_flats = {"health_regen": 1.2, "max_health": 12.0}
	weave.color = Color(0.55, 1.00, 0.72)
	weave.color_secondary = Color(0.90, 1.00, 0.85)
	weave.rarity = 1
	out.append(weave)

	var siege := _passive(&"siege_charge", "Siege Charge", 17)
	siege.description = "Overpacked charges that throw what they do not kill."
	siege.tooltip = "Much stronger knockback, slightly bigger effects."
	siege.stat_multipliers = {"knockback_mult": 0.22, "area_mult": 0.06}
	siege.color = Color(1.00, 0.72, 0.38)
	siege.color_secondary = Color(1.00, 0.92, 0.66)
	siege.rarity = 1
	out.append(siege)

	var shell := _passive(&"ablative_shell", "Ablative Shell", 18)
	shell.description = "A skin that spends itself a layer at a time so you do not."
	shell.tooltip = "Takes a flat cut out of everything that hits you."
	shell.stat_flats = {"damage_reduction": 0.05, "armor": 2.0}
	shell.color = Color(0.70, 0.78, 0.90)
	shell.color_secondary = Color(0.95, 0.98, 1.00)
	shell.rarity = 2
	out.append(shell)

	var barrel := _passive(&"split_barrel", "Split Barrel", 19)
	barrel.description = "Every barrel bored twice. Every second level pays out an extra shot."
	barrel.tooltip = "+1 projectile on every weapon, every two levels."
	barrel.stat_multipliers = {"projectile_speed_mult": 0.05}
	barrel.stat_flats = {"projectile_count_bonus": 0.5}
	barrel.color = Color(1.00, 0.86, 0.45)
	barrel.color_secondary = Color(0.80, 0.94, 1.00)
	barrel.rarity = 3
	barrel.weight = 0.8
	out.append(barrel)

	var fuse := _passive(&"long_fuse", "Long Fuse", 20)
	fuse.description = "Nothing you leave behind goes out as quickly as it should."
	fuse.tooltip = "Zones, fires and fields all last longer."
	fuse.stat_multipliers = {"duration_mult": 0.18, "area_mult": 0.05}
	fuse.color = Color(1.00, 0.66, 0.36)
	fuse.color_secondary = Color(1.00, 0.90, 0.55)
	fuse.rarity = 1
	out.append(fuse)

	var dice := _passive(&"omen_dice", "Omen Dice", 21)
	dice.description = "Weighted, and not in the swarm's favour."
	dice.tooltip = "Better luck: rarer offers and richer drops."
	dice.stat_multipliers = {"xp_gain_mult": 0.10}
	dice.stat_flats = {"luck": 0.07}
	dice.color = Color(0.82, 0.70, 1.00)
	dice.color_secondary = Color(1.00, 0.92, 0.70)
	dice.rarity = 2
	out.append(dice)

	return out
