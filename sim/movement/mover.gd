class_name Mover
extends RefCounted
## Free movement for one unit over one tick: acceleration toward the wished
## direction, sliding collision against the terrain, height rules, and falls under
## gravity. Pure: the host (WorldSim) and a client predicting its own hero run the
## same code. Unit-against-unit pushes are separate (separate_pair).
##
## Terrain rules (tiles keep their height; positions are continuous):
## - unwalkable tiles and the map's outside are solid squares;
## - a tile higher than the ground under the unit by more than its Jump is a cliff
##   face and blocks;
## - any drop is allowed: a drop of rules.movement.fall_min_levels or more is a fall
##   (no steering until it lands, gravity pulls it down), and falling more than
##   fall_damage_above levels hurts (the caller applies the damage it returns).


## Speed (tiles/s) the actor may move at now: its base (heroes: walk_speed,
## enemies: their own), the combat factor, Speed (each point = 1% faster, up to 3×),
## slows and Haste (the buffs' step multiplier), nothing while rooted or stunned.
static func speed_of(actor: Actor, rules: CombatRules, now: float) -> float:
	if actor.buffs.is_rooted(now) or actor.buffs.is_stunned(now):
		return 0.0
	var md := rules.movement
	var s := actor.base_move_speed(rules)
	if actor.in_combat(now):
		s *= md.combat_speed_factor
	var stat := maxf(actor.current_stats(now).speed, 0.0)
	s *= clampf((rules.speed_half_point + stat) / rules.speed_half_point, 0.25,
			rules.combat_step_base_seconds / rules.combat_step_min_seconds)
	s *= cast_move_factor(actor, rules)
	var mult := actor.buffs.step_multiplier(now)
	return s / mult if mult > 0.0 else s


## While casting (cast bar, wind-up, channel, timing bar) a unit walks at the
## ability's share of its speed; 1 otherwise.
static func cast_move_factor(actor: Actor, rules: CombatRules) -> float:
	var ability = actor.casting.get("ability")
	if not ability is AbilityDef:
		return 1.0
	var share: float = ability.cast_move_speed if ability.cast_move_speed >= 0.0 else rules.cast_move_speed_default
	return clampf(share, 0.0, 1.0)


## Moves `actor` for `dt` seconds toward `wish` (grid space, length 0..1).
## Returns {"landed": levels fallen when a fall ended this tick (0 if none),
## "fell": true when a fall started}.
static func step(actor: Actor, wish: Vector2, dt: float, grid: GridModel, rules: CombatRules,
		now: float, flying := false) -> Dictionary:
	var m := actor.move
	var md := rules.movement
	var out := {"landed": 0, "fell": false}
	if m.gliding or grid == null:
		return out
	if m.falling():
		m.vz += md.gravity * dt
		m.z -= m.vz * dt
		_slide(actor, m.vel * dt, grid, md, flying)
		if m.z <= 0.0:
			out.landed = m.fall_from - m.ground_h
			m.z = 0.0
			m.vz = 0.0
			m.vel = Vector2.ZERO
		m.draw_h = m.ground_h + maxf(m.z, 0.0)
		return out
	var speed := speed_of(actor, rules, now)
	var target := wish.limit_length(1.0) * speed
	var friction := grid.friction_at(m.to_tile)
	if target != Vector2.ZERO:
		m.vel = m.vel.move_toward(target, speed / maxf(md.accel_time, 0.001) * friction * dt)
	else:
		var full := maxf(speed, actor.base_move_speed(rules))
		m.vel = m.vel.move_toward(Vector2.ZERO, full / maxf(md.decel_time, 0.001) * friction * dt)
	var started := _slide(actor, m.vel * dt, grid, md, flying)
	if started:
		out.fell = true
	if not m.falling():
		m.draw_h = move_toward(m.draw_h, float(m.ground_h), md.step_smooth_rate * dt)
	else:
		m.draw_h = m.ground_h + m.z
	return out


## Moves by `delta` in sub-steps, pushing out of solid tiles after each and
## tracking the ground. True if a fall started.
static func _slide(actor: Actor, delta: Vector2, grid: GridModel, md: MovementDef, flying: bool) -> bool:
	var m := actor.move
	var n := maxi(ceili(delta.length() / maxf(md.substep, 0.01)), 1)
	var fell := false
	for i in n:
		var before := m.pos
		m.pos += delta / n
		resolve_terrain(actor, grid, flying)
		m.odometer += before.distance_to(m.pos)
		m.screen_odometer += MoveState.screen_length(m.pos - before)
		if _update_ground(actor, grid, md, flying):
			fell = true
	return fell


## When the centre enters a new tile: the ground under it changes; a big enough
## drop starts a fall. True if a fall started.
static func _update_ground(actor: Actor, grid: GridModel, md: MovementDef, flying: bool) -> bool:
	var m := actor.move
	var h := grid.height_at(m.to_tile)
	if h == m.ground_h:
		return false
	var drop := m.ground_h - h
	if not flying and drop >= md.fall_min_levels and not m.falling():
		m.fall_from = m.ground_h
		m.z = float(drop)
		m.vz = 0.0
		m.vel *= md.fall_carry
		m.ground_h = h
		return true
	if m.falling():
		m.z += float(m.ground_h - h) # still in the air, over different ground
		m.fall_from = maxi(m.fall_from, m.ground_h)
	m.ground_h = h
	return false


