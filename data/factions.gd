class_name Factions
extends RefCounted
## Who an NPC belongs to. Placeholder NPCs (no sprite yet) are drawn in their
## faction's colour, and their portrait frame uses it too.

enum Id {
	TOWNSFOLK,
	FLOOR_GUILD,
	EMBER_HAND,
	BEDRUN,
	VAEL,
	NONE, ## Objects, boards, shrines: no one's.
}

const NAMES := {
	Id.TOWNSFOLK: "Townsfolk",
	Id.FLOOR_GUILD: "Floor Guild",
	Id.EMBER_HAND: "Ember Hand",
	Id.BEDRUN: "Bedrun",
	Id.VAEL: "Vael",
	Id.NONE: "",
}

const COLORS := {
	Id.TOWNSFOLK: Color(0.62, 0.62, 0.64), # grey
	Id.FLOOR_GUILD: Color(0.27, 0.48, 0.92), # blue
	Id.EMBER_HAND: Color(0.86, 0.24, 0.2), # red
	Id.BEDRUN: Color(0.8, 0.6, 0.18), # ochre
	Id.VAEL: Color(0.68, 0.85, 1.0), # pale blue
	Id.NONE: Color(0.72, 0.6, 0.42), # wood
}


static func color(id: Id) -> Color:
	return COLORS.get(id, COLORS[Id.NONE])


static func display_name(id: Id) -> String:
	return NAMES.get(id, "")
