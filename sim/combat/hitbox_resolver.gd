class_name HitboxResolver
extends RefCounted
## Casting an ability that has a hitbox (AbilityDef.hitbox): what it hits in
## continuous space. CastResolver hands over here; costs, cast bars, timing bars,
## cooldowns, crits and threat work as before. The aim is a point in tile units
## (the mouse); the direction is from the caster toward it, at any angle.
##
## - TARGETED: the chosen unit, within reach edge to edge and in line of sight.
## - CONE / RECT: at once, every unit the shape touches that the caster can see
##   (a non-piercing RECT: only the nearest).
## - CIRCLE: at the aim point, pulled back to reach; after its telegraph if any.
## - PROJECTILE: flies at its speed, stopped by terrain; the first unit, or all
##   it passes if it pierces.
## - LOB: lands on the aim point after arc_seconds (over obstacles), a circle.
## - SELF_CIRCLE: around the caster.
## - DASH / LEAP / BLINK: the caster moves (its DASH_TO / LEAP / BLINK effects),
##   then hits what the dash swept, or a circle where it landed.
## - TILES: the tile under the aim (terrain, ground zones), as before.


## Why the cast can't go off (Result), checked before paying.
static func validate(ctx: CombatContext, caster: Actor, ability: AbilityDef, target: Actor, aim: Variant) -> AbilityResolver.Result:
	var hb := ability.hitbox
	match hb.shape:
		HitboxDef.Shape.TARGETED:
			if ability.target == AbilityDef.TargetType.SELF:
				target = caster
			if not AbilityResolver._is_valid_target(caster, ability, target):
				return AbilityResolver.Result.INVALID_TARGET
			if target != caster:
				var g := Hitbox.gap(caster, target)
				if g > hb.reach + 0.001 or g < hb.min_reach - 0.001:
					return AbilityResolver.Result.OUT_OF_RANGE
				if ability.requires_line_of_sight and g > 0.5 \
						and not Hitbox.has_los(ctx.grid, caster.move.pos, target.move.pos, ctx.rules.los_height_tolerance):
					return AbilityResolver.Result.NO_LINE_OF_SIGHT
		HitboxDef.Shape.NONE, HitboxDef.Shape.SELF_CIRCLE:
			pass
		_:
			var point: Variant = aim_point(caster, target, aim)
			if point == null:
				return AbilityResolver.Result.INVALID_TARGET
			if hb.shape in [HitboxDef.Shape.CONE, HitboxDef.Shape.RECT, HitboxDef.Shape.PROJECTILE, HitboxDef.Shape.DASH] \
					and caster.move.pos.distance_to(point) < 0.01:
				return AbilityResolver.Result.INVALID_TARGET
			if hb.shape in [HitboxDef.Shape.CIRCLE, HitboxDef.Shape.LOB, HitboxDef.Shape.LEAP, HitboxDef.Shape.BLINK, HitboxDef.Shape.TILES] \
					and caster.move.pos.distance_to(point) < hb.min_reach - 0.001:
				return AbilityResolver.Result.OUT_OF_RANGE
	return AbilityResolver.Result.OK


## The aim as a point: the given aim, else the target's position, else ahead.
static func aim_point(caster: Actor, target: Actor, aim: Variant) -> Variant:
	if aim is Vector2:
		return aim
	if aim is Vector2i:
		return Vector2(aim)
	if target != null:
		return target.move.pos
	return null


## `point` pulled back toward the caster to within `reach`.
static func clamp_point(caster: Actor, point: Vector2, reach: float) -> Vector2:
	var d := point - caster.move.pos
	return caster.move.pos + d.limit_length(reach)


