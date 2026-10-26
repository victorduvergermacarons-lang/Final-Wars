class_name WorldView
extends Node2D
## Placeholder renderer: draws the grid and actors from session state, back to
## front. Reads only; never changes the world.
##
## Terrain cache (`use_terrain_cache`): the ground is drawn once into chunk nodes
## under this one (a few depth rows each) and kept by Godot between frames. A
## chunk is redrawn only when a height in it changes (Raise Pillar, Earth Wall);
## water animates by itself (TileArt.animated_texture). Each frame this node
## then draws only what moves (actors, tile highlights) in the usual back-to-
## front order, and within a box around each of them it draws again, in order,
## the tiles from that row forward, cut to the box. Inside the boxes the picture
## is built exactly as a full redraw would build it; outside them the cache
## already is. Projectiles, labels and bars are drawn on top as before.

const FLOAT_TEXT_SECONDS := 1.2
const PICK_RADIUS := 26.0

const COLOR_WATER := Color(0.22, 0.42, 0.78)
const COLOR_ROCK := Color(0.35, 0.35, 0.38)
const COLOR_GRAVEYARD := Color(0.55, 0.5, 0.65)
const HEIGHT_COLORS := [
	Color(0.36, 0.62, 0.30), Color(0.45, 0.62, 0.30), Color(0.55, 0.58, 0.32),
	Color(0.58, 0.50, 0.33), Color(0.55, 0.47, 0.40), Color(0.60, 0.60, 0.60),
]
const HERO_COLORS := [Color(0.25, 0.5, 1.0), Color(0.2, 0.85, 0.45), Color(1.0, 0.8, 0.2), Color(0.85, 0.4, 0.95)]
const ENEMY_COLOR := Color(0.85, 0.2, 0.2)
## Quest-area value for an investigate spot (see _quest_area_tiles).
const SPOT := "spot"
## Tile highlights: aiming (valid / can't), enemy telegraphs, ground zones.
const AIM_COLOR := Color(0.2, 0.6, 1.0, 0.6)
const AIM_BAD_COLOR := Color(1.0, 0.25, 0.2, 0.55)
const TELEGRAPH_COLOR := Color(1.0, 0.15, 0.1)
const ZONE_COLOR := Color(1.0, 0.55, 0.1, 0.4)

var session # LocalSession or a networked session with the same API
var client: ClientState
var camera: PixelCamera

var _tiles_by_depth := {} # depth -> Array[Vector2i]
var _max_depth := 0
var _graveyards := {}
var _float_texts: Array = [] # {actor, text, color, t, row}
var _font: Font
var _landmarks: Array[ZoneLandmark] = []
var _zone: ZoneDef
## The zone's tileset art (null: placeholder diamonds).
var _art: TileArt
## Animated creatures: which frame each shows.
## The faint outline under a large body's tiles (its hitbox).
const BODY_COLOR := Color(0.95, 0.35, 0.1, 0.16)
## Fiery abilities that just went off: [{"tiles", "start"}] (see _draw_flames).
var _flames: Array = []
const FLAME_SECONDS := 0.7
## Enraged creatures (EnemyDef.enrage_buff) are drawn this much hotter.
const ENRAGE_TINT := Color(1.35, 0.85, 0.7)
var _animator := CreatureAnimator.new()
static var _frames_cache := {} # CreatureArtDef -> SpriteFrames
## Actor id -> render time its hit flash ends.
var _flash_until := {}
const FLASH_STRENGTH := 12.0
## Bars and markers queued while drawing actors, drawn last so terrain and
## other actors never cover them.
var _overlay: Array[Callable] = []
## Labels queued the same way: {pos, text, color, size, boxed}. Drawn after the
## overlay, nudged up so no two overlap.
var _labels: Array = []

## Off: redraw every tile every frame (the old way, kept to compare; the
## screenshot test compares both with SHOTS_COMPARE_CACHE=1).
static var use_terrain_cache := true
## Glows (telegraphs, quest areas) pulse on the real clock; screenshot tests stop it.
static var freeze_pulses := false
## Depth rows per terrain chunk.
const CHUNK_ROWS := 8
var _chunks: Array[Node2D] = []
var _terrain_root: Node2D
var _cache_on := true
var _grid: GridModel # the map this view was built for
var _row_index := {} # tile -> its position in its depth row's drawing order
var _heights_seen := PackedInt32Array()
var _max_height := 0


func setup(p_session, p_client: ClientState, zone: ZoneDef) -> void:
	session = p_session
	client = p_client
	_font = ThemeDB.fallback_font
	_zone = zone
	_art = TileArt.for_tileset(ContentDB.tilesets.get(zone.tileset)) if zone.has_terrain() else null
	var grid: GridModel = session.grid()
	for y in grid.depth:
		for x in grid.width:
			var p := Vector2i(x, y)
			var d := Iso.depth(p)
			if not _tiles_by_depth.has(d):
				_tiles_by_depth[d] = []
			_row_index[p] = _tiles_by_depth[d].size()
			_tiles_by_depth[d].append(p)
			_max_depth = maxi(_max_depth, d)
	for g in zone.graveyards:
		_graveyards[g] = true
	_landmarks = zone.landmarks
	camera = PixelCamera.new()
	add_child(camera)
	session.events_received.connect(_on_events)
	_grid = grid
	if use_terrain_cache and _art != null: # placeholder maps are tiny; drawn in full
		_build_terrain_cache(grid)


## True once the session has moved to another map: this view is being replaced
## and must not draw the new map's grid with this map's tables.
func _stale() -> bool:
	return session == null or session.grid() != _grid


func is_built_for(grid: GridModel) -> bool:
	return grid == _grid and not is_queued_for_deletion()


static func _pulse_ms() -> float:
	return 0.0 if freeze_pulses else float(Time.get_ticks_msec())


## Drawing from the terrain cache right now (not a placeholder map, not switched off).
func _cached() -> bool:
	return _cache_on and not _chunks.is_empty()


## Switches this view between the terrain cache and redrawing every tile (the
## screenshot test compares both on the same frame).
func set_terrain_cache(on: bool) -> void:
	_cache_on = on
	if _terrain_root != null:
		_terrain_root.visible = on
		for chunk in _chunks:
			chunk.queue_redraw()


