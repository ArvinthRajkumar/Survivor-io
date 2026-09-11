class_name MenuStage
extends Control
## The animated operative on the main menu.
##
## It is the same PlayerVisual the run uses, not a portrait and not a still:
## the character that walks across the title screen is the one the player is
## about to control, wearing the accent colours of whoever is selected and
## swinging the weapon they are carrying. Changing operative on the roster
## changes who is pacing here.
##
## The stage drives it with a fabricated patrol - walk, turn, occasionally cut -
## because PlayerVisual takes movement as input and does not care whether that
## movement came from a thumb or from a script.

## How far either side of centre the operative walks, as a fraction of width.
const WALK_SPAN := 0.30
const WALK_SPEED := 96.0
## Seconds spent standing at each end of the walk before turning back.
const PAUSE_TIME := 1.1
## Roughly how often the idle cut happens while standing.
const CUT_INTERVAL := 3.4

var _visual: Node2D
var _phase: float = 0.0
var _offset: float = 0.0
var _direction: float = 1.0
var _pause_left: float = 0.0
var _cut_timer: float = CUT_INTERVAL
var _hero: HeroData


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_visual = preload("res://scripts/player/PlayerVisual.gd").new()
	# Larger than in play: at run scale the character is a thumbnail, and this is
	# the one place in the app where there is room to actually look at them.
	_visual.scale = Vector2(4.1, 4.1)
	add_child(_visual)
	set_hero(_hero)


func set_hero(hero: HeroData) -> void:
	_hero = hero
	if _visual != null:
		_visual.call("configure", hero)


func _process(delta: float) -> void:
	if _visual == null:
		return
	_phase += delta
	queue_redraw()

	var span := size.x * WALK_SPAN
	var velocity := Vector2.ZERO
	if _pause_left > 0.0:
		_pause_left -= delta
		_cut_timer -= delta
		if _cut_timer <= 0.0:
			_cut_timer = CUT_INTERVAL
			# The idle cut faces the way the operative is standing, so the blade
			# never swings through their own back.
			_visual.call("play_slash", Vector2(_direction, 0.0), 1.0, 1.35, false)
	else:
		_offset += _direction * WALK_SPEED * delta
		velocity = Vector2(_direction * WALK_SPEED, 0.0)
		if absf(_offset) >= span:
			_offset = clampf(_offset, -span, span)
			_direction = -_direction
			_pause_left = PAUSE_TIME

	# A small bob keeps the character alive while standing still, which is most
	# of the time on a menu nobody is touching.
	var bob := sin(_phase * 2.1) * 3.0
	_visual.position = Vector2(size.x * 0.5 + _offset, size.y * 0.60 + bob)
	_visual.call("set_motion", Vector2(velocity.x / WALK_SPEED, 0.0), velocity, delta)


## Backdrop for the character: a lit floor panel with a grid running back from
## it, so the operative is standing somewhere rather than floating on the menu.
func _draw() -> void:
	var accent: Color = _hero.accent if _hero != null else Palette.ACCENT
	var floor_y := size.y * 0.78
	# Pool of light.
	for i in 4:
		var t := float(i) / 3.0
		draw_circle(Vector2(size.x * 0.5, floor_y), size.x * (0.20 + 0.22 * t),
			Color(accent.r, accent.g, accent.b, 0.05 * (1.0 - t)))
	# Floor line, brightest under the operative and fading out to both sides.
	for i in 12:
		var t2 := float(i) / 11.0
		var x0 := lerpf(size.x * 0.04, size.x * 0.96, t2)
		var x1 := x0 + size.x * 0.065
		var fade := 1.0 - absf(t2 - 0.5) * 1.7
		draw_line(Vector2(x0, floor_y), Vector2(x1, floor_y),
			Color(accent.r, accent.g, accent.b, maxf(0.0, 0.5 * fade)), 2.5, true)
	# Receding grid behind the floor, drifting so the stage is never static.
	var drift := fmod(_phase * 10.0, 46.0)
	for i in 9:
		var x := -46.0 + drift + float(i) * 46.0
		draw_line(Vector2(x, floor_y), Vector2(lerpf(size.x * 0.5, x, 2.1), size.y * 0.06),
			Color(accent.r, accent.g, accent.b, 0.055), 1.5, true)
