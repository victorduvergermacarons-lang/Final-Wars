class_name Stat
extends RefCounted
## Stat identifiers and their StatBlock property names.
##
## Units (keep consistent across content):
## - HP, MANA: max pool size.
## - PHYS_ATK, MAG_ATK, PHYS_DEF, MAG_DEF, ACCURACY, EVASION, SPEED: rating points.
## - CRIT_RATE: percent chance (5.0 = 5%).
## - CRIT_DMG: bonus damage on crit in percent (50.0 = crits deal +50%).
## - JUMP: height levels a hero can climb in one step (read as int).

enum Id {
	HP,
	MANA,
	PHYS_ATK,
	MAG_ATK,
	PHYS_DEF,
	MAG_DEF,
	CRIT_RATE,
	CRIT_DMG,
	SPEED,
	ACCURACY,
	EVASION,
	JUMP,
}

const COUNT := 12

## StatBlock property name for each Id, in enum order.
const PROPERTY := [
	&"hp",
	&"mana",
	&"phys_atk",
	&"mag_atk",
	&"phys_def",
	&"mag_def",
	&"crit_rate",
	&"crit_dmg",
	&"speed",
	&"accuracy",
	&"evasion",
	&"jump",
]


static func property_of(id: Id) -> StringName:
	return PROPERTY[id]


static func all() -> Array[Id]:
	var ids: Array[Id] = []
	for i in COUNT:
		ids.append(i as Id)
	return ids
