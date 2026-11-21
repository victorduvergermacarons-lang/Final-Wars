extends Node
## Cost of the water emitters (WaterAmbience / WaterSound) on Greenfields and
## Millbrook: indexing a map's water once when it loads, and one look around the hero
## (the part that runs every AudioConfig.water_update_seconds), averaged over every
## walkable tile of the map as the hero's spot, and at the worst tile.
##   godot --headless --path . res://tools/perf/water_profile.tscn


func _ready() -> void:
	var cfg: AudioConfig = Audio.config
	for id in [&"greenfields", &"town"]:
		var zone: ZoneDef = ContentDB.zones[id]
		var ts: TilesetData = ContentDB.tilesets[zone.tileset]
		var reps := 50
		var t0 := Time.get_ticks_usec()
		var index := {}
		for i in reps:
			index = WaterSound.index(zone, ts)
		var index_ms := (Time.get_ticks_usec() - t0) / 1000.0 / reps
		var water := 0
		for b in index.values():
			water += b.size()
		var grid := GridModel.from_zone(zone)
		var spots: Array[Vector2i] = []
		for y in grid.depth:
			for x in grid.width:
				if grid.is_walkable(Vector2i(x, y)):
					spots.append(Vector2i(x, y))
		var worst := 0.0
		var total := 0.0
		var near_most := 0
		for t in spots:
			var at := Vector2(t)
			var s0 := Time.get_ticks_usec()
			var near := WaterSound.near(index, at, cfg.water_radius_tiles)
			WaterSound.spots(near, at, cfg.water_max_emitters)
			var us := float(Time.get_ticks_usec() - s0)
			total += us
			worst = maxf(worst, us)
			near_most = maxi(near_most, near.size())
		var per_second := 1.0 / cfg.water_update_seconds
		print("%-12s %dx%d, %d water tiles: index %.2f ms once; look around %.3f ms on average, %.3f ms at worst (%d water tiles in reach); %.3f ms per second at %.1f looks/s" % [
				zone.display_name, grid.width, grid.depth, water, index_ms, total / spots.size() / 1000.0,
				worst / 1000.0, near_most, total / spots.size() / 1000.0 * per_second, per_second])
	get_tree().quit()