static func resolve(ctx: CombatContext, caster: Actor, ability: AbilityDef, target: Actor, aim: Variant, out: Dictionary) -> void:
	var hb := ability.hitbox
	var events: Array[Dictionary] = out.events
	if hb.shape == HitboxDef.Shape.TARGETED and ability.target == AbilityDef.TargetType.SELF:
		target = caster
	var origin := caster.move.pos
	var point: Vector2 = aim_point(caster, target, aim) if aim_point(caster, target, aim) != null \
			else origin + caster.facing_vector()
	var dir := (point - origin).normalized() if point.distance_to(origin) > 0.001 else caster.facing_vector()
	ctx.continuous = true
	ctx.cast_point = point
	ctx.cast_vec = dir
	ctx.cast_aim = MoveState.tile_of(point)
	ctx.cast_dir = TileGeometry.snap8(dir)
	ctx.cast_tiles = []
	if hb.shape not in [HitboxDef.Shape.NONE, HitboxDef.Shape.SELF_CIRCLE]:
		caster.face_angle(dir.angle())
	match hb.shape:
		HitboxDef.Shape.NONE:
			events.append({"type": "cast", "source": caster.id, "target": caster.id, "ability": ability.id})
			AbilityResolver.apply_caster_effects(ctx, caster, ability, events)
			AbilityResolver.apply_effects(ctx, caster, ability, caster, events)
		HitboxDef.Shape.TARGETED:
			AbilityResolver.apply_caster_effects(ctx, caster, ability, events)
			events.append({"type": "cast", "source": caster.id, "target": target.id, "ability": ability.id})
			if AbilityResolver.has_target_effects(ability):
				var reach := float(ability.hit_range) if ability.hit_range >= 0 else hb.reach
				if target == caster or Hitbox.gap(caster, target) <= reach + 0.05:
					AbilityResolver.apply_effects(ctx, caster, ability, target, events)
				else:
					events.append({"type": "whiff", "source": caster.id, "ability": ability.id, "tile": target.tile()})
			AbilityResolver.apply_area_effects(ctx, caster, ability,
					ctx.cast_tiles if not ctx.cast_tiles.is_empty() else [target.tile()], events)
		HitboxDef.Shape.CONE, HitboxDef.Shape.RECT:
			AbilityResolver.apply_caster_effects(ctx, caster, ability, events)
			var poly := shape_outline(ctx, caster, ability, point)
			events.append({"type": "cast", "source": caster.id, "target": -1, "ability": ability.id, "outline": poly})
			hit_shape(ctx, caster, ability, origin, dir, point, events)
		HitboxDef.Shape.CIRCLE, HitboxDef.Shape.LOB:
			var center := clamp_point(caster, point, hb.reach)
			var poly := Hitbox.outline("circle", center, dir, hb.radius, 0.0, center)
			var delay := ability.telegraph_seconds if hb.shape == HitboxDef.Shape.CIRCLE else ability.arc_seconds
			events.append({"type": "cast", "source": caster.id, "target": -1, "ability": ability.id,
					"outline": poly, "telegraph": delay, "tiles": Hitbox.tiles_in(ctx.grid, poly)})
			AbilityResolver.apply_caster_effects(ctx, caster, ability, events)
			if delay > 0.0:
				out.pending = pending_circle(caster, ability, center, hb.radius, ctx.now + delay)
			else:
				hit_circle(ctx, caster, ability, center, hb.radius, events)
		HitboxDef.Shape.SELF_CIRCLE:
			events.append({"type": "cast", "source": caster.id, "target": caster.id, "ability": ability.id,
					"outline": Hitbox.outline("circle", origin, dir, hb.radius, 0.0, origin)})
			AbilityResolver.apply_caster_effects(ctx, caster, ability, events)
			hit_circle(ctx, caster, ability, origin, hb.radius, events, ability.target == AbilityDef.TargetType.ALLY)
		HitboxDef.Shape.PROJECTILE:
			AbilityResolver.apply_caster_effects(ctx, caster, ability, events)
			var reach := Hitbox.clear_distance(ctx.grid, origin, dir, hb.reach, ctx.rules.los_height_tolerance)
			var p := Projectile.new()
			p.caster_id = caster.id
			p.ability = ability
			p.continuous = true
			p.origin = caster.tile()
			p.from = origin
			p.dirv = dir
			p.max_dist = reach
			p.radius = hb.size
			p.start_time = ctx.now
			p.speed = hb.speed
			p.pierce = hb.pierce
			events.append({"type": "cast", "source": caster.id, "target": -1, "ability": ability.id,
					"outline": Hitbox.outline("rect", origin, dir, reach, hb.size * 2.0)})
			out.projectile = p
		HitboxDef.Shape.DASH, HitboxDef.Shape.LEAP, HitboxDef.Shape.BLINK:
			var start := origin
			if hb.shape != HitboxDef.Shape.DASH:
				ctx.cast_point = clamp_point(caster, point, hb.reach)
				ctx.cast_aim = MoveState.tile_of(ctx.cast_point)
			events.append({"type": "cast", "source": caster.id, "target": target.id if target != null else -1,
					"ability": ability.id})
			AbilityResolver.apply_caster_effects(ctx, caster, ability, events)
			var end: Vector2 = caster.move.to_point if caster.move.gliding else caster.move.pos
			if hb.shape == HitboxDef.Shape.DASH:
				if target != null and target != caster and ability.hit_range >= 0:
					# A Lunge: dash, then strike the target if it got there.
					if target.alive and target.move.pos.distance_to(end) - caster.move.radius - target.move.radius <= ability.hit_range + 0.05:
						AbilityResolver.apply_effects(ctx, caster, ability, target, events)
					else:
						events.append({"type": "whiff", "source": caster.id, "ability": ability.id, "tile": target.tile()})
				elif AbilityResolver.has_target_effects(ability):
					hit_swept(ctx, caster, ability, start, end, hb.width * 0.5, events)
				AbilityResolver.apply_area_effects(ctx, caster, ability, ctx.cast_tiles, events)
			elif hb.radius > 0.0 and AbilityResolver.has_target_effects(ability):
				hit_circle_at(ctx, caster, ability, end, hb.radius, events)
		HitboxDef.Shape.TILES:
			pass # handled as a GROUND ability on the tile grid (CastResolver)
	ctx.continuous = false


