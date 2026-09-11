extends PowerBase
## Flamethrower — a jet of burning air sweeping out in front of the operative.
##
## The jet is one cone zone pinned to the player and aimed along `weapon_aim`,
## which turns at a limited rate: a continuous weapon that changed direction in
## a single frame read as the flame teleporting rather than sweeping, and was
## the main reason nobody could tell what the weapon was.
##
## Behind the jet it leaves burning ground. That lingering fire is the weapon's
## identity - it is weak per tick and relentless - but it used to be *all* there
## was, three detached circles thrown forward, which is why the weapon was
## unrecognisable without reading the card.

const RANGE := 250.0
## Narrow enough that the jet is longer than it is wide - a cone as wide as it
## is long reads as a puff of smoke, not a jet - and wide enough to still feel
## like a spray rather than a beam.
const CONE_ARC := 0.56
## Fire is dropped every few shots, not every one: a patch per shot at this
## cadence carpets the whole arena and the jet stops reading against it.
const PATCH_EVERY := 3

var _shots: int = 0


func _fire() -> void:
	if player == null:
		return
	var dir := player.weapon_aim
	if dir.length_squared() < 0.01:
		dir = player.facing if player.facing.length_squared() > 0.01 else Vector2.RIGHT
	var reach := RANGE * get_area()

	# The jet. Short-lived and re-spawned on every shot, so it tracks the sweep
	# of the aim instead of hanging in the air where it was fired.
	spawn_zone({
		"position": player.global_position,
		"follow": player,
		"radius": reach,
		"cone_facing": dir.angle(),
		"cone_arc": CONE_ARC,
		"tick_interval": data.hit_interval,
		"lifetime": maxf(0.16, get_cooldown() * 1.15),
		"damage": get_damage(),
		"crit_chance": get_crit_chance(),
		"crit_damage": get_crit_damage(),
		"style": DamageZone.Style.FLAME_JET,
		"color": data.color,
		"color2": data.color_secondary,
		"source_id": get_instance_id(),
	})

	_shots += 1
	if _shots % PATCH_EVERY == 0:
		_drop_fire(player.global_position + dir * reach * 0.72, reach)

	if player.visual != null:
		player.visual.call("play_attack", PlayerVisual.Pose.SPRAY, dir, 1.0, 2.0, false)
	play_sound(&"shoot", -18.0)


## Ground left burning where the jet has been playing.
func _drop_fire(at: Vector2, reach: float) -> void:
	spawn_zone({
		"position": at,
		"radius": reach * 0.30,
		"tick_interval": 0.30,
		"lifetime": get_duration() * (1.0 if is_max_level() else 0.7),
		# Weaker than the jet: standing in the wake should hurt, but the weapon
		# is meant to reward keeping the flame on a target.
		"damage": get_damage() * 0.6,
		"crit_chance": get_crit_chance(),
		"crit_damage": get_crit_damage(),
		"style": DamageZone.Style.FIRE_PATCH,
		"color": data.color,
		"color2": data.color_secondary,
		"source_id": get_instance_id(),
	})
