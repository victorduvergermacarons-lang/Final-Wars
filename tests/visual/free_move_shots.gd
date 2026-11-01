extends Node
## Free movement on screen (needs a display or xvfb):
##   SHOTS_DIR=/tmp/shots godot --path . res://tests/visual/free_move_shots.tscn
## A hero between tiles walking diagonally, beside a house, and a fall off
## Greenfields' plateau under gravity (mid-air, then landed with fall damage).

var out_dir := OS.get_environment("SHOTS_DIR").path_join("") if OS.get_environment("SHOTS_DIR") != "" else ProjectSettings.globalize_path("user://shots/")
var game: Game


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	TileArt.freeze_water = true
	WorldView.freeze_pulses = true
	get_window().size = Vector2i(1280, 720)
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
	game.settings_path = "user://free_move_shots_settings.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Ayla", ContentDB.heroes[&"adventurer"]))
	var session: LocalSession = game.session
	var hero := session.local_hero()
	var view: WorldView = await _view()
	# Walking diagonally (W + D) across Millbrook: between tiles, facing the way it goes.
	session.send_intent({"type": "move", "dir": Vector2i(1, -1), "face": 0.0})
	await get_tree().create_timer(0.6).timeout
	session.send_intent({"type": "move", "dir": Vector2i(1, -1), "face": 0.0})
	view.camera.follow(view.actor_screen_pos(hero), 0.0, true)
	await _shot("fm1_walking_diagonal")
	session.send_intent({"type": "move", "dir": Vector2i.ZERO, "face": 0.0})
	# Off a ledge: find a tile 4+ levels above a walkable neighbour, in Greenfields.
	var grid := GridModel.from_zone(ContentDB.zones[&"greenfields"])
	var edge := Vector2i(-1, -1)
	var down := Vector2i.ZERO
	for y in grid.depth:
		for x in grid.width:
			var p := Vector2i(x, y)
			for d in GridModel.DIRECTIONS:
				if edge.x < 0 and grid.is_walkable(p) and grid.is_walkable(p + d) \
						and grid.height_at(p) - grid.height_at(p + d) >= 4:
					edge = p
					down = d
	session.world.move_hero(hero.id, &"greenfields", edge)
	view = await _view()
	await get_tree().create_timer(0.2).timeout
	view.camera.follow(view.actor_screen_pos(hero), 0.0, true)
	await _shot("fm2_on_the_ledge")
	hero.walk_target = Vector2(edge + down * 2)
	hero.walk_deadline = session.now() + 3.0
	while not hero.move.falling():
		await get_tree().process_frame
	await get_tree().create_timer(0.12).timeout
	await _shot("fm3_falling")
	while hero.move.falling():
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	await _shot("fm4_landed")
	# Aim indicators (phase 4): Slash's cone and the Fireball's circle toward the
	# mouse, and an enemy-style telegraph outline.
	var sim := session.zone_sim()
	var at := hero.move.pos
	var wolf := sim.add_enemy(ContentDB.enemies[&"wolf"], hero.tile() + Vector2i(1, 1))
	TreeRules.master(hero, ContentDB.abilities[&"F07"])
	view.camera.follow(view.actor_screen_pos(hero), 0.0, true)
	for spec in [["fm5_aim_slash", &"S01", at + Vector2(1.2, 0.9)], ["fm6_aim_fireball", &"F07", at + Vector2(3.0, -1.5)],
			["fm7_aim_whip", &"F06", at + Vector2(2.0, 2.6)]]:
		var ab: AbilityDef = ContentDB.abilities[spec[1]]
		var p := AimPreview.preview(session.grid(), session.rules(), session.actors(), hero, ab, spec[2], null, session.now())
		game.client.aim = {"ability": ab, "tiles": p.tiles, "point": spec[2], "valid": true, "outline": p.outline}
		await _shot(spec[0])
	game.client.aim = {}
	get_tree().quit()
