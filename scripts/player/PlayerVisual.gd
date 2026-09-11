class_name PlayerVisual
extends Node2D
## The operative: a chibi humanoid drawn procedurally, one _draw() per frame.
##
## Proportions are deliberately exaggerated (the head is about as big as the
## whole torso) so the character stays readable at phone size with a hundred
## enemies on screen. Everything that makes it feel alive is layered on top of
## that silhouette rather than baked into it:
##
##  * the operative always faces the camera — only the left/right mirror and the
##    lean change with movement, so the player's own character is never a blank
##    silhouette to look at;
##  * a scarf simulated as a lagging chain, so direction changes whip it;
##  * squash and stretch driven by acceleration, plus a lean into the turn;
##  * footfall dust timed to the actual step cycle;
##  * the weapon carried in: stowed across the back at rest, and brought up and
##    used in the hand on every attack, drawn from the same geometry as its HUD
##    icon so the thing in the operative's hands and the thing on the card are
##    unmistakably the same object.
##
## Each of the eight starting weapons has its own attack: a katana swings, a
## spear thrusts, a revolver kicks, a bow draws and looses, a hammer comes down
## overhead. That is not decoration - a player who has picked one of eight
## weapons should be able to see which one they picked without reading the HUD.
##
## The API stays small — configure / set_weapon / set_motion / play_attack /
## flash_hurt / set_shielded / set_dead — so Player.gd never has to know how any
## of it works.

# Chibi proportions, about two and a half heads tall. The head used to be so
# large and sat so low that it covered the torso outright; the body needs to be
# visible under it for any of the animation to read.
const HEAD_RADIUS := 17.0
const BODY_WIDTH := 12.5
const BODY_HEIGHT := 21.0
const HIP_Y := 14.0
const STEP_RATE := 10.5
const SCARF_SEGMENTS := 7
const SCARF_LENGTH := 6.0
## Baby's sprite: how tall she is drawn and where her feet land relative to the
## body origin, matched to the procedural cast so the two share a shadow.
const BABY_HEIGHT := 94.0
const BABY_FOOT_Y := 38.0
const MAX_DUST := 10
const TRAIL_LENGTH := 7

## How long each attack takes, and how far it throws the body. A shot pushes
## back rather than forward, which is the whole read on a heavy gun.
const POSE_SPAN: Array[float] = [0.24, 0.20, 0.16, 0.30, 0.26, 0.34, 0.22]
const POSE_LUNGE: Array[float] = [5.0, 9.0, -3.5, -2.0, 4.0, 6.0, -1.5]

var accent: Color = Palette.ACCENT
var accent_secondary: Color = Palette.ACCENT_WARM
var hero_shape: int = 2

var _skin: Color = Color(0.99, 0.87, 0.78)
var _hair: Color = Color(0.16, 0.18, 0.28)

var _phase: float = 0.0
var _step: float = 0.0
var _thrust: float = 0.0
var _facing: float = 1.0
var _lean: float = 0.0
var _squash: float = 0.0
var _last_speed: float = 0.0
var _hurt_flash: float = 0.0
var _shielded: bool = false
var _dead: bool = false
var _death_time: float = 0.0
var _blink: float = 0.0
var _next_blink: float = 2.0

## Secondary motion. Hair and cloth do not travel with the body: they lag it,
## overshoot when it stops and settle afterwards. One critically-ish damped
## spring, integrated per frame, drives all of it. This is the single biggest
## thing that makes a small character look alive rather than like a sticker
## being slid around the screen, and it costs two vectors.
var _drag: Vector2 = Vector2.ZERO
var _drag_vel: Vector2 = Vector2.ZERO
## Idle breath, and a vertical spring that takes a kick on every footfall.
var _breath: float = 0.0
var _bounce: float = 0.0
var _bounce_vel: float = 0.0
## World velocity, kept so the spring has something to chase.
var _vel: Vector2 = Vector2.ZERO
## Where the operative is looking, in head radii. Follows the facing normally
## and snaps to the aim while attacking.
var _gaze: Vector2 = Vector2.ZERO

## How the operative uses whatever they are holding. The weapon decides which
## of these it plays; several weapons share one.
enum Pose { SWING, THRUST, SHOOT, DRAW, THROW, SMASH, SPRAY }

## Attack state.
var _pose: int = Pose.SWING
var _slash_time: float = 0.0
var _slash_span: float = 0.22
var _slash_dir: Vector2 = Vector2.RIGHT
var _slash_sign: float = 1.0
var _slash_arc: float = 2.0
var _slash_spin: bool = false
var _lunge: Vector2 = Vector2.ZERO
## Where the lunge is heading once the anticipation frame has passed.
var _wind: Vector2 = Vector2.ZERO
## Which weapon is in the operative's hands, as a PowerData id. Drives both the
## thing drawn in the hand and the thing stowed on the back.
var _weapon: StringName = &"katana"

## Which passives the operative is carrying, as booleans keyed by power id.
## A passive that only exists in a stat sheet may as well not have been picked,
## so the ones with a shape worth drawing get one on the character.
var _tells: Dictionary = {}
## Motes rising off the operative for the regeneration passive.
var _motes: Array[Dictionary] = []
var _mote_timer: float = 0.0

var _scarf: PackedVector2Array = PackedVector2Array()
var _dust: Array[Dictionary] = []
var _trail: Array[Vector2] = []
var _last_step_side: int = 0


func _ready() -> void:
	z_index = 10
	_reset_scarf()


func configure(hero: HeroData) -> void:
	if hero != null:
		accent = hero.accent
		accent_secondary = hero.accent_secondary
		hero_shape = hero.portrait_shape
		# Hair takes a deep, desaturated cast of the accent so each operative
		# reads as a different person without needing a separate palette.
		_hair = Color(accent.r * 0.30 + 0.06, accent.g * 0.26 + 0.07, accent.b * 0.34 + 0.12)
		_skin = HeroPortrait._skin_of(hero_shape)
	queue_redraw()


# --- State fed by Player.gd -------------------------------------------------

func set_motion(dir: Vector2, velocity: Vector2, delta: float) -> void:
	var speed := velocity.length()
	_thrust = clampf(dir.length(), 0.0, 1.0)
	if absf(dir.x) > 0.12:
		_facing = signf(dir.x)
	_lean = clampf(dir.x * 0.20, -0.24, 0.24)
	# Acceleration drives squash and stretch: speeding up stretches the body
	# along its travel, slamming to a stop squashes it.
	_vel = velocity
	var accel := (speed - _last_speed) / maxf(0.0001, delta)
	_last_speed = speed
	_squash = clampf(lerpf(_squash, clampf(accel / 5200.0, -0.22, 0.22), clampf(delta * 9.0, 0.0, 1.0)), -0.3, 0.3)
	_update_scarf(delta, velocity)
	if _trail.size() > TRAIL_LENGTH:
		_trail.pop_front()
	_trail.append(global_position)


