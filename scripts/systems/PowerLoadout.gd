class_name PowerLoadout
extends RefCounted
## What the player has chosen this run, and the six-slot rule that makes those
## choices matter.
##
## Powers and Passives share one pool of slots. Once MAX_SLOTS entries
## are owned the offer generator stops proposing new ones entirely — from that
## point a level-up can only deepen what you already have. Nothing can be
## swapped out, so an early pick is a commitment.
##
## The katana is the exception: every operative carries one in, so it is granted
## before the run starts and spends none of the six. It still levels like
## anything else, which is why it lives in this dictionary rather than off to one
## side — it is simply not counted against the budget.

signal entry_added(data: PowerData, level: int)
signal entry_leveled(data: PowerData, level: int)
signal entry_maxed(data: PowerData)
signal changed

const MAX_SLOTS := 6
## Granted at the start of every run and excluded from the slot budget.
const INNATE_ID := &"katana"

## StringName -> int level
var levels: Dictionary = {}


func clear() -> void:
	levels.clear()
	changed.emit()


## Only chosen entries count; the innate weapon is free.
func slots_used() -> int:
	var used := levels.size()
	if levels.has(INNATE_ID):
		used -= 1
	return maxi(0, used)


func slots_free() -> int:
	return maxi(0, MAX_SLOTS - slots_used())


func is_full() -> bool:
	return slots_used() >= MAX_SLOTS


func is_innate(id: StringName) -> bool:
	return id == INNATE_ID


## Owned ids with the innate weapon first, which is the order the HUD draws.
func get_ordered_ids() -> Array:
	var out: Array = []
	if levels.has(INNATE_ID):
		out.append(INNATE_ID)
	for id in levels.keys():
		if id != INNATE_ID:
			out.append(id)
	return out


## The chosen entries only — what the six-slot budget is actually spent on.
func get_chosen_ids() -> Array:
	var out: Array = []
	for id in levels.keys():
		if id != INNATE_ID:
			out.append(id)
	return out


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
	# The innate weapon is granted, never offered as a new pick.
	return data.id != INNATE_ID and not is_full()


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
	if is_full() and not is_innate(id):
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
	# The innate weapon goes in first so it keeps the leading HUD slot, and is
	# re-granted even for a run saved before it existed.
	if ContentDB.get_power(INNATE_ID) != null:
		levels[INNATE_ID] = maxi(1, int(dict.get(String(INNATE_ID), 1)))
	for key in dict.keys():
		var id := StringName(key)
		if id == INNATE_ID:
			continue
		if ContentDB.get_power(id) != null:
			levels[id] = int(dict[key])
	changed.emit()
