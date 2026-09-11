class_name BabyPortrait
extends RefCounted
## Baby, drawn as a likeness of a specific photograph in the house chibi style.
##
## Two things have to be true at once and they pull against each other. The
## style is the soft-render chibi look the rest of the cast now uses: an
## oversized head, huge glossy eyes, a tiny nose and mouth, everything rounded
## and shaded rather than outlined. The likeness is a real person, and the
## chibi language throws away most of what normally carries a likeness — the
## nose, the mouth, the exact set of the eyes — by shrinking it to nothing.
##
## So the resemblance is carried by the things chibi *keeps*, taken straight
## off the photograph:
##
##  - **The hair, above all.** Near-black, heavy, parted off-centre and pushed
##    back from a tall broad forehead with no fringe at all, enormous volume at
##    the sides, breaking into loose waves and falling well past the shoulders
##    to mid-chest. Lit flyaways stand off the crown. It is far wider than her
##    face. At thumbnail size it is the entire recognition.
##  - **The brows.** Thick, dark, softly arched, a clear gap between them, and
##    sitting close down over the eyes. In the photograph they are the
##    strongest feature after the hair.
##  - **The bindi**, small and black, on the brow line and a touch to frame
##    right of centre rather than dead centre, which is where it actually sits.
##  - **A round face with full cheeks and a small soft chin** — not the long
##    oval a stylised chibi defaults to, and not a pointed one either.
##  - **Warm mid-brown skin.**
##  - **The eyes' expression** rather than their size: level, calm, direct,
##    with a heavy upper lash line and a deep warm brown iris.
##  - **A closed, faintly amused mouth** with a defined cupid's bow.
##  - The gold ear stud and the fine gold chain with its small pendant, and the
##    cream open-collar shirt.
##
## Everything scales from `hr`, so one function draws the roster card and the
## HUD slot.

# Sampled off the photograph rather than guessed. The previous pass had her
# hair cool near-black and her skin a shade too orange; hers is a warm
# near-black and her skin is lighter and pinker than tan.
const HAIR := Color(0.098, 0.082, 0.080)
const HAIR_SHEEN := Color(0.420, 0.385, 0.375)
const SKIN := Color(0.836, 0.616, 0.478)
const IRIS := Color(0.355, 0.215, 0.140)
const LASH := Color(0.115, 0.080, 0.075)
const BROW := Color(0.215, 0.150, 0.125)
const LIP := Color(0.745, 0.415, 0.380)
const GOLD := Color(1.000, 0.820, 0.420)
const CREAM := Color(0.930, 0.902, 0.880)

## Face outline in head radii: round, widest at the cheekbone, full through the
## cheek, closing to a small rounded chin.
const FACE := [
	Vector2(0.00, -1.20), Vector2(0.76, -1.00), Vector2(1.06, -0.34),
	Vector2(0.99, 0.26), Vector2(0.73, 0.68), Vector2(0.00, 0.90),
	Vector2(-0.73, 0.68), Vector2(-0.99, 0.26), Vector2(-1.06, -0.34),
	Vector2(-0.76, -1.00),
]


static func draw_bust(ci: CanvasItem, c: Vector2, r: float, phase: float) -> void:
	var head := c + Vector2(0.0, -r * 0.12)
	var hr := r * 0.60
	var fine := hr >= 17.0
	# Breath: the head rises a hair and the hair follows it a beat later.
	var breath := sin(phase * 1.15) * hr * 0.012
	head.y += breath
	var sway := sin(phase * 0.85) * hr * 0.022

	_hair_back(ci, head, hr, sway, fine)
	_neck(ci, head, hr)
	_shirt(ci, c, r, head, hr)
	_face(ci, head, hr, fine)
	# The hair over the skull goes down as one unbroken mass and the forehead
	# is then painted back over it. Cutting a concave hairline into the hair
	# shape instead is what kept producing a hard widow's peak: the spline
	# through a dome-shaped notch overshoots, and the skin below it comes to a
	# point. Painting the forehead makes the hairline the *outline of the
	# forehead*, which is a shape that can be drawn to look like a hairline.
	_crown(ci, head, hr, sway)
	_forehead(ci, head, hr, fine)
	_features(ci, head, hr, phase, fine)
	_side_locks(ci, head, hr, sway, phase, fine)


