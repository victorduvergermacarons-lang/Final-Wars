extends GutTest
## Game speed (Escape menu > Gameplay test): the whole sim clock runs at
## `CombatRules.game_speed`, in and out of combat.

var session: LocalSession
var hero: Hero


func before_each() -> void:
	session = LocalSession.new()
	add_child(session)
	session.start(ContentDB.zones.values(), &"town", ContentDB.rules,
			CharacterData.new_character("Clock", ContentDB.heroes[&"adventurer"]))
	hero = session.local_hero()
	session.set_physics_process(false) # the test feeds the frames itself


func after_each() -> void:
	ContentDB.rules.game_speed = 1.0
	session.free()


func _sim_seconds_after(real_seconds: float, fighting := false) -> float:
	var start := session.now()
	for i in 10:
		if fighting:
			hero.combat_until = 1.0e9 # (no enemy lists it, so the sim would end it)
		session._physics_process(real_seconds / 10.0)
	return session.now() - start


func test_normal_speed_by_default() -> void:
	assert_almost_eq(_sim_seconds_after(1.0), 1.0, 0.06)


func test_out_of_combat_runs_at_the_game_speed() -> void:
	ContentDB.rules.game_speed = 0.1
	assert_almost_eq(_sim_seconds_after(2.0), 0.2, 0.06, "ten times slower")
	ContentDB.rules.game_speed = 2.0
	assert_almost_eq(_sim_seconds_after(1.0), 2.0, 0.06, "twice as fast")


func test_a_fight_runs_at_the_game_speed() -> void:
	ContentDB.rules.game_speed = 0.5
	assert_almost_eq(_sim_seconds_after(2.0, true), 1.0, 0.06, "half speed: 2 real seconds = 1 sim second")
	ContentDB.rules.game_speed = 2.0
	assert_almost_eq(_sim_seconds_after(1.0, true), 2.0, 0.06, "double speed")


func test_the_menu_intent_sets_it() -> void:
	session.send_intent({"type": "game_speed", "value": 0.25})
	session._physics_process(ContentDB.rules.tick_seconds)
	assert_eq(ContentDB.rules.game_speed, 0.25, "debug builds (tests) allow it")
