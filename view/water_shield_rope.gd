class_name WaterShieldRope
extends WaterRope
## Water Shield's rope (water physics phase 4, from water_shield_demo_approved.html):
## the rope leaves the caster's orbit, turns in and runs onto a great circle of a
## sphere round the target's chest, its tilt drifting so the turns cross like a ball
## of yarn; it stretches to LEN_MULT × its length, thinning, while it holds. Its
## length follows the shield left (the host's word, `set_left`); hits dent it and
## splash. Broken (`pop`): it bursts, falls and soaks in, all lost. Run out
## (`unwind`): it comes home with what's left along its own path.
## Coordinates as WaterRope: reference px from the caster's feet.

## The bubble: centre, radius, spin speed, drift, start angle and direction, and the
## drift's changes over time ([{t0, ph0, pr}]).
var sph := {}
## The way out: orbit arc + turn-in + cubic onto the bubble (`cp`, length `cp_L`).
var cp := {}
var cp_L := 0.0
var sh_s0 := 0.0
var sh_m0 := 0.0
var sh_m1 := 0.0
var s_cur := 0.0
var shield_up := false
var self_cast := false
## Shield left (0–1), and what's been shown of it.
var left := 1.0
var _shown_left := 1.0
var tail_s := 0.0
var lr0 := 0.0
var lcap := 0.0
var kick := 1.0
var rboost := 1.0
var wob := 0.0
var strained := false
var hold_s := 1.0
var gaps := {}
var last_hit := Vector2.ZERO
var home_n := 0
var home_m0 := 0
var home_w0 := 1.0
var rpre := 0.0
var _tilt_s := 0.0
var _tilt_c := 1.0


func _init(settings: WaterRopeSettings, seed := 0) -> void:
	super(settings, seed)
	_tilt_s = sin(s.TILT)
	_tilt_c = cos(s.TILT)


## Takes `points` (the caster's rope, as it was) and sends them to `target`
## (reference px from the caster's feet; the caster itself for a self-cast).
func cast_shield(points: Array[Pt], target: Vector2, is_self: bool, ph: float, wv: float) -> void:
	R = points
	conn.clear()
	strength = PackedFloat32Array()
	for i in maxi(M() - 1, 0):
		conn.append(true)
		strength.append(1.0)
	for i in M():
		R[i].id = i
	phase = ph
	w = wv
	self_cast = is_self
	var n := M()
	var pts := PackedVector3Array()
	var k := (n - 1) * 4
	while k >= 0:
		pts.append(orbit_t(k / 4.0))
		k -= 1
	sh_s0 = poly_path(pts).L
	var P0 := pts[pts.size() - 1]
	var h := s.HERO_H
	var r := s.SH_R * h / s.SH_DUMMY_H # a hero's bubble (the demo's dummy was 26 px)
	var C := Vector3(target.x, target.y, maxf(h * 0.5, r))
	aim = Vector3(20, 8, 10) if is_self else Vector3(target.x, target.y, 10)
	sph = {"C": C, "r": r, "vs": s.VS, "pr": s.PRECESS, "ph0": atan2(aim.y, aim.x), "th0": 0.0, "sg": 1.0}
	sph.segs = [{"t0": 0.0, "ph0": sph.ph0, "pr": sph.pr}]
	var vdir := Vector2(-sin(phase), cos(phase))
	var dr := vdir
	if not is_self:
		var dl := Vector2(C.x - P0.x, C.y - P0.y)
		dr = dl.normalized() if dl.length() > 0.0 else vdir
	# The entry: where the bubble's spin best lines up with the approach.
	var best := -1e9
	var bt := 0.0
	var bsg := 1.0
	for i in 72:
		for sg in [1.0, -1.0]:
			sph.th0 = i / 72.0 * TAU
			sph.sg = sg
			var q := sph_at(0.0)
			var q1 := sph_at(1.0)
			var g := Vector2(q1.x - q.x, q1.y - q.y)
			var sc := (g.dot(dr) / maxf(g.length(), 0.0001)) - s.ENTRY_DIST_W * q.distance_to(P0)
			if sc > best:
				best = sc
				bt = sph.th0
				bsg = sg
	sph.th0 = bt
	sph.sg = bsg
	var E := sph_at(0.0)
	var t3 := (sph_at(1.0) - E).normalized()
	var lift := s.LIFT_BASE + Vector2(E.x - P0.x, E.y - P0.y).length() * s.LIFT_PER
	var ti := _turn_in(Vector2(P0.x, P0.y), vdir, Vector2(E.x, E.y))
	var Q: Vector2 = ti.Q
	var tg := Vector2(t3.x, t3.y).normalized() if Vector2(t3.x, t3.y).length() > 0.0 else Vector2.RIGHT
	var Dq := maxf(2.0, Vector2(E.x, E.y).distance_to(Q))
	var tr: Array = [Vector2(P0.x, P0.y)]
	tr.append_array(ti.pts)
	_cubic(Q, Q + ti.h * minf(Dq * s.TRAVEL_CTRL, s.TRAVEL_CTRL_MAX), Vector2(E.x, E.y) - tg * Dq * s.ARRIVE_CTRL,
			Vector2(E.x, E.y), 80, tr)
	var lifted := _lift_z(tr, P0.z, E.z, lift, false)
	lifted[lifted.size() - 1] = E
	for i in range(1, lifted.size()):
		pts.append(lifted[i])
	cp = poly_path(pts)
	cp_L = cp.L
	var ltr := maxf(1.0, cp_L - sh_s0)
	sh_m0 = clampf(w * s.ORB * s.SH_T / ltr, 0.0, s.M_MAX)
	sh_m1 = clampf(sph.vs * s.SH_T / ltr, 0.0, s.M_MAX)
	shield_up = false
	st = "shield"
	tt = 0
	prev = R[0].p if M() > 0 else Vector3.ZERO
	wscale = 1.0
	left = 1.0
	_shown_left = 1.0
	kick = 1.0
	hold_s = 1.0
	home_n = 0
	rboost = 1.0
	wob = 0.0
	strained = false
	gaps = {}
	last_hit = Vector2.ZERO
	forming = false
	target_count = 0


