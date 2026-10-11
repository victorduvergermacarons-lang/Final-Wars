extends GutTest
## Runs the real solo game scene for a few seconds headless and drives it with
## intents, to catch script errors in the view/input/HUD layers.


func test_solo_game_runs_and_responds_to_intents() -> void:
	var game := Game.new()
	add_child(game)
	game.start_solo()
	var session: LocalSession = game.session
	var hero := session.local_hero()
	var start := hero.tile()
	session.send_intent({"type": "step", "to": start + Vector2i.UP})
	await wait_physics_frames(30)
	assert_ne(hero.tile(), start, "hero moved")
	game.client.target_id = session.world.enemies()[0].id
	game.get_node("PlayerInput").use_ability_slot(0)
	game.get_node("PlayerInput")._target_next_enemy()
	await wait_physics_frames(10)
	assert_gt(session.now(), 0.5)
	assert_not_null(game.get_node("WorldView").actor_at(game.get_node("WorldView").actor_screen_pos(hero) + Vector2(0, -14)))
	# Free now (not via autofree) so nothing is still alive if GUT exits right after.
	game.free()
	await wait_process_frames(1)
