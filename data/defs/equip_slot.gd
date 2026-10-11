class_name EquipSlot
extends RefCounted
## Equipment slots. A hero holds at most one item per slot.

enum Id {
	MAIN_HAND,
	OFF_HAND,
	ACCESSORY,
	BODY,
}

const COUNT := 4
