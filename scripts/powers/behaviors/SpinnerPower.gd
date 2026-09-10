extends PowerBase
## Spinners — saw blades that orbit the player.
##
## Below max level the whole set shares one duty cycle: they cut for a few
## seconds, retract into the player, then swing back out. At max level the cycle
## is dropped and they spin without stopping.

const ORBIT_RADIUS := 132.0

var _blades: Array[SawBlade] = []
var _cycle: float = 0.0
var _cycle_active: bool = true


func _on_setup() -> void:
	_rebuild()


func _on_level_changed() -> void:
	_retune()


func _on_reached_max_level() -> void:
	_cycle = 0.0
	_cycle_active = true
	_rebuild()
	if EffectSpawner.instance != null and player != null:
		EffectSpawner.instance.spawn_death_burst(player.global_position, data.color_secondary, 110.0)
	AudioManager.play_sfx(&"evolve", 0.05, -6.0)


## Rest shrinks and the cutting window grows as the power levels up.
func active_window() -> float:
	return 2.6 + 0.7 * float(level)


func rest_window() -> float:
	return maxf(0.6, 2.6 - 0.45 * float(level))


func _config(index: int, total: int) -> Dictionary:
	return {
		"target": player,
		"orbit_radius": ORBIT_RADIUS * (0.85 + 0.15 * get_area()),
		"orbit_speed": 2.1 + 0.12 * float(level),
		"orbit_angle": TAU * float(index) / float(maxi(1, total)),
		"blade_radius": 25.0 * get_area(),
		"color": data.color,
		"color2": data.color_secondary,
		"damage": get_damage(),
		"crit_chance": get_crit_chance(),
		"crit_damage": get_crit_damage(),
		"knockback": get_knockback(),
		"hit_interval": data.hit_interval,
		"active_time": active_window(),
		"rest_time": rest_window(),
		"continuous": is_max_level(),
		"source_id": get_instance_id(),
	}


func _rebuild() -> void:
	_clear()
	var total := get_count()
	for i in total:
		var blade := ProjectileSystem.instance.spawn_saw(_config(i, total)) if ProjectileSystem.instance != null else null
		if blade != null:
			blade.sync_cycle(_cycle, _cycle_active)
			_blades.append(blade)


func _retune() -> void:
	_prune()
	if _blades.size() != get_count():
		_rebuild()
		return
	for i in _blades.size():
		_blades[i].retune(_config(i, _blades.size()))


func _prune() -> void:
	var i := _blades.size() - 1
	while i >= 0:
		var blade := _blades[i]
		if blade == null or not is_instance_valid(blade) or blade.target != player:
			_blades.remove_at(i)
		i -= 1


## The power owns the shared clock so every blade retracts and returns together.
func _on_tick(delta: float) -> void:
	if is_max_level():
		return
	_cycle += delta
	var window := active_window() if _cycle_active else rest_window()
	if _cycle >= window:
		_cycle = 0.0
		_cycle_active = not _cycle_active
		for blade in _blades:
			if blade != null and is_instance_valid(blade):
				blade.sync_cycle(0.0, _cycle_active)
		if _cycle_active:
			play_sound(&"shoot", -20.0)


func _fire() -> void:
	_prune()
	if _blades.size() != get_count():
		_rebuild()


func _clear() -> void:
	for blade in _blades:
		if blade != null and is_instance_valid(blade):
			blade.expire()
	_blades.clear()


func _exit_tree() -> void:
	_clear()
