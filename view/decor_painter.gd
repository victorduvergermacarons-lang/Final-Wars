class_name DecorPainter
extends RefCounted
## Draws the placeholder objects of ZoneDecor as simple shapes standing on a tile
## (`at` = the centre of the tile's top, in world pixels). Everything is drawn as
## polygons so the terrain cache can redraw a piece of it cut to a box (`clip`),
## like the tile images. Shapes stay within ~46 px above the tile, inside the
## bounds the view reserves for a tile's prop.

const INK := Color(0.12, 0.09, 0.05)
const STONE := Color(0.58, 0.58, 0.6)
const WOOD := Color(0.45, 0.3, 0.15)
const COLORS := {
	ZoneDecor.Kind.WELL: STONE,
	ZoneDecor.Kind.DRY_WELL: Color(0.62, 0.55, 0.45),
	ZoneDecor.Kind.GER: Color(0.88, 0.85, 0.76),
	ZoneDecor.Kind.CAIRN: Color(0.62, 0.62, 0.66),
	ZoneDecor.Kind.CART: Color(0.4, 0.26, 0.14),
	ZoneDecor.Kind.ANIMAL: Color(0.55, 0.42, 0.3),
	ZoneDecor.Kind.SHRINE: Color(0.72, 0.72, 0.78),
	ZoneDecor.Kind.STALL: Color(0.78, 0.25, 0.2),
	ZoneDecor.Kind.SIGN: WOOD,
	ZoneDecor.Kind.MINE: Color(0.5, 0.33, 0.17),
	ZoneDecor.Kind.CRATES: Color(0.62, 0.45, 0.24),
}


static func color_of(d: ZoneDecor) -> Color:
	return d.color if d.color.a > 0.0 else COLORS.get(d.kind, Color.WHITE)


## Height of the drawing above the tile (where its label goes).
static func top(d: ZoneDecor) -> float:
	match d.kind:
		ZoneDecor.Kind.GER, ZoneDecor.Kind.SHRINE, ZoneDecor.Kind.MINE:
			return 44.0
		ZoneDecor.Kind.WELL, ZoneDecor.Kind.STALL, ZoneDecor.Kind.SIGN:
			return 36.0
		ZoneDecor.Kind.LABEL:
			return 10.0
	return 26.0


