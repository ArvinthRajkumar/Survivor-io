extends MenuScreen
## Title screen and hub.

func get_screen_title() -> String:
	return "LAST LIGHT"


func _build_content() -> void:
	title_label.add_theme_font_size_override("font_size", 64)

	var subtitle := UITheme.make_label("SWARMFALL", 34, Palette.ACCENT_WARM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.add_child(subtitle)

	GameManager.restore_last_selection()

	# An interrupted endless run takes priority over everything else on screen.
	if GameManager.has_resumable_run():
		body.add_child(_make_resume_card())
		var resume := UITheme.make_button("RESUME RUN", 130)
		resume.add_theme_font_size_override("font_size", 42)
		resume.add_theme_color_override("font_color", Palette.GOLD)
		resume.pressed.connect(_on_resume)
		body.add_child(resume)
		var discard := UITheme.make_button("Start a new run instead", 84)
		discard.add_theme_font_size_override("font_size", 26)
		discard.pressed.connect(_on_discard_and_deploy)
		body.add_child(discard)
	else:
		body.add_child(_make_summary())
		var deploy := UITheme.make_button("DEPLOY", 130)
		deploy.add_theme_font_size_override("font_size", 44)
		deploy.pressed.connect(_on_deploy)
		body.add_child(deploy)

	_add_nav("Operatives", GameManager.goto_hero_select)
	_add_nav("Sectors", GameManager.goto_level_select)
	_add_nav("Research Lab", GameManager.goto_meta)
	_add_nav("Settings", _on_settings)

	var stats := UITheme.make_label(_profile_line(), 24, Palette.TEXT_DIM)
	footer.add_child(stats)


func _make_summary() -> Control:
	var hero := GameManager.selected_hero
	var level := GameManager.selected_level
	var accent: Color = hero.accent if hero != null else Palette.ACCENT
	var card := make_card(accent, 190)
	card.disabled = true
	fill_card(card, accent, hero.portrait_shape if hero != null else 2,
		hero.display_name if hero != null else "No operative",
		level.display_name if level != null else "No sector",
		"Tap DEPLOY to start the run", true)
	return card


## Summarises the run waiting to be picked up, so "Resume" is an informed choice.
func _make_resume_card() -> Control:
	var saved := SaveManager.get_active_run()
	var hero := ContentDB.get_hero(StringName(saved.get("hero", "")))
	var level := ContentDB.get_level(StringName(saved.get("level", "")))
	var accent: Color = hero.accent if hero != null else Palette.GOLD
	var card := make_card(accent, 200)
	card.disabled = true
	var saved_loadout := saved.get("loadout", {}) as Dictionary
	# The katana is granted, so it never counts against the six.
	var slots := maxi(0, saved_loadout.size() - (1 if saved_loadout.has(String(PowerLoadout.INNATE_ID)) else 0))
	fill_card(card, accent, hero.portrait_shape if hero != null else 2,
		"Run in progress",
		"%s · %s" % [
			hero.display_name if hero != null else "Unknown operative",
			level.display_name if level != null else "Unknown sector"],
		"Survived %s · level %d · %d/%d slots used" % [
			MathUtil.format_time(float(saved.get("elapsed", 0.0))),
			int(saved.get("player_level", 1)), slots, PowerLoadout.MAX_SLOTS],
		true)
	return card


func _on_resume() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	if not GameManager.resume_run():
		# The save referred to content that no longer exists; fall back cleanly.
		GameManager.start_run()


func _on_discard_and_deploy() -> void:
	GameManager.discard_resumable_run()
	AudioManager.play_sfx(&"ui_click")
	get_tree().reload_current_scene()


func _add_nav(text: String, callback: Callable) -> void:
	var button := UITheme.make_button(text)
	button.pressed.connect(_on_nav.bind(callback))
	body.add_child(button)


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
	GameManager.start_run()


func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/Settings.tscn")
