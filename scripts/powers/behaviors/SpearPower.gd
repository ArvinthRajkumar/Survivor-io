extends PowerBase
## Spear — a thrust, not a swing.
##
## Reuses the katana's sweep entity with the arc cranked almost shut, which is
## what a thrust is: the same edge travelling, over a few degrees instead of a
## quadrant, at more than twice the reach. Levelling buys reach and damage; at
## max level the thrust becomes a double-tap, the second landing a beat after
## the first.

const BASE_REACH := 268.0
const ARC := 0.30

var _follow_up: float = -1.0


func get_reach() -> float:
	return BASE_REACH * get_area()


func _fire() -> void:
	_thrust()
	if is_max_level():
		_follow_up = 0.11


func _on_tick(delta: float) -> void:
	if _follow_up < 0.0:
		return
	_follow_up -= delta
	if _follow_up <= 0.0:
		_follow_up = -1.0
		_thrust()


func _thrust() -> void:
	if player == null or ProjectileSystem.instance == null:
		return
	var dir := player.move_dir.normalized() if player.is_moving() else player.facing
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT
	ProjectileSystem.instance.spawn_slash({
		"position": player.global_position,
		"follow": player,
		"facing": dir.angle(),
		"arc": ARC,
		"reach": get_reach(),
		# Quick and straight: a thrust that lingers reads as a beam.
		"sweep_time": 0.05,
		"life": 0.16,
		"direction": 1.0,
		"damage": get_damage(),
		"crit_chance": get_crit_chance(),
		"crit_damage": get_crit_damage(),
		"knockback": get_knockback(),
		"color": data.color,
		"color2": data.color_secondary,
		"source_id": get_instance_id(),
	})
	if player.visual != null:
		player.visual.call("play_slash", dir, 1.0, ARC, false)
	play_sound(&"shoot", -15.0)
