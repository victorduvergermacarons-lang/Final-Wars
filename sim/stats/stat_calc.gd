class_name StatCalc
extends RefCounted
## Pure stat formulas. No state; safe to call from the sim, UI or tests.


## Effective stats: base + permanent level-up growth + every equipped item's stats.
static func total(base: StatBlock, permanent_growth: StatBlock, equipped: Array[ItemDef]) -> StatBlock:
	var out := StatBlock.new()
	out.add(base)
	out.add(permanent_growth)
	for item in equipped:
		if item != null:
			out.add(item.stats)
	return out


## base + Σ(coefficient × stat). Never negative.
static func scaled_amount(base: float, scaling: Array[AbilityScaling], stats: StatBlock) -> float:
	var amount := base
	for term in scaling:
		if term != null:
			amount += term.coefficient * stats.get_stat(term.stat)
	return maxf(amount, 0.0)


## In-combat step cooldown. Speed shortens it hyperbolically
## (half at `speed_half_point`), never below the configured floor.
static func combat_step_cooldown(speed: float, rules: CombatRules) -> float:
	var s := maxf(speed, 0.0)
	var cd := rules.combat_step_base_seconds * rules.speed_half_point / (rules.speed_half_point + s)
	return maxf(cd, rules.combat_step_min_seconds)


## Height levels climbable in one step.
static func jump_levels(stats: StatBlock) -> int:
	return maxi(floori(stats.jump), 0)
