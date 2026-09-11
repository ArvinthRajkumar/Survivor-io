extends Area2D
## Fired by shooter-type enemies. It is passive: the player's hurtbox finds it
## and calls consume(), which keeps enemy bullets off the physics query budget.
##
## Drawn deliberately loud. An enemy bullet is the one thing on screen the player
## has to see and react to, and it competes with a hundred creatures, the
## operative's own effects and a lit floor. It used to be an 11px triangle with a
## soft glow, which disappeared completely in a crowd. It is now bigger than its
## own hitbox, carries a white-hot core and a dark contour so it survives both
## bright and dark backgrounds, and drags a trail so its heading is readable
## before it arrives.
##
## The hitbox is unchanged, so the bullet reads as slightly larger than it
## actually is - which errs in the player's favour.

const LIFETIME := 4.0
const BODY := 17.0
const TRAIL_STEPS := 6
## Distance between recorded trail points. Sampled by distance rather than by
## frame so the trail is the same length however fast the bullet travels.
const TRAIL_GAP := 13.0

var damage: float = 7.0

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 260.0
var _color: Color = Palette.DANGER
var _age: float = 0.0
var _alive: bool = false
var _trail: PackedVector2Array = PackedVector2Array()
var _last_mark: Vector2 = Vector2.ZERO


func _ready() -> void:
	collision_layer = Layers.ENEMY_ATTACK
	collision_mask = 0
	set_deferred("monitoring", false)
	set_deferred("monitorable", true)
	add_to_group(&"enemy_projectiles")
	z_index = 5


func pool_reset() -> void:
	_age = 0.0
	_alive = true
	_trail.clear()
	set_deferred("monitorable", true)


func pool_sleep() -> void:
	_alive = false
	set_deferred("monitorable", false)


func launch(dir: Vector2, speed: float, dmg: float, color: Color) -> void:
	_direction = dir.normalized()
	_speed = speed
	damage = dmg
	_color = color
	_age = 0.0
	_alive = true
	_trail.clear()
	_last_mark = global_position
	rotation = _direction.angle()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	_age += delta
	if _age >= LIFETIME:
		consume()
		return
	global_position += _direction * _speed * delta
	if global_position.distance_squared_to(_last_mark) >= TRAIL_GAP * TRAIL_GAP:
		_last_mark = global_position
		_trail.append(global_position)
		if _trail.size() > TRAIL_STEPS:
			_trail.remove_at(0)
	queue_redraw()


## Removes the bullet after it has been resolved by the player's hurtbox.
func consume() -> void:
	if not _alive:
		return
	_alive = false
	PoolManager.release(self)


func _draw() -> void:
	# Trail first, in local space: the node rotates with its heading, so the
	# recorded world points have to come back through the transform.
	if _trail.size() >= 2:
		var inv := global_transform.affine_inverse()
		for i in _trail.size() - 1:
			var a := inv * _trail[i]
			var b := inv * _trail[i + 1]
			var t := float(i + 1) / float(_trail.size())
			draw_line(a, b, Color(_color.r, _color.g, _color.b, 0.30 * t),
				BODY * 0.55 * t, true)

	# Halo, then a dark contour, then the body. The contour is what keeps the
	# bullet visible when it crosses something bright - a glow alone vanishes
	# against fire or a laser.
	Draw2D.glow_circle(self, Vector2.ZERO, BODY * 0.80, _color, 2)
	var head := Draw2D.polygon_points(3, BODY, 0.0)
	var contour := PackedVector2Array()
	for p in head:
		contour.append(p * 1.30)
	draw_colored_polygon(contour, Color(0.05, 0.02, 0.06, 0.85))
	Draw2D.neon_polygon(self, head,
		Color(_color.r * 0.45, _color.g * 0.20, _color.b * 0.30), _color, 3.0)
	# White-hot core, pulsing so the eye catches it among static scenery.
	var beat := 0.80 + 0.20 * sin(_age * 26.0)
	draw_circle(Vector2(BODY * 0.10, 0.0), BODY * 0.30 * beat, Color(1, 1, 1, 0.95))
