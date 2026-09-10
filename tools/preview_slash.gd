extends SceneTree
## Art harness for the katana cut: five stages of one sweep, side by side, with
## the trail ghosts SlashArc layers behind the leading crescent.
##   godot --path . --script res://tools/preview_slash.gd
##
## The cut is only ever on screen for a fifth of a second in play, which is far
## too short to judge a shape by. Here it holds still.

const ARC := 1.35          ## KatanaPower.BASE_ARC
const LIFE := 0.20
const SWEEP := 0.065
const TRAIL_STEPS := 4     ## SlashArc.TRAIL_STEPS

var _canvas: Node2D
var _frames: int = 0


func _initialize() -> void:
	RenderingServer.set_default_clear_color(Color(0.06, 0.07, 0.11))
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_stages)
	root.add_child(_canvas)


func _draw_stages() -> void:
	var color := Color(0.75, 0.90, 1.0)
	var secondary := Color(1.0, 0.78, 0.36)
	for i in 5:
		var c := Vector2(110.0 + float(i % 2) * 210.0, 110.0 + float(i / 2) * 200.0)
		var age := 0.02 + float(i) * 0.045
		var t := clampf(age / LIFE, 0.0, 1.0)
		# Where the operative would be standing.
		_canvas.draw_circle(c, 9.0, Color(0.3, 0.9, 1.0, 0.6))
		for k in TRAIL_STEPS:
			var lag := float(k) * 0.055
			var lt := clampf(t + lag, 0.0, 1.0)
			if lt >= 1.0:
				continue
			var swept := clampf((age - lag) / SWEEP, 0.0, 1.0)
			if swept <= 0.0:
				continue
			var centre := -0.5 - ARC * 0.5 + ARC * swept * 0.5
			PowerArt.draw_slash(_canvas, c, 70.0, ARC * swept, centre, lt, color, secondary)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		_capture()
	return _frames > 6


func _capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://slash.png")
	print("[slash] saved to user://slash.png")
	quit(0)
