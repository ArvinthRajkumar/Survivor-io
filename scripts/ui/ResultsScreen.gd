extends OverlayPanel
## End-of-run summary, including the rewards that were just banked to the profile.

signal retry_requested
signal menu_requested

var _title: Label
var _stats_box: VBoxContainer
var _reward_box: VBoxContainer


func _build_content() -> void:
	_title = UITheme.make_title("RUN OVER", UITheme.SIZE_SCREEN_TITLE, Palette.ACCENT)
	content.add_child(_title)

	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", UITheme.GAP_TIGHT)
	content.add_child(_stats_box)

	content.add_child(HSeparator.new())

	_reward_box = VBoxContainer.new()
	_reward_box.add_theme_constant_override("separation", UITheme.GAP_TIGHT)
	content.add_child(_reward_box)

	var retry := UITheme.make_button("Run Again")
	retry.pressed.connect(_on_retry)
	content.add_child(retry)

	var menu := UITheme.make_button("Main Menu", UITheme.SECONDARY_BUTTON_HEIGHT)
	menu.pressed.connect(_on_menu)
	content.add_child(menu)


func show_results(results: Dictionary) -> void:
	# Runs are endless, so there is no win state to report - the headline is how
	# long you lasted, and whether that beat the sector's unlock milestone.
	var cleared := bool(results.get("threshold_cleared", false))
	_title.text = "SECTOR CLEARED" if cleared else "OVERRUN"
	_title.add_theme_color_override("font_color", Palette.HEALTH if cleared else Palette.DANGER)

	for child in _stats_box.get_children():
		child.queue_free()
	for child in _reward_box.get_children():
		child.queue_free()

	add_stat_row(_stats_box, "Sector", String(results.get("level_name", "")))
	add_stat_row(_stats_box, "Operative", String(results.get("hero", "")))
	var survived := float(results.get("time", 0.0))
	var best := float(results.get("best_time", 0.0))
	add_stat_row(_stats_box, "Survived", MathUtil.format_time(survived),
		Palette.GOLD if survived >= best else Palette.TEXT)
	if best > 0.0:
		add_stat_row(_stats_box, "Personal best", MathUtil.format_time(maxf(best, survived)))
	var milestone := float(results.get("threshold_time", 0.0))
	if milestone > 0.0:
		add_stat_row(_stats_box, "Unlock milestone", MathUtil.format_time(milestone),
			Palette.HEALTH if cleared else Palette.TEXT_DIM)
	add_stat_row(_stats_box, "Level reached", str(int(results.get("level", 1))), Palette.ACCENT)
	add_stat_row(_stats_box, "Kills", MathUtil.format_number(int(results.get("kills", 0))))
	add_stat_row(_stats_box, "Elites felled", str(int(results.get("elite_kills", 0))))
	add_stat_row(_stats_box, "Bosses felled", str(int(results.get("boss_kills", 0))))
	add_stat_row(_stats_box, "Damage dealt", MathUtil.format_number(int(results.get("damage", 0.0))))

	_reward_box.add_child(UITheme.make_label("REWARDS", UITheme.SIZE_LABEL, Palette.TEXT_DIM))
	add_stat_row(_reward_box, "Credits",
		"+" + MathUtil.format_number(int(results.get("credits", 0))), Palette.GOLD)
	add_stat_row(_reward_box, "Research samples",
		"+" + str(int(results.get("research", 0))), Palette.RESEARCH)
	if cleared:
		add_stat_row(_reward_box, "Milestone bonus", "x1.4", Palette.ACCENT)
	if bool(results.get("first_clear", false)):
		add_stat_row(_reward_box, "First clear bonus", "x1.5", Palette.ACCENT)
	open()


func _on_retry() -> void:
	close()
	retry_requested.emit()


func _on_menu() -> void:
	close()
	menu_requested.emit()
