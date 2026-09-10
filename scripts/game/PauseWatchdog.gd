extends Node
## Calls one callback every frame, including while the tree is paused.
##
## Exists so GameScene can have a single always-on ticker without setting
## PROCESS_MODE_ALWAYS on the scene root: children inherit that mode by default,
## which would keep the entire world simulating through every pause.

var _tick: Callable = Callable()


func bind(callback: Callable) -> void:
	_tick = callback


func _process(delta: float) -> void:
	if _tick.is_valid():
		_tick.call(delta)