static func _pt(head: Vector2, hr: float, x: float, y: float) -> Vector2:
	return head + Vector2(x * hr, y * hr)


static func _ring(head: Vector2, hr: float, ctrl: Array, per_seg: int = 7) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for v in ctrl:
		pts.append(_pt(head, hr, (v as Vector2).x, (v as Vector2).y))
	return Chibi.smooth_closed(pts, per_seg)


# --- Hair -------------------------------------------------------------------

## The mass behind her. One big soft volume, then the clumps that give it
## waves. Drawn as shaded forms rather than a flat silhouette: black hair with
## no gradient in it reads as a hood, which is exactly what the last pass did.
static func _hair_back(ci: CanvasItem, head: Vector2, hr: float, sway: float,
		fine: bool) -> void:
	var h := head + Vector2(sway, 0.0)
	# Authored asymmetrically on purpose. A mirrored outline reads as a wig at
	# any size; hers is heavier on frame right, where it falls forward over the
	# shoulder in the photograph.
	Chibi.form(ci, _ring(h, hr, [
		Vector2(0.00, -1.50), Vector2(0.88, -1.28), Vector2(1.26, -0.56),
		Vector2(1.34, 0.16), Vector2(1.62, 0.70), Vector2(1.52, 1.20),
		Vector2(1.76, 1.74), Vector2(1.62, 2.24), Vector2(1.74, 2.68),
		Vector2(1.30, 3.10), Vector2(0.62, 3.32), Vector2(0.00, 3.36),
		Vector2(-0.64, 3.28), Vector2(-1.24, 3.02), Vector2(-1.62, 2.58),
		Vector2(-1.48, 2.12), Vector2(-1.70, 1.62), Vector2(-1.44, 1.10),
		Vector2(-1.58, 0.62), Vector2(-1.28, 0.12), Vector2(-1.22, -0.58),
		Vector2(-0.86, -1.28),
	], 8), HAIR, 0.30, 0.22, 0.46)

	if not fine:
		return
	# Wave clumps inside the mass. Rounded, overlapping, at different heights
	# on each side, so the fall breaks into locks instead of reading as one
	# flat sheet of black.
	var clumps := [
		Vector2(1.16, 0.46), Vector2(1.34, 1.52), Vector2(1.08, 2.52),
		Vector2(-1.12, 0.74), Vector2(-1.30, 1.86), Vector2(-1.00, 2.74),
	]
	for i in clumps.size():
		var cv: Vector2 = clumps[i]
		var w := 0.42 + 0.06 * float(i % 3)
		var tall := 0.66 + 0.10 * float((i + 1) % 3)
		Chibi.form(ci, _ring(h, hr, [
			Vector2(cv.x, cv.y - tall),
			Vector2(cv.x + signf(cv.x) * w, cv.y - tall * 0.30),
			Vector2(cv.x + signf(cv.x) * w * 0.72, cv.y + tall * 0.72),
			Vector2(cv.x, cv.y + tall),
			Vector2(cv.x - signf(cv.x) * w * 0.58, cv.y + tall * 0.20),
			Vector2(cv.x - signf(cv.x) * w * 0.34, cv.y - tall * 0.52),
		], 8), HAIR.lightened(0.055), 0.22, 0.16, 0.42)


## The mass over the skull. One closed volume with no notch in it — the
## hairline is cut by `_forehead`, painted back over the top of this.
static func _crown(ci: CanvasItem, head: Vector2, hr: float, sway: float) -> void:
	var h := head + Vector2(sway * 0.6, 0.0)
	Chibi.form(ci, _ring(h, hr, [
		Vector2(0.04, -1.52), Vector2(0.74, -1.38), Vector2(1.16, -0.86),
		Vector2(1.30, -0.10), Vector2(1.26, 0.52), Vector2(1.04, 0.28),
		Vector2(0.86, -0.30), Vector2(0.40, -0.60), Vector2(-0.10, -0.66),
		Vector2(-0.58, -0.56), Vector2(-0.94, -0.26), Vector2(-1.12, 0.30),
		Vector2(-1.30, 0.44), Vector2(-1.34, -0.18), Vector2(-1.20, -0.90),
		Vector2(-0.78, -1.40),
	], 8), HAIR, 0.20, 0.20, 0.40)


