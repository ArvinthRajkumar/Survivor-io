extends Node
## Top level game state machine and scene router.
##
## GameManager owns *when* things happen (menu -> run -> results, pausing for a
## level-up, offering a revive) while RunManager owns the run's numbers and the
## level scene owns the moment-to-moment simulation.

signal state_changed(new_state: int)
signal level_up_requested
signal revive_offered
signal run_results_ready(results: Dictionary)
signal quality_changed(quality: int)

enum State { BOOT, MAIN_MENU, HERO_SELECT, LEVEL_SELECT, META, PLAYING, PAUSED, LEVEL_UP, RESULTS }

const SCENE_MAIN_MENU := "res://scenes/menus/MainMenu.tscn"
const SCENE_HERO_SELECT := "res://scenes/menus/HeroSelect.tscn"
const SCENE_LEVEL_SELECT := "res://scenes/menus/LevelSelect.tscn"
const SCENE_META := "res://scenes/menus/MetaLab.tscn"
const SCENE_GAME := "res://scenes/game/GameScene.tscn"

var state: State = State.BOOT
var selected_hero: HeroData
var selected_level: LevelData
var quality: int = 1
## Set while a revive offer is on screen so the level scene can freeze.
var awaiting_revive: bool = false
var revives_available: int = 0

var _pause_sources: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	quality = int(SaveManager.get_setting("quality", 1))
	_apply_quality()
	# One generated theme on the window root styles every Control in the game.
	var root := get_tree().root
	if root != null:
		root.theme = UITheme.build()
	RunManager.run_finished.connect(_on_run_finished)


func set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(int(new_state))


# --- Selection -------------------------------------------------------------

func select_hero(hero: HeroData) -> void:
	selected_hero = hero
	if hero != null:
		SaveManager.profile["last_hero"] = String(hero.id)
		SaveManager.mark_dirty()


func select_level(level: LevelData) -> void:
	selected_level = level
	if level != null:
		SaveManager.profile["last_level"] = String(level.id)
		SaveManager.mark_dirty()


func restore_last_selection() -> void:
	if selected_hero == null:
		selected_hero = ContentDB.get_hero(StringName(SaveManager.profile.get("last_hero", "nova")))
	if selected_hero == null:
		selected_hero = ContentDB.get_first_hero()
	if selected_level == null:
		selected_level = ContentDB.get_level(StringName(SaveManager.profile.get("last_level", "neon_ruins")))
	if selected_level == null:
		selected_level = ContentDB.get_first_level()


# --- Navigation ------------------------------------------------------------

func goto_main_menu() -> void:
	_clear_pause()
	set_state(State.MAIN_MENU)
	AudioManager.play_music(&"menu")
	get_tree().change_scene_to_file(SCENE_MAIN_MENU)


func goto_hero_select() -> void:
	set_state(State.HERO_SELECT)
	get_tree().change_scene_to_file(SCENE_HERO_SELECT)


func goto_level_select() -> void:
	set_state(State.LEVEL_SELECT)
	get_tree().change_scene_to_file(SCENE_LEVEL_SELECT)


func goto_meta() -> void:
	set_state(State.META)
	get_tree().change_scene_to_file(SCENE_META)


func start_run() -> void:
	restore_last_selection()
	if selected_hero == null or selected_level == null:
		push_error("GameManager: cannot start a run without a hero and a level.")
		return
	SaveManager.clear_active_run()
	_clear_pause()
	awaiting_revive = false
	RunManager.configure(selected_hero, selected_level)
	# Revives depend on stats, which only exist after configure().
	revives_available = maxi(1, RunManager.stats.get_int(&"revives") + 1)
	set_state(State.PLAYING)
	get_tree().change_scene_to_file(SCENE_GAME)


## Picks up an endless run that was interrupted by the app closing.
## Returns false (leaving nothing changed) if the save is stale or unusable.
func resume_run() -> bool:
	if not SaveManager.has_active_run():
		return false
	if not RunManager.restore(SaveManager.get_active_run()):
		SaveManager.clear_active_run()
		return false
	selected_hero = RunManager.hero
	selected_level = RunManager.level_data
	_clear_pause()
	awaiting_revive = false
	revives_available = maxi(1, RunManager.stats.get_int(&"revives") + 1)
	set_state(State.PLAYING)
	get_tree().change_scene_to_file(SCENE_GAME)
	return true


func has_resumable_run() -> bool:
	return SaveManager.has_active_run()


func discard_resumable_run() -> void:
	SaveManager.clear_active_run()


func retry_run() -> void:
	start_run()


func abandon_run() -> void:
	if not RunManager.finished:
		RunManager.finish()
	goto_main_menu()


# --- Pause ------------------------------------------------------------------
## Several systems can want the game paused at once (pause menu, level-up panel,
## revive prompt). Reference counting keeps them from un-pausing each other.

func request_pause(source: String) -> void:
	_pause_sources[source] = true
	get_tree().paused = true
	RunManager.pause_clock()
	if source == "menu":
		set_state(State.PAUSED)
	elif source == "levelup":
		set_state(State.LEVEL_UP)


func release_pause(source: String) -> void:
	_pause_sources.erase(source)
	if _pause_sources.is_empty():
		get_tree().paused = false
		RunManager.resume_clock()
		if state == State.PAUSED or state == State.LEVEL_UP:
			set_state(State.PLAYING)


func is_paused_by(source: String) -> bool:
	return _pause_sources.has(source)


func _clear_pause() -> void:
	_pause_sources.clear()
	get_tree().paused = false


# --- Run events -------------------------------------------------------------

func notify_level_up() -> void:
	level_up_requested.emit()


func offer_revive() -> bool:
	if revives_available <= 0:
		return false
	awaiting_revive = true
	request_pause("revive")
	revive_offered.emit()
	return true


func consume_revive() -> void:
	revives_available = maxi(0, revives_available - 1)
	RunManager.revives_used += 1
	awaiting_revive = false
	release_pause("revive")


func decline_revive() -> void:
	awaiting_revive = false
	release_pause("revive")
	RunManager.finish()


func _on_run_finished(results: Dictionary) -> void:
	set_state(State.RESULTS)
	AudioManager.play_sfx(&"victory" if bool(results.get("threshold_cleared", false)) else &"defeat")
	run_results_ready.emit(results)


# --- Quality ----------------------------------------------------------------

func set_quality(value: int) -> void:
	quality = clampi(value, 0, 2)
	SaveManager.set_setting("quality", quality)
	_apply_quality()
	quality_changed.emit(quality)


func _apply_quality() -> void:
	# 2D perf on phones is dominated by draw calls and particle counts rather
	# than resolution, so quality tunes budgets (see particle_budget_scale,
	# RunManager.enemy_budget) and caps the frame rate on weaker devices.
	Engine.max_fps = 60 if quality < 2 else 0
	var tree := get_tree()
	if tree != null and tree.root != null:
		tree.root.msaa_2d = Viewport.MSAA_DISABLED if quality < 2 else Viewport.MSAA_2X


## Multiplier applied to every particle emitter and cosmetic effect count.
func particle_budget_scale() -> float:
	match quality:
		0:
			return 0.4
		1:
			return 0.75
		_:
			return 1.0


## Enemy separation is the most expensive per-frame system; low quality runs it
## less often.
func separation_frame_skip() -> int:
	match quality:
		0:
			return 4
		1:
			return 3
		_:
			return 2
