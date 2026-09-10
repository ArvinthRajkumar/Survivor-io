extends MenuScreen
## Research Lab: permanent stat upgrades and the relic loadout.
##
## Both tabs write straight to SaveManager, and RunManager reads them when the
## next run is configured.

const MAX_EQUIPPED_RELICS := 2

var _tab: int = 0
var _tab_buttons: Array[Button] = []
var _list: VBoxContainer


func get_screen_title() -> String:
	return "RESEARCH LAB"


func _build_content() -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	body.add_child(tabs)
	_tab_buttons.append(_make_tab(tabs, "Upgrades", 0))
	_tab_buttons.append(_make_tab(tabs, "Relics", 1))

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 16)
	body.add_child(_list)

	_refresh()
	add_back_button(GameManager.goto_main_menu)


func _make_tab(parent: Control, label: String, index: int) -> Button:
	var button := UITheme.make_button(label, 88)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_tab.bind(index))
	parent.add_child(button)
	return button


func _on_tab(index: int) -> void:
	_tab = index
	AudioManager.play_sfx(&"ui_click")
	_refresh()


func _refresh() -> void:
	for i in _tab_buttons.size():
		_tab_buttons[i].modulate = Color.WHITE if i == _tab else Color(0.6, 0.64, 0.72)
	for child in _list.get_children():
		child.queue_free()
	if _tab == 0:
		_build_upgrades()
	else:
		_build_relics()


# --- Permanent upgrades -----------------------------------------------------

func _build_upgrades() -> void:
	var any := false
	for item in ContentDB.upgrade_list:
		if not item.meta_only:
			continue
		any = true
		_list.add_child(_make_upgrade_card(item))
	if not any:
		_list.add_child(UITheme.make_label("No research available.", 26, Palette.TEXT_DIM))


func _make_upgrade_card(item: UpgradeData) -> Button:
	var level := SaveManager.get_meta_level(item.id)
	var maxed := level >= item.max_level
	var cost := item.meta_cost_at(level)
	var card := make_card(item.color, 210)

	var note := "MAXED" if maxed else "%s cr + %d rs" % [MathUtil.format_number(cost.x), cost.y]
	fill_card(card, item.color, item.icon_shape, item.display_name,
		"%s  (Lv %d / %d)" % [item.describe_step(level + 1), level, item.max_level], note)

	if maxed:
		card.disabled = true
	else:
		card.disabled = not SaveManager.can_afford(cost.x, cost.y)
		card.pressed.connect(_on_buy_upgrade.bind(item))
	return card


func _on_buy_upgrade(item: UpgradeData) -> void:
	var level := SaveManager.get_meta_level(item.id)
	var cost := item.meta_cost_at(level)
	if not SaveManager.spend(cost.x, cost.y):
		return
	SaveManager.set_meta_level(item.id, level + 1)
	AudioManager.play_sfx(&"ui_confirm")
	_refresh()


# --- Relics -----------------------------------------------------------------

func _build_relics() -> void:
	var equipped: Array = SaveManager.get_equipped_relics()
	_list.add_child(UITheme.make_label(
		"Equip up to %d relics. They bend a run without simply making it easier." % MAX_EQUIPPED_RELICS,
		24, Palette.TEXT_DIM))
	for relic in ContentDB.relic_list:
		_list.add_child(_make_relic_card(relic, equipped))
	if ContentDB.relic_list.is_empty():
		_list.add_child(UITheme.make_label("No relics recovered yet.", 26, Palette.TEXT_DIM))


func _make_relic_card(relic: RelicData, equipped: Array) -> Button:
	var owned := SaveManager.is_relic_unlocked(relic.id)
	var is_equipped := equipped.has(String(relic.id))
	var accent := relic.color if owned else Color(0.35, 0.38, 0.45)
	var card := make_card(accent, 210)

	var note := ""
	if not owned:
		note = "%s cr + %d rs to recover" % [MathUtil.format_number(relic.credit_cost), relic.research_cost]
	elif is_equipped:
		note = "EQUIPPED - tap to remove"
	else:
		note = "Tap to equip"

	fill_card(card, accent, relic.icon_shape, relic.display_name, relic.description, note)

	if not owned:
		card.disabled = not SaveManager.can_afford(relic.credit_cost, relic.research_cost)
		card.pressed.connect(_on_buy_relic.bind(relic))
	else:
		card.pressed.connect(_on_toggle_relic.bind(relic))
	return card


func _on_buy_relic(relic: RelicData) -> void:
	if not SaveManager.spend(relic.credit_cost, relic.research_cost):
		return
	SaveManager.unlock_relic(relic.id)
	AudioManager.play_sfx(&"evolve")
	_refresh()


func _on_toggle_relic(relic: RelicData) -> void:
	var equipped: Array = SaveManager.get_equipped_relics().duplicate()
	var key := String(relic.id)
	if equipped.has(key):
		equipped.erase(key)
	elif equipped.size() < MAX_EQUIPPED_RELICS:
		equipped.append(key)
	else:
		# Replace the oldest so the player is never stuck.
		equipped.pop_front()
		equipped.append(key)
	SaveManager.set_equipped_relics(equipped)
	AudioManager.play_sfx(&"ui_click")
	_refresh()
