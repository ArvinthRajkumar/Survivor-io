extends PowerBase
## Drone — a gun drone orbits the player and sprays bullets in a ring.
##
## The ring is deliberately untargeted for most of the upgrade path: it is area
## denial, not aim. At max level the drone switches to tracking fire, which is
## the payoff that changes how the power plays rather than just its numbers.

const ORBIT_RADIUS := 96.0

var _drones: Array[Companion] = []


func _on_setup() -> void:
	_rebuild()


func _on_level_changed() -> void:
	_retune()


func _on_reached_max_level() -> void:
	# Rebuild so the switch to targeted fire reads as a visible upgrade moment.
	_rebuild()
	if EffectSpawner.instance != null and player != null:
		EffectSpawner.instance.spawn_death_burst(player.global_position, data.color_secondary, 90.0)
	AudioManager.play_sfx(&"evolve", 0.05, -6.0)


func _config_for(index: int, total: int) -> Dictionary:
	return {
		"mode": Companion.Mode.GUN,
		"target": player,
		"orbit_radius": ORBIT_RADIUS * (0.9 + 0.15 * get_area()),
		"orbit_speed": 1.5,
		"orbit_angle": TAU * float(index) / float(maxi(1, total)),
		"body_radius": 17.0,
		"color": data.color,
		"color2": data.color_secondary,
		"damage": get_damage(),
		"crit_chance": get_crit_chance(),
		"crit_damage": get_crit_damage(),
		"bullet_speed": get_speed(),
		"bullet_count": 5 + level,
		"fire_interval": get_cooldown(),
		"targeted": is_max_level(),
		"source_id": get_instance_id(),
	}


func _rebuild() -> void:
	_clear()
	var total := get_count()
	for i in total:
		var drone := ProjectileSystem.instance.spawn_companion(_config_for(i, total)) if ProjectileSystem.instance != null else null
		if drone != null:
			_drones.append(drone)


func _retune() -> void:
	_prune()
	var total := get_count()
	if _drones.size() != total:
		_rebuild()
		return
	for i in _drones.size():
		_drones[i].retune(_config_for(i, total))


func _prune() -> void:
	var i := _drones.size() - 1
	while i >= 0:
		var drone := _drones[i]
		if drone == null or not is_instance_valid(drone) or drone.target != player:
			_drones.remove_at(i)
		i -= 1


func _fire() -> void:
	# The drones fire on their own clocks; this tick only repairs the formation.
	_prune()
	if _drones.size() != get_count():
		_rebuild()


func _clear() -> void:
	for drone in _drones:
		if drone != null and is_instance_valid(drone):
			drone.expire()
	_drones.clear()


func _exit_tree() -> void:
	_clear()
