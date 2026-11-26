class_name WaterRope
extends RefCounted
## The Water stance 1 rope and the Water Whip (2026-11-26): a port of
## docs/reference/water_whip_reference.html (the source of truth; its step() is
## followed state by state). Waterbending: the water never attaches to the hand; it
## lives in the bender's space and the body only steers it.
##
## States: idle → spin (near throws) → fly → pour → fall → rise → return → wrap → idle,
## plus "drain" (leaving the stance: the water goes back into the pouch or the river).
## Verlet points with distance links; one step = one 60 fps frame of game time.
##
## Space: reference pixels (× WATER_SCALE = art pixels), relative to the hero's feet on
## the ground: x to the screen's right, y into the screen (depth), z up. The orbit,
## spin, rise, return and wrap move with the hero; while flying, pouring and falling
## the water stays where it is in the world (`move_hero` shifts it back), and so do
## drops and puddles. Purely cosmetic: each player simulates their own; gameplay
## (the hit at 0.5 s, the water spent) is decided by the host.

class Pt:
	var p := Vector3.ZERO
	var q := Vector3.ZERO # where it was a frame ago (Verlet)
	var id := 0
	var gnd := false
	var near := false

	func _init(at: Vector3, i: int) -> void:
		p = at
		q = at
		id = i


var s: WaterRopeSettings
var R: Array[Pt] = []
var conn: Array[bool] = []
var strength := PackedFloat32Array() # the reference's `str`
var fr := 0
var st := "idle"
var tt := 0
var sim_t := 0
var aim := Vector3.ZERO
## Splash drops: {"p": Vector3, "v": Vector3, "l": frames left}.
var drops: Array = []
## Soaked puddles: {"p": Vector2, "l": frames left}.
var lost: Array = []
var phase := 0.0
var w := 0.0
var phase0 := 0.0
var Tf := 0
var Ts := 0
var Bk := 0.0
var cast_at := 0
var prev := Vector3.ZERO
var path := {} # {"pts": PackedVector3Array, "cum": PackedFloat32Array, "L": float}
var path_off := Vector3.ZERO # the world moving under the hero while it flies
var rpath := {}
var rs := 0.0
var hold := 1.0
var base := Vector2.ZERO
var has_base := false
var ib := 1.0
var tail_in := false
var settle := 0
var hit_at := 0
var break_at := 0
var joined_at := -1.0
var ret_at := 0
var ret_scale := 1.0
var pour_s := 0.0
var v_hit := 0.0
var poured: Array[bool] = []
## How many points the rope wants (NMAX; 0 while draining).
var target_count := 0
## Where new water comes from, hero-relative: the hips (the pouch) or a water tile.
var source := Vector3.ZERO
## Still forming the orbit after entering the stance (points come FORM_EVERY frames apart).
var forming := true
var rng := RandomNumberGenerator.new()
## Readouts (the reference's message line).
var readout := {}


func _init(settings: WaterRopeSettings, seed := 0) -> void:
	s = settings
	rng.seed = seed
	w = s.w_idle()
	target_count = s.NMAX


static func _clamp(v: float, a: float, b: float) -> float:
	return maxf(a, minf(b, v))


static func ramp(t: float, length: float) -> float:
	if length <= 0.0:
		return 1.0 if t >= 0.0 else 0.0
	var q := _clamp(t / length, 0.0, 1.0)
	return q * q * (3.0 - 2.0 * q)


func M() -> int:
	return R.size()


func is_empty() -> bool:
	return R.is_empty()


## Whether a throw can start now (the reference allows idle and wrap).
func can_cast() -> bool:
	return st == "idle" or st == "wrap"


# --- Speeds and shapes -------------------------------------------------------------

func _speed_curve_exp() -> float:
	var t := _clamp((s.HALF_TRIP - s.SPEED_FLOOR) / (1.0 - s.SPEED_FLOOR), 0.01, 0.99)
	return log(t) / log(0.5)