## Called by KatanaPower the instant a cut is spawned, so the blade in the
## operative's hands and the damage on the field are always the same event.
## Sets which weapon the operative is carrying, so the right thing is stowed on
## their back and appears in their hand.
func set_weapon(id: StringName) -> void:
	_weapon = id
	queue_redraw()


## Plays one attack. `pose` is how the body moves; the weapon drawn in the hand
## comes from set_weapon().
##
## `handedness` alternates the swing direction so a held attack reads as a combo
## rather than one animation looping, and `arc` is how wide a swing travels.
## Both are ignored by the poses they mean nothing to.
func play_attack(pose: int, dir: Vector2, handedness: float = 1.0, arc: float = 2.0,
		spin: bool = false) -> void:
	_pose = pose
	_slash_dir = dir.normalized() if dir.length_squared() > 0.001 else Vector2.RIGHT
	_slash_sign = 1.0 if handedness >= 0.0 else -1.0
	_slash_arc = arc
	_slash_spin = spin
	_slash_span = POSE_SPAN[pose]
	if spin:
		_slash_span += 0.10
	_slash_time = _slash_span
	if absf(_slash_dir.x) > 0.2:
		_facing = signf(_slash_dir.x)
	# A short lunge sells the commitment. A shot recoils backward instead.
	# The lunge starts *against* the strike: a frame of anticipation is what
	# makes a hit feel like it was thrown rather than teleported into place.
	var push: float = POSE_LUNGE[pose]
	_lunge = _slash_dir * -push * 0.45
	_wind = _slash_dir * push


## Kept for the katana, which is the one weapon whose behaviour predates poses.
func play_slash(dir: Vector2, handedness: float, arc: float, spin: bool) -> void:
	play_attack(Pose.SWING, dir, handedness, arc, spin)


## Tells the operative which passives they are carrying. Ids are PowerData ids;
## anything without a tell is simply ignored.
func set_passive_tells(ids: Array) -> void:
	_tells.clear()
	for id in ids:
		_tells[StringName(id)] = true
	queue_redraw()


func flash_hurt() -> void:
	_hurt_flash = 1.0


func set_shielded(value: bool) -> void:
	_shielded = value
	queue_redraw()


func set_dead(value: bool) -> void:
	_dead = value
	if value:
		_slash_time = 0.0
	queue_redraw()


# --- Simulation -------------------------------------------------------------

func _process(delta: float) -> void:
	_phase += delta
	if _hurt_flash > 0.0:
		_hurt_flash = maxf(0.0, _hurt_flash - delta * 3.2)
	if _slash_time > 0.0:
		_slash_time = maxf(0.0, _slash_time - delta)
	if _wind != Vector2.ZERO:
		# Snap through the anticipation into the lunge, then let it decay.
		_lunge = _lunge.lerp(_wind, clampf(delta * 26.0, 0.0, 1.0))
		if _lunge.distance_to(_wind) < _wind.length() * 0.18:
			_wind = Vector2.ZERO
	else:
		_lunge = _lunge.lerp(Vector2.ZERO, clampf(delta * 9.0, 0.0, 1.0))
	if _dead:
		_death_time = minf(1.0, _death_time + delta * 2.2)
	else:
		_death_time = maxf(0.0, _death_time - delta * 4.0)

	# The step cycle only advances while actually moving, so the character
	# settles into an idle breath instead of marching on the spot.
	var before := _step
	_step += delta * STEP_RATE * _thrust
	_emit_step_dust(before, _step)
	_thrust = lerpf(_thrust, 0.0, clampf(delta * 4.0, 0.0, 1.0))
	_lean = lerpf(_lean, 0.0, clampf(delta * 6.0, 0.0, 1.0))
	_squash = lerpf(_squash, 0.0, clampf(delta * 5.0, 0.0, 1.0))

	_tick_secondary(delta)
	_tick_blink(delta)
	_tick_dust(delta)
	_tick_motes(delta)
	queue_redraw()


## Everything that follows the body rather than being driven by it.
func _tick_secondary(delta: float) -> void:
	var step := clampf(delta, 0.0, 1.0 / 30.0)

	# Hair lag. The target is behind the direction of travel, so the mass
	# streams out behind a sprint and swings across the body on a direction
	# change. Damping is deliberately light: the overshoot when she stops is
	# the part that reads.
	var target := (-_vel * 0.021).limit_length(9.0)
	_drag_vel += (target - _drag) * 46.0 * step
	_drag_vel /= 1.0 + 8.5 * step
	_drag += _drag_vel * step
	_drag = _drag.limit_length(11.0)

	# Breath, and the vertical spring the footfalls kick.
	_breath = sin(_phase * 1.9)
	_bounce_vel -= _bounce * 150.0 * step
	_bounce_vel /= 1.0 + 11.0 * step
	_bounce += _bounce_vel * step

	# Gaze: toward the aim while swinging, otherwise the way she is walking.
	var want := Vector2(_facing * 0.55, 0.0)
	if _slash_time > 0.0:
		want = Vector2(_slash_dir.x, _slash_dir.y * 0.6) * 0.85
	elif _thrust > 0.2:
		want = Vector2(_facing * 0.7, -0.12)
	_gaze = _gaze.lerp(want, clampf(delta * 9.0, 0.0, 1.0))


func _tick_blink(delta: float) -> void:
	_next_blink -= delta
	if _next_blink <= 0.0:
		_next_blink = randf_range(2.4, 5.2)
		_blink = 0.14
	if _blink > 0.0:
		_blink = maxf(0.0, _blink - delta)


## A puff of dust each time a foot passes through the bottom of its arc, and a
## kick to the vertical spring so the body compresses on the plant.
func _emit_step_dust(before: float, after: float) -> void:
	if _thrust < 0.35 or _dead:
		return
	if int(floor(after / PI)) != int(floor(before / PI)):
		_bounce_vel += 1.35 * _thrust
	var side := int(floor(after / PI))
	if side == _last_step_side or int(floor(before / PI)) == side:
		return
	_last_step_side = side
	if _dust.size() >= MAX_DUST:
		_dust.pop_front()
	_dust.append({
		"pos": global_position + Vector2(randf_range(-7.0, 7.0), 26.0),
		"age": 0.0,
		"size": randf_range(4.0, 7.0),
		"drift": Vector2(randf_range(-14.0, 14.0), randf_range(-6.0, 2.0)),
	})


func _tick_dust(delta: float) -> void:
	var i := _dust.size() - 1
	while i >= 0:
		var puff := _dust[i]
		puff["age"] = float(puff["age"]) + delta
		puff["pos"] = (puff["pos"] as Vector2) + (puff["drift"] as Vector2) * delta
		if float(puff["age"]) > 0.45:
			_dust.remove_at(i)
		i -= 1


