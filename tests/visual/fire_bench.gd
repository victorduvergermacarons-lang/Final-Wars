extends Node
## Fire physics bench: an ability's look on the GPU fluid against a dummy, in the game's
## own world view, at Fire Mastery 0, 185 and 1000, near and far (the reference
## bench's distances), with frame times.
##   SHOTS_DIR=<dir> FIRE_ABILITY=F12 godot --path . res://tests/visual/fire_bench.tscn
## FIRE_STRESS=1: four casters on the same spot, for the frame time on your machine.

var out_dir := OS.get_environment("SHOTS_DIR").path_join("") if OS.get_environment("SHOTS_DIR") != "" else ProjectSettings.globalize_path("user://shots/")
var ability := StringName(OS.get_environment("FIRE_ABILITY")) if OS.get_environment("FIRE_ABILITY") != "" else &"F12"
var game: Game
var world: World
var hero: Hero
var view: WorldView
var dummy: Enemy
const DIR := Vector2(1, -1) # straight right on screen


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1920, 1080)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _spot(sim: WorldSim, reach: int) -> Vector2i:
	for y in range(reach + 2, sim.grid.depth - 4):
		for x in range(4, sim.grid.width - reach - 4):
			var t := Vector2i(x, y)
			var ok := true
			for k in range(-2, reach + 2):
				for side in [-1, 0, 1]:
					var c := t + Vector2i(k, -k) + Vector2i(side, side)
					if not sim.grid.in_bounds(c) or not sim.grid.is_walkable(c) or sim.grid.height_at(c) != sim.grid.height_at(t) \
							or sim.grid.blocks_sight(c) or sim.is_occupied(c):
						ok = false
			if ok:
				return t
	return Vector2i(8, 8)


func _run() -> void:
	game = Game.new()
	game.settings_path = "user://fire_bench.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Ember", ContentDB.heroes[&"adventurer"], ContentDB.elements[&"fire"]))
	world = game.session.world
	hero = world.heroes()[0]
	view = game.get_node("WorldView")
	var sim := world.zone_of(hero.id)
	var t := _spot(sim, 6)
	hero.move.place(t)
	hero.move.ground_h = sim.grid.height_at(t)
	var dd := EnemyDef.new()
	dd.id = &"bench_dummy"
	dd.display_name = "Dummy"
	dd.immobile = true
	dd.collider_radius = 0.3
	dd.stats = StatBlock.make({Stat.Id.HP: 100000})
	dd.aggro_radius = 0
	dummy = sim.add_enemy(dd, t + Vector2i(2, -2))
	await _frames(10)
	var look: FireLookDef = load("res://content/effects/fire/%s.tres" % ability)
	var stress := OS.get_environment("FIRE_STRESS") == "1"
	var ms_idle := await _frame_ms(60)
	print("frame time with no fire: %.2f ms" % ms_idle)
	for dist in [look.near, look.far]:
		var at := Vector2(t) + DIR.normalized() * (float(dist) / 16.0)
		dummy.move.place(at)
		dummy.move.pos = at
		for m in [0, 185, 1000]:
			var casters := 4 if stress else 1
			for c in casters:
				var e := view.fire.start(look, hero.id, Vector2(t), float(sim.grid.height_at(t)), at, float(m))
				if e == null:
					continue
				view.fire.set_walls(e, sim.grid)
				e.hold_steps = 190
				e.done_after = 190
				e.tail_steps = 60
			await _frames(30)
			var ms := await _frame_ms(60)
			await _shot("fire_%s_%s_m%d" % [String(ability), "near" if dist == look.near else "far", m], Vector2(t))
			print("%s %s mastery %d: %.2f ms a frame (%d effects, %d GPU steps run)" % [ability, "near" if dist == look.near else "far", m, ms,
					view.fire.effects.size(), view.fire.sim.frames_run])
			while not view.fire.effects.is_empty():
				await _frames(10)
	get_tree().quit()


func _frame_ms(n: int) -> float:
	var t0 := Time.get_ticks_usec()
	await _frames(n)
	return (Time.get_ticks_usec() - t0) / 1000.0 / n


func _shot(name: String, centre: Vector2) -> void:
	await _frames(1)
	var img := get_viewport().get_texture().get_image()
	var c := get_viewport().get_canvas_transform() * Iso.to_screen(centre + DIR * 1.6, hero.move.ground_h)
	var r := Rect2i(int(c.x) - 300, int(c.y) - 230, 600, 300).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(r).save_png(out_dir + name + ".png")