func dist_scale(length: float) -> float:
	var df := _clamp(length / s.DIST_REF, 0.0, 1.0)
	return s.SPEED_FLOOR + (1.0 - s.SPEED_FLOOR) * pow(df, _speed_curve_exp())


func orbit_t(id: int) -> Vector3:
	var a := phase - id * s.ang()
	return Vector3(cos(a) * s.ORB, sin(a) * s.ORB, s.ZW + sin(id * s.WAVE_LEN - fr * s.WAVE_SPEED) * s.WAVE_AMP)


## The orbit's entry point E (on the hero's right relative to the cast) and the cast
## direction on the ground.
func entry_point() -> Dictionary:
	var g := Vector2(aim.x, aim.y)
	var gl := g.length() if g.length() > 0.0 else 1.0
	var f := g / gl
	return {"E": Vector3(-f.y * s.ORB, f.x * s.ORB, s.ZW), "f": f}


static func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (2.0 * p1 + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 \
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


static func poly_path(pts: PackedVector3Array) -> Dictionary:
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i - 1].distance_to(pts[i]))
	return {"pts": pts, "cum": cum, "L": cum[cum.size() - 1]}


static func _build_path(kp: Array) -> Dictionary:
	var pts := PackedVector3Array()
	for sgm in range(1, kp.size() - 2):
		for k in range(0 if sgm == 1 else 1, 61):
			pts.append(_cr(kp[sgm - 1], kp[sgm], kp[sgm + 1], kp[sgm + 2], k / 60.0))
	return poly_path(pts)


static func along(P: Dictionary, u: float) -> Vector3:
	var t: float = _clamp(u, 0.0, 1.0) * float(P.L)
	var cm: PackedFloat32Array = P.cum
	var lo := 0
	var hi := cm.size() - 1
	while hi - lo > 1:
		var m := (lo + hi) >> 1
		if cm[m] < t:
			lo = m
		else:
			hi = m
	var sg := cm[hi] - cm[lo]
	if sg == 0.0:
		sg = 1.0
	var k := (t - cm[lo]) / sg
	return P.pts[lo].lerp(P.pts[hi], k)


func _along_path(u: float) -> Vector3:
	return along(path, u) + path_off


## The throw's speed profile: accelerates all the way (peak ≈ 2.07 × average).
static func prof(u: float) -> float:
	u = _clamp(u, 0.0, 1.0)
	return (0.45 * u + 0.5167 * u * u * u) / 0.9667


func ret_speed(f: float) -> float:
	var vc := s.ret_speed_cruise() * ret_scale
	var v_end := vc * s.ENTRY_KEEP
	var v0 := maxf(0.15, vc * s.RET_START)
	if f < s.RET_ACCEL:
		return v0 + (vc - v0) * ramp(f, s.RET_ACCEL)
	if f < 1.0 - s.RET_DECEL:
		return vc
	return vc + (v_end - vc) * ramp(f - (1.0 - s.RET_DECEL), s.RET_DECEL)


# --- Commands from the owner -------------------------------------------------------

## Fills the rope at once on its orbit, idle (tests, a hero coming back on screen).
func fill_now(count := -1) -> void:
	var n := s.NMAX if count < 0 else count
	R.clear()
	conn.clear()
	strength = PackedFloat32Array()
	for i in n:
		R.append(Pt.new(orbit_t(i), i))
	for i in maxi(n - 1, 0):
		conn.append(true)
		strength.append(1.0)
	st = "idle"
	tt = 0
	ib = 1.0
	w = s.w_idle()
	forming = false
	target_count = s.NMAX


## Leaving the stance: the water goes back where it came from, then the rope is gone.
func drain() -> void:
	target_count = 0
	st = "drain"
	tt = 0
	for i in conn.size():
		conn[i] = false
		strength[i] = 0.0


## A dead rope (drained) can be dropped by its owner.
func done() -> bool:
	return st == "drain" and R.is_empty() and drops.is_empty() and lost.is_empty()


