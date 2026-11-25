extends Node
## The Water Whip lab (2026-11-25): a hero on open ground at the Crossing casting the
## Verlet whip's effect (through the `fx` debug command: no damage, no cooldown).
## Open it in the editor (F6 on this scene) and use the keys:
##   1-8      cast toward the 8 screen directions: 1 up, 2 up-right, 3 right,
##            4 down-right, 5 down, 6 down-left, 7 left, 8 up-left
##   Q / E    target nearer / farther (1 to 5 tiles)
##   - / =    slower / faster (game speed x0.05 to x2); 0 back to x1
##   D        chain points and hand anchors on / off
##   W        walk while casting: the hero strolls back and forth
## Tune content/effects/water_whip_feel.tres; the lab reloads it on R.
## Screenshots instead (needs a display or xvfb):
##   WHIP_SHOTS=/tmp/whip xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . res://tests/visual/whip_lab.tscn
## take every direction at 3 tiles, slowed down, at 6 moments of the lash, with the
## debug view on (whip_<dir>_<n>.png), and quit.

const DIRS := ["up", "up_right", "right", "down_right", "down", "down_left", "left", "up_left"]
var game: Game
var hero: Hero
var session: LocalSession
var distance := 3.0
var speed := 0.25
var label: Label
var stroll := false


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	_start.call_deferred()


func _start() -> void:
	ContentDB.rules.timing_bars_enabled = false
	game = Game.new()
	game.settings_path = "user://whip_lab_settings.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Lash", ContentDB.heroes[&"adventurer"]))
	session = game.session
	hero = session.local_hero()
	session.world.move_hero(hero.id, &"crossing", Vector2i(12, 12))
	var view := await _view()
	hero.move.place(Vector2i(12, 12))
	hero.move.ground_h = session.zone_sim().grid.height_at(Vector2i(12, 12))
	for i in 10:
		await get_tree().process_frame
	view.camera.follow(view.actor_screen_pos(hero), 0.0, true)
	_set_speed(speed)
	label = Label.new()
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 22)
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.add_child(label)
	add_child(layer)
	_update_label()
	if OS.get_environment("WHIP_SHOTS") != "":
		await _shots(OS.get_environment("WHIP_SHOTS").path_join(""))
		get_tree().quit()


func _view() -> WorldView:
	while true:
		var view: WorldView = game.get_node_or_null("WorldView")
		if view != null and view.is_built_for(game.session.grid()):
			return view
		await get_tree().process_frame
	return null


## A tile-space direction for a screen direction (0 = up, clockwise in 45° steps).
static func tile_dir(i: int) -> Vector2:
	var sdir := Vector2.from_angle(deg_to_rad(-90.0 + 45.0 * i))
	# Screen to tile: x - y = sx / 32, x + y = sy / 16.
	return Vector2((sdir.x / 32.0 + sdir.y / 16.0) * 0.5, (sdir.y / 16.0 - sdir.x / 32.0) * 0.5).normalized()


func cast(i: int) -> void:
	session.world.submit(hero.id, {"type": "debug", "line": "fx W02", "aim": hero.move.pos + tile_dir(i) * distance})


func _set_speed(v: float) -> void:
	speed = clampf(v, 0.05, 2.0)
	ContentDB.rules.game_speed = speed


func _update_label() -> void:
	if label != null:
		label.text = "Water Whip lab  |  1-8 cast  Q/E distance %.0f  -/= speed x%.2f  D debug %s  W walk %s  R reload feel" \
				% [distance, speed, "on" if WorldView.debug_whip else "off", "on" if stroll else "off"]


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or hero == null:
		return
	var k: int = event.keycode
	if k >= KEY_1 and k <= KEY_8:
		cast(k - KEY_1)
	elif k == KEY_Q:
		distance = maxf(1.0, distance - 1.0)
	elif k == KEY_E:
		distance = minf(5.0, distance + 1.0)
	elif k == KEY_MINUS:
		_set_speed(speed * 0.5)
	elif k == KEY_EQUAL:
		_set_speed(speed * 2.0)
	elif k == KEY_0:
		_set_speed(1.0)
	elif k == KEY_D:
		WorldView.debug_whip = not WorldView.debug_whip
	elif k == KEY_W:
		stroll = not stroll
	elif k == KEY_R:
		var fx: FxDef = ContentDB.effects[&"water_whip"]
		fx.feel = ResourceLoader.load(fx.feel.resource_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	get_viewport().set_input_as_handled()
	_update_label()


func _process(_dt: float) -> void:
	if stroll and hero != null:
		var dir := Vector2i(1, 0) if int(Time.get_ticks_msec() / 1500) % 2 == 0 else Vector2i(-1, 0)
		session.world.submit(hero.id, {"type": "move", "dir": dir, "face": hero.facing_angle})


func _shots(out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	WorldView.debug_whip = OS.get_environment("WHIP_DEBUG") != "0"
	_set_speed(0.2)
	var moments := [0.02, 0.12, 0.24, 0.29, 0.36, 0.5]
	for i in 8:
		var t0: float = session.now()
		cast(i)
		for n in moments.size():
			while session.now() - t0 < moments[n]:
				await get_tree().process_frame
			await get_tree().process_frame
			var img := get_viewport().get_texture().get_image()
			var c := img.get_size() / 2
			img.get_region(Rect2i(c - Vector2i(260, 260), Vector2i(520, 440))).save_png(out + "whip_%s_%d.png" % [DIRS[i], n])
		while session.now() - t0 < 1.4:
			await get_tree().process_frame
	print("whip shots in ", out)
