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
## Water Shield's effect: the rope leaves for the bubble (WaterShieldRope).
const SHIELD_FX := &"water_shield_rope"
## Debug colours (the reference's): points, the front, the return path and entry mark.
const PT := Color("D4537E")
const TIPC := Color("EF9F27")

var settings: WaterRopeSettings
## hero id -> {"rope": WaterRope, "ground": Vector2 (reference px), "off": bool, "hero": Hero}
var ropes := {}
## Water Shield ropes, by caster id: {"rope": WaterShieldRope, "ground", "off", "hero",
## "target": actor id} (the caster's own rope refills meanwhile).
var shields := {}
## Frost Shard pieces in flight, freezing: {"hero", "p": projectile dict, "off":
## [Vector3] (each point from the piece's centre), "z0", "ground" (the caster's at
## launch), "age" (frames), "dir" (ground px)}.
var shards: Array = []
var _new_shards: Array = []
## Frost Shard's ice after it froze: sparkles, and fragments when it shatters. Each
## {"hero", "p": Vector3 (ground px, absolute), "v", "l", ...}.
var sparks: Array = []
var frags: Array = []


## Projectiles WaterRopes draws itself (the world view's generic ball skips them).
static func draws_projectile(p: Dictionary) -> bool:
	return StringName(p.get("ability", "")) == &"W04"
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
		if e.get("ability", &"") == &"W07":
			# Leeching Tide: the hoop reaches out as the channel starts, and stops drawing
			# water when it ends.
			if e.get("type", "") == "cast_start":
				_pending.append({"source": int(e.get("source", -1)), "to": Vector2(e.get("to", Vector2.ZERO)),
						"at": -INF, "fx": &"leech"})
			elif e.get("type", "") in ["channel_end", "cast_cancel"]:
				var lr := rope_of(int(e.get("source", -1)))
				if lr != null:
					lr.end_leech()
			continue
		if e.get("type", "") == "projectile" and e.get("projectile", {}).get("ability", &"") == &"W04":
			_new_shards.append(e.projectile) # Frost Shard: a piece of the rope breaks off
			continue
		if e.get("type", "") == "projectile_end":
			for sd in shards: # it hit something, or reached its range: it shatters
				if int(sd.p.get("id", -1)) == int(e.get("id", -2)):
					sd.ended = true
					sd.hit = int(e.get("target", -1)) >= 0
			continue
		if e.get("type", "") == "water_return":
			# Water Whip's second press, or what Healing Touch's heal didn't need:
			# that share of the water out comes home.
			var r := rope_of(int(e.get("source", -1)))
			if e.get("ability", &"") == &"W12" and shields.has(int(e.get("source", -1))):
				var sh: WaterShieldRope = shields[int(e.get("source", -1))].rope
				if float(e.get("share", 0.0)) <= 0.0:
					sh.pop() # broken: all of it lost
				else:
					sh.unwind(float(e.get("share", 0.0)))
				continue
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
					"at": float(e.get("at", 0.0)), "fx": fx.id, "target": int(e.get("target", -1)),
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
			if h.water_out.is_empty() and h.shield_out.is_empty() and not _shield_coming_home(h.id):
				e.rope.set_count(h.stance_water) # (the shield holds the rope: no rebuild, 2026-11-28)
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
		if _shield_coming_home(h.id) and now < float(t.at) + RECALL_WAIT:
			keep.append(t) # a recalled shield's rope first gets home, then this goes
			continue
		_adopt_shield(h)
		var e: Dictionary = ropes.get(h.id, {})
		if e.is_empty() or e.rope.st == "drain":
			e = _new_entry(h)
			e.rope.fill_now(mini(h.stance_water, settings.NMAX))
		var aim: Vector2 = ground_of(t.to) - e.ground
		if t.get("fx", &"") == &"leech":
			e.rope.leech(aim)
			continue
		if t.get("fx", &"") == SHIELD_FX:
			_send_shield(h, e, aim, bool(t.get("self", false)), int(t.get("target", -1)))
			continue
		if t.get("fx", &"") == HEAL_FX:
			e.rope.heal(aim, bool(t.get("self", false)))
			continue
		var dz := (float(grid.height_at(MoveState.tile_of(t.to))) - h.move.ground_h) * 8.0 / settings.WATER_SCALE \
				if grid != null else 0.0
		e.rope.cast(aim, dz)
	_pending = keep
	# Frost Shard: the piece breaks off its caster's rope as the shard is thrown.
	for p in _new_shards:
		var h: Hero = by_id.get(int(p.get("source", -1)))
		var e: Dictionary = ropes.get(int(p.get("source", -1)), {})
		var sh: Dictionary = shields.get(int(p.get("source", -1)), {})
		var off_shield: bool = not sh.is_empty() and sh.rope.st == "shield"
		if off_shield:
			e = sh # thrown off the Water Shield (its bubble, toward the shot)
		if h == null or e.is_empty():
			continue
		var dir_t: Vector2 = FxPainter.projectile_dir(p)
		var dir_px: Vector2 = ground_of(h.move.pos + dir_t) - ground_of(h.move.pos)
		var pts: Array[Vector3] = e.rope.throw_shard(dir_px, settings.SHARD_PIECE) if off_shield \
				else e.rope.break_piece(dir_px, settings.SHARD_PIECE)
		if pts.is_empty():
			continue
		var c := Vector3.ZERO
		for q in pts:
			c += q
		c /= pts.size()
		var off: Array = []
		for q in pts:
			off.append(q - c)
		# The piece's centre relative to where the shard starts (the caster).
		var start_px: Vector2 = ground_of(FxPainter.projectile_pos(p, float(p.start))) - e.ground
		shards.append({"hero": h.id, "p": p, "off": off, "c0": c - Vector3(start_px.x, start_px.y, 0.0),
				"ground": e.ground, "age": 0, "dir": dir_px.normalized(), "ended": false, "hit": false})
	_new_shards.clear()
	# Shields follow their target and the host's shield left.
	for id in shields.keys():
		var sh: Dictionary = shields[id]
		var h: Hero = by_id.get(id)
		if h == null:
			shields.erase(id)
			continue
		var g := ground_of(h.move.pos)
		sh.rope.move_hero(g - sh.ground)
		sh.ground = g
		sh.hero = h
		sh.off = not on_screen.call(h)
		var tgt: Actor = by_id.get(int(sh.target), h)
		sh.rope.follow_target(ground_of(tgt.move.pos) - g)
		if not h.shield_out.is_empty():
			sh.rope.set_left(float(h.shield_out.get("left", 1.0)))
		if sh.rope.st == "idle":
			_adopt_shield(h) # home: it is the rope again (or flows into the hip)
	_acc = minf(_acc + dt, STEP * 30.0)
	while _acc >= STEP:
		_acc -= STEP
		for id in ropes.keys():
			var e: Dictionary = ropes[id]
			if not e.off:
				e.rope.step()
			if e.rope.done():
				ropes.erase(id)
		for id in shields.keys():
			var sh: Dictionary = shields[id]
			sh.rope.step()
			if sh.rope.done():
				shields.erase(id)
		_step_ice()


