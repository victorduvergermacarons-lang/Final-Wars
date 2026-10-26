extends GutTest

const F := preload("res://tests/unit/progression_fixtures.gd")

var strike: AbilityDef
var sword: ItemDef
var staff: ItemDef
var shield: ItemDef


func before_each() -> void:
	strike = F.ability(&"strike", 30)
	sword = F.item(&"sword", EquipSlot.Type.MAIN_HAND, {Stat.Id.PHYS_ATK: 12, Stat.Id.HP: 20}, {}, [strike])
	staff = F.item(&"staff", EquipSlot.Type.MAIN_HAND, {Stat.Id.MAG_ATK: 15}, {}, [F.ability(&"fireball", 30)])
	shield = F.item(&"shield", EquipSlot.Type.OFF_HAND, {Stat.Id.PHYS_DEF: 20}, {}, [F.ability(&"block", 30)])


func test_equipped_items_add_their_stats() -> void:
	var h := F.hero_with([sword, shield])
	assert_eq(h.stats.hp, 120.0)
	assert_eq(h.stats.phys_atk, 12.0)
	assert_eq(h.stats.phys_def, 20.0)
	assert_eq(h.stats.jump, 2.0)


func test_equip_from_bag_swaps_with_the_worn_item() -> void:
	var h := F.hero_with([sword])
	h.bag.add(staff)
	assert_eq(h.equip_from_bag(h.bag.index_of(staff)), "")
	assert_eq(h.equipped_in(EquipSlot.Id.MAIN_HAND), staff)
	assert_eq(h.bag.count_of(sword), 1, "the sword went into the bag")
	assert_eq(h.bag.count_of(staff), 0)
	assert_eq(h.stats.phys_atk, 0.0)
	assert_eq(h.stats.mag_atk, 15.0)


func test_equip_from_an_empty_bag_slot_fails() -> void:
	var h := F.hero_with([])
	assert_eq(h.equip_from_bag(0), "empty")
	assert_null(h.equipped_in(EquipSlot.Id.MAIN_HAND))


func test_unequip_to_bag_needs_room() -> void:
	var h := F.hero_with([sword])
	var junk := F.item(&"junk", EquipSlot.Type.NONE, {}, {})
	for i in h.bag.size():
		h.bag.add(junk)
	assert_eq(h.unequip_to_bag(EquipSlot.Id.MAIN_HAND), "bag_full")
	assert_eq(h.equipped_in(EquipSlot.Id.MAIN_HAND), sword)
	h.bag.remove_at(0)
	assert_eq(h.unequip_to_bag(EquipSlot.Id.MAIN_HAND), "")
	assert_eq(h.bag.count_of(sword), 1)


func test_unequip_clamps_hp_to_new_max() -> void:
	var h := F.hero_with([sword])
	assert_eq(h.hp, 120.0)
	h.unequip(EquipSlot.Id.MAIN_HAND)
	assert_eq(h.stats.hp, 100.0)
	assert_eq(h.hp, 100.0)


func test_abilities_come_from_equipped_items() -> void:
	var h := F.hero_with([sword, shield])
	var ids := h.available_abilities().map(func(a): return a.id)
	assert_eq(ids, [&"strike", &"block"])
	h.unequip(EquipSlot.Id.MAIN_HAND)
	assert_null(h.find_ability(&"strike"), "lost with the sword")


func test_mastered_ability_stays_without_the_item() -> void:
	var h := F.hero_with([sword])
	h.mastered[&"strike"] = strike
	h.unequip(EquipSlot.Id.MAIN_HAND)
	assert_eq(h.find_ability(&"strike"), strike)


func test_from_def() -> void:
	var def := HeroDef.new()
	def.display_name = "Ayla"
	def.base_stats = StatBlock.make({Stat.Id.HP: 90, Stat.Id.MANA: 40})
	def.starting_items = [sword, staff, shield]
	def.starting_equipment = [sword]
	var h := Hero.from_def(7, def)
	assert_eq(h.id, 7)
	assert_eq(h.equipped_items(), [sword] as Array[ItemDef])
	assert_eq(h.bag.count_of(sword), 0, "worn items aren't in the bag")
	assert_eq(h.bag.count_of(staff) + h.bag.count_of(shield), 2)
	assert_eq(h.hp, 110.0, "starts at full HP including gear")
	assert_eq(def.base_stats.hp, 90.0, "def not mutated")
