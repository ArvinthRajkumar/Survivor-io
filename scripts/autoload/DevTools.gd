extends Node
## Command-line development helpers. Inert unless a flag is passed after `--`.
##
##   godot --path . -- --smoke              headless soak run (autopilot)
##   godot --path . -- --perf               log frame/entity stats every 5s
##   godot --path . -- --shot               save PNGs of the running game
##   godot --path . -- --screen=hero        boot straight into a menu
##   godot --path . -- --hero=ember          force the hero for this launch
##   godot --path . -- --level=ash_wastes    force the sector for this launch
##   godot --path . -- --seed=12345          fix the run RNG seed
##   godot --path . -- --meta=4             pretend every lab upgrade is level 4
##   godot --path . -- --pilot               autopilot movement, manual choices
##   godot --path . -- --no-tutorial        suppress the first-run overlay
##
## Screens: menu, hero, level, lab, settings, game.

signal shot_saved(path: String)

## Wall-clock seconds at which --shot captures a frame.
const SHOT_TIMES: PackedFloat32Array = [1.2, 3.0, 8.0, 30.0, 90.0, 180.0]

var args: PackedStringArray = PackedStringArray()
var shots_enabled: bool = false
var smoke: bool = false
## Autopilot movement without the auto-pick, so UI can be inspected mid-run.
var pilot: bool = false

var _elapsed: float = 0.0
var _next_shot: int = 0
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	args = OS.get_cmdline_user_args()
	shots_enabled = has_flag("--shot")
	smoke = has_flag("--smoke")
	pilot = smoke or has_flag("--pilot")
	set_process(shots_enabled)


func has_flag(flag: String) -> bool:
	return args.has(flag)


## Reads a `--key=value` argument as an integer, or `fallback` when absent.
func get_int_option(key: String, fallback: int = 0) -> int:
	var raw := get_option(key)
	return int(raw) if raw.is_valid_int() else fallback


## Reads `--key=value` style arguments.
func get_option(key: String, fallback: String = "") -> String:
	var prefix := "--%s=" % key
	for arg in args:
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return fallback


func _process(delta: float) -> void:
	if not shots_enabled or _busy or _next_shot >= SHOT_TIMES.size():
		return
	_elapsed += delta
	if _elapsed < SHOT_TIMES[_next_shot]:
		return
	_next_shot += 1
	_capture(_next_shot - 1)


func _capture(index: int) -> void:
	_busy = true
	await RenderingServer.frame_post_draw
	var viewport := get_viewport()
	if viewport == null:
		_busy = false
		return
	var image := viewport.get_texture().get_image()
	var path := "user://shot_%02d.png" % index
	if image.save_png(path) == OK:
		var full := ProjectSettings.globalize_path(path)
		print("[shot] ", full)
		shot_saved.emit(full)
	_busy = false


## Where `--screen=` should send the boot sequence, or an empty name for normal
## start-up.
func requested_screen() -> String:
	return get_option("screen")
