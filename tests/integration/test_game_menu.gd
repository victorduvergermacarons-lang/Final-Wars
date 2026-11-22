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


func test_the_controls_tab_lists_keyboard_and_controller() -> void:
	hud.game_menu.visible = true
	await wait_process_frames(1)
	var text: String = hud.game_menu._controls.text
	assert_string_contains(text, "Left click", "slot 1 on the mouse")
	assert_string_contains(text, "RT", "the timing bar on the controller")
	assert_string_contains(text, "Element power")


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


func test_the_quest_tracker_can_be_dragged() -> void:
	var start := hud._tracker_panel.position
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	hud._on_tracker_drag(press)
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(-50, 20)
	hud._on_tracker_drag(move)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	hud._on_tracker_drag(release)
	assert_almost_eq(hud._tracker_panel.position.x, start.x - 50, 1.0)
	assert_almost_eq(hud._tracker_panel.position.y, start.y + 20, 1.0)
	hud._on_tracker_drag(move)
	assert_almost_eq(hud._tracker_panel.position.x, start.x - 50, 1.0, "only while held")


func test_the_quest_tracker_folds_to_its_heading() -> void:
	hud._fold_tracker(true)
	assert_false(hud._tracker.visible)
	assert_eq(hud._tracker_fold.text, "+")
	hud._fold_tracker(false)
	assert_true(hud._tracker.visible)


## The tracker with two quests in it, so it has something to show.
func _tracker_with_quests() -> void:
	var hero: Hero = game.session.local_hero()
	var n := 0
	for id in ContentDB.quests:
		if n < 2 and QuestLog.accept(hero, ContentDB.quests[id]).size() >= 0:
			n += 1
	await wait_process_frames(3)
	assert_true(hud._tracker_panel.visible, "the tracker shows")


func _drag_tracker(by: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	hud._on_tracker_drag(press)
	var move := InputEventMouseMotion.new()
	move.relative = by
	hud._on_tracker_drag(move)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	hud._on_tracker_drag(release)


func test_folding_a_moved_tracker_shrinks_its_whole_frame_and_keeps_its_place() -> void:
	await _tracker_with_quests()
	var open_size := hud._tracker_panel.size
	_drag_tracker(Vector2(-200, -100))
	var moved_to := hud._tracker_panel.position
	hud._fold_tracker(true)
	await wait_process_frames(2)
	assert_lt(hud._tracker_panel.size.y, open_size.y * 0.5, "the frame shrinks to the heading, not just the text")
	assert_eq(hud._tracker_panel.position, moved_to, "it stays where it was put")
	hud._fold_tracker(false)
	await wait_process_frames(2)
	assert_almost_eq(hud._tracker_panel.size.y, open_size.y, 2.0, "and grows back")
	assert_eq(hud._tracker_panel.position, moved_to)


func test_folding_the_tracker_before_moving_it_shrinks_it_too() -> void:
	await _tracker_with_quests()
	var open_size := hud._tracker_panel.size
	var right := hud._tracker_panel.position.x + open_size.x
	hud._fold_tracker(true)
	await wait_process_frames(2)
	assert_lt(hud._tracker_panel.size.y, open_size.y * 0.5)
	assert_almost_eq(hud._tracker_panel.position.x + hud._tracker_panel.size.x, right, 1.0, "still on the right edge")
	hud._fold_tracker(false)
	await wait_process_frames(2)
	assert_almost_eq(hud._tracker_panel.size.y, open_size.y, 2.0)
