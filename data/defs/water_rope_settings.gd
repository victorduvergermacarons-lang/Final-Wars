class_name WaterRopeSettings
extends Resource
## Every constant of the Water stance 1 rope and the Water Whip (2026-11-26), under the
## names of docs/reference/water_whip_reference.html (the source of truth). Distances in
## reference pixels (× WATER_SCALE to art pixels), times in 60 fps frames. Tune in
## content/effects/water_rope_settings.tres.

@export_group("Scale and view")
## Art pixels per reference pixel (the reference hero is ~36 px tall, ours ~34 art px). Every distance goes through it; times don't.
@export var WATER_SCALE: float = 1.0
## Screen y per ground y (the reference used 0.4; our iso view is 2:1, so 0.5).
@export var K: float = 0.5
## Height of the hips above the feet, reference px: where pouch water comes out (not in the reference).
@export var HIP_Z: float = 12.0
@export_group("Orbit (Water stance 1)")
## Orbit height (waist).
@export var ZW: float = 16.0
## Orbit radius.
@export var ORB: float = 24.0
## Points in a full rope.
@export var NMAX: int = 24
## Link length.
@export var SEG: float = 4.4
## Seconds per loop.
@export var ORBIT_LAP: float = 3.0
## Ripple height along the orbit.
@export var WAVE_AMP: float = 2.0
## Ripple: radians per point.
@export var WAVE_LEN: float = 0.3
## Ripple: radians per frame.
@export var WAVE_SPEED: float = 0.05
## Idle links push back this hard when compressed (they always pull when stretched).
@export var IDLE_PUSH: float = 0.3
## Frames to blend into the idle springs.
@export var IDLE_BLEND: int = 40
## Idle: one point added every this many frames until NMAX.
@export var REFILL_EVERY: int = 8
## Idle spring toward the orbit spot.
@export var IDLE_SPRING: float = 0.08
## Spin spring toward the orbit spot.
@export var SPIN_SPRING: float = 0.22
## Idle: how fast the orbit speed eases back.
@export var IDLE_EASE: float = 0.03
## Spin: how fast the orbit speeds up.
@export var SPIN_EASE: float = 0.25
## Velocity kept per frame while idle or spinning.
@export var IDLE_DAMP: float = 0.86
## Idle and return: one drop falls every this many frames.
@export var DRIP_EVERY: int = 20
## Forming the orbit (entering the stance): a point every this many frames (not in the reference).
@export var FORM_EVERY: int = 3
@export_group("Throw")
## Frames from cast to impact (0.5 s). Gameplay uses its own 0.5 s.
@export var HIT: int = 30
## Comfortable throw speed, px per frame.
@export var VREF: float = 4.5
## Shortest flight, frames.
@export var TF_MIN: int = 12
## Longest pull-back.
@export var PULL_MAX: float = 55.0
## Orbit speed while spinning, radians per frame.
@export var W_SPIN: float = 0.16
## Impact height.
@export var TARGET_Z: float = 10.0
## Velocity kept per frame in fly, pour and fall.
@export var FLY_DAMP: float = 0.93
## Link passes per frame.
@export var ITERATIONS: int = 8
@export_group("Impact")
## The rope breaks when this point arrives.
@export var POUR_POINTS: int = 12
## How hard pouring points follow the path.
@export var POUR_BLEND: float = 0.6
## Drops per point breaking off.
@export var POUR_SPLASH: int = 3
## Gravity on falling rope points, px per frame squared.
@export var GRAV: float = 0.11
@export_group("Fall, regroup, rise")
## Return delay, frames (slider).
@export var RETURN_AT: int = 0
## Regroup after at most this many frames of falling.
@export var FALL_TIME_MAX: int = 8
## Points farther than this from the chain soak in…
@export var STRAY_GAP: float = 12.0
## …unless the chain would keep fewer than this.
@export var MIN_KEEP: int = 8
## Frames a soaked puddle lasts.
@export var SOAK_TIME: int = 110
## Rise spring.
@export var RISE_K: float = 0.016
## Frames for the rise spring to build up.
@export var RISE_RAMP: int = 35
## Rise: share of the way the arch drifts toward the hero per frame.
@export var RISE_DRIFT: float = 0.008
## Rise: it drifts no closer than this.
@export var RISE_STOP: float = 40.0
## Rise: a point this close to its spot counts as near.
@export var RECONNECT: float = 6.0
@export_group("Return")
## Max return speed, px per frame (slider).
@export var MAX_SPEED: float = 4.0
## Cruise = this × max speed.
@export var RET_CRUISE_RATIO: float = 0.75
## Fastest a loose point chases.
@export var CHASE_MAX: float = 8.0
## A half-length return goes at this share of full speed (slider).
@export var HALF_TRIP: float = 0.4
## Return length that goes at full speed.
@export var DIST_REF: float = 140.0
## Slowest share of full speed.
@export var SPEED_FLOOR: float = 0.15
## Starts at this share of cruise…
@export var RET_START: float = 0.3
## …reaching cruise over this share of the way.
@export var RET_ACCEL: float = 0.3333333
## Last share of the way eases toward the entry speed.
@export var RET_DECEL: float = 0.15
## Entry speed = this × cruise (no braking before the mark).
@export var ENTRY_KEEP: float = 1.0
## First control point: this share of the distance, toward the left point.
@export var CTRL_START: float = 0.4
## Second control point: this share back from the entry along the cast.
@export var CTRL_END: float = 0.4
## The return curve rises this much in the middle.
@export var ARC_LIFT: float = 10.0
## Samples along the return curve.
@export var PATH_SAMPLES: int = 200
## Velocity kept per frame while rising, returning, wrapping.
@export var RET_DRAG: float = 0.9
## Loose points chase the point ahead this hard.
@export var CHASE_K: float = 0.08
## The last attached point gets this many times the drag.
@export var CHASED_DRAG_MULT: float = 2.0
## A loose point's speed limit grows this much per px of gap.
@export var CHASE_GAIN: float = 0.12
## Points closer than this × link join.
@export var LINK_REACH: float = 1.5
## Frames for a new link to tighten.
@export var LINK_FADE: int = 20
## Per-pass correction cap = this × max speed / 1.6.
@export var CAP_STEP: float = 0.2
## From this share of the way home every link is forced.
@export var FORCE_AT: float = 0.5
## If the rope isn't whole by here…
@export var HOLD_AT: float = 0.7
## …the front eases to this share of speed.
@export var HOLD_SPEED: float = 0.35
## How fast it eases.
@export var HOLD_EASE: float = 0.1
## It can't pass this share of the way until whole.
@export var ENTRY_GUARD: float = 0.98
## Attached points follow the front's path this hard.
@export var FOLLOW_K: float = 0.25
## Past the entry they join their orbit spot this hard.
@export var JOIN_K: float = 0.12
## Return: a missing point comes out of the hips every this many frames (not in the reference).
@export var REBUILD_EVERY: int = 4
@export_group("Wrap (entering the orbit)")
## Orbit brake per frame (slider: 95% in 1.6 s).
@export var WRAP_EASE: float = 0.0307
## The front's spring onto the orbit.
@export var WRAP_LEAD: float = 0.05
## Frames for links to tighten back to idle.
@export var WRAP_TIGHT: int = 60
## Frames after the tail crosses the entry before idle.
@export var WRAP_SETTLE: int = 30
@export_group("Drawing")
## Added to every slice's radius.
@export var BODY_GROW: float = 0.2
## A slice facing the sun more than this gets the second rows.
@export var FACE_T: float = 0.75
## Highlight only where the radius is over this.
@export var HI_MIN_R: float = 1.6
## Second highlight row over this.
@export var HI2_MIN_R: float = 2.1
## Second dark row over this.
@export var SHADE2_MIN_R: float = 1.6
## Sideways ripple of the drawn slices, px.
@export var RIPPLE_AMP: float = 0.7
## Its wavelength, px.
@export var RIPPLE_LEN: float = 12.0
## Its speed, radians per frame.
@export var RIPPLE_SPEED: float = 0.12
## Splash drops: sideways scatter.
@export var SPLASH_SPREAD: float = 1.6
## Splash drops: upward kick.
@export var SPLASH_UP: float = 1.5
## Splash drops: velocity kept on the ground plane per frame.
@export var DROP_DRAG: float = 0.9
## Splash drops: vertical velocity kept per frame.
@export var DROP_ZDRAG: float = 0.92
## Splash drops: gravity.
@export var DROP_GRAV: float = 0.12
## Ground shadows darken what they fall on by this share (0.3 = 30% darker: black at
## 30% over the ground), each screen pixel at most once (2026-11-28).
@export var SHADOW_DARKEN: float = 0.3

