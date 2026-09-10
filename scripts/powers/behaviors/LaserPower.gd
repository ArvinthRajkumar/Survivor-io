extends PowerBase
## Laser — orbital strikes called down in a pattern around the player.
##
## The pattern rotates through ring, line and spiral so a volley reads as
## deliberate rather than random, and each strike is offset by a small delay so
## the beams walk across the ground instead of landing all at once.

enum Pattern { RING, LINE, SPIRAL }

const STRIKE_STAGGER := 0.09

var _pattern: int = Pattern.RING


func _on_setup() -> void:
	_pattern = Pattern.RING


func _fire() -> void:
	if ProjectileSystem.instance == null or player == null:
		return
	var count := get_count()
	var spread := 210.0 * get_area()
	var origin := player.global_position
	var base_angle := RunManager.rng.randf() * TAU

	for i in count:
		var offset := Vector2.ZERO
		match _pattern:
			Pattern.LINE:
				# A walking line through the player, aimed at the nearest threat.
				var dir := aim_direction()
				var t := (float(i) - float(count - 1) * 0.5) / maxf(1.0, float(count - 1))
				offset = dir * t * spread * 1.6
			Pattern.SPIRAL:
				var a := base_angle + float(i) * 0.9
				offset = Vector2(cos(a), sin(a)) * spread * (0.35 + 0.65 * float(i) / float(count))
			_:
				var a := base_angle + TAU * float(i) / float(count)
				offset = Vector2(cos(a), sin(a)) * spread
		ProjectileSystem.instance.spawn_laser({
			"position": origin + offset,
			"radius": 74.0 * get_area(),
			"damage": get_damage(),
			"crit_chance": get_crit_chance(),
			"crit_damage": get_crit_damage(),
			"knockback": get_knockback(),
			"color": data.color,
			"color2": data.color_secondary,
			"delay": float(i) * STRIKE_STAGGER,
			"source_id": get_instance_id(),
		})

	_pattern = (_pattern + 1) % 3
	play_sound(&"ultimate", -16.0)
