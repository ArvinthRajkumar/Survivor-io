class_name Chibi
extends RefCounted
## Soft-form drawing kit for the chibi cast.
##
## The whole cast used to be built from flat `draw_colored_polygon` fills with
## hand-placed corners, and it looked it: straight edges, faceted silhouettes,
## no volume anywhere. Nothing in here draws a flat polygon.
##
## Two ideas do all the work.
##
##  1. **Nothing is a straight edge.** Shapes are authored as a handful of
##     control points and run through `smooth_closed` / `smooth_open`, which
##     fit a Catmull-Rom spline through them and resample it densely. A cheek,
##     a shoulder, a lock of hair is a curve, and it stays a curve when the
##     sprite is drawn at 200px.
##  2. **Nothing is a flat fill.** Every form is filled as an indexed triangle
##     fan with per-vertex colour — a bright pole pushed toward the light, the
##     rim falling off away from it. That is what turns an outline into a
##     volume, and it is free: one triangle array per form, no shader, no
##     texture, and it batches like any other canvas item.
##
## `LIGHT` is the house key light, up and to frame left, and every form takes
## its shading from it unless a caller says otherwise.

## Direction from a surface toward the key light — up and to frame left, unit
## length. Written out rather than normalised at load: a method call is not a
## constant expression.
const LIGHT := Vector2(-0.5608, -0.8279)


# --- Curves -----------------------------------------------------------------

## Catmull-Rom through `ctrl`, closed, resampled at `per_seg` points per
## control segment. Authoring is done with 6-10 control points; what gets drawn
## is 60-100, which is what keeps silhouettes from faceting.
static func smooth_closed(ctrl: PackedVector2Array, per_seg: int = 7) -> PackedVector2Array:
	var n := ctrl.size()
	var out := PackedVector2Array()
	if n < 3:
		return ctrl
	for i in n:
		var p0 := ctrl[(i - 1 + n) % n]
		var p1 := ctrl[i]
		var p2 := ctrl[(i + 1) % n]
		var p3 := ctrl[(i + 2) % n]
		for k in per_seg:
			out.append(_catmull(p0, p1, p2, p3, float(k) / float(per_seg)))
	return out


## Catmull-Rom through `ctrl`, open: the end points are kept and the tangents
## at them are mirrored, so a strand does not kink at its tip.
static func smooth_open(ctrl: PackedVector2Array, per_seg: int = 7) -> PackedVector2Array:
	var n := ctrl.size()
	var out := PackedVector2Array()
	if n < 3:
		return ctrl
	for i in range(n - 1):
		var p0 := ctrl[i - 1] if i > 0 else ctrl[0] * 2.0 - ctrl[1]
		var p1 := ctrl[i]
		var p2 := ctrl[i + 1]
		var p3 := ctrl[i + 2] if i + 2 < n else ctrl[n - 1] * 2.0 - ctrl[n - 2]
		for k in per_seg:
			out.append(_catmull(p0, p1, p2, p3, float(k) / float(per_seg)))
	out.append(ctrl[n - 1])
	return out


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


