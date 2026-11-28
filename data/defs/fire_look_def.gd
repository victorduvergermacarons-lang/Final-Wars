class_name FireLookDef
extends Resource
## How a Fire ability looks: its settings on the fire fluid at mastery 0 (`s0`) and
## at the limit (`m1`), approved on fire-ability-reference.html (fire physics). A
## setting at Fire Mastery x is s0 + (m1 - s0) * x / (180 + x) (`settings`).
## Look only: the ability's gameplay is in its ability data.

## The ability (F12).
@export var id: StringName
## The reference's kind: stream, punch, kick, combo, dart, swb, overheat, whip, jet,
## phoenix, fireball, wheel, inferno, breathfire, combust.
@export var kind := ""
## Playback speed of the effect (the reference's ts): 0.5 steps every other frame.
## Gameplay times stay real.
@export var time_scale := 1.0
## Playback speed after the effect's main moment (Overheat's and Combustion's tsx).
@export var time_scale_after := 1.0
## The reference bench's near and far dummy distances (cells), for benches.
@export var near := 16
@export var far := 32
@export var s0 := {}
@export var m1 := {}

## The reference's BASE: settings every ability starts from.
const BASE := {"heat": 0.0, "hts": 0.0, "thrust": 0.0, "tts": 0.0, "widen": 0.1, "push": 2.0, "boom": 1.0,
		"brk": 0.75, "cool": 0.05, "fade": 0.02, "kat": 0.3, "temp": 1.0, "launch": 1.0}


## Mastery growth: 0 at none, 0.5 at 180, toward 1.
static func growth(mastery: float) -> float:
	var x := maxf(mastery, 0.0)
	return x / (180.0 + x)


## Every setting at this Fire Mastery, over BASE.
func settings(mastery: float) -> Dictionary:
	var g := growth(mastery)
	var o := BASE.duplicate()
	for k in s0:
		var a := float(s0[k])
		o[k] = a + (float(m1.get(k, a)) - a) * g
	return o
