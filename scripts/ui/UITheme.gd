class_name UITheme
extends RefCounted
## Builds the game's Theme in code.
##
## Generating it avoids shipping a .theme binary and keeps every colour in one
## readable place. GameManager applies the result to the scene tree root, so all
## Controls inherit it without any per-scene setup.

const CORNER := 18
const BORDER := 2

## One type scale for the whole app. Every screen pulls its sizes from here
## rather than hard-coding numbers, which is what keeps the menus, the pause
## dialog, the settings page and the in-run panels looking like one product
## instead of five that were written on different days.
const SIZE_SCREEN_TITLE := 64
const SIZE_TITLE := 52
const SIZE_HEADING := 40
const SIZE_BODY := 32
const SIZE_LABEL := 28
const SIZE_SMALL := 24
const SIZE_TINY := 20

## Shared spacing, so gaps between sections match across screens.
const GAP_SECTION := 26
const GAP_ROW := 14
const GAP_TIGHT := 8

## Content is centred inside this width on any screen wider than it, so a
## tablet or a landscape phone does not stretch a menu into one long line.
const CONTENT_MAX_WIDTH := 900

## Minimum height for a primary tap target. Anything the thumb has to find in a
## hurry gets this; secondary rows get SECONDARY_BUTTON_HEIGHT.
const BUTTON_HEIGHT := 118
const SECONDARY_BUTTON_HEIGHT := 96


## The one Theme instance the whole app shares.
##
## Assigning it to the window root is not enough on its own: Controls parented
## under a CanvasLayer (which is where every in-run dialog lives) do not inherit
## it, so the pause menu, the level-up panel and the HUD were falling back to
## Godot's stock button and panel styling — small text on flat grey. Anything
## under a CanvasLayer sets `theme = UITheme.shared()` on its own root.
static var _shared: Theme


static func shared() -> Theme:
	if _shared == null:
		_shared = build()
	return _shared


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = SIZE_BODY

	_style_button(theme)
	_style_panel(theme)
	_style_label(theme)
	_style_progress(theme)
	_style_slider(theme)
	_style_check(theme)
	_style_scroll(theme)
	return theme


static func panel_box(bg: Color, border: Color, corner: int = CORNER, border_width: int = BORDER) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(corner)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	return box


static func _style_button(theme: Theme) -> void:
	var normal := panel_box(Color(0.10, 0.13, 0.20, 0.95), Color(0.30, 0.45, 0.62, 0.85))
	var hover := panel_box(Color(0.14, 0.20, 0.30, 0.98), Palette.ACCENT)
	var pressed := panel_box(Color(0.07, 0.10, 0.16, 1.0), Palette.ACCENT)
	var disabled := panel_box(Color(0.08, 0.09, 0.12, 0.7), Color(0.25, 0.27, 0.32, 0.5))
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", panel_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	theme.set_color("font_color", "Button", Palette.TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Palette.ACCENT)
	theme.set_color("font_disabled_color", "Button", Palette.TEXT_DIM)
	theme.set_font_size("font_size", "Button", SIZE_HEADING - 4)


static func _style_panel(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer",
		panel_box(Palette.BG_PANEL, Color(0.22, 0.32, 0.46, 0.7)))
	theme.set_stylebox("panel", "Panel",
		panel_box(Palette.BG_PANEL, Color(0.22, 0.32, 0.46, 0.7)))


static func _style_label(theme: Theme) -> void:
	theme.set_color("font_color", "Label", Palette.TEXT)
	theme.set_font_size("font_size", "Label", SIZE_BODY)
	theme.set_color("font_color", "RichTextLabel", Palette.TEXT)
	theme.set_font_size("normal_font_size", "RichTextLabel", SIZE_LABEL)


static func _style_progress(theme: Theme) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	bg.set_corner_radius_all(10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.ACCENT
	fill.set_corner_radius_all(10)
	theme.set_stylebox("background", "ProgressBar", bg)
	theme.set_stylebox("fill", "ProgressBar", fill)
	theme.set_color("font_color", "ProgressBar", Color(0, 0, 0, 0))


static func _style_slider(theme: Theme) -> void:
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.10, 0.13, 0.20, 1.0)
	slider_bg.set_corner_radius_all(8)
	slider_bg.content_margin_top = 8
	slider_bg.content_margin_bottom = 8
	var grabber_area := StyleBoxFlat.new()
	grabber_area.bg_color = Palette.ACCENT
	grabber_area.set_corner_radius_all(8)
	grabber_area.content_margin_top = 8
	grabber_area.content_margin_bottom = 8
	theme.set_stylebox("slider", "HSlider", slider_bg)
	theme.set_stylebox("grabber_area", "HSlider", grabber_area)
	theme.set_stylebox("grabber_area_highlight", "HSlider", grabber_area)


static func _style_check(theme: Theme) -> void:
	theme.set_color("font_color", "CheckButton", Palette.TEXT)
	theme.set_font_size("font_size", "CheckButton", SIZE_BODY)


static func _style_scroll(theme: Theme) -> void:
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.30, 0.45, 0.62, 0.8)
	grabber.set_corner_radius_all(6)
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	theme.set_stylebox("grabber_pressed", "VScrollBar", grabber)


## A large, thumb-friendly primary button.
static func make_button(text: String, min_height: int = BUTTON_HEIGHT) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, min_height)
	button.focus_mode = Control.FOCUS_NONE
	return button


## The standard container for one row of settings or stats: same fill, border
## and padding as every other panel in the app, so a slider row, a toggle row
## and a pair of choice buttons all read as the same kind of object.
static func make_row_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		panel_box(Color(0.09, 0.11, 0.17, 0.92), Color(0.24, 0.34, 0.48, 0.75)))
	return panel


## One toggle row: label on the left, switch hard right, inside the standard row
## panel. Shared by the settings page and the pause dialog so a toggle looks the
## same wherever the player meets it. `on_toggled` receives the new state.
static func make_toggle_row(text: String, pressed: bool, on_toggled: Callable) -> PanelContainer:
	var panel := make_row_panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP_ROW)
	panel.add_child(row)

	var label := make_label(text, SIZE_BODY, Palette.TEXT, false)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	# The switch carries no text of its own, so every row's label is drawn by the
	# same make_label call at the same size and colour.
	var check := CheckButton.new()
	check.focus_mode = Control.FOCUS_NONE
	check.custom_minimum_size = Vector2(0, 64)
	check.button_pressed = pressed
	check.toggled.connect(on_toggled)
	row.add_child(check)
	return panel


static func make_title(text: String, size: int = SIZE_TITLE, color: Color = Palette.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


static func make_label(text: String, size: int = SIZE_LABEL, color: Color = Palette.TEXT_DIM,
		wrap: bool = true) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return label
