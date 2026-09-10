extends PowerBase
## War Hammer — one slow, enormous overhead smash at the player's feet.
##
## The trade is stated in the numbers rather than in a special rule: the longest
## cooldown of any weapon, and in exchange a hit that lands on everything within
## reach, throws it outward and leaves it staggered. At max level the impact
## sends out a second, wider shockwave.

const STAGGER := 0.45


func _fire() -> void:
	if player == null:
		return
	var radius := 150.0 * get_area()
	_smash(radius, get_damage(), get_knockback())
	if is_max_level():
		# The aftershock is weaker but reaches half again as far, so a mastered
		# hammer clears a ring the swing itself never touched.
		_smash(radius * 1.55, get_damage() * 0.45, get_knockback() * 0.7)
	if EffectSpawner.instance != null:
		EffectSpawner.instance.spawn_death_burst(player.global_position, data.color_secondary, radius)
	GameManager.request_shake(0.35)
	play_sound(&"shoot", -8.0)


func _smash(radius: float, damage: float, knockback: float) -> void:
	spawn_zone({
		"position": player.global_position,
		"radius": radius,
		# One tick, then gone: this is an impact, not a puddle.
		"tick_interval": 0.5,
		"lifetime": 0.34,
		"damage": damage,
		"crit_chance": get_crit_chance(),
		"crit_damage": get_crit_damage(),
		"knockback": knockback,
		"slow_factor": 0.45,
		"slow_duration": STAGGER,
		"style": DamageZone.Style.SHOCK,
		"growth": radius * 1.1,
		"color": data.color,
		"color2": data.color_secondary,
		"source_id": get_instance_id(),
	})
