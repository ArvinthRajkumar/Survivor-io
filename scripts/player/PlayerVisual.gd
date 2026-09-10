extends Node2D
## The operative: a chibi humanoid drawn procedurally, one _draw() per frame.
##
## Proportions are deliberately exaggerated (the head is about as big as the
## whole torso) so the character stays readable at phone size with a hundred
## enemies on screen. Everything that makes it feel alive is layered on top of
## that silhouette rather than baked into it:
##
##  * the operative always faces the camera — only the left/right mirror and the
##    lean change with movement, so the player's own character is never a blank
##    silhouette to look at;
##  * a scarf simulated as a lagging chain, so direction changes whip it;
##  * squash and stretch driven by acceleration, plus a lean into the turn;
##  * footfall dust timed to the actual step cycle;
##  * the katana: sheathed across the back at rest, drawn and swung in the hand
##    on every cut, using the same geometry as its HUD icon.
##
## The API stays small — configure / set_motion / play_slash / flash_hurt /
## set_shielded / set_dead — so Player.gd never has to know how any of it works.

const HEAD_RADIUS := 20.0
const BODY_WIDTH := 14.0
const BODY_HEIGHT := 17.0
const HIP_Y := 11.0
const STEP_RATE := 10.5
const SCARF_SEGMENTS := 7
const SCARF_LENGTH := 6.0
const MAX_DUST := 10
const TRAIL_LENGTH := 7

var accent: Color = Palette.ACCENT
var accent_secondary: Color = Palette.ACCENT_WARM
var hero_shape: int = 2

var _skin: Color = Color(0.99, 0.87, 0.78)
var _hair: Color = Color(0.16, 0.18, 0.28)

var _phase: float = 0.0
var _step: float = 0.0
var _thrust: float = 0.0
var _facing: float = 1.0
var _lean: float = 0.0
var _squash: float = 0.0
var _last_speed: float = 0.0
var _hurt_flash: float = 0.0
var _shielded: bool = false
var _dead: bool = false
var _death_time: float = 0.0
var _blink: float = 0.0
var _next_blink: float = 2.0

## Katana swing state.
var _slash_time: float = 0.0
var _slash_span: float = 0.22
var _slash_dir: Vector2 = Vector2.RIGHT
var _slash_sign: float = 1.0
var _slash_arc: float = 2.0
var _slash_spin: bool = false
var _lunge: Vector2 = Vector2.ZERO

var _scarf: PackedVector2Array = PackedVector2Array()
var _dust: Array[Dictionary] = []
var _trail: Array[Vector2] = []
var _last_step_side: int = 0


func _ready() -> void:
	z_index = 10
	_reset_scarf()


func configure(hero: HeroData) -> void:
	if hero != null:
		accent = hero.accent
		accent_secondary = hero.accent_secondary
		hero_shape = hero.portrait_shape
		# Hair takes a deep, desaturated cast of the accent so each operative
		# reads as a different person without needing a separate palette.
		_hair = Color(accent.r * 0.30 + 0.06, accent.g * 0.26 + 0.07, accent.b * 0.34 + 0.12)
	queue_redraw()


# --- State fed by Player.gd -------------------------------------------------

func set_motion(dir: Vector2, velocity: Vector2, delta: float) -> void:
	var speed := velocity.length()
	_thrust = clampf(dir.length(), 0.0, 1.0)
	if absf(dir.x) > 0.12:
		_facing = signf(dir.x)
	_lean = clampf(dir.x * 0.20, -0.24, 0.24)
	# Acceleration drives squash and stretch: speeding up stretches the body
	# along its travel, slamming to a stop squashes it.
	var accel := (speed - _last_speed) / maxf(0.0001, delta)
	_last_speed = speed
	_squash = clampf(lerpf(_squash, clampf(accel / 5200.0, -0.22, 0.22), clampf(delta * 9.0, 0.0, 1.0)), -0.3, 0.3)
	_update_scarf(delta, velocity)
	if _trail.size() > TRAIL_LENGTH:
		_trail.pop_front()
	_trail.append(global_position)


