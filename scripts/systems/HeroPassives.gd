class_name HeroPassives
extends RefCounted
## Applies a hero's always-on passive to the run's PlayerStats.
##
## Passives are pure stat changes so they compose cleanly with items and relics;
## anything that needs per-frame behaviour belongs in the ultimate instead.


static func apply(hero: HeroData, stats: PlayerStats) -> void:
	if hero == null or stats == null:
		return
	match hero.passive_id:
		&"overclock":
			# Nova: faster weapon cycling, slightly wider effects.
			stats.add_mult(&"cooldown_mult", 0.12)
			stats.add_mult(&"area_mult", 0.05)
		&"deep_roots":
			# Bramble: sustain instead of burst.
			stats.add_flat(&"health_regen", 1.6)
			stats.add_flat(&"max_health", 25.0)
		&"phase_step":
			# Rift: mobility and a sliver of damage avoidance.
			stats.add_mult(&"move_speed_mult", 0.14)
			stats.add_flat(&"damage_reduction", 0.08)
		&"bulwark_plating":
			# Aegis: soaks hits, moves slower.
			stats.add_flat(&"armor", 6.0)
			stats.add_flat(&"max_health", 40.0)
			stats.add_mult(&"move_speed_mult", -0.06)
		&"kindling":
			# Ember: big, hard-hitting areas.
			stats.add_mult(&"area_mult", 0.18)
			stats.add_mult(&"crit_damage_mult", 0.25)
		_:
			pass


## Short text for the hero-select screen when the resource has no copy yet.
static func describe(hero: HeroData) -> String:
	if hero == null:
		return ""
	if not hero.passive_description.is_empty():
		return hero.passive_description
	return "No passive."
