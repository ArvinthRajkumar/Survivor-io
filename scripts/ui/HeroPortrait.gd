class_name HeroPortrait
extends RefCounted
## Chibi bust portraits for the operative roster, drawn procedurally on the
## Chibi toolkit — soft shaded volumes, no flat fills and no straight edges.
##
## The five share one head-and-shoulders construction so they read as the same
## squad, and differ only in the things a player actually uses to tell people
## apart: hair, headgear, expression and the kit on their shoulders. That is
## deliberate — five unrelated silhouettes would look like five games.
##
## Baby is the exception and has her own geometry in BabyPortrait: she has to
## be a specific person off a specific photograph, and the shared construction
## averages faces toward a template, which is exactly what destroys a likeness.
##
## Everything is scaled from `r`, so one function draws a 40px roster thumbnail
## and a 200px card portrait.

const SKIN := Color(0.965, 0.845, 0.755)

## The shared skull: rounded, widest at the cheekbone, closing to a soft chin,
## with a tall cranium because that is where a chibi puts its volume.
const FACE := [
	Vector2(0.00, -1.20), Vector2(0.76, -1.00), Vector2(1.06, -0.34),
	Vector2(0.99, 0.26), Vector2(0.73, 0.68), Vector2(0.00, 0.90),
	Vector2(-0.73, 0.68), Vector2(-0.99, 0.26), Vector2(-1.06, -0.34),
	Vector2(-0.76, -1.00),
]


## Skin tone per operative. A squad that is six shades of the same beige is a
## squad of one person in six hats. PlayerVisual reads this too, so the
## character in the run and the portrait on the roster are the same person.
static func _skin_of(variant: int) -> Color:
	match variant:
		0:
			return Color(0.945, 0.760, 0.635)
		1:
			return Color(0.830, 0.630, 0.495)
		3:
			return Color(0.915, 0.790, 0.670)
		4:
			return Color(0.975, 0.870, 0.805)
		5:
			# Baby: sampled off the reference photograph.
			return BabyPortrait.SKIN
		_:
			return SKIN


## Deep, desaturated cast of the accent, so each operative's hair belongs to
## their own palette without a second colour having to be authored.
static func _hair_of(accent: Color, variant: int) -> Color:
	match variant:
		0:
			return Color(0.30, 0.13, 0.10)          # Ember - dark auburn
		1:
			return Color(0.24, 0.25, 0.31)          # Aegis - steel grey
		3:
			return Color(0.15, 0.26, 0.18)          # Bramble - deep moss
		4:
			return Color(0.23, 0.16, 0.33)          # Rift - dark violet
		5:
			return BabyPortrait.HAIR                # Baby - warm near-black
		_:
			return Color(0.17, 0.21, 0.33)          # Nova - navy


## `variant` is HeroData.portrait_shape: 0 Ember, 1 Aegis, 2 Nova, 3 Bramble,
## 4 Rift, 5 Baby. `phase` drives the small idle motions (blink, sway, glow).
static func draw_bust(ci: CanvasItem, c: Vector2, r: float, accent: Color,
		secondary: Color, variant: int, phase: float = 0.0) -> void:
	if variant == 5:
		BabyPortrait.draw_bust(ci, c, r, phase)
		return

	var hair := _hair_of(accent, variant)
	var skin := _skin_of(variant)
	var head := c + Vector2(0.0, -r * 0.12 + sin(phase * 1.15) * r * 0.007)
	var hr := r * 0.60
	var fine := hr >= 17.0
	var sway := sin(phase * 0.85) * hr * 0.022

	_hair_back(ci, head, hr, hair, variant, sway, phase, fine)
	_neck(ci, head, hr, skin)
	_shoulders(ci, c, r, accent, secondary, variant)
	_face(ci, head, hr, skin, fine)
	_crown(ci, head, hr, hair, variant, sway)
	_forehead(ci, head, hr, skin, variant, fine)
	_features(ci, head, hr, hair, accent, variant, phase, fine)
	_headgear(ci, head, hr, accent, secondary, hair, variant, phase, fine)


# --- Helpers ----------------------------------------------------------------

