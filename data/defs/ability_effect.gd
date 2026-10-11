class_name AbilityEffect
extends Resource
## One effect applied by an ability to its target.
## Amount = base_amount + Σ(scaling.coefficient × caster stat).

enum Kind {
	DAMAGE,
	HEAL,
	TAUNT,
	RESURRECT,
	BUFF, ## Applies `buff` to the target.
	RESTORE_MANA, ## Like HEAL, for Mana.
	HEAL_OVER_TIME, ## Applies `buff` and heals (base + scaling) in total over its duration.
	DASH, ## Moves the caster forward up to base_amount tiles instantly.
}

enum DamageType {
	PHYSICAL,
	MAGICAL,
}

@export var kind: Kind = Kind.DAMAGE
## Which defense mitigates it. Ignored for non-damage effects.
@export var damage_type: DamageType = DamageType.PHYSICAL
@export var base_amount: float = 0.0
## HEAL / RESTORE_MANA: also restore this fraction of the target's max HP / Mana.
@export var percent_of_max: float = 0.0
@export var scaling: Array[AbilityScaling] = []
@export var can_crit: bool = true
## Used when kind is BUFF.
@export var buff: BuffDef
## Multiplies the threat this effect generates (damage/heal amount × multiplier).
@export var threat_multiplier: float = 1.0