## Vital Weave's regeneration, as motes lifting off the operative. Spawned on a
## timer rather than per frame so the density does not change with frame rate.
func _tick_motes(delta: float) -> void:
	var i := _motes.size() - 1
	while i >= 0:
		var mote := _motes[i]
		mote["age"] = float(mote["age"]) + delta
		mote["pos"] = (mote["pos"] as Vector2) + (mote["drift"] as Vector2) * delta
		if float(mote["age"]) > 1.1:
			_motes.remove_at(i)
		i -= 1
	if not _tells.has(&"vital_weave") or _dead:
		return
	_mote_timer -= delta
	if _mote_timer > 0.0:
		return
	_mote_timer = 0.34
	if _motes.size() >= 8:
		return
	_motes.append({
		"pos": Vector2(randf_range(-13.0, 13.0), randf_range(2.0, 14.0)),
		"age": 0.0,
		"size": randf_range(1.8, 3.2),
		"drift": Vector2(randf_range(-5.0, 5.0), randf_range(-22.0, -13.0)),
	})


func _reset_scarf() -> void:
	_scarf.resize(SCARF_SEGMENTS)
	for i in SCARF_SEGMENTS:
		_scarf[i] = global_position


## Lagging chain: each knot chases the one in front of it, so a hard turn snaps
## the scarf out sideways and running straight streams it behind.
func _update_scarf(delta: float, velocity: Vector2) -> void:
	if _scarf.size() != SCARF_SEGMENTS:
		_reset_scarf()
	# Anchored off the far shoulder and pushed away from the body, so the tail
	# hangs clear of the torso instead of lying across the chest like a sash.
	var anchor := global_position + Vector2(-11.0 * _facing, -BODY_HEIGHT * 0.72)
	_scarf[0] = anchor
	var follow := clampf(delta * 24.0, 0.0, 1.0)
	# Gravity is always on, so the tail hangs at rest and only streams when the
	# operative is actually moving. Without it the scarf stands straight up the
	# moment the player runs downward, which reads as an antenna, not cloth.
	var drift := Vector2(-3.0 * _facing, 5.0)
	if velocity.length_squared() > 400.0:
		drift += -velocity.normalized() * 9.0
	# Kept below the shoulders on purpose. Physically the tail should stream
	# straight up when the operative runs down the screen, but on a top-down
	# view that draws a rigid spike out of the head — it reads as an antenna,
	# not cloth. Biasing it downward costs nothing and always looks like a scarf.
	drift.y = maxf(drift.y, 1.2)
	for i in range(1, SCARF_SEGMENTS):
		var lead := _scarf[i - 1]
		# Knots further down the tail lag more, which is what bends the chain
		# when the operative turns. A uniform chain just draws a stiff plank.
		var slack := 1.0 - 0.10 * float(i)
		var knot: Vector2 = _scarf[i].lerp(lead + drift, follow * slack)
		# Links hold their length exactly, so the tail always reads as cloth of
		# a fixed size rather than concertinaing into a blob when it slows down.
		var offset := knot - lead
		if offset.length_squared() < 0.01:
			offset = drift.normalized() if drift.length_squared() > 0.01 else Vector2.DOWN
		_scarf[i] = lead + offset.normalized() * SCARF_LENGTH


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	var tint := accent
	if _hurt_flash > 0.0:
		tint = tint.lerp(Palette.DANGER, _hurt_flash * 0.8)
	if _dead:
		tint = tint.darkened(0.45)

	# Idle breath, the run's vertical bob, and the spring each footfall kicks.
	var bob := _breath * 1.2 * (1.0 - _thrust) + absf(sin(_step)) * -3.4 * _thrust
	bob += _bounce * 2.2
	var slump := _death_time * 15.0
	var origin := Vector2(0.0, bob + slump) + _lunge
	var lean := _lean + _death_time * 0.5 * _facing + _slash_lean()
	var swing := sin(_step) * 0.6 * _thrust

	_draw_shadow(slump)
	_draw_dust()
	_draw_passive_aura(origin)
	if _thrust > 0.3 and not _dead:
		_draw_speed_trail(tint)

	# Squash and stretch is applied to everything above the shadow so the body
	# deforms as one. On top of the acceleration term, the run squashes into
	# each footfall and the idle breath swells the chest a little.
	var gait := (1.0 - absf(sin(_step))) * 0.045 * _thrust
	var puff := _breath * 0.012 * (1.0 - _thrust)
	var sq := clampf(_squash + gait - puff, -0.30, 0.30)

	if hero_shape == 5:
		# Baby is the supplied illustration, rigged rather than redrawn, so she
		# carries her own squash instead of the canvas transform doing it.
		_draw_baby(origin, lean, sq)
	else:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 - sq, 1.0 + sq))
		if _slash_time <= 0.0 and not _dead:
			_draw_sheath(origin, lean, tint)
		_draw_scarf_tail()
		_draw_arm(origin, lean, swing, tint, true)
		_draw_leg(origin, lean, -swing, tint, true)
		_draw_torso(origin, lean, tint)
		_draw_leg(origin, lean, swing, tint, false)
		_draw_collar(origin, lean)
		_draw_head(origin, lean, tint)
		_draw_sword_arm(origin, lean, swing, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_passive_motes()
	if _shielded:
		_draw_shield()


## The passives that are worth a picture, drawn under the operative.
##
## Only a handful of the twelve get one. A tell has to be legible at phone size
## behind a hundred enemies and has to say something a player can act on, which
## rules out anything that is really just a number going up.
func _draw_passive_aura(origin: Vector2) -> void:
	if _dead:
		return
	if _tells.has(&"ablative_shell"):
		# Armour plates orbiting at hip height, so the operative looks armoured
		# rather than merely tougher.
		var spin := _phase * 0.9
		for i in 3:
			var a := TAU * float(i) / 3.0 + spin
			var at := origin + Vector2(cos(a) * 19.0, 4.0 + sin(a) * 6.0)
			var facing_us := sin(a) > 0.0
			var alpha := 0.55 if facing_us else 0.22
			draw_colored_polygon(PackedVector2Array([
				at + Vector2(-3.4, -5.0), at + Vector2(3.4, -5.0),
				at + Vector2(4.6, 0.0), at + Vector2(3.4, 5.0),
				at + Vector2(-3.4, 5.0), at + Vector2(-4.6, 0.0),
			]), Color(0.72, 0.84, 1.0, alpha))
	if _tells.has(&"long_fuse"):
		# Embers guttering at the feet: everything this operative leaves behind
		# burns for longer.
		for i in 3:
			var t := fposmod(_phase * 0.8 + float(i) * 0.33, 1.0)
			var e := origin + Vector2(sin(_phase * 2.0 + float(i) * 2.1) * 11.0, 14.0 - t * 16.0)
			draw_circle(e, 2.2 * (1.0 - t), Color(1.0, 0.62, 0.26, 0.75 * (1.0 - t)))
	if _tells.has(&"omen_dice"):
		# A slow gold sparkle, so good luck has a look.
		var k := fposmod(_phase * 0.45, 1.0)
		if k < 0.35:
			var glint := sin(k / 0.35 * PI)
			var at2 := origin + Vector2(cos(_phase * 1.3) * 22.0, -26.0 + sin(_phase * 2.2) * 5.0)
			draw_circle(at2, 3.4 * glint, Color(1.0, 0.88, 0.42, 0.85 * glint))
			draw_circle(at2, 1.5 * glint, Color(1, 1, 1, glint))


## Regeneration motes, drawn over the body so they read as coming off it.
func _draw_passive_motes() -> void:
	for mote in _motes:
		var age := float(mote["age"])
		var fade := clampf(1.0 - age / 1.1, 0.0, 1.0)
		draw_circle(mote["pos"] as Vector2, float(mote["size"]) * fade,
			Color(0.55, 1.0, 0.72, 0.8 * fade))


## How far the body twists into a swing: hard at the strike, easing back out.
func _slash_lean() -> float:
	if _slash_time <= 0.0:
		return 0.0
	var t := _slash_time / _slash_span
	return _slash_sign * 0.42 * t * t



## A soft contact shadow that fades out at its edge. A hard-edged ellipse under
## a rounded character is the single most obvious tell that the art is flat.
func _draw_shadow(slump: float) -> void:
	var lift := 1.0 - clampf(absf(sin(_step)) * _thrust * 0.22, 0.0, 0.25)
	var at := Vector2(0.0, 40.0 + slump * 0.4)
	Chibi.soft(self, at, 21.0 * lift, 7.4 * lift, Color(0.0, 0.0, 0.0, 0.34), 28)
	Chibi.soft(self, at, 12.0 * lift, 4.2 * lift, Color(0.0, 0.0, 0.0, 0.22), 20)

func _draw_dust() -> void:
	for puff in _dust:
		var t := clampf(float(puff["age"]) / 0.45, 0.0, 1.0)
		var p := to_local(puff["pos"] as Vector2)
		draw_circle(p, float(puff["size"]) * (0.6 + t), Color(0.75, 0.82, 0.95, 0.22 * (1.0 - t)))


## Ghosted silhouettes behind the character while sprinting.
func _draw_speed_trail(tint: Color) -> void:
	for i in range(_trail.size() - 1):
		var t := float(i) / float(maxi(1, _trail.size()))
		var p := to_local(_trail[i])
		draw_circle(p + Vector2(0.0, -8.0), 10.0 * t + 3.0,
			Color(tint.r, tint.g, tint.b, 0.09 * t))


## The saya worn across the back, visible whenever the blade is not in hand.
func _draw_sheath(origin: Vector2, lean: float, tint: Color) -> void:
	# Angled so it clears the head silhouette — a weapon hidden entirely behind
	# the body might as well not be drawn.
	var hip := origin + Vector2(-12.0 * _facing, 7.0).rotated(lean)
	var tip := origin + Vector2(26.0 * _facing, -BODY_HEIGHT - 13.0).rotated(lean)
	match _weapon:
		&"revolver", &"machine_pistol":
			# A holster at the hip rather than a scabbard on the back.
			var holster := origin + Vector2(13.0 * _facing, 9.0).rotated(lean)
			draw_line(holster, holster + Vector2(2.0 * _facing, 11.0).rotated(lean),
				Color(0.09, 0.10, 0.15), 9.0, true)
			draw_circle(holster + Vector2(0.0, -2.0).rotated(lean), 3.2, accent_secondary)
			return
		&"longbow":
			# Strung across the back, so the curve reads even side-on.
			var arc_pts := PackedVector2Array()
			for i in 7:
				var u := float(i) / 6.0
				var along := hip.lerp(tip, u)
				var bend := sin(u * PI) * 7.0 * _facing
				arc_pts.append(along + Vector2(bend, 0.0))
			draw_polyline(arc_pts, tint.darkened(0.42), 4.0, true)
			draw_line(hip, tip, accent_secondary.darkened(0.3), 1.6, true)
			return
		&"chakram":
			var on_back := origin + Vector2(-6.0 * _facing, -BODY_HEIGHT * 0.2).rotated(lean)
			draw_arc(on_back, 9.0, 0.0, TAU, 14, tint.darkened(0.35), 3.4, true)
			draw_arc(on_back, 4.5, 0.0, TAU, 10, accent_secondary.darkened(0.2), 2.0, true)
			return
		&"flamethrower":
			# A tank, not a blade.
			var tank := origin + Vector2(-11.0 * _facing, -BODY_HEIGHT * 0.35).rotated(lean)
			draw_line(tank, tank + Vector2(0.0, 15.0).rotated(lean),
				Color(0.09, 0.10, 0.15), 11.0, true)
			draw_line(tank, tank + Vector2(0.0, 15.0).rotated(lean),
				tint.darkened(0.45), 7.0, true)
			draw_circle(tank + Vector2(0.0, -1.0).rotated(lean), 3.0, accent_secondary)
			return
		_:
			pass
	# Katana, spear and hammer all stow the same way: a haft across the back.
	var girth := 8.0
	if _weapon == &"warhammer":
		girth = 9.5
	draw_line(hip, tip, Color(0.09, 0.10, 0.15), girth, true)
	draw_line(hip, tip, tint.darkened(0.5), girth * 0.55, true)
	if _weapon == &"warhammer":
		# The head, so a stowed hammer is not a stowed sword.
		draw_line(tip - (tip - hip).normalized() * 3.0, tip,
			accent_secondary.darkened(0.1), 11.0, true)
		return
	if _weapon == &"spear":
		var point := tip + (tip - hip).normalized() * 5.0
		draw_line(tip, point, accent_secondary, 4.0, true)
		return
	# Two binding cords and the pommel cap.
	for t in [0.35, 0.62]:
		var p: Vector2 = hip.lerp(tip, t)
		draw_circle(p, 2.6, accent_secondary.darkened(0.15))
	draw_circle(tip, 3.4, accent_secondary)


func _draw_scarf_tail() -> void:
	if _scarf.size() < 3:
		return
	var pts := PackedVector2Array()
	for p in _scarf:
		pts.append(to_local(p))
	# The ripple is added here rather than in the simulation: displacing the
	# knots themselves would fight the length constraint and flatten the wave
	# out, whereas offsetting at draw time keeps it visible.
	for i in range(1, pts.size()):
		var along := pts[i] - pts[i - 1]
		if along.length_squared() < 0.01:
			continue
		var wave := sin(_phase * 8.0 - float(i) * 1.05) * (0.6 + 1.15 * float(i))
		pts[i] += along.orthogonal().normalized() * wave

	# Drawn as one trapezoid per segment, each using that segment's own normal.
	# Sharing normals between neighbours (or building the whole tail as a single
	# outline) folds into a bow-tie the moment the tail whips back on itself, and
	# a self-intersecting polygon cannot be triangulated at all.
	var cloth := accent_secondary if not _dead else accent_secondary.darkened(0.5)
	var right := PackedVector2Array()
	for i in range(pts.size() - 1):
		var span := pts[i + 1] - pts[i]
		if span.length_squared() < 0.02:
			continue
		var normal := span.orthogonal().normalized()
		var t0 := float(i) / float(pts.size() - 1)
		var t1 := float(i + 1) / float(pts.size() - 1)
		var h0 := lerpf(5.5, 0.6, t0 * t0)
		var h1 := lerpf(5.5, 0.6, t1 * t1)
		draw_colored_polygon(PackedVector2Array([
			pts[i] + normal * h0, pts[i + 1] + normal * h1,
			pts[i + 1] - normal * h1, pts[i] - normal * h0]), cloth)
		if right.is_empty():
			right.append(pts[i] - normal * h0)
		right.append(pts[i + 1] - normal * h1)

	# A darker under-edge gives the cloth a fold instead of a flat cut-out.
	if right.size() >= 2:
		draw_polyline(right, cloth.darkened(0.35), 1.6, true)



## The body: one rounded volume, shaded, with the jacket read as a lighter
## panel over it rather than as an outline around it.
func _draw_torso(origin: Vector2, lean: float, tint: Color) -> void:
	var centre := origin
	var w := BODY_WIDTH
	var h := BODY_HEIGHT

	var shell := PackedVector2Array()
	for v in [
		Vector2(0.0, -h * 0.62), Vector2(w * 0.74, -h * 0.50),
		Vector2(w * 0.96, -h * 0.02), Vector2(w * 1.04, h * 0.44),
		Vector2(w * 0.84, h * 0.70), Vector2(0.0, h * 0.78),
		Vector2(-w * 0.84, h * 0.70), Vector2(-w * 1.04, h * 0.44),
		Vector2(-w * 0.96, -h * 0.02), Vector2(-w * 0.74, -h * 0.50),
	]:
		shell.append((v as Vector2).rotated(lean) + centre)
	var body := Chibi.smooth_closed(shell, 4)

	# Dark contour a shade wider than the body. The operative is a small light
	# shape on a dark field with a hundred enemies passing behind, and without
	# it the silhouette dissolves into whatever is underneath.
	var contour := PackedVector2Array()
	for p in body:
		contour.append(centre + (p - centre) * 1.11)
	Chibi.flat(self, contour, Color(0.05, 0.06, 0.11, 0.85))
	Chibi.form(self, body, tint.darkened(0.42), 0.30, 0.34, 0.34)

	# Open jacket front: a lighter panel down the middle, narrower at the hem.
	var front := PackedVector2Array()
	for v in [Vector2(-w * 0.34, -h * 0.56), Vector2(w * 0.34, -h * 0.56),
			Vector2(w * 0.24, h * 0.62), Vector2(-w * 0.24, h * 0.62)]:
		front.append((v as Vector2).rotated(lean) + centre)
	Chibi.form(self, Chibi.smooth_closed(front, 4), tint.darkened(0.66), 0.24, 0.26, 0.30)
	_draw_emblem(centre + Vector2(0.0, -h * 0.14).rotated(lean), lean)

	# Belt: a rounded band, not a line.
	var belt := PackedVector2Array()
	for v in [Vector2(-w * 1.00, h * 0.34), Vector2(0.0, h * 0.40),
			Vector2(w * 1.00, h * 0.34), Vector2(w * 0.98, h * 0.52),
			Vector2(0.0, h * 0.58), Vector2(-w * 0.98, h * 0.52)]:
		belt.append((v as Vector2).rotated(lean) + centre)
	Chibi.form(self, Chibi.smooth_closed(belt, 4), accent_secondary.darkened(0.34),
		0.22, 0.24, 0.28)
	Chibi.ball(self, Vector2(0.0, h * 0.44).rotated(lean) + centre, 3.0, accent_secondary)
	# Light down the near shoulder.
	Chibi.soft(self, Vector2(-w * 0.44, -h * 0.30).rotated(lean) + centre, w * 0.52,
		h * 0.40, Color(1.0, 0.96, 0.90, 0.16))

func _draw_emblem(centre: Vector2, lean: float) -> void:
	var emblem: PackedVector2Array
	match hero_shape:
		0:
			emblem = Draw2D.polygon_points(3, 5.0, -PI * 0.5)
		1:
			emblem = Draw2D.polygon_points(4, 5.0, 0.0)
		3:
			emblem = Draw2D.polygon_points(6, 5.0, 0.0)
		4:
			emblem = Draw2D.star_points(5, 5.6, 2.4, -PI * 0.5)
		_:
			emblem = Draw2D.polygon_points(5, 5.0, -PI * 0.5)
	var placed := PackedVector2Array()
	for p in emblem:
		placed.append(p.rotated(lean) + centre)
	draw_colored_polygon(placed, accent_secondary)



## A leg as two tapered capsules and a rounded boot. Constant-width lines with
## square ends are half of why the old character read as a stick figure.
func _draw_leg(origin: Vector2, lean: float, swing: float, tint: Color, far: bool) -> void:
	var hip := origin + Vector2((-5.2 if far else 5.2) * _facing, HIP_Y).rotated(lean)
	var knee := hip + Vector2(swing * 7.5, 10.0)
	var foot := knee + Vector2(swing * 10.5, 11.0 - absf(swing) * 2.4)
	var color := tint.darkened(0.70 if far else 0.52)
	Chibi.capsule(self, hip, knee, 4.0, 3.2, color)
	Chibi.capsule(self, knee, foot, 3.2, 2.8, color)
	# Boot: a rounded cuff and a sole that runs out to a toe.
	var boot := accent_secondary.darkened(0.62 if far else 0.46)
	Chibi.capsule(self, foot + Vector2(-0.8 * _facing, -1.2),
		foot + Vector2(4.0 * _facing, 1.0), 3.4, 2.7, boot)
	Chibi.soft(self, foot + Vector2(1.4 * _facing, 2.8), 4.6, 1.6,
		Color(0.05, 0.05, 0.09, 0.5), 16)


## An arm as two tapered capsules and a rounded glove.
func _draw_arm(origin: Vector2, lean: float, swing: float, tint: Color, far: bool) -> void:
	var side := -1.0 if far else 1.0
	var shoulder := origin + Vector2(BODY_WIDTH * 0.94 * side, -BODY_HEIGHT * 0.34).rotated(lean)
	var elbow := shoulder + Vector2(swing * 5.0 + 2.4 * side, 6.4)
	var hand := elbow + Vector2(swing * 6.4 + 1.6 * side, 6.6)
	var color := tint.darkened(0.64 if far else 0.40)
	Chibi.capsule(self, shoulder, elbow, 3.5, 2.8, color)
	Chibi.capsule(self, elbow, hand, 2.8, 2.4, color)
	Chibi.ball(self, hand, 3.2, accent_secondary.darkened(0.56 if far else 0.40))

## The near arm, which is also the sword arm. Outside a swing it just swings
## with the walk cycle; during one it drives the blade through its arc.
func _draw_sword_arm(origin: Vector2, lean: float, swing: float, tint: Color) -> void:
	if _slash_time <= 0.0:
		_draw_arm(origin, lean, -swing, tint, false)
		return

	var t := 1.0 - clampf(_slash_time / _slash_span, 0.0, 1.0)   # 0 -> 1 across the attack
	var shoulder := origin + Vector2(BODY_WIDTH * 0.9, -BODY_HEIGHT * 0.35).rotated(lean)
	var swept := _pose_sweep(t)
	var angle := swept.x
	var reach := swept.y

	var hand := shoulder + Vector2(cos(angle), sin(angle)) * reach
	var color := tint.darkened(0.36)
	var elbow := shoulder.lerp(hand, 0.55)
	Chibi.capsule(self, shoulder, elbow, 3.5, 2.8, color)
	Chibi.capsule(self, elbow, hand, 2.8, 2.4, color)
	# The off hand comes up to steady a two-handed weapon.
	if _pose == Pose.SHOOT or _pose == Pose.DRAW or _pose == Pose.SMASH or _pose == Pose.SPRAY:
		var off := origin + Vector2(-BODY_WIDTH * 0.9, -BODY_HEIGHT * 0.35).rotated(lean)
		var off_elbow := off.lerp(hand, 0.45) + Vector2(0.0, 3.0)
		Chibi.capsule(self, off, off_elbow, 3.3, 2.7, color.darkened(0.18))
		Chibi.capsule(self, off_elbow, hand.lerp(off, 0.22), 2.7, 2.4, color.darkened(0.18))
	Chibi.ball(self, hand, 3.3, accent_secondary.darkened(0.36))

	_draw_held_weapon(hand, angle, t)


## Where the weapon points and how far out it is held, `t` through the attack.
## Returned as (angle, reach) so the arm rig and the sprite rig can share one
## definition of what each pose actually does - they draw the body completely
## differently, but a hammer has to fall the same way for both.
func _pose_sweep(t: float) -> Vector2:
	var aim := _slash_dir.angle()
	var angle := aim
	var reach := 17.0
	match _pose:
		Pose.THRUST:
			# Out fast, back slow: a spear is committed on the way in.
			var out := sin(minf(1.0, t * 1.35) * PI * 0.9)
			reach = 13.0 + 17.0 * out
		Pose.SHOOT:
			# Arm locked out, wrist kicking up on the shot and settling back.
			var kick := pow(1.0 - t, 3.0)
			angle = aim - _slash_sign * 0.55 * kick
			reach = 18.0 - 3.0 * kick
		Pose.DRAW:
			# Pull back past halfway, then loose.
			var pull := clampf(t / 0.62, 0.0, 1.0)
			var loose := clampf((t - 0.62) / 0.38, 0.0, 1.0)
			angle = aim + _slash_sign * 0.30 * pull * (1.0 - loose)
			reach = 19.0 - 5.0 * pull * (1.0 - loose)
		Pose.THROW:
			# Over the shoulder and away.
			var whip := 1.0 - pow(1.0 - t, 2.2)
			angle = lerpf(aim - _slash_sign * 1.5, aim + _slash_sign * 0.35, whip)
			reach = 14.0 + 8.0 * sin(whip * PI)
		Pose.SMASH:
			# Up over the head, then straight down. The pause at the top is what
			# makes a hammer feel heavy.
			var raise_t := clampf(t / 0.45, 0.0, 1.0)
			var fall := clampf((t - 0.45) / 0.55, 0.0, 1.0)
			angle = lerpf(aim - PI * 0.5, aim - PI * 1.35, raise_t)
			angle = lerpf(angle, aim + PI * 0.12, pow(fall, 0.6))
			reach = 18.0 + 5.0 * sin(t * PI)
		Pose.SPRAY:
			angle = aim + sin(t * 34.0) * 0.06
			reach = 19.0
		_:
			# Swing: fast out of the wind-up, slow into the follow-through.
			var eased := 1.0 - pow(1.0 - t, 2.4)
			angle = aim - _slash_sign * _slash_arc * 0.5 + _slash_sign * _slash_arc * eased
			if _slash_spin:
				angle = aim + _slash_sign * TAU * eased
			reach = 17.0 + 6.0 * sin(eased * PI)
	return Vector2(angle, reach)


## Baby is the one operative who is not drawn: she is the supplied illustration,
## cut into an upper body and two legs and animated as a paper doll. Everything
## around her - the shadow, the dust, the passive tells, the weapon in her hand
## - is the same code the rest of the cast uses.
func _draw_baby(origin: Vector2, lean: float, squash: float) -> void:
	var body := Color.WHITE
	if _hurt_flash > 0.0:
		body = body.lerp(Palette.DANGER, _hurt_flash * 0.55)
	if _dead:
		body = Color(0.52, 0.52, 0.60)
	# A narrower stride than the procedural cast walks with: her legs are a real
	# pair of legs and at a wide swing they cross through each other.
	var swing := sin(_step) * 0.30 * _thrust
	var ground := origin + Vector2(0.0, BABY_FOOT_Y)
	BabySprite.draw_figure(self, ground, BABY_HEIGHT, _facing,
		lean + _slash_lean() * 0.6, squash, swing, _drag, body)
	if _slash_time <= 0.0:
		return
	var t := 1.0 - clampf(_slash_time / _slash_span, 0.0, 1.0)
	var swept := _pose_sweep(t)
	var hand := BabySprite.hand_at(ground, BABY_HEIGHT, _facing)
	hand += Vector2(cos(swept.x), sin(swept.x)) * swept.y * 0.34
	_draw_held_weapon(hand, swept.x, t)


## The weapon itself, drawn from the same geometry as its HUD icon so the thing
## in the operative's hands and the thing on the card are the same object.
##
## Icons are drawn pointing up, hence the quarter turn on everything that has a
## length to it.
func _draw_held_weapon(hand: Vector2, angle: float, t: float) -> void:
	var fade := clampf(sin(clampf(t, 0.0, 1.0) * PI) * 1.6, 0.25, 1.0)
	var steel := Color(0.80, 0.88, 1.0, fade)
	var warm := Color(accent_secondary.r, accent_secondary.g, accent_secondary.b, fade)
	var along := Vector2(cos(angle), sin(angle))
	match _weapon:
		&"revolver", &"machine_pistol":
			# Held at the grip, so the barrel runs forward out of the fist.
			draw_set_transform(hand + along * 5.0, angle, Vector2.ONE)
			PowerArt.draw_gun(self, Vector2.ZERO, 13.5, steel, warm, _phase,
				_weapon == &"revolver")
			_muzzle_flash(hand + along * 16.0, t, fade)
		&"longbow":
			draw_set_transform(hand + along * 3.0, angle + PI * 0.5, Vector2.ONE)
			PowerArt.draw_bow(self, Vector2.ZERO, 18.0, steel, warm, _phase)
		&"spear":
			draw_set_transform(hand + along * 16.0, angle + PI * 0.25, Vector2.ONE)
			PowerArt.draw_spear(self, Vector2.ZERO, 23.0, steel, warm, _phase)
		&"chakram":
			draw_set_transform(hand + along * 6.0, angle, Vector2.ONE)
			PowerArt.draw_chakram(self, Vector2.ZERO, 13.0, steel, warm, _phase * 3.0, false)
		&"warhammer":
			draw_set_transform(hand + along * 15.0, angle + PI * 0.5, Vector2.ONE)
			PowerArt.draw_hammer(self, Vector2.ZERO, 20.0, steel, warm, _phase)
		&"flamethrower":
			draw_set_transform(hand + along * 8.0, angle, Vector2.ONE)
			PowerArt.draw_flame(self, Vector2.ZERO, 15.0, steel, warm, _phase * 4.0)
		_:
			draw_set_transform(hand + along * 13.0, angle + PI * 0.5, Vector2.ONE)
			PowerArt.draw_katana(self, Vector2.ZERO, 19.0, steel, warm, _phase)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 - _squash, 1.0 + _squash))