## The hero moved `delta` on the ground (reference px): what is out in the world
## stays where it is.
func move_hero(delta: Vector2) -> void:
	if delta == Vector2.ZERO:
		return
	var d := Vector3(delta.x, delta.y, 0.0)
	if st in ["fly", "pour", "fall"]:
		for p in R:
			p.p -= d
			p.q -= d
		aim -= d
		path_off -= d
		prev -= d
	for dr in drops:
		dr.p -= d
	for l in lost:
		l.p -= delta


## Throws the front of the rope at `target` (ground, reference px, hero-relative).
## The hit lands HIT frames later. A cast while the water is still out snaps the rope
## back onto its orbit first (the game's cooldown is shorter than a full return).
func cast(target: Vector2) -> void:
	var recast := st == "wrap"
	if not can_cast() or M() < 2:
		fill_now(maxi(M(), s.MIN_KEEP))
	if recast:
		for i in conn.size():
			conn[i] = true
			strength[i] = 1.0
	aim = Vector3(target.x, target.y, s.TARGET_Z)
	var gd := Vector2(aim.x, aim.y).length()
	if gd < 18.0:
		if gd == 0.0:
			aim.x = 18.0
		else:
			aim.x *= 18.0 / gd
			aim.y *= 18.0 / gd
	var d := R[0].p.distance_to(aim)
	Bk = _clamp((s.VREF * s.HIT - d) / 2.0, 0.0, s.PULL_MAX)
	Ts = roundi(_clamp((s.VREF * s.HIT - (d + 2.0 * Bk)) / s.VREF, 0.0, s.HIT - s.TF_MIN))
	Tf = s.HIT - Ts
	cast_at = sim_t
	st = "spin" if Ts > 0 else "fly"
	tt = 0
	forming = false
	if st == "fly":
		_release()
	readout = {"pull_back": Bk, "spin_s": Ts / 60.0, "flight_s": Tf / 60.0, "recast": recast}


func _release() -> void:
	var tp := R[0]
	var p0 := tp.p
	var v := tp.p - tp.q
	var vl := v.length() if v.length() > 0.0 else 1.0
	var g := Vector2(aim.x, aim.y)
	var gl := g.length() if g.length() > 0.0 else 1.0
	var u := g / gl
	var kp: Array = [p0 - v / vl * 8.0, p0]
	if Bk > 4.0:
		kp.append(Vector3(-u.x * Bk * 0.5, -u.y * Bk * 0.5, s.ZW + 6.0 + Bk * 0.6))
	kp.append(aim)
	var last: Vector3 = kp[kp.size() - 1]
	var before: Vector3 = kp[kp.size() - 2]
	var bl := before.distance_to(last) if before.distance_to(last) > 0.0 else 1.0
	kp.append(last + (last - before) / bl * 8.0)
	path = _build_path(kp)
	path_off = Vector3.ZERO
	prev = tp.p


func _start_return() -> void:
	var lead := R[0]
	var ep := entry_point()
	var E: Vector3 = ep.E
	var f: Vector2 = ep.f
	var left := Vector2(f.y * s.ORB, -f.x * s.ORB)
	var P0 := Vector2(lead.p.x, lead.p.y)
	var D := maxf(8.0, Vector2(E.x, E.y).distance_to(P0))
	var sd := left - P0
	var sl := sd.length() if sd.length() > 0.0 else 1.0
	sd /= sl
	var a := minf(D * s.CTRL_START, sl * 0.9)
	var b := D * s.CTRL_END
	var P1 := P0 + sd * a
	var P2 := Vector2(E.x, E.y) + f * b
	var Eg := Vector2(E.x, E.y)
	var z0 := lead.p.z
	var pts := PackedVector3Array()
	for k in s.PATH_SAMPLES + 1:
		var u := float(k) / s.PATH_SAMPLES
		var m := 1.0 - u
		var xy := m * m * m * P0 + 3.0 * m * m * u * P1 + 3.0 * m * u * u * P2 + u * u * u * Eg
		var z := z0 + (s.ZW - z0) * ramp(u, 1.0) + s.ARC_LIFT * sin(PI * u)
		pts.append(Vector3(xy.x, xy.y, maxf(z, 1.0)))
	pts[s.PATH_SAMPLES] = Vector3(E.x, E.y, s.ZW)
	rpath = poly_path(pts)
	rs = 0.0
	hold = 1.0
	joined_at = -1.0
	ret_at = sim_t
	prev = lead.p
	ret_scale = dist_scale(rpath.L)