static func _pt(head: Vector2, hr: float, x: float, y: float) -> Vector2:
	return head + Vector2(x * hr, y * hr)


static func _ring(head: Vector2, hr: float, ctrl: Array, per_seg: int = 7) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for v in ctrl:
		pts.append(_pt(head, hr, (v as Vector2).x, (v as Vector2).y))
	return Chibi.smooth_closed(pts, per_seg)


# --- Body -------------------------------------------------------------------

static func _neck(ci: CanvasItem, head: Vector2, hr: float, skin: Color) -> void:
	Chibi.capsule(ci, _pt(head, hr, 0.0, 0.70), _pt(head, hr, 0.0, 1.44),
		hr * 0.28, hr * 0.36, skin.darkened(0.12))
	Chibi.soft(ci, _pt(head, hr, 0.0, 0.84), hr * 0.32, hr * 0.20,
		Color(0.32, 0.20, 0.15, 0.32))


## Shoulders and the jacket. Every operative wears the same cut so the squad
## reads as a squad; the trim and what is strapped to it is theirs.
static func _shoulders(ci: CanvasItem, c: Vector2, r: float, accent: Color,
		secondary: Color, variant: int) -> void:
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
	]), 8), accent.darkened(0.52), 0.22, 0.30, 0.34)
	# Hair and head drop a shadow onto the shoulders.
	for sh in [-1.0, 1.0]:
		Chibi.soft(ci, Vector2(c.x + sh * r * 0.60, top - r * 0.06), r * 0.40,
			r * 0.34, Color(0.08, 0.07, 0.12, 0.34))
	# Open collar, with the undershirt showing in the V.
	Chibi.form(ci, Chibi.smooth_closed(PackedVector2Array([
		Vector2(c.x - r * 0.28, top - r * 0.40),
		Vector2(c.x + r * 0.28, top - r * 0.40),
		Vector2(c.x + r * 0.20, top - r * 0.02),
		Vector2(c.x, top + r * 0.18),
		Vector2(c.x - r * 0.20, top - r * 0.02),
	]), 8), accent.darkened(0.72), 0.16, 0.24, 0.28)
	for side in [-1.0, 1.0]:
		Chibi.form(ci, Chibi.smooth_closed(PackedVector2Array([
			Vector2(c.x + side * r * 0.24, top - r * 0.42),
			Vector2(c.x + side * r * 0.54, top - r * 0.32),
			Vector2(c.x + side * r * 0.44, top + r * 0.02),
			Vector2(c.x + side * r * 0.10, top + r * 0.22),
			Vector2(c.x + side * r * 0.17, top - r * 0.14),
		]), 8), accent.darkened(0.40), 0.22, 0.24, 0.30)
	# A strap and a shoulder plate, which is what makes it kit rather than
	# clothing. Aegis wears the heaviest of them.
	var plate: float = 1.06 if variant == 1 else 1.0
	Chibi.form(ci, Chibi.smooth_closed(PackedVector2Array([
		Vector2(c.x - r * 1.24 * plate, top + r * 0.04),
		Vector2(c.x - r * 0.86, top - r * 0.20),
		Vector2(c.x - r * 0.70, top - r * 0.06),
		Vector2(c.x - r * 0.80, top + r * 0.14),
		Vector2(c.x - r * 1.16 * plate, top + r * 0.28),
	]), 7), secondary.darkened(0.52), 0.18, 0.24, 0.28)
	Chibi.taper(ci, Chibi.smooth_open(PackedVector2Array([
		Vector2(c.x - r * 0.52, top - r * 0.18),
		Vector2(c.x + r * 0.10, top + r * 0.22),
		Vector2(c.x + r * 0.62, top + r * 0.50),
	]), 6), secondary.darkened(0.20), maxf(1.4, r * 0.055), 0.7, 1.0)


# --- Head -------------------------------------------------------------------