## A brief bloom at the muzzle, brightest the instant the shot leaves.
func _muzzle_flash(at: Vector2, t: float, fade: float) -> void:
	var punch := pow(1.0 - clampf(t, 0.0, 1.0), 3.0) * fade
	if punch <= 0.02:
		return
	draw_circle(at, 9.0 * punch, Color(accent_secondary.r, accent_secondary.g,
		accent_secondary.b, 0.55 * punch))
	draw_circle(at, 4.5 * punch, Color(1, 1, 1, 0.9 * punch))
	# Split Barrel fires a second round, so it gets a second muzzle.
	if _tells.has(&"split_barrel"):
		var twin := at + Vector2(0.0, 5.0)
		draw_circle(twin, 6.0 * punch, Color(accent_secondary.r, accent_secondary.g,
			accent_secondary.b, 0.45 * punch))
		draw_circle(twin, 3.0 * punch, Color(1, 1, 1, 0.75 * punch))



## The head, built the same way as the roster portraits so the person in the
## run and the person on the card are the same person: a rounded skull under a
## solid mass of hair, with the forehead painted back over the hair to cut the
## hairline. Cutting the hairline into the hair shape instead makes the spline
## overshoot into a hard peak.
func _draw_head(origin: Vector2, lean: float, tint: Color) -> void:
	# The head trails the body a little. A head that moves in perfect lockstep
	# with the hips is the tell that a character is one rigid sprite.
	var head := origin + Vector2(0.0, -BODY_HEIGHT - HEAD_RADIUS * 0.92).rotated(lean * 0.6)
	head += Vector2(_drag.x * 0.16, _drag.y * 0.10)
	var tilt := lean * 0.5 + clampf(_drag.x * 0.012, -0.10, 0.10)
	var r := HEAD_RADIUS

	_draw_hair_back(head, tilt)

	var skin := _skin
	if _hurt_flash > 0.0:
		skin = skin.lerp(Palette.DANGER, _hurt_flash * 0.55)
	if _dead:
		skin = skin.darkened(0.35)

	var face := _head_ring(head, tilt, 1.0)
	var contour := PackedVector2Array()
	for p in face:
		contour.append(head + (p - head) * 1.10)
	Chibi.flat(self, contour, Color(0.05, 0.06, 0.11, 0.85))
	Chibi.form(self, face, skin, 0.18, 0.28, 0.30)
	# Ears, tucked at the hairline.
	for side in [-1.0, 1.0]:
		Chibi.ball(self, head + Vector2(side * r * 1.00, r * 0.14).rotated(tilt), r * 0.13,
			skin.darkened(0.16), Vector2(0.78, 1.14))

	_draw_hair_front(head, tilt)
	_draw_face(head, skin)

	# Headband in the secondary accent - the readable "operative" cue, and what
	# keeps the silhouette distinct from the enemy shapes.
	var band := PackedVector2Array()
	for v in [Vector2(-0.98, -0.34), Vector2(0.0, -0.50), Vector2(0.98, -0.36),
			Vector2(0.96, -0.16), Vector2(0.0, -0.30), Vector2(-0.96, -0.14)]:
		band.append(head + ((v as Vector2) * r).rotated(tilt))
	Chibi.form(self, Chibi.smooth_closed(band, 4), accent_secondary, 0.26, 0.28, 0.32)
	Chibi.ball(self, head + Vector2(r * 0.30 * _facing, -r * 0.36).rotated(tilt),
		r * 0.10, Color(1, 1, 1, 0.9))