func _ground_ratio_at_end() -> float:
	var P: PackedVector3Array = rpath.pts
	var n := P.size()
	var a := P[n - 1]
	var b := P[n - 6] if n >= 6 else P[0]
	var d := a.distance_to(b) if a.distance_to(b) > 0.0 else 1.0
	return Vector2(a.x - b.x, a.y - b.y).length() / d


func _enter_orbit(step_len: float, leftover: float) -> void:
	var lead := R[0]
	var gr := _ground_ratio_at_end()
	var vg := step_len * gr
	var end: Vector3 = rpath.pts[rpath.pts.size() - 1]
	var a0 := atan2(end.y, end.x)
	phase0 = a0
	phase = a0 + leftover * gr / s.ORB
	w = maxf(0.002, vg / s.ORB)
	var sp := Vector2(cos(phase), sin(phase)) * s.ORB
	var tg := Vector2(-sin(phase), cos(phase)) * vg
	lead.p = Vector3(sp.x, sp.y, s.ZW)
	lead.q = Vector3(sp.x - tg.x, sp.y - tg.y, s.ZW)
	st = "wrap"
	tt = 0
	tail_in = false
	settle = 0
	readout = {"return_px": rpath.L, "return_share": ret_scale, "return_s": (sim_t - ret_at) / 60.0,
			"entry_px_s": vg * 60.0}


func _follow_path(sv: float, att: Array[bool]) -> void:
	for j in range(1, M()):
		if not att[j]:
			continue
		var sj := sv - j * s.sp()
		var p := R[j]
		if sj <= 0.0:
			continue
		if sj < rpath.L:
			_spring(p, along(rpath, sj / rpath.L), s.FOLLOW_K)
		else:
			_spring(p, orbit_t(p.id), s.JOIN_K)


func _reforming() -> bool:
	return st == "rise" or st == "return" or st == "wrap"


func _tightness() -> float:
	if st == "idle" or st == "spin":
		return s.IDLE_PUSH
	if st == "wrap":
		return s.IDLE_PUSH * ramp(tt, s.WRAP_TIGHT)
	return 0.0


static func _spring(p: Pt, g: Vector3, k: float) -> void:
	p.p += (g - p.p) * k


func _constrain(fix_n: int) -> void:
	var tg := _tightness()
	var cap := s.CAP_STEP * s.MAX_SPEED / 1.6 if _reforming() else 1e9
	var n := M()
	for _it in s.ITERATIONS:
		for i in n - 1:
			if not conn[i]:
				continue
			var a := R[i]
			var b := R[i + 1]
			var af := i < fix_n
			var bf := i + 1 < fix_n
			if af and bf:
				continue
			var dv := b.p - a.p
			var d := dv.length()
			if d == 0.0:
				d = 1.0
			if d <= s.SEG and tg == 0.0:
				continue
			var corr := d - s.SEG
			if d < s.SEG:
				corr *= tg
			corr *= strength[i]
			if af:
				corr = _clamp(corr, -cap, cap)
				b.p -= dv / d * corr
			else:
				var h := _clamp(corr * 0.5, -cap, cap)
				a.p += dv / d * h
				b.p -= dv / d * h


func _splash(at: Vector3, n: int, v: Vector3) -> void:
	for _k in n:
		drops.append({"p": at, "v": Vector3(v.x * 0.35 + rng.randf_range(-0.5, 0.5) * s.SPLASH_SPREAD,
				v.y * 0.35 + rng.randf_range(-0.5, 0.5) * s.SPLASH_SPREAD, v.z * 0.35 + rng.randf() * s.SPLASH_UP),
				"l": 30.0 + rng.randf() * 24.0})


