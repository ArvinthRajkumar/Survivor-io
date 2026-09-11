extends PowerBase
## The generic projectile weapon.
##
## A revolver, a machine pistol, a grenade volley, a seeking swarm, a returning
## blade and a bouncing orb are all the same loop — pick a direction, spawn
## `count` projectiles along it — differing only in how they aim, how they move
## and what they do on contact. All three of those are fields on PowerData, so
## this one script covers every one of them and a new weapon of that family is a
## content change rather than a code change.
##
## Anything that is genuinely a different loop (a thrust, a smash, a nova, a
## deployed turret) has its own script instead. Bending those into here would
## cost more in flags than it saves in files.

## How far out a target may be before the weapon fires along the player's
## heading instead. Roughly a screen and a half.
const TARGET_RANGE := 820.0

## Advances every radial volley so successive shots do not stack on the same
## spokes.
var _radial_phase: float = 0.0


func _fire() -> void:
	if player == null:
		return
	var count := get_count()
	var origin := player.global_position
	var aim := _aim_direction()
	_radial_phase += 0.37
	for i in count:
		var cfg := _projectile_config()
		cfg["position"] = origin
		cfg["direction"] = _direction_for(i, count, aim)
		spawn_projectile(cfg)
	_play_pose(aim)
	play_sound(&"shoot", -14.0)


## A gun kicks, a thrown blade goes over the shoulder. Reading the pose off the
## motion rather than off the weapon id means a new power in this family gets
## the right animation for free.
func _play_pose(aim: Vector2) -> void:
	if player == null or player.visual == null:
		return
	var pose := PlayerVisual.Pose.SHOOT
	if data.motion == Projectile.Motion.BOOMERANG:
		pose = PlayerVisual.Pose.THROW
	elif data.on_hit == Projectile.OnHit.EXPLODE:
		pose = PlayerVisual.Pose.THROW
	player.visual.call("play_attack", pose, aim, 1.0, 2.0, false)


## Where the volley as a whole is pointed. RADIAL ignores this.
func _aim_direction() -> Vector2:
	match data.aim:
		PowerData.Aim.MOVEMENT:
			if player.is_moving():
				return player.move_dir.normalized()
			return player.facing if player.facing.length_squared() > 0.01 else Vector2.RIGHT
		PowerData.Aim.RANDOM:
			var enemy := _random_target()
			if enemy != null:
				return (enemy.global_position - player.global_position).normalized()
		PowerData.Aim.DENSEST:
			var centre := _crowd_centre()
			if centre != Vector2.ZERO:
				return centre.normalized()
		_:
			pass
	return aim_direction(player.facing if player.facing.length_squared() > 0.01 else Vector2.RIGHT)


## Spokes for a radial volley, otherwise an even fan `spread` radians wide.
func _direction_for(index: int, count: int, aim: Vector2) -> Vector2:
	if data.aim == PowerData.Aim.RADIAL:
		return Vector2.RIGHT.rotated(TAU * float(index) / float(count) + _radial_phase)
	if count <= 1 or data.spread <= 0.0:
		return aim
	var t := float(index) / float(count - 1) - 0.5
	return aim.rotated(data.spread * t)


func _random_target() -> Enemy:
	if EnemyDirector.instance == null:
		return null
	var near := EnemyDirector.instance.get_in_radius(player.global_position, TARGET_RANGE, 24)
	if near.is_empty():
		return null
	return near[RunManager.rng.randi_range(0, near.size() - 1)]


## Offset from the player to the average position of the nearby crowd. Zero when
## there is nobody to average.
func _crowd_centre() -> Vector2:
	if EnemyDirector.instance == null:
		return Vector2.ZERO
	var near := EnemyDirector.instance.get_in_radius(player.global_position, TARGET_RANGE, 24)
	if near.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for enemy in near:
		sum += enemy.global_position
	return sum / float(near.size()) - player.global_position


func _projectile_config() -> Dictionary:
	var cfg := base_config()
	cfg["motion"] = data.motion
	cfg["on_hit"] = data.on_hit
	cfg["shape"] = data.projectile_shape
	# A returning projectile needs to know what to return to, and an exploding
	# one how big the blast is. Both are harmless to set for motions that ignore
	# them, which keeps this free of a switch per field.
	cfg["return_target"] = player
	cfg["explode_radius"] = data.effect_radius * get_area()
	cfg["chain_range"] = data.effect_radius * get_area()
	cfg["chain_count"] = maxi(1, int(data.effect_value))
	cfg["slow_factor"] = data.effect_value
	cfg["slow_duration"] = data.duration_at(level)
	return cfg
