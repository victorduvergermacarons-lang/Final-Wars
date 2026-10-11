extends GutTest


func test_valid_intents_pass_through() -> void:
	assert_eq(Intents.sanitize({"type": "step", "to": Vector2i(1, 2), "seq": 3}),
			{"type": "step", "to": Vector2i(1, 2), "seq": 3})
	assert_eq(Intents.sanitize({"type": "cast", "ability": "heal", "target": 4}),
			{"type": "cast", "ability": &"heal", "target": 4})
	assert_eq(Intents.sanitize({"type": "release"}), {"type": "release"})
	assert_eq(Intents.sanitize({"type": "equip", "item": "staff"}), {"type": "equip", "item": &"staff"})
	assert_eq(Intents.sanitize({"type": "unequip", "slot": 1}), {"type": "unequip", "slot": 1})


func test_malformed_intents_are_dropped() -> void:
	for bad in [null, 5, "step", {}, {"type": 7}, {"type": "fly"},
			{"type": "step", "to": Vector2(1, 2)}, {"type": "step"},
			{"type": "cast", "ability": 3}, {"type": "cast", "ability": "x", "target": "me"},
			{"type": "unequip", "slot": "main"}, {"type": "release", "seq": "1"}]:
		assert_eq(Intents.sanitize(bad), {}, str(bad))


func test_extra_fields_are_stripped() -> void:
	assert_eq(Intents.sanitize({"type": "release", "hp": 9999}), {"type": "release"})
