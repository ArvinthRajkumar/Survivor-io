class_name HeroPortrait
extends RefCounted
## Chibi bust portraits for the operative roster, drawn procedurally.
##
## The five operatives share one head-and-shoulders construction so they read as
## the same squad, and differ only in the things a player actually uses to tell
## people apart: hair, headgear, expression and the kit on their shoulders. That
## is deliberate — swapping in five unrelated silhouettes would look like five
## games, and a plain polygon (which is what this replaced) looks like none.
##
## Everything is scaled from `r`, so the same function draws a 40px roster
## thumbnail and a 200px card portrait without a second set of numbers.

const SKIN := Color(0.99, 0.87, 0.78)


## `variant` is HeroData.portrait_shape: 0 Ember, 1 Aegis, 2 Nova, 3 Bramble,
## 4 Rift. `phase` drives the small idle motions (blink, sway, glow).
static func draw_bust(ci: CanvasItem, c: Vector2, r: float, accent: Color,
		secondary: Color, variant: int, phase: float = 0.0) -> void:
	var hair := _hair_of(accent, variant)
	var head := c + Vector2(0.0, -r * 0.16)
	var head_r := r * 0.62

	_draw_shoulders(ci, c, r, accent, secondary, variant)
	_draw_hair_back(ci, head, head_r, hair, variant, phase)
	_draw_head_shape(ci, head, head_r)
	_draw_face(ci, head, head_r, accent, hair, variant, phase)
	_draw_headgear(ci, head, head_r, accent, secondary, hair, variant, phase)


## Deep, desaturated cast of the accent, so each operative's hair belongs to
## their own palette without a second colour having to be authored.
static func _hair_of(accent: Color, variant: int) -> Color:
	match variant:
		0:
			return Color(0.28, 0.12, 0.10)          # Ember - dark auburn
		1:
			return Color(0.20, 0.22, 0.28)          # Aegis - steel grey
		3:
			return Color(0.13, 0.24, 0.16)          # Bramble - deep moss
		4:
			return Color(0.20, 0.14, 0.30)          # Rift - dark violet
		_:
			return Color(0.15, 0.19, 0.30)          # Nova - navy


# --- Body -------------------------------------------------------------------

static func _draw_shoulders(ci: CanvasItem, c: Vector2, r: float, accent: Color,
		secondary: Color, variant: int) -> void:
	var top := c.y + r * 0.50
	var jacket := PackedVector2Array([
		Vector2(c.x - r * 0.86, top + r * 0.62),
		Vector2(c.x - r * 0.74, top + r * 0.04),
		Vector2(c.x - r * 0.30, top - r * 0.14),
		Vector2(c.x + r * 0.30, top - r * 0.14),
		Vector2(c.x + r * 0.74, top + r * 0.04),
		Vector2(c.x + r * 0.86, top + r * 0.62),
	])
	Draw2D.neon_polygon(ci, jacket, accent.darkened(0.62), accent, maxf(1.5, r * 0.045))

	# Collar, then the kit that tells the operatives apart at shoulder height.
	var collar := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		collar.append(Vector2(c.x + cos(a) * r * 0.32, top + r * 0.02 + sin(a) * r * 0.15))
	ci.draw_colored_polygon(collar, secondary)

	match variant:
		1:
			# Aegis - heavy pauldrons.
			for side in [-1.0, 1.0]:
				var pad := PackedVector2Array([
					Vector2(c.x + side * r * 0.52, top + r * 0.00),
					Vector2(c.x + side * r * 0.96, top + r * 0.16),
					Vector2(c.x + side * r * 0.92, top + r * 0.56),
					Vector2(c.x + side * r * 0.50, top + r * 0.42),
				])
				Draw2D.neon_polygon(ci, pad, secondary.darkened(0.35), secondary, maxf(1.0, r * 0.04))
		3:
			# Bramble - a sprig of leaves over one shoulder.
			for i in 3:
				var t := float(i) / 2.0
				var root := Vector2(c.x - r * 0.58 - t * r * 0.10, top + r * 0.34 - t * r * 0.26)
				var leaf := PackedVector2Array([
					root,
					root + Vector2(-r * 0.20, -r * 0.12),
					root + Vector2(-r * 0.06, -r * 0.24),
				])
				ci.draw_colored_polygon(leaf, Color(0.42, 0.78, 0.40))
		4:
			# Rift - a cloak clasp throwing a small glow.
			var clasp := c + Vector2(0.0, top - c.y + r * 0.30)
			ci.draw_circle(clasp, r * 0.13, Color(secondary.r, secondary.g, secondary.b, 0.35))
			ci.draw_circle(clasp, r * 0.07, secondary)
		0:
			# Ember - a strap of canisters across the chest.
			ci.draw_line(Vector2(c.x - r * 0.62, top + r * 0.52),
				Vector2(c.x + r * 0.54, top + r * 0.10),
				secondary.darkened(0.25), maxf(1.5, r * 0.09))
		_:
			# Nova - a shoulder tool loop.
			ci.draw_arc(Vector2(c.x + r * 0.62, top + r * 0.26), r * 0.16,
				0.0, TAU, 12, secondary, maxf(1.0, r * 0.05))


