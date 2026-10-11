class_name AbilityScaling
extends Resource
## One scaling term of an ability effect: `coefficient × stat`.

@export var stat: Stat.Id = Stat.Id.PHYS_ATK
@export var coefficient: float = 1.0


static func make(p_stat: Stat.Id, p_coefficient: float) -> AbilityScaling:
	var s := AbilityScaling.new()
	s.stat = p_stat
	s.coefficient = p_coefficient
	return s
