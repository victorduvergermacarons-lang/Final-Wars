extends GutTest
## The power formula: base + stats, × Mastery; durations and charges.

var rules: CombatRules
var hero: Hero
var ability: AbilityDef


func before_each() -> void:
	rules = CombatRules.new()
	hero = Hero.new(1, StatBlock.make({Stat.Id.MAG_ATK: 20, Stat.Id.PHYS_ATK: 7}))
	ability = AbilityDef.new()
	ability.id = &"F01"
	ability.tree = "Fire"
	ability.tier = 1
	ability.sheet = {"scales_with": [{"mastery": "Fire"}, {"stat": "mag_atk"}]}


func _effect(base: float, sheet := true) -> AbilityEffect:
	var e := AbilityEffect.new()
	e.base_amount = base
	e.sheet_scaling = sheet
	return e


func test_base_plus_sheet_stats_times_mastery() -> void:
	assert_eq(AbilityPower.amount(hero, ability, _effect(10), 0.0, rules), 30.0, "10 + 1.0 × MagAtk 20")
	Mastery.add_permanent(hero, "Fire", 200)
	assert_almost_eq(AbilityPower.amount(hero, ability, _effect(10), 0.0, rules), 36.0, 0.001, "× 1.2 at 200 Mastery")


func test_gear_mastery_adds_power() -> void:
	var charm := ItemDef.new()
	charm.slot = EquipSlot.Type.ACCESSORY
	charm.stats = StatBlock.make({Stat.Id.FIRE_MASTERY: 500})
	hero.wear(charm)
	assert_almost_eq(AbilityPower.amount(hero, ability, _effect(10), 0.0, rules), 45.0, 0.001)


func test_tier_default_base() -> void:
	ability.tier = 3
	assert_eq(AbilityPower.amount(hero, ability, _effect(-1), 0.0, rules), rules.tier_damage_base[2] + 20.0)
	var heal := _effect(-1)
	heal.kind = AbilityEffect.Kind.HEAL
	assert_eq(AbilityPower.amount(hero, ability, heal, 0.0, rules), rules.tier_heal_base[2] + 20.0)


func test_own_scaling_when_not_using_the_sheet() -> void:
	var e := _effect(5, false)
	e.scaling = [AbilityScaling.make(Stat.Id.PHYS_ATK, 2.0)] as Array[AbilityScaling]
	assert_eq(AbilityPower.amount(hero, ability, e, 0.0, rules), 19.0)


func test_non_tree_abilities_ignore_mastery() -> void:
	ability.tree = ""
	Mastery.add_permanent(hero, "Fire", 900)
	var e := _effect(5, false)
	assert_eq(AbilityPower.amount(hero, ability, e, 0.0, rules), 5.0)


func test_duration_and_charges() -> void:
	Mastery.add_permanent(hero, "Fire", 600)
	assert_almost_eq(AbilityPower.duration(hero, ability, 10.0, 0.0, rules), 13.0, 0.001)
	assert_eq(AbilityPower.charges(hero, ability, 1, 300.0, 0.0), 3, "Flame Dash: 1, +1 per 300")
