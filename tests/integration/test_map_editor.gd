extends GutTest
## The map editor screen: opens a map with the game's renderer, paints with the
## mouse tools, places and edits things, resizes, links edges, makes maps, undoes,
## warns before saving an unplayable map, and saves (here into a scratch folder,
## never the real files).

var editor: MapEditor
var backup := {}
const SCRATCH := "user://test_map_editor/"


func before_each() -> void:
	backup = {"zones": ContentDB.zones.duplicate(), "quests": ContentDB.quests.duplicate()}
	editor = MapEditor.new()
	editor.saver.redirect = SCRATCH
	add_child(editor)
	await wait_process_frames(2)


func after_each() -> void:
	editor.free()
	ContentDB.zones = backup.zones
	ContentDB.quests = backup.quests
	_remove_dir(ProjectSettings.globalize_path(SCRATCH))


static func _remove_dir(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for d in DirAccess.get_directories_at(dir):
		_remove_dir(dir.path_join(d))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


func _scratch(path: String) -> String:
	return SCRATCH + path.trim_prefix("res://")


func _grass_tile() -> Vector2i:
	for y in range(2, editor.edit.depth() - 2):
		for x in range(2, editor.edit.width() - 2):
			var p := Vector2i(x, y)
			if editor.edit.terrain_at(p) == "grass" and editor.edit.prop_at(p) == "" \
					and editor.edit.zone.decor_at(p) == null and editor.session.grid().is_walkable(p):
				return p
	return Vector2i(-1, -1)


func test_it_opens_millbrook_with_its_people_standing_still() -> void:
	assert_eq(editor.zone_id, &"town")
	assert_true(editor.view.is_built_for(editor.session.grid()))
	assert_gt(editor.session.actors().size(), 0, "enemies and people are shown")
	var where := {}
	for a in editor.session.actors():
		where[a.id] = a.move.pos
	await wait_process_frames(10)
	for a in editor.session.actors():
		assert_eq(a.move.pos, where[a.id], "actor %d stays frozen" % a.id)


func test_painting_ground_with_a_brush_and_undoing_it() -> void:
	var p := _grass_tile()
	editor.terrain = "cobble"
	editor.set_brush(3)
	editor.edit.begin_stroke()
	editor._apply(p, MOUSE_BUTTON_LEFT)
	editor.edit.end_stroke()
	assert_eq(editor.edit.terrain_at(p), "cobble")
	assert_eq(editor.edit.terrain_at(p + Vector2i(1, 1)), "cobble", "3×3 brush")
	assert_true(editor.edit.dirty)
	editor.undo()
	assert_eq(editor.edit.terrain_at(p), "grass")
	editor.redo()
	assert_eq(editor.edit.terrain_at(p), "cobble")


func test_right_click_with_ground_copies_the_tile() -> void:
	var p := _grass_tile()
	editor.terrain = "water"
	editor._apply(p, MOUSE_BUTTON_LEFT) # now water
	editor.terrain = "dirt"
	editor._apply(p, MOUSE_BUTTON_RIGHT)
	assert_eq(editor.terrain, "water", "the eyedropper")


func test_height_tool_raises_once_per_drag_and_lowers() -> void:
	var p := _grass_tile()
	var h := editor.edit.height_at(p)
	editor.set_tool(MapEditor.Tool.HEIGHT)
	editor.edit.begin_stroke()
	editor._apply(p, MOUSE_BUTTON_LEFT)
	editor._apply(p, MOUSE_BUTTON_LEFT) # the mouse wobbles on the same tile
	editor.edit.end_stroke()
	editor._painted = {}
	assert_eq(editor.edit.height_at(p), h + 1, "one level per drag")
	assert_eq(editor.session.grid().height_at(p), h + 1, "the map shown follows")
	editor._apply(p, MOUSE_BUTTON_RIGHT)
	assert_eq(editor.edit.height_at(p), h)
	editor._painted = {}
	editor.exact_height = true
	editor.height_level = 4
	editor._apply(p, MOUSE_BUTTON_LEFT)
	assert_eq(editor.edit.height_at(p), 4)


func test_props_tool_places_and_removes() -> void:
	var p := _grass_tile()
	editor.set_tool(MapEditor.Tool.PROPS)
	editor.prop = "flowers"
	editor._apply(p, MOUSE_BUTTON_LEFT)
	assert_eq(editor.edit.prop_at(p), "flowers")
	editor._painted = {}
	editor._apply(p, MOUSE_BUTTON_RIGHT)
	assert_eq(editor.edit.prop_at(p), "")


func test_saving_writes_the_file_and_the_loaded_game_map() -> void:
	var p := _grass_tile()
	editor.terrain = "cobble"
	editor._apply(p, MOUSE_BUTTON_LEFT)
	assert_eq(editor.problems().size(), 0)
	assert_eq(editor.write(), OK)
	assert_false(editor.edit.dirty)
	var saved: ZoneDef = ResourceLoader.load(_scratch("res://content/zones/town.tres"), "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(saved.terrain_at(p), "cobble")
	assert_eq(ContentDB.zones[&"town"].terrain_at(p), "cobble", "Play uses the new map without a restart")


func test_walling_in_the_graveyard_is_reported_before_saving() -> void:
	var g: Vector2i = editor.edit.zone.graveyards[0]
	editor.terrain = "water"
	editor.set_brush(1)
	for p in editor.edit.brush(g, 3):
		if p != g:
			editor._apply(p, MOUSE_BUTTON_LEFT)
	var found := editor.problems()
	assert_eq(found.size(), 1)
	assert_string_contains(found[0], "graveyard")


func test_switching_maps_with_unsaved_changes_asks_first() -> void:
	editor.terrain = "cobble"
	editor._apply(_grass_tile(), MOUSE_BUTTON_LEFT)
	editor._leaving(func(): editor.open_zone(&"crossing"))
	assert_eq(editor.zone_id, &"town", "waits for the answer")
	assert_true(editor._confirm.visible)
	editor._confirm.confirmed.emit()
	assert_eq(editor.zone_id, &"crossing")
	assert_false(editor.edit.dirty)


func test_every_map_in_the_list_opens() -> void:
	for z: ZoneDef in MapEditor.editable_zones():
		editor.open_zone(z.id)
		await wait_process_frames(1)
		assert_eq(editor.edit.zone.id, z.id)
		assert_eq(Array(editor.problems()), [], "%s starts out playable" % z.id)


func _enemy_actors() -> int:
	var n := 0
	for a in editor.session.actors():
		n += 1 if a is Enemy else 0
	return n


func test_things_tool_places_an_enemy_shown_on_the_map_and_undo_takes_it_back() -> void:
	var before := _enemy_actors()
	editor.set_tool(MapEditor.Tool.THINGS)
	editor.set_thing_kind("enemy")
	editor.thing_what = ContentDB.enemies[&"wolf"]
	var p := _grass_tile()
	editor.place(p)
	assert_eq(_enemy_actors(), before + 1, "the new wolf stands on the map")
	assert_eq(editor.selected.kind, "enemy", "and is selected")
	editor.undo()
	assert_eq(_enemy_actors(), before)
	assert_true(editor.selected.is_empty())


func test_select_drag_moves_a_person_and_delete_removes() -> void:
	editor.set_tool(MapEditor.Tool.SELECT)
	var npc: NpcSpawn = editor.edit.zone.npcs[0]
	var from := npc.tile
	editor.select_at(from)
	assert_eq(editor.selected.kind, "npc")
	var to := _grass_tile()
	editor.move_selected(to)
	assert_eq(editor.edit.thing_tile(editor.selected), to)
	var n := editor.edit.zone.npcs.size()
	editor.remove(editor.selected)
	assert_eq(editor.edit.zone.npcs.size(), n - 1)


func test_clicking_a_tile_twice_cycles_through_what_is_on_it() -> void:
	var p := _grass_tile()
	editor.edit.add_thing("hero_spawn", p)
	editor.edit.add_thing("decor", p, ZoneDecor.Kind.SIGN)
	editor._after_change()
	editor.set_tool(MapEditor.Tool.SELECT)
	editor.select_at(p)
	var first: Dictionary = editor.selected
	editor.select_at(p)
	assert_ne(editor.selected, first)
	editor.select_at(p)
	assert_eq(editor.selected, first)


func test_patrol_mode_adds_and_removes_points() -> void:
	editor.set_tool(MapEditor.Tool.THINGS)
	editor.set_thing_kind("enemy")
	editor.thing_what = ContentDB.enemies[&"wolf"]
	var p := _grass_tile()
	editor.place(p)
	editor.set_tool(MapEditor.Tool.SELECT)
	editor.set_patrol_mode(true)
	assert_true(editor.patrol_mode)
	editor._patrol_click(p + Vector2i(2, 0), MOUSE_BUTTON_LEFT)
	editor._patrol_click(p + Vector2i(2, 2), MOUSE_BUTTON_LEFT)
	var route: Array = editor.edit.thing(editor.selected).patrol
	assert_eq(route, [p, p + Vector2i(2, 0), p + Vector2i(2, 2)], "starts where it stands")
	editor._patrol_click(p + Vector2i(2, 2), MOUSE_BUTTON_RIGHT)
	assert_eq(editor.edit.thing(editor.selected).patrol.size(), 2)


func test_resizing_keeps_the_view_in_step() -> void:
	var w := editor.edit.width()
	editor.resize({Vector2i.LEFT: 2, Vector2i.RIGHT: 3}, "grass", 0)
	assert_eq(editor.edit.width(), w + 5)
	assert_eq(editor.session.grid().width, w + 5, "the map shown was rebuilt")
	assert_true(editor.view.is_built_for(editor.session.grid()))


func test_cutting_off_things_asks_first() -> void:
	var g: Vector2i = editor.edit.zone.graveyards[0]
	editor.resize({Vector2i.LEFT: -(g.x + 1)}, "grass", 0)
	assert_true(editor._confirm.visible, "asks")
	assert_true(editor.edit.zone.graveyards.has(g), "nothing yet")
	editor._confirm.confirmed.emit()
	assert_false(editor.edit.zone.graveyards.has(g))


func test_edge_summary_says_where_the_gate_lands() -> void:
	var e := editor.edit.edge_on(Vector2i.RIGHT)
	assert_not_null(e, "Millbrook's east side leads to Greenfields")
	var text := editor.edge_summary(Vector2i.RIGHT, e.to_zone, e.offset)
	assert_string_contains(text, "Greenfields")
	assert_string_contains(text, "walkable there")


func test_choosing_where_a_door_leads_in_another_map() -> void:
	editor.set_tool(MapEditor.Tool.THINGS)
	editor.set_thing_kind("exit")
	editor.thing_what = &"crossing"
	editor.place(_grass_tile())
	var got := []
	editor.pick_arrival(&"crossing", func(p): got.append(p))
	assert_true(editor.is_picking())
	assert_false(editor.view.visible, "the Crossing is shown instead")
	var to: Vector2i = ContentDB.zones[&"crossing"].hero_spawns[0]
	editor._peek.then.call(to)
	editor._end_peek()
	assert_false(editor.is_picking())
	assert_true(editor.view.visible)
	assert_eq(got, [to])


func test_a_new_map_is_made_saved_and_opened() -> void:
	assert_eq(editor.create_map("Test Hollow", Vector2i(12, 10), "grass", 1, Regions.Id.VAEL,
			MusicTrackDef.Context.EXPLORE), OK)
	assert_eq(editor.zone_id, &"test_hollow")
	assert_eq(editor.edit.size(), Vector2i(12, 10))
	assert_true(FileAccess.file_exists(_scratch("res://content/zones/test_hollow.tres")))
	assert_true(ContentDB.zones.has(&"test_hollow"))
	assert_eq(Array(editor.problems()), [], "a new map is playable")
	assert_eq(editor.create_map("Test Hollow", Vector2i(12, 10), "grass", 0, 0, 1), ERR_ALREADY_EXISTS)
