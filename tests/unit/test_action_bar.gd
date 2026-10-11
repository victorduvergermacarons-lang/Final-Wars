extends GutTest

const PATH := "user://test_action_bar.cfg"

var bar: ActionBarModel


func before_each() -> void:
	bar = ActionBarModel.new()


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _ids(a: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for x in a:
		out.append(x)
	return out


func test_defaults_are_ten_empty_slots_on_1_to_0() -> void:
	assert_eq(bar.slots.size(), 10)
	assert_eq(bar.slots.count(&""), 10)
	assert_eq(bar.keys[0], KEY_1)
	assert_eq(bar.keys[9], KEY_0)


func test_auto_place_fills_first_empty_slots_once() -> void:
	bar.auto_place(_ids([&"strike", &"heal"]))
	assert_eq(bar.slots[0], &"strike")
	assert_eq(bar.slots[1], &"heal")
	bar.clear(0)
	bar.auto_place(_ids([&"strike", &"heal", &"fireball"]))
	assert_eq(bar.slots[0], &"fireball", "cleared slot reused by the new ability")
	assert_eq(bar.slot_of(&"strike"), -1, "a cleared ability isn't put back")


func test_assign_moves_an_ability_already_on_the_bar() -> void:
	bar.auto_place(_ids([&"strike", &"heal"]))
	bar.assign(5, &"strike")
	assert_eq(bar.slots[5], &"strike")
	assert_eq(bar.slots[0], &"", "moved, not duplicated")


func test_assign_onto_occupied_slot_swaps() -> void:
	bar.auto_place(_ids([&"strike", &"heal"]))
	bar.assign(1, &"strike")
	assert_eq(bar.slots[0], &"heal")
	assert_eq(bar.slots[1], &"strike")


func test_swap() -> void:
	bar.auto_place(_ids([&"strike"]))
	bar.swap(0, 7)
	assert_eq(bar.slots[7], &"strike")
	assert_eq(bar.slots[0], &"")


func test_rebinding_steals_key_from_other_slot() -> void:
	assert_true(bar.set_key(4, KEY_1))
	assert_eq(bar.keys[4], KEY_1)
	assert_eq(bar.keys[0], KEY_NONE)
	assert_eq(bar.key_label(0), "")


func test_reserved_keys_cannot_be_bound() -> void:
	for key in [KEY_W, KEY_UP, KEY_TAB, KEY_ESCAPE, KEY_R, KEY_P, KEY_C]:
		assert_false(bar.set_key(0, key), OS.get_keycode_string(key))
	assert_eq(bar.keys[0], KEY_1)
	assert_true(bar.set_key(0, KEY_Q))


func test_save_and_load_round_trip() -> void:
	bar.auto_place(_ids([&"strike", &"heal"]))
	bar.set_key(1, KEY_Q)
	SettingsStore.save_action_bar(bar, PATH)
	var other := ActionBarModel.new()
	SettingsStore.load_action_bar(other, PATH)
	assert_eq(other.slots, bar.slots)
	assert_eq(other.keys, bar.keys)
	other.auto_place(_ids([&"strike"]))
	assert_eq(other.slots.count(&"strike"), 1, "remembers what was auto-placed")


func test_loading_garbage_falls_back_to_defaults() -> void:
	bar.load_dict({"slots": [5, null], "keys": ["x"]})
	assert_eq(bar.slots[0], &"")
	assert_eq(bar.keys[0], KEY_1)


func test_keys_are_applied_to_input_map() -> void:
	bar.set_key(2, KEY_Q)
	InputActions.apply_action_bar_keys(bar)
	var events := InputMap.action_get_events(InputActions.slot_action(2))
	assert_eq(events.size(), 1)
	assert_eq(events[0].physical_keycode, KEY_Q)
	assert_eq(InputMap.action_get_events(InputActions.slot_action(0)).size(), 1)
