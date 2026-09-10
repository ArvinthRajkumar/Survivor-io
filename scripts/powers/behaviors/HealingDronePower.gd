extends PowerBase
## Healing Drone — a support drone that drops healing circles near the player.
##
## The circle lands nearby rather than on top of you, so topping up is a small
## decision about where to stand rather than a free trickle of health.

const ORBIT_RADIUS := 78.0

var _drone: Companion


func _on_setup() -> void:
	_ensure_drone()


func _on_level_changed() -> void:
	_ensure_drone()


func _drone_config() -> Dictionary:
	return {
		"mode": Companion.Mode.HEAL,
		"target": player,
		"orbit_radius": ORBIT_RADIUS,
		"orbit_speed": -1.1,
		"orbit_angle": PI,
		"body_radius": 16.0,
		"color": data.color,
		"color2": data.color_secondary,
		"fire_interval": get_cooldown(),
		"heal_amount": get_damage(),
		"heal_radius": 90.0 * get_area(),
		"heal_duration": get_duration(),
		"drop_range": 190.0,
		"source_id": get_instance_id(),
	}


func _ensure_drone() -> void:
	if _drone != null and is_instance_valid(_drone) and _drone.target == player:
		_drone.retune(_drone_config())
		return
	if ProjectileSystem.instance != null:
		_drone = ProjectileSystem.instance.spawn_companion(_drone_config())


func _fire() -> void:
	# The drone drops on its own clock; this only repairs a lost companion.
	_ensure_drone()


func _exit_tree() -> void:
	if _drone != null and is_instance_valid(_drone):
		_drone.expire()
		_drone = null
