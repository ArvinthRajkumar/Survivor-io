extends Control
## First scene loaded. Waits for the content database, applies saved settings and
## routes straight to the main menu.

@onready var _title: Label = $Center/Box/Title
@onready var _subtitle: Label = $Center/Box/Subtitle
@onready var _status: Label = $Center/Box/Status

var _elapsed: float = 0.0
var _done: bool = false


func _ready() -> void:
	_title.text = "LAST LIGHT"
	_subtitle.text = "S W A R M F A L L"
	_status.text = "Loading"
	_title.add_theme_color_override("font_color", Palette.ACCENT)
	_subtitle.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_status.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(760, 0)
	GameManager.restore_last_selection()


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	if _elapsed < 0.6 or not ContentDB.is_ready():
		return
	_done = true
	if ContentDB.hero_list.is_empty():
		_status.text = "No hero resources found in resources/heroes."
		return
	GameManager.restore_last_selection()
	_apply_dev_selection()
	# Dev affordances (see DevTools): --smoke drops straight into an automated
	# run, --screen=<name> boots directly into one menu.
	if DevTools.smoke:
		GameManager.start_run()
		return
	match DevTools.requested_screen():
		"hero":
			GameManager.goto_hero_select()
		"level":
			GameManager.goto_level_select()
		"lab":
			GameManager.goto_meta()
		"weapon":
			GameManager.goto_weapon_select()
		"hardcore":
			GameManager.goto_hardcore_select()
		"settings":
			get_tree().change_scene_to_file("res://scenes/menus/Settings.tscn")
		"game":
			GameManager.start_run()
		_:
			GameManager.goto_main_menu()


## --hero= / --level= override the saved selection without touching the profile,
## so a soak run can be pointed at any combination.
func _apply_dev_selection() -> void:
	var hero_id := DevTools.get_option("hero")
	if not hero_id.is_empty():
		var hero := ContentDB.get_hero(StringName(hero_id))
		if hero != null:
			GameManager.selected_hero = hero
		else:
			push_warning("Boot: unknown --hero=%s" % hero_id)
	var level_id := DevTools.get_option("level")
	if not level_id.is_empty():
		var level := ContentDB.get_level(StringName(level_id))
		if level != null:
			GameManager.selected_level = level
		else:
			push_warning("Boot: unknown --level=%s" % level_id)


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Palette.BG_DEEP)
	var center := s * 0.5
	Draw2D.glow_circle(self, center, 90.0, Palette.ACCENT, 4)
