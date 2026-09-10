extends SceneTree
## Art harness for the swarm: all six body plans down the page, each shown
## walking, winding up, striking and shooting.
##   godot --path . --script res://tools/preview_enemies.gd
##
## In play these are 20px across, moving, and usually on fire, which makes it
## almost impossible to tell a body plan that reads badly from one that is
## simply small. Here they hold still at four times the size.

const ROWS: Array = [
	[EnemyArt.Body.SCUTTLER, Color(0.30, 0.12, 0.14), Color(1.00, 0.42, 0.40)],
	[EnemyArt.Body.SENTRY, Color(0.12, 0.18, 0.28), Color(0.55, 0.82, 1.00)],
	[EnemyArt.Body.BRUTE, Color(0.24, 0.16, 0.10), Color(1.00, 0.66, 0.32)],
	[EnemyArt.Body.WISP, Color(0.12, 0.22, 0.26), Color(0.50, 0.95, 0.90)],
	[EnemyArt.Body.OCULAR, Color(0.20, 0.12, 0.28), Color(0.80, 0.55, 1.00)],
	[EnemyArt.Body.MAW, Color(0.22, 0.14, 0.16), Color(1.00, 0.50, 0.55)],
]

## state, progress through it
const POSES: Array = [
	[EnemyArt.State.MOVE, 0.0],
	[EnemyArt.State.MOVE, 0.5],
	[EnemyArt.State.WINDUP, 0.9],
	[EnemyArt.State.STRIKE, 0.35],
	[EnemyArt.State.SHOOT, 0.2],
]

var _canvas: Node2D
var _frames: int = 0


func _initialize() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.06, 0.10))
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_all)
	root.add_child(_canvas)


func _draw_all() -> void:
	for row in ROWS.size():
		var entry: Array = ROWS[row]
		for col in POSES.size():
			var pose: Array = POSES[col]
			# draw_body draws around the canvas item's own origin, because in play
			# each enemy *is* the canvas item. Here one node draws all thirty, so
			# the transform is what places them.
			_canvas.draw_set_transform(
				Vector2(52.0 + float(col) * 96.0, 60.0 + float(row) * 112.0))
			# The two MOVE poses differ only by gait phase, which is what shows
			# the walk cycle actually moving.
			var gait := 1.2 + float(col) * 2.6
			EnemyArt.draw_body(_canvas, entry[0], 30.0, entry[1], entry[2],
				entry[2].lerp(Color.WHITE, 0.35), gait, pose[0], pose[1], col == 4)
	_canvas.draw_set_transform(Vector2.ZERO)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		_capture()
	return _frames > 6


func _capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://enemies.png")
	print("[enemies] saved to user://enemies.png")
	quit(0)
