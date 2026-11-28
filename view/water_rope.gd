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
	var off := Vector3.ZERO # Water Shield's dents (WaterShieldRope)
	var s := 0.0 # Leeching Tide: distance along the stream
	var dark := 0.0 # Leeching Tide: leeched water's tint (1 = full leech colours)

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
## Stance 2 (the hoop): the stance the rope is heading for (1 or 2), the blend toward
## the hoop (0–1, over ENTER_T frames), and the closing link between tail and head.
## Water Whip's return (water physics phase 4): the share of the thrown water that
## comes back (0–1), set by the player's second press (`call_back`); < 0: not yet, and
## the water waits on the ground ("ground") until it is.
var return_share := -1.0
## Healing Touch (water physics phase 4, healing_touch_demo.html): the path (orbit
## arc, travel arc, helix), the lead's distance along it, the Hermite speed curve's
## numbers, how many leading points have turned to mist, whether it was a self-cast,
## the target (for the way home), and the points still climbing after the tail went
## home (`heal_back`).
var hpath := {}
var heal_s := 0.0
var heal_s0 := 0.0
var heal_L := 0.0
var heal_m0 := 0.0
var heal_vend := 0.0
var heal_gone := 0
var heal_n0 := 0
var heal_self := false
var heal_to := Vector3.ZERO
var heal_tail: Array[Pt] = []
var heal_tail_base := 0
var heal_tt := 0
var mists: Array = []
## Leeching Tide: the reach path, the stream (conduit) and its length, the hoop angle
## where it enters, the reach's speed curve, and whether water is still drawn out of
## the target (`end_leech` stops it).
var lpath := {}
var lead_s := 0.0
var leech_s0 := 0.0
var leech_Lt := 0.0
var leech_m0 := 0.0
var cd := {}
var cd_L := 0.0
var a_e := 0.0
var spawning := false
## Drawn width (Water Shield thins as it stretches; WaterShieldRope).
var wscale := 1.0
var goal := 1
var sb := 0.0
var wrap := false
var wrap_str := 0.0
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


## Stance 1 or 2 (the hoop). Leaving the hoop opens it at once.
func set_stance(n: int) -> void:
	if n == goal:
		return
	goal = n
	if n != 2:
		wrap = false
		wrap_str = 0.0


## The hoop's points: spread evenly over however many there are (27–33).
func hoop_n() -> int:
	return maxi(maxi(target_count, M()), 3)


## Point `id`'s place on the hoop: round the chest, breathing and tilting.
func hoop_t(id: float) -> Vector3:
	var n := hoop_n()
	var a := phase - id * TAU / n
	var br := sin(fr * TAU / (s.BREATH_T * 60.0))
	var r := s.HR + s.BREATH * br
	return Vector3(cos(a) * r, sin(a) * r, s.HZ + s.BREATH * 0.6 * br + s.HOOP_TILT * sin(a - fr * s.HOOP_TILT_SPEED))


## Where point `id` belongs while idling: the waist orbit, the hoop or between.
func target_t(id: int) -> Vector3:
	var b := ramp(sb, 1.0)
	return orbit_t(id) if b <= 0.0 else orbit_t(id).lerp(hoop_t(id), b)


## How far apart neighbouring points sit: the rope's spacing, or the hoop's.
func seg_len() -> float:
	return lerpf(s.SEG, TAU * s.HR / hoop_n(), ramp(sb, 1.0))


func orbit_t(id: float) -> Vector3:
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
	target_count = n


## The host's stance water (Hero.stance_water): how many points the rope holds. Fewer
## while it idles: the tail's points spill as droplets that soak in; more: new points
## join from the source one at a time (`step`).
func set_count(n: int) -> void:
	n = clampi(n, 0, WaterBending.full(2))
	if n == target_count:
		return
	target_count = n
	if st in ["idle", "wrap"]:
		while M() > n:
			var p: Pt = R.pop_back()
			_splash(p.p, 2, p.p - p.q)
			if conn.size() > maxi(M() - 1, 0):
				conn.resize(maxi(M() - 1, 0))
				strength.resize(maxi(M() - 1, 0))


