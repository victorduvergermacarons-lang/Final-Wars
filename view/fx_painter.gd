class_name FxPainter
extends RefCounted
## Effect animations in the world (FxDef), for WorldView: what to draw each frame and
## where, from host times only, so every player sees the same frame:
## - "fx" events (an ability going off or released, a lob landing): played once from
##   the event's host time, from the caster toward its target or aim (rotated to
##   it), or at a point;
## - the rock a hero holds during Rock Throw's bar (AbilityDef.fx_carried): it rises
##   from the ground beside the hero while earth_root plays, then bobs;
## - a lob in flight (a pending hit with "from" and "start"): its carried sprite along
##   a parabola to where it lands, spinning.
## - a held bending stance's look (CreatureArtDef.stance_looks): a still around the
##   hero moved in code (FxDef "Held around a hero"), from the host time the stance
##   was taken, or a faint ring in the element's colour while its art isn't approved.
## WorldView draws each item in its back-to-front pass, on the tile under it.
## Items around an actor carry "actor" (drawn at its feet, "offset" tiles away);
## "behind" ones go before the actors of their tile, the rest after. Bare ground in
## front at or below their tile's height doesn't cover them (WorldView._covers).

## How high a thrown rock's arc rises above the straight line, in levels.
const ARC_PEAK_LEVELS := 1.6
## Turns a thrown rock spins in flight.
const SPIN_TURNS := 2.0
## How far the held rock bobs, in levels, and how fast (per second).
const BOB_LEVELS := 0.12
const BOB_HZ := 1.2

var _events: Array = [] # {"fx": FxDef, "from", "to", "at", "tiles", "on", "for", "fly"}
var _codes: Array = [] # code-drawn looks from events: {"code", "on", "at", "for"} (the `fx` preview)
## Particles thrown off ribbons and fronts (a fixed pool).
var particles: FxParticles:
	get: return _particles
var _particles := FxParticles.new()
var _last_t := 0.0
## Seismic Sense, while it runs: {"on": hero id, "at", "for", "speed"} (WorldView's
## screen shader reads it).
var sense := {}
## The fire dragon leaving along an aim: hero id -> {"at", "to"} (a stance-5 Fire cast).
var _dragon_leaves := {}
const DRAGON_UNCOIL := 0.4


## Takes the "fx" events of a batch (unknown effects are skipped). An event may
## carry "tiles" (one copy on each tile), "on" (an actor id: held around it, `for`
## seconds; the `fx` debug preview) and "for" (how long a looping one plays, 2 s
## by default).
func on_events(events: Array, effects: Dictionary) -> void:
	for e in events:
		if e.get("type", "") != "fx":
			continue
		if e.has("code"):
			_codes.append({"code": str(e.code), "on": int(e.get("on", -1)), "at": float(e.get("at", 0.0)),
					"for": float(e.get("for", 2.0))})
			continue
		var fx: FxDef = effects.get(StringName(e.get("fx", "")))
		if fx == null:
			continue
		if fx.tile_mode == FxDef.TileMode.SENSE:
			sense = {"on": int(e.get("source", -1)), "at": float(e.get("at", 0.0)), "for": fx.tile_seconds,
					"speed": fx.front_speed}
		_events.append({"fx": fx, "from": Vector2(e.get("from", Vector2.ZERO)), "to": Vector2(e.get("to", Vector2.ZERO)),
				"at": float(e.get("at", 0.0)), "tiles": e.get("tiles", []), "on": int(e.get("on", -1)),
				"for": float(e.get("for", fx.tile_seconds if fx.tile_mode != FxDef.TileMode.NONE else 2.0)),
				"fly": float(e.get("fly", 0.0)), "source": int(e.get("source", -1)), "seed": int(e.get("seed", 0)),
				"reach": float(e.get("reach", 0.0)), "rays": e.get("rays", []), "radius": float(e.get("radius", 0.0)),
				"ability": StringName(e.get("ability", ""))})


