class_name MapEditor
extends Node
## The map editor screen (main menu → Map Editor, when the game runs from the
## Godot editor). Paints a tiled zone's ground, heights and props with the mouse,
## shows the result with the game's own renderer, and saves into the zone's .tres.
## Enemies and people stand frozen where they spawn (EditorSession never ticks).

signal closed

enum Tool { GROUND, HEIGHT, PROPS, PICK }

const TOOL_NAMES := ["Ground", "Height", "Props", "Pick"]
const BRUSH_SIZES := [1, 3, 5]
const PAN_SPEED := 900.0 # world units per second at zoom 1
const HELP := {
	Tool.GROUND: "Left: paint the chosen ground\nRight: copy the ground under the mouse",
	Tool.HEIGHT: "Left: raise one level\nRight: lower one level\n(or tick \"Exact level\" and paint it)",
	Tool.PROPS: "Left: place the chosen prop\nRight: remove props",
	Tool.PICK: "Left: copy the tile under the mouse\n(its ground, height and prop)",
}
const KEYS_HELP := "WASD / arrows or middle-drag: move   Wheel: zoom\n1-4: tools   [ ]: brush size   Ctrl+Z / Ctrl+Y: undo / redo   Ctrl+S: save"

## The zone being edited (its id in ContentDB.zones) and the editing model.
var zone_id: StringName = &""
var edit: ZoneEdit
var session: EditorSession
var view: WorldView
var client := ClientState.new()

var tool := Tool.GROUND
var brush_size := 1
var terrain := "grass"
var prop := ""
var exact_height := false
var height_level := 1
var show_grid := false
var show_heights := false

var _cam_target := Vector2.ZERO
var _painting := MOUSE_BUTTON_NONE
var _painted := {} # tiles already changed in this drag (a drag raises each tile once)
var _hover: Variant = null

# UI
var _ui: CanvasLayer
var _maps: OptionButton
var _status: Label
var _palette: ItemList
var _palette_ids: Array = []
var _height_box: VBoxContainer
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
## Tests save into a copy of the zone file instead of the real one.
var save_path_override := ""


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


func _ready() -> void:
	_build_ui()
	var zones := editable_zones()
	var first: StringName = &"town" if ContentDB.zones.has(&"town") else zones[0].id
	open_zone(first)


# --- Opening a map --------------------------------------------------------------

func open_zone(id: StringName) -> void:
	zone_id = id
	_hover = null
	_painting = MOUSE_BUTTON_NONE
	_painted = {}
	if view != null:
		view.queue_free()
	if session != null:
		session.queue_free()
	var copy := ZoneEdit.copy_of(ContentDB.zones[id])
	session = EditorSession.new()
	session.name = "EditorSession"
	add_child(session)
	session.start(copy, ContentDB.rules)
	edit = ZoneEdit.new(copy, ContentDB.tilesets[copy.tileset], session.grid())
	view = WorldView.new()
	view.name = "WorldView"
	add_child(view)
	move_child(view, 0)
	view.setup(session, client, copy)
	_overlay = EditorOverlay.new()
	_overlay.editor = self
	_overlay.z_index = 50
	view.add_child(_overlay)
	var center := Vector2i(edit.width() / 2, edit.depth() / 2)
	_cam_target = Iso.to_screen(Vector2(center), edit.height_at(center))
	view.camera.follow(_cam_target, 0.0, true)
	client.aim = {}
	for i in _maps.item_count:
		if _maps.get_item_metadata(i) == id:
			_maps.select(i)
	_message = "Opened %s." % copy.display_name
	_fill_palette()
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
	if pan != Vector2.ZERO and not Input.is_key_pressed(KEY_CTRL):
		_cam_target += pan.normalized() * PAN_SPEED * delta / maxf(view.camera.zoom.x, 0.1)
	view.camera.follow(_cam_target, delta, true)
	# A drag let go over a panel: the panel took the release.
	if _painting != MOUSE_BUTTON_NONE and not Input.is_mouse_button_pressed(_painting):
		_finish_stroke()
	_update_hover()
	_overlay.queue_redraw()


func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is SpinBox


