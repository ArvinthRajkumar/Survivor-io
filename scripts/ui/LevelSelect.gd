extends MenuScreen
## Sector list. Runs are endless; a sector unlocks the next one once you have
## survived past its milestone.


func get_screen_title() -> String:
	return "SECTORS"


func _build_content() -> void:
	_rebuild()
	add_back_button(GameManager.goto_main_menu)


func _rebuild() -> void:
	for child in body.get_children():
		child.queue_free()
	for level in ContentDB.level_list:
		body.add_child(_make_level_card(level))


func _make_level_card(level: LevelData) -> Button:
	var unlocked := level.unlocked_by_default or SaveManager.is_level_unlocked(level.id)
	var selected := GameManager.selected_level != null and GameManager.selected_level.id == level.id
	var accent := level.accent if unlocked else Color(0.35, 0.38, 0.45)
	var card := make_card(accent, 300)

	var note := ""
	if not unlocked:
		var required := ContentDB.get_level(level.required_level_id)
		note = "LOCKED - clear %s first" % (required.display_name if required != null else "the previous sector")
	elif selected:
		note = "SELECTED"
	else:
		note = "Tap to select"

	var text_box := fill_card(card, accent, 5, level.display_name,
		level.description if unlocked else "Signal lost.", note)

	if unlocked:
		var stats := HBoxContainer.new()
		stats.add_theme_constant_override("separation", 26)
		stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_box.add_child(stats)
		var best := SaveManager.get_best_time(level.id)
		stats.add_child(UITheme.make_label(
			"Unlock at %s" % MathUtil.format_time(level.unlock_time), 23, Palette.TEXT_DIM, false))
		stats.add_child(UITheme.make_label(
			"Best %s" % MathUtil.format_time(best), 23,
			Palette.GOLD if best >= level.unlock_time else Palette.TEXT_DIM, false))
		stats.add_child(UITheme.make_label(
			"Clears %d" % SaveManager.get_clear_count(level.id), 23, accent, false))

	if unlocked:
		card.pressed.connect(_on_select.bind(level))
	else:
		card.disabled = true
	return card


func _on_select(level: LevelData) -> void:
	AudioManager.play_sfx(&"ui_confirm")
	GameManager.select_level(level)
	_rebuild()
