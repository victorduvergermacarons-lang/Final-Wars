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
## Placeholder objects show their labels within this many tiles of your hero.
const DECOR_LABEL_TILES := 12
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
## Effect animations (FxDef): played from "fx" events, held rocks, thrown rocks.
var _fx := FxPainter.new()
## Every hero's Water stance 1 rope on this screen (the Water Whip), stepped at 60 Hz.
var ropes := WaterRopes.new()
var _rope_t := -1.0
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
	_build_sense_overlay()
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
	_update_sense(t)
	queue_redraw()


## The water ropes: a fixed 60 steps per second of game time (the render clock runs
## at the game speed), in _physics_process as the reference was tuned.
func _physics_process(_delta: float) -> void:
	if _stale():
		return
	var t: float = session.render_time()
	var dt := clampf(t - _rope_t, 0.0, 0.25) if _rope_t >= 0.0 else 0.0
	_rope_t = t
	var heroes: Array = session.actors().filter(func(a): return a is Hero)
	var seen := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	seen = seen.grow(320.0)
	ropes.advance(dt, t, heroes, session.grid(), session.zone(), func(h): return seen.has_point(actor_screen_pos(h)),
			session.rules().water_near_tiles)


# --- Seismic Sense (a screen shader) -------------------------------------------

var _sense_layer: CanvasLayer
var _sense_rect: ColorRect
const SENSE_RINGS := 3
const SENSE_FADE := 0.6


func _build_sense_overlay() -> void:
	_sense_layer = CanvasLayer.new()
	_sense_layer.layer = 1 # over the world, under the HUD (added after the view)
	add_child(_sense_layer)
	_sense_rect = ColorRect.new()
	_sense_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sense_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://view/shaders/seismic_sense.gdshader")
	_sense_rect.material = mat
	_sense_rect.visible = false
	_sense_layer.add_child(_sense_rect)


## While Seismic Sense runs (FxPainter.sense): the screen greys over 0.6 s, rings of
## light leave the hero every second at its speed, and colour returns at the end.
func _update_sense(t: float) -> void:
	var sn: Dictionary = _fx.sense
	if sn.is_empty() or t > float(sn.at) + float(sn["for"]) or t < float(sn.at):
		_sense_rect.visible = false
		return
	var since := t - float(sn.at)
	var length := float(sn["for"])
	var grey := clampf(minf(since, length - since) / SENSE_FADE, 0.0, 1.0)
	var hero: Actor = session.get_actor(int(sn.on))
	# In window pixels (the shader's FRAGCOORD): the canvas, then the window's stretch.
	var to_window := get_viewport().get_final_transform() * get_viewport().get_canvas_transform()
	var center := to_window * (actor_screen_pos(hero) if hero != null else Vector2.ZERO)
	var px_per_tile := Iso.TILE_W * to_window.get_scale().x * 0.7
	var radii := Vector3.ZERO
	for i in SENSE_RINGS:
		var age := fmod(since, float(SENSE_RINGS)) - i
		if age < 0.0:
			age += SENSE_RINGS
		radii[i] = age * float(sn.speed) * px_per_tile
	var mat: ShaderMaterial = _sense_rect.material
	mat.set_shader_parameter("grey", grey)
	mat.set_shader_parameter("center", center)
	mat.set_shader_parameter("radii", radii)
	_sense_rect.visible = true


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


## Redraws the cached ground around `tiles` after their terrain or props changed
## (the map editor; height changes are noticed by themselves). The rows just
## behind and in front go too: hidden blocks and shoreline foam depend on them.
func refresh_tiles(tiles: Array) -> void:
	if _chunks.is_empty():
		return
	var rows := {}
	for p: Vector2i in tiles:
		var d := Iso.depth(p)
		for row in [d - 1, d, d + 1]:
			if row >= 0 and row <= _max_depth:
				rows[row / CHUNK_ROWS] = true
	for i in rows:
		_chunks[i].queue_redraw()


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
		var c := {"rect": _snap_rect(item.rect), "depth": int(item.depth), "h": float(item.get("h", 0)), "cover": {},
				"patch": {}}
		var merged := true
		while merged:
			merged = false
			for i in range(out.size() - 1, -1, -1):
				if out[i].rect.intersects(c.rect):
					c.rect = c.rect.merge(out[i].rect)
					c.depth = mini(c.depth, out[i].depth)
					c.h = minf(c.h, out[i].h)
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
			if grid.in_bounds(p) and _tile_bounds(grid, p).intersects(rect) and _covers(grid, p, float(cluster.h)):
				cluster.cover[p] = true
				_add_member(members, p)
	# A tile drawn again shows its lower faces, which the cached picture has hidden
	# under the bare ground in front of it. That ground isn't drawn again on its own
	# (it would cut feet and effects at its level), so it is put back right after the
	# tile it hides, before anything standing in front is drawn (2026-11-28: the
	# wall showing through around a hero whose rope reached behind a house).
	for p: Vector2i in cluster.cover:
		var under := []
		for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var q: Vector2i = p + d
			if grid.in_bounds(q) and grid.has_tile(q) and not cluster.cover.has(q) \
					and _tile_bounds(grid, q).intersects(rect):
				under.append(q)
		if not under.is_empty():
			cluster.patch[p] = under


## Whether tile `p` can hide something standing at ground height `h`: it rises above
## it, or holds a prop, an object or a graveyard marker. Bare ground at or below
## `h` never hides what stands on it or at its level (a hero's feet, a ring around
## them, an effect lying on the ground), so it isn't drawn over them again.
func _covers(grid: GridModel, p: Vector2i, h: float) -> bool:
	if grid.height_at(p) > h + 0.01:
		return true
	if _zone == null:
		return true
	return _zone.prop_at(p) != "" or _zone.decor_at(p) != null or _graveyards.has(p)


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
	return Iso.to_screen(actor.move.position_at(session.render_time()), actor_draw_height(actor))


