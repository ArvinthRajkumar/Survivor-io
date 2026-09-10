extends PowerBase
## Domain — a force field pinned to the player that grinds down anything inside.
##
## One long-lived zone is kept alive and re-tuned rather than respawned each
## cooldown, so the field never flickers. The cooldown instead drives a pulse
## that shoves enemies back off the boundary.

const BASE_RADIUS := 150.0

var _field: DamageZone
var _pulse_scale: float = 0.0


func _on_setup() -> void:
	_ensure_field()


func _on_level_changed() -> void:
	_ensure_field()


func _on_reached_max_level() -> void:
	if EffectSpawner.instance != null and player != null:
		EffectSpawner.instance.spawn_explosion(player.global_position, data.color, radius())


func radius() -> float:
	return BASE_RADIUS * get_area()


func _field_config() -> Dictionary:
	return {
		"position": player.global_position,
		"damage": get_damage(),
		"tick_interval": maxf(0.22, get_cooldown() * 0.5),
		"radius": radius(),
		"lifetime": 0.0,
		"color": data.color,
		"color2": data.color_secondary,
		"style": DamageZone.Style.DOMAIN,
		"follow": player,
		"knockback": get_knockback() * 0.25,
		"source_id": get_instance_id(),
		"crit_chance": get_crit_chance(),
		"crit_damage": get_crit_damage(),
		"max_targets": 60,
	}


func _ensure_field() -> void:
	if _field != null and is_instance_valid(_field):
		_field.configure(_field_config())
		return
	_field = spawn_zone(_field_config())


func _fire() -> void:
	if _field == null or not is_instance_valid(_field):
		_ensure_field()
		return
	_field.set_radius(radius())
	# Boundary pulse: a short outward shove plus a ring of sparks.
	damage_area(player.global_position, radius(), get_damage() * 0.6, get_knockback(), 60)
	if EffectSpawner.instance != null:
		for i in 6:
			var a := TAU * float(i) / 6.0 + RunManager.rng.randf()
			EffectSpawner.instance.spawn_hit_spark(
				player.global_position + Vector2(cos(a), sin(a)) * radius(), data.color_secondary)
	play_sound(&"shoot_spread", -16.0)


func _exit_tree() -> void:
	if _field != null and is_instance_valid(_field):
		_field.expire()
		_field = null