static func _face(ci: CanvasItem, head: Vector2, hr: float, skin: Color,
		fine: bool) -> void:
	Chibi.form(ci, _ring(head, hr, FACE, 9), skin, 0.16, 0.26, 0.30)
	if not fine:
		return
	for side in [-1.0, 1.0]:
		Chibi.soft(ci, _pt(head, hr, side * 0.48, 0.34), hr * 0.30, hr * 0.24,
			Color(0.90, 0.46, 0.40, 0.22))
	Chibi.soft(ci, _pt(head, hr, 0.50, 0.26), hr * 0.40, hr * 0.54,
		Color(0.46, 0.28, 0.22, 0.22))
	Chibi.soft(ci, _pt(head, hr, -0.52, -0.18), hr * 0.30, hr * 0.42,
		Color(1.0, 0.94, 0.86, 0.24))
	for side2 in [-1.0, 1.0]:
		Chibi.ball(ci, _pt(head, hr, side2 * 1.07, 0.20), hr * 0.135,
			skin.darkened(0.16), Vector2(0.78, 1.15))


## Hair over the skull as one unbroken mass. The hairline is cut by
## `_forehead`, painted back over this — notching it into the hair shape makes
## the spline overshoot into a hard widow's peak.
static func _crown(ci: CanvasItem, head: Vector2, hr: float, hair: Color,
		variant: int, sway: float) -> void:
	var h := head + Vector2(sway * 0.6, 0.0)
	var lift: float = 1.62 if variant == 0 else 1.50
	Chibi.form(ci, _ring(h, hr, [
		Vector2(0.04, -lift), Vector2(0.74, -1.38), Vector2(1.16, -0.86),
		Vector2(1.30, -0.10), Vector2(1.26, 0.52), Vector2(1.04, 0.28),
		Vector2(0.86, -0.30), Vector2(0.40, -0.60), Vector2(-0.10, -0.66),
		Vector2(-0.58, -0.56), Vector2(-0.94, -0.26), Vector2(-1.12, 0.30),
		Vector2(-1.30, 0.44), Vector2(-1.34, -0.18), Vector2(-1.20, -0.90),
		Vector2(-0.78, -1.40),
	], 8), hair, 0.24, 0.22, 0.42)


## The forehead, painted over the crown. Its top edge *is* the hairline: a
## fringe is simply a hairline that sits lower and is cut straighter.
static func _forehead(ci: CanvasItem, head: Vector2, hr: float, skin: Color,
		variant: int, fine: bool) -> void:
	# Rift wears a heavy fringe over one eye; Nova's is cut straight; the rest
	# push it back off the brow.
	var line: float = -0.76
	var tilt := 0.0
	match variant:
		2:
			line = -0.62
		3:
			line = -0.66
		4:
			line = -0.58
			tilt = 0.22
	Chibi.form(ci, _ring(head, hr, [
		Vector2(0.00, line), Vector2(0.40, line + tilt * 0.4 + 0.03),
		Vector2(0.72, line + tilt + 0.14), Vector2(0.90, line + tilt + 0.36),
		Vector2(1.00, -0.30), Vector2(0.98, 0.16), Vector2(0.52, 0.34),
		Vector2(0.00, 0.36), Vector2(-0.52, 0.34), Vector2(-0.98, 0.16),
		Vector2(-1.00, -0.30), Vector2(-0.90, line + 0.36),
		Vector2(-0.72, line + 0.14), Vector2(-0.40, line + 0.03),
	], 9), skin, 0.10, 0.24, 0.26)
	if not fine:
		return
	Chibi.soft(ci, _pt(head, hr, 0.0, line), hr * 0.92, hr * 0.30,
		Color(0.26, 0.16, 0.13, 0.36))
	for side in [-1.0, 1.0]:
		Chibi.soft(ci, _pt(head, hr, side * 0.88, -0.30), hr * 0.30, hr * 0.44,
			Color(0.26, 0.16, 0.13, 0.30))
	Chibi.soft(ci, _pt(head, hr, -0.44, line + 0.26), hr * 0.30, hr * 0.20,
		Color(1.0, 0.94, 0.86, 0.24))


