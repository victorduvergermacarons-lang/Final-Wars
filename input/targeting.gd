class_name Targeting
extends RefCounted
## Picks who an ability is used on, WoW-style. Shared by input and the HUD.
## Self abilities ignore the target; ally abilities fall back to self.


## Returns {"target": actor id or -1, "error": "" or a message for the player}.
static func pick(hero: Hero, ability: AbilityDef, target: Actor) -> Dictionary:
	if ability.shape != AbilityDef.Shape.TARGETED:
		return {"target": -1, "error": ""} # aimed by facing
	match ability.target:
		AbilityDef.TargetType.SELF:
			return {"target": hero.id, "error": ""}
		AbilityDef.TargetType.ENEMY:
			if target == null or not hero.is_hostile_to(target) or not target.alive:
				return {"target": -1, "error": "No enemy targeted"}
			return {"target": target.id, "error": ""}
		AbilityDef.TargetType.ALLY:
			var friendly := target != null and not hero.is_hostile_to(target) and target.alive
			return {"target": target.id if friendly else hero.id, "error": ""}
		AbilityDef.TargetType.DEAD_ALLY:
			if target == null or hero.is_hostile_to(target) or target.alive:
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
	var victim := AbilityShapes.front_victim(ctx, hero, ability) if ability.shape == AbilityDef.Shape.FRONT \
			else AbilityShapes.line_first_victim(ctx, hero, ability)
	return Usability.READY if victim != null else Usability.OUT_OF_RANGE
