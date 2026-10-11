extends GutTest

const F := preload("res://tests/unit/progression_fixtures.gd")

var rules: CombatRules
var strike: AbilityDef
var heal: AbilityDef
var rez: AbilityDef
var sword: ItemDef
var charm: ItemDef


func before_each() -> void:
	rules = CombatRules.new()
	rules.ap_per_level = 10
	strike = F.ability(&"strike", 30)
	heal = F.ability(&"heal", 20)
	rez = F.ability(&"resurrect", 40)
	sword = F.item(&"sword", EquipSlot.Type.MAIN_HAND, {}, {}, [strike])
	charm = F.item(&"charm", EquipSlot.Type.ACCESSORY, {}, {}, [heal, rez])


func test_level_up_awards_ap_to_equipped_abilities() -> void:
	var h := F.hero_with([sword, charm])
	Leveling.level_up(h, rules)
	assert_eq(h.ap, {&"strike": 10, &"heal": 10, &"resurrect": 10})


func test_unequipped_items_earn_nothing() -> void:
	var h := F.hero_with([sword])
	h.inventory.append(charm)
	Leveling.level_up(h, rules)
	assert_false(h.ap.has(&"heal"))


func test_mastery_at_threshold_is_permanent() -> void:
	var h := F.hero_with([sword])
	Leveling.level_up(h, rules)
	Leveling.level_up(h, rules)
	assert_false(h.is_mastered(&"strike"))
	var events := Leveling.level_up(h, rules)
	assert_true(h.is_mastered(&"strike"))
	assert_true(events.any(func(e): return e.type == "mastered" and e.ability == &"strike"))
	h.unequip(EquipSlot.Id.MAIN_HAND)
	assert_eq(h.find_ability(&"strike"), strike, "usable without the sword")


func test_item_with_two_abilities_masters_them_independently() -> void:
	var h := F.hero_with([charm])
	Leveling.level_up(h, rules)
	Leveling.level_up(h, rules)
	assert_true(h.is_mastered(&"heal"))
	assert_false(h.is_mastered(&"resurrect"))
	assert_eq(h.ap[&"resurrect"], 20)


func test_ap_does_not_overflow_or_continue_after_mastery() -> void:
	var h := F.hero_with([sword])
	var events := ApMastery.award(h, 100)
	assert_eq(h.ap[&"strike"], 30)
	assert_eq(ApMastery.award(h, 10).size(), 0)
	assert_eq(events.size(), 2, "ap + mastered")


func test_ap_progress_survives_swapping_items() -> void:
	var h := F.hero_with([sword])
	Leveling.level_up(h, rules)
	h.unequip(EquipSlot.Id.MAIN_HAND)
	Leveling.level_up(h, rules)
	h.equip(sword)
	Leveling.level_up(h, rules)
	assert_eq(h.ap[&"strike"], 20)


func test_abilities_without_threshold_are_never_mastered() -> void:
	var claw := F.ability(&"claw", 0)
	var h := F.hero_with([F.item(&"claws", EquipSlot.Type.MAIN_HAND, {}, {}, [claw])])
	assert_eq(ApMastery.award(h, 100).size(), 0)
	assert_false(h.is_mastered(&"claw"))
