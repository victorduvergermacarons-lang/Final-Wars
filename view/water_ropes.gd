class_name WaterRopes
extends RefCounted
## Every hero's water rope on this player's screen (2026-11-26): one WaterRope per
## hero holding Water stance 1 with water (the host's `rope` flag in snapshots), thrown
## by the Water Whip's effect event (FxDef.Path.ROPE: when and where, nothing more).
## Purely cosmetic and each player's own: the host decides the hit (0.5 s after the
## release) and the water spent. Stepped at a fixed 60 per second of game time (the
## game speed slows it like everything else), skipped for heroes off screen.
##
## Drawing: the reference's draw(), in our pixels: ripple slices lit by a sun at the
## top left, a dark rim on the shaded side, highlight rows, lit balls for the tip and
## loose points, splash pixels, shadows and soaking puddles. Every piece is filed
## under the tile it is over (WorldView's back-to-front pass); on the hero's own tile
## the part behind the hero (smaller depth) goes before the hero.

const STEP := 1.0 / 60.0
## Healing Touch's effect: the rope winds round the target (WaterRope.heal).
const HEAL_FX := &"water_heal_helix"
## Debug colours (the reference's): points, the front, the return path and entry mark.
const PT := Color("D4537E")
const TIPC := Color("EF9F27")

var settings: WaterRopeSettings
## hero id -> {"rope": WaterRope, "ground": Vector2 (reference px), "off": bool, "hero": Hero}
var ropes := {}
var _pending: Array = [] # throws not reached yet: {"source", "to", "at"}
var _acc := 0.0
## Shadow pixels already darkened this frame (world px): overlapping shadows (two
## ropes, a rope over its own drops) darken a pixel only once.
var _shadow_seen := {}
var _seed := 1


func _init(s: WaterRopeSettings = null) -> void:
	settings = s if s != null else load("res://content/effects/water_rope_settings.tres")


## A tile-space point on the ground, in reference pixels (x right, y into the screen).
func ground_of(p: Vector2) -> Vector2:
	return Vector2((p.x - p.y) * 16.0, (p.x + p.y) * 16.0) / settings.WATER_SCALE


## A ground offset in reference pixels as a tile-space offset.
func tiles_of(g: Vector2) -> Vector2:
	var a := g * settings.WATER_SCALE
	return Vector2((a.x + a.y) / 32.0, (a.y - a.x) / 32.0)


## Takes the throws from an event batch (the Water Whip's effect events).
func on_events(events: Array, effects: Dictionary) -> void:
	for e in events:
		if e.get("type", "") == "water_return":
			# Water Whip's second press, or what Healing Touch's heal didn't need:
			# that share of the water out comes home.
			var r := rope_of(int(e.get("source", -1)))
			if r != null:
				if r.st == "heal":
					r.heal_back(float(e.get("share", 0.0)))
				else:
					r.call_back(float(e.get("share", 0.0)))
			continue
		if e.get("type", "") != "fx":
			continue
		var fx: FxDef = effects.get(StringName(e.get("fx", "")))
		if fx != null and fx.ribbon and fx.path == FxDef.Path.ROPE:
			_pending.append({"source": int(e.get("source", -1)), "to": Vector2(e.get("to", Vector2.ZERO)),
					"at": float(e.get("at", 0.0)), "fx": fx.id,
					"self": int(e.get("target", -1)) == int(e.get("source", -1))})


