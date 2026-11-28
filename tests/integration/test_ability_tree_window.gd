extends GutTest
## The ability tree screen (Milestone 3 §6): states, Mastery thresholds,
## prerequisite lines, and dragging an ability onto the action bar.

const SETTINGS := "user://test_tree_settings.cfg"

var game: Game
var hud: Hud
var hero: Hero


func before_each() -> void:
	game = Game.new()
	game.settings_path = SETTINGS
	add_child(game)
	game.start_solo(CharacterData.new_character("Tree", ContentDB.heroes[&"adventurer"]))
	hud = game.get_node("Hud")
	hero = game.session.local_hero()


func after_each() -> void:
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


func _a(id: String) -> AbilityDef:
	return ContentDB.abilities[StringName(id)]


func test_states_follow_the_rules() -> void:
	var S := AbilityTreeWindow.State
	assert_eq(AbilityTreeWindow.state_of(hero, _a("F01")), S.LEARNING, "Ember Fist Scroll is in the learning slot")
	assert_eq(AbilityTreeWindow.state_of(hero, _a("F03")), S.LEARNABLE, "tier 1, no prerequisites")
	assert_eq(AbilityTreeWindow.state_of(hero, _a("F06")), S.LOCKED, "needs Fire Stream and 260 Fire Mastery")
	assert_eq(AbilityTreeWindow.state_of(hero, _a("F17")), S.NOT_IN_GAME)
	TreeRules.master(hero, _a("F03"))
	assert_eq(AbilityTreeWindow.state_of(hero, _a("F03")), S.MASTERED)
	assert_string_contains(AbilityTreeWindow.lock_reason(hero, _a("F06")), "Fire Mastery 260")
	Mastery.add_permanent(hero, "Fire", 260)
	TreeRules.master(hero, _a("F12"))
	assert_eq(AbilityTreeWindow.state_of(hero, _a("F06")), S.LEARNABLE, "unlocked")


func test_window_shows_tiers_nodes_and_prerequisite_lines() -> void:
	hud._toggle(hud.trees_window)
	hud.trees_window.show_tree("Fire")
	await wait_process_frames(3)
	var canvas = hud.trees_window._canvas
	assert_eq(canvas._nodes.size(), ContentDB.tree.ids("Fire").size())
	assert_gt(canvas._lines.size(), 5, "prerequisite lines")
	assert_string_contains(hud.trees_window._header.text, "Fire Mastery")
	var punch: Button = canvas.node(&"F01")
	assert_string_contains(punch.text, "AP 0/20", "the ability being learned shows its AP")
	hud.trees_window.show_tree("Sword")
	await wait_process_frames(3)
	assert_not_null(canvas.node(&"S01"))


func test_drag_a_usable_ability_onto_the_bar() -> void:
	hud._toggle(hud.trees_window)
	hud.trees_window.show_tree("Fire")
	await wait_process_frames(3)
	var canvas = hud.trees_window._canvas
	assert_null(canvas.node(&"F03").drag_payload(), "not usable yet: no drag")
	var data = canvas.node(&"F01").drag_payload()
	assert_eq(data, {"ability": &"F01"})
	var slot: SlotButton = hud.find_children("*", "SlotButton", true, false)[9]
	assert_true(slot._can_drop_data(Vector2.ZERO, data))
	slot._drop_data(Vector2.ZERO, data)
	assert_eq(game.client.action_bar.slots[9], &"F01")


func test_water_shows_each_abilitys_own_step() -> void:
	# Every tree unlocks one ability per step (Water since 2026-11-15, all trees since
	# the stance rework): a locked node says what it needs, columns open with their
	# first ability, and each column goes down in unlock order.
	assert_eq(AbilityTreeWindow.node_text(hero, _a("W03")).get_slice("\n", 1), "Needs 295",
			"Flow State (tier 3, step 2) shows its own step")
	assert_string_contains(AbilityTreeWindow.lock_reason(hero, _a("W03")), "Water Mastery 295")
	hud._toggle(hud.trees_window)
	hud.trees_window.show_tree("Water")
	await wait_process_frames(3)
	var canvas = hud.trees_window._canvas
	assert_eq(canvas._nodes.size(), ContentDB.tree.ids("Water").size())
	var mist: Control = canvas.node(&"W05") # tier 2, step 0 (100)
	var blessing: Control = canvas.node(&"W08") # tier 2, step 2 (160)
	assert_lt(mist.position.y, blessing.position.y, "Soothing Mist above Tidal Blessing in its column")
	var headers := canvas.get_children().filter(func(c): return c is Label and c.text.begins_with("Tier 3"))
	assert_eq(headers.size(), 1)
	assert_string_contains(headers[0].text, "needs 225", "tier 3 opens at its base (Revive, Ocean Spirit)")
