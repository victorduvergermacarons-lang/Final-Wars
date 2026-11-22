extends GutTest
## The ability wheel's four slots (2026-11-22; was 6 pages of 10).

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


func test_defaults_are_four_empty_slots() -> void:
	assert_eq(bar.slots.size(), 4)
	assert_eq(bar.slots.count(&""), 4)


func test_auto_place_fills_b_first_then_the_others_once() -> void:
	# Abilities with no slot of their own: B, then X, Y, A.
	bar.auto_place(_ids([&"strike", &"heal"]))
	assert_eq(bar.slots[3], &"strike")
	assert_eq(bar.slots[0], &"heal")
	bar.clear(3)
	bar.auto_place(_ids([&"strike", &"heal", &"fireball"]))
	assert_eq(bar.slots[3], &"fireball", "cleared slot reused by the new ability")
	assert_eq(bar.slot_of(&"strike"), -1, "a cleared ability isn't put back")


func test_abilities_that_dont_fit_wait_for_a_free_slot() -> void:
	bar.auto_place(_ids([&"a", &"b", &"c", &"d", &"e"]))
	assert_eq(bar.slots, _ids([&"b", &"c", &"d", &"a"]))
	bar.clear(1)
	bar.auto_place(_ids([&"a", &"b", &"c", &"d", &"e"]))
	assert_eq(bar.slots[1], &"e", "placed once there was room")


func test_assign_moves_an_ability_already_on_the_wheel() -> void:
	bar.auto_place(_ids([&"strike", &"heal"]))
	bar.assign(1, &"strike")
	assert_eq(bar.slots[1], &"strike")
	assert_eq(bar.slots[3], &"", "moved, not duplicated")


func test_assign_onto_occupied_slot_swaps() -> void:
	bar.auto_place(_ids([&"strike", &"heal"]))
	bar.assign(0, &"strike")
	assert_eq(bar.slots[3], &"heal")
	assert_eq(bar.slots[0], &"strike")


func test_swap() -> void:
	bar.auto_place(_ids([&"strike"]))
	bar.swap(3, 0)
	assert_eq(bar.slots[0], &"strike")
	assert_eq(bar.slots[3], &"")

func test_save_and_load_round_trip() -> void:
	bar.auto_place(_ids([&"strike", &"heal"]))
	SettingsStore.save_action_bar(bar, PATH)
	var other := ActionBarModel.new()
	SettingsStore.load_action_bar(other, PATH)
	assert_eq(other.slots, bar.slots)
	other.auto_place(_ids([&"strike"]))
	assert_eq(other.slots.count(&"strike"), 1, "remembers what was auto-placed")


func test_loading_garbage_falls_back_to_defaults() -> void:
	bar.load_dict({"slots": [5, null], "keys": ["x"]})
	assert_eq(bar.slots[0], &"")


func test_old_saves_start_over() -> void:
	# The 10-slot bar and the first wheel (no role placement): placed again by role.
	bar.load_dict({"pages": [["strike", "", "heal", "fire", "lost"], ["other"]], "page": 1,
			"auto_placed": ["lost", "other"]})
	assert_eq(bar.slots.count(&""), 4)
	bar.auto_place(_ids([&"lost"]))
	assert_eq(bar.slots.count(&"lost"), 1, "placed again")
	var first := ActionBarModel.new()
	first.load_dict({"slots": ["strike", "", "heal"], "auto_placed": ["strike"]})
	assert_eq(first.slots.count(&""), 4)


## Roles as the game gives them: the weapon art on X (0), ranged on Y (1), a dash
## or Earth's defense on A (2), anything else on none (B first).
static func _roles(id: StringName) -> int:
	return {&"slash": 0, &"dart": 1, &"whip": 1, &"dash": 2, &"stone_skin": 2}.get(id, -1)


func test_new_abilities_go_to_their_own_slot() -> void:
	bar.auto_place(_ids([&"punch", &"dart", &"dash"]), _roles)
	assert_eq(bar.slots, _ids([&"", &"dart", &"dash", &"punch"]), "punch on B, dart on Y, dash on A")
	bar.auto_place(_ids([&"slash"]), _roles)
	assert_eq(bar.slots[0], &"slash", "the weapon on X")


func test_the_weapon_takes_x_back_from_an_ability_that_doesnt_belong_there() -> void:
	bar.auto_place(_ids([&"punch", &"kick"]), _roles)
	assert_eq(bar.slots, _ids([&"kick", &"", &"", &"punch"]), "no weapon yet: X is free to use")
	bar.auto_place(_ids([&"slash"]), _roles)
	assert_eq(bar.slots[0], &"slash")
	assert_eq(bar.slots.count(&"kick"), 1, "the kick moved to a free slot")
	bar.auto_place(_ids([&"whip"]), _roles)
	assert_eq(bar.slots[1], &"whip", "ranged takes Y back from the kick")
	assert_eq(bar.slots.count(&"kick"), 1)


func test_what_the_player_placed_stays() -> void:
	bar.assign(0, &"punch")
	bar.auto_place(_ids([&"slash"]), _roles)
	assert_eq(bar.slots[0], &"punch", "dragged there by the player: kept")
	assert_eq(bar.slots.count(&"slash"), 1, "the weapon found another slot")


func test_a_ranged_attack_keeps_y_from_a_second_one() -> void:
	bar.auto_place(_ids([&"dart", &"whip"]), _roles)
	assert_eq(bar.slots[1], &"dart")
	assert_eq(bar.slots[3], &"whip", "the second goes to B")

func test_the_slots_have_fixed_buttons_on_both_devices() -> void:
	InputActions.ensure_registered()
	var events := InputMap.action_get_events(InputActions.slot_action(0))
	var kinds := events.map(func(e): return e.get_class())
	assert_true(kinds.has("InputEventMouseButton"), "slot 1: left click")
	assert_true(kinds.has("InputEventJoypadButton"), "and a face button")
	assert_eq(InputActions.hint(InputActions.slot_action(2), InputDevice.Kind.KEYBOARD), "Q")