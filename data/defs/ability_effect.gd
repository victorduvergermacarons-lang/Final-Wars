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
	DAMAGE_OVER_TIME, ## Applies `buff` and deals (base + scaling) in total over its duration.
	SHIELD, ## Applies `buff` holding a shield of (base + scaling) that absorbs damage.
	INTERRUPT, ## Cancels the target's cast or channel.
	KNOCKBACK, ## Pushes the target base_amount tiles away (8 directions).
	PULL, ## Pulls the target up to base_amount tiles toward the caster.
	DASH_TO, ## Moves the caster up to base_amount tiles toward the aim (8 directions).
	LEAP, ## The caster jumps onto the aimed tile (over obstacles).
	BLINK, ## The caster teleports to the aimed tile.
	TERRAIN, ## Raises (or lowers, if negative) the area by base_amount levels for a while.
	ZONE, ## Leaves a ground zone on the area that applies zone_ability every tick.
}

## Who an effect applies to: each affected unit (TARGETS), the caster once
## (CASTER: dashes, self buffs alongside an attack), or the cast's tiles once (AREA:
## terrain and ground zones).
enum Applies { TARGETS, CASTER, AREA }

enum DamageType {
	PHYSICAL,
	MAGICAL,
}

@export var kind: Kind = Kind.DAMAGE
@export var applies: Applies = Applies.TARGETS
## Which defense mitigates it. Ignored for non-damage effects.
@export var damage_type: DamageType = DamageType.PHYSICAL
@export var base_amount: float = 0.0
## HEAL / RESTORE_MANA: also restore this fraction of the target's max HP / Mana.
@export var percent_of_max: float = 0.0
@export var scaling: Array[AbilityScaling] = []
## Tree abilities: use the spreadsheet's Scales With stats (each × the rules'
## sheet_stat_coefficient) instead of `scaling`. A negative base_amount means "the
## tier default" (CombatRules.tier_damage_base / tier_heal_base). See AbilityPower.
@export var sheet_scaling: bool = false
@export var can_crit: bool = true
## Used when kind is BUFF.
@export var buff: BuffDef
## Multiplies the threat this effect generates (damage/heal amount × multiplier).
@export var threat_multiplier: float = 1.0
## Multiplies the whole amount (tier default + scaling): light hits < 1, heavy > 1.
@export var power: float = 1.0
## DAMAGE: heals the caster this fraction of the damage dealt (Leeching Tide).
@export var lifesteal: float = 0.0

@export_group("Movement, terrain and zones")
## KNOCKBACK: push along the cast's direction (a wave) instead of away from the caster.
@export var push_along_cast: bool = false
## KNOCKBACK/PULL: extra damage when the unit is stopped by a wall, ledge or unit.
@export var impact_damage: float = 0.0
## TERRAIN / ZONE: how long it lasts (seconds; scales with Mastery for tree abilities).
@export var duration_seconds: float = 0.0
## TERRAIN: the tiles become impassable (walls); WALL_LINE builds a line across the
## caster's facing through the aimed tile instead of using the cast's area.
@export var blocks_movement: bool = false
@export var wall_line: bool = false
## TERRAIN: units on the tiles ride up with them; enemies of the caster take this
## much physical damage, + `lift_damage_per_mastery` per point of the tree's Mastery
## (then the usual Mastery power bonus and defense). Earth Wall.
@export var lift_damage: float = 0.0
@export var lift_damage_per_mastery: float = 0.0
## Size bonus: +1 (terrain levels, wall tiles, push tiles) per this much tree
## Mastery (0 = none). E.g. Earth Wall +1 length per 300.
@export var mastery_per_extra: float = 0.0
## Most the Mastery size bonus can add (0 = no limit). Raise Pillar: 1.
@export var max_extra: int = 0
## ZONE: what the zone does to units standing in it, every zone_tick_seconds.
@export var zone_ability: AbilityDef
@export var zone_tick_seconds: float = 1.0