func _process(delta: float) -> void:
	if _stale():
		return
	var hero: Actor = session.local_hero()
	if hero != null:
		camera.follow(actor_screen_pos(hero), delta)
	var t: float = session.render_time()
	_float_texts = _float_texts.filter(func(f): return t - f.t < FLOAT_TEXT_SECONDS)
	_update_terrain_cache()
	queue_redraw()


# --- Terrain cache ------------------------------------------------------------

## One chunk node per CHUNK_ROWS depth rows, in drawing order, under this node
## (z_index −1: drawn before it).
func _build_terrain_cache(grid: GridModel) -> void:
	var root := Node2D.new()
	root.name = "Terrain"
	_terrain_root = root
	root.z_index = -1
	add_child(root)
	for first in range(0, _max_depth + 1, CHUNK_ROWS):
		var chunk := Node2D.new()
		root.add_child(chunk)
		chunk.draw.connect(_draw_chunk.bind(chunk, first))
		_chunks.append(chunk)
	_heights_seen = grid.heights().duplicate()
	_max_height = _highest(_heights_seen)


func _draw_chunk(chunk: Node2D, first: int) -> void:
	if _stale():
		return
	var grid: GridModel = session.grid()
	for d in range(first, mini(first + CHUNK_ROWS, _max_depth + 1)):
		for p in _tiles_by_depth.get(d, []):
			_draw_tile(chunk, grid, p)


## Redraws the chunks whose heights changed.
func _update_terrain_cache() -> void:
	if _chunks.is_empty():
		return
	var grid: GridModel = session.grid()
	var heights := grid.heights()
	if heights != _heights_seen:
		for i in heights.size():
			if heights[i] != _heights_seen[i]:
				# The tile, and the ones just behind it (their hidden blocks depend on it).
				var d := Iso.depth(Vector2i(i % grid.width, i / grid.width))
				for row in [d - 1, d]:
					if row >= 0:
						_chunks[row / CHUNK_ROWS].queue_redraw()
		_heights_seen = heights.duplicate()
		_max_height = _highest(_heights_seen)


static func _highest(heights: PackedInt32Array) -> int:
	var m := 0
	for h in heights:
		m = maxi(m, h)
	return m


## A screen box holding everything drawn for a tile (blocks from level 0 up, the
## prop one level above the top, image margins), so a test against it never
## misses an overlap.
func _tile_bounds(grid: GridModel, p: Vector2i) -> Rect2:
	var c := Iso.to_screen(Vector2(p), 0.0)
	var top := c.y - (grid.height_at(p) + 1) * Iso.LEVEL_H - Iso.TILE_W * 0.5
	return Rect2(c.x - Iso.TILE_W * 0.5, top, Iso.TILE_W, c.y + Iso.TILE_W * 0.5 - top)


## Boxes (screen rects) where something is drawn over the cached terrain, with
## the first depth row it is drawn on. Overlapping boxes are merged, so no tile
## piece is drawn twice. [{"rect", "depth", "cover": {tile: true}}]
func _clusters(items: Array) -> Array:
	var out: Array = []
	for item in items:
		var c := {"rect": _snap_rect(item.rect), "depth": int(item.depth), "cover": {}}
		var merged := true
		while merged:
			merged = false
			for i in range(out.size() - 1, -1, -1):
				if out[i].rect.intersects(c.rect):
					c.rect = c.rect.merge(out[i].rect)
					c.depth = mini(c.depth, out[i].depth)
					out.remove_at(i)
					merged = true
		out.append(c)
	return out


## Outward to whole art pixels, so clipped tile images stay pixel-exact.
static func _snap_rect(r: Rect2) -> Rect2:
	var s := PixelCamera.ART_SCALE
	var from := (r.position / s).floor() * s
	var to := (r.end / s).ceil() * s
	return Rect2(from, to - from)


## Fills a cluster's `cover` with every tile from its first depth row on whose
## drawing overlaps its box: inside the box they are drawn again in order, over
## what the cluster draws, so the box ends up as the full redraw would paint it.
func _collect_cover(grid: GridModel, cluster: Dictionary, members: Dictionary) -> void:
	var rect: Rect2 = cluster.rect
	var half_w := Iso.TILE_W * 0.5
	var half_h := Iso.TILE_H * 0.5
	var u_min := floori((rect.position.x - half_w) / half_w)
	var u_max := ceili((rect.end.x + half_w) / half_w)
	var s_min := maxi(cluster.depth, floori((rect.position.y - half_w) / half_h))
	var s_max := mini(_max_depth, ceili((rect.end.y + half_w + (_max_height + 1) * Iso.LEVEL_H) / half_h))
	for s in range(s_min, s_max + 1):
		for u in range(u_min, u_max + 1):
			if (s + u) & 1:
				continue
			var p := Vector2i((s + u) / 2, (s - u) / 2)
			if grid.in_bounds(p) and _tile_bounds(grid, p).intersects(rect):
				cluster.cover[p] = true
				_add_member(members, p)


static func _add_member(members: Dictionary, p: Vector2i) -> void:
	var d := Iso.depth(p)
	if not members.has(d):
		members[d] = {}
	members[d][p] = true


## Everything _draw_actor can draw below the overlay (labels and bars come later).
func _actor_rect(a: Actor) -> Rect2:
	var feet := actor_screen_pos(a)
	var r := Rect2(feet - Vector2(34, 46), Vector2(68, 62))
	if a is Enemy and (a as Enemy).def.art != null:
		var art := (a as Enemy).def.art
		var s := PixelCamera.ART_SCALE
		r = r.merge(Rect2(feet - art.feet * s, Vector2(art.frame_size) * s))
	if a.is_large():
		var e := Vector2(Iso.TILE_W * 1.2 + 2, Iso.TILE_H * 1.2 + 2) # target ellipse
		r = r.merge(Rect2(feet - e, e * 2))
	return r


