extends Control
## In-run heads-up display.
##
## Built in code rather than authored as a deep node tree, because almost every
## element is data-driven (six slots, a variable boss bar, a tooltip that follows
## whichever slot is hovered) and the layout is easier to reason about in one
## place.
##
## Layout, top to bottom: a status panel with the level badge, run clock and
## milestone bar; the boss banner; the floating log; then the bottom console with
## the health bar, two labelled slot rows and the ultimate button. The rows keep
## the two upgrade categories visually grouped instead of interleaved in pick
## order: Powers (the innate katana first, then any chosen Powers) on top,
## Passives below. Everything is one thumb's reach from the bottom of a phone
## screen.

signal pause_pressed
signal joystick_moved(direction: Vector2)

const LOG_LIFETIME := 2.6
const MAX_LOG_LINES := 3
const SLOT_SIZE := Vector2(88, 88)

@onready var joystick: TouchJoystick = $Joystick

var player: Player
var level: LevelData

var _status_panel: Control
var _level_badge: Control
var _timer_label: Label
var _kills_label: Label
var _milestone: Control
var _xp_ratio: float = 0.0
var _level_value: int = 1
var _milestone_ratio: float = 0.0

var _boss_panel: Control
var _boss_name: Label
var _boss_ratio: float = 1.0
var _boss: Boss

var _health_ratio: float = 1.0
var _health_ghost: float = 1.0
var _health_label: Label
var _health_bar: Control

## The two rows, each in pick order. Slot 0 of _power_slots is always the
## innate katana. Kept separate so rebuilding can route an owned id to the
## right row by category, but the two are iterated together (see _all_slots())
## wherever a piece of code genuinely does not care which row a slot is in.
var _power_slots: Array[PowerSlot] = []
var _passive_slots: Array[PowerSlot] = []
var _tooltip: PanelContainer
var _tooltip_title: Label
var _tooltip_body: Label
var _tooltip_target: PowerSlot

var _ultimate_button: Button
var _ultimate_ring: Control
var _ultimate_ratio: float = 0.0

var _log_box: VBoxContainer
var _log_times: Array[float] = []
var _warning: Label
var _warning_time: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	# Same CanvasLayer caveat as the dialogs: without this the HUD would fall
	# back to Godot's default font sizes instead of the app's type scale.
	theme = UITheme.shared()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	joystick.moved.connect(_on_joystick_moved)
	_apply_joystick_side()
	_build()

	RunManager.time_changed.connect(_on_time_changed)
	RunManager.xp_changed.connect(_on_xp_changed)
	RunManager.kills_changed.connect(_on_kills_changed)
	RunManager.loadout.changed.connect(_rebuild_slots)


func bind(bound_player: Player, level_data: LevelData) -> void:
	player = bound_player
	level = level_data
	player.health_changed.connect(_on_health_changed)
	player.ultimate.charge_changed.connect(_on_ultimate_charge)
	_on_health_changed(player.health.current_health, player.health.max_health)
	_health_ghost = _health_ratio
	_on_time_changed(RunManager.elapsed)
	_on_xp_changed(RunManager.xp_current, RunManager.xp_needed, RunManager.player_level)
	_on_kills_changed(RunManager.kills)
	_rebuild_slots()


func _apply_joystick_side() -> void:
	joystick.fixed_position = Vector2(840, 1430) if int(SaveManager.get_setting("joystick_side", 0)) == 1 else Vector2(240, 1430)


# --- Construction -----------------------------------------------------------

func _build() -> void:
	_build_status()
	_build_boss_banner()
	_build_log()
	_build_warning()
	_build_console()
	_build_tooltip()


func _panel(bg: Color = Palette.BG_PANEL, border: Color = Color(0.24, 0.36, 0.52, 0.55)) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_box(bg, border, 20, 2))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _build_status() -> void:
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.05, 0.07, 0.12, 0.82), Color(0.26, 0.40, 0.58, 0.5), 24, 2))
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	holder.offset_left = 22
	holder.offset_right = -22
	holder.offset_top = 26
	holder.offset_bottom = 200
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_status_panel = holder

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(column)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)

	_level_badge = Control.new()
	_level_badge.custom_minimum_size = Vector2(74, 74)
	_level_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_badge.draw.connect(_draw_level_badge)
	row.add_child(_level_badge)

	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 0)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(middle)

	_timer_label = UITheme.make_label("00:00", 52, Palette.TEXT, false)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	middle.add_child(_timer_label)

	_kills_label = UITheme.make_label("0 kills", 24, Palette.TEXT_DIM, false)
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	middle.add_child(_kills_label)

	var pause := Button.new()
	pause.custom_minimum_size = Vector2(74, 74)
	pause.focus_mode = Control.FOCUS_NONE
	pause.text = "II"
	pause.add_theme_font_size_override("font_size", 30)
	pause.pressed.connect(func() -> void: pause_pressed.emit())
	row.add_child(pause)

	# XP bar plus the survival-milestone marker, drawn together so the two
	# progress ideas never fight for space.
	_milestone = Control.new()
	_milestone.custom_minimum_size = Vector2(0, 30)
	_milestone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_milestone.draw.connect(_draw_progress)
	column.add_child(_milestone)


