class_name Draw2D
extends RefCounted
## Procedural vector-art helpers. Every visual in the game is generated from these
## primitives so the project ships with no external art assets.

## Regular n-gon points, optionally rotated.
static func polygon_points(sides: int, radius: float, rotation: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var a := rotation + TAU * float(i) / float(sides)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts

## A star / spiky shape, useful for shards and elite markers.
static func star_points(points: int, outer: float, inner: float, rotation: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := points * 2
	for i in steps:
		var a := rotation + TAU * float(i) / float(steps)
		var r := outer if i % 2 == 0 else inner
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

## Draws a filled polygon plus an outline: the house "neon vector" look.
static func neon_polygon(ci: CanvasItem, pts: PackedVector2Array, fill: Color, outline: Color, width: float = 3.0) -> void:
	if pts.size() < 3:
		return
	ci.draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, outline, width, true)

## Soft glow approximated with a few concentric transparent rings (cheap on mobile).
static func glow_circle(ci: CanvasItem, center: Vector2, radius: float, color: Color, layers: int = 3) -> void:
	for i in range(layers, 0, -1):
		var t := float(i) / float(layers)
		var c := color
		c.a = color.a * 0.18 * (1.0 - t + 0.35)
		ci.draw_circle(center, radius * (1.0 + t * 0.6), c)

static func ring(ci: CanvasItem, center: Vector2, radius: float, color: Color, width: float = 4.0) -> void:
	ci.draw_arc(center, radius, 0.0, TAU, 32, color, width, true)
