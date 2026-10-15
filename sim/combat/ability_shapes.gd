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
		return caster.is_ally_of(actor)
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


## Tiles an ARC ability covers: the tile in front and the two beside it.
static func arc_tiles(caster: Actor) -> Array[Vector2i]:
	var f := caster.front_tile()
	var side := Vector2i(caster.facing.y, -caster.facing.x)
	return [f, f + side, f - side]


## Tiles an AROUND ability covers: everything within `radius` of `center`.
static func around_tiles(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if absi(dx) + absi(dy) <= radius:
				out.append(center + Vector2i(dx, dy))
	return out


## Everyone an ARC or AROUND ability would affect, in id order.
static func area_victims(ctx: CombatContext, caster: Actor, ability: AbilityDef) -> Array[Actor]:
	var tiles: Array[Vector2i] = arc_tiles(caster) if ability.shape == AbilityDef.Shape.ARC \
			else around_tiles(caster.tile(), ability.max_range)
	var out: Array[Actor] = []
	var ids := ctx.actors.keys()
	ids.sort()
	for id in ids:
		var a: Actor = ctx.actors[id]
		if not tiles.has(a.tile()):
			continue
		var hits := affects(caster, ability, a) or (a == caster and a.alive \
				and ability.target == AbilityDef.TargetType.ALLY and ability.shape == AbilityDef.Shape.AROUND)
		if not hits:
			continue
		if ability.max_height_difference >= 0 \
				and absi(ctx.grid.height_at(a.tile()) - ctx.grid.height_at(caster.tile())) > ability.max_height_difference:
			continue
		out.append(a)
	return out


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


## Whether an affected actor standing on `tile` would be reached, given the
## caster's position and facing. Used by enemy AI with *perceived* positions.
static func reaches_tile(ctx: CombatContext, caster: Actor, ability: AbilityDef, tile: Vector2i) -> bool:
	if ability.targeting != AbilityDef.TargetingMode.LEGACY:
		# Milestone 3 targeting: square distance; line of sight except for ground.
		var d := TileGeometry.range_distance(caster.tile(), tile)
		if d < ability.min_range or d > ability.max_range:
			return false
		return ability.targeting == AbilityDef.TargetingMode.GROUND or not ability.requires_line_of_sight \
				or d <= 1 or LineOfSight.has_los(ctx.grid, caster.tile(), tile, ctx.rules.los_height_tolerance)
	match ability.shape:
		AbilityDef.Shape.ARC:
			return arc_tiles(caster).has(tile)
		AbilityDef.Shape.AROUND:
			return GridModel.distance(caster.tile(), tile) <= ability.max_range
		AbilityDef.Shape.FRONT:
			for k in range(maxi(ability.min_range, 1), ability.max_range + 1):
				if caster.tile() + caster.facing * k == tile:
					var dh := absi(ctx.grid.height_at(tile) - ctx.grid.height_at(caster.tile()))
					return ability.max_height_difference < 0 or dh <= ability.max_height_difference
			return false
		AbilityDef.Shape.LINE:
			return line_path(ctx.grid, caster.tile(), caster.facing, ability.max_range,
					ctx.rules.los_height_tolerance).has(tile)
	var dist := GridModel.distance(caster.tile(), tile)
	if dist < ability.min_range or dist > ability.max_range:
		return false
	return not ability.requires_line_of_sight or dist <= 1 \
			or LineOfSight.has_los(ctx.grid, caster.tile(), tile, ctx.rules.los_height_tolerance)


## Whether `target` stands where `ability` would reach it right now, given the
## caster's position and facing. For TARGETED abilities: range and line of sight.
static func in_reach(ctx: CombatContext, caster: Actor, ability: AbilityDef, target: Actor) -> bool:
	match ability.shape:
		AbilityDef.Shape.FRONT:
			return front_victim(ctx, caster, ability) == target
		AbilityDef.Shape.LINE:
			return line_first_victim(ctx, caster, ability) == target
		AbilityDef.Shape.ARC, AbilityDef.Shape.AROUND:
			return area_victims(ctx, caster, ability).has(target)
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