## The forehead, painted over the crown. Its top edge *is* the hairline: broad,
## almost flat across the middle, curving down into a shallow temple recession
## on each side. Hers is high and wide, and that plus the swept-back hair is
## half the likeness.
static func _forehead(ci: CanvasItem, head: Vector2, hr: float, fine: bool) -> void:
	Chibi.form(ci, _ring(head, hr, [
		Vector2(0.00, -0.98), Vector2(0.40, -0.95), Vector2(0.72, -0.84),
		Vector2(0.90, -0.62), Vector2(1.00, -0.30), Vector2(0.98, 0.16),
		Vector2(0.52, 0.34), Vector2(0.00, 0.36), Vector2(-0.52, 0.34),
		Vector2(-0.98, 0.16), Vector2(-1.00, -0.30), Vector2(-0.90, -0.62),
		Vector2(-0.72, -0.84), Vector2(-0.40, -0.95),
	], 9), SKIN, 0.10, 0.24, 0.26)
	if not fine:
		return
	# Occlusion from the hair onto the skin it overhangs, then light on the brow
	# ridge. The contact shadow is most of what makes a rendered chibi look lit
	# rather than pasted together.
	Chibi.soft(ci, _pt(head, hr, 0.0, -0.98), hr * 0.92, hr * 0.30,
		Color(0.30, 0.16, 0.11, 0.40))
	for side in [-1.0, 1.0]:
		Chibi.soft(ci, _pt(head, hr, side * 0.88, -0.30), hr * 0.30, hr * 0.44,
			Color(0.30, 0.16, 0.11, 0.34))
	Chibi.soft(ci, _pt(head, hr, -0.12, -0.60), hr * 0.44, hr * 0.20,
		Color(1.0, 0.90, 0.78, 0.22))
	Chibi.soft(ci, _pt(head, hr, -0.44, -0.70), hr * 0.30, hr * 0.20,
		Color(1.0, 0.90, 0.78, 0.24))