## The height (levels) an actor's feet are drawn at now.
func actor_draw_height(actor: Actor) -> float:
	var grid: GridModel = session.grid()
	var m := actor.move
	var t: float = session.render_time()
	if m.gliding or (m.duration > 0.0 and t < m.start_time + m.duration):
		# A tile step or a forced move: the height follows the ground along the way.
		var k := m.progress(t)
		return lerpf(grid.height_at(m.from_tile), grid.height_at(m.to_tile), k)
	return m.height_at_time(t)


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
		var other: Vector2i
		if a.move.free and not a.move.gliding:
			# Drawn with a tile in front of the one under it: the tiles of that row
			# in front of its own tile (a wall beside it) must still cover it.
			other = MoveState.tile_of(a.move.position_at(t_now))
			if other == t:
				continue
			for q in [other + Vector2i(1, 0), other + Vector2i(0, 1)]:
				if q != t and Iso.depth(q) == Iso.depth(t):
					_must_follow(after, q, t)
			continue
		if not a.move.is_moving(t_now) or a.move.from_tile == a.move.to_tile:
			continue
		other = a.move.from_tile if t == a.move.to_tile else a.move.to_tile
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
	# Effects take their place in the back-to-front drawing on the tile under them.
	var fx_by_tile := {}
	for item in _fx.items(t_now, session.actors(), session.telegraphs(), ContentDB.abilities, ContentDB.effects,
			func(x): return _hero_art(x), {"projectiles": session.projectiles(), "zones": session.ground_zones(),
			"buffs": ContentDB.buffs}):
		var ft := MoveState.tile_of(item.pos)
		if not grid.in_bounds(ft):
			continue
		if not fx_by_tile.has(ft):
			fx_by_tile[ft] = []
		fx_by_tile[ft].append(item)
	for item in ropes.items(func(h): return actor_screen_pos(h)):
		var ft := MoveState.tile_of(item.pos)
		if not grid.in_bounds(ft):
			continue
		if not fx_by_tile.has(ft):
			fx_by_tile[ft] = []
		fx_by_tile[ft].append(item)
	_overlay.clear()
	_labels.clear()
	if not _cached():
		for d in range(_max_depth + 1):
			# Tiles in one depth row never overlap each other, so each tile can be drawn
			# with the actors on it, in any order that keeps the constraints above.
			for p in _row_order(_tiles_by_depth.get(d, []), after):
				_draw_tile_with_marks(grid, p, quest_areas, marks)
				_draw_fx_items(grid, fx_by_tile.get(p, []), true)
				for a in actors_by_tile.get(p, []):
					_draw_actor(a)
				_draw_fx_items(grid, fx_by_tile.get(p, []), false)
	else:
		_draw_over_cache(grid, actors_by_tile, after, quest_areas, marks, fx_by_tile)
	_draw_outlines(grid)
	_draw_projectiles(grid)
	_draw_flames(grid)
	_draw_landmarks(grid)
	_draw_way_out(grid)
	_draw_drops(grid)
	_draw_duels(grid)
	_draw_decor_labels(grid)
	_draw_talk_prompt()
	for f in _overlay:
		f.call()
	if debug_rope_points or debug_rope_path:
		ropes.draw_debug(self, func(h): return actor_screen_pos(h), debug_rope_points, debug_rope_path)
	_queue_float_texts()
	_draw_labels()


## With the terrain cached underneath: the same back-to-front pass, limited to
## the tiles carrying actors or highlights and the tiles that cover them.
func _draw_over_cache(grid: GridModel, actors_by_tile: Dictionary, after: Dictionary, quest_areas: Dictionary,
		marks: Dictionary, fx_by_tile: Dictionary = {}) -> void:
	var members := {} # depth -> {tile: true}: what this pass visits
	var items := []
	for p in actors_by_tile:
		_add_member(members, p)
		for a in actors_by_tile[p]:
			# Covered only by what rises above its feet as drawn (2026-11-28): a hero
			# stepping off the back of a ledge is still level with it for a moment.
			items.append({"rect": _actor_rect(a), "depth": Iso.depth(p), "h": actor_draw_height(a)})
	for p in marks.keys() + quest_areas.keys():
		_add_member(members, p)
		items.append({"rect": _mark_rect(grid, p), "depth": Iso.depth(p), "h": grid.height_at(p)})
	for p in fx_by_tile:
		_add_member(members, p)
		for item in fx_by_tile[p]:
			items.append({"rect": _fx_rect(grid, item), "depth": Iso.depth(p), "h": grid.height_at(p)})
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
					var hide: Rect2 = c.rect.intersection(_tile_bounds(grid, p))
					for q in c.patch.get(p, []):
						_draw_tile(self, grid, q, hide)
			if quest_areas.has(p):
				_draw_quest_area(grid, p, quest_areas[p])
			for color in marks.get(p, []):
				_draw_tile_mark(grid, p, color)
			_draw_fx_items(grid, fx_by_tile.get(p, []), true)
			for a in actors_by_tile.get(p, []):
				_draw_actor(a)
			_draw_fx_items(grid, fx_by_tile.get(p, []), false)


## Where an effect item (FxPainter.items) sits on screen: its anchor, `lift` levels
## above the ground under it.
## Items around an actor ("actor") sit at its drawn feet, `offset` tiles away.
func _fx_anchor(grid: GridModel, item: Dictionary) -> Vector2:
	if item.has("actor"):
		var off: Vector2 = item.get("offset", Vector2.ZERO)
		return actor_screen_pos(item.actor) + Iso.to_screen(off, float(item.get("lift", 0.0))) - Iso.to_screen(Vector2.ZERO, 0.0)
	var tile: Vector2i = item.get("z_tile", MoveState.tile_of(item.pos)) # a projectile: its launch height
	return Iso.to_screen(item.pos, float(grid.height_at(tile)) + float(item.get("lift", 0.0)))


