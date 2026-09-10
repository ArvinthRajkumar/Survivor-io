extends PowerBase
## Katana — the weapon every operative carries in, and the only one the player
## aims with their feet.
##
## Every other Power picks its own targets. This one does not: it cuts along the
## direction you are moving, so repositioning is aiming. Standing still keeps the
## last heading, which means a player who backs off a crowd and stops still has
## their edge pointed at it.
##
## Swings alternate handedness (down-swing, then back-swing) so a held direction
## reads as a combo rather than one animation looping. Levels widen the arc,
## lengthen the reach and add follow-up cuts; at max level the follow-up becomes
## a full spin that clears every side at once.

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
	var cfg := {
		"position": player.global_position,
		"follow": player,
		"facing": dir.angle(),
		"arc": arc,
		"reach": reach,
		"direction": _handedness,
		"sweep_time": 0.16 if spin else 0.10,
		"life": 0.30 if spin else 0.24,
		"damage": get_damage() * (1.25 if spin else 1.0),
		"crit_chance": get_crit_chance(),
		"crit_damage": get_crit_damage(),
		"knockback": get_knockback(),
		"color": data.color,
		"color2": data.color_secondary,
		"source_id": get_instance_id(),
	}
	ProjectileSystem.instance.spawn_slash(cfg)
	# The character animation is driven from here so the blade in the operative's
	# hands is always in step with the cut that actually deals the damage.
	if player.visual != null:
		player.visual.call("play_slash", dir, _handedness, arc, spin)
	play_sound(&"shoot", -16.0 if not spin else -10.0)
