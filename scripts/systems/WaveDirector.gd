class_name WaveDirector
extends Node
## Runs a level's wave script: which enemies appear, how fast, in what shape,
## and when each boss arrives.
##
## Waves overlap by design - each entry is active while the clock is inside its
## window, so pressure builds from several sources at once. Runs are endless, so
## once the scripted waves are exhausted the director keeps drawing from the
## level's enemy pool on a shortening interval, and bosses repeat forever.

signal boss_warning(title: String)
signal boss_spawned(boss: Boss)
signal boss_defeated

const BOSS_SCENE := preload("res://scenes/enemies/Boss.tscn")
const WARNING_LEAD := 3.0

var level: LevelData
var running: bool = false

var _wave_timers: PackedFloat32Array = PackedFloat32Array()
var _wave_fired: PackedByteArray = PackedByteArray()
var _boss_warned: bool = false
var _boss: Boss
var _next_boss_time: float = 0.0
var _next_mid_boss_time: float = 0.0
var _boss_round: int = 0
var _endless_timer: float = 0.0
var _script_end: float = 0.0


func setup(level_data: LevelData) -> void:
	level = level_data
	# Bosses live under the enemy director so they share its culling and queries.
	if EnemyDirector.instance != null:
		PoolManager.register(BOSS_SCENE, EnemyDirector.instance, 1)
	_wave_timers = PackedFloat32Array()
	_wave_fired = PackedByteArray()
	if level != null:
		_wave_timers.resize(level.waves.size())
		_wave_fired.resize(level.waves.size())
		for i in level.waves.size():
			_wave_timers[i] = 0.0
			_wave_fired[i] = 0
	_boss_warned = false
	_boss = null
	_boss_round = 0
	_endless_timer = 0.0
	_script_end = 0.0
	if level != null:
		_next_boss_time = level.boss_time
		_next_mid_boss_time = level.mid_boss_time
		for wave in level.waves:
			_script_end = maxf(_script_end, wave.end_time)
	# A restored run resumes mid-schedule, so fast-forward the boss clocks.
	_catch_up(RunManager.elapsed)


## Advances the boss schedule past any milestones already behind us, which is
## what makes resuming a saved run land in the right place.
func _catch_up(now: float) -> void:
	if level == null or now <= 0.0:
		return
	while _next_mid_boss_time > 0.0 and now > _next_mid_boss_time and level.mid_boss_interval > 0.0:
		_next_mid_boss_time += level.mid_boss_interval
	while _next_boss_time > 0.0 and now > _next_boss_time and level.boss_interval > 0.0:
		_next_boss_time += level.boss_interval
		_boss_round += 1
	for i in level.waves.size():
		if level.waves[i].one_shot and now > level.waves[i].start_time:
			_wave_fired[i] = 1


func start() -> void:
	running = true


func stop() -> void:
	running = false


func _process(delta: float) -> void:
	if not running or level == null or EnemyDirector.instance == null:
		return
	var now := RunManager.elapsed
	_tick_waves(delta, now)
	_tick_bosses(now)


func _tick_waves(delta: float, now: float) -> void:
	var budget := RunManager.enemy_budget(GameManager.quality)
	var live := EnemyDirector.instance.count()
	_tick_endless(delta, now, budget, live)
	for i in level.waves.size():
		var wave: WaveData = level.waves[i]
		if now < wave.start_time or now > wave.end_time:
			continue
		if wave.one_shot:
			if _wave_fired[i] == 0:
				_wave_fired[i] = 1
				_spawn_batch(wave)
			continue
		_wave_timers[i] -= delta
		if _wave_timers[i] > 0.0:
			continue
		# Ramp the spawn interval across the wave's window.
		var span := maxf(0.001, wave.end_time - wave.start_time)
		var t := clampf((now - wave.start_time) / span, 0.0, 1.0)
		_wave_timers[i] = maxf(0.12, wave.interval * lerpf(1.0, wave.interval_end_scale, t))
		if live >= budget:
			continue
		_spawn_batch(wave)
		live += wave.batch_size


