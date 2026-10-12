class_name AbilityResolver
extends RefCounted
## Validates and resolves one ability use on the host. Whether the caster
## actually knows the ability (equipped item or mastered) is checked by the
## caller. Results are returned as plain-data events for replication and UI.
##
## Event types: cast, miss, whiff, damage, heal, mana, taunt, buff, resurrect, dash, death.
## LINE abilities with a projectile speed don't hit here: cast() returns the
## Projectile for WorldSim to fly, and WorldSim calls apply_effects() on impact.

enum Result {
	OK,
	CASTER_DEAD,
	INVALID_TARGET,
	OUT_OF_RANGE,
	NO_LINE_OF_SIGHT,
	NOT_ENOUGH_MANA,
	ON_COOLDOWN,
}


static func validate(ctx: CombatContext, caster: Actor, ability: AbilityDef, target: Actor) -> Result:
	if not caster.alive:
		return Result.CASTER_DEAD
	if ability.shape != AbilityDef.Shape.TARGETED:
		return _check_cost(ctx, caster, ability) # aimed by facing: no target to check
	if ability.target == AbilityDef.TargetType.SELF:
		target = caster
	if not _is_valid_target(caster, ability, target):
		return Result.INVALID_TARGET
	if target != caster:
		var dist := GridModel.distance(caster.tile(), target.tile())
		if dist < ability.min_range or dist > ability.max_range:
			return Result.OUT_OF_RANGE
		if ability.requires_line_of_sight and dist > 1 \
				and not LineOfSight.has_los(ctx.grid, caster.tile(), target.tile(), ctx.rules.los_height_tolerance):
			return Result.NO_LINE_OF_SIGHT
	return _check_cost(ctx, caster, ability)


static func _check_cost(ctx: CombatContext, caster: Actor, ability: AbilityDef) -> Result:
	if caster.mana + Cooldowns.EPSILON < ability.mana_cost:
		return Result.NOT_ENOUGH_MANA
	if not caster.cooldowns.can_use(ability, ctx.now):
		return Result.ON_COOLDOWN
	return Result.OK


## Validates, then spends mana, starts cooldowns and applies every effect.
## Returns {"result": Result, "events": Array[Dictionary], "projectile": Projectile or null}.
static func cast(ctx: CombatContext, caster: Actor, ability: AbilityDef, target: Actor) -> Dictionary:
	var result := validate(ctx, caster, ability, target)
	if result != Result.OK:
		return {"result": result, "events": [], "projectile": null}
	caster.mana -= ability.mana_cost
	caster.cooldowns.trigger(ability, ctx.now, ctx.rules.gcd_seconds)
	var events: Array[Dictionary] = []
	var projectile: Projectile = null
	match ability.shape:
		AbilityDef.Shape.TARGETED:
			if ability.target == AbilityDef.TargetType.SELF:
				target = caster
			events.append({"type": "cast", "source": caster.id, "target": target.id, "ability": ability.id})
			apply_effects(ctx, caster, ability, target, events)
		AbilityDef.Shape.FRONT:
			var victim := AbilityShapes.front_victim(ctx, caster, ability)
			events.append({"type": "cast", "source": caster.id, "target": victim.id if victim else -1,
					"ability": ability.id})
			if victim != null:
				apply_effects(ctx, caster, ability, victim, events)
			else:
				events.append({"type": "whiff", "source": caster.id, "ability": ability.id,
						"tile": caster.front_tile()})
		AbilityDef.Shape.LINE:
			events.append({"type": "cast", "source": caster.id, "target": -1, "ability": ability.id})
			if ability.projectile_speed > 0.0:
				projectile = Projectile.new()
				projectile.caster_id = caster.id
				projectile.ability = ability
				projectile.origin = caster.tile()
				projectile.dir = caster.facing
				projectile.path = AbilityShapes.line_path(ctx.grid, caster.tile(), caster.facing,
						ability.max_range, ctx.rules.los_height_tolerance)
				projectile.start_time = ctx.now
				projectile.speed = ability.projectile_speed
			else:
				var victim := AbilityShapes.line_first_victim(ctx, caster, ability)
				if victim != null:
					apply_effects(ctx, caster, ability, victim, events)
				else:
					events.append({"type": "whiff", "source": caster.id, "ability": ability.id,
							"tile": caster.front_tile()})
		AbilityDef.Shape.ARC, AbilityDef.Shape.AROUND:
			var victims := AbilityShapes.area_victims(ctx, caster, ability)
			events.append({"type": "cast", "source": caster.id, "target": -1, "ability": ability.id})
			for v in victims:
				apply_effects(ctx, caster, ability, v, events)
			if victims.is_empty():
				events.append({"type": "whiff", "source": caster.id, "ability": ability.id,
						"tile": caster.front_tile()})
	return {"result": Result.OK, "events": events, "projectile": projectile}