## Everything to draw at host time `t`: [{"fx", "frame", "pos" (tiles), "lift"
## (levels above the ground under pos), "angle" (screen radians), "rotate"}].
## `actors`: the zone's actors; `telegraphs`: the session's pending hits;
## `abilities` / `effects`: content by id; `art_for`: Callable(Actor) ->
## CreatureArtDef (the hero's art, for the rise's length); `world`: what else
## the session shows: "projectiles" and "zones" (their dictionaries) and "buffs"
## (BuffDefs by id).
func items(t: float, actors: Array, telegraphs: Array, abilities: Dictionary, effects: Dictionary,
		art_for: Callable, world: Dictionary = {}) -> Array:
	var out := []
	var keep := []
	var by_id := {}
	for a in actors:
		by_id[a.id] = a
	for e in _events:
		var fx: FxDef = e.fx
		var since := t - float(e.at)
		var code_drawn := fx.ribbon or fx.front or fx.tile_mode != FxDef.TileMode.NONE
		var length := float(e["for"]) if fx.loop or fx.tile_mode != FxDef.TileMode.NONE else fx.duration()
		if since > length + 0.5:
			continue # long over
		keep.append(e)
		if since < 0.0 or since > length:
			continue
		var frame := 0 if code_drawn else fx.frame_at(since)
		if frame < 0:
			continue
		if e.on >= 0:
			if by_id.has(e.on):
				out.append_array(held_items(fx, since, by_id[e.on]))
			continue
		if fx.ribbon and fx.path == FxDef.Path.ROPE:
			continue # the hero's own rope is thrown (WaterRopes)
		if fx.ribbon:
			out.append_array(ribbon_items(fx, e.from, e.to, since, e.seed, e.reach, by_id.get(e.source), art_for,
					String(e.ability)))
			continue
		if fx.front:
			out.append_array(front_items(fx, e.rays, since, effects))
			continue
		if fx.tile_mode != FxDef.TileMode.NONE:
			out.append_array(tile_items(fx, e, since, effects))
			continue
		if not e.tiles.is_empty():
			for tile in e.tiles:
				out.append(apply_motion({"fx": fx, "frame": frame, "pos": Vector2(tile), "lift": fx.height_levels,
						"angle": 0.0, "rotate": false}, fx, since))
			continue
		var dir: Vector2 = (e.to - e.from).normalized() if e.to.distance_to(e.from) > 0.001 else Vector2.RIGHT
		var pos: Vector2 = e.to if fx.anchor == FxDef.Anchor.POINT else e.from + dir * fx.forward_tiles
		if e.fly > 0.0:
			pos = e.from.lerp(e.to, clampf(since / e.fly, 0.0, 1.0)) # a preview flight
		out.append(apply_motion({"fx": fx, "frame": frame, "pos": pos, "lift": fx.height_levels,
				"angle": screen_angle(dir), "rotate": fx.rotate}, fx, since))
	_events = keep
	var codes := []
	for c in _codes:
		var since := t - float(c.at)
		if since > float(c["for"]) + 0.5:
			continue
		codes.append(c)
		if since >= 0.0 and since <= float(c["for"]) and by_id.has(c.on):
			var a: Actor = by_id[c.on]
			out.append({"code": c.code, "pos": a.move.pos, "actor": a, "offset": Vector2.ZERO, "lift": 0.0, "t": t,
					"behind": false})
	_codes = codes
	# Held while casting (Healing Touch's water ball in the hands).
	for a in actors:
		if a.casting.is_empty() or not a.alive:
			continue
		var ability = a.casting.get("ability")
		if ability == null or ability.fx_hands == &"":
			continue
		var fx: FxDef = effects.get(ability.fx_hands)
		if fx != null:
			for item in held_items(fx, t - float(a.casting.get("start", t)), a):
				item.offset = a.facing_vector() * fx.forward_tiles
				item.pos = a.move.pos + item.offset
				out.append(item)
	# Held around whoever has a buff with an effect (Water Shield's bubble).
	var buffs: Dictionary = world.get("buffs", {})
	for a in actors:
		if not a.alive:
			continue
		for b in a.buffs.summary(t):
			var def: BuffDef = buffs.get(StringName(b[0]))
			if def != null and def.code_fx != "":
				out.append({"code": def.code_fx, "pos": a.move.pos, "actor": a, "offset": Vector2.ZERO, "lift": 0.0,
						"t": t, "behind": false})
			if def == null or def.fx == &"":
				continue
			var fx: FxDef = effects.get(def.fx)
			if fx != null:
				out.append_array(held_items(fx, t, a))
	# A ground zone's effect on each of its tiles while it lasts (Flame Dash's trail).
	for z in world.get("zones", []):
		var ability: AbilityDef = abilities.get(StringName(z.get("ability", "")))
		if ability == null or ability.fx_tiles == &"":
			continue
		var fx: FxDef = effects.get(ability.fx_tiles)
		if fx == null:
			continue
		if fx.tile_mode == FxDef.TileMode.BURNING:
			out.append_array(burning_items(fx, z.get("tiles", []), t, effects))
			continue
		for tile in z.get("tiles", []):
			# Each tile its own phase, so a row of flames doesn't flicker as one.
			var since := t + float((tile.x * 7 + tile.y * 13) % 10) * 0.1
			out.append(apply_motion({"fx": fx, "frame": fx.frame_at(fmod(since, maxf(fx.duration(), 0.001))),
					"pos": Vector2(tile), "lift": fx.height_levels, "angle": 0.0, "rotate": false}, fx, since))
	# Projectiles with a sprite, turned to their flight.
	for p in world.get("projectiles", []):
		var ability: AbilityDef = abilities.get(StringName(p.get("ability", "")))
		if ability == null or ability.fx_projectile == &"":
			continue
		var fx: FxDef = effects.get(ability.fx_projectile)
		if fx == null:
			continue
		var at := projectile_pos(p, t)
		var dir := projectile_dir(p)
		var item := apply_motion({"fx": fx, "frame": fx.frame_at(maxf(t - float(p.start), 0.0)), "pos": at,
				"lift": fx.height_levels, "z_tile": Vector2i(p.origin), "angle": screen_angle(dir), "rotate": fx.rotate},
				fx, t - float(p.start))
		out.append(item)
		var trail: FxDef = effects.get(fx.trail_fx) if fx.trail_fx != &"" else null
		if trail != null and trail.ribbon:
			# A trail strip behind it (Air Blade), at most 2 tiles long.
			var back := at - dir * minf(2.0, at.distance_to(projectile_pos(p, float(p.start))))
			for q in ribbon_quads(trail, back, at, t - float(p.start), 0, 0.0, fx.height_levels, Vector2i(p.origin)):
				out.append(q)
	# A rock held during a bar (Rock Throw), beside the hero, rising then bobbing.
	for a in actors:
		if not (a is Hero) or a.casting.is_empty() or a.casting.get("kind", "") != "timing":
			continue
		var ability = a.casting.get("ability")
		if ability == null or ability.fx_carried == &"":
			continue
		var fx: FxDef = effects.get(ability.fx_carried)
		if fx == null:
			continue
		var since := t - float(a.casting.get("start", t))
		var art: CreatureArtDef = art_for.call(a)
		var own: Dictionary = art.ability_anim(ability.id) if art != null else {}
		var rise := art.duration(own.windup) if art != null and own.get("windup", "") != "" else 0.5
		var k := clampf(since / maxf(rise, 0.01), 0.0, 1.0)
		var lift := fx.height_levels * k + (sin(since * TAU * BOB_HZ) * BOB_LEVELS if k >= 1.0 else 0.0)
		out.append({"fx": fx, "frame": 0, "pos": a.move.pos + a.facing_vector() * fx.forward_tiles, "lift": lift,
				"angle": 0.0, "rotate": false})
	out.append_array(stance_items(t, actors, effects, art_for))
	# A thrown rock in flight: along a parabola, spinning.
	for h in telegraphs:
		var ability: AbilityDef = abilities.get(StringName(h.get("ability", "")))
		if ability == null or ability.fx_carried == &"":
			continue
		var fx: FxDef = effects.get(ability.fx_carried)
		var start := float(h.get("start", h.get("at", 0.0)))
		var land := float(h.get("at", 0.0))
		if fx == null or land <= start or t < start or t > land:
			continue
		var k := clampf((t - start) / (land - start), 0.0, 1.0)
		var from: Vector2 = h.get("from", Vector2.ZERO)
		var to: Vector2 = h.get("to", Vector2.ZERO)
		var lift := lerpf(fx.height_levels, 0.3, k) + 4.0 * ARC_PEAK_LEVELS * k * (1.0 - k)
		var spin := k * TAU * SPIN_TURNS * (1.0 if to.x - to.y >= from.x - from.y else -1.0)
		out.append({"fx": fx, "frame": 0, "pos": from.lerp(to, k), "lift": lift, "angle": spin, "rotate": true,
				"spin": true})
	_particles.update(t - _last_t if t > _last_t and t - _last_t < 0.25 else 0.0)
	_last_t = t
	for i in FxParticles.CAPACITY:
		if _particles.alive(i):
			var pp := _particles.pos[i]
			out.append({"particle": i, "pos": Vector2(pp.x, pp.y), "lift": pp.z, "z_tile": Vector2i(_particles.base_tile[i])})
	return out


