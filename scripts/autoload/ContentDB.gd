extends Node
## Loads every design-time resource once at boot and indexes it by id.
##
## Systems ask ContentDB for data instead of preloading paths, which keeps
## content additive: dropping a new .tres into resources/ is enough.

signal content_ready

const HERO_DIR := "res://resources/heroes"
const POWER_DIR := "res://resources/powers"
const UPGRADE_DIR := "res://resources/upgrades"
const ENEMY_DIR := "res://resources/enemies"
const LEVEL_DIR := "res://resources/levels"
const RELIC_DIR := "res://resources/relics"

var heroes: Dictionary = {}    # StringName -> HeroData
var powers: Dictionary = {}    # StringName -> PowerData
var upgrades: Dictionary = {}  # StringName -> UpgradeData
var enemies: Dictionary = {}   # StringName -> EnemyData
var levels: Dictionary = {}    # StringName -> LevelData
var relics: Dictionary = {}    # StringName -> RelicData

var hero_list: Array[HeroData] = []
var level_list: Array[LevelData] = []
var relic_list: Array[RelicData] = []
var power_list: Array[PowerData] = []
var active_power_list: Array[PowerData] = []
## The starting weapons, which are chosen before a run rather than offered
## during one. They are deliberately absent from power_list so nothing that
## builds a level-up pool has to remember to filter them out.
var weapon_list: Array[PowerData] = []
var passive_list: Array[PowerData] = []
var upgrade_list: Array[UpgradeData] = []

var _ready_done: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reload()


func reload() -> void:
	heroes = _load_dir(HERO_DIR)
	powers = _load_dir(POWER_DIR)
	upgrades = _load_dir(UPGRADE_DIR)
	enemies = _load_dir(ENEMY_DIR)
	levels = _load_dir(LEVEL_DIR)
	relics = _load_dir(RELIC_DIR)
	_rebuild_lists()
	_ready_done = true
	content_ready.emit()


func is_ready() -> bool:
	return _ready_done


func _rebuild_lists() -> void:
	hero_list.clear()
	for key in heroes:
		hero_list.append(heroes[key])
	hero_list.sort_custom(_sort_heroes)

	level_list.clear()
	for key in levels:
		level_list.append(levels[key])
	level_list.sort_custom(_sort_levels)

	relic_list.clear()
	for key in relics:
		relic_list.append(relics[key])
	relic_list.sort_custom(_sort_relics)

	power_list.clear()
	active_power_list.clear()
	passive_list.clear()
	weapon_list.clear()
	for key in powers:
		var power: PowerData = powers[key]
		if power.starting_weapon:
			weapon_list.append(power)
			continue
		power_list.append(power)
		if power.is_power():
			active_power_list.append(power)
		else:
			passive_list.append(power)
	power_list.sort_custom(_sort_powers)
	active_power_list.sort_custom(_sort_powers)
	passive_list.sort_custom(_sort_powers)
	weapon_list.sort_custom(_sort_powers)

	upgrade_list.clear()
	for key in upgrades:
		upgrade_list.append(upgrades[key])
	upgrade_list.sort_custom(_sort_by_name)


func _sort_heroes(a: HeroData, b: HeroData) -> bool:
	if a.unlocked_by_default != b.unlocked_by_default:
		return a.unlocked_by_default
	return a.display_name < b.display_name


func _sort_levels(a: LevelData, b: LevelData) -> bool:
	return a.order < b.order


func _sort_relics(a: RelicData, b: RelicData) -> bool:
	return a.credit_cost < b.credit_cost


func _sort_by_name(a: Resource, b: Resource) -> bool:
	return String(a.get("display_name")) < String(b.get("display_name"))


## Every choosable entry, weapons excluded. Used by the --everything soak flag.
func all_power_ids() -> Array:
	var out: Array = []
	for data in power_list:
		out.append(data.id)
	return out


func _sort_powers(a: PowerData, b: PowerData) -> bool:
	if a.category != b.category:
		return a.category < b.category
	if a.order != b.order:
		return a.order < b.order
	return a.display_name < b.display_name


## Scans a folder for .tres resources and keys them by their `id` field.
func _load_dir(path: String) -> Dictionary:
	var out: Dictionary = {}
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("ContentDB: missing folder %s" % path)
		return out
	for file_name in dir.get_files():
		var clean := file_name
		if clean.ends_with(".remap"):
			clean = clean.trim_suffix(".remap")
		if not (clean.ends_with(".tres") or clean.ends_with(".res")):
			continue
		var res: Resource = ResourceLoader.load(path.path_join(clean))
		if res == null:
			push_warning("ContentDB: failed to load %s" % clean)
			continue
		var id_value: Variant = res.get("id")
		if id_value == null or String(id_value).is_empty():
			push_warning("ContentDB: %s has no id, skipping" % clean)
			continue
		out[StringName(id_value)] = res
	return out


# --- Typed lookups ---------------------------------------------------------

func get_hero(id: StringName) -> HeroData:
	return heroes.get(id) as HeroData


func get_power(id: StringName) -> PowerData:
	return powers.get(id) as PowerData


func get_upgrade(id: StringName) -> UpgradeData:
	return upgrades.get(id) as UpgradeData


func get_enemy(id: StringName) -> EnemyData:
	return enemies.get(id) as EnemyData


func get_level(id: StringName) -> LevelData:
	return levels.get(id) as LevelData


func get_relic(id: StringName) -> RelicData:
	return relics.get(id) as RelicData


func get_first_hero() -> HeroData:
	return hero_list[0] if hero_list.size() > 0 else null


func get_first_level() -> LevelData:
	return level_list[0] if level_list.size() > 0 else null
