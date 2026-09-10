extends PowerBase
## Flamethrower — a short cone of burning air along the direction of travel.
##
## Implemented as a run of overlapping patches thrown forward rather than one
## long zone, because a cone that is really a line of circles keeps damaging
## whatever walks into it after the burst has passed. That lingering ground is
## the weapon's whole identity: it is weak per tick and relentless.

const RANGE := 210.0
const PATCHES := 3


func _fire() -> void:
	if player == null:
		return
	var dir := player.move_dir.normalized() if player.is_moving() else player.facing
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT
	var reach := RANGE * get_area()
	for i in PATCHES:
		var t := float(i + 1) / float(PATCHES)
		spawn_zone({
			"position": player.global_position + dir * reach * t,
			# The cone widens with distance, so the far patch is the big one.
			"radius": (44.0 + 46.0 * t) * get_area(),
			"tick_interval": 0.22,
			"lifetime": get_duration() * (1.0 if is_max_level() else 0.75),
			"damage": get_damage(),
			"crit_chance": get_crit_chance(),
			"crit_damage": get_crit_damage(),
			"style": DamageZone.Style.FLAME,
			"color": data.color,
			"color2": data.color_secondary,
			"source_id": get_instance_id(),
		})
	play_sound(&"shoot", -18.0)
