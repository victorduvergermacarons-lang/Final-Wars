class_name TimingBarDef
extends Resource
## A timing bar (the rhythm part of casting): when a hero uses an ability that has
## one, the bar runs for `seconds` and the player right-clicks on its zones:
## - green zone: a tap there gives full power
## - yellow zone (usually inside a green one): full power and a sure critical strike
## - blue (hold) zone: press as it starts and keep holding right-click through it;
##   held for at least HOLD_MIN_FRACTION of it, full power
## A tap outside the zones, a hold that falls short, or no press at all still casts,
## at reduced power (CombatRules "Timing bar"). One press per bar for now: a tap
## casts the ability at once, a hold when it is released (or its zone ends).

enum Grade { MISS, GOOD, PERFECT }

## A hold may start this long before its zone (or later, losing that part).
const HOLD_START_TOLERANCE := 0.2
## Share of a hold zone that must be held for full power.
const HOLD_MIN_FRACTION := 0.9
## Zone edges count as inside (floating-point sums such as 0.9 + 0.1).
const EPSILON := 0.0001

## How long the bar runs (sim seconds).
@export var seconds: float = 2.0
## Green zones: (start, length) in seconds from the bar's start.
@export var zones: Array[Vector2] = []
## Yellow zones: (start, length) in seconds from the bar's start.
@export var crit_zones: Array[Vector2] = []
## Blue hold zones: (start, length) in seconds from the bar's start.
@export var hold_zones: Array[Vector2] = []


## The grade of a tap `at` seconds after the bar started.
func judge(at: float) -> Grade:
	for z in crit_zones:
		if at >= z.x - EPSILON and at <= z.x + z.y + EPSILON:
			return Grade.PERFECT
	for z in zones:
		if at >= z.x - EPSILON and at <= z.x + z.y + EPSILON:
			return Grade.GOOD
	return Grade.MISS


## The hold zone a press `at` seconds in starts holding, or null (then it's a tap).
func hold_zone_at(at: float) -> Variant:
	for z in hold_zones:
		if at >= z.x - HOLD_START_TOLERANCE and at < z.x + z.y:
			return z
	return null


## The grade of holding zone `z` from `from` to `to` (seconds into the bar).
static func judge_hold(z: Vector2, from: float, to: float) -> Grade:
	var held := minf(to, z.x + z.y) - maxf(from, z.x)
	return Grade.GOOD if held >= z.y * HOLD_MIN_FRACTION - 0.0001 else Grade.MISS


static func grade_name(grade: Grade) -> String:
	return ["miss", "good", "perfect"][grade]