## The bubble moves with its target (reference px from the caster's feet).
func follow_target(target: Vector2) -> void:
	if sph.is_empty():
		return
	sph.C = Vector3(target.x, target.y, sph.C.z)


## The host's shield left (0–1): the rope keeps that share of its stretched length;
## a drop is a hit (dents, splash, ripple, a kick in the spin).
func set_left(f: float) -> void:
	f = clampf(f, 0.0, 1.0)
	if f < _shown_left - 0.001 and shield_up and st == "shield":
		_hit(_shown_left - f)
	_shown_left = f
	left = f


func _phase_at(tau: float) -> float:
	var g: Dictionary = sph.segs[0]
	for q in sph.segs:
		if tau >= q.t0:
			g = q
	return g.ph0 + g.pr * (tau - g.t0)


## Point `tau` frames along the bubble's great circle.
func sph_at(tau: float) -> Vector3:
	var th: float = sph.th0 + sph.sg * sph.vs * tau / sph.r
	var ph := _phase_at(tau)
	var n := Vector3(_tilt_s * cos(ph), _tilt_s * sin(ph), _tilt_c)
	var u := Vector3(-sin(ph), cos(ph), 0.0)
	var v := n.cross(u)
	var C: Vector3 = sph.C
	return C + sph.r * (cos(th) * u + sin(th) * v)


func _pos_at(sc: float) -> Vector3:
	return along(cp, maxf(0.0, sc) / cp.L) if sc <= cp_L else sph_at((sc - cp_L) / sph.vs)


func _turn_in(P: Vector2, h: Vector2, T: Vector2) -> Dictionary:
	return turn_in_static(s, P, h, T)


