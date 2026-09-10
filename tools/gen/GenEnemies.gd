class_name GenEnemies
extends RefCounted
## Authoring source for every enemy archetype, five per sector plus a mid-boss
## and a boss. Enemy.tscn is configured from these at spawn time.

const DIR := "res://resources/enemies/"


static func run() -> void:
	for group in [_neon_ruins(), _ash_wastes(), _flooded_vault(), _moonfall_ridge()]:
		for enemy in group:
			_save(enemy)


static func _save(enemy: EnemyData) -> void:
	var path := DIR + String(enemy.id) + ".tres"
	var err := ResourceSaver.save(enemy, path)
	if err != OK:
		push_error("GenEnemies: failed to save %s (%d)" % [path, err])
	else:
		print("  enemy  ", path)


static func _make(id: StringName, name: String, ai: EnemyData.AI, health: float,
		speed: float, damage: float, radius: float, xp: int,
		color: Color, dark: Color, shape: int) -> EnemyData:
	var enemy := EnemyData.new()
	enemy.id = id
	enemy.display_name = name
	enemy.ai = ai
	enemy.max_health = health
	enemy.move_speed = speed
	enemy.contact_damage = damage
	enemy.radius = radius
	enemy.xp_value = xp
	enemy.credit_value = xp
	enemy.color = color
	enemy.color_secondary = dark
	enemy.shape = shape
	enemy.mass = radius / 22.0
	return enemy


static func _boss(id: StringName, name: String, title: String, health: float,
		speed: float, damage: float, color: Color, dark: Color, shape: int) -> EnemyData:
	var boss := _make(id, name, EnemyData.AI.CHASER, health, speed, damage, 46.0, 60, color, dark, shape)
	boss.is_boss = true
	boss.can_be_elite = false
	boss.boss_title = title
	boss.knockback_resist = 0.85
	boss.mass = 12.0
	boss.projectile_speed = 320.0
	boss.projectile_damage = 16.0
	boss.boss_phase_thresholds = PackedFloat32Array([0.66, 0.33])
	return boss


# --- Sector 1: Neon Ruins ---------------------------------------------------

static func _neon_ruins() -> Array[EnemyData]:
	var cyan := Color(0.35, 0.85, 1.00)
	var magenta := Color(1.00, 0.35, 0.75)
	var lime := Color(0.65, 1.00, 0.45)
	var out: Array[EnemyData] = []

	out.append(_make(&"nr_drone", "Scrap Drone", EnemyData.AI.CHASER,
		14.0, 173.0, 4.4, 20.0, 1, cyan, Color(0.06, 0.14, 0.22), 3))

	var crawler := _make(&"nr_crawler", "Cable Crawler", EnemyData.AI.DRIFTER,
		22.0, 205.0, 5.5, 22.0, 1, magenta, Color(0.20, 0.04, 0.14), 5)
	out.append(crawler)

	var spark := _make(&"nr_spark", "Arc Sprinter", EnemyData.AI.CHARGER,
		30.0, 154.0, 7.7, 24.0, 2, lime, Color(0.10, 0.22, 0.06), 0)
	spark.charge_interval = 2.6
	spark.charge_speed_mult = 3.6
	out.append(spark)

	var turret := _make(&"nr_turret", "Wall Turret", EnemyData.AI.SHOOTER,
		38.0, 99.0, 5.5, 26.0, 3, Color(1.00, 0.78, 0.30), Color(0.24, 0.16, 0.02), 1)
	turret.shoot_interval = 2.2
	turret.projectile_speed = 300.0
	turret.projectile_damage = 9.0
	out.append(turret)

	var hulk := _make(&"nr_hulk", "Rebar Hulk", EnemyData.AI.CHASER,
		140.0, 118.0, 11.0, 40.0, 6, Color(0.60, 0.70, 0.85), Color(0.10, 0.14, 0.22), 2)
	hulk.knockback_resist = 0.55
	out.append(hulk)

	var mid := _boss(&"nr_mid_bulwark", "Rail Bulwark", "SIGNAL SPIKE",
		1600.0, 101.0, 13.2, Color(0.55, 0.90, 1.00), Color(0.06, 0.16, 0.26), 1)
	out.append(mid)

	var boss := _boss(&"nr_boss_warden", "Sentinel Warden", "WARDEN ONLINE",
		3400.0, 114.0, 16.5, cyan, Color(0.04, 0.12, 0.20), 3)
	boss.spin_speed = 0.5
	out.append(boss)
	return out