func _mark_rect(grid: GridModel, p: Vector2i) -> Rect2:
	var c := surface_point(grid, p)
	return Rect2(c - Vector2(Iso.TILE_W * 0.5 + 2, Iso.TILE_H * 0.5 + 2), Vector2(Iso.TILE_W + 4, Iso.TILE_H + 4))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.step_zoom(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.step_zoom(-1)


## Interpolated screen position of an actor's feet.
func actor_screen_pos(actor: Actor) -> Vector2:
	var grid: GridModel = session.grid()
	var m := actor.move
	var k := m.progress(session.render_time())
	var tile := Vector2(m.from_tile).lerp(Vector2(m.to_tile), k)
	var h := lerpf(grid.height_at(m.from_tile), grid.height_at(m.to_tile), k)
	return Iso.to_screen(tile, h)


## The map tile under a point (world coordinates), the highest one drawn there
## (null if none).
func tile_at(world_pos: Vector2) -> Variant:
	var grid: GridModel = session.grid()
	var best: Variant = null
	var best_depth := -1
	for h in range(HEIGHT_COLORS.size() + 8, -1, -1):
		var f := Iso.from_screen(world_pos, h)
		var t := Vector2i(roundi(f.x), roundi(f.y))
		if grid.in_bounds(t) and grid.height_at(t) == h and Iso.depth(t) > best_depth:
			best = t
			best_depth = Iso.depth(t)
	return best


## The actor drawn closest to a screen point (in world coordinates), or null.
func actor_at(world_pos: Vector2) -> Actor:
	var best: Actor = null
	var best_d := PICK_RADIUS
	for a in session.actors():
		var d := (actor_screen_pos(a) + Vector2(0, -14)).distance_to(world_pos)
		if d < best_d:
			best = a
			best_d = d
	return best


func _draw() -> void:
	if _stale():
		return
	var grid: GridModel = session.grid()
	var actors_by_tile := {}
	# Draw-order constraints inside a depth row: tile -> tiles that must be drawn
	# (with their actors) before it.
	var after := {}
	var t_now: float = session.render_time()
	for a in session.actors():
		var t := _draw_anchor(a)
		if not actors_by_tile.has(t):
			actors_by_tile[t] = []
		actors_by_tile[t].append(a)
		if not a.move.is_moving(t_now):
			continue
		var other: Vector2i = a.move.from_tile if t == a.move.to_tile else a.move.to_tile
		if Iso.depth(other) == Iso.depth(t):
			_must_follow(after, t, other) # a sideways push: both tiles go under it
		else:
			# It straddles `other` (one row back): the tiles of this row in front of
			# `other`, e.g. a wall beside it, must cover it, even with someone on them.
			for q in [other + Vector2i(1, 0), other + Vector2i(0, 1)]:
				if q != t and Iso.depth(q) == Iso.depth(t):
					_must_follow(after, q, t)
	var quest_areas := _quest_area_tiles()
	var marks := _tile_marks()
	_overlay.clear()
	_labels.clear()
	if not _cached():
		for d in range(_max_depth + 1):
			# Tiles in one depth row never overlap each other, so each tile can be drawn
			# with the actors on it, in any order that keeps the constraints above.
			for p in _row_order(_tiles_by_depth.get(d, []), after):
				_draw_tile_with_marks(grid, p, quest_areas, marks)
				for a in actors_by_tile.get(p, []):
					_draw_actor(a)
	else:
		_draw_over_cache(grid, actors_by_tile, after, quest_areas, marks)
	_draw_projectiles(grid)
	_draw_flames(grid)
	_draw_landmarks(grid)
	_draw_talk_prompt()
	for f in _overlay:
		f.call()
	_queue_float_texts()
	_draw_labels()


## With the terrain cached underneath: the same back-to-front pass, limited to
## the tiles carrying actors or highlights and the tiles that cover them.
func _draw_over_cache(grid: GridModel, actors_by_tile: Dictionary, after: Dictionary, quest_areas: Dictionary,
		marks: Dictionary) -> void:
	var members := {} # depth -> {tile: true}: what this pass visits
	var items := []
	for p in actors_by_tile:
		_add_member(members, p)
		for a in actors_by_tile[p]:
			items.append({"rect": _actor_rect(a), "depth": Iso.depth(p)})
	for p in marks.keys() + quest_areas.keys():
		_add_member(members, p)
		items.append({"rect": _mark_rect(grid, p), "depth": Iso.depth(p)})
	var clusters := _clusters(items)
	for c in clusters:
		_collect_cover(grid, c, members)
	var rows := members.keys()
	rows.sort()
	for d in rows:
		var row: Array = members[d].keys()
		row.sort_custom(func(a, b): return _row_index[a] < _row_index[b])
		for p in _row_order(row, after):
			for c in clusters:
				if c.cover.has(p):
					_draw_tile(self, grid, p, c.rect)
			if quest_areas.has(p):
				_draw_quest_area(grid, p, quest_areas[p])
			for color in marks.get(p, []):
				_draw_tile_mark(grid, p, color)
			for a in actors_by_tile.get(p, []):
				_draw_actor(a)


static func _must_follow(after: Dictionary, tile: Vector2i, first: Vector2i) -> void:
	if not after.has(tile):
		after[tile] = []
	after[tile].append(first)


## The row's tiles in their usual order, moved only as needed so every tile comes
## after the tiles `after` lists for it (a cycle is broken arbitrarily).
static func _row_order(row: Array, after: Dictionary) -> Array:
	if after.is_empty():
		return row
	var out := []
	var state := {} # 1 = visiting, 2 = done
	var in_row := {}
	for p in row:
		in_row[p] = true
	var visit := func(p: Vector2i, visit: Callable) -> void:
		if state.get(p, 0) != 0:
			return
		state[p] = 1
		for q in after.get(p, []):
			if in_row.has(q):
				visit.call(q, visit)
		state[p] = 2
		out.append(p)
	for p in row:
		visit.call(p, visit)
	return out


func _draw_tile_with_marks(grid: GridModel, p: Vector2i, quest_areas: Dictionary, marks: Dictionary) -> void:
	_draw_tile(self, grid, p)
	if quest_areas.has(p):
		_draw_quest_area(grid, p, quest_areas[p])
	for color in marks.get(p, []):
		_draw_tile_mark(grid, p, color)


## The tile an actor is drawn with. Standing: its own tile. Walking: the
## nearer-to-camera of the two tiles it straddles (the other one is in an earlier
## row), so neither covers its feet, while the rest of that row (e.g. a wall beside
## it, in front of where it is heading) still hides it. Ties: sideways pushes.
func _draw_anchor(a: Actor) -> Vector2i:
	var m := a.move
	if not m.is_moving(session.render_time()):
		return m.to_tile
	var df := Iso.depth(m.from_tile)
	var dt := Iso.depth(m.to_tile)
	if df != dt:
		return m.from_tile if df > dt else m.to_tile
	return m.to_tile


## Draws a tile on `canvas` (this view, or a terrain chunk); with `clip`, only
## the part inside that box (tileset maps only).
func _draw_tile(canvas: CanvasItem, grid: GridModel, p: Vector2i, clip := Rect2()) -> void:
	if _art != null:
		_draw_terrain_column(canvas, grid, p, clip)
		return
	var h := grid.height_at(p)
	var walkable := grid.is_walkable(p)
	var top_color: Color
	if not walkable and h == 0:
		top_color = COLOR_WATER
	elif not walkable:
		top_color = COLOR_ROCK
	elif _graveyards.has(p):
		top_color = COLOR_GRAVEYARD
	else:
		top_color = HEIGHT_COLORS[mini(h, HEIGHT_COLORS.size() - 1)]
	var c := Iso.to_screen(Vector2(p), h)
	var hw := Iso.TILE_W * 0.5
	var hh := Iso.TILE_H * 0.5
	var top := c + Vector2(0, -hh)
	var right := c + Vector2(hw, 0)
	var bottom := c + Vector2(0, hh)
	var left := c + Vector2(-hw, 0)
	var drop := Vector2(0, h * Iso.LEVEL_H + 6.0)
	canvas.draw_colored_polygon(PackedVector2Array([left, bottom, bottom + drop, left + drop]), top_color.darkened(0.35))
	canvas.draw_colored_polygon(PackedVector2Array([bottom, right, right + drop, bottom + drop]), top_color.darkened(0.5))
	canvas.draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), top_color)
	canvas.draw_polyline(PackedVector2Array([top, right, bottom, left, top]), top_color.darkened(0.2), 1.0)
	if _graveyards.has(p):
		canvas.draw_line(c + Vector2(0, -12), c + Vector2(0, 4), Color.WHITE, 2.0)
		canvas.draw_line(c + Vector2(-5, -7), c + Vector2(5, -7), Color.WHITE, 2.0)


