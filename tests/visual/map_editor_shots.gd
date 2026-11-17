extends Node
## Screenshots of the map editor (needs a display or xvfb):
##   SHOTS_DIR=/tmp/shots godot --path . res://tests/visual/map_editor_shots.tscn
## Paints a pond, a hill and flowers on a scratch copy of Millbrook (never saved),
## then cuts a hole and adds ground past its edge with the Shape tool.

var out_dir := OS.get_environment("SHOTS_DIR").path_join("") if OS.get_environment("SHOTS_DIR") != "" else ProjectSettings.globalize_path("user://shots/")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	TileArt.freeze_water = true
	get_window().size = Vector2i(1280, 720)
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 8:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out_dir + name + ".png")
	print("shot ", name)


func _run() -> void:
	var editor := MapEditor.new()
	add_child(editor)
	await get_tree().process_frame
	await _shot("editor_0_open")
	var c := Vector2i(16, 18)
	editor.terrain = "water"
	editor.set_brush(3)
	editor._apply(c + Vector2i(-3, 0), MOUSE_BUTTON_LEFT)
	editor._painted = {}
	editor.set_tool(MapEditor.Tool.HEIGHT)
	editor.set_brush(3)
	for i in 3:
		editor._apply(c + Vector2i(3, 0), MOUSE_BUTTON_LEFT)
		editor._painted = {}
	editor.set_brush(1)
	editor._apply(c + Vector2i(3, 0), MOUSE_BUTTON_LEFT)
	editor._painted = {}
	editor.set_tool(MapEditor.Tool.PROPS)
	editor.prop = "flowers"
	for p in [c + Vector2i(0, 2), c + Vector2i(1, 2), c + Vector2i(-1, 3)]:
		editor._apply(p, MOUSE_BUTTON_LEFT)
	editor._cam_target = Iso.to_screen(Vector2(c), 0)
	await _shot("editor_1_painted")
	editor.show_heights = true
	editor.show_grid = true
	await _shot("editor_2_helpers")
	editor.show_heights = false
	editor.show_grid = false
	await _shot("editor_3_cached")
	editor.view.set_terrain_cache(false) # the same picture, every tile redrawn
	await _shot("editor_4_full")
	editor.view.set_terrain_cache(true)
	# Things: a wolf with a patrol, a door, the selection; then the size and links panels.
	editor.set_tool(MapEditor.Tool.THINGS)
	editor.set_thing_kind("enemy")
	editor.thing_what = ContentDB.enemies[&"wolf"]
	editor.place(c + Vector2i(-1, -3))
	editor.set_tool(MapEditor.Tool.SELECT)
	editor.set_patrol_mode(true)
	for p in [c + Vector2i(3, -3), c + Vector2i(3, -6)]:
		editor._patrol_click(p, MOUSE_BUTTON_LEFT)
	editor.set_tool(MapEditor.Tool.THINGS)
	editor.set_thing_kind("exit")
	editor.thing_what = &"crossing"
	editor.place(c + Vector2i(1, 3))
	editor.set_tool(MapEditor.Tool.SELECT)
	editor.select(ZoneEdit.ref("enemy", editor.edit.zone.enemy_spawns.size() - 1))
	await _shot("editor_5_things")
	editor._cam_target = Iso.to_screen(Vector2(editor.edit.width() - 2, 9), 0)
	await _shot("editor_6_edge")
	editor._open_links_dialog()
	await _shot("editor_7_connections")
	editor._links_dialog.hide()
	# Shape: a hole cut in the green, and ground added past the map's north-west side.
	editor.set_tool(MapEditor.Tool.SHAPE)
	editor.set_brush(3)
	editor._press(c + Vector2i(0, -2), MOUSE_BUTTON_RIGHT)
	editor._release(null)
	editor.terrain = "dirt"
	editor.height_level = 1
	editor._press(Vector2i(-2, 12), MOUSE_BUTTON_LEFT)
	editor._release(null)
	editor._cam_target = Iso.to_screen(Vector2(4, 13), 0)
	await _shot("editor_8_shape")
	get_tree().quit()
