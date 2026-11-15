extends Node
## The hero's sprite art (PL-01-1) on screen (needs a display or xvfb):
##   SHOTS_DIR=/tmp/shots godot --path . res://tests/visual/hero_art_shots.tscn
## Facing the camera and away, walking, casting, hit, stunned (downed), dead, and
## getting up, beside a wolf for scale.

var out_dir := OS.get_environment("SHOTS_DIR").path_join("") if OS.get_environment("SHOTS_DIR") != "" else ProjectSettings.globalize_path("user://shots/")
var game: Game


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	TileArt.freeze_water = true
	WorldView.freeze_pulses = true
	get_window().size = Vector2i(1920, 1080)
	_run.call_deferred()


func _view() -> WorldView:
	while true:
		var view: WorldView = game.get_node_or_null("WorldView")
		if view != null and view.is_built_for(game.session.grid()):
			return view
		await get_tree().process_frame
	return null


func _shot(name: String, view: WorldView, hero: Hero) -> void:
	view.camera.follow(view.actor_screen_pos(hero), 0.0, true)
	for i in 4:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out_dir + name + ".png")
	print("shot ", name)


func _run() -> void:
	game = Game.new()
	game.settings_path = "user://hero_art_shots_settings.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Kael", ContentDB.heroes[&"adventurer"]))
	var session: LocalSession = game.session
	var hero := session.local_hero()
	session.world.move_hero(hero.id, &"crossing", Vector2i(16, 19))
	var view: WorldView = await _view()
	var sim := session.zone_sim()
	sim.add_enemy(ContentDB.enemies[&"wolf"], Vector2i(19, 20))
	session.rules().game_speed = 0.0001 # frozen: nothing moves unless told
	await get_tree().create_timer(0.1).timeout
	hero.face_angle(Vector2(1, 0).angle())
	await _shot("ha1_idle_facing_camera", view, hero)
	hero.face_angle(Vector2(0, -1).angle())
	await _shot("ha2_facing_away", view, hero)
	session.rules().game_speed = 1.0
	session.send_intent({"type": "move", "dir": Vector2i(1, 1), "face": 0.0})
	await get_tree().create_timer(0.4).timeout
	await _shot("ha3_walking", view, hero)
	session.send_intent({"type": "move", "dir": Vector2i.ZERO, "face": 0.0})
	await get_tree().create_timer(0.3).timeout
	view._animator.note(hero.id, "cast", session.render_time() - 0.22)
	await _shot("ha4_cast", view, hero)
	view._animator.note(hero.id, "hit", session.render_time() - 0.1)
	await _shot("ha5_hit", view, hero)
	hero.buffs.apply(ContentDB.buffs[&"searing_dive_stun"], session.now())
	await get_tree().create_timer(0.8).timeout
	await _shot("ha6_stunned", view, hero)
	hero.buffs.clear()
	await get_tree().create_timer(1.0).timeout
	hero.hp = 0.0
	hero.alive = false
	await get_tree().create_timer(1.0).timeout
	await _shot("ha7_dead", view, hero)
	get_tree().quit()
