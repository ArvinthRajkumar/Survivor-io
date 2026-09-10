class_name EnemyArt
extends RefCounted
## Procedural creature sprites for the swarm.
##
## This replaced flat polygons — a triangle, a hexagon, a five-pointed star —
## which told the player nothing except "hostile". Twenty-eight enemies do not
## get twenty-eight bespoke drawings, though: they get six body plans, each with
## its own silhouette, gait and way of attacking, and the roster picks one per
## archetype. Six is enough that a player can tell a charger from a shooter
## before it reaches them, which is the only thing the art has to achieve.
##
## Everything is drawn front-facing and flipped horizontally, so the swarm reads
## as characters like the operative does rather than as shapes seen from
## overhead. Everything scales from `r`, so one function serves a swarmling and
## a boss at four times the size.
##
## Frame budget: a run can have 260 of these on screen. Enemy.gd redraws each of
## them at roughly 11Hz on a stagger rather than every frame — a limb cycle at
## that rate is what hand-drawn animation runs at anyway, and it cuts the redraw
## cost by most of an order of magnitude.

## Body plans. The ids match EnemyData.shape, which is what the .tres files on
## disk already store, so the roster did not have to be re-authored.
enum Body { SCUTTLER, SENTRY, BRUTE, WISP, OCULAR, MAW }

## What the creature is doing. Enemy.gd sets these; state_t runs 0 to 1 across
## the action.
enum State { MOVE, WINDUP, STRIKE, SHOOT }


static func draw_body(ci: CanvasItem, body: int, r: float, fill: Color, outline: Color,
		accent: Color, phase: float, state: int, state_t: float, flip: bool) -> void:
	var dir := -1.0 if flip else 1.0
	match body:
		Body.SCUTTLER:
			_scuttler(ci, r, fill, outline, accent, phase, state, state_t, dir)
		Body.SENTRY:
			_sentry(ci, r, fill, outline, accent, phase, state, state_t, dir)
		Body.BRUTE:
			_brute(ci, r, fill, outline, accent, phase, state, state_t, dir)
		Body.WISP:
			_wisp(ci, r, fill, outline, accent, phase, state, state_t, dir)
		Body.OCULAR:
			_ocular(ci, r, fill, outline, accent, phase, state, state_t, dir)
		_:
			_maw(ci, r, fill, outline, accent, phase, state, state_t, dir)


# --- Shared parts -----------------------------------------------------------

