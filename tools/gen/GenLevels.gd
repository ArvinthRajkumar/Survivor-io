class_name GenLevels
extends RefCounted
## Authoring source for the four sectors: palette, hazards, enemy pool, wave
## script and boss timings.
##
## Runs are endless. `unlock_time` is the survival milestone that unlocks the
## next sector, the wave script covers the opening minutes, and the director
## keeps generating from the enemy pool after that.
##
## Waves deliberately overlap. Each entry is live between start_time and
## end_time, so late in a run three or four scripts feed the field at once.

const DIR := "res://resources/levels/"
const ENEMY_DIR := "res://resources/enemies/"


static func run() -> void:
	_save(_neon_ruins())
	_save(_ash_wastes())
	_save(_flooded_vault())
	_save(_moonfall_ridge())


static func _save(level: LevelData) -> void:
	var path := DIR + String(level.id) + ".tres"
	var err := ResourceSaver.save(level, path)
	if err != OK:
		push_error("GenLevels: failed to save %s (%d)" % [path, err])
	else:
		print("  level  ", path)


static func _pool(ids: Array) -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for id in ids:
		var res := ResourceLoader.load(ENEMY_DIR + String(id) + ".tres") as EnemyData
		if res == null:
			push_error("GenLevels: missing enemy resource %s" % id)
			continue
		out.append(res)
	return out


static func _wave(enemy_id: StringName, start: float, end: float, batch: int,
		interval: float, end_scale: float = 0.7,
		formation: WaveData.Formation = WaveData.Formation.SCATTER,
		elite_chance: float = 0.0, one_shot: bool = false) -> WaveData:
	var wave := WaveData.new()
	wave.enemy_id = enemy_id
	wave.start_time = start
	wave.end_time = end
	wave.batch_size = batch
	wave.interval = interval
	wave.interval_end_scale = end_scale
	wave.formation = formation
	wave.elite_chance = elite_chance
	wave.one_shot = one_shot
	return wave


## Typed-array wrapper so the wave literals below stay compact.
static func _waves(list: Array) -> Array[WaveData]:
	var out: Array[WaveData] = []
	for wave in list:
		out.append(wave as WaveData)
	return out


# --- Sector 1 ---------------------------------------------------------------

static func _neon_ruins() -> LevelData:
	var level := LevelData.new()
	level.id = &"neon_ruins"
	level.display_name = "Neon Ruins"
	level.description = "A collapsed sign-district still drawing power. The floor arcs where the grid broke."
	level.order = 0
	level.unlock_time = 420.0
	level.mid_boss_time = 110.0
	level.mid_boss_interval = 145.0
	level.boss_time = 230.0
	level.boss_interval = 200.0
	level.endless_interval = 1.6
	level.endless_batch = 5
	level.difficulty_scale = 1.0
	level.health_growth_per_minute = 0.17
	level.damage_growth_per_minute = 0.07

	level.enemy_pool = _pool([&"nr_drone", &"nr_crawler", &"nr_spark", &"nr_turret", &"nr_hulk"])
	level.boss_id = &"nr_boss_warden"
	level.mid_boss_id = &"nr_mid_bulwark"

	level.hazard_type = LevelData.Hazard.ELECTRIC_FLOOR
	level.hazard_count = 8
	level.hazard_damage = 12.0
	level.hazard_radius = 130.0
	level.hazard_interval = 3.6
	level.hazard_start_time = 60.0

	level.bg_top = Color(0.05, 0.07, 0.14)
	level.bg_bottom = Color(0.02, 0.02, 0.06)
	level.grid_color = Color(0.22, 0.60, 0.85, 0.30)
	level.accent = Color(0.35, 0.90, 1.00)
	level.fog_color = Color(0.08, 0.18, 0.32, 0.22)
	level.background_style = 0

	level.unlocked_by_default = true
	level.reward_credits = 400
	level.reward_research = 6

	level.waves = _waves([
		_wave(&"nr_drone", 0.0, 180.0, 3, 1.8, 0.6),
		_wave(&"nr_crawler", 45.0, 300.0, 3, 2.2, 0.6, WaveData.Formation.ARC),
		_wave(&"nr_spark", 110.0, 420.0, 2, 3.2, 0.55, WaveData.Formation.STREAM),
		_wave(&"nr_drone", 150.0, 540.0, 5, 1.6, 0.5, WaveData.Formation.SCATTER, 0.02),
		_wave(&"nr_turret", 190.0, 540.0, 2, 5.0, 0.6, WaveData.Formation.SCATTER, 0.04),
		_wave(&"nr_crawler", 240.0, 600.0, 6, 2.0, 0.45, WaveData.Formation.RING, 0.05),
		_wave(&"nr_hulk", 300.0, 600.0, 1, 9.0, 0.5, WaveData.Formation.SCATTER, 0.12),
		_wave(&"nr_drone", 360.0, 600.0, 10, 2.4, 0.4, WaveData.Formation.RING, 0.03),
		_wave(&"nr_spark", 420.0, 600.0, 4, 2.6, 0.5, WaveData.Formation.BURST, 0.10),
		_wave(&"nr_hulk", 480.0, 480.0, 6, 1.0, 1.0, WaveData.Formation.RING, 0.25, true),
	])
	return level