## Moves every rope on by `dt` seconds of game time at `now` (host time).
## `heroes`: the zone's heroes; `grid`: for heights; `zone`: for its water;
## `on_screen`: Callable(Hero) -> bool.
func advance(dt: float, now: float, heroes: Array, grid: GridModel, zone: ZoneDef, on_screen: Callable,
		water_near: float = 3.0) -> void:
	var by_id := {}
	for h in heroes:
		by_id[h.id] = h
	var water := WaterTiles.of(zone)
	for h: Hero in heroes:
		var wants := h.rope and h.alive
		var e: Dictionary = ropes.get(h.id, {})
		if wants and (e.is_empty() or e.rope.st == "drain"):
			e = _new_entry(h)
		if e.is_empty():
			continue
		if not wants and e.rope.st != "drain":
			e.rope.drain()
		var g := ground_of(h.move.pos)
		if wants:
			e.rope.set_stance(h.stance)
			if h.water_out.is_empty():
				e.rope.set_count(h.stance_water)
		e.rope.move_hero(g - e.ground)
		e.ground = g
		e.hero = h
		# Where new water comes from: a water tile near, else the hips (the pouch).
		var w = WaterTiles.nearest(water, h.move.pos, water_near)
		e.rope.source = Vector3(0, 0, settings.HIP_Z) if w == null \
				else Vector3(ground_of(Vector2(w)).x - g.x, ground_of(Vector2(w)).y - g.y, 0.0)
		var vis: bool = on_screen.call(h)
		if not vis:
			e.off = true
		elif e.off:
			e.off = false
			if e.rope.st != "drain":
				e.rope.fill_now(mini(h.stance_water, settings.NMAX)) # back on screen: on its orbit, as if it had been all along
	for id in ropes.keys():
		if not by_id.has(id):
			ropes.erase(id) # left the zone
	# Throws whose moment has come.
	var keep := []
	for t in _pending:
		if float(t.at) > now:
			keep.append(t)
			continue
		var h: Hero = by_id.get(t.source)
		if h == null:
			continue
		var e: Dictionary = ropes.get(h.id, {})
		if e.is_empty() or e.rope.st == "drain":
			e = _new_entry(h)
			e.rope.fill_now(mini(h.stance_water, settings.NMAX))
		var aim: Vector2 = ground_of(t.to) - e.ground
		if t.get("fx", &"") == HEAL_FX:
			e.rope.heal(aim, bool(t.get("self", false)))
			continue
		var dz := (float(grid.height_at(MoveState.tile_of(t.to))) - h.move.ground_h) * 8.0 / settings.WATER_SCALE \
				if grid != null else 0.0
		e.rope.cast(aim, dz)
	_pending = keep
	_acc = minf(_acc + dt, STEP * 30.0)
	while _acc >= STEP:
		_acc -= STEP
		for id in ropes.keys():
			var e: Dictionary = ropes[id]
			if not e.off:
				e.rope.step()
			if e.rope.done():
				ropes.erase(id)


func _new_entry(h: Hero) -> Dictionary:
	_seed += 1
	var r := WaterRope.new(settings, hash([h.id, _seed]))
	r.source = Vector3(0, 0, settings.HIP_Z)
	var e := {"rope": r, "ground": ground_of(h.move.pos), "off": false, "hero": h}
	ropes[h.id] = e
	return e


func rope_of(hero_id: int) -> WaterRope:
	var e: Dictionary = ropes.get(hero_id, {})
	return e.rope if not e.is_empty() else null


# --- Drawing ------------------------------------------------------------------------

## The reference's width: tapered, thickest a little past the middle, wobbling.
func rad(f: float, fr: int) -> float:
	return 0.5 + 1.3 * sin(PI * (0.12 + f * 0.82)) + sin(f * 4.0 - fr * 0.06) * 0.15


## Pieces to draw this frame, each {"rope": true, "pos": tile-space point (its tile),
## "behind": bool, "origin": art px of the hero's feet, plus one of "stamps",
## "blobs", "drops", "shadows", "puddles"}. `feet`: Callable(Hero) -> the hero's feet
## on screen (world px).
func items(feet: Callable) -> Array:
	_shadow_seen.clear()
	var out := []
	for id in ropes:
		var e: Dictionary = ropes[id]
		if e.off:
			continue
		out.append_array(_rope_items(e, feet.call(e.hero) / PixelCamera.ART_SCALE))
	return out


func _proj(p: Vector3) -> Vector2:
	return Vector2(p.x, p.y * settings.K - p.z) * settings.WATER_SCALE