func _fx_rect(grid: GridModel, item: Dictionary) -> Rect2:
	if item.has("rope"):
		return ropes.rect_of(item)
	var r := RING_RADIUS.x if item.has("ring") else 0.0
	if item.has("quad") or item.has("tilefx"):
		r = 160.0 # a strip piece or a shaded tile (and a sandstorm over its area)
	if item.has("fx"):
		var fx: FxDef = item.fx
		r = maxf(fx.frame_size.x, fx.frame_size.y) * PixelCamera.ART_SCALE
	return Rect2(_fx_anchor(grid, item) - Vector2(r, r), Vector2(r, r) * 2.0)


## Looks drawn in code (BuffDef.code_fx). "flames": three small orange flames
## licking up around the unit's body, each flickering on its own beat (Scorch).
func _draw_code_fx(grid: GridModel, item: Dictionary) -> void:
	if item.code != "flames":
		return
	var feet := _fx_anchor(grid, item).round()
	var t := float(item.t)
	var s := PixelCamera.ART_SCALE
	for i in 3:
		var beat := t * 7.0 + i * 2.1
		var x := (i - 1) * 7.0 * s
		var h := (5.0 + 2.0 * sin(beat)) * s
		var base := feet + Vector2(x, -(6.0 + 8.0 * float(i % 3)) * s)
		var sway := sin(beat * 1.7) * s
		for layer in 2:
			var k := 1.0 - layer * 0.45
			var c := Color(1.0, 0.45, 0.08, 0.85) if layer == 0 else Color(1.0, 0.85, 0.3, 0.95)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-2.5 * k * s, 0), base + Vector2(sway, -h * k),
					base + Vector2(2.5 * k * s, 0), base + Vector2(0, 1.5 * k * s)]), c)


## Escape menu → Gameplay test: draws the water ropes' points and their return
## paths (client-side, never sent).
static var debug_rope_points := false
static var debug_rope_path := false


## A strip piece of a ribbon: a quad from a to b, bent to its neighbours (each end
## at right angles to the path there), the strip's art mapped along it.
func _draw_ribbon_quad(grid: GridModel, item: Dictionary) -> void:
	var fx: FxDef = item.quad
	if fx.sheet == null:
		return
	var base := float(grid.height_at(item.z_tile))
	var a := RibbonPath.screen(item.a, base)
	var b := RibbonPath.screen(item.b, base)
	var pa := RibbonPath.screen(item.pa, base)
	var nb := RibbonPath.screen(item.nb, base)
	var na := (b - pa).orthogonal().normalized()
	var nbv := (nb - a).orthogonal().normalized()
	if na == Vector2.ZERO or nbv == Vector2.ZERO:
		return
	var r := fx.strip()
	var half := r.size.y * PixelCamera.ART_SCALE * fx.thickness * 0.5
	var tex := Vector2(fx.sheet.get_size())
	var x0 := (r.position.x + float(item.u0) * r.size.x) / tex.x
	var x1 := (r.position.x + float(item.u1) * r.size.x) / tex.x
	var y0 := r.position.y / tex.y
	var y1 := r.end.y / tex.y
	var c := Color(fx.tint, fx.tint.a * float(item.get("alpha", 1.0)) * fx.alpha)
	draw_polygon(PackedVector2Array([a - na * half, b - nbv * half, b + nbv * half, a + na * half]),
			PackedColorArray([c, c, c, c]),
			PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]), fx.sheet)


## A still drawn with its four corners at their own opacities: a burning tile's
## flames faded toward each open side ("fade": grid -x, +x, -y, +y). Screen left
## faces grid -x and +y, right faces +x and -y.
func _draw_faded(fx: FxDef, item: Dictionary, xf: Transform2D, color: Color) -> void:
	var f: PackedFloat32Array = item.fade
	var size := Vector2(fx.frame_size)
	var r := Rect2(-fx.pivot, size)
	var left := (f[0] + f[3]) * 0.5 # the screen's left faces grid -x and +y
	var right := (f[1] + f[2]) * 0.5 # its right faces +x and -y
	var tl := left
	var bl := left
	var tr := right
	var br := right
	var pts := PackedVector2Array([xf * r.position, xf * Vector2(r.end.x, r.position.y), xf * r.end,
			xf * Vector2(r.position.x, r.end.y)])
	var tex := Vector2(fx.sheet.get_size())
	var u0 := float(item.frame) * size.x / tex.x
	var u1 := u0 + size.x / tex.x
	draw_polygon(pts, PackedColorArray([Color(color, color.a * tl), Color(color, color.a * tr), Color(color, color.a * br),
			Color(color, color.a * bl)]), PackedVector2Array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1),
			Vector2(u0, 1)]), fx.sheet)