## Every unit the cone or rectangle touches (that the caster can see); a
## non-piercing rectangle only hits the nearest. Area effects on its tiles.
static func hit_shape(ctx: CombatContext, caster: Actor, ability: AbilityDef, origin: Vector2, dir: Vector2,
		point: Vector2, events: Array[Dictionary]) -> void:
	var hb := ability.hitbox
	var reach := Hitbox.clear_distance(ctx.grid, origin, dir, hb.reach, ctx.rules.los_height_tolerance) \
			if hb.shape == HitboxDef.Shape.RECT else hb.reach
	var victims: Array[Actor] = []
	for a in _candidates(ctx, caster, ability):
		var c := a.move.pos
		var inside := Hitbox.in_cone(origin, dir, reach, hb.angle, c, a.move.radius) if hb.shape == HitboxDef.Shape.CONE \
				else Hitbox.in_rect(origin, dir, reach, hb.width, c, a.move.radius)
		if inside and (a == caster or Hitbox.has_los(ctx.grid, origin, c, ctx.rules.los_height_tolerance)):
			victims.append(a)
	if hb.shape == HitboxDef.Shape.RECT and not hb.pierce and victims.size() > 1:
		victims.sort_custom(func(x, y): return x.move.pos.distance_to(origin) < y.move.pos.distance_to(origin))
		victims = [victims[0]]
	_apply_all(ctx, caster, ability, victims, events, MoveState.tile_of(point))
	AbilityResolver.apply_area_effects(ctx, caster, ability,
			Hitbox.tiles_in(ctx.grid, shape_outline(ctx, caster, ability, point)), events)


## A circle at `center`: every affected unit in it, then area effects on its tiles.
static func hit_circle(ctx: CombatContext, caster: Actor, ability: AbilityDef, center: Vector2, radius: float,
		events: Array[Dictionary], include_caster := false) -> void:
	hit_circle_at(ctx, caster, ability, center, radius, events, include_caster)
	var tiles := Hitbox.tiles_in(ctx.grid, Hitbox.outline("circle", center, Vector2.RIGHT, radius, 0.0, center))
	if tiles.is_empty():
		tiles = [MoveState.tile_of(center)]
	AbilityResolver.apply_area_effects(ctx, caster, ability, tiles, events)