## Leaving the stance: the water flows back where it came from, the tail first, over
## DRAIN_FRAMES; then the rope is gone.
const DRAIN_FRAMES := 30
var _drain_m := 0


func drain() -> void:
	target_count = 0
	st = "drain"
	tt = 0
	_drain_m = M()
	for i in conn.size():
		conn[i] = false
		strength[i] = 0.0


## A dead rope (drained) can be dropped by its owner.
func done() -> bool:
	return st == "drain" and R.is_empty() and drops.is_empty() and lost.is_empty() and mists.is_empty() \
			and heal_tail.is_empty()


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
func cast(target: Vector2, z_offset := 0.0) -> void:
	var recast := st == "wrap"
	if not can_cast() or M() < 2:
		fill_now(maxi(M(), s.MIN_KEEP))
	if recast:
		for i in conn.size():
			conn[i] = true
			strength[i] = 1.0
	aim = Vector3(target.x, target.y, s.TARGET_Z + z_offset)
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
	return_share = -1.0
	st = "spin" if Ts > 0 else "fly"
	tt = 0
	forming = false
	if st == "fly":
		_release()
	readout = {"pull_back": Bk, "spin_s": Ts / 60.0, "flight_s": Tf / 60.0, "recast": recast}


## Healing Touch: the whole rope winds round `target` (ground px from the hero; the
## hero itself for a self-cast): out along the orbit, a travel arc, then a helix from
## the waist up past the head, turning to mist at the top. The heal lands as the lead
## reaches the top, HEAL_T frames after the cast.
func heal(target: Vector2, self_cast: bool) -> void:
	if not can_cast() or M() < 2:
		fill_now(maxi(M(), s.MIN_KEEP))
	heal_self = self_cast
	var C := Vector2.ZERO if self_cast else target
	var n := M()
	var pts := PackedVector3Array()
	var k := (n - 1) * 4
	while k >= 0:
		pts.append(orbit_t(k / 4.0))
		k -= 1
	var P0 := pts[pts.size() - 1]
	heal_s0 = poly_path(pts).L
	var z0 := s.HERO_H * s.WAIST
	var z1 := s.HERO_H + s.TOP_LIFT
	var loops := lerpf(s.LOOPS_SELF, s.LOOPS_FAR, clampf(C.length() / s.FAR_REF, 0.0, 1.0))
	if self_cast:
		_helix(pts, C, phase, s.ORB, P0.z, z1, loops)
	else:
		var dv := (C - Vector2(P0.x, P0.y))
		var d := dv.normalized() if dv.length() > 0.0 else Vector2.RIGHT
		var a0 := atan2(d.y, d.x) - PI / 2.0
		var H0 := Vector3(C.x + cos(a0) * s.WRAP_R, C.y + sin(a0) * s.WRAP_R, z0)
		var vdir := Vector2(-sin(phase), cos(phase))
		var D := Vector2(H0.x, H0.y).distance_to(Vector2(P0.x, P0.y))
		var ca := minf(D * s.TRAVEL_CTRL, s.TRAVEL_CTRL_MAX)
		var cb := D * s.ARRIVE_CTRL
		var P1 := Vector2(P0.x, P0.y) + vdir * ca
		var P2 := Vector2(H0.x, H0.y) - d * cb
		var lift := s.LIFT_BASE + D * s.LIFT_PER
		for i in range(1, 81):
			var u := i / 80.0
			var m := 1.0 - u
			var xy := m * m * m * Vector2(P0.x, P0.y) + 3.0 * m * m * u * P1 + 3.0 * m * u * u * P2 + u * u * u * Vector2(H0.x, H0.y)
			pts.append(Vector3(xy.x, xy.y, lerpf(P0.z, z0, u) + lift * sin(PI * u)))
		_helix(pts, C, a0, s.WRAP_R, z0, z1, loops)
	hpath = poly_path(pts)
	heal_L = float(hpath.L) - heal_s0
	heal_m0 = clampf(w * s.ORB * s.HEAL_T / maxf(heal_L, 1.0), 0.0, s.M0_MAX)
	heal_vend = s.END_SLOPE * heal_L / s.HEAL_T
	heal_s = heal_s0
	heal_gone = 0
	heal_n0 = n
	heal_to = Vector3(C.x, C.y, s.TARGET_Z)
	heal_tail.clear()
	for i in conn.size():
		conn[i] = true
		strength[i] = 1.0
	return_share = -1.0
	forming = false
	st = "heal"
	tt = 0
	heal_tt = 0
	prev = R[0].p


