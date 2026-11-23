class_name RibbonPath
extends RefCounted
## The shapes of ribbons (FxDef.ribbon; stance rework phase 4): paths in tile space,
## each point Vector3(x, y, lift in levels), rebuilt by every player from the
## host's data only (start, end, time, seed, reach), so everyone sees the same
## curve. Then cut into quads along the path, one strip copy at a time, for
## WorldView to draw in its back-to-front pass (each quad on the tile under it).

## Points per tile of path.
const DENSITY := 8.0
## Lift at the far end of a ribbon (a target's chest), in levels.
const END_LIFT := 1.0
## Quads per strip copy at most (so a copy bends with the path).
const SUBDIVIDE_PX := 16.0


## The path at `since` seconds: from `from` (the hand, lifted `hand_lift` levels)
## to `to`. `reach`: the ability's full range (a whip curls more when the target is
## close). `seed`: from the host (a whip's side, lightning's jags). `uncoil`: the
## dragon straightening toward `to` (0 coiled, 1 straight).
static func points(fx: FxDef, from: Vector2, to: Vector2, since: float, seed: int, reach: float,
		hand_lift: float, uncoil: float = 0.0) -> PackedVector3Array:
	match fx.path:
		FxDef.Path.WHIP:
			return _whip(fx, from, to, since, seed, reach, hand_lift)
		FxDef.Path.FIGURE8:
			return _jag(fx, _figure8(from, since, hand_lift), since, seed)
		FxDef.Path.COIL:
			return _coil(from, to, since, uncoil)
	var out := PackedVector3Array()
	var length := from.distance_to(to) * fx.reach_at(since)
	var dir := (to - from).normalized() if to.distance_to(from) > 0.001 else Vector2.RIGHT
	var n := maxi(2, ceili(length * DENSITY) + 1)
	for i in n:
		var k := float(i) / (n - 1)
		var p := from + dir * length * k
		out.append(Vector3(p.x, p.y, lerpf(hand_lift, END_LIFT, k)))
	return _jag(fx, out, since, seed)


