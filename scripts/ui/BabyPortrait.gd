class_name BabyPortrait
extends RefCounted
## Baby's portrait — a likeness, not a body plan.
##
## Every other operative is drawn by HeroPortrait's shared chibi construction,
## which is the right call for five characters who only have to be told apart
## from each other. Baby has to be recognisable as a specific person from a
## specific photograph, and that is a different job: the shared construction
## averages faces toward a template, which is exactly what destroys a likeness.
## So she gets her own geometry, front to back.
##
## What actually carries the resemblance, in the order a viewer uses it:
##
##  1. **The hair.** One heavy, glossy, near-black mass — swept back off a tall
##     forehead, widest well below the ears, falling in soft waves over the
##     front of both shoulders. It is much wider than her face and it is most of
##     the recognition on its own, which is also why it is the part that
##     survives being shrunk to a roster thumbnail. It has to read as a *dense*
##     mass with a sheen on it; the first attempt drew separated strands and a
##     ring of spikes around the crown, and stringy hair is a different person.
##  2. **The brows.** Strong, dark, near-straight with a shallow arch and a
##     clear gap, set low and close over the eyes.
##  3. **The bindi**, small and dark, sitting just above the brow line.
##  4. **Warm mid-brown skin** with a golden undertone, lit from frame left, and
##     no hard shading anywhere near the jaw — an outlined jaw reads as stubble
##     and instantly makes her a man.
##  5. **A long oval face** tapering to a soft, slightly pointed chin. Wide
##     cheekbones, narrow jaw.
##  6. **Almond eyes**, dark, level, looking straight out, with a heavy upper
##     lash line.
##  7. **A closed, faintly amused mouth** — not the open chibi smile the others
##     wear, which reads as a different personality.
##
## Everything scales from `hr`, so the same function draws the 40px HUD slot and
## the 150px roster card; detail that turns to mud below about 20px of head
## radius is dropped rather than drawn and lost.

const HAIR := Color(0.070, 0.058, 0.082)
const HAIR_MID := Color(0.135, 0.115, 0.155)
const HAIR_LIT := Color(0.255, 0.225, 0.280)
const SKIN := Color(0.800, 0.600, 0.450)
const SKIN_LIT := Color(0.855, 0.665, 0.510)
const SKIN_SHADE := Color(0.680, 0.480, 0.350)
const INK := Color(0.100, 0.070, 0.080)
const LIP := Color(0.700, 0.400, 0.400)
const GOLD := Color(1.000, 0.840, 0.440)
const CREAM := Color(0.950, 0.920, 0.850)

## Right half of the face outline, top of the forehead down to the chin. Long
## and narrow with the widest point high, at the cheekbone.
const PROFILE := [
	Vector2(0.00, -1.04), Vector2(0.40, -0.96), Vector2(0.68, -0.74),
	Vector2(0.80, -0.36), Vector2(0.82, 0.06), Vector2(0.73, 0.46),
	Vector2(0.55, 0.80), Vector2(0.29, 1.05), Vector2(0.00, 1.17),
]

## How far down the hair falls, in head radii, measured from the middle of the
## head. Tuned so the tips land inside the bust rather than off the card.
const FALL := 2.35


static func draw_bust(ci: CanvasItem, c: Vector2, r: float, phase: float) -> void:
	# Proportioned so a real length of neck shows between the chin and the
	# collar. With the head any lower the collar met the jaw and the bust read
	# as a head in a box, which is most of what made the neck look wrong.
	var head := c + Vector2(0.0, -r * 0.20)
	var hr := r * 0.50
	var fine := hr >= 18.0

	_hair_mass(ci, head, hr, phase, fine)
	_neck(ci, head, hr)
	_body(ci, c, r)
	_face(ci, head, hr, fine)
	_features(ci, head, hr, phase, fine)
	_hair_crown(ci, head, hr, fine)
	_hair_locks(ci, head, hr, phase, fine)
	# Studs last, so they sit on top of the hair in front of the ear the way
	# they do in the photograph rather than disappearing behind it.
	for side in [-1.0, 1.0]:
		ci.draw_circle(head + Vector2(side * hr * 0.84, hr * 0.50), hr * 0.055, GOLD)


# --- Helpers ----------------------------------------------------------------

static func _poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color) -> void:
	if pts.size() >= 3:
		ci.draw_colored_polygon(pts, fill)