func _helix(pts: PackedVector3Array, C: Vector2, a0: float, r_start: float, z0: float, z1: float, loops: float) -> void:
	var A := TAU * loops
	var N := maxi(30, ceili(loops * 72.0))
	for k in range(1, N + 1):
		var u := float(k) / N
		var rb := lerpf(r_start, s.WRAP_R, ramp(u, 0.3))
		var r := lerpf(rb, s.TOP_R, ramp(u - s.NARROW_AT, 1.0 - s.NARROW_AT))
		var a := a0 + A * u
		pts.append(Vector3(C.x + cos(a) * r, C.y + sin(a) * r, lerpf(z0, z1, u)))


## Leeching Tide: the hoop opens at its front and the whole of it arcs out to
## `target` (ground px from the hero), latching at the target's chest after REACH_T
## frames; then a stream flows home, drawing new (dark) water out of the target, until
## `end_leech`. The rest flows into the hoop, which closes again.
func leech(target: Vector2) -> void:
	if M() < 2:
		fill_now(maxi(M(), s.MIN_KEEP))
	wrap = false
	wrap_str = 0.0
	aim = Vector3(target.x, target.y, 10.0)
	var n := M()
	var pts := PackedVector3Array()
	var k := (n - 1) * 4
	while k >= 0:
		pts.append(hoop_t(k / 4.0))
		k -= 1
	leech_s0 = poly_path(pts).L
	var P0 := pts[pts.size() - 1]
	var d := target.normalized() if target.length() > 0.0 else Vector2.RIGHT
	var A := Vector3(target.x - d.x * s.ATTACH_R, target.y - d.y * s.ATTACH_R, s.ATTACH_Z)
	var vdir := Vector2(-sin(phase), cos(phase))
	var ti := WaterShieldRope.turn_in_static(s, Vector2(P0.x, P0.y), vdir, Vector2(A.x, A.y))
	var Q: Vector2 = ti.Q
	var Dq := maxf(2.0, Vector2(A.x, A.y).distance_to(Q))
	var tr: Array = [Vector2(P0.x, P0.y)]
	tr.append_array(ti.pts)
	WaterShieldRope._cubic(Q, Q + ti.h * minf(Dq * s.TRAVEL_CTRL, s.TRAVEL_CTRL_MAX),
			Vector2(A.x, A.y) - d * Dq * s.ARRIVE_CTRL, Vector2(A.x, A.y), 80, tr)
	var lz := WaterShieldRope._lift_z(tr, P0.z, A.z, s.LIFT_BASE + Vector2(A.x - P0.x, A.y - P0.y).length() * s.LIFT_PER, false)
	for i in range(1, lz.size()):
		pts.append(lz[i])
	lpath = poly_path(pts)
	leech_Lt = float(lpath.L) - leech_s0
	leech_m0 = clampf(w * s.HR * s.REACH_T / maxf(leech_Lt, 1.0), 0.0, s.M_MAX)
	lead_s = leech_s0
	for i in conn.size():
		conn[i] = true
		strength[i] = 1.0
	st = "reach"
	tt = 0
	prev = R[0].p
	forming = false


