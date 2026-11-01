class_name Hitbox
extends RefCounted
## Geometry for hitboxes in continuous space (HitboxDef shapes against round
## bodies), shared by the sim and the client's aim indicator so what you aim at
## is exactly what gets hit. Positions in tile units (tile (x, y) centre = (x, y)).


## Whether a body (centre `c`, radius `r`) is inside a cone from `origin` facing
## `dir` (unit vector), `reach` long and `angle_deg` wide. Grazing counts.
static func in_cone(origin: Vector2, dir: Vector2, reach: float, angle_deg: float, c: Vector2, r: float) -> bool:
	var d := c - origin
	var dist := d.length()
	if dist > reach + r:
		return false
	if dist <= r:
		return true # the body overlaps the caster's point
	var half := deg_to_rad(angle_deg) * 0.5
	var off := absf(dir.angle_to(d))
	return off <= half + asin(clampf(r / dist, 0.0, 1.0))


## Whether a body is inside a rectangle from `origin` along `dir`, `length` long
## and `width` wide.
static func in_rect(origin: Vector2, dir: Vector2, length: float, width: float, c: Vector2, r: float) -> bool:
	var d := c - origin
	var along := d.dot(dir)
	var side := absf(d.dot(dir.orthogonal()))
	return along >= -r and along <= length + r and side <= width * 0.5 + r


static func in_circle(center: Vector2, radius: float, c: Vector2, r: float) -> bool:
	return center.distance_to(c) <= radius + r


## Whether a body is within `half_width` of the segment a–b (a swept path).
static func in_capsule(a: Vector2, b: Vector2, half_width: float, c: Vector2, r: float) -> bool:
	return Geometry2D.get_closest_point_to_segment(c, a, b).distance_to(c) <= half_width + r


## Edge-to-edge distance between two bodies.
static func gap(a: Actor, b: Actor) -> float:
	return maxf(a.move.pos.distance_to(b.move.pos) - a.move.radius - b.move.radius, 0.0)


## Line of sight between two points in continuous space: no sight-blocking tile,
## and no tile rising above the line between the two eye heights (plus tolerance),
## among the tiles the segment crosses (the end tiles excepted).
static func has_los(grid: GridModel, a: Vector2, b: Vector2, tolerance: float) -> bool:
	var ta := MoveState.tile_of(a)
	var tb := MoveState.tile_of(b)
	var ha := float(grid.height_at(ta))
	var hb := float(grid.height_at(tb))
	var length := a.distance_to(b)
	if length < 0.001:
		return true
	var steps := ceili(length / 0.25)
	for i in range(1, steps):
		var k := float(i) / steps
		var p := a.lerp(b, k)
		var t := MoveState.tile_of(p)
		if t == ta or t == tb:
			continue
		if grid.blocks_sight(t):
			return false
		if grid.height_at(t) > lerpf(ha, hb, k) + tolerance:
			return false
	return true


## How far along `dir` from `origin` a shot can travel before terrain stops it
## (a sight-blocking tile, or a tile higher than the shooter plus tolerance), up
## to `reach`.
static func clear_distance(grid: GridModel, origin: Vector2, dir: Vector2, reach: float, tolerance: float) -> float:
	var h := float(grid.height_at(MoveState.tile_of(origin)))
	var start := MoveState.tile_of(origin)
	var d := 0.0
	while d < reach:
		var next := minf(d + 0.1, reach)
		var t := MoveState.tile_of(origin + dir * next)
		if t != start and (not grid.in_bounds(t) or grid.blocks_sight(t) or grid.height_at(t) > h + tolerance):
			return d
		d = next
	return reach


