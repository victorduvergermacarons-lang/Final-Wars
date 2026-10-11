class_name ItemGrowth
extends RefCounted
## Permanent stat growth granted on level-up by the items equipped at that moment.


## The growth a hero gains for one level-up, given the growth they already have.
static func gain_for_level(equipped: Array[ItemDef], current_growth: StatBlock, rules: CombatRules) -> StatBlock:
	var raw := StatBlock.new()
	for item in equipped:
		if item != null:
			raw.add(item.growth, rules.growth_fraction)
	match rules.growth_limit:
		CombatRules.GrowthLimit.CAP:
			for id in Stat.all():
				var cap := rules.growth_cap.get_stat(id)
				if cap > 0.0:
					var room := maxf(cap - current_growth.get_stat(id), 0.0)
					raw.set_stat(id, minf(raw.get_stat(id), room))
		CombatRules.GrowthLimit.DIMINISHING:
			for id in Stat.all():
				var half := rules.growth_half_point.get_stat(id)
				if half > 0.0:
					var so_far := maxf(current_growth.get_stat(id), 0.0)
					raw.set_stat(id, raw.get_stat(id) * half / (half + so_far))
	return raw