## Called by KatanaPower the instant a cut is spawned, so the blade in the
## operative's hands and the damage on the field are always the same event.
func play_slash(dir: Vector2, handedness: float, arc: float, spin: bool) -> void:
	_slash_dir = dir.normalized() if dir.length_squared() > 0.001 else Vector2.RIGHT
	_slash_sign = 1.0 if handedness >= 0.0 else -1.0
	_slash_arc = arc
	_slash_spin = spin
	_slash_span = 0.34 if spin else 0.24
	_slash_time = _slash_span
	if absf(_slash_dir.x) > 0.2:
		_facing = signf(_slash_dir.x)
	# A short lunge sells the commitment of the swing.
	_lunge = _slash_dir * (7.0 if spin else 5.0)


func flash_hurt() -> void:
	_hurt_flash = 1.0


func set_shielded(value: bool) -> void:
	_shielded = value
	queue_redraw()


func set_dead(value: bool) -> void:
	_dead = value
	if value:
		_slash_time = 0.0
	queue_redraw()


# --- Simulation -------------------------------------------------------------

func _process(delta: float) -> void:
	_phase += delta
	if _hurt_flash > 0.0:
		_hurt_flash = maxf(0.0, _hurt_flash - delta * 3.2)
	if _slash_time > 0.0:
		_slash_time = maxf(0.0, _slash_time - delta)
	_lunge = _lunge.lerp(Vector2.ZERO, clampf(delta * 9.0, 0.0, 1.0))
	if _dead:
		_death_time = minf(1.0, _death_time + delta * 2.2)
	else:
		_death_time = maxf(0.0, _death_time - delta * 4.0)

	# The step cycle only advances while actually moving, so the character
	# settles into an idle breath instead of marching on the spot.
	var before := _step
	_step += delta * STEP_RATE * _thrust
	_emit_step_dust(before, _step)
	_thrust = lerpf(_thrust, 0.0, clampf(delta * 4.0, 0.0, 1.0))
	_lean = lerpf(_lean, 0.0, clampf(delta * 6.0, 0.0, 1.0))
	_squash = lerpf(_squash, 0.0, clampf(delta * 5.0, 0.0, 1.0))

	_tick_blink(delta)
	_tick_dust(delta)
	queue_redraw()


func _tick_blink(delta: float) -> void:
	_next_blink -= delta
	if _next_blink <= 0.0:
		_next_blink = randf_range(2.4, 5.2)
		_blink = 0.14
	if _blink > 0.0:
		_blink = maxf(0.0, _blink - delta)


## A puff of dust each time a foot passes through the bottom of its arc.
func _emit_step_dust(before: float, after: float) -> void:
	if _thrust < 0.35 or _dead:
		return
	var side := int(floor(after / PI))
	if side == _last_step_side or int(floor(before / PI)) == side:
		return
	_last_step_side = side
	if _dust.size() >= MAX_DUST:
		_dust.pop_front()
	_dust.append({
		"pos": global_position + Vector2(randf_range(-7.0, 7.0), 26.0),
		"age": 0.0,
		"size": randf_range(4.0, 7.0),
		"drift": Vector2(randf_range(-14.0, 14.0), randf_range(-6.0, 2.0)),
	})


func _tick_dust(delta: float) -> void:
	var i := _dust.size() - 1
	while i >= 0:
		var puff := _dust[i]
		puff["age"] = float(puff["age"]) + delta
		puff["pos"] = (puff["pos"] as Vector2) + (puff["drift"] as Vector2) * delta
		if float(puff["age"]) > 0.45:
			_dust.remove_at(i)
		i -= 1


func _reset_scarf() -> void:
	_scarf.resize(SCARF_SEGMENTS)
	for i in SCARF_SEGMENTS:
		_scarf[i] = global_position