## A turn-in arc (radius TURN_R) from `P` heading `h` until it faces `T` within TURN_OK.
static func turn_in_static(s: WaterRopeSettings, P: Vector2, h: Vector2, T: Vector2) -> Dictionary:
	var pts: Array = []
	var x := P
	var turned := 0.0
	for k in 400:
		var t := T - x
		var tl := t.length()
		if tl < 1.0:
			break
		var ang := atan2(h.cross(t) / tl, h.dot(t) / tl)
		if absf(ang) < s.TURN_OK or turned > PI:
			break
		var da := signf(ang) / s.TURN_R
		turned += absf(da)
		h = h.rotated(da)
		x += h
		pts.append(x)
	return {"pts": pts, "Q": x, "h": h}


static func _cubic(A: Vector2, B: Vector2, C: Vector2, D: Vector2, n: int, out: Array) -> void:
	for k in range(1, n + 1):
		var u := float(k) / n
		var m := 1.0 - u
		out.append(m * m * m * A + 3.0 * m * m * u * B + 3.0 * m * u * u * C + u * u * u * D)


static func _lift_z(pts: Array, z0: float, z1: float, lift: float, clamp_low: bool) -> PackedVector3Array:
	var flat := PackedVector3Array()
	for q in pts:
		flat.append(Vector3(q.x, q.y, 0.0))
	var P := poly_path(flat)
	var out := PackedVector3Array()
	for i in pts.size():
		var u: float = P.cum[i] / maxf(P.L, 0.0001)
		var z := z0 + (z1 - z0) * u + lift * sin(PI * u)
		out.append(Vector3(pts[i].x, pts[i].y, maxf(z, 1.0) if clamp_low else z))
	return out


func _sh_herm(u: float) -> float:
	var u2 := u * u
	var u3 := u2 * u
	return (u3 - 2.0 * u2 + u) * sh_m0 + (-2.0 * u3 + 3.0 * u2) + (u3 - u2) * sh_m1


func _hit(took: float) -> void:
	var a := rng.randf() * TAU
	var dir := Vector3(cos(a), sin(a), 0.0)
	var C: Vector3 = sph.C
	var at: Vector3 = C + dir * float(sph.r)
	last_hit = Vector2(dir.x, dir.y)
	for p in R:
		if p.p.distance_to(at) < s.DENT_R:
			p.off -= dir * s.DENT_PUSH
	_splash(at, roundi(2.0 + took * 20.0), Vector3(dir.x, dir.y, 0.5))
	rboost = s.RIPPLE_HIT
	kick = s.KICK


