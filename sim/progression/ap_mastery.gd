class_name ApMastery
extends RefCounted
## FFTA-style ability learning: abilities taught by equipped items earn AP on
## level-up; at the ability's threshold it is mastered and usable forever.


## Gives `amount` AP to each unmastered ability taught by the hero's equipped
## items. Returns events: {"type": "ap", ...} and {"type": "mastered", ...}.
## Tree abilities instead earn AP only through the learning slot (TreeRules).
static func award(hero: Hero, amount: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for ability in hero.taught_abilities():
		if ability.is_tree_ability() or ability.ap_to_master <= 0 or hero.is_mastered(ability.id):
			continue
		var total: int = mini(hero.ap.get(ability.id, 0) + amount, ability.ap_to_master)
		hero.ap[ability.id] = total
		events.append({"type": "ap", "target": hero.id, "ability": ability.id,
				"ap": total, "needed": ability.ap_to_master})
		if total >= ability.ap_to_master:
			hero.mastered[ability.id] = ability
			events.append({"type": "mastered", "target": hero.id, "ability": ability.id})
	events.append_array(TreeRules.award_ap(hero, amount))
	return events