## Outer edge of the hair at `u` down the fall, in head radii. It has to stay
## wide almost all the way down: the previous curve pulled in toward the centre
## at the tips, which turned the whole mass into a hood. Widest at 1.77, well
## outside both the face (0.82) and the shoulders (1.68), so the hair is the
## widest thing in the frame the way it is in the photograph.
static func _fall_x(u: float) -> float:
	var wave := sin(u * PI * 2.2) * 0.05
	return 1.30 + 0.68 * sin(u * 2.0) - 0.62 * pow(u, 2.6) + wave


static func _fall_y(u: float) -> float:
	return u * FALL


## Half-width of the face at height `y`, in head radii — 0 above the forehead
## and below the chin. The front locks use it to hug the face without ever
## creeping over a cheek.
static func _face_half(y: float) -> float:
	var first: Vector2 = PROFILE[0]
	var last: Vector2 = PROFILE[PROFILE.size() - 1]
	if y <= first.y or y >= last.y:
		return 0.0
	for i in range(PROFILE.size() - 1):
		var a: Vector2 = PROFILE[i]
		var b: Vector2 = PROFILE[i + 1]
		if y >= a.y and y <= b.y:
			return lerpf(a.x, b.x, (y - a.y) / maxf(b.y - a.y, 0.0001))
	return 0.0


# --- Hair -------------------------------------------------------------------

## The whole mass, drawn behind everything: a dome over the skull opening into
## the fall. One filled silhouette, then sheen laid on top of it — a solid shape
## with a highlight on it reads as heavy glossy hair, where separated strands
## read as a wig.
static func _hair_mass(ci: CanvasItem, head: Vector2, hr: float, phase: float,
		fine: bool) -> void:
	var drift := sin(phase * 0.9) * hr * 0.02
	var pts := PackedVector2Array()
	# Over the skull, left temple to right temple.
	for i in 21:
		var a := PI + PI * float(i) / 20.0
		pts.append(head + Vector2(cos(a) * hr * 1.30, sin(a) * hr * 1.34))
	# Down the right side, round the tips, back up the left. Traced as a single
	# monotonic loop — an outline that doubles back on itself is a polygon Godot
	# refuses to triangulate, and it fails silently.
	var steps := 18
	for i in range(1, steps + 1):
		var u := float(i) / float(steps)
		pts.append(head + Vector2(_fall_x(u) * hr + drift, _fall_y(u) * hr))
	for i in range(steps, -1, -1):
		var u2 := float(i) / float(steps)
		pts.append(head + Vector2(-_fall_x(u2) * hr - drift, _fall_y(u2) * hr))
	_poly(ci, pts, HAIR)

	if not fine:
		return
	# Sheen: a broad soft band following the outer edge, well inside it, so the
	# mass turns rather than sits flat.
	for side in [-1.0, 1.0]:
		var band := PackedVector2Array()
		for i in 13:
			var u3 := 0.06 + 0.62 * float(i) / 12.0
			band.append(head + Vector2(side * (_fall_x(u3) - 0.30) * hr, _fall_y(u3) * hr))
		for i in range(12, -1, -1):
			var u4 := 0.06 + 0.62 * float(i) / 12.0
			band.append(head + Vector2(side * (_fall_x(u4) - 0.56) * hr, _fall_y(u4) * hr))
		_poly(ci, band, Color(HAIR_MID.r, HAIR_MID.g, HAIR_MID.b, 0.85))


## Shoulders, the cream collar and the chain.
static func _body(ci: CanvasItem, c: Vector2, r: float) -> void:
	var top := c.y + r * 0.86
	_poly(ci, PackedVector2Array([
		Vector2(c.x - r * 0.84, top + r * 0.40),
		Vector2(c.x - r * 0.70, top - r * 0.06),
		Vector2(c.x - r * 0.28, top - r * 0.24),
		Vector2(c.x + r * 0.28, top - r * 0.24),
		Vector2(c.x + r * 0.70, top - r * 0.06),
		Vector2(c.x + r * 0.84, top + r * 0.40),
	]), CREAM)
	# Notched lapels falling either side of an open V.
	for side in [-1.0, 1.0]:
		_poly(ci, PackedVector2Array([
			Vector2(c.x + side * r * 0.07, top - r * 0.26),
			Vector2(c.x + side * r * 0.44, top - r * 0.20),
			Vector2(c.x + side * r * 0.26, top + r * 0.30),
			Vector2(c.x + side * r * 0.04, top + r * 0.08),
		]), CREAM.darkened(0.10))
		ci.draw_line(Vector2(c.x + side * r * 0.07, top - r * 0.26),
			Vector2(c.x + side * r * 0.05, top + r * 0.10),
			CREAM.darkened(0.26), maxf(1.0, r * 0.018), true)
	# Fine chain with a small pendant at the collarbone.
	var chain := PackedVector2Array()
	for i in 11:
		var u := float(i) / 10.0
		chain.append(Vector2(c.x + lerpf(-r * 0.22, r * 0.22, u),
			top - r * 0.14 + sin(u * PI) * r * 0.17))
	ci.draw_polyline(chain, GOLD, maxf(1.0, r * 0.018), true)
	ci.draw_circle(Vector2(c.x, top + r * 0.04), r * 0.030, GOLD)


