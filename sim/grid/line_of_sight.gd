class_name LineOfSight
extends RefCounted
## Height-aware line of sight between tile centers.
##
## The sight line runs from the attacker's tile height to the target's tile
## height. An intermediate tile blocks if its height is more than `tolerance`
## levels above the line at that point, or if it blocks sight outright (a tall
## prop). Where the line passes exactly through a tile corner, it is blocked
## only if both tiles touching that corner block.


static func has_los(grid: GridModel, from: Vector2i, to: Vector2i, tolerance: float) -> bool:
	if from == to:
		return true
	var h0 := float(grid.height_at(from))
	var h1 := float(grid.height_at(to))
	var ab := Vector2(to - from)
	var len_sq := ab.length_squared()
	for group in tiles_between(from, to):
		var all_block := true
		for p: Vector2i in group:
			var t := Vector2(p - from).dot(ab) / len_sq
			var line_h := lerpf(h0, h1, t)
			if not grid.blocks_sight(p) and float(grid.height_at(p)) <= line_h + tolerance:
				all_block = false
				break
		if all_block:
			return false
	return true


## Tiles the straight line between two tile centers passes through, excluding
## both ends. Each entry is an Array of 1 tile, or 2 tiles at an exact corner.
static func tiles_between(from: Vector2i, to: Vector2i) -> Array:
	var out: Array = []
	var dx := to.x - from.x
	var dy := to.y - from.y
	var nx := absi(dx)
	var ny := absi(dy)
	var sx := signi(dx)
	var sy := signi(dy)
	var p := from
	var ix := 0
	var iy := 0
	while ix < nx or iy < ny:
		var decision := (1 + 2 * ix) * ny - (1 + 2 * iy) * nx
		if decision == 0:
			out.append([Vector2i(p.x + sx, p.y), Vector2i(p.x, p.y + sy)])
			p += Vector2i(sx, sy)
			ix += 1
			iy += 1
		elif decision < 0:
			p.x += sx
			ix += 1
		else:
			p.y += sy
			iy += 1
		if p != to:
			out.append([p])
	return out