func end_leech() -> void:
	spawning = false
	if st == "reach":
		_latch()
		spawning = false


func _leech_herm(u: float) -> float:
	var u2 := u * u
	var u3 := u2 * u
	return (u3 - 2.0 * u2 + u) * leech_m0 + (-2.0 * u3 + 3.0 * u2) + (u3 - u2) * 0.6


## The stream home: from the attach point a turn-in arc toward a point bowed toward
## the caster's left, then onto the hoop's tangent at the entry on the caster's right.
func _build_conduit(A: Vector3) -> void:
	var ep := entry_point()
	var f: Vector2 = ep.f
	var E := Vector3(-f.y * s.HR, f.x * s.HR, s.HZ)
	a_e = atan2(E.y, E.x)
	var Ag := Vector2(A.x, A.y)
	var Eg := Vector2(E.x, E.y)
	var hd := (-Ag).normalized() if Ag.length() > 0.0 else Vector2.LEFT
	var D := maxf(8.0, Eg.distance_to(Ag))
	var cdir := (Eg - Ag) / D
	var nrm := Vector2(-cdir.y, cdir.x)
	var Lp := Vector2(f.y * s.HR, -f.x * s.HR)
	var mid := (Ag + Eg) / 2.0
	if nrm.dot(Lp - mid) < 0.0:
		nrm = -nrm
	var Wm := mid + nrm * D * s.STREAM_BEND
	var ti := WaterShieldRope.turn_in_static(s, Ag, hd, Wm)
	var Q: Vector2 = ti.Q
	var D1 := maxf(2.0, Wm.distance_to(Q))
	var D2 := maxf(2.0, Eg.distance_to(Wm))
	var u := (Eg - Q).normalized()
	var tr: Array = [Ag]
	tr.append_array(ti.pts)
	WaterShieldRope._cubic(Q, Q + ti.h * D1 * s.LEAVE_CTRL * 1.3, Wm - u * D1 * s.MID_CTRL * 1.3, Wm, 100, tr)
	WaterShieldRope._cubic(Wm, Wm + u * D2 * s.MID_CTRL * 1.3, Eg + f * D2 * s.END_CTRL, Eg, 100, tr)
	var pts := WaterShieldRope._lift_z(tr, A.z, s.HZ, s.STREAM_LIFT, false)
	pts[pts.size() - 1] = E
	cd = poly_path(pts)
	cd_L = cd.L


## Along the stream, then round the hoop past its entry.
func _cd_at(sv: float) -> Vector3:
	if sv <= cd_L:
		return along(cd, sv / cd_L)
	var a := a_e + (sv - cd_L) / s.HR
	var h := Vector3(cos(a) * s.HR, sin(a) * s.HR, s.HZ)
	var br := sin(fr * TAU / (s.BREATH_T * 60.0))
	var hb := Vector3(cos(a) * (s.HR + s.BREATH * br), sin(a) * (s.HR + s.BREATH * br),
			s.HZ + s.BREATH * 0.6 * br + s.HOOP_TILT * sin(a - fr * s.HOOP_TILT_SPEED))
	return h.lerp(hb, ramp(sv - cd_L, s.HOOP_BLEND_IN))


func _latch() -> void:
	_build_conduit(lpath.pts[lpath.pts.size() - 1])
	R.reverse()
	var n := M()
	var sp := TAU * s.HR / maxf(float(hoop_n()), 1.0)
	for i in n:
		R[i].s = (n - 1 - i) * sp
		R[i].id = i
	conn.resize(maxi(n - 1, 0))
	strength.resize(maxi(n - 1, 0))
	conn.fill(true)
	strength.fill(1.0)
	st = "leech"
	tt = 0
	spawning = true


