class_name MapEditor
extends Node
## The map editor screen (main menu → Map Editor, when the game runs from the
## Godot editor). Paints a tiled zone's ground, heights and props; places, moves and
## edits its enemies, people, spawn points, graveyards, objects, landmarks and doors;
## resizes it; links its edges to other maps; makes new maps. Shows the result with
## the game's own renderer and saves with ZoneSaver (the map and every file the
## change reaches). Enemies and people stand frozen where they spawn.

signal closed

enum Tool { GROUND, HEIGHT, PROPS, PICK, THINGS, SELECT }

const TOOL_NAMES := ["Ground", "Height", "Props", "Pick", "Things", "Select"]
const BRUSH_SIZES := [1, 3, 5]
const PAN_SPEED := 900.0 # world units per second at zoom 1
const HELP := {
	Tool.GROUND: "Left: paint the chosen ground\nRight: copy the ground under the mouse",
	Tool.HEIGHT: "Left: raise one level\nRight: lower one level\n(or tick \"Exact level\" and paint it)",
	Tool.PROPS: "Left: place the chosen prop\nRight: remove props",
	Tool.PICK: "Left: copy the tile under the mouse\n(its ground, height and prop)",
	Tool.THINGS: "Left: place the chosen thing\nRight: remove the thing under the mouse",
	Tool.SELECT: "Left: select a thing (click again for the next one on that tile)\nDrag: move it   Delete: remove it\nRight: select nothing",
}
const KEYS_HELP := "WASD / arrows or middle-drag: move   Wheel: zoom\n1-6: tools   [ ]: brush size   Ctrl+Z / Ctrl+Y: undo / redo   Ctrl+S: save"
## Things the Things tool places: kind -> label.
const CATEGORIES := [
	["enemy", "Enemies"], ["npc", "People"], ["hero_spawn", "Hero spawn point"],
	["graveyard", "Graveyard"], ["decor", "Objects"], ["landmark", "Landmark"], ["exit", "Doors"],
]
const FACINGS := {"Down": Vector2i.DOWN, "Up": Vector2i.UP, "Left": Vector2i.LEFT, "Right": Vector2i.RIGHT}
const MUSIC_CHOICES := ["TOWN", "EXPLORE", "DUNGEON"]

## The zone being edited (its id in ContentDB.zones) and the editing model.
var zone_id: StringName = &""
var zone_path := ""
var edit: ZoneEdit
var session: EditorSession
var view: WorldView
var client := ClientState.new()
var saver := ZoneSaver.new()

var tool := Tool.GROUND
var brush_size := 1
var terrain := "grass"
var prop := ""
var exact_height := false
var height_level := 1
var show_grid := false
var show_heights := false
## Things tool: what it places. `thing_kind` is a CATEGORIES kind; `thing_what` the
## EnemyDef / NpcDef / ZoneDecor.Kind / destination zone id it places.
var thing_kind := "enemy"
var thing_what: Variant = null
## Select tool: the selected thing ({} for none) and whether clicks edit its patrol.
var selected := {}
var patrol_mode := false

var _cam_target := Vector2.ZERO
var _painting := MOUSE_BUTTON_NONE
var _painted := {} # tiles already changed in this drag (a drag raises each tile once)
var _hover: Variant = null
var _drag_from: Variant = null
## Choosing where a door leads in another map: {"session", "view", "target", "then"}.
var _peek := {}

# UI
var _ui: CanvasLayer
var _maps: OptionButton
var _status: Label
var _palette: ItemList
var _palette_ids: Array = []
var _height_box: VBoxContainer
var _brush_row: HBoxContainer
var _things_box: VBoxContainer
var _category: OptionButton
var _props_box: VBoxContainer
var _exact: CheckBox
var _level: SpinBox
var _help: Label
var _tool_buttons: Array[Button] = []
var _brush_buttons: Array[Button] = []
var _save_button: Button
var _undo_button: Button
var _redo_button: Button
var _confirm: ConfirmationDialog
var _confirm_action := Callable()
var _overlay: EditorOverlay
var _message := ""
var _size_dialog: ConfirmationDialog
var _links_dialog: ConfirmationDialog
var _new_dialog: ConfirmationDialog


## Saving rewrites the game's own files: only while running from the Godot editor.
static func can_save() -> bool:
	return OS.has_feature("editor")


## Zones the editor can open: tiled maps stored in a file (not generated ones).
static func editable_zones() -> Array:
	var out := []
	for z: ZoneDef in ContentDB.zones.values():
		if z.has_terrain() and not z.enemy_pens and z.resource_path != "":
			out.append(z)
	out.sort_custom(func(a, b): return a.display_name < b.display_name)
	return out


## Every map a door or edge can lead to (the testing grounds too).
static func all_zone_ids() -> Array:
	var ids := ContentDB.zones.keys()
	ids.sort_custom(func(a, b): return ZoneEdit.zone_name(a) < ZoneEdit.zone_name(b))
	return ids


static func path_of(id: StringName) -> String:
	var z: ZoneDef = ContentDB.zones.get(id)
	if z != null and z.resource_path.begins_with("res://"):
		return z.resource_path
	return ZoneSaver.ZONES_DIR + "%s.tres" % id


func _ready() -> void:
	_build_ui()
	var zones := editable_zones()
	var first: StringName = &"town" if ContentDB.zones.has(&"town") else zones[0].id
	open_zone(first)


# --- Opening a map --------------------------------------------------------------

