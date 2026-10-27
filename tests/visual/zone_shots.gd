extends Node
## Renders the Act I zones to PNGs for a visual check (needs a display or xvfb):
##   SHOTS_DIR=/tmp/shots godot --path . res://tests/visual/zone_shots.tscn
## For each zone: an overview from the middle, zoomed out, then close-ups.

var out_dir := OS.get_environment("SHOTS_DIR").path_join("") if OS.get_environment("SHOTS_DIR") != "" else ProjectSettings.globalize_path("user://shots/")
var game: Game

## Zone -> tiles to look at (the first one is the overview).
const VIEWS := {
	&"town": [Vector2i(16, 16), Vector2i(14, 12), Vector2i(5, 24), Vector2i(24, 18)],
	&"crossing": [Vector2i(20, 20), Vector2i(10, 10), Vector2i(17, 22), Vector2i(31, 31), Vector2i(8, 27)],
	&"deepcut_road": [Vector2i(30, 11), Vector2i(8, 10), Vector2i(30, 8), Vector2i(50, 10)],
	&"deepcut": [Vector2i(22, 20), Vector2i(34, 13), Vector2i(12, 13), Vector2i(26, 11)],
	&"windsteppe": [Vector2i(28, 22), Vector2i(16, 21), Vector2i(30, 17), Vector2i(38, 34)],
	&"tidereach_shore": [Vector2i(9, 7)],
	&"silent_shaft": [Vector2i(33, 15), Vector2i(12, 14), Vector2i(36, 12), Vector2i(38, 23), Vector2i(55, 15)],
}


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


func _shot(name: String) -> void:
	for i in 8:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out_dir + name + ".png")
	print("shot ", name)


func _run() -> void:
	game = Game.new()
	game.settings_path = "user://zone_shots_settings.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Ayla", ContentDB.heroes[&"adventurer"]))
	var session: LocalSession = game.session
	var hero := session.local_hero()
	var only := OS.get_environment("SHOTS_ONLY") # e.g. "silent_shaft": just that zone
	for zone_id in VIEWS:
		if only != "" and String(zone_id) != only:
			continue
		var spots: Array = VIEWS[zone_id]
		var key: StringName = zone_id
		if session.world.is_dungeon(zone_id): # the party's own copy
			key = session.world.dungeon_instance(ContentDB.zones[zone_id], hero.id).key
		for i in spots.size():
			session.world.move_hero(hero.id, key, spots[i])
			var view: WorldView = await _view()
			for z in 4:
				view.camera.step_zoom(-1 if i == 0 else 1)
			if i > 0:
				view.camera.step_zoom(-1)
			await get_tree().process_frame
			view.camera.follow(view.actor_screen_pos(hero), 0.0, true)
			await _shot("zone_%s_%d" % [zone_id, i])
	get_tree().quit()
