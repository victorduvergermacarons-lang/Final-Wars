class_name WaterSound
extends RefCounted
## Where the water sound near the local hero comes from (plain functions, no nodes;
## WaterAmbience plays it). A zone's water tiles are found once, when its map loads,
## from the tileset: a tile whose terrain is water in the catalog (its tiles are in
## the "water" category, TilesetData.is_water_terrain: rivers, the grey river and
## polluted stream, ponds, lakes, puddles; fords and rocks in the water are stone,
## so they don't count). They are kept in square buckets, so a look around the hero only touches
## the buckets near it, never the whole map.

## Bucket size in tiles.
const BUCKET := 8

## Water tiles of `zone` by bucket: {Vector2i bucket: Array[Vector2i] tiles}.
## Empty for a zone without terrain, a tileset or water.
static func index(zone: ZoneDef, tileset: TilesetData) -> Dictionary:
	return WaterTiles.index(zone, tileset)


## The water tiles within `radius` tiles (straight-line distance to the tile's
## centre) of point `at` (tile units).
static func near(index: Dictionary, at: Vector2, radius: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if index.is_empty():
		return out
	var lo := Vector2i(floori((at.x - radius) / BUCKET), floori((at.y - radius) / BUCKET))
	var hi := Vector2i(floori((at.x + radius) / BUCKET), floori((at.y + radius) / BUCKET))
	var r2 := radius * radius
	for by in range(lo.y, hi.y + 1):
		for bx in range(lo.x, hi.x + 1):
			for t: Vector2i in index.get(Vector2i(bx, by), []):
				if at.distance_squared_to(Vector2(t)) <= r2:
					out.append(t)
	return out


## Where the emitters go: the tiles are grouped into clusters (tiles touching, the
## diagonals included), each cluster gives its tile nearest to `at`, and the
## `max_count` nearest of those are returned, nearest first.
static func spots(tiles: Array[Vector2i], at: Vector2, max_count: int) -> Array[Vector2i]:
	var left := {}
	for t in tiles:
		left[t] = true
	var best: Array = [] # [distance², tile] per cluster
	for t in tiles:
		if not left.has(t):
			continue
		left.erase(t)
		var nearest := t
		var nearest_d := at.distance_squared_to(Vector2(t))
		var queue: Array[Vector2i] = [t]
		while not queue.is_empty():
			var p: Vector2i = queue.pop_back()
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var n := p + Vector2i(dx, dy)
					if left.has(n):
						left.erase(n)
						queue.append(n)
						var d := at.distance_squared_to(Vector2(n))
						if d < nearest_d or (d == nearest_d and (n.y < nearest.y or n.y == nearest.y and n.x < nearest.x)):
							nearest = n
							nearest_d = d
		best.append([nearest_d, nearest])
	best.sort_custom(func(a, b): return a[0] < b[0] or a[0] == b[0] and (a[1].y < b[1].y or a[1].y == b[1].y and a[1].x < b[1].x))
	var out: Array[Vector2i] = []
	for i in mini(max_count, best.size()):
		out.append(best[i][1])
	return out


## How loud an emitter `distance` tiles away is, 0..1 (1 at the water, 0 at `radius`).
static func gain(distance: float, radius: float, falloff: float) -> float:
	if radius <= 0.0:
		return 0.0
	return pow(clampf(1.0 - distance / radius, 0.0, 1.0), maxf(falloff, 0.01))