## Element colours of the faint rings (as the action bar's stance slots).
const RING_COLORS := {"Fire": Color(1.0, 0.45, 0.15), "Water": Color(0.35, 0.6, 1.0),
	"Earth": Color(0.7, 0.55, 0.3), "Air": Color(0.85, 0.95, 1.0)}
const RING_ALPHA := 0.35


## The looks of held stances (see the class notes). A stance shown as a body look
## ("look:<name>": Earth's stone) adds nothing here; WorldView tints the hero.
func stance_items(t: float, actors: Array, effects: Dictionary, art_for: Callable) -> Array:
	var out := []
	for a in actors:
		if not (a is Hero) or not a.alive or a.stance <= 0 or a.stance_tree == "":
			continue
		if a.stance_tree == "Water" and a.stance in [1, 2]:
			continue # its look is the water rope or hoop (WaterRopes), not a ring or FX-15-11
		var art: CreatureArtDef = art_for.call(a)
		var key := art.stance_look(a.stance_tree, a.stance) if art != null else ""
		if key.begins_with("look:"):
			continue
		var since := maxf(t - float(a.stance_at), 0.0)
		var fx: FxDef = effects.get(StringName(key)) if key != "" else null
		if fx != null and fx.ribbon:
			# The fire dragon: coiled around the hero; a stance-5 Fire cast makes it
			# uncoil toward the aim and leave (it comes back coiled after).
			var leave: Dictionary = _dragon_leaves.get(a.id, {})
			var uncoil := 0.0
			var alpha := 1.0
			if not leave.is_empty():
				var k := (t - float(leave.at)) / DRAGON_UNCOIL
				if k >= 0.0 and k < 2.5:
					uncoil = clampf(k, 0.0, 1.0)
					alpha = clampf(2.0 - k, 0.0, 1.0) if k > 1.0 else 1.0
					if k > 2.0:
						alpha = clampf((k - 2.0) * 2.0, 0.0, 1.0) # back, coiled
						uncoil = 0.0
			var to: Vector2 = leave.get("to", a.move.pos + a.facing_vector() * 3.0)
			for q in ribbon_quads(fx, a.move.pos, to, since, 0, 0.0, 0.0, a.tile(), uncoil):
				q.alpha = alpha
				out.append(q)
			continue
		if fx == null:
			for half in [-1, 1]:
				out.append({"ring": RING_COLORS.get(a.stance_tree, Color.WHITE), "alpha": RING_ALPHA, "pos": a.move.pos,
						"actor": a, "offset": Vector2.ZERO, "lift": 0.0, "half": half, "behind": half < 0})
			continue
		out.append_array(held_items(fx, since, a))
	return out


