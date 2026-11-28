class_name FrontRays
extends RefCounted
## The rays a front is drawn along (FxDef.front; stance rework phase 4), computed by
## the host from the ability's own hitbox and sent to every player: fanned across a
## cone, or laid side by side across a line's width, `spacing` tiles apart, each
## stopping where the hitbox's terrain rule stops a shot (Hitbox.clear_distance),
## so nothing is drawn past what the hitbox can hit. A pillar in a cone leaves a gap.


## [[origin x, origin y, dir x, dir y, stop, length], ...] for a front from `origin` toward
## `dir`. Cones: `angle_deg` wide, `reach` long; lines: `width` wide, `reach` long
## (`angle_deg` 0).
static func rays(grid: GridModel, origin: Vector2, dir: Vector2, reach: float, angle_deg: float, width: float,
		tolerance: float, spacing: float) -> Array:
	var out := []
	if angle_deg > 0.0:
		var half := deg_to_rad(angle_deg) * 0.5
		var n := maxi(2, ceili(deg_to_rad(angle_deg) * reach / maxf(spacing, 0.05)) + 1)
		for i in n:
			var d := dir.rotated(lerpf(-half, half, float(i) / (n - 1)))
			out.append([origin.x, origin.y, d.x, d.y, Hitbox.clear_distance(grid, origin, d, reach, tolerance), reach])
	else:
		var side := dir.orthogonal()
		var n := maxi(1, floori(width / maxf(spacing, 0.05)) + 1)
		for i in n:
			var off := (float(i) - (n - 1) * 0.5) * spacing
			var o := origin + side * off
			out.append([o.x, o.y, dir.x, dir.y, Hitbox.clear_distance(grid, o, dir, reach, tolerance)])
	return out


## The tiles a front's rays pass over up to `travel` tiles (wet ground behind a wave).
static func tiles_crossed(rays: Array, travel: float) -> Array:
	var seen := {}
	for r in rays:
		var o := Vector2(r[0], r[1])
		var d := Vector2(r[2], r[3])
		var end := minf(float(r[4]), travel)
		var s := 0.0
		while s <= end:
			seen[MoveState.tile_of(o + d * s)] = true
			s += 0.25
	return seen.keys()
