extends Node
## Holes in a map's shape on screen (needs a display or xvfb):
##   SHOTS_DIR=/tmp/shots godot --path . res://tests/visual/map_shape_shots.tscn
## The Crossing with a chasm carved east of the hero and a missing corner block:
## nothing is drawn there, and the tiles around show their sides down to the
## bottom, as at the map's edge.

var out_dir := OS.get_environment("SHOTS_DIR").path_join("") if OS.get_environment("SHOTS_DIR") != "" else ProjectSettings.globalize_path("user://shots/")
var game: Game


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	TileArt.freeze_water = true
	WorldView.freeze_pulses = true
	get_window().size = Vector2i(1920, 1080)
	_run.call_deferred()


## Carves the tiles of `holes` out of `zone` (in memory only).
static func carve(zone: ZoneDef, holes: Array) -> void:
	for p in holes:
		for rows in [zone.height_rows, zone.terrain_rows]:
			rows[p.y] = rows[p.y].substr(0, p.x) + ZoneDef.NO_TILE + rows[p.y].substr(p.x + 1)
		for pair in [[zone.walk_rows, "#"], [zone.prop_rows, "."], [zone.sight_rows, "."]]:
			var rows: PackedStringArray = pair[0]
			if p.y < rows.size():
				rows[p.y] = rows[p.y].substr(0, p.x) + pair[1] + rows[p.y].substr(p.x + 1)
	zone.decor = zone.decor.filter(func(d): return not holes.has(d.tile))
	zone.forget_decor_cache()


func _run() -> void:
	var zone: ZoneDef = ContentDB.zones[&"crossing"]
	var holes := []
	for y in range(14, 25):
		for x in range(17, 20):
			holes.append(Vector2i(x, y))
	for y in range(22, 25):
		for x in range(10, 13):
			holes.append(Vector2i(x, y))
	carve(zone, holes)
	game = Game.new()
	game.settings_path = "user://map_shape_shots_settings.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Kael", ContentDB.heroes[&"adventurer"]))
	var session: LocalSession = game.session
	var me := session.local_hero()
	session.world.move_hero(me.id, &"crossing", Vector2i(15, 19))
	var view: WorldView
	while true:
		view = game.get_node_or_null("WorldView")
		if view != null and view.is_built_for(game.session.grid()):
			break
		await get_tree().process_frame
	for i in 20:
		await get_tree().process_frame
	view.camera.follow(view.actor_screen_pos(me), 0.0, true)
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out_dir + "shape_holes.png")
	print("shot shape_holes")
	get_tree().quit()
