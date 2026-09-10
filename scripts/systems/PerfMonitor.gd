class_name PerfMonitor
extends Node
## Lightweight profiling aid for mobile tuning.
##
## Enabled by passing `--perf` (or `--smoke`) after a bare `--` on the command
## line, or by flipping `always_on`. It prints one line per interval with the
## numbers that actually matter on a phone: frame time, live enemies, pooled
## objects and draw calls.
##
##   godot --path . -- --perf
##   adb logcat -s godot   (on device)

@export var interval: float = 5.0
@export var always_on: bool = false

var enabled: bool = false

var _timer: float = 0.0
var _frames: int = 0
var _worst_frame_ms: float = 0.0


func _ready() -> void:
	enabled = always_on or DevTools.has_flag("--perf") or DevTools.smoke
	set_process(enabled)
	if enabled:
		print("[perf] monitoring enabled (every %.0fs)" % interval)


func _process(delta: float) -> void:
	_frames += 1
	_worst_frame_ms = maxf(_worst_frame_ms, delta * 1000.0)
	_timer += delta
	if _timer < interval:
		return
	print(_snapshot())
	_timer = 0.0
	_frames = 0
	_worst_frame_ms = 0.0


func _snapshot() -> String:
	var enemies := EnemyDirector.instance.count() if EnemyDirector.instance != null else 0
	return "[perf] t=%s fps=%d worst=%.1fms enemies=%d pooled=%d objects=%d draws=%d mem=%.1fMB" % [
		MathUtil.format_time(RunManager.elapsed),
		int(Engine.get_frames_per_second()),
		_worst_frame_ms,
		enemies,
		PoolManager.total_active(),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
	]
