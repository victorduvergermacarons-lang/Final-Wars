class_name CastResolver
extends RefCounted
## Milestone 3 targeting (abilities whose `targeting` isn't LEGACY; CLAUDE.md §3):
## - TARGETED: on a unit; locks on, can't miss; range (square distance) and line of
##   sight checked at cast.
## - SKILLSHOT: aimed at a point; an any-angle or 8-way line (or cone) clipped by
##   height and walls. Instant, a flying projectile (speed), or lobbed (arc_seconds)
##   onto the aimed tile. Hits the first unit unless it pierces. Units count as on a
##   tile if they were there in the last `skillshot_grace_seconds`.
## - GROUND: a tile within range; the square area resolves at once or after its
##   telegraph, on whoever stands there then.
## - SELF: the caster, or a square area around them.
## There's no Accuracy/Evasion roll (dodge by moving); crits still roll.
##
## cast() returns {"result", "events", "projectile" (or null), "pending" (or null)}:
## WorldSim flies projectiles and resolves pending hits (telegraphs, lobs) later.


static func validate(ctx: CombatContext, caster: Actor, ability: AbilityDef, target: Actor, aim: Variant) -> AbilityResolver.Result:
	if not caster.alive:
		return AbilityResolver.Result.CASTER_DEAD
	match ability.targeting:
		AbilityDef.TargetingMode.TARGETED:
			if ability.target == AbilityDef.TargetType.SELF:
				target = caster
			if not AbilityResolver._is_valid_target(caster, ability, target):
				return AbilityResolver.Result.INVALID_TARGET
			if target != caster:
				var dist := TileGeometry.distance(caster.tile(), target.tile())
				if dist < ability.min_range or dist > ability.max_range:
					return AbilityResolver.Result.OUT_OF_RANGE
				if ability.requires_line_of_sight and dist > 1 \
						and not LineOfSight.has_los(ctx.grid, caster.tile(), target.tile(), ctx.rules.los_height_tolerance):
					return AbilityResolver.Result.NO_LINE_OF_SIGHT
		AbilityDef.TargetingMode.SKILLSHOT:
			var point: Variant = aim_point(caster, target, aim)
			if point == null or Vector2(caster.tile()).distance_to(point) < 0.01:
				return AbilityResolver.Result.INVALID_TARGET
		AbilityDef.TargetingMode.GROUND:
			var tile: Variant = aim_tile(caster, target, aim)
			if tile == null or not ctx.grid.in_bounds(tile):
				return AbilityResolver.Result.INVALID_TARGET
			var dist := TileGeometry.distance(caster.tile(), tile)
			if dist < ability.min_range or dist > ability.max_range:
				return AbilityResolver.Result.OUT_OF_RANGE
	return AbilityResolver._check_cost(ctx, caster, ability)


static func cast(ctx: CombatContext, caster: Actor, ability: AbilityDef, target: Actor, aim: Variant) -> Dictionary:
	var out := {"result": validate(ctx, caster, ability, target, aim), "events": [] as Array[Dictionary],
			"projectile": null, "pending": null}
	if out.result != AbilityResolver.Result.OK:
		return out
	caster.mana -= ability.mana_cost
	caster.cooldowns.trigger(ability, ctx.now, ctx.rules.gcd_seconds)
	var events: Array[Dictionary] = out.events
	match ability.targeting:
		AbilityDef.TargetingMode.TARGETED:
			if ability.target == AbilityDef.TargetType.SELF:
				target = caster
			_face(caster, Vector2(target.tile()))
			events.append({"type": "cast", "source": caster.id, "target": target.id, "ability": ability.id})
			AbilityResolver.apply_effects(ctx, caster, ability, target, events)
		AbilityDef.TargetingMode.SKILLSHOT:
			var point: Vector2 = aim_point(caster, target, aim)
			_face(caster, point)
			_cast_skillshot(ctx, caster, ability, point, out)
		AbilityDef.TargetingMode.GROUND:
			var tile: Vector2i = aim_tile(caster, target, aim)
			_face(caster, Vector2(tile))
			var area := area_tiles(ctx.grid, tile, ability.area_radius)
			events.append({"type": "cast", "source": caster.id, "target": -1, "ability": ability.id,
					"tiles": area, "telegraph": ability.telegraph_seconds})
			if ability.telegraph_seconds > 0.0:
				out.pending = _pending(caster, ability, area, ctx.now + ability.telegraph_seconds, 0.0)
			else:
				hit_tiles(ctx, caster, ability, area, 0.0, events)
		AbilityDef.TargetingMode.SELF:
			events.append({"type": "cast", "source": caster.id, "target": caster.id, "ability": ability.id})
			if ability.area_radius <= 0:
				AbilityResolver.apply_effects(ctx, caster, ability, caster, events)
			else:
				var area := area_tiles(ctx.grid, caster.tile(), ability.area_radius)
				hit_tiles(ctx, caster, ability, area, 0.0, events, ability.target == AbilityDef.TargetType.ALLY)
	return out


