class_name TimingBarDef
extends Resource
## A timing bar (the rhythm part of casting): when a hero uses an ability that has
## one, the bar runs for `seconds` and the player right-clicks on its zones:
## - green zone: a tap there gives full power
## - yellow zone (usually inside a green one): full power and a sure critical strike
## - blue (hold) zone: press right-click as it starts and let go as it ends. Its
##   accuracy (hold_accuracy) loses the mistiming at both ends, in proportion:
##   HOLD_PERFECT or better is a sure crit at full power, HOLD_MISS or worse a miss,
##   and power rises steadily in between (hold_power). A hold zone ends 0.2–0.3 s
##   before the bar does (HOLD_END_GAP), so letting go on time is part of it.
## A tap outside the zones, a poor hold, or no press at all still casts, at reduced
## power (CombatRules "Timing bar"). One press per bar for now: a tap casts the
## ability at once, a hold when it is let go (or when the bar ends, still held).

enum Grade { MISS, GOOD, PERFECT }

## A hold may start this long before its zone (the early part counts as mistiming).
const HOLD_START_TOLERANCE := 0.2
## Hold accuracy for a sure crit at full power, and at or under which it's a miss.
const HOLD_PERFECT := 0.95
const HOLD_MISS := 0.5
## The rule for hold zones: they end 0.2–0.3 s before the bar (checked on import).
const HOLD_END_GAP := 0.2
const HOLD_END_GAP_MAX := 0.3
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


## How well zone `z` was held from `from` to `to` (seconds into the bar): 1 minus
## the mistiming at both ends (pressed early or late, let go early or late) as a
## share of the zone's length, 0 to 1.
static func hold_accuracy(z: Vector2, from: float, to: float) -> float:
	var off := absf(from - z.x) + absf(to - (z.x + z.y))
	return clampf(1.0 - off / maxf(z.y, 0.01), 0.0, 1.0)


static func hold_grade(accuracy: float) -> Grade:
	if accuracy >= HOLD_PERFECT - EPSILON:
		return Grade.PERFECT
	if accuracy <= HOLD_MISS + EPSILON:
		return Grade.MISS
	return Grade.GOOD


## Power of a hold this accurate: `miss_power` up to HOLD_MISS, rising steadily
## to full at HOLD_PERFECT.
static func hold_power(accuracy: float, miss_power: float) -> float:
	var k := clampf((accuracy - HOLD_MISS) / (HOLD_PERFECT - HOLD_MISS), 0.0, 1.0)
	return lerpf(miss_power, 1.0, k)


static func grade_name(grade: Grade) -> String:
	return ["miss", "good", "perfect"][grade]
