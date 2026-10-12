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
## - ARC: the tile in front plus the tiles on either side of it (Cleave).
## - AROUND: every tile within max_range of the caster (Frost Nova, Rallying Roar);
##   for ALLY abilities this includes the caster.
## For FRONT, LINE, ARC and AROUND, `target` says who is affected (ENEMY or ALLY).

enum Shape {
	TARGETED,
	FRONT,
	LINE,
	ARC,
	AROUND,
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
## Abilities with the same group share one cooldown (e.g. all potions).
@export var cooldown_group: StringName = &""
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

@export_group("Targeting (Milestone 3)")
## LEGACY = the M1/M2 shapes above. The others follow the Milestone 3 targeting
## rules (CastResolver): TARGETED locks on a unit and can't miss; SKILLSHOT is aimed
## along a tile line; GROUND picks a tile (optionally telegraphed); SELF is
## centred on the caster. max_range is the range / line length.
enum TargetingMode { LEGACY, TARGETED, SKILLSHOT, GROUND, SELF }
@export var targeting: TargetingMode = TargetingMode.LEGACY
## SKILLSHOT: any-angle line toward the aim point, or snapped to 8 directions.
enum Aim { ANY_ANGLE, EIGHT_WAY }
@export var aim: Aim = Aim.ANY_ANGLE
## SKILLSHOT: LINE hits along a line; CONE hits a widening cone (8-way).
enum LineShape { LINE, CONE }
@export var line_shape: LineShape = LineShape.LINE
## SKILLSHOT: keeps going through units instead of stopping at the first one.
@export var pierce: bool = false
## SKILLSHOT: lobbed instead of flying (e.g. Rock Throw): lands on the aimed tile
## after this many seconds, over obstacles; hits whoever is on it then.
@export var arc_seconds: float = 0.0
## GROUND / SELF: square radius of the area (0 = the tile itself).
@export var area_radius: int = 0
## GROUND: seconds the area is shown before it goes off (0 = at once).
@export var telegraph_seconds: float = 0.0
## Cast time: resolves after this many seconds; moving, a stun or an interrupt
## cancels it (mana and cooldown are only spent when it goes off).
@export var cast_seconds: float = 0.0
## Wind-up: paid at once, resolves after this delay; the caster can't move
## meanwhile, but the target can step away (Smash 0.3 s).
@export var windup_seconds: float = 0.0
## Channel: paid at once, then resolves every channel_tick_seconds for this long;
## moving, a stun or an interrupt ends it.
@export var channel_seconds: float = 0.0
@export var channel_tick_seconds: float = 1.0
## Charges: uses stored up to max (base + 1 per mastery_per_charge tree Mastery);
## each recharges in cooldown_seconds, one at a time. 0 = no charges.
@export var charges_base: int = 0
@export var mastery_per_charge: float = 0.0

@export_group("Ability tree")
## Set for abilities from design/Ability_Tree.xlsx ("" = not a tree ability).
@export var tree: String = ""
@export var tier: int = 0
## Tree abilities without behavior data yet can't be learned or used.
@export var implemented: bool = true
## The spreadsheet row (see AbilityTreeData): prerequisites, Mastery values, texts.
var sheet: Dictionary = {}


## Spells are blocked by silence: element abilities, and other abilities that heal
## or deal magical damage. Weapon arts and physical attacks still work.
func is_spell() -> bool:
	if is_tree_ability():
		return not needs_weapon()
	for e in effects:
		if e != null and (e.kind == AbilityEffect.Kind.HEAL or e.kind == AbilityEffect.Kind.HEAL_OVER_TIME \
				or (e.kind == AbilityEffect.Kind.DAMAGE and e.damage_type == AbilityEffect.DamageType.MAGICAL)):
			return true
	return false


func is_tree_ability() -> bool:
	return tree != ""


## Element (scroll) trees work without a weapon; weapon arts need one.
func needs_weapon() -> bool:
	return tree == "Sword" or tree == "Bow" or tree == "Hammer"


## Returns a list of problems; empty when the definition is usable.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id == &"":
		errors.append("ability has no id")
	if min_range < 0 or max_range < min_range:
		errors.append("%s: invalid range %d..%d" % [id, min_range, max_range])
	if mana_cost < 0.0 or cooldown_seconds < 0.0:
		errors.append("%s: negative cost or cooldown" % id)
	if effects.is_empty() and implemented:
		errors.append("%s: no effects" % id)
	if shape != Shape.TARGETED and target != TargetType.ENEMY and target != TargetType.ALLY:
		errors.append("%s: FRONT/LINE abilities must affect ENEMY or ALLY" % id)
	if (shape == Shape.FRONT or shape == Shape.AROUND) and max_range < 1:
		errors.append("%s: FRONT/AROUND need max_range >= 1" % id)
	if ap_to_master < 0:
		errors.append("%s: negative ap_to_master" % id)
	return errors


## The key its cooldown is tracked under: the group if it has one, else its id.
func cooldown_key() -> StringName:
	return cooldown_group if cooldown_group != &"" else id


## Melee shapes get flanking bonuses.
func is_melee() -> bool:
	if targeting == TargetingMode.TARGETED:
		return max_range <= 1 and target == TargetType.ENEMY
	return targeting == TargetingMode.LEGACY and (shape == Shape.FRONT or shape == Shape.ARC)
