class_name StatModifier
extends Resource
## Changes one stat while a buff is active: (stat + flat) × multiplier.

@export var stat: Stat.Id = Stat.Id.PHYS_DEF
@export var flat: float = 0.0
@export var multiplier: float = 1.0


static func make(p_stat: Stat.Id, p_multiplier: float, p_flat: float = 0.0) -> StatModifier:
	var m := StatModifier.new()
	m.stat = p_stat
	m.multiplier = p_multiplier
	m.flat = p_flat
	return m
