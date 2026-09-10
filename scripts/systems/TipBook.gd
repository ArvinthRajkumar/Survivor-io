class_name TipBook
extends RefCounted
## Loads the shipped gameplay tips from data/tips.json.
##
## Kept as plain JSON rather than a Resource so the text can be edited (or
## translated) without opening the engine, and so it is obvious that nothing in
## data/ affects behaviour - it is copy only.

const PATH := "res://data/tips.json"

static var _tips: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


static func all() -> PackedStringArray:
	if not _loaded:
		_load()
	return _tips


## A tip chosen at random. Falls back to an empty string if the file is missing,
## so a broken data file can never block the loading screen.
static func random(rng: RandomNumberGenerator = null) -> String:
	var tips := all()
	if tips.is_empty():
		return ""
	if rng != null:
		return tips[rng.randi() % tips.size()]
	return tips[randi() % tips.size()]


static func _load() -> void:
	_loaded = true
	_tips = PackedStringArray()
	if not FileAccess.file_exists(PATH):
		push_warning("TipBook: %s is missing." % PATH)
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_warning("TipBook: could not open %s" % PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		push_warning("TipBook: %s is not a JSON object." % PATH)
		return
	var entries: Variant = (parsed as Dictionary).get("tips", [])
	if not (entries is Array):
		return
	for entry in (entries as Array):
		if entry is Dictionary:
			var text := String((entry as Dictionary).get("text", ""))
			if not text.is_empty():
				_tips.append(text)