## Water Shield cast: the caster's rope leaves for the bubble round `target`; the
## caster's rope then grows back from the source (the host refills it).
func _send_shield(h: Hero, e: Dictionary, aim: Vector2, self_cast: bool, target_id: int) -> void:
	var r: WaterRope = e.rope
	r.leave_hoop_now()
	var n := int(h.shield_out.get("points", r.M()))
	if r.M() < maxi(n, 2) and r.can_cast():
		r.fill_now(maxi(n, settings.MIN_KEEP)) # the whole rope goes, never part of it
	elif r.M() < 2:
		r.fill_now(maxi(r.M(), settings.MIN_KEEP))
	_seed += 1
	var sh := WaterShieldRope.new(settings, hash([h.id, _seed, "shield"]))
	sh.source = r.source
	var pts: Array[WaterRope.Pt] = r.R.duplicate()
	sh.cast_shield(pts, Vector2.ZERO if self_cast else aim, self_cast, r.phase, r.w)
	r.R.clear()
	r.conn.clear()
	r.strength = PackedFloat32Array()
	r.st = "idle"
	r.tt = 0
	r.target_count = 0 # the shield holds the rope: nothing regrows until it comes home
	shields[h.id] = {"rope": sh, "ground": e.ground, "off": false, "hero": h,
			"target": h.id if self_cast else target_id}


