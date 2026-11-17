extends GutTest
## The map editor's Shape tool in its model (ZoneEdit): removing tiles makes holes
## (kept in step in the rows and the live grid, undone as one stroke), adding tiles
## fills holes or grows the map beyond its rectangle (moving everything with the
## ground), trimming cuts empty sides off before saving, and the check names things
## left on holes.

var edit: ZoneEdit
var source: ZoneDef
const SCRATCH := "user://map_shape_edit_test/"
var _backup := {}


func before_each() -> void:
	_backup = {"zones": ContentDB.zones.duplicate(), "quests": ContentDB.quests.duplicate()}
	source = ContentDB.zones[&"town"]
	var copy := ZoneEdit.copy_of(source)
	edit = ZoneEdit.new(copy, ContentDB.tilesets[copy.tileset], GridModel.from_zone(copy))


func after_each() -> void:
	ContentDB.zones = _backup.zones
	ContentDB.quests = _backup.quests
	var dir := ProjectSettings.globalize_path(SCRATCH)
	if DirAccess.dir_exists_absolute(dir):
		OS.move_to_trash(dir)


## A tile of plain ground with nothing on it, away from the edges.
func _free_tile() -> Vector2i:
	var used := {}
	for r in edit.all_things():
		used[edit.thing_tile(r)] = true
	for y in range(3, edit.depth() - 3):
		for x in range(3, edit.width() - 3):
			var p := Vector2i(x, y)
			if edit.is_walkable(p) and edit.prop_at(p) == "" and not used.has(p):
				return p
	return Vector2i(-1, -1)


func test_removing_a_tile_makes_a_hole_in_rows_and_grid() -> void:
	var p := _free_tile()
	assert_eq(edit.remove_tiles([p]), [p] as Array[Vector2i])
	assert_false(edit.has_tile(p))
	assert_eq(edit.zone.height_rows[p.y][p.x], ZoneDef.NO_TILE)
	assert_eq(edit.zone.terrain_rows[p.y][p.x], ZoneDef.NO_TILE)
	assert_eq(edit.zone.walk_rows[p.y][p.x], "#")
	assert_false(edit.grid.has_tile(p))
	assert_false(edit.grid.is_walkable(p))
	assert_eq(edit.zone.validate(), PackedStringArray())
	assert_eq(edit.zone.validate_terrain(edit.tileset), PackedStringArray())


func test_painting_skips_holes_and_things_cannot_go_there() -> void:
	var p := _free_tile()
	edit.remove_tiles([p])
	assert_eq(edit.paint_terrain([p], "water"), [] as Array[Vector2i])
	assert_eq(edit.change_height([p], 1), [] as Array[Vector2i])
	assert_eq(edit.paint_prop([p], "flowers"), [] as Array[Vector2i])
	assert_false(edit.has_tile(p), "still a hole")
	assert_true(edit.add_thing("hero_spawn", p).is_empty())


func test_a_shape_stroke_undoes_and_redoes_as_one_step() -> void:
	var p := _free_tile()
	var ground := edit.terrain_at(p)
	var h := edit.height_at(p)
	edit.begin_stroke()
	edit.remove_tiles([p, p + Vector2i(1, 0)])
	edit.end_stroke()
	edit.undo()
	assert_true(edit.has_tile(p))
	assert_eq(edit.terrain_at(p), ground)
	assert_eq(edit.height_at(p), h)
	assert_true(edit.grid.has_tile(p))
	assert_true(edit.grid.is_walkable(p))
	edit.redo()
	assert_false(edit.has_tile(p + Vector2i(1, 0)))


func test_adding_fills_a_hole_with_the_chosen_ground() -> void:
	var p := _free_tile()
	edit.remove_tiles([p])
	assert_eq(edit.add_tiles([p], "dirt", 2), [p] as Array[Vector2i])
	assert_true(edit.has_tile(p))
	assert_eq(edit.terrain_at(p), "dirt")
	assert_eq(edit.height_at(p), 2)
	assert_true(edit.grid.has_tile(p))
	assert_eq(edit.grid.height_at(p), 2)
	assert_eq(edit.add_tiles([p], "grass", 0), [] as Array[Vector2i], "only where there is no tile")