@export_group("Stance 2 hoop (water_stance2_demo_approved.html)")
## Hoop radius and height (reference px), seconds per lap, thickness, breathing.
@export var HR: float = 22.0
@export var HZ: float = 20.0
@export var LAP2: float = 4.0
@export var THICK: float = 1.5
@export var BREATH: float = 2.0
@export var BREATH_T: float = 4.0
@export var HOOP_BASE_R: float = 2.0
@export var HOOP_RIPPLE_AMP: float = 0.8
@export var HOOP_RIPPLE_LEN: float = 14.0
@export var HOOP_RIPPLE_SPEED: float = 0.08
@export var HOOP_TILT: float = 1.5
@export var HOOP_TILT_SPEED: float = 0.012
## Frames: rope to hoop (and back), the hoop's closing link fading in.
@export var ENTER_T: int = 48
@export var WRAP_FADE: int = 20
## The hoop closes once the blend reaches this and every point is there.
@export var CLOSE_AT: float = 0.95
## How hard each point follows its place on the hoop (the reference's FOLLOW_K).
@export var HOOP_FOLLOW: float = 0.12
@export_group("Healing Touch (healing_touch_demo.html)")
## Frames from the cast to the heal (the lead reaches the top of the helix).
@export var HEAL_T: int = 72
@export var LOOPS_SELF: float = 2.0
@export var LOOPS_FAR: float = 1.0
## Loops scale from LOOPS_SELF at 0 to LOOPS_FAR at this distance (px).
@export var FAR_REF: float = 140.0
## Helix radius round the body, at its top, and where it starts narrowing (share).
@export var WRAP_R: float = 10.0
@export var TOP_R: float = 3.0
@export var NARROW_AT: float = 0.55
## Helix from WAIST × the target's height to its height + TOP_LIFT (px).
@export var WAIST: float = 0.45
@export var TOP_LIFT: float = 4.0
## A hero's height (px), the helix's target.
@export var HERO_H: float = 36.0
@export var HEAL_FOLLOW: float = 0.35
@export var HEAL_DRAG: float = 0.8
## Lead speed: a Hermite curve from the orbit speed (at most M0_MAX) to END_SLOPE.
@export var END_SLOPE: float = 0.6
@export var M0_MAX: float = 2.5
## The travel arc: leaving control 0.4 × distance (at most 20), arriving 0.35 ×
## distance, lifted 4 + 0.05 × distance.
@export var TRAVEL_CTRL: float = 0.4
@export var TRAVEL_CTRL_MAX: float = 20.0
@export var ARRIVE_CTRL: float = 0.35
@export var LIFT_BASE: float = 4.0
@export var LIFT_PER: float = 0.05
## Mist: per point at the top; frames it lasts (+ up to MIST_LIFE_RND).
@export var MIST_PER: int = 3
@export var MIST_LIFE: int = 50
@export var MIST_LIFE_RND: int = 40

