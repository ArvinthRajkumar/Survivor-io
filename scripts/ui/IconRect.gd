class_name IconRect
extends Control
## Reusable procedural icon: a coloured shape on a rounded plate, optionally with
## a level pip row. Used for weapon slots, upgrade cards, relics and hero tiles.

var icon_color: Color = Palette.ACCENT
var shape_id: int = 0
var level: int = 0
var max_level: int = 0
var show_level: bool = true
var plate: bool = true
var evolved: bool = false
## Heroes use their own shape vocabulary (0..4 = triangle, diamond, pentagon,
## hexagon, star) rather than the weapon icon set.
var portrait_mode: bool = false
## Second colour, used by the chibi portraits for trim and headgear.
var icon_secondary: Color = Palette.ACCENT_WARM
var _phase: float = 0.0


func setup(color: Color, shape: int, current_level: int = 0, maximum: int = 0,
		secondary: Color = Palette.ACCENT_WARM) -> void:
	icon_color = color
	shape_id = shape
	level = current_level
	max_level = maximum
	icon_secondary = secondary
	queue_redraw()


func _process(delta: float) -> void:
	# Portraits blink and sway; nothing else here animates, so the per-frame
	# redraw is only paid where it buys something.
	if not portrait_mode:
		set_process(false)
		return
	_phase += delta
	queue_redraw()


func set_evolved(value: bool) -> void:
	evolved = value
	queue_redraw()


func _draw() -> void:
	var s := size
	var center := s * 0.5
	var radius := minf(s.x, s.y) * 0.30

	if plate:
		var plate_color := Color(icon_color.r * 0.16, icon_color.g * 0.18, icon_color.b * 0.24, 0.9)
		draw_rect(Rect2(Vector2.ZERO, s), plate_color)
		var border := icon_color
		border.a = 0.85 if not evolved else 1.0
		draw_rect(Rect2(Vector2.ZERO, s), border, false, 3.0 if evolved else 2.0)

	_draw_shape(center, radius)

	if show_level and max_level > 0:
		_draw_pips(s)


func _draw_shape(center: Vector2, radius: float) -> void:
	var fill := Color(icon_color.r * 0.35, icon_color.g * 0.4, icon_color.b * 0.5, 0.95)
	if portrait_mode:
		_draw_portrait(center, radius, fill)
		return
	match shape_id:
		1:  # pellet cluster
			for i in 3:
				var a := TAU * float(i) / 3.0 - PI * 0.5
				draw_circle(center + Vector2(cos(a), sin(a)) * radius * 0.5, radius * 0.34, icon_color)
		2:  # ring
			draw_arc(center, radius, 0.0, TAU, 24, icon_color, 5.0, true)
		3:  # drone
			_poly(center, Draw2D.polygon_points(4, radius, PI * 0.25), fill)
			draw_circle(center, radius * 0.28, Color(1, 1, 1, 0.9))
		4:  # mine
			_poly(center, Draw2D.star_points(6, radius, radius * 0.45, 0.0), fill)
		5:  # orb
			draw_circle(center, radius, Color(icon_color.r, icon_color.g, icon_color.b, 0.35))
			draw_arc(center, radius, 0.0, TAU, 24, icon_color, 4.0, true)
		6:  # blade
			_poly(center, Draw2D.star_points(4, radius * 1.2, radius * 0.32, PI * 0.25), fill)
		7:  # rift
			_poly(center, Draw2D.star_points(6, radius * 1.1, radius * 0.4, 0.0), fill)
			draw_circle(center, radius * 0.32, Color(0.02, 0.0, 0.05, 0.95))
		_:  # bolt
			var pts := PackedVector2Array([
				center + Vector2(0.0, -radius * 1.15),
				center + Vector2(radius * 0.62, radius * 0.2),
				center + Vector2(radius * 0.18, radius * 0.2),
				center + Vector2(0.0, radius * 1.15),
				center + Vector2(-radius * 0.62, -radius * 0.2),
				center + Vector2(-radius * 0.18, -radius * 0.2),
			])
			_poly(center, pts, fill, false)


## Operatives are drawn as chibi busts rather than as their roster polygon, so
## the person you pick on this screen is the person you see on the field.
func _draw_portrait(center: Vector2, radius: float, _fill: Color) -> void:
	# Framed like a character card: the bust is drawn well over tile size and
	# cropped by it (the tile sets clip_contents), so the head fills the plate
	# instead of floating in the middle of it.
	HeroPortrait.draw_bust(self, center + Vector2(0.0, radius * 0.54), radius * 1.74,
		icon_color, icon_secondary, shape_id, _phase)
	Draw2D.ring(self, center, radius * 1.42,
		Color(icon_color.r, icon_color.g, icon_color.b, 0.18), 2.0)


func _poly(center: Vector2, points: PackedVector2Array, fill: Color, offset: bool = true) -> void:
	var pts := PackedVector2Array()
	for p in points:
		pts.append(p + center if offset else p)
	Draw2D.neon_polygon(self, pts, fill, icon_color, 2.5)


func _draw_pips(s: Vector2) -> void:
	var count := mini(max_level, 8)
	if count <= 0:
		return
	var width := s.x - 16.0
	var pip_width := width / float(count)
	var y := s.y - 10.0
	for i in count:
		var x := 8.0 + pip_width * float(i)
		var filled := i < level
		var c := icon_color if filled else Color(1, 1, 1, 0.14)
		draw_rect(Rect2(Vector2(x + 1.0, y), Vector2(pip_width - 3.0, 5.0)), c)
