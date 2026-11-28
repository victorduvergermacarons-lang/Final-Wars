class_name FireEffect
extends RefCounted
## One fire effect on the fluid: its slot, the window it sits in, and the reference's
## per-kind timeline (what it emits each step). Cosmetic: every player runs their own
## from the host's events.
##
## The window: 128 x 128 cells (16 a tile), its corner on a tile corner so its tile
## diagonals are the world's. `origin` is the world tile at the window's cell (0, 0)
## tile; a local cell point p is the world point origin - (0.5, 0.5) + p / 16.

const CELLS_PER_TILE := 16.0
## The reference dummy's radius (cells) is the body of a 0.3-tile unit.
const UNIT_CELLS_PER_TILE := 2.6 / 0.3

var look: FireLookDef
var p: Dictionary          # the settings at the caster's mastery
var slot := -1
var origin := Vector2i.ZERO
var base_h := 0.0          # the ground height the fire sits on (levels)
var caster_id := -1
var hero := Vector2.ZERO   # the caster, local cells
var aim := 0.0             # radians, local (= world grid) angle
var aim_t := 0.0
var target_id := -1
var ct := 0                # steps since the cast
var f := 0                 # steps alive
var hold_steps := 0        # the stream: steps the caster keeps it on
var done_after := 0        # steps after which nothing more is emitted
var tail_steps := 180      # steps the fire is left to burn out before the slot is freed
## Particles (the reference's parts): {x, y, z, vx, vy, vz, l, L, k, gr, gs, gz}; local
## cells and px above the floor. k: 0 gold mote, 1 falling spark, 2 jet spark, 3 trail
## ember, 4 fire drop (lands, licks the floor and lights it).
var parts: Array = []
## A projectile's head, drawn in code: {} or {x, y, dx, dy, ball (bool), size}.
var head := {}
const MAX_PARTS := 900
## Ground fire (phase 2): this window draws the ground fire. ground_until: world tile ->
## when the host's fire there ends (host clock); ground_new: tiles to fuel next step;
## ground_light: tiles to light next step.
var ground := false
var ground_until := {}
var ground_new: Array = []
var ground_light: Array = []
var now := 0.0           # the host clock, set each frame
var zone: ZoneDef
var grid: GridModel


## Where to put the window for a caster at `pos` aiming along `dir`: the caster near the
## corner behind it, as the reference places its hero (40 cells in, both ways).
static func place_origin(pos: Vector2, dir: Vector2) -> Vector2i:
	var want := Vector2(64, 64) - dir.normalized() * 56.6
	want = want.clamp(Vector2(12, 12), Vector2(116, 116))
	var corner := pos - want / CELLS_PER_TILE # the world point at local (0, 0)
	return Vector2i(roundi(corner.x + 0.5), roundi(corner.y + 0.5))


func to_local(world: Vector2) -> Vector2:
	return (world - Vector2(origin) + Vector2(0.5, 0.5)) * CELLS_PER_TILE


func to_world(local: Vector2) -> Vector2:
	return Vector2(origin) - Vector2(0.5, 0.5) + local / CELLS_PER_TILE


## One step of the timeline: add this step's sources to the sim.
func step(sim: FireSim) -> void:
	var dd := atan2(sin(aim_t - aim), cos(aim_t - aim))
	aim += clampf(dd, -0.08, 0.08)
	var ax := cos(aim)
	var ay := sin(aim)
	match look.kind:
		"stream":
			if ct < hold_steps:
				var wob := 0.04 * sin(f * 0.21) + 0.03 * sin(f * 0.53 + 1.0)
				sim.emit(slot, hero.x + ax * 6.5, hero.y + ay * 6.5, ax, ay, 1.25, float(p.temp), float(p.launch), wob)
	step_parts(sim)
	if ground:
		_step_ground(sim)
	var params := p.duplicate()
	params["aim"] = Vector2(ax, ay)
	params["ground"] = ground
	params["contact"] = 1 if look.kind in ["stream", "punch", "wheel", "breathfire", "jet"] else (2 if look.kind in ["kick", "combo"] else 0)
	sim.set_params(slot, params)
	ct += 1
	f += 1


