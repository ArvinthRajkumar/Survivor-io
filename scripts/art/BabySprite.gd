class_name BabySprite
extends RefCounted
## Baby, drawn from the supplied character art rather than reconstructed.
##
## Every other operative in this game is procedural geometry. Baby is not: she
## is a specific illustration and the brief was to use it exactly, so nothing
## here redraws her. What it does is cut her into pieces and move them.
##
## `tools/cut_baby.py` lifts the front-facing figure off the character sheet,
## splits her at the skirt hem into an upper body and two legs, and packs those
## into `assets/sprites/baby.png`. The constants below are the numbers that
## script prints. Re-run it against a new sheet and paste them back.
##
## Everything is in *figure pixels* - the coordinate space of the un-split
## 236x768 figure - and scaled at draw time, so the same rig serves a 60px
## character in a run and a 200px portrait on a card.

const TEX: Texture2D = preload("res://assets/sprites/baby.png")

## Sampled off the character sheet. Nothing here draws her, but the rest of the
## game needs her colours: the HUD tints, the run's hair-coloured effects and
## the roster card all key off them.
const SKIN := Color(0.880, 0.660, 0.520)
const HAIR := Color(0.090, 0.066, 0.060)
const ACCENT := Color(0.360, 0.322, 0.218)

## The figure before it was cut up. Parts are positioned in this space.
const FIGURE := Vector2(236.0, 768.0)

const RECT_UPPER := Rect2(0.0, 0.0, 236.0, 447.0)
const ORIGIN_UPPER := Vector2(0.0, 0.0)
const RECT_LEG_L := Rect2(0.0, 447.0, 127.0, 339.0)
const ORIGIN_LEG_L := Vector2(11.0, 429.0)
const RECT_LEG_R := Rect2(127.0, 447.0, 93.0, 317.0)
const ORIGIN_LEG_R := Vector2(123.0, 429.0)

## Joints. The upper body leans and breathes about the waist; each leg swings
## about its own hip, which is the centroid of that leg's topmost rows.
const WAIST := Vector2(124.0, 440.0)
const HIP_L := Vector2(82.0, 429.0)
const HIP_R := Vector2(180.0, 429.0)

## Where a weapon sits when she is holding one, and where the head is. Both are
## read off the figure, not guessed.
const HAND := Vector2(196.0, 300.0)
const HEAD := Vector2(132.0, 74.0)
## Half the head height, in figure pixels - the portrait scales from this so a
## caller can ask for "a head this big" the way it could with the procedural
## portraits.
const HEAD_R := 46.0


## Draw one atlas piece with its pivot landing on `at`.
##
## Inside the transform one unit is one figure pixel, so the part rect is
## positioned by `origin - pivot` and needs no further arithmetic.
static func _part(ci: CanvasItem, rect: Rect2, origin: Vector2, pivot: Vector2,
		at: Vector2, rot: float, scale: Vector2, tint: Color) -> void:
	ci.draw_set_transform(at, rot, scale)
	ci.draw_texture_rect_region(TEX, Rect2(origin - pivot, rect.size), rect, tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The whole figure, standing on `ground` (the point between her feet) and
## `height` pixels tall.
##
## `facing` flips her horizontally. `lean` tips the upper body, `squash` is the
## usual squash-and-stretch (positive squashes), `swing` is the walk cycle in
## radians and `drag` leans the upper body against the direction of travel so
## the mass has some lag in it.
static func draw_figure(ci: CanvasItem, ground: Vector2, height: float,
		facing: float = 1.0, lean: float = 0.0, squash: float = 0.0,
		swing: float = 0.0, drag: Vector2 = Vector2.ZERO,
		tint: Color = Color.WHITE) -> void:
	var k := height / FIGURE.y
	var flip := signf(facing) if absf(facing) > 0.01 else 1.0
	var sc := Vector2(k * flip, k)

	# Legs first: they pass behind the skirt, which is part of the upper piece.
	_part(ci, RECT_LEG_L, ORIGIN_LEG_L, HIP_L,
		_place(ground, HIP_L, k, flip), -swing * flip, sc, tint)
	_part(ci, RECT_LEG_R, ORIGIN_LEG_R, HIP_R,
		_place(ground, HIP_R, k, flip), swing * flip, sc, tint)
	# The lean is damped hard. The procedural cast is a stack of blobs and can
	# tip a long way before it looks wrong; a full figure at the same angle
	# reads as falling over.
	var tip := clampf(lean * 0.45 + drag.x * 0.004, -0.16, 0.16)
	_part(ci, RECT_UPPER, ORIGIN_UPPER, WAIST,
		_place(ground, WAIST, k, flip) + Vector2(drag.x * 0.30 * flip, drag.y * 0.20),
		tip * flip,
		Vector2(sc.x * (1.0 - squash), sc.y * (1.0 + squash)), tint)


## Figure-space point to local canvas space, with the figure standing on
## `ground` at scale `k`.
static func _place(ground: Vector2, p: Vector2, k: float, flip: float) -> Vector2:
	return ground + Vector2((p.x - FIGURE.x * 0.5) * k * flip, (p.y - FIGURE.y) * k)


## Where she is holding a weapon, in local canvas space, for the same arguments
## `draw_figure` was called with.
static func hand_at(ground: Vector2, height: float, facing: float = 1.0) -> Vector2:
	var k := height / FIGURE.y
	var flip := signf(facing) if absf(facing) > 0.01 else 1.0
	return _place(ground, HAND, k, flip)


## Head-and-shoulders, for the roster card and the HUD slot. `r` matches the
## procedural portraits: her head comes out about 0.9*r across, centred a
## little above `c`, so she frames the same way the rest of the cast does.
static func draw_bust(ci: CanvasItem, c: Vector2, r: float, phase: float) -> void:
	var k := r * 0.45 / HEAD_R
	# A slow breath, and the head drifting a hair with it.
	var breath := sin(phase * 1.15) * r * 0.008
	var at := c + Vector2(0.0, -r * 0.12 + breath)
	ci.draw_set_transform(at, 0.0, Vector2(k, k))
	ci.draw_texture_rect_region(TEX, Rect2(-HEAD, RECT_UPPER.size), RECT_UPPER)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
