class_name WaterTiles
extends RefCounted
## Where a zone's water is, for waterbending (2026-11-26): the tiles whose terrain is
## water in the tileset's catalog (TilesetData.is_water_terrain: rivers, ponds, lakes,
## puddles; fords and rocks in the water are stone). Kept in square buckets, so a
## look around a hero only touches the buckets near it. The water sound uses the
## same index (WaterSound).

## Bucket size in tiles.
const BUCKET := 8

static var _cache := {} # zone id -> index


## Water tiles of `zone` by bucket: {Vector2i bucket: Array[Vector2i] tiles}.
## Empty for a zone without terrain, a tileset or water.
static func index(zone: ZoneDef, tileset: TilesetData) -> Dictionary:
	var out := {}
	if zone == null or tileset == null or not zone.has_terrain():
		return out
	var water := {} # terrain name -> is water (a map has only a few terrains)
	for c in zone.terrain_legend:
		var name := str(zone.terrain_legend[c])
		water[name] = tileset.is_water_terrain(name)
	if not water.values().has(true):
		return out
	for y in zone.terrain_rows.size():
		var row: String = zone.terrain_rows[y]
		for x in row.length():
			var name := str(zone.terrain_legend.get(row[x], ""))
			if water.get(name, false):
				var b := Vector2i(floori(float(x) / BUCKET), floori(float(y) / BUCKET))
				if not out.has(b):
					out[b] = [] as Array[Vector2i]
				out[b].append(Vector2i(x, y))
	return out


## The index of `zone`, built once per zone (from ContentDB's tilesets).
static func of(zone: ZoneDef) -> Dictionary:
	if zone == null:
		return {}
	if not _cache.has(zone.id):
		_cache[zone.id] = index(zone, ContentDB.tilesets.get(zone.tileset))
	return _cache[zone.id]


## Forgets the cached indexes (a map was edited).
static func clear_cache() -> void:
	_cache.clear()


## The nearest water tile within `radius` tiles of point `at` (tile units), or null.
static func nearest(idx: Dictionary, at: Vector2, radius: float) -> Variant:
	if idx.is_empty():
		return null
	var best: Variant = null
	var best_d := radius
	var lo := Vector2i(floori((at.x - radius) / BUCKET), floori((at.y - radius) / BUCKET))
	var hi := Vector2i(floori((at.x + radius) / BUCKET), floori((at.y + radius) / BUCKET))
	for bx in range(lo.x, hi.x + 1):
		for by in range(lo.y, hi.y + 1):
			for t: Vector2i in idx.get(Vector2i(bx, by), []):
				var d := at.distance_to(Vector2(t))
				if d <= best_d:
					best_d = d
					best = t
	return best
