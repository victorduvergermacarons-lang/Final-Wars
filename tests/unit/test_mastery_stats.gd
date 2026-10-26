extends GutTest
## Tree Mastery stats: permanent (base + growth) vs gear.

var hero: Hero


func before_each() -> void:
	hero = Hero.from_def(1, ContentDB.heroes[&"adventurer"])


func _item(stats: Dictionary, growth: Dictionary = {}) -> ItemDef:
	var i := ItemDef.new()
	i.id = &"test_charm"
	i.slot = EquipSlot.Type.ACCESSORY
	i.stats = StatBlock.make(stats)
	i.growth = StatBlock.make(growth)
	return i


func test_seven_mastery_stats() -> void:
	assert_eq(Stat.COUNT, 19)
	assert_eq(Stat.core().size(), 12)
	for tree in Mastery.TREES:
		assert_true(Mastery.stat_for(tree) >= Stat.CORE_COUNT, tree)
	assert_eq(ItemTooltip.STAT_LABELS.size(), Stat.COUNT)
	assert_eq(ItemTooltip.STAT_LABELS[Stat.Id.WATER_MASTERY], "Water Mastery")


func test_gear_mastery_adds_power_but_not_permanent() -> void:
	hero.wear(_item({Stat.Id.FIRE_MASTERY: 50}))
	assert_eq(Mastery.total(hero, "Fire", 0.0), 50.0)
	assert_eq(Mastery.permanent(hero, "Fire"), 0.0, "gear doesn't unlock tiers")


func test_earned_mastery_is_permanent_and_saves() -> void:
	Mastery.add_permanent(hero, "Water", 160.0)
	assert_eq(Mastery.permanent(hero, "Water"), 160.0)
	assert_eq(Mastery.total(hero, "Water", 0.0), 160.0)
	assert_eq(Mastery.best_element(hero), 160.0)
	var back := CharacterData.restore(2, JSON.parse_string(JSON.stringify(CharacterData.capture(hero))), ContentDB)
	assert_eq(Mastery.permanent(back, "Water"), 160.0)


func test_item_growth_can_grant_mastery() -> void:
	hero.wear(_item({}, {Stat.Id.EARTH_MASTERY: 20}))
	Leveling.add_xp(hero, 100, ContentDB.rules)
	assert_eq(hero.level, 2)
	assert_almost_eq(Mastery.permanent(hero, "Earth"), 20.0 * ContentDB.rules.growth_fraction, 0.001)


func test_mastery_survives_the_network_form() -> void:
	var block := StatBlock.make({Stat.Id.HAMMER_MASTERY: 12.5})
	assert_eq(StatBlock.from_dict(block.to_dict()).hammer_mastery, 12.5)
