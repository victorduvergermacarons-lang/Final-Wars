class_name WaterBending
extends RefCounted
## Water as a resource (water physics pass, phase 3, 2026-11-28). A waterbender's water
## lives in two places, both counted by the host and sent in snapshots:
## - the stance water (`Hero.stance_water`): what's drawn round the hero in Water
##   stance 1 (the rope, full at 24) or stance 2 (the hoop, full at 33);
## - the reserve (`Hero.water`): the Water Pouch at the hip.
## Water used by abilities is gone. Water tiles within `water_near_tiles` are an
## unlimited source. Every water ability's power = 0.2 + 0.8 × stance points ÷ full.

## Full stance water per Water stance.
const FULL := {1: 24, 2: 33}
## Total water (stance + reserve) needed to enter stance 2.
const STANCE_2_ENTRY := 27
## Power at an empty stance, and what the stance water adds up to full.
const POWER_FLOOR := 0.2


## The full count of Water stance `n` (0 for the stances without water).
static func full(n: int) -> int:
	return int(FULL.get(n, 0))


## Whether `ability` is a water ability drawn from the stance water (Water stances 1–2).
static func uses_stance_water(ability: AbilityDef) -> bool:
	return ability != null and ability.tree == "Water" and FULL.has(ability.stance)


## Whether `hero` holds a Water stance with water (1 or 2).
static func in_water_stance(hero: Hero) -> bool:
	return hero.stance_tree == "Water" and FULL.has(hero.stance)


## Power of `ability` for `hero`: 0.2 + 0.8 × points ÷ full. The points are those the
## ability was cast with (recorded when it was paid), else the stance water now; out
## of the ability's stance (a tooltip), full.
static func power(hero: Hero, ability: AbilityDef) -> float:
	if not uses_stance_water(ability):
		return 1.0
	var n := full(ability.stance)
	var points := n
	if hero.cast_water.has(ability.id):
		points = int(hero.cast_water[ability.id])
	elif hero.stance_tree == "Water" and hero.stance == ability.stance:
		points = hero.stance_water
	return POWER_FLOOR + (1.0 - POWER_FLOOR) * clampf(float(points) / n, 0.0, 1.0)


## Whether the stance holds enough water for `ability`: at least 1 point and at least
## its cost.
static func has_enough(hero: Hero, ability: AbilityDef) -> bool:
	if not uses_stance_water(ability):
		return true
	return hero.stance_water >= maxi(1, ability.water_cost)


## The water `hero` could put into a stance: stance water + reserve, or unlimited by
## water tiles.
static func total(hero: Hero) -> int:
	if hero.near_water:
		return 1 << 20
	return hero.stance_water + (hero.water if hero.has_water_pouch() else 0)
