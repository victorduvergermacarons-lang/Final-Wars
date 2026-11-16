extends GutTest
## The map editor's model (ZoneEdit), its file writer (ZoneFile) and the
## playability check it runs before saving (ZoneCheck).

var edit: ZoneEdit
var source: ZoneDef


func before_each() -> void:
	source = ContentDB.zones[&"town"]
	var copy := ZoneEdit.copy_of(source)
	edit = ZoneEdit.new(copy, ContentDB.tilesets[copy.tileset], GridModel.from_zone(copy))


func _grass_tile() -> Vector2i:
	for y in range(1, edit.depth() - 1):
		for x in range(1, edit.width() - 1):
			var p := Vector2i(x, y)
			if edit.terrain_at(p) == "grass" and edit.prop_at(p) == "" and source.decor_at(p) == null:
				return p
	return Vector2i(-1, -1)


func test_painting_works_on_a_copy_not_the_games_zone() -> void:
	var p := _grass_tile()
	edit.paint_terrain([p], "water")
	assert_eq(edit.terrain_at(p), "water")
	assert_eq(source.terrain_at(p), "grass", "the game's own zone is untouched until saved")
	assert_true(edit.dirty)


func test_painting_water_makes_the_tile_unwalkable_in_rows_and_grid() -> void:
	var p := _grass_tile()
	assert_true(edit.grid.is_walkable(p))
	edit.paint_terrain([p], "water")
	assert_false(edit.grid.is_walkable(p))
	assert_eq(edit.zone.walk_rows[p.y][p.x], "#")
	edit.paint_terrain([p], "grass")
	assert_true(edit.grid.is_walkable(p))
	assert_eq(edit.zone.walk_rows[p.y][p.x], ".")


func test_a_new_terrain_gets_a_legend_letter() -> void:
	var name := ""
	for t in edit.terrain_names():
		if not edit.zone.terrain_legend.values().has(t) and edit.tileset.terrain_walkable(t):
			name = t
			break
	if name == "":
		pending("every terrain is already in the legend")
		return
	var p := _grass_tile()
	edit.paint_terrain([p], name)
	assert_true(edit.zone.terrain_legend.values().has(name))
	assert_eq(edit.terrain_at(p), name)
	assert_eq(Array(edit.zone.validate_terrain(edit.tileset)), [])


func test_heights_raise_lower_and_clamp() -> void:
	var p := _grass_tile()
	var h := edit.height_at(p)
	edit.change_height([p], 1)
	assert_eq(edit.height_at(p), h + 1)
	assert_eq(edit.grid.height_at(p), h + 1, "the live grid follows")
	edit.set_height([p], 0)
	edit.change_height([p], -1)
	assert_eq(edit.height_at(p), 0, "never below 0")
	edit.set_height([p], 42)
	assert_eq(edit.height_at(p), ZoneEdit.MAX_HEIGHT)


func test_props_are_placed_and_erased_and_a_boulder_blocks_the_way() -> void:
	var p := _grass_tile()
	var blocking := ""
	for g in edit.prop_names():
		if not edit.tileset.is_walkable(edit.tileset.pick_prop(g, p)):
			blocking = g
			break
	assert_ne(blocking, "", "the tileset has a prop you can't walk through")
	edit.paint_prop([p], blocking)
	assert_eq(edit.prop_at(p), blocking)
	assert_false(edit.grid.is_walkable(p))
	edit.paint_prop([p], "")
	assert_eq(edit.prop_at(p), "")
	assert_true(edit.grid.is_walkable(p))


func test_a_stroke_undoes_and_redoes_as_one_step() -> void:
	var p := _grass_tile()
	var before := edit.zone.terrain_rows.duplicate()
	edit.begin_stroke()
	edit.paint_terrain(edit.brush(p, 3), "cobble")
	edit.paint_terrain(edit.brush(p + Vector2i(1, 0), 3), "cobble")
	edit.end_stroke()
	var after := edit.zone.terrain_rows.duplicate()
	assert_ne(Array(after), Array(before))
	var undone := edit.undo()
	assert_gt(undone.size(), 0)
	assert_eq(Array(edit.zone.terrain_rows), Array(before), "one undo takes back the whole drag")
	assert_false(edit.can_undo())
	edit.redo()
	assert_eq(Array(edit.zone.terrain_rows), Array(after))


func test_painting_the_same_value_is_not_a_change() -> void:
	var p := _grass_tile()
	assert_eq(edit.paint_terrain([p], "grass").size(), 0)
	assert_false(edit.can_undo())
	assert_false(edit.dirty)


func test_brush_is_a_square_cut_at_the_map_edge() -> void:
	assert_eq(edit.brush(Vector2i(5, 5), 1).size(), 1)
	assert_eq(edit.brush(Vector2i(5, 5), 3).size(), 9)
	assert_eq(edit.brush(Vector2i(5, 5), 5).size(), 25)
	assert_eq(edit.brush(Vector2i(0, 0), 3).size(), 4)


func test_eyedropper_reads_all_three_layers() -> void:
	var p := _grass_tile()
	edit.set_height([p], 2)
	assert_eq(edit.pick(p), {"terrain": "grass", "height": 2, "prop": ""})


func test_the_file_keeps_everything_but_the_layers() -> void:
	var text := FileAccess.get_file_as_string(source.resource_path)
	assert_eq(ZoneFile.with_layers(text, source), text, "writing the unchanged zone changes nothing")
	var p := _grass_tile()
	edit.paint_terrain([p], "water")
	edit.change_height([p + Vector2i(1, 0)], 1)
	edit.paint_prop([p + Vector2i(0, 1)], "flowers")
	var out := ZoneFile.with_layers(text, edit.zone)
	assert_ne(out, text)
	var path := "user://test_zone_edit.tres"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(out)
	f.close()
	var loaded: ZoneDef = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(loaded.terrain_at(p), "water")
	assert_eq(ZoneDef.parse_height(loaded.height_rows[p.y][p.x + 1]), edit.height_at(p + Vector2i(1, 0)))
	assert_eq(loaded.prop_at(p + Vector2i(0, 1)), "flowers")
	assert_eq(Array(loaded.walk_rows), Array(edit.zone.walk_rows))
	assert_eq(loaded.npcs.size(), source.npcs.size(), "people stay")
	assert_eq(loaded.enemy_spawns.size(), source.enemy_spawns.size())
	assert_eq(loaded.edges.size(), source.edges.size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_tidy_drops_legend_letters_nothing_uses() -> void:
	var p := _grass_tile()
	edit.paint_prop([p], "stump")
	edit.paint_prop([p], "")
	edit.tidy_legends()
	for c in edit.zone.prop_legend:
		var used := false
		for row in edit.zone.prop_rows:
			used = used or row.contains(c)
		assert_true(used, "legend letter %s is used" % c)


func test_the_check_finds_a_walled_in_graveyard() -> void:
	assert_eq(Array(ZoneCheck.problems(edit.zone, edit.grid)), [])
	var g: Vector2i = edit.zone.graveyards[0]
	var ring: Array[Vector2i] = []
	for p in edit.brush(g, 3):
		if p != g:
			ring.append(p)
	edit.paint_terrain(ring, "water")
	var problems := ZoneCheck.problems(edit.zone, edit.grid)
	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "graveyard")
