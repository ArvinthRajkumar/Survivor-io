class_name WaveData
extends Resource
## One entry in a level's wave script.
##
## The director walks the list in order and keeps a wave active while the run
## clock sits between start_time and end_time, so waves can deliberately overlap.

enum Formation { SCATTER, RING, ARC, STREAM, BURST }

@export var enemy_id: StringName = &""
@export var start_time: float = 0.0
@export var end_time: float = 60.0
## Enemies released per spawn tick.
@export var batch_size: int = 4
## Seconds between spawn ticks at the start of the wave.
@export var interval: float = 1.5
## Interval multiplier reached by the end of the wave (below 1.0 = ramps up).
@export var interval_end_scale: float = 0.7
@export var formation: Formation = Formation.SCATTER
@export_range(0.0, 1.0) var elite_chance: float = 0.0
## One-shot waves fire a single time at start_time.
@export var one_shot: bool = false
