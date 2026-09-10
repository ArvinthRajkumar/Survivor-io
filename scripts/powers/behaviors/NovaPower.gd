extends PowerBase
## Radial pulses centred on the player, or on the crowd.
##
## Frost Nova, Sun Flare and Thorn Aura are all this: a circle that appears,
## does its damage and goes. What separates them is where it lands, how long it
## stays and what it leaves behind — all of which are data, so they share a
## script.
##
## `aim` picks the placement: DENSEST drops it on the thickest part of the
## crowd (which is what makes Sun Flare feel aimed), anything else centres it on
## the player, and a duration long enough to matter makes it follow.
const CROWD_RANGE := 620.0


func _fire() -> void:
	if player == null:
		return
	var radius := 132.0 * get_area()
	var lifetime := get_duration()
	# A pulse that outlives its own animation is an aura and should travel with
	# the player; a short one is an impact and stays where it landed.
	var sticky := lifetime >= 1.2
	spawn_zone({
		"position": _centre(),
		"follow": player if sticky and data.aim != PowerData.Aim.DENSEST else null,
		"radius": radius,
		"tick_interval": data.hit_interval if sticky else 0.5,
		"lifetime": maxf(0.30, lifetime),
		"damage": get_damage(),
		"crit_chance": get_crit_chance(),
		"crit_damage": get_crit_damage(),
		"knockback": get_knockback(),
		"slow_factor": data.effect_value,
		"slow_duration": data.effect_value if data.effect_value >= 1.0 else get_duration(),
		"style": data.projectile_shape,
		"growth": 0.0 if sticky else radius * 1.25,
		"color": data.color,
		"color2": data.color_secondary,
		"source_id": get_instance_id(),
	})
	play_sound(&"shoot", -16.0)


func _centre() -> Vector2:
	if data.aim != PowerData.Aim.DENSEST or EnemyDirector.instance == null:
		return player.global_position
	var near := EnemyDirector.instance.get_in_radius(player.global_position, CROWD_RANGE, 24)
	if near.is_empty():
		return player.global_position
	var sum := Vector2.ZERO
	for enemy in near:
		sum += enemy.global_position
	return sum / float(near.size())