## A recalled or run-out shield's rope on its way home.
func _shield_coming_home(id: int) -> bool:
	return shields.has(id) and shields[id].rope.st in ["return", "wrap"]


## How long (host seconds) a throw waits for a recalled shield's rope to get home.
const RECALL_WAIT := 0.6


## A shield's rope coming home becomes the hero's rope again, where its points are,
## when the rope is empty (the shield held all of it); else it flows into the hip.
func _adopt_shield(h: Hero) -> void:
	if not shields.has(h.id):
		return
	var sh: WaterShieldRope = shields[h.id].rope
	if sh.st in ["shield", "shield_fall"]:
		return
	var e: Dictionary = ropes.get(h.id, {})
	if e.is_empty() or e.rope.st == "drain" or e.rope.M() > 0 or not h.rope:
		sh.drain()
		return
	var r: WaterRope = e.rope
	r.R = sh.R
	r.conn = sh.conn
	r.strength = sh.strength
	r.phase = sh.phase
	r.w = sh.w
	r.st = "idle"
	r.tt = 0
	r.forming = false
	r.target_count = r.M()
	sh.R = []
	sh.conn = []
	sh.strength = PackedFloat32Array()
	sh.drain()


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
	for id in shields:
		var e: Dictionary = shields[id]
		if e.off:
			continue
		out.append_array(_rope_items(e, feet.call(e.hero) / PixelCamera.ART_SCALE))
	for sd in shards:
		var e: Dictionary = ropes.get(int(sd.hero), {})
		if e.is_empty() or e.off:
			continue
		var tmp := _shard_rope(sd, e.ground)
		if tmp != null:
			out.append_array(_rope_items({"rope": tmp, "hero": e.hero}, feet.call(e.hero) / PixelCamera.ART_SCALE))
	out.append_array(_ice_items(feet))
	return out


## Frost Shard after the throw (2026-11-28, as frost_shard_demo.html): it freezes
## (sparkles), flies as ice, and shatters into fragments and two drops where it hits
## or at the end of its range.
func _step_ice() -> void:
	var s := settings
	var keep := []
	for sd in shards:
		sd.age += 1
		var c := shard_centre(sd)
		if sd.age == s.SHARD_FREEZE:
			for k in s.SPARK_N:
				sparks.append({"hero": sd.hero, "p": c + Vector3(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5),
						randf_range(-2, 2)), "l": randf_range(8, 14)})
		var flight: float = float(sd.p.get("length", 0.0)) / maxf(float(sd.p.get("speed", 1.0)), 0.001)
		if sd.ended or sd.age / 60.0 > flight + 0.3:
			var d := Vector3(sd.dir.x, sd.dir.y, 0.0) * (-0.4 if sd.hit else 1.0)
			for k in s.FRAG_N:
				frags.append({"hero": sd.hero, "p": c, "v": Vector3(d.x * 0.6 + randf_range(-0.7, 0.7),
						d.y * 0.6 + randf_range(-0.7, 0.7), randf_range(0.4, 1.6)),
						"l": randf_range(30, 50), "hi": k % 3 == 0, "gnd": false})
			for k in 2:
				frags.append({"hero": sd.hero, "p": c, "v": Vector3(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6),
						randf_range(0.6, 1.6)), "l": 30.0, "drop": true, "gnd": false})
			continue
		keep.append(sd)
	shards = keep
	for f in frags:
		f.p += f.v
		f.v.x *= 0.92 if not f.has("drop") else 0.9
		f.v.y *= 0.92 if not f.has("drop") else 0.9
		f.v.z -= s.FRAG_GRAV
		f.l -= 1.0
		if f.p.z < 0.0:
			f.p.z = 0.0
			f.v.z *= -0.25
			f.v.x *= 0.4
			f.v.y *= 0.4
			f.gnd = true
	frags = frags.filter(func(f): return f.l > 0.0)
	for sp in sparks:
		sp.l -= 1.0
	sparks = sparks.filter(func(sp): return sp.l > 0.0)