## Lagging chain: each knot chases the one in front of it, so a hard turn snaps
## the scarf out sideways and running straight streams it behind.
func _update_scarf(delta: float, velocity: Vector2) -> void:
	if _scarf.size() != SCARF_SEGMENTS:
		_reset_scarf()
	# Anchored off the far shoulder and pushed away from the body, so the tail
	# hangs clear of the torso instead of lying across the chest like a sash.
	var anchor := global_position + Vector2(-11.0 * _facing, -BODY_HEIGHT * 0.72)
	_scarf[0] = anchor
	var follow := clampf(delta * 24.0, 0.0, 1.0)
	# Gravity is always on, so the tail hangs at rest and only streams when the
	# operative is actually moving. Without it the scarf stands straight up the
	# moment the player runs downward, which reads as an antenna, not cloth.
	var drift := Vector2(-3.0 * _facing, 5.0)
	if velocity.length_squared() > 400.0:
		drift += -velocity.normalized() * 9.0
	# Kept below the shoulders on purpose. Physically the tail should stream
	# straight up when the operative runs down the screen, but on a top-down
	# view that draws a rigid spike out of the head — it reads as an antenna,
	# not cloth. Biasing it downward costs nothing and always looks like a scarf.
	drift.y = maxf(drift.y, 1.2)
	for i in range(1, SCARF_SEGMENTS):
		var lead := _scarf[i - 1]
		# Knots further down the tail lag more, which is what bends the chain
		# when the operative turns. A uniform chain just draws a stiff plank.
		var slack := 1.0 - 0.10 * float(i)
		var knot: Vector2 = _scarf[i].lerp(lead + drift, follow * slack)
		# Links hold their length exactly, so the tail always reads as cloth of
		# a fixed size rather than concertinaing into a blob when it slows down.
		var offset := knot - lead
		if offset.length_squared() < 0.01:
			offset = drift.normalized() if drift.length_squared() > 0.01 else Vector2.DOWN
		_scarf[i] = lead + offset.normalized() * SCARF_LENGTH


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	var tint := accent
	if _hurt_flash > 0.0:
		tint = tint.lerp(Palette.DANGER, _hurt_flash * 0.8)
	if _dead:
		tint = tint.darkened(0.45)

	var bob := sin(_phase * 2.4) * 1.5 * (1.0 - _thrust) + absf(sin(_step)) * -3.0 * _thrust
	var slump := _death_time * 15.0
	var origin := Vector2(0.0, bob + slump) + _lunge
	var lean := _lean + _death_time * 0.5 * _facing + _slash_lean()
	var swing := sin(_step) * 0.6 * _thrust

	_draw_shadow(slump)
	_draw_dust()
	if _thrust > 0.3 and not _dead:
		_draw_speed_trail(tint)

	# Squash and stretch is applied to everything above the shadow so the
	# character deforms as one body rather than in pieces.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 - _squash, 1.0 + _squash))

	if _slash_time <= 0.0 and not _dead:
		_draw_sheath(origin, lean, tint)
	_draw_scarf_tail()
	_draw_arm(origin, lean, swing, tint, true)
	_draw_leg(origin, lean, -swing, tint, true)
	_draw_torso(origin, lean, tint)
	_draw_leg(origin, lean, swing, tint, false)
	_draw_collar(origin, lean)
	_draw_head(origin, lean, tint)
	_draw_sword_arm(origin, lean, swing, tint)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _shielded:
		_draw_shield()


## How far the body twists into a swing: hard at the strike, easing back out.
func _slash_lean() -> float:
	if _slash_time <= 0.0:
		return 0.0
	var t := _slash_time / _slash_span
	return _slash_sign * 0.42 * t * t


func _draw_shadow(slump: float) -> void:
	var lift := 1.0 - clampf(absf(sin(_step)) * _thrust * 0.22, 0.0, 0.25)
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		pts.append(Vector2(cos(a) * 19.0 * lift, sin(a) * 6.5 * lift) + Vector2(0.0, 30.0 + slump * 0.4))
	draw_colored_polygon(pts, Color(0.0, 0.0, 0.0, 0.30))


