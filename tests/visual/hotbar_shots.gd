extends Node
## Phase 2 of feature/water-physics (2026-11-28): the action bar with every learned
## ability on it (no stances), the stance badge lit for the stance held, and the main
## menu's Delete confirmation.
##   SHOTS_DIR=/tmp/bar xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . res://tests/visual/hotbar_shots.tscn

var out_dir := OS.get_environment("SHOTS_DIR").path_join("") if OS.get_environment("SHOTS_DIR") != "" else ProjectSettings.globalize_path("user://shots/")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1920, 1080)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String, region := Rect2i()) -> void:
	await _frames(4)
	var img := get_viewport().get_texture().get_image()
	if region.has_area():
		img = img.get_region(region)
	img.save_png(out_dir + name + ".png")
	print("shot ", name)


func _run() -> void:
	var game := Game.new()
	game.settings_path = "user://hotbar_shots_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.settings_path))
	add_child(game)
	game.start_solo(CharacterData.new_character("Kanna", ContentDB.heroes[&"adventurer"], ContentDB.elements[&"water"]))
	var hero: Hero = game.session.local_hero()
	for id in [&"W02", &"W12", &"W04", &"W07"]:
		TreeRules.master(hero, ContentDB.abilities[id])
	Mastery.add_permanent(hero, "Water", 200)
	await _frames(10)
	var bar_rect := Rect2i(560, 960, 800, 120)
	await _shot("hb0_no_stance", bar_rect)
	game.session.world.submit(hero.id, {"type": "stance", "tree": "Water", "stance": 1})
	await _frames(10)
	await _shot("hb1_water_1", bar_rect)
	game.queue_free()
	await _frames(2)
	var menu := MainMenu.new()
	menu.store = CharacterStore.new("user://hotbar_shots_chars")
	menu.store.save(CharacterData.new_character("Kanna", ContentDB.heroes[&"adventurer"]))
	add_child(menu)
	await _frames(4)
	menu._on_delete()
	await _shot("hb2_delete_confirm")
	get_tree().quit()