static func _cast_skillshot(ctx: CombatContext, caster: Actor, ability: AbilityDef, point: Vector2, out: Dictionary) -> void:
	var events: Array[Dictionary] = out.events
	var grace := ctx.rules.skillshot_grace_seconds
	if ability.arc_seconds > 0.0:
		var landing := lob_tile(caster.tile(), point, ability.max_range)
		var tiles: Array[Vector2i] = [landing]
		events.append({"type": "cast", "source": caster.id, "target": -1, "ability": ability.id,
				"tiles": tiles, "telegraph": ability.arc_seconds})
		out.pending = _pending(caster, ability, tiles, ctx.now + ability.arc_seconds, grace)
		return
	var tiles := skillshot_tiles(ctx, caster, ability, point)
	events.append({"type": "cast", "source": caster.id, "target": -1, "ability": ability.id, "tiles": tiles})
	if ability.projectile_speed > 0.0:
		var p := Projectile.new()
		p.caster_id = caster.id
		p.ability = ability
		p.origin = caster.tile()
		p.dir = TileGeometry.snap8(point - Vector2(caster.tile()))
		p.path = tiles
		p.start_time = ctx.now
		p.speed = ability.projectile_speed
		p.pierce = ability.pierce
		out.projectile = p
		return
	if ability.line_shape == AbilityDef.LineShape.CONE or ability.pierce:
		hit_tiles(ctx, caster, ability, tiles, grace, events)
		return
	for t in tiles:
		var victims := actors_on(ctx, t, caster, ability, grace)
		if not victims.is_empty():
			AbilityResolver.apply_effects(ctx, caster, ability, victims[0], events)
			return
	events.append({"type": "whiff", "source": caster.id, "ability": ability.id, "tile": tiles.back() if not tiles.is_empty() else caster.tile()})


## The tiles a skillshot covers, after terrain clipping.
static func skillshot_tiles(ctx: CombatContext, caster: Actor, ability: AbilityDef, point: Vector2) -> Array[Vector2i]:
	var origin := caster.tile()
	var tiles: Array[Vector2i]
	if ability.line_shape == AbilityDef.LineShape.CONE:
		tiles = TileGeometry.cone(origin, TileGeometry.snap8(point - Vector2(origin)), ability.max_range)
		return tiles.filter(func(t): return ctx.grid.in_bounds(t) \
				and ctx.grid.height_at(t) <= ctx.grid.height_at(origin) + ctx.rules.los_height_tolerance)
	if ability.aim == AbilityDef.Aim.EIGHT_WAY:
		tiles = TileGeometry.line8(origin, TileGeometry.snap8(point - Vector2(origin)), ability.max_range)
	else:
		tiles = TileGeometry.line_toward(origin, point, ability.max_range)
	return TileGeometry.clip_line(ctx.grid, tiles, ctx.grid.height_at(origin), ctx.rules.los_height_tolerance)


## Where a lobbed shot lands: the aimed tile, or the furthest tile toward it in range.
static func lob_tile(origin: Vector2i, point: Vector2, max_range: int) -> Vector2i:
	var aimed := Vector2i(roundi(point.x), roundi(point.y))
	if TileGeometry.distance(origin, aimed) <= max_range:
		return aimed
	var line := TileGeometry.line_toward(origin, point, max_range)
	return line.back() if not line.is_empty() else origin