## The skull outline, scaled: rounded, widest at the cheekbone, closing to a
## soft chin. `k` scales it about the head centre.
func _head_ring(head: Vector2, tilt: float, k: float) -> PackedVector2Array:
	var r := HEAD_RADIUS * k
	var ctrl := PackedVector2Array()
	for v in [Vector2(0.00, -1.06), Vector2(0.68, -0.90), Vector2(1.00, -0.28),
			Vector2(0.94, 0.30), Vector2(0.62, 0.76), Vector2(0.00, 0.98),
			Vector2(-0.62, 0.76), Vector2(-0.94, 0.30), Vector2(-1.00, -0.28),
			Vector2(-0.68, -0.90)]:
		ctrl.append(head + ((v as Vector2) * r).rotated(tilt))
	return Chibi.smooth_closed(ctrl, 4)


## The mass behind the head, plus the strands that lag as she moves. Baby's are
## long and heavy, because her hair is what identifies her in the portrait and
## the character in the run has to be the same person.
func _draw_hair_back(head: Vector2, tilt: float) -> void:
	var r := HEAD_RADIUS
	# The spring does the work; the sine is only a breeze on top of it so the
	# hair is never completely still.
	var sway := sin(_phase * 2.6) * 0.035 + _drag.x / r * 0.62
	var drop := 1.05
	var wide := 1.16

	var ctrl := PackedVector2Array()
	for v in [Vector2(0.00, -1.26), Vector2(0.78, -1.06), Vector2(wide, -0.30),
			Vector2(wide * 0.96, drop * 0.50), Vector2(wide * 0.62, drop * 0.90),
			Vector2(0.00, drop), Vector2(-wide * 0.62, drop * 0.90),
			Vector2(-wide * 0.96, drop * 0.50), Vector2(-wide, -0.30),
			Vector2(-0.78, -1.06)]:
		var p: Vector2 = v
		ctrl.append(head + Vector2(p.x * r + sway * r * p.y * 0.30, p.y * r).rotated(tilt))
	Chibi.form(self, Chibi.smooth_closed(ctrl, 4), _hair, 0.28, 0.22, 0.42)