func open_zone(id: StringName) -> void:
	_end_peek()
	zone_id = id
	zone_path = path_of(id)
	_hover = null
	_painting = MOUSE_BUTTON_NONE
	_painted = {}
	selected = {}
	patrol_mode = false
	var copy := ZoneEdit.load_working(saver._target(zone_path) if saver.redirect != "" and FileAccess.file_exists(saver._target(zone_path)) else zone_path,
			ContentDB.tilesets.get(ContentDB.zones[id].tileset))
	edit = ZoneEdit.new(copy, ContentDB.tilesets[copy.tileset])
	var center := Vector2i(edit.width() / 2, edit.depth() / 2)
	_cam_target = Iso.to_screen(Vector2(center), edit.height_at(center))
	_rebuild_view()
	_refresh_maps()
	_message = "Opened %s." % copy.display_name
	_fill_palette()
	_show_props()
	_refresh_status()


## A fresh session and view of the zone being edited (after things, size or links
## changed), keeping the camera where it was.
func _rebuild_view() -> void:
	if view != null:
		view.queue_free()
	if session != null:
		session.queue_free()
	session = EditorSession.new()
	session.name = "EditorSession"
	add_child(session)
	session.start(edit.zone, ContentDB.rules)
	edit.grid = session.grid()
	edit.rebuild_needed = false
	view = WorldView.new()
	view.name = "WorldView"
	add_child(view)
	move_child(view, 0)
	view.setup(session, client, edit.zone)
	_overlay = EditorOverlay.new()
	_overlay.editor = self
	_overlay.z_index = 50
	view.add_child(_overlay)
	view.camera.make_current()
	view.camera.follow(_cam_target, 0.0, true)
	client.aim = {}


## After any step: rebuild the view if the step needs it, keep the selection valid.
func _after_change() -> void:
	if edit.rebuild_needed:
		_rebuild_view()
	if not selected.is_empty() and edit.thing(selected) == null:
		selected = {}
		patrol_mode = false
	_show_props()
	_refresh_status()


# --- Frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if view == null:
		return
	var pan := Vector2.ZERO
	if not _typing():
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			pan.x -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			pan.x += 1
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			pan.y -= 1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			pan.y += 1
	var active := _active_view()
	if pan != Vector2.ZERO and not Input.is_key_pressed(KEY_CTRL):
		_move_camera(pan.normalized() * PAN_SPEED * delta / maxf(active.camera.zoom.x, 0.1))
	active.camera.follow(_peek.target if not _peek.is_empty() else _cam_target, delta, true)
	# A drag let go over a panel: the panel took the release.
	if _painting != MOUSE_BUTTON_NONE and not Input.is_mouse_button_pressed(_painting):
		_finish_stroke()
	_update_hover()
	_overlay.queue_redraw()


func _active_view() -> WorldView:
	return _peek.view if not _peek.is_empty() else view


func _move_camera(by: Vector2) -> void:
	if not _peek.is_empty():
		_peek.target += by
	else:
		_cam_target += by


func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is SpinBox


func _update_hover() -> void:
	var t: Variant = null
	var active := _active_view()
	if not _mouse_over_ui():
		t = active.tile_at(active.get_global_mouse_position())
	if t != _hover:
		_hover = t
		if _hover != null and _painting != MOUSE_BUTTON_NONE and _peek.is_empty() and _paints():
			_apply(_hover, _painting)
		_refresh_status()
	if _hover == null:
		client.aim = {}
	else:
		var tiles: Array[Vector2i] = [_hover]
		if _paints() and _peek.is_empty():
			tiles = edit.brush(_hover, brush_size)
		client.aim = {"tiles": tiles, "valid": true}


## The current tool paints tiles (drags over many).
func _paints() -> bool:
	return tool == Tool.GROUND or tool == Tool.HEIGHT or tool == Tool.PROPS


func _mouse_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null


# --- Input ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if view == null:
		return
	if event is InputEventMouseButton:
		var b: int = event.button_index
		if b == MOUSE_BUTTON_LEFT or b == MOUSE_BUTTON_RIGHT:
			var active := _active_view()
			var tile: Variant = active.tile_at(active.get_global_mouse_position())
			if not _peek.is_empty():
				if event.pressed and tile != null:
					if b == MOUSE_BUTTON_LEFT:
						var then: Callable = _peek.then
						_end_peek()
						then.call(tile)
					else:
						_end_peek()
						_message = "Cancelled."
						_refresh_status()
			elif event.pressed and _painting == MOUSE_BUTTON_NONE:
				_press(tile, b)
			elif not event.pressed and b == _painting:
				_release(tile)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
		_move_camera(-event.relative / maxf(_active_view().camera.zoom.x, 0.1))
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if _shortcut(event):
			get_viewport().set_input_as_handled()


func _press(tile: Variant, button: int) -> void:
	_painting = button
	_painted = {}
	_drag_from = null
	if _paints():
		edit.begin_stroke()
	_hover = tile
	if tile == null:
		return
	if _paints() or tool == Tool.PICK:
		_apply(tile, button)
	elif tool == Tool.THINGS:
		if button == MOUSE_BUTTON_LEFT:
			place(tile)
		else:
			var here := edit.things_at(tile)
			if not here.is_empty():
				remove(here[0])
	elif tool == Tool.SELECT:
		if patrol_mode and not selected.is_empty():
			_patrol_click(tile, button)
		elif button == MOUSE_BUTTON_LEFT:
			select_at(tile)
			_drag_from = tile if not selected.is_empty() else null
		else:
			select({})


func _release(tile: Variant) -> void:
	if tool == Tool.SELECT and _drag_from != null and tile != null and tile != _drag_from \
			and not selected.is_empty():
		move_selected(tile)
	_finish_stroke()


func _finish_stroke() -> void:
	if _painting == MOUSE_BUTTON_NONE:
		return
	_painting = MOUSE_BUTTON_NONE
	_painted = {}
	_drag_from = null
	if _paints():
		edit.end_stroke()
	_refresh_status()


