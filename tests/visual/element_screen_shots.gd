extends Node
## The element screen on screen (needs a display or xvfb):
##   SHOTS_DIR=/tmp/shots godot --path . res://tests/visual/element_screen_shots.tscn

var out_dir := OS.get_environment("SHOTS_DIR").path_join("") if OS.get_environment("SHOTS_DIR") != "" else ProjectSettings.globalize_path("user://shots/")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1920, 1080)
	_run.call_deferred()


func _run() -> void:
	add_child(ElementScreen.new("Brook"))
	for i in 8:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out_dir + "element_screen.png")
	print("shot element_screen")
	get_tree().quit()
