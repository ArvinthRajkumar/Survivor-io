extends Node2D
## Chibi humanoid player character, drawn procedurally.
##
## Proportions are deliberately exaggerated (head roughly the size of the whole
## torso) so the character stays readable at phone size while a hundred enemies
## are on screen. The hero's accent colours drive the outfit and visor, so every
## operative is recognisable without needing separate art.
##
## The API is deliberately small — configure / set_motion / flash_hurt /
## set_shielded / set_dead — so Player.gd never has to know how any of it is
## drawn.

const HEAD_RADIUS := 21.0
const BODY_WIDTH := 15.0
const BODY_HEIGHT := 17.0
const HIP_Y := 12.0
const STEP_RATE := 11.0

var accent: Color = Palette.ACCENT
var accent_secondary: Color = Palette.ACCENT_WARM
var hero_shape: int = 2

var _phase: float = 0.0
var _step: float = 0.0
var _thrust: float = 0.0
var _facing: float = 1.0
var _lean: float = 0.0
var _hurt_flash: float = 0.0
var _shielded: bool = false
var _dead: bool = false
var _death_time: float = 0.0
var _trail: Array[Vector2] = []


func _ready() -> void:
	z_index = 10


func configure(hero: HeroData) -> void:
	if hero != null:
		accent = hero.accent
		accent_secondary = hero.accent_secondary
		hero_shape = hero.portrait_shape
	queue_redraw()


func _process(delta: float) -> void:
	_phase += delta
	if _hurt_flash > 0.0:
		_hurt_flash = maxf(0.0, _hurt_flash - delta * 3.5)
	if _dead:
		_death_time = minf(1.0, _death_time + delta * 2.2)
	else:
		_death_time = maxf(0.0, _death_time - delta * 4.0)
	# The step cycle only advances while actually moving, so the character
	# settles into an idle bob instead of marching on the spot.
	_step += delta * STEP_RATE * _thrust
	_thrust = lerpf(_thrust, 0.0, clampf(delta * 4.0, 0.0, 1.0))
	_lean = lerpf(_lean, 0.0, clampf(delta * 6.0, 0.0, 1.0))
	queue_redraw()


func set_motion(dir: Vector2, _delta: float) -> void:
	_thrust = clampf(dir.length(), 0.0, 1.0)
	if absf(dir.x) > 0.15:
		_facing = signf(dir.x)
	_lean = clampf(dir.x * 0.18, -0.22, 0.22)
	if _trail.size() > 6:
		_trail.pop_front()
	_trail.append(global_position)


func flash_hurt() -> void:
	_hurt_flash = 1.0


func set_shielded(value: bool) -> void:
	_shielded = value
	queue_redraw()


func set_dead(value: bool) -> void:
	_dead = value
	queue_redraw()


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	var tint := accent
	if _hurt_flash > 0.0:
		tint = tint.lerp(Palette.DANGER, _hurt_flash * 0.85)
	if _dead:
		tint = tint.darkened(0.45)

	var bob := sin(_phase * 2.6) * 1.6 * (1.0 - _thrust) + sin(_step) * 2.4 * _thrust
	var slump := _death_time * 14.0
	var origin := Vector2(0.0, bob + slump)
	var lean := _lean + _death_time * 0.5 * _facing

	_draw_shadow()
	if _thrust > 0.25 and not _dead:
		_draw_speed_trail(tint)

	# Body parts are drawn back to front: far limbs, torso, near limbs, head.
	var swing := sin(_step) * 0.55 * _thrust
	_draw_leg(origin, lean, -swing, tint, true)
	_draw_arm(origin, lean, swing, tint, true)
	_draw_torso(origin, lean, tint)
	_draw_leg(origin, lean, swing, tint, false)
	_draw_arm(origin, lean, -swing, tint, false)
	_draw_head(origin, lean, tint)

	if _shielded:
		_draw_shield()


