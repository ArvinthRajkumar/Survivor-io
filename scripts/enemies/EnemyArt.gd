class_name EnemyArt
extends RefCounted
## Procedural creature art for the swarm — the source the sprite atlas is baked
## from, not something the game draws at runtime.
##
## Twenty-eight enemies share six body plans. Six is enough that a charger can be
## told from a shooter before it arrives, which is the only thing the art has to
## achieve; twenty-eight bespoke creatures would not be maintainable and would
## read no better at 20px.
##
## ## Why this is baked
##
## These used to be drawn live, every enemy every frame. That was wrong twice
## over: a body is 7-18 draw commands and the renderer resubmits all of them
## every frame whether or not `_draw` re-ran, so metering redraws to 11Hz saved
## only the GDScript and left the animation visibly choppy while still paying the
## full draw cost. Baked, a creature is one textured quad and the animation runs
## at the frame rate for free.
##
## ## The colour channels
##
## Nothing here is drawn in a literal colour. Every element is a *tone* of one of
## three roles — body, edge, accent — and at bake time those roles are the pure
## red, green and blue channels, so the atlas comes out as a mask that says which
## role owns each pixel and how light it is. `creature.gdshader` turns that back
## into an archetype's real colours at runtime, which is what lets one atlas
## serve a pale drifter and a magma spitter.
##
## The consequence for anyone editing this file: **never write a literal Color,
## and never call lightened()/darkened()**. Both leak across channels and the
## pixel comes back wearing the wrong colour. Use `_tone(role, level)`, where
## 0.5 is the colour as authored, 0 is black and 1 is white.

enum Body { SCUTTLER, SENTRY, BRUTE, WISP, OCULAR, MAW }
enum State { MOVE, WINDUP, STRIKE, SHOOT }

## Frames baked per state. A gait cycle reads as smooth from about eight.
const FRAMES_PER_STATE := 8
const STATE_COUNT := 4
const BODY_COUNT := 6
## Pixels per baked frame, and the radius the creature is drawn at inside one.
## The margin is what limbs and the strike lunge need: they reach about 1.5r.
const FRAME_SIZE := 128
const BAKE_RADIUS := 42.0

## Authored level for each tone. Named so the shading reads as intent rather
## than as arithmetic.
const SHADOW := 0.26
const DARK := 0.38
const BASE := 0.50
const LIT := 0.66
const RIM := 0.82
const HOT := 1.00


## A tone of one role. `level` 0.5 is the colour as authored; below darkens
## toward black, above lifts toward white.
static func _tone(role: Color, level: float, alpha: float = 1.0) -> Color:
	var k := level * 2.0
	return Color(role.r * k, role.g * k, role.b * k, alpha)


## The frame index for a body in a state, `t` running 0..1 through the action.
static func frame_index(body: int, state: int, t: float) -> int:
	var f := clampi(int(t * float(FRAMES_PER_STATE)), 0, FRAMES_PER_STATE - 1)
	return (body * STATE_COUNT + state) * FRAMES_PER_STATE + f


static func total_frames() -> int:
	return BODY_COUNT * STATE_COUNT * FRAMES_PER_STATE


## Draws one frame, centred on the canvas item's origin.
##
## `t` is progress through the state, 0..1. MOVE loops, so its t wraps; the other
## three play once.
static func draw_body(ci: CanvasItem, body: int, r: float, fill: Color, outline: Color,
		accent: Color, state: int, t: float) -> void:
	_contact_shadow(ci, r, body)
	match body:
		Body.SCUTTLER:
			_scuttler(ci, r, fill, outline, accent, state, t)
		Body.SENTRY:
			_sentry(ci, r, fill, outline, accent, state, t)
		Body.BRUTE:
			_brute(ci, r, fill, outline, accent, state, t)
		Body.WISP:
			_wisp(ci, r, fill, outline, accent, state, t)
		Body.OCULAR:
			_ocular(ci, r, fill, outline, accent, state, t)
		_:
			_maw(ci, r, fill, outline, accent, state, t)


# --- Shared construction ----------------------------------------------------

