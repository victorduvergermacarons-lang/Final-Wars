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
	STUNNED,
	SILENCED,
	BUSY, ## Already casting, winding up or channelling.
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


## Crowd control, mana and cooldowns (GCD optional: a finishing cast already holds it).
static func _check_cost(ctx: CombatContext, caster: Actor, ability: AbilityDef, check_gcd: bool = true) -> Result:
	if caster.buffs.is_stunned(ctx.now):
		return Result.STUNNED
	if ability.is_spell() and caster.buffs.is_silenced(ctx.now):
		return Result.SILENCED
	if caster.mana + Cooldowns.EPSILON < ability.mana_cost:
		return Result.NOT_ENOUGH_MANA
	if not caster.cooldowns.can_use(ability, ctx.now, max_charges(caster, ability, ctx.now), check_gcd):
		return Result.ON_COOLDOWN
	return Result.OK


## Spends mana and starts the cooldown (haste shortens it), and the GCD if asked.
static func pay(ctx: CombatContext, caster: Actor, ability: AbilityDef, with_gcd: bool = true) -> void:
	caster.mana -= ability.mana_cost
	caster.cooldowns.trigger(ability, ctx.now, ctx.rules.gcd_seconds if with_gcd else 0.0,
			caster.buffs.cooldown_multiplier(ctx.now), max_charges(caster, ability, ctx.now))


## How many charges the ability holds for this caster (1 = no charges).
static func max_charges(caster: Actor, ability: AbilityDef, now: float) -> int:
	if ability.charges_base <= 0:
		return 1
	return AbilityPower.charges(caster, ability, ability.charges_base, ability.mastery_per_charge, now)


## Validates, then spends mana, starts cooldowns and applies every effect.
## Returns {"result": Result, "events": Array[Dictionary], "projectile": Projectile or null}.
static func cast(ctx: CombatContext, caster: Actor, ability: AbilityDef, target: Actor) -> Dictionary:
	var result := validate(ctx, caster, ability, target)
	if result != Result.OK:
		return {"result": result, "events": [], "projectile": null}
	pay(ctx, caster, ability)
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
		if effect.applies == AbilityEffect.Applies.TARGETS:
			_apply_effect(ctx, caster, ability, target, effect, events)


## The ability's CASTER effects (dashes, leaps, self buffs alongside an attack).
static func apply_caster_effects(ctx: CombatContext, caster: Actor, ability: AbilityDef, events: Array[Dictionary]) -> void:
	for effect in ability.effects:
		if effect.applies == AbilityEffect.Applies.CASTER:
			_apply_effect(ctx, caster, ability, caster, effect, events)


## The ability's AREA effects (terrain, ground zones) on `tiles`.
static func apply_area_effects(ctx: CombatContext, caster: Actor, ability: AbilityDef, tiles: Array,
		events: Array[Dictionary]) -> void:
	for effect in ability.effects:
		if effect.applies != AbilityEffect.Applies.AREA:
			continue
		var duration := AbilityPower.duration(caster, ability, effect.duration_seconds, ctx.now, ctx.rules)
		match effect.kind:
			AbilityEffect.Kind.TERRAIN:
				var area: Array = tiles
				if effect.wall_line:
					area = _wall_tiles(ctx, caster, ability, effect)
				var levels := int(effect.base_amount) + _extra(caster, ability, effect, ctx.now)
				ctx.requests.append({"type": "terrain", "source": caster.id, "tiles": area, "levels": levels,
						"blocks": effect.blocks_movement, "until": ctx.now + duration, "ability": ability.id})
			AbilityEffect.Kind.ZONE:
				ctx.requests.append({"type": "zone", "source": caster.id, "tiles": tiles, "ability": ability,
						"zone_ability": effect.zone_ability, "tick": maxf(effect.zone_tick_seconds, 0.1),
						"until": ctx.now + duration, "bonus": ctx.damage_bonus})


## Whether the ability does anything to the units it reaches (else no "whiff").
static func has_target_effects(ability: AbilityDef) -> bool:
	return ability.effects.any(func(e): return e.applies == AbilityEffect.Applies.TARGETS)


## +1 per `mastery_per_extra` tree Mastery.
static func _extra(caster: Actor, ability: AbilityDef, effect: AbilityEffect, now: float) -> int:
	if effect.mastery_per_extra <= 0.0 or not ability.is_tree_ability():
		return 0
	var extra := floori(Mastery.total(caster, ability.tree, now) / effect.mastery_per_extra)
	return mini(extra, effect.max_extra) if effect.max_extra > 0 else extra


