class_name TimingBarDef
extends Resource
## A timing bar (the rhythm part of casting): when a hero uses an ability that has
## one, a cursor sweeps across the bar for `seconds`, and the player right-clicks
## while it is over a green zone for full power, or over a blue zone (usually the
## middle of a green one) for full power and a sure critical strike. A press
## outside them, or none, still casts at reduced power (CombatRules "Timing bar").
## For now one press per bar: the press casts the ability at once.

enum Grade { MISS, GOOD, PERFECT }

## How long the cursor takes to cross the bar (sim seconds).
@export var seconds: float = 2.0
## Green zones: (start, length) in seconds from the bar's start.
@export var zones: Array[Vector2] = []
## Blue zones: (start, length) in seconds from the bar's start.
@export var crit_zones: Array[Vector2] = []


## The grade of a press `at` seconds after the bar started.
func judge(at: float) -> Grade:
	for z in crit_zones:
		if at >= z.x and at <= z.x + z.y:
			return Grade.PERFECT
	for z in zones:
		if at >= z.x and at <= z.x + z.y:
			return Grade.GOOD
	return Grade.MISS


static func grade_name(grade: Grade) -> String:
	return ["miss", "good", "perfect"][grade]