func _step_leech() -> void:
	var sp := TAU * s.HR / maxf(float(hoop_n()), 1.0)
	if st == "reach":
		lead_s = leech_s0 + leech_Lt * _leech_herm(float(tt) / s.REACH_T) if tt <= s.REACH_T else leech_s0 + leech_Lt
		for j in M():
			var q := along(lpath, maxf(0.0, lead_s - j * sp) / lpath.L)
			if j == 0:
				R[j].q = prev
				R[j].p = q
				prev = q
			else:
				_spring(R[j], q, s.REACH_FOLLOW)
		_constrain(1)
		if tt >= s.REACH_T:
			_latch()
		return
	var k := lerpf(s.LATCH_K0, s.LATCH_K1, ramp(tt, s.LATCH_BLEND))
	for p in R:
		p.s += s.FLOW_V
		_spring(p, _cd_at(p.s), k)
		if p.s > cd_L:
			p.dark = maxf(0.0, p.dark - s.DARK_FADE)
	var arc_max := (hoop_n() - 1) * sp + sp * 0.5
	while M() > 1 and R[0].s > cd_L + arc_max: # a full ring home: the front soaks into the hero
		R.pop_front()
		conn.resize(maxi(M() - 1, 0))
		strength.resize(maxi(M() - 1, 0))
	if spawning:
		var t := R[M() - 1]
		if t.s >= sp: # new water drawn out of the target
			var np := Pt.new(_cd_at(t.s - sp), M())
			np.s = t.s - sp
			np.dark = 1.0
			R.append(np)
			conn.append(true)
			strength.append(1.0)
	elif R[M() - 1].s > cd_L + 2.0:
		# Everything is back in the hoop: it takes over at the stream's speed.
		phase = a_e + (R[0].s - cd_L) / s.HR
		w = s.FLOW_V / s.HR
		for i in M():
			R[i].id = i
		st = "idle"
		tt = 0
		ib = 1.0
	_constrain(0)


## Water Shield's states (WaterShieldRope overrides this).
func _step_shield() -> void:
	pass


func _herm(u: float) -> float:
	var u2 := u * u
	var u3 := u2 * u
	return (u3 - 2.0 * u2 + u) * heal_m0 + (-2.0 * u3 + 3.0 * u2) + (u3 - u2) * s.END_SLOPE


## The host's word on the heal: `share` of the water (what full health turned away)
## comes home off the rope's tail (a self-cast unwinds straight into the orbit); the
## rest climbs on and turns to mist.
func heal_back(share: float) -> void:
	if st != "heal":
		return
	var keep := mini(roundi(clampf(share, 0.0, 1.0) * heal_n0), M())
	heal_tail = R.slice(0, M() - keep)
	heal_tail_base = heal_gone
	R = R.slice(M() - keep)
	for i in R.size():
		R[i].id = i
	conn.resize(maxi(M() - 1, 0))
	strength.resize(maxi(M() - 1, 0))
	conn.fill(true)
	strength.fill(1.0)
	tt = 0
	if M() == 0:
		st = "idle"
	elif heal_self:
		st = "idle"
		ib = 0.15
	else:
		aim = heal_to
		st = "return"
		for i in M():
			R[i].near = true
			R[i].off = Vector3.ZERO
		has_base = false
		_start_home_arc()


## Moves points along the heal path: the lead exactly, the others springing to
## their place; those past the top turn to mist. `base`: how many went before.
## Returns how many turned to mist.
func _heal_follow(pts: Array[Pt], sv: float, base: int, lead_exact: bool) -> int:
	var gone := 0
	var L: float = hpath.L
	while not pts.is_empty():
		var sj := sv - (base + gone) * s.sp()
		if sj < L - 0.01:
			break
		pts.pop_front()
		_mist_at(hpath.pts[hpath.pts.size() - 1])
		gone += 1
	for j in pts.size():
		var sj := sv - (base + gone + j) * s.sp()
		var q := along(hpath, maxf(0.0, sj) / L)
		if j == 0 and lead_exact and gone == 0:
			pts[j].q = prev
			pts[j].p = q
			prev = q
		else:
			_spring(pts[j], q, s.HEAL_FOLLOW)
	return gone


