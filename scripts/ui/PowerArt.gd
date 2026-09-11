class_name PowerArt
extends RefCounted
## Shared vector artwork for every power and passive.
##
## One library draws both the HUD/card icons and the entities that appear in the
## world, so a Molotov in your hand and the Molotov icon in the bottom bar are
## recognisably the same object. Everything is plain CanvasItem draw calls at a
## normalised radius, which keeps the project asset-free and lets the same shape
## scale from a 40px icon to a 60px world entity.
##
## Every function takes `phase` (seconds) so art can animate — rotors spin,
## flames flicker, lenses pulse.

# --- Small helpers ----------------------------------------------------------

static func _poly(points: PackedVector2Array, angle: float, offset: Vector2, scale: float = 1.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p.rotated(angle) * scale + offset)
	return out


static func _fill(ci: CanvasItem, points: PackedVector2Array, fill: Color, outline: Color, width: float = 2.0) -> void:
	if points.size() < 3:
		return
	ci.draw_colored_polygon(points, fill)
	var loop := points.duplicate()
	loop.append(points[0])
	ci.draw_polyline(loop, outline, width, true)


static func _rounded_body(radius: float, squash: float = 0.75) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * float(i) / 10.0
		pts.append(Vector2(cos(a) * radius, sin(a) * radius * squash))
	return pts


static func _shade(color: Color, amount: float) -> Color:
	return color.darkened(amount) if amount > 0.0 else color.lightened(-amount)


# --- Entry point ------------------------------------------------------------

## Draws the art for `art_id` centred on `center` at `radius`.
static func draw(ci: CanvasItem, art_id: StringName, center: Vector2, radius: float,
		color: Color, secondary: Color, phase: float = 0.0) -> void:
	match art_id:
		&"katana":
			draw_katana(ci, center, radius, color, secondary, phase)
		&"drone":
			draw_drone(ci, center, radius, color, secondary, phase, false)
		&"healing_drone":
			draw_drone(ci, center, radius, color, secondary, phase, true)
		&"domain":
			draw_domain(ci, center, radius, color, secondary, phase)
		&"molotov":
			draw_molotov(ci, center, radius, color, secondary, phase)
		&"drill":
			draw_drill(ci, center, radius, color, secondary, phase)
		&"laser":
			draw_laser_emitter(ci, center, radius, color, secondary, phase)
		&"spinners":
			draw_saw(ci, center, radius, color, secondary, phase)
		&"overclock_core":
			draw_core(ci, center, radius, color, secondary, phase)
		&"alloy_plating":
			draw_plating(ci, center, radius, color, secondary, phase)
		&"kinetic_boots":
			draw_boots(ci, center, radius, color, secondary, phase)
		&"resonance_lens":
			draw_lens(ci, center, radius, color, secondary, phase)
		&"salvage_magnet":
			draw_magnet(ci, center, radius, color, secondary, phase)

		# --- Starting weapons ---
		&"revolver":
			draw_gun(ci, center, radius, color, secondary, phase, true)
		&"machine_pistol":
			draw_gun(ci, center, radius, color, secondary, phase, false)
		&"longbow":
			draw_bow(ci, center, radius, color, secondary, phase)
		&"spear":
			draw_spear(ci, center, radius, color, secondary, phase)
		&"chakram":
			draw_chakram(ci, center, radius, color, secondary, phase, false)
		&"warhammer":
			draw_hammer(ci, center, radius, color, secondary, phase)
		&"flamethrower":
			draw_flame(ci, center, radius, color, secondary, phase)

		# --- Powers ---
		&"arc_coil":
			draw_arc_coil(ci, center, radius, color, secondary, phase)
		&"seeker_swarm":
			draw_missile(ci, center, radius, color, secondary, phase)
		&"grenade_volley":
			draw_grenade(ci, center, radius, color, secondary, phase)
		&"boomerang_fang":
			draw_chakram(ci, center, radius, color, secondary, phase, true)
		&"ricochet_orb":
			draw_orb(ci, center, radius, color, secondary, phase)
		&"rail_lance":
			draw_rail(ci, center, radius, color, secondary, phase)
		&"frost_nova":
			draw_frost(ci, center, radius, color, secondary, phase)
		&"sun_flare":
			draw_sun(ci, center, radius, color, secondary, phase)
		&"thorn_aura":
			draw_thorns(ci, center, radius, color, secondary, phase)
		&"mine_field":
			draw_mine(ci, center, radius, color, secondary, phase)
		&"shock_turret":
			draw_turret(ci, center, radius, color, secondary, phase)
		&"blade_storm":
			draw_blade_storm(ci, center, radius, color, secondary, phase)
		&"void_well":
			draw_well(ci, center, radius, color, secondary, phase)

		# --- Passives ---
		&"hollow_point":
			draw_hollow_point(ci, center, radius, color, secondary, phase)
		&"vital_weave":
			draw_weave(ci, center, radius, color, secondary, phase)
		&"siege_charge":
			draw_siege(ci, center, radius, color, secondary, phase)
		&"ablative_shell":
			draw_shell(ci, center, radius, color, secondary, phase)
		&"split_barrel":
			draw_split_barrel(ci, center, radius, color, secondary, phase)
		&"long_fuse":
			draw_fuse(ci, center, radius, color, secondary, phase)
		&"omen_dice":
			draw_dice(ci, center, radius, color, secondary, phase)
		_:
			draw_core(ci, center, radius, color, secondary, phase)


# --- Powers -----------------------------------------------------------------

## Quadcopter seen from above: chassis, two rotor booms with blurred blades, a
## glowing sensor eye, and either a gun barrel or a medical cross.
static func draw_drone(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float, medical: bool = false) -> void:
	var boom := r * 0.86
	var dark := _shade(color, 0.55)

	# Rotor booms.
	for i in 2:
		var a := PI * 0.25 + PI * float(i) * 0.5
		var dir := Vector2(cos(a), sin(a))
		ci.draw_line(c - dir * boom, c + dir * boom, dark, r * 0.16, true)

	# Spinning rotor discs.
	var spin := phase * 22.0
	for i in 4:
		var a := PI * 0.25 + TAU * float(i) / 4.0
		var hub := c + Vector2(cos(a), sin(a)) * boom
		ci.draw_circle(hub, r * 0.30, Color(secondary.r, secondary.g, secondary.b, 0.16))
		for blade in 2:
			var ba := spin + PI * float(blade) + float(i) * 0.7
			var tip := hub + Vector2(cos(ba), sin(ba)) * r * 0.30
			ci.draw_line(hub, tip, Color(secondary.r, secondary.g, secondary.b, 0.75), 2.0, true)
		ci.draw_circle(hub, r * 0.09, dark)

	# Chassis.
	var bob := sin(phase * 3.0) * r * 0.05
	var body := _poly(_rounded_body(r * 0.62, 0.78), 0.0, c + Vector2(0.0, bob))
	_fill(ci, body, _shade(color, 0.45), color, maxf(1.5, r * 0.09))

	# Canopy / sensor eye.
	var eye := c + Vector2(0.0, bob - r * 0.08)
	ci.draw_circle(eye, r * 0.26, Color(secondary.r, secondary.g, secondary.b, 0.9))
	ci.draw_circle(eye, r * 0.13, Color(1, 1, 1, 0.95))

	if medical:
		# Red cross under the chassis.
		var arm := r * 0.13
		var span := r * 0.34
		var cc := c + Vector2(0.0, bob + r * 0.30)
		ci.draw_rect(Rect2(cc - Vector2(arm, span * 0.5), Vector2(arm * 2.0, span)), secondary)
		ci.draw_rect(Rect2(cc - Vector2(span * 0.5, arm), Vector2(span, arm * 2.0)), secondary)
	else:
		# Under-slung gun barrel with a muzzle glow that pulses as it fires.
		var muzzle := c + Vector2(0.0, bob + r * 0.62)
		ci.draw_line(c + Vector2(0.0, bob + r * 0.25), muzzle, dark, r * 0.20, true)
		var heat := 0.45 + 0.55 * absf(sin(phase * 6.0))
		ci.draw_circle(muzzle, r * 0.16 * heat, Color(secondary.r, secondary.g, secondary.b, heat))


