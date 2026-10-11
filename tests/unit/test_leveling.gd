extends GutTest

const F := preload("res://tests/unit/progression_fixtures.gd")

var rules: CombatRules
var hero: Hero


func before_each() -> void:
	rules = CombatRules.new()
	hero = F.hero_with([F.item(&"sword", EquipSlot.Id.MAIN_HAND, {}, {Stat.Id.HP: 20})])


func _types(events: Array) -> Array:
	return events.map(func(e): return e.type)


func test_xp_curve() -> void:
	assert_eq(Leveling.xp_to_next(1, rules), 100.0)
	assert_eq(Leveling.xp_to_next(4, rules), 400.0)


func test_xp_below_threshold_does_not_level() -> void:
	var events := Leveling.add_xp(hero, 99, rules)
	assert_eq(hero.level, 1)
	assert_eq(hero.xp, 99.0)
	assert_eq(_types(events), ["xp"])


func test_level_up_carries_over_extra_xp() -> void:
	var events := Leveling.add_xp(hero, 130, rules)
	assert_eq(hero.level, 2)
	assert_eq(hero.xp, 30.0)
	assert_has(_types(events), "level_up")


func test_big_xp_gain_gives_several_levels() -> void:
	Leveling.add_xp(hero, 100 + 200 + 300 + 50, rules)
	assert_eq(hero.level, 4)
	assert_eq(hero.xp, 50.0)
	assert_eq(hero.growth.hp, 30.0, "3 level-ups × 20 × 0.5")


func test_level_up_refills_hp_and_mana_by_default() -> void:
	hero.hp = 1
	hero.mana = 0
	Leveling.add_xp(hero, 100, rules)
	assert_eq(hero.hp, hero.stats.hp)
	assert_eq(hero.hp, 110.0)
	assert_eq(hero.mana, 50.0)


func test_refill_can_be_turned_off() -> void:
	rules.refill_on_level_up = false
	hero.hp = 1
	Leveling.add_xp(hero, 100, rules)
	assert_eq(hero.hp, 1.0)


func test_max_level_stops_progress() -> void:
	rules.max_level = 2
	Leveling.add_xp(hero, 1000, rules)
	assert_eq(hero.level, 2)
	assert_eq(hero.xp, 0.0)
	assert_eq(Leveling.add_xp(hero, 50, rules).size(), 0)


func test_no_cap_by_default() -> void:
	Leveling.add_xp(hero, 100000, rules)
	assert_gt(hero.level, 40)


func test_zero_or_negative_xp_is_ignored() -> void:
	assert_eq(Leveling.add_xp(hero, 0, rules).size(), 0)
	assert_eq(Leveling.add_xp(hero, -10, rules).size(), 0)
	assert_eq(hero.xp, 0.0)