## Grounds the creature. Without it every body reads as floating, which is the
## single most common thing that makes 2D game art look unfinished.
static func _contact_shadow(ci: CanvasItem, r: float, body: int) -> void:
	if body == Body.WISP or body == Body.OCULAR:
		# These two do float; theirs is smaller and further down.
		_ellipse(ci, Vector2(0.0, r * 1.02), r * 0.44, r * 0.13, Color(0, 0, 0, 0.30))
		return
	_ellipse(ci, Vector2(0.0, r * 0.96), r * 0.72, r * 0.20, Color(0, 0, 0, 0.34))


static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, color: Color,
		points: int = 20) -> void:
	var pts := PackedVector2Array()
	for i in points:
		var a := TAU * float(i) / float(points)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, color)


static func _blob(rx: float, ry: float, points: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points:
		var a := TAU * float(i) / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _moved(pts: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + offset)
	return out


## A filled shape with an edge, and optionally the shading that gives it a
## volume: a shadow low inside it and a rim highlight along the top.
##
## The shading is drawn *inside* the silhouette - the polygon shrunk toward its
## own centroid and then offset - rather than as a shifted copy underneath.
## A shifted copy is hidden the moment the fill goes over it, which is a very
## easy way to spend two draw calls a part on nothing at all.
static func _part(ci: CanvasItem, pts: PackedVector2Array, fill: Color, level: float,
		edge: Color, width: float, shading: float = 0.0) -> void:
	if pts.size() < 3:
		return
	ci.draw_colored_polygon(pts, _tone(fill, level))
	if shading > 0.0:
		# Cel shading, cut with a horizontal line rather than built from
		# concentric insets. Light comes from above, so the lit band has to hug
		# the top edge and the shadow the bottom; an inset centred on the shape
		# reads as a blob sitting on it, because shading not attached to an edge
		# is not shading.
		var mid := _centroid(pts)
		var reach := _extent(pts, mid)
		var lit := _clip_above(pts, mid.y - reach * 0.22)
		if lit.size() >= 3:
			ci.draw_colored_polygon(lit, _tone(fill, minf(0.98, level + 0.18 * shading)))
		var shadow := _clip_below(pts, mid.y + reach * 0.30)
		if shadow.size() >= 3:
			ci.draw_colored_polygon(shadow, _tone(fill, maxf(0.04, level - 0.17 * shading)))
	if width <= 0.0:
		return
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, _tone(edge, BASE), width, true)