## An ellipse as a dense ring, ready to hand to `form`.
static func ellipse(c: Vector2, rx: float, ry: float, seg: int = 48,
		rot: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in seg:
		var a := TAU * float(i) / float(seg)
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return out


# --- Filled volumes ---------------------------------------------------------

## Fill a closed ring as a shaded volume.
##
## `pole` pushes the bright centre of the fan toward the light as a fraction of
## the form's radius; `lift` is how much brighter that pole is and `shade` how
## much darker the far rim goes. The defaults read as soft studio lighting on a
## rounded surface, which is the look of both reference sheets.
static func form(ci: CanvasItem, rim: PackedVector2Array, base: Color,
		lift: float = 0.26, shade: float = 0.30, pole: float = 0.30,
		light: Vector2 = LIGHT) -> void:
	var n := rim.size()
	if n < 3:
		return
	var centre := Vector2.ZERO
	for p in rim:
		centre += p
	centre /= float(n)
	var radius := 0.0
	for p in rim:
		radius += p.distance_to(centre)
	radius /= float(n)

	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	pts.append(centre + light * radius * pole)
	cols.append(base.lightened(lift))
	for p in rim:
		var away := clampf(0.5 - 0.5 * (p - centre).normalized().dot(light), 0.0, 1.0)
		pts.append(p)
		cols.append(base.darkened(shade * away))
	var idx := PackedInt32Array()
	for i in n:
		idx.append(0)
		idx.append(1 + i)
		idx.append(1 + (i + 1) % n)
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


## A flat-shaded ring, for the few places that want an even fill (a pupil, a
## gem) without losing the smooth outline.
static func flat(ci: CanvasItem, rim: PackedVector2Array, col: Color) -> void:
	if rim.size() >= 3:
		ci.draw_colored_polygon(rim, col)


## A shaded sphere. The workhorse: heads, shoulders, fists, boot toes.
static func ball(ci: CanvasItem, c: Vector2, r: float, base: Color,
		squash: Vector2 = Vector2.ONE, rot: float = 0.0,
		lift: float = 0.30, shade: float = 0.34) -> void:
	form(ci, ellipse(c, r * squash.x, r * squash.y, 40, rot), base, lift, shade, 0.38)


## A tapered capsule between two points — arms, legs, fingers, hair ropes.
## Built as one closed ring with round caps so the silhouette has no corner
## anywhere along it.
static func capsule(ci: CanvasItem, a: Vector2, b: Vector2, ra: float, rb: float,
		base: Color, lift: float = 0.24, shade: float = 0.32) -> void:
	var axis := b - a
	if axis.length() < 0.001:
		ball(ci, a, ra, base)
		return
	var n := axis.normalized()
	var perp := Vector2(-n.y, n.x)
	var rim := PackedVector2Array()
	var caps := 12
	for i in range(caps + 1):
		var t := PI * float(i) / float(caps)
		rim.append(a + (perp * cos(t) - n * sin(t)) * ra)
	for i in range(caps + 1):
		var t2 := PI * float(i) / float(caps)
		rim.append(b + (-perp * cos(t2) + n * sin(t2)) * rb)
	form(ci, rim, base, lift, shade, 0.34)


# --- Soft passes ------------------------------------------------------------

## Contact shadow / ambient occlusion: a filled ring that fades to nothing at
## its edge, so it never shows a hard boundary the way an alpha polygon does.
static func soft(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color,
		seg: int = 32) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	pts.append(c)
	cols.append(col)
	for i in seg:
		var a := TAU * float(i) / float(seg)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		cols.append(Color(col.r, col.g, col.b, 0.0))
	var idx := PackedInt32Array()
	for i in seg:
		idx.append(0)
		idx.append(1 + i)
		idx.append(1 + (i + 1) % seg)
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


## A crescent of light along part of a form's edge. Both reference sheets lean
## on this hard: it is what lifts a dark silhouette off a dark background.
static func rim_light(ci: CanvasItem, c: Vector2, rx: float, ry: float,
		from_a: float, to_a: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	var steps := 18
	for i in range(steps + 1):
		var a := lerpf(from_a, to_a, float(i) / float(steps))
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	var cols := PackedColorArray()
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var fade: float = sin(t * PI)
		cols.append(Color(col.r, col.g, col.b, col.a * fade))
	_ribbon(ci, pts, cols, width)


## A tapered, colour-per-vertex stroke. Used for rim light, hair gloss and
## lash lines, all of which look wrong as a constant-width line.
static func _ribbon(ci: CanvasItem, path: PackedVector2Array,
		cols: PackedColorArray, width: float) -> void:
	var n := path.size()
	if n < 2:
		return
	var pts := PackedVector2Array()
	var vc := PackedColorArray()
	for i in n:
		var tangent: Vector2
		if i == 0:
			tangent = path[1] - path[0]
		elif i == n - 1:
			tangent = path[n - 1] - path[n - 2]
		else:
			tangent = path[i + 1] - path[i - 1]
		var perp := Vector2(-tangent.y, tangent.x).normalized() * width * 0.5
		pts.append(path[i] + perp)
		pts.append(path[i] - perp)
		vc.append(cols[i])
		vc.append(cols[i])
	var idx := PackedInt32Array()
	for i in range(n - 1):
		var a := i * 2
		idx.append(a)
		idx.append(a + 1)
		idx.append(a + 2)
		idx.append(a + 1)
		idx.append(a + 3)
		idx.append(a + 2)
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, vc)


## A stroke that tapers to a point at both ends — hair strands, eyelashes,
## cloth folds. A constant-width line is the other half of why the old art
## looked like it was made of sticks.
static func taper(ci: CanvasItem, path: PackedVector2Array, col: Color,
		width: float, head: float = 0.15, tail: float = 1.0) -> void:
	var n := path.size()
	if n < 2:
		return
	var pts := PackedVector2Array()
	var vc := PackedColorArray()
	for i in n:
		var t := float(i) / float(n - 1)
		var w: float = width * lerpf(head, tail, sin(clampf(t, 0.0, 1.0) * PI))
		var tangent: Vector2
		if i == 0:
			tangent = path[1] - path[0]
		elif i == n - 1:
			tangent = path[n - 1] - path[n - 2]
		else:
			tangent = path[i + 1] - path[i - 1]
		var perp := Vector2(-tangent.y, tangent.x).normalized() * w * 0.5
		pts.append(path[i] + perp)
		pts.append(path[i] - perp)
		vc.append(col)
		vc.append(col)
	var idx := PackedInt32Array()
	for i in range(n - 1):
		var a := i * 2
		idx.append(a)
		idx.append(a + 1)
		idx.append(a + 2)
		idx.append(a + 1)
		idx.append(a + 3)
		idx.append(a + 2)
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, vc)


