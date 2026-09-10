extends Node
## Owns everything that is true for the duration of a single run: the seeded RNG,
## the clock, XP/level, difficulty scaling and the end-of-run reward maths.
##
## Runs are endless. There is no timer to beat — the clock counts up, difficulty
## keeps climbing, and the run only ends when the player does. Sectors unlock by
## surviving past a threshold rather than by "winning".
##
## It deliberately knows nothing about nodes; the level scene reads from it and
## systems listen to its signals.

signal run_configured(hero: HeroData, level: LevelData)
signal run_started
signal run_finished(results: Dictionary)
signal time_changed(elapsed: float)
signal xp_changed(current: int, needed: int, level: int)
signal leveled_up(new_level: int)
signal kills_changed(kills: int)
signal difficulty_changed(tier: int)
signal threshold_reached(level_id: StringName)

const XP_BASE := 8
const XP_GROWTH := 1.21
const XP_LINEAR := 7
## Difficulty keeps compounding past the scripted content at this rate.
const ENDLESS_RAMP_PER_MINUTE := 0.055

var rng := RandomNumberGenerator.new()
var seed_value: int = 0

var hero: HeroData
var level_data: LevelData
var loadout := PowerLoadout.new()
var stats := PlayerStats.new()
var relics: Array[RelicData] = []

var elapsed: float = 0.0
var running: bool = false
var finished: bool = false

var player_level: int = 1
var xp_current: int = 0
var xp_needed: int = XP_BASE
var pending_level_ups: int = 0

var kills: int = 0
var elite_kills: int = 0
var boss_kills: int = 0
var damage_dealt: float = 0.0
var revives_used: int = 0
var difficulty_tier: int = 0
## True once the player has survived long enough to unlock the next sector.
var threshold_cleared: bool = false

var _last_whole_second: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)


func _process(delta: float) -> void:
	if not running or finished:
		return
	elapsed += delta
	var whole := int(elapsed)
	if whole == _last_whole_second:
		return
	_last_whole_second = whole
	time_changed.emit(elapsed)
	var tier := int(elapsed / 60.0)
	if tier != difficulty_tier:
		difficulty_tier = tier
		difficulty_changed.emit(tier)
	if not threshold_cleared and level_data != null and elapsed >= level_data.unlock_time:
		threshold_cleared = true
		_unlock_next_level()
		threshold_reached.emit(level_data.id)


# --- Lifecycle -------------------------------------------------------------

func configure(selected_hero: HeroData, selected_level: LevelData, run_seed: int = 0) -> void:
	hero = selected_hero
	level_data = selected_level
	var forced := DevTools.get_int_option("seed")
	if run_seed != 0:
		seed_value = run_seed
	elif forced != 0:
		seed_value = forced
	elif DevTools.smoke:
		# Fixed seed so the headless soak test is a comparable balance signal.
		seed_value = 20260907
	else:
		seed_value = int(Time.get_unix_time_from_system() * 1000.0) & 0x7FFFFFFF
	rng.seed = seed_value

	elapsed = 0.0
	running = false
	finished = false
	player_level = 1
	xp_current = 0
	xp_needed = XP_BASE
	pending_level_ups = 0
	kills = 0
	elite_kills = 0
	boss_kills = 0
	damage_dealt = 0.0
	revives_used = 0
	difficulty_tier = 0
	threshold_cleared = false
	_last_whole_second = -1

	loadout.clear()
	stats.reset()
	stats.apply_hero(hero)
	_apply_hero_rank()
	_apply_meta_upgrades()
	_apply_relics()
	if hero != null:
		# The starting Power takes the first of the six slots.
		loadout.add_or_level(hero.starting_power_id)
	run_configured.emit(hero, level_data)


## Permanent ranks bought for this specific hero on the roster screen.
func _apply_hero_rank() -> void:
	if hero == null:
		return
	var rank := SaveManager.get_hero_rank(hero.id)
	if rank <= 0:
		return
	stats.add_flat(&"max_health", hero.max_health * hero.rank_health_bonus * float(rank))
	stats.add_mult(&"damage_mult", hero.rank_damage_bonus * float(rank))


