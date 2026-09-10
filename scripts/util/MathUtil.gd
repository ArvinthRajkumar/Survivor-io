class_name MathUtil
extends RefCounted
## Small numeric helpers reused across systems.

## Diminishing-returns curve: 0 -> 0, and never reaches `cap`.
static func soft_cap(value: float, cap: float) -> float:
	if value <= 0.0:
		return 0.0
	return cap * value / (value + cap)

## Uniform random point on a circle of the given radius.
static func random_point_on_circle(rng: RandomNumberGenerator, radius: float) -> Vector2:
	var a := rng.randf() * TAU
	return Vector2(cos(a), sin(a)) * radius

## Random point inside an annulus (ring) - used for off-screen spawning.
static func random_point_in_ring(rng: RandomNumberGenerator, inner: float, outer: float) -> Vector2:
	var a := rng.randf() * TAU
	var r := sqrt(rng.randf() * (outer * outer - inner * inner) + inner * inner)
	return Vector2(cos(a), sin(a)) * r

static func format_time(seconds: float) -> String:
	var total := int(max(0.0, seconds))
	return "%02d:%02d" % [total / 60, total % 60]

static func format_number(value: int) -> String:
	var s := str(absi(value))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if value < 0 else "") + out
