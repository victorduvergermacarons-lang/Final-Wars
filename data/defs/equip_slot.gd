class_name EquipSlot
extends RefCounted
## Equipment positions on a hero (Id) and the kind of position an item fits (Type).
## Accessories fit either accessory position; two-handed weapons sit in Main Hand
## and keep Off Hand empty.

enum Id {
	HEAD,
	CHEST,
	LEGS,
	FEET,
	HANDS,
	MAIN_HAND,
	OFF_HAND,
	ACCESSORY_1,
	ACCESSORY_2,
}

const COUNT := 9

enum Type {
	HEAD,
	CHEST,
	LEGS,
	FEET,
	HANDS,
	MAIN_HAND,
	OFF_HAND,
	ACCESSORY,
	TWO_HAND,
	NONE, ## Not equippable (potions, quest items).
}

const NAMES := ["Head", "Chest", "Legs", "Feet", "Hands", "Main Hand", "Off Hand", "Accessory", "Accessory"]
const TYPE_NAMES := ["Head", "Chest", "Legs", "Feet", "Hands", "Main Hand", "Off Hand", "Accessory", "Two-Hand", ""]


## Positions an item of this type can go in.
static func slots_for(type: Type) -> Array[Id]:
	match type:
		Type.HEAD: return [Id.HEAD]
		Type.CHEST: return [Id.CHEST]
		Type.LEGS: return [Id.LEGS]
		Type.FEET: return [Id.FEET]
		Type.HANDS: return [Id.HANDS]
		Type.MAIN_HAND, Type.TWO_HAND: return [Id.MAIN_HAND]
		Type.OFF_HAND: return [Id.OFF_HAND]
		Type.ACCESSORY: return [Id.ACCESSORY_1, Id.ACCESSORY_2]
	return []
