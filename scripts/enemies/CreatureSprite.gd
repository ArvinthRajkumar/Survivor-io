class_name CreatureSprite
extends Sprite2D
## Draws one enemy from the baked creature atlas.
##
## Replaces the procedural body Enemy used to draw. That was choppy and
## expensive at the same time: a creature is 7-18 draw commands and the renderer
## resubmits every one of them each frame whether or not `_draw` re-ran, so
## metering redraws saved only the GDScript while the animation visibly stepped.
## One textured quad costs the same as one polygon and animates at the frame rate
## for nothing.
##
## The atlas is baked as luminance and tinted per archetype through `modulate`,
## so one sheet dresses the whole roster. There is deliberately no material: a
## per-instance ShaderMaterial carrying three role colours was tried first and
## its uniforms do not reliably reach the renderer for a pooled node configured
## before it enters the tree - the creature comes out drawn in the raw mask.
## Tinting also lets the swarm batch, which 260 unique materials never could.

const ATLAS := preload("res://assets/sprites/creatures.png")

## How far above 1.0 the tint is pushed for a damage flash. Modulate multiplies,
## so overdriving it is what blows the sprite out to white.
const FLASH_GAIN := 3.2

var _frame: int = -1
var _columns: int = 1
var _tint := Color.WHITE


func _init() -> void:
	texture = ATLAS
	region_enabled = true
	centered = true
	_columns = maxi(1, ATLAS.get_width() / EnemyArt.FRAME_SIZE)
	set_frame_index(0)


## The archetype's colour. `secondary` shades it slightly toward the darker of
## the pair so two enemies of the same family are not identical, and an elite is
## pushed toward gold.
func set_palette(color: Color, secondary: Color, elite: bool) -> void:
	_tint = color.lerp(secondary, 0.18)
	if elite:
		_tint = _tint.lerp(Color(1.0, 0.86, 0.35), 0.65)
	modulate = _tint


## Scales the quad so the creature's baked radius lands on `radius` on screen.
func set_radius(radius: float) -> void:
	var s := radius / EnemyArt.BAKE_RADIUS
	scale = Vector2(s, s)


## Mirrors horizontally. The atlas holds one facing; flipping is free and halves
## the sheet.
func set_facing_left(value: bool) -> void:
	flip_h = value


func set_flash(amount: float) -> void:
	var k := clampf(amount, 0.0, 1.0)
	modulate = _tint.lerp(Color(FLASH_GAIN, FLASH_GAIN, FLASH_GAIN), k)


func set_frame_index(index: int) -> void:
	if index == _frame:
		return
	_frame = index
	var size := EnemyArt.FRAME_SIZE
	region_rect = Rect2(
		float((index % _columns) * size), float((index / _columns) * size),
		float(size), float(size))
