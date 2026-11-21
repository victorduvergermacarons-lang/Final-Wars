extends Node
## The ability effects on screen (needs a display or xvfb):
##   SHOTS_DIR=/tmp/shots godot --path . res://tests/visual/fx_shots.tscn
## Each effect played from a hero toward a wolf, sent two ways (south-east and
## north-west, to check the rotation and that it stays upright), a frame from its
## middle; then Rock Throw's rock held, in flight and landing.

var out_dir := OS.get_environment("SHOTS_DIR").path_join("") if OS.get_environment("SHOTS_DIR") != "" else ProjectSettings.globalize_path("user://shots/")
var game: Game


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	TileArt.freeze_water = true
	WorldView.freeze_pulses = true
	get_window().size = Vector2i(1920, 1080)
	_run.call_deferred()


func _view() -> WorldView:
	while true:
		var view: WorldView = game.get_node_or_null("WorldView")
		if view != null and view.is_built_for(game.session.grid()):
			return view
		await get_tree().process_frame
	return null


func _shot(name: String) -> void:
	for i in 4:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out_dir + name + ".png")
	print("shot ", name)


func _run() -> void:
	game = Game.new()
	game.settings_path = "user://fx_shots_settings.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Kael", ContentDB.heroes[&"adventurer"]))
	var session: LocalSession = game.session
	var me := session.local_hero()
	session.world.move_hero(me.id, &"crossing", Vector2i(16, 20))
	var view: WorldView = await _view()
	var sim := session.zone_sim()
	me.move.place(Vector2i(16, 20))
	var west := sim.add_hero(ContentDB.heroes[&"adventurer"])
	west.move.place(Vector2i(20, 20))
	session.rules().game_speed = 0.0001 # frozen
	await get_tree().create_timer(0.1).timeout
	for j in 6:
		await get_tree().process_frame
	view.camera.follow(view.actor_screen_pos(me).lerp(view.actor_screen_pos(west), 0.5), 0.0, true)
	var t: float = session.render_time()
	var n := 0
	for id in [&"water_lash", &"fire_arc", &"air_palm_spiral", &"air_gust_spiral", &"rock_impact"]:
		var fx: FxDef = ContentDB.effects[id]
		var mid := t - fx.duration() * 0.45
		# Hero 1 sends it south-east toward a point 2 tiles away; hero 2 north-west.
		view._fx.on_events([
			{"type": "fx", "fx": id, "from": me.move.pos, "to": me.move.pos + Vector2(2, 0), "at": mid},
			{"type": "fx", "fx": id, "from": west.move.pos, "to": west.move.pos + Vector2(-2, 0), "at": mid},
		], ContentDB.effects)
		await _shot("fx%d_%s" % [n, id])
		view._fx.clear()
		n += 1
	# Rock Throw: held beside the hero (risen), then in flight, then landing.
	me.casting = {"ability": ContentDB.abilities[&"E01"], "kind": "timing", "start": t - 1.0, "end": t + 2.0}
	me.face(Vector2i.RIGHT)
	await _shot("fx5_rock_held")
	me.casting = {}
	var e01: AbilityDef = ContentDB.abilities[&"E01"]
	sim._pending_hits.append({"caster": me.id, "ability": e01, "tiles": [] as Array[Vector2i], "at": t + 0.15,
			"grace": 0.0, "bonus": 1.0, "circle": [me.move.pos + Vector2(4, 0), 0.5], "from": me.move.pos,
			"start": t - 0.15})
	await _shot("fx6_rock_in_flight")
	get_tree().quit()
