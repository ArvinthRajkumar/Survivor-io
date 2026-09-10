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
## reads as a combo rather than one animation looping. Levels widen the arc,
## lengthen the reach and add follow-up cuts; at max level the follow-up becomes
## a full spin that clears every side in one sweep (so it skips the separate
## back cut — a mirrored copy of a circle that already covers everything would
## just double its own damage for no new coverage).

const BASE_REACH := 122.0
const BASE_ARC := 2.05
## Seconds between the cuts of a multi-hit swing.
const FOLLOW_UP_DELAY := 0.13

var _handedness: float = 1.0
var _queued: int = 0
var _queue_timer: float = 0.0
var _queue_dir: Vector2 = Vector2.RIGHT


func get_reach() -> float:
	return BASE_REACH * get_area()


## Widens from a little over a quadrant to most of a half-circle; the max-level
## spin is handled separately in _swing().
func get_arc() -> float:
	return minf(PI * 0.95, BASE_ARC + 0.12 * float(level - 1))


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
	var dir := _swing_direction()
	_swing(dir, false)
	# The pressure pulse is tied to the cooldown, not to every individual cut,
	# so a levelled combo does not also multiply the AOE by its cut count.
	_aoe_pulse()
	# Extra cuts land as a follow-up rather than all at once, so a levelled
	# katana reads as a faster combo instead of a thicker single hit.
	_queued = maxi(0, get_count() - 1)
	_queue_timer = FOLLOW_UP_DELAY
	_queue_dir = dir


func _on_tick(delta: float) -> void:
	if _queued <= 0 or not firing or player == null or player.is_dead:
		return
	_queue_timer -= delta
	if _queue_timer > 0.0:
		return
	_queue_timer = FOLLOW_UP_DELAY
	_queued -= 1
	# Follow-ups track the direction the player has drifted into since the first
	# cut, which keeps a moving player's combo pointed where they are going.
	# Only the last cut of a maxed combo becomes the full spin, so the finisher
	# stays a finisher instead of the whole string turning into spins.
	_swing(_swing_direction().lerp(_queue_dir, 0.35).normalized(), _queued == 0)


## `finisher` marks the last cut of a combo; at max level that one becomes a
## full 360 spin instead of another directional sweep.
func _swing(dir: Vector2, finisher: bool) -> void:
	if player == null or ProjectileSystem.instance == null:
		return
	_handedness = -_handedness
	var spin := is_max_level() and finisher
	var arc := TAU if spin else get_arc()
	var reach := get_reach() * (1.12 if spin else 1.0)
	var base_cfg := {
		"position": player.global_position,
		"follow": player,
		"reach": reach,
		"sweep_time": 0.16 if spin else 0.10,
		"life": 0.30 if spin else 0.24,
		"crit_chance": get_crit_chance(),
		"crit_damage": get_crit_damage(),
		"knockback": get_knockback(),
		"color": data.color,
		"color2": data.color_secondary,
		"source_id": get_instance_id(),
	}
	if spin:
		# A spin already sweeps every side in one pass; a mirrored copy of a full
		# circle would just double its own damage without covering anything new.
		var cfg := base_cfg.duplicate()
		cfg["facing"] = dir.angle()
		cfg["arc"] = arc
		cfg["direction"] = _handedness
		cfg["damage"] = get_damage() * 1.25
		ProjectileSystem.instance.spawn_slash(cfg)
	else:
		var front := base_cfg.duplicate()
		front["facing"] = dir.angle()
		front["arc"] = arc
		front["direction"] = _handedness
		front["damage"] = get_damage()
		ProjectileSystem.instance.spawn_slash(front)
		# Mirrored back cut: same arc and reach, aimed the other way, swept in
		# the opposite hand so the two crescents read as one X-shaped pass
		# rather than a single blade teleporting.
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
		player.visual.call("play_slash", dir, _handedness, arc, spin)
	play_sound(&"shoot", -16.0 if not spin else -10.0)


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
		"damage": get_damage() * 0.5,
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
