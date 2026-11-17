extends Node
## The hero walking in all eight directions, for a GIF (needs a display or xvfb):
##   SHOTS_DIR=/tmp/shots godot --path . res://tests/visual/hero_walk_shots.tscn
## Saves walk_<dir>_<n>.png crops around the hero (every other frame at 60 fps);
## tools/once/make_walk_gif.py joins them into walk.gif. The feet should keep pace
## with the ground in every direction.

var out_dir := OS.get_environment("SHOTS_DIR").path_join("") if OS.get_environment("SHOTS_DIR") != "" else ProjectSettings.globalize_path("user://shots/")
var game: Game
## Screen directions (WASD): right, down-right, down, ... and the row each shows.
const DIRS := [["e", Vector2i(1, 0)], ["se", Vector2i(1, 1)], ["s", Vector2i(0, 1)], ["sw", Vector2i(-1, 1)],
		["w", Vector2i(-1, 0)], ["nw", Vector2i(-1, -1)], ["n", Vector2i(0, -1)], ["ne", Vector2i(1, -1)]]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	TileArt.freeze_water = true
	WorldView.freeze_pulses = true
	get_window().size = Vector2i(1280, 720)
	_run.call_deferred()


func _run() -> void:
	game = Game.new()
	game.settings_path = "user://hero_walk_shots_settings.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Kael", ContentDB.heroes[&"adventurer"]))
	var session: LocalSession = game.session
	var me := session.local_hero()
	session.world.move_hero(me.id, &"crossing", Vector2i(14, 19))
	var view: WorldView
	while true:
		view = game.get_node_or_null("WorldView")
		if view != null and view.is_built_for(game.session.grid()):
			break
		await get_tree().process_frame
	var sim := session.zone_sim()
	for entry in DIRS:
		me.move.place(Vector2i(14, 19))
		for i in 40:
			sim.submit(me.id, {"type": "move", "dir": entry[1], "face": 0.0})
			await get_tree().physics_frame
			if i % 2 == 1 and i >= 8:
				await get_tree().process_frame
				var img := get_viewport().get_texture().get_image()
				var c := Vector2i(img.get_width() / 2, img.get_height() / 2)
				img.get_region(Rect2i(c - Vector2i(110, 150), Vector2i(220, 220))).save_png(
						out_dir + "walk_%s_%02d.png" % [entry[0], i])
		sim.submit(me.id, {"type": "move", "dir": Vector2i.ZERO, "face": 0.0})
		for i in 10:
			await get_tree().physics_frame
	print("shot walk")
	get_tree().quit()
