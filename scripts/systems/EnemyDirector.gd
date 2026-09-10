class_name EnemyDirector
extends Node2D
## Owns every live enemy: spawning them off-camera, stepping their AI in a
## single loop, keeping a spatial hash for cheap neighbour queries, and applying
## crowd separation so the swarm spreads instead of stacking into one dot.

static var instance: EnemyDirector

signal enemy_spawned(enemy: Enemy)
signal enemy_died(enemy: Enemy)

const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const CELL_SIZE := 64.0
const SEPARATION_STRENGTH := 340.0
## Enemies further than this from the player are recycled and re-spawned closer.
const CULL_DISTANCE := 2400.0

@export var spawn_margin: float = 160.0

var active: Array[Enemy] = []
var _grid: Dictionary = {}
var _frame: int = 0
var _separation_skip: int = 3
var _player_pos: Vector2 = Vector2.ZERO
var _view_half: Vector2 = Vector2(540, 960)


func _ready() -> void:
	instance = self
	_separation_skip = GameManager.separation_frame_skip()
	PoolManager.register(ENEMY_SCENE, self, 120)
	var vp := get_viewport()
	if vp != null:
		_view_half = vp.get_visible_rect().size * 0.5


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _physics_process(delta: float) -> void:
	if active.is_empty():
		return
	var player := Player.instance
	if player == null:
		return
	_player_pos = player.global_position
	_frame += 1

	# Compact first: the spatial hash stores indices into `active`, so the list
	# must not change again until the next rebuild.
	_compact()
	_rebuild_grid()
	if _frame % _separation_skip == 0:
		_apply_separation(float(_separation_skip))

	for enemy in active:
		enemy.update_ai(delta, _player_pos)


## Drops dead enemies and recycles anything that has wandered far off screen.
func _compact() -> void:
	var cull_sq := CULL_DISTANCE * CULL_DISTANCE
	var i := active.size() - 1
	while i >= 0:
		var enemy := active[i]
		if enemy == null or not is_instance_valid(enemy) or not enemy.alive:
			active.remove_at(i)
		elif not enemy.is_boss and enemy.global_position.distance_squared_to(_player_pos) > cull_sq:
			enemy.despawn()
			active.remove_at(i)
		i -= 1


func _rebuild_grid() -> void:
	_grid.clear()
	for index in active.size():
		var enemy := active[index]
		if enemy == null or not is_instance_valid(enemy) or not enemy.alive:
			continue
		var cell := _cell_of(enemy.global_position)
		var bucket: Array = _grid.get(cell, [])
		bucket.append(index)
		_grid[cell] = bucket


func _cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / CELL_SIZE)), int(floor(pos.y / CELL_SIZE)))


## Pushes overlapping neighbours apart. Runs every few frames with a matching
## strength boost, which looks identical but costs a fraction of the time.
func _apply_separation(strength_scale: float) -> void:
	for cell in _grid:
		var bucket: Array = _grid[cell]
		for offset_x in range(-1, 2):
			for offset_y in range(-1, 2):
				var other_cell := Vector2i(cell.x + offset_x, cell.y + offset_y)
				if other_cell < cell:
					continue
				var other: Array = _grid.get(other_cell, [])
				if other.is_empty():
					continue
				_separate_buckets(bucket, other, other_cell == cell, strength_scale)


func _separate_buckets(a: Array, b: Array, same: bool, strength_scale: float) -> void:
	for ia in a.size():
		var ea := active[a[ia]]
		if ea == null or not ea.alive:
			continue
		var start := ia + 1 if same else 0
		for ib in range(start, b.size()):
			var eb := active[b[ib]]
			if eb == null or not eb.alive or eb == ea:
				continue
			var delta_pos := eb.global_position - ea.global_position
			var min_dist := ea.radius + eb.radius
			var dist_sq := delta_pos.length_squared()
			if dist_sq >= min_dist * min_dist or dist_sq < 0.0001:
				continue
			var dist := sqrt(dist_sq)
			var push := delta_pos / dist * (1.0 - dist / min_dist) * SEPARATION_STRENGTH * strength_scale
			# Heavier enemies shove lighter ones.
			var total_mass := ea.data.mass + eb.data.mass
			ea.separation -= push * (eb.data.mass / total_mass)
			eb.separation += push * (ea.data.mass / total_mass)


# --- Spawning --------------------------------------------------------------