func _draw_dust() -> void:
	for puff in _dust:
		var t := clampf(float(puff["age"]) / 0.45, 0.0, 1.0)
		var p := to_local(puff["pos"] as Vector2)
		draw_circle(p, float(puff["size"]) * (0.6 + t), Color(0.75, 0.82, 0.95, 0.22 * (1.0 - t)))


## Ghosted silhouettes behind the character while sprinting.
func _draw_speed_trail(tint: Color) -> void:
	for i in range(_trail.size() - 1):
		var t := float(i) / float(maxi(1, _trail.size()))
		var p := to_local(_trail[i])
		draw_circle(p + Vector2(0.0, -8.0), 10.0 * t + 3.0,
			Color(tint.r, tint.g, tint.b, 0.09 * t))


## The saya worn across the back, visible whenever the blade is not in hand.
func _draw_sheath(origin: Vector2, lean: float, tint: Color) -> void:
	# Angled so the tip clears the head silhouette — a saya hidden entirely
	# behind the body might as well not be drawn.
	var hip := origin + Vector2(-12.0 * _facing, 7.0).rotated(lean)
	var tip := origin + Vector2(26.0 * _facing, -BODY_HEIGHT - 13.0).rotated(lean)
	draw_line(hip, tip, Color(0.09, 0.10, 0.15), 8.0, true)
	draw_line(hip, tip, tint.darkened(0.5), 4.4, true)
	# Two binding cords and the pommel cap.
	for t in [0.35, 0.62]:
		var p: Vector2 = hip.lerp(tip, t)
		draw_circle(p, 2.6, accent_secondary.darkened(0.15))
	draw_circle(tip, 3.4, accent_secondary)


func _draw_scarf_tail() -> void:
	if _scarf.size() < 3:
		return
	var pts := PackedVector2Array()
	for p in _scarf:
		pts.append(to_local(p))
	# The ripple is added here rather than in the simulation: displacing the
	# knots themselves would fight the length constraint and flatten the wave
	# out, whereas offsetting at draw time keeps it visible.
	for i in range(1, pts.size()):
		var along := pts[i] - pts[i - 1]
		if along.length_squared() < 0.01:
			continue
		var wave := sin(_phase * 8.0 - float(i) * 1.05) * (0.6 + 1.15 * float(i))
		pts[i] += along.orthogonal().normalized() * wave

	# Drawn as one trapezoid per segment, each using that segment's own normal.
	# Sharing normals between neighbours (or building the whole tail as a single
	# outline) folds into a bow-tie the moment the tail whips back on itself, and
	# a self-intersecting polygon cannot be triangulated at all.
	var cloth := accent_secondary if not _dead else accent_secondary.darkened(0.5)
	var right := PackedVector2Array()
	for i in range(pts.size() - 1):
		var span := pts[i + 1] - pts[i]
		if span.length_squared() < 0.02:
			continue
		var normal := span.orthogonal().normalized()
		var t0 := float(i) / float(pts.size() - 1)
		var t1 := float(i + 1) / float(pts.size() - 1)
		var h0 := lerpf(5.5, 0.6, t0 * t0)
		var h1 := lerpf(5.5, 0.6, t1 * t1)
		draw_colored_polygon(PackedVector2Array([
			pts[i] + normal * h0, pts[i + 1] + normal * h1,
			pts[i + 1] - normal * h1, pts[i] - normal * h0]), cloth)
		if right.is_empty():
			right.append(pts[i] - normal * h0)
		right.append(pts[i + 1] - normal * h1)

	# A darker under-edge gives the cloth a fold instead of a flat cut-out.
	if right.size() >= 2:
		draw_polyline(right, cloth.darkened(0.35), 1.6, true)