## Square area around `center`, inside the map.
static func area_tiles(grid: GridModel, center: Vector2i, radius: int) -> Array[Vector2i]:
	return TileGeometry.square(center, radius).filter(func(t): return grid.in_bounds(t))


## Applies the ability to every affected unit on `tiles` (each once). SELF areas
## for allies include the caster.
static func hit_tiles(ctx: CombatContext, caster: Actor, ability: AbilityDef, tiles: Array, grace: float,
		events: Array[Dictionary], include_caster: bool = false) -> void:
	var hit := {}
	if include_caster and caster.alive:
		hit[caster.id] = true
		AbilityResolver.apply_effects(ctx, caster, ability, caster, events)
	for t in tiles:
		for a in actors_on(ctx, t, caster, ability, grace):
			if not hit.has(a.id):
				hit[a.id] = true
				AbilityResolver.apply_effects(ctx, caster, ability, a, events)
	if hit.is_empty():
		events.append({"type": "whiff", "source": caster.id, "ability": ability.id,
				"tile": tiles[0] if not tiles.is_empty() else caster.tile()})


## Units the ability would affect on `tile` (now, or within the grace window), by id.
static func actors_on(ctx: CombatContext, tile: Vector2i, caster: Actor, ability: AbilityDef, grace: float) -> Array[Actor]:
	var out: Array[Actor] = []
	var ids := ctx.actors.keys()
	ids.sort()
	for id in ids:
		var a: Actor = ctx.actors[id]
		if AbilityShapes.affects(caster, ability, a) and ctx.was_on(a, tile, grace):
			out.append(a)
	return out


## Aim as a point in tile units: the given aim, else the target's tile.
static func aim_point(caster: Actor, target: Actor, aim: Variant) -> Variant:
	if aim is Vector2:
		return aim
	if aim is Vector2i:
		return Vector2(aim)
	if target != null:
		return Vector2(target.tile())
	return null


static func aim_tile(caster: Actor, target: Actor, aim: Variant) -> Variant:
	var p: Variant = aim_point(caster, target, aim)
	return null if p == null else Vector2i(roundi(p.x), roundi(p.y))


## A delayed resolution (telegraphed ground area, lobbed shot).
static func _pending(caster: Actor, ability: AbilityDef, tiles: Array[Vector2i], at: float, grace: float) -> Dictionary:
	return {"caster": caster.id, "ability": ability, "tiles": tiles, "at": at, "grace": grace}


## Turns the caster (4-way facing) toward a point.
static func _face(caster: Actor, point: Vector2) -> void:
	var d := point - Vector2(caster.tile())
	if d.length_squared() < 0.01:
		return
	caster.face(Vector2i(signi(roundi(d.x)), 0) if absf(d.x) >= absf(d.y) else Vector2i(0, signi(roundi(d.y))))


## Abilities whose warning time (skillshot travel, lob or telegraph) is shorter than
## a hero's base combat step plus the reaction time: they can't really be dodged.
static func dodge_warnings(abilities: Array, rules: CombatRules) -> PackedStringArray:
	var out: PackedStringArray = []
	var limit := rules.combat_step_base_seconds + rules.dodge_reaction_seconds
	for a in abilities:
		if a == null or not a.implemented:
			continue
		var warn := -1.0
		if a.targeting == AbilityDef.TargetingMode.SKILLSHOT:
			if a.arc_seconds > 0.0:
				warn = a.arc_seconds
			elif a.projectile_speed > 0.0:
				warn = a.max_range / a.projectile_speed
			else:
				warn = 0.0
		elif a.targeting == AbilityDef.TargetingMode.GROUND and a.effects.any(func(e): return e.kind == AbilityEffect.Kind.DAMAGE):
			warn = a.telegraph_seconds
		if warn >= 0.0 and warn < limit:
			out.append("%s (%s): %.2f s to react, under step %.1f s + %.1f s: can't really be dodged" % [
					a.display_name, a.id, warn, rules.combat_step_base_seconds, rules.dodge_reaction_seconds])
	return out
