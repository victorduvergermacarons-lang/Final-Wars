class_name WorldView
extends Node2D
## Placeholder renderer: draws the grid and actors from session state, back to
## front, every frame. Reads only; never changes the world.

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
			_tiles_by_depth[d].append(p)
			_max_depth = maxi(_max_depth, d)
	for g in zone.graveyards:
		_graveyards[g] = true
	_landmarks = zone.landmarks
	camera = PixelCamera.new()
	add_child(camera)
	session.events_received.connect(_on_events)


func _process(delta: float) -> void:
	if session == null:
		return
	var hero: Actor = session.local_hero()
	if hero != null:
		camera.follow(actor_screen_pos(hero), delta)
	var t: float = session.render_time()
	_float_texts = _float_texts.filter(func(f): return t - f.t < FLOAT_TEXT_SECONDS)
	queue_redraw()


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
	if session == null:
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
	for d in range(_max_depth + 1):
		# Tiles in one depth row never overlap each other, so each tile can be drawn
		# with the actors on it, in any order that keeps the constraints above.
		for p in _row_order(_tiles_by_depth.get(d, []), after):
			_draw_tile_with_marks(grid, p, quest_areas, marks)
			for a in actors_by_tile.get(p, []):
				_draw_actor(a)
	_draw_projectiles(grid)
	_draw_landmarks(grid)
	_draw_talk_prompt()
	for f in _overlay:
		f.call()
	_queue_float_texts()
	_draw_labels()


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
	_draw_tile(grid, p)
	if quest_areas.has(p):
		_draw_quest_area(grid, p)
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


func _draw_tile(grid: GridModel, p: Vector2i) -> void:
	if _art != null:
		_draw_terrain_column(grid, p)
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
	draw_colored_polygon(PackedVector2Array([left, bottom, bottom + drop, left + drop]), top_color.darkened(0.35))
	draw_colored_polygon(PackedVector2Array([bottom, right, right + drop, bottom + drop]), top_color.darkened(0.5))
	draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), top_color)
	draw_polyline(PackedVector2Array([top, right, bottom, left, top]), top_color.darkened(0.2), 1.0)
	if _graveyards.has(p):
		draw_line(c + Vector2(0, -12), c + Vector2(0, 4), Color.WHITE, 2.0)
		draw_line(c + Vector2(-5, -7), c + Vector2(5, -7), Color.WHITE, 2.0)


