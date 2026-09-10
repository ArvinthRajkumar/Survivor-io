extends Node2D
## Draws the level backdrop procedurally in screen space, scrolling with the
## camera. Four styles cover the four levels; each is a handful of draw calls, so
## it costs far less than a tiled TileMap or a full-screen shader on low-end GPUs.

const GRID_SIZE := 128.0

var level: LevelData
var camera: Camera2D

var _size: Vector2 = Vector2(1080, 1920)
var _time: float = 0.0
var _offset: Vector2 = Vector2.ZERO
var _dust: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	z_index = -100
	_resize()
	get_viewport().size_changed.connect(_resize)


func setup(level_data: LevelData, level_camera: Camera2D) -> void:
	level = level_data
	camera = level_camera
	_seed_dust()
	queue_redraw()


func _resize() -> void:
	_size = get_viewport().get_visible_rect().size
	_seed_dust()
	queue_redraw()


func _seed_dust() -> void:
	_dust = PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 987654
	for i in 42:
		_dust.append(Vector2(rng.randf() * _size.x, rng.randf() * _size.y))


func _process(delta: float) -> void:
	_time += delta
	if camera != null and is_instance_valid(camera):
		_offset = camera.global_position
	queue_redraw()


func _draw() -> void:
	if level == null:
		draw_rect(Rect2(Vector2.ZERO, _size), Palette.BG_DEEP)
		return
	_draw_gradient()
	match level.background_style:
		1:
			_draw_ash()
		2:
			_draw_water()
		3:
			_draw_lunar()
		_:
			_draw_neon_grid()
	_draw_vignette()


## Vertical gradient approximated with a few bands - cheaper than a shader and
## indistinguishable at this scale.
func _draw_gradient() -> void:
	var bands := 10
	for i in bands:
		var t := float(i) / float(bands - 1)
		var color := level.bg_top.lerp(level.bg_bottom, t)
		var y := _size.y * float(i) / float(bands)
		draw_rect(Rect2(Vector2(0.0, y), Vector2(_size.x, _size.y / float(bands) + 1.0)), color)


func _draw_neon_grid() -> void:
	var color := level.grid_color
	var offset := Vector2(fmod(-_offset.x, GRID_SIZE), fmod(-_offset.y, GRID_SIZE))
	var x := offset.x
	while x < _size.x + GRID_SIZE:
		draw_line(Vector2(x, 0.0), Vector2(x, _size.y), color, 1.5)
		x += GRID_SIZE
	var y := offset.y
	while y < _size.y + GRID_SIZE:
		draw_line(Vector2(0.0, y), Vector2(_size.x, y), color, 1.5)
		y += GRID_SIZE
	# A few brighter "signage" blocks to sell the ruined-city read.
	var accent := level.accent
	accent.a = 0.18
	for i in 6:
		var seed_pos := Vector2(float((i * 337) % 900), float((i * 613) % 1700))
		var p := _wrap(seed_pos - _offset * 0.35)
		draw_rect(Rect2(p, Vector2(90.0 + float(i % 3) * 40.0, 26.0)), accent)


func _draw_ash() -> void:
	var color := level.grid_color
	for i in 9:
		var base_y := float(i) * (_size.y / 9.0)
		var y := fmod(base_y - _offset.y * 0.25, _size.y + 200.0) - 100.0
		var pts := PackedVector2Array()
		for j in 9:
			var x := _size.x * float(j) / 8.0
			pts.append(Vector2(x, y + sin(float(j) * 1.3 + float(i)) * 26.0))
		draw_polyline(pts, color, 3.0, true)
	var glow := level.accent
	glow.a = 0.10
	for p in _dust:
		var q := _wrap(p - _offset * 0.5)
		draw_circle(q, 3.0, glow)


func _draw_water() -> void:
	var color := level.grid_color
	for i in 14:
		var y := fmod(float(i) * 140.0 - _offset.y * 0.4 + sin(_time * 0.6) * 20.0, _size.y + 200.0) - 100.0
		var pts := PackedVector2Array()
		for j in 13:
			var x := _size.x * float(j) / 12.0
			pts.append(Vector2(x, y + sin(_time * 1.4 + float(j) * 0.7 + float(i)) * 14.0))
		draw_polyline(pts, color, 2.0, true)
	var caustic := level.accent
	caustic.a = 0.08
	for i in 5:
		var c := _wrap(Vector2(float((i * 211) % 1000), float((i * 517) % 1800)) - _offset * 0.6)
		draw_circle(c, 120.0 + 20.0 * sin(_time + float(i)), caustic)


func _draw_lunar() -> void:
	var color := level.grid_color
	for p in _dust:
		var q := _wrap(p - _offset * 0.7)
		draw_circle(q, 2.0, color)
	# Distant cliff silhouettes.
	var cliff := level.bg_top.darkened(0.35)
	for i in 4:
		var base := _wrap(Vector2(float((i * 421) % 1000) - 200.0, float((i * 733) % 1900)) - _offset * 0.2)
		var pts := PackedVector2Array([
			base,
			base + Vector2(180.0 + float(i) * 40.0, -140.0 - float(i) * 30.0),
			base + Vector2(360.0 + float(i) * 60.0, 0.0),
		])
		draw_colored_polygon(pts, cliff)
	var halo := level.accent
	halo.a = 0.10
	draw_circle(Vector2(_size.x * 0.7, _size.y * 0.18), 190.0, halo)


func _draw_vignette() -> void:
	var fog := level.fog_color
	draw_rect(Rect2(Vector2.ZERO, Vector2(_size.x, 140.0)), Color(fog.r, fog.g, fog.b, fog.a))
	draw_rect(Rect2(Vector2(0.0, _size.y - 200.0), Vector2(_size.x, 200.0)), Color(fog.r, fog.g, fog.b, fog.a))


## Keeps a parallax element inside the screen rectangle.
func _wrap(p: Vector2) -> Vector2:
	var w := _size.x + 400.0
	var h := _size.y + 400.0
	return Vector2(fposmod(p.x + 200.0, w) - 200.0, fposmod(p.y + 200.0, h) - 200.0)
