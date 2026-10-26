class_name Targeting
extends RefCounted
## Picks who an ability is used on, WoW-style. Shared by input and the HUD.
## Self abilities ignore the target; ally abilities fall back to self.


## Returns {"target": actor id or -1, "error": "" or a message for the player}.
static func pick(hero: Hero, ability: AbilityDef, target: Actor) -> Dictionary:
	match ability.targeting:
		AbilityDef.TargetingMode.LEGACY:
			if ability.shape != AbilityDef.Shape.TARGETED:
				return {"target": -1, "error": ""} # aimed by facing
		AbilityDef.TargetingMode.SELF:
			return {"target": hero.id, "error": ""}
		AbilityDef.TargetingMode.SKILLSHOT, AbilityDef.TargetingMode.GROUND:
			# Aimed at a point; a targeted enemy is the default aim.
			var enemy := target != null and target.alive and hero.is_hostile_to(target)
			return {"target": target.id if enemy else -1, "error": ""}
	match ability.target:
		AbilityDef.TargetType.SELF:
			return {"target": hero.id, "error": ""}
		AbilityDef.TargetType.ENEMY:
			if target == null or not hero.is_hostile_to(target) or not target.alive:
				return {"target": -1, "error": "No enemy targeted"}
			return {"target": target.id, "error": ""}
		AbilityDef.TargetType.ALLY:
			var friendly := target != null and hero.is_ally_of(target) and target.alive
			return {"target": target.id if friendly else hero.id, "error": ""}
		AbilityDef.TargetType.DEAD_ALLY:
			if target == null or not hero.is_ally_of(target) or target.alive:
				return {"target": -1, "error": "Target a fallen ally"}
			return {"target": target.id, "error": ""}
	return {"target": -1, "error": "Invalid target"}


enum Usability {
	READY,
	UNAVAILABLE, ## Not known right now (item unequipped, not mastered).
	COOLDOWN,
	NO_MANA,
	OUT_OF_RANGE, ## Also: no line of sight.
	NO_TARGET,
	DEAD,
}


## Client-side preview of whether pressing the ability would work, for slot tinting.
## Uses the same validation as the host on the client's copy of the world.
## `actors` (all actors in the world) is needed for FRONT/LINE abilities: red
## means nothing would be hit where the hero is facing.
static func usability(hero: Hero, ability: AbilityDef, target: Actor, grid: GridModel,
		rules: CombatRules, now: float, actors: Array = []) -> Usability:
	if not hero.alive:
		return Usability.DEAD
	if hero.find_ability(ability.id) == null:
		return Usability.UNAVAILABLE
	var picked := pick(hero, ability, target)
	if picked.error != "":
		return Usability.NO_TARGET
	var ctx := CombatContext.new(grid, rules, null)
	ctx.now = now
	if ability.targeting != AbilityDef.TargetingMode.LEGACY:
		return _m3_usability(grid, rules, hero, ability, target, now, actors)
	if ability.shape != AbilityDef.Shape.TARGETED:
		return _shape_usability(ctx, hero, ability, actors)
	var chosen: Actor = hero if picked.target == hero.id else target
	match AbilityResolver.validate(ctx, hero, ability, chosen):
		AbilityResolver.Result.OK:
			return Usability.READY
		AbilityResolver.Result.ON_COOLDOWN:
			return Usability.COOLDOWN
		AbilityResolver.Result.NOT_ENOUGH_MANA:
			return Usability.NO_MANA
		AbilityResolver.Result.OUT_OF_RANGE, AbilityResolver.Result.NO_LINE_OF_SIGHT:
			return Usability.OUT_OF_RANGE
		_:
			return Usability.NO_TARGET


static func _shape_usability(ctx: CombatContext, hero: Hero, ability: AbilityDef, actors: Array) -> Usability:
	for a in actors:
		ctx.add_actor(a)
	match AbilityResolver.validate(ctx, hero, ability, null):
		AbilityResolver.Result.ON_COOLDOWN:
			return Usability.COOLDOWN
		AbilityResolver.Result.NOT_ENOUGH_MANA:
			return Usability.NO_MANA
	var hits := false
	match ability.shape:
		AbilityDef.Shape.FRONT:
			hits = AbilityShapes.front_victim(ctx, hero, ability) != null
		AbilityDef.Shape.LINE:
			hits = AbilityShapes.line_first_victim(ctx, hero, ability) != null
		_:
			hits = not AbilityShapes.area_victims(ctx, hero, ability).is_empty()
	return Usability.READY if hits else Usability.OUT_OF_RANGE


## Milestone 3 targeting: the host's own checks (CastResolver.validate). Aimed
## abilities are judged at their default aim (the targeted enemy, else ahead).
static func _m3_usability(grid: GridModel, rules: CombatRules, hero: Hero, ability: AbilityDef, target: Actor,
		now: float, actors: Array) -> Usability:
	var p := AimPreview.preview(grid, rules, actors, hero, ability, AimPreview.default_aim(hero, ability, target),
			target, now)
	match p.result:
		AbilityResolver.Result.OK:
			return Usability.READY
		AbilityResolver.Result.ON_COOLDOWN, AbilityResolver.Result.BUSY:
			return Usability.COOLDOWN
		AbilityResolver.Result.NOT_ENOUGH_MANA:
			return Usability.NO_MANA
		AbilityResolver.Result.OUT_OF_RANGE, AbilityResolver.Result.NO_LINE_OF_SIGHT:
			# Aimed abilities can always be aimed elsewhere with the mouse.
			return Usability.READY if AimPreview.is_aimed(ability) else Usability.OUT_OF_RANGE
		_:
			return Usability.NO_TARGET