func test_adding_beyond_the_north_west_grows_the_map_and_moves_everything() -> void:
	var size := edit.size()
	var spawn: Vector2i = edit.zone.hero_spawns[0]
	var shift := edit.shift
	var by := edit.grow_to_include([Vector2i(-2, -1)], 3)
	assert_eq(by, Vector2i(5, 4))
	assert_eq(edit.size(), size + by)
	assert_eq(edit.zone.hero_spawns[0], spawn + by, "things keep their ground")
	assert_eq(edit.shift, shift + by)
	assert_false(edit.has_tile(Vector2i(0, 0)), "the new rows hold no tiles yet")
	var added := Vector2i(-2, -1) + by
	assert_eq(edit.add_tiles([added], "grass", 0), [added] as Array[Vector2i])
	assert_true(edit.has_tile(added))
	assert_eq(edit.zone.validate(), PackedStringArray())


func test_trim_cuts_empty_sides_and_moves_things_back() -> void:
	var size := edit.size()
	var spawn: Vector2i = edit.zone.hero_spawns[0]
	var by := edit.grow_to_include([Vector2i(-1, -1), size], 2)
	assert_eq(edit.trimmable().size(), 4, "empty rows on every side")
	assert_eq(edit.trim(), -by)
	assert_eq(edit.size(), size)
	assert_eq(edit.zone.hero_spawns[0], spawn)
	assert_eq(edit.trim(), Vector2i.ZERO, "nothing more to cut")


func test_trim_after_removing_a_whole_side() -> void:
	var size := edit.size()
	var row: Array = []
	for x in edit.width():
		row.append(Vector2i(x, edit.depth() - 1))
	var spawn: Vector2i = edit.zone.hero_spawns[0]
	edit.remove_tiles(row)
	assert_eq(edit.trimmable(), {Vector2i.DOWN: -1})
	edit.trim()
	assert_eq(edit.size(), size - Vector2i(0, 1))
	assert_eq(edit.zone.hero_spawns[0], spawn, "a cut on the south-west side moves nothing")


func test_the_last_tile_cannot_be_removed() -> void:
	var all: Array = []
	for y in edit.depth():
		for x in edit.width():
			all.append(Vector2i(x, y))
	assert_eq(edit.remove_tiles(all), [] as Array[Vector2i])
	assert_eq(edit.tile_count(), edit.width() * edit.depth())


func test_the_check_names_things_left_on_a_hole() -> void:
	var g: Vector2i = edit.zone.graveyards[0]
	edit.remove_tiles([g])
	var found := ZoneCheck.problems(edit.zone, GridModel.from_zone(edit.zone))
	assert_true(Array(found).any(func(s): return "graveyard" in s and "no tile" in s), str(found))


func test_a_shaped_map_saves_and_loads_back() -> void:
	var p := _free_tile()
	edit.remove_tiles([p])
	edit.grow_to_include([Vector2i(edit.width(), 0)], 0)
	edit.add_tiles([Vector2i(edit.width() - 1, 0)], "grass", 1)
	var s := ZoneSaver.new()
	s.redirect = SCRATCH
	assert_eq(s.save(edit, source.resource_path), OK)
	var back: ZoneDef = ResourceLoader.load(SCRATCH + source.resource_path.trim_prefix("res://"), "",
			ResourceLoader.CACHE_MODE_IGNORE)
	assert_false(back.has_tile(p))
	assert_true(back.has_tile(Vector2i(back.get_width() - 1, 0)))
	assert_false(back.has_tile(Vector2i(back.get_width() - 1, 1)), "the rest of the new column is empty")
	var g := GridModel.from_zone(back)
	assert_not_null(g)
	assert_false(g.has_tile(p))
