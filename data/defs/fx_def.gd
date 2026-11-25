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
	if ribbon and path == Path.VERLET and feel != null:
		return hit_seconds() + maxf(feel.recovery_seconds, feel.impact_seconds) + feel.droplet_life
	if ribbon and path == Path.WHIP and extend_frames > 0:
		return (snap_frame + retract_frames) / maxf(fps, 0.001)
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


@export_group("Ribbon (a strip laid along a path)")
## Drawn as a strip of `sheet` repeated along a path from the caster's hand to its end
## (stance rework phase 4): the path is rebuilt by every player from the host's
## start, end, time and seed.
@export var ribbon: bool = false
## LINE: straight (streams, jets, cables, lightning). WHIP: a curve that reaches out,
## snaps and pulls back. FIGURE8: an infinity sign around the caster (Lightning
## Redirection). COIL: loops around the caster (the fire dragon). VERLET: a chain of
## points with Verlet physics pinned to the caster's hand, drawn in pixels from
## `feel` (the Water Whip since 2026-11-25; see VerletWhip).
enum Path { LINE, WHIP, FIGURE8, COIL, VERLET }
@export var path: Path = Path.LINE
## VERLET: every value that sets its feel (WhipFeelDef).
@export var feel: WhipFeelDef
## The part of `sheet` repeated along the path (art px; empty: the whole first frame).
## Cut to its most seamless span by tools/once/make_effect_sheets.py.
@export var strip_rect: Rect2 = Rect2()
## Pieces at its ends: the tip (a whip's), the head (a stream's front), the impact
## where it stops, and the burst at the hand.
@export var tip_fx: StringName = &""
@export var head_fx: StringName = &""
@export var impact_fx: StringName = &""
@export var hand_fx: StringName = &""
## Whole-pixel thickening (2 = pixel-doubled across, never smoothed).
@export var thickness: int = 1
## How fast the strip flows toward its end (art px per second; negative: toward
## the caster, Leeching Tide).
@export var scroll_speed: float = 0.0
## WHIP: how far the curve bends sideways at point-blank range (a fraction of its
## length); nearly straight at full range.
@export var curl: float = 0.0
## WHIP (at `fps`): frames reaching out, the frame it snaps on (the hit lands then:
## `hit_frame` is set to it at load), frames pulling back.
@export var extend_frames: int = 0
@export var snap_frame: int = 0
@export var retract_frames: int = 0
## Lightning: the path is re-jagged every `jag_seconds`, points pushed up to
## `jag_amount` tiles sideways (from the host's seed).
@export var jag_seconds: float = 0.0
@export var jag_amount: float = 0.0
## Colour the strip is multiplied by (Leeching Tide: darker blue).
@export var tint: Color = Color.WHITE

@export_group("Front (a leading edge across a hitbox)")
## Drawn as pieces at the tips of rays fanned across a cone or laid across a line,
## each ray stopping where the hitbox's terrain rule stops it (the host sends where).
@export var front: bool = false
@export var ray_spacing: float = 0.25
## Tiles per second.
@export var front_speed: float = 8.0
## Left behind the front, fading (its own piece; empty: none).
@export var trail_fx: StringName = &""
@export var trail_fade_seconds: float = 0.4
## Where terrain stops a ray.
@export var blocked_fx: StringName = &""
## Whole-pixel scale of the pieces (Air Blast: Gust's front, larger).
@export var piece_scale: int = 1
## Tiles the front passes over turn wet (Tidal Wave, Water Pulse).
@export var wets: bool = false

@export_group("Tiles and the screen (drawn in code)")
## WET: a glossy water film. BURNING: flames auto-tiled by neighbours. SAND: a sand
## tint (Sinkhole). RING: a shock ring lifting and shading the real tiles (Seismic
## Stomp). CRACKS: cracks shaded on the tiles, shaking. SANDSTORM: swirling sand over
## the area. SENSE: the Seismic Sense screen shader. RAIN: falling drops over the area.
enum TileMode { NONE, WET, BURNING, SAND, RING, CRACKS, SANDSTORM, SENSE, RAIN }
@export var tile_mode: TileMode = TileMode.NONE
@export var tile_tint: Color = Color(0, 0, 0, 0)
## How long it lasts when the event doesn't say (seconds).
@export var tile_seconds: float = 3.0


## The strip's rectangle in `sheet`.
func strip() -> Rect2:
	if strip_rect.size != Vector2.ZERO:
		return strip_rect
	return Rect2(Vector2.ZERO, Vector2(frame_size))


## A whip's or stream's length over time: 0 to 1 while reaching out, 1 at the snap,
## back to 0 while pulling back; streams are always 1.
func reach_at(since: float) -> float:
	if path != Path.WHIP or extend_frames <= 0:
		return 1.0
	var f := since * fps
	if f < extend_frames:
		return clampf(f / extend_frames, 0.0, 1.0)
	var back := f - snap_frame
	if back <= 0.0:
		return 1.0
	return clampf(1.0 - back / maxf(retract_frames, 1.0), 0.0, 1.0)