## The outline of a shape on the ground (grid space), for aim indicators and
## telegraphs: a cone, a rectangle (also a dash lane or projectile path), a circle.
static func outline(kind: String, origin: Vector2, dir: Vector2, a: float, b: float, center := Vector2.ZERO) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match kind:
		"cone": # a = reach, b = angle (degrees)
			pts.append(origin)
			var half := deg_to_rad(b) * 0.5
			var n := maxi(int(b / 10.0), 3)
			for i in n + 1:
				pts.append(origin + dir.rotated(-half + 2.0 * half * i / n) * a)
		"rect": # a = length, b = width
			var side := dir.orthogonal() * b * 0.5
			var n := maxi(ceili(a / 0.5), 1)
			for i in n + 1:
				pts.append(origin + dir * a * i / n + side)
			for i in range(n, -1, -1):
				pts.append(origin + dir * a * i / n - side)
		"circle": # a = radius
			for i in 24:
				pts.append(center + Vector2.from_angle(TAU * i / 24.0) * a)
	return pts


## Tiles whose centre lies inside an outline (area effects of a continuous shape:
## ground zones, terrain).
static func tiles_in(grid: GridModel, poly: PackedVector2Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if poly.size() < 3:
		return out
	var lo := poly[0]
	var hi := poly[0]
	for p in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	for y in range(floori(lo.y), ceili(hi.y) + 1):
		for x in range(floori(lo.x), ceili(hi.x) + 1):
			var t := Vector2i(x, y)
			if grid.in_bounds(t) and Geometry2D.is_point_in_polygon(Vector2(t), poly):
				out.append(t)
	return out


## Whether `unit`'s body could stand at `p`: no solid or too-high tile under its
## circle, and no other living unit overlapping (ignoring `ignore`).
static func free_spot(ctx: CombatContext, unit: Actor, p: Vector2, ignore: Actor = null) -> String:
	var r := unit.move.radius
	var jump := StatCalc.jump_levels(unit.current_stats(ctx.now))
	var from_h := unit.move.ground_h
	var c := MoveState.tile_of(p)
	var reach := ceili(r + 0.5)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var t := c + Vector2i(dx, dy)
			var closest := p.clamp(Vector2(t) - Vector2(0.5, 0.5), Vector2(t) + Vector2(0.5, 0.5))
			if closest.distance_to(p) >= r - 0.02:
				continue
			if not ctx.grid.in_bounds(t) or not ctx.grid.is_walkable(t):
				return "wall"
			if ctx.grid.height_at(t) - from_h > jump:
				return "ledge"
	for id in ctx.actors:
		var a: Actor = ctx.actors[id]
		if a == unit or a == ignore or not a.alive:
			continue
		if a.move.pos.distance_to(p) < a.move.radius + r - 0.02:
			return "unit"
	return ""


## Slides `unit` up to `distance` along `dir` (knockback, pull, dash), stopping
## before walls, cliffs and units. {"from", "end" (point), "stopped_by" ("" if it
## went the whole way), "path" (tiles crossed), "blocker" (the unit it hit)}.
## Starts a glide there over `seconds_per_tile` per tile; a cast in progress ends.
static func slide(ctx: CombatContext, unit: Actor, dir: Vector2, distance: float, seconds_per_tile: float) -> Dictionary:
	var from := unit.move.pos
	var at := from
	var stopped := ""
	var path: Array[Vector2i] = []
	var d := 0.0
	while d < distance - 0.0001:
		var step := minf(0.1, distance - d)
		var next := at + dir * step
		stopped = free_spot(ctx, unit, next)
		if stopped != "":
			break
		at = next
		d += step
		var t := MoveState.tile_of(at)
		if path.is_empty() or path.back() != t:
			path.append(t)
	var blocker: Actor = null
	if stopped == "unit":
		for id in ctx.actors:
			var a: Actor = ctx.actors[id]
			if a != unit and a.alive and a.move.pos.distance_to(at + dir * 0.1) < a.move.radius + unit.move.radius:
				blocker = a
				break
	if at.distance_to(from) > 0.01:
		unit.casting = {}
		unit.move.begin(at, ctx.now, seconds_per_tile * at.distance_to(from))
	return {"from": from, "end": at, "stopped_by": stopped, "path": path, "blocker": blocker}