## The locks that fall in front of the shoulders, the sheen, and the flyaways.
## They carry the length: without hair crossing the shirt she reads as a bob,
## and in the photograph it falls well past her shoulders.
static func _side_locks(ci: CanvasItem, head: Vector2, hr: float, sway: float,
		phase: float, fine: bool) -> void:
	var h := head + Vector2(sway * 0.6, 0.0)
	var locks := [
		[Vector2(0.96, -1.06), Vector2(1.50, -0.04), Vector2(1.40, 0.86),
			Vector2(1.66, 1.62), Vector2(1.44, 2.30), Vector2(1.06, 2.82),
			Vector2(0.78, 2.28), Vector2(1.02, 1.44), Vector2(1.14, 0.50),
			Vector2(1.10, -0.44)],
		[Vector2(-0.94, -1.08), Vector2(-1.46, -0.08), Vector2(-1.54, 0.78),
			Vector2(-1.36, 1.52), Vector2(-1.54, 2.18), Vector2(-1.18, 2.74),
			Vector2(-0.88, 2.16), Vector2(-1.08, 1.36), Vector2(-1.18, 0.46),
			Vector2(-1.12, -0.46)],
	]
	for lock in locks:
		Chibi.form(ci, _ring(h, hr, lock, 8), HAIR, 0.24, 0.20, 0.42)

	if not fine:
		return
	# Sheen. One soft band over the crown and one running down each lock. Black
	# hair is only legible as hair when the light moves across it.
	Chibi.rim_light(ci, h + Vector2(-hr * 0.08, -hr * 0.30), hr * 1.10, hr * 1.06,
		PI * 1.08, PI * 1.58, Color(HAIR_SHEEN.r, HAIR_SHEEN.g, HAIR_SHEEN.b, 0.50),
		hr * 0.18)
	for side2 in [-1.0, 1.0]:
		var gloss := Chibi.smooth_open(PackedVector2Array([
			_pt(h, hr, side2 * 1.22, -0.30),
			_pt(h, hr, side2 * 1.34, 0.44),
			_pt(h, hr, side2 * 1.24, 1.26),
			_pt(h, hr, side2 * 1.36, 1.90),
			_pt(h, hr, side2 * 1.08, 2.46),
		]), 6)
		Chibi.taper(ci, gloss, Color(HAIR_SHEEN.r, HAIR_SHEEN.g, HAIR_SHEEN.b,
			0.38 if side2 < 0.0 else 0.20), hr * 0.14, 0.15, 1.0)
	# The parting sits left of centre, with a wing of hair sweeping back over
	# that temple - the shape the photograph actually has.
	Chibi.soft(ci, _pt(h, hr, -0.22, -1.16), hr * 0.26, hr * 0.20,
		Color(0.0, 0.0, 0.0, 0.40))
	var wing := Chibi.smooth_open(PackedVector2Array([
		_pt(h, hr, -0.22, -1.16), _pt(h, hr, -0.74, -1.10),
		_pt(h, hr, -1.14, -0.78), _pt(h, hr, -1.32, -0.26),
	]), 7)
	Chibi.taper(ci, wing, Color(HAIR_SHEEN.r, HAIR_SHEEN.g, HAIR_SHEEN.b, 0.30),
		hr * 0.10, 0.2, 1.0)

	# Flyaways: three, curved, hugging the crown and catching the light. Drawn
	# radially they became a ring of pins, which is the opposite of soft.
	for i in 3:
		var t := (float(i) + 0.5) / 3.0
		var a := PI * 1.16 + PI * 0.60 * t
		var root := h + Vector2(cos(a) * hr * 1.08, sin(a) * hr * 1.22)
		var drift := sin(phase * 1.3 + float(i) * 2.1) * hr * 0.05
		var out := Vector2(cos(a), sin(a))
		var side := Vector2(-out.y, out.x)
		var wisp := Chibi.smooth_open(PackedVector2Array([
			root,
			root + out * hr * 0.13 + side * hr * 0.07 + Vector2(drift, 0.0),
			root + out * hr * 0.20 + side * hr * 0.20 + Vector2(drift * 1.6, 0.0),
		]), 6)
		Chibi.taper(ci, wisp, Color(HAIR_SHEEN.r, HAIR_SHEEN.g, HAIR_SHEEN.b, 0.55),
			hr * 0.032, 1.0, 0.05)


# --- Head and body ----------------------------------------------------------

static func _neck(ci: CanvasItem, head: Vector2, hr: float) -> void:
	Chibi.capsule(ci, _pt(head, hr, 0.0, 0.70), _pt(head, hr, 0.0, 1.44),
		hr * 0.28, hr * 0.36, SKIN.darkened(0.10))
	# Contact shadow where the jaw sits on the neck. Kept faint: dark under a
	# chin reads as a beard, and that is an easy way to lose a face entirely.
	Chibi.soft(ci, _pt(head, hr, 0.0, 0.84), hr * 0.32, hr * 0.20,
		Color(0.38, 0.23, 0.16, 0.32))


