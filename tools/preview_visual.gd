extends SceneTree
## Temporary art harness: renders the player character large on a flat
## background so the chibi sprite can be eyeballed without playing a run.
##   godot --path . --script res://tools/preview_visual.gd

const VISUAL := preload("res://scripts/player/PlayerVisual.gd")

var _visual: Node2D
var _frames: int = 0
var _shot: int = 0
var _poses: Array = []


func _initialize() -> void:
	RenderingServer.set_default_clear_color(Color(0.10, 0.12, 0.18))
	_visual = Node2D.new()
	_visual.set_script(VISUAL)
	_visual.scale = Vector2(6.0, 6.0)
	_visual.position = Vector2(320.0, 380.0)
	root.add_child(_visual)
	_poses = [
		{"dir": Vector2.ZERO, "vel": Vector2.ZERO, "slash": null},
		{"dir": Vector2(1.0, 0.2), "vel": Vector2(320.0, 60.0), "slash": null},
		{"dir": Vector2(0.0, -1.0), "vel": Vector2(0.0, -330.0), "slash": null},
		{"dir": Vector2(1.0, 0.0), "vel": Vector2(330.0, 0.0), "slash": Vector2(1.0, 0.0)},
		{"dir": Vector2(-1.0, 0.4), "vel": Vector2(-300.0, 120.0), "slash": Vector2(-1.0, 0.4)},
	]


func _process(_delta: float) -> bool:
	_frames += 1
	var pose: Dictionary = _poses[_shot]
	_visual.call("set_motion", pose["dir"], pose["vel"], 1.0 / 60.0)
	if _frames % 40 == 34 and pose["slash"] != null:
		_visual.call("play_slash", pose["slash"], 1.0, 2.2, false)
	if _frames % 40 == 0 and _frames > 0:
		_capture()
	return _shot >= _poses.size()


func _capture() -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("user://preview_%d.png" % _shot)
	print("[preview] pose ", _shot)
	_shot += 1
	if _shot >= _poses.size():
		quit(0)