func _draw_shadow() -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a) * 20.0, sin(a) * 7.0) + Vector2(0.0, 30.0))
	draw_colored_polygon(pts, Color(0.0, 0.0, 0.0, 0.28))


## A few ghosted silhouettes behind the character while sprinting.
func _draw_speed_trail(tint: Color) -> void:
	for i in range(_trail.size() - 1):
		var t := float(i) / float(_trail.size())
		var p := to_local(_trail[i])
		draw_circle(p + Vector2(0.0, -6.0), 9.0 * t + 3.0,
			Color(tint.r, tint.g, tint.b, 0.10 * t))


func _draw_torso(origin: Vector2, lean: float, tint: Color) -> void:
	var top := origin + Vector2(0.0, -BODY_HEIGHT * 0.5)
	var pts := PackedVector2Array([
		Vector2(-BODY_WIDTH * 0.86, -BODY_HEIGHT * 0.5),
		Vector2(BODY_WIDTH * 0.86, -BODY_HEIGHT * 0.5),
		Vector2(BODY_WIDTH, BODY_HEIGHT * 0.6),
		Vector2(-BODY_WIDTH, BODY_HEIGHT * 0.6),
	])
	var body := PackedVector2Array()
	for p in pts:
		body.append(p.rotated(lean) + top + Vector2(0.0, BODY_HEIGHT * 0.5))
	Draw2D.neon_polygon(self, body, tint.darkened(0.55), tint, 3.0)

	# Chest emblem: the hero's roster shape, so the character and the portrait
	# read as the same person.
	var emblem_center := top + Vector2(0.0, BODY_HEIGHT * 0.45)
	var emblem: PackedVector2Array
	match hero_shape:
		0:
			emblem = Draw2D.polygon_points(3, 5.5, -PI * 0.5)
		1:
			emblem = Draw2D.polygon_points(4, 5.5, 0.0)
		3:
			emblem = Draw2D.polygon_points(6, 5.5, 0.0)
		4:
			emblem = Draw2D.star_points(5, 6.0, 2.6, -PI * 0.5)
		_:
			emblem = Draw2D.polygon_points(5, 5.5, -PI * 0.5)
	var placed := PackedVector2Array()
	for p in emblem:
		placed.append(p.rotated(lean) + emblem_center)
	draw_colored_polygon(placed, accent_secondary)


func _draw_leg(origin: Vector2, lean: float, swing: float, tint: Color, far: bool) -> void:
	var hip := origin + Vector2((-5.0 if far else 5.0) * _facing, HIP_Y).rotated(lean)
	var knee := hip + Vector2(swing * 7.0, 9.0)
	var foot := knee + Vector2(swing * 9.0, 9.0)
	var color := tint.darkened(0.65 if far else 0.45)
	draw_line(hip, knee, color, 7.0, true)
	draw_line(knee, foot, color, 7.0, true)
	# Boot.
	draw_line(foot, foot + Vector2(3.5 * _facing, 0.0), accent_secondary.darkened(0.2), 7.0, true)


func _draw_arm(origin: Vector2, lean: float, swing: float, tint: Color, far: bool) -> void:
	var shoulder := origin + Vector2((-BODY_WIDTH * 0.9 if far else BODY_WIDTH * 0.9), -4.0).rotated(lean)
	var hand := shoulder + Vector2(swing * 8.0 + (-3.0 if far else 3.0), 12.0)
	var color := tint.darkened(0.6 if far else 0.35)
	draw_line(shoulder, hand, color, 6.0, true)
	draw_circle(hand, 3.6, accent_secondary.darkened(0.15))


