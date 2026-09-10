extends PowerBase
## A well that drags everything inward while it burns them.
##
## The pull is the point: on its own the damage is unremarkable, but a crowd
## packed into one spot is a crowd every other weapon in the loadout can hit at
## once. It is dropped on the thickest part of the field rather than on the
## player, because a well centred on the operative would pull the swarm onto
## them.

const CROWD_RANGE := 640.0
const DROP_MIN := 190.0


func _fire() -> void:
	if player == null:
		return
	spawn_zone({
		"position": _drop_point(),
		"radius": 168.0 * get_area(),
		"tick_interval": data.hit_interval,
		"lifetime": get_duration(),
		"damage": get_damage(),
		"crit_chance": get_crit_chance(),
		"crit_damage": get_crit_damage(),
		# Negative knockback would fight the pull; the well does its holding
		# with pull_force alone.
		"knockback": 0.0,
		"pull_force": 240.0 + 40.0 * float(level),
		"slow_factor": 0.7,
		"slow_duration": 0.5,
		"style": DamageZone.Style.RIFT,
		"color": data.color,
		"color2": data.color_secondary,
		"source_id": get_instance_id(),
	})
	play_sound(&"shoot", -15.0)


## The middle of the nearby crowd, pushed far enough away that the well never
## opens under the player's own feet.
func _drop_point() -> Vector2:
	var here := player.global_position
	if EnemyDirector.instance == null:
		return here + player.facing * DROP_MIN
	var near := EnemyDirector.instance.get_in_radius(here, CROWD_RANGE, 24)
	if near.is_empty():
		return here + player.facing * DROP_MIN
	var sum := Vector2.ZERO
	for enemy in near:
		sum += enemy.global_position
	var centre: Vector2 = sum / float(near.size())
	var offset := centre - here
	if offset.length() < DROP_MIN:
		offset = (offset.normalized() if offset.length_squared() > 0.01 else player.facing) * DROP_MIN
	return here + offset
