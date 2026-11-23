extends Node
## The stance rework on screen (needs a display or xvfb), at 1920x1080:
##   SHOTS_DIR=/tmp/shots xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . res://tests/visual/stance_shots.tscn
## Phase 1: the four element trees with the new tiers and steps (Mastery 240 in each, a
## few mastered), Earth Wall with its trench on raised ground.

var out_dir := OS.get_environment("SHOTS_DIR").path_join("") if OS.get_environment("SHOTS_DIR") != "" else ProjectSettings.globalize_path("user://shots/")
var game: Game


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	TileArt.freeze_water = true
	WorldView.freeze_pulses = true
	get_window().size = Vector2i(1920, 1080)
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out_dir + name + ".png")
	print("shot ", name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> WorldView:
	while true:
		var view: WorldView = game.get_node_or_null("WorldView")
		if view != null and view.is_built_for(game.session.grid()):
			return view
		await get_tree().process_frame
	return null


func _run() -> void:
	var cd := ContentDB
	game = Game.new()
	game.settings_path = "user://stance_shots_settings.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Kael", cd.heroes[&"adventurer"]))
	var session: LocalSession = game.session
	var hero := session.local_hero()
	var hud: Hud = game.get_node("Hud")
	for tree in ["Fire", "Earth", "Water", "Air"]:
		Mastery.add_permanent(hero, tree, 240)
	for id in [&"F02", &"F03", &"F09", &"W01", &"W02", &"W05", &"E01", &"E04", &"A01", &"A02"]:
		TreeRules.master(hero, cd.abilities[id])
	hud._toggle(hud.trees_window)
	for tree in ["Fire", "Earth", "Water", "Air"]:
		hud.trees_window.show_tree(tree)
		await _shot("st1_tree_%s" % tree.to_lower())
	hud._toggle(hud.trees_window)
	await phase1_trench(session, hero)
	get_tree().quit()


## Earth Wall on raised ground (height 2), the hero facing south-east: the wall rises
## 2, the row in front of it sinks 1.
func phase1_trench(session: LocalSession, hero: Hero) -> void:
	session.world.move_hero(hero.id, &"crossing", Vector2i(16, 20))
	var view := await _view()
	var sim := session.zone_sim()
	var raised := []
	for x in range(14, 21):
		for y in range(20, 27):
			sim.grid.set_tile(Vector2i(x, y), 2, true)
			raised.append(Vector2i(x, y))
	view.refresh_tiles(raised)
	hero.move.place(Vector2i(17, 21))
	hero.move.ground_h = 2
	TreeRules.master(hero, ContentDB.abilities[&"E05"])
	sim.cast(hero, ContentDB.abilities[&"E05"], null, Vector2(17, 23))
	await _frames(20)
	view.camera.follow(view.actor_screen_pos(hero) + Vector2(0, 40), 0.0, true)
	await _shot("st1_earth_wall_trench")
