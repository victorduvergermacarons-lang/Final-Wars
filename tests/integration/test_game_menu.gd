extends GutTest
## The Escape menu (log, controls, keybinds, leave game), what Esc does first,
## and the foldable quest tracker.

const SETTINGS := "user://test_game_menu_settings.cfg"

var game: Game
var hud: Hud


func before_each() -> void:
	game = Game.new()
	game.settings_path = SETTINGS
	add_child(game)
	game.start_solo(CharacterData.new_character("Esc", ContentDB.heroes[&"adventurer"]))
	hud = game.get_node("Hud")
	await wait_process_frames(2)


func after_each() -> void:
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


func test_esc_closes_open_menus_before_opening_the_escape_menu() -> void:
	hud._toggle(hud.inventory_window)
	await wait_process_frames(1)
	assert_true(hud.book.visible)
	assert_true(hud._escape(), "Esc is used")
	await wait_process_frames(1)
	assert_false(hud.book.visible, "first Esc closes the book")
	assert_false(hud.game_menu.visible)
	assert_true(hud._escape())
	assert_true(hud.game_menu.visible, "next Esc opens the menu")
	assert_true(hud._escape())
	assert_false(hud.game_menu.visible, "and Esc closes it again")


func test_esc_clears_a_target_before_opening_the_menu() -> void:
	hud.client.target_id = 99
	assert_false(hud._escape(), "left to PlayerInput, which clears the target")
	assert_false(hud.game_menu.visible)
	hud.client.target_id = -1
	assert_true(hud._escape())
	assert_true(hud.game_menu.visible)


func test_the_log_tab_shows_everything_said() -> void:
	for i in 8:
		hud.client.say("Message %d" % i)
	hud.game_menu.visible = true
	await wait_process_frames(1)
	assert_string_contains(hud.game_menu._log.text, "Message 0", "older than the 5 recent messages")
	assert_string_contains(hud.game_menu._log.text, "Message 7")


func test_keybinds_button_starts_keybind_mode() -> void:
	hud.game_menu.visible = true
	hud.game_menu._bind.pressed.emit()
	assert_true(hud.bind_mode)
	assert_false(hud.game_menu.visible, "the menu gets out of the way of the action bar")


func test_the_book_arrows_turn_through_the_menus() -> void:
	hud._toggle(hud.inventory_window)
	await wait_process_frames(1)
	assert_eq(hud.book.prev_button.text, "<  Character")
	assert_eq(hud.book.next_button.text, "Spellbook  >")
	hud.book.next_button.pressed.emit()
	assert_true(hud._spellbook.visible)
	assert_false(hud.inventory_window.visible, "one menu at a time")
	hud.book.prev_button.pressed.emit()
	hud.book.prev_button.pressed.emit()
	assert_true(hud._character.visible)
	hud.book.prev_button.pressed.emit()
	assert_true(hud.quest_log.visible, "wraps around to the last")
	hud.book.next_button.pressed.emit()
	assert_true(hud._character.visible, "and back to the first")


func test_the_quest_tracker_folds_to_its_heading() -> void:
	hud._fold_tracker(true)
	assert_false(hud._tracker.visible)
	assert_eq(hud._tracker_fold.text, "+")
	hud._fold_tracker(false)
	assert_true(hud._tracker.visible)
