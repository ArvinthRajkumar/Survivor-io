extends SceneTree
## Art harness for the power, passive and weapon icons: every one of them on a
## grid, at the size the level-up card draws them.
##   godot --path . --script res://tools/preview_icons.gd
##
## Icons are the only artwork in the game a player studies rather than glances
## at, and they are also the easiest to get subtly wrong - a polygon Godot
## refuses to triangulate draws as an outline with no fill and says nothing.
## Errors from that show up on this run.

const COLUMNS := 5
const CELL := 86.0

var _canvas: Node2D
var _frames: int = 0
var _entries: Array = []


func _initialize() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.06, 0.10))
	# The database is an autoload and is not available to a --script run, so the
	# resources are loaded straight off disk here.
	var dir := DirAccess.open("res://resources/powers")
	if dir != null:
		for file in dir.get_files():
			var res := ResourceLoader.load("res://resources/powers/" + file.replace(".remap", ""))
			if res is PowerData:
				_entries.append(res)
	_entries.sort_custom(func(a, b): return String(a.id) < String(b.id))
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_all)
	root.add_child(_canvas)


func _draw_all() -> void:
	for i in _entries.size():
		var data: PowerData = _entries[i]
		var c := Vector2(CELL * (float(i % COLUMNS) + 0.6), CELL * (float(i / COLUMNS) + 0.6))
		PowerArt.draw(_canvas, data.art_id(), c, CELL * 0.40,
			data.color, data.color_secondary, 1.7)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		_capture()
	return _frames > 6


func _capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://icons.png")
	print("[icons] %d drawn, saved to user://icons.png" % _entries.size())
	quit(0)