## A wall across the caster's facing, centred on the aimed tile, skipping occupied tiles.
static func _wall_tiles(ctx: CombatContext, caster: Actor, ability: AbilityDef, effect: AbilityEffect) -> Array:
	var length := 3 + _extra(caster, ability, effect, ctx.now)
	var across := Vector2i(caster.facing.y, caster.facing.x)
	var out := []
	for k in range(-(length - 1) / 2, length / 2 + 1):
		var t := ctx.cast_aim + across * k
		if ctx.grid.in_bounds(t) and not _occupied(ctx, t, null):
			out.append(t)
	return out


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
			# Milestone 3 targeting has no hit roll (you dodge by moving), except enemy
			# melee, which still rolls Accuracy against Evasion.
			var rolls := ability.targeting == AbilityDef.TargetingMode.LEGACY \
					or (caster is Enemy and ability.is_melee())
			var sure_hit := not rolls or (flank == CombatMath.Flank.BEHIND and rules.behind_never_misses)
			if not sure_hit and ctx.rng.randf() >= CombatMath.hit_chance(caster_stats.accuracy, target_stats.evasion, rules):
				events.append({"type": "miss", "source": caster.id, "target": target.id, "ability": ability.id})
				return
			var raw := AbilityPower.amount(caster, ability, effect, ctx.now, rules) * ctx.damage_bonus
			raw *= CombatMath.flank_multiplier(flank, rules)
			raw *= CombatMath.high_ground_multiplier(
					ctx.grid.height_advantage(caster.tile(), target.tile()), ability.ranged, rules)
			var crit := _roll_crit(ctx, effect, caster_stats)
			if crit:
				raw *= CombatMath.crit_multiplier(caster_stats.crit_dmg, rules)
			var def := CombatMath.defense_for(effect.damage_type, target_stats, rules)
			var dealt := CombatMath.final_damage(raw, def.x, def.y, rules)
			var before := target.hp
			deal_damage(ctx, caster, target, ability.id, dealt, crit, events, ["", "side", "behind"][flank],
					effect.threat_multiplier, ability.is_melee())
			if effect.lifesteal > 0.0 and caster.alive and before > target.hp:
				var max_hp := caster.current_stats(ctx.now).hp
				var healed := clampf(roundf((before - target.hp) * effect.lifesteal), 0.0, maxf(max_hp - caster.hp, 0.0))
				caster.hp += healed
				events.append({"type": "heal", "source": caster.id, "target": caster.id, "ability": ability.id,
						"amount": healed, "crit": false})

		AbilityEffect.Kind.KNOCKBACK, AbilityEffect.Kind.PULL:
			if not target.alive or target == caster:
				return
			var pull := effect.kind == AbilityEffect.Kind.PULL
			var dir := TileGeometry.snap8(Vector2((caster.tile() - target.tile()) if pull else (target.tile() - caster.tile())))
			if effect.push_along_cast and ctx.cast_dir != Vector2i.ZERO:
				dir = ctx.cast_dir
			var tiles := Weight.adjust(int(effect.base_amount) + _extra(caster, ability, effect, ctx.now), target.weight)
			if pull:
				tiles = mini(tiles, TileGeometry.distance(caster.tile(), target.tile()) - 1)
			var r := move_unit(ctx, target, dir, tiles, 0.15)
			events.append({"type": "pushed" if not pull else "pulled", "source": caster.id, "target": target.id,
					"ability": ability.id, "from": r.from, "to": r.end, "stopped_by": r.stopped_by})
			if effect.impact_damage > 0.0 and r.stopped_by != "" and target.alive:
				var dmg := CombatMath.final_damage(effect.impact_damage * AbilityPower.mastery_multiplier(caster, ability, ctx.now, rules),
						target.current_stats(ctx.now).phys_def, rules.physical_defense_k, rules)
				deal_damage(ctx, caster, target, ability.id, dmg, false, events)

		AbilityEffect.Kind.DASH_TO:
			if not caster.alive:
				return
			var dir := ctx.cast_dir
			if dir == Vector2i.ZERO:
				dir = TileGeometry.snap8(Vector2(caster.facing))
			var limit := mini(int(effect.base_amount) + _extra(caster, ability, effect, ctx.now),
					TileGeometry.distance(caster.tile(), ctx.cast_aim))
			var r := move_unit(ctx, caster, dir, limit, 0.12)
			ctx.cast_tiles = r.path
			events.append({"type": "dash", "source": caster.id, "target": caster.id, "ability": ability.id,
					"from": r.from, "to": r.end})

		AbilityEffect.Kind.LEAP, AbilityEffect.Kind.BLINK:
			var to := ctx.cast_aim
			if not caster.alive or not ctx.grid.in_bounds(to) or not ctx.grid.is_walkable(to) or _occupied(ctx, to, caster):
				events.append({"type": "whiff", "source": caster.id, "ability": ability.id, "tile": to})
				return
			var from := caster.tile()
			caster.casting = {}
			caster.move.place(from)
			caster.move.begin(to, ctx.now, 0.35 if effect.kind == AbilityEffect.Kind.LEAP else 0.0)
			if effect.kind == AbilityEffect.Kind.BLINK:
				caster.move.place(to)
			events.append({"type": "dash", "source": caster.id, "target": caster.id, "ability": ability.id,
					"from": from, "to": to})

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

		AbilityEffect.Kind.SHIELD:
			if effect.buff == null or not target.alive:
				return
			var size := AbilityPower.amount(caster, ability, effect, ctx.now, rules)
			target.buffs.apply(effect.buff, ctx.now, 0.0, caster.id,
					{"duration": AbilityPower.duration(caster, ability, effect.buff.duration_seconds, ctx.now, rules),
					"shield": size})
			events.append({"type": "shield", "source": caster.id, "target": target.id,
					"ability": ability.id, "buff": effect.buff.id, "amount": size})
			_share_support_threat(ctx, caster, target, 0.0)

		AbilityEffect.Kind.INTERRUPT:
			if target.alive and not target.casting.is_empty():
				var what: StringName = target.casting.ability.id
				target.casting = {}
				events.append({"type": "interrupt", "source": caster.id, "target": target.id,
						"ability": ability.id, "interrupted": what})

		AbilityEffect.Kind.BUFF:
			if effect.buff == null or not target.alive:
				return
			target.buffs.apply(effect.buff, ctx.now, 0.0, -1,
					{"duration": AbilityPower.duration(caster, ability, effect.buff.duration_seconds, ctx.now, rules)})
			if effect.buff.stuns or effect.buff.sleeps:
				target.casting = {} # can't keep casting while stunned
			events.append({"type": "buff", "source": caster.id, "target": target.id,
					"ability": ability.id, "buff": effect.buff.id})
			if caster.is_hostile_to(target):
				if target.threat != null:
					target.threat.add(caster.id, 0.0) # a debuff pulls the enemy onto you
			else:
				_share_support_threat(ctx, caster, target, 0.0)

		AbilityEffect.Kind.HEAL_OVER_TIME, AbilityEffect.Kind.DAMAGE_OVER_TIME:
			if effect.buff == null or not target.alive:
				return
			var total := AbilityPower.amount(caster, ability, effect, ctx.now, rules)
			var harmful := effect.kind == AbilityEffect.Kind.DAMAGE_OVER_TIME
			if harmful:
				total *= ctx.damage_bonus
			var duration := AbilityPower.duration(caster, ability, effect.buff.duration_seconds, ctx.now, rules)
			var ticks := maxf(floorf(duration / maxf(effect.buff.tick_seconds, 0.05)), 1.0)
			target.buffs.apply(effect.buff, ctx.now, total / ticks, caster.id,
					{"duration": duration, "tick_damage": harmful, "damage_type": effect.damage_type})
			if harmful:
				events.append({"type": "buff", "source": caster.id, "target": target.id,
						"ability": ability.id, "buff": effect.buff.id})
				if target.threat != null:
					target.threat.add(caster.id, 0.0)
				return
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