## The shard's centre now (ground px, absolute: ground_of of its path, at its height).
func shard_centre(sd: Dictionary) -> Vector3:
	var s := settings
	var a := float(sd.age)
	var flight_end: float = float(sd.p.start) + float(sd.p.get("length", 0.0)) / maxf(float(sd.p.get("speed", 1.0)), 0.001)
	var t: float = minf(float(sd.p.start) + a / 60.0, flight_end)
	var g := ground_of(FxPainter.projectile_pos(sd.p, t))
	var k := WaterRope.ramp(a, float(s.SHARD_FREEZE))
	var z: float = lerpf(float(sd.c0.z), s.TARGET_Z, k)
	return Vector3(g.x + sd.c0.x * (1.0 - k), g.y + sd.c0.y * (1.0 - k), z)


## Draw items for the ice (shards in flight, sparkles, fragments), relative to the
## hero who threw them.
func _ice_items(feet: Callable) -> Array:
	var s := settings
	var groups := {}
	var put := func(hero_id: int, kind: String, g: Vector3, piece: Array, ground_level := false) -> void:
		var e: Dictionary = ropes.get(hero_id, {})
		if e.is_empty() or e.off:
			return
		var rel: Vector2 = Vector2(g.x, g.y) - Vector2(e.ground)
		var tile := MoveState.tile_of((e.hero as Hero).move.pos + tiles_of(rel))
		var key := [hero_id, tile, ground_level, kind]
		if not groups.has(key):
			groups[key] = {"rope": true, "pos": Vector2(tile), "behind": ground_level,
					"origin": feet.call(e.hero) / PixelCamera.ART_SCALE, kind: []}
		piece[0] = _proj(Vector3(rel.x, rel.y, g.z))
		groups[key][kind].append(piece)
	for sd in shards:
		var fp := WaterRope.ramp(float(sd.age), float(s.SHARD_FREEZE))
		if fp <= 0.05:
			continue
		var c := shard_centre(sd)
		var d := _proj(Vector3(sd.dir.x, sd.dir.y, 0.0))
		d = d.normalized() if d.length() > 0.0 else Vector2.RIGHT
		put.call(sd.hero, "ice", c, [Vector2.ZERO, d, maxf(2.0, s.SHARD_LEN * fp), maxf(0.6, s.SHARD_W * fp)])
		put.call(sd.hero, "shadows", Vector3(c.x, c.y, 0.0), [Vector2.ZERO, maxi(1, roundi(s.SHARD_LEN * fp * 0.5))], true)
	for f in frags:
		if f.p.z > 1.0:
			put.call(f.hero, "shadows", Vector3(f.p.x, f.p.y, 0.0), [Vector2.ZERO, 1], true)
		var col: Color = s.DROP if f.has("drop") or (f.gnd and f.l < 15.0) else (s.ICE_HI if f.hi else s.ICE_BODY)
		put.call(f.hero, "frags", f.p, [Vector2.ZERO, col])
	for sp in sparks:
		put.call(sp.hero, "sparks", sp.p, [Vector2.ZERO, sp.l > 8.0])
	return groups.values()