static func _shirt(ci: CanvasItem, c: Vector2, r: float, head: Vector2, hr: float) -> void:
	var top := c.y + r * 0.78
	Chibi.form(ci, Chibi.smooth_closed(PackedVector2Array([
		Vector2(c.x - r * 1.30, top + r * 0.58),
		Vector2(c.x - r * 1.12, top - r * 0.08),
		Vector2(c.x - r * 0.62, top - r * 0.30),
		Vector2(c.x - r * 0.22, top - r * 0.34),
		Vector2(c.x + r * 0.22, top - r * 0.34),
		Vector2(c.x + r * 0.62, top - r * 0.30),
		Vector2(c.x + r * 1.12, top - r * 0.08),
		Vector2(c.x + r * 1.30, top + r * 0.58),
	]), 8), CREAM, 0.10, 0.22, 0.34)
	# Shadow the hair casts onto the shoulders.
	for sh in [-1.0, 1.0]:
		Chibi.soft(ci, Vector2(c.x + sh * r * 0.64, top - r * 0.04), r * 0.38,
			r * 0.36, Color(0.16, 0.13, 0.16, 0.32))
	# The shirt is open: a wedge of chest shows between the lapels, which is
	# where the chain sits. Painting the collar onto a closed front made it
	# read as a bib.
	Chibi.form(ci, Chibi.smooth_closed(PackedVector2Array([
		Vector2(c.x - r * 0.30, top - r * 0.40),
		Vector2(c.x + r * 0.30, top - r * 0.40),
		Vector2(c.x + r * 0.22, top - r * 0.02),
		Vector2(c.x, top + r * 0.18),
		Vector2(c.x - r * 0.22, top - r * 0.02),
	]), 8), SKIN.darkened(0.08), 0.10, 0.20, 0.26)
	Chibi.soft(ci, Vector2(c.x, top - r * 0.36), r * 0.30, r * 0.16,
		Color(0.34, 0.20, 0.14, 0.34))
	# Notched lapels either side of the opening.
	for side in [-1.0, 1.0]:
		Chibi.form(ci, Chibi.smooth_closed(PackedVector2Array([
			Vector2(c.x + side * r * 0.24, top - r * 0.44),
			Vector2(c.x + side * r * 0.50, top - r * 0.34),
			Vector2(c.x + side * r * 0.40, top - r * 0.02),
			Vector2(c.x + side * r * 0.09, top + r * 0.20),
			Vector2(c.x + side * r * 0.17, top - r * 0.14),
		]), 8), CREAM.darkened(0.06), 0.12, 0.18, 0.28)
	# Fine chain with a small pendant, hanging in the open V.
	var chain := Chibi.smooth_open(PackedVector2Array([
		Vector2(c.x - r * 0.20, top - r * 0.34),
		Vector2(c.x, top - r * 0.12),
		Vector2(c.x + r * 0.20, top - r * 0.34),
	]), 7)
	Chibi.taper(ci, chain, GOLD, maxf(1.2, r * 0.016), 0.6, 1.0)
	Chibi.ball(ci, Vector2(c.x, top - r * 0.09), r * 0.028, GOLD)


static func _face(ci: CanvasItem, head: Vector2, hr: float, fine: bool) -> void:
	Chibi.form(ci, _ring(head, hr, FACE, 9), SKIN, 0.16, 0.26, 0.30)
	if not fine:
		return
	# Cheeks: warm, high and round, which is most of what makes the face read
	# as full rather than as a wedge.
	for side in [-1.0, 1.0]:
		Chibi.soft(ci, _pt(head, hr, side * 0.48, 0.34), hr * 0.30, hr * 0.24,
			Color(0.86, 0.44, 0.36, 0.20))
	# Warm bounce along the shadow side of the jaw, no hard edge anywhere.
	Chibi.soft(ci, _pt(head, hr, 0.50, 0.26), hr * 0.40, hr * 0.54,
		Color(0.52, 0.30, 0.20, 0.24))
	# Light on the planes that face the key: the near temple, the cheek under
	# it, and a touch along the jaw.
	Chibi.soft(ci, _pt(head, hr, -0.52, -0.18), hr * 0.30, hr * 0.42,
		Color(1.0, 0.88, 0.74, 0.26))
	Chibi.soft(ci, _pt(head, hr, -0.44, 0.30), hr * 0.30, hr * 0.28,
		Color(1.0, 0.88, 0.74, 0.20))
	# Ears, small and low, tucked at the hairline.
	for side2 in [-1.0, 1.0]:
		Chibi.ball(ci, _pt(head, hr, side2 * 1.07, 0.20), hr * 0.135,
			SKIN.darkened(0.16), Vector2(0.78, 1.15))


