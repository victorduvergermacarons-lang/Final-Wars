class_name AbilityPower
extends RefCounted
## The ability power formulas, in one place (CLAUDE.md, Milestone 3 §2). All
## constants live in CombatRules ("Ability power" group):
##
##   amount   = (base + Σ coefficient × stat) × (1 + Mastery × mastery_power_per_point)
##   duration = seconds × (1 + Mastery × mastery_duration_per_point)
##   charges  = base charges + floor(Mastery / Mastery per extra charge)
##
## Mastery is the caster's total Mastery in the ability's tree (gear included; only
## permanent Mastery unlocks tiers). Non-tree abilities have no Mastery term.
## For tree abilities an effect may use the tier default base (base_amount < 0) and
## the spreadsheet's Scales With stats (sheet_scaling) instead of its own scaling.


static func amount(caster: Actor, ability: AbilityDef, effect: AbilityEffect, now: float,
		rules: CombatRules) -> float:
	var stats := caster.current_stats(now)
	var value := effect.base_amount
	if value < 0.0:
		value = tier_base(ability, effect, rules)
	if effect.sheet_scaling and ability.is_tree_ability():
		for term in ability.sheet.get("scales_with", []):
			if term.has("stat") and term.stat != "crit_rate" and term.stat != "crit_dmg":
				value += rules.sheet_stat_coefficient * stats.get(StringName(term.stat))
	else:
		for term in effect.scaling:
			if term != null:
				value += term.coefficient * stats.get_stat(term.stat)
	return maxf(value * mastery_multiplier(caster, ability, now, rules), 0.0)


## 1 + Mastery × mastery_power_per_point (1 for non-tree abilities).
static func mastery_multiplier(caster: Actor, ability: AbilityDef, now: float, rules: CombatRules) -> float:
	if not ability.is_tree_ability():
		return 1.0
	return 1.0 + Mastery.total(caster, ability.tree, now) * rules.mastery_power_per_point


static func duration(caster: Actor, ability: AbilityDef, seconds: float, now: float, rules: CombatRules) -> float:
	if not ability.is_tree_ability():
		return seconds
	return seconds * (1.0 + Mastery.total(caster, ability.tree, now) * rules.mastery_duration_per_point)


## e.g. Flame Dash: 1 charge, +1 per 300 Fire Mastery.
static func charges(caster: Actor, ability: AbilityDef, base_charges: int, mastery_per_charge: float,
		now: float) -> int:
	if mastery_per_charge <= 0.0 or not ability.is_tree_ability():
		return base_charges
	return base_charges + floori(Mastery.total(caster, ability.tree, now) / mastery_per_charge)


## Default base amount for a tree ability's effect, by tier (decision M3-1).
static func tier_base(ability: AbilityDef, effect: AbilityEffect, rules: CombatRules) -> float:
	var t := clampi(ability.tier, 1, 5) - 1
	match effect.kind:
		AbilityEffect.Kind.DAMAGE:
			return rules.tier_damage_base[t]
		AbilityEffect.Kind.HEAL, AbilityEffect.Kind.HEAL_OVER_TIME:
			return rules.tier_heal_base[t]
	return 0.0