## The hair over the skull, then the forehead painted back over it. The
## hairline is therefore the outline of the forehead, which is a shape that can
## be drawn to look like one.
func _draw_hair_front(head: Vector2, tilt: float) -> void:
	var r := HEAD_RADIUS
	var crown := PackedVector2Array()
	for v in [Vector2(0.02, -1.30), Vector2(0.76, -1.14), Vector2(1.14, -0.60),
			Vector2(1.22, 0.12), Vector2(1.06, 0.46), Vector2(0.92, -0.10),
			Vector2(0.50, -0.44), Vector2(0.00, -0.52), Vector2(-0.50, -0.44),
			Vector2(-0.92, -0.10), Vector2(-1.06, 0.46), Vector2(-1.22, 0.12),
			Vector2(-1.16, -0.60), Vector2(-0.80, -1.16)]:
		crown.append(head + ((v as Vector2) * r).rotated(tilt))
	Chibi.form(self, Chibi.smooth_closed(crown, 4), _hair, 0.24, 0.20, 0.44)

	var skin := _skin
	if _hurt_flash > 0.0:
		skin = skin.lerp(Palette.DANGER, _hurt_flash * 0.55)
	if _dead:
		skin = skin.darkened(0.35)

	var line := -0.58
	var brow := PackedVector2Array()
	for v in [Vector2(0.00, line), Vector2(0.42, line + 0.05), Vector2(0.74, line + 0.22),
			Vector2(0.92, line + 0.52), Vector2(0.94, 0.30), Vector2(0.00, 0.44),
			Vector2(-0.94, 0.30), Vector2(-0.92, line + 0.52),
			Vector2(-0.74, line + 0.22), Vector2(-0.42, line + 0.05)]:
		brow.append(head + ((v as Vector2) * r).rotated(tilt))
	Chibi.form(self, Chibi.smooth_closed(brow, 4), skin, 0.12, 0.22, 0.26)
	# Occlusion from the hair onto the skin it overhangs.
	Chibi.soft(self, head + Vector2(0.0, line * r).rotated(tilt), r * 0.86, r * 0.26,
		Color(0.20, 0.12, 0.10, 0.38), 22)
	# One soft sheen across the crown, offset to the light side.
	Chibi.rim_light(self, head + Vector2(-r * 0.06, -r * 0.10), r * 0.96, r * 0.98,
		PI * 1.10, PI * 1.60, Color(_hair.lightened(0.42), 0.55), r * 0.15)


