extends OverlayPanel
## In-run pause dialog: resume, quick audio toggles and abandon.

signal resume_requested
signal quit_requested

var _stats_box: VBoxContainer


func _build_content() -> void:
	content.add_child(UITheme.make_title("PAUSED", 56, Palette.ACCENT))

	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 8)
	content.add_child(_stats_box)

	var resume := UITheme.make_button("Resume")
	resume.pressed.connect(_on_resume)
	content.add_child(resume)

	content.add_child(_make_toggle("Music", "music_volume"))
	content.add_child(_make_toggle("Sound", "sfx_volume"))

	var quit := UITheme.make_button("Abandon Run", 92)
	quit.add_theme_color_override("font_color", Palette.DANGER)
	quit.pressed.connect(_on_quit)
	content.add_child(quit)


## Volume toggles here are binary; the full sliders live in the settings screen.
func _make_toggle(label: String, key: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = label
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.button_pressed = float(SaveManager.get_setting(key, 0.8)) > 0.01
	toggle.toggled.connect(_on_toggle.bind(key))
	return toggle


func _on_toggle(pressed: bool, key: String) -> void:
	SaveManager.set_setting(key, 0.8 if pressed else 0.0)
	AudioManager.apply_settings()


func open() -> void:
	_refresh_stats()
	super.open()


func _refresh_stats() -> void:
	for child in _stats_box.get_children():
		child.queue_free()
	add_stat_row(_stats_box, "Time survived", MathUtil.format_time(RunManager.elapsed))
	add_stat_row(_stats_box, "Kills", MathUtil.format_number(RunManager.kills))
	add_stat_row(_stats_box, "Level", str(RunManager.player_level), Palette.ACCENT)


func _on_resume() -> void:
	close()
	AudioManager.play_sfx(&"ui_click")
	resume_requested.emit()


func _on_quit() -> void:
	close()
	quit_requested.emit()
