extends GutTest
## The dialogue box in the running game: speaker, faction and placeholder
## portrait, lines from the dialogue file with their choices, quest offers from a
## quest board with the file's answers, and co-op (another player's conversation
## shows as a bubble; a quest they accept is offered to you, and Join takes it).

const SETTINGS := "user://test_dialogue_settings.cfg"

var game: Game
var session: LocalSession
var hud: Hud
var me: Hero


func before_each() -> void:
	game = Game.new()
	game.settings_path = SETTINGS
	add_child_autofree(game)
	game.start_solo(CharacterData.new_character("Tester", ContentDB.heroes[&"adventurer"]))
	session = game.session
	hud = game.get_node("Hud")
	me = session.local_hero()
	_go_to_crossing(me)
	await wait_physics_frames(3)
	await wait_process_frames(2)


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


func _npc(id: StringName) -> Npc:
	for a in session.actors():
		if a is Npc and a.def.id == id:
			return a
	return null


## Act I's Guild Board and Warden Dorne are at the Crossing: the test plays there.
func _go_to_crossing(h: Hero) -> void:
	if session.world.zone_of(h.id).zone.id != &"crossing":
		session.world.move_hero(h.id, &"crossing", Vector2i(17, 20))


func _beside(h: Hero, npc: Npc) -> void:
	var sim := session.world.zone(&"crossing")
	h.move.place(sim.find_free_tile_near(npc.tile()))


func _talk(id: StringName) -> void:
	var npc := _npc(id)
	_beside(me, npc)
	session.send_intent({"type": "talk", "npc": npc.id})
	await wait_physics_frames(4)
	await wait_process_frames(2)


func test_dialogue_shows_the_speaker_and_follows_choices() -> void:
	await _talk(&"warden_dorne")
	var box := hud.dialogue
	assert_true(box.visible, "the dialogue box opens")
	assert_eq(box.speaker_name(), "Warden Iska Dorne")
	assert_eq(box._faction.text, "Floor Guild")
	assert_eq(box._portrait.initials, "WD", "placeholder portrait: initials")
	assert_eq(box._portrait.frame_color, Factions.color(Factions.Id.FLOOR_GUILD), "in the faction's colour")
	assert_eq(box.line_id, "npc.warden_dorne.greeting")
	assert_string_contains(box.text(), ContentDB.dialogue.text("npc.warden_dorne.greeting"))
	var labels := box.option_labels()
	assert_true(labels.has("What is the Floor Guild?") and labels.has("Goodbye"), str(labels))
	box.press("What is the Floor Guild?")
	assert_eq(box.line_id, "npc.warden_dorne.about_guild")
	assert_eq(box.option_labels(), ["Continue"] as Array[String])
	box.press("Continue")
	assert_eq(box.line_id, "npc.warden_dorne.about_guild_2")
	box.press("Back")
	assert_eq(box.line_id, "npc.warden_dorne.greeting", "back to the main page")
	box.press("Goodbye")
	assert_false(box.visible)


## Ready for the Guild's trials: 1-01 and 1-02 done, level 3 (the board's quests).
func _ready_for_trials(h: Hero) -> void:
	for id in [&"act1_01_guild_comes_to_millbrook", &"act1_02_applicants_wanted"]:
		h.quest_state[String(id)] = {"state": "done"}
	h.level = 3


func test_a_quest_board_offers_quests_with_the_files_answers() -> void:
	_ready_for_trials(me)
	await wait_physics_frames(3)
	assert_eq(hud.client.npc_markers.get(&"guild_board", ""), "!", "the board shows !")
	await _talk(&"guild_board")
	var box := hud.dialogue
	assert_eq(box.speaker_name(), "Guild Board")
	assert_true(box.press("! 1-04 Grain for Deepcut"), str(box.option_labels()))
	assert_eq(box.line_id, "quest.act1_04_grain_for_deepcut.offer")
	assert_string_contains(box.text(), "Main quest · Road to Deepcut")
	assert_eq(box.option_labels(), ["Take the notice", "Leave it pinned"] as Array[String])
	box.press("Take the notice")
	await wait_physics_frames(4)
	await wait_process_frames(2)
	assert_true(QuestLog.is_active(me, &"act1_04_grain_for_deepcut"))
	assert_string_contains(hud._tracker.text, "Escort the grain wagon", "on the tracker")
	assert_eq(hud.client.npc_markers.get(&"guild_board", ""), "!", "the board still has 1-05 to give")


func test_coop_bubble_and_quest_prompt() -> void:
	var bob := session.world.add_saved_hero(CharacterData.new_character("Bob", ContentDB.heroes[&"adventurer"]), ContentDB)
	_go_to_crossing(bob)
	for h in [me, bob]:
		_ready_for_trials(h)
	var board := _npc(&"guild_board")
	_beside(bob, board)
	session.world.submit(bob.id, {"type": "talk", "npc": board.id})
	await wait_physics_frames(3)
	assert_true(hud.client.live_bubbles().has(board.id), "I see a bubble over the board Bob reads")
	assert_false(hud.dialogue.visible, "Bob's conversation isn't mine")
	session.world.submit(bob.id, {"type": "accept_quest", "npc": board.id, "quest": &"act1_05_fever_in_millbrook"})
	await wait_physics_frames(3)
	await wait_process_frames(2)
	assert_true(hud.quest_prompt.visible, "the quest is offered to me too")
	assert_eq(hud.quest_prompt.current_quest(), &"act1_05_fever_in_millbrook")
	assert_string_contains(hud.quest_prompt._text.text, "Bob")
	me.move.place(Vector2i(30, 20)) # far from the board: Join works anyway
	hud.quest_prompt._join()
	await wait_physics_frames(3)
	await wait_process_frames(2)
	assert_true(QuestLog.is_active(me, &"act1_05_fever_in_millbrook"), "joined")
	assert_eq(me.bag.count_of(ContentDB.items[&"fever_draught"]), 3, "with the draughts to deliver")
	assert_false(hud.quest_prompt.visible)
