class_name MenuScreen
extends Control
## Shared frame for the out-of-run screens: animated backdrop, header with the
## player's currencies, a scrolling body and an optional back button.

var header: VBoxContainer
var body: VBoxContainer
var footer: VBoxContainer
var title_label: Label

var _credits_label: Label
var _research_label: Label
var _backdrop: Control
var _column: VBoxContainer
var _scroll: ScrollContainer
var _time: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_frame()
	_build_content()
	_refresh_currency()
	SaveManager.currency_changed.connect(_on_currency_changed)


func _build_frame() -> void:
	_backdrop = Control.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.draw.connect(_draw_backdrop)
	add_child(_backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)

	# The whole screen is centred inside a fixed maximum width. On a phone this
	# changes nothing; on anything wider it stops the menu from stretching into
	# one thin line of text across the display.
	var centre := HBoxContainer.new()
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(centre)

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(0, 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", UITheme.GAP_SECTION)
	centre.add_child(column)
	_column = column

	# Currencies live on their own line, hard against the right edge, so the
	# title underneath can sit dead centre instead of being pushed off it by
	# however many digits the player happens to have.
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_END
	chips.add_theme_constant_override("separation", 20)
	column.add_child(chips)

	# Currency chips must never wrap - a squeezed HBox would stack them letter
	# by letter.
	_credits_label = UITheme.make_label("0", UITheme.SIZE_LABEL, Palette.GOLD, false)
	_credits_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chips.add_child(_credits_label)
	_research_label = UITheme.make_label("0", UITheme.SIZE_LABEL, Palette.RESEARCH, false)
	_research_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chips.add_child(_research_label)

	header = VBoxContainer.new()
	header.add_theme_constant_override("separation", UITheme.GAP_TIGHT)
	column.add_child(header)

	title_label = UITheme.make_title(get_screen_title(), UITheme.SIZE_SCREEN_TITLE, Palette.ACCENT)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title_label)

	var subtitle_text := get_screen_subtitle()
	if not subtitle_text.is_empty():
		var subtitle := UITheme.make_label(
			subtitle_text, UITheme.SIZE_HEADING, Palette.ACCENT_WARM, false)
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_scroll = scroll

	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Centred while the content is shorter than the screen, scrolling once it is
	# not. _process keeps the minimum height matched to the viewport, which is
	# what makes both halves of that true at the same time.
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", UITheme.GAP_ROW + 4)
	scroll.add_child(body)

	footer = VBoxContainer.new()
	footer.add_theme_constant_override("separation", UITheme.GAP_ROW)
	column.add_child(footer)


func _process(delta: float) -> void:
	_time += delta
	if _backdrop != null:
		_backdrop.queue_redraw()
	if _column != null:
		# Applied every frame rather than once, because the viewport size is not
		# final until the first resize on some devices.
		var available := size.x - 72.0
		_column.custom_minimum_size.x = minf(available, float(UITheme.CONTENT_MAX_WIDTH))
	if _scroll != null and body != null:
		body.custom_minimum_size.y = _scroll.size.y


## Slow drifting grid so the menus feel like part of the same world.
func _draw_backdrop() -> void:
	var s := _backdrop.size
	_backdrop.draw_rect(Rect2(Vector2.ZERO, s), Palette.BG_DEEP)
	var grid := Color(0.16, 0.30, 0.44, 0.22)
	var step := 120.0
	var offset := fmod(_time * 14.0, step)
	var x := -step + offset
	while x < s.x + step:
		_backdrop.draw_line(Vector2(x, 0.0), Vector2(x, s.y), grid, 1.5)
		x += step
	var y := -step + offset
	while y < s.y + step:
		_backdrop.draw_line(Vector2(0.0, y), Vector2(s.x, y), grid, 1.5)
		y += step
	var glow := Palette.ACCENT
	glow.a = 0.06
	_backdrop.draw_circle(Vector2(s.x * 0.5, s.y * 0.22), 320.0 + 18.0 * sin(_time), glow)


func get_screen_title() -> String:
	return "MENU"


## Optional second line under the title. Empty on every screen but the hub.
func get_screen_subtitle() -> String:
	return ""


func _build_content() -> void:
	pass


func _refresh_currency() -> void:
	_credits_label.text = "%s cr" % MathUtil.format_number(SaveManager.get_credits())
	_research_label.text = "%s rs" % MathUtil.format_number(SaveManager.get_research())


func _on_currency_changed(_credits: int, _research: int) -> void:
	_refresh_currency()


func add_back_button(callback: Callable, label: String = "Back") -> Button:
	var button := UITheme.make_button(label, UITheme.SECONDARY_BUTTON_HEIGHT)
	button.pressed.connect(callback)
	footer.add_child(button)
	return button


## A tappable card used by the hero, level and relic lists.
func make_card(accent: Color, min_height: int = 200) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, min_height)
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_stylebox_override("normal",
		UITheme.panel_box(Color(accent.r * 0.10, accent.g * 0.12, accent.b * 0.16, 0.94), accent))
	card.add_theme_stylebox_override("hover",
		UITheme.panel_box(Color(accent.r * 0.18, accent.g * 0.20, accent.b * 0.26, 1.0), Color.WHITE))
	card.add_theme_stylebox_override("pressed",
		UITheme.panel_box(Color(accent.r * 0.06, accent.g * 0.08, accent.b * 0.12, 1.0), accent))
	card.add_theme_stylebox_override("disabled",
		UITheme.panel_box(Color(0.08, 0.09, 0.12, 0.85), Color(0.28, 0.30, 0.36, 0.6)))
	return card


## Standard card interior: icon on the left, stacked text on the right.
## Returns the text column so callers can append extra lines to it - anchoring a
## second block over the card would overlap this one.
func fill_card(card: Button, icon_color: Color, shape: int, title: String,
		subtitle: String, note: String = "", portrait: bool = false,
		icon_secondary: Color = Palette.ACCENT_WARM) -> VBoxContainer:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 24
	row.offset_right = -24
	row.offset_top = 16
	row.offset_bottom = -16
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var icon := IconRect.new()
	icon.custom_minimum_size = Vector2(150, 150) if portrait else Vector2(128, 128)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.portrait_mode = portrait
	row.add_child(icon)
	icon.setup(icon_color, shape, 0, 0, icon_secondary)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.add_theme_constant_override("separation", 6)
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_box)

	text_box.add_child(UITheme.make_label(title, UITheme.SIZE_HEADING, Palette.TEXT, false))
	text_box.add_child(UITheme.make_label(subtitle, UITheme.SIZE_LABEL, Palette.TEXT_DIM))
	if not note.is_empty():
		text_box.add_child(UITheme.make_label(note, UITheme.SIZE_SMALL, icon_color))
	return text_box
