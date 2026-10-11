class_name ItemDef
extends Resource
## An equippable item: flat stats while equipped, per-level growth granted on
## level-up while equipped, and abilities it teaches.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var slot: EquipSlot.Id = EquipSlot.Id.MAIN_HAND
## Added to the hero's stats while equipped.
@export var stats: StatBlock = StatBlock.new()
## Per-level growth. On level-up the hero permanently gains
## CombatRules.growth_fraction × this (subject to the growth limit settings).
@export var growth: StatBlock = StatBlock.new()
## Usable while equipped; mastered permanently once enough AP is earned.
@export var teaches: Array[AbilityDef] = []


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id == &"":
		errors.append("item has no id")
	if stats == null or growth == null:
		errors.append("%s: missing stats or growth block" % id)
	for ability in teaches:
		if ability == null:
			errors.append("%s: null ability in teaches" % id)
		else:
			errors.append_array(ability.validate())
	return errors