func _build_boss_banner() -> void:
	_boss_panel = PanelContainer.new()
	(_boss_panel as PanelContainer).add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.16, 0.04, 0.07, 0.85), Color(1.0, 0.32, 0.38, 0.7), 16, 2))
	_boss_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_boss_panel.offset_left = 60
	_boss_panel.offset_right = -60
	_boss_panel.offset_top = 214
	_boss_panel.offset_bottom = 306
	_boss_panel.visible = false
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.add_child(column)

	_boss_name = UITheme.make_label("BOSS", 26, Color(1.0, 0.72, 0.75), false)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_boss_name)

	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 22)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(_draw_boss_bar.bind(bar))
	column.add_child(bar)


func _build_log() -> void:
	_log_box = VBoxContainer.new()
	_log_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_log_box.offset_left = -420
	_log_box.offset_right = 420
	_log_box.offset_top = 360
	_log_box.offset_bottom = 520
	_log_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_log_box.add_theme_constant_override("separation", 6)
	_log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_log_box)


func _build_warning() -> void:
	_warning = UITheme.make_label("WARNING", 68, Palette.DANGER, false)
	_warning.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_warning.offset_left = -420
	_warning.offset_right = 420
	_warning.offset_top = -180
	_warning.offset_bottom = -80
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_warning.pivot_offset = Vector2(420, 50)
	_warning.visible = false
	_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_warning)


func _build_console() -> void:
	var console := PanelContainer.new()
	console.add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.05, 0.07, 0.12, 0.88), Color(0.26, 0.40, 0.58, 0.5), 26, 2))
	console.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	console.offset_left = 18
	console.offset_right = -18
	console.offset_top = -340
	console.offset_bottom = -22
	console.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(console)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	console.add_child(column)

	_health_bar = Control.new()
	_health_bar.custom_minimum_size = Vector2(0, 34)
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar.draw.connect(_draw_health)
	column.add_child(_health_bar)

	_health_label = UITheme.make_label("", 22, Palette.TEXT, false)
	_health_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar.add_child(_health_label)

	# Each row's socket count is however many of that category could ever be
	# owned at once — capped by the six-slot budget, but also by how many of
	# that category actually exist in content, so the Passives row (only five
	# exist) is not stretched out with sockets nothing could ever fill.
	var power_capacity := 1 + mini(PowerLoadout.MAX_SLOTS,
		maxi(0, ContentDB.active_power_list.size() - 1))
	var passive_capacity := mini(PowerLoadout.MAX_SLOTS, ContentDB.passive_list.size())
	_power_slots = _build_slot_row(column, "POWERS", power_capacity, true)
	_passive_slots = _build_slot_row(column, "PASSIVES", passive_capacity, false)

	_build_ultimate()


## One labelled row of sockets. `innate_first` marks slot 0 as the katana,
## which only the Powers row ever has.
func _build_slot_row(column: VBoxContainer, title: String, capacity: int,
		innate_first: bool) -> Array[PowerSlot]:
	var label := UITheme.make_label(title, 18, Palette.TEXT_DIM, false)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(row)

	var slots: Array[PowerSlot] = []
	for i in capacity:
		var slot := PowerSlot.new()
		slot.slot_index = i
		slot.innate = innate_first and i == 0
		slot.custom_minimum_size = SLOT_SIZE
		# Fixed, not expanding: stretched sockets stop being square and the
		# artwork inside them starts to look stretched with them.
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.hover_changed.connect(_on_slot_hover)
		row.add_child(slot)
		slots.append(slot)
	return slots


## The two rows concatenated, for the handful of places (the per-frame charge
## sweep) that genuinely want every slot regardless of category.
func _all_slots() -> Array[PowerSlot]:
	var out: Array[PowerSlot] = []
	out.append_array(_power_slots)
	out.append_array(_passive_slots)
	return out


