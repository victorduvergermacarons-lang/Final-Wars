extends GutTest
## Square distance, 8-way and any-angle lines, cones, line clipping, push paths.

var grid: GridModel


func before_each() -> void:
	grid = GridModel.new(10, 10, 0)


func test_square_distance_and_areas() -> void:
	assert_eq(TileGeometry.distance(Vector2i(2, 2), Vector2i(3, 3)), 1, "diagonal neighbours are adjacent")
	assert_eq(TileGeometry.distance(Vector2i(0, 0), Vector2i(4, 2)), 4)
	assert_eq(TileGeometry.square(Vector2i(5, 5), 1).size(), 9, "3x3")
	assert_eq(TileGeometry.ring(Vector2i(5, 5)).size(), 8)
	assert_does_not_have(TileGeometry.ring(Vector2i(5, 5)), Vector2i(5, 5))


func test_snap8() -> void:
	assert_eq(TileGeometry.snap8(Vector2(3, 0.4)), Vector2i(1, 0))
	assert_eq(TileGeometry.snap8(Vector2(2, 2.3)), Vector2i(1, 1))
	assert_eq(TileGeometry.snap8(Vector2(-0.2, -5)), Vector2i(0, -1))
	assert_eq(TileGeometry.snap8(Vector2(-3, 2.8)), Vector2i(-1, 1))
	assert_eq(TileGeometry.snap8(Vector2.ZERO), Vector2i.ZERO)


func test_lines() -> void:
	assert_eq(TileGeometry.line8(Vector2i(2, 2), Vector2i(1, 1), 3),
			[Vector2i(3, 3), Vector2i(4, 4), Vector2i(5, 5)] as Array[Vector2i])
	var any := TileGeometry.line_toward(Vector2i(0, 0), Vector2(4, 2), 6)
	assert_eq(any.size(), 6)
	assert_eq(any[1], Vector2i(2, 1), "passes through the aim line")
	assert_eq(any[3], Vector2i(4, 2), "hits the aim tile")
	assert_eq(any[5], Vector2i(6, 3), "keeps going past it")
	assert_eq(TileGeometry.line_toward(Vector2i(3, 3), Vector2(3, 3), 4).size(), 0)


func test_cone() -> void:
	var c := TileGeometry.cone(Vector2i(5, 5), Vector2i(1, 0), 3)
	assert_eq(c.size(), 1 + 3 + 5)
	assert_has(c, Vector2i(6, 5))
	assert_has(c, Vector2i(8, 3))
	assert_has(c, Vector2i(8, 7))


func test_clip_line_at_walls_and_height() -> void:
	grid.set_tile(Vector2i(3, 0), 3, false) # a rock wall
	var line := TileGeometry.line8(Vector2i(0, 0), Vector2i(1, 0), 6)
	assert_eq(TileGeometry.clip_line(grid, line, 0, 1.0).size(), 2, "stops before the wall")
	grid.set_tile(Vector2i(3, 0), 0, false) # water: shots fly over it
	assert_eq(TileGeometry.clip_line(grid, line, 0, 1.0).size(), 6)
	assert_eq(TileGeometry.clip_line(grid, TileGeometry.line8(Vector2i(8, 0), Vector2i(1, 0), 5), 0, 1.0).size(), 1,
			"stops at the map edge")


func test_push_path() -> void:
	var r := TileGeometry.push_path(grid, Vector2i(2, 2), Vector2i(1, 0), 3, 1, {})
	assert_eq(r.end, Vector2i(5, 2))
	assert_eq(r.stopped_by, "")
	r = TileGeometry.push_path(grid, Vector2i(2, 2), Vector2i(1, 0), 3, 1, {Vector2i(4, 2): true})
	assert_eq(r.end, Vector2i(3, 2))
	assert_eq(r.stopped_by, "unit")
	grid.set_tile(Vector2i(3, 3), 0, false)
	r = TileGeometry.push_path(grid, Vector2i(2, 2), Vector2i(1, 1), 3, 1, {})
	assert_eq(r.end, Vector2i(2, 2))
	assert_eq(r.stopped_by, "wall", "diagonal push into water stops")
	grid.set_tile(Vector2i(2, 1), 3, true)
	r = TileGeometry.push_path(grid, Vector2i(2, 2), Vector2i(0, -1), 2, 1, {})
	assert_eq(r.stopped_by, "ledge")
	r = TileGeometry.push_path(grid, Vector2i(9, 2), Vector2i(1, 0), 2, 1, {})
	assert_eq(r.stopped_by, "wall", "map edge")