static func _features(ci: CanvasItem, head: Vector2, hr: float, phase: float,
		fine: bool) -> void:
	var cycle := fposmod(phase + 1.6, 4.9)
	var open := 1.0
	if cycle < 0.16:
		open = clampf(absf(cycle - 0.08) / 0.08, 0.0, 1.0)
	# A slow, small drift of the gaze, so she is looking rather than staring.
	var look := Vector2(sin(phase * 0.42) * 0.5, sin(phase * 0.31) * 0.25)

	for side in [-1.0, 1.0]:
		Chibi.eye(ci, _pt(head, hr, side * 0.385, 0.135), hr * 0.265, hr * 0.235,
			IRIS, Vector2(look.x * side, look.y), open, LASH, side)

	# Brows: thick, softly arched, a clear gap, sitting close down over the
	# eyes. Drawn as tapered strokes rather than slabs so they have a hair end
	# and a head end the way real brows do.
	for side2 in [-1.0, 1.0]:
		var brow := Chibi.smooth_open(PackedVector2Array([
			_pt(head, hr, side2 * 0.16, -0.325),
			_pt(head, hr, side2 * 0.38, -0.415),
			_pt(head, hr, side2 * 0.58, -0.405),
			_pt(head, hr, side2 * 0.72, -0.325),
		]), 8)
		Chibi.taper(ci, brow, BROW, hr * 0.105, 0.45, 1.0)

	# Bindi: on the brow line, and a touch to frame right of centre, which is
	# where it sits in the photograph rather than dead between the brows.
	Chibi.ball(ci, _pt(head, hr, 0.115, -0.345), hr * 0.042,
		Color(0.12, 0.05, 0.06), Vector2.ONE, 0.0, 0.0, 0.10)

	# Nose: a button. In this style it is nearly nothing, but nothing at all
	# leaves a blank between the eyes and the mouth.
	Chibi.soft(ci, _pt(head, hr, 0.02, 0.435), hr * 0.150, hr * 0.100,
		Color(0.42, 0.23, 0.15, 0.72))
	if fine:
		Chibi.soft(ci, _pt(head, hr, -0.045, 0.375), hr * 0.075, hr * 0.135,
			Color(1.0, 0.90, 0.78, 0.34))
		for side3 in [-1.0, 1.0]:
			Chibi.soft(ci, _pt(head, hr, side3 * 0.11, 0.447), hr * 0.055,
				hr * 0.050, Color(0.40, 0.22, 0.15, 0.35))

	# Mouth: small, closed, corners lifted, with a cupid's bow.
	var m := _pt(head, hr, 0.0, 0.615)
	Chibi.form(ci, Chibi.smooth_closed(PackedVector2Array([
		m + Vector2(-hr * 0.165, -hr * 0.004),
		m + Vector2(-hr * 0.07, -hr * 0.075),
		m + Vector2(0.0, -hr * 0.034),
		m + Vector2(hr * 0.07, -hr * 0.075),
		m + Vector2(hr * 0.165, -hr * 0.004),
		m + Vector2(hr * 0.08, hr * 0.086),
		m + Vector2(0.0, hr * 0.100),
		m + Vector2(-hr * 0.08, hr * 0.086),
	]), 7), LIP, 0.16, 0.26, 0.34)
	var seam := Chibi.smooth_open(PackedVector2Array([
		m + Vector2(-hr * 0.155, -hr * 0.004),
		m + Vector2(0.0, hr * 0.011),
		m + Vector2(hr * 0.155, -hr * 0.004),
	]), 6)
	Chibi.taper(ci, seam, LIP.darkened(0.45), hr * 0.030, 0.3, 1.0)
	if fine:
		Chibi.soft(ci, m + Vector2(-hr * 0.04, hr * 0.05), hr * 0.06, hr * 0.035,
			Color(1, 0.92, 0.90, 0.40))
		# The stud is on her right ear, as in the photograph.
		Chibi.ball(ci, _pt(head, hr, -1.10, 0.32), hr * 0.048, GOLD)