## A tile shaded in code: its own art lifted and brightened as a shock ring passes
## (RING), a glossy water film (WET), sand (SAND), cracks shaking (CRACKS), a
## sandstorm or rain over an area.
func _draw_tile_fx(grid: GridModel, item: Dictionary) -> void:
	var fx: FxDef = item.tilefx
	var tile: Vector2i = item.tile
	if not grid.in_bounds(tile) or not grid.has_tile(tile):
		return
	var a := float(item.get("alpha", 1.0))
	var c := Iso.to_screen(Vector2(tile), grid.height_at(tile))
	var hw := Iso.TILE_W * 0.5
	var hh := Iso.TILE_H * 0.5
	var diamond := PackedVector2Array([c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(-hw, 0)])
	match fx.tile_mode:
		FxDef.TileMode.RING:
			var lift := float(item.get("lift_px", 0.0)) * PixelCamera.ART_SCALE
			draw_set_transform(Vector2(0, -roundf(lift)))
			_draw_tile(self, grid, tile)
			draw_set_transform(Vector2.ZERO)
			var up := PackedVector2Array()
			for q in diamond:
				up.append(q + Vector2(0, -roundf(lift)))
			draw_colored_polygon(up, Color(1, 1, 0.9, 0.22 * a))
		FxDef.TileMode.WET:
			draw_colored_polygon(diamond, Color(fx.tile_tint, fx.tile_tint.a * a))
			# A glint along the top edges.
			draw_polyline(PackedVector2Array([diamond[3] + Vector2(6, 0), diamond[0] + Vector2(0, 4), diamond[1] - Vector2(6, 0)]),
					Color(0.8, 0.9, 1.0, 0.35 * a), 1.0)
		FxDef.TileMode.SAND:
			draw_colored_polygon(diamond, Color(fx.tile_tint, fx.tile_tint.a * a))
		FxDef.TileMode.CRACKS:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(tile)
			var shake := Vector2(sin(float(item.since) * 47.0), cos(float(item.since) * 39.0)) * PixelCamera.ART_SCALE
			for k in 3:
				var p := c + Vector2(rng.randf_range(-hw * 0.5, hw * 0.5), rng.randf_range(-hh * 0.5, hh * 0.5)) + shake
				var pts := PackedVector2Array([p])
				for j in 4:
					p += Vector2(rng.randf_range(-8, 8), rng.randf_range(-4, 4))
					pts.append(p)
				draw_polyline(pts, Color(fx.tile_tint, fx.tile_tint.a * a), PixelCamera.ART_SCALE * 1.5)
		FxDef.TileMode.SANDSTORM:
			var center := Iso.to_screen(item.pos, grid.height_at(tile))
			var size := sqrt(float(item.area.size())) * hw
			draw_colored_polygon(_ellipse_points(center, size, size * 0.5), Color(fx.tile_tint, fx.tile_tint.a * a))
			var t := float(item.since)
			for k in 140:
				var r := fposmod(k * 0.618, 1.0) * size
				var ang := t * (2.0 - r / size) * 2.0 + k * 1.7
				var h := fposmod(k * 0.37 + t * 0.5, 1.0) * 40.0
				var p := center + Vector2(cos(ang) * r, sin(ang) * r * 0.5 - h)
				draw_rect(Rect2(p.round(), Vector2(2, 2) * PixelCamera.ART_SCALE), Color(0.9, 0.74, 0.46, 0.9 * a))
		FxDef.TileMode.RAIN:
			var t := float(item.since)
			for tile_v in item.area:
				var tc := Iso.to_screen(Vector2(tile_v), grid.height_at(tile_v))
				for k in 4:
					var fall := fposmod(t * 1.6 + k * 0.25 + (tile_v.x * 0.17 + tile_v.y * 0.29), 1.0)
					var p := (tc + Vector2((k - 1.5) * 12.0, -80.0 + fall * 80.0)).round()
					draw_line(p, p + Vector2(-2, 10), Color(fx.tile_tint, fx.tile_tint.a * a * (1.0 - fall * 0.5)),
							PixelCamera.ART_SCALE)


