class_name UITheme
extends RefCounted
## Builds the game's Theme in code.
##
## Generating it avoids shipping a .theme binary and keeps every colour in one
## readable place. GameManager applies the result to the scene tree root, so all
## Controls inherit it without any per-scene setup.

const CORNER := 18
const BORDER := 2


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 30

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
	theme.set_font_size("font_size", "Button", 34)


static func _style_panel(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer",
		panel_box(Palette.BG_PANEL, Color(0.22, 0.32, 0.46, 0.7)))
	theme.set_stylebox("panel", "Panel",
		panel_box(Palette.BG_PANEL, Color(0.22, 0.32, 0.46, 0.7)))


static func _style_label(theme: Theme) -> void:
	theme.set_color("font_color", "Label", Palette.TEXT)
	theme.set_font_size("font_size", "Label", 30)
	theme.set_color("font_color", "RichTextLabel", Palette.TEXT)
	theme.set_font_size("normal_font_size", "RichTextLabel", 28)


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
	theme.set_font_size("font_size", "CheckButton", 30)


static func _style_scroll(theme: Theme) -> void:
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.30, 0.45, 0.62, 0.8)
	grabber.set_corner_radius_all(6)
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	theme.set_stylebox("grabber_pressed", "VScrollBar", grabber)


## A large, thumb-friendly primary button.
static func make_button(text: String, min_height: int = 108) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, min_height)
	button.focus_mode = Control.FOCUS_NONE
	return button


static func make_title(text: String, size: int = 56, color: Color = Palette.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


static func make_label(text: String, size: int = 26, color: Color = Palette.TEXT_DIM,
		wrap: bool = true) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return label
