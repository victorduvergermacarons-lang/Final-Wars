extends GutTest
## Nine equipment positions, accessories, two-handed weapons, rarity.

const F := preload("res://tests/unit/progression_fixtures.gd")

var sword: ItemDef
var shield: ItemDef
var greataxe: ItemDef
var ring: ItemDef
var amulet: ItemDef
var potion: ItemDef
var helm: ItemDef


func before_each() -> void:
	sword = F.item(&"sword", EquipSlot.Type.MAIN_HAND, {Stat.Id.PHYS_ATK: 10}, {})
	shield = F.item(&"shield", EquipSlot.Type.OFF_HAND, {Stat.Id.PHYS_DEF: 10}, {})
	greataxe = F.item(&"greataxe", EquipSlot.Type.TWO_HAND, {Stat.Id.PHYS_ATK: 25}, {})
	ring = F.item(&"ring", EquipSlot.Type.ACCESSORY, {Stat.Id.CRIT_RATE: 2}, {})
	amulet = F.item(&"amulet", EquipSlot.Type.ACCESSORY, {Stat.Id.MANA: 10}, {})
	helm = F.item(&"helm", EquipSlot.Type.HEAD, {Stat.Id.HP: 15}, {})
	potion = F.item(&"potion", EquipSlot.Type.NONE, {}, {})
	potion.max_stack = 20


func _hero(items: Array[ItemDef]) -> Hero:
	var h := Hero.new(1, StatBlock.make({Stat.Id.HP: 100}))
	h.inventory = items.duplicate()
	return h


func test_there_are_nine_positions() -> void:
	assert_eq(EquipSlot.Id.size(), EquipSlot.COUNT)
	assert_eq(EquipSlot.NAMES.size(), EquipSlot.COUNT)
	assert_eq(EquipSlot.TYPE_NAMES.size(), EquipSlot.Type.size())


func test_each_armor_piece_goes_in_its_own_position() -> void:
	var h := _hero([helm, sword, shield])
	assert_true(h.equip(helm))
	assert_true(h.equip(sword))
	assert_true(h.equip(shield))
	assert_eq(h.equipped_in(EquipSlot.Id.HEAD), helm)
	assert_eq(h.stats.hp, 115.0)
	assert_eq(h.equipped_items().size(), 3)


func test_accessories_fill_both_positions() -> void:
	var h := _hero([ring, amulet])
	h.equip(ring)
	h.equip(amulet)
	assert_eq(h.equipped_in(EquipSlot.Id.ACCESSORY_1), ring)
	assert_eq(h.equipped_in(EquipSlot.Id.ACCESSORY_2), amulet)


func test_wearing_the_same_accessory_twice_needs_two_copies() -> void:
	var h := _hero([ring])
	assert_true(h.equip(ring, EquipSlot.Id.ACCESSORY_1))
	assert_false(h.equip(ring, EquipSlot.Id.ACCESSORY_2), "only one owned")
	h.inventory.append(ring)
	assert_true(h.equip(ring, EquipSlot.Id.ACCESSORY_2))
	assert_eq(h.stats.crit_rate, 4.0)


func test_wrong_position_is_refused() -> void:
	var h := _hero([helm, ring, potion])
	assert_false(h.equip(helm, EquipSlot.Id.CHEST))
	assert_false(h.equip(ring, EquipSlot.Id.MAIN_HAND))
	assert_false(h.equip(potion), "potions aren't equippable")


func test_two_hander_takes_both_hands() -> void:
	var h := _hero([sword, shield, greataxe])
	h.equip(sword)
	h.equip(shield)
	assert_eq(h.displaced_by(greataxe), [sword, shield] as Array[ItemDef])
	assert_true(h.equip(greataxe))
	assert_eq(h.equipped_in(EquipSlot.Id.MAIN_HAND), greataxe)
	assert_null(h.equipped_in(EquipSlot.Id.OFF_HAND))
	assert_eq(h.stats.phys_atk, 25.0)


func test_off_hand_replaces_a_two_hander() -> void:
	var h := _hero([shield, greataxe])
	h.equip(greataxe)
	assert_eq(h.displaced_by(shield), [greataxe] as Array[ItemDef])
	assert_true(h.equip(shield))
	assert_null(h.equipped_in(EquipSlot.Id.MAIN_HAND))


func test_rarity_colors_and_names() -> void:
	assert_eq(Rarity.NAMES.size(), Rarity.Id.size())
	assert_eq(Rarity.COLORS.size(), Rarity.Id.size())
	assert_ne(Rarity.color(Rarity.Id.COMMON), Rarity.color(Rarity.Id.EPIC))


func test_item_validation_of_stacks() -> void:
	assert_eq(potion.validate().size(), 0)
	var bad := F.item(&"stacky_sword", EquipSlot.Type.MAIN_HAND, {}, {})
	bad.max_stack = 5
	assert_eq(bad.validate().size(), 1, "equippable items can't stack")


func test_starter_content_uses_the_new_positions() -> void:
	var db = preload("res://autoload/content_db.gd").new()
	assert_eq(db.items[&"sword"].slot, EquipSlot.Type.MAIN_HAND)
	assert_eq(db.items[&"staff"].slot, EquipSlot.Type.MAIN_HAND)
	assert_eq(db.items[&"shield"].slot, EquipSlot.Type.OFF_HAND)
	assert_eq(db.items[&"holy_charm"].slot, EquipSlot.Type.ACCESSORY)
	for item in db.items.values():
		assert_eq(item.rarity, Rarity.Id.COMMON)
		assert_gt(item.price, 0)
	db.free()
