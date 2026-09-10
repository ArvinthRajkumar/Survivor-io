extends Node
## Local JSON persistence for unlocks, meta upgrades, relics and settings.
##
## The whole profile is one small dictionary written to
## user://lastlight_save.json. Writes go through a short debounce so rapid
## changes (e.g. spending currency in a shop) do not thrash storage on mobile.

signal profile_loaded
signal profile_changed
signal currency_changed(credits: int, research: int)

const SAVE_PATH := "user://lastlight_save.json"
const BACKUP_PATH := "user://lastlight_save.bak.json"
const SAVE_VERSION := 1
const AUTOSAVE_DELAY := 0.75

var profile: Dictionary = {}

var _dirty: bool = false
var _timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_profile()


func _process(delta: float) -> void:
	if not _dirty:
		return
	_timer -= delta
	if _timer <= 0.0:
		write_now()


func default_profile() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"credits": 0,
		"research": 0,
		"unlocked_heroes": ["nova"],
		"unlocked_levels": ["neon_ruins"],
		"unlocked_relics": [],
		"equipped_relics": [],
		"meta_upgrades": {},        # upgrade id -> level
		"hero_levels": {},          # hero id -> permanent stat level
		"best_times": {},           # level id -> best survived seconds
		"clears": {},               # level id -> times completed
		"total_runs": 0,
		"total_kills": 0,
		"tutorial_done": false,
		"active_run": {},   # an interrupted endless run, restored on next launch
		"last_hero": "nova",
		"last_level": "neon_ruins",
		"settings": default_settings(),
	}


func default_settings() -> Dictionary:
	return {
		"music_volume": 0.7,
		"sfx_volume": 0.9,
		"vibration": true,
		"quality": 1,          # 0 low, 1 medium, 2 high
		"show_damage_numbers": true,
		"joystick_side": 0,    # 0 left, 1 right
		"joystick_dynamic": true,
	}


func load_profile() -> void:
	profile = default_profile()
	var text := _read_file(SAVE_PATH)
	if text.is_empty():
		text = _read_file(BACKUP_PATH)
	if not text.is_empty():
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			_merge_into_profile(parsed as Dictionary)
		else:
			push_warning("SaveManager: save file was not valid JSON, using defaults.")
	profile_loaded.emit()


func _read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("SaveManager: could not open %s" % path)
		return ""
	var text := f.get_as_text()
	f.close()
	return text


## Copies known keys from disk over the defaults so older saves keep working
## when new fields are added.
func _merge_into_profile(loaded: Dictionary) -> void:
	for key in profile.keys():
		if not loaded.has(key):
			continue
		if key == "settings":
			var settings: Dictionary = profile["settings"]
			var loaded_settings: Variant = loaded["settings"]
			if loaded_settings is Dictionary:
				for skey in settings.keys():
					if (loaded_settings as Dictionary).has(skey):
						settings[skey] = (loaded_settings as Dictionary)[skey]
			continue
		profile[key] = loaded[key]
	profile["version"] = SAVE_VERSION


func mark_dirty() -> void:
	_dirty = true
	_timer = AUTOSAVE_DELAY
	profile_changed.emit()


func write_now() -> void:
	_dirty = false
	_timer = 0.0
	if FileAccess.file_exists(SAVE_PATH):
		var old := _read_file(SAVE_PATH)
		if not old.is_empty():
			var b := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if b != null:
				b.store_string(old)
				b.close()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: unable to write %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(profile, "\t"))
	f.close()


## Closing the window, backgrounding the app on mobile, or the tree going away
## all mean the same thing: commit whatever is pending, including a run in
## progress, before we lose the chance.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, 		NOTIFICATION_WM_GO_BACK_REQUEST, NOTIFICATION_EXIT_TREE:
			capture_active_run()
			if _dirty:
				write_now()


# --- Interrupted run --------------------------------------------------------

## Snapshots a live run so it can be resumed after the app is closed. Called on
## shutdown and periodically by the level scene.
func capture_active_run() -> void:
	if RunManager.hero == null or RunManager.finished or not RunManager.running:
		return
	profile["active_run"] = RunManager.to_save_dictionary()
	mark_dirty()


func get_active_run() -> Dictionary:
	var stored: Variant = profile.get("active_run", {})
	return stored as Dictionary if stored is Dictionary else {}


func has_active_run() -> bool:
	var stored := get_active_run()
	return stored.has("hero") and not String(stored.get("hero", "")).is_empty()


func clear_active_run() -> void:
	if profile.get("active_run", {}) != {}:
		profile["active_run"] = {}
		mark_dirty()


