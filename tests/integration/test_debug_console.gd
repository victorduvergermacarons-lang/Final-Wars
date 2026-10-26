extends GutTest
## The debug console window: open with `, run a command, see the result, and
## typing doesn't move the hero.

const SETTINGS := "user://test_console_settings.cfg"

var game: Game
var hud: Hud
var hero: Hero


func before_each() -> void:
	game = Game.new()
	game.settings_path = SETTINGS
	add_child(game)
	game.start_solo(CharacterData.new_character("Dev", ContentDB.heroes[&"adventurer"]))
	hud = game.get_node("Hud")
	hero = game.session.local_hero()


func after_each() -> void:
	Input.action_release(&"move_up")
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


func test_console_runs_commands_and_shows_results() -> void:
	hud.console.open()
	await wait_process_frames(2)
	assert_true(hud.console.visible)
	hud.console._submit("level 3")
	await wait_physics_frames(4)
	assert_eq(hero.level, 3)
	assert_string_contains(hud.console._log.text, "Level 3.")
	hud.console._submit("bogus")
	await wait_physics_frames(4)
	assert_string_contains(hud.console._log.text, "Unknown command")


func test_typing_does_not_walk() -> void:
	hud.console.open()
	await wait_process_frames(2)
	var start := hero.tile()
	Input.action_press(&"move_up")
	await wait_physics_frames(20)
	assert_eq(hero.tile(), start, "W typed into the console, not walked")
	hud.console.close()
	await wait_physics_frames(20)
	assert_ne(hero.tile(), start, "walks once the console is closed")