## Permanent upgrades bought in the meta screen.
##
## `--meta=N` overrides the profile with every lab upgrade at level N. It exists
## so a soak run can check that a progressed account holds up deeper into an
## endless run, and it never touches the saved profile.
func _apply_meta_upgrades() -> void:
	var meta: Dictionary = SaveManager.profile.get("meta_upgrades", {})
	var forced_level := DevTools.get_int_option("meta")
	if forced_level > 0:
		meta = {}
		for item in ContentDB.upgrade_list:
			if item.meta_only:
				meta[String(item.id)] = mini(forced_level, item.max_level)
	for key in meta.keys():
		var data := ContentDB.get_upgrade(StringName(key))
		if data == null:
			continue
		var level := int(meta[key])
		if level <= 0:
			continue
		if data.is_multiplier:
			stats.add_mult(data.stat_key, data.value_per_level * float(level))
		else:
			stats.add_flat(data.stat_key, data.value_per_level * float(level))


func _apply_relics() -> void:
	relics.clear()
	for id in SaveManager.get_equipped_relics():
		var relic := ContentDB.get_relic(StringName(id))
		if relic == null:
			continue
		relics.append(relic)
		stats.add_mult_dict(relic.stat_multipliers)
		stats.add_flat_dict(relic.stat_flats)
		stats.add_mult_dict(relic.stat_penalties, -1.0)


func has_relic_special(special: StringName) -> bool:
	for relic in relics:
		if relic.special == special:
			return true
	return false


func relic_special_value(special: StringName) -> float:
	var total := 0.0
	for relic in relics:
		if relic.special == special:
			total += relic.special_value
	return total


func start() -> void:
	running = true
	finished = false
	set_process(true)
	time_changed.emit(elapsed)
	xp_changed.emit(xp_current, xp_needed, player_level)
	kills_changed.emit(kills)
	run_started.emit()


func pause_clock() -> void:
	running = false


func resume_clock() -> void:
	if not finished:
		running = true


func finish() -> void:
	if finished:
		return
	finished = true
	running = false
	set_process(false)
	var results := build_results()
	SaveManager.record_run(level_data.id if level_data != null else &"unknown",
		elapsed, kills, threshold_cleared)
	SaveManager.add_currency(int(results["credits"]), int(results["research"]))
	SaveManager.clear_active_run()
	run_finished.emit(results)


func _unlock_next_level() -> void:
	if level_data == null:
		return
	for candidate in ContentDB.level_list:
		if candidate.required_level_id == level_data.id and not SaveManager.is_level_unlocked(candidate.id):
			SaveManager.unlock_level(candidate.id)


# --- XP and levelling ------------------------------------------------------

func xp_for_level(level: int) -> int:
	return int(round(float(XP_BASE) * pow(XP_GROWTH, float(level - 1)) + float(XP_LINEAR * (level - 1))))


func add_xp(amount: int) -> void:
	if finished or amount <= 0:
		return
	var gained := int(round(float(amount) * stats.get_stat(&"xp_gain_mult")))
	xp_current += maxi(1, gained)
	var leveled := false
	while xp_current >= xp_needed:
		xp_current -= xp_needed
		player_level += 1
		xp_needed = xp_for_level(player_level)
		pending_level_ups += 1
		leveled = true
	xp_changed.emit(xp_current, xp_needed, player_level)
	if leveled:
		leveled_up.emit(player_level)


func consume_level_up() -> bool:
	if pending_level_ups <= 0:
		return false
	pending_level_ups -= 1
	return true


func register_kill(is_elite: bool = false, is_boss: bool = false) -> void:
	kills += 1
	if is_elite:
		elite_kills += 1
	if is_boss:
		boss_kills += 1
	kills_changed.emit(kills)


func register_damage(amount: float) -> void:
	damage_dealt += amount


# --- Difficulty ------------------------------------------------------------
## Endless runs need curves that keep climbing without a ceiling, so the scripted
## per-minute growth is compounded by a second, slower term that only starts to
## matter after the first several minutes.

func _endless_factor() -> float:
	var minutes := elapsed / 60.0
	return 1.0 + ENDLESS_RAMP_PER_MINUTE * maxf(0.0, minutes - 6.0) * minutes * 0.25


func enemy_health_scale() -> float:
	if level_data == null:
		return 1.0
	var minutes := elapsed / 60.0
	var base := (1.0 + level_data.health_growth_per_minute * minutes) * level_data.difficulty_scale
	return base * _endless_factor()


func enemy_damage_scale() -> float:
	if level_data == null:
		return 1.0
	var minutes := elapsed / 60.0
	return (1.0 + level_data.damage_growth_per_minute * minutes) * sqrt(_endless_factor())


