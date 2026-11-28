extends Node
## The water rope lab (2026-11-26): a Water hero in Water stance 1 at the Crossing,
## a near and a far training dummy, the reference's controls and readouts. Open it in
## the editor (F6 on this scene).
##   Click the ground or a dummy: throw the Water Whip there (its effect only, through
##   the `fx` debug command: no damage, no cooldown, no water spent).
##   Near / Far (or keys 1 / 2): throw at the dummies.
##   Points, Return path, Slow (game speed 1/3): toggles.
##   The four sliders of the reference: max return speed, half-trip speed, return
##   delay, orbit brake time (they change content/effects/water_rope_settings.tres in
##   memory only; tune the file itself to keep a value).
## Screenshots instead (needs a display or xvfb):
##   WATER_SHOTS=/tmp/water xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . res://tests/visual/water_lab.tscn

const NEAR := Vector2i(1, 1)
const FAR := Vector2i(4, -2)

var game: Game
var session: LocalSession
var hero: Hero
var view: WorldView
var near: Enemy
var far: Enemy
var readout: Label
var slow := false
var _last_readout := {}


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	_start.call_deferred()


func _start() -> void:
	game = Game.new()
	game.settings_path = "user://water_lab_settings.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Kanna", ContentDB.heroes[&"adventurer"], ContentDB.elements[&"water"]))
	session = game.session
	hero = session.local_hero()
	session.world.move_hero(hero.id, &"crossing", Vector2i(12, 12))
	view = await _view()
	var sim := session.zone_sim()
	var at := Vector2i(12, 12)
	hero.move.place(at)
	hero.move.ground_h = sim.grid.height_at(at)
	near = sim.add_enemy(ContentDB.enemies[&"training_dummy"], at + NEAR)
	far = sim.add_enemy(ContentDB.enemies[&"training_dummy"], at + FAR)
	session.world.submit(hero.id, {"type": "stance", "tree": "Water", "stance": 1})
	for i in 10:
		await get_tree().process_frame
	view.camera.follow(view.actor_screen_pos(hero), 0.0, true)
	if OS.get_environment("WATER_SHOTS") != "":
		await _shots(OS.get_environment("WATER_SHOTS").path_join(""))
		get_tree().quit()
		return
	_build_ui()


func _view() -> WorldView:
	while true:
		var v: WorldView = game.get_node_or_null("WorldView")
		if v != null and v.is_built_for(game.session.grid()):
			return v
		await get_tree().process_frame
	return null


func throw_at(point: Vector2) -> void:
	session.world.submit(hero.id, {"type": "debug", "line": "fx W02", "aim": point})


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(430, 0)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Water stance 1 and Water Whip"
	box.add_child(title)
	var s := view.ropes.settings
	_slider(box, "Max return speed", 0.8, 6.0, 0.1, s.MAX_SPEED, func(v):
		s.MAX_SPEED = v
		s.CHASE_MAX = maxf(5.0, v * 2.0)
		return "%.1f px/f" % v)
	_slider(box, "Half-trip speed", 20, 80, 5, s.HALF_TRIP * 100.0, func(v):
		s.HALF_TRIP = v / 100.0
		return "%d%%" % v)
	_slider(box, "Return delay", 0.0, 1.0, 0.05, s.RETURN_AT / 60.0, func(v):
		s.RETURN_AT = roundi(v * 60.0)
		return "%.2f s" % v)
	_slider(box, "Orbit brake time", 0.2, 3.0, 0.1, 1.6, func(v):
		s.WRAP_EASE = WaterRopeSettings.brake_ease(v)
		return "%.1f s" % v)
	var row := HBoxContainer.new()
	box.add_child(row)
	for b in [["Near", func(): throw_at(near.move.pos)], ["Far", func(): throw_at(far.move.pos)]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(b[1])
		row.add_child(btn)
	for t in [["Points", func(on): WorldView.debug_rope_points = on],
			["Return path", func(on): WorldView.debug_rope_path = on],
			["Slow", func(on): _set_slow(on)]]:
		var c := CheckButton.new()
		c.text = t[0]
		c.focus_mode = Control.FOCUS_NONE
		c.toggled.connect(t[1])
		row.add_child(c)
	readout = Label.new()
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD
	readout.custom_minimum_size = Vector2(430, 60)
	readout.text = "Click the ground, or use Near and Far to hit the dummies."
	box.add_child(readout)


func _slider(box: VBoxContainer, label: String, lo: float, hi: float, step: float, value: float, apply: Callable) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = value
	sl.custom_minimum_size = Vector2(180, 0)
	sl.focus_mode = Control.FOCUS_NONE
	row.add_child(sl)
	var out := Label.new()
	out.text = apply.call(value)
	row.add_child(out)
	sl.value_changed.connect(func(v): out.text = apply.call(v))


func _set_slow(on: bool) -> void:
	slow = on
	ContentDB.rules.game_speed = 1.0 / 3.0 if on else 1.0


func _unhandled_input(event: InputEvent) -> void:
	if hero == null or view == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			throw_at(near.move.pos)
		elif event.keycode == KEY_2:
			throw_at(far.move.pos)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var w := view.get_global_mouse_position()
		var picked := view.actor_at(w)
		if picked is Enemy:
			throw_at(picked.move.pos)
		else:
			throw_at(Iso.from_screen(w, float(hero.move.ground_h)))
		get_viewport().set_input_as_handled()


func _process(_dt: float) -> void:
	if view == null or readout == null:
		return
	var r := view.ropes.rope_of(hero.id)
	if r == null or r.readout == _last_readout:
		return
	_last_readout = r.readout.duplicate()
	var d := r.readout
	if d.has("entry_px_s"):
		readout.text = "Return %d px at %d%% of max speed, took %.2f s, entered orbit at %d px/s." \
				% [d.return_px, roundi(d.return_share * 100.0), d.return_s, roundi(d.entry_px_s)]
	elif d.has("hit_s"):
		readout.text = "Hit landed at %.2f s (pull-back %d)" % [d.hit_s, roundi(d.pull_back)]
	elif d.has("flight_s"):
		readout.text = "%sPull-back %d, spin %.2f s, flight %.2f s" \
				% ["Recast during wrap. " if d.recast else "", roundi(d.pull_back), d.spin_s, d.flight_s]


func _crop(path: String, w := 560, h := 420) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var c := img.get_size() / 2 # the camera keeps the hero in the middle
	img.get_region(Rect2i(c - Vector2i(w / 2, h * 3 / 5), Vector2i(w, h))).save_png(path)
	print("shot ", path)


func _wait(sim_seconds: float) -> void:
	var t0: float = session.now()
	while session.now() - t0 < sim_seconds:
		await get_tree().process_frame


func _shots(out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	ContentDB.rules.game_speed = 0.25
	await _wait(1.6) # the orbit forms from the hips
	await _crop(out + "w0_orbit.png")
	WorldView.debug_rope_points = OS.get_environment("WATER_DEBUG") == "1"
	WorldView.debug_rope_path = WorldView.debug_rope_points
	for target in [["near", near], ["far", far]]:
		throw_at(target[1].move.pos)
		var moments := [0.12, 0.3, 0.5, 0.6, 0.8, 1.1, 1.5, 2.2]
		var t0: float = session.now()
		for i in moments.size():
			while session.now() - t0 < moments[i]:
				await get_tree().process_frame
			await _crop(out + "w_%s_%d.png" % [target[0], i])
		await _wait(2.5)
	print("readout: ", view.ropes.rope_of(hero.id).readout)
