class_name CombatMath
extends RefCounted
## Pure combat formulas. Constants come from CombatRules.


## Chance to hit in 0..1.
static func hit_chance(accuracy: float, evasion: float, rules: CombatRules) -> float:
	var pct := rules.base_hit_percent + (accuracy - evasion) * rules.hit_percent_per_point
	return clampf(pct, rules.min_hit_percent, rules.max_hit_percent) / 100.0


## Chance to crit in 0..1 (Crit Rate is a percent).
static func crit_chance(crit_rate: float) -> float:
	return clampf(crit_rate / 100.0, 0.0, 1.0)


## Damage/heal multiplier on a crit: 1 + (base bonus + Crit Damage) / 100.
static func crit_multiplier(crit_damage: float, rules: CombatRules) -> float:
	return 1.0 + maxf(rules.base_crit_damage_percent + crit_damage, 0.0) / 100.0


## Fraction of damage removed by defense: D / (D + K). 0 for D ≤ 0.
static func mitigation(defense: float, k: float) -> float:
	if defense <= 0.0:
		return 0.0
	return defense / (defense + k)


static func defense_for(damage_type: AbilityEffect.DamageType, stats: StatBlock, rules: CombatRules) -> Vector2:
	## Returns Vector2(defense, k) for the damage type.
	if damage_type == AbilityEffect.DamageType.MAGICAL:
		return Vector2(stats.mag_def, rules.magical_defense_k)
	return Vector2(stats.phys_def, rules.physical_defense_k)


## Bonus multiplier for ranged abilities fired from above. No penalty from below.
static func high_ground_multiplier(height_advantage: int, ranged: bool, rules: CombatRules) -> float:
	if not ranged or height_advantage <= 0:
		return 1.0
	return 1.0 + height_advantage * rules.high_ground_bonus_percent_per_level / 100.0


## Final damage from a pre-mitigation amount. Rounded; at least min_damage.
static func final_damage(raw: float, defense: float, k: float, rules: CombatRules) -> float:
	var dmg := roundf(raw * (1.0 - mitigation(defense, k)))
	return maxf(dmg, rules.min_damage)
