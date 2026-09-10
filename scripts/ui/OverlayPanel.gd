class_name OverlayPanel
extends Control
## Shared scaffolding for the full-screen dialogs shown during a run
## (pause, revive, results). Subclasses fill in `content` and react to open/close.

var dim: ColorRect
var panel: PanelContainer
var content: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	center.add_theme_constant_override("margin_left", 60)
	center.add_theme_constant_override("margin_right", 60)
	center.add_theme_constant_override("margin_top", 200)
	center.add_theme_constant_override("margin_bottom", 200)
	add_child(center)

	panel = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	margin.add_child(content)


## Subclasses build their widgets here.
func _build_content() -> void:
	pass


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
