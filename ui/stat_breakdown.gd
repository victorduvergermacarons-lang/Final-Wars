class_name StatBreakdown
extends RefCounted
## Where each of a hero's stats comes from: base, permanent growth from level-ups,
## equipped gear, and active buffs.


## One row per stat in `ids` (default: the combat stats):
## {"stat", "base", "growth", "gear", "buffs", "total"}.
static func rows(hero: Hero, now: float, ids: Array[Stat.Id] = Stat.core()) -> Array[Dictionary]:
	var gear := StatBlock.new()
	for item in hero.equipped_items():
		gear.add(item.stats)
	var total := hero.current_stats(now)
	var out: Array[Dictionary] = []
	for id in ids:
		var base := hero.base_stats.get_stat(id)
		var growth := hero.growth.get_stat(id)
		var g := gear.get_stat(id)
		var t := total.get_stat(id)
		out.append({"stat": id, "base": base, "growth": growth, "gear": g,
				"buffs": t - base - growth - g, "total": t})
	return out


## Abilities to list on the sheet: {"mastered": [AbilityDef], "in_progress": [
## {"ability", "ap", "needed", "earning"}]}. In progress = taught by a worn item, or
## with some AP already earned (from items carried in the bag).
static func abilities(hero: Hero) -> Dictionary:
	var mastered: Array = []
	var ids := hero.mastered.keys()
	ids.sort()
	for id in ids:
		mastered.append(hero.mastered[id])
	var progress: Array = []
	var seen := {}
	# Tree abilities earn AP only from the learning slot; old-style items from
	# being worn.
	var active := hero.active_learning_item()
	var learning := active.tree_ability() if active != null else null
	for ability in hero.taught_abilities():
		if ability.ap_to_master > 0 and not hero.is_mastered(ability.id):
			seen[ability.id] = true
			progress.append({"ability": ability, "ap": hero.ap.get(ability.id, 0),
					"needed": ability.ap_to_master, "earning": not ability.is_tree_ability() or ability == learning})
	for i in hero.bag.size():
		var item := hero.bag.item_at(i)
		if item == null:
			continue
		for ability in item.teaches:
			if seen.has(ability.id) or hero.is_mastered(ability.id) or hero.ap.get(ability.id, 0) <= 0:
				continue
			seen[ability.id] = true
			progress.append({"ability": ability, "ap": hero.ap[ability.id],
					"needed": ability.ap_to_master, "earning": false})
	return {"mastered": mastered, "in_progress": progress}
