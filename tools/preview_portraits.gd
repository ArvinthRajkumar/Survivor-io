extends SceneTree
## Art harness for the operative roster portraits: draws all five busts in a row
## on a flat background so they can be compared without unlocking heroes.
##   godot --path . --script res://tools/preview_portraits.gd
##
## Worth running after any change to HeroPortrait - a polygon Godot refuses to
## triangulate fails silently in-game (outline, no fill) but prints here.

## Accent / secondary pairs, matching resources/heroes/*.tres in variant order:
## 0 Ember, 1 Aegis, 2 Nova, 3 Bramble, 4 Rift.
const PALETTES: Array = [
	[Color(1.0, 0.42, 0.25), Color(1.0, 0.80, 0.30)],
	[Color(1.0, 0.78, 0.35), Color(0.55, 0.75, 1.0)],
	[Color(0.30, 0.85, 1.0), Color(0.45, 1.0, 0.70)],
	[Color(0.45, 0.90, 0.45), Color(0.95, 0.82, 0.35)],
	[Color(0.70, 0.45, 1.0), Color(1.0, 0.55, 0.90)],
]

var _frames: int = 0
var _canvas: Node2D


func _initialize() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.06, 0.10))
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_all)
	root.add_child(_canvas)


func _draw_all() -> void:
	for i in PALETTES.size():
		var pair: Array = PALETTES[i]
		HeroPortrait.draw_bust(_canvas, Vector2(70.0 + float(i) * 60.0, 68.0), 30.0,
			pair[0], pair[1], i, 1.7)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		_capture()
	return _frames > 6


func _capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://portraits.png")
	print("[portraits] saved to user://portraits.png")
	quit(0)