static func _features(ci: CanvasItem, head: Vector2, hr: float, hair: Color,
		accent: Color, variant: int, phase: float, fine: bool) -> void:
	var cycle := fposmod(phase + float(variant) * 0.7, 4.4)
	var open := 1.0
	if cycle < 0.16:
		open = clampf(absf(cycle - 0.08) / 0.08, 0.0, 1.0)
	var look := Vector2(sin(phase * 0.42 + float(variant)) * 0.5,
		sin(phase * 0.31) * 0.25)
	var iris := accent.lerp(Color(0.26, 0.18, 0.14), 0.45)
	var ink := Color(0.10, 0.09, 0.14)

	for side in [-1.0, 1.0]:
		Chibi.eye(ci, _pt(head, hr, side * 0.385, 0.135), hr * 0.265, hr * 0.235,
			iris, Vector2(look.x * side, look.y), open, ink, side)

	# Brows carry the expression, so each operative gets a different set.
	var brow_y := -0.325
	var arch := -0.09
	var tilt_in := 0.0
	match variant:
		0:
			arch = -0.05
			tilt_in = 0.05                       # Ember - flat and forward
		1:
			brow_y = -0.30
			tilt_in = 0.04                       # Aegis - low and level
		3:
			arch = -0.12                         # Bramble - soft and high
		4:
			arch = -0.11
			tilt_in = -0.04                      # Rift - amused
	for side2 in [-1.0, 1.0]:
		Chibi.taper(ci, Chibi.smooth_open(PackedVector2Array([
			_pt(head, hr, side2 * 0.16, brow_y + tilt_in),
			_pt(head, hr, side2 * 0.38, brow_y + arch),
			_pt(head, hr, side2 * 0.58, brow_y + arch + 0.01),
			_pt(head, hr, side2 * 0.72, brow_y + 0.02),
		]), 8), hair.lightened(0.14), hr * 0.105, 0.45, 1.0)

	Chibi.soft(ci, _pt(head, hr, 0.02, 0.435), hr * 0.150, hr * 0.100,
		Color(0.42, 0.24, 0.17, 0.60))
	if fine:
		Chibi.soft(ci, _pt(head, hr, -0.045, 0.375), hr * 0.075, hr * 0.135,
			Color(1.0, 0.94, 0.86, 0.30))
	_mouth(ci, head, hr, variant)


static func _mouth(ci: CanvasItem, head: Vector2, hr: float, variant: int) -> void:
	var m := _pt(head, hr, 0.0, 0.615)
	var ink := Color(0.28, 0.16, 0.16)
	match variant:
		1:
			# Aegis: a flat, patient line.
			Chibi.taper(ci, PackedVector2Array([
				m + Vector2(-hr * 0.13, 0.0), m + Vector2(hr * 0.13, 0.0)]),
				ink, hr * 0.05, 0.5, 1.0)
		4:
			# Rift: a crooked half-smile.
			Chibi.taper(ci, Chibi.smooth_open(PackedVector2Array([
				m + Vector2(-hr * 0.14, hr * 0.02), m + Vector2(0.0, hr * 0.07),
				m + Vector2(hr * 0.15, -hr * 0.05)]), 6), ink, hr * 0.055, 0.4, 1.0)
		_:
			Chibi.taper(ci, Chibi.smooth_open(PackedVector2Array([
				m + Vector2(-hr * 0.14, -hr * 0.02), m + Vector2(0.0, hr * 0.06),
				m + Vector2(hr * 0.14, -hr * 0.02)]), 6), ink, hr * 0.055, 0.4, 1.0)


# --- Hair and headgear ------------------------------------------------------