## One still held around actor `a`, `since` seconds after it appeared, moved by its
## FxDef motion: one item, or two for a split one (back half behind, front half in front).
static func held_items(fx: FxDef, since: float, a: Actor) -> Array:
	var item := apply_motion({"fx": fx, "frame": maxi(fx.frame_at(fmod(since, maxf(fx.duration(), 0.001))), 0),
			"pos": a.move.pos, "actor": a, "offset": Vector2.ZERO, "lift": fx.height_levels, "angle": 0.0,
			"rotate": false, "flat": fx.flat, "mirror": false, "behind": fx.behind}, fx, since)
	if fx.motion == FxDef.Motion.ORBIT:
		var phase := since * fx.motion_hz
		var off := Vector2(cos(phase * TAU), sin(phase * TAU)) * fx.orbit_tiles
		item.offset = off
		item.pos = a.move.pos + off
		item.behind = off.x + off.y < 0.0 # the far side of the hero
	if not fx.split:
		return [item]
	var back := item.duplicate()
	back.behind = true
	back.half = -1
	var front := item.duplicate()
	front.behind = false
	front.half = 1
	return [back, front]


## An item moved by its effect's code motion `since` seconds after it started, and
## faded (FxDef.alpha_at).
static func apply_motion(item: Dictionary, fx: FxDef, since: float) -> Dictionary:
	var phase := since * fx.motion_hz
	var alpha := fx.alpha_at(since)
	match fx.motion:
		FxDef.Motion.SPIN:
			item.angle = phase * TAU
			item.rotate = true
			item.spin = true
		FxDef.Motion.BOB:
			item.lift = float(item.lift) + sin(phase * TAU) * fx.motion_amount
		FxDef.Motion.FLICKER:
			item.mirror = int(floor(phase)) % 2 == 1
		FxDef.Motion.SWAY:
			item.angle = sin(phase * TAU) * fx.motion_amount
			item.rotate = true
			item.spin = true
		FxDef.Motion.PULSE:
			alpha *= 0.85 + 0.15 * sin(phase * TAU)
		FxDef.Motion.DROP:
			var k := clampf(since / maxf(fx.duration() * 0.4, 0.001), 0.0, 1.0)
			item.lift = float(item.lift) + fx.motion_amount * (1.0 - k * k)
	item.alpha = alpha
	return item


