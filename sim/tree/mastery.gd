class_name Mastery
extends RefCounted
## Tree Mastery on a hero. Each tree has a Stat (Fire Mastery…).
## - Permanent Mastery = base + growth (level-up item growth and Mastery earned from
##   learning and using abilities). Only this counts toward unlocking tiers.
## - Total Mastery also includes gear and buffs; it scales ability power.

const TREES := ["Fire", "Earth", "Water", "Air", "Sword", "Bow", "Hammer"]
const ELEMENTS := ["Fire", "Earth", "Water", "Air"]
const STATS := {
	"Fire": Stat.Id.FIRE_MASTERY, "Earth": Stat.Id.EARTH_MASTERY, "Water": Stat.Id.WATER_MASTERY,
	"Air": Stat.Id.AIR_MASTERY, "Sword": Stat.Id.SWORD_MASTERY, "Bow": Stat.Id.BOW_MASTERY,
	"Hammer": Stat.Id.HAMMER_MASTERY,
}


static func stat_for(tree: String) -> Stat.Id:
	return STATS.get(tree, -1)


static func is_tree(tree: String) -> bool:
	return STATS.has(tree)


## Mastery that counts toward tier unlocks (never gear or buffs).
static func permanent(hero: Hero, tree: String) -> float:
	if not STATS.has(tree):
		return 0.0
	return hero.base_stats.get_stat(STATS[tree]) + hero.growth.get_stat(STATS[tree])


## Mastery including gear and buffs: what ability power uses.
static func total(hero: Actor, tree: String, now: float) -> float:
	if not STATS.has(tree):
		return 0.0
	return hero.current_stats(now).get_stat(STATS[tree])


## Highest permanent Mastery among the element trees (for "any element Mastery N").
static func best_element(hero: Hero) -> float:
	var best := 0.0
	for tree in ELEMENTS:
		best = maxf(best, permanent(hero, tree))
	return best


## Adds permanent Mastery (kept with the hero's growth, so it saves with it).
static func add_permanent(hero: Hero, tree: String, amount: float) -> void:
	if not STATS.has(tree) or is_zero_approx(amount):
		return
	var id: Stat.Id = STATS[tree]
	hero.growth.set_stat(id, hero.growth.get_stat(id) + amount)
	hero.refresh_stats()