func _build_ultimate() -> void:
	_ultimate_button = Button.new()
	_ultimate_button.custom_minimum_size = Vector2(150, 150)
	_ultimate_button.focus_mode = Control.FOCUS_NONE
	_ultimate_button.text = ""
	_ultimate_button.flat = true
	_ultimate_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_ultimate_button.offset_left = -186
	_ultimate_button.offset_right = -36
	# Floats clear above the console, which is now two slot rows tall.
	_ultimate_button.offset_top = -520
	_ultimate_button.offset_bottom = -370
	_ultimate_button.pressed.connect(_on_ultimate_pressed)
	add_child(_ultimate_button)

	_ultimate_ring = Control.new()
	_ultimate_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ultimate_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ultimate_ring.draw.connect(_draw_ultimate)
	_ultimate_button.add_child(_ultimate_ring)


func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.06, 0.09, 0.15, 0.97), Palette.ACCENT, 14, 2))
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.top_level = true
	add_child(_tooltip)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(column)

	_tooltip_title = UITheme.make_label("", 26, Palette.TEXT, false)
	column.add_child(_tooltip_title)
	_tooltip_body = UITheme.make_label("", 22, Palette.TEXT_DIM)
	_tooltip_body.custom_minimum_size = Vector2(360, 0)
	column.add_child(_tooltip_body)


# --- Slots and tooltip ------------------------------------------------------

func _rebuild_slots() -> void:
	# Katana first (get_ordered_ids() guarantees that), then split by category
	# so each row only ever shows its own kind, in the order it was picked.
	var power_ids: Array = []
	var passive_ids: Array = []
	for id in RunManager.loadout.get_ordered_ids():
		var data := ContentDB.get_power(id)
		if data == null:
			continue
		if data.is_passive():
			passive_ids.append(id)
		else:
			power_ids.append(id)
	_fill_row(_power_slots, power_ids)
	_fill_row(_passive_slots, passive_ids)
	if _tooltip_target != null and not _tooltip_target.is_filled():
		_hide_tooltip()


func _fill_row(slots: Array[PowerSlot], ids: Array) -> void:
	for i in slots.size():
		if i < ids.size():
			var id: StringName = ids[i]
			slots[i].set_entry(ContentDB.get_power(id), RunManager.loadout.get_level(id))
		else:
			slots[i].clear_entry()


func _on_slot_hover(slot: PowerSlot, hovered: bool) -> void:
	if not hovered:
		if _tooltip_target == slot:
			_hide_tooltip()
		return
	if not slot.is_filled():
		_hide_tooltip()
		return
	_tooltip_target = slot
	var prefix := "◆ " if slot.innate else ""
	_tooltip_title.text = "%s%s  ·  Lv %d/%d" % [
		prefix, slot.data.display_name, slot.level, slot.data.max_level]
	_tooltip_body.text = slot.tooltip_line()
	_tooltip.visible = true
	_tooltip.reset_size()
	# Anchor above the slot, clamped so it never runs off either edge.
	var slot_rect := Rect2(slot.global_position, slot.size)
	var tip_size := _tooltip.size
	var x := slot_rect.get_center().x - tip_size.x * 0.5
	x = clampf(x, 20.0, size.x - tip_size.x - 20.0)
	_tooltip.global_position = Vector2(x, slot_rect.position.y - tip_size.y - 14.0)


func _hide_tooltip() -> void:
	_tooltip_target = null
	_tooltip.visible = false


# --- Signals ----------------------------------------------------------------

func _on_time_changed(elapsed: float) -> void:
	_timer_label.text = MathUtil.format_time(elapsed)
	_milestone_ratio = RunManager.threshold_progress()


func _on_kills_changed(kills: int) -> void:
	_kills_label.text = "%s kills" % MathUtil.format_number(kills)


func _on_xp_changed(current: int, needed: int, player_level: int) -> void:
	_xp_ratio = clampf(float(current) / maxf(1.0, float(needed)), 0.0, 1.0)
	_level_value = player_level
	if _level_badge != null:
		_level_badge.queue_redraw()


func _on_health_changed(current: float, maximum: float) -> void:
	_health_ratio = clampf(current / maxf(1.0, maximum), 0.0, 1.0)
	_health_label.text = "%d / %d" % [int(ceil(current)), int(ceil(maximum))]


func _on_ultimate_charge(ratio: float) -> void:
	_ultimate_ratio = ratio


func _on_ultimate_pressed() -> void:
	if player != null and is_instance_valid(player):
		player.ultimate.activate()


func _on_joystick_moved(direction: Vector2) -> void:
	joystick_moved.emit(direction)


