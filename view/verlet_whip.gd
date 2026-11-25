class_name VerletWhip
extends RefCounted
## The Water Whip drawn in code (2026-11-25, user brief): a chain of points with
## Verlet physics, point 0 pinned to the hero's hand every frame, drawn as whole
## art pixels in four colours. Every value that sets its feel is in a WhipFeelDef
## (content/effects/water_whip_feel.tres).
##
## Water bending, not a rope: gravity nearly off (it hovers), loose links and plenty
## of drag (it glides after the hand), a slow wave running along it (it sways even
## held still), and for a split second at the strike it stiffens and cracks.
## Each point is drawn a little toward the shape the bender wills (a line from the
## hand to the target with the wave on it), so it reaches where it should whatever
## the physics does. The host decides nothing here: the hit comes from the ability
## (its release delay = the effect's hit frame), this is only how it looks.
##
## Space: screen art pixels (world screen position / PixelCamera.ART_SCALE), so
## gravity is screen-down and the hero walking drags the chain along.

var feel: WhipFeelDef
## The hit lands this long after the effect starts (FxDef.hit_seconds): the snap.
var hit_seconds := 0.29
var pos := PackedVector2Array()
var prev := PackedVector2Array()
## Seconds since the effect started, as far as it has been simulated.
var time := 0.0
var started := false
var cracked := false
var hand := Vector2.ZERO
var target := Vector2.ZERO
## The wave's phase and side, from the host's seed (the same on every screen).
var phase := 0.0
var side := 1.0
## Droplets (a fixed pool): position, velocity, age; age < 0 = free.
var drop_pos := PackedVector2Array()
var drop_vel := PackedVector2Array()
var drop_age := PackedFloat32Array()
var _drop_debt := 0.0
var _rng := RandomNumberGenerator.new()
## When the impact splash started (seconds since the effect started), or -1.
var impact_at := -1.0
## What `raster` last made: segment -> [pixels (PackedVector2Array), colours
## (PackedColorArray)], whole art pixels.
var raster := {}


func _init(feel_def: WhipFeelDef, hit: float, seed: int) -> void:
	feel = feel_def
	hit_seconds = hit
	_rng.seed = seed
	phase = float(seed % 997) / 997.0 * TAU
	side = 1.0 if seed % 2 == 0 else -1.0
	drop_pos.resize(feel.droplet_pool)
	drop_vel.resize(feel.droplet_pool)
	drop_age.resize(feel.droplet_pool)
	drop_age.fill(-1.0)


## Whether the whip itself is out (droplets may outlive it).
func body_visible() -> bool:
	return started and time <= hit_seconds + feel.recovery_seconds


## Whether anything is left to draw.
func alive() -> bool:
	if body_visible() or (impact_at >= 0.0 and time - impact_at < feel.impact_seconds):
		return true
	for a in drop_age:
		if a >= 0.0:
			return true
	return false


## Share of its full length the whip has at `t` (launch → full at the snap → back).
func length_share(t: float) -> float:
	if t < hit_seconds:
		var k := clampf(t / maxf(hit_seconds, 0.001), 0.0, 1.0)
		return lerpf(feel.launch_length, 1.0, 1.0 - pow(1.0 - k, 2.0)) # quick out, easing in
	var r := clampf((t - hit_seconds) / maxf(feel.recovery_seconds, 0.001), 0.0, 1.0)
	return lerpf(1.0, feel.recovery_length, r * r * (3.0 - 2.0 * r))


func _stiff(t: float) -> bool:
	return t >= hit_seconds - feel.strike_stiff_seconds and t <= hit_seconds + feel.strike_stiff_seconds * 0.5


## Where point `i` would be if it were exactly as the bender wills at `t`.
func guide(i: int, t: float) -> Vector2:
	var n := pos.size()
	var u := float(i) / float(n - 1)
	var d := target - hand
	var dir := d.normalized() if d.length() > 0.01 else Vector2.RIGHT
	var nrm := Vector2(-dir.y, dir.x) * side
	var full := d.length() * feel.reach_factor
	var wave := feel.wave_size * u * sin(TAU * (feel.wave_cycles * u - feel.wave_speed * t) + phase)
	wave *= length_share(t) # a short whip waves less (no curls at the hand)
	if _stiff(t):
		wave *= 0.2 # the crack straightens it
	return hand + dir * full * length_share(t) * u + nrm * wave


## Moves the simulation on to `t` seconds after the effect started, the hand and the
## target where they are now (screen art pixels). Fixed steps, so it moves the same
## at any frame rate.
func advance(t: float, hand_px: Vector2, target_px: Vector2) -> void:
	hand = hand_px
	target = target_px
	if not started:
		started = true
		time = t
		var n := maxi(feel.point_count, 4)
		pos.resize(n)
		prev.resize(n)
		for i in n:
			pos[i] = guide(i, t)
			prev[i] = pos[i]
	var dt := 1.0 / maxf(feel.steps_per_second, 1.0)
	var steps := 0
	while time + dt <= t and steps < 64:
		time += dt
		steps += 1
		_step(dt)
	if t - time > dt * 64.0:
		time = t # a long gap (a hidden window): don't try to catch up
	pos[0] = hand