## A slim neck in a *mild* shade. Drawn dark it reads as a beard shadow under
## the chin, which is the fastest way to lose the likeness there is.
static func _neck(ci: CanvasItem, head: Vector2, hr: float) -> void:
	_poly(ci, PackedVector2Array([
		head + Vector2(-hr * 0.25, hr * 0.78),
		head + Vector2(hr * 0.25, hr * 0.78),
		head + Vector2(hr * 0.36, hr * 1.74),
		head + Vector2(hr * 0.62, hr * 2.00),
		head + Vector2(-hr * 0.62, hr * 2.00),
		head + Vector2(-hr * 0.36, hr * 1.74),
	]), Color(0.745, 0.548, 0.408))
	# Contact shadow where the jaw sits on it, kept high and soft.
	_poly(ci, PackedVector2Array([
		head + Vector2(-hr * 0.24, hr * 0.80),
		head + Vector2(hr * 0.24, hr * 0.80),
		head + Vector2(hr * 0.25, hr * 1.16),
		head + Vector2(-hr * 0.25, hr * 1.16),
	]), Color(SKIN_SHADE.r, SKIN_SHADE.g, SKIN_SHADE.b, 0.55))


## The face: one long oval, lit from frame left. There is deliberately no shadow
## following the jaw — a dark line along a jaw reads as stubble at any size, and
## that single mistake was doing more damage than everything else combined.
static func _face(ci: CanvasItem, head: Vector2, hr: float, fine: bool) -> void:
	var pts := PackedVector2Array()
	for v in PROFILE:
		pts.append(head + Vector2((v as Vector2).x * hr, (v as Vector2).y * hr))
	for i in range(PROFILE.size() - 2, 0, -1):
		var m: Vector2 = PROFILE[i]
		pts.append(head + Vector2(-m.x * hr, m.y * hr))
	_poly(ci, pts, SKIN)

	if fine:
		# Form shading down the shadow side only, hugging the outline and fading
		# out before it reaches the chin.
		var shade := PackedVector2Array()
		for i in range(2, PROFILE.size()):
			var a: Vector2 = PROFILE[i]
			shade.append(head + Vector2(a.x * hr, a.y * hr))
		for i in range(PROFILE.size() - 2, 1, -1):
			var b: Vector2 = PROFILE[i]
			shade.append(head + Vector2(b.x * 0.68 * hr, b.y * hr))
		_poly(ci, shade, Color(SKIN_SHADE.r, SKIN_SHADE.g, SKIN_SHADE.b, 0.40))
		# Light catching the opposite cheekbone and the forehead.
		ci.draw_circle(head + Vector2(-hr * 0.40, hr * 0.20), hr * 0.32,
			Color(SKIN_LIT.r, SKIN_LIT.g, SKIN_LIT.b, 0.28))
		ci.draw_circle(head + Vector2(-hr * 0.18, -hr * 0.52), hr * 0.28,
			Color(SKIN_LIT.r, SKIN_LIT.g, SKIN_LIT.b, 0.22))

	# Ears, tucked behind the hair. The studs go on last, over it.
	for side in [-1.0, 1.0]:
		ci.draw_circle(head + Vector2(side * hr * 0.78, hr * 0.20), hr * 0.13, SKIN_SHADE)