@export_group("Water Shield (water_shield_demo_approved.html)")
## Frames from the cast to the shield going up.
@export var SH_T: int = 48
## Bubble radius (px) round a 26 px dummy; a hero's is × HERO_H / 26.
@export var SH_R: float = 15.0
@export var SH_DUMMY_H: float = 26.0
## Spin speed (px per frame) and wind drift (rad per frame of spin).
@export var VS: float = 2.0
@export var PRECESS: float = 0.025
## The loop's tilt from horizontal (rad).
@export var TILT: float = 0.45
## Stretch: to LEN_MULT × its length over GROW_T frames, thinning to WIDTH_MULT.
@export var GROW_T: int = 240
@export var LEN_MULT: float = 2.0
@export var WIDTH_MULT: float = 0.67
@export var SH_FOLLOW: float = 0.35
@export var SH_DRAG: float = 0.8
@export var M_MAX: float = 3.0
## Entry choice: the spin lined up with the approach, minus this × the distance.
@export var ENTRY_DIST_W: float = 0.03
## The turn-in arc (radius px; done within this angle).
@export var TURN_R: float = 10.0
@export var TURN_OK: float = 0.35
## The way home: a self-cast enters 0.8 rad ahead; others bow 0.3 × distance left.
@export var SELF_HOME_AHEAD: float = 0.8
@export var ARC_BEND: float = 0.3
@export var LEAVE_CTRL: float = 0.3
@export var MID_CTRL: float = 0.25
## Broken: the burst outward, then falling, then soaking in.
@export var POP_OUT: float = 1.3
@export var POP_KEEP: float = 0.4
@export var POP_UP: float = 0.6
@export var POP_SPLASH_EVERY: int = 3
@export var POP_FALL: int = 34
@export var POP_DAMP: float = 0.93
@export var BREAK_AWAY: float = 0.8
## Below these shares of the shield left: strained (drift ×2, wobble), cracking (gaps).
@export var STRAIN_AT: float = 0.5
@export var CRACK_AT: float = 0.25
## A hit: dents within DENT_R px pushed DENT_PUSH, fading ×DENT_DECAY a frame;
## ripple ×RIPPLE_HIT fading ×RIPPLE_DECAY; spin ×KICK fading ×KICK_DECAY.
@export var DENT_R: float = 8.0
@export var DENT_PUSH: float = 2.0
@export var DENT_DECAY: float = 0.85
@export var RIPPLE_HIT: float = 3.0
@export var RIPPLE_DECAY: float = 0.9
@export var KICK: float = 1.3
@export var KICK_DECAY: float = 0.93
@export var SHED_EASE: float = 0.2
@export var WOBBLE: float = 1.5
@export var GAP_EVERY: int = 10
@export var GAP_LIFE: int = 8
@export var GAP_HOLD: float = 0.5
@export var GAP_HOLD_EASE: float = 0.15
@export var GAP_STR: float = 0.6
@export var HOME_THICKEN: float = 0.08
@export var MIN_HOME_PTS: int = 4

