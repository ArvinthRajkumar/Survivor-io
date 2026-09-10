extends PowerBase
## Drill — drills that ricochet around the play area.
##
## The drills are persistent bodies rather than timed projectiles: levelling up
## adds more of them and sharpens the ones already out, so the screen gradually
## fills with ricochets instead of the power firing in bursts.

const BOUNDS := Vector2(470.0, 840.0)

var _drills: Array[DrillBody] = []


func _on_setup() -> void:
	_rebuild()


func _on_level_changed() -> void:
	_retune()


func _config(index: int, total: int) -> Dictionary:
	var angle := TAU * float(index) / float(maxi(1, total)) + RunManager.rng.randf_range(-0.3, 0.3)
	return {
		"position": player.global_position + Vector2(cos(angle), sin(angle)) * 90.0,
		"direction": Vector2(cos(angle), sin(angle)),
		"speed": get_speed(),
		"drill_radius": 20.0 * get_area(),
		"color": data.color,
		"color2": data.color_secondary,
		"damage": get_damage(),
		"crit_chance": get_crit_chance(),
		"crit_damage": get_crit_damage(),
		"knockback": get_knockback(),
		"hit_interval": data.hit_interval,
		"source_id": get_instance_id(),
		"half_extents": BOUNDS,
	}


func _rebuild() -> void:
	_clear()
	var total := get_count()
	for i in total:
		var drill := ProjectileSystem.instance.spawn_drill(_config(i, total)) if ProjectileSystem.instance != null else null
		if drill != null:
			_drills.append(drill)


func _retune() -> void:
	_prune()
	if _drills.size() != get_count():
		_rebuild()
		return
	for i in _drills.size():
		_drills[i].retune(_config(i, _drills.size()))


func _prune() -> void:
	var i := _drills.size() - 1
	while i >= 0:
		if _drills[i] == null or not is_instance_valid(_drills[i]):
			_drills.remove_at(i)
		i -= 1


func _fire() -> void:
	_prune()
	if _drills.size() != get_count():
		_rebuild()


func _clear() -> void:
	for drill in _drills:
		if drill != null and is_instance_valid(drill):
			drill.expire()
	_drills.clear()


func _exit_tree() -> void:
	_clear()
