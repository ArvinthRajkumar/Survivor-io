extends PowerBase
## Proximity charges dropped in the player's wake.
##
## The only weapon in the game that rewards running away: mines are laid behind
## the operative, so a player being chased is laying a trail through the crowd
## following them. They arm after a moment — dropping a live blast at your own
## feet would just be a nova with extra steps.

const ARM_TIME := 0.45
const TRAIL_BACK := 46.0


func _fire() -> void:
	if player == null:
		return
	var behind := -player.facing
	if player.is_moving():
		behind = -player.move_dir.normalized()
	if behind.length_squared() < 0.01:
		behind = Vector2.DOWN
	for i in get_count():
		# Fanned out behind rather than stacked, so a line of them covers a
		# doorway instead of one very loud point.
		var spread := behind.rotated((float(i) - float(get_count() - 1) * 0.5) * 0.5)
		_drop(player.global_position + spread * TRAIL_BACK)
	play_sound(&"shoot", -20.0)


func _drop(at: Vector2) -> void:
	var blast := 118.0 * get_area()
	var mine := spawn_zone({
		"position": at,
		"radius": blast * 0.24,
		# Harmless while it arms: a long interval means the first tick lands
		# after the charge has settled.
		"tick_interval": ARM_TIME,
		"lifetime": ARM_TIME + 0.34,
		"damage": get_damage(),
		"crit_chance": get_crit_chance(),
		"crit_damage": get_crit_damage(),
		"knockback": get_knockback(),
		"style": DamageZone.Style.BEACON,
		"growth": blast,
		"color": data.color,
		"color2": data.color_secondary,
		"source_id": get_instance_id(),
	})
	if mine == null:
		return
