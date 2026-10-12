class_name TileGeometry
extends RefCounted
## Tile shapes for abilities (Milestone 3 targeting). Movement stays 4-way, but
## ability ranges and areas use square (Chebyshev) distance: diagonal neighbours
## are 1 away, "within 4" is a 9×9 square, 3×3 blasts, 8-way aiming and knockback.

const DIRS8: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]


static func distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Every tile within `radius` (square), centre included, in row order.
static func square(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			out.append(Vector2i(x, y))
	return out


## The 8 tiles around `center`.
static func ring(center: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS8:
		out.append(center + d)
	return out


## The 8-way direction closest to the direction of `v` (ZERO for a zero vector).
static func snap8(v: Vector2) -> Vector2i:
	if v.length_squared() < 0.0001:
		return Vector2i.ZERO
	var octant := wrapi(roundi(atan2(v.y, v.x) / (PI / 4.0)), 0, 8)
	# atan2 octants start at +x and turn toward +y.
	return [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0),
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)][octant]


## `length` tiles straight out from `origin` along an 8-way direction (origin excluded).
static func line8(origin: Vector2i, dir: Vector2i, length: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if dir == Vector2i.ZERO:
		return out
	for k in range(1, length + 1):
		out.append(origin + dir * k)
	return out


## Any-angle line from the centre of `origin` toward `aim` (a tile or a point in
## tile units), `length` tiles long in square distance, origin excluded. The line
## keeps going past the aim point. Each step advances one tile along the longer axis.
static func line_toward(origin: Vector2i, aim: Vector2, length: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var d := aim - Vector2(origin)
	var major := maxf(absf(d.x), absf(d.y))
	if major < 0.0001:
		return out
	var step := d / major
	for k in range(1, length + 1):
		var p := Vector2(origin) + step * k
		out.append(Vector2i(roundi(p.x), roundi(p.y)))
	return out


## A cone opening from `origin` along an 8-way direction: row k (1..length) is the
## tile k steps out plus k−1 tiles to each side (perpendicular), clipped to width.
static func cone(origin: Vector2i, dir: Vector2i, length: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if dir == Vector2i.ZERO:
		return out
	var side := Vector2i(-dir.y, dir.x)
	if dir.x != 0 and dir.y != 0:
		side = Vector2i(signi(-dir.y), signi(dir.x)) # diagonal: widen along the anti-diagonal
	for k in range(1, length + 1):
		var c := origin + dir * k
		for s in range(-(k - 1), k):
			var t := c + side * s
			if not out.has(t):
				out.append(t)
	return out


## Cuts a line where terrain or walls block it: a tile whose height rises more than
## `tolerance` above `from_height` stops the line (that tile excluded); so do tiles
## outside the map.
static func clip_line(grid: GridModel, tiles: Array[Vector2i], from_height: int, tolerance: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t in tiles:
		if not grid.in_bounds(t):
			break
		if grid.height_at(t) > from_height + tolerance:
			break
		out.append(t)
	return out


## Where a unit pushed (or pulled) from `from` along an 8-way `dir` for up to
## `distance` tiles ends: it stops before walls, unwalkable tiles, units (`blocked`
## tile set) and climbs higher than `jump`. Drops are allowed.
## Returns {"path": tiles moved through (excluding `from`), "end": final tile,
## "stopped_by": "" | "wall" | "unit" | "ledge"}.
static func push_path(grid: GridModel, from: Vector2i, dir: Vector2i, distance: int, jump: int,
		blocked: Dictionary) -> Dictionary:
	var path: Array[Vector2i] = []
	var at := from
	var stopped := ""
	for k in distance:
		var next := at + dir
		if not grid.in_bounds(next) or not grid.is_walkable(next):
			stopped = "wall"
			break
		if blocked.has(next):
			stopped = "unit"
			break
		if grid.height_at(next) - grid.height_at(at) > jump:
			stopped = "ledge"
			break
		at = next
		path.append(at)
	return {"path": path, "end": at, "stopped_by": stopped}
