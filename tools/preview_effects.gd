extends SceneTree
## Art harness for the flame jet: four sweep angles, held still.
##   godot --path . --rendering-driver opengl3 --script res://tools/preview_effects.gd
##
## The jet is the hardest effect in the game to judge in play - it is on screen
## for a fraction of a second with a hundred enemies over it. If it cannot be
## recognised here it cannot be recognised there.

const HOT := Color(1.00, 0.52, 0.22)
const WARM := Color(1.00, 0.86, 0.36)

var _canvas: Node2D
var _frames: int = 0


func _initialize() -> void:
	RenderingServer.set_default_clear_color(Color(0.043, 0.051, 0.086))
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_all)
	root.add_child(_canvas)


func _draw_all() -> void:
	# A sweep, as the operative turns from up-left round to the right.
	for i in 4:
		var at := Vector2(78.0 + float(i) * 96.0, 110.0)
		var facing := -PI * 0.85 + float(i) * 0.62
		_canvas.draw_circle(at, 7.0, Color(0.35, 0.9, 1.0, 0.7))
		PowerArt.draw_flame_jet(_canvas, at, 78.0, facing, 0.56, HOT, WARM,
			0.8 + float(i) * 0.4, 1.0)
	# Held on one heading at four points of its flicker, to check it boils.
	for i in 4:
		var at2 := Vector2(78.0 + float(i) * 96.0, 268.0)
		_canvas.draw_circle(at2, 7.0, Color(0.35, 0.9, 1.0, 0.7))
		PowerArt.draw_flame_jet(_canvas, at2, 78.0, 0.0, 0.56, HOT, WARM,
			float(i) * 0.09, 1.0)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 4:
		_capture()
	return _frames > 8


func _capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://effects.png")
	print("[effects] saved to user://effects.png")
	quit(0)
