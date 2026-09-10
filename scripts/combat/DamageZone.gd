class_name DamageZone
extends Node2D
## A pooled area-of-effect: auras, mine fields, thorn mazes, flame walls, rifts
## and beacons are all this one scene with different settings.
##
## Zones do their own radius query against EnemyDirector's spatial hash instead
## of being physics areas - with several zones alive at once that is noticeably
## cheaper, and it gives exact control over tick rate.

enum Style { AURA, FIELD, FLAME, THORNS, RIFT, BEACON, SHOCK, FIRE_PATCH, HEAL_CIRCLE, DOMAIN }

var damage: float = 8.0
var tick_interval: float = 0.4
var radius: float = 140.0
var lifetime: float = 3.0
var color: Color = Palette.ACCENT
var color2: Color = Color.WHITE
var style: int = Style.AURA
var follow: Node2D
var slow_factor: float = 1.0
var slow_duration: float = 0.0
var pull_force: float = 0.0
var knockback: float = 0.0
var growth: float = 0.0
var move_dir: Vector2 = Vector2.ZERO
var move_speed: float = 0.0
var source_id: int = 0
var crit_chance: float = 0.0
var crit_damage: float = 1.6
var max_targets: int = 40
## Health per second restored to the player while they stand inside. Used by the
## Healing Drone; zero for every offensive zone.
var heal_rate: float = 0.0

var _age: float = 0.0
var _tick: float = 0.0
var _alive: bool = false
var _pulse: float = 0.0


func _ready() -> void:
	add_to_group(&"damage_zones")
	z_index = -1


func pool_reset() -> void:
	_age = 0.0
	_tick = 0.0
	_pulse = 0.0
	_alive = true
	scale = Vector2.ONE
	modulate = Color.WHITE


func pool_sleep() -> void:
	_alive = false
	follow = null


func configure(cfg: Dictionary) -> void:
	damage = float(cfg.get("damage", 8.0))
	tick_interval = float(cfg.get("tick_interval", 0.4))
	radius = float(cfg.get("radius", 140.0))
	lifetime = float(cfg.get("lifetime", 3.0))
	color = cfg.get("color", Palette.ACCENT)
	color2 = cfg.get("color2", Color.WHITE)
	style = int(cfg.get("style", Style.AURA))
	follow = cfg.get("follow", null)
	slow_factor = float(cfg.get("slow_factor", 1.0))
	slow_duration = float(cfg.get("slow_duration", 0.0))
	pull_force = float(cfg.get("pull_force", 0.0))
	knockback = float(cfg.get("knockback", 0.0))
	growth = float(cfg.get("growth", 0.0))
	move_dir = cfg.get("move_dir", Vector2.ZERO)
	move_speed = float(cfg.get("move_speed", 0.0))
	source_id = int(cfg.get("source_id", get_instance_id()))
	crit_chance = float(cfg.get("crit_chance", 0.0))
	crit_damage = float(cfg.get("crit_damage", 1.6))
	max_targets = int(cfg.get("max_targets", 40))
	heal_rate = float(cfg.get("heal_rate", 0.0))
	_tick = 0.0
	queue_redraw()


func set_radius(value: float) -> void:
	radius = value
	queue_redraw()


func _process(delta: float) -> void:
	if not _alive:
		return
	_age += delta
	_pulse += delta
	if lifetime > 0.0 and _age >= lifetime:
		_expire()
		return
	if follow != null and is_instance_valid(follow):
		global_position = follow.global_position
	elif move_speed != 0.0:
		global_position += move_dir * move_speed * delta
	if growth != 0.0:
		radius += growth * delta

	_tick -= delta
	if _tick <= 0.0:
		_tick = tick_interval
		_apply()
	queue_redraw()


func _apply() -> void:
	_apply_healing()
	if damage <= 0.0 and slow_duration <= 0.0 and pull_force == 0.0:
		return
	if EnemyDirector.instance == null:
		return
	var targets := EnemyDirector.instance.get_in_radius(global_position, radius, max_targets)
	for enemy in targets:
		var offset := enemy.global_position - global_position
		var is_crit := crit_chance > 0.0 and RunManager.rng.randf() < crit_chance
		var amount := damage * (crit_damage if is_crit else 1.0)
		var kb := Vector2.ZERO
		if knockback != 0.0 and offset.length() > 0.01:
			kb = offset.normalized() * knockback
		enemy.apply_hit(amount, is_crit, kb, source_id, tick_interval * 0.9)
		if slow_duration > 0.0:
			enemy.apply_slow(slow_factor, slow_duration)
		if pull_force != 0.0 and offset.length() > 8.0:
			enemy.global_position -= offset.normalized() * pull_force * tick_interval


## Healing zones top the player up for as long as they stay inside the circle.
func _apply_healing() -> void:
	if heal_rate <= 0.0:
		return
	var player := Player.instance
	if player == null or not is_instance_valid(player) or player.is_dead:
		return
	if player.global_position.distance_to(global_position) > radius:
		return
	player.heal(heal_rate * tick_interval)
	if EffectSpawner.instance != null and RunManager.rng.randf() < 0.5:
		EffectSpawner.instance.spawn_hit_spark(
			player.global_position + MathUtil.random_point_on_circle(RunManager.rng, 18.0),
			Color(0.45, 1.0, 0.6))