## A tiled zone's tile: its stack of blocks, bottom first, then its prop. Blocks
## the tiles in front fully cover are skipped (they would be drawn over anyway).
func _draw_terrain_column(canvas: CanvasItem, grid: GridModel, p: Vector2i, clip := Rect2()) -> void:
	var h := grid.height_at(p)
	var front := mini(_front_height(grid, p + Vector2i(1, 0)), _front_height(grid, p + Vector2i(0, 1)))
	var terrain := _zone.terrain_at(p)
	# With the terrain cache, water animates by itself (TileArt.animated_texture).
	var live := _cached()
	var anim: String = str(_art.data.terrains.get(terrain, {}).get("animation", "")) if live else ""
	for block in _art.column(terrain, p, h, front, _land_sides(p), session.render_time()):
		var at := Iso.to_screen(Vector2(p), block[1])
		if anim != "" and block[1] == h:
			_art.draw_texture(canvas, _art.animated_texture(anim, p), at, Color.WHITE, clip)
		else:
			_art.draw(canvas, block[0], at, Color.WHITE, clip)
	if _art.data.is_water_terrain(terrain):
		if live:
			_art.draw_texture(canvas, _art.sparkle_texture(p), Iso.to_screen(Vector2(p), h), Color.WHITE, clip)
		else:
			var sparkle := _art.sparkle_frame(p, session.render_time())
			if sparkle >= 0:
				_art.draw(canvas, sparkle, Iso.to_screen(Vector2(p), h))
	# The prop goes with its tile, so the tiles in front still cover what's behind
	# a boulder, and a unit behind it is hidden by it.
	var group := _zone.prop_at(p)
	if group != "":
		_art.draw_prop(canvas, _art.data.pick_prop(group, p), p, h, clip)
	if _graveyards.has(p):
		var c := Iso.to_screen(Vector2(p), h)
		# Drawn as thin boxes so a clip can cut them exactly.
		for r in [Rect2(c + Vector2(-1, -12), Vector2(2, 16)), Rect2(c + Vector2(-5, -8), Vector2(10, 2))]:
			var part: Rect2 = r if not clip.has_area() else r.intersection(clip)
			if part.has_area():
				canvas.draw_rect(part, Color.WHITE)


## Sides of a water tile that touch land (for shoreline foam); map edges count
## as water.
func _land_sides(p: Vector2i) -> Array:
	var out := []
	if not _art.data.is_water_terrain(_zone.terrain_at(p)):
		return out
	for side in TilesetData.SIDES:
		var n: Vector2i = p + TilesetData.SIDES[side]
		var t := _zone.terrain_at(n)
		if t != "" and not _art.data.is_water_terrain(t):
			out.append(side)
	return out


## The centre of a tile's visible top: water surfaces sit a little lower.
func surface_point(grid: GridModel, p: Vector2i) -> Vector2:
	var c := Iso.to_screen(Vector2(p), grid.height_at(p))
	if _art != null:
		var terrain := _zone.terrain_at(p)
		if _art.data.is_water_terrain(terrain) and _zone.prop_at(p) == "":
			c.y += _art.data.surface_drop(_art.top_tile(terrain, p, _land_sides(p))) * PixelCamera.ART_SCALE
	return c


func _front_height(grid: GridModel, p: Vector2i) -> int:
	return grid.height_at(p) if grid.in_bounds(p) else -1


