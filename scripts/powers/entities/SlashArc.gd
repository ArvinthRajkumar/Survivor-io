class_name SlashArc
extends Node2D
## One katana sweep.
##
## The arc is not a hitbox that lingers: it is a moving edge. A cursor travels
## from one end of the swept angle to the other over `sweep_time`, and an enemy
## is hit at the instant the edge passes over it. That is what makes the slash
## feel like a cut rather than a cone of damage — enemies on the far side of the
## swing are struck a fraction of a second after the ones nearest the start, so
## a crowd folds over in sequence.
##
## The visual is a crescent that widens, brightens and fades in ~0.22s, drawn by
## PowerArt.draw_slash so the icon, the blade in the player's hands and the cut
## itself all share one look.

const TRAIL_STEPS := 4

## The cut travels with the operative. A sweep pinned to the spot it was
## launched from visibly detaches from the character within a couple of frames
## at full sprint, and the damage stops matching what the player can see.
var follow: Node2D
var facing: float = 0.0          ## centre angle of the sweep
var arc: float = 2.1             ## total swept angle in radians
var reach: float = 150.0
var sweep_time: float = 0.11     ## how long the edge takes to travel the arc
var life: float = 0.24
var direction: float = 1.0       ## +1 sweeps anticlockwise, -1 clockwise
var color: Color = Color(0.75, 0.90, 1.0)
var color_secondary: Color = Color.WHITE

var damage: float = 20.0
var crit_chance: float = 0.05
var crit_damage: float = 1.6
var knockback: float = 180.0
var source_id: int = 0

var _age: float = 0.0
var _cursor: float = 0.0
var _alive: bool = false
var _hit: Dictionary = {}
var _sparks: Array[Vector2] = []


func _ready() -> void:
	add_to_group(&"slashes")
	z_index = 14


func pool_reset() -> void:
	_age = 0.0
	_cursor = 0.0
	_alive = true
	_hit.clear()
	_sparks.clear()
	modulate = Color.WHITE


func pool_sleep() -> void:
	_alive = false
	follow = null
	_hit.clear()
	_sparks.clear()


func configure(cfg: Dictionary) -> void:
	follow = cfg.get("follow", null) as Node2D
	facing = float(cfg.get("facing", 0.0))
	arc = float(cfg.get("arc", 2.1))
	reach = float(cfg.get("reach", 150.0))
	sweep_time = maxf(0.02, float(cfg.get("sweep_time", 0.11)))
	life = maxf(sweep_time + 0.06, float(cfg.get("life", 0.24)))
	direction = 1.0 if float(cfg.get("direction", 1.0)) >= 0.0 else -1.0
	color = cfg.get("color", color)
	color_secondary = cfg.get("color2", color_secondary)
	damage = float(cfg.get("damage", 20.0))
	crit_chance = float(cfg.get("crit_chance", 0.05))
	crit_damage = float(cfg.get("crit_damage", 1.6))
	knockback = float(cfg.get("knockback", 180.0))
	source_id = int(cfg.get("source_id", get_instance_id()))
	_age = 0.0
	_cursor = 0.0
	_hit.clear()
	_sparks.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if not _alive:
		return
	if follow != null and is_instance_valid(follow):
		global_position = follow.global_position
	_age += delta
	var previous := _cursor
	_cursor = clampf(_age / sweep_time, 0.0, 1.0)
	if previous < 1.0:
		_cut(previous, _cursor)
	if _age >= life:
		expire()
		return
	queue_redraw()


## Damages everything the edge crossed between two points of the sweep.
func _cut(from_t: float, to_t: float) -> void:
	if EnemyDirector.instance == null:
		return
	var start := facing - direction * arc * 0.5
	var from_angle := start + direction * arc * from_t
	var to_angle := start + direction * arc * to_t
	var reach_sq := reach * reach
	for enemy in EnemyDirector.instance.get_in_radius(global_position, reach + 24.0, 32):
		var key := enemy.get_instance_id()
		if _hit.has(key):
			continue
		var offset := enemy.global_position - global_position
		# Enemies are discs, so allow the cut to land slightly short of centre.
		if offset.length_squared() > reach_sq + enemy.radius * enemy.radius:
			continue
		var angle := offset.angle()
		if not _angle_crossed(from_angle, to_angle, angle, enemy.radius / maxf(1.0, offset.length())):
			continue
		_hit[key] = true
		var is_crit := RunManager.rng.randf() < crit_chance
		var amount := damage * (crit_damage if is_crit else 1.0)
		var push := offset.normalized() * knockback
		if enemy.apply_hit(amount, is_crit, push, source_id, 0.0):
			_sparks.append(to_local(enemy.global_position))
			if EffectSpawner.instance != null:
				EffectSpawner.instance.spawn_hit_spark(enemy.global_position, color_secondary)


## True when `angle` lies in the wedge the edge swept this frame, widened by the
## enemy's own angular size so small targets are never skipped between frames.
func _angle_crossed(from_angle: float, to_angle: float, angle: float, slack: float) -> bool:
	var pad := clampf(slack, 0.0, 0.6) + 0.05
	var lo := minf(from_angle, to_angle) - pad
	var span := absf(to_angle - from_angle) + pad * 2.0
	if span >= TAU:
		return true
	# Measured as a positive walk from the low edge, so it wraps correctly.
	return fposmod(angle - lo, TAU) <= span


func expire() -> void:
	if not _alive:
		return
	_alive = false
	PoolManager.release(self)


func _draw() -> void:
	if not _alive:
		return
	var t := clampf(_age / life, 0.0, 1.0)
	# Ghosted repeats behind the leading crescent give the swing its weight.
	for i in TRAIL_STEPS:
		var lag := float(i) * 0.055
		var lt := clampf(t + lag, 0.0, 1.0)
		if lt >= 1.0:
			continue
		var swept := clampf((_age - lag) / sweep_time, 0.0, 1.0)
		if swept <= 0.0:
			continue
		var centre := facing - direction * arc * 0.5 + direction * arc * swept * 0.5
		PowerArt.draw_slash(self, Vector2.ZERO, reach, arc * swept, centre, lt,
			color, color_secondary)

	# Impact sparks left where the edge actually connected.
	var spark_fade := 1.0 - t
	for p in _sparks:
		draw_circle(p, 5.0 * spark_fade + 1.0, Color(1, 1, 1, 0.7 * spark_fade))
		draw_circle(p, 11.0 * spark_fade, Color(color_secondary.r, color_secondary.g,
			color_secondary.b, 0.25 * spark_fade))