func _regroup() -> void:
	var pool: Array[Pt] = R.duplicate()
	var start: Pt = pool[0]
	for p in pool:
		if Vector2(p.p.x, p.p.y).length() > Vector2(start.p.x, start.p.y).length():
			start = p
	var chain: Array[Pt] = [start]
	pool.erase(start)
	while not pool.is_empty():
		var t := chain[chain.size() - 1]
		var best: Pt = null
		var bd := 1e9
		for p in pool:
			var d := Vector2(p.p.x - t.p.x, p.p.y - t.p.y).length()
			if d < bd:
				bd = d
				best = p
		if bd > s.STRAY_GAP and chain.size() >= s.MIN_KEEP:
			break
		chain.append(best)
		pool.erase(best)
	for p in pool:
		lost.append({"p": Vector2(p.p.x, p.p.y), "l": float(s.SOAK_TIME)})
	R = chain
	for i in R.size():
		R[i].id = i
	conn.clear()
	strength = PackedFloat32Array()
	for i in maxi(R.size() - 1, 0):
		conn.append(false)
		strength.append(0.0)
	var sum := Vector2.ZERO
	for p in R:
		sum += Vector2(p.p.x, p.p.y)
	base = sum / R.size()
	has_base = true


func _rise_t(i: int) -> Vector3:
	var n := M()
	var bl := base.length() if base.length() > 0.0 else 1.0
	var u := -base / bl
	var sp := (i - (n - 1) / 2.0) * s.SEG * 0.7
	return Vector3(base.x + u.x * sp, base.y + u.y * sp,
			3.0 + sin(float(i) / maxf(1, n - 1) * PI) * 10.0 + sin(i * s.WAVE_LEN - fr * s.WAVE_SPEED) * 1.5)


func attached() -> Array[bool]:
	var a: Array[bool] = [true]
	for i in range(1, M()):
		a.append(a[i - 1] and conn[i - 1] and strength[i - 1] > 0.35)
	return a


func _link_up(force: bool) -> void:
	for i in M() - 1:
		if conn[i]:
			continue
		var d := R[i].p.distance_to(R[i + 1].p)
		if (R[i].near and R[i + 1].near and d < s.SEG * s.LINK_REACH) or d < s.SEG * s.LINK_REACH * 0.8 or force:
			conn[i] = true


func _chase_loose(att: Array[bool]) -> void:
	for i in range(1, M()):
		if att[i]:
			continue
		_spring(R[i], R[i - 1].p, s.CHASE_K)
		R[i].near = false


func _path_dir_end() -> Vector3:
	var pts: PackedVector3Array = path.pts
	var a := pts[pts.size() - 2]
	var b := pts[pts.size() - 1]
	var l := a.distance_to(b) if a.distance_to(b) > 0.0 else 1.0
	return (b - a) / l


func _pour_off(j: int) -> void:
	var dir := _path_dir_end()
	var p := R[j]
	poured[j] = true
	p.p = aim
	p.q = aim - dir * v_hit * 0.6
	if j < M() - 1:
		conn[j] = false
	_splash(p.p, s.POUR_SPLASH, dir * v_hit)


## A new point of water at the source (the hips or a water tile), joined to the tail
## (`linked`: tightening over LINK_FADE frames) or loose (it chases the tail).
func _add_point(linked: bool) -> void:
	var at := source
	R.append(Pt.new(at, R.size()))
	if R.size() > 1:
		conn.append(linked)
		strength.append(0.0)


# --- One frame ----------------------------------------------------------------------