func _shortcut(event: InputEventKey) -> bool:
	if _typing():
		return false
	var ctrl := event.ctrl_pressed or event.meta_pressed
	match event.physical_keycode:
		KEY_Z when ctrl and event.shift_pressed:
			redo()
		KEY_Z when ctrl:
			undo()
		KEY_Y when ctrl:
			redo()
		KEY_S when ctrl:
			save()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6 when not ctrl:
			set_tool(event.physical_keycode - KEY_1)
		KEY_BRACKETLEFT:
			set_brush(BRUSH_SIZES[maxi(BRUSH_SIZES.find(brush_size) - 1, 0)])
		KEY_BRACKETRIGHT:
			set_brush(BRUSH_SIZES[mini(BRUSH_SIZES.find(brush_size) + 1, BRUSH_SIZES.size() - 1)])
		KEY_DELETE, KEY_BACKSPACE:
			if selected.is_empty():
				return false
			remove(selected)
		KEY_ESCAPE:
			if not _peek.is_empty():
				_end_peek()
			elif patrol_mode:
				set_patrol_mode(false)
			else:
				select({})
		_:
			return false
	return true


# --- Painting tools ---------------------------------------------------------------------

## Uses a painting tool (or Pick) on `tile` with a mouse button.
func _apply(tile: Vector2i, button: int) -> void:
	if tool == Tool.PICK or (tool == Tool.GROUND and button == MOUSE_BUTTON_RIGHT):
		pick_from(tile)
		return
	var tiles: Array = []
	for p in edit.brush(tile, brush_size):
		if not _painted.has(p):
			_painted[p] = true
			tiles.append(p)
	var changed: Array[Vector2i] = []
	match tool:
		Tool.GROUND:
			changed = edit.paint_terrain(tiles, terrain)
		Tool.HEIGHT:
			if exact_height and button == MOUSE_BUTTON_LEFT:
				changed = edit.set_height(tiles, height_level)
			else:
				changed = edit.change_height(tiles, 1 if button == MOUSE_BUTTON_LEFT else -1)
		Tool.PROPS:
			changed = edit.paint_prop(tiles, prop if button == MOUSE_BUTTON_LEFT else "")
	if not changed.is_empty():
		view.refresh_tiles(changed)
		_message = ""
		_refresh_status()


## The eyedropper: the tile's ground, height and prop become the selections.
func pick_from(tile: Vector2i) -> void:
	var got := edit.pick(tile)
	terrain = got.terrain
	height_level = got.height
	if got.prop != "":
		prop = got.prop
	_level.set_value_no_signal(height_level)
	_message = "Copied: %s, height %d%s." % [ZoneEdit.pretty(terrain), height_level,
			", " + ZoneEdit.pretty(got.prop) if got.prop != "" else ""]
	if tool == Tool.PICK:
		set_tool(Tool.GROUND)
	else:
		_fill_palette()
		_refresh_status()


func set_tool(t: int) -> void:
	tool = clampi(t, 0, Tool.size() - 1) as Tool
	for i in _tool_buttons.size():
		_tool_buttons[i].set_pressed_no_signal(i == tool)
	if tool != Tool.SELECT:
		patrol_mode = false
	_fill_palette()
	_show_props()
	_refresh_status()


func set_brush(size: int) -> void:
	brush_size = size
	for i in _brush_buttons.size():
		_brush_buttons[i].set_pressed_no_signal(BRUSH_SIZES[i] == size)


func undo() -> void:
	var could := edit.can_undo()
	var tiles := edit.undo()
	view.refresh_tiles(tiles)
	_message = "Undone." if could else "Nothing to undo."
	_after_change()


func redo() -> void:
	var could := edit.can_redo()
	var tiles := edit.redo()
	view.refresh_tiles(tiles)
	_message = "Redone." if could else "Nothing to redo."
	_after_change()


# --- Things --------------------------------------------------------------------------------

func set_thing_kind(kind: String) -> void:
	thing_kind = kind
	thing_what = null
	_fill_palette()


## Places what the Things tool holds on `tile`, then selects it.
func place(tile: Vector2i) -> void:
	if thing_kind in ["enemy", "npc", "decor", "exit"] and thing_what == null:
		_message = "Choose what to place in the list first."
		_refresh_status()
		return
	var what: Variant = thing_what
	if thing_kind == "exit" and str(what) == "":
		what = null
	var was_elsewhere := ""
	if thing_kind == "npc":
		was_elsewhere = ZoneEdit.placements(zone_id).get(what.id, "")
	var r := edit.add_thing(thing_kind, tile, what)
	if r.is_empty():
		return
	selected = r
	_message = "Placed %s." % edit.describe(r)
	if was_elsewhere != "":
		_message += " Saving moves %s here from %s." % [what.display_name, ZoneEdit.zone_name(was_elsewhere)]
	_after_change()
	_fill_palette()


func remove(r: Dictionary) -> void:
	var name := edit.describe(r)
	if edit.remove_thing(r):
		if selected == r:
			selected = {}
		elif not selected.is_empty() and selected.kind == r.kind and selected.index > r.index:
			selected.index -= 1
		_message = "Removed %s." % name
		_after_change()
		_fill_palette()


func select(r: Dictionary) -> void:
	selected = r
	patrol_mode = false
	_show_props()
	_refresh_status()


## Selects the thing on `tile` (the next one if it's already selected), or the person
## or enemy drawn under the mouse.
func select_at(tile: Vector2i) -> void:
	var here := edit.things_at(tile)
	if here.is_empty():
		var actor: Actor = view.actor_at(view.get_global_mouse_position())
		if actor != null:
			here = edit.things_at(actor.tile())
	if here.is_empty():
		select({})
		return
	var i := here.find(selected)
	select(here[(i + 1) % here.size()])