## Where a projectile dictionary (Projectile.to_dict) is at host time `t`, in tiles.
static func projectile_pos(p: Dictionary, t: float) -> Vector2:
	if p.has("from"):
		return p.from + p.dirv * clampf((t - p.start) * p.speed, 0.0, p.length)
	var dist := clampf((t - p.start) * p.speed, 0.0, p.length + 0.5)
	var origin := Vector2(p.origin)
	var to_end := Vector2(p.get("end", p.origin)) - origin
	var steps := maxf(float(p.length), 1.0)
	return origin + (to_end / steps * dist if to_end.length_squared() > 0.0 else Vector2(p.dir) * dist)


## Which way a projectile flies, in tiles.
static func projectile_dir(p: Dictionary) -> Vector2:
	if p.has("dirv"):
		return p.dirv
	var to_end := Vector2(p.get("end", p.origin)) - Vector2(p.origin)
	return to_end.normalized() if to_end.length_squared() > 0.0 else Vector2(p.get("dir", Vector2.RIGHT))


## Called by WorldView with every event batch: casts of stance-5 Fire abilities.
func on_casts(events: Array, abilities: Dictionary) -> void:
	for e in events:
		if e.get("type", "") != "cast":
			continue
		var a: AbilityDef = abilities.get(StringName(e.get("ability", "")))
		if a == null or a.tree != "Fire" or a.stance != 5:
			continue
		var leave := {"at": float(e.get("at", _last_t))}
		if e.has("point"):
			leave.to = Vector2(e.point)
		_dragon_leaves[int(e.get("source", -1))] = leave


## The pieces of a ribbon from `from` toward `to`, starting at the caster's hand.
func ribbon_items(fx: FxDef, from: Vector2, to: Vector2, since: float, seed: int, reach: float, caster: Actor,
		art_for: Callable, anim: String) -> Array:
	var hand := Vector2.ZERO
	if caster != null:
		var art: CreatureArtDef = art_for.call(caster)
		if art != null:
			var dir := art.direction_for_angle((to - from).angle(), caster.facing)
			var own: Dictionary = art.ability_anim(StringName(anim)) if anim != "" else {}
			hand = art.hand_point(str(own.get("anim", "water_whip")), dir)
	var tile := caster.tile() if caster != null else MoveState.tile_of(from)
	return ribbon_quads(fx, from + Vector2(hand.x, -hand.x) / 32.0, to, since, seed, reach, hand.y / 8.0, tile)