func _expire() -> void:
	if not _alive:
		return
	_alive = false
	PoolManager.release(self)


func expire() -> void:
	_expire()


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	var fade := 1.0
	if lifetime > 0.0:
		fade = clampf(1.0 - _age / lifetime, 0.0, 1.0)
		fade = minf(1.0, fade * 3.0)  # only fade near the end
	var base := color
	base.a = color.a * fade

	match style:
		Style.FIELD:
			draw_circle(Vector2.ZERO, radius, Color(base.r, base.g, base.b, 0.16 * fade))
			Draw2D.ring(self, Vector2.ZERO, radius, base, 3.0)
		Style.FLAME:
			_draw_flame(base, fade)
		Style.THORNS:
			_draw_thorns(base, fade)
		Style.RIFT:
			_draw_rift(base, fade)
		Style.BEACON:
			_draw_beacon(base, fade)
		Style.SHOCK:
			_draw_shock(base, fade)
		Style.FIRE_PATCH:
			_draw_fire_patch(base, fade)
		Style.HEAL_CIRCLE:
			_draw_heal_circle(base, fade)
		Style.DOMAIN:
			_draw_domain(base, fade)
		_:
			_draw_aura(base, fade)


func _draw_aura(base: Color, fade: float) -> void:
	var pulse := 0.92 + 0.08 * sin(_pulse * 4.0)
	draw_circle(Vector2.ZERO, radius * pulse, Color(base.r, base.g, base.b, 0.12 * fade))
	Draw2D.ring(self, Vector2.ZERO, radius * pulse, base, 4.0)
	Draw2D.ring(self, Vector2.ZERO, radius * pulse * 0.72, Color(base.r, base.g, base.b, 0.4 * fade), 2.0)


func _draw_flame(base: Color, fade: float) -> void:
	var pts := PackedVector2Array()
	var count := 20
	for i in count + 1:
		var t := float(i) / float(count)
		var a := t * TAU
		var wobble := 1.0 + 0.18 * sin(a * 5.0 + _pulse * 9.0)
		pts.append(Vector2(cos(a), sin(a)) * radius * wobble)
	draw_colored_polygon(pts, Color(base.r, base.g, base.b, 0.22 * fade))
	pts.append(pts[0])
	draw_polyline(pts, Color(1.0, 0.75, 0.3, 0.8 * fade), 4.0, true)


func _draw_thorns(base: Color, fade: float) -> void:
	draw_circle(Vector2.ZERO, radius, Color(base.r, base.g, base.b, 0.10 * fade))
	for i in 9:
		var a := TAU * float(i) / 9.0 + _pulse * 0.4
		var outer := Vector2(cos(a), sin(a)) * radius
		var left := Vector2(cos(a + 0.16), sin(a + 0.16)) * radius * 0.42
		var right := Vector2(cos(a - 0.16), sin(a - 0.16)) * radius * 0.42
		draw_colored_polygon(PackedVector2Array([outer, left, right]),
			Color(base.r, base.g, base.b, 0.75 * fade))
	Draw2D.ring(self, Vector2.ZERO, radius * 0.42, base, 2.0)


func _draw_rift(base: Color, fade: float) -> void:
	var pulse := 0.85 + 0.15 * sin(_pulse * 6.0)
	draw_circle(Vector2.ZERO, radius * pulse, Color(0.02, 0.0, 0.06, 0.6 * fade))
	Draw2D.ring(self, Vector2.ZERO, radius * pulse, base, 5.0)
	for i in 5:
		var a := _pulse * 2.0 + TAU * float(i) / 5.0
		var p1 := Vector2(cos(a), sin(a)) * radius * 0.3
		var p2 := Vector2(cos(a), sin(a)) * radius * pulse
		draw_line(p1, p2, Color(base.r, base.g, base.b, 0.55 * fade), 2.5, true)


func _draw_beacon(base: Color, fade: float) -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.03, 0.0, 0.08, 0.45 * fade))
	for i in 4:
		var r := radius * (0.25 + 0.25 * float(i)) * (0.9 + 0.1 * sin(_pulse * 3.0 + float(i)))
		Draw2D.ring(self, Vector2.ZERO, r, Color(base.r, base.g, base.b, (0.5 - 0.08 * float(i)) * fade), 2.5)
	draw_circle(Vector2.ZERO, radius * 0.14, Color(1, 1, 1, 0.85 * fade))


func _draw_shock(base: Color, fade: float) -> void:
	Draw2D.ring(self, Vector2.ZERO, radius, base, 3.0)
	for i in 7:
		var a := TAU * float(i) / 7.0 + _pulse * 3.0
		var jitter := 0.75 + 0.25 * sin(_pulse * 20.0 + float(i) * 2.0)
		var p := Vector2(cos(a), sin(a)) * radius * jitter
		var mid := p * 0.5 + Vector2(cos(a + 1.2), sin(a + 1.2)) * radius * 0.12
		draw_polyline(PackedVector2Array([Vector2.ZERO, mid, p]),
			Color(base.r, base.g, base.b, 0.7 * fade), 2.5, true)


