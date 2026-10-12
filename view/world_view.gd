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

var session # LocalSession or a networked session with the same API
var client: ClientState
var camera: Camera2D

var _tiles_by_depth := {} # depth -> Array[Vector2i]
var _max_depth := 0
var _graveyards := {}
var _float_texts: Array = [] # {actor, text, color, t, row}
var _font: Font
var _landmarks: Array[ZoneLandmark] = []
## Labels, bars and markers queued while drawing actors, drawn last so terrain
## and other actors never cover them.
var _overlay: Array[Callable] = []


func setup(p_session, p_client: ClientState, zone: ZoneDef) -> void:
	session = p_session
	client = p_client
	_font = ThemeDB.fallback_font
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
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.zoom = Vector2(1.5, 1.5)
	add_child(camera)
	session.events_received.connect(_on_events)


func _process(delta: float) -> void:
	if session == null:
		return
	var hero: Actor = session.local_hero()
	if hero != null:
		camera.position = actor_screen_pos(hero)
	var t: float = session.render_time()
	_float_texts = _float_texts.filter(func(f): return t - f.t < FLOAT_TEXT_SECONDS)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = (camera.zoom * 1.1).clamp(Vector2(0.5, 0.5), Vector2(3, 3))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = (camera.zoom / 1.1).clamp(Vector2(0.5, 0.5), Vector2(3, 3))


## Interpolated screen position of an actor's feet.
func actor_screen_pos(actor: Actor) -> Vector2:
	var grid: GridModel = session.grid()
	var m := actor.move
	var k := m.progress(session.render_time())
	var tile := Vector2(m.from_tile).lerp(Vector2(m.to_tile), k)
	var h := lerpf(grid.height_at(m.from_tile), grid.height_at(m.to_tile), k)
	return Iso.to_screen(tile, h)


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
	var actors_by_depth := {}
	for a in session.actors():
		var d := maxi(Iso.depth(a.move.from_tile), Iso.depth(a.move.to_tile))
		if not actors_by_depth.has(d):
			actors_by_depth[d] = []
		actors_by_depth[d].append(a)
	var quest_areas := _quest_area_tiles()
	_overlay.clear()
	for d in range(_max_depth + 1):
		for p in _tiles_by_depth.get(d, []):
			_draw_tile(grid, p)
			if quest_areas.has(p):
				_draw_quest_area(grid, p)
		for a in actors_by_depth.get(d, []):
			_draw_actor(a)
	_draw_projectiles(grid)
	_draw_landmarks(grid)
	_draw_talk_prompt()
	for f in _overlay:
		f.call()
	_draw_float_texts()


func _draw_tile(grid: GridModel, p: Vector2i) -> void:
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


func _draw_actor(a: Actor) -> void:
	var feet := actor_screen_pos(a)
	var now: float = session.now()
	var is_target := client != null and client.target_id == a.id
	if is_target:
		_draw_ellipse(feet, 20, 9, Color(1, 0.9, 0.2), 2.0)
	var body := feet + Vector2(0, -14)
	var alpha := 0.45 if a.evading else 1.0
	if a.alive:
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
		if not a.alive:
			return
		var c := Color(ENEMY_COLOR, alpha)
		var edef := (a as Enemy).def
		var s := 1.6 if edef.elite else 1.0
		var diamond := PackedVector2Array([body + Vector2(0, -12) * s, body + Vector2(10, 0) * s,
				body + Vector2(0, 12) * s, body + Vector2(-10, 0) * s])
		draw_colored_polygon(diamond, c)
		if edef.elite:
			diamond.append(diamond[0])
			draw_polyline(diamond, Color(1, 0.8, 0.2, alpha), 2.0)
			_draw_label(body + Vector2(0, -32), "Elite %s  Lv%d" % [a.display_name, edef.level], Color(1, 0.85, 0.3, alpha))
		else:
			_draw_label(body + Vector2(0, -26), "%s  Lv%d" % [a.display_name, edef.level], Color(1, 0.8, 0.8, alpha))
	if a.alive:
		var max_hp := a.current_stats(now).hp
		_draw_bar(body + Vector2(-14, -20), 28, a.hp / maxf(max_hp, 1.0), Color(0.2, 0.85, 0.3))


## Projectiles: a glowing ball moving along its path at the origin's height.
## Heroes' are orange, enemies' purple.
func _draw_projectiles(grid: GridModel) -> void:
	var t: float = session.render_time()
	for p in session.projectiles():
		var dist := clampf((t - p.start) * p.speed, 0.0, p.length + 0.5)
		var pos := Vector2(p.origin) + Vector2(p.dir) * dist
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


## Queues a centred label for the overlay pass.
func _draw_label(pos: Vector2, text: String, color: Color, size: int = 11) -> void:
	_overlay.append(func(): _draw_label_now(pos, text, color, size))


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


func _draw_float_texts() -> void:
	var t: float = session.render_time()
	for f in _float_texts:
		var actor: Actor = session.get_actor(f.actor)
		if actor == null:
			continue
		var age: float = (t - f.t) / FLOAT_TEXT_SECONDS
		var pos := actor_screen_pos(actor) + Vector2(0, -50 - age * 30 - f.row * 14)
		_draw_label_now(pos, f.text, Color(f.color, 1.0 - age), 12)


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


## Texts that pop up together on one actor stack instead of overlapping.
func _float(actor_id: int, text: String, color: Color, t: float) -> void:
	var row := 0
	for f in _float_texts:
		if f.actor == actor_id and t - f.t < 0.4:
			row = maxi(row, f.row + 1)
	_float_texts.append({"actor": actor_id, "text": text, "color": color, "t": t, "row": row})


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
					if GridModel.distance(p, o.tile) <= o.radius:
						out[p] = true
	return out


func _draw_quest_area(grid: GridModel, p: Vector2i) -> void:
	var c := Iso.to_screen(Vector2(p), grid.height_at(p))
	var pulse := 0.35 + 0.25 * sin(Time.get_ticks_msec() / 250.0)
	var hw := Iso.TILE_W * 0.5 - 4
	var hh := Iso.TILE_H * 0.5 - 2
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh),
			c + Vector2(-hw, 0)]), Color(1, 0.85, 0.2, pulse))


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
	var pos := actor_screen_pos(npc) + Vector2(0, y)
	_overlay.append(func():
		var text := "[E] Talk"
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_rect(Rect2(pos - Vector2(w * 0.5 + 6, 14), Vector2(w + 12, 19)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(pos - Vector2(w * 0.5 + 6, 14), Vector2(w + 12, 19)), Color(1, 0.85, 0.3), false, 1.0)
		_draw_label_now(pos, text, Color(1, 0.95, 0.6), 13))
