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


## Pay modes for cast(): INSTANT checks and pays everything (mana, cooldown, GCD);
## COMPLETE finishes a cast time (pays mana and cooldown; the GCD was taken when
## the cast started); FREE resolves an already-paid wind-up or channel tick.
enum Pay { INSTANT, COMPLETE, FREE }


static func validate(ctx: CombatContext, caster: Actor, ability: AbilityDef, target: Actor, aim: Variant,
		pay_mode: Pay = Pay.INSTANT) -> AbilityResolver.Result:
	if not caster.alive:
		return AbilityResolver.Result.CASTER_DEAD
	if pay_mode == Pay.INSTANT and not caster.casting.is_empty():
		return AbilityResolver.Result.BUSY
	match ability.targeting:
		AbilityDef.TargetingMode.TARGETED:
			if ability.target == AbilityDef.TargetType.SELF:
				target = caster
			if not AbilityResolver._is_valid_target(caster, ability, target):
				return AbilityResolver.Result.INVALID_TARGET
			if target != caster:
				var dist := TileGeometry.range_distance(caster.tile(), target.tile())
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
			var dist := TileGeometry.range_distance(caster.tile(), tile)
			if dist < ability.min_range or dist > ability.max_range:
				return AbilityResolver.Result.OUT_OF_RANGE
	if pay_mode == Pay.FREE:
		return AbilityResolver.Result.OK
	return AbilityResolver._check_cost(ctx, caster, ability, pay_mode == Pay.INSTANT)


static func cast(ctx: CombatContext, caster: Actor, ability: AbilityDef, target: Actor, aim: Variant,
		pay_mode: Pay = Pay.INSTANT, bonus: float = -1.0) -> Dictionary:
	var out := {"result": validate(ctx, caster, ability, target, aim, pay_mode), "events": [] as Array[Dictionary],
			"projectile": null, "pending": null, "bonus": 1.0}
	if out.result != AbilityResolver.Result.OK:
		return out
	if pay_mode != Pay.FREE:
		AbilityResolver.pay(ctx, caster, ability, pay_mode == Pay.INSTANT)
	# Damage bonuses (e.g. Kindle) are fixed when the ability goes off and carried
	# by its projectile or delayed hit; charges are used up after.
	out.bonus = bonus if bonus >= 0.0 else caster.buffs.damage_dealt_multiplier(ability.tree, ctx.now)
	ctx.damage_bonus = out.bonus
	var had := caster.buffs.ids()
	had[&""] = true # never empty: spare what this cast applies
	_resolve(ctx, caster, ability, target, aim, out)
	ctx.damage_bonus = 1.0
	if pay_mode != Pay.FREE:
		caster.buffs.consume_on_cast(ability.tree, ctx.now, had)
	if out.projectile != null:
		out.projectile.damage_bonus = out.bonus
	if out.pending != null:
		out.pending.bonus = out.bonus
	return out


