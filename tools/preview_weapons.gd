extends SceneTree
## Art harness for the operative's attacks: every starting weapon down the page,
## each one stepped through its own animation.
##   godot --path . --rendering-driver opengl3 --script res://tools/preview_weapons.gd
##
## In play an attack is on screen for a fifth of a second while the screen is
## full of enemies, which is nowhere near long enough to tell whether a bow
## actually draws or a hammer actually comes down. Here they hold still.

## weapon id, pose, and how wide a swing travels.
const WEAPONS: Array = [
	[&"katana", PlayerVisual.Pose.SWING, 1.35],
	[&"spear", PlayerVisual.Pose.THRUST, 0.30],
	[&"revolver", PlayerVisual.Pose.SHOOT, 2.0],
	[&"machine_pistol", PlayerVisual.Pose.SHOOT, 2.0],
	[&"longbow", PlayerVisual.Pose.DRAW, 2.0],
	[&"chakram", PlayerVisual.Pose.THROW, 2.0],
	[&"warhammer", PlayerVisual.Pose.SMASH, 2.0],
	[&"flamethrower", PlayerVisual.Pose.SPRAY, 2.0],
]
## Points through each attack, plus one at rest to show the stowed weapon.
const STEPS: Array = [-1.0, 0.12, 0.42, 0.72, 0.95]

var _visuals: Array = []
var _frames: int = 0


func _initialize() -> void:
	RenderingServer.set_default_clear_color(Color(0.043, 0.051, 0.086))
	for row in WEAPONS.size():
		var entry: Array = WEAPONS[row]
		for col in STEPS.size():
			var v := PlayerVisual.new()
			v.accent = Color(0.35, 0.90, 1.0)
			v.accent_secondary = Color(1.0, 0.66, 0.28)
			v.scale = Vector2(1.15, 1.15)
			v.position = Vector2(46.0 + float(col) * 86.0, 54.0 + float(row) * 92.0)
			root.add_child(v)
			v.set_weapon(entry[0])
			# Every tell at once: this is the harness, not a real loadout.
			v.set_passive_tells([&"ablative_shell", &"vital_weave", &"long_fuse",
				&"omen_dice", &"split_barrel"])
			if float(STEPS[col]) >= 0.0:
				v.play_attack(entry[1], Vector2.RIGHT, 1.0, entry[2], false)
			_visuals.append([v, STEPS[col]])


func _process(_delta: float) -> bool:
	_frames += 1
	# Every visual is wound to its own point in the attack by hand: _process
	# would run them all at the same rate and they would never line up.
	for pair in _visuals:
		var v: PlayerVisual = pair[0]
		var at: float = pair[1]
		if at >= 0.0:
			v.set("_slash_time", v.get("_slash_span") * (1.0 - at))
		v.queue_redraw()
	if _frames == 4:
		_capture()
	return _frames > 8


func _capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://weapons.png")
	print("[weapons] saved to user://weapons.png")
	quit(0)
