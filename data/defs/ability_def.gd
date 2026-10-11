class_name AbilityDef
extends Resource
## An ability a hero (via an item) or an enemy can use.
## Ranges are in tiles, measured as grid (Manhattan) distance.
##
## Shape decides where it lands:
## - TARGETED: on the chosen target (heals, resurrect; SELF target type = self).
## - FRONT: on whoever stands on the tiles straight ahead, min_range..max_range
##   (Strike, Bite). Empty tiles: it whiffs.
## - LINE: a projectile flying straight ahead up to max_range tiles; it stops at
##   the first actor it affects or at terrain too high to pass (Fireball).
## For FRONT and LINE, `target` says who is affected (ENEMY = hostile actors).

enum Shape {
	TARGETED,
	FRONT,
	LINE,
}

enum TargetType {
	SELF,
	ENEMY,
	ALLY, ## Any living friendly actor, including self.
	DEAD_ALLY,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var shape: Shape = Shape.TARGETED
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
## FRONT: only hits actors within this many height levels of the caster (-1 = any).
@export var max_height_difference: int = -1
## LINE: projectile speed in tiles per second (0 = hits instantly).
@export var projectile_speed: float = 0.0
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
	if shape != Shape.TARGETED and target != TargetType.ENEMY and target != TargetType.ALLY:
		errors.append("%s: FRONT/LINE abilities must affect ENEMY or ALLY" % id)
	if shape == Shape.FRONT and max_range < 1:
		errors.append("%s: FRONT needs max_range >= 1" % id)
	if ap_to_master < 0:
		errors.append("%s: negative ap_to_master" % id)
	return errors