func _mist_at(at: Vector3) -> void:
	for k in s.MIST_PER:
		var life := float(s.MIST_LIFE + rng.randi_range(0, s.MIST_LIFE_RND))
		mists.append({"p": at, "v": Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.35, 0.35),
				rng.randf_range(0.15, 0.5)), "l": life, "L0": life, "k": rng.randi_range(0, 3)})


func _step_mists() -> void:
	var keep := []
	for m in mists:
		m.p += m.v
		m.v = Vector3(m.v.x * 0.95, m.v.y * 0.95, m.v.z * 0.95 - 0.006)
		if m.p.z < 1.0:
			m.p.z = 1.0
		m.l -= 1.0
		if m.l > 0.0:
			keep.append(m)
	mists = keep


## Frost Shard: `n` points break off the orbit where it faces `dir` (ground px); if
## the orbit's gap faces it, the nearer end breaks off. The two ends re-link (the link
## fading in), and the orbit springs pull the tail forward. Returns the piece's
## positions, front first.
func break_piece(dir: Vector2, n: int, center := Vector2.ZERO) -> Array[Vector3]:
	var out: Array[Vector3] = []
	n = mini(n, M())
	if n <= 0:
		return out
	var want := atan2(dir.y, dir.x)
	var best := 0
	var bd := INF
	for i in M():
		var d := absf(angle_difference(atan2(R[i].p.y - center.y, R[i].p.x - center.x), want))
		if d < bd:
			bd = d
			best = i
	var start := clampi(best - n / 2, 0, M() - n)
	if bd > 2.0 * s.ang(): # the gap faces the cast: the nearer end goes
		start = 0 if best < M() / 2 else M() - n
	for i in n:
		out.append(R[start + i].p)
	for i in n:
		R.remove_at(start)
	for i in M():
		R[i].id = i
	conn.resize(maxi(M() - 1, 0))
	strength.resize(maxi(M() - 1, 0))
	conn.fill(true)
	strength.fill(1.0)
	if start > 0 and start - 1 < strength.size():
		strength[start - 1] = 0.0 # the ends re-link, fading in
	return out


## The second press: `share` of the thrown water comes home, the rest soaks in.
## Before the water has landed it is kept for the landing; on the ground it rises now.
func call_back(share: float) -> void:
	return_share = clampf(share, 0.0, 1.0)
	if st == "ground":
		_cut_and_rise()


## Keeps the front `return_share` of the regrouped water; the tail's points soak in.
func _cut_and_rise() -> void:
	var keep := roundi(return_share * M())
	while M() > keep:
		var p: Pt = R.pop_back()
		lost.append({"p": Vector2(p.p.x, p.p.y), "l": float(s.SOAK_TIME)})
	conn.resize(maxi(M() - 1, 0))
	strength.resize(maxi(M() - 1, 0))
	tt = 0
	if M() == 0:
		st = "idle" # all of it soaked in: the rope grows back from the source
		has_base = false
		return
	st = "rise"


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


