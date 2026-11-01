class_name MoveState
extends RefCounted
## Where an actor is and how it moves. Positions are continuous, in tile units:
## the centre of tile (x, y) is the point (x, y), so `to_tile` (the tile under the
## centre) stays the actor's tile for everything still thinking in tiles.
##
## Two ways to move:
## - **Free** (heroes since the free-movement rework): `Mover` integrates `vel` from
##   the actor's wish direction every tick, with collisions, height rules and falls.
## - **Glide**: a timed slide from one point to another (`begin`), used by actors
##   still stepping tile to tile (enemies, NPCs, until phase 5) and by forced moves
##   (knockbacks, dashes, leaps). While a glide runs the actor doesn't steer.
##
## Drawing: `position_at(t)` interpolates between the last two sim ticks (or along
## the glide), and `draw_height` follows the ground smoothly (a 1-level step reads as
## a step) or falls under gravity (`z`).

var pos := Vector2.ZERO
var vel := Vector2.ZERO
## Free movers: integrate from input every tick (Mover). Others only glide.
var free := false
## Body radius in tiles (collisions; ranges are measured edge to edge).
var radius := 0.3

## The previous tick's position and when the last two ticks were (render interpolation).
var prev_pos := Vector2.ZERO
var prev_time := 0.0
var time := 0.0

## Glide (tile step or forced move).
var gliding := false
var from_point := Vector2.ZERO
var to_point := Vector2.ZERO
var start_time := 0.0
var duration := 0.0

## Height: the ground under the centre, a fall in progress (`z` levels above the
## ground, falling at `vz` levels/s), and the height drawn.
var ground_h := 0
var z := 0.0
var vz := 0.0
var fall_from := 0
var draw_h := 0.0
var prev_draw_h := 0.0
## Total distance walked (tiles): run animations and footsteps for free movers.
var odometer := 0.0
## Set by place(): the sim takes the ground height from the new tile next tick.
var just_placed := true


func _init(tile: Vector2i = Vector2i.ZERO) -> void:
	place(tile)


## The tile under the centre (while gliding: the tile it's gliding to, which it
## already holds, as tile steps always did).
var to_tile: Vector2i:
	get:
		return tile_of(to_point) if gliding else tile_of(pos)

## The tile a glide started from; for a free mover, the neighbouring tile its body
## reaches into most (the view draws it between the two), or its own tile.
var from_tile: Vector2i:
	get:
		if gliding:
			return tile_of(from_point)
		return straddled_tile()


static func tile_of(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x), roundi(p.y))


## The neighbouring tile the body reaches into most, or its own tile.
func straddled_tile() -> Vector2i:
	var base := tile_of(pos)
	var f := pos - Vector2(base)
	var reach := radius * 0.5
	if absf(f.x) >= absf(f.y) and absf(f.x) > reach:
		return base + Vector2i(signi(roundi(signf(f.x))), 0)
	if absf(f.y) > reach:
		return base + Vector2i(0, roundi(signf(f.y)))
	return base


## Starts a glide to tile `to` over `seconds` (a tile step or a forced move).
func begin(to: Variant, now: float, seconds: float) -> void:
	var target: Vector2 = Vector2(to) if to is Vector2i else to
	# A glide after a glide starts where the last one ends (steps chain tile to tile).
	from_point = to_point if gliding else pos
	pos = from_point
	to_point = target
	start_time = now
	duration = seconds
	vel = Vector2.ZERO
	if seconds <= 0.0:
		_set_pos(target, now)
		gliding = false
	else:
		gliding = true


## Snaps to a tile (or point) with nothing in progress (spawn, respawn, teleport).
func place(where: Variant) -> void:
	var p: Vector2 = Vector2(where) if where is Vector2i else where
	just_placed = true
	pos = p
	prev_pos = p
	vel = Vector2.ZERO
	gliding = false
	from_point = p
	to_point = p
	duration = 0.0
	z = 0.0
	vz = 0.0


