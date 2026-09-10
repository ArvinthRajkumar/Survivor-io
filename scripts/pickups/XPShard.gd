class_name XPShard
extends Area2D
## Experience dropped by enemies. Idle shards do nothing until the player's
## magnet area touches them, at which point they accelerate in - so a field of
## hundreds of shards costs almost nothing.

const COLLECT_DISTANCE := 26.0
## Uncollected shards eventually fade, which bounds memory on long runs.
const LIFETIME := 75.0
## Shards inside this multiple of the magnet radius start drifting in on their
## own. The Area2D magnet gives a crisp snap; this soft pull is what stops a
## ranged build from leaving most of its own XP on the floor. Kept close to 1x
## now that the base pickup radius is itself tight (a shard should not start
## flying across half the screen just because the player exists somewhere on
## it) — a dedicated magnet passive is what is supposed to widen this.
const SOFT_PULL_SCALE := 1.5
const SCAN_INTERVAL := 0.3

var value: int = 1
var _target: Node2D
var _speed: float = 120.0
var _age: float = 0.0
var _alive: bool = false
var _tier: int = 0
var _scan_timer: float = 0.0


func _ready() -> void:
	collision_layer = Layers.PICKUP
	collision_mask = 0
	set_deferred("monitoring", false)
	set_deferred("monitorable", true)
	add_to_group(&"pickups")
	set_process(false)


func pool_reset() -> void:
	_target = null
	_speed = 120.0
	_age = 0.0
	_alive = true
	_scan_timer = RunManager.rng.randf() * SCAN_INTERVAL
	set_process(true)
	set_deferred("monitorable", true)


func pool_sleep() -> void:
	_alive = false
	set_process(false)
	set_deferred("monitorable", false)


func setup(xp_value: int) -> void:
	value = maxi(1, xp_value)
	_tier = 0 if value < 5 else (1 if value < 15 else 2)
	queue_redraw()


func attract_to(target: Node2D) -> void:
	if not _alive or _target != null:
		return
	_target = target
	_speed = 260.0
	set_process(true)


func _process(delta: float) -> void:
	if not _alive:
		return
	_age += delta
	if _target == null or not is_instance_valid(_target):
		if _age > LIFETIME:
			PoolManager.release(self)
			return
		_scan_timer -= delta
		if _scan_timer <= 0.0:
			_scan_timer = SCAN_INTERVAL
			_check_soft_pull()
		return
	_speed = minf(1500.0, _speed + 1900.0 * delta)
	var to_target := _target.global_position - global_position
	if to_target.length() <= COLLECT_DISTANCE:
		_collect()
		return
	global_position += to_target.normalized() * _speed * delta


## Staggered by a random offset at spawn so hundreds of shards never scan on the
## same frame.
func _check_soft_pull() -> void:
	var player := Player.instance
	if player == null or not is_instance_valid(player) or player.is_dead:
		return
	var reach := player.get_pickup_radius() * SOFT_PULL_SCALE
	if global_position.distance_squared_to(player.global_position) <= reach * reach:
		attract_to(player)


func _collect() -> void:
	if not _alive:
		return
	_alive = false
	RunManager.add_xp(value)
	AudioManager.play_sfx(&"pickup", 0.25, -20.0)
	PoolManager.release(self)


func _draw() -> void:
	var color := Palette.XP
	var size := 8.0
	match _tier:
		1:
			color = Color(0.55, 0.95, 0.85)
			size = 11.0
		2:
			color = Color(1.0, 0.80, 0.35)
			size = 14.0
		_:
			pass
	Draw2D.glow_circle(self, Vector2.ZERO, size, color, 2)
	Draw2D.neon_polygon(self, Draw2D.polygon_points(4, size, 0.0),
		Color(color.r * 0.4, color.g * 0.5, color.b * 0.7, 0.95), color, 2.0)
