extends GutTest

const F := preload("res://tests/unit/progression_fixtures.gd")

var rules: CombatRules
var sword: ItemDef
var charm: ItemDef


func before_each() -> void:
	rules = CombatRules.new()
	rules.growth_fraction = 0.5
	sword = F.item(&"sword", EquipSlot.Type.MAIN_HAND, {}, {Stat.Id.PHYS_ATK: 4, Stat.Id.HP: 10})
	charm = F.item(&"charm", EquipSlot.Type.ACCESSORY, {}, {Stat.Id.MAG_ATK: 2, Stat.Id.HP: 6})


func test_gain_is_fraction_of_every_equipped_items_growth() -> void:
	var gain := ItemGrowth.gain_for_level([sword, charm] as Array[ItemDef], StatBlock.new(), rules)
	assert_eq(gain.phys_atk, 2.0)
	assert_eq(gain.mag_atk, 1.0)
	assert_eq(gain.hp, 8.0)


func test_no_limit_by_default() -> void:
	assert_eq(rules.growth_limit, CombatRules.GrowthLimit.NONE)
	var gain := ItemGrowth.gain_for_level([sword] as Array[ItemDef], StatBlock.make({Stat.Id.PHYS_ATK: 9999}), rules)
	assert_eq(gain.phys_atk, 2.0)


func test_cap_mode_stops_at_cap_per_stat() -> void:
	rules.growth_limit = CombatRules.GrowthLimit.CAP
	rules.growth_cap = StatBlock.make({Stat.Id.PHYS_ATK: 10})
	var so_far := StatBlock.make({Stat.Id.PHYS_ATK: 9, Stat.Id.HP: 500})
	var gain := ItemGrowth.gain_for_level([sword] as Array[ItemDef], so_far, rules)
	assert_eq(gain.phys_atk, 1.0, "only 1 left under the cap")
	assert_eq(gain.hp, 5.0, "HP has no cap (0)")
	so_far.phys_atk = 12
	assert_eq(ItemGrowth.gain_for_level([sword] as Array[ItemDef], so_far, rules).phys_atk, 0.0)


func test_diminishing_mode_halves_at_half_point() -> void:
	rules.growth_limit = CombatRules.GrowthLimit.DIMINISHING
	rules.growth_half_point = StatBlock.make({Stat.Id.PHYS_ATK: 20})
	var fresh := ItemGrowth.gain_for_level([sword] as Array[ItemDef], StatBlock.new(), rules)
	assert_eq(fresh.phys_atk, 2.0)
	var grown := ItemGrowth.gain_for_level([sword] as Array[ItemDef], StatBlock.make({Stat.Id.PHYS_ATK: 20}), rules)
	assert_almost_eq(grown.phys_atk, 1.0, 0.0001)
	assert_eq(grown.hp, 5.0, "HP has no half point (0)")


func test_level_up_growth_is_permanent_after_unequip() -> void:
	var h := F.hero_with([sword])
	Leveling.level_up(h, rules)
	h.unequip(EquipSlot.Id.MAIN_HAND)
	assert_eq(h.stats.phys_atk, 2.0, "kept the growth, lost the sword")
	assert_eq(h.stats.hp, 105.0)


func test_only_items_equipped_at_level_up_count() -> void:
	var h := F.hero_with([sword])
	Leveling.level_up(h, rules)
	h.wear(charm)
	Leveling.level_up(h, rules)
	assert_eq(h.growth.phys_atk, 4.0, "sword grew twice")
	assert_eq(h.growth.mag_atk, 1.0, "charm grew once")
