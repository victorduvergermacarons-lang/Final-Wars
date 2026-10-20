extends Node
## Renders a few game situations to PNGs for a visual check (needs a display or
## xvfb and a Godot build with a renderer):
##   SHOTS_DIR=/tmp/shots godot --path . res://tests/visual/shots.tscn

## Where the PNGs go: $SHOTS_DIR, or user://shots/.
var out_dir := OS.get_environment("SHOTS_DIR").path_join("") if OS.get_environment("SHOTS_DIR") != "" else ProjectSettings.globalize_path("user://shots/")
var game: Game


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	# Another window size: launch with --resolution 1920x1080 (and an xvfb screen
	# that big); resizing the window from here leaves part of the capture black.
	if not OS.get_cmdline_args().has("--resolution"):
		get_window().size = Vector2i(1280, 720)
	_run.call_deferred()


## Puts the camera on the hero at once (it normally eases toward them).
func _snap_camera(hero: Hero) -> void:
	await get_tree().process_frame
	var view: WorldView = game.get_node("WorldView")
	view.camera.follow(view.actor_screen_pos(hero), 0.0, true)


func _shot(name: String) -> void:
	for i in 8:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out_dir + name + ".png")
	print("shot ", name)


func _run() -> void:
	var cd = ContentDB
	game = Game.new()
	game.settings_path = "user://shots_settings.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Ayla", cd.heroes[&"adventurer"]))
	var session: LocalSession = game.session
	var hero := session.local_hero()
	var hud: Hud = game.get_node("Hud")
	# 1. Town next to Rowan, quest tracked, bar 2 shown.
	hero.move.place(Vector2i(11, 9))
	hero.face(Vector2i.RIGHT)
	QuestLog.accept(hero, cd.quests[&"word_to_hilda"])
	game.client.action_bar.set_page(1)
	await _shot("1_town_rowan")
	# 2. Inventory + quest log open: tracker hidden.
	game.client.action_bar.set_page(0)
	hud.inventory_window.visible = true
	await _shot("2_inventory_open")
	hud.inventory_window.visible = false
	hud.quest_log.visible = true
	await _shot("3_quest_log")
	hud.quest_log.visible = false
	# 3. Greenfields, near the bandit camp, quest active.
	hero.quest_state["wolves_at_the_gate"] = {"state": "done"}
	hero.level = 3
	QuestLog.accept(hero, cd.quests[&"bandit_camp"])
	session.world.move_hero(hero.id, &"greenfields", Vector2i(18, 24))
	await _shot("4_bandit_camp")
	# 4. Floating combat text pile-up on a Wolf next to us.
	var fields := session.world.zone(&"greenfields")
	var wolf: Enemy = fields.enemies().filter(func(e): return e.def.id == &"wolf")[0]
	hero.move.place(wolf.tile() + Vector2i(0, 1))
	hero.face(Vector2i.UP)
	var view: WorldView = game.get_node("WorldView")
	view._on_events([{"type": "damage", "target": wolf.id, "amount": 31, "crit": false},
			{"type": "damage", "target": wolf.id, "amount": 62, "crit": true, "flank": "side"},
			{"type": "miss", "target": hero.id}, {"type": "level_up", "target": hero.id, "level": 4}])
	await _shot("5_float_text")
	# 5. Grizzlehide.
	var bear: Enemy = fields.enemies().filter(func(e): return e.def.elite)[0]
	hero.move.place(bear.tile() + Vector2i(-5, 0))
	await _shot("6_grizzlehide")
	# 6. Milestone 3 aiming: a Fire Whip line aimed at the wolf, Burning Ground and
	# a Fireball telegraph, a wolf winding up a bite.
	hero.move.place(wolf.tile() + Vector2i(-3, 0))
	hero.face(Vector2i.RIGHT)
	for id in [&"F06", &"F07", &"F08"]:
		TreeRules.master(hero, cd.abilities[id])
	fields.cast(hero, cd.abilities[&"F08"], null, Vector2(wolf.tile() + Vector2i(0, 3)))
	hero.cooldowns = Cooldowns.new()
	fields.cast(hero, cd.abilities[&"F07"], null, Vector2(wolf.tile() + Vector2i(-1, -3)))
	wolf.casting = {"ability": cd.abilities[&"wolf_bite"], "kind": "windup", "start": session.now(),
			"end": session.now() + 30.0, "target": hero.id, "aim": null, "next_tick": INF, "bonus": 1.0}
	var input: PlayerInput = game.get_node("PlayerInput")
	game.client.target_id = wolf.id
	input.start_aiming(cd.abilities[&"F06"])
	await _shot("7_aiming_telegraphs")
	input.cancel_aiming()
	# 7. Fire tree: Fire Dart mastered, Fire Punch being learned, tier 2 unlocked.
	TreeRules.master(hero, cd.abilities[&"F03"])
	Mastery.add_permanent(hero, "Fire", 160)
	hud._toggle(hud.trees_window)
	hud.trees_window.show_tree("Fire")
	await _shot("8_fire_tree")
	hud._toggle(hud.trees_window)
	# 8. Inventory and character sheet with the learning slot.
	hud.inventory_window.visible = true
	hud._character.visible = true
	await _shot("9_learning_slot")
	hud.inventory_window.visible = false
	hud._character.visible = false
	# 9. Debug console after a few commands.
	hud.console.open()
	for line in ["help", "spawn wolf 3 2", "mastery water 200"]:
		hud.console._submit(line)
		await get_tree().physics_frame
		await get_tree().physics_frame
	await _shot("10_debug_console")
	hud.console.close()
	# 10. A Goblin Shaman's bolt flying at an angle toward the hero.
	var shaman: Enemy = fields.enemies().filter(func(e): return e.def.id == &"goblin_shaman")[0]
	hero.move.place(shaman.tile() + Vector2i(4, 2))
	shaman.cooldowns = Cooldowns.new()
	fields.cast(shaman, cd.abilities[&"shadow_bolt"], null, Vector2(hero.tile()))
	for i in 4:
		await get_tree().physics_frame
	await _shot("11_angled_bolt")
	# 10b. A Bandit Brute winding up Crushing Blow: three tiles telegraphed.
	var brute: Enemy = fields.enemies().filter(func(e): return e.def.id == &"bandit_brute")[0]
	hero.move.place(brute.tile() + Vector2i(-1, 0))
	brute.cooldowns = Cooldowns.new()
	fields.cast(brute, cd.abilities[&"crushing_blow"], null, Vector2(hero.tile()))
	await _shot("11b_brute_swipe")
	# 10c. Standing behind a boulder on a rock pillar (Greenfields (18,15)).
	hero.alive = true
	hero.hp = 100.0
	hero.move.place(Vector2i(17, 15))
	await _shot("11c_behind_boulder")
	# 11. Hilda's shop, scrolled.
	session.world.move_hero(hero.id, &"town", Vector2i(8, 8))
	var town := session.world.zone(&"town")
	var hilda: Npc = town.npcs().filter(func(n): return n.def.id == &"hilda")[0]
	hud.vendor_window.open(hilda)
	hud.vendor_window.visible = true
	await _shot("12_shop")
	hud.vendor_window.visible = false
	hud.dialogue.visible = false
	# 12. Standing right behind an Earth Wall (the wall runs along the grid's y axis).
	hero.alive = true
	hero.hp = 100.0
	# Arrived from the tile nearer the camera (the case that drew the hero over the wall).
	hero.move.place(Vector2i(8, 9))
	hero.move.begin(Vector2i(8, 8), session.now() - 1.0, 0.2)
	for y in range(5, 12):
		town.grid.set_tile(Vector2i(9, y), town.grid.height_at(Vector2i(9, y)) + 2, true)
	await _shot("13_behind_wall")
	# Mid-step beside the wall: walking away from the camera (70% of the way) and
	# toward it (30%); the wall must hide the hero in both.
	hero.move.place(Vector2i(8, 9))
	hero.move.begin(Vector2i(8, 8), session.render_time() - 7.0, 10.0)
	await _shot("13b_walking_away")
	hero.move.place(Vector2i(8, 8))
	hero.move.begin(Vector2i(8, 9), session.render_time() - 3.0, 10.0)
	await _shot("13c_walking_toward")
	# Same, with a (calm) wolf standing on the wall tile beside the hero: the wall
	# still hides the hero, and the wolf stands on top.
	var calm: EnemyDef = cd.enemies[&"wolf"].duplicate()
	calm.aggro_radius = 0
	town.add_enemy(calm, Vector2i(9, 8))
	hero.move.place(Vector2i(8, 8))
	hero.move.begin(Vector2i(8, 9), session.render_time() - 3.0, 10.0)
	await _shot("13d_wall_tile_occupied")
	# 14. The tiled zones: Greenfields overview (zoomed out), the rocky plateau,
	# the pond and river, and Millbrook.
	session.world.move_hero(hero.id, &"greenfields", Vector2i(15, 15))
	await get_tree().process_frame
	var gview: WorldView = game.get_node("WorldView")
	for i in 3:
		gview.camera.step_zoom(-1)
	await _snap_camera(hero)
	await _shot("14_greenfields_overview")
	for i in 3:
		gview.camera.step_zoom(1)
	hero.move.place(Vector2i(22, 13))
	await _snap_camera(hero)
	await _shot("15_rocky_plateau")
	hero.move.place(Vector2i(23, 25))
	await _snap_camera(hero)
	await _shot("16_pond_and_river")
	session.world.move_hero(hero.id, &"town", Vector2i(9, 9))
	await get_tree().process_frame
	await _snap_camera(hero)
	await _shot("17_millbrook")
	# 15. Wolves: one facing each way (SW, SE, NW, NE), feet on their tiles.
	session.world.move_hero(hero.id, &"greenfields", Vector2i(9, 25))
	await get_tree().process_frame
	var gf := session.world.zone(&"greenfields")
	var still: EnemyDef = cd.enemies[&"wolf"].duplicate()
	still.aggro_radius = 0
	var dirs := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]
	for i in 4:
		var w := gf.add_enemy(still, Vector2i(6 + i * 2, 27))
		w.face(dirs[i])
	var view4: WorldView = game.get_node("WorldView")
	view4.camera.step_zoom(1)
	await _snap_camera(hero)
	await _shot("18_wolf_facings")
	# 16. The first wolf mid-death, the second flashing white from a hit.
	var line := gf.enemies().filter(func(e): return e.def == still)
	line[0].alive = false
	line[0].state = Enemy.State.DEAD
	line[0].died_at = session.render_time() - 0.6
	line[0].respawn_at = INF
	view4._flash_until[line[1].id] = session.render_time() + 30.0
	await _shot("19_wolf_death_and_flash")
	# 17. The pack in the north-west corner: one wolf spots the hero and howls,
	# then the pack closes in.
	hero.hp = hero.current_stats(session.now()).hp
	hero.move.place(Vector2i(3, 7))
	await _snap_camera(hero)
	await get_tree().create_timer(0.5).timeout
	await _snap_camera(hero)
	await _shot("20_pack_howl")
	await get_tree().create_timer(1.6).timeout
	await _snap_camera(hero)
	await _shot("21_pack_closing_in")
	view4.camera.step_zoom(-1)
	# 18. Millbrook's gate to the Enemy Testing Grounds (north-east hedge).
	hero.hp = hero.current_stats(session.now()).hp
	session.world.move_hero(hero.id, &"town", Vector2i(16, 2))
	await get_tree().process_frame
	await _snap_camera(hero)
	await _shot("22_millbrook_gate")
	# 19. The testing grounds: entrance with the Reset Shrine, then pens.
	session.world.move_hero(hero.id, &"enemy_testing", Vector2i(4, 11))
	await get_tree().process_frame
	await _snap_camera(hero)
	await _shot("23_testing_entrance")
	var tz := session.world.zone(&"enemy_testing")
	var hound: Enemy = tz.enemies().filter(func(e): return e.def.id == &"salamander_hound")[0]
	hero.move.place(hound.spawn_tile + Vector2i(0, 7))
	await _snap_camera(hero)
	await _shot("24_hound_pen")
	# 20. Salamander Hounds facing each way, one flashing, one dead.
	var calm_hound: EnemyDef = cd.enemies[&"salamander_hound"].duplicate()
	calm_hound.aggro_radius = 0
	var view5: WorldView = game.get_node("WorldView")
	view5.camera.step_zoom(1)
	var row: Array = []
	for i in 4:
		var h := tz.add_enemy(calm_hound, hound.spawn_tile + Vector2i(-3 + i * 2, 4))
		h.face(dirs[i])
		row.append(h)
	hero.move.place(hound.spawn_tile + Vector2i(0, 7))
	await _snap_camera(hero)
	await _shot("25_hound_facings")
	view5._flash_until[row[1].id] = session.render_time() + 30.0
	row[0].alive = false
	row[0].state = Enemy.State.DEAD
	row[0].died_at = session.render_time() - 0.6
	row[0].respawn_at = INF
	await _shot("26_hound_death_and_flash")
	for h in row:
		tz.remove_enemy(h.id)
	# 21. The hound fights: Cinder Pounce's mark, then its Ember Trail.
	hero.move.place(hound.spawn_tile + Vector2i(0, 3)) # 3 tiles away: it pounces
	await _snap_camera(hero)
	await get_tree().create_timer(0.3).timeout
	await _shot("27_cinder_pounce_mark")
	await get_tree().create_timer(0.6).timeout
	await _shot("28_pounce_landed")
	hero.move.place(hound.tile() + Vector2i(5, 1))
	await get_tree().create_timer(1.6).timeout
	await _snap_camera(hero)
	await _shot("29_ember_trail")
	# 22. The Boss Arena at the far end.
	var boss: Enemy = tz.enemies().filter(func(e): return e.def.elite)[0]
	view5.camera.step_zoom(-1)
	hero.move.place(boss.spawn_tile + Vector2i(-14, 8))
	await _snap_camera(hero)
	await _shot("30_boss_arena")
	get_tree().quit()