## The mass behind the head. Everyone on this squad wears it long; the
## differences are in the shape of the fall, not its presence.
static func _hair_back(ci: CanvasItem, head: Vector2, hr: float, hair: Color,
		variant: int, sway: float, phase: float, fine: bool) -> void:
	var h := head + Vector2(sway, 0.0)
	var drop_by := {0: 1.55, 1: 1.30, 2: 1.85, 3: 1.50, 4: 1.90}
	var fall: float = float(drop_by.get(variant, 1.6))
	var wide := 1.26 if variant != 1 else 1.16

	Chibi.form(ci, _ring(h, hr, [
		Vector2(0.00, -1.46), Vector2(0.84, -1.24), Vector2(wide, -0.50),
		Vector2(wide + 0.10, 0.32), Vector2(wide, fall * 0.58),
		Vector2(wide * 0.70, fall * 0.92), Vector2(0.00, fall),
		Vector2(-wide * 0.70, fall * 0.92), Vector2(-wide, fall * 0.58),
		Vector2(-wide - 0.10, 0.32), Vector2(-wide, -0.50), Vector2(-0.84, -1.24),
	], 8), hair, 0.28, 0.22, 0.44)

	if fine:
		# Clumps, so the fall breaks into locks instead of one flat sheet.
		for i in 4:
			var side := -1.0 if i < 2 else 1.0
			var y0 := 0.36 + 0.74 * float(i % 2)
			Chibi.form(ci, _ring(h, hr, [
				Vector2(side * (wide - 0.28), y0 - 0.44),
				Vector2(side * (wide - 0.02), y0 + 0.06),
				Vector2(side * (wide - 0.22), y0 + 0.62),
				Vector2(side * (wide - 0.62), y0 + 0.12),
			], 8), hair.lightened(0.06), 0.20, 0.16, 0.40)

	# Nova wears a side tail that sways.
	if variant == 2:
		var tail := sin(phase * 2.2) * hr * 0.10
		Chibi.capsule(ci, _pt(h, hr, 1.02, -0.44),
			_pt(h, hr, 1.44, 0.44) + Vector2(tail, 0.0), hr * 0.20, hr * 0.22, hair)
		Chibi.ball(ci, _pt(h, hr, 1.02, -0.42), hr * 0.14, hair.lightened(0.10))


