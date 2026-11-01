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
	var mult := actor.buffs.step_multiplier(now)
	return s / mult if mult > 0.0 else s


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
	if not grid.in_bounds(t):
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
## direction of length 1 (or zero): W = up the screen = grid (−1, −1).
static func screen_to_grid(dir: Vector2i) -> Vector2:
	var sx := float(clampi(dir.x, -1, 1))
	var sy := float(clampi(dir.y, -1, 1))
	var g := Vector2(sx * 0.5 + sy, sy - sx * 0.5)
	return g.normalized() if g != Vector2.ZERO else Vector2.ZERO