func step() -> void:
	tt += 1
	sim_t += 1
	fr += 1
	var tw := s.W_SPIN if st == "spin" else s.w_idle()
	w += (tw - w) * (s.SPIN_EASE if st == "spin" else s.WRAP_EASE if st == "wrap" else s.IDLE_EASE)
	phase += w
	if st == "drain":
		_step_drain()
		_step_drops()
		return
	if R.is_empty():
		if st == "idle" and target_count > 0:
			_add_point(true)
		_step_drops()
		return
	var damp := s.FLY_DAMP if st in ["fly", "fall", "pour"] else s.RET_DRAG if _reforming() else s.IDLE_DAMP
	var homing := st == "return" or st == "wrap"
	var att0: Array[bool] = attached() if homing else ([] as Array[bool])
	var chased := {}
	if homing:
		for i in range(1, M()):
			if not att0[i] and att0[i - 1]:
				chased[i - 1] = true
	var damp_chased := 1.0 - (1.0 - damp) * s.CHASED_DRAG_MULT
	for i in M():
		var p := R[i]
		var dm := damp_chased if chased.has(i) else damp
		var v := (p.p - p.q) * dm
		if _reforming():
			var lim := s.MAX_SPEED
			if homing and i > 0 and not att0[i]:
				var gap := p.p.distance_to(R[i - 1].p)
				lim = minf(s.CHASE_MAX, s.MAX_SPEED + s.CHASE_GAIN * maxf(0.0, gap - s.SEG))
			var vl := v.length()
			if vl > lim:
				v *= lim / vl
		var gz := s.GRAV if st == "fall" or (st == "pour" and i < poured.size() and poured[i]) else 0.0
		p.q = p.p
		p.p += v - Vector3(0, 0, gz)
	for i in M() - 1:
		strength[i] = minf(1.0, strength[i] + 1.0 / s.LINK_FADE) if conn[i] else 0.0
	if has_base and (st == "rise" or st == "return"):
		var bl := base.length() if base.length() > 0.0 else 1.0
		var nb := bl + (s.RISE_STOP - bl) * s.RISE_DRIFT
		base *= nb / bl
	match st:
		"idle", "spin":
			ib = minf(1.0, ib + 1.0 / s.IDLE_BLEND)
			var k := s.SPIN_SPRING if st == "spin" else s.IDLE_SPRING * ib
			for p in R:
				_spring(p, orbit_t(p.id), k)
			_constrain(0)
			# Refill from the pouch (the hips) or the water nearby, one point at a time.
			var every := s.FORM_EVERY if forming else s.REFILL_EVERY
			if st == "idle" and M() < target_count and tt % every == 0:
				_add_point(true)
			if forming and M() >= target_count:
				forming = false
			if st == "spin" and tt >= Ts:
				st = "fly"
				tt = 0
				_release()
		"fly":
			var tp := R[0]
			var q := _along_path(prof(float(tt) / Tf))
			tp.q = prev
			tp.p = q
			prev = q
			_constrain(1)
			if tt >= Tf:
				v_hit = maxf(2.0, tp.p.distance_to(tp.q))
				st = "pour"
				tt = 0
				hit_at = sim_t
				poured.clear()
				poured.resize(M())
				poured.fill(false)
				pour_s = path.L
				_pour_off(0)
				readout = {"hit_s": (sim_t - cast_at) / 60.0, "pull_back": Bk}
		"pour":
			pour_s += v_hit
			var last := mini(s.POUR_POINTS, M()) - 1
			if last < 1:
				_break_all()
			for j in range(1, last + 1):
				if poured[j]:
					continue
				var sj := pour_s - j * s.sp()
				var p := R[j]
				if sj >= path.L:
					_pour_off(j)
					if j == last:
						_break_all()
					continue
				if sj <= 0.0:
					continue
				var q := _along_path(sj / float(path.L))
				var old := p.p
				p.p += (q - p.p) * s.POUR_BLEND
				p.q = old
			if st == "pour":
				_constrain(last + 1)
		"fall":
			if tt >= mini(s.FALL_TIME_MAX, s.RETURN_AT):
				_regroup()
				st = "rise"
				tt = 0
		"rise":
			var k := s.RISE_K * ramp(tt, s.RISE_RAMP)
			for i in M():
				var g := _rise_t(i)
				_spring(R[i], g, k)
				R[i].near = R[i].p.distance_to(g) < s.RECONNECT
			_link_up(false)
			_constrain(0)
			if sim_t - break_at >= s.RETURN_AT:
				st = "return"
				tt = 0
				_start_return()
		"return":
			# Water lost at the target comes out of the hips (the pouch) and chases the
			# tail, so the rope comes home whole at its own speed.
			if M() < target_count and tt % s.REBUILD_EVERY == 0:
				_add_point(false)
			var lead := R[0]
			var f := rs / float(rpath.L)
			var att := attached()
			var whole := att.all(func(x): return x) and M() >= target_count
			if whole and joined_at < 0.0:
				joined_at = f
			hold += ((s.HOLD_SPEED if f >= s.HOLD_AT and not whole else 1.0) - hold) * s.HOLD_EASE
			var step_len := ret_speed(f) * hold
			if whole and rs + step_len >= rpath.L:
				var leftover: float = rs + step_len - float(rpath.L)
				rs = rpath.L
				_follow_path(rs, att)
				_enter_orbit(step_len, leftover)
				_constrain(1)
			else:
				rs = minf(rpath.L if whole else rpath.L * s.ENTRY_GUARD, rs + step_len)
				var q := along(rpath, rs / rpath.L)
				lead.q = prev
				lead.p = q
				prev = q
				_follow_path(rs, att)
				_chase_loose(att)
				_link_up(f >= s.FORCE_AT)
				_constrain(1)
		"wrap":
			var sv: float = float(rpath.L) + (phase - phase0) * s.ORB
			var att := attached()
			_spring(R[0], orbit_t(0), s.WRAP_LEAD)
			_follow_path(sv, att)
			_chase_loose(att)
			_link_up(true)
			_constrain(1)
			if not tail_in and sv - (M() - 1) * s.sp() >= rpath.L:
				tail_in = true
			if tail_in:
				settle += 1
				if settle > s.WRAP_SETTLE:
					st = "idle"
					tt = 0
					ib = 0.15
	for p in R:
		if p.p.z < 0.0:
			if (st == "fall" or st == "pour") and p.q.z - p.p.z > 1.0 and not p.gnd:
				_splash(Vector3(p.p.x, p.p.y, 0.0), 2, Vector3(p.p.x - p.q.x, p.p.y - p.q.y, 0.0))
				p.gnd = true
			p.p.z = 0.0
			p.q.z = p.p.z - (p.q.z - p.p.z) * 0.2
			p.q.x = p.p.x - (p.p.x - p.q.x) * 0.5
			p.q.y = p.p.y - (p.p.y - p.q.y) * 0.5
		elif p.p.z > 1.0:
			p.gnd = false
	_step_drops()
	if (st == "idle" or st == "return") and fr % s.DRIP_EVERY == 0 and M() > 0:
		var p := R[rng.randi() % M()]
		drops.append({"p": p.p, "v": Vector3(0, 0, 0.3), "l": 14.0})


