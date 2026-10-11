class_name AbilityEffect
extends Resource
## One effect applied by an ability to its target.
## Amount = base_amount + Σ(scaling.coefficient × caster stat).

enum Kind {
	DAMAGE,
	HEAL,
	TAUNT,
	RESURRECT,
}

enum DamageType {
	PHYSICAL,
	MAGICAL,
}

@export var kind: Kind = Kind.DAMAGE
## Which defense mitigates it. Ignored for non-damage effects.
@export var damage_type: DamageType = DamageType.PHYSICAL
@export var base_amount: float = 0.0
@export var scaling: Array[AbilityScaling] = []
@export var can_crit: bool = true
## Multiplies the threat this effect generates (damage/heal amount × multiplier).
@export var threat_multiplier: float = 1.0