## The face. Big glossy eyes, a tiny nose and a small mouth, and an expression
## that changes with what the operative is doing - the whole point of a chibi
## is that you can read its mood from across the screen.
func _draw_face(head: Vector2, skin: Color) -> void:
	var r := HEAD_RADIUS
	var eye_y := head.y + r * 0.14
	var look := _gaze
	var ink := Color(0.10, 0.09, 0.14)

	if _dead:
		for side in [-1.0, 1.0]:
			var e := Vector2(head.x + side * r * 0.40, eye_y)
			for d in [Vector2(1.0, 1.0), Vector2(1.0, -1.0)]:
				Chibi.taper(self, PackedVector2Array([e - (d as Vector2) * 4.0,
					e + (d as Vector2) * 4.0]), ink, 2.8, 1.0, 1.0)
		return

	var hurt := _hurt_flash > 0.25
	var open := 1.0 if _blink <= 0.0 else 0.08
	var iris := accent.lerp(Color(0.30, 0.20, 0.14), 0.55)

	for side in [-1.0, 1.0]:
		var e := Vector2(head.x + side * r * 0.40, eye_y)
		if hurt:
			# Screwed up against the hit.
			var shut := PackedVector2Array([
				e + Vector2(-r * 0.24, r * 0.06 * side), e + Vector2(0.0, -r * 0.05),
				e + Vector2(r * 0.24, r * 0.06 * side)])
			Chibi.taper(self, Chibi.smooth_open(shut, 5), ink, r * 0.10, 0.4, 1.0)
			continue
		Chibi.eye(self, e, r * 0.27, r * 0.245, iris, look, open, ink, side)
		if open > 0.5:
			var b := PackedVector2Array()
			var lift: float = -0.02 if _slash_time > 0.0 else 0.0
			for v in [Vector2(0.16, -0.20 + lift), Vector2(0.40, -0.30 + lift),
					Vector2(0.64, -0.29), Vector2(0.80, -0.20)]:
				b.append(Vector2(head.x + side * (v as Vector2).x * r,
					eye_y + (v as Vector2).y * r))
			Chibi.taper(self, Chibi.smooth_open(b, 6), _hair.lightened(0.12), r * 0.10, 0.45, 1.0)

	for side2 in [-1.0, 1.0]:
		Chibi.soft(self, Vector2(head.x + side2 * r * 0.62, eye_y + r * 0.22), r * 0.20,
			r * 0.14, Color(1.0, 0.52, 0.48, 0.24), 18)

	# Nose: a soft shadow, which is all a chibi face needs.
	Chibi.soft(self, Vector2(head.x + look.x * r * 0.04, eye_y + r * 0.26), r * 0.085,
		r * 0.060, Color(0.42, 0.24, 0.17, 0.55), 14)

	var mouth := Vector2(head.x + look.x * r * 0.05, eye_y + r * 0.46)
	if hurt:
		Chibi.form(self, Chibi.smooth_closed(PackedVector2Array([
			mouth + Vector2(-3.4, -0.4), mouth + Vector2(3.4, -0.4),
			mouth + Vector2(0.0, 4.4)]), 5), Color(0.34, 0.12, 0.14), 0.12, 0.30, 0.30)
	elif _slash_time > 0.0:
		# A clenched, determined line while swinging.
		Chibi.taper(self, PackedVector2Array([mouth - Vector2(3.0, 0.0),
			mouth + Vector2(3.0, -0.6)]), ink, 2.0, 0.6, 1.0)
	else:
		var smile := Chibi.smooth_open(PackedVector2Array([
			mouth + Vector2(-3.2, -0.8), mouth + Vector2(0.0, 1.4),
			mouth + Vector2(3.2, -0.8)]), 6)
		Chibi.taper(self, smile, ink, 2.2, 0.35, 1.0)

