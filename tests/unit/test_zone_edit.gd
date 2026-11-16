extends GutTest
## The map editor's model (ZoneEdit), its saver (ZoneSaver, writing into a scratch
## folder here) and the checks it runs before saving (ZoneCheck).

var edit: ZoneEdit
var source: ZoneDef
const SCRATCH := "user://zone_edit_test/"
var _backup := {}


func before_each() -> void:
	_backup = {"zones": ContentDB.zones.duplicate(), "quests": ContentDB.quests.duplicate()}
	source = ContentDB.zones[&"town"]
	var copy := ZoneEdit.copy_of(source)
	edit = ZoneEdit.new(copy, ContentDB.tilesets[copy.tileset], GridModel.from_zone(copy))


func after_each() -> void:
	ContentDB.zones = _backup.zones
	ContentDB.quests = _backup.quests
	_remove_dir(ProjectSettings.globalize_path(SCRATCH))


static func _remove_dir(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for d in DirAccess.get_directories_at(dir):
		_remove_dir(dir.path_join(d))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


func _saver() -> ZoneSaver:
	var s := ZoneSaver.new()
	s.redirect = SCRATCH
	return s


func _saved(path: String) -> Resource:
	return ResourceLoader.load(SCRATCH + path.trim_prefix("res://"), "", ResourceLoader.CACHE_MODE_IGNORE)


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


# --- Saving -----------------------------------------------------------------------

func test_saving_an_unchanged_map_keeps_everything() -> void:
	var s := _saver()
	assert_eq(s.save(edit, source.resource_path), OK)
	var back: ZoneDef = _saved(source.resource_path)
	for key in ZoneEdit.ROW_KEYS:
		assert_eq(Array(back.get(key)), Array(edit.zone.get(key)), key)
	assert_eq(back.npcs.size(), source.npcs.size(), "people")
	assert_eq(back.enemy_spawns.size(), source.enemy_spawns.size(), "enemies")
	assert_eq(back.decor.size(), source.decor.size(), "objects")
	assert_eq(back.edges.size(), source.edges.size(), "edges")
	assert_eq(back.enemy_spawns[0].enemy, source.enemy_spawns[0].enemy, "enemies stay links to their files")
	assert_eq(Array(s.written), [source.resource_path], "nothing else was touched")


func test_every_map_saves_and_loads_back_the_same() -> void:
	for z: ZoneDef in MapEditor.editable_zones():
		var e := ZoneEdit.new(ZoneEdit.copy_of(z), ContentDB.tilesets[z.tileset])
		assert_eq(_saver().save(e, z.resource_path), OK)
		var back: ZoneDef = _saved(z.resource_path)
		back.bake_walkability(ContentDB.tilesets[z.tileset])
		assert_eq(ZoneEdit._same(ZoneEdit._plain_zone(back), ZoneEdit._plain_zone(z)), true, "%s" % z.id)


func test_painted_tiles_are_saved() -> void:
	var p := _grass_tile()
	edit.paint_terrain([p], "water")
	edit.change_height([p + Vector2i(1, 0)], 1)
	edit.paint_prop([p + Vector2i(0, 1)], "flowers")
	assert_eq(_saver().save(edit, source.resource_path), OK)
	var back: ZoneDef = _saved(source.resource_path)
	assert_eq(back.terrain_at(p), "water")
	assert_eq(ZoneDef.parse_height(back.height_rows[p.y][p.x + 1]), edit.height_at(p + Vector2i(1, 0)))
	assert_eq(back.prop_at(p + Vector2i(0, 1)), "flowers")
	assert_false(edit.dirty)


# --- Things -----------------------------------------------------------------------

func test_placing_moving_and_removing_an_enemy_undoes() -> void:
	var p := _grass_tile()
	var n := edit.zone.enemy_spawns.size()
	var r := edit.add_thing("enemy", p, ContentDB.enemies[&"wolf"])
	assert_eq(edit.zone.enemy_spawns.size(), n + 1)
	assert_eq(edit.things_at(p)[0], r)
	assert_true(edit.rebuild_needed)
	assert_true(edit.move_thing(r, p + Vector2i(1, 0)))
	assert_eq(edit.thing_tile(r), p + Vector2i(1, 0))
	edit.undo()
	assert_eq(edit.thing_tile(r), p, "moved back")
	edit.undo()
	assert_eq(edit.zone.enemy_spawns.size(), n, "and gone")
	edit.redo()
	assert_eq(edit.zone.enemy_spawns.size(), n + 1)
	assert_true(edit.remove_thing(r))
	assert_eq(edit.zone.enemy_spawns.size(), n)


func test_objects_block_their_tile_and_moving_them_frees_it() -> void:
	var p := _grass_tile()
	var r := edit.add_thing("decor", p, ZoneDecor.Kind.WELL)
	assert_false(edit.is_walkable(p), "a well blocks its tile")
	edit.move_thing(r, p + Vector2i(1, 0))
	assert_true(edit.is_walkable(p))
	assert_false(edit.is_walkable(p + Vector2i(1, 0)))


func test_a_person_already_here_moves_instead_of_doubling() -> void:
	var hilda: NpcDef = ContentDB.npcs[&"hilda"]
	var n := edit.zone.npcs.size()
	var p := _grass_tile()
	edit.add_thing("npc", p, hilda)
	assert_eq(edit.zone.npcs.size(), n)
	var found := false
	for s in edit.zone.npcs:
		found = found or (s.npc == hilda and s.tile == p)
	assert_true(found)


func test_a_person_placed_here_leaves_the_other_map_when_saved() -> void:
	var crossing: ZoneDef = ContentDB.zones[&"crossing"]
	var someone: NpcDef = crossing.npcs[0].npc
	edit.add_thing("npc", _grass_tile(), someone)
	var s := _saver()
	assert_eq(s.save(edit, source.resource_path), OK)
	var other: ZoneDef = _saved(_backup.zones[&"crossing"].resource_path)
	for n in other.npcs:
		assert_ne(n.npc.id, someone.id, "%s is no longer in the Crossing" % someone.display_name)
	assert_eq(other.npcs.size(), crossing.npcs.size() - 1)
	assert_gt(s.notes.size(), 0)


func test_settings_and_patrols() -> void:
	var r := edit.add_thing("enemy", _grass_tile(), ContentDB.enemies[&"wolf"])
	edit.set_thing(r, {"level": 4, "respawn_seconds": 12.0})
	assert_eq(edit.thing(r).level, 4)
	var p := edit.thing_tile(r)
	edit.set_patrol(r, [p, p + Vector2i(2, 0)])
	assert_eq(edit.thing(r).patrol.size(), 2)
	edit.move_thing(r, p + Vector2i(0, 1))
	assert_eq(edit.thing(r).patrol[1], p + Vector2i(2, 1), "the route moves with it")
	edit.undo()
	edit.undo()
	assert_eq(edit.thing(r).patrol.size(), 0)


func test_hero_spawns_and_graveyards_are_tiles() -> void:
	var p := _grass_tile()
	var r := edit.add_thing("graveyard", p)
	assert_true(edit.zone.graveyards.has(p))
	edit.move_thing(r, p + Vector2i(1, 0))
	assert_true(edit.zone.graveyards.has(p + Vector2i(1, 0)))
	assert_false(edit.zone.graveyards.has(p))


# --- Size --------------------------------------------------------------------------

func test_growing_north_west_moves_everything_with_the_ground() -> void:
	var w := edit.width()
	var d := edit.depth()
	var spawn: Vector2i = edit.zone.hero_spawns[0]
	var t := edit.terrain_at(spawn)
	assert_true(edit.resize({Vector2i.LEFT: 3, Vector2i.UP: 2, Vector2i.RIGHT: 1}, "grass", 0))
	assert_eq(edit.size(), Vector2i(w + 4, d + 2))
	assert_eq(edit.zone.hero_spawns[0], spawn + Vector2i(3, 2))
	assert_eq(edit.terrain_at(spawn + Vector2i(3, 2)), t, "the ground moved too")
	assert_eq(edit.terrain_at(Vector2i(0, 0)), "grass", "new ground")
	assert_eq(edit.shift, Vector2i(3, 2))
	assert_eq(Array(ZoneCheck.problems(edit.zone, GridModel.from_zone(edit.zone))), [])
	edit.undo()
	assert_eq(edit.size(), Vector2i(w, d))
	assert_eq(edit.zone.hero_spawns[0], spawn)


func test_shrinking_reports_and_removes_what_is_cut_off() -> void:
	var g: Vector2i = edit.zone.graveyards[0]
	var cut := {Vector2i.LEFT: -(g.x + 1)}
	var losses := edit.resize_losses(cut)
	var listed := false
	for l in losses:
		listed = listed or l.begins_with("Graveyard")
	assert_true(listed, "the graveyard is listed")
	edit.resize(cut, "grass", 0)
	assert_false(edit.zone.graveyards.has(g))
	assert_false(edit.resize({Vector2i.LEFT: -edit.width()}, "grass", 0), "at least 4×4")


func test_a_resize_moves_quests_doors_and_edges_in_other_files() -> void:
	# Deepcut: quests have places there, the Road links to it, the shaft's door leads to it.
	var deepcut: ZoneDef = ContentDB.zones[&"deepcut"]
	var e := ZoneEdit.new(ZoneEdit.copy_of(deepcut), ContentDB.tilesets[deepcut.tileset])
	e.resize({Vector2i.LEFT: 2, Vector2i.UP: 1}, "grass", 0)
	var s := _saver()
	assert_eq(s.save(e, deepcut.resource_path), OK)
	assert_eq(e.saved_shift, Vector2i(2, 1))
	var quests := 0
	for q: QuestDef in _backup.quests.values():
		for i in q.objectives.size():
			var o: QuestObjective = q.objectives[i]
			if o.zone != &"deepcut":
				continue
			var back: QuestDef = _saved(q.resource_path) if FileAccess.file_exists(SCRATCH + q.resource_path.trim_prefix("res://")) else null
			assert_not_null(back, "%s was rewritten" % q.id)
			if back != null:
				assert_eq(back.objectives[i].tile, o.tile + Vector2i(2, 1))
				for j in o.spots.size():
					assert_eq(back.objectives[i].spots[j], o.spots[j] + Vector2i(2, 1))
				for j in o.path.size():
					assert_eq(back.objectives[i].path[j], o.path[j] + Vector2i(2, 1))
				quests += 1
	assert_gt(quests, 0, "some quest has places in Deepcut")
	var shaft: ZoneDef = _saved(_backup.zones[&"silent_shaft"].resource_path)
	for x in shaft.exits:
		if x.to_zone == &"deepcut":
			var was: ZoneExit
			for y in _backup.zones[&"silent_shaft"].exits:
				if y.tile == x.tile:
					was = y
			assert_eq(x.to_tile, was.to_tile + Vector2i(2, 1), "the shaft's way out still lands in the same place")
	var road: ZoneDef = _saved(_backup.zones[&"deepcut_road"].resource_path)
	for edge in road.edges:
		if edge.to_zone == &"deepcut":
			for mine in e.zone.edges:
				if mine.to_zone == &"deepcut_road":
					assert_eq(edge.offset, -mine.offset, "the Road's edge matches")
	assert_eq(Array(ZoneCheck.link_problems(e.zone, ContentDB.zones)), [], "links still line up")


# --- Edges and doors -----------------------------------------------------------------

func test_linking_an_edge_writes_the_other_side_too() -> void:
	var side := Vector2i.LEFT
	edit.set_edge(side, &"windsteppe", 3)
	assert_eq(edit.edge_on(side).to_zone, &"windsteppe")
	assert_eq(_saver().save(edit, source.resource_path), OK)
	var steppe: ZoneDef = _saved(_backup.zones[&"windsteppe"].resource_path)
	var found := false
	for e in steppe.edges:
		if e.to_zone == &"town":
			found = e.side == Vector2i.RIGHT and e.offset == -3
	assert_true(found, "the Windsteppe's east side leads back with the opposite offset")
	edit.set_edge(side, &"", 0)
	assert_null(edit.edge_on(side))
	assert_eq(_saver().save(edit, source.resource_path), OK)
	steppe = _saved(_backup.zones[&"windsteppe"].resource_path)
	for e in steppe.edges:
		assert_ne(e.to_zone, &"town", "unlinked on both sides")


func test_a_door_onto_a_blocked_tile_is_reported() -> void:
	var p := _grass_tile()
	var r := edit.add_thing("exit", p, &"crossing")
	edit.set_thing(r, {"to_tile": Vector2i(0, 0)})
	var found := ZoneCheck.link_problems(edit.zone)
	assert_gt(found.size(), 0)
	assert_string_contains(found[0], "can't stand on")


func test_removing_a_quest_giver_is_reported() -> void:
	var giver := ""
	for i in edit.zone.npcs.size():
		for q: QuestDef in ContentDB.quests.values():
			if q.giver == edit.zone.npcs[i].npc.id:
				giver = edit.zone.npcs[i].npc.display_name
				edit.remove_thing(ZoneEdit.ref("npc", i))
				break
		if giver != "":
			break
	assert_ne(giver, "", "Millbrook has a quest giver")
	var found := ZoneCheck.story_problems(edit.zone)
	assert_gt(found.size(), 0)
	assert_string_contains(" ".join(found), giver)