## Applies every effect of `ability` from `caster` to `target` (also used for
## projectile impacts).
static func apply_effects(ctx: CombatContext, caster: Actor, ability: AbilityDef, target: Actor,
		events: Array[Dictionary]) -> void:
	for effect in ability.effects:
		_apply_effect(ctx, caster, ability, target, effect, events)


static func _is_valid_target(caster: Actor, ability: AbilityDef, target: Actor) -> bool:
	if target == null:
		return false
	match ability.target:
		AbilityDef.TargetType.SELF:
			return true
		AbilityDef.TargetType.ENEMY:
			return target.alive and caster.is_hostile_to(target) and not target.evading
		AbilityDef.TargetType.ALLY:
			return target.alive and caster.is_ally_of(target)
		AbilityDef.TargetType.DEAD_ALLY:
			return not target.alive and caster.is_ally_of(target)
	return false


static func _apply_effect(ctx: CombatContext, caster: Actor, ability: AbilityDef, target: Actor,
		effect: AbilityEffect, events: Array[Dictionary]) -> void:
	var rules := ctx.rules
	var caster_stats := caster.current_stats(ctx.now)
	match effect.kind:
		AbilityEffect.Kind.DAMAGE:
			if not target.alive:
				return
			var target_stats := target.current_stats(ctx.now)
			var flank := CombatMath.Flank.FRONT
			if ability.is_melee():
				flank = CombatMath.flank(caster.tile(), target.tile(), target.facing)
			# Milestone 3 targeting has no hit roll: you dodge by moving.
			var sure_hit := ability.targeting != AbilityDef.TargetingMode.LEGACY \
					or (flank == CombatMath.Flank.BEHIND and rules.behind_never_misses)
			if not sure_hit and ctx.rng.randf() >= CombatMath.hit_chance(caster_stats.accuracy, target_stats.evasion, rules):
				events.append({"type": "miss", "source": caster.id, "target": target.id, "ability": ability.id})
				return
			var raw := AbilityPower.amount(caster, ability, effect, ctx.now, rules)
			raw *= CombatMath.flank_multiplier(flank, rules)
			raw *= CombatMath.high_ground_multiplier(
					ctx.grid.height_advantage(caster.tile(), target.tile()), ability.ranged, rules)
			var crit := _roll_crit(ctx, effect, caster_stats)
			if crit:
				raw *= CombatMath.crit_multiplier(caster_stats.crit_dmg, rules)
			var def := CombatMath.defense_for(effect.damage_type, target_stats, rules)
			var dmg := minf(CombatMath.final_damage(raw, def.x, def.y, rules), target.hp)
			target.hp -= dmg
			events.append({"type": "damage", "source": caster.id, "target": target.id,
					"ability": ability.id, "amount": dmg, "crit": crit,
					"flank": ["", "side", "behind"][flank]})
			if target.threat != null:
				target.threat.add(caster.id, dmg * effect.threat_multiplier)
			if target.hp <= 0.0:
				target.die()
				events.append({"type": "death", "source": caster.id, "target": target.id})

		AbilityEffect.Kind.HEAL:
			if not target.alive:
				return
			var max_hp := target.current_stats(ctx.now).hp
			var amount := AbilityPower.amount(caster, ability, effect, ctx.now, rules) \
					+ effect.percent_of_max * max_hp
			var crit := _roll_crit(ctx, effect, caster_stats)
			if crit:
				amount *= CombatMath.crit_multiplier(caster_stats.crit_dmg, rules)
			var healed := clampf(roundf(amount), 0.0, maxf(max_hp - target.hp, 0.0))
			target.hp += healed
			events.append({"type": "heal", "source": caster.id, "target": target.id,
					"ability": ability.id, "amount": healed, "crit": crit})
			_share_support_threat(ctx, caster, target, healed * rules.heal_threat_multiplier * effect.threat_multiplier)

		AbilityEffect.Kind.RESTORE_MANA:
			if not target.alive:
				return
			var max_mana := target.current_stats(ctx.now).mana
			var amount := AbilityPower.amount(caster, ability, effect, ctx.now, rules) \
					+ effect.percent_of_max * max_mana
			var restored := clampf(roundf(amount), 0.0, maxf(max_mana - target.mana, 0.0))
			target.mana += restored
			events.append({"type": "mana", "source": caster.id, "target": target.id,
					"ability": ability.id, "amount": restored})

		AbilityEffect.Kind.TAUNT:
			if target.threat != null:
				target.threat.taunt(caster.id, rules.taunt_lead_percent)
				events.append({"type": "taunt", "source": caster.id, "target": target.id, "ability": ability.id})

		AbilityEffect.Kind.RESURRECT:
			if target.alive:
				return
			var stats := target.current_stats(ctx.now)
			target.alive = true
			target.hp = maxf(roundf(stats.hp * rules.resurrect_fraction), 1.0)
			target.mana = roundf(stats.mana * rules.resurrect_fraction)
			events.append({"type": "resurrect", "source": caster.id, "target": target.id, "ability": ability.id})

		AbilityEffect.Kind.BUFF:
			if effect.buff == null or not target.alive:
				return
			target.buffs.apply(effect.buff, ctx.now)
			events.append({"type": "buff", "source": caster.id, "target": target.id,
					"ability": ability.id, "buff": effect.buff.id})
			if caster.is_hostile_to(target):
				if target.threat != null:
					target.threat.add(caster.id, 0.0) # a debuff pulls the enemy onto you
			else:
				_share_support_threat(ctx, caster, target, 0.0)

		AbilityEffect.Kind.HEAL_OVER_TIME:
			if effect.buff == null or not target.alive:
				return
			var total := AbilityPower.amount(caster, ability, effect, ctx.now, rules)
			var ticks := maxf(floorf(effect.buff.duration_seconds / maxf(effect.buff.tick_seconds, 0.05)), 1.0)
			target.buffs.apply(effect.buff, ctx.now, total / ticks, caster.id)
			events.append({"type": "buff", "source": caster.id, "target": target.id,
					"ability": ability.id, "buff": effect.buff.id})
			_share_support_threat(ctx, caster, target, total * rules.heal_threat_multiplier * effect.threat_multiplier)

		AbilityEffect.Kind.DASH:
			if not caster.alive:
				return
			var from := caster.tile()
			var to := from
			var jump := StatCalc.jump_levels(caster_stats)
			for k in int(effect.base_amount):
				var next := to + caster.facing
				if not ctx.grid.can_step(to, next, jump) or _occupied(ctx, next, caster):
					break
				to = next
			if to != from:
				caster.move.place(from)
				caster.move.begin(to, ctx.now, 0.12)
			events.append({"type": "dash", "source": caster.id, "target": caster.id,
					"ability": ability.id, "from": from, "to": to})


static func _occupied(ctx: CombatContext, tile: Vector2i, ignore: Actor) -> bool:
	for id in ctx.actors:
		var a: Actor = ctx.actors[id]
		if a != ignore and a.alive and a.tile() == tile:
			return true
	return false


static func _roll_crit(ctx: CombatContext, effect: AbilityEffect, caster_stats: StatBlock) -> bool:
	return effect.can_crit and ctx.rng.randf() < CombatMath.crit_chance(caster_stats.crit_rate)


## Healing or buffing someone puts the caster on the threat table of every enemy
## fighting that target, splitting `total_threat` evenly between them.
static func _share_support_threat(ctx: CombatContext, caster: Actor, target: Actor, total_threat: float) -> void:
	var enemies := ctx.enemies_fighting(target.id)
	if enemies.is_empty():
		return
	var share := total_threat / enemies.size()
	for enemy in enemies:
		enemy.threat.add(caster.id, share)