static func _resolve(ctx: CombatContext, caster: Actor, ability: AbilityDef, target: Actor, aim: Variant, out: Dictionary) -> void:
	var events: Array[Dictionary] = out.events
	if ability.targeting == AbilityDef.TargetingMode.TARGETED and ability.target == AbilityDef.TargetType.SELF:
		target = caster
	var point: Variant = aim_point(caster, target, aim)
	if ability.targeting == AbilityDef.TargetingMode.SELF and aim == null:
		point = Vector2(caster.tile() + caster.facing)
	if point == null:
		point = Vector2(caster.tile() + caster.facing)
	ctx.cast_aim = Vector2i(roundi(point.x), roundi(point.y))
	ctx.cast_dir = TileGeometry.snap8(point - Vector2(caster.tile()))
	ctx.cast_tiles = []
	if ability.targeting != AbilityDef.TargetingMode.SELF or aim != null:
		_face(caster, point)
	# The caster's own effects first: a Lunge dashes, then strikes.
	AbilityResolver.apply_caster_effects(ctx, caster, ability, events)
	var trail: Array = ctx.cast_tiles.duplicate() # tiles a dash went through (Flame Dash)
	match ability.targeting:
		AbilityDef.TargetingMode.TARGETED:
			events.append({"type": "cast", "source": caster.id, "target": target.id, "ability": ability.id})
			if AbilityResolver.has_target_effects(ability):
				var reach := ability.hit_range if ability.hit_range >= 0 else ability.max_range
				if target == caster or TileGeometry.range_distance(caster.tile(), target.tile()) <= reach:
					AbilityResolver.apply_effects(ctx, caster, ability, target, events)
				else:
					events.append({"type": "whiff", "source": caster.id, "ability": ability.id, "tile": target.tile()})
			AbilityResolver.apply_area_effects(ctx, caster, ability, trail if not trail.is_empty() else [target.tile()], events)
		AbilityDef.TargetingMode.SKILLSHOT:
			_cast_skillshot(ctx, caster, ability, point, out)
		AbilityDef.TargetingMode.GROUND:
			var area := area_tiles(ctx.grid, ctx.cast_aim, ability.area_radius)
			events.append({"type": "cast", "source": caster.id, "target": -1, "ability": ability.id,
					"tiles": area, "telegraph": ability.telegraph_seconds})
			if ability.telegraph_seconds > 0.0:
				out.pending = _pending(caster, ability, area, ctx.now + ability.telegraph_seconds, 0.0)
			else:
				hit_tiles(ctx, caster, ability, area, 0.0, events, false, trail)
		AbilityDef.TargetingMode.SELF:
			events.append({"type": "cast", "source": caster.id, "target": caster.id, "ability": ability.id})
			if ability.area_radius <= 0:
				AbilityResolver.apply_effects(ctx, caster, ability, caster, events)
				AbilityResolver.apply_area_effects(ctx, caster, ability, trail if not trail.is_empty() else [caster.tile()], events)
			else:
				var area := area_tiles(ctx.grid, caster.tile(), ability.area_radius)
				hit_tiles(ctx, caster, ability, area, 0.0, events, ability.target == AbilityDef.TargetType.ALLY, trail)


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
	ctx.cast_tiles = tiles
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
	if TileGeometry.range_distance(origin, aimed) <= max_range:
		return aimed
	var line := TileGeometry.line_toward(origin, point, max_range)
	while not line.is_empty() and TileGeometry.range_distance(origin, line.back()) > max_range:
		line.pop_back() # diagonals count double
	return line.back() if not line.is_empty() else origin


## Square area around `center`, inside the map.
static func area_tiles(grid: GridModel, center: Vector2i, radius: int) -> Array[Vector2i]:
	return TileGeometry.square(center, radius).filter(func(t): return grid.in_bounds(t))


## Applies the ability to every affected unit on `tiles` (each once), then its
## AREA effects (terrain, zones) to `tiles` — or to `area_override` (a dash trail).
## SELF areas for allies include the caster.
static func hit_tiles(ctx: CombatContext, caster: Actor, ability: AbilityDef, tiles: Array, grace: float,
		events: Array[Dictionary], include_caster: bool = false, area_override: Array = []) -> void:
	var hit := {}
	if include_caster and caster.alive:
		hit[caster.id] = true
		AbilityResolver.apply_effects(ctx, caster, ability, caster, events)
	for t in tiles:
		for a in actors_on(ctx, t, caster, ability, grace):
			if not hit.has(a.id):
				hit[a.id] = true
				AbilityResolver.apply_effects(ctx, caster, ability, a, events)
	if hit.is_empty() and AbilityResolver.has_target_effects(ability):
		events.append({"type": "whiff", "source": caster.id, "ability": ability.id,
				"tile": tiles[0] if not tiles.is_empty() else caster.tile()})
	AbilityResolver.apply_area_effects(ctx, caster, ability, area_override if not area_override.is_empty() else tiles, events)


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
	return {"caster": caster.id, "ability": ability, "tiles": tiles, "at": at, "grace": grace, "bonus": 1.0}


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
		if warn >= 0.0:
			warn += a.windup_seconds # a wind-up is time to react too
		if warn >= 0.0 and warn < limit:
			out.append("%s (%s): %.2f s to react, under step %.1f s + %.1f s: can't really be dodged" % [
					a.display_name, a.id, warn, rules.combat_step_base_seconds, rules.dodge_reaction_seconds])
	return out