func move_selected(tile: Vector2i) -> void:
	if edit.move_thing(selected, tile):
		_message = "Moved %s to (%d, %d)." % [edit.describe(selected), tile.x, tile.y]
		_after_change()


func set_patrol_mode(on: bool) -> void:
	patrol_mode = on and not selected.is_empty() and selected.kind == "enemy"
	_show_props()
	_refresh_status()


func _patrol_click(tile: Vector2i, button: int) -> void:
	var route: Array = edit.thing(selected).patrol.duplicate()
	if button == MOUSE_BUTTON_LEFT:
		if route.is_empty():
			route.append(edit.thing_tile(selected)) # the walk starts where it stands
		route.append(tile)
	else:
		var at := route.rfind(tile)
		if at == -1:
			return
		route.remove_at(at)
		if route.size() == 1:
			route.clear()
	edit.set_patrol(selected, route)
	_after_change()


## Sets properties of the selected thing (see ZoneEdit.set_thing).
func set_selected(values: Dictionary) -> void:
	if selected.is_empty():
		return
	edit.set_thing(selected, values)
	_after_change()
	_fill_palette()


# --- Doors: choosing where they lead --------------------------------------------------

## Shows map `id` (read only) and calls `then` with the tile clicked there; this map
## itself just waits for a click.
func pick_arrival(id: StringName, then: Callable) -> void:
	_end_peek()
	if id == &"" or id == zone_id:
		_peek = {"view": view, "then": then, "target": _cam_target, "own": true}
		_message = "Click where the lift leads on this map (right-click or Esc to cancel)."
		_refresh_status()
		return
	var dest: ZoneDef = ContentDB.zones[id]
	var s := EditorSession.new()
	add_child(s)
	s.start(dest, ContentDB.rules)
	var v := WorldView.new()
	add_child(v)
	move_child(v, 0)
	v.setup(s, client, dest)
	view.visible = false
	v.camera.make_current()
	var center := Vector2i(dest.get_width() / 2, dest.get_depth() / 2)
	var target := Iso.to_screen(Vector2(center), s.grid().height_at(center))
	_peek = {"session": s, "view": v, "then": then, "target": target}
	_message = "Click where the door leads in %s (right-click or Esc to cancel)." % dest.display_name
	_refresh_status()


func _end_peek() -> void:
	if _peek.is_empty():
		return
	if not _peek.has("own"):
		_peek.view.queue_free()
		_peek.session.queue_free()
		view.visible = true
		view.camera.make_current()
	_peek = {}
	client.aim = {}


func is_picking() -> bool:
	return not _peek.is_empty()


# --- Map size, links, new maps ------------------------------------------------------------

## Resizes the map (see ZoneEdit.resize), asking first if things would be cut off.
func resize(grow: Dictionary, fill: String, fill_height: int) -> void:
	var losses := edit.resize_losses(grow)
	var by := Vector2(int(grow.get(Vector2i.LEFT, 0)), int(grow.get(Vector2i.UP, 0)))
	var apply := func():
		if edit.resize(grow, fill, fill_height):
			_cam_target += Iso.to_screen(by, 0) - Iso.to_screen(Vector2.ZERO, 0) # stay over the same ground
			_message = "The map is now %d × %d." % [edit.width(), edit.depth()]
		else:
			_message = "A map must stay at least 4 × 4."
		_after_change()
	if losses.is_empty():
		apply.call()
	else:
		_ask("Resizing removes:\n\n• %s\n\nGo ahead?" % "\n• ".join(losses), apply)


func set_edge(side: Vector2i, to_zone: StringName, offset: int) -> void:
	edit.set_edge(side, to_zone, offset)
	_after_change()


## Makes a new map file, adds it to the game and opens it. Returns OK or an error.
func create_map(display_name: String, size: Vector2i, ground: String, ground_height: int,
		region: int, music: int) -> Error:
	var id := StringName(display_name.strip_edges().to_snake_case().replace(" ", "_").replace("'", ""))
	if String(id) == "" or ContentDB.zones.has(id):
		_message = "A map called %s already exists." % display_name if String(id) != "" else "Give the map a name."
		_refresh_status()
		return ERR_ALREADY_EXISTS
	var ts_id: StringName = edit.zone.tileset if edit != null else &"iso_basic"
	var ts: TilesetData = ContentDB.tilesets[ts_id]
	var z := ZoneDef.new()
	z.id = id
	z.display_name = display_name.strip_edges()
	z.tileset = ts_id
	z.terrain_legend = {"a": ground}
	z.prop_legend = {}
	var hc := ZoneDef.HEIGHT_CHARS[clampi(ground_height, 0, ZoneEdit.MAX_HEIGHT)]
	for y in size.y:
		z.terrain_rows.append("a".repeat(size.x))
		z.height_rows.append(hc.repeat(size.x))
		z.prop_rows.append(".".repeat(size.x))
	z.bake_walkability(ts)
	var c := size / 2
	var spawns: Array[Vector2i] = [c]
	var graves: Array[Vector2i] = [c + Vector2i(2, 0)]
	z.hero_spawns = spawns
	z.graveyards = graves
	z.region = region as Regions.Id
	z.music_context = music as MusicTrackDef.Context
	var path := ZoneSaver.ZONES_DIR + "%s.tres" % id
	var err := saver._write(z, path)
	if err != OK:
		_message = "Could not create %s (%s)." % [path, error_string(err)]
		_refresh_status()
		return err
	saver.refresh_game(PackedStringArray([path]))
	if saver.redirect == "":
		AudioSpecWriter.write(ContentDB, Audio.config) # the new map's ambience key
	_refresh_maps()
	open_zone(id)
	_message = "Created %s (%d × %d). Link it to another map in Connections." % [z.display_name, size.x, size.y]
	_refresh_status()
	return OK


