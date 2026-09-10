class_name GenHeroes
extends RefCounted
## Authoring source for the five operatives.
##
## Run tools/generate_content.gd to (re)write resources/heroes/*.tres from this
## file. Editing numbers here and re-running keeps the data readable in git.

const DIR := "res://resources/heroes/"


static func run() -> void:
	_save(_nova())
	_save(_bramble())
	_save(_rift())
	_save(_aegis())
	_save(_ember())


static func _save(hero: HeroData) -> void:
	var path := DIR + String(hero.id) + ".tres"
	var err := ResourceSaver.save(hero, path)
	if err != OK:
		push_error("GenHeroes: failed to save %s (%d)" % [path, err])
	else:
		print("  hero  ", path)


static func _base() -> HeroData:
	var hero := HeroData.new()
	hero.max_health = 100.0
	hero.move_speed = 320.0
	hero.armor = 0.0
	hero.damage_mult = 1.0
	hero.cooldown_mult = 1.0
	hero.area_mult = 1.0
	hero.pickup_radius = 260.0
	hero.crit_chance = 0.05
	hero.crit_damage = 1.6
	hero.ultimate_cooldown = 42.0
	hero.ultimate_duration = 8.0
	return hero


static func _nova() -> HeroData:
	var hero := _base()
	hero.id = &"nova"
	hero.display_name = "Nova"
	hero.role = "Plasma Engineer"
	hero.description = "Keeps the grid alive by overclocking anything with a power cell. Fast cycles, thin plating."
	hero.max_health = 110.0
	hero.move_speed = 330.0
	hero.cooldown_mult = 0.94
	hero.crit_chance = 0.08
	hero.starting_power_id = &"drone"
	hero.passive_id = &"overclock"
	hero.passive_name = "Overclock"
	hero.passive_description = "Weapons cycle 12% faster and cover slightly more ground."
	hero.ultimate_id = &"plasma_drones"
	hero.ultimate_name = "Drone Halo"
	hero.ultimate_description = "Summons five plasma drones that orbit and shred anything they touch."
	hero.accent = Color(0.35, 0.90, 1.00)
	hero.accent_secondary = Color(0.60, 1.00, 0.85)
	hero.portrait_shape = 2
	hero.unlocked_by_default = true
	hero.unlock_credit_cost = 0
	hero.unlock_research_cost = 0
	return hero


static func _bramble() -> HeroData:
	var hero := _base()
	hero.id = &"bramble"
	hero.display_name = "Bramble"
	hero.role = "Bio-Guardian"
	hero.description = "Grew the vault gardens, then grew something that fights back. Slow, patient, hard to finish."
	hero.max_health = 130.0
	hero.move_speed = 300.0
	hero.armor = 2.0
	hero.area_mult = 1.05
	hero.starting_power_id = &"domain"
	hero.passive_id = &"deep_roots"
	hero.passive_name = "Deep Roots"
	hero.passive_description = "Regenerates health continuously and carries a larger reserve."
	hero.ultimate_id = &"thorn_maze"
	hero.ultimate_name = "Thorn Maze"
	hero.ultimate_description = "Grows a lattice of thorn patches that cut and badly slow anything crossing them."
	hero.accent = Color(0.45, 0.95, 0.55)
	hero.accent_secondary = Color(0.90, 1.00, 0.45)
	hero.portrait_shape = 3
	hero.unlock_credit_cost = 1400
	hero.unlock_research_cost = 18
	return hero


static func _rift() -> HeroData:
	var hero := _base()
	hero.id = &"rift"
	hero.display_name = "Rift"
	hero.role = "Dimensional Scout"
	hero.description = "Maps the tears the swarm crawls out of. Never quite in the place you last saw."
	hero.max_health = 85.0
	hero.move_speed = 355.0
	hero.crit_chance = 0.10
	hero.crit_damage = 1.75
	hero.luck = 2.0
	hero.starting_power_id = &"drill"
	hero.passive_id = &"phase_step"
	hero.passive_name = "Phase Step"
	hero.passive_description = "Moves 14% faster and shrugs off a slice of all incoming damage."
	hero.ultimate_id = &"rift_walk"
	hero.ultimate_name = "Rift Walk"
	hero.ultimate_description = "Blinks repeatedly into the thickest crowd, leaving damaging tears behind."
	hero.accent = Color(0.72, 0.55, 1.00)
	hero.accent_secondary = Color(1.00, 0.45, 0.85)
	hero.portrait_shape = 4
	hero.unlock_credit_cost = 2200
	hero.unlock_research_cost = 26
	return hero


static func _aegis() -> HeroData:
	var hero := _base()
	hero.id = &"aegis"
	hero.display_name = "Aegis"
	hero.role = "Shield Soldier"
	hero.description = "Last of the wall units. Built to stand in the doorway until the lights come back on."
	hero.max_health = 165.0
	hero.move_speed = 280.0
	hero.armor = 4.0
	hero.damage_mult = 0.94
	hero.starting_power_id = &"spinners"
	hero.passive_id = &"bulwark_plating"
	hero.passive_name = "Bulwark Plating"
	hero.passive_description = "Heavy armour and a deep health pool, at the cost of a little speed."
	hero.ultimate_id = &"aegis_bulwark"
	hero.ultimate_name = "Bulwark"
	hero.ultimate_description = "Becomes invulnerable and reflects every hit back at whatever landed it."
	hero.accent = Color(1.00, 0.78, 0.35)
	hero.accent_secondary = Color(0.55, 0.75, 1.00)
	hero.portrait_shape = 1
	hero.unlock_credit_cost = 1800
	hero.unlock_research_cost = 22
	return hero


static func _ember() -> HeroData:
	var hero := _base()
	hero.id = &"ember"
	hero.display_name = "Ember"
	hero.role = "Firecaster"
	hero.description = "Burned the first nest down alone. Has been feeding the habit ever since."
	hero.max_health = 100.0
	hero.move_speed = 310.0
	hero.damage_mult = 1.08
	hero.area_mult = 1.10
	hero.starting_power_id = &"molotov"
	hero.passive_id = &"kindling"
	hero.passive_name = "Kindling"
	hero.passive_description = "Every effect covers 18% more ground and critical hits land much harder."
	hero.ultimate_id = &"flame_wall"
	hero.ultimate_name = "Firewall"
	hero.ultimate_description = "Rolls a growing wall of flame outward in the direction you are facing."
	hero.accent = Color(1.00, 0.52, 0.22)
	hero.accent_secondary = Color(1.00, 0.85, 0.35)
	hero.portrait_shape = 0
	hero.unlock_credit_cost = 2600
	hero.unlock_research_cost = 30
	return hero
