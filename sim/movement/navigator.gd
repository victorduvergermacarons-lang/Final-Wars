class_name Navigator
extends RefCounted
## Free-movement navigation for units that walk by themselves (enemies, escorted
## NPCs): a path over the tile graph (Pathfinder: heights, ramps, cliffs, large
## bodies, fliers), smoothed into straight runs (string-pulling), then followed
## with the same Mover as heroes (acceleration, collisions, falls).
##
## A brain calls `go` with a goal tile every tick it wants to move; the path is
## only searched again when the goal changes, every REPLAN seconds, or when it ran
## out. `follow` (WorldSim, once per tick) turns the path into a wish direction.

## Seconds between path searches toward the same goal.
const REPLAN := 0.5
## A waypoint counts as reached within this distance (tiles).
const REACHED := 0.2
## How far apart the straight-run test samples (tiles).
const SAMPLE := 0.2


## Heads `actor` toward `goal` at `pace` (0..1 of its speed). `stop_short`: stop
## that far from the goal's centre (the edge of a target's body). `arrived`
## (optional, tile -> bool) ends the search at the first tile it accepts.
## Returns false when no path was found (nothing changes then).
static func go(world: WorldSim, actor: Actor, goal: Vector2i, pace := 1.0, stop_short := 0.0,
		arrived := Callable(), max_expanded := 1024) -> bool:
	actor.nav_pace = pace
	actor.nav_stop_short = stop_short
	if goal == actor.nav_goal and world.now < actor.nav_replan_at and not actor.nav_path.is_empty():
		return true
	var tiles := world.path_for(actor, goal, world.occupied_tiles(actor), max_expanded, arrived)
	actor.nav_goal = goal
	actor.nav_replan_at = world.now + REPLAN
	if tiles.is_empty():
		actor.nav_path.clear()
		return false
	actor.nav_path = smooth(world, actor, tiles)
	return true


## Stops (decelerates) and forgets the path.
static func stop(actor: Actor) -> void:
	actor.nav_path.clear()
	actor.nav_goal = Vector2i(-9999, -9999)


## Waypoints from a tile path: its tiles' centres, dropping each one the actor
## could skip by walking straight from the last kept point.
static func smooth(world: WorldSim, actor: Actor, tiles: Array[Vector2i]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if tiles.size() < 2:
		if not tiles.is_empty():
			out.append(Vector2(tiles[0]))
		return out
	var from := actor.move.pos
	var i := 1
	while i < tiles.size():
		# The farthest tile reachable in a straight line from `from`.
		var j := tiles.size() - 1
		while j > i and not clear(world, actor, from, Vector2(tiles[j])):
			j -= 1
		out.append(Vector2(tiles[j]))
		from = Vector2(tiles[j])
		i = j + 1
	return out


## Whether the actor's body can walk straight from `a` to `b`: every tile its
## centre line and both edges cross is one it may enter from the tile before (the
## same height rules as the tile graph).
static func clear(world: WorldSim, actor: Actor, a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var length := d.length()
	if length < 0.001:
		return true
	var side := d.orthogonal().normalized() * actor.move.radius * 0.9
	for off in [Vector2.ZERO, side, -side]:
		var prev := MoveState.tile_of(a + off)
		var steps := ceili(length / SAMPLE)
		for k in range(1, steps + 1):
			var t := MoveState.tile_of(a + off + d * (float(k) / steps))
			if t == prev:
				continue
			if not _enters(world, actor, prev, t):
				return false
			prev = t
	return true


## One move between neighbouring (or diagonal) tiles by the actor's rules; a
## diagonal also needs one of its two side tiles (no squeezing through corners).
static func _enters(world: WorldSim, actor: Actor, from: Vector2i, to: Vector2i) -> bool:
	var delta := to - from
	if absi(delta.x) > 1 or absi(delta.y) > 1:
		return false
	if delta.x != 0 and delta.y != 0:
		var via_x := from + Vector2i(delta.x, 0)
		var via_y := from + Vector2i(0, delta.y)
		return (_step(world, actor, from, via_x) and _step(world, actor, via_x, to)) \
				and (_step(world, actor, from, via_y) and _step(world, actor, via_y, to))
	return _step(world, actor, from, to)


static func _step(world: WorldSim, actor: Actor, from: Vector2i, to: Vector2i) -> bool:
	if actor is Enemy and (actor as Enemy).airborne(world.now):
		return world.grid.can_fly(from, to, (actor as Enemy).fly_rise(world.now))
	return world.grid.can_step(from, to, StatCalc.jump_levels(actor.current_stats(world.now)))


## This tick's wish (grid direction, length = pace) along the actor's path;
## Vector2.ZERO when there is none or it has arrived.
static func follow(actor: Actor) -> Vector2:
	var m := actor.move
	while not actor.nav_path.is_empty():
		var next: Vector2 = actor.nav_path[0]
		var last := actor.nav_path.size() == 1
		var left := m.pos.distance_to(next) - (actor.nav_stop_short if last else 0.0)
		if left > REACHED:
			return (next - m.pos).normalized() * actor.nav_pace
		actor.nav_path.remove_at(0)
	return Vector2.ZERO


## Whether the actor still has somewhere to go.
static func moving(actor: Actor) -> bool:
	return not actor.nav_path.is_empty()
