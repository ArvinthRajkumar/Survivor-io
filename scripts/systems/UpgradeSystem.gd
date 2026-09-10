class_name UpgradeSystem
extends RefCounted
## Builds the choices shown on level-up and applies the picked one.
##
## Two rules shape every offer set:
##  * Powers and Passive Abilities share six slots. While slots remain, offers
##    mix new entries with upgrades to what you own. Once all six are taken the
##    pool collapses to owned-and-not-yet-maxed entries only — nothing can be
##    swapped out, so the panel stops teasing options you can never take.
##  * While slots remain the set is biased to show one of each category, so a
##    run never accidentally rails into all-passives or all-powers.
##
## Offers are plain dictionaries so the UI never has to branch on resource types.

enum OfferKind { NEW, LEVEL, HEAL }

const HEAL_FRACTION := 0.35


static func generate(count: int = 3) -> Array[Dictionary]:
	var loadout := RunManager.loadout
	var pool := _build_pool(loadout)
	_weighted_shuffle(pool)

	var offers: Array[Dictionary] = []
	if not loadout.is_full():
		for category in [PowerData.Category.POWER, PowerData.Category.PASSIVE]:
			if offers.size() >= count:
				break
			var pick := _take_first(pool, int(category), OfferKind.NEW)
			if not pick.is_empty():
				offers.append(pick)

	for offer in pool:
		if offers.size() >= count:
			break
		if _contains(offers, offer):
			continue
		offers.append(offer)

	# Everything owned is maxed: the only thing left worth offering is health.
	if offers.is_empty():
		offers.append(_heal_offer())
	return offers


static func _take_first(pool: Array[Dictionary], category: int, kind: int) -> Dictionary:
	for offer in pool:
		if int(offer.get("category", -1)) == category and int(offer.get("kind", -1)) == kind:
			return offer
	return {}


static func _contains(offers: Array[Dictionary], offer: Dictionary) -> bool:
	for existing in offers:
		if existing.get("id") == offer.get("id"):
			return true
	return false


static func _build_pool(loadout: PowerLoadout) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for data in ContentDB.power_list:
		if not loadout.can_offer(data):
			continue
		var owned := loadout.has(data.id)
		var next_level := loadout.get_level(data.id) + 1
		var tag := ""
		if owned:
			tag = "MAX LEVEL" if next_level >= data.max_level else "LEVEL %d" % next_level
		else:
			tag = "NEW POWER" if data.is_power() else "NEW ABILITY"
		pool.append({
			"kind": OfferKind.LEVEL if owned else OfferKind.NEW,
			"category": int(data.category),
			"id": data.id,
			"art": data.art_id(),
			"title": data.display_name,
			"subtitle": data.note_for_level(next_level) if owned else data.description,
			"tooltip": data.tooltip,
			"level": next_level,
			"max_level": data.max_level,
			"color": data.color,
			"color2": data.color_secondary,
			"rarity": 3 if (owned and next_level >= data.max_level) else data.rarity,
			# Unowned entries are pushed a little harder while slots remain.
			"weight": data.weight * (1.35 if not owned else 1.0),
			"tag": tag,
		})
	return pool


static func _heal_offer() -> Dictionary:
	return {
		"kind": OfferKind.HEAL,
		"category": int(PowerData.Category.PASSIVE),
		"id": &"field_repair",
		"art": &"field_repair",
		"title": "Field Repair",
		"subtitle": "Restore %d%% of maximum health." % int(HEAL_FRACTION * 100.0),
		"tooltip": "Emergency patch-up.",
		"level": 1,
		"max_level": 1,
		"color": Palette.HEALTH,
		"color2": Color(0.85, 1.0, 0.9),
		"rarity": 0,
		"weight": 1.0,
		"tag": "RECOVER",
	}


## Efraimidis-Spirakis weighted sampling: one random key per entry, then sort.
static func _weighted_shuffle(pool: Array[Dictionary]) -> void:
	var luck := 1.0
	if RunManager.stats != null:
		luck = 1.0 + clampf(RunManager.stats.get_stat(&"luck") * 0.05, 0.0, 1.0)
	for offer in pool:
		var weight := maxf(0.01, float(offer.get("weight", 1.0)) * luck)
		offer["_key"] = pow(RunManager.rng.randf(), 1.0 / weight)
	pool.sort_custom(_sort_by_key)


static func _sort_by_key(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("_key", 0.0)) > float(b.get("_key", 0.0))


## Applies a chosen offer. Returns a short line for the HUD log.
static func apply(offer: Dictionary) -> String:
	var kind := int(offer.get("kind", OfferKind.HEAL))
	if kind == OfferKind.HEAL:
		var player := Player.instance
		if player != null:
			player.heal(player.health.max_health * HEAL_FRACTION)
		return "Health restored"

	var id := StringName(offer.get("id", &""))
	var level := RunManager.loadout.add_or_level(id)
	if level <= 0:
		return ""
	var data := ContentDB.get_power(id)
	if data != null and level >= data.max_level:
		return "%s — MAX" % data.display_name
	return "%s Lv.%d" % [offer.get("title", ""), level]