## Healing Touch's water coming home from an ally (2026-11-28, user): it doesn't
## turn back down the helix; it keeps its heading and curves home, as the Water
## Shield's rope does: the rope's own shape (tail to head) as the start of the path,
## a turn-in arc toward a point bowed toward the caster's left, then a cubic onto the
## orbit's entry.
func _start_home_arc() -> void:
	var lead := R[0]
	var ep := entry_point()
	var E: Vector3 = ep.E
	var f: Vector2 = ep.f
	var pre := PackedVector3Array()
	for i in range(M() - 1, -1, -1):
		pre.append(R[i].p)
	var P0 := Vector2(lead.p.x, lead.p.y)
	var Eg := Vector2(E.x, E.y)
	var D := maxf(8.0, Eg.distance_to(P0))
	var Lp := Vector2(f.y * s.ORB, -f.x * s.ORB)
	var sd := (Vector2(R[0].p.x - R[1].p.x, R[0].p.y - R[1].p.y) if M() > 1 else Lp - P0).normalized()
	var u := (Eg - P0).normalized()
	var nrm := Vector2(-u.y, u.x)
	var mid := (P0 + Eg) / 2.0
	if nrm.dot(Lp - mid) < 0.0:
		nrm = -nrm
	var Wm := mid + nrm * D * s.ARC_BEND
	var ti := WaterShieldRope.turn_in_static(s, P0, sd, Wm)
	var Q: Vector2 = ti.Q
	var D1 := maxf(2.0, Wm.distance_to(Q))
	var D2 := maxf(2.0, Eg.distance_to(Wm))
	var mu := (Eg - Q).normalized()
	var tr: Array = [P0]
	tr.append_array(ti.pts)
	WaterShieldRope._cubic(Q, Q + ti.h * D1 * s.LEAVE_CTRL * 1.3, Wm - mu * D1 * s.MID_CTRL * 1.3, Wm, s.PATH_SAMPLES / 2, tr)
	WaterShieldRope._cubic(Wm, Wm + mu * D2 * s.MID_CTRL * 1.3, Eg + f * D2 * s.CTRL_END, Eg, s.PATH_SAMPLES / 2, tr)
	var lifted := WaterShieldRope._lift_z(tr, lead.p.z, s.ZW, s.ARC_LIFT, true)
	lifted[lifted.size() - 1] = Vector3(E.x, E.y, s.ZW)
	var all := pre.duplicate()
	for i in range(1, lifted.size()):
		all.append(lifted[i])
	var pre_L: float = poly_path(pre).L
	rpath = poly_path(all)
	rs = pre_L
	hold = 1.0
	joined_at = -1.0
	ret_at = sim_t
	prev = lead.p
	ret_scale = dist_scale(rpath.L - pre_L)


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
	var SEG := seg_len() if st == "idle" else s.SEG
	for _it in s.ITERATIONS:
		if wrap and n > 2 and st == "idle":
			_link(R[n - 1], R[0], SEG, wrap_str, tg)
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
			if d <= SEG and tg == 0.0:
				continue
			var corr := d - SEG
			if d < SEG:
				corr *= tg
			corr *= strength[i]
			if af:
				corr = _clamp(corr, -cap, cap)
				b.p -= dv / d * corr
			else:
				var h := _clamp(corr * 0.5, -cap, cap)
				a.p += dv / d * h
				b.p -= dv / d * h