## Deals already-mitigated damage: target damage-taken multipliers, shields, sleep
## breaking, threat and death. Emits damage (with "absorbed") and death events.
static func deal_damage(ctx: CombatContext, source: Actor, target: Actor, ability_id: StringName, amount: float,
		crit: bool, events: Array[Dictionary], flank: String = "", threat_multiplier: float = 1.0,
		melee: bool = false) -> void:
	if not target.alive:
		return
	# Counters (Parry, Riposte, reflects): only against an attacker.
	if source != null and source != target:
		var counter := target.buffs.counter_for(melee, ctx.now)
		if not counter.is_empty():
			if counter.negate:
				events.append({"type": "parry", "source": source.id, "target": target.id, "ability": ability_id})
			if counter.ability != null:
				ctx.requests.append({"type": "counter", "owner": target.id, "ability": counter.ability, "target": source.id})
			if counter.reflect > 0.0 and source.alive:
				deal_damage(ctx, target, source, &"reflect", roundf(amount * counter.reflect), false, events)
			if counter.negate:
				return
	var taken := maxf(roundf(amount * target.buffs.damage_taken_multiplier(ctx.now)), ctx.rules.min_damage)
	var through := target.buffs.absorb(taken)
	var dmg := minf(through, target.hp)
	target.hp -= dmg
	target.buffs.wake()
	var e := {"type": "damage", "source": source.id if source != null else -1, "target": target.id,
			"ability": ability_id, "amount": dmg, "crit": crit, "flank": flank}
	if taken - through > 0.0:
		e.absorbed = taken - through
	events.append(e)
	if target.threat != null and source != null:
		target.threat.add(source.id, dmg * threat_multiplier)
	if target.hp <= 0.0:
		target.die()
		target.casting = {}
		events.append({"type": "death", "source": source.id if source != null else -1, "target": target.id})


## Slides a unit up to `tiles` along an 8-way `dir` (knockback, pull, dash),
## stopping before walls, water, units and climbs over its Jump. Cancels its cast.
## Returns TileGeometry.push_path's result plus "from".
static func move_unit(ctx: CombatContext, unit: Actor, dir: Vector2i, tiles: int, seconds: float) -> Dictionary:
	var blocked := {}
	for id in ctx.actors:
		var a: Actor = ctx.actors[id]
		if a != unit and a.alive:
			blocked[a.tile()] = true
	var from := unit.tile()
	var r := TileGeometry.push_path(ctx.grid, from, dir, maxi(tiles, 0),
			StatCalc.jump_levels(unit.current_stats(ctx.now)), blocked)
	r.from = from
	if r.end != from:
		unit.casting = {}
		unit.move.place(from)
		unit.move.begin(r.end, ctx.now, seconds * r.path.size())
	return r


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