func _update_hover() -> void:
	var t: Variant = null
	if not _mouse_over_ui():
		t = view.tile_at(view.get_global_mouse_position())
	if t != _hover:
		_hover = t
		if _hover != null and _painting != MOUSE_BUTTON_NONE:
			_apply(_hover, _painting)
		_refresh_status()
	if _hover == null:
		client.aim = {}
	else:
		var tiles: Array[Vector2i] = [_hover] if tool == Tool.PICK else edit.brush(_hover, brush_size)
		client.aim = {"tiles": tiles, "valid": true}


func _mouse_over_ui() -> bool:
	var c := get_viewport().gui_get_hovered_control()
	return c != null


# --- Input ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if view == null:
		return
	if event is InputEventMouseButton:
		var b: int = event.button_index
		if b == MOUSE_BUTTON_LEFT or b == MOUSE_BUTTON_RIGHT:
			if event.pressed and _painting == MOUSE_BUTTON_NONE:
				_painting = b
				_painted = {}
				edit.begin_stroke()
				_hover = view.tile_at(view.get_global_mouse_position())
				if _hover != null:
					_apply(_hover, b)
			elif not event.pressed and b == _painting:
				_finish_stroke()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
		_cam_target -= event.relative / maxf(view.camera.zoom.x, 0.1)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if _shortcut(event):
			get_viewport().set_input_as_handled()


func _finish_stroke() -> void:
	_painting = MOUSE_BUTTON_NONE
	_painted = {}
	edit.end_stroke()
	_refresh_status()


func _shortcut(event: InputEventKey) -> bool:
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
		KEY_1, KEY_2, KEY_3, KEY_4 when not ctrl:
			set_tool(event.physical_keycode - KEY_1)
		KEY_BRACKETLEFT:
			set_brush(BRUSH_SIZES[maxi(BRUSH_SIZES.find(brush_size) - 1, 0)])
		KEY_BRACKETRIGHT:
			set_brush(BRUSH_SIZES[mini(BRUSH_SIZES.find(brush_size) + 1, BRUSH_SIZES.size() - 1)])
		_:
			return false
	return true


# --- Tools --------------------------------------------------------------------------

## Uses the current tool on `tile` with a mouse button (what a click does).
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
	_message = "Copied: %s, height %d%s." % [_pretty(terrain), height_level,
			", " + _pretty(got.prop) if got.prop != "" else ""]
	if tool == Tool.PICK:
		set_tool(Tool.GROUND)
	else:
		_fill_palette()
		_refresh_status()


func set_tool(t: int) -> void:
	tool = clampi(t, 0, Tool.size() - 1) as Tool
	for i in _tool_buttons.size():
		_tool_buttons[i].set_pressed_no_signal(i == tool)
	_fill_palette()
	_refresh_status()


func set_brush(size: int) -> void:
	brush_size = size
	for i in _brush_buttons.size():
		_brush_buttons[i].set_pressed_no_signal(BRUSH_SIZES[i] == size)


func undo() -> void:
	var tiles := edit.undo()
	view.refresh_tiles(tiles)
	_message = "Undone." if not tiles.is_empty() else "Nothing to undo."
	_refresh_status()


func redo() -> void:
	var tiles := edit.redo()
	view.refresh_tiles(tiles)
	_message = "Redone." if not tiles.is_empty() else "Nothing to redo."
	_refresh_status()


# --- Saving ---------------------------------------------------------------------------

## Problems that would make the map unplayable (empty: none).
func problems() -> PackedStringArray:
	var out := edit.zone.validate_terrain(edit.tileset)
	out.append_array(ZoneCheck.problems(edit.zone, session.grid()))
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


## Writes the map into its .tres and into the game's loaded copy (so Play uses it).
func write() -> Error:
	var source: ZoneDef = ContentDB.zones[zone_id]
	edit.tidy_legends()
	var path := save_path_override if save_path_override != "" else source.resource_path
	var err := ZoneFile.save(path, edit.zone)
	if err != OK:
		_message = "Could not save %s (%s)." % [path, error_string(err)]
		_refresh_status()
		return err
	for key in ZoneFile.ROW_KEYS:
		source.set(key, PackedStringArray(Array(edit.zone.get(key))))
	source.terrain_legend = edit.zone.terrain_legend.duplicate()
	source.prop_legend = edit.zone.prop_legend.duplicate()
	source.friction_tiles = edit.zone.friction_tiles.duplicate()
	edit.dirty = false
	_message = "Saved %s." % path.get_file()
	_refresh_status()
	return OK


func _ask(text: String, then: Callable) -> void:
	_confirm.dialog_text = text
	_confirm_action = then
	_confirm.popup_centered(Vector2i(520, 0))


