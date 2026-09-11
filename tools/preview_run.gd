extends SceneTree
## The in-run character at four sizes and five poses, for eyeballing the chibi
## without playing. Content scaling is off so the pixel sizes are honest.
##   godot --path . --rendering-driver opengl3 --script res://tools/preview_run.gd

const VISUAL := preload("res://scripts/player/PlayerVisual.gd")

var _vs: Array = []
var _n: int = 0


func _initialize() -> void:
	RenderingServer.set_default_clear_color(Color(0.11, 0.13, 0.18))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var hero: Resource = load("res://resources/heroes/baby.tres")
	var others := ["ember", "nova", "aegis"]
	for i in 4:
		var v := Node2D.new()
		v.set_script(VISUAL)
		v.scale = Vector2(3.0, 3.0)
		v.position = Vector2(108.0 + float(i % 2) * 216.0, 250.0 + float(i / 2) * 330.0)
		root.add_child(v)
		if i == 0:
			v.call("configure", hero)
		else:
			v.call("configure", load("res://resources/heroes/%s.tres" % others[i - 1]))
		_vs.append(v)


func _process(_d: float) -> bool:
	_n += 1
	var dirs := [Vector2(1.0, 0.0), Vector2(-1.0, 0.2), Vector2.ZERO, Vector2(0.6, -0.8)]
	for i in _vs.size():
		_vs[i].call("set_motion", dirs[i], (dirs[i] as Vector2) * 320.0, 1.0 / 60.0)
	if _n == 18:
		for j in _vs.size():
			_vs[j].call("set_motion", dirs[j], (dirs[j] as Vector2) * 320.0, 1.0 / 60.0)
	if _n == 14:
		_vs[0].call("play_attack", 0, Vector2(1.0, 0.0), 1.0, 2.2, false)
		_vs[3].call("play_attack", 2, Vector2(1.0, -0.3), 1.0, 2.0, false)
	if _n == 20:
		_shot()
	return _n > 30


func _shot() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://run.png")
	print("[run] saved")
	quit(0)
