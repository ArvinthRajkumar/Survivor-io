extends OverlayPanel
## First-run coaching: three short pages, then it never appears again unless the
## player resets it from the settings screen.

const PAGES: Array[Dictionary] = [
	{
		"title": "MOVE",
		"body": "Drag anywhere on the lower half of the screen. The stick appears under your thumb, so one hand is enough.",
	},
	{
		"title": "KATANA",
		"body": "You always carry a blade, and it cuts along the way you are moving. Steering is aiming.",
	},
	{
		"title": "AUTO-FIRE",
		"body": "Everything else aims and fires on its own. Positioning is the whole game.",
	},
	{
		"title": "SIX SLOTS",
		"body": "Collect shards to level up, then pick a Power or Ability. Six slots for the whole run — the katana costs none of them.",
	},
]

var _page: int = 0
var _title: Label
var _body: Label
var _next: Button


func _build_content() -> void:
	_title = UITheme.make_title("MOVE", 56, Palette.ACCENT)
	content.add_child(_title)
	_body = UITheme.make_label("", 30, Palette.TEXT)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.custom_minimum_size = Vector2(0, 190)
	content.add_child(_body)
	_next = UITheme.make_button("Next")
	_next.pressed.connect(_on_next)
	content.add_child(_next)


## Called by GameScene; does nothing if the player has already seen it.
func maybe_show() -> void:
	if bool(SaveManager.profile.get("tutorial_done", false)):
		return
	# Automated runs must not stop on a dialog.
	if DevTools.smoke or DevTools.has_flag("--no-tutorial"):
		return
	_page = 0
	_refresh()
	GameManager.request_pause("tutorial")
	open()


func _refresh() -> void:
	var page: Dictionary = PAGES[_page]
	_title.text = String(page["title"])
	_body.text = String(page["body"])
	_next.text = "Start" if _page == PAGES.size() - 1 else "Next"


func _on_next() -> void:
	AudioManager.play_sfx(&"ui_click")
	_page += 1
	if _page >= PAGES.size():
		SaveManager.profile["tutorial_done"] = true
		SaveManager.mark_dirty()
		close()
		GameManager.release_pause("tutorial")
		return
	_refresh()
