extends GutTest
## Creating a character from the main menu opens the element screen; choosing an
## element saves the character with it; Back leaves without one.

const DIR := "user://test_element_menu/"
var menu: MainMenu


func before_each() -> void:
	menu = MainMenu.new()
	menu.store = CharacterStore.new(DIR)
	add_child(menu)
	await wait_process_frames(2)


func after_each() -> void:
	menu.free()
	var dir := ProjectSettings.globalize_path(DIR)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


func test_creating_asks_for_the_element_then_saves_it() -> void:
	menu._new_name.text = "Brook"
	menu._on_create()
	assert_not_null(menu.element_screen, "the element screen opens")
	assert_false(menu.store.exists("Brook"), "not saved before an element is chosen")
	await wait_process_frames(2)
	menu.element_screen.buttons[&"water"].pressed.emit()
	assert_null(menu.element_screen)
	var data := menu.store.load_character("Brook")
	assert_eq(data.element, "water")
	assert_eq(data.learning, "river_lash_scroll")


func test_back_creates_nothing() -> void:
	menu._new_name.text = "Brook"
	menu._on_create()
	await wait_process_frames(2)
	menu.element_screen.cancelled.emit()
	assert_null(menu.element_screen)
	assert_false(menu.store.exists("Brook"))