func _rope_items(e: Dictionary, origin: Vector2) -> Array:
	var s := settings
	var r: WaterRope = e.rope
	var hero: Hero = e.hero
	var groups := {} # [tile, behind] -> item
	var put := func(kind: String, ground: Vector2, piece: Array, ground_level := false) -> void:
		var at: Vector2 = hero.move.pos + tiles_of(ground)
		var tile := MoveState.tile_of(at)
		var behind := ground_level or (tile == hero.tile() and ground.y < 0.0)
		var key := [tile, behind, kind]
		if not groups.has(key):
			groups[key] = {"rope": true, "pos": Vector2(tile), "behind": behind, "origin": origin, kind: []}
		groups[key][kind].append(piece)
	var n := r.M()
	# The points to draw: the rope, then Healing Touch's front still climbing to its
	# mist after the tail went home (WaterRope.heal_tail, always linked).
	var P: Array[Vector3] = []
	for pt in r.R:
		P.append(pt.p)
	for pt in r.heal_tail:
		P.append(pt.p)
	var tail_n := r.heal_tail.size()
	# Segments to draw ([from, to, index in its chain, chain length]): each linked
	# pair, the hoop's closing link once it shows, and the climbing front.
	var b := WaterRope.ramp(r.sb, 1.0)
	var closed := r.wrap and r.wrap_str >= 0.35 and n > 2
	var segs := []
	for i in n - 1:
		if r.conn[i] and r.strength[i] >= 0.35:
			segs.append([i, i + 1, i, n])
	if closed:
		segs.append([n - 1, 0, n - 1, n])
	for j in tail_n - 1:
		segs.append([n + j, n + j + 1, j, tail_n])
	var lit := func(i: int) -> bool:
		if i >= n:
			return tail_n > 1
		return closed or (i > 0 and r.conn[i - 1] and r.strength[i - 1] >= 0.35) or (i < n - 1 and r.conn[i] and r.strength[i] >= 0.35)
	# Shadows under airborne water (on the ground: before everything on its tile).
	var shadow_w := 3 if b > 0.5 else 2 # the hoop's shadow is a pixel wider
	for sg in segs:
		var a: Vector3 = P[sg[0]]
		var c: Vector3 = P[sg[1]]
		if a.z < 1.5 and c.z < 1.5:
			continue
		var sa := _proj(Vector3(a.x, a.y, 0))
		var sc := _proj(Vector3(c.x, c.y, 0))
		var k0 := maxi(1, ceili(sa.distance_to(sc)))
		for k in k0 + 1:
			var t := float(k) / k0
			put.call("shadows", Vector2(lerpf(a.x, c.x, t), lerpf(a.y, c.y, t)), [sa.lerp(sc, t), shadow_w], true)
	for i in P.size():
		var p: Vector3 = P[i]
		if not lit.call(i) and p.z > 1.5:
			put.call("shadows", Vector2(p.x, p.y), [_proj(Vector3(p.x, p.y, 0)) - Vector2(1, 0), 3], true)
	for d in r.drops:
		if d.p.z > 1.0:
			put.call("shadows", Vector2(d.p.x, d.p.y), [_proj(Vector3(d.p.x, d.p.y, 0)), 1], true)
	for l in r.lost:
		put.call("puddles", l.p, [_proj(Vector3(l.p.x, l.p.y, 0)), l.l / float(s.SOAK_TIME)], true)
	# The rope: rippled slices, lit.
	var total := 0.0
	for sg in segs:
		total += _proj(P[sg[0]]).distance_to(_proj(P[sg[1]]))
	var rl := lerpf(s.RIPPLE_LEN, s.HOOP_RIPPLE_LEN, b)
	# A closed hoop fits a whole number of ripples round it, so they meet seamlessly.
	var kw := TAU * maxf(1.0, roundf(total / rl)) / total if closed and total > 0.0 else TAU / rl
	var r_amp := lerpf(s.RIPPLE_AMP, s.HOOP_RIPPLE_AMP, b)
	var r_speed := lerpf(s.RIPPLE_SPEED, s.HOOP_RIPPLE_SPEED, b)
	var arc := 0.0
	var sun := s.SUN.normalized()
	for sg in segs:
		var i: int = sg[0]
		var a: Vector3 = P[i]
		var c: Vector3 = P[sg[1]]
		var sa := _proj(a)
		var sc := _proj(c)
		var L := sa.distance_to(sc)
		var tdir := (sc - sa) / L if L > 0.0 else Vector2.RIGHT
		var q := Vector2(-tdir.y, tdir.x)
		var k0 := maxi(1, ceili(L))
		for st in k0:
			var k := float(st) / k0
			var f := (float(sg[2]) + k) / maxf(1.0, float(sg[3]) - 1.0)
			var u := (arc + k * L) / (total if total > 0.0 else 1.0)
			var ph := (arc + k * L) * kw - r.fr * r_speed
			var amp := r_amp if closed else r_amp * (0.4 + 0.6 * sin(PI * f))
			var at := sa.lerp(sc, k) + q * amp * sin(ph)
			var rd := (tdir + q * amp * kw * cos(ph)).normalized()
			var nrm := Vector2(-rd.y, rd.x)
			if nrm.dot(sun) < 0.0:
				nrm = -nrm
			var hoop_r := s.HOOP_BASE_R * s.THICK + sin(u * TAU * 3.0 - r.fr * 0.05) * 0.15
			var radius := hoop_r if closed else lerpf(rad(f, r.fr) + s.BODY_GROW,
					hoop_r * (0.5 + 0.5 * sin(PI * clampf(f, 0.04, 0.96))), b)
			put.call("stamps", Vector2(lerpf(a.x, c.x, k), lerpf(a.y, c.y, k)), [at, radius, nrm, nrm.dot(sun)])
		arc += L
	for i in n:
		if not lit.call(i):
			var p: Vector3 = P[i]
			var rr := maxf(0.8, rad(float(i) / maxf(1, n - 1), r.fr) * 0.75 + s.BODY_GROW * 0.6)
			put.call("blobs", Vector2(p.x, p.y), [_proj(p), rr, p.z < 1.5])
	if (r.st == "fly" or r.st == "return") and n > 0:
		var tp: Vector3 = r.R[0].p
		put.call("blobs", Vector2(tp.x, tp.y), [_proj(tp), 1.5, false])
	for d in r.drops:
		put.call("drops", Vector2(d.p.x, d.p.y), [_proj(d.p)])
	for m in r.mists: # Healing Touch's mist: [screen, life left (0–1), its dither phase]
		put.call("mists", Vector2(m.p.x, m.p.y), [_proj(m.p), m.l / m.L0, (int(m.k) + (r.fr >> 2)) & 1])
	return groups.values()


