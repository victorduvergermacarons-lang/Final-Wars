extends Node
## The hero's sprite art (PL-01-1 and the PL-02 weapon sets) on screen (needs a
## display or xvfb):
##   SHOTS_DIR=/tmp/shots godot --path . res://tests/visual/hero_art_shots.tscn
## Four heroes in a row facing south-west, south-east, north-west and north-east,
## one shot per animation (a frame from its middle), and walking. The frames come
## from each hero's Hero.anim times, set here as the host would.

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
	game.settings_path = "user://hero_art_shots_settings.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Kael", ContentDB.heroes[&"adventurer"]))
	var session: LocalSession = game.session
	var me := session.local_hero()
	session.world.move_hero(me.id, &"crossing", Vector2i(14, 19))
	var view: WorldView = await _view()
	var sim := session.zone_sim()
	var heroes: Array[Hero] = [me]
	for i in 3:
		heroes.append(sim.add_hero(ContentDB.heroes[&"adventurer"]))
	for i in heroes.size():
		heroes[i].move.place(Vector2i(14 + i * 2, 19 - i * 2)) # a row across the screen
		heroes[i].face(FACINGS[i])
	session.rules().game_speed = 0.0001 # frozen: nothing moves unless told
	await get_tree().create_timer(0.1).timeout
	for i in 4:
		for j in 6:
			await get_tree().process_frame
		view.camera.follow(view.actor_screen_pos(heroes[1]).lerp(view.actor_screen_pos(heroes[2]), 0.5), 0.0, true)
	var t: float = session.render_time()
	var art: CreatureArtDef = ContentDB.heroes[&"adventurer"].art
	await _shot("ha0_idle")
	# Abilities: element (cast), then the weapon sets with their weapon in hand.
	for shot in [["ha1_cast", &"F01", null], ["ha2_sword_slash", &"S01", &"travelers_longsword"],
			["ha3_sword_lunge", &"S04", &"travelers_longsword"], ["ha4_bow_quick_shot", &"B01", &"hunters_shortbow"],
			["ha5_bow_aimed_shot", &"B02", &"hunters_shortbow"]]:
		for h in heroes:
			if shot[2] != null:
				h.wear(ContentDB.items[shot[2]])
			h.anim.act = shot[1]
			var anim := CreatureAnimator.action_anim(h, art)
			h.anim.act_at = t - art.duration(anim) * 0.5
		await _shot(shot[0])
	for h in heroes:
		h.anim.act_at = Hero.NEVER
		h.anim.hit = t - art.duration("hit") * 0.5
	await _shot("ha6_hit")
	for h in heroes:
		h.anim.hit = Hero.NEVER
		h.alive = false
		h.hp = 0.0
		h.anim.died = t - art.duration("death") * 0.5
	await _shot("ha7_dying")
	for h in heroes:
		h.anim.died = t - 10.0
	await _shot("ha8_dead_lying")
	for h in heroes:
		h.alive = true
		h.hp = 50.0
		h.anim.up = t - art.duration("revived") * 0.5
	await _shot("ha9_revived")
	for h in heroes:
		h.anim.up = Hero.NEVER
	# Walking: every hero moves the way it faces (the clock stays frozen).
	for i in heroes.size():
		heroes[i].move.vel = Vector2(FACINGS[i]) * 3.0
		heroes[i].move.odometer = 0.4
	await _shot("ha10_walking")
	get_tree().quit()