# --- Sector 2 ---------------------------------------------------------------

static func _ash_wastes() -> LevelData:
	var level := LevelData.new()
	level.id = &"ash_wastes"
	level.display_name = "Ash Wastes"
	level.description = "Volcanic flats under permanent fallout. Vents open without warning."
	level.order = 1
	level.unlock_time = 480.0
	level.mid_boss_time = 120.0
	level.mid_boss_interval = 140.0
	level.boss_time = 240.0
	level.boss_interval = 195.0
	level.endless_interval = 1.5
	level.endless_batch = 6
	level.difficulty_scale = 1.22
	level.health_growth_per_minute = 0.19
	level.damage_growth_per_minute = 0.08

	level.enemy_pool = _pool([&"aw_scuttler", &"aw_hound", &"aw_spitter", &"aw_brood", &"aw_behemoth"])
	level.boss_id = &"aw_boss_ashbrand"
	level.mid_boss_id = &"aw_mid_maw"

	level.hazard_type = LevelData.Hazard.FIRE_VENT
	level.hazard_count = 10
	level.hazard_damage = 15.0
	level.hazard_radius = 120.0
	level.hazard_interval = 3.0
	level.hazard_start_time = 45.0

	level.bg_top = Color(0.14, 0.06, 0.04)
	level.bg_bottom = Color(0.04, 0.02, 0.02)
	level.grid_color = Color(0.55, 0.28, 0.15, 0.35)
	level.accent = Color(1.00, 0.52, 0.22)
	level.fog_color = Color(0.30, 0.14, 0.06, 0.25)
	level.background_style = 1

	level.required_level_id = &"neon_ruins"
	level.reward_credits = 700
	level.reward_research = 9

	level.waves = _waves([
		_wave(&"aw_scuttler", 0.0, 220.0, 4, 1.7, 0.55),
		_wave(&"aw_hound", 50.0, 360.0, 3, 2.6, 0.5, WaveData.Formation.STREAM),
		_wave(&"aw_spitter", 120.0, 480.0, 2, 4.2, 0.55, WaveData.Formation.ARC, 0.04),
		_wave(&"aw_scuttler", 160.0, 660.0, 7, 1.5, 0.42, WaveData.Formation.SCATTER, 0.03),
		_wave(&"aw_brood", 210.0, 660.0, 2, 5.5, 0.5, WaveData.Formation.SCATTER, 0.08),
		_wave(&"aw_hound", 280.0, 660.0, 5, 2.2, 0.45, WaveData.Formation.RING, 0.07),
		_wave(&"aw_behemoth", 330.0, 660.0, 1, 8.0, 0.5, WaveData.Formation.SCATTER, 0.14),
		_wave(&"aw_spitter", 400.0, 660.0, 4, 3.4, 0.5, WaveData.Formation.RING, 0.10),
		_wave(&"aw_brood", 470.0, 660.0, 4, 4.0, 0.45, WaveData.Formation.BURST, 0.12),
		_wave(&"aw_behemoth", 540.0, 540.0, 5, 1.0, 1.0, WaveData.Formation.RING, 0.3, true),
	])
	return level


# --- Sector 3 ---------------------------------------------------------------

