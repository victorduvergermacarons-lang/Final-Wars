extends GutTest


func test_valid_intents_pass_through() -> void:
	assert_eq(Intents.sanitize({"type": "step", "to": Vector2i(1, 2), "seq": 3}),
			{"type": "step", "to": Vector2i(1, 2), "seq": 3})
	assert_eq(Intents.sanitize({"type": "cast", "ability": "heal", "target": 4}),
			{"type": "cast", "ability": &"heal", "target": 4})
	assert_eq(Intents.sanitize({"type": "release"}), {"type": "release"})
	assert_eq(Intents.sanitize({"type": "face", "dir": Vector2i.UP}), {"type": "face", "dir": Vector2i.UP})
	assert_eq(Intents.sanitize({"type": "equip", "bag_index": 3}), {"type": "equip", "bag_index": 3})
	assert_eq(Intents.sanitize({"type": "equip", "bag_index": 3, "slot": 7}), {"type": "equip", "bag_index": 3, "slot": 7})
	assert_eq(Intents.sanitize({"type": "move_item", "from": 0, "to": 4}), {"type": "move_item", "from": 0, "to": 4})
	assert_eq(Intents.sanitize({"type": "split_item", "index": 2, "count": 5}), {"type": "split_item", "index": 2, "count": 5})
	assert_eq(Intents.sanitize({"type": "destroy_item", "index": 2}), {"type": "destroy_item", "index": 2})
	assert_eq(Intents.sanitize({"type": "buy", "npc": 4, "item": "minor_health_potion", "count": 2}),
			{"type": "buy", "npc": 4, "item": &"minor_health_potion", "count": 2})
	assert_eq(Intents.sanitize({"type": "sell", "npc": 4, "bag_index": 3, "count": 1}),
			{"type": "sell", "npc": 4, "bag_index": 3, "count": 1})
	assert_eq(Intents.sanitize({"type": "use_item", "bag_index": 3}), {"type": "use_item", "bag_index": 3})
	assert_eq(Intents.sanitize({"type": "unequip", "slot": 1}), {"type": "unequip", "slot": 1})


func test_malformed_intents_are_dropped() -> void:
	for bad in [null, 5, "step", {}, {"type": 7}, {"type": "fly"},
			{"type": "step", "to": Vector2(1, 2)}, {"type": "step"},
			{"type": "cast", "ability": 3}, {"type": "cast", "ability": "x", "target": "me"},
			{"type": "unequip", "slot": "main"}, {"type": "face", "dir": "up"},
			{"type": "equip", "item": "staff"}, {"type": "move_item", "from": 0}, {"type": "destroy_item", "index": "1"}, {"type": "release", "seq": "1"}]:
		assert_eq(Intents.sanitize(bad), {}, str(bad))


func test_extra_fields_are_stripped() -> void:
	assert_eq(Intents.sanitize({"type": "release", "hp": 9999}), {"type": "release"})
