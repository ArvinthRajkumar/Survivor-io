extends SceneTree
## Baby at four sizes, for comparing against the reference photograph.
##   godot --path . --rendering-driver opengl3 --script res://tools/preview_baby.gd
##
## She is the one character in the game that has to be a specific person rather
## than a readable silhouette, so she gets her own harness: the roster card size
## is 150px and the HUD slot is 40px, and a likeness that only works at one of
## them is not finished.

var _canvas: Node2D
var _frames: int = 0


func _initialize() -> void:
	RenderingServer.set_default_clear_color(Color(0.09, 0.10, 0.14))
	# The project maps 1080x1920 of drawing onto whatever window it gets, so a
	# radius of 150 would render at 60 real pixels here and the sizes below
	# would all be lies. Turn the mapping off: on a device, draw units and
	# pixels are the same thing, and that is what has to be judged.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_all)
	root.add_child(_canvas)


func _draw_all() -> void:
	BabySprite.draw_bust(_canvas, Vector2(216.0, 300.0), 175.0, 1.7)
	BabySprite.draw_bust(_canvas, Vector2(70.0, 690.0), 60.0, 1.7)
	BabySprite.draw_bust(_canvas, Vector2(200.0, 700.0), 38.0, 1.7)
	BabySprite.draw_bust(_canvas, Vector2(300.0, 706.0), 20.0, 1.7)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 4:
		_capture()
	return _frames > 8


func _capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://baby.png")
	print("[baby] saved to user://baby.png")
	quit(0)
