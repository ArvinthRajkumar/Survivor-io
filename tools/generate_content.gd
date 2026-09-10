extends SceneTree
## Content build step.
##
## Run it from the project root with:
##   godot --headless --script res://tools/generate_content.gd
##
## It regenerates every .tres under resources/ from the readable authoring
## scripts in tools/gen/. Editing balance numbers there and re-running keeps the
## data reviewable in version control instead of hidden in binary-ish resources.
##
## Order matters: levels reference enemy resources, so enemies are written first.

# Preloaded rather than referenced by class_name: this script is run before the
# editor has necessarily refreshed its global class cache.
const GEN_HEROES := preload("res://tools/gen/GenHeroes.gd")
const GEN_POWERS := preload("res://tools/gen/GenPowers.gd")
const GEN_UPGRADES := preload("res://tools/gen/GenUpgrades.gd")
const GEN_ENEMIES := preload("res://tools/gen/GenEnemies.gd")
const GEN_LEVELS := preload("res://tools/gen/GenLevels.gd")
const GEN_RELICS := preload("res://tools/gen/GenRelics.gd")

const DIRS := [
	"res://resources/heroes",
	"res://resources/powers",
	"res://resources/upgrades",
	"res://resources/enemies",
	"res://resources/levels",
	"res://resources/relics",
]


func _initialize() -> void:
	print("Last Light: Swarmfall - generating content")
	_ensure_dirs()
	GEN_HEROES.run()
	GEN_POWERS.run()
	GEN_UPGRADES.run()
	GEN_ENEMIES.run()
	GEN_LEVELS.run()
	GEN_RELICS.run()
	print("Content generation complete.")
	quit(0)


func _ensure_dirs() -> void:
	for path in DIRS:
		if not DirAccess.dir_exists_absolute(path):
			DirAccess.make_dir_recursive_absolute(path)
