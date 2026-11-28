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
## Water Whip's return (water physics phase 4): a second press `t` seconds after the
## cast brings back 50% at once, 100% at WHIP_PERFECT, falling to 0% at WHIP_WINDOW
## (no press: 0%).
const WHIP_PERFECT := 0.5
const WHIP_WINDOW := 1.5


static func whip_share(t: float) -> float:
	if t < 0.0 or t >= WHIP_WINDOW:
		return 0.0
	if t <= WHIP_PERFECT:
		return 0.5 + 0.5 * t / WHIP_PERFECT
	return 1.0 - (t - WHIP_PERFECT) / (WHIP_WINDOW - WHIP_PERFECT)


## Sends the whole stance water out for `ability` (AbilityDef.water_whole_rope): its
## power is that water; what comes back is settled later (Hero.water_out).
static func send_out(hero: Hero, ability: AbilityDef, now: float, target_id := -1) -> void:
	hero.cast_water[ability.id] = hero.stance_water
	var out := {"ability": ability.id, "points": hero.stance_water, "at": now, "paid": false, "target": target_id}
	if ability.water_back == AbilityDef.WaterBack.SHIELD_LEFT:
		hero.shield_out = out
	else:
		hero.water_out = out
	hero.stance_water = 0


## The water `ability` sent out (Hero.water_out, or Hero.shield_out for a shield).
static func out_of(hero: Hero, ability: AbilityDef) -> Dictionary:
	return hero.shield_out if ability.water_back == AbilityDef.WaterBack.SHIELD_LEFT else hero.water_out


## Water Shield's water while it is up: its points × the share of the shield left.
static func shield_water(hero: Hero) -> int:
	var out := hero.shield_out
	if out.is_empty() or not out.get("paid", false):
		return 0
	return roundi(int(out.get("points", 0)) * float(out.get("left", 1.0)))


## Frost Shard while a Water Shield is up (2026-11-28, user): the stance doesn't
## rebuild while the shield holds the rope, so the shard is thrown off the shield.
static func from_shield(hero: Hero, ability: AbilityDef) -> bool:
	return ability != null and ability.id == &"W04" and not hero.shield_out.is_empty() \
			and hero.shield_out.get("paid", false) and hero.stance_water < maxi(1, ability.water_cost)


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
	var need := maxi(1, ability.water_cost)
	if from_shield(hero, ability):
		return shield_water(hero) >= need
	var out := out_of(hero, ability)
	if out.get("ability", &"") == ability.id and not out.get("paid", true):
		return int(out.points) >= need # sent out at its release: going off now
	return hero.stance_water >= need


## The water `hero` could put into a stance: stance water + reserve, or unlimited by
## water tiles.
static func total(hero: Hero) -> int:
	if hero.near_water:
		return 1 << 20
	return hero.stance_water + (hero.water if hero.has_water_pouch() else 0)
