class_name PowerLoadout
extends RefCounted
## What the player has chosen this run, and the six-slot rule that makes those
## choices matter.
##
## Powers and Passive Abilities share one pool of slots. Once MAX_SLOTS entries
## are owned the offer generator stops proposing new ones entirely — from that
## point a level-up can only deepen what you already have. Nothing can be
## swapped out, so an early pick is a commitment.

signal entry_added(data: PowerData, level: int)
signal entry_leveled(data: PowerData, level: int)
signal entry_maxed(data: PowerData)
signal changed

const MAX_SLOTS := 6

## StringName -> int level
var levels: Dictionary = {}


func clear() -> void:
	levels.clear()
	changed.emit()


func slots_used() -> int:
	return levels.size()


func slots_free() -> int:
	return maxi(0, MAX_SLOTS - levels.size())


func is_full() -> bool:
	return levels.size() >= MAX_SLOTS


func has(id: StringName) -> bool:
	return levels.has(id)


func get_level(id: StringName) -> int:
	return int(levels.get(id, 0))


func get_ids() -> Array:
	return levels.keys()


## Owned ids of one category, in the order they were picked.
func get_ids_of(category: PowerData.Category) -> Array:
	var out: Array = []
	for id in levels.keys():
		var data := ContentDB.get_power(id)
		if data != null and data.category == category:
			out.append(id)
	return out


func is_maxed(id: StringName) -> bool:
	var data := ContentDB.get_power(id)
	return data != null and get_level(id) >= data.max_level


## True when this entry can legally appear in a level-up offer.
func can_offer(data: PowerData) -> bool:
	if data == null:
		return false
	if levels.has(data.id):
		return get_level(data.id) < data.max_level
	return not is_full()


## Adds the entry at level 1, or raises it by one. Returns the new level.
func add_or_level(id: StringName) -> int:
	var data := ContentDB.get_power(id)
	if data == null:
		push_warning("PowerLoadout: unknown power %s" % id)
		return 0
	if levels.has(id):
		var level: int = mini(data.max_level, get_level(id) + 1)
		levels[id] = level
		entry_leveled.emit(data, level)
		if level >= data.max_level:
			entry_maxed.emit(data)
		changed.emit()
		return level
	if is_full():
		push_warning("PowerLoadout: all %d slots are taken." % MAX_SLOTS)
		return 0
	levels[id] = 1
	entry_added.emit(data, 1)
	changed.emit()
	return 1


# --- Persistence (used to resume an interrupted run) ------------------------

func to_dictionary() -> Dictionary:
	var out: Dictionary = {}
	for id in levels:
		out[String(id)] = int(levels[id])
	return out


func from_dictionary(dict: Dictionary) -> void:
	levels.clear()
	for key in dict.keys():
		var id := StringName(key)
		if ContentDB.get_power(id) != null:
			levels[id] = int(dict[key])
	changed.emit()
