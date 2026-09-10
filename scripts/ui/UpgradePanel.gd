extends Control
## Level-up choice panel.
##
## The header is doing real work here: it tells you how many of the six shared
## slots are left, and once they run out it says so plainly, because from that
## point every card is an upgrade to something you already own and nothing can
## be swapped. Cards show the power's own artwork so a choice can be recognised
## before the text is read.

signal choice_made(offer: Dictionary)

## Tall enough for a two-line description; the button cannot grow to fit its
## own contents, so anything longer is clamped rather than allowed to spill past
## the card border.
const CARD_HEIGHT := 202
const DESCRIPTION_LINES := 2

var _offers: Array[Dictionary] = []
var _rerolls: int = 0

var _title: Label
var _slot_line: Label
var _slot_pips: Control
var _cards_box: VBoxContainer
var _reroll_button: Button
var _phase: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _process(delta: float) -> void:
	if not visible:
		return
	_phase += delta
	if _slot_pips != null:
		_slot_pips.queue_redraw()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.90)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 100)
	margin.add_theme_constant_override("margin_bottom", 80)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(root)

	_title = UITheme.make_title("LEVEL UP", 62, Palette.ACCENT)
	root.add_child(_title)

	_slot_line = UITheme.make_label("", 26, Palette.TEXT_DIM, false)
	_slot_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_slot_line)

	_slot_pips = Control.new()
	_slot_pips.custom_minimum_size = Vector2(0, 22)
	_slot_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_pips.draw.connect(_draw_slot_pips)
	root.add_child(_slot_pips)

	# Deliberately not SIZE_EXPAND_FILL: letting the card box absorb the spare
	# height pins the cards to the top and strands the reroll button against the
	# HUD. Shrink-wrapping lets the parent VBox centre the whole stack instead.
	_cards_box = VBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 16)
	root.add_child(_cards_box)

	_reroll_button = UITheme.make_button("Reroll (0)", 88)
	_reroll_button.pressed.connect(_on_reroll)
	root.add_child(_reroll_button)


func open(offers: Array[Dictionary], player_level: int) -> void:
	_offers = offers
	_title.text = "LEVEL %d" % player_level
	_rerolls = int(RunManager.relic_special_value(&"reroll"))
	_refresh_header()
	_refresh_reroll()
	_populate()
	visible = true
	# Headless soak runs have nobody to tap a card; take the first offer so the
	# run keeps moving. (The tree is paused here, so _process cannot do it.)
	if DevTools.smoke:
		pick_first.call_deferred()


func _refresh_header() -> void:
	var loadout := RunManager.loadout
	if loadout.is_full():
		_slot_line.text = "All %d slots filled — upgrades only" % PowerLoadout.MAX_SLOTS
		_slot_line.add_theme_color_override("font_color", Palette.ACCENT_WARM)
	else:
		var free := loadout.slots_free()
		_slot_line.text = "%d of %d slots free — choices are permanent" % [free, PowerLoadout.MAX_SLOTS]
		_slot_line.add_theme_color_override("font_color", Palette.TEXT_DIM)


## A row of six pips: filled ones carry the colour of what is in them.
func _draw_slot_pips() -> void:
	var ci := _slot_pips
	var loadout := RunManager.loadout
	var ids := loadout.get_ids()
	var total := PowerLoadout.MAX_SLOTS
	var gap := 10.0
	var width := (ci.size.x - gap * float(total - 1)) / float(total)
	width = minf(width, 76.0)
	var span := width * float(total) + gap * float(total - 1)
	var x := (ci.size.x - span) * 0.5
	for i in total:
		var rect := Rect2(Vector2(x + (width + gap) * float(i), 4.0), Vector2(width, 12.0))
		if i < ids.size():
			var data := ContentDB.get_power(ids[i])
			ci.draw_rect(rect, data.color if data != null else Palette.ACCENT)
		else:
			ci.draw_rect(rect, Color(1, 1, 1, 0.12))
			ci.draw_rect(rect, Color(1, 1, 1, 0.20), false, 1.0)


func _populate() -> void:
	for child in _cards_box.get_children():
		child.queue_free()
	for offer in _offers:
		_cards_box.add_child(_make_card(offer))


func _make_card(offer: Dictionary) -> Control:
	var color: Color = offer.get("color", Palette.ACCENT)
	var color2: Color = offer.get("color2", Color.WHITE)
	var rarity: int = int(offer.get("rarity", 0))
	var accent := Palette.rarity_color(rarity)
	var is_power := int(offer.get("category", 0)) == int(PowerData.Category.POWER)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal",
		UITheme.panel_box(Color(accent.r * 0.10, accent.g * 0.12, accent.b * 0.17, 0.97), accent))
	button.add_theme_stylebox_override("hover",
		UITheme.panel_box(Color(accent.r * 0.20, accent.g * 0.22, accent.b * 0.28, 1.0), Color.WHITE))
	button.add_theme_stylebox_override("pressed",
		UITheme.panel_box(Color(accent.r * 0.06, accent.g * 0.08, accent.b * 0.13, 1.0), accent))
	button.pressed.connect(_on_card_pressed.bind(offer))

	# Artwork panel on the left, drawn with the same library the HUD uses.
	var art := PowerCardArt.new()
	art.art_id = StringName(offer.get("art", offer.get("id", &"")))
	art.color = color
	art.color_secondary = color2
	art.level = int(offer.get("level", 1))
	art.max_level = int(offer.get("max_level", 1))
	art.custom_minimum_size = Vector2(122, 122)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 22
	row.offset_right = -22
	row.offset_top = 16
	row.offset_bottom = -16
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	row.add_child(art)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.add_theme_constant_override("separation", 4)
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_box)

	var tag_row := HBoxContainer.new()
	tag_row.add_theme_constant_override("separation", 10)
	tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(tag_row)
	tag_row.add_child(_make_chip("POWER" if is_power else "ABILITY",
		color if is_power else Palette.RESEARCH))
	tag_row.add_child(UITheme.make_label(String(offer.get("tag", "")), 22, accent, false))

	text_box.add_child(UITheme.make_label(String(offer.get("title", "")), 38, Palette.TEXT, false))

	var description := UITheme.make_label(String(offer.get("subtitle", "")), 24, Palette.TEXT_DIM)
	description.max_lines_visible = DESCRIPTION_LINES
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(description)
	return button


## Small pill used for the category badge.
func _make_chip(text: String, color: Color) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(color.r * 0.22, color.g * 0.24, color.b * 0.30, 0.95), color, 10, 1))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := UITheme.make_label(text, 19, color, false)
	chip.add_child(label)
	return chip


## Used by the headless soak test to take the first offer.
func pick_first() -> void:
	if _offers.is_empty():
		return
	_on_card_pressed(_offers[0])


func _on_card_pressed(offer: Dictionary) -> void:
	visible = false
	choice_made.emit(offer)


func _on_reroll() -> void:
	if _rerolls <= 0:
		return
	_rerolls -= 1
	_refresh_reroll()
	var extra := int(RunManager.relic_special_value(&"extra_choice"))
	_offers = UpgradeSystem.generate(3 + extra)
	_populate()
	AudioManager.play_sfx(&"ui_click")


## Rerolls only exist if a relic granted them, so the button stays hidden rather
## than sitting there permanently greyed out.
func _refresh_reroll() -> void:
	_reroll_button.visible = _rerolls > 0
	_reroll_button.text = "Reroll (%d)" % _rerolls