# --- Head -------------------------------------------------------------------

static func _draw_head_shape(ci: CanvasItem, head: Vector2, hr: float) -> void:
	var face := PackedVector2Array()
	for i in 18:
		var a := TAU * float(i) / 18.0
		var rr := hr * (1.0 - 0.06 * cos(a * 2.0))
		face.append(head + Vector2(cos(a) * rr, sin(a) * rr * 0.98))
	ci.draw_colored_polygon(face, SKIN)
	# Ears.
	for side in [-1.0, 1.0]:
		ci.draw_circle(head + Vector2(side * hr * 0.95, hr * 0.06), hr * 0.15, SKIN.darkened(0.08))


static func _draw_hair_back(ci: CanvasItem, head: Vector2, hr: float, hair: Color,
		variant: int, phase: float) -> void:
	var shell := PackedVector2Array()
	for i in 16:
		var a := PI * 0.92 + PI * 1.16 * float(i) / 15.0
		shell.append(head + Vector2(cos(a), sin(a)) * hr * 1.12)
	var drop := Vector2(0.0, hr * (0.95 if variant == 2 else 0.55))
	shell.append(shell[shell.size() - 1] + drop)
	shell.append(shell[0] + drop)
	ci.draw_colored_polygon(shell, hair)

	# Rift keeps a hood over the back of the head instead of loose hair.
	if variant == 4:
		var hood := PackedVector2Array()
		for i in 16:
			var a := PI * 0.86 + PI * 1.28 * float(i) / 15.0
			hood.append(head + Vector2(cos(a), sin(a)) * hr * 1.24)
		hood.append(hood[hood.size() - 1] + Vector2(0.0, hr * 0.5))
		hood.append(hood[0] + Vector2(0.0, hr * 0.5))
		ci.draw_colored_polygon(hood, hair.darkened(0.25))

	# Nova wears a side tail that sways.
	if variant == 2:
		var sway := sin(phase * 2.2) * hr * 0.08
		var root := head + Vector2(hr * 0.86, -hr * 0.10)
		ci.draw_line(root, root + Vector2(hr * 0.30 + sway, hr * 1.05), hair, maxf(2.0, hr * 0.24), true)


static func _draw_face(ci: CanvasItem, head: Vector2, hr: float, accent: Color,
		hair: Color, variant: int, phase: float) -> void:
	var ink := Color(0.08, 0.10, 0.17)
	var eye_y := head.y + hr * 0.08
	var blink := fposmod(phase + float(variant) * 0.9, 4.2) < 0.13

	# Aegis's visor covers the eyes entirely, so the face reads as a helmet.
	if variant == 1:
		var visor := PackedVector2Array([
			head + Vector2(-hr * 0.94, -hr * 0.30),
			head + Vector2(hr * 0.94, -hr * 0.30),
			head + Vector2(hr * 0.80, hr * 0.26),
			head + Vector2(-hr * 0.80, hr * 0.26),
		])
		ci.draw_colored_polygon(visor, Color(0.06, 0.10, 0.16))
		# A soft band behind the hard line, so the visor looks lit from the
		# inside rather than scratched.
		var glow := 0.55 + 0.45 * absf(sin(phase * 1.6))
		ci.draw_line(head + Vector2(-hr * 0.78, -hr * 0.02), head + Vector2(hr * 0.78, -hr * 0.02),
			Color(accent.r, accent.g, accent.b, glow * 0.30), maxf(2.0, hr * 0.30), true)
		ci.draw_line(head + Vector2(-hr * 0.74, -hr * 0.02), head + Vector2(hr * 0.74, -hr * 0.02),
			Color(accent.r, accent.g, accent.b, glow), maxf(1.5, hr * 0.12), true)
		_draw_mouth(ci, head, hr, ink, variant)
		return

	for side in [-1.0, 1.0]:
		var e := head + Vector2(side * hr * 0.38, eye_y - head.y)
		if blink:
			ci.draw_line(e - Vector2(hr * 0.20, 0.0), e + Vector2(hr * 0.20, 0.0), ink,
				maxf(1.5, hr * 0.09), true)
			continue
		ci.draw_circle(e, hr * 0.20, ink)
		# Rift's eyes glow; everyone else gets a normal iris.
		var iris := accent.lerp(Color.WHITE, 0.25) if variant != 4 else accent.lerp(Color.WHITE, 0.55)
		ci.draw_circle(e + Vector2(0.0, hr * 0.05), hr * 0.11, iris)
		ci.draw_circle(e + Vector2(-hr * 0.07, -hr * 0.09), hr * 0.06, Color(1, 1, 1, 0.95))

	# Brows carry most of the personality.
	var brow_y := eye_y - hr * 0.34
	for side in [-1.0, 1.0]:
		var inner := head + Vector2(side * hr * 0.20, brow_y - head.y)
		var outer := head + Vector2(side * hr * 0.60, brow_y - head.y)
		match variant:
			0:
				# Ember - angled down at the inside, a permanent scowl.
				inner += Vector2(0.0, hr * 0.10)
			3:
				# Bramble - raised and soft.
				outer += Vector2(0.0, -hr * 0.06)
			4:
				# Rift - one brow higher than the other.
				inner += Vector2(0.0, hr * 0.06 * side)
		ci.draw_line(inner, outer, hair, maxf(1.5, hr * 0.10), true)

	# Cheeks and nose.
	for side in [-1.0, 1.0]:
		ci.draw_circle(head + Vector2(side * hr * 0.66, eye_y - head.y + hr * 0.26),
			hr * 0.14, Color(1.0, 0.55, 0.55, 0.22))
	ci.draw_circle(head + Vector2(0.0, eye_y - head.y + hr * 0.26), hr * 0.05, SKIN.darkened(0.22))
	_draw_mouth(ci, head, hr, ink, variant)