static func _features(ci: CanvasItem, head: Vector2, hr: float, phase: float,
		fine: bool) -> void:
	var blink := fposmod(phase + 1.9, 5.4) < 0.12
	var eye := hr * 0.05

	# Brows: thick, near-straight, a shallow arch, a clear gap. These do more
	# for the likeness than the eyes do. They sit a full tenth of a head radius
	# clear of the lids — any closer and at thumbnail size the brow, the lash
	# line and the lid merge into one dark bar across her face, which is what
	# the 38px version used to look like.
	var thick := 0.13 if fine else 0.10
	for side in [-1.0, 1.0]:
		_poly(ci, PackedVector2Array([
			head + Vector2(side * hr * 0.15, -hr * 0.28),
			head + Vector2(side * hr * 0.40, -hr * 0.41),
			head + Vector2(side * hr * 0.66, -hr * 0.37),
			head + Vector2(side * hr * 0.68, -hr * (0.37 - thick)),
			head + Vector2(side * hr * 0.41, -hr * (0.41 - thick)),
			head + Vector2(side * hr * 0.15, -hr * (0.28 - thick)),
		]), INK)

	# Bindi, between the brows and clear of both.
	ci.draw_circle(head + Vector2(0.0, -hr * 0.38), hr * 0.055, Color(0.20, 0.05, 0.08))

	for side2 in [-1.0, 1.0]:
		var e := head + Vector2(side2 * hr * 0.37, eye)
		if blink:
			ci.draw_line(e - Vector2(hr * 0.21, 0.0), e + Vector2(hr * 0.21, 0.0),
				INK, maxf(1.2, hr * 0.06), true)
			continue
		# Almond, not round: wider than tall, the outer corner a little lower
		# than the inner one.
		_poly(ci, PackedVector2Array([
			e + Vector2(-hr * 0.25, hr * 0.01),
			e + Vector2(-hr * 0.10, -hr * 0.14),
			e + Vector2(hr * 0.10, -hr * 0.15),
			e + Vector2(hr * 0.25, -hr * 0.01),
			e + Vector2(hr * 0.10, hr * 0.13),
			e + Vector2(-hr * 0.10, hr * 0.12),
		]), Color(0.98, 0.95, 0.92))
		ci.draw_circle(e, hr * 0.125, Color(0.23, 0.12, 0.08))
		ci.draw_circle(e, hr * 0.060, Color(0.05, 0.03, 0.03))
		if fine:
			ci.draw_circle(e + Vector2(-hr * 0.05, -hr * 0.05), hr * 0.028,
				Color(1, 1, 1, 0.95))
		# Upper lash line, heaviest at the outer corner.
		ci.draw_polyline(PackedVector2Array([
			e + Vector2(-hr * 0.26, hr * 0.00),
			e + Vector2(-hr * 0.08, -hr * 0.16),
			e + Vector2(hr * 0.11, -hr * 0.16),
			e + Vector2(hr * 0.28, -hr * 0.02),
		]), INK, maxf(1.0, hr * 0.040), true)

	# Nose: a soft shadow down one side and a rounded tip, never an outline.
	if fine:
		ci.draw_line(head + Vector2(-hr * 0.080, hr * 0.14),
			head + Vector2(-hr * 0.115, hr * 0.44),
			Color(SKIN_SHADE.r, SKIN_SHADE.g, SKIN_SHADE.b, 0.75),
			maxf(1.0, hr * 0.042), true)
	_poly(ci, PackedVector2Array([
		head + Vector2(-hr * 0.11, hr * 0.44),
		head + Vector2(hr * 0.11, hr * 0.44),
		head + Vector2(hr * 0.13, hr * 0.50),
		head + Vector2(0.0, hr * 0.53),
		head + Vector2(-hr * 0.13, hr * 0.50),
	]), Color(SKIN_SHADE.r, SKIN_SHADE.g, SKIN_SHADE.b, 0.80))
	if fine:
		for side4 in [-1.0, 1.0]:
			ci.draw_circle(head + Vector2(side4 * hr * 0.095, hr * 0.485), hr * 0.030,
				Color(SKIN_SHADE.r, SKIN_SHADE.g, SKIN_SHADE.b, 0.95))

	# Mouth: closed, corners barely lifted.
	var mouth := head + Vector2(0.0, hr * 0.70)
	_poly(ci, PackedVector2Array([
		mouth + Vector2(-hr * 0.24, -hr * 0.01),
		mouth + Vector2(-hr * 0.10, -hr * 0.09),
		mouth + Vector2(0.0, -hr * 0.05),
		mouth + Vector2(hr * 0.10, -hr * 0.09),
		mouth + Vector2(hr * 0.24, -hr * 0.01),
		mouth + Vector2(hr * 0.11, hr * 0.11),
		mouth + Vector2(-hr * 0.11, hr * 0.11),
	]), LIP)
	ci.draw_line(mouth + Vector2(-hr * 0.23, 0.0), mouth + Vector2(hr * 0.23, 0.0),
		LIP.darkened(0.45), maxf(1.0, hr * 0.028), true)
	if fine:
		for side3 in [-1.0, 1.0]:
			ci.draw_circle(head + Vector2(side3 * hr * 0.55, hr * 0.44), hr * 0.15,
				Color(0.88, 0.48, 0.40, 0.16))


