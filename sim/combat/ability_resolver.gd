class_name AbilityResolver
extends RefCounted
## Validates and resolves one ability use on the host. Whether the caster
## actually knows the ability (equipped item or mastered) is checked by the
## caller. Results are returned as plain-data events for replication and UI.
##
## Event types: cast, miss, damage, heal, taunt, buff, resurrect, death.

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
	if caster.mana + Cooldowns.EPSILON < ability.mana_cost:
		return Result.NOT_ENOUGH_MANA
	if not caster.cooldowns.can_use(ability, ctx.now):
		return Result.ON_COOLDOWN
	return Result.OK


## Validates, then spends mana, starts cooldowns and applies every effect.
## Returns {"result": Result, "events": Array[Dictionary]}.
static func cast(ctx: CombatContext, caster: Actor, ability: AbilityDef, target: Actor) -> Dictionary:
	var result := validate(ctx, caster, ability, target)
	if result != Result.OK:
		return {"result": result, "events": []}
	if ability.target == AbilityDef.TargetType.SELF:
		target = caster

	caster.mana -= ability.mana_cost
	caster.cooldowns.trigger(ability, ctx.now, ctx.rules.gcd_seconds)
	var events: Array[Dictionary] = [
		{"type": "cast", "source": caster.id, "target": target.id, "ability": ability.id},
	]
	for effect in ability.effects:
		_apply_effect(ctx, caster, ability, target, effect, events)
	return {"result": Result.OK, "events": events}


static func _is_valid_target(caster: Actor, ability: AbilityDef, target: Actor) -> bool:
	if target == null:
		return false
	match ability.target:
		AbilityDef.TargetType.SELF:
			return true
		AbilityDef.TargetType.ENEMY:
			return target.alive and caster.is_hostile_to(target)
		AbilityDef.TargetType.ALLY:
			return target.alive and not caster.is_hostile_to(target)
		AbilityDef.TargetType.DEAD_ALLY:
			return not target.alive and not caster.is_hostile_to(target)
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
			if ctx.rng.randf() >= CombatMath.hit_chance(caster_stats.accuracy, target_stats.evasion, rules):
				events.append({"type": "miss", "source": caster.id, "target": target.id, "ability": ability.id})
				return
			var raw := StatCalc.scaled_amount(effect.base_amount, effect.scaling, caster_stats)
			raw *= CombatMath.high_ground_multiplier(
					ctx.grid.height_advantage(caster.tile(), target.tile()), ability.ranged, rules)
			var crit := _roll_crit(ctx, effect, caster_stats)
			if crit:
				raw *= CombatMath.crit_multiplier(caster_stats.crit_dmg, rules)
			var def := CombatMath.defense_for(effect.damage_type, target_stats, rules)
			var dmg := minf(CombatMath.final_damage(raw, def.x, def.y, rules), target.hp)
			target.hp -= dmg
			events.append({"type": "damage", "source": caster.id, "target": target.id,
					"ability": ability.id, "amount": dmg, "crit": crit})
			if target.threat != null:
				target.threat.add(caster.id, dmg * effect.threat_multiplier)
			if target.hp <= 0.0:
				target.die()
				events.append({"type": "death", "source": caster.id, "target": target.id})

		AbilityEffect.Kind.HEAL:
			if not target.alive:
				return
			var amount := StatCalc.scaled_amount(effect.base_amount, effect.scaling, caster_stats)
			var crit := _roll_crit(ctx, effect, caster_stats)
			if crit:
				amount *= CombatMath.crit_multiplier(caster_stats.crit_dmg, rules)
			var max_hp := target.current_stats(ctx.now).hp
			var healed := clampf(roundf(amount), 0.0, maxf(max_hp - target.hp, 0.0))
			target.hp += healed
			events.append({"type": "heal", "source": caster.id, "target": target.id,
					"ability": ability.id, "amount": healed, "crit": crit})
			_share_support_threat(ctx, caster, target, healed * rules.heal_threat_multiplier * effect.threat_multiplier)

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
			_share_support_threat(ctx, caster, target, 0.0)


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