## The hoop's closing link (tail to head), like the reference's link().
func _link(a: Pt, b: Pt, L: float, k: float, push: float) -> void:
	var dv := b.p - a.p
	var d := dv.length()
	if d == 0.0:
		d = 1.0
	var corr := d - L
	if d < L:
		corr *= push
	corr *= k * 0.5
	a.p += dv / d * corr
	b.p -= dv / d * corr


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
	var tw := s.W_SPIN if st == "spin" else lerpf(s.w_idle(), TAU / (s.LAP2 * 60.0), ramp(sb, 1.0))
	sb = _clamp(sb + (1.0 if goal == 2 else -1.0) / s.ENTER_T, 0.0, 1.0)
	if goal == 2 and not wrap and sb >= s.CLOSE_AT and M() >= target_count and M() > 2:
		wrap = true
		wrap_str = 0.0
	if wrap:
		wrap_str = minf(1.0, wrap_str + 1.0 / s.WRAP_FADE)
	w += (tw - w) * (s.SPIN_EASE if st == "spin" else s.WRAP_EASE if st == "wrap" else s.IDLE_EASE)
	phase += w
	_step_mists()
	if not heal_tail.is_empty() and st != "heal":
		# Healing Touch's front, still climbing after the tail went home.
		for p in heal_tail:
			var v := (p.p - p.q) * s.HEAL_DRAG
			p.q = p.p
			p.p += v
		heal_s += heal_vend
		heal_tail_base += _heal_follow(heal_tail, heal_s, heal_tail_base, false)
	if st == "drain":
		_step_drain()
		_step_drops()
		return
	if R.is_empty():
		if st == "idle" and target_count > 0:
			_add_point(true)
		_step_drops()
		return
	var damp := s.FLY_DAMP if st in ["fly", "fall", "pour"] else s.HEAL_DRAG if st in ["heal", "reach", "leech"] \
			else s.SH_DRAG if st == "shield" else s.POP_DAMP if st == "shield_fall" \
			else s.RET_DRAG if _reforming() else s.IDLE_DAMP
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
		var gz := s.GRAV if st == "fall" or st == "shield_fall" or (st == "pour" and i < poured.size() and poured[i]) else 0.0
		p.q = p.p
		p.p += v - Vector3(0, 0, gz)
	for i in M() - 1:
		strength[i] = minf(1.0, strength[i] + 1.0 / s.LINK_FADE) if conn[i] else 0.0
	if has_base and (st == "rise" or st == "return"):
		var bl := base.length() if base.length() > 0.0 else 1.0
		var nb := bl + (s.RISE_STOP - bl) * s.RISE_DRIFT
		base *= nb / bl
	match st:
		"shield", "shield_fall":
			_step_shield()
		"reach", "leech":
			_step_leech()
		"idle", "spin":
			ib = minf(1.0, ib + 1.0 / s.IDLE_BLEND)
			var k := s.SPIN_SPRING if st == "spin" else s.IDLE_SPRING * ib
			if sb > 0.0 and st == "idle":
				k = lerpf(k, s.HOOP_FOLLOW, ramp(sb, 1.0))
			for p in R:
				_spring(p, target_t(p.id) if st == "idle" else orbit_t(p.id), k)
				p.dark = maxf(0.0, p.dark - s.DARK_FADE)
			_constrain(0)
			# Refill from the pouch (the hips) or the water nearby, one point at a time.
			var every := s.FORM_EVERY if forming else s.HOOP_ADD_EVERY if goal == 2 else s.REFILL_EVERY
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
				st = "ground"
				tt = 0
				if return_share >= 0.0:
					_cut_and_rise()
		"ground":
			pass # regrouped on the ground, waiting for the second press (call_back)
		"heal":
			heal_tt += 1
			var sv := heal_s0 + heal_L * _herm(float(heal_tt) / s.HEAL_T) if heal_tt <= s.HEAL_T \
					else heal_s + heal_vend
			heal_s = sv
			heal_gone += _heal_follow(R, sv, heal_gone, true)
			conn.resize(maxi(M() - 1, 0))
			strength.resize(maxi(M() - 1, 0))
			_constrain(1 if heal_gone == 0 else 0)
			if R.is_empty():
				st = "idle" # all of it went into the heal: the rope grows back from the source
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
	# Points let go one after another from the tail: the last ones first.
	var free_from := _drain_m - ceili(float(tt) * _drain_m / DRAIN_FRAMES)
	for p in R:
		var v := (p.p - p.q) * s.RET_DRAG
		p.q = p.p
		p.p += v
		if p.id >= free_from:
			_spring(p, source, 0.15)
		else:
			_spring(p, orbit_t(p.id), s.IDLE_SPRING)
		if p.p.distance_to(source) > 3.0:
			keep.append(p)
	R = keep
	conn.resize(maxi(R.size() - 1, 0))
	strength.resize(maxi(R.size() - 1, 0))
	conn.fill(false)
	strength.fill(0.0)