static func _flooded_vault() -> LevelData:
	var level := LevelData.new()
	level.id = &"flooded_vault"
	level.display_name = "Flooded Vault"
	level.description = "A research vault two hundred metres under. Whatever was contained here is loose."
	level.order = 2
	level.unlock_time = 540.0
	level.mid_boss_time = 125.0
	level.mid_boss_interval = 135.0
	level.boss_time = 250.0
	level.boss_interval = 190.0
	level.endless_interval = 1.45
	level.endless_batch = 6
	level.difficulty_scale = 1.38
	level.health_growth_per_minute = 0.19
	level.damage_growth_per_minute = 0.09

	level.enemy_pool = _pool([&"fv_leech", &"fv_drifter", &"fv_lurker", &"fv_sporeling", &"fv_warden"])
	level.boss_id = &"fv_boss_sentinel"
	level.mid_boss_id = &"fv_mid_husk"

	level.hazard_type = LevelData.Hazard.SLOW_WATER
	level.hazard_count = 12
	level.hazard_damage = 9.0
	level.hazard_radius = 170.0
	level.hazard_interval = 2.6
	level.hazard_start_time = 45.0

	level.bg_top = Color(0.03, 0.09, 0.14)
	level.bg_bottom = Color(0.01, 0.03, 0.06)
	level.grid_color = Color(0.20, 0.60, 0.70, 0.32)
	level.accent = Color(0.35, 0.95, 0.85)
	level.fog_color = Color(0.05, 0.20, 0.26, 0.30)
	level.background_style = 2

	level.required_level_id = &"ash_wastes"
	level.reward_credits = 1100
	level.reward_research = 13

	level.waves = _waves([
		_wave(&"fv_leech", 0.0, 240.0, 5, 1.6, 0.5),
		_wave(&"fv_drifter", 40.0, 400.0, 4, 2.2, 0.48, WaveData.Formation.ARC),
		_wave(&"fv_lurker", 110.0, 520.0, 3, 3.4, 0.5, WaveData.Formation.RING, 0.05),
		_wave(&"fv_leech", 150.0, 720.0, 8, 1.4, 0.4, WaveData.Formation.SCATTER, 0.04),
		_wave(&"fv_sporeling", 200.0, 720.0, 2, 5.0, 0.5, WaveData.Formation.SCATTER, 0.09),
		_wave(&"fv_warden", 260.0, 720.0, 2, 4.6, 0.5, WaveData.Formation.ARC, 0.08),
		_wave(&"fv_drifter", 320.0, 720.0, 7, 1.9, 0.42, WaveData.Formation.RING, 0.07),
		_wave(&"fv_lurker", 400.0, 720.0, 5, 2.8, 0.45, WaveData.Formation.RING, 0.12),
		_wave(&"fv_sporeling", 480.0, 720.0, 4, 3.6, 0.45, WaveData.Formation.BURST, 0.15),
		_wave(&"fv_warden", 600.0, 600.0, 6, 1.0, 1.0, WaveData.Formation.RING, 0.35, true),
	])
	return level


# --- Sector 4 ---------------------------------------------------------------

static func _moonfall_ridge() -> LevelData:
	var level := LevelData.new()
	level.id = &"moonfall_ridge"
	level.display_name = "Moonfall Ridge"
	level.description = "Cliffs of alien glass where gravity forgets itself. The last place the light reached."
	level.order = 3
	level.unlock_time = 600.0
	level.mid_boss_time = 130.0
	level.mid_boss_interval = 130.0
	level.boss_time = 260.0
	level.boss_interval = 185.0
	level.endless_interval = 1.4
	level.endless_batch = 7
	level.difficulty_scale = 1.42
	level.health_growth_per_minute = 0.21
	level.damage_growth_per_minute = 0.10

	level.enemy_pool = _pool([&"mr_mote", &"mr_swarmling", &"mr_stalker", &"mr_seer", &"mr_colossus"])
	level.boss_id = &"mr_boss_parasite"
	level.mid_boss_id = &"mr_mid_grasper"

	level.hazard_type = LevelData.Hazard.GRAVITY_ANOMALY
	level.hazard_count = 12
	level.hazard_damage = 13.0
	level.hazard_radius = 160.0
	level.hazard_interval = 3.0
	level.hazard_start_time = 65.0

	level.bg_top = Color(0.07, 0.05, 0.14)
	level.bg_bottom = Color(0.02, 0.01, 0.05)
	level.grid_color = Color(0.45, 0.40, 0.70, 0.30)
	level.accent = Color(0.78, 0.55, 1.00)
	level.fog_color = Color(0.14, 0.08, 0.26, 0.28)
	level.background_style = 3

	level.required_level_id = &"flooded_vault"
	level.reward_credits = 1700
	level.reward_research = 18

	level.waves = _waves([
		_wave(&"mr_mote", 0.0, 260.0, 4, 1.9, 0.45),
		_wave(&"mr_swarmling", 45.0, 440.0, 4, 2.3, 0.42, WaveData.Formation.STREAM),
		_wave(&"mr_stalker", 120.0, 560.0, 3, 3.4, 0.48, WaveData.Formation.ARC, 0.06),
		_wave(&"mr_mote", 160.0, 780.0, 9, 1.3, 0.38, WaveData.Formation.SCATTER, 0.05),
		_wave(&"mr_seer", 220.0, 780.0, 2, 4.4, 0.5, WaveData.Formation.SCATTER, 0.09),
		_wave(&"mr_swarmling", 280.0, 780.0, 8, 1.7, 0.4, WaveData.Formation.RING, 0.08),
		_wave(&"mr_colossus", 340.0, 780.0, 1, 7.5, 0.5, WaveData.Formation.SCATTER, 0.16),
		_wave(&"mr_stalker", 420.0, 780.0, 6, 2.4, 0.42, WaveData.Formation.RING, 0.14),
		_wave(&"mr_seer", 500.0, 780.0, 4, 3.2, 0.45, WaveData.Formation.RING, 0.16),
		_wave(&"mr_colossus", 660.0, 660.0, 5, 1.0, 1.0, WaveData.Formation.RING, 0.4, true),
	])
	return level