# --- Sector 2: Ash Wastes ---------------------------------------------------

static func _ash_wastes() -> Array[EnemyData]:
	var ember := Color(1.00, 0.48, 0.20)
	var ash := Color(0.72, 0.66, 0.60)
	var out: Array[EnemyData] = []

	out.append(_make(&"aw_scuttler", "Cinder Scuttler", EnemyData.AI.CHASER,
		26.0, 195.0, 6.1, 20.0, 1, ember, Color(0.24, 0.08, 0.02), 0))

	var hound := _make(&"aw_hound", "Ash Hound", EnemyData.AI.CHARGER,
		42.0, 166.0, 9.4, 24.0, 2, Color(1.00, 0.30, 0.20), Color(0.24, 0.04, 0.03), 5)
	hound.charge_interval = 2.2
	out.append(hound)

	var spitter := _make(&"aw_spitter", "Magma Spitter", EnemyData.AI.SHOOTER,
		48.0, 112.0, 6.6, 26.0, 3, Color(1.00, 0.72, 0.25), Color(0.28, 0.16, 0.02), 2)
	spitter.shoot_interval = 2.0
	spitter.projectile_damage = 12.0
	out.append(spitter)

	var brood := _make(&"aw_brood", "Ember Brood", EnemyData.AI.SPLITTER,
		62.0, 141.0, 7.2, 30.0, 3, Color(1.00, 0.60, 0.35), Color(0.26, 0.10, 0.04), 3)
	brood.split_into_id = &"aw_scuttler"
	brood.split_count = 3
	out.append(brood)

	var behemoth := _make(&"aw_behemoth", "Slag Behemoth", EnemyData.AI.CHASER,
		230.0, 109.0, 14.3, 44.0, 8, ash, Color(0.16, 0.13, 0.11), 2)
	behemoth.knockback_resist = 0.7
	out.append(behemoth)

	var mid := _boss(&"aw_mid_maw", "Cinder Maw", "THE GROUND SPLITS",
		2600.0, 96.0, 15.4, Color(1.00, 0.55, 0.20), Color(0.26, 0.08, 0.02), 5)
	out.append(mid)

	var boss := _boss(&"aw_boss_ashbrand", "Ashbrand", "ASHBRAND WAKES",
		7000.0, 104.0, 19.8, Color(1.00, 0.36, 0.12), Color(0.22, 0.05, 0.01), 2)
	boss.knockback_resist = 0.95
	out.append(boss)
	return out


# --- Sector 3: Flooded Vault ------------------------------------------------

