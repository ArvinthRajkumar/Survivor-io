class_name PowerCardArt
extends Control
## The animated artwork panel on an upgrade card.
##
## It is a live drawing rather than a static icon: the drone's rotors turn, the
## Molotov's rag flickers, the saw spins. That motion is the clearest signal that
## a card is an object in the world and not just a label.

var art_id: StringName = &""
var color: Color = Palette.ACCENT
var color_secondary: Color = Color.WHITE
var level: int = 1
var max_level: int = 5

var _phase: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Runs while the tree is paused, because the level-up panel pauses the game.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_phase += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	var center := s * 0.5
	var radius := minf(s.x, s.y) * 0.34

	# Plate with a soft radial glow behind the art.
	draw_rect(Rect2(Vector2.ZERO, s), Color(color.r * 0.12, color.g * 0.14, color.b * 0.20, 0.95))
	draw_rect(Rect2(Vector2.ZERO, s), Color(color.r, color.g, color.b, 0.55), false, 2.0)
	for i in 3:
		var t := float(i) / 3.0
		draw_circle(center, radius * (1.5 - t * 0.4),
			Color(color.r, color.g, color.b, 0.05 * (1.0 - t)))

	PowerArt.draw(self, art_id, center, radius, color, color_secondary, _phase)

	# Level pips along the bottom edge, matching the HUD slot language.
	var count := mini(max_level, 8)
	if count <= 0:
		return
	var width := s.x - 16.0
	var pip := width / float(count)
	var y := s.y - 11.0
	for i in count:
		var x := 8.0 + pip * float(i)
		var filled := i < level
		draw_rect(Rect2(Vector2(x + 1.0, y), Vector2(pip - 2.0, 5.0)),
			color if filled else Color(1, 1, 1, 0.15))
