class_name AimPreview
extends RefCounted
## What an aimed ability (Milestone 3 SKILLSHOT / GROUND, plus SELF and TARGETED)
## would affect, worked out on the client's copy of the world for the aiming
## highlight. Mirrors CastResolver; the host still decides what really happens.


## Whether the ability is aimed at a point (hold the key, aim with the mouse).
static func is_aimed(ability: AbilityDef) -> bool:
	return ability.targeting in [AbilityDef.TargetingMode.SKILLSHOT, AbilityDef.TargetingMode.GROUND]


## Where to aim when the mouse isn't used: the targeted enemy, else straight ahead
## at full range.
static func default_aim(hero: Actor, ability: AbilityDef, target: Actor) -> Vector2:
	if target != null and target.alive and hero.is_hostile_to(target):
		return Vector2(target.tile())
	return Vector2(hero.tile() + hero.facing * maxi(ability.max_range, 1))


## {"tiles": Array[Vector2i] affected, "result": AbilityResolver.Result of the
## host's checks (OK, OUT_OF_RANGE, ON_COOLDOWN…)}.
static func preview(grid: GridModel, rules: CombatRules, actors: Array, hero: Actor, ability: AbilityDef,
		aim: Vector2, target: Actor, now: float) -> Dictionary:
	var ctx := CombatContext.new(grid, rules, null)
	ctx.now = now
	for a in actors:
		ctx.add_actor(a)
	var on: Actor = target
	if ability.targeting == AbilityDef.TargetingMode.SELF or ability.target == AbilityDef.TargetType.SELF:
		on = hero
	var result := CastResolver.validate(ctx, hero, ability, on, aim if is_aimed(ability) else null)
	return {"tiles": _tiles(ctx, hero, ability, aim, on), "result": result}


static func _tiles(ctx: CombatContext, hero: Actor, ability: AbilityDef, aim: Vector2, target: Actor) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	match ability.targeting:
		AbilityDef.TargetingMode.TARGETED:
			if target != null:
				out.append(target.tile())
		AbilityDef.TargetingMode.SELF:
			out = CastResolver.area_tiles(ctx.grid, hero.tile(), ability.area_radius, ability.area_diamond)
		AbilityDef.TargetingMode.SKILLSHOT:
			if ability.arc_seconds > 0.0:
				out.append(CastResolver.lob_tile(hero.tile(), aim, ability.max_range))
			else:
				out = CastResolver.skillshot_tiles(ctx, hero, ability, aim)
				if not ability.pierce and ability.line_shape == AbilityDef.LineShape.LINE:
					out = _until_first_enemy(ctx, hero, out)
		AbilityDef.TargetingMode.GROUND:
			var tile := Vector2i(roundi(aim.x), roundi(aim.y))
			out = _ground_tiles(ctx, hero, ability, tile)
	return out


## A projectile that doesn't pierce stops at the first enemy in its path.
static func _until_first_enemy(ctx: CombatContext, hero: Actor, line: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t in line:
		out.append(t)
		for id in ctx.actors:
			var a: Actor = ctx.actors[id]
			if a.alive and a.covers(t) and hero.is_hostile_to(a):
				return out
	return out


## A ground ability's area, or what its movement and terrain effects would cover
## (Flame Dash's trail, Earth Wall's line).
static func _ground_tiles(ctx: CombatContext, hero: Actor, ability: AbilityDef, tile: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for e in ability.effects:
		if e.kind == AbilityEffect.Kind.DASH_TO and e.applies == AbilityEffect.Applies.CASTER:
			var blocked := {}
			for id in ctx.actors:
				var a: Actor = ctx.actors[id]
				if a != hero and a.alive:
					for t in a.tiles():
						blocked[t] = true
			var limit := mini(int(e.base_amount), TileGeometry.distance(hero.tile(), tile))
			var r := TileGeometry.push_path(ctx.grid, hero.tile(), TileGeometry.snap8(Vector2(tile - hero.tile())),
					limit, StatCalc.jump_levels(hero.current_stats(ctx.now)), blocked)
			out.assign(r.path)
			return out
		if e.kind == AbilityEffect.Kind.TERRAIN and e.wall_line:
			var facing := hero.facing
			ctx.cast_aim = tile
			CastResolver._face(hero, Vector2(tile))
			out.assign(AbilityResolver._wall_tiles(ctx, hero, ability, e))
			hero.facing = facing
			return out
	return CastResolver.area_tiles(ctx.grid, tile, ability.area_radius, ability.area_diamond)
