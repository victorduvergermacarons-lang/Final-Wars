class_name ItemDef
extends Resource
## An item design. Equippable items give flat stats while equipped, per-level
## growth on level-up while equipped, and teach abilities. Items are fixed designs:
## every copy of an item is identical (no random rolls).

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Where it can be equipped (NONE: potions, quest items…).
@export var slot: EquipSlot.Type = EquipSlot.Type.NONE
@export var rarity: Rarity.Id = Rarity.Id.COMMON
## Vendor price in gold (vendors buy it back for a fraction).
@export var price: int = 0
## How many fit in one bag slot. Equippable items don't stack.
@export var max_stack: int = 1
## Quest items: shown as such, can't be sold.
@export var quest_item: bool = false
## Consumables: using the item casts this ability on yourself and uses one up.
@export var use_ability: AbilityDef
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
	if max_stack < 1:
		errors.append("%s: max_stack must be at least 1" % id)
	if is_equippable() and max_stack != 1:
		errors.append("%s: equippable items can't stack" % id)
	if stats == null or growth == null:
		errors.append("%s: missing stats or growth block" % id)
	for ability in teaches:
		if ability == null:
			errors.append("%s: null ability in teaches" % id)
		else:
			errors.append_array(ability.validate())
	return errors


func is_equippable() -> bool:
	return slot != EquipSlot.Type.NONE


func is_two_handed() -> bool:
	return slot == EquipSlot.Type.TWO_HAND
