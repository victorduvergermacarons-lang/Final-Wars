extends Node
## Phase 1 of feature/water-physics (2026-11-28): the render fixes in Millbrook, a
## Water hero with the stance 1 rope next to Seer Ilyth's house and the flowers by it.
##   SHOTS_DIR=/tmp/fix xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . res://tests/visual/render_fix_shots.tscn
## SHOTS_SPOTS="x,y;x,y" overrides the hero's tiles; each spot is shot with the terrain
## cache and with a full redraw (rf_<n>_cache.png, rf_<n>_full.png).

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


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _crop(name: String, w := 480, h := 360) -> void:
	await _frames(3)
	var img := get_viewport().get_texture().get_image()
	var c := img.get_size() / 2
	img.get_region(Rect2i(c - Vector2i(w / 2, h * 3 / 5), Vector2i(w, h))).save_png(out_dir + name + ".png")
	print("shot ", name)


func _run() -> void:
	game = Game.new()
	game.settings_path = "user://render_fix_settings.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Bernard", ContentDB.heroes[&"adventurer"], ContentDB.elements[&"water"]))
	var session: LocalSession = game.session
	var hero := session.local_hero()
	var view := await _view()
	session.world.submit(hero.id, {"type": "stance", "tree": "Water", "stance": 1})
	var spots: Array = []
	var env := OS.get_environment("SHOTS_SPOTS")
	if env != "":
		for s in env.split(";"):
			spots.append(Vector2i(int(s.get_slice(",", 0)), int(s.get_slice(",", 1))))
	else:
		spots = [Vector2i(17, 18), Vector2i(14, 15), Vector2i(16, 19), Vector2i(12, 18), Vector2i(20, 20)]
	var n := 0
	for t in spots:
		hero.move.place(t)
		hero.move.ground_h = session.zone_sim().grid.height_at(t)
		await _frames(150) # the rope forms
		view.camera.follow(view.actor_screen_pos(hero), 0.0, true)
		view.set_terrain_cache(true)
		await _crop("rf_%d_cache" % n)
		view.set_terrain_cache(false)
		await _crop("rf_%d_full" % n)
		view.set_terrain_cache(true)
		n += 1
	get_tree().quit()