func _draw_actor(a: Actor) -> void:
	var feet := actor_screen_pos(a)
	var now: float = session.now()
	var is_target := client != null and client.target_id == a.id
	if is_target:
		if a.is_large():
			_draw_ellipse(feet, Iso.TILE_W * 1.2, Iso.TILE_H * 1.2, Color(1, 0.9, 0.2), 2.0) # around its whole body
		else:
			_draw_ellipse(feet, 20, 9, Color(1, 0.9, 0.2), 2.0)
	var body := feet + Vector2(0, -14)
	var alpha := 0.45 if a.evading else 1.0
	var animated := (a is Enemy and (a as Enemy).def.art != null) or (a is Npc and (a as Npc).def.art != null)
	if a.alive and not animated: # animated creatures show their facing themselves
		_draw_facing(feet, a.facing, Color(1, 1, 1, 0.85 * alpha))
	if a is Hero:
		var color: Color = HERO_COLORS[(a.id - 1) % HERO_COLORS.size()]
		if not a.alive:
			draw_line(feet + Vector2(-8, -8), feet + Vector2(8, 4), Color(0.6, 0.6, 0.6), 3.0)
			draw_line(feet + Vector2(-8, 4), feet + Vector2(8, -8), Color(0.6, 0.6, 0.6), 3.0)
		else:
			draw_circle(body, 11, color)
			var outline := Color(1, 0.25, 0.2) if a.in_combat(now) else Color(0.05, 0.05, 0.1)
			draw_arc(body, 11, 0, TAU, 24, outline, 2.0)
		_draw_label(body + Vector2(0, -22), "%s  Lv%d" % [a.display_name, (a as Hero).level], Color.WHITE)
	elif a is Npc:
		_draw_npc(a as Npc, feet, body)
		return
	else:
		var edef := (a as Enemy).def
		if not a.alive:
			if edef.art != null:
				_draw_creature(a as Enemy, feet, alpha) # dying, then the corpse fades
			return
		var c := Color(ENEMY_COLOR, alpha)
		if edef.art != null and _draw_creature(a as Enemy, feet, alpha):
			var top := feet - Vector2(0, (edef.art.feet.y - edef.art.head_y) * PixelCamera.ART_SCALE)
			if edef.elite:
				_draw_label(top + Vector2(0, -16), "Elite %s  Lv%d" % [a.display_name, (a as Enemy).level], Color(1, 0.85, 0.3, alpha))
			else:
				_draw_label(top + Vector2(0, -16), "%s  Lv%d" % [a.display_name, (a as Enemy).level], Color(1, 0.8, 0.8, alpha))
			_draw_bar(top + Vector2(-14, -10), 28, a.hp / maxf(a.current_stats(now).hp, 1.0), Color(0.2, 0.85, 0.3))
			_draw_cast_bar(a, feet, now)
			if edef.flying and not (a as Enemy).airborne(now):
				_draw_label(feet + Vector2(0, 22), "Grounded", Color(1, 0.9, 0.4), 11) # knocked out of the air
			return
		if edef.training_dummy:
			_draw_dummy(feet, alpha)
			_draw_label(body + Vector2(0, -26), a.display_name, Color(1, 0.9, 0.75, alpha))
			if a.alive:
				_draw_bar(body + Vector2(-14, -20), 28, a.hp / maxf(a.current_stats(now).hp, 1.0), Color(0.2, 0.85, 0.3))
			return
		var s := 1.6 if edef.elite else 1.0
		var diamond := PackedVector2Array([body + Vector2(0, -12) * s, body + Vector2(10, 0) * s,
				body + Vector2(0, 12) * s, body + Vector2(-10, 0) * s])
		draw_colored_polygon(diamond, c)
		if edef.elite:
			diamond.append(diamond[0])
			draw_polyline(diamond, Color(1, 0.8, 0.2, alpha), 2.0)
			_draw_label(body + Vector2(0, -32), "Elite %s  Lv%d" % [a.display_name, (a as Enemy).level], Color(1, 0.85, 0.3, alpha))
		else:
			_draw_label(body + Vector2(0, -26), "%s  Lv%d" % [a.display_name, (a as Enemy).level], Color(1, 0.8, 0.8, alpha))
	if a.alive:
		var max_hp := a.current_stats(now).hp
		_draw_bar(body + Vector2(-14, -20), 28, a.hp / maxf(max_hp, 1.0), Color(0.2, 0.85, 0.3))
		_draw_cast_bar(a, feet, now)


## Draws an animated creature standing on `feet`; false if it has nothing to show.
func _draw_creature(e: Actor, feet: Vector2, alpha: float, art: CreatureArtDef = null) -> bool:
	if art == null:
		art = (e as Enemy).def.art
	var pick := _animator.pick(e, art, session.render_time())
	if pick.is_empty():
		return false
	if not _frames_cache.has(art):
		var sheets: Dictionary = CreatureRecolor.sheets(art, get_tree().root) if art.recolor else {}
		_frames_cache[art] = [art.build_sprite_frames(sheets), art.build_sprite_frames(art.flash_sheets) if not art.flash_sheets.is_empty() else null]
	var frames: SpriteFrames = _frames_cache[art][0]
	var name := StringName("%s_%s" % [pick.anim, pick.dir])
	if not frames.has_animation(name):
		return false
	var tex := frames.get_frame_texture(name, mini(pick.frame, frames.get_frame_count(name) - 1))
	var s := PixelCamera.ART_SCALE
	var color := Color(1, 1, 1, alpha * float(pick.get("alpha", 1.0)))
	var now: float = session.now()
	if e is Enemy and e.alive and e.def.enrage_buff != null and e.buffs.has(e.def.enrage_buff.id, now):
		color = Color(ENRAGE_TINT, color.a) # Molten Fury: glowing hotter
	var rect := Rect2(feet - art.feet * s, Vector2(art.frame_size) * s)
	draw_texture_rect(tex, rect, false, color)
	if session.render_time() < float(_flash_until.get(e.id, -1.0)):
		# Hit flash: no hit animation exists, so the body flashes white. The
		# shadowless frame drawn with colours above 1 saturates to white.
		var plain: SpriteFrames = _frames_cache[art][1]
		var body := plain.get_frame_texture(name, mini(pick.frame, plain.get_frame_count(name) - 1)) if plain != null else tex
		draw_texture_rect(body, rect, false, Color(FLASH_STRENGTH, FLASH_STRENGTH, FLASH_STRENGTH, color.a))
	return true


