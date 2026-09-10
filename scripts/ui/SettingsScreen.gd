extends MenuScreen
## Sound, music, vibration, quality and control preferences. Everything written
## here goes straight into the JSON profile.


func get_screen_title() -> String:
	return "SETTINGS"


func _build_content() -> void:
	body.add_child(_make_slider("Music", "music_volume"))
	body.add_child(_make_slider("Sound effects", "sfx_volume"))
	body.add_child(_make_check("Vibration", "vibration"))
	body.add_child(_make_check("Damage numbers", "show_damage_numbers"))
	body.add_child(_make_check("Stick follows thumb", "joystick_dynamic"))
	body.add_child(_make_option("Stick side", "joystick_side", ["Left", "Right"]))
	body.add_child(_make_option("Quality", "quality", ["Low", "Medium", "High"]))

	body.add_child(HSeparator.new())
	var reset_tutorial := UITheme.make_button("Replay tutorial", 92)
	reset_tutorial.pressed.connect(_on_reset_tutorial)
	body.add_child(reset_tutorial)

	var wipe := UITheme.make_button("Erase all progress", 92)
	wipe.add_theme_color_override("font_color", Palette.DANGER)
	wipe.pressed.connect(_on_wipe)
	body.add_child(wipe)

	add_back_button(GameManager.goto_main_menu)


func _make_row(label: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(UITheme.make_label(label, 30, Palette.TEXT))
	return box


func _make_slider(label: String, key: String) -> Control:
	var box := _make_row(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(SaveManager.get_setting(key, 0.8))
	slider.custom_minimum_size = Vector2(0, 60)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(_on_slider.bind(key))
	box.add_child(slider)
	return box


func _on_slider(value: float, key: String) -> void:
	SaveManager.set_setting(key, value)
	AudioManager.apply_settings()


func _make_check(label: String, key: String) -> Control:
	var check := CheckButton.new()
	check.text = label
	check.focus_mode = Control.FOCUS_NONE
	check.custom_minimum_size = Vector2(0, 70)
	check.button_pressed = bool(SaveManager.get_setting(key, true))
	check.toggled.connect(_on_check.bind(key))
	return check


func _on_check(pressed: bool, key: String) -> void:
	SaveManager.set_setting(key, pressed)
	if key == "show_damage_numbers" and EffectSpawner.instance != null:
		EffectSpawner.instance.set_show_numbers(pressed)
	AudioManager.play_sfx(&"ui_click")


func _make_option(label: String, key: String, choices: Array) -> Control:
	var box := _make_row(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var current := int(SaveManager.get_setting(key, 0))
	for i in choices.size():
		var button := UITheme.make_button(String(choices[i]), 80)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.modulate = Color.WHITE if i == current else Color(0.6, 0.64, 0.72)
		button.pressed.connect(_on_option.bind(key, i))
		row.add_child(button)
	return box


func _on_option(key: String, index: int) -> void:
	SaveManager.set_setting(key, index)
	if key == "quality":
		GameManager.set_quality(index)
	AudioManager.play_sfx(&"ui_click")
	_reload()


func _on_reset_tutorial() -> void:
	SaveManager.profile["tutorial_done"] = false
	SaveManager.mark_dirty()
	AudioManager.play_sfx(&"ui_confirm")


func _on_wipe() -> void:
	SaveManager.reset_profile()
	GameManager.selected_hero = null
	GameManager.selected_level = null
	GameManager.restore_last_selection()
	AudioManager.play_sfx(&"defeat")
	_reload()


func _reload() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/Settings.tscn")