func _draw_torso(origin: Vector2, lean: float, tint: Color) -> void:
	var top := origin + Vector2(0.0, -BODY_HEIGHT * 0.5)
	var centre := top + Vector2(0.0, BODY_HEIGHT * 0.5)

	# Jacket: narrow at the shoulders, flaring to the hem.
	var shell := PackedVector2Array([
		Vector2(-BODY_WIDTH * 0.84, -BODY_HEIGHT * 0.55),
		Vector2(BODY_WIDTH * 0.84, -BODY_HEIGHT * 0.55),
		Vector2(BODY_WIDTH * 1.06, BODY_HEIGHT * 0.42),
		Vector2(BODY_WIDTH * 0.92, BODY_HEIGHT * 0.66),
		Vector2(-BODY_WIDTH * 0.92, BODY_HEIGHT * 0.66),
		Vector2(-BODY_WIDTH * 1.06, BODY_HEIGHT * 0.42),
	])
	var body := PackedVector2Array()
	for p in shell:
		body.append(p.rotated(lean) + centre)
	Draw2D.neon_polygon(self, body, tint.darkened(0.58), tint, 2.6)

	# Shaded half, so the body has a light direction instead of reading flat.
	var shade := PackedVector2Array()
	for p in [shell[0], Vector2(0.0, -BODY_HEIGHT * 0.55), Vector2(0.0, BODY_HEIGHT * 0.66), shell[4], shell[5]]:
		shade.append((p as Vector2).rotated(lean) + centre)
	draw_colored_polygon(shade, Color(0.0, 0.0, 0.0, 0.16))

	# Open jacket, undershirt, and the roster emblem — always visible since the
	# operative always faces the camera.
	var lapel := PackedVector2Array()
	for p in [Vector2(-5.5, -BODY_HEIGHT * 0.55), Vector2(5.5, -BODY_HEIGHT * 0.55),
			Vector2(3.0, BODY_HEIGHT * 0.6), Vector2(-3.0, BODY_HEIGHT * 0.6)]:
		lapel.append((p as Vector2).rotated(lean) + centre)
	draw_colored_polygon(lapel, tint.darkened(0.75))
	_draw_emblem(centre + Vector2(0.0, -BODY_HEIGHT * 0.12).rotated(lean), lean)

	# Belt across the hips.
	var belt_l := Vector2(-BODY_WIDTH * 1.0, BODY_HEIGHT * 0.44).rotated(lean) + centre
	var belt_r := Vector2(BODY_WIDTH * 1.0, BODY_HEIGHT * 0.44).rotated(lean) + centre
	draw_line(belt_l, belt_r, accent_secondary.darkened(0.32), 3.2, true)
	draw_circle(belt_l.lerp(belt_r, 0.5), 2.8, accent_secondary)


func _draw_emblem(centre: Vector2, lean: float) -> void:
	var emblem: PackedVector2Array
	match hero_shape:
		0:
			emblem = Draw2D.polygon_points(3, 5.0, -PI * 0.5)
		1:
			emblem = Draw2D.polygon_points(4, 5.0, 0.0)
		3:
			emblem = Draw2D.polygon_points(6, 5.0, 0.0)
		4:
			emblem = Draw2D.star_points(5, 5.6, 2.4, -PI * 0.5)
		_:
			emblem = Draw2D.polygon_points(5, 5.0, -PI * 0.5)
	var placed := PackedVector2Array()
	for p in emblem:
		placed.append(p.rotated(lean) + centre)
	draw_colored_polygon(placed, accent_secondary)


func _draw_leg(origin: Vector2, lean: float, swing: float, tint: Color, far: bool) -> void:
	var hip := origin + Vector2((-5.0 if far else 5.0) * _facing, HIP_Y).rotated(lean)
	var knee := hip + Vector2(swing * 7.0, 8.5)
	var foot := knee + Vector2(swing * 9.5, 9.0 - absf(swing) * 2.0)
	var color := tint.darkened(0.68 if far else 0.48)
	draw_line(hip, knee, color, 7.0, true)
	draw_line(knee, foot, color, 6.4, true)
	# Boot: a sole wedge rather than a stub, so the foot reads at a glance.
	var toe := foot + Vector2(4.5 * _facing, 0.5)
	draw_line(foot + Vector2(-1.5 * _facing, 0.0), toe,
		accent_secondary.darkened(0.28 if far else 0.1), 7.0, true)
	draw_line(foot + Vector2(-2.0 * _facing, 3.0), toe + Vector2(0.0, 3.0),
		Color(0.08, 0.09, 0.13), 2.4, true)


