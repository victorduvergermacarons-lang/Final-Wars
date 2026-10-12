extends GutTest
## The learning slot in the inventory and on the character sheet, and the
## learning lines in item tooltips (Milestone 3 §6).

const SETTINGS := "user://test_learning_settings.cfg"

var game: Game
var hud: Hud
var hero: Hero


func before_each() -> void:
	game = Game.new()
	game.settings_path = SETTINGS
	add_child(game)
	game.start_solo(CharacterData.new_character("Lea", ContentDB.heroes[&"adventurer"]))
	hud = game.get_node("Hud")
	hero = game.session.local_hero()


func after_each() -> void:
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


func _learning_view(root: Control) -> ItemSlotView:
	for v in root.find_children("*", "ItemSlotView", true, false):
		if v.kind == ItemSlotView.Kind.LEARNING:
			return v
	return null


func test_inventory_and_sheet_show_the_learning_slot() -> void:
	assert_not_null(_learning_view(hud.inventory_window))
	assert_not_null(_learning_view(hud._character))
	assert_eq(_learning_view(hud.inventory_window).item().id, &"ember_fist_scroll")
	assert_string_contains(LearningRow.text_for(hero), "Fire Punch")
	assert_string_contains(LearningRow.text_for(hero), "AP 0 / 20")


func test_drop_a_scroll_on_the_learning_slot() -> void:
	var slot := _learning_view(hud.inventory_window)
	var index := hero.bag.index_of(ContentDB.items[&"menders_scroll"])
	var data := {"item_from": ItemSlotView.Kind.BAG, "index": index}
	assert_true(slot._can_drop_data(Vector2.ZERO, data))
	slot._drop_data(Vector2.ZERO, data)
	await wait_physics_frames(4)
	assert_eq(hero.learning_item.id, &"menders_scroll")
	assert_eq(hero.bag.count_of(ContentDB.items[&"ember_fist_scroll"]), 1, "the old scroll went back to the bag")


func test_drop_the_worn_weapon_then_stop_learning() -> void:
	var slot := _learning_view(hud.inventory_window)
	slot._drop_data(Vector2.ZERO, {"item_from": ItemSlotView.Kind.EQUIP, "index": EquipSlot.Id.MAIN_HAND})
	await wait_physics_frames(4)
	assert_eq(hero.learning_item.id, &"rusty_shortsword")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	slot._gui_input(right)
	await wait_physics_frames(4)
	assert_null(hero.learning_item)
	assert_string_contains(LearningRow.text_for(hero), "nothing")


func test_right_click_a_scroll_to_learn_it() -> void:
	var index := hero.bag.index_of(ContentDB.items[&"menders_scroll"])
	var view: ItemSlotView = null
	for v in hud.inventory_window.find_children("*", "ItemSlotView", true, false):
		if v.kind == ItemSlotView.Kind.BAG and v.index == index:
			view = v
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	view._gui_input(right)
	await wait_physics_frames(4)
	assert_eq(hero.learning_item.id, &"menders_scroll")


func test_tooltips_say_where_an_item_stands() -> void:
	var rules: CombatRules = game.session.rules()
	var learning := ItemTooltip.text(ContentDB.items[&"ember_fist_scroll"], hero, rules, true)
	assert_string_contains(learning, "In your learning slot")
	assert_string_contains(learning, "Per level while in your learning slot")
	var ready := ItemTooltip.text(ContentDB.items[&"menders_scroll"], hero, rules, false)
	assert_string_contains(ready, "Right-click or drag onto Learning")
	var locked := ItemTooltip.text(ContentDB.items[&"lash_of_embers_scroll"], hero, rules, false)
	assert_string_contains(locked, "Locked")
	var later := ItemTooltip.text(ContentDB.items[&"granite_skin_scroll"], hero, rules, false)
	assert_string_contains(later, "isn't in the game yet")
	var weapon := ItemTooltip.text(ContentDB.items[&"iron_mallet"], hero, rules, false)
	assert_string_contains(weapon, "Wield it, then drag it onto Learning")


func test_character_sheet_marks_what_earns_ap() -> void:
	hero.ap[&"S01"] = 4
	var ab := StatBreakdown.abilities(hero)
	var by_id := {}
	for p in ab.in_progress:
		by_id[p.ability.id] = p.earning
	assert_true(by_id[&"F01"], "the scroll in the learning slot earns AP")
	assert_false(by_id[&"S01"], "the worn sword doesn't while it isn't the learning item")