## A ribbon's quads plus its end pieces (tip, head, impact, hand burst), and a few
## particles thrown off it. `hand_lift`: the hand's height in levels.
func ribbon_quads(fx: FxDef, from: Vector2, to: Vector2, since: float, seed: int, reach: float, hand_lift: float,
		base_tile: Vector2i, uncoil := 0.0) -> Array:
	var out := []
	var pts := RibbonPath.points(fx, from, to, since, seed, maxf(reach, from.distance_to(to)), hand_lift, uncoil)
	if pts.size() < 2:
		return out
	var alpha := fx.alpha_at(since)
	for q in RibbonPath.quads(fx, pts, since):
		q.quad = fx
		q.z_tile = base_tile
		q.alpha = alpha
		out.append(q)
	var last := pts[pts.size() - 1]
	var prev := pts[pts.size() - 2]
	var ang := (RibbonPath.screen(last, 0.0) - RibbonPath.screen(prev, 0.0)).angle()
	var effects := ContentDB.effects
	var end_piece := func(id: StringName, p: Vector3, rotate: bool, item_alpha: float) -> void:
		var piece: FxDef = effects.get(id)
		if piece != null:
			out.append({"fx": piece, "frame": 0, "pos": Vector2(p.x, p.y), "lift": p.z if rotate else 0.0,
					"z_tile": base_tile if rotate else MoveState.tile_of(Vector2(p.x, p.y)), "angle": ang,
					"rotate": rotate and piece.rotate, "alpha": item_alpha * piece.alpha})
	if fx.tip_fx != &"":
		end_piece.call(fx.tip_fx, last, true, alpha)
	if fx.head_fx != &"":
		end_piece.call(fx.head_fx, last, true, alpha)
	if fx.hand_fx != &"":
		end_piece.call(fx.hand_fx, pts[0], true, alpha)
	var reached := fx.reach_at(since) >= 0.999 and (fx.path != FxDef.Path.WHIP or since * fx.fps >= fx.snap_frame)
	if fx.impact_fx != &"" and reached and fx.path in [FxDef.Path.LINE, FxDef.Path.WHIP]:
		end_piece.call(fx.impact_fx, last, false, alpha)
	# A few particles off the ribbon (embers for fire, drops for water).
	if alpha > 0.2 and randf() < 0.5:
		var i := randi() % pts.size()
		var c := _particle_color(fx)
		_particles.emit(pts[i], Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(0.5, 1.5)),
				randf_range(0.3, 0.6), c, base_tile)
	return out


static func _particle_color(fx: FxDef) -> Color:
	var id := String(fx.id)
	if id.contains("fire") or id.contains("breath") or id.contains("dragon"):
		return Color(1.0, 0.6, 0.15, 0.9)
	if id.contains("lightning"):
		return Color(0.75, 0.85, 1.0, 0.9)
	if id.contains("cable"):
		return Color(1.0, 0.85, 0.4, 0.9)
	if id.contains("gust") or id.contains("air"):
		return Color(0.9, 0.95, 1.0, 0.6)
	return Color(0.55, 0.8, 1.0, 0.9)


## A front at `since`: its piece at each ray's tip, a fading trail behind, the
## blocked piece where terrain stopped a ray; near-duplicates (the same art pixel)
## dropped. Rays: [ox, oy, dx, dy, stop, length].
func front_items(fx: FxDef, rays: Array, since: float, effects: Dictionary) -> Array:
	var out := []
	var travel := since * fx.front_speed
	var seen := {}
	var piece: FxDef = effects.get(fx.head_fx)
	var trail: FxDef = effects.get(fx.trail_fx)
	var blocked: FxDef = effects.get(fx.blocked_fx)
	var put := func(f: FxDef, p: Vector2, a: float) -> void:
		if f == null or a <= 0.02:
			return
		var key := [f.id, Vector2i((p * 6.0).round())] # near-duplicates: closer than a sixth of a tile
		if seen.has(key):
			return
		seen[key] = true
		out.append({"fx": f, "frame": 0, "pos": p, "lift": f.height_levels, "angle": 0.0, "rotate": false,
				"alpha": a * f.alpha, "scale": fx.piece_scale})
	for r in rays:
		var o := Vector2(r[0], r[1])
		var d := Vector2(r[2], r[3])
		var stop := float(r[4])
		var length := float(r[5]) if r.size() > 5 else stop
		if travel < stop:
			put.call(piece, o + d * travel, 1.0)
		elif stop < length - 0.05:
			var since_block := (travel - stop) / fx.front_speed
			if since_block < 0.5:
				put.call(blocked, o + d * stop, 1.0 - since_block * 2.0)
		# The trail fades behind the front (not past where the ray stopped).
		var j := 1
		while trail != null:
			var s := minf(travel, stop) - j * 0.75
			var age := (travel - s) / fx.front_speed
			if s <= 0.3 or age > fx.trail_fade_seconds:
				break
			put.call(trail, o + d * s, (1.0 - age / fx.trail_fade_seconds) * 0.8)
			j += 1
	if fx.wets:
		var wet: FxDef = effects.get(&"wet_ground")
		if wet != null:
			for tile in FrontRays.tiles_crossed(rays, travel):
				out.append(_tile_item(wet, tile, since, wet.tile_seconds + fx.hold_seconds))
	if travel < 99.0 and randf() < 0.4 and not rays.is_empty():
		var r: Array = rays[randi() % rays.size()]
		var at := Vector2(r[0], r[1]) + Vector2(r[2], r[3]) * minf(travel, float(r[4]))
		_particles.emit(Vector3(at.x, at.y, 0.5), Vector3(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4), 1.2),
				0.4, _particle_color(fx), MoveState.tile_of(at))
	return out


