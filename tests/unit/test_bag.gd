extends GutTest

const F := preload("res://tests/unit/progression_fixtures.gd")

var bag: Bag
var potion: ItemDef
var sword: ItemDef


func before_each() -> void:
	bag = Bag.new(4)
	potion = F.item(&"potion", EquipSlot.Type.NONE, {}, {})
	potion.max_stack = 20
	sword = F.item(&"sword", EquipSlot.Type.MAIN_HAND, {}, {})


func test_default_size_is_20() -> void:
	assert_eq(Bag.new().size(), 20)


func test_stacks_fill_before_new_slots() -> void:
	assert_eq(bag.add(potion, 15), 0)
	assert_eq(bag.add(potion, 10), 0)
	assert_eq(bag.count_at(0), 20)
	assert_eq(bag.count_at(1), 5)
	assert_eq(bag.count_of(potion), 25)


func test_equippable_items_take_one_slot_each() -> void:
	bag.add(sword, 3)
	assert_eq(bag.free_slots(), 1)


func test_overflow_is_returned() -> void:
	assert_eq(bag.add(sword, 6), 2)
	assert_eq(bag.room_for(sword), 0)
	assert_eq(bag.room_for(potion), 0)


func test_room_for_counts_partial_stacks() -> void:
	bag.add(potion, 15)
	bag.add(sword, 3)
	assert_eq(bag.room_for(potion), 5)


func test_remove_item_is_all_or_nothing() -> void:
	bag.add(potion, 25)
	assert_false(bag.remove_item(potion, 30))
	assert_eq(bag.count_of(potion), 25)
	assert_true(bag.remove_item(potion, 22))
	assert_eq(bag.count_of(potion), 3)


func test_move_swaps_or_merges() -> void:
	bag.add(sword)
	bag.move(0, 3)
	assert_null(bag.item_at(0))
	assert_eq(bag.item_at(3), sword)
	bag.add(potion, 20)
	bag.add(potion, 5)
	var full := bag.index_of(potion)
	var partial := -1
	for i in bag.size():
		if bag.item_at(i) == potion and i != full:
			partial = i
	bag.remove_at(full, 8) # 12 left
	bag.move(partial, full)
	assert_eq(bag.count_at(full), 17)
	assert_null(bag.item_at(partial))


func test_split() -> void:
	bag.add(potion, 10)
	assert_true(bag.split(0, 4))
	assert_eq(bag.count_at(0), 6)
	assert_eq(bag.count_at(1), 4)
	assert_false(bag.split(0, 6), "can't split off everything")


func test_plain_data_round_trip_drops_unknown_ids() -> void:
	bag.add(potion, 7)
	bag.add(sword)
	var data := bag.to_array()
	data[3] = ["mystery", 1]
	var copy := Bag.from_array(data, {&"potion": potion, &"sword": sword}, 4)
	assert_eq(copy.count_of(potion), 7)
	assert_eq(copy.count_of(sword), 1)
	assert_null(copy.item_at(3))
	var hacked := Bag.from_array([["potion", 999]], {&"potion": potion}, 4)
	assert_eq(hacked.count_at(0), 20, "stack size is clamped")