## Leaves (or switches map) now, or after asking if there are unsaved changes.
func _leaving(then: Callable) -> void:
	if edit != null and edit.dirty:
		_ask("You have unsaved changes to %s. Leave without saving?" % edit.zone.display_name, then)
	else:
		then.call()


func close() -> void:
	_leaving(func(): closed.emit())


# --- UI ----------------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)

	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_ui.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	top.add_child(bar)
	var map_label := Label.new()
	map_label.text = "Map"
	bar.add_child(map_label)
	_maps = OptionButton.new()
	for z: ZoneDef in editable_zones():
		_maps.add_item(z.display_name)
		_maps.set_item_metadata(_maps.item_count - 1, z.id)
	_maps.item_selected.connect(func(i):
		var id: StringName = _maps.get_item_metadata(i)
		if id == zone_id:
			return
		_leaving(func(): open_zone(id))
		# Until the answer: show the map that is still open.
		for j in _maps.item_count:
			if _maps.get_item_metadata(j) == zone_id:
				_maps.select(j))
	bar.add_child(_maps)
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
	side.offset_right = 268
	_ui.add_child(side)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	side.add_child(col)
	var tools := HBoxContainer.new()
	var tool_group := ButtonGroup.new()
	for i in TOOL_NAMES.size():
		var b := _button(tools, "%d %s" % [i + 1, TOOL_NAMES[i]], set_tool.bind(i))
		b.toggle_mode = true
		b.button_group = tool_group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tool_buttons.append(b)
	col.add_child(tools)
	var brushes := HBoxContainer.new()
	var brush_label := Label.new()
	brush_label.text = "Brush"
	brushes.add_child(brush_label)
	var brush_group := ButtonGroup.new()
	for s in BRUSH_SIZES:
		var b := _button(brushes, "%d×%d" % [s, s], set_brush.bind(s))
		b.toggle_mode = true
		b.button_group = brush_group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_brush_buttons.append(b)
	col.add_child(brushes)

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

	_palette = ItemList.new()
	_palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_palette.fixed_icon_size = Vector2i(32, 32)
	_palette.item_selected.connect(_on_palette)
	col.add_child(_palette)

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


func _fill_palette() -> void:
	if _palette == null:
		return
	_palette.clear()
	_palette_ids = []
	_height_box.visible = tool == Tool.HEIGHT
	_palette.visible = tool == Tool.GROUND or tool == Tool.PROPS
	_help.text = HELP[tool]
	if edit == null:
		return
	var art := TileArt.for_tileset(edit.tileset)
	if tool == Tool.GROUND:
		for t in edit.terrain_names():
			_palette.add_item(_pretty(t), art.texture(art.top_tile(t, Vector2i.ZERO)))
			_palette_ids.append(t)
			if t == terrain:
				_palette.select(_palette.item_count - 1)
	elif tool == Tool.PROPS:
		for g in edit.prop_names():
			_palette.add_item(_pretty(g), art.texture(edit.tileset.pick_prop(g, Vector2i.ZERO)))
			_palette_ids.append(g)
			if g == prop:
				_palette.select(_palette.item_count - 1)
		if prop == "" and not _palette_ids.is_empty():
			prop = _palette_ids[0]
			_palette.select(0)
	var sel := _palette.get_selected_items()
	if not sel.is_empty():
		_palette.ensure_current_is_visible()


func _on_palette(i: int) -> void:
	if tool == Tool.GROUND:
		terrain = _palette_ids[i]
	elif tool == Tool.PROPS:
		prop = _palette_ids[i]


func _refresh_status() -> void:
	if _status == null or edit == null:
		return
	var parts := PackedStringArray()
	parts.append(edit.zone.display_name + (" (unsaved changes)" if edit.dirty else ""))
	if _hover != null:
		var p: Vector2i = _hover
		var got := edit.pick(p)
		parts.append("(%d, %d) %s, height %d%s" % [p.x, p.y, _pretty(got.terrain), got.height,
				", " + _pretty(got.prop) if got.prop != "" else ""])
	if _message != "":
		parts.append(_message)
	_status.text = "   ".join(parts)
	_undo_button.disabled = not edit.can_undo()
	_redo_button.disabled = not edit.can_redo()


static func _pretty(id: String) -> String:
	return id.replace("_", " ").capitalize()