func _step_shield() -> void:
	rboost = 1.0 + (rboost - 1.0) * s.RIPPLE_DECAY
	if st == "shield_fall":
		if tt >= s.POP_FALL:
			for p in R: # broken: all of it soaks in where it fell (no regroup)
				lost.append({"p": Vector2(p.p.x, p.p.y), "l": float(s.SOAK_TIME)})
			R.clear()
			conn.clear()
			strength = PackedFloat32Array()
			st = "drain"
		return
	if tt <= s.SH_T:
		s_cur = sh_s0 + (cp_L - sh_s0) * _sh_herm(float(tt) / s.SH_T)
	else:
		var split := false
		for i in M() - 1:
			if not conn[i] or strength[i] < s.GAP_STR:
				split = true
				break
		hold_s += ((s.GAP_HOLD if split else 1.0) - hold_s) * s.GAP_HOLD_EASE
		s_cur += sph.vs * kick * hold_s
		kick = 1.0 + (kick - 1.0) * s.KICK_DECAY
	var sv := s_cur
	if not shield_up and tt >= s.SH_T:
		shield_up = true
		lr0 = (M() - 1) * s.sp()
		tail_s = sv - lr0
		lcap = lr0 * s.LEN_MULT
	if shield_up:
		var lmax := lr0 * s.LEN_MULT
		var ltar := lmax * left
		var vt := maxf(0.0, sph.vs - (lmax - lr0) / s.GROW_T)
		lcap = lcap + (ltar - lcap) * s.SHED_EASE if ltar < lcap else ltar
		tail_s = maxf(tail_s + (vt * hold_s * kick if tt > s.SH_T else 0.0), sv - lcap)
		var lc := sv - tail_s
		var gp := clampf(float(tt - s.SH_T) / s.GROW_T, 0.0, 1.0)
		wscale = 1.0 - (1.0 - s.WIDTH_MULT) * gp
		if not strained and left < s.STRAIN_AT:
			strained = true
			var tl: float = (sv - cp_L) / float(sph.vs)
			sph.segs.append({"t0": tl, "ph0": _phase_at(tl), "pr": sph.pr * 2.0})
		wob += ((s.WOBBLE if left < s.STRAIN_AT else 0.0) - wob) * 0.05
		var want := maxi(2, mini(floori(lc / s.sp() + 0.001) + 1, roundi((s.NMAX - 1) * s.LEN_MULT) + 1))
		while M() > want and M() > 2:
			var p: Pt = R.pop_back()
			conn.resize(maxi(M() - 1, 0))
			strength.resize(maxi(M() - 1, 0))
			drops.append({"p": p.p, "v": Vector3(0, 0, 0.4), "l": 20.0})
		while M() < want:
			var id := M()
			var q := _pos_at(sv - id * s.sp())
			var q0 := _pos_at(sv - id * s.sp() - sph.vs)
			var np := Pt.new(q, id)
			np.q = q0
			R.append(np)
			conn.append(true)
			strength.append(1.0)
	var C: Vector3 = sph.C
	for j in M():
		var p := R[j]
		var sj := sv - j * s.sp()
		var q := _pos_at(sj)
		if j > 0 and sj > cp_L and wob > 0.01:
			var d := Vector2(q.x - C.x, q.y - C.y)
			var o := sin(j * 0.45 - fr * 0.12) * wob
			if d.length() > 0.0:
				d = d.normalized() * o
				q += Vector3(d.x, d.y, 0.0)
		if j == 0:
			p.q = prev
			p.p = q
			prev = q
		elif sj > cp_L: # on the bubble every point sits on its spot (dents as fading offsets)
			p.off *= s.DENT_DECAY
			p.p = q + p.off
		else:
			_spring(p, q, s.SH_FOLLOW)
	if shield_up and left < s.CRACK_AT and tt % s.GAP_EVERY == 0 and M() > 3:
		var i := 1 + rng.randi_range(0, M() - 3)
		if i < conn.size() and conn[i]:
			conn[i] = false
			gaps[i] = s.GAP_LIFE
	for i in gaps.keys():
		gaps[i] -= 1
		if gaps[i] <= 0:
			if i < conn.size():
				conn[i] = true
			gaps.erase(i)
	_constrain(1)


## Broken: it bursts outward (away from the last hit), falls and soaks in. Keeps 24
## evenly spaced points; the others become droplets.
func pop() -> void:
	if st != "shield":
		return
	if M() > s.NMAX:
		var keep: Array[Pt] = []
		var step_ := float(M()) / s.NMAX
		for k in s.NMAX:
			keep.append(R[mini(M() - 1, roundi(k * step_))])
		for p in R:
			if not keep.has(p) and rng.randf() < 0.25:
				drops.append({"p": p.p, "v": (p.p - p.q) * 0.5 + Vector3(0, 0, 0.6), "l": 26.0})
		R = keep
	wscale = 1.0
	var C: Vector3 = sph.C if not sph.is_empty() else Vector3.ZERO
	for i in M():
		var p := R[i]
		var d := (p.p - C).normalized()
		var away := -last_hit * s.BREAK_AWAY
		var v := d * s.POP_OUT + (p.p - p.q) * s.POP_KEEP + Vector3(away.x, away.y, s.POP_UP)
		p.q = p.p - v
		if i % s.POP_SPLASH_EVERY == 0:
			_splash(p.p, 2, v)
	conn.resize(maxi(M() - 1, 0))
	strength.resize(maxi(M() - 1, 0))
	conn.fill(false)
	strength.fill(0.0)
	st = "shield_fall"
	tt = 0


