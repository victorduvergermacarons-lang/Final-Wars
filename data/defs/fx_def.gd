class_name FxDef
extends Resource
## An effect animation drawn in the world (content/effects/<id>.tres; sheets in
## assets/effects/, cut by tools/once/make_effect_sheets.py): one view, drawn
## pointing right, rotated to the direction it is sent. Played from host times
## (an "fx" event, or state in the snapshot), so every player sees the same frame.

## Where it sits: at the caster (toward its target or aim) or at a point (a landing).
enum Anchor { CASTER, POINT }

@export var id: StringName = &""
@export var sheet: Texture2D
@export var frame_size: Vector2i = Vector2i(64, 64)
@export var frames: int = 9
@export var fps: float = 18.0
@export var loop: bool = false
## The art pixel placed on the anchor (e.g. the lash's root at the hand).
@export var pivot: Vector2 = Vector2(32, 32)
@export var anchor: Anchor = Anchor.CASTER
## How far from the anchor along the direction it points, in tiles.
@export var forward_tiles: float = 0.0
## Height above the ground, in levels (1 = a block; a hero's chest is about 1).
@export var height_levels: float = 1.0
## Turned toward where it is sent (else drawn as it is, e.g. an impact).
@export var rotate: bool = true
## Opacity (air effects are drawn solid: about 60% makes them see-through).
@export_range(0.0, 1.0) var alpha: float = 1.0
## The frame where it strikes (Water Whip's snap): an ability whose
## AbilityDef.release_delay_from is "fx" lands its hit this long after the release.
## -1: none.
@export var hit_frame: int = -1
## A still played once: how long it shows (0 = frames / fps).
@export var hold_seconds: float = 0.0
## Fades out over the last 40% of its time (stills).
@export var fade_out: bool = false

@export_group("Projectiles (pre-rotated)")
## The screen direction the art points, in degrees (0 = right, 90 = down the
## screen). Turned by (flight angle - this) when `rotate` is on.
@export var drawn_angle: float = 0.0
## The art turned to `rot_steps` angles around the pivot without blurring
## (RotSprite: tools/once/make_effect_sheets.py), one cell per step from
## `drawn_angle`, the pivot at each cell's centre. Without it the art is turned
## with nearest sampling.
@export var rot_sheet: Texture2D
@export var rot_steps: int = 0

@export_group("Held around a hero (stance looks)")
## How a still moves, in code: SPIN turns it (flat ones turn on the ground), BOB
## lifts it up and down, ORBIT circles it around the hero at `orbit_tiles`, FLICKER
## mirrors it now and then (flames), SWAY rocks it a little either way.
## PULSE breathes its opacity (70-100%), DROP falls from `motion_amount` levels
## above onto its place over the first 40% of its time (a dropped boulder).
enum Motion { NONE, SPIN, BOB, ORBIT, FLICKER, SWAY, PULSE, DROP }
@export var motion: Motion = Motion.NONE
## Cycles per second (turns for SPIN and ORBIT).
@export var motion_hz: float = 0.5
## BOB: levels; SWAY: radians.
@export var motion_amount: float = 0.1
@export var orbit_tiles: float = 0.5
## Drawn lying on the ground (half as tall on screen, like a tile).
@export var flat: bool = false
## The part above the pivot is drawn behind the hero, the rest in front (a ring
## around them).
@export var split: bool = false
## Drawn wholly behind the hero.
@export var behind: bool = false


func duration() -> float:
	if frames <= 1 and hold_seconds > 0.0:
		return hold_seconds
	return frames / maxf(fps, 0.001)


## The frame shown `since` seconds after it started (-1: over).
func frame_at(since: float) -> int:
	if since < 0.0:
		return -1
	var f := floori(since * fps + 0.0001)
	if loop:
		return f % maxi(frames, 1)
	if frames <= 1 and hold_seconds > 0.0:
		return 0 if since < hold_seconds else -1
	return f if f < frames else -1


## Its opacity `since` seconds after it started (fading out at the end).
func alpha_at(since: float) -> float:
	if not fade_out or loop:
		return alpha
	var d := duration()
	return alpha * clampf((d - since) / maxf(d * 0.4, 0.001), 0.0, 1.0)


func hit_seconds() -> float:
	return hit_frame / maxf(fps, 0.001) if hit_frame >= 0 else 0.0
