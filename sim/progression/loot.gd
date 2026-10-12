class_name Loot
extends RefCounted
## Rolls loot tables and hands out personal loot.


## One hero's roll: {"gold": int, "items": [[ItemDef, count], ...]}.
## Quest items drop only while the hero's quest still needs them (`quests`:
## id -> QuestDef; without the def, while the quest is active).
static func roll(table: LootTable, rng: RandomNumberGenerator, hero: Hero, quests: Dictionary = {}) -> Dictionary:
	var out := {"gold": 0, "items": []}
	if table == null:
		return out
	if table.gold_max > 0:
		out.gold = rng.randi_range(maxi(table.gold_min, 0), maxi(table.gold_max, table.gold_min))
	for entry in table.entries:
		if entry == null or entry.item == null:
			continue
		if entry.quest_id != &"":
			if quests.has(entry.quest_id):
				if not QuestLog.needs_item(hero, quests, entry.quest_id, entry.item):
					continue
			elif not has_active_quest(hero, entry.quest_id):
				continue
		if rng.randf() < entry.chance:
			out.items.append([entry.item, rng.randi_range(maxi(entry.min_count, 1), maxi(entry.max_count, entry.min_count))])
	return out


static func has_active_quest(hero: Hero, quest_id: StringName) -> bool:
	var q = hero.quest_state.get(String(quest_id))
	return typeof(q) == TYPE_DICTIONARY and q.get("state") == "active"


## Plain-data form of item lists: [[id, count], ...].
static func items_to_array(items: Array) -> Array:
	return items.map(func(pair): return [String(pair[0].id), pair[1]])
