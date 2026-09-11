extends PowerBase
## Katana — the weapon every operative carries in, and the only one the player
## aims with their feet.
##
## Every other Power picks its own targets. This one does not: it cuts along the
## direction you are moving, so repositioning is aiming. Standing still keeps the
## last heading, which means a player who backs off a crowd and stops still has
## their edge pointed at it.
##
## Every swing is really three attacks at once, so nothing standing next to the
## player is ever actually safe:
##  * a front cut in the direction of travel;
##  * a mirrored back cut, so a crowd that has wrapped around the player is not
##    a blind spot;
##  * a lighter full-circle pressure pulse layered on top, once per cooldown,
##    which is the "not just the line attack" case — an enemy standing still
##    beside the player between swings still takes chip damage from it.
##
## Swings alternate handedness (down-swing, then back-swing) so a held direction
## reads as a combo rather than one animation looping.
##
## Levelling buys reach, arc and damage — never swing rate and never extra cuts.
## Making the base weapon fire faster made every level-up feel like the same
## upgrade and left the blade permanently short; a cooldown passive is where
## "swing faster" belongs.

const BASE_REACH := 138.0
## Deliberately narrow. A wide sweep covers more ground but stops reading as a
## cut - it looks like the character is spinning a disc. A quadrant-ish arc
## travelled quickly is what a sword swing looks like.
const BASE_ARC := 1.35

var _handedness: float = 1.0


func get_reach() -> float:
	return BASE_REACH * get_area()


## Widens a little with level, but never past a bit over a half-circle: past
## that the cut loses its direction and the weapon stops being something the
## player aims with their feet.
func get_arc() -> float:
	return minf(PI * 0.62, BASE_ARC + 0.10 * float(level - 1))


func _on_reached_max_level() -> void:
	if EffectSpawner.instance != null and player != null:
		EffectSpawner.instance.spawn_death_burst(player.global_position,
			data.color_secondary, get_reach())
	AudioManager.play_sfx(&"evolve", 0.05, -6.0)


## The heading the player is travelling in, falling back to the last one held.
func _swing_direction() -> Vector2:
	if player == null:
		return Vector2.RIGHT
	if player.is_moving():
		return player.move_dir.normalized()
	if player.facing.length_squared() > 0.01:
		return player.facing
	return Vector2.RIGHT


func _fire() -> void:
	_swing(_swing_direction())
	_aoe_pulse()


func _swing(dir: Vector2) -> void:
	if player == null or ProjectileSystem.instance == null:
		return
	_handedness = -_handedness
	var arc := get_arc()
	var reach := get_reach()
	var base_cfg := {
		"position": player.global_position,
		"follow": player,
		"reach": reach,
		"sweep_time": 0.065,
		"life": 0.20,
		"crit_chance": get_crit_chance(),
		"crit_damage": get_crit_damage(),
		"knockback": get_knockback(),
		"color": data.color,
		"color2": data.color_secondary,
		"source_id": get_instance_id(),
	}
	var front := base_cfg.duplicate()
	front["facing"] = dir.angle()
	front["arc"] = arc
	front["direction"] = _handedness
	front["damage"] = get_damage()
	ProjectileSystem.instance.spawn_slash(front)
	# Mirrored back cut: same arc and reach, aimed the other way, swept in the
	# opposite hand so the two crescents read as one X-shaped pass rather than a
	# single blade teleporting.
	var back := base_cfg.duplicate()
	back["facing"] = dir.angle() + PI
	back["arc"] = arc
	back["direction"] = -_handedness
	back["damage"] = get_damage()
	ProjectileSystem.instance.spawn_slash(back)
	# The character animation is driven from here so the blade in the operative's
	# hands is always in step with the front cut — the one visible attack that
	# actually has an arm behind it.
	if player.visual != null:
		player.visual.call("play_attack", PlayerVisual.Pose.SWING, dir, _handedness, arc, false)
	play_sound(&"shoot", -16.0)


## The full-circle pressure pulse layered under the directional cuts. Weaker
## than a direct hit — it is meant to catch anything standing still next to the
## player between swings, not to replace aiming the cut itself.
func _aoe_pulse() -> void:
	if player == null or ProjectileSystem.instance == null:
		return
	var cfg := {
		"position": player.global_position,
		"follow": player,
		"facing": 0.0,
		"arc": TAU,
		"reach": get_reach() * 0.85,
		"direction": 1.0,
		"sweep_time": 0.15,
		"life": 0.26,
		# Half strength until the blade is mastered, then full — the one thing
		# max level changes, and it is still power rather than rate.
		"damage": get_damage() * (1.0 if is_max_level() else 0.5),
		"crit_chance": get_crit_chance(),
		"crit_damage": get_crit_damage(),
		"knockback": get_knockback() * 0.6,
		# Swapped palette from the directional cuts, so the ring reads as its
		# own distinct effect rather than a third copy of the same crescent.
		"color": data.color_secondary,
		"color2": data.color,
		"source_id": get_instance_id(),
	}
	ProjectileSystem.instance.spawn_slash(cfg)