# --- Eyes -------------------------------------------------------------------

## One chibi eye, drawn the way both reference sheets draw them: a big almond
## sclera under a heavy lash line, an iris that is dark at the top and bright
## at the bottom where light bounces up into it, a black pupil, and two
## catchlights — a large one on the light side and a small one opposite.
##
## `flip` is +1 for the eye on frame right and -1 for the one on frame left; it
## mirrors the *shape* so the inner corner is always the one nearest the nose.
## Drawing both eyes from one unmirrored outline is a subtle thing to get wrong
## and an obvious thing to look at: one eye ends up almond and the other ends
## up wrong way round, and the face reads as lopsided without it being clear
## why. The catchlights deliberately do not mirror — the key light is in one
## place, so they sit on the same side of both eyes.
##
## `look` shifts the iris within the sclera; `open` closes the lid for blinks.
static func eye(ci: CanvasItem, c: Vector2, w: float, h: float, iris: Color,
		look: Vector2 = Vector2.ZERO, open: float = 1.0,
		lash: Color = Color(0.10, 0.07, 0.09), flip: float = 1.0) -> void:
	if open < 0.12:
		var shut := PackedVector2Array()
		for v in [Vector2(-1.02, 0.06), Vector2(-0.45, 0.26), Vector2(0.40, 0.14),
				Vector2(1.00, -0.06)]:
			shut.append(c + Vector2((v as Vector2).x * w * flip, (v as Vector2).y * h))
		taper(ci, smooth_open(shut, 6), lash, h * 0.34, 0.25, 1.0)
		return

	var hh := h * open
	var sclera := PackedVector2Array()
	for v in [Vector2(-1.00, 0.10), Vector2(-0.55, -0.80), Vector2(0.10, -1.00),
			Vector2(0.80, -0.55), Vector2(1.00, -0.02), Vector2(0.60, 0.72),
			Vector2(-0.10, 0.92), Vector2(-0.70, 0.55)]:
		sclera.append(c + Vector2((v as Vector2).x * w * flip, (v as Vector2).y * hh))
	form(ci, smooth_closed(sclera, 8), Color(0.995, 0.985, 0.975), 0.02, 0.14, 0.30)
	# Lid shadow across the top of the white — warm and shallow. Cool and deep,
	# it turns the whole eye grey and kills it.
	soft(ci, c + Vector2(0.0, -hh * 0.82), w * 0.92, hh * 0.50,
		Color(0.58, 0.44, 0.42, 0.34), 24)

	var eye_c := c + Vector2(look.x * w * 0.16, look.y * hh * 0.14)
	# The iris is an upright ellipse that fills the eye almost edge to edge.
	# Drawn as a small circle it leaves white all round and the eye reads as
	# startled rather than calm, which is the whole difference in expression.
	var irx := w * 0.82
	var iry := minf(hh * 1.00, irx * 1.28)
	form(ci, ellipse(eye_c, irx, iry, 36), iris.darkened(0.22), 0.02, 0.55, 0.60,
		Vector2(0.0, 1.0))
	form(ci, ellipse(eye_c + Vector2(0.0, iry * 0.30), irx * 0.72, iry * 0.58, 30),
		iris.lightened(0.36), 0.16, 0.28, 0.30, Vector2(0.0, 1.0))
	flat(ci, ellipse(eye_c + Vector2(0.0, -iry * 0.04), irx * 0.44, iry * 0.46, 28),
		Color(0.05, 0.03, 0.05))
	flat(ci, ellipse(eye_c + Vector2(-irx * 0.38, -iry * 0.42), irx * 0.30, iry * 0.30, 20),
		Color(1, 1, 1, 0.97))
	flat(ci, ellipse(eye_c + Vector2(irx * 0.36, iry * 0.36), irx * 0.15, iry * 0.13, 16),
		Color(1, 1, 1, 0.70))

	# Upper lash line: heavy, thickening toward the outer corner, with a short
	# flick. A long flick runs into the brow tail and the two become one bar.
	var lid := PackedVector2Array()
	for v in [Vector2(-1.02, 0.08), Vector2(-0.52, -0.84), Vector2(0.20, -1.02),
			Vector2(0.86, -0.60), Vector2(1.08, -0.30)]:
		lid.append(c + Vector2((v as Vector2).x * w * flip, (v as Vector2).y * hh))
	taper(ci, smooth_open(lid, 7), lash, h * 0.36, 0.28, 1.0)
	# Lower rim, much lighter, so the eye does not look outlined.
	var low := PackedVector2Array()
	for v in [Vector2(-0.72, 0.52), Vector2(-0.05, 0.88), Vector2(0.62, 0.58)]:
		low.append(c + Vector2((v as Vector2).x * w * flip, (v as Vector2).y * hh))
	taper(ci, smooth_open(low, 6), Color(lash.r, lash.g, lash.b, 0.40), h * 0.15, 0.30, 1.0)
