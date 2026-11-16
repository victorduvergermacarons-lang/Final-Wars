extends Node
## Screenshots of the map editor (needs a display or xvfb):
##   SHOTS_DIR=/tmp/shots godot --path . res://tests/visual/map_editor_shots.tscn
## Paints a pond, a hill and flowers on a scratch copy of Millbrook (never saved).

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
	get_tree().quit()
