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
## power (CombatRules "Timing bar").
## A bar may ask for several inputs, played in order (inputs(): each tap zone with
## the yellow zones inside it, and each hold zone; Aimed Shot: a tap, then a hold).
## Each press goes to the next input whose window isn't over yet (input_for_press);
## an input skipped or never played is a miss. The ability goes off once the last
## input is played: power = the inputs' average power, a sure crit only if every
## input was perfect (combine).

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


## The inputs in the order they're played: [{"kind": "tap"|"hold", "zone": Vector2,
## "crits": [Vector2…] (a tap's yellow zones)}…].
func inputs() -> Array:
	var out := []
	for z in zones:
		var crits: Array[Vector2] = []
		for c in crit_zones:
			if c.x >= z.x - EPSILON and c.x + c.y <= z.x + z.y + EPSILON:
				crits.append(c)
		out.append({"kind": "tap", "zone": z, "crits": crits})
	for z in hold_zones:
		out.append({"kind": "hold", "zone": z, "crits": [] as Array[Vector2]})
	out.sort_custom(func(a, b): return a.zone.x < b.zone.x)
	return out


## Which input a press `at` seconds in goes to, `next` being the first one not played
## yet: inputs whose window is already over are skipped (they count as misses).
## inputs().size() when none is left.
func input_for_press(next: int, at: float) -> int:
	var list := inputs()
	var i := next
	while i < list.size() and at > list[i].zone.x + list[i].zone.y + EPSILON:
		i += 1
	return i


## A tap input's grade for a press `at` seconds in.
static func judge_tap(input: Dictionary, at: float) -> Grade:
	for c in input.crits:
		if at >= c.x - EPSILON and at <= c.x + c.y + EPSILON:
			return Grade.PERFECT
	var z: Vector2 = input.zone
	return Grade.GOOD if at >= z.x - EPSILON and at <= z.x + z.y + EPSILON else Grade.MISS


## Whether a press `at` seconds in starts holding this hold input (too early: a miss).
static func starts_hold(input: Dictionary, at: float) -> bool:
	var z: Vector2 = input.zone
	return at >= z.x - HOLD_START_TOLERANCE and at < z.x + z.y


## One played input's result: {"kind", "grade", "power", "accuracy"}.
static func tap_result(grade: Grade, miss_power: float) -> Dictionary:
	return {"kind": "tap", "grade": grade, "power": miss_power if grade == Grade.MISS else 1.0,
			"accuracy": 0.0 if grade == Grade.MISS else 1.0}


static func hold_result(accuracy: float, miss_power: float) -> Dictionary:
	return {"kind": "hold", "grade": hold_grade(accuracy), "power": hold_power(accuracy, miss_power),
			"accuracy": accuracy}


static func missed_input(kind: String, miss_power: float) -> Dictionary:
	return {"kind": kind, "grade": Grade.MISS, "power": miss_power, "accuracy": 0.0}


## The whole bar's result from its inputs' results: {"grade", "power", "accuracy"}.
## Power = the average; PERFECT only if every input was, MISS only if every input
## was, GOOD otherwise. Accuracy (the average) is -1 for a bar of one tap, which
## shows no percentage.
static func combine(results: Array) -> Dictionary:
	if results.is_empty():
		return {"grade": Grade.MISS, "power": 0.0, "accuracy": -1.0}
	var power := 0.0
	var accuracy := 0.0
	var all_perfect := true
	var all_miss := true
	for r in results:
		power += r.power
		accuracy += r.accuracy
		all_perfect = all_perfect and r.grade == Grade.PERFECT
		all_miss = all_miss and r.grade == Grade.MISS
	var grade := Grade.PERFECT if all_perfect else (Grade.MISS if all_miss else Grade.GOOD)
	var single_tap: bool = results.size() == 1 and results[0].kind == "tap"
	return {"grade": grade, "power": power / results.size(),
			"accuracy": -1.0 if single_tap else accuracy / results.size()}


static func grade_name(grade: Grade) -> String:
	return ["miss", "good", "perfect"][grade]