# --- Convenience accessors -------------------------------------------------

func get_setting(key: String, fallback: Variant = null) -> Variant:
	var settings: Dictionary = profile.get("settings", {})
	return settings.get(key, fallback)


func set_setting(key: String, value: Variant) -> void:
	var settings: Dictionary = profile.get("settings", {})
	settings[key] = value
	profile["settings"] = settings
	mark_dirty()


func get_credits() -> int:
	return int(profile.get("credits", 0))


func get_research() -> int:
	return int(profile.get("research", 0))


func add_currency(credits: int, research: int) -> void:
	profile["credits"] = maxi(0, get_credits() + credits)
	profile["research"] = maxi(0, get_research() + research)
	currency_changed.emit(get_credits(), get_research())
	mark_dirty()


func can_afford(credits: int, research: int) -> bool:
	return get_credits() >= credits and get_research() >= research


func spend(credits: int, research: int) -> bool:
	if not can_afford(credits, research):
		return false
	add_currency(-credits, -research)
	return true


func is_hero_unlocked(hero_id: StringName) -> bool:
	return (profile.get("unlocked_heroes", []) as Array).has(String(hero_id))


func unlock_hero(hero_id: StringName) -> void:
	var list: Array = profile.get("unlocked_heroes", [])
	if not list.has(String(hero_id)):
		list.append(String(hero_id))
		profile["unlocked_heroes"] = list
		mark_dirty()


func is_level_unlocked(level_id: StringName) -> bool:
	return (profile.get("unlocked_levels", []) as Array).has(String(level_id))


func unlock_level(level_id: StringName) -> void:
	var list: Array = profile.get("unlocked_levels", [])
	if not list.has(String(level_id)):
		list.append(String(level_id))
		profile["unlocked_levels"] = list
		mark_dirty()


func is_relic_unlocked(relic_id: StringName) -> bool:
	return (profile.get("unlocked_relics", []) as Array).has(String(relic_id))


func unlock_relic(relic_id: StringName) -> void:
	var list: Array = profile.get("unlocked_relics", [])
	if not list.has(String(relic_id)):
		list.append(String(relic_id))
		profile["unlocked_relics"] = list
		mark_dirty()


func get_equipped_relics() -> Array:
	return profile.get("equipped_relics", [])


func set_equipped_relics(ids: Array) -> void:
	profile["equipped_relics"] = ids
	mark_dirty()


## Per-hero permanent rank, bought on the roster screen.
func get_hero_rank(hero_id: StringName) -> int:
	var dict: Dictionary = profile.get("hero_levels", {})
	return int(dict.get(String(hero_id), 0))


func set_hero_rank(hero_id: StringName, rank: int) -> void:
	var dict: Dictionary = profile.get("hero_levels", {})
	dict[String(hero_id)] = rank
	profile["hero_levels"] = dict
	mark_dirty()


func get_meta_level(upgrade_id: StringName) -> int:
	var dict: Dictionary = profile.get("meta_upgrades", {})
	return int(dict.get(String(upgrade_id), 0))


func set_meta_level(upgrade_id: StringName, level: int) -> void:
	var dict: Dictionary = profile.get("meta_upgrades", {})
	dict[String(upgrade_id)] = level
	profile["meta_upgrades"] = dict
	mark_dirty()


func record_run(level_id: StringName, survived: float, kills: int, victory: bool) -> void:
	profile["total_runs"] = int(profile.get("total_runs", 0)) + 1
	profile["total_kills"] = int(profile.get("total_kills", 0)) + kills
	var best: Dictionary = profile.get("best_times", {})
	var key := String(level_id)
	if survived > float(best.get(key, 0.0)):
		best[key] = survived
	profile["best_times"] = best
	if victory:
		var clears: Dictionary = profile.get("clears", {})
		clears[key] = int(clears.get(key, 0)) + 1
		profile["clears"] = clears
	mark_dirty()


func get_best_time(level_id: StringName) -> float:
	var best: Dictionary = profile.get("best_times", {})
	return float(best.get(String(level_id), 0.0))


## Longest survival across every sector, for the main menu's headline stat.
func get_best_time_overall() -> float:
	var best: Dictionary = profile.get("best_times", {})
	var top := 0.0
	for key in best:
		top = maxf(top, float(best[key]))
	return top


func get_clear_count(level_id: StringName) -> int:
	var clears: Dictionary = profile.get("clears", {})
	return int(clears.get(String(level_id), 0))


func reset_profile() -> void:
	profile = default_profile()
	write_now()
	profile_loaded.emit()
