class_name BuffDef
extends Resource
## A timed effect on an actor, e.g. Block: Physical Defense × 2.
## Re-applying an active buff refreshes its duration; it does not stack.

@export var id: StringName = &""
@export var display_name: String = ""
@export var duration_seconds: float = 5.0
@export var modifiers: Array[StatModifier] = []