static func _flooded_vault() -> Array[EnemyData]:
	var teal := Color(0.35, 0.95, 0.85)
	var deep := Color(0.30, 0.60, 1.00)
	var out: Array[EnemyData] = []

	out.append(_make(&"fv_leech", "Vault Leech", EnemyData.AI.CHASER,
		26.0, 189.0, 7.2, 20.0, 2, teal, Color(0.04, 0.20, 0.20), 5))

	out.append(_make(&"fv_drifter", "Pale Drifter", EnemyData.AI.DRIFTER,
		36.0, 202.0, 8.2, 24.0, 2, deep, Color(0.04, 0.12, 0.26), 3))

	var lurker := _make(&"fv_lurker", "Coil Lurker", EnemyData.AI.ORBITER,
		51.0, 211.0, 8.8, 26.0, 3, Color(0.65, 0.45, 1.00), Color(0.12, 0.06, 0.26), 4)
	lurker.orbit_radius = 190.0
	out.append(lurker)

	var sporeling := _make(&"fv_sporeling", "Spore Vessel", EnemyData.AI.SPLITTER,
		62.0, 147.0, 8.2, 32.0, 4, Color(0.60, 1.00, 0.55), Color(0.10, 0.24, 0.08), 3)
	sporeling.split_into_id = &"fv_leech"
	sporeling.split_count = 3
	out.append(sporeling)

	var warden := _make(&"fv_warden", "Pressure Warden", EnemyData.AI.SHOOTER,
		78.0, 106.0, 8.8, 30.0, 5, Color(1.00, 0.80, 0.40), Color(0.26, 0.18, 0.04), 1)
	warden.shoot_interval = 1.8
	warden.projectile_damage = 15.0
	warden.projectile_speed = 340.0
	out.append(warden)

	var mid := _boss(&"fv_mid_husk", "Drowned Husk", "PRESSURE RISING",
		2940.0, 94.0, 17.6, deep, Color(0.03, 0.10, 0.24), 5)
	out.append(mid)

	var boss := _boss(&"fv_boss_sentinel", "Mutated Sentinel", "CONTAINMENT FAILED",
		7700.0, 109.0, 23.1, teal, Color(0.02, 0.18, 0.18), 4)
	boss.boss_phase_thresholds = PackedFloat32Array([0.75, 0.5, 0.25])
	out.append(boss)
	return out


# --- Sector 4: Moonfall Ridge -----------------------------------------------

static func _moonfall_ridge() -> Array[EnemyData]:
	var violet := Color(0.78, 0.55, 1.00)
	var pale := Color(0.85, 0.90, 1.00)
	var out: Array[EnemyData] = []

	out.append(_make(&"mr_mote", "Gravity Mote", EnemyData.AI.DRIFTER,
		28.0, 221.0, 8.8, 18.0, 2, pale, Color(0.16, 0.18, 0.28), 4))

	var swarmling := _make(&"mr_swarmling", "Ridge Swarmling", EnemyData.AI.CHASER,
		35.0, 243.0, 9.9, 20.0, 3, violet, Color(0.14, 0.06, 0.26), 0)
	out.append(swarmling)

	var stalker := _make(&"mr_stalker", "Chasm Stalker", EnemyData.AI.CHARGER,
		58.0, 179.0, 13.2, 28.0, 4, Color(1.00, 0.40, 0.70), Color(0.24, 0.04, 0.16), 5)
	stalker.charge_interval = 1.9
	stalker.charge_speed_mult = 4.0
	out.append(stalker)

	var seer := _make(&"mr_seer", "Pale Seer", EnemyData.AI.SHOOTER,
		72.0, 115.0, 11.0, 32.0, 6, Color(0.55, 0.95, 1.00), Color(0.06, 0.20, 0.28), 2)
	seer.shoot_interval = 1.6
	seer.projectile_damage = 19.0
	seer.projectile_speed = 380.0
	out.append(seer)

	var colossus := _make(&"mr_colossus", "Moonfall Colossus", EnemyData.AI.CHASER,
		216.0, 106.0, 18.7, 48.0, 12, Color(0.70, 0.75, 0.95), Color(0.14, 0.16, 0.26), 2)
	colossus.knockback_resist = 0.8
	out.append(colossus)

	var mid := _boss(&"mr_mid_grasper", "Ridge Grasper", "THE RIDGE MOVES",
		3850.0, 99.0, 22.0, violet, Color(0.12, 0.04, 0.24), 4)
	out.append(mid)

	var boss := _boss(&"mr_boss_parasite", "Celestial Parasite", "IT LOOKS BACK",
		9900.0, 112.0, 28.6, Color(0.90, 0.60, 1.00), Color(0.10, 0.02, 0.20), 4)
	boss.boss_phase_thresholds = PackedFloat32Array([0.8, 0.6, 0.4, 0.2])
	boss.spin_speed = 0.35
	out.append(boss)
	return out