static func _blob(r: float, squash: float, points: int = 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points:
		var a := TAU * float(i) / float(points)
		pts.append(Vector2(cos(a) * r, sin(a) * r * squash))
	return pts


static func _shape(ci: CanvasItem, pts: PackedVector2Array, offset: Vector2,
		fill: Color, outline: Color, width: float) -> void:
	var moved := PackedVector2Array()
	for p in pts:
		moved.append(p + offset)
	Draw2D.neon_polygon(ci, moved, fill, outline, width)


## One glowing eye with a pupil. Every body plan has eyes in some form; giving
## them a shared function is what keeps the swarm looking related.
static func _eye(ci: CanvasItem, at: Vector2, size: float, accent: Color,
		angry: float, dir: float) -> void:
	ci.draw_circle(at, size, Color(0.04, 0.04, 0.08, 0.9))
	ci.draw_circle(at, size * 0.72, Color(accent.r, accent.g, accent.b, 0.55 + 0.45 * angry))
	# Pupil and catchlight are sub-pixel on a small enemy: two draw calls each,
	# on every one of a couple of hundred bodies, for nothing visible.
	if size < 5.0:
		return
	ci.draw_circle(at + Vector2(dir * size * 0.20, 0.0), size * 0.32, Color(0.03, 0.02, 0.05))
	ci.draw_circle(at + Vector2(-dir * size * 0.22, -size * 0.26), size * 0.18,
		Color(1, 1, 1, 0.75))


## How far through an attack the creature is, as a lunge offset. Wind-up pulls
## back, the strike throws forward, everything else sits at rest.
static func _lunge(state: int, t: float, r: float) -> float:
	match state:
		State.WINDUP:
			return -r * 0.30 * t
		State.STRIKE:
			# Fast out, slow back: the shape of an actual swing.
			return r * 0.62 * sin(minf(1.0, t * 1.4) * PI * 0.9)
		State.SHOOT:
			return -r * 0.22 * (1.0 - t)
	return 0.0


# --- Body plans -------------------------------------------------------------

## Low six-legged insect. The fastest, flimsiest things in the game, so the
## silhouette is all legs and almost no body.
static func _scuttler(ci: CanvasItem, r: float, fill: Color, outline: Color,
		accent: Color, phase: float, state: int, t: float, dir: float) -> void:
	var push := _lunge(state, t, r) * dir
	var body_c := Vector2(push, -r * 0.06)
	var width := maxf(1.2, r * 0.11)
	# Legs first so they sit behind the shell. Two banks of three, half a cycle
	# apart, which is what makes the gait read as skittering rather than hopping.
	# Twelve segments in one draw_multiline rather than six polylines. Limbs are
	# most of the cost of an animated body and a run can have 260 of them, so
	# every body plan below batches its limbs the same way.
	var legs := PackedVector2Array()
	for side in [-1.0, 1.0]:
		for i in 3:
			var swing := sin(phase * 9.0 + float(i) * 1.1 + (0.0 if side > 0.0 else PI))
			var root := body_c + Vector2((float(i) - 1.0) * r * 0.34, r * 0.10)
			var knee := root + Vector2(side * r * 0.42, r * 0.30 + swing * r * 0.10)
			var foot := knee + Vector2(side * r * 0.28, r * 0.44 - swing * r * 0.18)
			legs.append(root)
			legs.append(knee)
			legs.append(knee)
			legs.append(foot)
	ci.draw_multiline(legs, outline, width)
	_shape(ci, _blob(r * 0.68, 0.62), body_c, fill, outline, maxf(1.5, r * 0.14))
	# Carapace ridge.
	ci.draw_line(body_c + Vector2(-r * 0.46, -r * 0.10), body_c + Vector2(r * 0.46, -r * 0.10),
		outline.lightened(0.25), maxf(1.0, r * 0.08), true)
	_eye(ci, body_c + Vector2(dir * r * 0.30, -r * 0.10), r * 0.17, accent,
		1.0 if state != State.MOVE else 0.4, dir)
	# Mandibles, opening as it strikes.
	var gape := (0.5 + 0.5 * t) if state == State.STRIKE else 0.35
	var jaws := PackedVector2Array()
	for side2 in [-1.0, 1.0]:
		var jaw := body_c + Vector2(dir * r * 0.62, side2 * r * 0.10 * gape)
		jaws.append(body_c + Vector2(dir * r * 0.40, 0.0))
		jaws.append(jaw + Vector2(dir * r * 0.22, side2 * r * 0.22 * gape))
	ci.draw_multiline(jaws, accent, width)


## Armoured emplacement on stubby legs, with a shoulder cannon. The one body
## plan that visibly aims, so a player can tell it is about to be shot at.
static func _sentry(ci: CanvasItem, r: float, fill: Color, outline: Color,
		accent: Color, phase: float, state: int, t: float, dir: float) -> void:
	var recoil := (_lunge(state, t, r) if state == State.SHOOT else 0.0) * dir
	var bob := sin(phase * 5.0) * r * 0.04
	var width := maxf(1.5, r * 0.13)
	var legs := PackedVector2Array()
	for side in [-1.0, 1.0]:
		var step := sin(phase * 5.0 + (0.0 if side > 0.0 else PI)) * r * 0.10
		legs.append(Vector2(side * r * 0.30, r * 0.40))
		legs.append(Vector2(side * r * 0.34, r * 0.92 + step))
	ci.draw_multiline(legs, outline, width * 1.3)
	# Chassis: a wedge, wider at the shoulders than the base.
	_shape(ci, PackedVector2Array([
		Vector2(-r * 0.62, -r * 0.44),
		Vector2(r * 0.62, -r * 0.44),
		Vector2(r * 0.48, r * 0.46),
		Vector2(-r * 0.48, r * 0.46),
	]), Vector2(0.0, bob), fill, outline, maxf(1.5, r * 0.14))
	# Cannon: pulled back while charging, thrown forward on the shot.
	var muzzle := Vector2(dir * (r * 0.98 + recoil), -r * 0.22 + bob)
	ci.draw_line(Vector2(dir * r * 0.30, -r * 0.22 + bob), muzzle,
		outline.lightened(0.15), width * 1.5, true)
	if state == State.SHOOT:
		var flash := 1.0 - t
		ci.draw_circle(muzzle, r * 0.28 * flash, Color(accent.r, accent.g, accent.b, 0.8 * flash))
		ci.draw_circle(muzzle, r * 0.14 * flash, Color(1, 1, 1, flash))
	_shape(ci, _blob(r * 0.34, 0.86, 8), Vector2(0.0, -r * 0.56 + bob), fill.lightened(0.10),
		outline, maxf(1.2, r * 0.10))
	_eye(ci, Vector2(dir * r * 0.12, -r * 0.56 + bob), r * 0.15, accent,
		1.0 if state == State.SHOOT else 0.5, dir)


## Heavyweight. Slow, wide, top-heavy, with arms it winds all the way back
## before it swings.
static func _brute(ci: CanvasItem, r: float, fill: Color, outline: Color,
		accent: Color, phase: float, state: int, t: float, dir: float) -> void:
	var push := _lunge(state, t, r) * dir
	var stomp := absf(sin(phase * 3.2))
	var width := maxf(1.5, r * 0.15)
	for side in [-1.0, 1.0]:
		var lift := (stomp if side > 0.0 else 1.0 - stomp) * r * 0.14
		_shape(ci, PackedVector2Array([
			Vector2(side * r * 0.14, r * 0.20),
			Vector2(side * r * 0.56, r * 0.24),
			Vector2(side * r * 0.50, r * 0.96 - lift),
			Vector2(side * r * 0.10, r * 0.92 - lift),
		]), Vector2.ZERO, fill.darkened(0.20), outline, width * 0.8)
	# Torso.
	_shape(ci, PackedVector2Array([
		Vector2(-r * 0.78, -r * 0.52),
		Vector2(r * 0.78, -r * 0.52),
		Vector2(r * 0.54, r * 0.34),
		Vector2(-r * 0.54, r * 0.34),
	]), Vector2(push * 0.4, 0.0), fill, outline, maxf(2.0, r * 0.16))
	# Arms. The near one carries the swing; the far one counterweights it.
	for side2 in [-1.0, 1.0]:
		var lead: bool = (side2 > 0.0) == (dir > 0.0)
		var reach := push * (1.0 if lead else -0.3)
		var shoulder := Vector2(side2 * r * 0.74, -r * 0.30)
		var fist := shoulder + Vector2(side2 * r * 0.30 + reach, r * 0.62 - absf(reach) * 0.5)
		ci.draw_line(shoulder, fist, outline, width * 1.6, true)
		ci.draw_circle(fist, r * 0.24, fill.darkened(0.10))
		Draw2D.ring(ci, fist, r * 0.24, outline, maxf(1.0, r * 0.08))
	# Head sunk between the shoulders.
	_shape(ci, _blob(r * 0.34, 0.88, 8), Vector2(push * 0.5, -r * 0.62), fill.lightened(0.12),
		outline, maxf(1.2, r * 0.10))
	_eye(ci, Vector2(push * 0.5 + dir * r * 0.10, -r * 0.62), r * 0.14, accent,
		1.0 if state != State.MOVE else 0.35, dir)


## Floating body with trailing tendrils. Never touches the ground, so its
## motion is a bob and a drift rather than a gait.
static func _wisp(ci: CanvasItem, r: float, fill: Color, outline: Color,
		accent: Color, phase: float, state: int, t: float, dir: float) -> void:
	var push := _lunge(state, t, r) * dir
	var bob := sin(phase * 2.6) * r * 0.14
	var centre := Vector2(push, bob - r * 0.14)
	# Tendrils, drawn first so the bell sits over their roots.
	var tendrils := PackedVector2Array()
	for i in 5:
		var x := (float(i) - 2.0) * r * 0.26
		var sway := sin(phase * 3.4 + float(i) * 0.9) * r * 0.16
		var root := centre + Vector2(x * 0.8, r * 0.22)
		var mid := centre + Vector2(x + sway * 0.5, r * 0.48)
		var tip := centre + Vector2(x + sway, r * (0.72 + 0.10 * float(i % 2)))
		tendrils.append(root)
		tendrils.append(mid)
		tendrils.append(mid)
		tendrils.append(tip)
	ci.draw_multiline(tendrils, Color(outline.r, outline.g, outline.b, 0.75), maxf(1.0, r * 0.09))
	# Bell.
	var bell := PackedVector2Array()
	for i in 14:
		var a := PI + PI * float(i) / 13.0
		bell.append(Vector2(cos(a) * r * 0.72, sin(a) * r * 0.66))
	bell.append(Vector2(r * 0.62, r * 0.24))
	bell.append(Vector2(-r * 0.62, r * 0.24))
	_shape(ci, bell, centre, fill, outline, maxf(1.5, r * 0.13))
	Draw2D.glow_circle(ci, centre, r * 0.44, accent, 2)
	_eye(ci, centre + Vector2(dir * r * 0.16, -r * 0.14), r * 0.19, accent,
		1.0 if state != State.MOVE else 0.5, dir)


## A single eye held inside a cage of plates. Unsettling rather than animal,
## which is what the sectors' stranger enemies want.
static func _ocular(ci: CanvasItem, r: float, fill: Color, outline: Color,
		accent: Color, phase: float, state: int, t: float, dir: float) -> void:
	var push := _lunge(state, t, r) * dir
	var centre := Vector2(push, sin(phase * 2.0) * r * 0.10)
	# Plates orbiting the eye, drawn behind and in front so it reads as a cage.
	var spin := phase * (2.6 if state == State.MOVE else 5.0)
	for i in 6:
		var a := TAU * float(i) / 6.0 + spin
		var at := centre + Vector2(cos(a), sin(a)) * r * 0.86
		var out := Vector2(cos(a), sin(a))
		var side := Vector2(-out.y, out.x)
		Draw2D.neon_polygon(ci, PackedVector2Array([
			at - side * r * 0.20,
			at + out * r * 0.26,
			at + side * r * 0.20,
		]), fill.darkened(0.15), outline, maxf(1.0, r * 0.08))
	_shape(ci, _blob(r * 0.62, 0.96), centre, fill, outline, maxf(1.5, r * 0.13))
	var glare: float = 1.0 if state != State.MOVE else 0.45
	_eye(ci, centre + Vector2(dir * r * 0.10, 0.0), r * 0.40, accent, glare, dir)
	# The iris flares as it winds up, which is the only warning it gives.
	if state == State.WINDUP or state == State.SHOOT:
		Draw2D.ring(ci, centre, r * (0.66 + 0.34 * t),
			Color(accent.r, accent.g, accent.b, 0.55 * (1.0 - t)), maxf(1.0, r * 0.07))


## Four-legged jaw. Everything about it points forward: it is the body plan for
## the things that run you down.
static func _maw(ci: CanvasItem, r: float, fill: Color, outline: Color,
		accent: Color, phase: float, state: int, t: float, dir: float) -> void:
	var push := _lunge(state, t, r) * dir
	var width := maxf(1.2, r * 0.12)
	# Four legs in a two-beat gait.
	var legs := PackedVector2Array()
	for i in 4:
		var front: bool = i < 2
		var side := 1.0 if (i % 2) == 0 else -1.0
		var swing := sin(phase * 7.5 + (0.0 if front == (side > 0.0) else PI))
		var hip := Vector2(dir * (r * 0.34 if front else -r * 0.40), r * 0.16)
		var knee := hip + Vector2(side * r * 0.16, r * 0.40)
		var foot := hip + Vector2(swing * r * 0.30 + side * r * 0.10, r * 0.74)
		legs.append(hip)
		legs.append(knee)
		legs.append(knee)
		legs.append(foot)
	ci.draw_multiline(legs, outline, width)
	# Body, lower at the shoulders than the haunches.
	_shape(ci, PackedVector2Array([
		Vector2(dir * r * 0.72 + push, -r * 0.30),
		Vector2(-dir * r * 0.66, -r * 0.46),
		Vector2(-dir * r * 0.86, r * 0.16),
		Vector2(dir * r * 0.62 + push, r * 0.26),
	]), Vector2.ZERO, fill, outline, maxf(1.5, r * 0.14))
	# Tail.
	var tail_sway := sin(phase * 4.0) * r * 0.24
	ci.draw_polyline(PackedVector2Array([
		Vector2(-dir * r * 0.80, -r * 0.16),
		Vector2(-dir * r * 1.10, -r * 0.10 + tail_sway * 0.5),
		Vector2(-dir * r * 1.34, -r * 0.34 + tail_sway),
	]), outline, width, true)
	# Head and jaws. The gape is the attack: closed while running, wide open on
	# the bite.
	var head := Vector2(dir * (r * 0.92 + push * 1.2), -r * 0.26)
	var gape: float = 0.12
	if state == State.WINDUP:
		gape = 0.12 + 0.5 * t
	elif state == State.STRIKE:
		gape = 0.72 * (1.0 - t)
	_shape(ci, PackedVector2Array([
		head + Vector2(-dir * r * 0.30, -r * 0.22),
		head + Vector2(dir * r * 0.34, -r * 0.16 - r * gape),
		head + Vector2(dir * r * 0.36, r * 0.02),
		head + Vector2(-dir * r * 0.28, r * 0.10),
	]), Vector2.ZERO, fill.lightened(0.10), outline, maxf(1.2, r * 0.11))
	_shape(ci, PackedVector2Array([
		head + Vector2(-dir * r * 0.26, r * 0.06),
		head + Vector2(dir * r * 0.34, r * 0.10 + r * gape),
		head + Vector2(-dir * r * 0.20, r * 0.24),
	]), Vector2.ZERO, fill.darkened(0.15), outline, maxf(1.2, r * 0.10))
	# Teeth, visible only when the jaws are actually open.
	if gape > 0.25:
		var teeth := PackedVector2Array()
		for i in 3:
			var x := dir * (r * 0.02 + float(i) * r * 0.13)
			teeth.append(head + Vector2(x, -r * 0.10 - r * gape * 0.6))
			teeth.append(head + Vector2(x, -r * 0.10 - r * gape * 0.2))
		ci.draw_multiline(teeth, Color(1, 1, 1, 0.85), maxf(1.0, r * 0.05))
	_eye(ci, head + Vector2(-dir * r * 0.06, -r * 0.14), r * 0.14, accent,
		1.0 if state != State.MOVE else 0.4, dir)
