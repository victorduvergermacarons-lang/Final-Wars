extends GutTest
## The "End of Act I" screen (ActEndScreen): it waits for the hand-in
## conversation to close, shows the party's records, and its button takes the hero
## back to the Crossing. Also the Escape menu's dungeon testing switch.

const SETTINGS := "user://test_act_end_settings.cfg"
const QUEST := &"act1_07_the_silent_shaft"

var game: Game
var hud: Hud


func before_each() -> void:
	game = Game.new()
	game.settings_path = SETTINGS
	add_child(game)
	game.start_solo(CharacterData.new_character("Ayla", ContentDB.heroes[&"adventurer"]))
	hud = game.get_node("Hud")
	await wait_process_frames(2)


func after_each() -> void:
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


func _event(hero: Hero) -> Dictionary:
	return {"type": "act_complete", "target": hero.id, "act": 1, "quest": QUEST, "party": [
		{"id": hero.id, "name": "Ayla", "level": 12, "kills": 140, "damage": 52000, "healing": 9100, "deaths": 3, "quests": 10},
		{"id": 999, "name": "Bram", "level": 12, "kills": 128, "damage": 47000, "healing": 30500, "deaths": 1, "quests": 10}]}


func test_the_screen_shows_the_party_and_takes_you_to_the_crossing() -> void:
	var session: LocalSession = game.session
	var hero := session.local_hero()
	hero.quest_state[String(QUEST)] = {"state": "done", "progress": [1, 1, 1, 1], "ready": false, "found": {}}
	hud.dialogue.open_line("npc.caedan_shaft.greeting", "…", hero.tile()) # the hand-in conversation is still open
	hud._on_events([_event(hero)])
	await wait_process_frames(2)
	assert_false(hud.act_end.visible, "waits for the conversation to end")
	hud.dialogue.close()
	await wait_process_frames(2)
	assert_true(hud.act_end.visible, "End of Act I")
	assert_eq(hud.act_end._title.text, "Act I: The Floor Guild")
	var rows := hud.act_end.rows()
	assert_eq(rows.size(), 3, "a heading and one row per hero")
	assert_eq(rows[1], ["Ayla", "12", "140", "52000", "9100", "3", "10"])
	assert_eq(rows[2][0], "Bram")
	assert_eq(hud.act_end._button.text, "Return to The Crossing")
	hud.act_end._button.pressed.emit()
	assert_false(hud.act_end.visible)
	for i in 6:
		session.world.step()
	assert_eq(session.world.zone_of(hero.id).key, &"crossing", "back at the Crossing")


func test_the_dungeon_testing_switch_reaches_the_host() -> void:
	var rules: CombatRules = game.session.rules()
	assert_true(rules.dungeon_testing, "on by default in debug builds")
	hud.game_menu._dungeon_testing.button_pressed = false
	game.session.world.step()
	await wait_process_frames(1)
	assert_false(rules.dungeon_testing, "the real game's rule: a party of 3")
	assert_eq(rules.min_dungeon_party(), 3)
	hud.game_menu._dungeon_testing.button_pressed = true
	game.session.world.step()
	assert_true(rules.dungeon_testing)
	assert_eq(rules.min_dungeon_party(), 1)
