extends PowerBase
## A deployed emplacement that shoots on its own.
##
## Unlike the drone, it does not travel with the operative: it is planted where
## the player was standing and holds that spot until its timer runs out. That
## makes it the one power whose value depends on where the player chooses to
## fight rather than on what they are carrying.

func _fire() -> void:
	if player == null or ProjectileSystem.instance == null:
		return
	ProjectileSystem.instance.spawn_companion({
		"position": player.global_position,
		"mode": Companion.Mode.GUN,
		# No orbit target: a turret with nothing to orbit stays put.
		"target": null,
		"orbit_radius": 0.0,
		"orbit_speed": 0.0,
		"body_radius": 20.0 * get_area(),
		"damage": get_damage(),
		"crit_chance": get_crit_chance(),
		"crit_damage": get_crit_damage(),
		"bullet_speed": get_speed(),
		"bullet_count": get_count() + 2,
		"fire_interval": maxf(0.18, data.hit_interval),
		# A turret that sprays radially is a decoration; one that aims is cover.
		"targeted": true,
		"lifetime": get_duration(),
		"color": data.color,
		"color2": data.color_secondary,
		"source_id": get_instance_id(),
	})
	play_sound(&"shoot", -16.0)
