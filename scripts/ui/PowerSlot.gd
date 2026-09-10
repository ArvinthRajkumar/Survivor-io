class_name PowerSlot
extends Control
## One slot in the bottom bar.
##
## A slot is either filled with an owned Power/Passive or shown as an empty
## socket, so the six-slot budget is legible at a glance rather than something
## the player has to remember. Filled slots draw the power's own artwork, its
## level pips, and — for Powers — a cooldown sweep.
##
## Hovering (or touching and holding, on a phone) raises `hover_changed`, which
## the HUD turns into a tooltip.

signal hover_changed(slot: PowerSlot, hovered: bool)

const LONG_PRESS_TIME := 0.22

var data: PowerData
var level: int = 0
var charge: float = 1.0
var slot_index: int = 0

var _phase: float = 0.0
var _hovered: bool = false
var _press_time: float = -1.0
var _pop: float = 0.0
var _max_flash: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(96, 96)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func set_entry(power: PowerData, power_level: int) -> void:
	var was_level := level
	data = power
	level = power_level
	if power != null and power_level > was_level:
		_pop = 1.0
		if power_level >= power.max_level:
			_max_flash = 1.0
	queue_redraw()


func clear_entry() -> void:
	data = null
	level = 0
	queue_redraw()


func set_charge(value: float) -> void:
	charge = clampf(value, 0.0, 1.0)


func is_filled() -> bool:
	return data != null


func tooltip_line() -> String:
	if data == null:
		return ""
	return data.tooltip if not data.tooltip.is_empty() else data.description


func _process(delta: float) -> void:
	_phase += delta
	_pop = maxf(0.0, _pop - delta * 2.2)
	_max_flash = maxf(0.0, _max_flash - delta * 1.2)
	# Long press stands in for hover on touch devices.
	if _press_time >= 0.0:
		_press_time += delta
		if _press_time >= LONG_PRESS_TIME and not _hovered:
			_set_hovered(true)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press_time = 0.0
		else:
			_press_time = -1.0
			_set_hovered(false)
		accept_event()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_press_time = 0.0 if button.pressed else -1.0
			if not button.pressed:
				_set_hovered(false)
			accept_event()


func _on_mouse_entered() -> void:
	_set_hovered(true)


func _on_mouse_exited() -> void:
	_press_time = -1.0
	_set_hovered(false)


func _set_hovered(value: bool) -> void:
	if _hovered == value:
		return
	_hovered = value
	hover_changed.emit(self, value)
	queue_redraw()


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	var s := size
	var rect := Rect2(Vector2.ZERO, s)
	if data == null:
		_draw_empty(rect)
		return

	var accent := data.color
	var maxed := level >= data.max_level
	# A short pop on level-up, and a lingering glow once the power is maxed.
	var pop := 1.0 + 0.10 * _pop

	draw_set_transform(s * 0.5, 0.0, Vector2.ONE * pop)
	var local := Rect2(-s * 0.5, s)

	# Plate.
	var plate := Color(accent.r * 0.14, accent.g * 0.16, accent.b * 0.22, 0.95)
	draw_rect(local, plate)
	# Cooldown sweep: the unfilled part is dimmed from the bottom up.
	if data.is_power() and charge < 1.0:
		var h := local.size.y * (1.0 - charge)
		draw_rect(Rect2(local.position, Vector2(local.size.x, h)), Color(0, 0, 0, 0.45))

	var border := accent
	if maxed:
		border = border.lerp(Color(1.0, 0.86, 0.35), 0.55 + 0.35 * absf(sin(_phase * 2.5)))
	elif _hovered:
		border = Color.WHITE
	draw_rect(local, border, false, 3.0 if (maxed or _hovered) else 2.0)

	# Passives get a subtle corner notch so the two categories read apart even
	# before you read the icon.
	if data.is_passive():
		var notch := PackedVector2Array([
			local.position + Vector2(local.size.x - 16.0, 0.0),
			local.position + Vector2(local.size.x, 0.0),
			local.position + Vector2(local.size.x, 16.0),
		])
		draw_colored_polygon(notch, Color(accent.r, accent.g, accent.b, 0.85))

	var art_radius := minf(s.x, s.y) * 0.30
	PowerArt.draw(self, data.art_id(), Vector2(0.0, -s.y * 0.06), art_radius,
		accent, data.color_secondary, _phase)

	_draw_pips(local, accent, maxed)

	if _max_flash > 0.0:
		draw_rect(local, Color(1, 1, 1, 0.35 * _max_flash))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pips(local: Rect2, accent: Color, maxed: bool) -> void:
	if data == null:
		return
	var count := mini(data.max_level, 8)
	var width := local.size.x - 14.0
	var pip_w := width / float(count)
	var y := local.position.y + local.size.y - 9.0
	for i in count:
		var x := local.position.x + 7.0 + pip_w * float(i)
		var filled := i < level
		var color := (Color(1.0, 0.86, 0.35) if maxed else accent) if filled else Color(1, 1, 1, 0.15)
		draw_rect(Rect2(Vector2(x + 1.0, y), Vector2(pip_w - 2.0, 5.0)), color)


## Empty sockets are drawn as a dashed outline with a plus, which communicates
## "you may still choose something" without looking like a broken icon.
func _draw_empty(rect: Rect2) -> void:
	var dim := Color(1, 1, 1, 0.10)
	draw_rect(rect, Color(1, 1, 1, 0.035))
	var dash := 9.0
	var edges := [
		[rect.position, Vector2(rect.end.x, rect.position.y)],
		[Vector2(rect.end.x, rect.position.y), rect.end],
		[rect.end, Vector2(rect.position.x, rect.end.y)],
		[Vector2(rect.position.x, rect.end.y), rect.position],
	]
	for edge in edges:
		var from: Vector2 = edge[0]
		var to: Vector2 = edge[1]
		var length := from.distance_to(to)
		var dir := (to - from).normalized()
		var travelled := 0.0
		while travelled < length:
			var seg := minf(dash, length - travelled)
			draw_line(from + dir * travelled, from + dir * (travelled + seg), dim, 2.0)
			travelled += dash * 2.0
	var center := rect.get_center()
	var arm := 11.0
	draw_line(center - Vector2(arm, 0.0), center + Vector2(arm, 0.0), Color(1, 1, 1, 0.22), 3.0)
	draw_line(center - Vector2(0.0, arm), center + Vector2(0.0, arm), Color(1, 1, 1, 0.22), 3.0)
