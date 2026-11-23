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
## "behind" ones go before the actors of their tile, the rest after; "ground" ones (the
## front half of something lying on the ground) after the two rows in front of it.

## How high a thrown rock's arc rises above the straight line, in levels.
const ARC_PEAK_LEVELS := 1.6
## Turns a thrown rock spins in flight.
const SPIN_TURNS := 2.0
## How far the held rock bobs, in levels, and how fast (per second).
const BOB_LEVELS := 0.12
const BOB_HZ := 1.2

var _events: Array = [] # {"fx": FxDef, "from", "to", "at", "tiles", "on", "for", "fly"}
var _codes: Array = [] # code-drawn looks from events: {"code", "on", "at", "for"} (the `fx` preview)


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
		_events.append({"fx": fx, "from": Vector2(e.get("from", Vector2.ZERO)), "to": Vector2(e.get("to", Vector2.ZERO)),
				"at": float(e.get("at", 0.0)), "tiles": e.get("tiles", []), "on": int(e.get("on", -1)),
				"for": float(e.get("for", 2.0)), "fly": float(e.get("fly", 0.0))})


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
		var length := float(e["for"]) if fx.loop else fx.duration()
		if since > length + 0.5:
			continue # long over
		keep.append(e)
		if since < 0.0 or since > length:
			continue
		var frame := fx.frame_at(since)
		if frame < 0:
			continue
		if e.on >= 0:
			if by_id.has(e.on):
				out.append_array(held_items(fx, since, by_id[e.on]))
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
		var art: CreatureArtDef = art_for.call(a)
		var key := art.stance_look(a.stance_tree, a.stance) if art != null else ""
		if key.begins_with("look:"):
			continue
		var since := maxf(t - float(a.stance_at), 0.0)
		var fx: FxDef = effects.get(StringName(key)) if key != "" else null
		if fx == null:
			for half in [-1, 1]:
				out.append({"ring": RING_COLORS.get(a.stance_tree, Color.WHITE), "alpha": RING_ALPHA, "pos": a.move.pos,
						"actor": a, "offset": Vector2.ZERO, "lift": 0.0, "half": half, "behind": half < 0,
						"ground": half > 0})
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
	front.ground = fx.flat # lying on the ground: drawn once the tiles it lies on are
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


## The screen-space angle of a direction in tile space (the art points right).
static func screen_angle(dir: Vector2) -> float:
	var s := Iso.to_screen(dir, 0.0) - Iso.to_screen(Vector2.ZERO, 0.0)
	return s.angle() if s.length() > 0.0001 else 0.0


func clear() -> void:
	_events.clear()
	_codes.clear()
