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
## - *_MASTERY: points in that ability tree (0 and up). Permanent Mastery (base +
##   growth) unlocks tiers; gear Mastery only adds power. See Mastery.

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
	FIRE_MASTERY,
	EARTH_MASTERY,
	WATER_MASTERY,
	AIR_MASTERY,
	SWORD_MASTERY,
	BOW_MASTERY,
	HAMMER_MASTERY,
}

const COUNT := 19
## The first CORE_COUNT ids are the combat stats; the rest are tree Masteries.
const CORE_COUNT := 12

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
	&"fire_mastery",
	&"earth_mastery",
	&"water_mastery",
	&"air_mastery",
	&"sword_mastery",
	&"bow_mastery",
	&"hammer_mastery",
]


static func property_of(id: Id) -> StringName:
	return PROPERTY[id]


static func all() -> Array[Id]:
	var ids: Array[Id] = []
	for i in COUNT:
		ids.append(i as Id)
	return ids


## The combat stats (HP … Jump), without the tree Masteries.
static func core() -> Array[Id]:
	var ids: Array[Id] = []
	for i in CORE_COUNT:
		ids.append(i as Id)
	return ids