## Past the end of the scripted waves the level keeps producing from its pool.
## The interval shortens with time so pressure keeps rising indefinitely.
func _tick_endless(delta: float, now: float, budget: int, live: int) -> void:
	if level.enemy_pool.is_empty() or now < _script_end * 0.75:
		return
	_endless_timer -= delta
	if _endless_timer > 0.0:
		return
	var minutes := now / 60.0
	_endless_timer = maxf(0.35, level.endless_interval * pow(0.94, maxf(0.0, minutes - 4.0)))
	if live >= budget:
		return
	var batch := level.endless_batch + int(minutes * 0.5)
	var base_angle := RunManager.rng.randf() * TAU
	for i in batch:
		var data: EnemyData = level.enemy_pool[RunManager.rng.randi() % level.enemy_pool.size()]
		var elite := RunManager.rng.randf() < level.endless_elite_chance + minutes * 0.004
		EnemyDirector.instance.spawn_offscreen(data, elite,
			base_angle + TAU * float(i) / float(maxi(1, batch)))


func _spawn_batch(wave: WaveData) -> void:
	var data := ContentDB.get_enemy(wave.enemy_id)
	if data == null:
		return
	var director := EnemyDirector.instance
	var base_angle := RunManager.rng.randf() * TAU
	for i in wave.batch_size:
		var elite := RunManager.rng.randf() < wave.elite_chance
		match wave.formation:
			WaveData.Formation.RING:
				director.spawn_offscreen(data, elite, TAU * float(i) / float(wave.batch_size))
			WaveData.Formation.ARC:
				director.spawn_offscreen(data, elite, base_angle + (float(i) - float(wave.batch_size) * 0.5) * 0.26)
			WaveData.Formation.STREAM:
				director.spawn_offscreen(data, elite, base_angle + RunManager.rng.randf_range(-0.16, 0.16))
			WaveData.Formation.BURST:
				# Spread rather than stacked: a burst that shares one exact bearing
				# arrives as a single blob and reads as one big enemy.
				director.spawn_offscreen(data, elite, base_angle + RunManager.rng.randf_range(-0.42, 0.42))
			_:
				director.spawn_offscreen(data, elite)


## Bosses repeat for as long as the run lasts, each round tougher than the last.
func _tick_bosses(now: float) -> void:
	if _next_mid_boss_time > 0.0 and now >= _next_mid_boss_time:
		_next_mid_boss_time = now + maxf(30.0, level.mid_boss_interval)
		_spawn_boss(level.mid_boss_id, 0.55 * _round_power())

	if _next_boss_time > 0.0 and not _boss_warned and now >= _next_boss_time - WARNING_LEAD:
		_boss_warned = true
		var boss_data := ContentDB.get_enemy(level.boss_id)
		AudioManager.play_sfx(&"boss_warning")
		AudioManager.play_music(&"boss")
		boss_warning.emit(boss_data.boss_title if boss_data != null else "WARNING")

	if _next_boss_time > 0.0 and now >= _next_boss_time:
		_next_boss_time = now + maxf(60.0, level.boss_interval)
		_boss_warned = false
		_spawn_boss(level.boss_id, _round_power())
		_boss_round += 1


## Each boss round is meaningfully stronger, which is what keeps an endless run
## from flattening out once your build comes online.
func _round_power() -> float:
	return 1.0 + 0.55 * float(_boss_round)


func _spawn_boss(boss_id: StringName, power: float) -> void:
	var data := ContentDB.get_enemy(boss_id)
	if data == null or Player.instance == null:
		return
	var boss := PoolManager.acquire(BOSS_SCENE) as Boss
	if boss == null:
		return
	var offset := MathUtil.random_point_on_circle(RunManager.rng, 700.0)
	boss.global_position = Player.instance.global_position + offset
	boss.configure(data, false, RunManager.enemy_health_scale() * power, RunManager.enemy_damage_scale())
	if not boss.died.is_connected(EnemyDirector.instance._on_enemy_died):
		boss.died.connect(EnemyDirector.instance._on_enemy_died)
	if not boss.boss_defeated.is_connected(_on_boss_defeated):
		boss.boss_defeated.connect(_on_boss_defeated)
	EnemyDirector.instance.active.append(boss)
	_boss = boss
	boss_spawned.emit(boss)


func _on_boss_defeated() -> void:
	_boss = null
	AudioManager.play_music(&"battle")
	boss_defeated.emit()


func get_boss() -> Boss:
	return _boss if _boss != null and is_instance_valid(_boss) else null
