class_name EditorOverlay
extends Node2D
## The map editor's marks over the map: tile outlines (Grid) and heights (Height
## numbers) near the camera; markers for hero spawn points and doors; the open tiles
## of each linked map edge with where they lead; the selected thing; patrol routes.

## How far from the screen's centre (in tiles) the grid and numbers are drawn.
const RADIUS := 26
const SELECT_COLOR := Color(1.0, 0.85, 0.2)
const SPAWN_COLOR := Color(0.3, 0.6, 1.0)
const DOOR_COLOR := Color(0.75, 0.45, 1.0)
const EDGE_COLOR := Color(0.3, 0.95, 0.75)
const PATROL_COLOR := Color(1.0, 0.6, 0.2)

var editor: MapEditor


func _draw() -> void:
	if editor == null or editor.view == null or editor.edit == null or not editor.view.visible:
		return
	var grid := editor.session.grid()
	var font := ThemeDB.fallback_font
	if editor.show_grid or editor.show_heights:
		_draw_helpers(grid, font)
	var edit := editor.edit
	for e in edit.zone.edges:
		for p in edit.edge_tiles(e.side):
			_diamond(grid, p, Color(EDGE_COLOR, 0.25), Color(EDGE_COLOR, 0.8))
		var gate := edit.edge_tiles(e.side)
		if not gate.is_empty():
			var mid: Vector2i = gate[gate.size() / 2]
			_text(font, _at(grid, mid) + Vector2(0, -18), "→ " + ZoneEdit.zone_name(e.to_zone), EDGE_COLOR)
	for p in edit.zone.hero_spawns:
		_diamond(grid, p, Color(SPAWN_COLOR, 0.35), SPAWN_COLOR)
		_text(font, _at(grid, p) + Vector2(0, -6), "Spawn", SPAWN_COLOR)
	for e in edit.zone.exits:
		_diamond(grid, e.tile, Color(DOOR_COLOR, 0.35), DOOR_COLOR)
		var to := "Lift" if e.to_zone == &"" or e.to_zone == edit.zone.id else "→ " + ZoneEdit.zone_name(e.to_zone)
		_text(font, _at(grid, e.tile) + Vector2(0, -6), to, DOOR_COLOR)
	var tools := editor.tool == MapEditor.Tool.SELECT or editor.tool == MapEditor.Tool.THINGS
	for i in edit.zone.enemy_spawns.size():
		var s: EnemySpawn = edit.zone.enemy_spawns[i]
		var mine := editor.selected == ZoneEdit.ref("enemy", i)
		if s.patrol.size() > 1 and (tools or mine):
			_patrol(grid, font, s.patrol, mine)
	if not editor.selected.is_empty() and edit.thing(editor.selected) != null:
		var p := edit.thing_tile(editor.selected)
		_diamond(grid, p, Color(SELECT_COLOR, 0.25), SELECT_COLOR, 3.0)
		var r: Dictionary = editor.selected
		if r.kind == "exit":
			var e: ZoneExit = edit.thing(r)
			if e.to_zone == &"" or e.to_zone == edit.zone.id:
				_diamond(grid, e.to_tile, Color(DOOR_COLOR, 0.2), DOOR_COLOR, 2.0)
				draw_line(_at(grid, p), _at(grid, e.to_tile), Color(DOOR_COLOR, 0.8), 2.0)


func _draw_helpers(grid: GridModel, font: Font) -> void:
	var centre := Iso.from_screen(editor.view.camera.position, 0.0)
	var c := Vector2i(roundi(centre.x), roundi(centre.y))
	for y in range(c.y - RADIUS, c.y + RADIUS + 1):
		for x in range(c.x - RADIUS, c.x + RADIUS + 1):
			var p := Vector2i(x, y)
			if not grid.in_bounds(p):
				continue
			var at := _at(grid, p)
			if editor.show_grid:
				var hw := Iso.TILE_W * 0.5
				var hh := Iso.TILE_H * 0.5
				var pts := PackedVector2Array([at + Vector2(0, -hh), at + Vector2(hw, 0),
						at + Vector2(0, hh), at + Vector2(-hw, 0), at + Vector2(0, -hh)])
				draw_polyline(pts, Color(1, 1, 1, 0.22), 1.0)
			if editor.show_heights:
				var colour := Color(1, 1, 1) if grid.is_walkable(p) else Color(1, 0.55, 0.5)
				_text(font, at + Vector2(0, 5), str(grid.height_at(p)), colour, 14)


func _patrol(grid: GridModel, font: Font, route: Array, mine: bool) -> void:
	var colour := PATROL_COLOR if mine else Color(PATROL_COLOR, 0.45)
	for i in route.size():
		var a := _at(grid, route[i])
		var b := _at(grid, route[(i + 1) % route.size()])
		draw_line(a, b, colour, 2.5 if mine else 1.5)
		if mine:
			draw_circle(a, 7.0, Color(0, 0, 0, 0.6))
			_text(font, a + Vector2(0, 5), str(i + 1), colour, 12)


func _at(grid: GridModel, p: Vector2i) -> Vector2:
	return editor.view.surface_point(grid, p) if grid.in_bounds(p) else Iso.to_screen(Vector2(p), 0.0)


func _diamond(grid: GridModel, p: Vector2i, fill: Color, edge: Color, width := 1.5) -> void:
	var c := _at(grid, p)
	var hw := Iso.TILE_W * 0.5 - 4
	var hh := Iso.TILE_H * 0.5 - 2
	var pts := PackedVector2Array([c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(-hw, 0)])
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, edge, width)


func _text(font: Font, at: Vector2, text: String, colour: Color, size := 12) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := at + Vector2(-w * 0.5, 0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.85))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
