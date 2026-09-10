extends PowerBase
## Longbow — one arrow that goes through the whole line and hits harder the
## farther it has flown.
##
## Every other ranged weapon in the game is best in a crowd at close range. This
## one inverts that: the arrow is at its weakest leaving the bow and reaches full
## strength around the far edge of the screen, so the bow rewards the player who
## keeps distance rather than the one who wades in.

const FALLOFF_START := 90.0
const FALLOFF_END := 620.0
## Multiplier at point blank; it climbs to 1.0 by FALLOFF_END.
const NEAR_MULT := 0.55


func _fire() -> void:
	if player == null:
		return
	var aim := aim_direction(player.facing if player.facing.length_squared() > 0.01 else Vector2.RIGHT)
	var count := get_count()
	for i in count:
		var dir := aim
		if count > 1:
			dir = aim.rotated((float(i) / float(count - 1) - 0.5) * 0.22)
		var cfg := base_config()
		cfg["position"] = player.global_position
		cfg["direction"] = dir
		cfg["shape"] = 8
		# Pierce is what makes it a line weapon; without it the arrow is just a
		# slow bullet.
		cfg["pierce"] = data.pierce + level
		cfg["ramp_from"] = FALLOFF_START
		cfg["ramp_to"] = FALLOFF_END
		cfg["ramp_near_mult"] = NEAR_MULT
		spawn_projectile(cfg)
	play_sound(&"shoot", -13.0)
