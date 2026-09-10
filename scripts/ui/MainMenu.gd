extends MenuScreen
## Title screen and hub.
##
## The operative is shown live rather than as a portrait: MenuStage runs the
## same PlayerVisual the run uses, wearing the selected hero's colours and
## swinging their blade. That is the screen's centrepiece, so everything else is
## arranged to leave it room — the navigation is two-up rather than a stack of
## full-width buttons, and the run summary is a single line under the stage
## instead of the card it used to be.

var _stage: MenuStage


func get_screen_title() -> String:
	return "LAST LIGHT"


func get_screen_subtitle() -> String:
	return "SWARMFALL"


func _build_content() -> void:
	GameManager.restore_last_selection()

	_stage = MenuStage.new()
	_stage.custom_minimum_size = Vector2(0, 350)
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.set_hero(GameManager.selected_hero)
	body.add_child(_stage)
	body.add_child(_make_caption())

	# An interrupted endless run takes priority over everything else on screen.
	if GameManager.has_resumable_run():
		body.add_child(_make_resume_line())
		var resume := UITheme.make_button("RESUME RUN", 138)
		resume.add_theme_font_size_override("font_size", UITheme.SIZE_HEADING + 6)
		resume.add_theme_color_override("font_color", Palette.GOLD)
		resume.pressed.connect(_on_resume)
		body.add_child(resume)
		var discard := UITheme.make_button("Start a new run instead", UITheme.SECONDARY_BUTTON_HEIGHT)
		discard.add_theme_font_size_override("font_size", UITheme.SIZE_LABEL)
		discard.pressed.connect(_on_discard_and_deploy)
		body.add_child(discard)
	else:
		var deploy := UITheme.make_button("DEPLOY", 138)
		deploy.add_theme_font_size_override("font_size", UITheme.SIZE_HEADING + 8)
		deploy.pressed.connect(_on_deploy)
		body.add_child(deploy)

		var hardcore := UITheme.make_button("HARDCORE", UITheme.SECONDARY_BUTTON_HEIGHT)
		hardcore.add_theme_font_size_override("font_size", UITheme.SIZE_BODY)
		hardcore.add_theme_color_override("font_color", Palette.DANGER)
		hardcore.pressed.connect(_on_hardcore)
		body.add_child(hardcore)

	# Two per row. Four full-width buttons pushed the stage off the top of a
	# phone screen, and none of these is a primary action.
	body.add_child(_nav_row(
		["Operatives", GameManager.goto_hero_select],
		["Sectors", GameManager.goto_level_select]))
	body.add_child(_nav_row(
		["Research Lab", GameManager.goto_meta],
		["Settings", _on_settings]))

	# Longest single survival across every sector — the run's whole headline
	# stat is "how long did you last", so that is what belongs on the title
	# screen. Left off entirely on a blank profile rather than showing 00:00.
	var best := SaveManager.get_best_time_overall()
	if best > 0.0:
		var best_label := UITheme.make_label(
			"Best survival: %s" % MathUtil.format_time(best), UITheme.SIZE_BODY, Palette.GOLD, false)
		best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		footer.add_child(best_label)

	var stats := UITheme.make_label(_profile_line(), UITheme.SIZE_SMALL, Palette.TEXT_DIM, false)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(stats)


## Who is on the stage and where they are being sent, in one line under it.
func _make_caption() -> Control:
	var hero := GameManager.selected_hero
	var level := GameManager.selected_level
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var name_label := UITheme.make_title(
		hero.display_name if hero != null else "No operative",
		UITheme.SIZE_TITLE, hero.accent if hero != null else Palette.ACCENT)
	box.add_child(name_label)

	var where := UITheme.make_label("%s · %s" % [
		hero.role if hero != null and not hero.role.is_empty() else "Operative",
		level.display_name if level != null else "No sector",
	], UITheme.SIZE_LABEL, Palette.TEXT_DIM, false)
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(where)
	return box


## Summarises the run waiting to be picked up, so "Resume" is an informed choice.
func _make_resume_line() -> Control:
	var saved := SaveManager.get_active_run()
	var level := ContentDB.get_level(StringName(saved.get("level", "")))
	var saved_loadout := saved.get("loadout", {}) as Dictionary
	# The starting weapon is granted, so it never counts against the six.
	var weapon := String(saved.get("weapon", PowerLoadout.DEFAULT_WEAPON))
	var slots := maxi(0, saved_loadout.size() - (1 if saved_loadout.has(weapon) else 0))
	var text := "Run in progress · %s · survived %s · level %d · %d/%d slots" % [
		level.display_name if level != null else "Unknown sector",
		MathUtil.format_time(float(saved.get("elapsed", 0.0))),
		int(saved.get("player_level", 1)), slots, PowerLoadout.MAX_SLOTS,
	]
	var label := UITheme.make_label(text, UITheme.SIZE_SMALL, Palette.GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _nav_row(left: Array, right: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.GAP_TIGHT + 4)
	for entry in [left, right]:
		var button := UITheme.make_button(String(entry[0]), UITheme.SECONDARY_BUTTON_HEIGHT)
		button.add_theme_font_size_override("font_size", UITheme.SIZE_BODY)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_nav.bind(entry[1] as Callable))
		row.add_child(button)
	return row


func _on_resume() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	if not GameManager.resume_run():
		# The save referred to content that no longer exists; fall back cleanly.
		GameManager.start_run()


func _on_discard_and_deploy() -> void:
	GameManager.discard_resumable_run()
	AudioManager.play_sfx(&"ui_click")
	get_tree().reload_current_scene()


func _on_nav(callback: Callable) -> void:
	AudioManager.play_sfx(&"ui_click")
	callback.call()


func _profile_line() -> String:
	var profile := SaveManager.profile
	return "Runs %d    Kills %s    Heroes %d/%d" % [
		int(profile.get("total_runs", 0)),
		MathUtil.format_number(int(profile.get("total_kills", 0))),
		(profile.get("unlocked_heroes", []) as Array).size(),
		ContentDB.hero_list.size(),
	]


func _on_deploy() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	GameManager.goto_weapon_select()


func _on_hardcore() -> void:
	AudioManager.play_sfx(&"ui_click")
	GameManager.goto_hardcore_select()


func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/Settings.tscn")