static func _headgear(ci: CanvasItem, head: Vector2, hr: float, accent: Color,
		secondary: Color, hair: Color, variant: int, phase: float,
		fine: bool) -> void:
	match variant:
		0:
			# Ember - goggles pushed up onto the forehead, lenses catching light.
			var strap := Chibi.smooth_open(PackedVector2Array([
				_pt(head, hr, -1.02, -0.52), _pt(head, hr, 0.0, -0.70),
				_pt(head, hr, 1.02, -0.54),
			]), 7)
			Chibi.taper(ci, strap, Color(0.16, 0.14, 0.16), hr * 0.20, 0.8, 1.0)
			for side in [-1.0, 1.0]:
				Chibi.ball(ci, _pt(head, hr, side * 0.44, -0.66), hr * 0.24,
					Color(0.20, 0.18, 0.20))
				Chibi.ball(ci, _pt(head, hr, side * 0.44, -0.66), hr * 0.185,
					Color(0.42, 0.66, 0.80))
				if fine:
					Chibi.soft(ci, _pt(head, hr, side * 0.38, -0.72), hr * 0.09,
						hr * 0.07, Color(1, 1, 1, 0.75), 14)
			# Swept-back licks over the crown.
			for i in 4:
				var t := float(i) / 3.0
				var root := _pt(head, hr, lerpf(-0.72, 0.56, t), -1.10)
				Chibi.taper(ci, Chibi.smooth_open(PackedVector2Array([
					root, root + Vector2(hr * (0.20 + 0.14 * t), -hr * 0.22),
					root + Vector2(hr * (0.34 + 0.26 * t), -hr * (0.30 + 0.22 * t)),
				]), 6), hair.lightened(0.06), hr * 0.24, 1.0, 0.08)
		1:
			# Aegis - a helmet dome over everything, with a crest.
			Chibi.form(ci, _ring(head, hr, [
				Vector2(0.00, -1.58), Vector2(0.86, -1.40), Vector2(1.30, -0.78),
				Vector2(1.38, -0.10), Vector2(1.10, -0.30), Vector2(0.60, -0.48),
				Vector2(0.00, -0.54), Vector2(-0.60, -0.48), Vector2(-1.10, -0.30),
				Vector2(-1.38, -0.10), Vector2(-1.30, -0.78), Vector2(-0.86, -1.40),
			], 8), secondary.darkened(0.38), 0.26, 0.32, 0.40)
			# Brow ridge: the band that turns a dome into a helmet.
			Chibi.form(ci, _ring(head, hr, [
				Vector2(0.00, -0.70), Vector2(0.86, -0.50), Vector2(1.34, -0.10),
				Vector2(1.30, 0.10), Vector2(0.82, -0.28), Vector2(0.00, -0.46),
				Vector2(-0.82, -0.28), Vector2(-1.30, 0.10), Vector2(-1.34, -0.10),
				Vector2(-0.86, -0.50),
			], 8), secondary.darkened(0.18), 0.24, 0.26, 0.30)
			Chibi.form(ci, _ring(head, hr, [
				Vector2(0.00, -1.94), Vector2(0.24, -1.66), Vector2(0.22, -1.02),
				Vector2(0.00, -1.14), Vector2(-0.22, -1.02), Vector2(-0.24, -1.66),
			], 7), accent, 0.26, 0.28, 0.34)
			if fine:
				Chibi.rim_light(ci, head, hr * 1.16, hr * 1.18, PI * 1.10, PI * 1.62,
					Color(1, 1, 1, 0.34), hr * 0.12)
		2:
			# Nova - a visor band across the brow with a live readout on it.
			var band := _ring(head, hr, [
				Vector2(-1.06, -0.54), Vector2(0.0, -0.72), Vector2(1.06, -0.56),
				Vector2(1.04, -0.30), Vector2(0.0, -0.46), Vector2(-1.04, -0.28),
			], 7)
			Chibi.form(ci, band, secondary.darkened(0.22), 0.24, 0.26, 0.32)
			if fine:
				var blip := 0.5 + 0.5 * sin(phase * 3.1)
				Chibi.ball(ci, _pt(head, hr, 0.42, -0.54), hr * 0.07,
					Color(0.5, 0.95, 1.0, 0.5 + 0.5 * blip))
		3:
			# Bramble - a hood up over the hair, and a plait escaping it.
			Chibi.form(ci, _ring(head, hr, [
				Vector2(0.00, -1.66), Vector2(0.92, -1.44), Vector2(1.38, -0.70),
				Vector2(1.46, 0.30), Vector2(1.20, 0.20), Vector2(1.06, -0.52),
				Vector2(0.56, -0.86), Vector2(0.00, -0.94), Vector2(-0.56, -0.86),
				Vector2(-1.06, -0.52), Vector2(-1.20, 0.20), Vector2(-1.46, 0.30),
				Vector2(-1.38, -0.70), Vector2(-0.92, -1.44),
			], 8), accent.darkened(0.58), 0.24, 0.26, 0.38)
			var plait := Chibi.smooth_open(PackedVector2Array([
				_pt(head, hr, -1.14, 0.10), _pt(head, hr, -1.28, 0.56),
				_pt(head, hr, -1.18, 1.06),
			]), 7)
			Chibi.taper(ci, plait, hair, hr * 0.24, 0.9, 0.35)
			if fine:
				for i in 3:
					Chibi.ball(ci, _pt(head, hr, -1.20 - 0.03 * float(i % 2),
						0.26 + 0.30 * float(i)), hr * 0.065, accent.lightened(0.20))
		4:
			# Rift - a hood thrown back, and a long fringe over one eye.
			Chibi.form(ci, _ring(head, hr, [
				Vector2(0.00, -1.10), Vector2(1.10, -0.80), Vector2(1.54, 0.10),
				Vector2(1.62, 0.94), Vector2(1.26, 0.72), Vector2(1.20, 0.02),
				Vector2(0.00, -0.52), Vector2(-1.20, 0.02), Vector2(-1.26, 0.72),
				Vector2(-1.62, 0.94), Vector2(-1.54, 0.10), Vector2(-1.10, -0.80),
			], 8), accent.darkened(0.62), 0.22, 0.26, 0.36)
			Chibi.form(ci, _ring(head, hr, [
				Vector2(0.10, -0.86), Vector2(0.86, -0.62), Vector2(1.04, 0.10),
				Vector2(0.80, 0.44), Vector2(0.46, 0.10), Vector2(0.18, -0.36),
			], 8), hair, 0.22, 0.20, 0.40)
		_:
			pass