static func draw(canvas: CanvasItem, d: ZoneDecor, at: Vector2, clip := Rect2()) -> void:
	var c := color_of(d)
	var p := _Pen.new(canvas, at, clip)
	match d.kind:
		ZoneDecor.Kind.WELL, ZoneDecor.Kind.DRY_WELL:
			var dry := d.kind == ZoneDecor.Kind.DRY_WELL
			p.ellipse(Vector2(0, 0), 15, 7.5, c.darkened(0.35))
			p.poly([Vector2(-15, 0), Vector2(-15, -9), Vector2(15, -9), Vector2(15, 0)], c.darkened(0.15))
			p.ellipse(Vector2(0, -9), 15, 7.5, c)
			p.ellipse(Vector2(0, -9), 11, 5, Color(0.35, 0.27, 0.18) if dry else Color(0.25, 0.42, 0.7))
			if dry:
				p.line(Vector2(-6, -10), Vector2(2, -8), 1.5, INK) # cracked mud
				p.line(Vector2(2, -8), Vector2(7, -11), 1.5, INK)
			else:
				for x in [-13.0, 13.0]:
					p.line(Vector2(x, -9), Vector2(x, -30), 3.0, WOOD)
				p.line(Vector2(-15, -30), Vector2(15, -30), 3.0, WOOD)
				p.poly([Vector2(-17, -29), Vector2(0, -36), Vector2(17, -29)], Color(0.6, 0.35, 0.2))
		ZoneDecor.Kind.GER:
			p.ellipse(Vector2(0, 0), 24, 12, Color(0, 0, 0, 0.25))
			p.poly([Vector2(-22, -2), Vector2(-22, -18), Vector2(22, -18), Vector2(22, -2)], c.darkened(0.1))
			p.ellipse(Vector2(0, -2), 22, 9, c.darkened(0.1))
			p.poly([Vector2(-24, -18), Vector2(-8, -38), Vector2(8, -38), Vector2(24, -18)], c.lightened(0.1))
			p.ellipse(Vector2(0, -38), 8, 3, c.darkened(0.25))
			p.line(Vector2(-22, -12), Vector2(22, -12), 2.0, Color(0.6, 0.2, 0.15)) # felt band
			p.poly([Vector2(-5, 4), Vector2(-5, -11), Vector2(5, -11), Vector2(5, 4)], Color(0.7, 0.22, 0.15)) # door
		ZoneDecor.Kind.CAIRN:
			var y := 0.0
			for r in [13.0, 10.0, 8.0, 5.5]:
				p.ellipse(Vector2(r * 0.15, y - r * 0.5), r, r * 0.65, c.darkened(0.08 * (13.0 - r) / 3.0))
				y -= r * 1.05
		ZoneDecor.Kind.CART:
			p.poly([Vector2(-18, -6), Vector2(-15, -20), Vector2(15, -20), Vector2(18, -6)], c)
			for x in [-8.0, 0.0, 8.0]:
				p.ellipse(Vector2(x, -21), 5, 3.5, Color(0.72, 0.3, 0.18)) # ore
			for x in [-11.0, 11.0]:
				p.circle(Vector2(x, -4), 5, INK)
				p.circle(Vector2(x, -4), 2.5, WOOD)
		ZoneDecor.Kind.ANIMAL:
			for x in [-7.0, -3.0, 4.0, 8.0]:
				p.line(Vector2(x, -8), Vector2(x, 0), 2.0, c.darkened(0.4))
			p.ellipse(Vector2(0, -12), 12, 7, c)
			p.circle(Vector2(12, -16), 4.5, c.darkened(0.15))
			p.line(Vector2(10, -20), Vector2(8, -24), 1.5, Color(0.9, 0.88, 0.8)) # horns
			p.line(Vector2(14, -20), Vector2(16, -24), 1.5, Color(0.9, 0.88, 0.8))
		ZoneDecor.Kind.SHRINE:
			p.poly([Vector2(-14, 0), Vector2(-14, -6), Vector2(14, -6), Vector2(14, 0)], c.darkened(0.25))
			p.poly([Vector2(-7, -6), Vector2(-6, -36), Vector2(6, -36), Vector2(7, -6)], c)
			p.poly([Vector2(-6, -36), Vector2(0, -42), Vector2(6, -36)], c.lightened(0.15))
			p.circle(Vector2(0, -24), 4, Color(0.75, 0.9, 1.0))
		ZoneDecor.Kind.STALL:
			for x in [-14.0, 14.0]:
				p.line(Vector2(x, 0), Vector2(x, -30), 2.5, WOOD)
			p.poly([Vector2(-15, -2), Vector2(-15, -12), Vector2(15, -12), Vector2(15, -2)], WOOD.lightened(0.15))
			for i in 4: # striped awning
				var x0 := -17.0 + i * 8.5
				p.poly([Vector2(x0, -27), Vector2(x0 + 2, -35), Vector2(x0 + 10.5, -35), Vector2(x0 + 8.5, -27)],
						c if i % 2 == 0 else Color(0.95, 0.92, 0.85))
			p.circle(Vector2(-6, -15), 3, Color(0.9, 0.7, 0.2)) # goods
			p.circle(Vector2(3, -15), 3, Color(0.4, 0.7, 0.3))
		ZoneDecor.Kind.SIGN:
			p.line(Vector2(0, 0), Vector2(0, -24), 3.0, c)
			p.poly([Vector2(-12, -22), Vector2(-12, -33), Vector2(12, -33), Vector2(12, -22)], c.lightened(0.2))
		ZoneDecor.Kind.MINE:
			p.poly([Vector2(-17, 2), Vector2(-17, -30), Vector2(-10, -40), Vector2(10, -40), Vector2(17, -30), Vector2(17, 2)],
					Color(0.07, 0.05, 0.05))
			for x in [-15.0, 15.0]:
				p.line(Vector2(x, 2), Vector2(x, -32), 4.0, c)
			p.line(Vector2(-19, -32), Vector2(19, -32), 4.0, c)
			p.line(Vector2(-6, 2), Vector2(-3, -10), 2.0, Color(0.4, 0.4, 0.42)) # rails
			p.line(Vector2(6, 2), Vector2(3, -10), 2.0, Color(0.4, 0.4, 0.42))
		ZoneDecor.Kind.CRATES:
			p.poly([Vector2(-16, 0), Vector2(-16, -12), Vector2(0, -12), Vector2(0, 0)], c)
			p.poly([Vector2(1, 0), Vector2(1, -10), Vector2(14, -10), Vector2(14, 0)], c.darkened(0.12))
			p.poly([Vector2(-10, -13), Vector2(-10, -24), Vector2(4, -24), Vector2(4, -13)], c.lightened(0.08))
			p.line(Vector2(-16, -6), Vector2(0, -6), 1.0, INK)
			p.line(Vector2(-10, -18), Vector2(4, -18), 1.0, INK)


## Draws polygons offset to a tile, cut to `clip` when it has an area.
class _Pen:
	var canvas: CanvasItem
	var at: Vector2
	var clip: Rect2
	var clip_poly: PackedVector2Array

	func _init(p_canvas: CanvasItem, p_at: Vector2, p_clip: Rect2) -> void:
		canvas = p_canvas
		at = p_at
		clip = p_clip
		if clip.has_area():
			clip_poly = PackedVector2Array([clip.position, Vector2(clip.end.x, clip.position.y), clip.end,
					Vector2(clip.position.x, clip.end.y)])

	func poly(points: Array, color: Color) -> void:
		var pts := PackedVector2Array()
		for q in points:
			pts.append(at + q)
		if clip_poly.is_empty():
			canvas.draw_colored_polygon(pts, color)
			return
		for part in Geometry2D.intersect_polygons(pts, clip_poly):
			if part.size() >= 3: # a convex box cuts no holes
				canvas.draw_colored_polygon(part, color)

	func ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
		var pts := []
		for i in 16:
			var a := TAU * i / 16.0
			pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
		poly(pts, color)

	func circle(center: Vector2, r: float, color: Color) -> void:
		ellipse(center, r, r, color)

	func line(a: Vector2, b: Vector2, width: float, color: Color) -> void:
		var n := (b - a).orthogonal().normalized() * width * 0.5
		poly([a + n, b + n, b - n, a - n], color)