## A whip: a cubic curve bending to one side (the seed picks which), deep when the
## target is close and nearly straight at full range; it reaches out over the
## extend frames, straightens as it snaps, and pulls back.
static func _whip(fx: FxDef, from: Vector2, to: Vector2, since: float, seed: int, reach: float,
		hand_lift: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var d := from.distance_to(to)
	if d < 0.01:
		return out
	var dir := (to - from) / d
	var nrm := Vector2(-dir.y, dir.x) * (1.0 if seed % 2 == 0 else -1.0)
	var k := fx.reach_at(since)
	var slack := fx.curl * clampf(1.0 - d / maxf(reach, 0.01), 0.0, 1.0) * d
	var bend := slack * (1.0 - 0.4 * k) # straightens a little as it reaches the target
	var p1 := from + dir * d / 3.0 + nrm * bend
	var p2 := from + dir * d * 2.0 / 3.0 - nrm * bend * 0.5
	var n := maxi(2, ceili(d * k * DENSITY) + 1)
	for i in n:
		var t := k * float(i) / (n - 1)
		var u := 1.0 - t
		var p := from * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + to * t * t * t
		out.append(Vector3(p.x, p.y, lerpf(hand_lift, END_LIFT, t)))
	return out


## Lightning Redirection: an infinity sign around the caster at chest height,
## drawn from its centre going up the screen first, traced over half a second.
static func _figure8(center: Vector2, since: float, hand_lift: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var right := Vector2(1, -1).normalized() * 0.9 # screen right, in tiles
	var up := Vector2(-1, -1).normalized() * 0.9 # screen up
	var span := TAU * clampf(since / 0.5, 0.05, 1.0)
	var n := 48
	for i in n + 1:
		var th := span * i / n
		var p := center + right * sin(th) + up * sin(th) * cos(th)
		out.append(Vector3(p.x, p.y, hand_lift + 0.4))
	return out


## The fire dragon: a coil of 1.5 turns around the caster, rising and falling as it
## turns; `uncoil` straightens it toward `to` (it leaves along the aim).
static func _coil(center: Vector2, to: Vector2, since: float, uncoil: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var dir := (to - center).normalized() if to.distance_to(center) > 0.001 else Vector2(1, 1).normalized()
	var spin := since * TAU * 0.35
	var n := 40
	for i in n + 1:
		var k := float(i) / n
		var th := spin + k * TAU * 1.5
		var coil := Vector3(center.x + cos(th) * 0.8, center.y + sin(th) * 0.8, 1.2 + 1.3 * k + 0.4 * sin(th * 2.0))
		var line_p := center + dir * (0.4 + (1.0 - k) * 3.0) # head first, toward the aim
		var straight := Vector3(line_p.x, line_p.y, 1.5)
		out.append(coil.lerp(straight, clampf(uncoil, 0.0, 1.0)))
	return out


## Lightning's jags: every point but the ends pushed sideways at random, re-rolled
## every `jag_seconds` from the host's seed (the same for everyone).
static func _jag(fx: FxDef, pts: PackedVector3Array, since: float, seed: int) -> PackedVector3Array:
	if fx.jag_seconds <= 0.0 or pts.size() < 3:
		return pts
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, int(since / fx.jag_seconds)])
	var out := pts.duplicate()
	for i in range(1, pts.size() - 1):
		var a := Vector2(pts[i - 1].x, pts[i - 1].y)
		var b := Vector2(pts[i + 1].x, pts[i + 1].y)
		var nrm := (b - a).orthogonal().normalized()
		var off := nrm * rng.randf_range(-1.0, 1.0) * fx.jag_amount
		out[i] = Vector3(pts[i].x + off.x, pts[i].y + off.y, pts[i].z + rng.randf_range(-0.5, 0.5) * fx.jag_amount * 4.0)
	return out


## Where a path point lands on screen, its ground at `base_h` levels.
static func screen(p: Vector3, base_h: float) -> Vector2:
	return Iso.to_screen(Vector2(p.x, p.y), base_h + p.z)


## The path cut into quads: [{"a", "b", "pa", "nb" (Vector3: this quad's ends and
## the points either side, for bending), "u0", "u1" (where in the strip), "pos"
## (tile-space middle, for its tile)}]. The strip repeats every strip-width art
## pixels on screen, scrolled by `scroll_speed`.
static func quads(fx: FxDef, pts: PackedVector3Array, since: float) -> Array:
	var out := []
	if pts.size() < 2:
		return out
	# Screen lengths (the ground at 0: heights along one ribbon barely change).
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + screen(pts[i], 0.0).distance_to(screen(pts[i - 1], 0.0)))
	var total := cum[cum.size() - 1]
	var strip_px := fx.strip().size.x * PixelCamera.ART_SCALE
	if total < 1.0 or strip_px < 1.0:
		return out
	var parts := ceili(strip_px / SUBDIVIDE_PX)
	var step := strip_px / parts
	var phase := fposmod(-fx.scroll_speed * PixelCamera.ART_SCALE * since, strip_px)
	# Cut points: every `step` along the strip copies (offset by the scroll), plus the ends.
	var cuts := PackedFloat32Array([0.0])
	var s := fposmod(-phase, step)
	if s < 0.5:
		s += step
	while s < total - 0.5:
		cuts.append(s)
		s += step
	cuts.append(total)
	var at := func(dist: float) -> Vector3:
		var j := cum.bsearch(dist)
		j = clampi(j, 1, cum.size() - 1)
		var seg := cum[j] - cum[j - 1]
		var k := (dist - cum[j - 1]) / seg if seg > 0.0 else 0.0
		return pts[j - 1].lerp(pts[j], clampf(k, 0.0, 1.0))
	for i in range(cuts.size() - 1):
		var d0 := cuts[i]
		var d1 := cuts[i + 1]
		var u0 := fposmod(d0 + phase, strip_px) / strip_px
		var u1 := u0 + (d1 - d0) / strip_px
		var a: Vector3 = at.call(d0)
		var b: Vector3 = at.call(d1)
		var mid := (a + b) * 0.5
		out.append({"a": a, "b": b, "pa": at.call(maxf(d0 - 2.0, 0.0)), "nb": at.call(minf(d1 + 2.0, total)),
				"u0": u0, "u1": minf(u1, 1.0), "pos": Vector2(mid.x, mid.y)})
	return out
