class_name HealthComponent
extends Node
## Reusable hit points container used by the player, enemies and bosses.
##
## Owners never mutate health directly; they call take_damage/heal and react to
## the signals, which keeps damage numbers, flashes and death handling in one place.

signal damaged(amount: float, is_crit: bool, source_position: Vector2)
signal healed(amount: float)
signal health_changed(current: float, maximum: float)
signal died

@export var max_health: float = 100.0
@export var invulnerable: bool = false
## Seconds of immunity granted after a hit (0 disables i-frames).
@export var invuln_time: float = 0.0

var current_health: float = 100.0
var armor: float = 0.0
var damage_reduction: float = 0.0

var _invuln_timer: float = 0.0
var _dead: bool = false


func _ready() -> void:
	set_process(invuln_time > 0.0)


func _process(delta: float) -> void:
	if _invuln_timer > 0.0:
		_invuln_timer -= delta


func setup(maximum: float, keep_ratio: bool = false) -> void:
	var ratio := 1.0
	if keep_ratio and max_health > 0.0:
		ratio = clampf(current_health / max_health, 0.0, 1.0)
	max_health = maxf(1.0, maximum)
	current_health = max_health * (ratio if keep_ratio else 1.0)
	_dead = false
	_invuln_timer = 0.0
	health_changed.emit(current_health, max_health)


func is_dead() -> bool:
	return _dead


func is_invulnerable() -> bool:
	return invulnerable or _invuln_timer > 0.0


func get_ratio() -> float:
	return clampf(current_health / maxf(1.0, max_health), 0.0, 1.0)


## Returns the damage actually dealt after armor and reduction.
func take_damage(amount: float, is_crit: bool = false, source_position: Vector2 = Vector2.ZERO) -> float:
	if _dead or is_invulnerable() or amount <= 0.0:
		return 0.0
	# Armor subtracts flatly but can never negate more than 80% of a hit.
	var mitigated: float = maxf(amount * 0.2, amount - armor)
	mitigated *= clampf(1.0 - damage_reduction, 0.05, 1.0)
	current_health = maxf(0.0, current_health - mitigated)
	if invuln_time > 0.0:
		_invuln_timer = invuln_time
	damaged.emit(mitigated, is_crit, source_position)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		_dead = true
		died.emit()
	return mitigated


func heal(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	var before := current_health
	current_health = minf(max_health, current_health + amount)
	var gained := current_health - before
	if gained > 0.0:
		healed.emit(gained)
		health_changed.emit(current_health, max_health)


## Used by the revive flow and by pooled enemies being recycled.
func revive(ratio: float = 0.5) -> void:
	_dead = false
	current_health = max_health * clampf(ratio, 0.05, 1.0)
	health_changed.emit(current_health, max_health)
