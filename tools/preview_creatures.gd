extends SceneTree
## Shows the baked creature atlas the way the game draws it: through
## CreatureSprite and the recolouring shader, at the sizes enemies actually
## appear at.
##   godot --path . --rendering-driver opengl3 --script res://tools/preview_creatures.gd
##
## Worth running after a re-bake. It is the only view that exercises the atlas,
## the shader and the frame indexing together — a contact sheet made straight
## from the PNG proves none of them.

## color, color_secondary per row, matching the roster's palettes.
const PALETTES: Array = [
	[Color(1.00, 0.35, 0.45), Color(0.25, 0.05, 0.12)],
	[Color(0.55, 0.82, 1.00), Color(0.06, 0.12, 0.24)],
	[Color(1.00, 0.62, 0.28), Color(0.20, 0.10, 0.04)],
	[Color(0.35, 0.85, 1.00), Color(0.06, 0.14, 0.22)],
	[Color(0.78, 0.50, 1.00), Color(0.14, 0.06, 0.24)],
	[Color(1.00, 0.45, 0.52), Color(0.22, 0.08, 0.12)],
]
const POSES: Array = [
	[EnemyArt.State.MOVE, 0.0], [EnemyArt.State.MOVE, 0.25],
	[EnemyArt.State.MOVE, 0.5], [EnemyArt.State.MOVE, 0.75],
	[EnemyArt.State.WINDUP, 0.85], [EnemyArt.State.STRIKE, 0.3],
	[EnemyArt.State.SHOOT, 0.2],
]

var _frames: int = 0


func _initialize() -> void:
	RenderingServer.set_default_clear_color(Color(0.043, 0.051, 0.086))
	for row in PALETTES.size():
		for col in POSES.size():
			var pose: Array = POSES[col]
			var sprite := CreatureSprite.new()
			sprite.set_palette(PALETTES[row][0], PALETTES[row][1], false)
			# 30px radius: about what a mid-tier enemy occupies in play.
			sprite.set_radius(30.0)
			sprite.set_facing_left(col == 6)
			sprite.set_frame_index(EnemyArt.frame_index(row, pose[0], pose[1]))
			sprite.position = Vector2(40.0 + float(col) * 58.0, 50.0 + float(row) * 92.0)
			root.add_child(sprite)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 4:
		_capture()
	return _frames > 8


func _capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://creatures.png")
	print("[creatures] saved to user://creatures.png")
	quit(0)
