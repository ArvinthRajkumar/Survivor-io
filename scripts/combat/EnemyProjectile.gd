extends Area2D
## Fired by shooter-type enemies. It is passive: the player's hurtbox finds it
## and calls consume(), which keeps enemy bullets off the physics query budget.

const LIFETIME := 4.0

var damage: float = 7.0

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 260.0
var _color: Color = Palette.DANGER
var _age: float = 0.0
var _alive: bool = false


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


## Removes the bullet after it has been resolved by the player's hurtbox.
func consume() -> void:
	if not _alive:
		return
	_alive = false
	PoolManager.release(self)


func _draw() -> void:
	Draw2D.glow_circle(self, Vector2.ZERO, 9.0, _color, 2)
	Draw2D.neon_polygon(self, Draw2D.polygon_points(3, 11.0, 0.0),
		Color(_color.r * 0.4, _color.g * 0.2, _color.b * 0.3), _color, 2.0)
