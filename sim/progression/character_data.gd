class_name CharacterData
extends RefCounted
## A hero's persistent progress as plain data (saved as JSON on the player's
## computer and sent to the host when joining). Loading never trusts the data:
## unknown ids are dropped and numbers are clamped.

const VERSION := 1
const MAX_LEVEL_SANITY := 999
const MAX_GOLD := 999_999_999


static func capture(hero: Hero) -> Dictionary:
	var equipped := {}
	var equipment := hero.equipment()
	for slot in equipment:
		equipped[str(int(slot))] = String(equipment[slot].id)
	var ap := {}
	for id in hero.ap:
		ap[String(id)] = int(hero.ap[id])
	return {
		"version": VERSION,
		"name": hero.display_name,
		"hero": String(hero.def_id),
		"level": hero.level,
		"xp": hero.xp,
		"gold": hero.gold,
		"growth": _stats_out(hero.growth),
		"bag": hero.bag.to_array(),
		"equipped": equipped,
		"ap": ap,
		"mastered": hero.mastered.keys().map(func(id): return String(id)),
		"quests": hero.quest_state.duplicate(true),
	}


## Builds a hero from saved data. `content` provides heroes/items/abilities by id.
static func restore(id: int, data: Dictionary, content) -> Hero:
	var def: HeroDef = content.heroes.get(StringName(str(data.get("hero", "adventurer"))))
	if def == null:
		def = content.heroes.values()[0]
	var hero := Hero.new(id, def.base_stats.copy())
	hero.def_id = def.id
	hero.display_name = clean_name(str(data.get("name", "Adventurer")))
	hero.level = clampi(_int(data.get("level"), 1), 1, MAX_LEVEL_SANITY)
	hero.xp = maxf(_float(data.get("xp"), 0.0), 0.0)
	hero.gold = clampi(_int(data.get("gold"), 0), 0, MAX_GOLD)
	hero.growth = _stats_in(data.get("growth"))
	var bag_data = data.get("bag")
	hero.bag = Bag.from_array(bag_data if typeof(bag_data) == TYPE_ARRAY else [], content.items)
	var equipped = data.get("equipped")
	if typeof(equipped) == TYPE_DICTIONARY:
		for key in equipped:
			var slot := _int(key, -1)
			var item: ItemDef = content.items.get(StringName(str(equipped[key])))
			if slot >= 0 and slot < EquipSlot.COUNT and item != null:
				hero.wear(item, slot)
	var ap = data.get("ap")
	if typeof(ap) == TYPE_DICTIONARY:
		for key in ap:
			var ability: AbilityDef = content.abilities.get(StringName(str(key)))
			if ability != null:
				hero.ap[ability.id] = clampi(_int(ap[key], 0), 0, maxi(ability.ap_to_master, 0))
	var mastered = data.get("mastered")
	if typeof(mastered) == TYPE_ARRAY:
		for key in mastered:
			var ability: AbilityDef = content.abilities.get(StringName(str(key)))
			if ability != null:
				hero.mastered[ability.id] = ability
	var quests = data.get("quests")
	if typeof(quests) == TYPE_DICTIONARY:
		hero.quest_state = quests.duplicate(true)
	hero.refresh_stats()
	hero.hp = hero.stats.hp
	hero.mana = hero.stats.mana
	return hero


## A fresh level-1 character.
static func new_character(char_name: String, hero_def: HeroDef) -> Dictionary:
	var hero := Hero.from_def(0, hero_def)
	hero.display_name = clean_name(char_name)
	return capture(hero)


## Names are 1–16 printable characters, trimmed.
static func clean_name(raw: String) -> String:
	var out := ""
	for c in raw.strip_edges():
		if c.unicode_at(0) >= 32:
			out += c
	out = out.left(16)
	return out if not out.is_empty() else "Adventurer"


static func _stats_out(block: StatBlock) -> Dictionary:
	var d := {}
	for id in Stat.all():
		var v := block.get_stat(id)
		if not is_zero_approx(v):
			d[String(Stat.property_of(id))] = v
	return d


static func _stats_in(raw) -> StatBlock:
	var block := StatBlock.new()
	if typeof(raw) != TYPE_DICTIONARY:
		return block
	for id in Stat.all():
		var v := _float(raw.get(String(Stat.property_of(id))), 0.0)
		block.set_stat(id, clampf(v, -1_000_000.0, 1_000_000.0))
	return block


static func _int(v, fallback: int) -> int:
	match typeof(v):
		TYPE_INT:
			return v
		TYPE_FLOAT:
			return int(v) if is_finite(v) else fallback
		TYPE_STRING:
			return int(v) if v.is_valid_int() else fallback
	return fallback


static func _float(v, fallback: float) -> float:
	if typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)):
		return float(v)
	return fallback