## One tile shaded in code (WET, SAND, CRACKS...), fading over its last second.
static func _tile_item(fx: FxDef, tile: Vector2i, since: float, length: float) -> Dictionary:
	var a := clampf(length - since, 0.0, 1.0)
	return {"tilefx": fx, "tile": tile, "pos": Vector2(tile), "alpha": a, "since": since, "behind": true}


## Tile effects from an event: shaded tiles (its "tiles"), a shock ring (its radius,
## around "to"), a sandstorm or rain over the area.
func tile_items(fx: FxDef, e: Dictionary, since: float, effects: Dictionary) -> Array:
	var out := []
	var length := float(e["for"])
	match fx.tile_mode:
		FxDef.TileMode.BURNING:
			out.append_array(burning_items(fx, e.tiles, since, effects))
		FxDef.TileMode.RING:
			# A shock ring travelling out: tiles it is passing lift and shade their own art.
			var center: Vector2 = e.to
			var r := since * fx.front_speed
			var radius := maxf(float(e.radius), 1.0)
			if r > radius + 1.0:
				return out
			var c := MoveState.tile_of(center)
			var reach := ceili(radius) + 1
			for dx in range(-reach, reach + 1):
				for dy in range(-reach, reach + 1):
					var tile := c + Vector2i(dx, dy)
					var d := Vector2(tile).distance_to(center)
					var k := 1.0 - absf(d - r) / 0.7
					if d <= radius + 0.5 and k > 0.0:
						out.append({"tilefx": fx, "tile": tile, "pos": Vector2(tile), "alpha": k, "since": since,
								"lift_px": 3.0 * k, "behind": true})
		FxDef.TileMode.SANDSTORM, FxDef.TileMode.RAIN:
			var tiles: Array = e.tiles
			if tiles.is_empty():
				return out
			var center := Vector2.ZERO
			for tile in tiles:
				center += Vector2(tile)
			center /= tiles.size()
			out.append({"tilefx": fx, "tile": MoveState.tile_of(center), "pos": center, "alpha": clampf(length - since, 0.0, 1.0),
					"since": since, "area": tiles, "behind": false})
			if fx.tile_mode == FxDef.TileMode.RAIN:
				var wet: FxDef = effects.get(&"wet_ground")
				if wet != null:
					for tile in tiles:
						out.append(_tile_item(wet, tile, since, length))
		_:
			for tile in e.tiles:
				out.append(_tile_item(fx, tile, since, length))
	return out


## Burning tiles, auto-tiled by neighbours: the full flames on every tile, faded
## toward each open side (no burning neighbour there) until the edge and corner
## pieces are approved. "fade" holds the four sides' opacities: grid -x, +x, -y, +y.
func burning_items(fx: FxDef, tiles: Array, t: float, effects: Dictionary) -> Array:
	var out := []
	var piece: FxDef = effects.get(fx.head_fx)
	if piece == null:
		return out
	var set := {}
	for tile in tiles:
		set[tile] = true
	for tile in tiles:
		var fade := PackedFloat32Array()
		for side in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			fade.append(1.0 if set.has(tile + side) else BURN_EDGE_ALPHA)
		var since := t + float((tile.x * 7 + tile.y * 13) % 10) * 0.1
		var item := apply_motion({"fx": piece, "frame": 0, "pos": Vector2(tile), "lift": 0.0, "angle": 0.0,
				"rotate": false}, piece, since)
		item.fade = fade
		out.append(item)
	return out


## How opaque a burning tile's flames get toward a side with no fire.
const BURN_EDGE_ALPHA := 0.25


## The screen-space angle of a direction in tile space (the art points right).
static func screen_angle(dir: Vector2) -> float:
	var s := Iso.to_screen(dir, 0.0) - Iso.to_screen(Vector2.ZERO, 0.0)
	return s.angle() if s.length() > 0.0001 else 0.0


func clear() -> void:
	_events.clear()
	_codes.clear()
	_particles.clear()
	_dragon_leaves.clear()
	sense = {}