## Spawn pressure: how many enemies the director is allowed to keep alive.
func enemy_budget(quality: int) -> int:
	var budgets: PackedInt32Array = [110, 180, 260]
	var base: int = budgets[clampi(quality, 0, 2)]
	var minutes := elapsed / 60.0
	# Ramps to the nominal budget at nine minutes, then creeps toward 1.35x so a
	# long run keeps getting denser without ever becoming unrenderable.
	var ramp := clampf(0.28 + minutes * 0.08, 0.28, 1.0)
	if minutes > 9.0:
		ramp = 1.0 + minf(0.35, (minutes - 9.0) * 0.02)
	return int(float(base) * ramp)


## 0..1 progress toward unlocking the next sector, for the HUD marker.
func threshold_progress() -> float:
	if level_data == null or level_data.unlock_time <= 0.0:
		return 1.0
	return clampf(elapsed / level_data.unlock_time, 0.0, 1.0)


# --- Rewards ---------------------------------------------------------------

func build_results() -> Dictionary:
	var minutes := elapsed / 60.0
	var credits := int(kills) + int(minutes * 45.0)
	var research := int(minutes * 0.9) + elite_kills + boss_kills * 3
	var first_clear := false
	if threshold_cleared and level_data != null:
		credits = int(float(credits) * 1.4) + level_data.reward_credits
		research += level_data.reward_research
		first_clear = SaveManager.get_clear_count(level_data.id) == 0
		if first_clear:
			credits = int(float(credits) * 1.5)
	return {
		"time": elapsed,
		"kills": kills,
		"elite_kills": elite_kills,
		"boss_kills": boss_kills,
		"level": player_level,
		"damage": damage_dealt,
		"revives": revives_used,
		"credits": credits,
		"research": research,
		"hero": hero.display_name if hero != null else "",
		"level_name": level_data.display_name if level_data != null else "",
		"threshold_cleared": threshold_cleared,
		"threshold_time": level_data.unlock_time if level_data != null else 0.0,
		"first_clear": first_clear,
		"best_time": SaveManager.get_best_time(level_data.id) if level_data != null else 0.0,
	}


# --- Interrupted-run persistence -------------------------------------------
## The whole point of an endless run is that it can be long, so closing the app
## must not throw one away. Everything needed to rebuild a run is small enough to
## sit in the profile JSON.

func to_save_dictionary() -> Dictionary:
	return {
		"seed": seed_value,
		"hero": String(hero.id) if hero != null else "",
		"level": String(level_data.id) if level_data != null else "",
		"elapsed": elapsed,
		"player_level": player_level,
		"xp_current": xp_current,
		"xp_needed": xp_needed,
		"pending_level_ups": pending_level_ups,
		"kills": kills,
		"elite_kills": elite_kills,
		"boss_kills": boss_kills,
		"damage": damage_dealt,
		"revives_used": revives_used,
		"threshold_cleared": threshold_cleared,
		"loadout": loadout.to_dictionary(),
	}


## Rebuilds a run from a saved dictionary. Returns false when the save refers to
## content that no longer exists, in which case the caller should start fresh.
func restore(dict: Dictionary) -> bool:
	var saved_hero := ContentDB.get_hero(StringName(dict.get("hero", "")))
	var saved_level := ContentDB.get_level(StringName(dict.get("level", "")))
	if saved_hero == null or saved_level == null:
		return false

	configure(saved_hero, saved_level, int(dict.get("seed", 0)))
	elapsed = float(dict.get("elapsed", 0.0))
	player_level = maxi(1, int(dict.get("player_level", 1)))
	xp_current = int(dict.get("xp_current", 0))
	xp_needed = maxi(1, int(dict.get("xp_needed", XP_BASE)))
	pending_level_ups = int(dict.get("pending_level_ups", 0))
	kills = int(dict.get("kills", 0))
	elite_kills = int(dict.get("elite_kills", 0))
	boss_kills = int(dict.get("boss_kills", 0))
	damage_dealt = float(dict.get("damage", 0.0))
	revives_used = int(dict.get("revives_used", 0))
	threshold_cleared = bool(dict.get("threshold_cleared", false))
	difficulty_tier = int(elapsed / 60.0)
	_last_whole_second = int(elapsed)

	var saved_loadout: Variant = dict.get("loadout", {})
	if saved_loadout is Dictionary:
		loadout.from_dictionary(saved_loadout as Dictionary)
	return true
