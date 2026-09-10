extends MenuScreen
## Hardcore: build the whole loadout before the run, then survive it.
##
## An ordinary run is a sequence of choices made under pressure, most of them
## with incomplete information. This mode removes that entirely — every weapon,
## power and passive is on the table from the start and everything picked is
## granted at its final level — and puts the difficulty in the only place left:
## the swarm. A Hardcore run opens at the pressure a normal one reaches six
## minutes in, with enemies that hit harder and take more killing.
##
## The six-slot budget still applies. It is the rule the whole upgrade system is
## built around, and lifting it here would not make the mode harder, only
## louder: thirty-two maxed powers firing at once is unreadable on a phone.

var _picks: Array[StringName] = []
var _weapon_id: StringName = &""
var _cards: Dictionary = {}          # StringName -> Button
var _deploy: Button
var _counter: Label


func get_screen_title() -> String:
	return "HARDCORE"


func get_screen_subtitle() -> String:
	return "BUILD IT ALL, THEN SURVIVE IT"


func _build_content() -> void:
	GameManager.restore_last_selection()
	_weapon_id = GameManager.selected_weapon_id
	if ContentDB.get_power(_weapon_id) == null:
		_weapon_id = ContentDB.weapon_list[0].id if not ContentDB.weapon_list.is_empty() else &""

	body.add_child(_make_warning())

	body.add_child(_section("WEAPON"))
	for weapon in ContentDB.weapon_list:
		body.add_child(_make_entry(weapon, true))

	_counter = UITheme.make_label("", UITheme.SIZE_LABEL, Palette.ACCENT_WARM, false)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	body.add_child(_section("POWERS"))
	for data in ContentDB.active_power_list:
		body.add_child(_make_entry(data, false))

	body.add_child(_section("PASSIVES"))
	for data in ContentDB.passive_list:
		body.add_child(_make_entry(data, false))

	footer.add_child(_counter)
	_deploy = UITheme.make_button("DEPLOY", 132)
	_deploy.add_theme_color_override("font_color", Palette.DANGER)
	_deploy.pressed.connect(_on_deploy)
	footer.add_child(_deploy)
	add_back_button(GameManager.goto_main_menu)
	_refresh()


func _make_warning() -> Control:
	var panel := UITheme.make_row_panel()
	var text := UITheme.make_label(
		"Everything you pick starts at max level. So does the swarm: this run "
		+ "opens at six-minute pressure, with tougher enemies that hit harder.",
		UITheme.SIZE_SMALL, Palette.ACCENT_WARM)
	panel.add_child(text)
	return panel


func _section(title: String) -> Control:
	var label := UITheme.make_title(title, UITheme.SIZE_HEADING, Palette.ACCENT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _make_entry(data: PowerData, is_weapon: bool) -> Control:
	var card := make_card(data.color, 176)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20
	row.offset_right = -20
	row.offset_top = 12
	row.offset_bottom = -12
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var art := PowerCardArt.new()
	art.art_id = data.art_id()
	art.color = data.color
	art.color_secondary = data.color_secondary
	art.level = data.max_level
	art.max_level = data.max_level
	art.custom_minimum_size = Vector2(104, 104)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 4)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	text.add_child(UITheme.make_label(data.display_name, UITheme.SIZE_BODY, Palette.TEXT, false))
	var note := UITheme.make_label(data.tooltip, UITheme.SIZE_SMALL, Palette.TEXT_DIM)
	note.max_lines_visible = 2
	note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	note.custom_minimum_size = Vector2(0, UITheme.SIZE_SMALL * 2.4)
	text.add_child(note)

	if is_weapon:
		card.pressed.connect(_on_weapon.bind(data.id))
	else:
		card.pressed.connect(_on_toggle.bind(data.id))
	_cards[data.id] = card
	return card


func _on_weapon(id: StringName) -> void:
	_weapon_id = id
	AudioManager.play_sfx(&"ui_click")
	_refresh()


func _on_toggle(id: StringName) -> void:
	if _picks.has(id):
		_picks.erase(id)
	elif _picks.size() < PowerLoadout.MAX_SLOTS:
		_picks.append(id)
	else:
		# Full. Saying so beats a tap that silently does nothing.
		AudioManager.play_sfx(&"hurt", 0.0, -18.0)
		_counter.text = "All %d slots are taken — drop one first" % PowerLoadout.MAX_SLOTS
		return
	AudioManager.play_sfx(&"ui_click")
	_refresh()


## Selection is shown by brightness rather than by a tick, so a card that is in
## the loadout is legible at a glance while scrolling past thirty of them.
func _refresh() -> void:
	for id in _cards:
		var card: Button = _cards[id]
		var chosen: bool = id == _weapon_id or _picks.has(id)
		card.modulate = Color.WHITE if chosen else Color(0.52, 0.55, 0.62)
	_counter.text = "%d of %d slots filled" % [_picks.size(), PowerLoadout.MAX_SLOTS]
	_deploy.disabled = ContentDB.get_power(_weapon_id) == null


func _on_deploy() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	GameManager.selected_weapon_id = _weapon_id
	GameManager.hardcore_mode = true
	GameManager.hardcore_picks = _picks.duplicate()
	GameManager.start_run()
