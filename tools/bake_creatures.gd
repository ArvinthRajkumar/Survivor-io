extends SceneTree
## Bakes the six creature body plans into a single sprite atlas.
##   godot --path . --rendering-driver opengl3 --script res://tools/bake_creatures.gd
##   godot --path . --editor --quit-after 400      <-- and then this
##
## Run both after any change to EnemyArt.gd, and commit the PNG: the game loads
## the atlas and never draws a creature procedurally.
##
## The second command is not optional. Godot serves the *imported* copy of the
## texture, so a freshly baked PNG that has not been re-imported is invisible to
## the game - it keeps drawing the previous bake, which looks exactly like the
## new art having had no effect.
##
## ## What comes out
##
## `assets/sprites/creatures.png`, a grid of 128px frames laid out as
## body-major, then state, then frame. The art is baked as **luminance**: every
## element is a grey whose brightness says how lit it is, and the game tints the
## whole sprite with the archetype's colour through `modulate`. Dark body,
## bright edge, near-white eye - the neon look the rest of the game is drawn in,
## and one 400KB sheet dresses all twenty-eight archetypes.
##
## The obvious alternative was to bake each of the three roles into its own
## colour channel and recombine them in a shader, which would have let a
## creature carry a body colour and an edge colour that were genuinely
## different. It does not work here: a per-instance ShaderMaterial's uniforms do
## not reliably reach the renderer for pooled nodes configured before they enter
## the tree, and the creatures render as the raw mask - flat red, green and
## blue. Tinting also batches, which 260 unique materials never could.

const COLUMNS := 16

## The three roles as levels of grey. The gaps between them are what separate a
## body from its outline once everything is one hue: too close together and the
## creature reads as a blob, too far and the body disappears.
const ROLE_BODY := Color(0.44, 0.44, 0.44, 1.0)
const ROLE_EDGE := Color(0.90, 0.90, 0.90, 1.0)
const ROLE_ACCENT := Color(1.00, 1.00, 1.00, 1.0)

var _viewport: SubViewport
var _canvas: Node2D
var _frame: int = 0
var _pending: int = 0
var _atlas: Image
var _started: bool = false


func _initialize() -> void:
	var total := EnemyArt.total_frames()
	var rows := int(ceil(float(total) / float(COLUMNS)))
	_atlas = Image.create(COLUMNS * EnemyArt.FRAME_SIZE, rows * EnemyArt.FRAME_SIZE,
		false, Image.FORMAT_RGBA8)
	_atlas.fill(Color(0, 0, 0, 0))

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(EnemyArt.FRAME_SIZE, EnemyArt.FRAME_SIZE)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# No filtering or gamma on the way in: the atlas is data, not a picture.
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(_viewport)

	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_current)
	_viewport.add_child(_canvas)
	print("[bake] %d frames, %dx%d atlas" % [total, _atlas.get_width(), _atlas.get_height()])


func _draw_current() -> void:
	var per_body := EnemyArt.STATE_COUNT * EnemyArt.FRAMES_PER_STATE
	var body := _frame / per_body
	var within := _frame % per_body
	var state := within / EnemyArt.FRAMES_PER_STATE
	var step := within % EnemyArt.FRAMES_PER_STATE
	# Sampled at the centre of each frame's slice rather than its start, so a
	# looping gait is evenly spaced and never repeats its first pose.
	var t := (float(step) + 0.5) / float(EnemyArt.FRAMES_PER_STATE)
	var half := float(EnemyArt.FRAME_SIZE) * 0.5
	_canvas.draw_set_transform(Vector2(half, half))
	EnemyArt.draw_body(_canvas, body, EnemyArt.BAKE_RADIUS,
		ROLE_BODY, ROLE_EDGE, ROLE_ACCENT, state, t)
	_canvas.draw_set_transform(Vector2.ZERO)


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_capture_all()
	return false


func _capture_all() -> void:
	var total := EnemyArt.total_frames()
	while _frame < total:
		_canvas.queue_redraw()
		# Two frames per capture: one for the redraw to be recorded, one for the
		# viewport to actually render it.
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := _viewport.get_texture().get_image()
		var col := _frame % COLUMNS
		var row := _frame / COLUMNS
		_atlas.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()),
			Vector2i(col * EnemyArt.FRAME_SIZE, row * EnemyArt.FRAME_SIZE))
		_frame += 1
		if _frame % 32 == 0:
			print("[bake] %d/%d" % [_frame, total])
	var path := "res://assets/sprites/creatures.png"
	var err := _atlas.save_png(path)
	if err != OK:
		push_error("bake_creatures: could not write %s (%d)" % [path, err])
	else:
		print("[bake] wrote ", path)
	quit(0)