static func _ellipse_points(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var ang := TAU * i / 24.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts


## A stance's faint ring (art not approved yet): its half-size on screen.
const RING_RADIUS := Vector2(30, 15)


## The items of one tile that go behind its actors (`behind`), or in front.
func _draw_fx_items(grid: GridModel, items: Array, behind: bool) -> void:
	for item in items:
		if bool(item.get("behind", false)) == behind:
			_draw_fx(grid, item)


## Draws one effect frame: its pivot on the anchor, at the art scale, turned toward
## where it was sent (kept upright when it points left), at its opacity.
func _draw_fx(grid: GridModel, item: Dictionary) -> void:
	if item.has("ring"):
		var c: Color = item.ring
		var centre := _fx_anchor(grid, item).round()
		var pts := PackedVector2Array()
		var from := PI if int(item.get("half", 1)) < 0 else 0.0 # back arc: the top half
		for i in 17:
			var ang := from + PI * i / 16.0
			pts.append(centre + Vector2(cos(ang) * RING_RADIUS.x, sin(ang) * RING_RADIUS.y))
		draw_polyline(pts, Color(c, float(item.alpha)), 2.0)
		return
	if item.has("code"):
		_draw_code_fx(grid, item)
		return
	if item.has("rope"):
		ropes.draw(self, item)
		return
	if item.has("quad"):
		_draw_ribbon_quad(grid, item)
		return
	if item.has("tilefx"):
		_draw_tile_fx(grid, item)
		return
	if item.has("particle"):
		var i: int = item.particle
		var pp := _fx.particles
		var k := 1.0 - pp.age[i] / maxf(pp.life[i], 0.001)
		var c: Color = pp.color[i]
		draw_rect(Rect2(_fx_anchor(grid, item).round(), Vector2(2, 2) * PixelCamera.ART_SCALE * 0.5),
				Color(c, c.a * k))
		return
	var fx: FxDef = item.fx
	if fx.sheet == null:
		return
	var s := PixelCamera.ART_SCALE
	var angle: float = item.angle if item.rotate else 0.0
	var flip: bool = item.rotate and not item.get("spin", false) and cos(angle) < 0.0
	if item.rotate and not item.get("spin", false) and fx.drawn_angle != 0.0:
		angle -= deg_to_rad(fx.drawn_angle) # art not drawn pointing right (no pre-rotated cells)
		flip = false
	var mirror: bool = item.get("mirror", false)
	# Turned, mirrored, then (lying on the ground) squashed to half height, like a tile.
	s *= int(item.get("scale", 1)) # whole-pixel enlargement (Air Blast's front)
	var squash := 0.5 if item.get("flat", false) else 1.0
	var xf := Transform2D(Vector2(s, 0), Vector2(0, s * squash), Vector2.ZERO) * Transform2D(angle, Vector2.ZERO) \
			* Transform2D(Vector2(-1.0 if mirror else 1.0, 0), Vector2(0, -1.0 if flip else 1.0), Vector2.ZERO)
	xf.origin = _fx_anchor(grid, item).round()
	var size := Vector2(fx.frame_size)
	var color := Color(1, 1, 1, float(item.get("alpha", fx.alpha)))
	if fx.rot_sheet != null and fx.rot_steps > 0 and item.rotate and not item.get("spin", false):
		# Pre-rotated (RotSprite): the nearest of its turns, drawn upright, its pivot at
		# the cell's centre.
		var turn := wrapf(float(item.angle) - deg_to_rad(fx.drawn_angle), 0.0, TAU)
		var step := int(round(turn / TAU * fx.rot_steps)) % fx.rot_steps
		var cell := float(fx.rot_sheet.get_height())
		draw_set_transform(_fx_anchor(grid, item).round(), 0.0, Vector2(s, s))
		draw_texture_rect_region(fx.rot_sheet, Rect2(-Vector2(cell, cell) * 0.5, Vector2(cell, cell)),
				Rect2(step * cell, 0, cell, cell), color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var half := int(item.get("half", 0))
	if item.has("fade"):
		_draw_faded(fx, item, xf, color)
		return
	if half == 0:
		draw_set_transform_matrix(xf)
		draw_texture_rect_region(fx.sheet, Rect2(-fx.pivot, size), Rect2(Vector2(item.frame * size.x, 0), size), color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# A split still: only the half of its screen box above (behind the actor) or below
	# (in front of it) the anchor, its texture mapped back through the transform.
	var box := xf * Rect2(-fx.pivot, size)
	var y0 := box.position.y if half < 0 else xf.origin.y
	var y1 := xf.origin.y if half < 0 else box.end.y
	if y1 <= y0:
		return
	var pts := PackedVector2Array([Vector2(box.position.x, y0), Vector2(box.end.x, y0), Vector2(box.end.x, y1),
			Vector2(box.position.x, y1)])
	var inv := xf.affine_inverse()
	var tex := Vector2(fx.sheet.get_size())
	var uvs := PackedVector2Array()
	for q in pts:
		uvs.append((inv * q + fx.pivot + Vector2(item.frame * size.x, 0)) / tex)
	draw_polygon(pts, PackedColorArray([color, color, color, color]), uvs, fx.sheet)


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
	if not grid.has_tile(p):
		return # no glow or mark over a hole
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
	if m.free and not m.gliding:
		return _free_anchor(a)
	if not m.is_moving(session.render_time()) or m.from_tile == m.to_tile:
		return m.to_tile
	var df := Iso.depth(m.from_tile)
	var dt := Iso.depth(m.to_tile)
	if df != dt:
		return m.from_tile if df > dt else m.to_tile
	return m.to_tile


## A free mover (moving or standing) is drawn with the frontmost tile its body
## reaches into that isn't higher than its feet, so flat ground in front of it never
## covers it; higher tiles in front (walls, cliffs) still do.
func _free_anchor(a: Actor) -> Vector2i:
	var grid: GridModel = session.grid()
	var p: Vector2 = a.move.position_at(session.render_time())
	var base := MoveState.tile_of(p)
	var feet := grid.height_at(base) if grid.in_bounds(base) else 0
	var best := base
	var r := a.move.radius
	for off in [Vector2(r, 0), Vector2(0, r), Vector2(r, r) * 0.7071]:
		var t := MoveState.tile_of(p + off)
		if t != base and grid.in_bounds(t) and grid.height_at(t) <= feet and Iso.depth(t) > Iso.depth(best):
			best = t
	return best


## Draws a tile on `canvas` (this view, or a terrain chunk); with `clip`, only
## the part inside that box (tileset maps only).
func _draw_tile(canvas: CanvasItem, grid: GridModel, p: Vector2i, clip := Rect2()) -> void:
	if not grid.has_tile(p):
		return # a hole in the map's shape: nothing there
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
	var decor := _zone.decor_at(p)
	if decor != null:
		DecorPainter.draw(canvas, decor, Iso.to_screen(Vector2(p), h), clip)
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


## How high the tile in front stands (-1 off the map or at a hole, so every block
## of the tile behind shows its sides, as at the map's edge).
func _front_height(grid: GridModel, p: Vector2i) -> int:
	return grid.height_at(p) if grid.has_tile(p) else -1


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
	if a.move.falling():
		# Falling: its shadow stays on the ground below, so the drop reads clearly.
		var ground := Iso.to_screen(a.move.position_at(session.render_time()), float(a.move.ground_h))
		draw_set_transform(ground, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var animated := (a is Hero and _hero_art(a) != null) or (a is Enemy and (a as Enemy).def.art != null) or (a is Npc and (a as Npc).def.art != null)
	var still := a is Enemy and (a as Enemy).def.immobile # the Grey Heart faces nowhere
	if a.alive and not animated and not still: # animated creatures show their facing themselves
		_draw_facing(feet, a.facing_vector() if a.move.free else Vector2(a.facing), Color(1, 1, 1, 0.85 * alpha))
	var hero_art := _hero_art(a)
	if hero_art != null and _draw_creature(a, feet, alpha, hero_art):
		var top := feet - Vector2(0, (hero_art.feet.y - hero_art.head_y) * PixelCamera.ART_SCALE)
		_draw_label(top + Vector2(0, -16), "%s  Lv%d" % [a.display_name, (a as Hero).level], Color.WHITE)
		if a.alive:
			_draw_bar(top + Vector2(-14, -10), 28, a.hp / maxf(a.current_stats(now).hp, 1.0), Color(0.2, 0.85, 0.3))
			_draw_cast_bar(a, feet, now)
		return
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
		if edef.look == EnemyDef.Look.CRYSTAL:
			_draw_crystal(a as Enemy, feet, alpha)
			_draw_label(feet + Vector2(0, -78), "%s  Lv%d" % [a.display_name, (a as Enemy).level], Color(1, 0.85, 0.45, alpha))
			if a.alive:
				_draw_bar(feet + Vector2(-20, -70), 40, a.hp / maxf(a.current_stats(now).hp, 1.0), Color(0.2, 0.85, 0.3))
				if (a as Enemy).invulnerable:
					_draw_label(feet + Vector2(0, 18), "Shielded by the Foreman", Color(0.8, 0.8, 0.85), 11)
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


## The Grey Heart (EnemyDef.Look.CRYSTAL): a cracked crystal of black-gold
## Sunstone leaking grey smoke, pulsing slowly. Shielded (invulnerable) it shows
## a pale ring; once it can be hurt, its gold cracks glow brighter.
func _draw_crystal(e: Enemy, feet: Vector2, alpha: float) -> void:
	var t := _pulse_ms() / 1000.0
	var glow := 0.5 + 0.5 * sin(t * 2.4)
	var open := not e.invulnerable
	_draw_ellipse(feet, 26, 12, Color(0, 0, 0, 0.35 * alpha), 6.0)
	var top := feet + Vector2(0, -64)
	var shard := PackedVector2Array([top, feet + Vector2(16, -40), feet + Vector2(12, -6), feet + Vector2(0, 2),
			feet + Vector2(-12, -6), feet + Vector2(-16, -40)])
	draw_colored_polygon(shard, Color(0.08, 0.07, 0.06, alpha))
	var face := PackedVector2Array([top, feet + Vector2(16, -40), feet + Vector2(12, -6), feet + Vector2(0, 2)])
	draw_colored_polygon(face, Color(0.2, 0.17, 0.1, alpha))
	var gold := Color(1.0, 0.78, 0.2, alpha * (0.55 + (0.45 if open else 0.25) * glow))
	for crack in [[Vector2(0, -60), Vector2(-5, -42), Vector2(3, -30), Vector2(-2, -10)],
			[Vector2(10, -40), Vector2(5, -26), Vector2(9, -12)], [Vector2(-12, -34), Vector2(-7, -20)]]:
		var pts := PackedVector2Array()
		for p in crack:
			pts.append(feet + p)
		draw_polyline(pts, gold, 2.0 if open else 1.5)
	shard.append(shard[0])
	draw_polyline(shard, Color(0.55, 0.45, 0.2, alpha), 1.5)
	for i in 3: # grey smoke rising and fading
		var k := fmod(t * 0.35 + i / 3.0, 1.0)
		draw_circle(top + Vector2(sin(t + i * 2.0) * 6.0, -k * 30.0), 4.0 + k * 7.0, Color(0.55, 0.55, 0.58, (1.0 - k) * 0.45 * alpha))
	if e.invulnerable and e.alive:
		_draw_ellipse(feet + Vector2(0, -28), 26, 40, Color(0.8, 0.82, 0.9, 0.35 * alpha), 2.0)


## A hero's sprite art (HeroDef.art), or null: then it is drawn as a circle.
func _hero_art(a: Actor) -> CreatureArtDef:
	if not (a is Hero):
		return null
	var def: HeroDef = ContentDB.heroes.get((a as Hero).def_id)
	return def.art if def != null else null


## Stone looks from least to most of the body (Earth stances 1-4, Stone Guard buffs).
const STONE_LOOKS: Array[StringName] = [&"stone_25", &"stone_50", &"stone_75", &"stone"]


## The look a creature's body wears: its buff's (Stone Skin), or its held stance's
## ("look:<name>", Earth's stone); with both, the one that covers more stone.
func _body_look(e: Actor, art: CreatureArtDef) -> StringName:
	if not e.alive:
		return &""
	var look: StringName = e.buffs.look(session.now())
	if e is Hero and e.stance > 0:
		var key := art.stance_look(e.stance_tree, e.stance)
		if key.begins_with("look:"):
			var held := StringName(key.trim_prefix("look:"))
			if look == &"" or STONE_LOOKS.find(held) > STONE_LOOKS.find(look):
				look = held
	return look


## Draws an animated creature standing on `feet`; false if it has nothing to show.
func _draw_creature(e: Actor, feet: Vector2, alpha: float, art: CreatureArtDef = null) -> bool:
	if art == null:
		art = (e as Enemy).def.art
	var pick := _animator.pick_hero(e, art, session.render_time()) if e is Hero \
			else _animator.pick(e, art, session.render_time())
	if pick.is_empty():
		return false
	if not _frames_cache.has(art):
		var sheets: Dictionary = CreatureRecolor.sheets(art, get_tree().root) if art.recolor else {}
		_frames_cache[art] = [art.build_sprite_frames(sheets), art.build_sprite_frames(art.flash_sheets) if not art.flash_sheets.is_empty() else null]
	var frames: SpriteFrames = _frames_cache[art][0]
	# A buff's look (Stone Skin: grey stone), except while its own end animation plays.
	var look: StringName = _body_look(e, art)
	if look != &"" and art.looks.has(look) and pick.anim != str((e as Hero).anim.get("buff_end_anim", "") if e is Hero else ""):
		var key := [art, look]
		if not _frames_cache.has(key):
			_frames_cache[key] = [art.build_sprite_frames(CreatureRecolor.sheets(art, get_tree().root, look)), null]
		frames = _frames_cache[key][0]
	var name := StringName("%s_%s" % [pick.anim, pick.dir])
	if not frames.has_animation(name):
		return false
	var tex := frames.get_frame_texture(name, mini(pick.frame, frames.get_frame_count(name) - 1))
	var s := PixelCamera.ART_SCALE
	var color := Color(1, 1, 1, alpha * float(pick.get("alpha", 1.0)))
	var now: float = session.now()
	if e is Enemy and e.alive and e.def.enrage_buff != null and e.buffs.has(e.def.enrage_buff.id, now):
		color = Color(ENRAGE_TINT, color.a) # Molten Fury: glowing hotter
	var lunge := float(pick.get("lunge", 0.0))
	if lunge != 0.0:
		# Attack fallback (no attack art): a short lunge toward its facing.
		var toward := Iso.to_screen(e.facing_vector(), 0.0) - Iso.to_screen(Vector2.ZERO, 0.0)
		feet += (toward.normalized() * lunge * s).round()
	var tip := float(pick.get("tip", 0.0))
	var flip: bool = pick.get("flip", false)
	if tip > 0.0 or flip:
		# Death fallback (no death art): tips over onto its side about its feet.
		# Mirrored rows (CreatureArtDef.mirror_rows): flipped left to right about the feet.
		var side := -1.0 if pick.dir in ["sw", "nw"] else 1.0
		draw_set_transform(feet, side * tip * PI * 0.45, Vector2(-1.0 if flip else 1.0, 1.0))
		feet = Vector2.ZERO
	var rect := Rect2(feet - art.feet * s, Vector2(art.frame_size) * s)
	draw_texture_rect(tex, rect, false, color)
	if session.render_time() < float(_flash_until.get(e.id, -1.0)):
		# Hit flash: no hit animation exists, so the body flashes white. The
		# shadowless frame drawn with colours above 1 saturates to white.
		var plain: SpriteFrames = _frames_cache[art][1]
		var body := plain.get_frame_texture(name, mini(pick.frame, plain.get_frame_count(name) - 1)) if plain != null else tex
		draw_texture_rect(body, rect, false, Color(FLASH_STRENGTH, FLASH_STRENGTH, FLASH_STRENGTH, color.a))
	if tip > 0.0 or flip:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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


## Hitbox shapes on the ground (free movement): enemy telegraphs in red, brighter
## as they land, then the local player's aim (blue, red when it can't be cast).
func _draw_outlines(grid: GridModel) -> void:
	var now: float = session.now()
	for h in session.telegraphs():
		var poly: PackedVector2Array = h.get("outline", PackedVector2Array())
		if poly.size() >= 3:
			var left := clampf(float(h.at) - now, 0.0, 1.5)
			var a := 0.45 - 0.2 * left / 1.5 + 0.08 * sin(_pulse_ms() / 80.0)
			_draw_ground_poly(grid, poly, Color(TELEGRAPH_COLOR, a))
	if client != null and not client.aim.is_empty():
		var poly: PackedVector2Array = client.aim.get("outline", PackedVector2Array())
		if poly.size() >= 3:
			_draw_ground_poly(grid, poly, AIM_COLOR if client.aim.valid else AIM_BAD_COLOR)


## A grid-space polygon drawn flat on the ground, at the height under its centre
## (corners at their own heights tear it apart across ledges).
func _draw_ground_poly(grid: GridModel, poly: PackedVector2Array, color: Color) -> void:
	var centre := Vector2.ZERO
	for q in poly:
		centre += q
	centre /= poly.size()
	var h := grid.height_at(MoveState.tile_of(centre))
	var pts := PackedVector2Array()
	for q in poly:
		pts.append(Iso.to_screen(q, h))
	var fill := Color(color, color.a * 0.45)
	if Geometry2D.triangulate_polygon(pts).size() > 0:
		draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, Color(0.05, 0.05, 0.1, 0.6), 3.0)
	draw_polyline(pts, Color(color.lightened(0.25), minf(color.a + 0.4, 1.0)), 1.5)


## Projectiles: a glowing ball moving along its path at the origin's height.
## Heroes' are orange, enemies' purple.
func _draw_projectiles(grid: GridModel) -> void:
	var t: float = session.render_time()
	for p in session.projectiles():
		var ability: AbilityDef = ContentDB.abilities.get(StringName(p.get("ability", "")))
		if ability != null and ability.fx_projectile != &"" and ContentDB.effects.has(ability.fx_projectile):
			continue # drawn with its sprite in the back-to-front pass (FxPainter)
		if WaterRopes.draws_projectile(p):
			continue # Frost Shard: drawn in code by WaterRopes
		if p.has("from"):
			# Free movement: from its start point along its direction.
			var at: Vector2 = p.from + p.dirv * clampf((t - p.start) * p.speed, 0.0, p.length)
			var sp := Iso.to_screen(at, grid.height_at(Vector2i(p.origin))) + Vector2(0, -16)
			if session.get_actor(p.source) is Enemy:
				draw_circle(sp, 8, Color(0.6, 0.2, 0.9, 0.5))
				draw_circle(sp, 5, Color(0.85, 0.6, 1.0))
			else:
				_draw_fireball(sp)
			continue
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
func _draw_facing(feet: Vector2, facing: Vector2, color: Color) -> void:
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
	_fx.on_events(events, ContentDB.effects)
	ropes.on_events(events, ContentDB.effects)
	_fx.on_casts(events, ContentDB.abilities)
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
			"immune":
				_float(e.target, "Immune", Color(0.8, 0.82, 0.9), t)
			"boss_phase":
				_float(e.source, "Phase %d!" % e.phase, Color(1, 0.6, 0.3), t)
			"heart_pulse":
				_float(e.source, "Pulse!", Color(0.75, 0.75, 0.8), t)
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


## Duels: a flag at the midpoint and the boundary circle; the countdown above
## the flag.
func _draw_duels(grid: GridModel) -> void:
	for d in session.duels():
		var p: Vector2 = d.flag
		var t := MoveState.tile_of(p)
		var h := grid.height_at(t) if grid.in_bounds(t) else 0
		var base := Iso.to_screen(p, h)
		var c := Color(0.95, 0.3, 0.2, 0.55 if d.state != "over" else 0.25)
		var ring := PackedVector2Array()
		for i in 49:
			var a := TAU * i / 48.0
			ring.append(Iso.to_screen(p + Vector2.from_angle(a) * float(d.radius), h))
		draw_polyline(ring, c, 2.0)
		draw_line(base, base + Vector2(0, -50), Color(0.35, 0.25, 0.15), 3.0)
		var cloth := PackedVector2Array([base + Vector2(1, -50), base + Vector2(24, -44), base + Vector2(1, -36)])
		draw_colored_polygon(cloth, Color(0.85, 0.15, 0.15))
		draw_colored_polygon(PackedVector2Array([base + Vector2(1, -36), base + Vector2(24, -42), base + Vector2(1, -30)]),
				Color(0.95, 0.95, 0.9))
		if d.state == "countdown":
			var left := ceili(float(d.starts_at) - session.render_time())
			_draw_label(base + Vector2(0, -62), str(maxi(left, 1)), Color(1, 0.85, 0.3), 22)


## Your own loot on the ground (only yours are sent): a light beam in the item's
## rarity colour (white, green, blue, purple, gold) and its name in your colour.
func _draw_drops(grid: GridModel) -> void:
	var mine: Array = session.my_drops()
	if mine.is_empty():
		return
	var pp: PartyPlayDef = session.rules().party_play
	var hero: Actor = session.local_hero()
	var tag: Color = HERO_COLORS[(hero.id - 1) % HERO_COLORS.size()] if hero != null else Color.WHITE
	var pulse := 0.5 + 0.5 * sin(_pulse_ms() * 0.003)
	for d in mine:
		var item: ItemDef = ContentDB.items.get(StringName(d.item))
		if item == null:
			continue
		var p: Vector2 = d.pos
		var t := MoveState.tile_of(p)
		var base := Iso.to_screen(p, grid.height_at(t) if grid.in_bounds(t) else 0)
		var c: Color = Rarity.BEAM_COLORS[item.rarity]
		_draw_ellipse(base, 12.0, 6.0, Color(c, 0.7), 2.0)
		var top := base + Vector2(0, -pp.beam_height)
		for k in 3: # soft glow: wide and faint to narrow and bright
			var w := pp.beam_width * (3.0 - k)
			draw_line(base, top, Color(c, (0.12 + 0.18 * k) * (0.75 + 0.25 * pulse)), w)
		draw_circle(base, 3.0, Color(c, 0.9))
		# Its icon at the beam's top, half the world art's pixel size (whole screen
		# pixels: 1 per icon pixel at 720p, 2 at 1080p), its name above.
		var icon := Icons.of_item(item)
		var label_at := top + Vector2(0, -6)
		if icon != null:
			var px := Icons.screen_scale_of(self) # screen pixels per world unit
			var k := maxi(floori(px * PixelCamera.ART_SCALE * 0.5 + 0.0001), 1)
			var icon_size := Vector2(icon.get_size()) * k / maxf(px, 0.001)
			var at := ((top - Vector2(icon_size.x * 0.5, icon_size.y * 0.7)) * px).round() / maxf(px, 0.001)
			draw_texture_rect(icon, Rect2(at, icon_size), false)
			label_at = Vector2(top.x, at.y + icon_size.y * 0.12)
		var label := item.display_name + (" x%d" % d.count if d.count > 1 else "")
		_draw_label(label_at, label, tag, 12)


## The way out of a cleared dungeon: a pulsing golden ring of light on its tile
## with "Way out" over it, so nobody misses it.
func _draw_way_out(grid: GridModel) -> void:
	var tile: Variant = session.way_out()
	if tile == null or not grid.in_bounds(tile):
		return
	var base := Iso.to_screen(Vector2(tile), grid.height_at(tile))
	var pulse := 0.5 + 0.5 * sin(_pulse_ms() * 0.004)
	for i in 3:
		var k := 1.0 - i * 0.28
		_draw_ellipse(base, 30.0 * k, 15.0 * k, Color(1.0, 0.85, 0.35, (0.45 + 0.4 * pulse) * k), 3.0)
	draw_line(base, base + Vector2(0, -46), Color(1.0, 0.9, 0.5, 0.35 + 0.3 * pulse), 10.0)
	draw_line(base, base + Vector2(0, -46), Color(1.0, 0.97, 0.8, 0.6 + 0.3 * pulse), 3.0)
	_draw_label(base + Vector2(0, -54), "Way out", Color(1, 0.9, 0.4), 15)


## Named places: a banner on a pole and the name in gold.
func _draw_landmarks(grid: GridModel) -> void:
	for lm in _landmarks:
		var base := Iso.to_screen(Vector2(lm.tile), grid.height_at(lm.tile))
		draw_line(base, base + Vector2(0, -34), Color(0.35, 0.25, 0.15), 3.0)
		draw_colored_polygon(PackedVector2Array([base + Vector2(1, -34), base + Vector2(18, -29),
				base + Vector2(1, -24)]), Color(0.75, 0.2, 0.15))
		_draw_label(base + Vector2(0, -40), lm.name, Color(1, 0.85, 0.3), 14)


## Labels of the placeholder objects near the local hero (all of them would crowd
## the screen).
func _draw_decor_labels(grid: GridModel) -> void:
	var hero: Actor = session.local_hero()
	for d in _zone.decor:
		if d.label == "" or (hero != null and GridModel.distance(hero.tile(), d.tile) > DECOR_LABEL_TILES):
			continue
		var base := Iso.to_screen(Vector2(d.tile), grid.height_at(d.tile))
		_draw_label(base + Vector2(0, -DecorPainter.top(d) - 6), d.label, Color(0.95, 0.92, 0.82), 11)


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
	if what.kind == "fill":
		var me: Hero = session.local_hero()
		var verb := "Filling Water Pouch" if not me.pouch_fill.is_empty() else "[E] Fill Water Pouch"
		_draw_label(actor_screen_pos(me) + Vector2(0, -70), "%s (%d / %d)"
				% [verb, me.water, session.rules().water_pouch_capacity], Color(0.6, 0.85, 1), 13, true)
		return
	var npc: Npc = what.npc
	var marker: String = client.npc_markers.get(npc.def.id, "") if client != null else ""
	var y := -70.0 if marker != "" else -54.0
	var verb := "Use" if npc.def.kind == NpcDef.Kind.OBJECT else ("Read" if npc.def.kind == NpcDef.Kind.BOARD else "Talk")
	_draw_label(actor_screen_pos(npc) + Vector2(0, y), "[E] %s" % verb, Color(1, 0.95, 0.6), 13, true)
