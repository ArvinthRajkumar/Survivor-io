class_name PowerManager
extends Node2D
## Turns the run loadout into live behaviour.
##
## Powers become child nodes running their own behaviour script; Passives are
## folded into PlayerStats. Both are driven from PowerLoadout signals, so picking
## an upgrade in the level-up panel is immediately reflected in play with no
## other wiring.
##
## Passive levels already applied are tracked per id, which means sync() is safe
## to call repeatedly — including when restoring a run that was interrupted.

signal loadout_synced

const BEHAVIORS := {
	PowerData.Behavior.KATANA: preload("res://scripts/powers/behaviors/KatanaPower.gd"),
	PowerData.Behavior.DRONE: preload("res://scripts/powers/behaviors/DronePower.gd"),
	PowerData.Behavior.DOMAIN: preload("res://scripts/powers/behaviors/DomainPower.gd"),
	PowerData.Behavior.MOLOTOV: preload("res://scripts/powers/behaviors/MolotovPower.gd"),
	PowerData.Behavior.DRILL: preload("res://scripts/powers/behaviors/DrillPower.gd"),
	PowerData.Behavior.HEALING_DRONE: preload("res://scripts/powers/behaviors/HealingDronePower.gd"),
	PowerData.Behavior.LASER: preload("res://scripts/powers/behaviors/LaserPower.gd"),
	PowerData.Behavior.SPINNERS: preload("res://scripts/powers/behaviors/SpinnerPower.gd"),
	PowerData.Behavior.VOLLEY: preload("res://scripts/powers/behaviors/VolleyPower.gd"),
	PowerData.Behavior.NOVA: preload("res://scripts/powers/behaviors/NovaPower.gd"),
	PowerData.Behavior.SPEAR: preload("res://scripts/powers/behaviors/SpearPower.gd"),
	PowerData.Behavior.HAMMER: preload("res://scripts/powers/behaviors/HammerPower.gd"),
	PowerData.Behavior.FLAMER: preload("res://scripts/powers/behaviors/FlamerPower.gd"),
	PowerData.Behavior.MINES: preload("res://scripts/powers/behaviors/MinePower.gd"),
	PowerData.Behavior.TURRET: preload("res://scripts/powers/behaviors/TurretPower.gd"),
	PowerData.Behavior.BLADESTORM: preload("res://scripts/powers/behaviors/BladeStormPower.gd"),
	PowerData.Behavior.VOID_WELL: preload("res://scripts/powers/behaviors/VoidWellPower.gd"),
	PowerData.Behavior.BOW: preload("res://scripts/powers/behaviors/BowPower.gd"),
}

var player: Player
var stats: PlayerStats

var _powers: Dictionary = {}                  # StringName -> PowerBase
var _applied_passive_levels: Dictionary = {}  # StringName -> int
var _firing: bool = true


func setup(owner_player: Player, owner_stats: PlayerStats) -> void:
	player = owner_player
	stats = owner_stats
	var loadout := RunManager.loadout
	if not loadout.entry_added.is_connected(_on_entry_changed):
		loadout.entry_added.connect(_on_entry_changed)
		loadout.entry_leveled.connect(_on_entry_changed)
	sync()


## Brings live behaviour in line with the loadout. Idempotent.
func sync() -> void:
	var loadout := RunManager.loadout
	for id in loadout.get_ids():
		var data := ContentDB.get_power(id)
		if data == null:
			continue
		var level := loadout.get_level(id)
		if data.is_passive():
			_apply_passive(data, level)
		elif _powers.has(id):
			(_powers[id] as PowerBase).set_level(level)
		else:
			_add_power(data, level)

	# Drop anything no longer owned (never happens today, but keeps sync honest).
	for id in _powers.keys():
		if not loadout.has(id):
			_remove_power(id)
	loadout_synced.emit()


func _on_entry_changed(data: PowerData, level: int) -> void:
	if data.is_passive():
		_apply_passive(data, level)
		return
	if _powers.has(data.id):
		(_powers[data.id] as PowerBase).set_level(level)
	else:
		_add_power(data, level)


func _add_power(data: PowerData, level: int) -> void:
	if data == null or _powers.has(data.id):
		return
	var script: Script = BEHAVIORS.get(data.behavior)
	if script == null:
		push_warning("PowerManager: no behaviour for %s" % data.display_name)
		return
	var node := Node2D.new()
	node.set_script(script)
	node.name = "Power_%s" % String(data.id)
	add_child(node)
	var power := node as PowerBase
	power.set_firing(_firing)
	power.setup(data, level, player, stats)
	_powers[data.id] = power


func _remove_power(id: StringName) -> void:
	var power: PowerBase = _powers.get(id)
	if power != null and is_instance_valid(power):
		power.queue_free()
	_powers.erase(id)


## Applies only the levels not yet folded into PlayerStats, so this is safe to
## call again after a restore without double-counting.
func _apply_passive(data: PowerData, level: int) -> void:
	if stats == null:
		return
	var already := int(_applied_passive_levels.get(data.id, 0))
	var missing := level - already
	if missing <= 0:
		return
	_applied_passive_levels[data.id] = level
	for key in data.stat_multipliers:
		stats.add_mult(StringName(key), float(data.stat_multipliers[key]) * float(missing))
	for key in data.stat_flats:
		stats.add_flat(StringName(key), float(data.stat_flats[key]) * float(missing))


func set_firing(value: bool) -> void:
	_firing = value
	for id in _powers:
		(_powers[id] as PowerBase).set_firing(value)


func get_power(id: StringName) -> PowerBase:
	return _powers.get(id) as PowerBase


## Cooldown progress of an owned power, for the HUD slot ring. Passives report 1.
func get_charge_ratio(id: StringName) -> float:
	var power := get_power(id)
	return power.get_charge_ratio() if power != null else 1.0