func _break_all() -> void:
	for i in conn.size():
		conn[i] = false
		strength[i] = 0.0
	st = "fall"
	tt = 0
	break_at = sim_t


func _step_drops() -> void:
	var keep := []
	for d in drops:
		var v: Vector3 = d.v
		d.p += v
		v.x *= s.DROP_DRAG
		v.y *= s.DROP_DRAG
		v.z = v.z * s.DROP_ZDRAG - s.DROP_GRAV
		d.l -= 1.0
		if d.p.z < 0.0:
			d.p.z = 0.0
			v.z *= -0.2
			v.x *= 0.4
			v.y *= 0.4
		d.v = v
		if d.l > 0.0:
			keep.append(d)
	drops = keep
	var kl := []
	for l in lost:
		l.l -= 1.0
		if l.l > 0.0:
			kl.append(l)
	lost = kl


## Draining: each point flows back to the source and is gone when it gets there.
func _step_drain() -> void:
	var keep: Array[Pt] = []
	for p in R:
		var v := (p.p - p.q) * s.RET_DRAG
		p.q = p.p
		p.p += v
		_spring(p, source, 0.15)
		if p.p.distance_to(source) > 3.0:
			keep.append(p)
	R = keep
	for i in R.size():
		R[i].id = i
	conn.resize(maxi(R.size() - 1, 0))
	strength.resize(maxi(R.size() - 1, 0))
	conn.fill(false)
	strength.fill(0.0)