func _step(dt: float) -> void:
	var n := pos.size()
	var stiff := _stiff(time)
	var follow := feel.strike_follow if stiff else feel.follow
	var k_link := feel.strike_stiffness if stiff else feel.stiffness
	var iterations := feel.strike_iterations if stiff else feel.iterations
	var keep := 1.0 - feel.drag
	var g := Vector2(0, feel.gravity * dt * dt)
	var tip_before := pos[n - 1]
	for i in range(1, n):
		var v := (pos[i] - prev[i]) * keep
		prev[i] = pos[i]
		pos[i] += v + g
		pos[i] = pos[i].lerp(guide(i, time), follow)
	if not cracked and time >= hit_seconds:
		cracked = true
		impact_at = time
		var d := (target - hand).normalized()
		for i in range(n / 2, n):
			var u := float(i - n / 2) / float(n - n / 2)
			prev[i] = pos[i] - d * feel.crack_speed * dt * u * u # the lash: the tip fastest
		_splash()
	pos[0] = hand
	prev[0] = hand
	var rest := (target - hand).length() * feel.reach_factor * length_share(time) / float(n - 1)
	for _it in iterations:
		for i in range(n - 1):
			var dv := pos[i + 1] - pos[i]
			var dist := dv.length()
			if dist < 0.0001:
				continue
			var corr := dv * ((dist - rest) / dist) * k_link
			if i == 0:
				pos[i + 1] -= corr
			else:
				pos[i] += corr * 0.5
				pos[i + 1] -= corr * 0.5
	_droplets(dt, (pos[n - 1] - tip_before) / dt)


func _droplets(dt: float, tip_vel: Vector2) -> void:
	for i in drop_age.size():
		if drop_age[i] < 0.0:
			continue
		drop_age[i] += dt
		if drop_age[i] > feel.droplet_life:
			drop_age[i] = -1.0
			continue
		if drop_age[i] > feel.droplet_float_seconds:
			drop_vel[i].y += feel.droplet_fall_gravity * dt
		else:
			drop_vel[i] *= 0.92 # floating: it slows and hangs
		drop_pos[i] += drop_vel[i] * dt
	var speed := tip_vel.length()
	if not body_visible() or speed < feel.droplet_speed_threshold:
		_drop_debt = 0.0
		return
	_drop_debt += feel.droplet_rate * (speed / feel.droplet_speed_threshold) * dt
	while _drop_debt >= 1.0:
		_drop_debt -= 1.0
		var jitter := Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 18.0
		_emit(pos[pos.size() - 1], tip_vel * feel.droplet_carry + jitter)


func _splash() -> void:
	for k in feel.impact_droplets:
		var a := TAU * (float(k) + _rng.randf()) / maxf(feel.impact_droplets, 1)
		_emit(target, Vector2.from_angle(a) * _rng.randf_range(30.0, 70.0) + Vector2(0, -25))


func _emit(at: Vector2, vel: Vector2) -> void:
	for i in drop_age.size():
		if drop_age[i] < 0.0:
			drop_pos[i] = at
			drop_vel[i] = vel
			drop_age[i] = 0.0
			return


## Width of the body at `u` along it (0 hand, 1 tip), art pixels.
func width_at(u: float) -> float:
	var w := feel.width_tip + (feel.width_hand - feel.width_tip) * (1.0 - pow(u, maxf(feel.taper_power, 0.01)))
	w *= 1.0 + feel.swell_amount * sin(TAU * (feel.swell_cycles * u - feel.swell_speed * time) + phase)
	return maxf(w, 1.0)


## Turns the chain into whole art pixels in the four colours: the body, a 1 px dark
## outline around it, a light highlight along its top edge. Each pixel belongs to the
## segment nearest it (so walls in front can cover the far part only).
func rasterize() -> Dictionary:
	raster = {}
	if not body_visible() or pos.size() < 2:
		return raster
	var body := {} # pixel -> segment
	var n := pos.size()
	for i in range(n - 1):
		var a := pos[i]
		var b := pos[i + 1]
		var steps := maxi(1, ceili(a.distance_to(b) * 2.0))
		for s in steps + 1:
			var k := float(s) / steps
			var c := a.lerp(b, k)
			var r := width_at((float(i) + k) / float(n - 1)) * 0.5
			var ri := ceili(r)
			for dy in range(-ri, ri + 1):
				for dx in range(-ri, ri + 1):
					var px := Vector2i(floori(c.x) + dx, floori(c.y) + dy)
					if (Vector2(px) + Vector2(0.5, 0.5)).distance_to(c) <= r + 0.15 and not body.has(px):
						body[px] = i
	var out := {}
	var add := func(seg: int, px: Vector2i, col: Color) -> void:
		if not out.has(seg):
			out[seg] = [PackedVector2Array(), PackedColorArray()]
		out[seg][0].append(Vector2(px))
		out[seg][1].append(col)
	var outline := {}
	for px: Vector2i in body:
		var seg: int = body[px]
		var top := not body.has(px + Vector2i(0, -1))
		var lit := top and body.has(px + Vector2i(0, 1)) # needs a pixel under it: thin tips stay body
		add.call(seg, px, feel.highlight_color if lit else feel.body_color)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = px + d
			if not body.has(q) and not outline.has(q):
				outline[q] = seg
	for q: Vector2i in outline:
		add.call(outline[q], q, feel.outline_color)
	raster = out
	return out


## Live droplets: [whole art pixel].
func droplets() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in drop_age.size():
		if drop_age[i] >= 0.0:
			out.append(drop_pos[i].floor())
	return out


func tip() -> Vector2:
	return pos[pos.size() - 1] if not pos.is_empty() else hand