## Drops any touch the stick is holding. Called when a dialog takes over: the
## finger that was steering never delivers its release once the tree pauses, and
## a stick still holding that touch both keeps steering and can swallow the next
## tap meant for the dialog.
func cancel_touch() -> void:
	if joystick != null and is_instance_valid(joystick):
		joystick.cancel()


# --- Boss -------------------------------------------------------------------

func show_boss_warning(title: String) -> void:
	_warning.text = title if not title.is_empty() else "WARNING"
	_warning.visible = true
	_warning_time = 3.0


func bind_boss(boss: Boss) -> void:
	_boss = boss
	_boss_panel.visible = true
	_boss_name.text = boss.data.display_name.to_upper()
	_boss_ratio = 1.0
	if not boss.boss_health_changed.is_connected(_on_boss_health):
		boss.boss_health_changed.connect(_on_boss_health)


func _on_boss_health(ratio: float) -> void:
	_boss_ratio = ratio


func clear_boss() -> void:
	if _boss != null and is_instance_valid(_boss):
		if _boss.boss_health_changed.is_connected(_on_boss_health):
			_boss.boss_health_changed.disconnect(_on_boss_health)
	_boss = null
	_boss_panel.visible = false


# --- Log --------------------------------------------------------------------

func push_log(text: String) -> void:
	if text.is_empty():
		return
	var label := UITheme.make_label(text, 30, Palette.ACCENT, false)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_log_box.add_child(label)
	_log_times.append(LOG_LIFETIME)
	while _log_box.get_child_count() > MAX_LOG_LINES:
		_log_box.get_child(0).queue_free()
		_log_times.pop_front()


func _expire_log(delta: float) -> void:
	var i := 0
	while i < _log_times.size():
		_log_times[i] -= delta
		var child: Node = _log_box.get_child(i) if i < _log_box.get_child_count() else null
		if child != null:
			(child as Control).modulate.a = clampf(_log_times[i], 0.0, 1.0)
		if _log_times[i] <= 0.0:
			if child != null:
				child.queue_free()
			_log_times.remove_at(i)
			continue
		i += 1


# --- Frame ------------------------------------------------------------------

func _process(delta: float) -> void:
	_phase += delta
	# Health drains toward the true value so a big hit reads as a visible chunk.
	_health_ghost = move_toward(_health_ghost, _health_ratio, delta * 0.55)
	if _health_ghost < _health_ratio:
		_health_ghost = _health_ratio

	if _warning_time > 0.0:
		_warning_time -= delta
		_warning.modulate.a = clampf(_warning_time, 0.0, 1.0)
		_warning.scale = Vector2.ONE * (1.0 + 0.05 * sin(_warning_time * 12.0))
		if _warning_time <= 0.0:
			_warning.visible = false

	if _boss != null and (not is_instance_valid(_boss) or not _boss.alive):
		clear_boss()

	if player != null and is_instance_valid(player):
		for slot in _all_slots():
			if slot.is_filled() and slot.data.is_power():
				slot.set_charge(player.powers.get_charge_ratio(slot.data.id))

	if _tooltip_target != null and _tooltip.visible:
		_tooltip.modulate.a = minf(1.0, _tooltip.modulate.a + delta * 6.0)

	_expire_log(delta)
	_milestone.queue_redraw()
	_health_bar.queue_redraw()
	_ultimate_ring.queue_redraw()
	if _boss_panel.visible:
		_boss_panel.get_child(0).get_child(1).queue_redraw()


# --- Custom drawing ---------------------------------------------------------

## Circular level badge with an XP ring around it.
func _draw_level_badge() -> void:
	var ci := _level_badge
	var c := ci.size * 0.5
	var r := minf(c.x, c.y) - 4.0
	ci.draw_circle(c, r, Color(0.08, 0.12, 0.20, 0.95))
	ci.draw_arc(c, r - 3.0, 0.0, TAU, 28, Color(1, 1, 1, 0.10), 5.0, true)
	if _xp_ratio > 0.0:
		ci.draw_arc(c, r - 3.0, -PI * 0.5, -PI * 0.5 + TAU * _xp_ratio, 32, Palette.XP, 5.0, true)
	var font := ThemeDB.fallback_font
	if font != null:
		var text := str(_level_value)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30).x
		ci.draw_string(font, c + Vector2(-w * 0.5, 8.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30, Palette.TEXT)
		var cap := "LV"
		var cw := font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15).x
		ci.draw_string(font, c + Vector2(-cw * 0.5, -12.0), cap,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Palette.TEXT_DIM)