## An NPC, quest board, object or caravan. With art (NpcDef.art) it is drawn like
## the creatures; until then, a shape for its kind in its faction's colour. Then
## its name, its quest marker, and a health bar while escorted or hurt.
func _draw_npc(npc: Npc, feet: Vector2, body: Vector2) -> void:
	if not npc.alive:
		return # a lost caravan is gone until it is back home
	var def := npc.def
	var c := def.color()
	var ink := Color(0.1, 0.08, 0.02)
	var top := body + Vector2(0, -22)
	if def.art != null and _draw_creature(npc, feet, 1.0, def.art):
		top = feet - Vector2(0, (def.art.feet.y - def.art.head_y) * PixelCamera.ART_SCALE) + Vector2(0, -6)
	else:
		match def.kind:
			NpcDef.Kind.BOARD:
				# A notice board on two posts, with pinned notes.
				for x in [-12.0, 10.0]:
					draw_rect(Rect2(feet + Vector2(x, -26), Vector2(3, 26)), Color(0.35, 0.24, 0.12))
				var board := Rect2(feet + Vector2(-17, -40), Vector2(34, 20))
				draw_rect(board, c.darkened(0.15))
				draw_rect(board, ink, false, 2.0)
				for n in 3:
					draw_rect(Rect2(board.position + Vector2(4 + n * 10, 4 + (n % 2) * 3), Vector2(7, 9)),
							Color(0.95, 0.9, 0.78))
				top = feet + Vector2(0, -48)
			NpcDef.Kind.OBJECT:
				# Something to examine: a small block with a glint.
				var box := Rect2(feet + Vector2(-10, -16), Vector2(20, 16))
				draw_rect(box, c)
				draw_rect(box, ink, false, 2.0)
				draw_line(box.position, box.end, ink.lightened(0.2), 1.0)
				draw_circle(feet + Vector2(5, -12), 2.0, Color(1, 1, 0.85))
				top = feet + Vector2(0, -26)
			NpcDef.Kind.CARAVAN:
				# A covered wagon: bed, canvas and two wheels.
				draw_rect(Rect2(feet + Vector2(-20, -18), Vector2(40, 10)), Color(0.45, 0.3, 0.15))
				draw_colored_polygon(PackedVector2Array([feet + Vector2(-17, -18), feet + Vector2(-13, -34),
						feet + Vector2(13, -34), feet + Vector2(17, -18)]), c)
				draw_polyline(PackedVector2Array([feet + Vector2(-17, -18), feet + Vector2(-13, -34),
						feet + Vector2(13, -34), feet + Vector2(17, -18)]), ink, 2.0)
				for x in [-12.0, 12.0]:
					draw_circle(feet + Vector2(x, -6), 6.0, ink)
					draw_circle(feet + Vector2(x, -6), 3.0, Color(0.55, 0.4, 0.2))
				top = feet + Vector2(0, -42)
			_:
				# A person: body and head.
				draw_rect(Rect2(body - Vector2(8, 4), Vector2(16, 18)), c)
				draw_rect(Rect2(body - Vector2(8, 4), Vector2(16, 18)), ink, false, 2.0)
				draw_circle(body + Vector2(0, -10), 7.0, c.lightened(0.25))
				draw_arc(body + Vector2(0, -10), 7.0, 0, TAU, 20, ink, 2.0)
				top = body + Vector2(0, -24)
	_draw_label(top, npc.display_name, c.lerp(Color.WHITE, 0.7))
	if npc.escorting or npc.hp < npc.stats.hp - 0.01:
		_draw_bar(top + Vector2(-14, 4), 28, npc.hp / maxf(npc.stats.hp, 1.0), Color(0.2, 0.85, 0.3))
	var marker: String = client.npc_markers.get(def.id, "") if client != null else ""
	if marker != "":
		_draw_label(top + Vector2(0, -14), marker, Color(1, 0.85, 0.1), 20)
	_draw_cast_bar(npc, feet, session.now())


## A training dummy: a straw mannequin on a wooden post with a crossbar for arms.
func _draw_dummy(feet: Vector2, alpha: float) -> void:
	var wood := Color(0.45, 0.28, 0.14, alpha)
	var straw := Color(0.86, 0.72, 0.42, alpha)
	var dark := Color(0.2, 0.12, 0.06, alpha)
	draw_set_transform(feet + Vector2(0, 1), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 9, Color(0, 0, 0, 0.3 * alpha)) # shadow
	draw_set_transform(Vector2.ZERO)
	draw_line(feet, feet + Vector2(0, -8), wood, 3.0) # post
	draw_line(feet + Vector2(-11, -18), feet + Vector2(11, -18), wood, 3.0) # arms
	var torso := Rect2(feet + Vector2(-6, -23), Vector2(12, 16))
	draw_rect(torso, straw)
	draw_rect(torso, dark, false, 1.0)
	draw_line(feet + Vector2(-6, -15), feet + Vector2(6, -15), dark, 1.0) # rope belt
	draw_circle(feet + Vector2(0, -28), 5, straw) # head
	draw_arc(feet + Vector2(0, -28), 5, 0, TAU, 16, dark, 1.0)


## A bar under a unit that is casting (yellow), winding up (red) or channelling
## (blue), filling as it goes.
func _draw_cast_bar(a: Actor, feet: Vector2, now: float) -> void:
	var c: Dictionary = a.casting
	if c.is_empty() or not c.has("end"):
		return
	# Your own timing bar is drawn big by the HUD (TimingBarView); others see this one.
	if c.get("kind", "") == "timing" and a.id == session.local_hero_id:
		return
	var span := maxf(float(c.end) - float(c.get("start", c.end)), 0.01)
	var done := clampf((now - float(c.get("start", now))) / span, 0.0, 1.0)
	var color: Color = {"cast": Color(1, 0.85, 0.2), "windup": Color(1, 0.3, 0.2), "channel": Color(0.4, 0.7, 1),
			"timing": Color(0.3, 0.9, 0.4)}.get(
			c.get("kind", "cast"), Color.WHITE)
	_draw_bar(feet + Vector2(-16, 8), 32, done, color)
	var ability = c.get("ability")
	if ability is AbilityDef:
		_draw_label(feet + Vector2(0, 22), ability.display_name, color, 10)


## Projectiles: a glowing ball moving along its path at the origin's height.
## Heroes' are orange, enemies' purple.
func _draw_projectiles(grid: GridModel) -> void:
	var t: float = session.render_time()
	for p in session.projectiles():
		# Straight from where it was cast toward the end of its path (any angle).
		var dist := clampf((t - p.start) * p.speed, 0.0, p.length + 0.5)
		var origin := Vector2(p.origin)
		var to_end := Vector2(p.get("end", p.origin)) - origin
		var steps := maxf(float(p.length), 1.0)
		var pos := origin + (to_end / steps * dist if to_end.length_squared() > 0.0 else Vector2(p.dir) * dist)
		var screen := Iso.to_screen(pos, grid.height_at(p.origin)) + Vector2(0, -16)
		if session.get_actor(p.source) is Enemy:
			draw_circle(screen, 8, Color(0.6, 0.2, 0.9, 0.5))
			draw_circle(screen, 5, Color(0.85, 0.6, 1.0))
		else:
			_draw_fireball(screen)


## The fire glow heroes' projectiles use; flames (Sunfire Breath) are made of them.
func _draw_fireball(at: Vector2, size: float = 1.0, alpha: float = 1.0) -> void:
	draw_circle(at, 8 * size, Color(1, 0.45, 0.1, 0.5 * alpha))
	draw_circle(at, 5 * size, Color(1, 0.85, 0.3, alpha))


