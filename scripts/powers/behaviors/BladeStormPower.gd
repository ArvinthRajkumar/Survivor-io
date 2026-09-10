extends PowerBase
## A ring of cuts sweeping around the operative.
##
## Four blades launched a beat apart, each sweeping a quarter of the circle from
## where the last one finished, so the effect is one continuous edge travelling
## all the way round rather than four crescents appearing at once. At max level
## it makes a second pass the other way.

const BLADES := 4
const STEP := 0.055

var _queued: int = 0
var _queue_timer: float = 0.0
var _spin: float = 1.0
var _start_angle: float = 0.0


func _fire() -> void:
	_start_angle = RunManager.rng.randf() * TAU
	_spin = 1.0
	_queued = BLADES * (2 if is_max_level() else 1)
	_queue_timer = 0.0


func _on_tick(delta: float) -> void:
	if _queued <= 0 or player == null:
		return
	_queue_timer -= delta
	if _queue_timer > 0.0:
		return
	_queue_timer = STEP
	var index := _queued - 1
	# The second pass runs the other way round, which is what stops a mastered
	# blade storm from looking like the same animation played twice.
	if is_max_level() and index < BLADES:
		_spin = -1.0
	var arc := TAU / float(BLADES)
	var centre := _start_angle + _spin * arc * float(index % BLADES)
	ProjectileSystem.instance.spawn_slash({
		"position": player.global_position,
		"follow": player,
		"facing": centre,
		"arc": arc * 1.12,
		"reach": 156.0 * get_area(),
		"sweep_time": 0.07,
		"life": 0.20,
		"direction": _spin,
		"damage": get_damage(),
		"crit_chance": get_crit_chance(),
		"crit_damage": get_crit_damage(),
		"knockback": get_knockback(),
		"color": data.color,
		"color2": data.color_secondary,
		"source_id": get_instance_id(),
	})
	_queued -= 1
	if _queued == 0:
		play_sound(&"shoot", -14.0)
