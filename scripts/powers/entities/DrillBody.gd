class_name DrillBody
extends Node2D
## A drill that ricochets around the play area, boring through whatever it meets.
##
## It bounces inside a rectangle anchored to the player rather than to the world,
## so drills never wander off screen no matter how far the player travels.

const BOUNCE_SQUASH := 0.22

var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var drill_radius: float = 22.0
var color: Color = Palette.ACCENT
var color_secondary: Color = Color.WHITE

var damage: float = 14.0
var crit_chance: float = 0.05
var crit_damage: float = 1.6
var knockback: float = 140.0
var hit_interval: float = 0.4
var source_id: int = 0
var half_extents: Vector2 = Vector2(470.0, 860.0)

var _phase: float = 0.0
var _sweep: float = 0.0
var _squash: float = 0.0
var _alive: bool = false


func _ready() -> void:
	add_to_group(&"drills")
	z_index = 11


func pool_reset() -> void:
	_phase = 0.0
	_sweep = 0.0
	_squash = 0.0
	_alive = true
	scale = Vector2.ONE


func pool_sleep() -> void:
	_alive = false


func configure(cfg: Dictionary) -> void:
	direction = (cfg.get("direction", Vector2.RIGHT) as Vector2).normalized()
	speed = float(cfg.get("speed", 300.0))
	drill_radius = float(cfg.get("drill_radius", 22.0))
	color = cfg.get("color", Palette.ACCENT)
	color_secondary = cfg.get("color2", Color.WHITE)
	damage = float(cfg.get("damage", 14.0))
	crit_chance = float(cfg.get("crit_chance", 0.05))
	crit_damage = float(cfg.get("crit_damage", 1.6))
	knockback = float(cfg.get("knockback", 140.0))
	hit_interval = float(cfg.get("hit_interval", 0.4))
	source_id = int(cfg.get("source_id", get_instance_id()))
	half_extents = cfg.get("half_extents", Vector2(470.0, 860.0))
	queue_redraw()


func retune(cfg: Dictionary) -> void:
	var keep_dir := direction
	configure(cfg)
	direction = keep_dir


func _process(delta: float) -> void:
	if not _alive:
		return
	var player := Player.instance
	if player == null or not is_instance_valid(player):
		expire()
		return
	_phase += delta
	_squash = maxf(0.0, _squash - delta * 4.0)
	global_position += direction * speed * delta
	rotation = direction.angle() + PI * 0.5

	_bounce(player.global_position)

	_sweep -= delta
	if _sweep <= 0.0:
		_sweep = 0.08
		_bore()
	queue_redraw()


func _bounce(anchor: Vector2) -> void:
	var local := global_position - anchor
	var bounced := false
	if absf(local.x) > half_extents.x:
		direction.x = -direction.x
		global_position.x = anchor.x + signf(local.x) * half_extents.x
		bounced = true
	if absf(local.y) > half_extents.y:
		direction.y = -direction.y
		global_position.y = anchor.y + signf(local.y) * half_extents.y
		bounced = true
	if bounced:
		_squash = 1.0
		if EffectSpawner.instance != null:
			EffectSpawner.instance.spawn_hit_spark(global_position, color_secondary)


func _bore() -> void:
	if EnemyDirector.instance == null:
		return
	for enemy in EnemyDirector.instance.get_in_radius(global_position, drill_radius + 8.0, 8):
		var is_crit := RunManager.rng.randf() < crit_chance
		var amount := damage * (crit_damage if is_crit else 1.0)
		var push := direction * knockback
		if enemy.apply_hit(amount, is_crit, push, source_id, hit_interval):
			if EffectSpawner.instance != null:
				EffectSpawner.instance.spawn_hit_spark(enemy.global_position, color)


func expire() -> void:
	if not _alive:
		return
	_alive = false
	PoolManager.release(self)


func _draw() -> void:
	if not _alive:
		return
	# Squash-and-stretch on impact sells the ricochet.
	var stretch := 1.0 + BOUNCE_SQUASH * _squash
	var squash := 1.0 - BOUNCE_SQUASH * 0.6 * _squash
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(squash, stretch))

	# Sparks streaming off the tip.
	for i in 3:
		var t := fposmod(_phase * 3.0 + float(i) / 3.0, 1.0)
		var p := Vector2(sin(_phase * 9.0 + float(i)) * drill_radius * 0.4,
			drill_radius * (0.4 + t * 0.9))
		draw_circle(p, 2.4 * (1.0 - t), Color(color_secondary.r, color_secondary.g, color_secondary.b, 1.0 - t))

	PowerArt.draw_drill(self, Vector2.ZERO, drill_radius, color, color_secondary, _phase)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