static func hit_circle_at(ctx: CombatContext, caster: Actor, ability: AbilityDef, center: Vector2, radius: float,
		events: Array[Dictionary], include_caster := false) -> void:
	var victims: Array[Actor] = []
	if include_caster and caster.alive:
		victims.append(caster)
	for a in _candidates(ctx, caster, ability):
		if a != caster and Hitbox.in_circle(center, radius, a.move.pos, a.move.radius):
			victims.append(a)
	_apply_all(ctx, caster, ability, victims, events, MoveState.tile_of(center))


## Every affected unit within `half_width` of the swept segment (a dash).
static func hit_swept(ctx: CombatContext, caster: Actor, ability: AbilityDef, a: Vector2, b: Vector2,
		half_width: float, events: Array[Dictionary]) -> void:
	var victims: Array[Actor] = []
	for u in _candidates(ctx, caster, ability):
		if u != caster and Hitbox.in_capsule(a, b, half_width, u.move.pos, u.move.radius):
			victims.append(u)
	_apply_all(ctx, caster, ability, victims, events, MoveState.tile_of(b))


static func _candidates(ctx: CombatContext, caster: Actor, ability: AbilityDef) -> Array[Actor]:
	var out: Array[Actor] = []
	var ids := ctx.actors.keys()
	ids.sort()
	for id in ids:
		var a: Actor = ctx.actors[id]
		if AbilityShapes.affects(caster, ability, a):
			out.append(a)
	return out


static func _apply_all(ctx: CombatContext, caster: Actor, ability: AbilityDef, victims: Array[Actor],
		events: Array[Dictionary], whiff_tile: Vector2i) -> void:
	for v in victims:
		AbilityResolver.apply_effects(ctx, caster, ability, v, events)
	if victims.is_empty() and AbilityResolver.has_target_effects(ability):
		events.append({"type": "whiff", "source": caster.id, "ability": ability.id, "tile": whiff_tile})


## The shape a cast would cover from where the caster stands toward `point`
## (grid-space polygon; empty for targeted and buff abilities).
static func shape_outline(ctx: CombatContext, caster: Actor, ability: AbilityDef, point: Vector2) -> PackedVector2Array:
	var hb := ability.hitbox
	var origin := caster.move.pos
	var dir := (point - origin).normalized() if point.distance_to(origin) > 0.001 else caster.facing_vector()
	match hb.shape:
		HitboxDef.Shape.CONE:
			return Hitbox.outline("cone", origin, dir, hb.reach, hb.angle)
		HitboxDef.Shape.RECT:
			var reach := Hitbox.clear_distance(ctx.grid, origin, dir, hb.reach, ctx.rules.los_height_tolerance)
			return Hitbox.outline("rect", origin, dir, reach, hb.width)
		HitboxDef.Shape.PROJECTILE:
			var reach := Hitbox.clear_distance(ctx.grid, origin, dir, hb.reach, ctx.rules.los_height_tolerance)
			return Hitbox.outline("rect", origin, dir, reach, maxf(hb.size * 2.0, 0.3))
		HitboxDef.Shape.CIRCLE, HitboxDef.Shape.LOB, HitboxDef.Shape.LEAP, HitboxDef.Shape.BLINK:
			var c := clamp_point(caster, point, hb.reach)
			return Hitbox.outline("circle", c, dir, maxf(hb.radius, 0.35), 0.0, c)
		HitboxDef.Shape.SELF_CIRCLE:
			return Hitbox.outline("circle", origin, dir, hb.radius, 0.0, origin)
		HitboxDef.Shape.DASH:
			var reach := minf(hb.reach, origin.distance_to(point))
			return Hitbox.outline("rect", origin, dir, reach, maxf(hb.width, caster.move.radius * 2.0))
	return PackedVector2Array()


## A delayed circle (a telegraph or a lob's landing).
static func pending_circle(caster: Actor, ability: AbilityDef, center: Vector2, radius: float, at: float) -> Dictionary:
	return {"caster": caster.id, "ability": ability, "tiles": [] as Array[Vector2i], "at": at, "grace": 0.0,
			"bonus": 1.0, "circle": [center, radius],
			"outline": Hitbox.outline("circle", center, Vector2.RIGHT, radius, 0.0, center)}