@export_group("Frost Shard (frost_shard_demo.html)")
## Points that break off (the user's piece size, 2026-11-28; the demo had 5).
@export var SHARD_PIECE: int = 4
## Bulge outward and lean toward the target over the first frames (visual only).
@export var SHARD_BULGE: float = 6.0
@export var SHARD_LEAN: float = 3.0
@export var SHARD_WINDUP: int = 9
## Frames for the water to pull together into the shard; drawn as water until 75%.
@export var SHARD_FREEZE: int = 9

@export_group("Leeching Tide (leeching_tide_demo.html)")
## Frames to reach the target (the hoop opens and arcs out).
@export var REACH_T: int = 24
## Stream speed (px per frame) and its bow toward the caster's left (× distance).
@export var FLOW_V: float = 1.5
@export var STREAM_BEND: float = 0.3
## Where it latches: this far in front of the target, at this height.
@export var ATTACH_R: float = 4.0
@export var ATTACH_Z: float = 13.0
@export var REACH_FOLLOW: float = 0.35
## The stream's spring grows from LATCH_K0 to LATCH_K1 over LATCH_BLEND frames.
@export var LATCH_K0: float = 0.25
@export var LATCH_K1: float = 0.6
@export var LATCH_BLEND: int = 14
@export var STREAM_LIFT: float = 6.0
@export var END_CTRL: float = 0.4
## Past the entry it follows the hoop, blended in over this many px.
@export var HOOP_BLEND_IN: float = 20.0
## Leeched water fades back to blue over 2 s (per frame).
@export var DARK_FADE: float = 1.0 / 120.0
## The leech tint (approved with the demo).
@export var LOUT: Color = Color("082A4D")
@export var LBODY: Color = Color("2A5F99")
@export var LHI: Color = Color("6E9BCF")
@export var LDROP: Color = Color("4A78AC")

## Frames between points joining the hoop (the reference's ADD_EVERY).
@export var HOOP_ADD_EVERY: int = 4
@export_group("Palette")
## Outline and shade.
@export var OUT: Color = Color("0C447C")
## Body.
@export var BODY: Color = Color("378ADD")
## Highlight.
@export var HI: Color = Color("9DC5EE")
## Droplets.
@export var DROP: Color = Color("85B7EB")
## Shadows on the ground.
@export var SHAD: Color = Color("B4B2A9")
## The sun, top left, on screen.
@export var SUN: Vector2 = Vector2(-0.70710678, -0.70710678)


## Orbit speed while idle, radians per frame.
func w_idle() -> float:
	return TAU / (ORBIT_LAP * 60.0)


## Angle between neighbouring orbit spots (arc = link × 0.95).
func ang() -> float:
	return SEG / ORB * 0.95


## Arc length between orbit spots.
func sp() -> float:
	return ang() * ORB


func ret_speed_cruise() -> float:
	return MAX_SPEED * RET_CRUISE_RATIO


## Orbit brake time (seconds to 95%) to WRAP_EASE and back (the reference's slider).
static func brake_ease(seconds: float) -> float:
	return 1.0 - pow(0.05, 1.0 / (seconds * 60.0))
