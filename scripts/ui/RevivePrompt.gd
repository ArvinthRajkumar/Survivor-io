extends OverlayPanel
## Offered when the player dies, once per revive charge. A countdown keeps the
## moment tense instead of letting the run sit paused indefinitely.

signal revive_accepted
signal revive_declined

const DECISION_TIME := 8.0

var _timer: float = 0.0
var _countdown: Label
var _accept: Button


func _build_content() -> void:
	content.add_child(UITheme.make_title("YOU FELL", 56, Palette.DANGER))
	var body := UITheme.make_label(
		"Revive with half health and clear the space around you.", 28, Palette.TEXT_DIM)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(body)

	_countdown = UITheme.make_title("8", 72, Palette.ACCENT)
	content.add_child(_countdown)

	_accept = UITheme.make_button("Revive")
	_accept.pressed.connect(_on_accept)
	content.add_child(_accept)

	var decline := UITheme.make_button("Give Up", 92)
	decline.add_theme_color_override("font_color", Palette.TEXT_DIM)
	decline.pressed.connect(_on_decline)
	content.add_child(decline)


func open(revives_left: int = 1) -> void:
	_timer = DECISION_TIME
	_accept.text = "Revive (%d left)" % revives_left
	_accept.disabled = revives_left <= 0
	super.open()
	# Automated soak runs take the revive so the later minutes get exercised.
	if revives_left > 0 and DevTools.smoke:
		_on_accept.call_deferred()


func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	_countdown.text = str(int(ceil(maxf(0.0, _timer))))
	if _timer <= 0.0:
		_on_decline()


func _on_accept() -> void:
	close()
	AudioManager.play_sfx(&"ui_confirm")
	revive_accepted.emit()


func _on_decline() -> void:
	close()
	revive_declined.emit()
