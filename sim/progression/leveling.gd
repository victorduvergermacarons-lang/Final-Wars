class_name Leveling
extends RefCounted
## XP and level-ups. Each level-up applies item growth, awards AP and (by
## default) refills HP and Mana.


static func xp_to_next(level: int, rules: CombatRules) -> float:
	return rules.xp_per_level_factor * level


static func is_max_level(level: int, rules: CombatRules) -> bool:
	return rules.max_level > 0 and level >= rules.max_level


## Adds XP and processes any level-ups (possibly several). Returns events.
static func add_xp(hero: Hero, amount: float, rules: CombatRules) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if amount <= 0.0 or is_max_level(hero.level, rules):
		return events
	hero.xp += amount
	events.append({"type": "xp", "target": hero.id, "amount": amount})
	while not is_max_level(hero.level, rules) and hero.xp + Cooldowns.EPSILON >= xp_to_next(hero.level, rules):
		hero.xp = maxf(hero.xp - xp_to_next(hero.level, rules), 0.0)
		events.append_array(level_up(hero, rules))
	if is_max_level(hero.level, rules):
		hero.xp = 0.0
	return events


## One level-up: growth from equipped items, AP, stat refresh, optional refill.
static func level_up(hero: Hero, rules: CombatRules) -> Array[Dictionary]:
	hero.level += 1
	var gain := ItemGrowth.gain_for_level(hero.equipped_items(), hero.growth, rules)
	hero.growth.add(gain)
	hero.refresh_stats()
	if rules.refill_on_level_up:
		hero.hp = hero.stats.hp
		hero.mana = hero.stats.mana
	var events: Array[Dictionary] = [
		{"type": "level_up", "target": hero.id, "level": hero.level, "growth": gain.to_dict()},
	]
	events.append_array(ApMastery.award(hero, rules.ap_per_level))
	return events
