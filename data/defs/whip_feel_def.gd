class_name WhipFeelDef
extends Resource
## Every value that sets how the Water Whip feels (2026-11-25, user brief: a
## code-drawn Verlet whip that floats and flows like water bending, stiffening for a
## split second to crack on the strike). One file to tune:
## content/effects/water_whip_feel.tres. Lengths are in art pixels (one art pixel =
## PixelCamera.ART_SCALE world units), times in seconds.

@export_group("Chain")
## Points along the whip; point 0 is pinned to the hero's hand.
@export_range(4, 40) var point_count: int = 18
## How much longer than hand-to-target the whip reaches at full stretch (1 = exactly).
@export var reach_factor: float = 1.04
## Physics steps per second (fixed, so every player gets the same motion).
@export var steps_per_second: float = 120.0

@export_group("Physics")
## Pull downward, in art px per second². Near 0: it hovers instead of hanging.
@export var gravity: float = 6.0
## Share of speed lost each step (0 = keeps sliding, 1 = stops dead). High: glides after the hand.
@export_range(0.0, 1.0) var drag: float = 0.16
## How hard each link holds its length (0 = elastic water, 1 = rigid). Low: loose links.
@export_range(0.0, 1.0) var stiffness: float = 0.35
## Link solving passes per step (more = less stretch).
@export_range(1, 20) var iterations: int = 3
## How strongly each point is drawn toward the shape the bender wills (a line to the
## target with the wave on it), per step. Low: lazy and fluid; high: precise.
@export_range(0.0, 1.0) var follow: float = 0.08

@export_group("Strike (the crack)")
## For this long around the snap the whip stiffens and lashes out.
@export var strike_stiff_seconds: float = 0.08
@export_range(0.0, 1.0) var strike_stiffness: float = 0.95
@export_range(1, 30) var strike_iterations: int = 10
@export_range(0.0, 1.0) var strike_follow: float = 0.35
## The tip's kick forward at the snap, in art px per second.
@export var crack_speed: float = 260.0

@export_group("Reach and recovery")
## Share of its full length the whip starts at when it launches.
@export_range(0.0, 1.0) var launch_length: float = 0.2
## After the snap: how long it takes to pull back into the hand and vanish.
@export var recovery_seconds: float = 0.35
## Share of its full length it has shrunk back to when it vanishes.
@export_range(0.0, 1.0) var recovery_length: float = 0.1

@export_group("Wave (it sways even held still)")
## Wave cycles per second running along the whip.
@export var wave_speed: float = 1.4
## Sideways size of the wave at the tip, art px (none at the hand).
@export var wave_size: float = 5.0
## Waves along the whip's length.
@export var wave_cycles: float = 1.25

@export_group("Width")
## Thickness at the hand and at the tip, art px (the 1 px outline comes on top).
@export var width_hand: float = 4.0
@export var width_tip: float = 1.0
## How fast it thins toward the tip (1 = evenly, 2 = stays thick longer).
@export var taper_power: float = 1.4
## Swelling and thinning as it moves: share of the width, and how fast.
@export_range(0.0, 1.0) var swell_amount: float = 0.22
@export var swell_speed: float = 3.0
@export var swell_cycles: float = 2.0

@export_group("Droplets")
## The tip must move this fast (art px per second) to shed droplets.
@export var droplet_speed_threshold: float = 120.0
## Droplets per second while it does (at the threshold; more the faster it goes).
@export var droplet_rate: float = 40.0
## Most droplets alive at once (a fixed pool).
@export_range(0, 64) var droplet_pool: int = 32
## They float this long, then fall.
@export var droplet_float_seconds: float = 0.18
@export var droplet_fall_gravity: float = 220.0
@export var droplet_life: float = 0.6
## Share of the tip's speed a droplet leaves with.
@export_range(0.0, 1.0) var droplet_carry: float = 0.25
## Droplets thrown out by the impact.
@export_range(0, 32) var impact_droplets: int = 10

@export_group("Colours (only these four)")
@export var outline_color: Color = Color("031143")
@export var body_color: Color = Color("0A97F5")
@export var highlight_color: Color = Color("52D2F9")
@export var droplet_color: Color = Color("4CCBF9")

@export_group("Hand-drawn art (drawn on top when the file exists)")
## The tip, the impact splash and a droplet. Effect art never includes ground,
## bases or people. Missing: simple code placeholders.
@export_file("*.png") var tip_art: String = "res://assets/effects/water_whip/tip.png"
@export_file("*.png") var impact_art: String = "res://assets/effects/water_whip/impact.png"
@export_file("*.png") var droplet_art: String = "res://assets/effects/water_whip/droplet.png"
## How long the impact splash shows.
@export var impact_seconds: float = 0.3


## The art at `path` if it's there, else null (the placeholder is drawn instead).
static func art(path: String) -> Texture2D:
	return load(path) if path != "" and ResourceLoader.exists(path) else null