## A tiled zone's tile: its stack of blocks, bottom first, then its prop. Blocks
## the tiles in front fully cover are skipped (they would be drawn over anyway).
func _draw_terrain_column(grid: GridModel, p: Vector2i) -> void:
	var h := grid.height_at(p)
	var front := mini(_front_height(grid, p + Vector2i(1, 0)), _front_height(grid, p + Vector2i(0, 1)))
	var terrain := _zone.terrain_at(p)
	for block in _art.column(terrain, p, h, front, _land_sides(p), session.render_time()):
		_art.draw(self, block[0], Iso.to_screen(Vector2(p), block[1]))
	if _art.data.is_water_terrain(terrain):
		var sparkle := _art.sparkle_frame(p, session.render_time())
		if sparkle >= 0:
			_art.draw(self, sparkle, Iso.to_screen(Vector2(p), h))
	# The prop goes with its tile, so the tiles in front still cover what's behind
	# a boulder, and a unit behind it is hidden by it.
	var group := _zone.prop_at(p)
	if group != "":
		_art.draw_prop(self, _art.data.pick_prop(group, p), p, h)
	if _graveyards.has(p):
		var c := Iso.to_screen(Vector2(p), h)
		draw_line(c + Vector2(0, -12), c + Vector2(0, 4), Color.WHITE, 2.0)
		draw_line(c + Vector2(-5, -7), c + Vector2(5, -7), Color.WHITE, 2.0)


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
		_draw_ellipse(feet, 20, 9, Color(1, 0.9, 0.2), 2.0)
	var body := feet + Vector2(0, -14)
	var alpha := 0.45 if a.evading else 1.0
	var animated := a is Enemy and (a as Enemy).def.art != null
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
		var npc := a as Npc
		draw_rect(Rect2(body - Vector2(9, 11), Vector2(18, 22)), npc.def.color)
		draw_rect(Rect2(body - Vector2(9, 11), Vector2(18, 22)), Color(0.1, 0.08, 0.02), false, 2.0)
		_draw_label(body + Vector2(0, -22), npc.display_name, Color(1, 0.95, 0.7))
		var marker: String = client.npc_markers.get(npc.def.id, "") if client != null else ""
		if marker != "":
			_draw_label(body + Vector2(0, -36), marker, Color(1, 0.85, 0.1), 20)
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
			_draw_label(top + Vector2(0, -16), "%s  Lv%d" % [a.display_name, (a as Enemy).level], Color(1, 0.8, 0.8, alpha))
			_draw_bar(top + Vector2(-14, -10), 28, a.hp / maxf(a.current_stats(now).hp, 1.0), Color(0.2, 0.85, 0.3))
			_draw_cast_bar(a, feet, now)
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
func _draw_creature(e: Enemy, feet: Vector2, alpha: float) -> bool:
	var art := e.def.art
	var pick := _animator.pick(e, art, session.render_time())
	if pick.is_empty():
		return false
	if not _frames_cache.has(art):
		_frames_cache[art] = [art.build_sprite_frames(), art.build_sprite_frames(art.flash_sheets) if not art.flash_sheets.is_empty() else null]
	var frames: SpriteFrames = _frames_cache[art][0]
	var name := StringName("%s_%s" % [pick.anim, pick.dir])
	if not frames.has_animation(name):
		return false
	var tex := frames.get_frame_texture(name, mini(pick.frame, frames.get_frame_count(name) - 1))
	var s := PixelCamera.ART_SCALE
	var color := Color(1, 1, 1, alpha * float(pick.get("alpha", 1.0)))
	var rect := Rect2(feet - art.feet * s, Vector2(art.frame_size) * s)
	draw_texture_rect(tex, rect, false, color)
	if session.render_time() < float(_flash_until.get(e.id, -1.0)):
		# Hit flash: no hit animation exists, so the body flashes white. The
		# shadowless frame drawn with colours above 1 saturates to white.
		var plain: SpriteFrames = _frames_cache[art][1]
		var body := plain.get_frame_texture(name, mini(pick.frame, plain.get_frame_count(name) - 1)) if plain != null else tex
		draw_texture_rect(body, rect, false, Color(FLASH_STRENGTH, FLASH_STRENGTH, FLASH_STRENGTH, color.a))
	return true


## A bar under a unit that is casting (yellow), winding up (red) or channelling
## (blue), filling as it goes.
func _draw_cast_bar(a: Actor, feet: Vector2, now: float) -> void:
	var c: Dictionary = a.casting
	if c.is_empty() or not c.has("end"):
		return
	var span := maxf(float(c.end) - float(c.get("start", c.end)), 0.01)
	var done := clampf((now - float(c.get("start", now))) / span, 0.0, 1.0)
	var color: Color = {"cast": Color(1, 0.85, 0.2), "windup": Color(1, 0.3, 0.2), "channel": Color(0.4, 0.7, 1)}.get(
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
			draw_circle(screen, 8, Color(1, 0.45, 0.1, 0.5))
			draw_circle(screen, 5, Color(1, 0.85, 0.3))


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
	return out


## Highlights per tile: tile -> [Color]. Ground zones, then enemy telegraphs
## (brighter as they're about to land), then the local player's aim on top.
func _tile_marks() -> Dictionary:
	var marks := {}
	var now: float = session.now()
	for z in session.ground_zones():
		for t in z.tiles:
			_mark(marks, t, ZONE_COLOR)
	for h in session.telegraphs():
		var left := clampf(float(h.at) - now, 0.0, 1.5)
		var c := Color(TELEGRAPH_COLOR, 0.65 - 0.3 * left / 1.5 + 0.1 * sin(Time.get_ticks_msec() / 80.0))
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


func _draw_quest_area(grid: GridModel, p: Vector2i) -> void:
	var c := surface_point(grid, p)
	var pulse := 0.5 + 0.2 * sin(Time.get_ticks_msec() / 250.0)
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


## "[E] Talk" over the townsperson E would talk to.
func _draw_talk_prompt() -> void:
	var npc := PlayerInput.talk_target(session)
	if npc == null:
		return
	var marker: String = client.npc_markers.get((npc as Npc).def.id, "") if client != null else ""
	var y := -70.0 if marker != "" else -54.0
	_draw_label(actor_screen_pos(npc) + Vector2(0, y), "[E] Talk", Color(1, 0.95, 0.6), 13, true)
