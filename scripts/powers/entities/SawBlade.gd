class_name SawBlade
extends Node2D
## One orbiting saw blade.
##
## Below max level the blades run a duty cycle: they spin up, cut for a while,
## then wind down and retract into the player before coming back. At max level
## `continuous` is set and they never stop, which is the reward for finishing
## the upgrade path.

const SPAWN_TIME := 0.30

var target: Node2D
var orbit_radius: float = 120.0
var orbit_speed: float = 2.4
var orbit_angle: float = 0.0
var blade_radius: float = 26.0
var color: Color = Palette.ACCENT
var color_secondary: Color = Color.WHITE

var damage: float = 12.0
var crit_chance: float = 0.05
var crit_damage: float = 1.6
var knockback: float = 120.0
var hit_interval: float = 0.35
var source_id: int = 0

## Duty cycle, in seconds. `continuous` ignores both.
var active_time: float = 4.0
var rest_time: float = 2.0
var continuous: bool = false

var _phase: float = 0.0
var _spin: float = 0.0
var _cycle: float = 0.0
var _active: bool = true
var _visibility: float = 0.0
var _sweep: float = 0.0
var _alive: bool = false


func _ready() -> void:
	add_to_group(&"saw_blades")
	z_index = 12


func pool_reset() -> void:
	_phase = 0.0
	_spin = 0.0
	_cycle = 0.0
	_active = true
	_visibility = 0.0
	_sweep = 0.0
	_alive = true
	scale = Vector2.ONE


func pool_sleep() -> void:
	_alive = false
	target = null


func configure(cfg: Dictionary) -> void:
	target = cfg.get("target", null)
	orbit_radius = float(cfg.get("orbit_radius", 120.0))
	orbit_speed = float(cfg.get("orbit_speed", 2.4))
	orbit_angle = float(cfg.get("orbit_angle", 0.0))
	blade_radius = float(cfg.get("blade_radius", 26.0))
	color = cfg.get("color", Palette.ACCENT)
	color_secondary = cfg.get("color2", Color.WHITE)
	damage = float(cfg.get("damage", 12.0))
	crit_chance = float(cfg.get("crit_chance", 0.05))
	crit_damage = float(cfg.get("crit_damage", 1.6))
	knockback = float(cfg.get("knockback", 120.0))
	hit_interval = float(cfg.get("hit_interval", 0.35))
	source_id = int(cfg.get("source_id", get_instance_id()))
	active_time = float(cfg.get("active_time", 4.0))
	rest_time = float(cfg.get("rest_time", 2.0))
	continuous = bool(cfg.get("continuous", false))
	if continuous:
		_active = true
	queue_redraw()


func retune(cfg: Dictionary) -> void:
	var keep_cycle := _cycle
	var keep_active := _active
	var keep_vis := _visibility
	configure(cfg)
	_cycle = keep_cycle
	_active = keep_active or continuous
	_visibility = keep_vis


## Shared cycle clock so a whole set of blades retracts and returns together.
func sync_cycle(time: float, active: bool) -> void:
	_cycle = time
	_active = active or continuous


func _process(delta: float) -> void:
	if not _alive:
		return
	if target == null or not is_instance_valid(target):
		expire()
		return
	_phase += delta

	if continuous:
		_active = true
	else:
		_cycle += delta
		var window := active_time if _active else rest_time
		if _cycle >= window:
			_cycle = 0.0
			_active = not _active

	# Blades fade and shrink on the way out, then snap back with a spin-up.
	var want := 1.0 if _active else 0.0
	_visibility = move_toward(_visibility, want, delta / SPAWN_TIME)
	_spin += delta * orbit_speed * (2.6 if _active else 0.6)
	orbit_angle += orbit_speed * delta * (1.0 if _active else 0.25)

	var eased := 1.0 - pow(1.0 - _visibility, 3.0)
	global_position = target.global_position + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius * eased
	scale = Vector2.ONE * maxf(0.001, eased)

	if _active and _visibility > 0.6:
		_sweep -= delta
		if _sweep <= 0.0:
			_sweep = 0.08
			_cut()
	queue_redraw()


func _cut() -> void:
	if EnemyDirector.instance == null:
		return
	for enemy in EnemyDirector.instance.get_in_radius(global_position, blade_radius + 6.0, 8):
		var is_crit := RunManager.rng.randf() < crit_chance
		var amount := damage * (crit_damage if is_crit else 1.0)
		var push := (enemy.global_position - global_position).normalized() * knockback
		if enemy.apply_hit(amount, is_crit, push, source_id, hit_interval):
			if EffectSpawner.instance != null:
				EffectSpawner.instance.spawn_hit_spark(enemy.global_position, color_secondary)


func expire() -> void:
	if not _alive:
		return
	_alive = false
	PoolManager.release(self)


func _draw() -> void:
	if not _alive or _visibility <= 0.01:
		return
	var alpha := clampf(_visibility, 0.0, 1.0)
	if _active and _visibility > 0.9:
		# Motion blur ring while cutting.
		draw_arc(Vector2.ZERO, blade_radius * 1.08, 0.0, TAU, 20,
			Color(color_secondary.r, color_secondary.g, color_secondary.b, 0.22), 3.0, true)
	var tint := Color(color.r, color.g, color.b, alpha)
	var tint2 := Color(color_secondary.r, color_secondary.g, color_secondary.b, alpha)
	PowerArt.draw_saw(self, Vector2.ZERO, blade_radius, tint, tint2, _spin)