## Spawns just outside the visible rectangle so enemies always walk on screen.
func spawn_offscreen(data: EnemyData, elite: bool = false, angle_hint: float = -1.0) -> Enemy:
	var angle := angle_hint if angle_hint >= 0.0 else RunManager.rng.randf() * TAU
	var dir := Vector2(cos(angle), sin(angle))
	var half := _view_half + Vector2(spawn_margin, spawn_margin)
	# Scale the direction out to the edge of the view rectangle.
	var scale_x := half.x / maxf(0.001, absf(dir.x))
	var scale_y := half.y / maxf(0.001, absf(dir.y))
	var reach := minf(scale_x, scale_y)
	var pos := _player_pos + dir * reach
	return spawn_at(data, pos, elite)


func spawn_at(data: EnemyData, pos: Vector2, elite: bool = false) -> Enemy:
	if data == null:
		return null
	var enemy := PoolManager.acquire(ENEMY_SCENE) as Enemy
	if enemy == null:
		return null
	enemy.global_position = pos
	enemy.configure(data, elite, RunManager.enemy_health_scale(), RunManager.enemy_damage_scale())
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)
	active.append(enemy)
	enemy_spawned.emit(enemy)
	return enemy


func _on_enemy_died(enemy: Enemy) -> void:
	enemy_died.emit(enemy)


func count() -> int:
	return active.size()


func set_view_half(value: Vector2) -> void:
	_view_half = value


func set_player_position(pos: Vector2) -> void:
	_player_pos = pos


# --- Queries (used by homing weapons and the auto-aim) ---------------------

## Nearest live enemy within `max_dist`, searched through the spatial hash so
## the cost does not grow with the total swarm size.
func get_nearest(pos: Vector2, max_dist: float = 900.0) -> Enemy:
	var best: Enemy = null
	var best_sq := max_dist * max_dist
	var reach := maxi(1, int(ceil(max_dist / CELL_SIZE)))
	var center := _cell_of(pos)
	for ring in range(0, reach + 1):
		var found_in_ring := false
		for offset_x in range(-ring, ring + 1):
			for offset_y in range(-ring, ring + 1):
				# Only walk the outer shell of each ring.
				if ring > 0 and absi(offset_x) != ring and absi(offset_y) != ring:
					continue
				var bucket: Array = _grid.get(Vector2i(center.x + offset_x, center.y + offset_y), [])
				for index in bucket:
					var enemy := active[index]
					if enemy == null or not is_instance_valid(enemy) or not enemy.alive:
						continue
					var d := pos.distance_squared_to(enemy.global_position)
					if d < best_sq:
						best_sq = d
						best = enemy
						found_in_ring = true
		# One extra ring after the first hit guarantees we did not miss a closer
		# enemy sitting just across a cell boundary.
		if found_in_ring and ring > 0:
			break
	if best == null and not active.is_empty():
		best = _linear_nearest(pos, max_dist)
	return best


func _linear_nearest(pos: Vector2, max_dist: float) -> Enemy:
	var best: Enemy = null
	var best_sq := max_dist * max_dist
	for enemy in active:
		if enemy == null or not is_instance_valid(enemy) or not enemy.alive:
			continue
		var d := pos.distance_squared_to(enemy.global_position)
		if d < best_sq:
			best_sq = d
			best = enemy
	return best


## All live enemies within a radius - used by explosions, auras and ultimates.
func get_in_radius(pos: Vector2, radius: float, limit: int = 64) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var radius_sq := radius * radius
	var reach := maxi(1, int(ceil(radius / CELL_SIZE)))
	var center := _cell_of(pos)
	for offset_x in range(-reach, reach + 1):
		for offset_y in range(-reach, reach + 1):
			var bucket: Array = _grid.get(Vector2i(center.x + offset_x, center.y + offset_y), [])
			for index in bucket:
				var enemy := active[index]
				if enemy == null or not is_instance_valid(enemy) or not enemy.alive:
					continue
				if pos.distance_squared_to(enemy.global_position) <= radius_sq:
					out.append(enemy)
					if out.size() >= limit:
						return out
	return out


## Clears the field, e.g. when a bomb pickup is collected or the run ends.
func kill_all_on_screen(damage: float) -> void:
	for enemy in active.duplicate():
		if enemy == null or not is_instance_valid(enemy) or not enemy.alive or enemy.is_boss:
			continue
		enemy.apply_hit(damage, false, Vector2.ZERO, get_instance_id(), 0.0)


func clear_all() -> void:
	for enemy in active.duplicate():
		if enemy != null and is_instance_valid(enemy):
			enemy.despawn()
	active.clear()
	_grid.clear()
