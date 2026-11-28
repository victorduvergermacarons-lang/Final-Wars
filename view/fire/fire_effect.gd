class_name FireEffect
extends RefCounted
## One fire effect on the fluid: its slot, the window it sits in, and the reference's
## per-kind timeline (what it emits each step). Cosmetic: every player runs their own
## from the host's events.
##
## The window: 128 x 128 cells (16 a tile), its corner on a tile corner so its tile
## diagonals are the world's. `origin` is the world tile at the window's cell (0, 0)
## tile; a local cell point p is the world point origin - (0.5, 0.5) + p / 16.

const CELLS_PER_TILE := 16.0
## The reference dummy's radius (cells) is the body of a 0.3-tile unit.
const UNIT_CELLS_PER_TILE := 2.6 / 0.3

var look: FireLookDef
var p: Dictionary          # the settings at the caster's mastery
var slot := -1
var origin := Vector2i.ZERO
var base_h := 0.0          # the ground height the fire sits on (levels)
var caster_id := -1
var hero := Vector2.ZERO   # the caster, local cells
var aim := 0.0             # radians, local (= world grid) angle
var aim_t := 0.0
var target_id := -1
var ct := 0                # steps since the cast
var f := 0                 # steps alive
var hold_steps := 0        # the stream: steps the caster keeps it on
var done_after := 0        # steps after which nothing more is emitted
var tail_steps := 180      # steps the fire is left to burn out before the slot is freed


## Where to put the window for a caster at `pos` aiming along `dir`: the caster near the
## corner behind it, as the reference places its hero (40 cells in, both ways).
static func place_origin(pos: Vector2, dir: Vector2) -> Vector2i:
	var want := Vector2(64, 64) - dir.normalized() * 56.6
	want = want.clamp(Vector2(12, 12), Vector2(116, 116))
	var corner := pos - want / CELLS_PER_TILE # the world point at local (0, 0)
	return Vector2i(roundi(corner.x + 0.5), roundi(corner.y + 0.5))


func to_local(world: Vector2) -> Vector2:
	return (world - Vector2(origin) + Vector2(0.5, 0.5)) * CELLS_PER_TILE


func to_world(local: Vector2) -> Vector2:
	return Vector2(origin) - Vector2(0.5, 0.5) + local / CELLS_PER_TILE


## One step of the timeline: add this step's sources to the sim.
func step(sim: FireSim) -> void:
	var dd := atan2(sin(aim_t - aim), cos(aim_t - aim))
	aim += clampf(dd, -0.08, 0.08)
	var ax := cos(aim)
	var ay := sin(aim)
	match look.kind:
		"stream":
			if ct < hold_steps:
				var wob := 0.04 * sin(f * 0.21) + 0.03 * sin(f * 0.53 + 1.0)
				sim.emit(slot, hero.x + ax * 6.5, hero.y + ay * 6.5, ax, ay, 1.25, float(p.temp), float(p.launch), wob)
	var params := p.duplicate()
	params["aim"] = Vector2(ax, ay)
	params["contact"] = 1 if look.kind in ["stream", "punch", "wheel", "breathfire", "jet"] else (2 if look.kind in ["kick", "combo"] else 0)
	sim.set_params(slot, params)
	ct += 1
	f += 1


func finished() -> bool:
	return ct > done_after + tail_steps