func _draw_arm(origin: Vector2, lean: float, swing: float, tint: Color, far: bool) -> void:
	var side := -1.0 if far else 1.0
	var shoulder := origin + Vector2(BODY_WIDTH * 0.92 * side, -BODY_HEIGHT * 0.35).rotated(lean)
	var elbow := shoulder + Vector2(swing * 5.0 + 2.0 * side, 7.0)
	var hand := elbow + Vector2(swing * 7.0 + 1.5 * side, 7.5)
	var color := tint.darkened(0.62 if far else 0.38)
	draw_line(shoulder, elbow, color, 6.0, true)
	draw_line(elbow, hand, color, 5.4, true)
	# Glove.
	draw_circle(hand, 3.8, accent_secondary.darkened(0.3 if far else 0.08))


## The near arm, which is also the sword arm. Outside a swing it just swings
## with the walk cycle; during one it drives the blade through its arc.
func _draw_sword_arm(origin: Vector2, lean: float, swing: float, tint: Color) -> void:
	if _slash_time <= 0.0:
		_draw_arm(origin, lean, -swing, tint, false)
		return

	var t := 1.0 - clampf(_slash_time / _slash_span, 0.0, 1.0)   # 0 -> 1 across the swing
	# Fast out of the wind-up, slow into the follow-through.
	var eased := 1.0 - pow(1.0 - t, 2.4)
	var base := _slash_dir.angle()
	var angle := base - _slash_sign * _slash_arc * 0.5 + _slash_sign * _slash_arc * eased
	if _slash_spin:
		angle = base + _slash_sign * TAU * eased

	var shoulder := origin + Vector2(BODY_WIDTH * 0.9, -BODY_HEIGHT * 0.35).rotated(lean)
	var reach := 17.0 + 6.0 * sin(eased * PI)
	var hand := shoulder + Vector2(cos(angle), sin(angle)) * reach
	var color := tint.darkened(0.34)
	draw_line(shoulder, shoulder.lerp(hand, 0.55), color, 6.0, true)
	draw_line(shoulder.lerp(hand, 0.55), hand, color, 5.4, true)
	draw_circle(hand, 3.8, accent_secondary)

	# The blade itself, reusing the icon geometry so the weapon in the hand and
	# the weapon in the HUD are unmistakably the same object. The icon points
	# up, hence the quarter turn.
	var fade := clampf(sin(clampf(t, 0.0, 1.0) * PI) * 1.6, 0.2, 1.0)
	draw_set_transform(hand + Vector2(cos(angle), sin(angle)) * 13.0, angle + PI * 0.5, Vector2.ONE)
	PowerArt.draw_katana(self, Vector2.ZERO, 16.0,
		Color(0.80, 0.88, 1.0, fade), Color(accent_secondary.r, accent_secondary.g, accent_secondary.b, fade),
		_phase)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 - _squash, 1.0 + _squash))