## The knot the scarf is tied in, sitting on the collarbone. It is deliberately
## small: anything bigger swallows the chin and the character loses its face.
func _draw_collar(origin: Vector2, lean: float) -> void:
	var neck := origin + Vector2(0.0, -BODY_HEIGHT * 0.46).rotated(lean)
	var shade := accent_secondary if not _dead else accent_secondary.darkened(0.5)
	Chibi.form(self, Chibi.ellipse(neck, 9.8, 4.9, 28, lean), shade, 0.24, 0.30, 0.34)
	Chibi.soft(self, neck + Vector2(0.0, 2.0).rotated(lean), 8.0, 2.4,
		Color(0.0, 0.0, 0.0, 0.28), 18)
	if _hurt_flash > 0.0:
		Chibi.flat(self, Chibi.ellipse(neck, 9.8, 4.9, 24, lean),
			Color(1, 1, 1, 0.25 * _hurt_flash))

func _draw_shield() -> void:
	var shield := Color(0.55, 0.85, 1.0, 0.5)
	var radius := 46.0 + 2.0 * sin(_phase * 4.0)
	Draw2D.ring(self, Vector2(0.0, -12.0), radius, shield, 4.0)
	draw_circle(Vector2(0.0, -12.0), radius, Color(shield.r, shield.g, shield.b, 0.08))
	# Hex facets so the bubble reads as a constructed field.
	for i in 6:
		var a := _phase * 0.8 + TAU * float(i) / 6.0
		var p := Vector2(cos(a), sin(a)) * radius + Vector2(0.0, -12.0)
		draw_circle(p, 3.0, Color(shield.r, shield.g, shield.b, 0.7))