## Whether the tile `t` stops a unit standing at height `from_h` with `jump`.
static func blocks(grid: GridModel, t: Vector2i, from_h: int, jump: int, flying: bool, fly_rise := 1) -> bool:
	if not grid.has_tile(t): # off the map, or a hole in its shape
		return true
	if flying:
		return grid.blocks_sight(t) or (not grid.is_walkable(t) and grid.height_at(t) - from_h > fly_rise)
	if not grid.is_walkable(t):
		return true
	return grid.height_at(t) - from_h > jump


## Pushes the actor's circle out of every solid tile around it, removing the
## velocity into the wall (so it slides along it).
static func resolve_terrain(actor: Actor, grid: GridModel, flying := false) -> void:
	var m := actor.move
	var r := m.radius
	var jump := StatCalc.jump_levels(actor.stats)
	var from_h := m.ground_h + int(ceilf(m.z)) if m.falling() else m.ground_h
	var reach := ceili(r + 0.5)
	for _round in 2:
		var c := MoveState.tile_of(m.pos)
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var t := c + Vector2i(dx, dy)
				if (dx == 0 and dy == 0) or not blocks(grid, t, from_h, jump, flying):
					continue
				var lo := Vector2(t) - Vector2(0.5, 0.5)
				var hi := Vector2(t) + Vector2(0.5, 0.5)
				var closest := m.pos.clamp(lo, hi)
				var d := m.pos - closest
				var dist := d.length()
				if dist >= r:
					continue
				var normal: Vector2
				if dist > 0.00001:
					normal = d / dist
					m.pos += normal * (r - dist)
				else:
					# The centre is inside the square: out along the shallowest side.
					var pen := [m.pos.x - lo.x, hi.x - m.pos.x, m.pos.y - lo.y, hi.y - m.pos.y]
					var k := pen.find(pen.min())
					normal = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN][k]
					m.pos += normal * (pen[k] + r)
				var vn := m.vel.dot(normal)
				if vn < 0.0:
					m.vel -= normal * vn


## Pushes two overlapping units apart, the lighter one more (Weight); `a_fixed` /
## `b_fixed` units don't move (gliding, immobile, the dummy).
static func separate_pair(a: Actor, b: Actor, a_fixed: bool, b_fixed: bool) -> bool:
	var d := b.move.pos - a.move.pos
	var min_d := a.move.radius + b.move.radius
	var dist := d.length()
	if dist >= min_d or (a_fixed and b_fixed):
		return false
	var normal := d / dist if dist > 0.00001 else Vector2.RIGHT.rotated(float(a.id % 8) * PI / 4.0)
	var overlap := min_d - dist
	var wa := 0.0 if a_fixed else _mass(b)
	var wb := 0.0 if b_fixed else _mass(a)
	var total := wa + wb
	a.move.pos -= normal * overlap * wa / total
	b.move.pos += normal * overlap * wb / total
	return true


static func _mass(a: Actor) -> float:
	return [1.0, 2.0, 4.0][clampi(int(a.weight), 0, 2)]


## Fall damage for a fall of `levels` (0 when it doesn't hurt), before the
## can't-kill rule.
static func fall_damage(levels: int, max_hp: float, md: MovementDef) -> float:
	var over := levels - md.fall_damage_above
	if over <= 0:
		return 0.0
	return roundf(max_hp * minf(over * md.fall_damage_percent_per_level, md.fall_damage_max_percent) / 100.0)


## Screen-relative 8-way input (x right, y down on screen, each −1..1) to a grid
## direction of length 1 (or zero). One key walks straight along the screen:
## W = up the screen = grid (−1, −1). Two keys walk exactly along a grid line
## (on the 2:1 isometric grid those run at 26.6° on screen, not 45°):
## W+A = grid (−1, 0), W+D = grid (0, −1), S+D = grid (1, 0), S+A = grid (0, 1).
## A stick direction on screen (x right, y down, length 0..1: how far it's pushed)
## as a grid-space wish of the same length. Unlike the keys' 8 directions, any
## angle: straight up the screen is between grid up and grid left.
static func stick_to_grid(stick: Vector2) -> Vector2:
	var s := stick.limit_length(1.0)
	var g := Vector2(s.x * 0.5 + s.y, s.y - s.x * 0.5)
	return g.normalized() * s.length() if g != Vector2.ZERO else Vector2.ZERO


## The wish of a move intent: the stick if it has one, else the held keys.
static func wish_of(intent: Dictionary) -> Vector2:
	if intent.get("stick") is Vector2:
		return stick_to_grid(intent.stick)
	return screen_to_grid(intent.get("dir", Vector2i.ZERO))


static func screen_to_grid(dir: Vector2i) -> Vector2:
	var sx := clampi(dir.x, -1, 1)
	var sy := clampi(dir.y, -1, 1)
	if sx != 0 and sy != 0:
		return Vector2((sx + sy) / 2, (sy - sx) / 2)
	var g := Vector2(sx * 0.5 + sy, sy - sx * 0.5)
	return g.normalized() if g != Vector2.ZERO else Vector2.ZERO