func _draw_head(origin: Vector2, lean: float, tint: Color) -> void:
	var head := origin + Vector2(0.0, -BODY_HEIGHT - HEAD_RADIUS * 0.55).rotated(lean * 0.6)
	var tilt := lean * 0.5

	# Hair mass behind the face, with a couple of loose strands that sway.
	_draw_hair_back(head, tilt)

	# Ears.
	for side in [-1.0, 1.0]:
		draw_circle(head + Vector2(side * HEAD_RADIUS * 0.94, HEAD_RADIUS * 0.06), 3.2,
			_skin.darkened(0.08))

	var skin := _skin
	if _hurt_flash > 0.0:
		skin = skin.lerp(Palette.DANGER, _hurt_flash * 0.55)
	if _dead:
		skin = skin.darkened(0.35)

	# Head shape: a slightly squared circle reads more like a face than a ball.
	var face := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		var r := HEAD_RADIUS * (1.0 - 0.06 * cos(a * 2.0))
		face.append(head + Vector2(cos(a) * r, sin(a) * r * 0.98))
	draw_colored_polygon(face, skin)

	_draw_face(head, skin)
	_draw_hair_front(head, tilt)

	# Headband in the secondary accent — the readable "operative" cue, and what
	# keeps the silhouette distinct from the enemy shapes.
	draw_line(head + Vector2(-HEAD_RADIUS * 0.95, -HEAD_RADIUS * 0.42),
		head + Vector2(HEAD_RADIUS * 0.95, -HEAD_RADIUS * 0.46),
		accent_secondary, 4.2, true)
	draw_circle(head + Vector2(HEAD_RADIUS * 0.30 * _facing, -HEAD_RADIUS * 0.44), 3.0,
		Color(1, 1, 1, 0.85))


func _draw_hair_back(head: Vector2, tilt: float) -> void:
	var shell := PackedVector2Array()
	for i in 16:
		var a := PI * 0.92 + PI * 1.16 * float(i) / 15.0
		shell.append(head + Vector2(cos(a), sin(a)).rotated(tilt) * HEAD_RADIUS * 1.12)
	# Close the shape off the ends of the arc rather than at fixed points: a
	# tilted head would otherwise fold the outline back through itself.
	var drop := Vector2(0.0, HEAD_RADIUS * 0.52).rotated(tilt)
	shell.append(shell[shell.size() - 1] + drop)
	shell.append(shell[0] + drop)
	draw_colored_polygon(shell, _hair)

	# Two strands that lag behind the head as it moves.
	var sway := sin(_phase * 3.4) * 2.0 + _lean * 12.0
	for side in [-1.0, 1.0]:
		var root := head + Vector2(side * HEAD_RADIUS * 0.92, -HEAD_RADIUS * 0.1)
		var tip := root + Vector2(side * 4.0 - sway, HEAD_RADIUS * 0.95)
		draw_line(root, tip, _hair, 5.0, true)
		draw_line(root, tip, _hair.lightened(0.12), 2.0, true)


func _draw_hair_front(head: Vector2, tilt: float) -> void:
	# Bangs: overlapping wedges across the brow, uneven so it looks cut, not drawn.
	var widths := [0.95, 0.55, 0.15, -0.3, -0.75]
	for i in widths.size():
		var x: float = float(widths[i]) * HEAD_RADIUS
		var drop := HEAD_RADIUS * (0.30 + 0.16 * float((i * 3) % 4) / 3.0)
		var wedge := PackedVector2Array([
			head + Vector2(x - HEAD_RADIUS * 0.30, -HEAD_RADIUS * 0.72).rotated(tilt * 0.4),
			head + Vector2(x + HEAD_RADIUS * 0.34, -HEAD_RADIUS * 0.78).rotated(tilt * 0.4),
			head + Vector2(x + HEAD_RADIUS * 0.16, -HEAD_RADIUS * 0.72 + drop).rotated(tilt * 0.4),
		])
		draw_colored_polygon(wedge, _hair)
	# Highlight band catching the light.
	draw_arc(head + Vector2(0.0, -HEAD_RADIUS * 0.20), HEAD_RADIUS * 0.78,
		PI * 1.18, PI * 1.62, 8, _hair.lightened(0.30), 3.0, true)