static func _draw_mouth(ci: CanvasItem, head: Vector2, hr: float, ink: Color, variant: int) -> void:
	var mouth := head + Vector2(0.0, hr * 0.50)
	match variant:
		0:
			# Ember - a hard, flat line.
			ci.draw_line(mouth - Vector2(hr * 0.18, 0.0), mouth + Vector2(hr * 0.18, 0.0),
				ink, maxf(1.2, hr * 0.07), true)
		1:
			ci.draw_line(mouth - Vector2(hr * 0.14, 0.0), mouth + Vector2(hr * 0.14, 0.0),
				ink, maxf(1.2, hr * 0.06), true)
		4:
			# Rift - a small smirk, higher on one side.
			ci.draw_line(mouth - Vector2(hr * 0.16, hr * 0.04), mouth + Vector2(hr * 0.16, -hr * 0.06),
				ink, maxf(1.2, hr * 0.06), true)
		_:
			ci.draw_arc(mouth - Vector2(0.0, hr * 0.10), hr * 0.18,
				PI * 0.15, PI * 0.85, 8, ink, maxf(1.2, hr * 0.06), true)


static func _draw_headgear(ci: CanvasItem, head: Vector2, hr: float, accent: Color,
		secondary: Color, hair: Color, variant: int, phase: float) -> void:
	match variant:
		0:
			# Ember - swept-back flame-lick hair and goggles pushed up.
			for i in 4:
				var t := float(i) / 3.0
				var root := head + Vector2(lerpf(-0.80, 0.62, t) * hr, -hr * 0.66)
				var tip := root + Vector2(hr * (0.24 + 0.16 * t), -hr * (0.34 + 0.26 * t))
				ci.draw_line(root, tip, hair, maxf(1.5, hr * 0.20), true)
			ci.draw_line(head + Vector2(-hr * 0.92, -hr * 0.52), head + Vector2(hr * 0.92, -hr * 0.56),
				secondary.darkened(0.15), maxf(1.5, hr * 0.16), true)
			for side in [-1.0, 1.0]:
				ci.draw_circle(head + Vector2(side * hr * 0.42, -hr * 0.56), hr * 0.19,
					Color(0.35, 0.55, 0.70, 0.95))
		1:
			# Aegis - a full helmet dome with a crest.
			# The dome stops at the visor line. Its arc is cut there rather than
			# closed with extra points below the ends: that shape overlaps itself
			# and Godot refuses to fill it, leaving a bare outline over skin.
			var cut := asin(0.30 / 1.14)
			var dome := PackedVector2Array()
			for i in 16:
				var a := PI + cut + (PI - 2.0 * cut) * float(i) / 15.0
				dome.append(head + Vector2(cos(a), sin(a)) * hr * 1.14)
			Draw2D.neon_polygon(ci, dome, secondary.darkened(0.45), secondary, maxf(1.2, hr * 0.07))
			ci.draw_line(head + Vector2(0.0, -hr * 1.20), head + Vector2(0.0, -hr * 0.62),
				accent, maxf(1.5, hr * 0.14), true)
			# Cheek guards down either side of the visor, so the helmet closes
			# around the face instead of sitting on it like a hat.
			for side in [-1.0, 1.0]:
				Draw2D.neon_polygon(ci, PackedVector2Array([
					head + Vector2(side * hr * 1.10, -hr * 0.34),
					head + Vector2(side * hr * 0.78, -hr * 0.34),
					head + Vector2(side * hr * 0.66, hr * 0.72),
					head + Vector2(side * hr * 0.98, hr * 0.52),
				]), secondary.darkened(0.55), secondary, maxf(1.0, hr * 0.05))
		3:
			# Bramble - a leafy hood with a single bud.
			var hood := PackedVector2Array()
			for i in 16:
				var a := PI * 0.98 + PI * 1.04 * float(i) / 15.0
				hood.append(head + Vector2(cos(a), sin(a)) * hr * 1.18)
			hood.append(head + Vector2(hr * 1.05, hr * 0.22))
			hood.append(head + Vector2(-hr * 1.05, hr * 0.22))
			Draw2D.neon_polygon(ci, hood, Color(0.18, 0.36, 0.22), Color(0.42, 0.78, 0.40),
				maxf(1.2, hr * 0.06))
			# Hood sides falling past the jaw. The dome on its own read as a bowl
			# balanced on her head rather than something she is inside.
			for side in [-1.0, 1.0]:
				Draw2D.neon_polygon(ci, PackedVector2Array([
					head + Vector2(side * hr * 1.16, -hr * 0.12),
					head + Vector2(side * hr * 0.84, -hr * 0.16),
					head + Vector2(side * hr * 0.78, hr * 0.78),
					head + Vector2(side * hr * 1.08, hr * 0.60),
				]), Color(0.15, 0.31, 0.19), Color(0.42, 0.78, 0.40), maxf(1.0, hr * 0.05))
			# Leaf points along the brim, which is what makes it a leafy hood and
			# not a hoodie.
			for i in 5:
				var t := float(i) / 4.0
				var la := PI * 1.06 + PI * 0.88 * t
				var dir := Vector2(cos(la), sin(la))
				var side_v := Vector2(-dir.y, dir.x)
				ci.draw_colored_polygon(PackedVector2Array([
					head + dir * hr * 1.14 + side_v * hr * 0.17,
					head + dir * hr * 1.42,
					head + dir * hr * 1.14 - side_v * hr * 0.17,
				]), Color(0.34, 0.64, 0.33))
			var bud := head + Vector2(hr * 0.16, -hr * 1.28)
			ci.draw_line(head + Vector2(hr * 0.10, -hr * 1.05), bud,
				Color(0.42, 0.78, 0.40), maxf(1.2, hr * 0.07), true)
			ci.draw_circle(bud, hr * 0.15, Color(0.95, 0.82, 0.35))
		4:
			# Rift - hood brim plus a drifting mote.
			var brim_cut := asin(0.26 / 1.22)
			var brim := PackedVector2Array()
			for i in 14:
				var a := PI + brim_cut + (PI - 2.0 * brim_cut) * float(i) / 13.0
				brim.append(head + Vector2(cos(a), sin(a)) * hr * 1.22)
			ci.draw_colored_polygon(brim, hair.darkened(0.15))
			# A lit rim along the brim edge, so the hood has a shape of its own
			# against hair of nearly the same colour.
			ci.draw_polyline(brim, Color(secondary.r, secondary.g, secondary.b, 0.55),
				maxf(1.0, hr * 0.05), true)
			var mote := head + Vector2(hr * (0.95 + 0.10 * sin(phase * 1.7)), -hr * 0.95)
			ci.draw_circle(mote, hr * 0.16, Color(secondary.r, secondary.g, secondary.b, 0.30))
			ci.draw_circle(mote, hr * 0.08, secondary)
		_:
			# Nova - bangs plus the headband the player character wears in-run,
			# so the roster portrait and the operative on the field match.
			var widths := [0.92, 0.50, 0.08, -0.34, -0.78]
			for i in widths.size():
				var x: float = float(widths[i]) * hr
				var fall := hr * (0.34 + 0.16 * float((i * 3) % 4) / 3.0)
				ci.draw_colored_polygon(PackedVector2Array([
					head + Vector2(x - hr * 0.30, -hr * 0.74),
					head + Vector2(x + hr * 0.34, -hr * 0.80),
					head + Vector2(x + hr * 0.16, -hr * 0.74 + fall),
				]), hair)
			ci.draw_line(head + Vector2(-hr * 0.96, -hr * 0.44), head + Vector2(hr * 0.96, -hr * 0.48),
				secondary, maxf(1.5, hr * 0.18), true)
			ci.draw_circle(head + Vector2(hr * 0.30, -hr * 0.46), hr * 0.13, Color(1, 1, 1, 0.85))
