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
## Shown on the target's frame; harmful effects (slows, roots) are debuffs.
@export var is_debuff: bool = false