## Flames over the tiles a fiery ability just hit (AbilityDef.flame_effect):
## a few fireballs per tile rising and fading for FLAME_SECONDS.
func _draw_flames(grid: GridModel) -> void:
	var t: float = session.render_time()
	var live: Array = []
	for f in _flames:
		var age: float = t - f.start
		if age > FLAME_SECONDS:
			continue
		live.append(f)
		var k := age / FLAME_SECONDS
		for tile in f.tiles:
			var base := surface_point(grid, tile)
			for i in 3:
				var h := TilesetData.cell_hash(tile, 50 + i)
				var off := Vector2(float(h % 29) - 14.0, float((h >> 5) % 11) - 5.0)
				var rise := (12.0 + 10.0 * i) * k + 4.0 * sin(t * 18.0 + i)
				_draw_fireball(base + off + Vector2(0, -6 - rise), 1.3 - 0.5 * k, 1.0 - k)
	_flames = live


## A small arrow on the ground pointing the way the actor faces.
func _draw_facing(feet: Vector2, facing: Vector2i, color: Color) -> void:
	var d := Iso.to_screen(Vector2(facing), 0.0).normalized()
	var side := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([feet + d * 22, feet + d * 12 + side * 6, feet + d * 12 - side * 6]), color)


func _draw_bar(pos: Vector2, width: float, fraction: float, color: Color) -> void:
	_overlay.append(func(): _draw_bar_now(pos, width, fraction, color))


func _draw_bar_now(pos: Vector2, width: float, fraction: float, color: Color) -> void:
	draw_rect(Rect2(pos, Vector2(width, 4)), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(pos, Vector2(width * clampf(fraction, 0, 1), 4)), color)


## Queues a centred label (baseline at `pos`) for the label pass.
func _draw_label(pos: Vector2, text: String, color: Color, size: int = 11, boxed: bool = false) -> void:
	_labels.append({"pos": pos, "text": text, "color": color, "size": size, "boxed": boxed})


## Draws queued labels from the bottom of the screen up; a label that would
## overlap one already placed moves up just above it.
func _draw_labels() -> void:
	_labels.sort_custom(func(a, b): return a.pos.y > b.pos.y)
	var placed: Array[Rect2] = []
	for l in _labels:
		var w: float = _font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.size).x + (12.0 if l.boxed else 2.0)
		var h: float = l.size + (8.0 if l.boxed else 3.0)
		var rect := Rect2(l.pos.x - w * 0.5, l.pos.y - l.size - (4.0 if l.boxed else 1.0), w, h)
		for i in 8:
			var hit := -1
			for j in placed.size():
				if placed[j].intersects(rect):
					hit = j
					break
			if hit < 0:
				break
			rect.position.y = placed[hit].position.y - rect.size.y
		placed.append(rect)
		var pos := Vector2(l.pos.x, rect.position.y + float(l.size) + (4.0 if l.boxed else 1.0))
		if l.boxed:
			draw_rect(rect, Color(0, 0, 0, 0.7))
			draw_rect(rect, Color(1, 0.85, 0.3), false, 1.0)
		_draw_label_now(pos, l.text, l.color, l.size)