## The host's burning tiles of this window: fuel the new ones, light the zone's middle,
## and tell the sim how long each tile may still burn and how fast its char fades.
func _step_ground(sim: FireSim) -> void:
	for t in ground_new:
		var c := to_local(Vector2(t))
		var lit := ground_light.has(t) or ground_new.size() <= 3 # a trail lights as it is laid
		sim.patch(slot, c.x, c.y, 11.0, maxf(float(ground_until.get(t, now)) - now, 0.0), 3.0 if lit else 0.0)
	ground_new.clear()
	ground_light.clear()
	var left := PackedFloat32Array()
	var fade := PackedFloat32Array()
	left.resize(64)
	fade.resize(64)
	for ty in 8:
		for tx in 8:
			var t := origin + Vector2i(tx, ty)
			var secs := maxf(float(ground_until.get(t, 0.0)) - now, 0.0)
			var ts: TilesetData = ContentDB.tilesets.get(zone.tileset) if zone != null and zone.has_terrain() else null
			if ts != null and ts.is_water_terrain(zone.terrain_at(t)):
				secs = 0.0 # nothing burns on water
			left[ty * 8 + tx] = secs * 60.0 * float(look.time_scale)
			var long := zone != null and (zone.terrain_at(t) in FireEffects.LONG_FADE_TERRAINS or zone.prop_at(t) in FireEffects.WOOD_PROPS)
			fade[ty * 8 + tx] = (FireEffects.CHAR_FADE_LONG if long else FireEffects.CHAR_FADE_SHORT) * 60.0
	sim.set_tiles(slot, left, fade)


# --- The reference's sources and particles ---------------------------------

func part(x: float, y: float, z: float, vx: float, vy: float, vz: float, life: float, k: int) -> void:
	if parts.size() < MAX_PARTS:
		parts.append({"x": x, "y": y, "z": z, "vx": vx, "vy": vy, "vz": vz, "l": 0.0, "L": life, "k": k, "gr": 0.0, "gs": 0.0, "gz": 0.0})


func drop(x: float, y: float, z: float, vx: float, vy: float, vz: float, gr: float, gs: float, gz: float = 0.0) -> void:
	if parts.size() < MAX_PARTS:
		parts.append({"x": x, "y": y, "z": z, "vx": vx, "vy": vy, "vz": vz, "l": 0.0, "L": 200.0, "k": 4, "gr": gr, "gs": gs, "gz": gz})


## A lick of flame on one cell (the reference's lick).
func lick(sim: FireSim, x: float, y: float, t: float, zz: float, sp: float) -> void:
	var a := randf() * TAU
	sim.point(slot, roundf(x), roundf(y), t, 1.0, 0.3, zz, cos(a) * sp, sin(a) * sp)


## Flames licking up around a unit's body (the reference's burnUnit): `rate` a step.
func burn_unit(sim: FireSim, x: float, y: float, rate: float, t: float, body: float = 2.6) -> void:
	var n := rate
	while n > 0.0:
		if n < 1.0 and randf() > n:
			break
		n -= 1.0
		var a := randf() * TAU
		var rr := body + 0.6 + randf() * 0.8
		sim.point(slot, roundf(x + cos(a) * rr), roundf(y + sin(a) * rr), t * (0.6 + 0.4 * randf()), 1.0, 0.3,
				-FireSim.ZC + 3.0 + randf() * 8.0, cos(a) * 0.15, sin(a) * 0.15)


## Moves every particle one step; a fire drop that lands licks the floor
## (and lights the ground fire, phase 2).
func step_parts(sim: FireSim) -> void:
	for q in range(parts.size() - 1, -1, -1):
		var o: Dictionary = parts[q]
		o.l += 1.0
		o.x += o.vx
		o.y += o.vy
		o.z += o.vz
		if o.k == 0:
			o.vz += float(p.get("srise", 0.25)) * 0.05
			o.vx *= 0.96
			o.vy *= 0.96
			if o.z < 1.0:
				o.z = 1.0
				o.vz = absf(o.vz) * 0.3
		else:
			if o.gz != 0.0:
				o.vz -= o.gz
			if o.k == 1:
				o.vz -= 0.02
			if o.k == 3:
				o.vx *= 0.95
				o.vy *= 0.95
		if o.k == 4 and o.z <= 0.0:
			lick(sim, o.x, o.y, 0.9, -FireSim.ZC + 2.0, 0.2)
			landed(o)
			o.l = o.L
		if o.k == 2 and o.z <= 0.0:
			o.l = o.L
		if o.l >= o.L:
			parts.remove_at(q)


## A fire drop reached the floor (ground fire hooks in here).
func landed(_o: Dictionary) -> void:
	pass


func finished() -> bool:
	return ct > done_after + tail_steps