# --- Saving ---------------------------------------------------------------------------------

## Problems that would make the map hard to play (empty: none).
func problems() -> PackedStringArray:
	var out := edit.zone.validate_terrain(edit.tileset)
	out.append_array(ZoneCheck.problems(edit.zone, session.grid()))
	out.append_array(ZoneCheck.link_problems(edit.zone))
	out.append_array(ZoneCheck.story_problems(edit.zone))
	return out


## Saves, asking first if the check found problems.
func save() -> void:
	if not can_save():
		_message = "Saving only works when the game runs from the Godot editor."
		_refresh_status()
		return
	var found := problems()
	if found.is_empty():
		write()
		return
	_ask("These would make the map hard to play:\n\n• %s\n\nSave anyway?" % "\n• ".join(found), write)


## Writes the map (and the files the change reaches) and refreshes the game's copies.
func write() -> Error:
	var err := saver.save(edit, zone_path)
	if err != OK:
		_message = "Could not save %s (%s)." % [zone_path, error_string(err)]
		_refresh_status()
		return err
	_message = "Saved %s." % ", ".join(Array(saver.written).map(func(p): return p.get_file()))
	if not saver.notes.is_empty():
		_message += " " + " ".join(saver.notes)
	_refresh_maps()
	_fill_palette()
	_refresh_status()
	return OK


func _ask(text: String, then: Callable) -> void:
	_confirm.dialog_text = text
	_confirm_action = then
	_confirm.popup_centered(Vector2i(560, 0))


## Leaves (or switches map) now, or after asking if there are unsaved changes.
func _leaving(then: Callable) -> void:
	if edit != null and edit.dirty:
		_ask("You have unsaved changes to %s. Leave without saving?" % edit.zone.display_name, then)
	else:
		then.call()


func close() -> void:
	_leaving(func(): closed.emit())


