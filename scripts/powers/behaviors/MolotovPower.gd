extends PowerBase
## Molotov Cocktail — bottles lobbed around the player that leave burning ground.
##
## Two bottles at level 1, six at max. They land in a rough ring rather than at
## random so the burning patches tend to form a usable perimeter instead of
## clumping on one side.


func _fire() -> void:
	if ProjectileSystem.instance == null or player == null:
		return
	var count := get_count()
	var base_angle := RunManager.rng.randf() * TAU
	var spread := 190.0 * get_area()
	for i in count:
		var angle := base_angle + TAU * float(i) / float(count) + RunManager.rng.randf_range(-0.2, 0.2)
		var distance := spread * RunManager.rng.randf_range(0.55, 1.0)
		var land := player.global_position + Vector2(cos(angle), sin(angle)) * distance
		ProjectileSystem.instance.spawn_bottle({
			"from": player.global_position,
			"to": land,
			"flight_time": clampf(distance / 420.0, 0.25, 0.8),
			"arc_height": 90.0 + distance * 0.25,
			"bottle_radius": 14.0,
			"color": data.color,
			"color2": data.color_secondary,
			"fire_damage": get_damage(),
			"fire_radius": 96.0 * get_area(),
			"fire_duration": get_duration(),
			"tick_interval": maxf(0.25, data.hit_interval),
			"crit_chance": get_crit_chance(),
			"crit_damage": get_crit_damage(),
			"source_id": get_instance_id(),
		})
	play_sound(&"shoot_spread", -14.0)
