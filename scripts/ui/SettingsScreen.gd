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

	var wipe := UITheme.make_button("Erase all progress", UITheme.SECONDARY_BUTTON_HEIGHT)
	wipe.add_theme_color_override("font_color", Palette.DANGER)
	wipe.pressed.connect(_on_wipe)
	body.add_child(wipe)

	add_back_button(GameManager.goto_main_menu)


## Every setting is one panel of the same shape, whatever control it holds.
## Mixing bare sliders with framed toggles was what made this page look like it
## had been assembled from three different screens.
func _make_row(label: String) -> Array:
	var panel := UITheme.make_row_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UITheme.GAP_TIGHT + 4)
	panel.add_child(box)
	box.add_child(UITheme.make_label(label, UITheme.SIZE_BODY, Palette.TEXT, false))
	return [panel, box]


func _make_slider(label: String, key: String) -> Control:
	var row := _make_row(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(SaveManager.get_setting(key, 0.8))
	slider.custom_minimum_size = Vector2(0, 64)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(_on_slider.bind(key))
	(row[1] as VBoxContainer).add_child(slider)
	return row[0] as Control


func _on_slider(value: float, key: String) -> void:
	SaveManager.set_setting(key, value)
	AudioManager.apply_settings()


func _make_check(label: String, key: String) -> Control:
	return UITheme.make_toggle_row(label, bool(SaveManager.get_setting(key, true)),
		_on_check.bind(key))


func _on_check(pressed: bool, key: String) -> void:
	SaveManager.set_setting(key, pressed)
	if key == "show_damage_numbers" and EffectSpawner.instance != null:
		EffectSpawner.instance.set_show_numbers(pressed)
	AudioManager.play_sfx(&"ui_click")


func _make_option(label: String, key: String, choices: Array) -> Control:
	var row := _make_row(label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", UITheme.GAP_TIGHT + 2)
	(row[1] as VBoxContainer).add_child(buttons)
	var current := int(SaveManager.get_setting(key, 0))
	for i in choices.size():
		var button := UITheme.make_button(String(choices[i]), UITheme.SECONDARY_BUTTON_HEIGHT - 12)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", UITheme.SIZE_BODY)
		# The chosen side is filled in accent rather than merely brighter, so the
		# current value is readable at a glance instead of by comparison.
		if i == current:
			button.add_theme_stylebox_override("normal",
				UITheme.panel_box(Color(Palette.ACCENT.r * 0.24, Palette.ACCENT.g * 0.26,
					Palette.ACCENT.b * 0.32, 1.0), Palette.ACCENT))
			button.add_theme_color_override("font_color", Color.WHITE)
		else:
			button.add_theme_color_override("font_color", Palette.TEXT_DIM)
		button.pressed.connect(_on_option.bind(key, i))
		buttons.add_child(button)
	return row[0] as Control


func _on_option(key: String, index: int) -> void:
	SaveManager.set_setting(key, index)
	if key == "quality":
		GameManager.set_quality(index)
	AudioManager.play_sfx(&"ui_click")
	_reload()


func _on_wipe() -> void:
	SaveManager.reset_profile()
	GameManager.selected_hero = null
	GameManager.selected_level = null
	GameManager.restore_last_selection()
	AudioManager.play_sfx(&"defeat")
	_reload()


func _reload() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/Settings.tscn")
