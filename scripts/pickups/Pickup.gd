class_name Pickup
extends Area2D
## Non-XP drops: health, a magnet pulse, a screen-clearing bomb and boss chests.
##
## Movement and collection run in _process, not _physics_process: collecting a
## bomb kills everything on screen, which spawns a burst of pooled effects, and
## pools cannot grow from inside a physics callback.

enum Kind { HEALTH, MAGNET, BOMB, CHEST, CREDITS }

const COLLECT_DISTANCE := 30.0
const LIFETIME := 30.0

var kind: int = Kind.HEALTH
var _target: Node2D
var _speed: float = 200.0
var _age: float = 0.0
var _alive: bool = false


func _ready() -> void:
	collision_layer = Layers.PICKUP
	collision_mask = 0
	set_deferred("monitoring", false)
	set_deferred("monitorable", true)
	add_to_group(&"pickups")


func pool_reset() -> void:
	_target = null
	_speed = 200.0
	_age = 0.0
	_alive = true
	set_deferred("monitorable", true)


func pool_sleep() -> void:
	_alive = false
	set_deferred("monitorable", false)


func setup(pickup_kind: int) -> void:
	kind = pickup_kind
	queue_redraw()


func attract_to(target: Node2D) -> void:
	_target = target


func _process(delta: float) -> void:
	if not _alive:
		return
	_age += delta
	queue_redraw()
	if _age > LIFETIME:
		PoolManager.release(self)
		return
	if _target == null or not is_instance_valid(_target):
		return
	_speed = minf(1400.0, _speed + 1600.0 * delta)
	var to_target := _target.global_position - global_position
	if to_target.length() <= COLLECT_DISTANCE:
		_collect()
		return
	global_position += to_target.normalized() * _speed * delta


func _collect() -> void:
	if not _alive:
		return
	_alive = false
	var player := Player.instance
	match kind:
		Kind.HEALTH:
			if player != null:
				player.heal(player.health.max_health * 0.25)
		Kind.MAGNET:
			_magnet_pulse()
		Kind.BOMB:
			if EnemyDirector.instance != null:
				EnemyDirector.instance.kill_all_on_screen(9999.0)
			if EffectSpawner.instance != null and player != null:
				EffectSpawner.instance.spawn_explosion(player.global_position, Palette.ACCENT_WARM, 600.0)
		Kind.CHEST:
			_open_chest()
		Kind.CREDITS:
			RunManager.add_xp(25)
		_:
			pass
	AudioManager.play_sfx(&"pickup", 0.1, -6.0)
	PoolManager.release(self)


## Pulls in every loose shard on the field.
func _magnet_pulse() -> void:
	var player := Player.instance
	if player == null:
		return
	for node in get_tree().get_nodes_in_group(&"pickups"):
		if node == self:
			continue
		if node.has_method("attract_to"):
			node.call("attract_to", player)


## Boss reward: an immediate burst of levels worth of XP.
func _open_chest() -> void:
	RunManager.add_xp(RunManager.xp_needed * 2 + 40)


func _draw() -> void:
	var pulse := 1.0 + 0.08 * sin(_age * 5.0)
	match kind:
		Kind.HEALTH:
			_draw_cross(Palette.HEALTH, 18.0 * pulse)
		Kind.MAGNET:
			_draw_magnet(Palette.XP, 18.0 * pulse)
		Kind.BOMB:
			_draw_bomb(Palette.DANGER, 20.0 * pulse)
		Kind.CHEST:
			_draw_chest(Palette.GOLD, 24.0 * pulse)
		_:
			Draw2D.neon_polygon(self, Draw2D.polygon_points(6, 16.0 * pulse, 0.0),
				Palette.BG_PANEL_SOLID, Palette.GOLD, 2.5)


func _draw_cross(color: Color, size: float) -> void:
	Draw2D.glow_circle(self, Vector2.ZERO, size, color, 2)
	var arm := size * 0.34
	draw_rect(Rect2(Vector2(-arm, -size * 0.9), Vector2(arm * 2.0, size * 1.8)), color)
	draw_rect(Rect2(Vector2(-size * 0.9, -arm), Vector2(size * 1.8, arm * 2.0)), color)


func _draw_magnet(color: Color, size: float) -> void:
	Draw2D.glow_circle(self, Vector2.ZERO, size, color, 2)
	draw_arc(Vector2.ZERO, size * 0.75, PI * 0.15, PI * 0.85, 20, color, 7.0, true)
	draw_line(Vector2(-size * 0.72, 0.0), Vector2(-size * 0.72, size * 0.7), color, 7.0)
	draw_line(Vector2(size * 0.72, 0.0), Vector2(size * 0.72, size * 0.7), color, 7.0)


func _draw_bomb(color: Color, size: float) -> void:
	Draw2D.glow_circle(self, Vector2.ZERO, size, color, 3)
	Draw2D.neon_polygon(self, Draw2D.star_points(8, size, size * 0.45, _age * 1.5),
		Color(0.25, 0.02, 0.06), color, 2.5)


func _draw_chest(color: Color, size: float) -> void:
	Draw2D.glow_circle(self, Vector2.ZERO, size, color, 3)
	Draw2D.neon_polygon(self, Draw2D.polygon_points(6, size, 0.0),
		Color(0.22, 0.16, 0.02), color, 3.0)
	draw_circle(Vector2.ZERO, size * 0.25, Color(1, 1, 1, 0.9))