## A Frost Shard piece as a short rope to draw: its points pull together toward the
## shard's centre (flying along the shard's path) over SHARD_FREEZE frames, after
## bulging outward and leaning toward the target; drawn as water until 75% of the
## freeze, thinning to 55% width; then 3 sparkles (the shard sprite takes over).
func _shard_rope(sd: Dictionary, ground_now: Vector2) -> WaterRope:
	var s := settings
	var a := float(sd.age)
	var t: float = float(sd.p.start) + a / 60.0
	var c_px: Vector2 = ground_of(FxPainter.projectile_pos(sd.p, t)) - ground_now
	var k := WaterRope.ramp(a, float(s.SHARD_FREEZE))
	var z: float = lerpf(float(sd.c0.z), s.TARGET_Z, k)
	var start_px: Vector2 = ground_of(FxPainter.projectile_pos(sd.p, float(sd.p.start))) - ground_now
	var c := Vector3(c_px.x, c_px.y, z) + Vector3(sd.c0.x, sd.c0.y, 0.0) * (1.0 - k)
	var bulge := WaterRope.ramp(a, float(s.SHARD_WINDUP)) * (1.0 - k)
	var out_dir := Vector3(start_px.x + sd.c0.x, start_px.y + sd.c0.y, 0.0)
	out_dir = out_dir.normalized() if out_dir.length() > 0.0 else Vector3.ZERO
	var lean := Vector3(sd.dir.x, sd.dir.y, 0.0)
	var r := WaterRope.new(s, 1)
	r.fr = int(a)
	if a <= s.SHARD_FREEZE * 0.75:
		for i in sd.off.size():
			var q: Vector3 = c + sd.off[i] * (1.0 - k) + (out_dir * s.SHARD_BULGE + lean * s.SHARD_LEAN) * bulge
			r.R.append(WaterRope.Pt.new(q, i))
		for i in maxi(r.M() - 1, 0):
			r.conn.append(true)
			r.strength.append(1.0)
		r.wscale = lerpf(1.0, 0.55, clampf(a / (s.SHARD_FREEZE * 0.75), 0.0, 1.0))
	return r


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
	var D: Array[float] = [] # Leeching Tide's tint per point
	for pt in r.R:
		P.append(pt.p)
		D.append(pt.dark)
	for pt in r.heal_tail:
		P.append(pt.p)
		D.append(0.0)
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
	if r is WaterShieldRope:
		r_amp *= (r as WaterShieldRope).rboost # a hit's ripple
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
			radius = maxf(0.55, radius * r.wscale) # Water Shield thins as it stretches
			put.call("stamps", Vector2(lerpf(a.x, c.x, k), lerpf(a.y, c.y, k)),
					[at, radius, nrm, nrm.dot(sun), lerpf(D[sg[0]], D[sg[1]], k) > 0.5])
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
		# Leeched water (a stamp's 5th value) in the leech tint.
		var out_c := func(q) -> Color: return s.LOUT if q.size() > 4 and q[4] else s.OUT
		var body_c := func(q) -> Color: return s.LBODY if q.size() > 4 and q[4] else s.BODY
		var hi_c := func(q) -> Color: return s.LHI if q.size() > 4 and q[4] else s.HI
		for q in S2:
			disc.call(q[0].x - q[2].x, q[0].y - q[2].y, q[1], out_c.call(q))
		for q in S2:
			disc.call(q[0].x, q[0].y, q[1], body_c.call(q))
		for q in S2:
			var r: float = q[1]
			if q[3] > s.FACE_T and r > s.SHADE2_MIN_R:
				px.call(q[0].x - q[2].x * (r - 0.45), q[0].y - q[2].y * (r - 0.45), out_c.call(q))
		for q in S2:
			var r: float = q[1]
			if r > s.HI_MIN_R:
				px.call(q[0].x + q[2].x * (r - 1.0), q[0].y + q[2].y * (r - 1.0), hi_c.call(q))
				if q[3] > s.FACE_T and r > s.HI2_MIN_R:
					px.call(q[0].x + q[2].x * (r - 2.0), q[0].y + q[2].y * (r - 2.0), hi_c.call(q))
			elif r > 0.9: # thin water (the rope's ends, a stretched shield): one lit pixel
				if q[3] > 0.3:
					px.call(q[0].x + q[2].x * maxf(0.0, r - 1.0), q[0].y + q[2].y * maxf(0.0, r - 1.0), hi_c.call(q))
			elif q[3] > s.FACE_T:
				px.call(q[0].x, q[0].y, hi_c.call(q))
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
		# Two pixels each, lit, outlined below (2026-11-28, user: they were too faint).
		for d in item.drops:
			px.call(d[0].x, d[0].y + 1, s.OUT, 2, 1)
			px.call(d[0].x, d[0].y, s.DROP, 2, 1)
			px.call(d[0].x, d[0].y, s.HI)
	if item.has("ice"):
		# The demo's shardShape: a point ahead, a rounder tail; outlined below-right,
		# lit on the side toward the sun (ice body, shade, highlight on its top edges).
		for q in item.ice:
			_draw_shard(px, q[0], q[1], q[2], q[3])
	if item.has("frags"):
		for f in item.frags:
			px.call(f[0].x + 1, f[0].y + 1, s.OUT)
			px.call(f[0].x, f[0].y, f[1])
	if item.has("sparks"):
		for sp in item.sparks:
			px.call(sp[0].x, sp[0].y, s.ICE_HI)
			if sp[1]:
				px.call(sp[0].x - 1, sp[0].y, s.ICE_HI)
				px.call(sp[0].x + 1, sp[0].y, s.ICE_HI)
				px.call(sp[0].x, sp[0].y - 1, s.ICE_HI)
				px.call(sp[0].x, sp[0].y + 1, s.ICE_HI)
	if item.has("mists"):
		# Drifting mist pixels, dithering out in their last 30%.
		for m in item.mists:
			var q: float = m[1]
			if q < 0.3 and int(m[2]) == 1:
				continue
			px.call(m[0].x, m[0].y, s.HI if q > 0.55 else s.DROP, 2 if q > 0.7 else 1, 1)


