class_name OverlayPanel
extends Control
## Shared scaffolding for the full-screen dialogs shown during a run
## (pause, revive, results). Subclasses fill in `content` and react to open/close.

var dim: ColorRect
var panel: PanelContainer
var content: VBoxContainer

var _panel_row: HBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# These dialogs hang off a CanvasLayer, which does not pass the window root's
	# theme down to them.
	theme = UITheme.shared()
	# Internal process rather than _process: a subclass that needs its own
	# _process (the revive countdown does) would otherwise silently replace this
	# one, and the panel would be laid out at zero size. That is not a mistake a
	# subclass author should have to remember not to make.
	set_process_internal(true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_frame()
	_build_content()


func _build_frame() -> void:
	dim = ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := MarginContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("margin_left", 36)
	center.add_theme_constant_override("margin_right", 36)
	center.add_theme_constant_override("margin_top", 90)
	center.add_theme_constant_override("margin_bottom", 90)
	add_child(center)

	# Centred horizontally inside the shared maximum width, and vertically
	# centred only while it fits — a panel taller than the screen scrolls
	# instead of pushing its own buttons out of reach.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(row)

	panel = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(panel)
	_panel_row = row

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	_scroll = scroll

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", UITheme.GAP_SECTION)
	scroll.add_child(content)


## Subclasses build their widgets here.
func _build_content() -> void:
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_INTERNAL_PROCESS:
		_update_layout()


func _update_layout() -> void:
	if not visible or _panel_row == null:
		return
	var available := size.x - 72.0
	panel.custom_minimum_size.x = minf(available, float(UITheme.CONTENT_MAX_WIDTH))
	if _scroll != null and content != null:
		# Shrink-wrap the scroll box to its content so a short dialog stays a
		# short dialog, and only a genuinely tall one starts scrolling.
		var wanted := content.get_combined_minimum_size().y
		var room := size.y - 220.0
		_scroll.custom_minimum_size.y = minf(wanted, maxf(240.0, room))


func open() -> void:
	visible = true


func close() -> void:
	visible = false


## Small helper for the stat rows used by the results and pause screens.
##
## Both labels are built with wrap off. A wrapped Label reports almost no
## minimum width (Godot lets the container decide, since it can always wrap
## more) — with `key` set to EXPAND_FILL that starved `value` down to a sliver,
## and every digit in it wrapped onto its own line. These are short one-line
## stats by design, so there is nothing to wrap in the first place.
func add_stat_row(parent: Control, label_text: String, value_text: String,
		value_color: Color = Palette.TEXT) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var key := UITheme.make_label(label_text, 28, Palette.TEXT_DIM, false)
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key)
	var value := UITheme.make_label(value_text, 32, value_color, false)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return row
