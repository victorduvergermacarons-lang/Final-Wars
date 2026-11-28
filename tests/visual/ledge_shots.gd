extends Node
## Going over a ledge (2026-11-28, user: it looked like clipping). A hero walks off
## a 1-level step and a 2+ level ledge, away from the camera and toward it; a shot
## every 0.05 s, cropped round the hero:
##   SHOTS_DIR=/tmp/shots godot --path . res://tests/visual/ledge_shots.tscn

var out_dir := OS.get_environment("SHOTS_DIR").path_join("") if OS.get_environment("SHOTS_DIR") != "" else ProjectSettings.globalize_path("user://shots/")
var game: Game


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	TileArt.freeze_water = true
	WorldView.freeze_pulses = true
	get_window().size = Vector2i(1280, 720)
	_run.call_deferred()


func _view() -> WorldView:
	while true:
		var view: WorldView = game.get_node_or_null("WorldView")
		if view != null and view.is_built_for(game.session.grid()):
			return view
		await get_tree().process_frame
	return null


func _shot(name: String, view: WorldView, hero: Hero) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var c := view.get_global_transform_with_canvas() * view.actor_screen_pos(hero)
	var r := Rect2i(int(c.x) - 90, int(c.y) - 130, 180, 180).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(r).save_png(out_dir + name + ".png")


## A walkable tile whose neighbour `d` is walkable and `drop` levels lower (exactly, or
## at least when `at_least`), with walkable ground to keep going on.
func _edge(grid: GridModel, d: Vector2i, drop: int, at_least: bool) -> Vector2i:
	for y in range(2, grid.depth - 3):
		for x in range(2, grid.width - 3):
			var p := Vector2i(x, y)
			var dh := grid.height_at(p) - grid.height_at(p + d)
			if grid.is_walkable(p) and grid.is_walkable(p - d) and grid.height_at(p - d) == grid.height_at(p) \
					and grid.is_walkable(p + d) and grid.is_walkable(p + d * 2) \
					and grid.height_at(p + d * 2) == grid.height_at(p + d) \
					and (dh >= drop if at_least else dh == drop):
				return p
	return Vector2i(-1, -1)


func _run() -> void:
	game = Game.new()
	game.settings_path = "user://ledge_shots_settings.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Ayla", ContentDB.heroes[&"adventurer"]))
	var session: LocalSession = game.session
	var hero := session.local_hero()
	await _view()
	for zone in [&"greenfields", &"crossing", &"town"]:
		var grid := GridModel.from_zone(ContentDB.zones[zone])
		# Away from the camera: grid up (-y) and grid left (-x); toward it: +y.
		for c in [["back_step", Vector2i(0, -1), 1, false], ["back_step_x", Vector2i(-1, 0), 1, false],
				["back_fall", Vector2i(0, -1), 2, true], ["back_fall_x", Vector2i(-1, 0), 2, true],
				["front_step", Vector2i(0, 1), 1, false], ["front_fall", Vector2i(0, 1), 2, true]]:
			if FileAccess.file_exists(out_dir + "%s_00.png" % c[0]):
				continue
			var e := _edge(grid, c[1], c[2], c[3])
			if e.x < 0:
				continue
			session.world.move_hero(hero.id, zone, e - c[1])
			var view: WorldView = await _view()
			await get_tree().create_timer(0.3).timeout
			view.camera.follow(view.actor_screen_pos(hero), 0.0, true)
			hero.walk_target = Vector2(e + c[1] * 2)
			hero.walk_deadline = session.now() + 3.0
			for i in 18:
				view.camera.follow(view.actor_screen_pos(hero), 0.0, true)
				await _shot("%s_%02d" % [c[0], i], view, hero)
				await get_tree().create_timer(0.05).timeout
			print("ledge ", c[0], " in ", zone, " at ", e)
	get_tree().quit()