## The front of the hair: a cap whose lower edge is the hairline, sitting high
## enough that a full forehead shows. The reference has no fringe, and drawing
## one was the single biggest thing wrong with the first attempt.
static func _hair_crown(ci: CanvasItem, head: Vector2, hr: float, fine: bool) -> void:
	var cap := PackedVector2Array()
	for i in 19:
		var a := PI * 1.00 + PI * 1.00 * float(i) / 18.0
		cap.append(head + Vector2(cos(a) * hr * 1.22, sin(a) * hr * 1.26))
	# Hairline, dipping to a shallow centre point.
	var line := [
		Vector2(1.02, -0.16), Vector2(0.92, -0.50), Vector2(0.66, -0.70),
		Vector2(0.34, -0.80), Vector2(0.00, -0.72), Vector2(-0.34, -0.80),
		Vector2(-0.66, -0.70), Vector2(-0.92, -0.50), Vector2(-1.02, -0.16),
	]
	for v in line:
		cap.append(head + Vector2((v as Vector2).x * hr, (v as Vector2).y * hr))
	_poly(ci, cap, HAIR)

	if not fine:
		return
	# A single soft highlight on the lit side of the skull. Symmetric and
	# strong, it read as a headband; off-centre and faint, it reads as shine.
	var gloss := PackedVector2Array()
	for i in 11:
		var a2 := PI * 1.18 + PI * 0.44 * float(i) / 10.0
		gloss.append(head + Vector2(cos(a2) * hr * 1.10, sin(a2) * hr * 1.14))
	for i in range(10, -1, -1):
		var a3 := PI * 1.18 + PI * 0.44 * float(i) / 10.0
		gloss.append(head + Vector2(cos(a3) * hr * 0.86, sin(a3) * hr * 0.90))
	_poly(ci, gloss, Color(HAIR_LIT.r, HAIR_LIT.g, HAIR_LIT.b, 0.26))


## The two locks that fall in front of the shoulders. Drawn last, over the
## blouse: near-black hair crossing the cream is what sells the volume, and
## without it the whole mass hides behind the bust and she loses her silhouette.
static func _hair_locks(ci: CanvasItem, head: Vector2, hr: float, phase: float,
		fine: bool) -> void:
	var drift := sin(phase * 0.9) * hr * 0.02
	for side in [-1.0, 1.0]:
		var lock := PackedVector2Array()
		var steps := 20
		for i in range(steps + 1):
			var u := 0.02 + 0.98 * float(i) / float(steps)
			lock.append(head + Vector2(side * (_fall_x(u) * hr + drift), _fall_y(u) * hr))
		for i in range(steps, -1, -1):
			var u2 := 0.02 + 0.98 * float(i) / float(steps)
			lock.append(head + Vector2(side * (_lock_inner(u2) * hr + drift), _fall_y(u2) * hr))
		_poly(ci, lock, HAIR)

		if not fine:
			continue
		# Two sheen lines inside each lock, following its curve rather than
		# hanging straight down, which is what makes it read as a wave.
		for k in 2:
			var strand := PackedVector2Array()
			for i in 11:
				var u3 := 0.16 + 0.70 * float(i) / 10.0
				var span := _fall_x(u3) - _lock_inner(u3)
				var off := span * (0.28 + 0.34 * float(k))
				strand.append(head + Vector2(
					side * ((_fall_x(u3) - off) * hr + drift), _fall_y(u3) * hr))
			ci.draw_polyline(strand, Color(HAIR_LIT.r, HAIR_LIT.g, HAIR_LIT.b, 0.55),
				maxf(1.0, hr * 0.038), true)


## Inner edge of a front lock. It comes to a point at the tip, and never crosses
## the face: the widest it is allowed to be is whatever leaves the cheek clear.
static func _lock_inner(u: float) -> float:
	var outer := _fall_x(u)
	var width := (0.86 + 0.38 * u) * minf(1.0, (1.0 - u) * 5.0)
	return maxf(outer - width, _face_half(_fall_y(u)) + 0.05)
