extends GutTest
## The map editor screen: opens a map with the game's renderer, paints with the
## mouse tools, undoes, warns before saving an unplayable map, and saves (here
## into a scratch copy of the zone file, never the real one).

var editor: MapEditor
var backup := {}
const SCRATCH := "user://test_map_editor_town.tres"


func before_each() -> void:
	var town: ZoneDef = ContentDB.zones[&"town"]
	backup = {}
	for key in ZoneFile.ROW_KEYS:
		backup[key] = PackedStringArray(Array(town.get(key)))
	backup.terrain_legend = town.terrain_legend.duplicate()
	backup.prop_legend = town.prop_legend.duplicate()
	var f := FileAccess.open(SCRATCH, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(town.resource_path))
	f.close()
	editor = MapEditor.new()
	add_child(editor)
	editor.save_path_override = SCRATCH
	await wait_process_frames(2)


func after_each() -> void:
	editor.free()
	var town: ZoneDef = ContentDB.zones[&"town"]
	for key in backup:
		town.set(key, backup[key])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))


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
	var saved: ZoneDef = ResourceLoader.load(SCRATCH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(saved.terrain_at(p), "cobble")
	assert_eq(ContentDB.zones[&"town"].terrain_at(p), "cobble", "Play uses the new map without a restart")
	assert_eq(FileAccess.get_file_as_string(ContentDB.zones[&"town"].resource_path).length() > 0, true)


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
