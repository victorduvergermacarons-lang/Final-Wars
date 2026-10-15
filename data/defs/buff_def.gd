class_name BuffDef
extends Resource
## A timed effect on an actor, e.g. Block: Physical Defense × 2.
## Re-applying an active buff refreshes its duration; it does not stack.

@export var id: StringName = &""
@export var display_name: String = ""
@export var duration_seconds: float = 5.0
@export var modifiers: Array[StatModifier] = []
## Movement: multiplies the step cooldown (2.0 = half speed). 1.0 = no change.
@export var step_cooldown_multiplier: float = 1.0
## Can't step at all while active (still can turn and use abilities).
@export var roots: bool = false
## Heal-over-time buffs heal every this many seconds.
@export var tick_seconds: float = 1.0
## Restores this % of max Mana per second while active (Sun Warrior's Breath: 1 for 10 s).
@export var mana_regen_percent: float = 0.0
## Shown on the target's frame; harmful effects (slows, roots) are debuffs.
@export var is_debuff: bool = false

@export_group("Crowd control")
## No stepping and no abilities.
@export var stuns: bool = false
## No spells (element abilities, heals, magical attacks); weapon arts still work.
@export var silences: bool = false
## Like a stun, but any damage wakes the unit up.
@export var sleeps: bool = false

@export_group("Modifiers")
## Ability cooldowns and the GCD are multiplied by this when triggered (Haste 0.75).
@export var cooldown_multiplier: float = 1.0
## Damage the owner deals × this (only abilities of `affects_tree`, if set).
@export var damage_dealt_multiplier: float = 1.0
## Damage the owner takes × this.
@export var damage_taken_multiplier: float = 1.0
## Limits damage_dealt_multiplier (and charge use) to one ability tree ("" = all).
@export var affects_tree: String = ""
## Uses before it ends (0 = lasts its whole duration): each qualifying ability
## cast (Kindle: next 3 fire abilities), or each step for free_steps (Air Step).
@export var charges: int = 0
## Steps cost no step cooldown while it lasts (uses a charge per step).
@export var free_steps: bool = false

@export_group("Counters")
## Fraction of incoming damage dealt back to the attacker.
@export var reflect_fraction: float = 0.0
## Incoming hits are negated completely (uses a charge each, if charges > 0).
@export var negate_hits: bool = false
## Used on the attacker for free when the owner is hit.
@export var counter_ability: AbilityDef
## Negate / counter only melee hits.
@export var melee_only: bool = true