static func _centroid(pts: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in pts:
		sum += p
	return sum / float(pts.size())


## Rough radius of a shape, used to scale its shading with its size.
static func _extent(pts: PackedVector2Array, mid: Vector2) -> float:
	var most := 0.0
	for p in pts:
		most = maxf(most, p.distance_to(mid))
	return most


## Sutherland-Hodgman clip against a horizontal line, keeping the side named.
## Two of them are what cut a part into a lit band, a base and a shadow.
static func _clip(pts: PackedVector2Array, y: float, keep_above: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count := pts.size()
	for i in count:
		var a := pts[i]
		var b := pts[(i + 1) % count]
		var a_in := (a.y <= y) if keep_above else (a.y >= y)
		var b_in := (b.y <= y) if keep_above else (b.y >= y)
		if a_in:
			out.append(a)
		if a_in != b_in:
			var span := b.y - a.y
			if absf(span) > 0.0001:
				out.append(a.lerp(b, (y - a.y) / span))
	return out


static func _clip_above(pts: PackedVector2Array, y: float) -> PackedVector2Array:
	return _clip(pts, y, true)


static func _clip_below(pts: PackedVector2Array, y: float) -> PackedVector2Array:
	return _clip(pts, y, false)


static func _inset(pts: PackedVector2Array, mid: Vector2, scale: float,
		offset: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(mid + (p - mid) * scale + offset)
	return out


## One eye. Every body plan has one; sharing the construction is what makes the
## six read as the same bestiary.
static func _eye(ci: CanvasItem, at: Vector2, size: float, accent: Color,
		outline: Color, open: float) -> void:
	var lid := clampf(open, 0.12, 1.0)
	# Socket, so the eye sits in the head rather than on it.
	_ellipse(ci, at, size * 1.24, size * 1.24, _tone(outline, SHADOW))
	# Sclera in the accent colour, a dark pupil, and one small catchlight. The
	# catchlight is the only pure white on a creature: spend it anywhere else and
	# the whole thing goes chalky.
	_ellipse(ci, at, size, size * lid, _tone(accent, BASE))
	_ellipse(ci, at + Vector2(size * 0.16, 0.0), size * 0.46, size * 0.46 * lid,
		_tone(outline, SHADOW))
	if lid > 0.55:
		_ellipse(ci, at + Vector2(-size * 0.28, -size * 0.30), size * 0.22, size * 0.22,
			_tone(accent, HOT))


## Gathers limb segments so a whole set of legs is one draw command.
static func _limbs(ci: CanvasItem, segments: PackedVector2Array, edge: Color,
		level: float, width: float) -> void:
	if segments.is_empty():
		return
	ci.draw_multiline(segments, _tone(edge, level), width)


## Lunge offset for an attack. Wind-up coils back, the strike throws forward and
## settles; a shot recoils and recovers.
static func _lunge(state: int, t: float, r: float) -> float:
	match state:
		State.WINDUP:
			return -r * 0.34 * _ease_out(t)
		State.STRIKE:
			# Out fast, back slow, which is the shape of an actual swing.
			return r * 0.70 * sin(minf(1.0, t * 1.25) * PI * 0.92)
		State.SHOOT:
			return -r * 0.26 * (1.0 - _ease_out(t))
	return 0.0


static func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 2.0)


## Gait phase for a walk frame. MOVE loops over t; the attack states hold a
## planted stance instead of continuing to stride.
static func _gait(state: int, t: float) -> float:
	return t * TAU if state == State.MOVE else PI * 0.25


# --- Body plans -------------------------------------------------------------

## Low six-legged insect: all legs and almost no body. The fastest, flimsiest
## things in the game.
static func _scuttler(ci: CanvasItem, r: float, fill: Color, outline: Color,
		accent: Color, state: int, t: float) -> void:
	var push := _lunge(state, t, r)
	var g := _gait(state, t)
	var body_c := Vector2(push, -r * 0.04)
	var thin := maxf(1.0, r * 0.085)

	# Far legs, body, then near legs. Drawing both banks before the shell is
	# what makes an insect look like a shell with wires attached to it.
	_scuttler_legs(ci, r, outline, body_c, g, true, thin)

	# Abdomen behind the thorax gives the silhouette a waist.
	_part(ci, _moved(_blob(r * 0.46, r * 0.36), body_c + Vector2(-r * 0.50, r * 0.05)),
		fill, DARK, outline, thin, 0.6)

	var shell := _moved(_blob(r * 0.66, r * 0.44), body_c)
	_part(ci, shell, fill, BASE, outline, thin * 1.4, 1.0)
	# Segment seams across the carapace, following its curve.
	var seams := PackedVector2Array()
	for i in 3:
		var u := (float(i) - 1.0) * 0.32
		var x := body_c.x + u * r * 0.66
		var drop := r * 0.40 * sqrt(maxf(0.0, 1.0 - u * u * 1.4))
		seams.append(Vector2(x, body_c.y - drop))
		seams.append(Vector2(x, body_c.y + drop))
	_limbs(ci, seams, outline, DARK, maxf(1.0, r * 0.055))

	_scuttler_legs(ci, r, outline, body_c, g, false, thin)

	# Head, set forward and slightly lower than the thorax.
	var head := body_c + Vector2(r * 0.62, r * 0.02)
	_part(ci, _moved(_blob(r * 0.28, r * 0.24), head), fill, LIT, outline, thin * 1.1, 0.8)
	_eye(ci, head + Vector2(r * 0.06, -r * 0.04), r * 0.13, accent, outline, 1.0)
	# Antennae, which is most of what says "insect" at a glance.
	var feelers := PackedVector2Array()
	for side3 in [-1.0, 1.0]:
		var wave := sin(g + (0.0 if side3 > 0.0 else PI)) * r * 0.07
		feelers.append(head + Vector2(r * 0.10, -r * 0.16))
		feelers.append(head + Vector2(r * 0.44, -r * 0.44 + side3 * r * 0.14 + wave))
	_limbs(ci, feelers, outline, BASE, maxf(1.0, r * 0.045))

	# Mandibles: shut while running, wide on the bite.
	var gape := 0.30
	if state == State.WINDUP:
		gape = 0.30 + 0.55 * _ease_out(t)
	elif state == State.STRIKE:
		gape = 0.85 * (1.0 - _ease_out(t)) + 0.16
	var jaws := PackedVector2Array()
	for side2 in [-1.0, 1.0]:
		jaws.append(head + Vector2(r * 0.16, side2 * r * 0.06))
		jaws.append(head + Vector2(r * 0.46, side2 * r * 0.28 * gape))
	_limbs(ci, jaws, accent, LIT, maxf(1.0, r * 0.075))


## One bank of three legs, near or far. Segments are gathered so a whole bank is
## a single draw command.
static func _scuttler_legs(ci: CanvasItem, r: float, outline: Color, body_c: Vector2,
		g: float, far: bool, thin: float) -> void:
	var side := -1.0 if far else 1.0
	var segs := PackedVector2Array()
	for i in 3:
		var swing := sin(g + float(i) * 1.05 + (0.0 if far else PI))
		var root := body_c + Vector2((float(i) - 1.0) * r * 0.30, r * 0.04)
		# The knee sits above the body, so the legs arch the way an insect's do
		# rather than hanging off it.
		var knee := root + Vector2(side * r * 0.34, -r * 0.30 + swing * r * 0.05)
		var foot := knee + Vector2(side * r * 0.26 + swing * r * 0.18, r * 1.12)
		segs.append(root); segs.append(knee)
		segs.append(knee); segs.append(foot)
	_limbs(ci, segs, outline, DARK if far else BASE, thin * (0.9 if far else 1.2))


## Armoured emplacement on stubby legs with a shoulder cannon. The one body plan
## that visibly aims, so a player can tell it is about to be shot at.
static func _sentry(ci: CanvasItem, r: float, fill: Color, outline: Color,
		accent: Color, state: int, t: float) -> void:
	var recoil := _lunge(state, t, r) if state == State.SHOOT else 0.0
	var g := _gait(state, t)
	var bob := sin(g * 2.0) * r * 0.045
	var thick := maxf(1.2, r * 0.11)

	var legs := PackedVector2Array()
	for side in [-1.0, 1.0]:
		var step := sin(g * 2.0 + (0.0 if side > 0.0 else PI)) * r * 0.11
		legs.append(Vector2(side * r * 0.30, r * 0.36 + bob))
		legs.append(Vector2(side * r * 0.36, r * 0.90 + step))
	_limbs(ci, legs, outline, BASE, thick * 1.5)
	# Feet, so the legs end in something.
	for side2 in [-1.0, 1.0]:
		var step2 := sin(g * 2.0 + (0.0 if side2 > 0.0 else PI)) * r * 0.11
		_ellipse(ci, Vector2(side2 * r * 0.36, r * 0.92 + step2), r * 0.16, r * 0.09,
			_tone(outline, DARK))

	var chassis := PackedVector2Array([
		Vector2(-r * 0.64, -r * 0.42 + bob),
		Vector2(r * 0.64, -r * 0.42 + bob),
		Vector2(r * 0.50, r * 0.44 + bob),
		Vector2(-r * 0.50, r * 0.44 + bob),
	])
	_part(ci, chassis, fill, BASE, outline, thick * 1.2, 1.0)
	# Armour plate across the chest.
	_part(ci, PackedVector2Array([
		Vector2(-r * 0.40, -r * 0.24 + bob),
		Vector2(r * 0.40, -r * 0.24 + bob),
		Vector2(r * 0.32, r * 0.10 + bob),
		Vector2(-r * 0.32, r * 0.10 + bob),
	]), fill, DARK, outline, thick * 0.7)

	# Cannon. It tracks upward as the shot charges and kicks back on release.
	var aim := -0.18
	if state == State.WINDUP:
		aim = -0.18 - 0.12 * _ease_out(t)
	var pivot := Vector2(r * 0.24, -r * 0.20 + bob)
	var muzzle := pivot + Vector2(cos(aim), sin(aim)) * (r * 0.86 + recoil)
	var along := Vector2(cos(aim), sin(aim))
	_part(ci, _taper(pivot, muzzle, r * 0.17, r * 0.11), fill, LIT, outline, thick, 0.9)
	# Muzzle collar: a barrel that just stops looks unfinished at any size.
	_part(ci, _taper(muzzle - along * r * 0.12, muzzle + along * r * 0.05,
		r * 0.17, r * 0.17), fill, DARK, outline, thick * 0.8)
	_part(ci, _moved(_blob(r * 0.21, r * 0.21, 12), pivot), fill, DARK, outline, thick * 0.8)
	if state == State.SHOOT:
		var flash := 1.0 - _ease_out(t)
		_ellipse(ci, muzzle, r * 0.34 * flash, r * 0.34 * flash, _tone(accent, LIT, 0.85))
		_ellipse(ci, muzzle, r * 0.17 * flash, r * 0.17 * flash, _tone(accent, HOT))

	var head := Vector2(0.0, -r * 0.58 + bob)
	_part(ci, _moved(_blob(r * 0.32, r * 0.26), head), fill, LIT, outline, thick * 0.8)
	_eye(ci, head + Vector2(r * 0.06, 0.0), r * 0.13, accent, outline, 1.0)


## Heavyweight. Slow, wide, top-heavy, with arms it winds all the way back
## before it swings.
static func _brute(ci: CanvasItem, r: float, fill: Color, outline: Color,
		accent: Color, state: int, t: float) -> void:
	var push := _lunge(state, t, r)
	var g := _gait(state, t)
	var stomp := sin(g)
	var thick := maxf(1.2, r * 0.12)

	# Far arm behind the torso.
	_brute_arm(ci, r, fill, outline, -1.0, push * -0.35, thick, true)

	for side in [-1.0, 1.0]:
		var lift := (stomp if side > 0.0 else -stomp) * r * 0.10
		var leg := PackedVector2Array([
			Vector2(side * r * 0.12, r * 0.16),
			Vector2(side * r * 0.54, r * 0.22),
			Vector2(side * r * 0.48, r * 0.92 - lift),
			Vector2(side * r * 0.08, r * 0.88 - lift),
		])
		_part(ci, leg, fill, DARK, outline, thick * 0.8)
		_ellipse(ci, Vector2(side * r * 0.28, r * 0.92 - lift), r * 0.24, r * 0.11,
			_tone(outline, DARK))

	# Broad at the shoulders, pinched at the waist. The trapezoid this replaced
	# was the same width top and bottom, which is why it read as a crate.
	var lean := push * 0.3
	var torso := PackedVector2Array([
		Vector2(-r * 0.62 + lean, -r * 0.56),
		Vector2(-r * 0.86 + lean, -r * 0.34),
		Vector2(-r * 0.72 + lean, r * 0.06),
		Vector2(-r * 0.46 + lean, r * 0.32),
		Vector2(r * 0.46 + lean, r * 0.32),
		Vector2(r * 0.72 + lean, r * 0.06),
		Vector2(r * 0.86 + lean, -r * 0.34),
		Vector2(r * 0.62 + lean, -r * 0.56),
	])
	_part(ci, torso, fill, BASE, outline, thick * 1.4, 1.0)
	# Plates across the chest, which is what gives the mass a scale.
	# A single deep seam down the chest rather than rungs across it: fewer lines,
	# and it follows the taper instead of fighting it.
	_limbs(ci, PackedVector2Array([
		Vector2(lean, -r * 0.44), Vector2(lean, r * 0.24),
	]), outline, DARK, maxf(1.0, r * 0.07))

	# Neck, so the head is attached to something.
	_part(ci, _taper(Vector2(lean, -r * 0.50), Vector2(push * 0.45, -r * 0.66),
		r * 0.20, r * 0.16), fill, DARK, outline, thick * 0.6)

	var head := Vector2(push * 0.45, -r * 0.82)
	_part(ci, PackedVector2Array([
		head + Vector2(-r * 0.40, -r * 0.24),
		head + Vector2(r * 0.40, -r * 0.24),
		head + Vector2(r * 0.44, r * 0.12),
		head + Vector2(r * 0.24, r * 0.34),
		head + Vector2(-r * 0.24, r * 0.34),
		head + Vector2(-r * 0.44, r * 0.12),
	]), fill, LIT, outline, thick, 1.0)
	# Brow ridge: the whole personality of a heavy is in the scowl.
	_part(ci, PackedVector2Array([
		head + Vector2(-r * 0.36, -r * 0.06),
		head + Vector2(r * 0.36, -r * 0.14),
		head + Vector2(r * 0.32, r * 0.04),
		head + Vector2(-r * 0.32, r * 0.08),
	]), fill, SHADOW, outline, thick * 0.5)
	_eye(ci, head + Vector2(r * 0.10, r * 0.14), r * 0.13, accent, outline, 1.0)

	# Near arm carries the swing.
	_brute_arm(ci, r, fill, outline, 1.0, push, thick, false)


static func _brute_arm(ci: CanvasItem, r: float, fill: Color, outline: Color,
		side: float, reach: float, thick: float, far: bool) -> void:
	var level := DARK if far else BASE
	var shoulder := Vector2(side * r * 0.70, -r * 0.30)
	var elbow := shoulder + Vector2(side * r * 0.26 + reach * 0.55, r * 0.32)
	var fist := elbow + Vector2(side * r * 0.06 + reach * 0.85, r * 0.32 - absf(reach) * 0.40)
	# Upper arm and forearm as tapered quads, so the limb has a thickness that
	# changes along its length instead of the constant width a stroke gives.
	_part(ci, _taper(shoulder, elbow, r * 0.22, r * 0.17), fill, level, outline,
		thick * 0.7, 0.0 if far else 0.8)
	_part(ci, _taper(elbow, fist, r * 0.17, r * 0.13), fill, level, outline,
		thick * 0.7, 0.0 if far else 0.8)
	_part(ci, _moved(_blob(r * 0.24, r * 0.22, 12), shoulder), fill, level, outline,
		thick * 0.7, 0.0 if far else 0.9)
	# Fist: the heaviest thing on the silhouette, so it gets the most contrast.
	_part(ci, _moved(_blob(r * 0.27, r * 0.25, 12), fist), fill,
		LIT if not far else DARK, outline, thick, 0.0 if far else 1.0)


## A quad from `a` to `b`, `wa` wide at one end and `wb` at the other.
static func _taper(a: Vector2, b: Vector2, wa: float, wb: float) -> PackedVector2Array:
	var dir := (b - a)
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	var side := Vector2(-dir.y, dir.x).normalized()
	return PackedVector2Array([
		a + side * wa, b + side * wb, b - side * wb, a - side * wa,
	])


static func _closed(pts: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var out := _moved(pts, offset)
	out.append(out[0])
	return out


## Floating bell with trailing tendrils. Never touches the ground, so its motion
## is a bob and a pulse rather than a gait.
static func _wisp(ci: CanvasItem, r: float, fill: Color, outline: Color,
		accent: Color, state: int, t: float) -> void:
	var push := _lunge(state, t, r)
	var g := _gait(state, t)
	var bob := sin(g) * r * 0.13
	# The bell pulses like a jellyfish: it squashes as it pushes down.
	var squash := 1.0 + 0.12 * sin(g + PI * 0.5)
	var centre := Vector2(push, bob - r * 0.12)
	var thin := maxf(1.0, r * 0.08)

	var tendrils := PackedVector2Array()
	for i in 6:
		var x := (float(i) - 2.5) * r * 0.22
		var sway := sin(g + float(i) * 0.8) * r * 0.15
		var root := centre + Vector2(x * 0.78, r * 0.20)
		var mid := centre + Vector2(x + sway * 0.5, r * 0.48)
		var tip := centre + Vector2(x + sway, r * (0.74 + 0.09 * float(i % 2)))
		tendrils.append(root); tendrils.append(mid)
		tendrils.append(mid); tendrils.append(tip)
	_limbs(ci, tendrils, outline, DARK, thin * 1.1)

	# Bell: a dome with a scalloped hem.
	var bell := PackedVector2Array()
	for i in 15:
		var a := PI + PI * float(i) / 14.0
		bell.append(centre + Vector2(cos(a) * r * 0.74 / squash, sin(a) * r * 0.62 * squash))
	for i in 7:
		var u := 1.0 - float(i) / 6.0
		var x2 := lerpf(-r * 0.70, r * 0.70, u) / squash
		bell.append(centre + Vector2(x2, r * 0.20 + sin(u * PI * 3.0) * r * 0.06))
	_part(ci, bell, fill, BASE, outline, thin * 1.4, 1.0)

	# Inner glow, brightest at the top of the pulse.
	var glow := 0.5 + 0.5 * sin(g)
	_ellipse(ci, centre + Vector2(0.0, -r * 0.10), r * 0.34, r * 0.28,
		_tone(accent, DARK + 0.24 * glow, 0.75))
	_eye(ci, centre + Vector2(r * 0.12, -r * 0.12), r * 0.16, accent, outline,
		0.35 if state == State.WINDUP else 1.0)


## A single eye held inside a cage of plates. Unsettling rather than animal,
## which is what the stranger sectors want.
static func _ocular(ci: CanvasItem, r: float, fill: Color, outline: Color,
		accent: Color, state: int, t: float) -> void:
	var push := _lunge(state, t, r)
	var g := _gait(state, t)
	var centre := Vector2(push, sin(g) * r * 0.09)
	var thin := maxf(1.0, r * 0.075)
	# The cage spins faster the moment it means to do something.
	var spin := g * 0.5 + (t * 1.6 if state != State.MOVE else 0.0)
	# Plates behind, then the eye, then plates in front: that ordering is what
	# makes it read as a cage rather than a ring.
	for layer in 2:
		for i in 3:
			var a := TAU * (float(i) / 3.0 + 0.5 * float(layer)) + spin
			var out := Vector2(cos(a), sin(a))
			if (out.y > 0.0) != (layer == 0):
				continue
			_ocular_plate(ci, centre, out, r, fill, outline, DARK if layer == 0 else BASE, thin)

	var iris_open := 1.0
	if state == State.WINDUP:
		iris_open = 1.0 - 0.45 * _ease_out(t)
	elif state == State.STRIKE or state == State.SHOOT:
		iris_open = 0.55 + 0.45 * _ease_out(t)
	var ball := _moved(_blob(r * 0.60, r * 0.58), centre)
	_part(ci, ball, fill, BASE, outline, thin * 1.5, 1.0)
	_eye(ci, centre + Vector2(r * 0.06, 0.0), r * 0.38 * iris_open, accent, outline, 1.0)

	for i in 3:
		var a2 := TAU * (float(i) / 3.0 + 0.5) + spin
		var out2 := Vector2(cos(a2), sin(a2))
		if out2.y <= 0.0:
			continue
		_ocular_plate(ci, centre, out2, r, fill, outline, LIT, thin)


static func _ocular_plate(ci: CanvasItem, centre: Vector2, out: Vector2, r: float,
		fill: Color, outline: Color, level: float, thin: float) -> void:
	var at := centre + out * r * 0.88
	var side := Vector2(-out.y, out.x)
	_part(ci, PackedVector2Array([
		at - side * r * 0.22 - out * r * 0.10,
		at + out * r * 0.30,
		at + side * r * 0.22 - out * r * 0.10,
		at - out * r * 0.20,
	]), fill, level, outline, thin)


## Four-legged jaw. Everything about it points forward: the body plan for the
## things that run you down.
static func _maw(ci: CanvasItem, r: float, fill: Color, outline: Color,
		accent: Color, state: int, t: float) -> void:
	var push := _lunge(state, t, r)
	var g := _gait(state, t)
	var thin := maxf(1.0, r * 0.09)
	# The whole body dips as it gathers and extends as it lunges.
	var crouch := (r * 0.10 * _ease_out(t)) if state == State.WINDUP else 0.0

	# Far pair of legs, darker and behind.
	_maw_legs(ci, r, fill, outline, g, PI, DARK, thin * 0.9, crouch)

	# Chest high and forward, haunches high and back, belly slung between them:
	# the profile of something built to run, rather than the slab this was.
	var body := PackedVector2Array([
		Vector2(r * 0.66 + push, -r * 0.30 + crouch),
		Vector2(r * 0.30 + push, -r * 0.46 + crouch),
		Vector2(-r * 0.26, -r * 0.40 + crouch),
		Vector2(-r * 0.66, -r * 0.52 + crouch),
		Vector2(-r * 0.88, -r * 0.10 + crouch),
		Vector2(-r * 0.72, r * 0.22 + crouch),
		Vector2(-r * 0.20, r * 0.30 + crouch),
		Vector2(r * 0.34 + push, r * 0.26 + crouch),
		Vector2(r * 0.64 + push, r * 0.06 + crouch),
	])
	_part(ci, body, fill, BASE, outline, thin * 1.4, 1.0)
	# Spine ridge.
	var spine := PackedVector2Array()
	for i in 4:
		var u := float(i) / 3.0
		var x := lerpf(-r * 0.56, r * 0.44 + push, u)
		var y := lerpf(-r * 0.44, -r * 0.30, u) + crouch
		spine.append(Vector2(x, y))
		spine.append(Vector2(x + r * 0.06, y - r * 0.16 - sin(u * PI) * r * 0.06))
	_limbs(ci, spine, outline, LIT, thin)

	var tail_sway := sin(g) * r * 0.22
	ci.draw_polyline(PackedVector2Array([
		Vector2(-r * 0.80, -r * 0.12 + crouch),
		Vector2(-r * 1.06, -r * 0.06 + tail_sway * 0.5 + crouch),
		Vector2(-r * 1.32, -r * 0.30 + tail_sway + crouch),
	]), _tone(outline, BASE), thin * 1.2, true)

	# Near pair of legs, in front of the body.
	_maw_legs(ci, r, fill, outline, g, 0.0, BASE, thin, crouch)

	# Head and jaws.
	var head := Vector2(r * 0.90 + push * 1.15, -r * 0.24 + crouch * 0.6)
	var gape := 0.10
	if state == State.WINDUP:
		gape = 0.10 + 0.62 * _ease_out(t)
	elif state == State.STRIKE:
		gape = 0.78 * (1.0 - _ease_out(t)) + 0.08
	# Skull, then the two jaws hinged off it, so the head keeps a shape of its
	# own however wide the bite opens.
	_part(ci, PackedVector2Array([
		head + Vector2(-r * 0.36, -r * 0.30),
		head + Vector2(r * 0.06, -r * 0.34),
		head + Vector2(r * 0.16, -r * 0.06),
		head + Vector2(-r * 0.20, r * 0.16),
		head + Vector2(-r * 0.40, r * 0.02),
	]), fill, LIT, outline, thin * 1.2, 1.0)
	var upper := PackedVector2Array([
		head + Vector2(-r * 0.16, -r * 0.24),
		head + Vector2(r * 0.30, -r * 0.16 - r * gape),
		head + Vector2(r * 0.44, -r * 0.06 - r * gape),
		head + Vector2(r * 0.12, r * 0.04),
	])
	_part(ci, upper, fill, BASE, outline, thin * 1.1)
	_part(ci, PackedVector2Array([
		head + Vector2(-r * 0.14, r * 0.02),
		head + Vector2(r * 0.30, r * 0.10 + r * gape),
		head + Vector2(r * 0.40, r * 0.20 + r * gape),
		head + Vector2(-r * 0.06, r * 0.20),
	]), fill, DARK, outline, thin)
	if gape > 0.22:
		var teeth := PackedVector2Array()
		for i in 4:
			var x2 := r * (0.00 + float(i) * 0.11)
			teeth.append(head + Vector2(x2, -r * 0.08 - r * gape * 0.62))
			teeth.append(head + Vector2(x2, -r * 0.08 - r * gape * 0.18))
		_limbs(ci, teeth, accent, HOT, maxf(1.0, r * 0.045))
	_eye(ci, head + Vector2(-r * 0.08, -r * 0.14), r * 0.13, accent, outline, 1.0)


static func _maw_legs(ci: CanvasItem, r: float, fill: Color, outline: Color, g: float,
		phase_shift: float, level: float, width: float, crouch: float) -> void:
	for i in 2:
		var front: bool = i == 0
		var swing := sin(g + phase_shift + (0.0 if front else PI))
		var hip := Vector2(r * 0.34 if front else -r * 0.44, r * 0.14 + crouch)
		var knee := hip + Vector2(r * 0.10 * (1.0 if front else -1.0), r * 0.40)
		var foot := hip + Vector2(swing * r * 0.32, r * 0.80 - absf(swing) * r * 0.10)
		# Tapered quads rather than strokes: a stick leg on an animal that is
		# meant to look powerful undercuts the whole body.
		_part(ci, _taper(hip, knee, r * 0.16, r * 0.11), fill, level, outline, width * 0.7)
		_part(ci, _taper(knee, foot, r * 0.11, r * 0.07), fill, level, outline, width * 0.7)
		_ellipse(ci, foot, r * 0.12, r * 0.07, _tone(outline, level))