## Draws one piece list on `canvas` (WorldView), in whole art pixels.
func draw(canvas: CanvasItem, item: Dictionary) -> void:
	var s := settings
	var o: Vector2 = item.origin
	var S := PixelCamera.ART_SCALE
	var px := func(x: float, y: float, col: Color, w := 1, h := 1) -> void:
		canvas.draw_rect(Rect2((o + Vector2(roundf(x), roundf(y))).round() * S, Vector2(w, h) * S), col)
	var disc := func(x: float, y: float, r: float, col: Color) -> void:
		var cx := roundf(x)
		var cy := roundf(y)
		var R := ceili(r)
		for yy in range(-R, R + 1):
			var span := r * r + 0.3 - yy * yy
			if span < 0.0:
				continue
			var w := floori(sqrt(span))
			canvas.draw_rect(Rect2((o + Vector2(cx - w, cy + yy)).round() * S, Vector2(2 * w + 1, 1) * S), col)
	if item.has("shadows"):
		# Black at SHADOW_DARKEN over the ground = the ground × (1 − SHADOW_DARKEN):
		# a darker green on grass, a darker grey on stone. Each pixel once.
		var shade := Color(0, 0, 0, s.SHADOW_DARKEN)
		for sh in item.shadows:
			var at := (o + Vector2(roundf(sh[0].x), roundf(sh[0].y))).round()
			for k in int(sh[1]):
				var key := Vector2i(at) + Vector2i(k, 0)
				if _shadow_seen.has(key):
					continue
				_shadow_seen[key] = true
				canvas.draw_rect(Rect2(Vector2(key) * S, Vector2(S, S)), shade)
	if item.has("puddles"):
		for pd in item.puddles:
			var q: float = pd[1]
			var w := maxi(1, roundi(5.0 * q))
			if q > 0.25:
				px.call(pd[0].x - w / 2.0, pd[0].y, s.OUT, w, 1)
				px.call(pd[0].x - w / 2.0, pd[0].y - 1, s.BODY, w, 1)
			else:
				px.call(pd[0].x, pd[0].y, s.OUT)
	if item.has("stamps"):
		var S2: Array = item.stamps
		for q in S2:
			disc.call(q[0].x - q[2].x, q[0].y - q[2].y, q[1], s.OUT)
		for q in S2:
			disc.call(q[0].x, q[0].y, q[1], s.BODY)
		for q in S2:
			var r: float = q[1]
			if q[3] > s.FACE_T and r > s.SHADE2_MIN_R:
				px.call(q[0].x - q[2].x * (r - 0.45), q[0].y - q[2].y * (r - 0.45), s.OUT)
		for q in S2:
			var r: float = q[1]
			if r > s.HI_MIN_R:
				px.call(q[0].x + q[2].x * (r - 1.0), q[0].y + q[2].y * (r - 1.0), s.HI)
				if q[3] > s.FACE_T and r > s.HI2_MIN_R:
					px.call(q[0].x + q[2].x * (r - 2.0), q[0].y + q[2].y * (r - 2.0), s.HI)
	if item.has("blobs"):
		var sun := s.SUN.normalized()
		for b in item.blobs:
			var at: Vector2 = b[0]
			var r: float = b[1]
			if b[2]: # lying on the ground
				px.call(at.x - 1, at.y, s.OUT, 4, 1)
				px.call(at.x - 1, at.y - 1, s.BODY, 4, 1)
				continue
			disc.call(at.x - sun.x, at.y - sun.y, r, s.OUT)
			disc.call(at.x, at.y, r, s.BODY)
			if r > s.SHADE2_MIN_R:
				px.call(at.x - sun.x * (r - 0.45), at.y - sun.y * (r - 0.45), s.OUT)
			if r > s.HI_MIN_R - 0.4:
				px.call(at.x + sun.x * (r - 1.0), at.y + sun.y * (r - 1.0), s.HI)
				if r > s.HI2_MIN_R:
					px.call(at.x + sun.x * (r - 2.0), at.y + sun.y * (r - 2.0), s.HI)
	if item.has("drops"):
		for d in item.drops:
			px.call(d[0].x + 1, d[0].y + 1, s.OUT)
			px.call(d[0].x, d[0].y, s.DROP)
	if item.has("mists"):
		# Drifting mist pixels, dithering out in their last 30%.
		for m in item.mists:
			var q: float = m[1]
			if q < 0.3 and int(m[2]) == 1:
				continue
			px.call(m[0].x, m[0].y, s.HI if q > 0.55 else s.DROP, 2 if q > 0.7 else 1, 1)