## A katana held point-up: curved blade with a hamon temper line, a lozenge
## tsuba guard, a wrapped tsuka, and a drifting glint that travels the edge.
## The same geometry is reused by the world sprite the player carries, so the
## icon and the weapon in your hands are unmistakably one object.
static func draw_katana(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var tilt := -0.42 + sin(phase * 1.6) * 0.03
	var steel := Color(0.86, 0.91, 0.98)
	var edge := Color(1.0, 1.0, 1.0, 0.95)

	# Blade. The curve builds toward the tip rather than bulging in the middle:
	# a sine bulge reads as a scimitar, while an arc that only deviates near the
	# point is what makes a katana a katana.
	var span := r * 1.62
	var curve := r * 0.30
	var blade := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		blade.append(Vector2(-curve * t * t - r * 0.055, -r * 0.34 - span * t * 0.62))
	for i in range(8, -1, -1):
		var t2 := float(i) / 8.0
		blade.append(Vector2(-curve * t2 * t2 + r * 0.085, -r * 0.34 - span * t2 * 0.62))
	_fill(ci, _poly(blade, tilt, c), steel, _shade(steel, 0.35), maxf(1.0, r * 0.05))

	# Hamon: the wavy temper line along the cutting edge.
	var hamon := PackedVector2Array()
	for i in 9:
		var t3 := float(i) / 8.0
		hamon.append(Vector2(
			-curve * t3 * t3 + r * 0.045 + sin(t3 * 9.0) * r * 0.012,
			-r * 0.34 - span * t3 * 0.62))
	ci.draw_polyline(_poly(hamon, tilt, c), Color(edge.r, edge.g, edge.b, 0.75),
		maxf(1.0, r * 0.035), true)

	# Glint travelling up the edge.
	var g := fposmod(phase * 0.75, 1.0)
	var glint := Vector2(-curve * g * g + r * 0.05, -r * 0.34 - span * g * 0.62).rotated(tilt) + c
	ci.draw_circle(glint, r * 0.11, Color(1, 1, 1, 0.55 * sin(g * PI)))

	# Tsuba (guard): a lozenge with a bright rim.
	var guard := PackedVector2Array([
		Vector2(0.0, -r * 0.52), Vector2(r * 0.30, -r * 0.34),
		Vector2(0.0, -r * 0.16), Vector2(-r * 0.30, -r * 0.34),
	])
	_fill(ci, _poly(guard, tilt, c), _shade(secondary, 0.25), secondary, maxf(1.0, r * 0.05))

	# Tsuka (hilt) with its diamond ito wrap.
	var hilt := PackedVector2Array([
		Vector2(-r * 0.115, -r * 0.30), Vector2(r * 0.115, -r * 0.30),
		Vector2(r * 0.095, r * 0.72), Vector2(-r * 0.095, r * 0.72),
	])
	_fill(ci, _poly(hilt, tilt, c), _shade(color, 0.62), _shade(color, 0.30), maxf(1.0, r * 0.05))
	for i in 4:
		var y := -r * 0.18 + r * 0.22 * float(i)
		var a := Vector2(-r * 0.12, y).rotated(tilt) + c
		var b := Vector2(r * 0.12, y + r * 0.10).rotated(tilt) + c
		ci.draw_line(a, b, Color(secondary.r, secondary.g, secondary.b, 0.65), maxf(1.0, r * 0.04), true)
		ci.draw_line(Vector2(-r * 0.12, y + r * 0.10).rotated(tilt) + c,
			Vector2(r * 0.12, y).rotated(tilt) + c,
			Color(secondary.r, secondary.g, secondary.b, 0.35), maxf(1.0, r * 0.03), true)

	# Kashira (pommel cap).
	ci.draw_circle(Vector2(0.0, r * 0.74).rotated(tilt) + c, r * 0.11, secondary)


## The crescent left behind by a sweep. `t` runs 0 (just struck) to 1 (gone);
## `arc` is the total swept angle and `facing` its centre direction.
static func draw_slash(ci: CanvasItem, c: Vector2, reach: float, arc: float,
		facing: float, t: float, color: Color, secondary: Color) -> void:
	var fade := 1.0 - t
	# A sweep that has barely started has no area yet; drawing it would hand the
	# renderer a degenerate polygon. A full turn is capped just short of closing
	# for the same reason: at exactly TAU the band's two ends meet and the ring
	# stops being a simple polygon.
	if fade <= 0.01 or arc <= 0.06 or reach <= 1.0:
		return
	arc = minf(arc, TAU - 0.14)

	# The tip travels a circle of fixed radius, because that is what the end of a
	# blade does. What varies is the ribbon's *thickness*: near nothing at both
	# ends, widest around the middle of the sweep. That lens shape is the whole
	# difference between "a blade was drawn through here" and the slice of a
	# ring this used to draw, which read as a cone of damage sitting on the
	# ground.
	var outer := reach * (0.92 + 0.10 * t)
	var thickest := reach * (0.20 + 0.11 * t)
	var steps := 24
	var band := PackedVector2Array()
	for i in steps + 1:
		var a := facing - arc * 0.5 + arc * float(i) / float(steps)
		band.append(c + Vector2(cos(a), sin(a)) * outer)
	for i in range(steps, -1, -1):
		var u := float(i) / float(steps)
		var a2 := facing - arc * 0.5 + arc * u
		band.append(c + Vector2(cos(a2), sin(a2)) * (outer - thickest * _taper(u)))
	ci.draw_colored_polygon(band, Color(secondary.r, secondary.g, secondary.b, 0.38 * fade * fade))

	# The cutting edge itself: the same lens, a fraction of the thickness, in
	# near-white. Drawn as a polygon rather than a polyline because a polyline is
	# one constant width from end to end and would blunt both tips.
	var edge_w := thickest * 0.42
	var edge := PackedVector2Array()
	for i in steps + 1:
		var a3 := facing - arc * 0.5 + arc * float(i) / float(steps)
		edge.append(c + Vector2(cos(a3), sin(a3)) * outer)
	for i in range(steps, -1, -1):
		var u2 := float(i) / float(steps)
		var a4 := facing - arc * 0.5 + arc * u2
		edge.append(c + Vector2(cos(a4), sin(a4)) * (outer - edge_w * _taper(u2)))
	ci.draw_colored_polygon(edge, Color(1, 1, 1, 0.85 * fade))

	# Sparks flying off the leading tip.
	var tip := c + Vector2(cos(facing + arc * 0.5), sin(facing + arc * 0.5)) * outer
	for i in 3:
		var sa := facing + arc * 0.5 + (float(i) - 1.0) * 0.30
		ci.draw_line(tip, tip + Vector2(cos(sa), sin(sa)) * reach * 0.18 * fade,
			Color(1, 1, 1, 0.5 * fade), 2.0, true)


## Thickness profile along the sweep, 0 at the ends and 1 in the middle. The
## floor keeps the two edges from meeting exactly at the tips, where coincident
## vertices would give the triangulator a degenerate polygon.
static func _taper(u: float) -> float:
	return 0.06 + 0.94 * pow(sin(PI * clampf(u, 0.0, 1.0)), 0.65)


## A hex-lattice bubble: two counter-rotating hex rings plus a bright core.
static func draw_domain(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var pulse := 0.94 + 0.06 * sin(phase * 2.4)
	var outer := Draw2D.polygon_points(6, r * pulse, phase * 0.5)
	ci.draw_colored_polygon(_poly(outer, 0.0, c), Color(color.r, color.g, color.b, 0.14))
	var loop := _poly(outer, 0.0, c)
	loop.append(loop[0])
	ci.draw_polyline(loop, color, maxf(1.5, r * 0.09), true)

	var inner := _poly(Draw2D.polygon_points(6, r * 0.58 * pulse, -phase * 0.8), 0.0, c)
	inner.append(inner[0])
	ci.draw_polyline(inner, Color(color.r, color.g, color.b, 0.55), maxf(1.0, r * 0.05), true)

	# Lattice spokes so it reads as a field rather than a plain ring.
	for i in 6:
		var a := phase * 0.5 + TAU * float(i) / 6.0
		var dir := Vector2(cos(a), sin(a))
		ci.draw_line(c + dir * r * 0.58, c + dir * r * pulse,
			Color(color.r, color.g, color.b, 0.4), maxf(1.0, r * 0.04), true)

	ci.draw_circle(c, r * 0.22, Color(secondary.r, secondary.g, secondary.b, 0.9))
	ci.draw_circle(c, r * 0.10, Color(1, 1, 1, 0.9))


## A bottle: shoulders, neck, liquid line and a burning rag.
static func draw_molotov(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var glass := Color(0.55, 0.75, 0.72, 0.95)
	var body := PackedVector2Array([
		Vector2(-r * 0.42, r * 0.90),
		Vector2(-r * 0.46, r * 0.05),
		Vector2(-r * 0.18, -r * 0.32),
		Vector2(-r * 0.16, -r * 0.66),
		Vector2(r * 0.16, -r * 0.66),
		Vector2(r * 0.18, -r * 0.32),
		Vector2(r * 0.46, r * 0.05),
		Vector2(r * 0.42, r * 0.90),
	])
	_fill(ci, _poly(body, 0.0, c), Color(color.r * 0.45, color.g * 0.30, color.b * 0.20, 0.95),
		glass, maxf(1.5, r * 0.08))

	# Fuel level.
	var fuel := PackedVector2Array([
		Vector2(-r * 0.40, r * 0.88),
		Vector2(-r * 0.43, r * 0.18),
		Vector2(r * 0.43, r * 0.18),
		Vector2(r * 0.40, r * 0.88),
	])
	ci.draw_colored_polygon(_poly(fuel, 0.0, c), Color(color.r, color.g * 0.55, 0.12, 0.85))

	# Burning rag: three flickering tongues.
	var base := c + Vector2(0.0, -r * 0.66)
	for i in 3:
		var flick := sin(phase * 11.0 + float(i) * 2.1) * r * 0.10
		# Tongue leans with the flicker so the flame reads as alive.
		var tip := base + Vector2(flick, -r * (0.42 + 0.16 * absf(sin(phase * 7.0 + float(i)))))
		var flame := PackedVector2Array([
			base + Vector2(-r * 0.15 + float(i) * r * 0.15, 0.0),
			tip,
			base + Vector2(-r * 0.02 + float(i) * r * 0.15, 0.0),
		])
		var hot := Color(1.0, 0.75 - 0.15 * float(i), 0.20, 0.95)
		ci.draw_colored_polygon(_poly(flame, 0.0, Vector2.ZERO), hot)
	ci.draw_circle(base, r * 0.14, Color(1.0, 0.9, 0.5, 0.8))


## A drill bit: tapered cone with helical flutes and a collar.
static func draw_drill(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var steel := Color(0.72, 0.78, 0.88)
	var cone := PackedVector2Array([
		Vector2(0.0, -r * 1.0),
		Vector2(r * 0.42, r * 0.32),
		Vector2(-r * 0.42, r * 0.32),
	])
	_fill(ci, _poly(cone, 0.0, c), _shade(color, 0.35), steel, maxf(1.5, r * 0.08))

	# Helical flutes: horizontal chords that slide upward, reading as rotation.
	for i in 4:
		var t := fposmod(float(i) / 4.0 + phase * 1.6, 1.0)
		var y := lerpf(-r * 0.85, r * 0.26, t)
		var half := lerpf(r * 0.06, r * 0.38, t)
		ci.draw_line(c + Vector2(-half, y), c + Vector2(half, y),
			Color(secondary.r, secondary.g, secondary.b, 0.75), maxf(1.0, r * 0.07), true)

	# Collar and shank.
	ci.draw_rect(Rect2(c + Vector2(-r * 0.46, r * 0.30), Vector2(r * 0.92, r * 0.22)), steel)
	ci.draw_rect(Rect2(c + Vector2(-r * 0.28, r * 0.50), Vector2(r * 0.56, r * 0.40)),
		_shade(color, 0.5))
	ci.draw_circle(c + Vector2(0.0, -r * 0.98), r * 0.10, Color(1, 1, 1, 0.9))


## Orbital emitter: a satellite pod above, a tapering beam, and a ground reticle.
static func draw_laser_emitter(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var top := c + Vector2(0.0, -r * 0.78)
	# Satellite pod with solar fins.
	ci.draw_rect(Rect2(top + Vector2(-r * 0.62, -r * 0.10), Vector2(r * 0.30, r * 0.20)),
		_shade(color, 0.4))
	ci.draw_rect(Rect2(top + Vector2(r * 0.32, -r * 0.10), Vector2(r * 0.30, r * 0.20)),
		_shade(color, 0.4))
	_fill(ci, _poly(_rounded_body(r * 0.30, 0.7), 0.0, top), _shade(color, 0.5), color,
		maxf(1.5, r * 0.08))

	# Beam, brightest right after a strike.
	var flash := 0.35 + 0.65 * pow(absf(sin(phase * 2.0)), 6.0)
	var beam := PackedVector2Array([
		top + Vector2(-r * 0.13, r * 0.16),
		top + Vector2(r * 0.13, r * 0.16),
		c + Vector2(r * 0.44, r * 0.74),
		c + Vector2(-r * 0.44, r * 0.74),
	])
	ci.draw_colored_polygon(beam, Color(color.r, color.g, color.b, 0.30 * flash))
	ci.draw_line(top + Vector2(0.0, r * 0.16), c + Vector2(0.0, r * 0.74),
		Color(1, 1, 1, 0.85 * flash), maxf(1.5, r * 0.10), true)

	# Ground reticle.
	var ground := c + Vector2(0.0, r * 0.74)
	ci.draw_arc(ground, r * 0.44, 0.0, TAU, 20, Color(color.r, color.g, color.b, 0.9),
		maxf(1.0, r * 0.06), true)
	for i in 4:
		var a := TAU * float(i) / 4.0 + phase
		var dir := Vector2(cos(a), sin(a) * 0.45)
		ci.draw_line(ground + dir * r * 0.30, ground + dir * r * 0.56, secondary,
			maxf(1.0, r * 0.05), true)


## Circular saw blade: toothed rim, hub and bolt holes.
static func draw_saw(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var teeth := 10
	var pts := PackedVector2Array()
	for i in teeth * 2:
		var a := phase * 3.0 + TAU * float(i) / float(teeth * 2)
		# Asymmetric tooth profile so the spin direction is readable.
		var rad := r if i % 2 == 0 else r * 0.74
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	_fill(ci, pts, _shade(color, 0.4), color, maxf(1.5, r * 0.07))

	ci.draw_circle(c, r * 0.34, _shade(color, 0.6))
	ci.draw_arc(c, r * 0.34, 0.0, TAU, 18, secondary, maxf(1.0, r * 0.05), true)
	for i in 3:
		var a := -phase * 3.0 + TAU * float(i) / 3.0
		ci.draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.20, r * 0.07,
			Color(secondary.r, secondary.g, secondary.b, 0.8))
	ci.draw_circle(c, r * 0.09, Color(1, 1, 1, 0.9))


# --- Passives ---------------------------------------------------------------

## Overclock Core: a chip with pins and a lightning bolt.
static func draw_core(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var pin := _shade(color, 0.35)
	for i in 8:
		var a := TAU * float(i) / 8.0 + PI / 8.0
		var dir := Vector2(cos(a), sin(a))
		ci.draw_line(c + dir * r * 0.62, c + dir * r * 0.96, pin, maxf(1.0, r * 0.10), true)
	var chip := _poly(Draw2D.polygon_points(4, r * 0.72, PI * 0.25), 0.0, c)
	_fill(ci, chip, _shade(color, 0.55), color, maxf(1.5, r * 0.08))

	var glow := 0.5 + 0.5 * absf(sin(phase * 4.0))
	var bolt := PackedVector2Array([
		Vector2(r * 0.10, -r * 0.46),
		Vector2(-r * 0.24, r * 0.04),
		Vector2(-r * 0.02, r * 0.04),
		Vector2(-r * 0.12, r * 0.46),
		Vector2(r * 0.26, -r * 0.06),
		Vector2(r * 0.02, -r * 0.06),
	])
	ci.draw_colored_polygon(_poly(bolt, 0.0, c),
		Color(secondary.r, secondary.g, secondary.b, 0.55 + 0.45 * glow))


## Alloy Plating: overlapping armour plates with rivets.
static func draw_plating(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var shield := PackedVector2Array([
		Vector2(0.0, -r * 0.98),
		Vector2(r * 0.80, -r * 0.52),
		Vector2(r * 0.62, r * 0.52),
		Vector2(0.0, r * 0.98),
		Vector2(-r * 0.62, r * 0.52),
		Vector2(-r * 0.80, -r * 0.52),
	])
	_fill(ci, _poly(shield, 0.0, c), _shade(color, 0.5), color, maxf(1.5, r * 0.09))

	# Three plate seams.
	for i in 3:
		var y := -r * 0.40 + float(i) * r * 0.42
		var half := r * (0.72 - 0.16 * float(i))
		ci.draw_line(c + Vector2(-half, y), c + Vector2(half, y),
			Color(secondary.r, secondary.g, secondary.b, 0.55), maxf(1.0, r * 0.05), true)
		ci.draw_circle(c + Vector2(-half + r * 0.10, y), r * 0.06, secondary)
		ci.draw_circle(c + Vector2(half - r * 0.10, y), r * 0.06, secondary)

	var sheen := 0.25 + 0.25 * absf(sin(phase * 1.6))
	ci.draw_line(c + Vector2(-r * 0.30, -r * 0.70), c + Vector2(r * 0.10, r * 0.10),
		Color(1, 1, 1, sheen), maxf(1.0, r * 0.07), true)


## Kinetic Boots: a boot silhouette with speed streaks.
static func draw_boots(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	for i in 3:
		var y := -r * 0.40 + float(i) * r * 0.40
		var wobble := fposmod(phase * 2.2 + float(i) * 0.4, 1.0)
		var x := lerpf(-r * 1.05, -r * 0.45, wobble)
		ci.draw_line(c + Vector2(x, y), c + Vector2(x + r * 0.42, y),
			Color(secondary.r, secondary.g, secondary.b, 0.65 * (1.0 - wobble)),
			maxf(1.0, r * 0.07), true)

	var boot := PackedVector2Array([
		Vector2(-r * 0.30, -r * 0.86),
		Vector2(r * 0.16, -r * 0.86),
		Vector2(r * 0.20, r * 0.16),
		Vector2(r * 0.86, r * 0.44),
		Vector2(r * 0.86, r * 0.78),
		Vector2(-r * 0.34, r * 0.78),
	])
	_fill(ci, _poly(boot, 0.0, c), _shade(color, 0.5), color, maxf(1.5, r * 0.09))
	ci.draw_rect(Rect2(c + Vector2(-r * 0.36, r * 0.60), Vector2(r * 1.24, r * 0.20)),
		_shade(color, 0.15))
	for i in 2:
		var y := -r * 0.52 + float(i) * r * 0.34
		ci.draw_line(c + Vector2(-r * 0.28, y), c + Vector2(r * 0.16, y),
			Color(secondary.r, secondary.g, secondary.b, 0.7), maxf(1.0, r * 0.06), true)


## Resonance Lens: a faceted prism throwing refracted rays.
static func draw_lens(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var pulse := 0.9 + 0.1 * sin(phase * 3.0)
	for i in 6:
		var a := phase * 0.9 + TAU * float(i) / 6.0
		var dir := Vector2(cos(a), sin(a))
		ci.draw_line(c + dir * r * 0.70, c + dir * r * 1.05,
			Color(secondary.r, secondary.g, secondary.b, 0.5), maxf(1.0, r * 0.05), true)

	var lens := PackedVector2Array([
		Vector2(0.0, -r * 0.86 * pulse),
		Vector2(r * 0.62 * pulse, 0.0),
		Vector2(0.0, r * 0.86 * pulse),
		Vector2(-r * 0.62 * pulse, 0.0),
	])
	_fill(ci, _poly(lens, 0.0, c), Color(color.r, color.g, color.b, 0.35), color,
		maxf(1.5, r * 0.08))
	ci.draw_line(c + Vector2(0.0, -r * 0.86 * pulse), c + Vector2(0.0, r * 0.86 * pulse),
		Color(secondary.r, secondary.g, secondary.b, 0.6), maxf(1.0, r * 0.05), true)
	ci.draw_circle(c, r * 0.16, Color(1, 1, 1, 0.85))


## Salvage Magnet: a horseshoe magnet with poles and attraction arcs.
static func draw_magnet(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var width := r * 0.34
	var span := r * 0.56
	# Horseshoe drawn as a thick arc plus two straight legs.
	ci.draw_arc(c + Vector2(0.0, -r * 0.10), span, PI, TAU, 20, color, width, false)
	ci.draw_line(c + Vector2(-span, -r * 0.10), c + Vector2(-span, r * 0.68), color, width)
	ci.draw_line(c + Vector2(span, -r * 0.10), c + Vector2(span, r * 0.68), color, width)

	# Pole tips.
	ci.draw_line(c + Vector2(-span, r * 0.52), c + Vector2(-span, r * 0.82), secondary, width)
	ci.draw_line(c + Vector2(span, r * 0.52), c + Vector2(span, r * 0.82),
		Color(1.0, 0.35, 0.38), width)

	# Field arcs pulsing outward between the poles.
	for i in 3:
		var t := fposmod(phase * 1.1 + float(i) / 3.0, 1.0)
		var rad := lerpf(span * 0.35, span * 1.15, t)
		ci.draw_arc(c + Vector2(0.0, r * 0.82), rad, PI * 1.15, PI * 1.85, 14,
			Color(secondary.r, secondary.g, secondary.b, 0.7 * (1.0 - t)),
			maxf(1.0, r * 0.05), true)


# --- Second-wave icons -------------------------------------------------------
#
# Every icon below is built from a silhouette that survives being shrunk to the
# 40px HUD slot. That rules out anything whose identity lives in fine detail:
# what reads at that size is the outline and one accent, so each of these is one
# strong shape plus one bright mark.


## Sidearm in profile. The heavy variant has a cylinder and a fat muzzle; the
## light one is slim with a vented slide, so the two are told apart by outline
## rather than by size.
static func draw_gun(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float, heavy: bool) -> void:
	var body := PackedVector2Array([
		Vector2(-r * 0.86, -r * 0.24),
		Vector2(r * 0.92, -r * 0.24),
		Vector2(r * 0.92, r * 0.04),
		Vector2(-r * 0.30, r * 0.10),
		Vector2(-r * 0.44, r * 0.86),
		Vector2(-r * 0.86, r * 0.72),
	])
	_fill(ci, _poly(body, 0.0, c), _shade(color, 0.55), color, maxf(1.5, r * 0.09))
	if heavy:
		# Cylinder: the one part of a revolver everyone recognises.
		ci.draw_circle(c + Vector2(-r * 0.10, -r * 0.06), r * 0.30, _shade(color, 0.30))
		Draw2D.ring(ci, c + Vector2(-r * 0.10, -r * 0.06), r * 0.30, secondary, maxf(1.2, r * 0.07))
		for i in 5:
			var a := TAU * float(i) / 5.0 + phase * 0.8
			ci.draw_circle(c + Vector2(-r * 0.10, -r * 0.06) + Vector2(cos(a), sin(a)) * r * 0.17,
				r * 0.06, _shade(color, 0.65))
	else:
		# Vents along the slide.
		for i in 3:
			var x := -r * 0.10 + float(i) * r * 0.26
			ci.draw_line(c + Vector2(x, -r * 0.19), c + Vector2(x, -r * 0.02),
				secondary, maxf(1.0, r * 0.07), true)
	# Muzzle flash, brightest right after a shot.
	var flash := 0.35 + 0.65 * absf(sin(phase * 5.0))
	ci.draw_circle(c + Vector2(r * 0.98, -r * 0.10), r * 0.16 * flash,
		Color(secondary.r, secondary.g, secondary.b, 0.85 * flash))


## Longbow: a drawn stave with the string pulled back and an arrow nocked.
static func draw_bow(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var draw_t := 0.55 + 0.45 * absf(sin(phase * 2.2))
	var stave := PackedVector2Array()
	for i in 13:
		var a := -PI * 0.42 + PI * 0.84 * float(i) / 12.0
		stave.append(c + Vector2(cos(a) * r * 0.92 + r * 0.12, sin(a) * r * 0.98))
	ci.draw_polyline(stave, color, maxf(2.0, r * 0.13), true)
	# String, pulled back by the current draw.
	var nock := c + Vector2(r * 0.12 - r * 0.62 * draw_t, 0.0)
	ci.draw_polyline(PackedVector2Array([stave[0], nock, stave[stave.size() - 1]]),
		_shade(secondary, -0.2), maxf(1.0, r * 0.05), true)
	# Arrow.
	ci.draw_line(nock, c + Vector2(r * 0.86, 0.0), secondary, maxf(1.5, r * 0.08), true)
	_fill(ci, _poly(PackedVector2Array([
		Vector2(r * 1.02, 0.0),
		Vector2(r * 0.74, r * 0.20),
		Vector2(r * 0.74, -r * 0.20),
	]), 0.0, c), Color.WHITE, secondary, maxf(1.0, r * 0.05))


## Spear: one long shaft on the diagonal with a leaf-shaped head and a binding.
static func draw_spear(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var axis := Vector2(0.72, -0.69)
	ci.draw_line(c - axis * r * 0.96, c + axis * r * 0.52, _shade(secondary, 0.35),
		maxf(2.0, r * 0.14), true)
	var head := _poly(PackedVector2Array([
		Vector2(0.0, -r * 0.52),
		Vector2(r * 0.19, -r * 0.10),
		Vector2(0.0, r * 0.12),
		Vector2(-r * 0.19, -r * 0.10),
	]), axis.angle() + PI * 0.5, c + axis * r * 0.66)
	_fill(ci, head, _shade(color, 0.25), Color.WHITE, maxf(1.5, r * 0.07))
	# Binding where the head meets the shaft.
	ci.draw_line(c + axis * r * 0.30 + Vector2(-axis.y, axis.x) * r * 0.13,
		c + axis * r * 0.30 - Vector2(-axis.y, axis.x) * r * 0.13,
		secondary, maxf(1.2, r * 0.09), true)
	var glint := 0.4 + 0.6 * absf(sin(phase * 3.0))
	ci.draw_circle(c + axis * r * 0.92, r * 0.10 * glint, Color(1, 1, 1, 0.8 * glint))


## Ring of blades. `fanged` swaps the even spacing for paired hooks, which is
## what separates the Chakram from the Boomerang Fang at a glance.
static func draw_chakram(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float, fanged: bool) -> void:
	var spin := phase * (2.4 if fanged else 1.6)
	Draw2D.ring(ci, c, r * 0.60, color, maxf(2.0, r * 0.14))
	Draw2D.ring(ci, c, r * 0.34, _shade(color, 0.35), maxf(1.0, r * 0.06))
	var blades := 3 if fanged else 4
	for i in blades:
		var a := TAU * float(i) / float(blades) + spin
		var dir := Vector2(cos(a), sin(a))
		var side := Vector2(-dir.y, dir.x)
		var tip := 1.02 if fanged else 0.94
		_fill(ci, PackedVector2Array([
			c + dir * r * 0.56 + side * r * 0.20,
			c + dir * r * tip + side * (r * 0.06 if fanged else -r * 0.02),
			c + dir * r * 0.56 - side * r * 0.10,
		]), _shade(secondary, 0.15), Color.WHITE, maxf(1.0, r * 0.05))
	ci.draw_circle(c, r * 0.12, Color(secondary.r, secondary.g, secondary.b, 0.9))


## War hammer: a heavy head on a short haft, with the impact ring it leaves.
static func draw_hammer(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var hit := absf(sin(phase * 1.8))
	Draw2D.ring(ci, c + Vector2(0.0, r * 0.62), r * (0.42 + 0.52 * hit),
		Color(secondary.r, secondary.g, secondary.b, 0.55 * (1.0 - hit)), maxf(1.5, r * 0.08))
	ci.draw_line(c + Vector2(r * 0.30, -r * 0.46), c + Vector2(-r * 0.26, r * 0.72),
		_shade(secondary, 0.45), maxf(2.0, r * 0.15), true)
	var head := _poly(PackedVector2Array([
		Vector2(-r * 0.46, -r * 0.30),
		Vector2(r * 0.46, -r * 0.30),
		Vector2(r * 0.38, r * 0.30),
		Vector2(-r * 0.38, r * 0.30),
	]), -0.7, c + Vector2(r * 0.34, -r * 0.52))
	_fill(ci, head, _shade(color, 0.30), color, maxf(1.5, r * 0.09))
	ci.draw_circle(c + Vector2(r * 0.34, -r * 0.52), r * 0.10, Color(1, 1, 1, 0.55))


## Flamethrower: a nozzle throwing three overlapping tongues of fire.
static func draw_flame(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var nozzle := PackedVector2Array([
		Vector2(-r * 0.92, -r * 0.20),
		Vector2(-r * 0.20, -r * 0.26),
		Vector2(-r * 0.20, r * 0.22),
		Vector2(-r * 0.92, r * 0.28),
	])
	_fill(ci, _poly(nozzle, 0.0, c), _shade(color, 0.60), color, maxf(1.2, r * 0.07))
	for i in 3:
		var t := float(i) / 2.0
		var flick := sin(phase * 6.0 + t * 2.2) * r * 0.10
		var reach := r * (0.42 + 0.58 * t)
		var spread := r * (0.16 + 0.30 * t)
		var alpha := 0.85 - 0.22 * t
		_fill(ci, PackedVector2Array([
			c + Vector2(-r * 0.16, 0.0),
			c + Vector2(reach, -spread + flick),
			c + Vector2(reach + r * 0.20, flick * 0.5),
			c + Vector2(reach, spread + flick),
		]), Color(secondary.r, secondary.g, secondary.b, alpha * 0.55),
			Color(secondary.r, secondary.g, secondary.b, alpha), maxf(1.0, r * 0.05))


## Arc Coil: a coil throwing a bolt that forks.
static func draw_arc_coil(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	for i in 4:
		var y := -r * 0.62 + float(i) * r * 0.30
		Draw2D.ring(ci, c + Vector2(-r * 0.42, y), r * 0.26 - float(i) * r * 0.02,
			_shade(color, 0.15), maxf(1.0, r * 0.06))
	var live := 0.45 + 0.55 * absf(sin(phase * 7.0))
	var bolt := PackedVector2Array([
		c + Vector2(-r * 0.16, -r * 0.42),
		c + Vector2(r * 0.14, -r * 0.06),
		c + Vector2(-r * 0.04, r * 0.02),
		c + Vector2(r * 0.42, r * 0.52),
	])
	ci.draw_polyline(bolt, Color(secondary.r, secondary.g, secondary.b, live),
		maxf(1.5, r * 0.10), true)
	ci.draw_polyline(PackedVector2Array([
		c + Vector2(r * 0.14, -r * 0.06),
		c + Vector2(r * 0.62, -r * 0.24),
	]), Color(1, 1, 1, 0.75 * live), maxf(1.0, r * 0.06), true)


## Seeker Swarm: a missile with fins and an exhaust plume.
static func draw_missile(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var body := PackedVector2Array([
		Vector2(r * 0.92, 0.0),
		Vector2(r * 0.30, r * 0.30),
		Vector2(-r * 0.56, r * 0.24),
		Vector2(-r * 0.56, -r * 0.24),
		Vector2(r * 0.30, -r * 0.30),
	])
	_fill(ci, _poly(body, -0.5, c), _shade(color, 0.35), color, maxf(1.5, r * 0.09))
	for side in [-1.0, 1.0]:
		_fill(ci, _poly(PackedVector2Array([
			Vector2(-r * 0.20, side * r * 0.26),
			Vector2(-r * 0.62, side * r * 0.66),
			Vector2(-r * 0.62, side * r * 0.20),
		]), -0.5, c), _shade(secondary, 0.30), secondary, maxf(1.0, r * 0.05))
	var burn := 0.5 + 0.5 * absf(sin(phase * 9.0))
	var tail := Vector2(-r * 0.62, 0.0).rotated(-0.5)
	ci.draw_circle(c + tail, r * 0.22 * burn,
		Color(secondary.r, secondary.g, secondary.b, 0.8 * burn))
	ci.draw_circle(c + tail, r * 0.11 * burn, Color(1, 1, 1, 0.9 * burn))


## Grenade Volley: a fragmentation charge with its pin and a lit fuse.
static func draw_grenade(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var body := _rounded_body(r * 0.62, 1.10)
	_fill(ci, _poly(body, 0.0, c + Vector2(0.0, r * 0.16)), _shade(color, 0.45), color,
		maxf(1.5, r * 0.09))
	# Segment lines, which is what makes it a grenade and not a ball.
	for i in 2:
		var y := c.y + r * (0.02 + float(i) * 0.30)
		ci.draw_line(Vector2(c.x - r * 0.56, y), Vector2(c.x + r * 0.56, y),
			_shade(color, 0.70), maxf(1.0, r * 0.05), true)
	ci.draw_line(Vector2(c.x, c.y - r * 0.52), Vector2(c.x, c.y + r * 0.74),
		_shade(color, 0.70), maxf(1.0, r * 0.05), true)
	# Spoon and pin.
	_fill(ci, _poly(PackedVector2Array([
		Vector2(-r * 0.16, -r * 0.86),
		Vector2(r * 0.16, -r * 0.86),
		Vector2(r * 0.16, -r * 0.46),
		Vector2(-r * 0.16, -r * 0.46),
	]), 0.0, c), _shade(secondary, 0.35), secondary, maxf(1.0, r * 0.05))
	Draw2D.ring(ci, c + Vector2(r * 0.44, -r * 0.76), r * 0.18, secondary, maxf(1.0, r * 0.06))
	var spark := 0.4 + 0.6 * absf(sin(phase * 8.0))
	ci.draw_circle(c + Vector2(0.0, -r * 0.92), r * 0.13 * spark, Color(1, 1, 1, spark))


## Ricochet Orb: an orb with the corner it just bounced off.
static func draw_orb(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var bounce := absf(sin(phase * 2.6))
	var at := c + Vector2(-r * 0.14, r * 0.10) * (1.0 - bounce)
	# The wall it came off, and the path back.
	ci.draw_line(c + Vector2(r * 0.34, -r * 0.98), c + Vector2(r * 0.98, -r * 0.34),
		_shade(color, 0.55), maxf(1.5, r * 0.10), true)
	ci.draw_polyline(PackedVector2Array([
		c + Vector2(-r * 0.86, r * 0.62),
		c + Vector2(r * 0.62, -r * 0.58),
		c + Vector2(-r * 0.30, -r * 0.92),
	]), Color(color.r, color.g, color.b, 0.38), maxf(1.0, r * 0.05), true)
	Draw2D.glow_circle(ci, at, r * 0.40, color, 3)
	ci.draw_circle(at, r * 0.34, Color(secondary.r, secondary.g, secondary.b, 0.95))
	ci.draw_circle(at + Vector2(-r * 0.11, -r * 0.12), r * 0.11, Color(1, 1, 1, 0.85))


## Rail Lance: two rails and the slug between them, mid-launch.
static func draw_rail(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	for side in [-1.0, 1.0]:
		_fill(ci, PackedVector2Array([
			c + Vector2(-r * 0.94, side * r * 0.50),
			c + Vector2(r * 0.78, side * r * 0.28),
			c + Vector2(r * 0.78, side * r * 0.10),
			c + Vector2(-r * 0.94, side * r * 0.26),
		]), _shade(color, 0.50), color, maxf(1.2, r * 0.07))
	var charge := 0.35 + 0.65 * absf(sin(phase * 5.0))
	# The beam between the rails.
	ci.draw_line(c + Vector2(-r * 0.80, 0.0), c + Vector2(r * 0.90, 0.0),
		Color(secondary.r, secondary.g, secondary.b, 0.30 + 0.45 * charge),
		maxf(2.0, r * 0.28 * charge), true)
	ci.draw_line(c + Vector2(-r * 0.80, 0.0), c + Vector2(r * 0.90, 0.0),
		Color(1, 1, 1, 0.85 * charge), maxf(1.0, r * 0.09), true)
	ci.draw_circle(c + Vector2(r * 0.90, 0.0), r * 0.17 * charge, Color(1, 1, 1, charge))


## Frost Nova: a six-armed flake inside the ring it just threw out.
static func draw_frost(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var pulse := fposmod(phase * 0.7, 1.0)
	Draw2D.ring(ci, c, r * (0.42 + 0.58 * pulse),
		Color(color.r, color.g, color.b, 0.5 * (1.0 - pulse)), maxf(1.5, r * 0.08))
	for i in 6:
		var a := TAU * float(i) / 6.0
		var dir := Vector2(cos(a), sin(a))
		ci.draw_line(c, c + dir * r * 0.78, color, maxf(1.5, r * 0.09), true)
		# Barbs, which is what makes it a snowflake rather than a star.
		for t in [0.42, 0.66]:
			var root := c + dir * r * float(t)
			ci.draw_line(root, root + dir.rotated(0.7) * r * 0.20, color, maxf(1.0, r * 0.06), true)
			ci.draw_line(root, root + dir.rotated(-0.7) * r * 0.20, color, maxf(1.0, r * 0.06), true)
	ci.draw_circle(c, r * 0.17, Color(secondary.r, secondary.g, secondary.b, 0.95))


## Sun Flare: a bright core with rays of alternating length.
static func draw_sun(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	for i in 12:
		var a := TAU * float(i) / 12.0 + phase * 0.5
		var long := (i % 2) == 0
		var dir := Vector2(cos(a), sin(a))
		var beam := PackedVector2Array([
			c + dir * r * 0.46 + Vector2(-dir.y, dir.x) * r * 0.10,
			c + dir * r * (0.98 if long else 0.72),
			c + dir * r * 0.46 - Vector2(-dir.y, dir.x) * r * 0.10,
		])
		ci.draw_colored_polygon(beam, Color(color.r, color.g, color.b, 0.85 if long else 0.5))
	Draw2D.glow_circle(ci, c, r * 0.44, color, 3)
	ci.draw_circle(c, r * 0.40, color)
	ci.draw_circle(c, r * 0.26, Color(secondary.r, secondary.g, secondary.b, 0.95))
	ci.draw_circle(c + Vector2(-r * 0.09, -r * 0.10), r * 0.09, Color(1, 1, 1, 0.8))


## Thorn Aura: a briar ring, barbs pointing outward.
static func draw_thorns(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var sway := sin(phase * 1.4) * 0.12
	Draw2D.ring(ci, c, r * 0.58, color, maxf(1.5, r * 0.10))
	for i in 9:
		var a := TAU * float(i) / 9.0 + sway
		var dir := Vector2(cos(a), sin(a))
		var side := Vector2(-dir.y, dir.x)
		_fill(ci, PackedVector2Array([
			c + dir * r * 0.52 + side * r * 0.13,
			c + dir * r * 0.98 + side * r * 0.03,
			c + dir * r * 0.52 - side * r * 0.09,
		]), _shade(color, 0.20), secondary, maxf(1.0, r * 0.04))
	# A couple of leaves so it reads as growth rather than wire.
	for side_sign in [-1.0, 1.0]:
		var root := c + Vector2(side_sign * r * 0.40, r * 0.42)
		ci.draw_colored_polygon(PackedVector2Array([
			root,
			root + Vector2(side_sign * r * 0.26, r * 0.06),
			root + Vector2(side_sign * r * 0.10, r * 0.28),
		]), Color(secondary.r, secondary.g, secondary.b, 0.85))


## Mine Field: a domed charge with legs and a blinking arming light.
static func draw_mine(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	for side in [-1.0, 1.0]:
		ci.draw_line(c + Vector2(side * r * 0.24, r * 0.16),
			c + Vector2(side * r * 0.72, r * 0.72), _shade(color, 0.55),
			maxf(1.2, r * 0.08), true)
	var dome := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		dome.append(c + Vector2(cos(a) * r * 0.66, sin(a) * r * 0.58 + r * 0.20))
	dome.append(c + Vector2(r * 0.66, r * 0.20))
	dome.append(c + Vector2(-r * 0.66, r * 0.20))
	_fill(ci, dome, _shade(color, 0.45), color, maxf(1.5, r * 0.09))
	# Trigger prongs.
	for i in 3:
		var x := -r * 0.34 + float(i) * r * 0.34
		ci.draw_line(c + Vector2(x, -r * 0.28), c + Vector2(x, -r * 0.62),
			_shade(secondary, 0.20), maxf(1.0, r * 0.06), true)
	var blink := absf(sin(phase * 6.0))
	ci.draw_circle(c + Vector2(0.0, -r * 0.04), r * 0.15,
		Color(secondary.r, secondary.g, secondary.b, 0.35 + 0.65 * blink))


## Shock Turret: a squat emplacement with a barrel and a sweeping sensor.
static func draw_turret(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	_fill(ci, PackedVector2Array([
		c + Vector2(-r * 0.78, r * 0.88),
		c + Vector2(-r * 0.50, r * 0.34),
		c + Vector2(r * 0.50, r * 0.34),
		c + Vector2(r * 0.78, r * 0.88),
	]), _shade(color, 0.60), color, maxf(1.5, r * 0.08))
	var swing := sin(phase * 1.6) * 0.5
	var barrel := _poly(PackedVector2Array([
		Vector2(-r * 0.14, 0.0),
		Vector2(r * 0.14, 0.0),
		Vector2(r * 0.11, -r * 0.86),
		Vector2(-r * 0.11, -r * 0.86),
	]), swing, c + Vector2(0.0, r * 0.22))
	_fill(ci, barrel, _shade(secondary, 0.40), secondary, maxf(1.2, r * 0.07))
	ci.draw_circle(c + Vector2(0.0, r * 0.22), r * 0.34, _shade(color, 0.25))
	Draw2D.ring(ci, c + Vector2(0.0, r * 0.22), r * 0.34, color, maxf(1.2, r * 0.07))
	var eye := 0.4 + 0.6 * absf(sin(phase * 3.4))
	ci.draw_circle(c + Vector2(0.0, r * 0.22), r * 0.14,
		Color(secondary.r, secondary.g, secondary.b, eye))


## Blade Storm: four crescents chasing each other round a ring.
static func draw_blade_storm(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	Draw2D.ring(ci, c, r * 0.34, Color(color.r, color.g, color.b, 0.35), maxf(1.0, r * 0.05))
	for i in 4:
		var lead := phase * 2.6 + TAU * float(i) / 4.0
		var fade := 1.0 - float(i) * 0.18
		var arc := 0.9
		var band := PackedVector2Array()
		for k in 9:
			var a := lead + arc * float(k) / 8.0
			band.append(c + Vector2(cos(a), sin(a)) * r * 0.92)
		for k in range(8, -1, -1):
			var u := float(k) / 8.0
			var a2 := lead + arc * u
			var w := r * 0.22 * (0.10 + 0.90 * sin(PI * u))
			band.append(c + Vector2(cos(a2), sin(a2)) * (r * 0.92 - w))
		ci.draw_colored_polygon(band,
			Color(secondary.r, secondary.g, secondary.b, 0.75 * fade))
	ci.draw_circle(c, r * 0.16, Color(color.r, color.g, color.b, 0.9))


## Void Well: a dark core with matter spiralling into it.
static func draw_well(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	for i in 5:
		var t := fposmod(phase * 0.55 + float(i) / 5.0, 1.0)
		# Radius shrinks as the arm winds in, which is what sells the pull.
		var rad := r * (0.30 + 0.72 * t)
		var arm := PackedVector2Array()
		for k in 9:
			var a := TAU * float(i) / 5.0 - t * 4.0 + float(k) * 0.16
			arm.append(c + Vector2(cos(a), sin(a)) * lerpf(rad, rad * 0.62, float(k) / 8.0))
		ci.draw_polyline(arm, Color(secondary.r, secondary.g, secondary.b, 0.65 * (1.0 - t)),
			maxf(1.0, r * 0.07 * (1.0 - t * 0.5)), true)
	Draw2D.glow_circle(ci, c, r * 0.34, color, 3)
	ci.draw_circle(c, r * 0.30, Color(0.04, 0.03, 0.09, 1.0))
	Draw2D.ring(ci, c, r * 0.30, color, maxf(1.5, r * 0.08))


## Hollow Point: a round in section, its tip opened into petals.
static func draw_hollow_point(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var casing := PackedVector2Array([
		Vector2(-r * 0.34, r * 0.92),
		Vector2(r * 0.34, r * 0.92),
		Vector2(r * 0.34, -r * 0.18),
		Vector2(-r * 0.34, -r * 0.18),
	])
	_fill(ci, _poly(casing, 0.0, c), _shade(secondary, 0.35), secondary, maxf(1.2, r * 0.07))
	# The opened tip: four petals peeling back off the nose.
	for i in 4:
		var a := -PI * 0.5 + (float(i) - 1.5) * 0.34
		var dir := Vector2(cos(a), sin(a))
		_fill(ci, PackedVector2Array([
			c + Vector2(0.0, -r * 0.14),
			c + dir * r * 0.86 + Vector2(-dir.y, dir.x) * r * 0.12,
			c + dir * r * 0.86 - Vector2(-dir.y, dir.x) * r * 0.12,
		]), _shade(color, 0.25), color, maxf(1.0, r * 0.05))
	var glint := 0.4 + 0.6 * absf(sin(phase * 3.6))
	ci.draw_circle(c + Vector2(0.0, -r * 0.10), r * 0.13 * glint, Color(1, 1, 1, glint))


## Vital Weave: a heart under a lattice, beating.
static func draw_weave(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var beat := 1.0 + 0.09 * sin(phase * 4.5)
	var heart := PackedVector2Array()
	for i in 22:
		var t := TAU * float(i) / 22.0
		# The standard heart curve, scaled to the icon.
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		heart.append(c + Vector2(x, y) * r * 0.052 * beat)
	_fill(ci, heart, _shade(color, 0.35), color, maxf(1.5, r * 0.08))
	# The weave over it.
	for i in 3:
		var y := -r * 0.30 + float(i) * r * 0.30
		ci.draw_line(Vector2(c.x - r * 0.62, c.y + y), Vector2(c.x + r * 0.62, c.y + y),
			Color(secondary.r, secondary.g, secondary.b, 0.55), maxf(1.0, r * 0.05), true)
	for i in 3:
		var x := -r * 0.34 + float(i) * r * 0.34
		ci.draw_line(Vector2(c.x + x, c.y - r * 0.52), Vector2(c.x + x, c.y + r * 0.56),
			Color(secondary.r, secondary.g, secondary.b, 0.55), maxf(1.0, r * 0.05), true)


## Siege Charge: a shell with a shockwave coming off the nose.
static func draw_siege(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var push := fposmod(phase * 0.9, 1.0)
	for i in 2:
		var t := fposmod(push + float(i) * 0.5, 1.0)
		Draw2D.ring(ci, c + Vector2(r * 0.30, 0.0), r * (0.30 + 0.78 * t),
			Color(secondary.r, secondary.g, secondary.b, 0.5 * (1.0 - t)), maxf(1.2, r * 0.07))
	var shell := PackedVector2Array([
		Vector2(r * 0.66, 0.0),
		Vector2(r * 0.10, r * 0.36),
		Vector2(-r * 0.80, r * 0.30),
		Vector2(-r * 0.80, -r * 0.30),
		Vector2(r * 0.10, -r * 0.36),
	])
	_fill(ci, _poly(shell, 0.0, c), _shade(color, 0.35), color, maxf(1.5, r * 0.09))
	ci.draw_line(c + Vector2(-r * 0.44, -r * 0.32), c + Vector2(-r * 0.44, r * 0.32),
		_shade(secondary, 0.10), maxf(1.2, r * 0.08), true)


## Ablative Shell: three shield layers, the outer one flaking away.
static func draw_shell(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	for i in 3:
		var scale := 1.0 - float(i) * 0.24
		var shield := PackedVector2Array([
			Vector2(0.0, -r * 0.96) * scale,
			Vector2(r * 0.78, -r * 0.46) * scale,
			Vector2(r * 0.58, r * 0.58) * scale,
			Vector2(0.0, r * 0.96) * scale,
			Vector2(-r * 0.58, r * 0.58) * scale,
			Vector2(-r * 0.78, -r * 0.46) * scale,
		])
		var tint := _shade(color, 0.55 - float(i) * 0.18)
		_fill(ci, _poly(shield, 0.0, c), tint, color if i == 0 else _shade(color, -0.1),
			maxf(1.0, r * 0.06))
	# Chips coming off the outer layer.
	for i in 3:
		var a := -0.8 + float(i) * 0.8
		var drift := fposmod(phase * 0.8 + float(i) * 0.33, 1.0)
		var dir := Vector2(cos(a), sin(a))
		ci.draw_circle(c + dir * r * (0.90 + 0.42 * drift), r * 0.08 * (1.0 - drift),
			Color(secondary.r, secondary.g, secondary.b, 0.8 * (1.0 - drift)))


## Split Barrel: one weapon bored twice, both muzzles lit.
static func draw_split_barrel(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	for side in [-1.0, 1.0]:
		var barrel := PackedVector2Array([
			c + Vector2(-r * 0.86, side * r * 0.10),
			c + Vector2(r * 0.86, side * r * 0.46),
			c + Vector2(r * 0.86, side * r * 0.14),
			c + Vector2(-r * 0.86, side * r * -0.14),
		])
		_fill(ci, barrel, _shade(color, 0.50), color, maxf(1.2, r * 0.07))
		var flash := 0.35 + 0.65 * absf(sin(phase * 5.0 + (0.0 if side > 0.0 else 1.6)))
		ci.draw_circle(c + Vector2(r * 0.92, side * r * 0.30), r * 0.15 * flash,
			Color(secondary.r, secondary.g, secondary.b, 0.9 * flash))
	# The block they split from.
	_fill(ci, PackedVector2Array([
		c + Vector2(-r * 0.96, -r * 0.34),
		c + Vector2(-r * 0.52, -r * 0.26),
		c + Vector2(-r * 0.52, r * 0.26),
		c + Vector2(-r * 0.96, r * 0.34),
	]), _shade(secondary, 0.50), secondary, maxf(1.2, r * 0.07))


## Long Fuse: a coiled fuse burning slowly toward a charge.
static func draw_fuse(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var cord := PackedVector2Array()
	for i in 26:
		var t := float(i) / 25.0
		var a := -PI * 0.4 + t * TAU * 1.25
		cord.append(c + Vector2(cos(a), sin(a)) * r * (0.90 - 0.52 * t))
	ci.draw_polyline(cord, _shade(color, 0.25), maxf(1.5, r * 0.10), true)
	# The lit end travels the cord, which is the whole idea of the passive.
	var burn := fposmod(phase * 0.35, 1.0)
	var idx := clampi(int(burn * float(cord.size() - 1)), 0, cord.size() - 1)
	var tip: Vector2 = cord[idx]
	Draw2D.glow_circle(ci, tip, r * 0.18, secondary, 3)
	ci.draw_circle(tip, r * 0.12, Color(1, 1, 1, 0.95))
	ci.draw_circle(c, r * 0.22, _shade(color, 0.40))
	Draw2D.ring(ci, c, r * 0.22, color, maxf(1.0, r * 0.06))


## Omen Dice: a pair of dice, one showing six.
static func draw_dice(ci: CanvasItem, c: Vector2, r: float, color: Color,
		secondary: Color, phase: float) -> void:
	var tumble := sin(phase * 1.3) * 0.18
	# Back die, plain, so the front one reads as the subject.
	_fill(ci, _poly(Draw2D.polygon_points(4, r * 0.52, PI * 0.25), -0.4 + tumble,
		c + Vector2(r * 0.40, -r * 0.34)), _shade(color, 0.55), color, maxf(1.2, r * 0.07))
	var face := _poly(Draw2D.polygon_points(4, r * 0.68, PI * 0.25), 0.18 + tumble,
		c + Vector2(-r * 0.16, r * 0.16))
	_fill(ci, face, _shade(color, 0.30), secondary, maxf(1.5, r * 0.08))
	# Six pips.
	var origin := c + Vector2(-r * 0.16, r * 0.16)
	for col in 2:
		for row in 3:
			var p := Vector2((float(col) - 0.5) * r * 0.42, (float(row) - 1.0) * r * 0.34)
			ci.draw_circle(origin + p.rotated(0.18 + tumble), r * 0.08, Color(1, 1, 1, 0.92))


## A jet of fire leaving a nozzle: narrow and white-hot at the muzzle, widening
## and cooling at the far end, with tongues licking along the edges.
##
## What the flamethrower used to draw was a wobbly circle, which is why nobody
## could tell it from any other aura. A cone with a direction is the entire
## read - so this is shaped, not tinted.
static func draw_flame_jet(ci: CanvasItem, c: Vector2, radius: float, facing: float,
		arc: float, color: Color, secondary: Color, pulse: float, fade: float) -> void:
	var steps := 14
	# Three nested cones, each shorter, narrower and hotter than the last, so
	# the jet has a temperature gradient instead of one flat colour.
	var layers := [
		[1.00, 1.00, Color(color.r, color.g, color.b, 0.72 * fade)],
		[0.74, 0.66, Color(secondary.r, secondary.g, secondary.b, 0.85 * fade)],
		[0.42, 0.40, Color(1.0, 0.97, 0.84, 0.90 * fade)],
	]
	for layer in layers:
		var reach: float = radius * float(layer[0])
		var spread: float = arc * float(layer[1])
		var cone := PackedVector2Array()
		cone.append(c)
		for i in steps + 1:
			var u := float(i) / float(steps)
			var a := facing - spread * 0.5 + spread * u
			# Flicker rides along the rim rather than scaling the whole cone, so
			# the jet boils at its edges the way fire does.
			var lick := 1.0 + 0.06 * sin(u * 9.0 + pulse * 22.0) + 0.04 * sin(pulse * 31.0)
			cone.append(c + Vector2(cos(a), sin(a)) * reach * lick)
		ci.draw_colored_polygon(cone, layer[2])
	# Tongues breaking off the leading edge and burning out.
	for i in 5:
		var drift := fposmod(pulse * 1.6 + float(i) * 0.21, 1.0)
		var a2 := facing + sin(float(i) * 5.3 + pulse * 4.0) * arc * 0.42
		var at := c + Vector2(cos(a2), sin(a2)) * radius * (0.55 + 0.55 * drift)
		var heat := 1.0 - drift
		ci.draw_circle(at, radius * 0.11 * heat,
			Color(1.0, 0.72 + 0.2 * heat, 0.25, 0.6 * heat * fade))
	# The muzzle: a white core where the fuel ignites.
	ci.draw_circle(c + Vector2(cos(facing), sin(facing)) * radius * 0.10,
		radius * 0.12, Color(1.0, 0.97, 0.88, 0.9 * fade))
