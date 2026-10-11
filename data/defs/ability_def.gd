class_name AbilityDef
extends Resource
## An ability a hero (via an item) or an enemy can use.
## Ranges are in tiles, measured as grid (Manhattan) distance.

enum TargetType {
	SELF,
	ENEMY,
	ALLY, ## Any living friendly actor, including self.
	DEAD_ALLY,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var target: TargetType = TargetType.ENEMY
@export var min_range: int = 0
@export var max_range: int = 1
@export var mana_cost: float = 0.0
@export var cooldown_seconds: float = 0.0
## Whether using it triggers (and is blocked by) the global cooldown.
@export var on_gcd: bool = true
## Ranged abilities can get the high-ground bonus.
@export var ranged: bool = false
@export var requires_line_of_sight: bool = true
@export var effects: Array[AbilityEffect] = []
## AP needed to master this ability. 0 = cannot be mastered (e.g. enemy attacks).
@export var ap_to_master: int = 0


## Returns a list of problems; empty when the definition is usable.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id == &"":
		errors.append("ability has no id")
	if min_range < 0 or max_range < min_range:
		errors.append("%s: invalid range %d..%d" % [id, min_range, max_range])
	if mana_cost < 0.0 or cooldown_seconds < 0.0:
		errors.append("%s: negative cost or cooldown" % id)
	if effects.is_empty():
		errors.append("%s: no effects" % id)
	if ap_to_master < 0:
		errors.append("%s: negative ap_to_master" % id)
	return errors