## Burning ground left by a Molotov: a charred base, licking flame tongues and
## rising embers. Deliberately busier than the generic flame ring so a patch of
## fire never gets confused with an aura.
func _draw_fire_patch(base: Color, fade: float) -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.18, 0.07, 0.03, 0.42 * fade))
	var tongues := 12
	var pts := PackedVector2Array()
	for i in tongues + 1:
		var t := float(i) / float(tongues)
		var a := t * TAU
		var flick := 0.78 + 0.30 * absf(sin(a * 3.0 + _pulse * 8.0)) + 0.10 * sin(_pulse * 13.0 + a * 7.0)
		pts.append(Vector2(cos(a), sin(a)) * radius * flick)
	draw_colored_polygon(pts, Color(1.0, 0.42, 0.10, 0.34 * fade))

	var inner := PackedVector2Array()
	for i in tongues + 1:
		var t := float(i) / float(tongues)
		var a := t * TAU + 0.4
		var flick := 0.45 + 0.22 * absf(sin(a * 4.0 - _pulse * 10.0))
		inner.append(Vector2(cos(a), sin(a)) * radius * flick)
	draw_colored_polygon(inner, Color(1.0, 0.78, 0.25, 0.42 * fade))

	# Embers drifting upward out of the patch.
	for i in 6:
		var seed_a := float(i) * 2.399
		var rise := fposmod(_pulse * 0.9 + float(i) / 6.0, 1.0)
		var p := Vector2(cos(seed_a), sin(seed_a)) * radius * 0.6 + Vector2(0.0, -rise * radius * 0.9)
		draw_circle(p, 3.0 * (1.0 - rise), Color(1.0, 0.72, 0.28, 0.8 * (1.0 - rise) * fade))


## Healing circle: a soft field with a medical cross and rising motes.
func _draw_heal_circle(base: Color, fade: float) -> void:
	var green := Color(0.35, 1.0, 0.58)
	var pulse := 0.94 + 0.06 * sin(_pulse * 3.0)
	draw_circle(Vector2.ZERO, radius * pulse, Color(green.r, green.g, green.b, 0.12 * fade))
	Draw2D.ring(self, Vector2.ZERO, radius * pulse, Color(green.r, green.g, green.b, 0.75 * fade), 4.0)
	Draw2D.ring(self, Vector2.ZERO, radius * pulse * 0.62,
		Color(green.r, green.g, green.b, 0.35 * fade), 2.0)

	# Cross in the middle, unmistakably "stand here".
	var arm := radius * 0.09
	var span := radius * 0.30
	var cross := Color(green.r, green.g, green.b, 0.85 * fade)
	draw_rect(Rect2(Vector2(-arm, -span), Vector2(arm * 2.0, span * 2.0)), cross)
	draw_rect(Rect2(Vector2(-span, -arm), Vector2(span * 2.0, arm * 2.0)), cross)

	for i in 8:
		var a := float(i) * 0.785
		var rise := fposmod(_pulse * 0.7 + float(i) / 8.0, 1.0)
		var p := Vector2(cos(a), sin(a)) * radius * 0.75 + Vector2(0.0, -rise * radius * 0.55)
		draw_circle(p, 3.5 * (1.0 - rise), Color(green.r, green.g, green.b, 0.75 * (1.0 - rise) * fade))


## The Domain force field: a hex shell with a rotating lattice and edge arcs.
func _draw_domain(base: Color, fade: float) -> void:
	var pulse := 0.97 + 0.03 * sin(_pulse * 2.2)
	var r := radius * pulse
	draw_circle(Vector2.ZERO, r, Color(base.r, base.g, base.b, 0.10 * fade))

	# Two counter-rotating hex rings.
	for ring_index in 2:
		var spin := _pulse * (0.5 if ring_index == 0 else -0.8)
		var scale_r := r * (1.0 if ring_index == 0 else 0.66)
		var hex := Draw2D.polygon_points(6, scale_r, spin)
		var loop := hex.duplicate()
		loop.append(hex[0])
		draw_polyline(loop, Color(base.r, base.g, base.b, (0.85 if ring_index == 0 else 0.4) * fade),
			4.0 if ring_index == 0 else 2.0, true)

	# Radial lattice.
	for i in 6:
		var a := _pulse * 0.5 + TAU * float(i) / 6.0
		var dir := Vector2(cos(a), sin(a))
		draw_line(dir * r * 0.66, dir * r, Color(base.r, base.g, base.b, 0.35 * fade), 2.0, true)

	# Energy arcs crawling along the boundary.
	for i in 3:
		var start := _pulse * 1.6 + TAU * float(i) / 3.0
		draw_arc(Vector2.ZERO, r, start, start + 0.7, 12,
			Color(color2.r, color2.g, color2.b, 0.8 * fade), 5.0, true)
