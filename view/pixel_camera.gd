class_name PixelCamera
extends Camera2D
## A camera for pixel art. Tile art is drawn at ART_SCALE world units per art
## pixel, the camera zooms, and the window stretches the whole canvas (1.5x on a
## 1080p screen). The camera only uses zooms where all of that together shows
## every art pixel as a whole number of screen pixels (its "art scale": 1x, 2x,
## 3x...), and it moves by whole screen pixels.

## World units per art pixel (32 px tile art drawn on the 64 px wide grid).
const ART_SCALE := 2.0
## The zoom the camera starts near (in world units, as before tiles).
const DEFAULT_ZOOM := 1.5
## Zoom limits in world units; the art scale stays within them where it can.
const MIN_ZOOM := 0.4
const MAX_ZOOM := 2.5
## How fast the camera catches up with its target (like Camera2D smoothing).
const FOLLOW_SPEED := 8.0

## Screen pixels per art pixel.
var art_scale := 0
## Tests set this to fix the window stretch (0 = read it from the window).
var stretch_override := 0.0
## Where the camera is heading, unsnapped (smoothing works on this).
var _smooth := Vector2.ZERO
var _placed := false


func _ready() -> void:
	_apply(default_art_scale(stretch()))


## Moves toward `target` (smoothly unless `snap_now`) and snaps to the pixel grid.
func follow(target: Vector2, delta: float, snap_now: bool = false) -> void:
	if snap_now or not _placed:
		_smooth = target
		_placed = true
	else:
		_smooth = _smooth.lerp(target, 1.0 - exp(-FOLLOW_SPEED * delta))
	# The window may have been resized: keep a whole art scale for the new stretch.
	var s := stretch()
	if not is_equal_approx(zoom.x, zoom_for(art_scale, s)):
		_apply(nearest_art_scale(zoom.x, s))
	position = snapped_position(_smooth, zoom.x * s)


## One zoom step in (`direction` > 0) or out: the next whole art scale.
func step_zoom(direction: int) -> void:
	var s := stretch()
	var next := art_scale + signi(direction)
	if next < 1 or zoom_for(next, s) > MAX_ZOOM and direction > 0 or zoom_for(next, s) < MIN_ZOOM and direction < 0:
		return
	_apply(next)
	position = snapped_position(_smooth, zoom.x * s)


func _apply(scale_px: int) -> void:
	art_scale = maxi(scale_px, 1)
	var z := zoom_for(art_scale, stretch())
	zoom = Vector2(z, z)


## How much the window stretches the canvas (1 when not in a window).
func stretch() -> float:
	if stretch_override > 0.0:
		return stretch_override
	if not is_inside_tree():
		return 1.0
	var s := get_viewport().get_final_transform().get_scale().x
	return s if s > 0.0 else 1.0


## The camera zoom that shows art at `scale_px` screen pixels per art pixel.
static func zoom_for(scale_px: int, window_stretch: float) -> float:
	return scale_px / (ART_SCALE * window_stretch)


## The whole art scale closest to `zoom_level` (at least 1).
static func nearest_art_scale(zoom_level: float, window_stretch: float) -> int:
	return maxi(roundi(zoom_level * ART_SCALE * window_stretch), 1)


## The starting art scale: as close to DEFAULT_ZOOM as a whole scale allows,
## rounding down (3x at 1280x720, 4x at 1920x1080).
static func default_art_scale(window_stretch: float) -> int:
	return maxi(floori(DEFAULT_ZOOM * ART_SCALE * window_stretch + 0.001), 1)


## `pos` rounded so the camera sits on a whole screen pixel when world units
## are drawn at `screen_scale` screen pixels each.
static func snapped_position(pos: Vector2, screen_scale: float) -> Vector2:
	return (pos * screen_scale).round() / screen_scale