## The demo's shard: pixels whose centre lies inside a spindle `len` long and `wid`
## half-wide along `d` (pointed ahead, rounder behind), at `c` (art px).
static func shard_pixels(c: Vector2, d: Vector2, len: float, wid: float) -> Dictionary:
	var half := len / 2.0
	var set := {}
	var R := ceili(half) + 2
	var X := roundi(c.x)
	var Y := roundi(c.y)
	for y in range(Y - R, Y + R + 1):
		for x in range(X - R, X + R + 1):
			var ex := x + 0.5 - c.x
			var ey := y + 0.5 - c.y
			var u := ex * d.x + ey * d.y
			var v := -ex * d.y + ey * d.x
			if u > half or u < -half:
				continue
			var wu := wid * (1.0 - u / half) if u >= 0.0 else wid * (1.0 - pow(-u / half, 2.2))
			if absf(v) <= wu + 0.35:
				set[Vector2i(x, y)] = true
	return set


func _draw_shard(px: Callable, c: Vector2, d: Vector2, len: float, wid: float) -> void:
	var s := settings
	var set := shard_pixels(c, d, len, wid)
	var side := Vector2(-d.y, d.x)
	if side.dot(s.SUN) < 0.0:
		side = -side
	for k in set:
		for o in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			if not set.has(k + o):
				px.call(k.x + o.x, k.y + o.y, s.OUT)
	for k in set:
		var v := (Vector2(k) + Vector2(0.5, 0.5) - c).dot(side)
		px.call(k.x, k.y, s.ICE_BODY if v > -0.3 else s.ICE_SHADE)
	for k in set:
		var v := (Vector2(k) + Vector2(0.5, 0.5) - c).dot(side)
		if v > 0.0 and (not set.has(k - Vector2i(1, 0)) or not set.has(k - Vector2i(0, 1))):
			px.call(k.x, k.y, s.ICE_HI)


## The screen box an item can touch (world px), for the terrain cache.
func rect_of(item: Dictionary) -> Rect2:
	var o: Vector2 = item.origin
	var r := Rect2(o * PixelCamera.ART_SCALE, Vector2.ZERO)
	for kind in ["stamps", "blobs", "drops", "shadows", "puddles", "mists", "ice", "frags", "sparks"]:
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
