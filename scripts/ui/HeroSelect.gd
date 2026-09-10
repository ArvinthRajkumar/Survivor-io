extends MenuScreen
## Operative roster: pick a hero, or spend meta currency to unlock one.

var _cards: Array[Button] = []


func get_screen_title() -> String:
	return "OPERATIVES"


func _build_content() -> void:
	_rebuild()
	add_back_button(GameManager.goto_main_menu)


func _rebuild() -> void:
	for child in body.get_children():
		child.queue_free()
	_cards.clear()
	for hero in ContentDB.hero_list:
		body.add_child(_make_hero_card(hero))
		var rank_row := _make_rank_row(hero)
		if rank_row != null:
			body.add_child(rank_row)


func _make_hero_card(hero: HeroData) -> Button:
	var unlocked := hero.unlocked_by_default or SaveManager.is_hero_unlocked(hero.id)
	var selected := GameManager.selected_hero != null and GameManager.selected_hero.id == hero.id
	var accent := hero.accent if unlocked else Color(0.35, 0.38, 0.45)
	var card := make_card(accent, 340)

	var rank := SaveManager.get_hero_rank(hero.id)
	var note := ""
	if not unlocked:
		note = "LOCKED - %s cr + %d rs" % [
			MathUtil.format_number(hero.unlock_credit_cost), hero.unlock_research_cost]
	elif selected:
		note = "SELECTED   -   RANK %d / %d" % [rank, hero.max_rank]
	else:
		note = "Tap to select   -   RANK %d / %d" % [rank, hero.max_rank]

	var text_box := fill_card(card, accent, hero.portrait_shape, hero.display_name,
		hero.role if unlocked else "Encrypted personnel file", note, true)

	if unlocked:
		text_box.add_child(UITheme.make_label(
			"Passive - %s: %s" % [hero.passive_name, hero.passive_description], 22, Palette.TEXT_DIM))
		text_box.add_child(UITheme.make_label(
			"Ultimate - %s: %s" % [hero.ultimate_name, hero.ultimate_description], 22, accent))
	else:
		text_box.add_child(UITheme.make_label(hero.description, 22, Palette.TEXT_DIM))

	if unlocked:
		card.pressed.connect(_on_select.bind(hero))
	else:
		card.pressed.connect(_on_unlock.bind(hero))
		card.disabled = not SaveManager.can_afford(hero.unlock_credit_cost, hero.unlock_research_cost)
	return card


## Permanent per-hero investment, shown as its own row so the card itself stays
## a single tap target.
func _make_rank_row(hero: HeroData) -> Control:
	if not (hero.unlocked_by_default or SaveManager.is_hero_unlocked(hero.id)):
		return null
	var rank := SaveManager.get_hero_rank(hero.id)
	var button := UITheme.make_button("", 88)
	if rank >= hero.max_rank:
		button.text = "Rank %d - fully trained" % rank
		button.disabled = true
		return button
	var cost := hero.rank_cost_at(rank)
	button.text = "Train to rank %d   (%s cr + %d rs)" % [
		rank + 1, MathUtil.format_number(cost.x), cost.y]
	button.add_theme_font_size_override("font_size", 26)
	button.disabled = not SaveManager.can_afford(cost.x, cost.y)
	button.tooltip_text = hero.describe_rank_step()
	button.pressed.connect(_on_train.bind(hero))
	return button


func _on_train(hero: HeroData) -> void:
	var rank := SaveManager.get_hero_rank(hero.id)
	var cost := hero.rank_cost_at(rank)
	if not SaveManager.spend(cost.x, cost.y):
		return
	SaveManager.set_hero_rank(hero.id, rank + 1)
	AudioManager.play_sfx(&"ui_confirm")
	_rebuild()


func _on_select(hero: HeroData) -> void:
	AudioManager.play_sfx(&"ui_confirm")
	GameManager.select_hero(hero)
	_rebuild()


func _on_unlock(hero: HeroData) -> void:
	if not SaveManager.spend(hero.unlock_credit_cost, hero.unlock_research_cost):
		AudioManager.play_sfx(&"ui_click")
		return
	SaveManager.unlock_hero(hero.id)
	AudioManager.play_sfx(&"evolve")
	GameManager.select_hero(hero)
	_rebuild()
