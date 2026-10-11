class_name AbilityShapes
extends RefCounted
## Geometry of FRONT and LINE abilities: which tiles they cover and whom they hit.
## Used by the host to resolve, by enemy AI to decide, and by the HUD to preview.


## Whether `ability` would affect `actor` when cast by `caster`.
static func affects(caster: Actor, ability: AbilityDef, actor: Actor) -> bool:
	if actor == null or actor == caster or not actor.alive:
		return false
	if ability.target == AbilityDef.TargetType.ENEMY:
		return caster.is_hostile_to(actor) and not actor.evading
	if ability.target == AbilityDef.TargetType.ALLY:
		return not caster.is_hostile_to(actor)
	return false


## The first affected actor on the tiles straight ahead (min..max range), or null.
static func front_victim(ctx: CombatContext, caster: Actor, ability: AbilityDef) -> Actor:
	for k in range(maxi(ability.min_range, 1), ability.max_range + 1):
		var tile := caster.tile() + caster.facing * k
		var actor := actor_at(ctx, tile, caster, ability)
		if actor == null:
			continue
		var dh := absi(ctx.grid.height_at(tile) - ctx.grid.height_at(caster.tile()))
		if ability.max_height_difference < 0 or dh <= ability.max_height_difference:
			return actor
	return null


## Tiles a projectile from `origin` flying along `dir` passes through, nearest
## first, up to `max_range`. It flies at the origin's height and stops before a
## tile that rises more than `tolerance` levels above that (or leaves the map).
static func line_path(grid: GridModel, origin: Vector2i, dir: Vector2i, max_range: int, tolerance: float) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var fly_height := float(grid.height_at(origin))
	for k in range(1, max_range + 1):
		var tile := origin + dir * k
		if not grid.in_bounds(tile) or float(grid.height_at(tile)) > fly_height + tolerance:
			break
		path.append(tile)
	return path


## Whether `target` stands where `ability` would reach it right now, given the
## caster's position and facing. For TARGETED abilities: range and line of sight.
static func in_reach(ctx: CombatContext, caster: Actor, ability: AbilityDef, target: Actor) -> bool:
	match ability.shape:
		AbilityDef.Shape.FRONT:
			return front_victim(ctx, caster, ability) == target
		AbilityDef.Shape.LINE:
			return line_first_victim(ctx, caster, ability) == target
	var r := AbilityResolver.validate(ctx, caster, ability, target)
	return r != AbilityResolver.Result.OUT_OF_RANGE and r != AbilityResolver.Result.NO_LINE_OF_SIGHT \
			and r != AbilityResolver.Result.INVALID_TARGET


## The first affected actor along the caster's line, as if the projectile were
## instant. Null if it would hit nothing.
static func line_first_victim(ctx: CombatContext, caster: Actor, ability: AbilityDef) -> Actor:
	for tile in line_path(ctx.grid, caster.tile(), caster.facing, ability.max_range, ctx.rules.los_height_tolerance):
		var actor := actor_at(ctx, tile, caster, ability)
		if actor != null:
			return actor
	return null


## The first actor on `tile` that the ability would affect, or null.
static func actor_at(ctx: CombatContext, tile: Vector2i, caster: Actor, ability: AbilityDef) -> Actor:
	var ids := ctx.actors.keys()
	ids.sort()
	for id in ids:
		var a: Actor = ctx.actors[id]
		if a.tile() == tile and affects(caster, ability, a):
			return a
	return null