func _draw_label_now(pos: Vector2, text: String, color: Color, size: int = 11) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(_font, pos - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color.BLACK)
	draw_string(_font, pos - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var ang := TAU * i / 32.0
		pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_polyline(pts, color, width)


## Floating combat texts join the label pass so they don't cover names or
## other actors' texts.
func _queue_float_texts() -> void:
	var t: float = session.render_time()
	for f in _float_texts:
		var actor: Actor = session.get_actor(f.actor)
		if actor == null:
			continue
		var age: float = (t - f.t) / FLOAT_TEXT_SECONDS
		var pos := actor_screen_pos(actor) + Vector2(0, -62 - age * 12 - f.row * 15)
		_draw_label(pos, f.text, Color(f.color, 1.0 - age), 12)


func _on_events(events: Array) -> void:
	var t: float = session.render_time()
	for e in events:
		match e.type:
			"damage":
				var flank: String = e.get("flank", "")
				var text: String = ("%d!" if e.crit else "%d") % e.amount
				if flank == "behind":
					text = "Backstab " + text
				elif flank == "side":
					text = "Flank " + text
				_float(e.target, text, Color(1, 0.35, 0.3), t)
				var hit = session.get_actor(e.target)
				if hit is Enemy and (hit as Enemy).def.art != null:
					_flash_until[e.target] = t + (hit as Enemy).def.art.flash_seconds
			"heal":
				_float(e.target, ("+%d!" if e.crit else "+%d") % e.amount, Color(0.4, 1, 0.4), t)
			"mana":
				_float(e.target, "+%d mana" % e.amount, Color(0.45, 0.6, 1), t)
			"miss":
				_float(e.target, "Miss", Color(0.8, 0.8, 0.8), t)
			"whiff":
				_float(e.source, "Whiff", Color(0.75, 0.75, 0.75), t)
			"level_up":
				_float(e.target, "Level %d!" % e.level, Color(1, 0.9, 0.3), t)
			"mastered":
				_float(e.target, "Mastered %s!" % e.ability, Color(0.6, 0.8, 1), t)
			"evade":
				_float(e.target, "Evade", Color(0.8, 0.8, 0.8), t)
			"cast":
				var ability: AbilityDef = ContentDB.abilities.get(e.get("ability", &""))
				if ability != null and ability.flame_effect and e.has("tiles"):
					_flames.append({"tiles": e.tiles, "start": t})
			"grounded":
				_float(e.target, "Grounded!", Color(1, 0.9, 0.4), t)
			"enrage":
				var buff: BuffDef = ContentDB.buffs.get(e.get("buff", &""))
				_float(e.target, "%s!" % (buff.display_name if buff != null else "Enraged"), Color(1, 0.55, 0.15), t)


## A new text on an actor appears at the bottom of its stack and pushes the
## older ones up a row, so they never overlap.
func _float(actor_id: int, text: String, color: Color, t: float) -> void:
	for f in _float_texts:
		if f.actor == actor_id:
			f.row += 1
	_float_texts.append({"actor": actor_id, "text": text, "color": color, "t": t, "row": 0})


## Tiles inside the target area of the local hero's unfinished REACH objectives
## in this zone, so "Find the bandit camp" shows where to go.
func _quest_area_tiles() -> Dictionary:
	var out := {}
	var hero: Hero = session.local_hero()
	if hero == null:
		return out
	var zone_id: StringName = session.zone().id
	for def in QuestText.active_quests(hero, ContentDB.quests):
		for i in def.objectives.size():
			var o: QuestObjective = def.objectives[i]
			if o.kind != QuestObjective.Kind.REACH or o.zone != zone_id \
					or QuestLog.progress(hero, def, i) >= o.needed():
				continue
			for y in range(o.tile.y - o.radius, o.tile.y + o.radius + 1):
				for x in range(o.tile.x - o.radius, o.tile.x + o.radius + 1):
					var p := Vector2i(x, y)
					if GridModel.distance(p, o.tile) <= o.radius and session.grid().is_walkable(p):
						out[p] = true
		# An escort's destination glows like a place to reach.
		var e := def.escort_objective()
		if e >= 0 and def.objectives[e].zone == zone_id and QuestLog.progress(hero, def, e) < 1:
			out[def.objectives[e].path[-1]] = true
	# Spots to investigate glow differently (a pulsing ring).
	for p in QuestLog.open_spots(hero, ContentDB.quests, zone_id):
		out[p] = SPOT
	return out


## Highlights per tile: tile -> [Color]. Ground zones, then enemy telegraphs
## (brighter as they're about to land), then the local player's aim on top.
func _tile_marks() -> Dictionary:
	var marks := {}
	var now: float = session.now()
	for z in session.ground_zones():
		for t in z.tiles:
			_mark(marks, t, ZONE_COLOR)
	# Large bodies (Sunscale Drake) show the tiles they cover: their hitbox.
	for a in session.actors():
		if a is Enemy and a.alive and a.is_large():
			for t in a.tiles():
				_mark(marks, t, BODY_COLOR)
	for h in session.telegraphs():
		var left := clampf(float(h.at) - now, 0.0, 1.5)
		var c := Color(TELEGRAPH_COLOR, 0.65 - 0.3 * left / 1.5 + 0.1 * sin(_pulse_ms() / 80.0))
		for t in h.tiles:
			_mark(marks, t, c)
	if client != null and not client.aim.is_empty():
		var c := AIM_COLOR if client.aim.valid else AIM_BAD_COLOR
		for t in client.aim.tiles:
			_mark(marks, t, c)
	return marks


static func _mark(marks: Dictionary, tile: Vector2i, color: Color) -> void:
	if not marks.has(tile):
		marks[tile] = []
	marks[tile].append(color)


func _draw_tile_mark(grid: GridModel, p: Vector2i, color: Color) -> void:
	var c := surface_point(grid, p)
	var hw := Iso.TILE_W * 0.5 - 3
	var hh := Iso.TILE_H * 0.5 - 1.5
	var pts := PackedVector2Array([c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(-hw, 0)])
	draw_colored_polygon(pts, color)
	pts.append(pts[0])
	# A dark rim under the bright edge keeps marks readable on light grass.
	draw_polyline(pts, Color(0.05, 0.05, 0.1, 0.6), 3.5)
	draw_polyline(pts, Color(color.lightened(0.25), minf(color.a + 0.4, 1.0)), 1.5)


func _draw_quest_area(grid: GridModel, p: Vector2i, kind: Variant = true) -> void:
	var c := surface_point(grid, p)
	var pulse := 0.5 + 0.2 * sin(_pulse_ms() / 250.0)
	if kind is String and kind == SPOT:
		# An investigate spot: a glowing ring with a "?" over it.
		var r := 10.0 + 3.0 * sin(_pulse_ms() / 200.0)
		_draw_ellipse(c, r * 1.6, r * 0.8, Color(0.55, 0.95, 1.0, 0.9), 2.5)
		_draw_ellipse(c, r * 0.9, r * 0.45, Color(0.85, 1.0, 1.0, 0.7), 1.5)
		_draw_label(c + Vector2(0, -14), "?", Color(0.7, 1.0, 1.0), 16)
		return
	var hw := Iso.TILE_W * 0.5 - 4
	var hh := Iso.TILE_H * 0.5 - 2
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh),
			c + Vector2(-hw, 0)]), Color(1, 0.85, 0.2, pulse))
	draw_polyline(PackedVector2Array([c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh),
			c + Vector2(-hw, 0), c + Vector2(0, -hh)]), Color(1, 0.95, 0.5, 0.9), 1.5)


## Named places: a banner on a pole and the name in gold.
func _draw_landmarks(grid: GridModel) -> void:
	for lm in _landmarks:
		var base := Iso.to_screen(Vector2(lm.tile), grid.height_at(lm.tile))
		draw_line(base, base + Vector2(0, -34), Color(0.35, 0.25, 0.15), 3.0)
		draw_colored_polygon(PackedVector2Array([base + Vector2(1, -34), base + Vector2(18, -29),
				base + Vector2(1, -24)]), Color(0.75, 0.2, 0.15))
		_draw_label(base + Vector2(0, -40), lm.name, Color(1, 0.85, 0.3), 14)


## "[E] Talk" over the townsperson E would talk to ("[E] Use" on objects,
## "[E] Examine" on a quest spot), and speech bubbles from other players'
## conversations.
func _draw_talk_prompt() -> void:
	if client != null:
		var bubbles := client.live_bubbles()
		for id in bubbles:
			var speaker: Actor = session.get_actor(id)
			if speaker != null:
				_draw_label(actor_screen_pos(speaker) + Vector2(0, -86), "\u201c%s\u201d" % bubbles[id].text,
						Color(1, 1, 0.92), 12, true)
	var what := PlayerInput.interaction(session)
	if what.is_empty():
		return
	if what.kind == "examine":
		_draw_label(surface_point(session.grid(), what.tile) + Vector2(0, -34), "[E] Examine", Color(0.75, 1, 1), 13, true)
		return
	var npc: Npc = what.npc
	var marker: String = client.npc_markers.get(npc.def.id, "") if client != null else ""
	var y := -70.0 if marker != "" else -54.0
	var verb := "Use" if npc.def.kind == NpcDef.Kind.OBJECT else ("Read" if npc.def.kind == NpcDef.Kind.BOARD else "Talk")
	_draw_label(actor_screen_pos(npc) + Vector2(0, y), "[E] %s" % verb, Color(1, 0.95, 0.6), 13, true)