## XP bar with the sector milestone marked on it, so both "how close is my next
## upgrade" and "how close is the unlock" are answered by one strip.
func _draw_progress() -> void:
	var ci := _milestone
	var w := ci.size.x
	var bar := Rect2(Vector2(0.0, 4.0), Vector2(w, 14.0))
	ci.draw_rect(bar, Color(0.05, 0.07, 0.12, 0.9))
	ci.draw_rect(Rect2(bar.position, Vector2(w * _xp_ratio, bar.size.y)), Palette.XP)
	ci.draw_rect(bar, Color(1, 1, 1, 0.08), false, 1.0)

	var track := Rect2(Vector2(0.0, 22.0), Vector2(w, 5.0))
	ci.draw_rect(track, Color(1, 1, 1, 0.08))
	var done := _milestone_ratio >= 1.0
	var color := Palette.HEALTH if done else Palette.ACCENT_WARM
	ci.draw_rect(Rect2(track.position, Vector2(w * _milestone_ratio, track.size.y)), color)
	# Flag at the milestone end.
	var flag := Vector2(w - 2.0, 24.5)
	ci.draw_circle(flag, 5.0, color)
	if done:
		ci.draw_circle(flag, 8.0 + 2.0 * sin(_phase * 4.0), Color(color.r, color.g, color.b, 0.35))


func _draw_health() -> void:
	var ci := _health_bar
	var w := ci.size.x
	var h := ci.size.y
	var bar := Rect2(Vector2.ZERO, Vector2(w, h))
	ci.draw_rect(bar, Color(0.05, 0.07, 0.12, 0.95))
	# Ghost fill shows what was just lost before it catches up.
	ci.draw_rect(Rect2(Vector2.ZERO, Vector2(w * _health_ghost, h)), Color(1.0, 0.45, 0.5, 0.45))
	var color := Palette.HEALTH if _health_ratio > 0.35 else Palette.DANGER
	if _health_ratio <= 0.2:
		color = color.lerp(Color.WHITE, 0.35 * absf(sin(_phase * 7.0)))
	ci.draw_rect(Rect2(Vector2.ZERO, Vector2(w * _health_ratio, h)), color)
	# Tick marks every 25% give the bar a readable scale.
	for i in range(1, 4):
		var x := w * 0.25 * float(i)
		ci.draw_line(Vector2(x, 2.0), Vector2(x, h - 2.0), Color(0, 0, 0, 0.30), 2.0)
	ci.draw_rect(bar, Color(1, 1, 1, 0.10), false, 1.0)


func _draw_boss_bar(bar: Control) -> void:
	var w := bar.size.x
	var h := bar.size.y
	bar.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.10, 0.03, 0.05, 0.95))
	bar.draw_rect(Rect2(Vector2.ZERO, Vector2(w * _boss_ratio, h)), Color(1.0, 0.32, 0.38))
	# Segment ticks so chunks of boss health are countable at a glance.
	for i in range(1, 8):
		var x := w * float(i) / 8.0
		bar.draw_line(Vector2(x, 0.0), Vector2(x, h), Color(0, 0, 0, 0.35), 2.0)
	bar.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(1, 1, 1, 0.12), false, 1.0)


func _draw_ultimate() -> void:
	var ci := _ultimate_ring
	var c := ci.size * 0.5
	var r := minf(c.x, c.y) - 6.0
	var ready := _ultimate_ratio >= 1.0
	var accent := player.hero.accent if (player != null and player.hero != null) else Palette.ACCENT

	ci.draw_circle(c, r, Color(0.06, 0.09, 0.15, 0.9))
	ci.draw_arc(c, r - 4.0, 0.0, TAU, 32, Color(1, 1, 1, 0.10), 7.0, true)
	var ring_color := accent if not ready else Color(1.0, 0.86, 0.35)
	ci.draw_arc(c, r - 4.0, -PI * 0.5, -PI * 0.5 + TAU * _ultimate_ratio, 40, ring_color, 7.0, true)
	if ready:
		var pulse := 0.45 + 0.35 * absf(sin(_phase * 4.0))
		ci.draw_circle(c, r * 0.78, Color(ring_color.r, ring_color.g, ring_color.b, 0.18 * pulse))
		ci.draw_arc(c, r + 3.0 * pulse, 0.0, TAU, 32,
			Color(ring_color.r, ring_color.g, ring_color.b, 0.5 * pulse), 3.0, true)

	# A small starburst glyph rather than the word "ULT".
	var glyph := Draw2D.star_points(6, r * 0.42, r * 0.16, _phase * (1.2 if ready else 0.25))
	var pts := PackedVector2Array()
	for p in glyph:
		pts.append(p + c)
	ci.draw_colored_polygon(pts, Color(ring_color.r, ring_color.g, ring_color.b, 0.95 if ready else 0.5))