## Advances a glide to sim time `now` (WorldSim does this every tick).
func update_glide(now: float) -> void:
	if not gliding:
		return
	var k := progress(now)
	_set_pos(from_point.lerp(to_point, k), now)
	if k >= 1.0:
		gliding = false


func _set_pos(p: Vector2, now: float) -> void:
	pos = p


## Called once per sim tick before anything moves: remembers where the actor was.
func begin_tick(now: float) -> void:
	prev_pos = pos
	prev_draw_h = draw_h
	prev_time = time
	time = now


func is_moving(now: float) -> bool:
	if gliding:
		return now + Cooldowns.EPSILON < start_time + duration
	return vel.length_squared() > 0.0025 or falling()


func falling() -> bool:
	return z > 0.0


## 0.0 at the glide's start, 1.0 at its end (1.0 when not gliding).
func progress(now: float) -> float:
	if not gliding or duration <= 0.0:
		return 1.0
	return clampf((now - start_time) / duration, 0.0, 1.0)


## Where to draw it at time `t`: along the glide, or between the last two ticks.
func position_at(t: float) -> Vector2:
	if gliding or (duration > 0.0 and t < start_time + duration):
		return from_point.lerp(to_point, clampf((t - start_time) / maxf(duration, 0.0001), 0.0, 1.0))
	var span := time - prev_time
	if span <= 0.0:
		return pos
	# One tick behind, so there is always a newer position to move toward.
	return prev_pos.lerp(pos, clampf((t - time) / span, 0.0, 1.0))


## The height to draw at time `t` (levels): smoothed steps, or a fall.
func height_at_time(t: float) -> float:
	var span := time - prev_time
	if span <= 0.0:
		return draw_h
	return lerpf(prev_draw_h, draw_h, clampf((t - time) / span, 0.0, 1.0))


func can_start_step(in_combat: bool, cooldowns: Cooldowns, now: float) -> bool:
	if is_moving(now):
		return false
	return cooldowns.can_step(now) if in_combat else true


func to_dict() -> Dictionary:
	var d := {"pos": pos, "vel": vel, "z": z, "h": draw_h, "free": free, "r": radius, "odo": odometer}
	if gliding or duration > 0.0:
		d.glide = [from_point, to_point, start_time, duration]
	return d


## Takes the host's state from a snapshot at sim time `now`, remembering the
## previous one so the view can move smoothly between them.
func apply_dict(d: Dictionary, now: float) -> void:
	var fresh := MoveState.from_dict(d)
	prev_pos = pos if time > 0.0 else fresh.pos
	prev_draw_h = draw_h if time > 0.0 else fresh.draw_h
	prev_time = time
	time = now
	pos = fresh.pos
	vel = fresh.vel
	z = fresh.z
	draw_h = fresh.draw_h
	odometer = fresh.odometer
	free = fresh.free
	radius = fresh.radius
	gliding = fresh.gliding
	from_point = fresh.from_point
	to_point = fresh.to_point
	start_time = fresh.start_time
	duration = fresh.duration


static func from_dict(d: Dictionary) -> MoveState:
	var m := MoveState.new()
	m.pos = d.get("pos", Vector2.ZERO)
	m.prev_pos = m.pos
	m.vel = d.get("vel", Vector2.ZERO)
	m.z = d.get("z", 0.0)
	m.draw_h = d.get("h", 0.0)
	m.odometer = d.get("odo", 0.0)
	m.prev_draw_h = m.draw_h
	m.free = d.get("free", false)
	m.radius = d.get("r", 0.3)
	var g = d.get("glide")
	if g is Array and g.size() == 4:
		m.from_point = g[0]
		m.to_point = g[1]
		m.start_time = g[2]
		m.duration = g[3]
		m.gliding = true
	m.from_point = m.from_point if m.gliding else m.pos
	m.to_point = m.to_point if m.gliding else m.pos
	return m
