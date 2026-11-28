extends Node
## Phase 3 of feature/water-physics (2026-11-28): water as a resource. The stance 1
## rope forming from the hips and from a river, a short rope growing back, the stance 2
## hoop (full at 33, and at 27), going back to stance 1 (the extra water spills), the
## water flowing home when the stance drops, and the pouch filling at the river.
##   SHOTS_DIR=/tmp/w3 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . res://tests/visual/water_resource_shots.tscn

var out_dir := OS.get_environment("SHOTS_DIR").path_join("") if OS.get_environment("SHOTS_DIR") != "" else ProjectSettings.globalize_path("user://shots/")
var game: Game
var world: World
var hero: Hero
var crop := Rect2i(960 - 260, 540 - 230, 520, 360)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1920, 1080)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String, region := crop) -> void:
	await _frames(2)
	var img := get_viewport().get_texture().get_image()
	if region.has_area():
		img = img.get_region(region)
	img.save_png(out_dir + name + ".png")
	print("shot ", name, "  stance ", hero.stance, "  stance water ", hero.stance_water, "  pouch ", hero.water)


func _stance(n: int) -> void:
	world.submit(hero.id, {"type": "stance", "tree": "Water" if n > 0 else "", "stance": n})


## A walkable tile with nothing within `away` tiles but water within `near` of it.
func _spot(sim: WorldSim, min_d: float, max_d: float) -> Vector2i:
	var idx := WaterTiles.of(sim.zone)
	for y in range(4, sim.grid.depth - 4):
		for x in range(4, sim.grid.width - 4):
			var t := Vector2i(x, y)
			if not sim.grid.is_walkable(t) or sim.is_occupied(t):
				continue
			var w = WaterTiles.nearest(idx, Vector2(t), max_d)
			if w != null and WaterTiles.nearest(idx, Vector2(t), min_d) == null:
				return t
	return Vector2i(-1, -1)


func _go(t: Vector2i) -> void:
	var sim := world.zone_of(hero.id)
	hero.move.place(t)
	hero.move.ground_h = sim.grid.height_at(t)
	await _frames(8)


## A tile of `terrain` with walkable ground of the same height round it, far from water.
func _terrain_spot(sim: WorldSim, terrain: String) -> Vector2i:
	var idx := WaterTiles.of(sim.zone)
	for y in range(3, sim.grid.depth - 3):
		for x in range(3, sim.grid.width - 3):
			var t := Vector2i(x, y)
			if sim.zone.terrain_at(t) != terrain or not sim.grid.is_walkable(t) or sim.is_occupied(t):
				continue
			if WaterTiles.nearest(idx, Vector2(t), 4.0) != null:
				continue
			var ok := true
			for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1)]:
				if sim.zone.terrain_at(t + d) != terrain or sim.grid.height_at(t + d) != sim.grid.height_at(t):
					ok = false
			if ok:
				return t
	return Vector2i(-1, -1)


func _run() -> void:
	game = Game.new()
	game.settings_path = "user://water_resource_shots.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Kanna", ContentDB.heroes[&"adventurer"], ContentDB.elements[&"water"]))
	world = game.session.world
	hero = world.heroes()[0] if world.has_method("heroes") else game.session.local_hero()
	for id in [&"W02", &"W12", &"W04", &"W07"]:
		TreeRules.master(hero, ContentDB.abilities[id])
	Mastery.add_permanent(hero, "Water", 200)
	var sim := world.zone_of(hero.id)
	if OS.get_environment("SHOTS_ONLY") == "shadows":
		# The rope's shadow (black at 30%) on three kinds of ground.
		_stance(1)
		for terrain in ["grass", "cobble", "path"]:
			var t := _terrain_spot(sim, terrain)
			if t == Vector2i(-1, -1):
				print("no ", terrain)
				continue
			await _go(t)
			hero.stance_water = 24
			await _wait(1.2)
			await _shot("w5_shadow_on_" + terrain, Rect2i(960 - 120, 540 - 110, 240, 170))
		get_tree().quit()
		return
	await _go(_spot(sim, 9.0, 30.0))
	# 1. Stance 1 away from water: the rope forms from the hips.
	_stance(1)
	await _wait(0.25)
	await _shot("w3_01_forming_from_the_hips")
	await _wait(1.5)
	await _shot("w3_02_full_rope_24")
	# 2. A short rope (12 points, as after spending water) grows back a point every 17 frames.
	hero.stance_water = 12
	await _wait(0.2)
	await _shot("w3_03_short_rope_12")
	await _wait(1.7)
	await _shot("w3_04_growing_back")
	# 3. Stance 2: the hoop, full at 33.
	_stance(2)
	await _wait(0.4)
	await _shot("w3_05_hoop_forming")
	await _wait(2.0)
	await _shot("w3_06_hoop_33")
	# 4. Back to stance 1: the 9 extra points spill.
	_stance(1)
	await _wait(0.1)
	await _shot("w3_07_back_to_1_spilling")
	await _wait(1.0)
	# 5. A hoop of 27 (the least that enters stance 2).
	_stance(0)
	await _wait(1.2)
	hero.water = 27
	_stance(2)
	await _wait(2.5)
	await _shot("w3_08_hoop_27")
	# 6. The stance drops after 10 s idle: the water flows back to the hip, tail first.
	_stance(0)
	hero.water = 200
	_stance(1)
	await _wait(2.0)
	hero.stance_busy_at = world.zone_of(hero.id).now - 9.9
	await _wait(0.25)
	await _shot("w3_09_dropping_tail_first")
	await _wait(1.0)
	await _shot("w3_10_back_in_the_pouch")
	# 7. Near the river: the water comes from it.
	await _go(_spot(sim, 1.5, 2.6))
	_stance(1)
	await _wait(0.3)
	await _shot("w3_11_forming_from_the_river")
	await _wait(1.5)
	await _shot("w3_12_full_by_the_river")
	_stance(0)
	await _wait(1.0)
	# 8. Filling the pouch with E: 10 s for an empty one.
	await _go(_spot(sim, 0.9, 1.5))
	hero.water = 60
	world.submit(hero.id, {"type": "fill_water"})
	await _wait(1.0)
	await _shot("w3_13_filling_the_pouch")
	get_tree().quit()