## Run out with `share` of the shield left: the rope comes home that long
## (24 × share points, at least MIN_HOME_PTS), thickening back as its tail shortens.
func unwind(share: float) -> void:
	if st != "shield":
		return
	home_n = mini(M(), maxi(s.MIN_HOME_PTS, roundi(s.NMAX * share)))
	home_m0 = M()
	home_w0 = wscale
	for i in M():
		R[i].id = i
		R[i].near = true
		R[i].off = Vector3.ZERO
	conn.resize(maxi(M() - 1, 0))
	strength.resize(maxi(M() - 1, 0))
	conn.fill(true)
	strength.fill(1.0)
	gaps = {}
	has_base = false
	st = "return"
	tt = 0
	_start_home()


## The way home: the rope's own shape (tail to head), a turn-in arc toward a point
## bowed toward the caster's left, then a cubic onto the orbit's entry.
func _start_home() -> void:
	var lead := R[0]
	if self_cast and M() > 1:
		var hd := Vector2(R[0].p.x - R[1].p.x, R[0].p.y - R[1].p.y).normalized()
		var a := atan2(-hd.x, hd.y) + s.SELF_HOME_AHEAD
		aim = Vector3(sin(a) * 20.0, -cos(a) * 20.0, 10.0)
	var ep := entry_point()
	var E: Vector3 = ep.E
	var f: Vector2 = ep.f
	var pre := PackedVector3Array()
	for i in range(M() - 1, -1, -1):
		pre.append(R[i].p)
	var P0 := Vector2(lead.p.x, lead.p.y)
	var Eg := Vector2(E.x, E.y)
	var D := maxf(8.0, Eg.distance_to(P0))
	var sd := (Vector2(R[0].p.x - R[1].p.x, R[0].p.y - R[1].p.y) if M() > 1 \
			else Vector2(f.y * s.ORB, -f.x * s.ORB) - P0).normalized()
	var u := (Eg - P0).normalized()
	var nrm := Vector2(-u.y, u.x)
	var Lp := Vector2(f.y * s.ORB, -f.x * s.ORB)
	var mid := (P0 + Eg) / 2.0
	if nrm.dot(Lp - mid) < 0.0:
		nrm = -nrm
	var bend := 0.0 if self_cast else s.ARC_BEND
	var Wm := mid + nrm * D * bend
	var ti := _turn_in(P0, sd, Wm)
	var Q: Vector2 = ti.Q
	var D1 := maxf(2.0, Wm.distance_to(Q))
	var D2 := maxf(2.0, Eg.distance_to(Wm))
	var mu := (Eg - Q).normalized()
	var tr: Array = [P0]
	tr.append_array(ti.pts)
	_cubic(Q, Q + ti.h * D1 * s.LEAVE_CTRL * 1.3, Wm - mu * D1 * s.MID_CTRL * 1.3, Wm, s.PATH_SAMPLES / 2, tr)
	_cubic(Wm, Wm + mu * D2 * s.MID_CTRL * 1.3, Eg + f * D2 * s.CTRL_END, Eg, s.PATH_SAMPLES / 2, tr)
	var lifted := _lift_z(tr, lead.p.z, s.ZW, s.ARC_LIFT, true)
	lifted[lifted.size() - 1] = Vector3(E.x, E.y, s.ZW)
	var all := pre.duplicate()
	for i in range(1, lifted.size()):
		all.append(lifted[i])
	rpre = poly_path(pre).L
	rpath = poly_path(all)
	rs = rpre
	hold = 1.0
	joined_at = -1.0
	ret_at = sim_t
	prev = lead.p
	ret_scale = dist_scale(rpath.L - rpre)


func step() -> void:
	super()
	if home_n > 0 and (st == "return" or st == "wrap"):
		if M() > home_n:
			R.pop_back()
			conn.resize(maxi(M() - 1, 0))
			strength.resize(maxi(M() - 1, 0))
		wscale = lerpf(home_w0, 1.0, float(home_m0 - M()) / (home_m0 - home_n)) if home_m0 > home_n else 1.0
		if M() <= home_n and wscale >= 0.999:
			home_n = 0
	elif st != "shield":
		wscale += (1.0 - wscale) * s.HOME_THICKEN