func _draw_face(head: Vector2, skin: Color) -> void:
	var eye_y := head.y + HEAD_RADIUS * 0.06
	var look := Vector2(_facing * HEAD_RADIUS * 0.11, 0.0)
	var ink := Color(0.08, 0.10, 0.17)

	if _dead:
		for side in [-1.0, 1.0]:
			var e := Vector2(head.x + side * HEAD_RADIUS * 0.38, eye_y)
			draw_line(e - Vector2(3.6, 3.6), e + Vector2(3.6, 3.6), ink, 2.6, true)
			draw_line(e - Vector2(3.6, -3.6), e + Vector2(3.6, -3.6), ink, 2.6, true)
		return

	var hurt := _hurt_flash > 0.25
	var open := 1.0 if _blink <= 0.0 else 0.15
	for side in [-1.0, 1.0]:
		var e := Vector2(head.x + side * HEAD_RADIUS * 0.38, eye_y) + look
		if hurt:
			# Screwed-up eyes while taking a hit.
			draw_line(e - Vector2(4.0, 2.6 * side), e + Vector2(4.0, 2.6 * side), ink, 2.8, true)
			continue
		if open < 0.5:
			draw_line(e - Vector2(4.0, 0.0), e + Vector2(4.0, 0.0), ink, 2.6, true)
			continue
		# Big chibi eye: dark iris, bright catchlight, soft lower rim.
		draw_circle(e, HEAD_RADIUS * 0.19, ink)
		draw_circle(e + Vector2(0.0, HEAD_RADIUS * 0.05), HEAD_RADIUS * 0.10,
			accent.lerp(Color.WHITE, 0.25))
		draw_circle(e + Vector2(-1.4, -1.8), HEAD_RADIUS * 0.07, Color(1, 1, 1, 0.95))
		# Brow, angled by mood.
		var brow_y := eye_y - HEAD_RADIUS * 0.30
		draw_line(Vector2(e.x - 4.4, brow_y + (1.2 if side < 0.0 else 0.0)),
			Vector2(e.x + 4.4, brow_y + (0.0 if side < 0.0 else 1.2)), _hair, 2.4, true)

	# Cheeks and mouth.
	for side in [-1.0, 1.0]:
		draw_circle(Vector2(head.x + side * HEAD_RADIUS * 0.66, eye_y + HEAD_RADIUS * 0.24),
			HEAD_RADIUS * 0.13, Color(1.0, 0.55, 0.55, 0.22))
	var mouth := Vector2(head.x + look.x * 0.5, eye_y + HEAD_RADIUS * 0.44)
	if hurt:
		draw_colored_polygon(PackedVector2Array([
			mouth + Vector2(-3.2, 0.0), mouth + Vector2(3.2, 0.0), mouth + Vector2(0.0, 4.2)]), ink)
	elif _slash_time > 0.0:
		# A clenched, determined line while swinging.
		draw_line(mouth - Vector2(2.8, 0.0), mouth + Vector2(2.8, 0.0), ink, 1.8, true)
	else:
		draw_arc(mouth - Vector2(0.0, 2.0), 3.4, PI * 0.15, PI * 0.85, 6, ink, 2.0, true)

	# Nose: a single dot, which is all a chibi face needs.
	draw_circle(Vector2(head.x + look.x, eye_y + HEAD_RADIUS * 0.24), 1.3,
		skin.darkened(0.22))


## The knot the scarf is tied in, sitting on the collarbone. It is deliberately
## small: anything bigger swallows the chin and the character loses its face.
func _draw_collar(origin: Vector2, lean: float) -> void:
	var neck := origin + Vector2(0.0, -BODY_HEIGHT * 0.46).rotated(lean)
	var wrap := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		wrap.append(neck + Vector2(cos(a) * 9.5, sin(a) * 4.6).rotated(lean))
	var shade := accent_secondary if not _dead else accent_secondary.darkened(0.5)
	draw_colored_polygon(wrap, shade)
	draw_line(neck + Vector2(-8.0, 1.6).rotated(lean), neck + Vector2(8.0, 1.6).rotated(lean),
		shade.darkened(0.35), 2.0, true)
	if _hurt_flash > 0.0:
		draw_colored_polygon(wrap, Color(1, 1, 1, 0.25 * _hurt_flash))


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
