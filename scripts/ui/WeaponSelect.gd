extends MenuScreen
## The last screen before a run: pick what you are carrying in.
##
## Three of the eight weapons are offered, drawn fresh every time this screen is
## opened. Offering all eight would make this a settings page — the same
## favourite every run — while offering one would make it an announcement. Three
## is enough that the pick is a decision and small enough to read at a glance.
##
## The weapon spends none of the six in-run slots, so this choice shapes a run
## without costing anything: it decides how the player fights, not how much they
## can carry.

const OFFER_COUNT := 3

var _offers: Array[PowerData] = []


func get_screen_title() -> String:
	return "LOADOUT"


func get_screen_subtitle() -> String:
	return "CHOOSE YOUR WEAPON"


func _build_content() -> void:
	GameManager.restore_last_selection()
	_offers = _roll_offers()
	for weapon in _offers:
		body.add_child(_make_weapon_card(weapon))
	add_back_button(GameManager.goto_main_menu)


## Three distinct weapons, weighted by rarity so the plainer ones show up more
## often. The one carried last run is excluded, which is the cheapest way to
## stop the screen handing the player the same answer every time.
func _roll_offers() -> Array[PowerData]:
	var pool: Array[PowerData] = []
	for weapon in ContentDB.weapon_list:
		if weapon.id != GameManager.selected_weapon_id:
			pool.append(weapon)
	if pool.size() < OFFER_COUNT:
		pool = ContentDB.weapon_list.duplicate()
	pool.shuffle()
	var out: Array[PowerData] = []
	for weapon in pool:
		if out.size() >= OFFER_COUNT:
			break
		out.append(weapon)
	return out


func _make_weapon_card(weapon: PowerData) -> Control:
	var card := make_card(weapon.color, 250)
	var text := fill_card(card, weapon.color, 2, weapon.display_name,
		weapon.description, weapon.tooltip)
	# fill_card draws an operative bust in the icon slot; a weapon wants its own
	# artwork, so the icon is swapped for the card art the level-up panel uses.
	_replace_icon(card, weapon)
	text.add_theme_constant_override("separation", UITheme.GAP_TIGHT)
	card.pressed.connect(_on_pick.bind(weapon))
	return card


## Swaps the portrait IconRect that fill_card inserted for the weapon's own art.
func _replace_icon(card: Button, weapon: PowerData) -> void:
	var row := card.get_child(0)
	if row == null or row.get_child_count() == 0:
		return
	var slot := row.get_child(0)
	var art := PowerCardArt.new()
	art.art_id = weapon.art_id()
	art.color = weapon.color
	art.color_secondary = weapon.color_secondary
	art.level = 1
	art.max_level = weapon.max_level
	art.custom_minimum_size = Vector2(132, 132)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)
	row.move_child(art, 0)
	row.remove_child(slot)
	slot.queue_free()


func _on_pick(weapon: PowerData) -> void:
	AudioManager.play_sfx(&"ui_confirm")
	GameManager.selected_weapon_id = weapon.id
	GameManager.start_run()
