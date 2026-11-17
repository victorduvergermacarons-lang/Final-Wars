extends GutTest
## Maps that aren't rectangles: a ' ' (ZoneDef.NO_TILE) in height_rows is a hole in
## the map's shape. It is a wall to walkers and fliers (enemies path around it),
## but height 0 and open to sight, so spells and arrows fly over it; ground areas,
## terrain changes and walls leave it out.

var rules: CombatRules
var world: WorldSim
var hero: Hero


## 12×12 at height 0 with a hole across x = 6 for rows 0–9 (rows 10–11 go round it)
## and the north-east corner (x 10–11, y 0–1) missing.
static func shaped_zone() -> ZoneDef:
	var z := ZoneDef.new()
	z.id = &"island"
	var h: PackedStringArray = []
	var w: PackedStringArray = []
	for y in 12:
		var hr := ""
		var wr := ""
		for x in 12:
			var hole := (x == 6 and y <= 9) or (x >= 10 and y <= 1)
			hr += ZoneDef.NO_TILE if hole else "0"
			wr += "#" if hole else "."
		h.append(hr)
		w.append(wr)
	z.height_rows = h
	z.walk_rows = w
	z.hero_spawns = [Vector2i(1, 1)] as Array[Vector2i]
	z.graveyards = [Vector2i(1, 1)] as Array[Vector2i]
	return z


func before_each() -> void:
	rules = CombatRules.new()
	world = WorldSim.new(shaped_zone(), rules, 3)
	hero = world.add_hero(ContentDB.heroes[&"adventurer"])
	hero.move.place(Vector2i(4, 3))
	world.step()


func test_a_shaped_map_is_valid_and_its_holes_have_no_tile() -> void:
	var z := shaped_zone()
	assert_eq(z.validate(), PackedStringArray())
	assert_false(z.has_tile(Vector2i(6, 3)))
	assert_true(z.has_tile(Vector2i(6, 10)))
	var g := world.grid
	assert_true(g.in_bounds(Vector2i(6, 3)), "inside the rectangle")
	assert_false(g.has_tile(Vector2i(6, 3)))
	assert_false(g.is_walkable(Vector2i(6, 3)))
	assert_false(g.blocks_sight(Vector2i(6, 3)))
	assert_eq(g.height_at(Vector2i(6, 3)), 0)
	assert_true(g.has_tile(Vector2i(5, 3)))
	assert_false(g.has_tile(Vector2i(11, 0)))
	assert_false(g.has_tile(Vector2i(12, 5)), "outside the map")


func test_heroes_cannot_walk_into_a_hole() -> void:
	hero.move.place(Vector2(5.0, 3.0))
	world.step()
	world.submit(hero.id, {"type": "move", "dir": Vector2i(1, 1), "face": 0.0}) # grid +x
	world.advance(1.0)
	assert_lte(hero.move.pos.x, 5.5 - hero.move.radius + 0.01, "stopped at the hole's edge")
	assert_true(world.grid.has_tile(hero.tile()))


func test_paths_go_round_a_hole() -> void:
	var path := Pathfinder.find_path(world.grid, Vector2i(4, 3), Vector2i(8, 3), 2)
	assert_false(path.is_empty(), "there is a way round")
	for t in path:
		assert_true(world.grid.has_tile(t), "never through the hole: %s" % t)
	assert_true(path.any(func(t): return t.y >= 10), "round the bottom")


func test_fliers_cannot_cross_a_hole_either() -> void:
	assert_false(world.grid.can_fly(Vector2i(5, 3), Vector2i(6, 3), 1))
	assert_true(Mover.blocks(world.grid, Vector2i(6, 3), 0, 2, true))
	var path := Pathfinder.find_path(world.grid, Vector2i(4, 3), Vector2i(8, 3), 2, {}, -1, 4096, 1)
	for t in path:
		assert_true(world.grid.has_tile(t), "a flier goes round too: %s" % t)
	assert_true(Pathfinder.find_path(world.grid, Vector2i(4, 3), Vector2i(6, 3), 2, {}, -1, 4096, 1).is_empty(),
			"and can't end in it")


func test_shots_fly_over_a_hole() -> void:
	assert_true(Hitbox.has_los(world.grid, Vector2(4, 3), Vector2(8, 3), rules.los_height_tolerance))
	assert_almost_eq(Hitbox.clear_distance(world.grid, Vector2(4, 3), Vector2(1, 0), 4.0, rules.los_height_tolerance),
			4.0, 0.01, "nothing stops a line across the gap")


func test_ground_areas_leave_holes_out() -> void:
	var tiles := CastResolver.area_tiles(world.grid, Vector2i(6, 3), 1)
	assert_eq(tiles.size(), 6, "the 3×3 minus the hole's column")
	for t in tiles:
		assert_ne(t.x, 6)


func test_baked_walkability_keeps_holes_blocked() -> void:
	var z := shaped_zone()
	z.tileset = &"iso_basic"
	var ts: TilesetData = ContentDB.tilesets[&"iso_basic"]
	var terrain := ""
	for c in ts.terrains:
		terrain = c
		if ts.terrain_walkable(c):
			break
	z.terrain_legend = {"g": terrain}
	var rows: PackedStringArray = []
	for y in 12:
		var r := ""
		for x in 12:
			r += ZoneDef.NO_TILE if not z.has_tile(Vector2i(x, y)) else "g"
		rows.append(r)
	z.terrain_rows = rows
	assert_eq(z.validate_terrain(ts), PackedStringArray())
	z.bake_walkability(ts)
	assert_eq(z.walk_rows[3][6], "#")
	assert_eq(z.walk_rows[3][5], ".")
	assert_eq(z.sight_rows[3][6], ".")