# --- UI ----------------------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)

	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_ui.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	top.add_child(bar)
	var map_label := Label.new()
	map_label.text = "Map"
	bar.add_child(map_label)
	_maps = OptionButton.new()
	_maps.item_selected.connect(func(i):
		var id: StringName = _maps.get_item_metadata(i)
		if id == zone_id:
			return
		_leaving(func(): open_zone(id))
		_refresh_maps()) # until the answer: show the map that is still open
	bar.add_child(_maps)
	_button(bar, "New map", _open_new_dialog)
	_button(bar, "Map size", _open_size_dialog)
	_button(bar, "Connections", _open_links_dialog)
	_undo_button = _button(bar, "Undo", undo)
	_redo_button = _button(bar, "Redo", redo)
	_save_button = _button(bar, "Save", save)
	_save_button.disabled = not can_save()
	if not can_save():
		_save_button.tooltip_text = "Saving only works when the game runs from the Godot editor."
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.clip_text = true
	bar.add_child(_status)
	_button(bar, "Back to menu", close)

	var side := PanelContainer.new()
	side.anchor_top = 0.0
	side.anchor_bottom = 1.0
	side.offset_top = 44
	side.offset_bottom = -8
	side.offset_left = 8
	side.offset_right = 288
	_ui.add_child(side)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	side.add_child(col)
	var tool_group := ButtonGroup.new()
	for row_tools in [[0, 1, 2], [3, 4, 5]]:
		var row := HBoxContainer.new()
		for i in row_tools:
			var b := _button(row, "%d %s" % [i + 1, TOOL_NAMES[i]], set_tool.bind(i))
			b.toggle_mode = true
			b.button_group = tool_group
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_tool_buttons.append(b)
		col.add_child(row)
	_brush_row = HBoxContainer.new()
	var brush_label := Label.new()
	brush_label.text = "Brush"
	_brush_row.add_child(brush_label)
	var brush_group := ButtonGroup.new()
	for s in BRUSH_SIZES:
		var b := _button(_brush_row, "%d×%d" % [s, s], set_brush.bind(s))
		b.toggle_mode = true
		b.button_group = brush_group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_brush_buttons.append(b)
	col.add_child(_brush_row)

	_height_box = VBoxContainer.new()
	_exact = CheckBox.new()
	_exact.text = "Exact level (paint this height)"
	_exact.toggled.connect(func(on): exact_height = on)
	_height_box.add_child(_exact)
	var level_row := HBoxContainer.new()
	var level_label := Label.new()
	level_label.text = "Level"
	level_row.add_child(level_label)
	_level = SpinBox.new()
	_level.min_value = 0
	_level.max_value = ZoneEdit.MAX_HEIGHT
	_level.value = height_level
	_level.value_changed.connect(func(v):
		height_level = int(v)
		exact_height = true
		_exact.set_pressed_no_signal(true))
	level_row.add_child(_level)
	_height_box.add_child(level_row)
	col.add_child(_height_box)

	_things_box = VBoxContainer.new()
	_category = OptionButton.new()
	for c in CATEGORIES:
		_category.add_item(c[1])
	_category.item_selected.connect(func(i): set_thing_kind(CATEGORIES[i][0]))
	_things_box.add_child(_category)
	col.add_child(_things_box)

	_palette = ItemList.new()
	_palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_palette.fixed_icon_size = Vector2i(32, 32)
	_palette.item_selected.connect(_on_palette)
	col.add_child(_palette)

	_props_box = VBoxContainer.new()
	_props_box.add_theme_constant_override("separation", 4)
	col.add_child(_props_box)

	var show_row := HBoxContainer.new()
	var grid_box := CheckBox.new()
	grid_box.text = "Grid"
	grid_box.toggled.connect(func(on): show_grid = on)
	show_row.add_child(grid_box)
	var heights_box := CheckBox.new()
	heights_box.text = "Height numbers"
	heights_box.toggled.connect(func(on): show_heights = on)
	show_row.add_child(heights_box)
	col.add_child(show_row)
	_help = Label.new()
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD
	_help.add_theme_font_size_override("font_size", 13)
	col.add_child(_help)

	var keys := Label.new()
	keys.text = KEYS_HELP
	keys.add_theme_font_size_override("font_size", 13)
	keys.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	keys.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	keys.grow_vertical = Control.GROW_DIRECTION_BEGIN
	keys.offset_right = -10
	keys.offset_bottom = -8
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	keys.add_theme_color_override("font_outline_color", Color.BLACK)
	keys.add_theme_constant_override("outline_size", 4)
	_ui.add_child(keys)

	_confirm = ConfirmationDialog.new()
	_confirm.title = "Map editor"
	_confirm.ok_button_text = "Yes"
	_confirm.cancel_button_text = "No"
	_confirm.confirmed.connect(func():
		var then := _confirm_action
		_confirm_action = Callable()
		if then.is_valid():
			then.call())
	_ui.add_child(_confirm)

	set_tool(Tool.GROUND)
	set_brush(1)


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE # keys keep moving the camera
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _label(parent: Control, text: String, size := 14, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l


func _refresh_maps() -> void:
	if _maps == null:
		return
	_maps.clear()
	for z: ZoneDef in editable_zones():
		_maps.add_item(z.display_name)
		_maps.set_item_metadata(_maps.item_count - 1, z.id)
		if z.id == zone_id:
			_maps.select(_maps.item_count - 1)


func _fill_palette() -> void:
	if _palette == null:
		return
	_palette.clear()
	_palette_ids = []
	_height_box.visible = tool == Tool.HEIGHT
	_brush_row.visible = _paints()
	_things_box.visible = tool == Tool.THINGS
	_palette.visible = tool == Tool.GROUND or tool == Tool.PROPS or \
			(tool == Tool.THINGS and thing_kind in ["enemy", "npc", "decor", "exit"])
	_help.text = HELP[tool]
	if edit == null:
		return
	var art := TileArt.for_tileset(edit.tileset)
	match tool:
		Tool.GROUND:
			for t in edit.terrain_names():
				_add_entry(ZoneEdit.pretty(t), t, art.texture(art.top_tile(t, Vector2i.ZERO)), t == terrain)
		Tool.PROPS:
			for g in edit.prop_names():
				_add_entry(ZoneEdit.pretty(g), g, art.texture(edit.tileset.pick_prop(g, Vector2i.ZERO)), g == prop)
			if prop == "" and not _palette_ids.is_empty():
				prop = _palette_ids[0]
				_palette.select(0)
		Tool.THINGS:
			_fill_things_palette()
	if not _palette.get_selected_items().is_empty():
		_palette.ensure_current_is_visible()


func _fill_things_palette() -> void:
	match thing_kind:
		"enemy":
			var defs: Array = ContentDB.enemies.values()
			defs.sort_custom(func(a, b): return a.level < b.level or (a.level == b.level and a.display_name < b.display_name))
			for d in defs:
				_add_entry("%s (Lv %d)" % [d.display_name, d.level], d, null, d == thing_what)
		"npc":
			var here := {}
			for n in edit.zone.npcs:
				here[n.npc.id] = true
			var elsewhere := ZoneEdit.placements(zone_id)
			var defs: Array = ContentDB.npcs.values()
			defs.sort_custom(func(a, b): return a.display_name < b.display_name)
			for d in defs:
				var where := " (here)" if here.has(d.id) else (" — " + ZoneEdit.zone_name(elsewhere[d.id]) if elsewhere.has(d.id) else " (not placed)")
				_add_entry(d.display_name + where, d, null, d == thing_what)
		"decor":
			for k in ZoneDecor.Kind.size():
				_add_entry(ZoneEdit.pretty(ZoneDecor.Kind.keys()[k]), k, null, thing_what == k)
		"exit":
			_add_entry("Lift (inside this map)", "", null, thing_what != null and str(thing_what) == "")
			for id in all_zone_ids():
				if id != zone_id:
					_add_entry("Door to " + ZoneEdit.zone_name(id), id, null, thing_what != null and str(thing_what) == String(id))


func _add_entry(text: String, id: Variant, icon: Texture2D, selected_now: bool) -> void:
	_palette.add_item(text, icon)
	_palette_ids.append(id)
	if selected_now:
		_palette.select(_palette.item_count - 1)


func _on_palette(i: int) -> void:
	match tool:
		Tool.GROUND:
			terrain = _palette_ids[i]
		Tool.PROPS:
			prop = _palette_ids[i]
		Tool.THINGS:
			thing_what = _palette_ids[i]


## The selected thing's settings (Things and Select tools).
func _show_props() -> void:
	if _props_box == null:
		return
	for c in _props_box.get_children():
		c.queue_free()
	_props_box.visible = (tool == Tool.SELECT or tool == Tool.THINGS) and not selected.is_empty() and edit.thing(selected) != null
	if not _props_box.visible:
		return
	var r := selected
	var t: Variant = edit.thing(r)
	var tile := edit.thing_tile(r)
	_label(_props_box, "%s at (%d, %d)" % [edit.describe(r), tile.x, tile.y], 15)
	match r.kind:
		"enemy":
			var type := OptionButton.new()
			var defs: Array = ContentDB.enemies.values()
			defs.sort_custom(func(a, b): return a.display_name < b.display_name)
			for d in defs:
				type.add_item(d.display_name)
				type.set_item_metadata(type.item_count - 1, d)
				if d == t.enemy:
					type.select(type.item_count - 1)
			type.item_selected.connect(func(i): set_selected({"enemy": type.get_item_metadata(i)}))
			_props_box.add_child(type)
			var lv := _spin(_props_box, "Level (0 = its own, %d)" % t.enemy.level, 0, 60, t.level)
			lv.value_changed.connect(func(v): set_selected({"level": int(v)}))
			var rs := _spin(_props_box, "Respawn seconds (-1 = usual)", -1, 3600, t.respawn_seconds)
			rs.value_changed.connect(func(v): set_selected({"respawn_seconds": float(v)}))
			var row := HBoxContainer.new()
			var pb := _button(row, "Stop editing patrol" if patrol_mode else "Edit patrol", func(): set_patrol_mode(not patrol_mode))
			pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_button(row, "Clear patrol", func():
				edit.set_patrol(selected, [])
				_after_change())
			_props_box.add_child(row)
			_label(_props_box, "Patrol: %d points. Left-click adds a point, right-click removes one." % t.patrol.size()
					if patrol_mode else "Patrol: %d points." % t.patrol.size(), 13)
		"npc":
			_label(_props_box, "Each person stands in one place in the game.", 13)
			var facing := OptionButton.new()
			for k in FACINGS:
				facing.add_item("Facing " + k)
				if FACINGS[k] == t.facing:
					facing.select(facing.item_count - 1)
			facing.item_selected.connect(func(i): set_selected({"facing": FACINGS.values()[i]}))
			_props_box.add_child(facing)
		"decor":
			var kind := OptionButton.new()
			for k in ZoneDecor.Kind.size():
				kind.add_item(ZoneEdit.pretty(ZoneDecor.Kind.keys()[k]))
			kind.select(t.kind)
			kind.item_selected.connect(func(i): set_selected({"kind": i}))
			_props_box.add_child(kind)
			_text(_props_box, "Label", t.label, func(s): set_selected({"label": s}))
		"landmark":
			_text(_props_box, "Name", t.name, func(s): set_selected({"name": s}))
		"exit":
			var dest := OptionButton.new()
			dest.add_item("Lift (inside this map)")
			dest.set_item_metadata(0, &"")
			for id in all_zone_ids():
				if id != zone_id:
					dest.add_item("Door to " + ZoneEdit.zone_name(id))
					dest.set_item_metadata(dest.item_count - 1, id)
					if id == t.to_zone:
						dest.select(dest.item_count - 1)
			dest.item_selected.connect(func(i): set_selected({"to_zone": dest.get_item_metadata(i)}))
			_props_box.add_child(dest)
			var to: StringName = t.to_zone if t.to_zone != &"" else zone_id
			_label(_props_box, "Leads to (%d, %d) in %s." % [t.to_tile.x, t.to_tile.y, ZoneEdit.zone_name(to)], 13)
			_button(_props_box, "Choose where it leads…", func():
				var keep := selected
				pick_arrival(t.to_zone, func(p):
					selected = keep
					set_selected({"to_tile": p})
					_message = "The door now leads to (%d, %d)." % [p.x, p.y]
					_refresh_status()))
	_button(_props_box, "Remove", func(): remove(selected))


func _spin(parent: Control, text: String, lo: float, hi: float, value: float) -> SpinBox:
	var row := HBoxContainer.new()
	_label(row, text, 13).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.value = value
	row.add_child(s)
	parent.add_child(row)
	return s


func _text(parent: Control, text: String, value: String, commit: Callable) -> LineEdit:
	var row := HBoxContainer.new()
	_label(row, text, 13, false)
	var e := LineEdit.new()
	e.text = value
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text_submitted.connect(func(s):
		commit.call(s)
		e.release_focus())
	e.focus_exited.connect(func():
		if is_instance_valid(e) and e.text != value:
			commit.call(e.text))
	row.add_child(e)
	parent.add_child(row)
	return e


func _dialog(title: String, ok: String) -> Array:
	var d := ConfirmationDialog.new()
	d.title = title
	d.ok_button_text = ok
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	d.add_child(box)
	_ui.add_child(d)
	return [d, box]


func _open_size_dialog() -> void:
	if _size_dialog != null:
		_size_dialog.queue_free()
	var made := _dialog("Map size", "Apply")
	_size_dialog = made[0]
	var box: VBoxContainer = made[1]
	_label(box, "The map is %d × %d. Add (+) or remove (−) rows and columns on each side." % [edit.width(), edit.depth()])
	var spins := {}
	for side in ZoneEdit.SIDES:
		spins[side] = _spin(box, ZoneEdit.SIDES[side], -200, 200, 0)
	var fill := OptionButton.new()
	for t in edit.terrain_names():
		fill.add_item("New ground: " + ZoneEdit.pretty(t))
		fill.set_item_metadata(fill.item_count - 1, t)
		if t == terrain:
			fill.select(fill.item_count - 1)
	box.add_child(fill)
	var fh := _spin(box, "New ground's height", 0, ZoneEdit.MAX_HEIGHT, 0)
	_label(box, "Everything on the map keeps its place on the ground. Quests, doors from other maps and linked edges are moved with it when you save.", 13)
	_size_dialog.confirmed.connect(func():
		var grow := {}
		for side in spins:
			grow[side] = int(spins[side].value)
		resize(grow, fill.get_item_metadata(fill.selected), int(fh.value)))
	_size_dialog.popup_centered(Vector2i(520, 0))


func _open_links_dialog() -> void:
	if _links_dialog != null:
		_links_dialog.queue_free()
	var made := _dialog("Connections: map edges", "Apply")
	_links_dialog = made[0]
	var box: VBoxContainer = made[1]
	_label(box, "Walking off a side leads to the matching side of the map chosen. The offset lines the two sides up (rows or columns). The other map is updated when you save. Doors are placed with the Things tool.", 13)
	var rows := {}
	for side in ZoneEdit.SIDES:
		var e := edit.edge_on(side)
		box.add_child(HSeparator.new())
		_label(box, ZoneEdit.SIDES[side] + ": %d open tiles" % edit.edge_tiles(side).size(), 14)
		var row := HBoxContainer.new()
		var to := OptionButton.new()
		to.add_item("Leads nowhere")
		to.set_item_metadata(0, &"")
		for id in all_zone_ids():
			if id != zone_id:
				to.add_item(ZoneEdit.zone_name(id))
				to.set_item_metadata(to.item_count - 1, id)
				if e != null and e.to_zone == id:
					to.select(to.item_count - 1)
		to.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(to)
		_label(row, "Offset", 13, false)
		var off := SpinBox.new()
		off.min_value = -300
		off.max_value = 300
		off.value = e.offset if e != null else 0
		row.add_child(off)
		box.add_child(row)
		var info := _label(box, "", 13)
		var update := func(_x = null):
			info.text = edge_summary(side, to.get_item_metadata(to.selected), int(off.value))
		to.item_selected.connect(update)
		off.value_changed.connect(update)
		update.call()
		rows[side] = [to, off]
	_links_dialog.confirmed.connect(func():
		for side in rows:
			var to: OptionButton = rows[side][0]
			var e := edit.edge_on(side)
			var id: StringName = to.get_item_metadata(to.selected)
			var off := int(rows[side][1].value)
			if (e == null and id == &"") or (e != null and e.to_zone == id and e.offset == off):
				continue
			edit.set_edge(side, id, off)
		_message = "Connections changed (the other maps are updated when you save)."
		_after_change())
	_links_dialog.popup_centered(Vector2i(620, 0))


## Where a side's open tiles land in another map, in words.
func edge_summary(side: Vector2i, to_zone: StringName, offset: int) -> String:
	if to_zone == &"":
		return ""
	var dest: ZoneDef = ContentDB.zones.get(to_zone)
	if dest == null:
		return ""
	var g := GridModel.from_zone(dest)
	var e := ZoneEdge.new()
	e.side = side
	e.offset = offset
	var gate := edit.edge_tiles(side)
	if gate.is_empty():
		return "No open tiles on this side: make some walkable ground on the edge."
	var ok := 0
	var first := e.arrival(gate[0], Vector2i(g.width, g.depth))
	var last := e.arrival(gate[gate.size() - 1], Vector2i(g.width, g.depth))
	for p in gate:
		var t := e.arrival(p, Vector2i(g.width, g.depth))
		if g.in_bounds(t) and g.is_walkable(t):
			ok += 1
	return "Arrives on (%d, %d) … (%d, %d) in %s: %d of %d tiles walkable there." % [
			first.x, first.y, last.x, last.y, dest.display_name, ok, gate.size()]


func _open_new_dialog() -> void:
	if _new_dialog != null:
		_new_dialog.queue_free()
	var made := _dialog("New map", "Create")
	_new_dialog = made[0]
	var box: VBoxContainer = made[1]
	var name := _text(box, "Name", "", func(_s): pass)
	var w := _spin(box, "Width", 8, 160, 30)
	var d := _spin(box, "Depth", 8, 160, 30)
	var ground := OptionButton.new()
	for t in edit.terrain_names():
		ground.add_item("Ground: " + ZoneEdit.pretty(t))
		ground.set_item_metadata(ground.item_count - 1, t)
		if t == "grass":
			ground.select(ground.item_count - 1)
	box.add_child(ground)
	var h := _spin(box, "Height", 0, ZoneEdit.MAX_HEIGHT, 0)
	var region := OptionButton.new()
	for r in Regions.Id.keys():
		region.add_item("Region: " + ZoneEdit.pretty(r.to_lower()))
	box.add_child(region)
	var music := OptionButton.new()
	for m in MUSIC_CHOICES:
		music.add_item("Music: " + ZoneEdit.pretty(m.to_lower()))
	music.select(1)
	box.add_child(music)
	_label(box, "It starts with a hero spawn point and a graveyard in the middle.", 13)
	_new_dialog.confirmed.connect(func():
		var create := func():
			create_map(name.text, Vector2i(int(w.value), int(d.value)), ground.get_item_metadata(ground.selected),
					int(h.value), region.selected, MusicTrackDef.Context[MUSIC_CHOICES[music.selected]])
		_leaving(create))
	_new_dialog.popup_centered(Vector2i(460, 0))


func _refresh_status() -> void:
	if _status == null or edit == null:
		return
	var parts := PackedStringArray()
	parts.append("%s %d×%d%s" % [edit.zone.display_name, edit.width(), edit.depth(), " (unsaved changes)" if edit.dirty else ""])
	if _hover != null and _peek.is_empty():
		var p: Vector2i = _hover
		if edit.in_bounds(p):
			var got := edit.pick(p)
			parts.append("(%d, %d) %s, height %d%s" % [p.x, p.y, ZoneEdit.pretty(got.terrain), got.height,
					", " + ZoneEdit.pretty(got.prop) if got.prop != "" else ""])
	if _message != "":
		parts.append(_message)
	_status.text = "   ".join(parts)
	_status.tooltip_text = _message
	_undo_button.disabled = not edit.can_undo()
	_redo_button.disabled = not edit.can_redo()