## The screen box an item can touch (world px), for the terrain cache.
func rect_of(item: Dictionary) -> Rect2:
	var o: Vector2 = item.origin
	var r := Rect2(o * PixelCamera.ART_SCALE, Vector2.ZERO)
	for kind in ["stamps", "blobs", "drops", "shadows", "puddles", "mists"]:
		for piece in item.get(kind, []):
			r = r.expand((o + piece[0]) * PixelCamera.ART_SCALE)
	return r.grow(8.0 * PixelCamera.ART_SCALE)


## Debug, on top of everything: every point (the front orange), the target, the
## entry mark, and the return path.
func draw_debug(canvas: CanvasItem, feet: Callable, points: bool, path: bool) -> void:
	var S := PixelCamera.ART_SCALE
	for id in ropes:
		var e: Dictionary = ropes[id]
		if e.off:
			continue
		var r: WaterRope = e.rope
		var o: Vector2 = feet.call(e.hero) / S
		if points:
			for i in r.M():
				var at := (o + _proj(r.R[i].p)).round()
				canvas.draw_rect(Rect2((at - Vector2(1, 1)) * S, Vector2(3, 3) * S), TIPC if i == 0 else PT)
			var aim := (o + _proj(r.aim)).round()
			canvas.draw_rect(Rect2((aim - Vector2(1, 0)) * S, Vector2(3, 1) * S), PT)
			canvas.draw_rect(Rect2((aim - Vector2(0, 1)) * S, Vector2(1, 3) * S), PT)
			var E: Vector3 = r.entry_point().E
			var es := (o + _proj(Vector3(E.x, E.y, 0))).round()
			canvas.draw_rect(Rect2((es - Vector2(1, 0)) * S, Vector2(3, 1) * S), TIPC)
			canvas.draw_rect(Rect2((es - Vector2(0, 1)) * S, Vector2(1, 3) * S), TIPC)
		if path and r.st == "return" and not r.rpath.is_empty():
			var pts: PackedVector3Array = r.rpath.pts
			for k in range(0, pts.size(), 5):
				canvas.draw_rect(Rect2((o + _proj(pts[k])).round() * S, Vector2(S, S)), TIPC)