func _draw_head(origin: Vector2, lean: float, tint: Color) -> void:
	var head := origin + Vector2(0.0, -BODY_HEIGHT - HEAD_RADIUS * 0.55).rotated(lean * 0.6)

	# Hair / helmet shell behind the face.
	var shell := PackedVector2Array()
	for i in 14:
		var a := PI + PI * float(i) / 13.0
		shell.append(head + Vector2(cos(a), sin(a)) * HEAD_RADIUS * 1.06)
	shell.append(head + Vector2(HEAD_RADIUS * 0.95, HEAD_RADIUS * 0.25))
	shell.append(head + Vector2(-HEAD_RADIUS * 0.95, HEAD_RADIUS * 0.25))
	draw_colored_polygon(shell, tint.darkened(0.35))

	# Face.
	var skin := Color(0.98, 0.86, 0.76)
	if _hurt_flash > 0.0:
		skin = skin.lerp(Palette.DANGER, _hurt_flash * 0.6)
	if _dead:
		skin = skin.darkened(0.35)
	draw_circle(head, HEAD_RADIUS, skin)
	draw_arc(head, HEAD_RADIUS, 0.0, TAU, 24, tint.darkened(0.2), 2.5, true)

	# Visor band in the secondary accent — the readable "sci-fi operative" cue.
	var visor_y := head.y - HEAD_RADIUS * 0.12
	var visor := PackedVector2Array([
		Vector2(head.x - HEAD_RADIUS * 0.92, visor_y - HEAD_RADIUS * 0.30),
		Vector2(head.x + HEAD_RADIUS * 0.92, visor_y - HEAD_RADIUS * 0.30),
		Vector2(head.x + HEAD_RADIUS * 0.80, visor_y + HEAD_RADIUS * 0.22),
		Vector2(head.x - HEAD_RADIUS * 0.80, visor_y + HEAD_RADIUS * 0.22),
	])
	draw_colored_polygon(visor, Color(accent_secondary.r, accent_secondary.g, accent_secondary.b, 0.9))

	if _dead:
		# Closed eyes read instantly as "down".
		for side in [-1.0, 1.0]:
			var e := head + Vector2(side * HEAD_RADIUS * 0.36, visor_y - head.y)
			draw_line(e - Vector2(3.5, 0.0), e + Vector2(3.5, 0.0), Color(0.1, 0.1, 0.14), 2.5, true)
	else:
		# Eyes look the way the character is moving.
		var look := Vector2(_facing * HEAD_RADIUS * 0.10, 0.0)
		var blink := 1.0 if fposmod(_phase, 3.4) > 0.12 else 0.25
		for side in [-1.0, 1.0]:
			var e := head + Vector2(side * HEAD_RADIUS * 0.36, visor_y - head.y) + look
			draw_circle(e, HEAD_RADIUS * 0.13 * blink + 1.0, Color(0.06, 0.09, 0.16))
			if blink > 0.5:
				draw_circle(e + Vector2(1.2, -1.2), HEAD_RADIUS * 0.05, Color(1, 1, 1, 0.9))

	# Antenna with a blinking tip.
	var tip := head + Vector2(HEAD_RADIUS * 0.55, -HEAD_RADIUS * 1.15)
	draw_line(head + Vector2(HEAD_RADIUS * 0.42, -HEAD_RADIUS * 0.78), tip,
		tint.darkened(0.25), 2.5, true)
	var blink_glow := 0.4 + 0.6 * absf(sin(_phase * 3.0))
	draw_circle(tip, 3.2, Color(accent_secondary.r, accent_secondary.g, accent_secondary.b, blink_glow))


func _draw_shield() -> void:
	var shield := Color(0.55, 0.85, 1.0, 0.5)
	var radius := 46.0 + 2.0 * sin(_phase * 4.0)
	Draw2D.ring(self, Vector2(0.0, -6.0), radius, shield, 4.0)
	draw_circle(Vector2(0.0, -6.0), radius, Color(shield.r, shield.g, shield.b, 0.08))
	# Hex facets so the bubble reads as a constructed field.
	for i in 6:
		var a := _phase * 0.8 + TAU * float(i) / 6.0
		var p := Vector2(cos(a), sin(a)) * radius + Vector2(0.0, -6.0)
		draw_circle(p, 3.0, Color(shield.r, shield.g, shield.b, 0.7))
