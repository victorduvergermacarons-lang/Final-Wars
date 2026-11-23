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

var _events: Array = [] # {"fx": FxDef, "from", "to", "at"}


## Takes the "fx" events of a batch (unknown effects are skipped).
func on_events(events: Array, effects: Dictionary) -> void:
	for e in events:
		if e.get("type", "") != "fx":
			continue
		var fx: FxDef = effects.get(StringName(e.get("fx", "")))
		if fx == null:
			continue
		_events.append({"fx": fx, "from": Vector2(e.get("from", Vector2.ZERO)), "to": Vector2(e.get("to", Vector2.ZERO)),
				"at": float(e.get("at", 0.0))})


## Everything to draw at host time `t`: [{"fx", "frame", "pos" (tiles), "lift"
## (levels above the ground under pos), "angle" (screen radians), "rotate"}].
## `actors`: the zone's actors; `telegraphs`: the session's pending hits;
## `abilities` / `effects`: content by id; `art_for`: Callable(Actor) ->
## CreatureArtDef (the hero's art, for the rise's length).
func items(t: float, actors: Array, telegraphs: Array, abilities: Dictionary, effects: Dictionary,
		art_for: Callable) -> Array:
	var out := []
	var keep := []
	for e in _events:
		var fx: FxDef = e.fx
		var since := t - float(e.at)
		if since > fx.duration() + 0.5 and not fx.loop:
			continue # long over
		keep.append(e)
		var frame := fx.frame_at(since)
		if frame < 0:
			continue
		var dir: Vector2 = (e.to - e.from).normalized() if e.to.distance_to(e.from) > 0.001 else Vector2.RIGHT
		var pos: Vector2 = e.to if fx.anchor == FxDef.Anchor.POINT else e.from + dir * fx.forward_tiles
		out.append({"fx": fx, "frame": frame, "pos": pos, "lift": fx.height_levels,
				"angle": screen_angle(dir), "rotate": fx.rotate})
	_events = keep
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
	var phase := since * fx.motion_hz
	var item := {"fx": fx, "frame": 0, "pos": a.move.pos, "actor": a, "offset": Vector2.ZERO,
			"lift": fx.height_levels, "angle": 0.0, "rotate": false, "flat": fx.flat, "mirror": false,
			"behind": fx.behind}
	match fx.motion:
		FxDef.Motion.SPIN:
			item.angle = phase * TAU
			item.rotate = true
			item.spin = true
		FxDef.Motion.BOB:
			item.lift = fx.height_levels + sin(phase * TAU) * fx.motion_amount
		FxDef.Motion.ORBIT:
			var off := Vector2(cos(phase * TAU), sin(phase * TAU)) * fx.orbit_tiles
			item.offset = off
			item.pos = a.move.pos + off
			item.behind = off.x + off.y < 0.0 # the far side of the hero
		FxDef.Motion.FLICKER:
			item.mirror = int(floor(phase)) % 2 == 1
		FxDef.Motion.SWAY:
			item.angle = sin(phase * TAU) * fx.motion_amount
			item.rotate = true
			item.spin = true
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


## The screen-space angle of a direction in tile space (the art points right).
static func screen_angle(dir: Vector2) -> float:
	var s := Iso.to_screen(dir, 0.0) - Iso.to_screen(Vector2.ZERO, 0.0)
	return s.angle() if s.length() > 0.0001 else 0.0


func clear() -> void:
	_events.clear()
