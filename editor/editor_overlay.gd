class_name EditorOverlay
extends Node2D
## The map editor's helpers over the map: tile outlines (Grid) and each tile's
## height (Height numbers), for the tiles around the camera.

## How far from the screen's centre (in tiles) the helpers are drawn.
const RADIUS := 26

var editor: MapEditor


func _draw() -> void:
	if editor == null or editor.view == null or editor.edit == null:
		return
	if not (editor.show_grid or editor.show_heights):
		return
	var grid := editor.session.grid()
	var centre := Iso.from_screen(editor.view.camera.position, 0.0)
	var c := Vector2i(roundi(centre.x), roundi(centre.y))
	var font := ThemeDB.fallback_font
	for y in range(c.y - RADIUS, c.y + RADIUS + 1):
		for x in range(c.x - RADIUS, c.x + RADIUS + 1):
			var p := Vector2i(x, y)
			if not grid.in_bounds(p):
				continue
			var at := editor.view.surface_point(grid, p)
			if editor.show_grid:
				var hw := Iso.TILE_W * 0.5
				var hh := Iso.TILE_H * 0.5
				var pts := PackedVector2Array([at + Vector2(0, -hh), at + Vector2(hw, 0),
						at + Vector2(0, hh), at + Vector2(-hw, 0), at + Vector2(0, -hh)])
				draw_polyline(pts, Color(1, 1, 1, 0.22), 1.0)
			if editor.show_heights:
				var text := str(grid.height_at(p))
				var colour := Color(1, 1, 1) if grid.is_walkable(p) else Color(1, 0.55, 0.5)
				var size := 14
				var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				draw_string_outline(font, at + Vector2(-w * 0.5, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.8))
				draw_string(font, at + Vector2(-w * 0.5, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
