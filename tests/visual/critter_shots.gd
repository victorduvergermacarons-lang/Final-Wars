extends Node
## The Critters pack's boar and stag on screen (needs a display or xvfb):
##   SHOTS_DIR=/tmp/shots godot --path . res://tests/visual/critter_shots.tscn
## Four boars and four stags in the Windsteppe facing south-west, south-east,
## north-west and north-east: idle, walking / running, the boar's attack fallback
## (held run frame, then the lunge) and its death fallback (tipped over).

var out_dir := OS.get_environment("SHOTS_DIR").path_join("") if OS.get_environment("SHOTS_DIR") != "" else ProjectSettings.globalize_path("user://shots/")
var game: Game
const FACINGS := [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP]


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
	game.settings_path = "user://critter_shots_settings.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Kael", ContentDB.heroes[&"adventurer"]))
	var session: LocalSession = game.session
	var me := session.local_hero()
	session.world.move_hero(me.id, &"windsteppe", Vector2i(30, 36))
	var view: WorldView = await _view()
	var sim := session.zone_sim()
	for e in sim.enemies():
		sim.remove_enemy(e.id) # just ours on screen
	await get_tree().create_timer(2.5).timeout # a clock past the death times set below
	var boars: Array[Enemy] = []
	var stags: Array[Enemy] = []
	for i in 4:
		var b := sim.add_enemy(ContentDB.enemies[&"boar"], Vector2i(26 + i * 2, 33))
		b.face(FACINGS[i])
		boars.append(b)
		var s := sim.add_enemy(ContentDB.enemies[&"stag"], Vector2i(27 + i * 2, 30))
		s.face(FACINGS[i])
		stags.append(s)
	session.rules().game_speed = 0.0001 # frozen: nothing moves unless told
	await get_tree().create_timer(0.1).timeout
	for i in 6:
		await get_tree().process_frame
		view.camera.follow(view.actor_screen_pos(boars[1]).lerp(view.actor_screen_pos(stags[2]), 0.5), 0.0, true)
	await _shot("cr0_idle")
	for e in boars + stags:
		e.move.vel = Vector2(e.facing) * 2.0 # walking the way it faces (stags walk out of a fight)
	await _shot("cr1_walk")
	for e in boars + stags:
		e.state = Enemy.State.COMBAT # in a fight: stags run
	await _shot("cr2_run")
	var t: float = session.render_time()
	for b in boars:
		b.move.vel = Vector2.ZERO
		b.casting = {"ability": ContentDB.abilities[&"boar_gore"], "kind": "windup", "start": t - 0.1, "end": t + 1.0, "aim": Vector2(b.tile() + b.facing), "target": -1}
	await _shot("cr3_boar_windup")
	for b in boars:
		b.casting = {}
		b.alive = false
		b.died_at = t - 0.2
	for s in stags:
		s.move.vel = Vector2.ZERO
		s.state = Enemy.State.IDLE
	await _shot("cr4_boar_dying")
	for b in boars:
		b.died_at = t - 2.0
	await _shot("cr5_boar_dead")
	get_tree().quit()
