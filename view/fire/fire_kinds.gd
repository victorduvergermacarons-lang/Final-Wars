class_name FireKinds
extends RefCounted
## The reference's per-ability timelines (fire-ability-reference.html, step()), one
## function per kind: what each step emits on the fluid, the particles, the projectile
## head, the whip, the beam, the warning marker and the heat haze. Look only: gameplay
## (hits, burns, leaps, areas) is the host's and these follow its timings.
##
## `e.hero` is the caster and `e.tg` the target or aimed point, in local cells; both
## follow the actors each step. Times are in steps at the effect's playback speed, as in
## the reference (secF for the times that are gameplay: they stay real).

const ZC := 13.0
const PXC := 1.4


static func sec_f(e: FireEffect, s: float) -> int:
	return roundi(s * 60.0 * float(e.look.time_scale))


static func punch_len(p: Dictionary) -> int:
	return maxi(2, roundi(float(p.get("ptime", 0.1)) * 60.0))


static func kick_len(p: Dictionary) -> int:
	return maxi(2, roundi(float(p.get("ktime", 0.2)) * 60.0))


static func gap_f(p: Dictionary) -> int:
	return maxi(4, roundi(float(p.get("gap", 0.22)) * 60.0))


## How long the kind emits (steps), so the window can be freed after its tail.
static func length(e: FireEffect) -> int:
	var p := e.p
	match e.look.kind:
		"punch": return maxi(punch_len(p), 40)
		"kick": return maxi(kick_len(p), 60) + sec_f(e, float(p.get("btime", 2.0)))
		"combo": return 2 * gap_f(p) + kick_len(e.p_kick) + 40 + sec_f(e, float(e.p_kick.get("btime", 2.0)))
		"dart", "fireball": return 200
		"swb": return roundi(float(p.sdur) * 60.0 + float(p.slife) + 20.0)
		"overheat": return roundi((float(p.ocast) + float(p.odur)) * 60.0 + 50.0)
		"whip": return roundi((float(p.wout) + float(p.wext) + float(p.wret)) * 60.0 + 30.0)
		"jet": return roundi(float(p.jdur) * 60.0 + 30.0)
		"phoenix": return roundi(float(p.pleap) * 60.0 + 110.0)
		"wheel": return roundi(float(p.wspin) * 60.0 + 40.0)
		"inferno": return sec_f(e, float(p.itele) + float(p.idur)) + 70
		"breathfire": return roundi(float(p.bdur) * 60.0 + 50.0)
		"combust": return roundi(cboom(p) * 60.0 + 100.0)
		"stream": return e.hold_steps
	return 120


static func cboom(p: Dictionary) -> float:
	return float(p.cstart) + float(p.cbeam) + float(p.chold)


## The playback rate now (Overheat and Combustion Blast slow down after their moment).
static func rate(e: FireEffect) -> float:
	var p := e.p
	if e.look.kind == "overheat" and e.ct >= (float(p.ocast) + float(p.odur)) * 60.0:
		return e.look.time_scale_after
	if e.look.kind == "combust" and e.ct >= cboom(p) * 60.0:
		return e.look.time_scale_after
	return e.look.time_scale


## One step of the kind's timeline.
static func step(e: FireEffect, sim: FireSim) -> void:
	var p := e.p
	var ct := e.ct
	var ax := cos(e.aim)
	var ay := sin(e.aim)
	var pxv := -ay
	var pyv := ax
	var HX := e.hero.x
	var HY := e.hero.y
	var s := e.slot
	e.whip_pts = []
	e.streak = 0.0
	e.beam = 0.0
	e.btail = 0.0
	e.haze *= 0.95
	e.bmul = 1.0
	match e.look.kind:
		"stream":
			if ct < e.hold_steps:
				var wob := 0.04 * sin(e.f * 0.21) + 0.03 * sin(e.f * 0.53 + 1.0)
				sim.emit(s, HX + ax * 6.5, HY + ay * 6.5, ax, ay, 1.25, float(p.temp), float(p.launch), wob)
		"punch":
			var L := punch_len(p)
			if ct < L:
				var k := minf(1.0, float(ct) / float(L - 1))
				var r := 3.0 + 3.5 * k
				sim.emit(s, HX + ax * r, HY + ay * r, ax, ay, float(p.prad), float(p.temp), float(p.launch))
		"kick":
			var L := kick_len(p)
			if ct < L:
				_kick_emit(e, sim, p, ct, ax, ay)
			_burn(e, sim, p, L)
		"combo":
			var g := gap_f(e.p_punch)
			var L := punch_len(e.p_punch)
			var LK := kick_len(e.p_kick)
			var pp: Dictionary = e.p_punch if ct < 2 * gap_f(p) else e.p_kick
			for h in 2:
				var c := ct - h * gap_f(p)
				if c >= 0 and c < L:
					var k := minf(1.0, float(c) / float(L - 1))
					var r := 3.0 + 3.5 * k
					var sd := -1.2 if h == 1 else 1.2
					sim.emit(s, HX + ax * r + pxv * sd, HY + ay * r + pyv * sd, ax, ay, float(pp.prad), float(pp.temp), float(pp.launch))
			var c2 := ct - 2 * gap_f(p)
			if c2 >= 0 and c2 < LK:
				_kick_emit(e, sim, e.p_kick, c2, ax, ay)
			if c2 >= 0 and c2 < LK + 20:
				e.bmul = float(p.get("fin", 1.5))
			if c2 == LK / 2:
				# the finisher's first contact pushes the air around the target along the aim
				sim.air(s, e.tg.x, e.tg.y, 6.0, 2, float(p.get("kpush", 0.3)), ax, ay)
			_burn(e, sim, e.p_kick, 2 * gap_f(p) + LK)
			e.p_now = pp
		"dart", "fireball":
			_projectile(e, sim, p, ax, ay)
		"swb":
			var L := float(p.sdur) * 60.0
			if ct < L:
				var n := float(p.srate)
				while n > 0.0:
					if n < 1.0 and randf() > n:
						break
					n -= 1.0
					var sp := float(p.sspd) * (0.7 + 0.6 * randf())
					var a := e.aim + (randf() - 0.5) * 0.35
					var nos := -0.35 if randf() < 0.5 else 0.35
					e.part(HX + ax * 1.6 + pxv * nos, HY + ay * 1.6 + pyv * nos, 19.0, cos(a) * sp * 0.42, sin(a) * sp * 0.42,
							-sp * (0.95 + 0.3 * randf()), float(p.slife) * (0.7 + 0.6 * randf()), 0)
		"overheat":
			var Lc := float(p.ocast) * 60.0
			var Lb := float(p.odur) * 60.0
			var tg := e.tg
			if ct < Lc:
				if ct % 2 == 0:
					for k in 2:
						var q := randf()
						e.part(HX + ax * 5.0, HY + ay * 5.0, 13.0, (tg.x - HX - ax * 5.0) / Lc * (0.9 + 0.2 * q),
								(tg.y - HY - ay * 5.0) / Lc * (0.9 + 0.2 * q), (randf() - 0.5) * 0.3, Lc, 5)
			elif ct < Lc + Lb:
				var sN := (float(ct) - Lc) / Lb
				e.burn_unit(sim, tg.x, tg.y, 0.2 + float(p.oburn) * sN, 0.5 + (float(p.obtemp) - 0.5) * sN)
				e.haze = maxf(e.haze, float(p.ohaze) * minf(1.0, (float(ct) - Lc) / maxf(1.0, float(p.ohrise) * 60.0)))
			elif ct == roundi(Lc + Lb):
				sim.pburst(s, tg.x, tg.y, float(p.popR), float(p.popT), float(p.popS), 0.0)
				e.haze = 0.0
		"whip":
			_whip(e, sim, p, ax, ay, pxv, pyv)
		"jet":
			var L := float(p.jdur) * 60.0
			if ct < L + 20:
				var up := minf(1.0, ct / 18.0) if ct < L else maxf(0.0, 1.0 - (ct - L) / 20.0)
				e.hz = float(p.jlift) * up + (1.5 * sin(ct * 0.15) * up if ct < L else 0.0)
				if ct < L:
					var n := float(p.jrate)
					while n > 0.0:
						if n < 1.0 and randf() > n:
							break
						n -= 1.0
						var sd := -1.0 if randf() < 0.5 else 1.0
						e.part(HX + sd * 0.7, HY - sd * 0.7, e.hz + 1.0, (randf() - 0.5) * 0.05, (randf() - 0.5) * 0.05,
								-(1.2 + randf() * 0.8), maxf(4.0, e.hz / 1.5), 2)
					var fall := maxf(0.0, 1.0 - e.hz / 30.0)
					if fall > 0.05:
						for k in 10:
							var a := k / 10.0 * TAU + e.f * 0.3
							sim.emit(s, HX + cos(a) * float(p.jrad), HY + sin(a) * float(p.jrad), cos(a), sin(a), 0.9,
									float(p.jsT) * fall, float(p.jsplash), 0.0, -ZC + 1.0, 0.0, 0.3, 0.4)
						sim.air(s, HX, HY, 8.0, 0, float(p.gpush) * fall)
						if randf() < float(p.jgrate):
							var a := randf() * TAU
							e.patch_later(HX + cos(a) * float(p.jrad), HY + sin(a) * float(p.jrad), float(p.jgr), float(p.jgb), 1.0)
			else:
				e.hz = 0.0
		"phoenix":
			var L := maxf(4.0, float(p.pleap) * 60.0)
			if ct == 0:
				var d := e.tg - e.start
				var dl := maxf(d.length(), 0.001)
				var r := minf(96.0, maxf(0.0, dl - 16.0))
				e.land = e.start + d / dl * r
			if ct < L:
				var t := float(ct) / L
				e.hz = float(p.pheight) * 4.0 * t * (1.0 - t)
				var hp := e.start.lerp(e.land, t)
				var n := float(p.ptrail)
				while n > 0.0:
					if n < 1.0 and randf() > n:
						break
					n -= 1.0
					e.part(hp.x + (randf() - 0.5) * 2.0, hp.y + (randf() - 0.5) * 2.0, e.hz + 10.0 + randf() * 6.0,
							-ax * 0.3 + (randf() - 0.5) * 0.3, -ay * 0.3 + (randf() - 0.5) * 0.3, 0.15 + randf() * 0.2, 22.0 + randf() * 12.0, 3)
				if t > 0.5:
					var m := float(p.prain)
					while m > 0.0:
						if m < 1.0 and randf() > m:
							break
						m -= 1.0
						var a := randf() * TAU
						var sp := float(p.pspread) * (0.5 + randf())
						e.drop(hp.x + (randf() - 0.5) * 2.0, hp.y + (randf() - 0.5) * 2.0, e.hz + 1.0,
								(e.land.x - e.start.x) / L + cos(a) * sp, (e.land.y - e.start.y) / L + sin(a) * sp,
								float(p.pheight) * 4.0 * (1.0 - 2.0 * t) / L, float(p.pdrop), float(p.ptchT), 8.0 * float(p.pheight) / (L * L))
			elif ct == roundi(L):
				e.hz = 0.0
				sim.pburst(s, e.land.x, e.land.y, float(p.popR), float(p.popT), float(p.popS), -ZC + 2.0, true)
			else:
				e.hz = 0.0
		"wheel":
			var L := maxf(4.0, float(p.wspin) * 60.0)
			if ct < L:
				var k := float(ct) / (L - 1.0)
				var th := e.aim + PI * 0.5 + k * float(p.wrev) * TAU
				var cx := HX + cos(th) * float(p.wrad)
				var cy := HY + sin(th) * float(p.wrad)
				var tn := Vector2(-sin(th), cos(th))
				var on := Vector2(cos(th), sin(th))
				var d := (tn * float(p.wtan) + on * (1.0 - float(p.wtan))).normalized()
				sim.emit(s, cx, cy, d.x, d.y, float(p.frad), float(p.temp), float(p.launch), 0.0, float(p.kz0) - ZC, 0.0, 0.0, 0.0)
		"inferno":
			_inferno(e, sim, p)
		"breathfire":
			var L := float(p.bdur) * 60.0
			if ct < L:
				var mx := HX + ax * 4.0
				var my := HY + ay * 4.0
				var cone := float(p.bcone) * PI / 180.0
				for k in 7:
					var a := e.aim + (k / 6.0 - 0.5) * cone * (0.85 + 0.1 * sin(e.f * 0.3 + k))
					sim.emit(s, mx + cos(a) * 1.5, my + sin(a) * 1.5, cos(a), sin(a), 1.1, float(p.temp), float(p.launch), 0.0,
							float(p.bz), 0.0, float(p.bloose), 0.0)
		"combust":
			var L1 := float(p.cfirst) * 60.0
			var Ls := float(p.cstart) * 60.0
			var Lb := maxf(2.0, float(p.cbeam) * 60.0)
			var Lh := float(p.chold) * 60.0
			var LE := roundi(Ls + Lb + Lh)
			if ct < LE:
				if ct < L1:
					var k := ct / L1
					e.streak = 1.0 if k < 0.3 else 1.0 - (k - 0.3) / 0.7 * 0.85
				if ct >= Ls:
					e.beam = minf(1.0, (ct - Ls + 1.0) / Lb)
					e.btail = 0.5 * minf(1.0, (ct - Ls - Lb + 1.0) / maxf(1.0, Lh)) if ct >= Ls + Lb else 0.0
			elif ct == LE:
				sim.pburst(s, e.tg.x, e.tg.y, float(p.popR), float(p.popT), float(p.popS), 0.0)
				e.patch_later(e.tg.x, e.tg.y, float(p.ptchR), float(p.ptchT), float(p.cign))


## The kick's foot: a tilted arc swept around the hero (the reference's footAt).
static func foot_at(e: FireEffect, p: Dictionary, ct: int) -> Array:
	var L := kick_len(p)
	var k := minf(1.0, float(ct) / float(L - 1))
	var sw := float(p.karc) * PI / 180.0
	var th := (PI + sw) / 2.0 - sw * k
	var al := float(p.ktilt) * PI / 180.0
	var sa := maxf(0.05, sin(al))
	var R := maxf(2.0, (float(p.kapex) - float(p.kz0)) / (sa * PXC))
	var fx := cos(e.aim)
	var fy := sin(e.aim)
	var sx := -fy
	var sy := fx
	var c := cos(th)
	var sn := sin(th)
	var ca := cos(al)
	var hx := c * sx + sn * ca * fx
	var hy := c * sy + sn * ca * fy
	return [e.hero.x + R * hx, e.hero.y + R * hy, th, float(p.kz0) + R * sn * sa * PXC, hx, hy, sn * sa]


static func _kick_emit(e: FireEffect, sim: FireSim, p: Dictionary, ct: int, ax: float, ay: float) -> void:
	var ft := foot_at(e, p, ct)
	var hl := Vector2(ft[4], ft[5]).length()
	var dx: float = ft[4] / hl if hl > 1e-3 else ax
	var dy: float = ft[5] / hl if hl > 1e-3 else ay
	sim.emit(e.slot, ft[0], ft[1], dx, dy, float(p.frad), float(p.temp), float(p.launch) * hl, 0.0, float(ft[3]) - ZC,
			float(p.launch) * float(ft[6]) * PXC, 0.0, 0.0)


## The kick's burn on the target (gameplay: the burn debuff), from the kick's end.
static func _burn(e: FireEffect, sim: FireSim, p: Dictionary, from_step: int) -> void:
	var bt := sec_f(e, float(p.get("btime", 2.0)))
	var c := e.ct - from_step
	if c >= 0 and c < bt and e.target_id >= 0:
		var left := float(bt - c)
		e.burn_unit(sim, e.tg.x, e.tg.y, float(p.get("brate", 0.5)), float(p.get("btemp", 0.8)) * minf(1.0, left / 30.0))


static func _projectile(e: FireEffect, sim: FireSim, p: Dictionary, ax: float, ay: float) -> void:
	var fb := e.look.kind == "fireball"
	var ct := e.ct
	if ct == 0:
		var rng := 112.0 if fb else 104.0
		var d := Vector2(ax, ay)
		var R := rng
		if fb:
			var ex := e.tg - e.hero
			var l := ex.length()
			if l > 3.0:
				d = ex / l
				R = minf(rng, maxf(6.0, l - 5.0)) if e.target_id < 0 else minf(rng, l)
		e.proj = {"x": e.hero.x + d.x * 5.0, "y": e.hero.y + d.y * 5.0, "dx": d.x, "dy": d.y, "d": 0.0, "R": R, "end": 0, "t": 0}
	var pr := e.proj
	if pr.is_empty():
		e.head = {}
		return
	if int(pr.end) == 0:
		var mv := float(p.dspd) / float(e.look.time_scale)
		while mv > 0.0 and int(pr.end) == 0:
			var st := minf(1.0, mv)
			mv -= st
			pr.x += pr.dx * st
			pr.y += pr.dy * st
			pr.d += st
			if e.hits_unit(Vector2(pr.x, pr.y), 1.5 if fb else 0.8):
				pr.end = 1
			elif pr.d >= pr.R or pr.x < 3 or pr.y < 3 or pr.x > FireSim.SW - 4 or pr.y > FireSim.SW - 4:
				pr.end = 2
		sim.emit(e.slot, pr.x - pr.dx * 1.5, pr.y - pr.dy * 1.5, pr.dx, pr.dy, float(p.trad), float(p.ttemp), float(p.tlaunch) * float(p.dspd))
		e.head = {"x": pr.x, "y": pr.y, "dx": pr.dx, "dy": pr.dy, "ball": fb, "size": float(p.dsize)}
		if int(pr.end) != 0:
			var k := 2.0 if fb else 1.0
			var bx: float = pr.x - pr.dx * k
			var by: float = pr.y - pr.dy * k
			var R: float = float(p.popR) if (int(pr.end) == 1 or fb) else float(p.popR) * 0.7
			sim.pburst(e.slot, bx, by, R, float(p.popT), float(p.popS), 0.0)
			if fb:
				e.patch_later(bx, by, float(p.ptchR), float(p.ptchT), 3.0)
			pr.t = 0
			e.head = {}
	else:
		pr.t += 1
		if int(pr.t) > 3:
			e.proj = {}


static func _whip(e: FireEffect, sim: FireSim, p: Dictionary, ax: float, ay: float, pxv: float, pyv: float) -> void:
	var ct := e.ct
	var Te := maxf(2.0, float(p.wext) * 60.0)
	var Tr := maxf(2.0, float(p.wret) * 60.0)
	var hx := e.hero.x + ax * 3.0
	var hy := e.hero.y + ay * 3.0
	var Lm := 80.0
	if e.target_id >= 0:
		var dx := e.tg.x - hx
		var dy := e.tg.y - hy
		var along := dx * ax + dy * ay
		var perp := absf(-dx * ay + dy * ax)
		if along > 0.0 and perp < 2.6 + 1.0 and along - 2.6 < 80.0:
			Lm = maxf(8.0, along - 2.6 + 0.5)
	var To := maxf(2.0, float(p.wout) * 60.0)
	var Tw := maxf(4.0, Te)
	# The hit time is constant: the crack always takes the extension time, whatever the
	# length (Tc = Tw, no loop shortening by distance).
	var Tc := Tw
	var Tl := Tw - Tc
	var Lp := minf(Lm, float(p.wprep))
	var lt := float(p.wtilt)
	var lx := pxv * lt
	var ly := pyv * lt
	var lz := (1.0 - lt) * PXC
	var crack := func(t: float, L: float) -> Array:
		var pa := pow(t, float(p.waccel))
		var a := L * pa
		var rr := maxf(0.6, float(p.wloop) * (1.0 - 0.85 * a / maxf(1.0, L)))
		var o := []
		for k in 25:
			var sN := k / 24.0 * L
			var al: float
			var off: float
			if sN <= a:
				al = sN
				off = 0.0
			else:
				var b := sN - a
				var ph := b / rr
				if ph < PI:
					al = a + rr * sin(ph)
					off = rr * (1.0 - cos(ph))
				else:
					al = a - (b - PI * rr)
					off = 2.0 * rr
			var x := hx + ax * al + lx * off
			var y := hy + ay * al + ly * off
			var z := 13.0 + lz * off
			if al < 0.0:
				var bk := -al
				x = hx - ax * bk * 0.6 + lx * off
				y = hy - ay * bk * 0.6 + ly * off
				z = 13.0 + lz * off + PXC * (bk * 0.9 - bk * bk * 0.014)
			o.append(Vector3(x, y, z))
		return o
	var lp := func(ph: float, L: float) -> Array:
		var o := []
		for k in 25:
			var sN := k / 24.0 * L
			var rad := 2.5 + sN * 0.25
			var an := ph - sN / rad
			o.append(Vector3(e.hero.x + cos(an) * rad, e.hero.y + sin(an) * rad, maxf(2.0, 22.0 - sN * 0.15)))
		return o
	var mix := func(A: Array, B: Array, w: float) -> Array:
		var o := []
		for k in A.size():
			o.append((A[k] as Vector3).lerp(B[k], w))
		return o
	if ct < To + Tw + Tr:
		var pts: Array
		var tc := 0.0
		var c2 := ct - To
		if ct < To:
			pts = crack.call(0.0, Lp * (1.0 - pow(1.0 - ct / To, 2.0)))
		elif c2 < Tl:
			var q := c2 / Tl
			pts = lp.call(e.aim + q * TAU, Lp)
			if q < 0.3:
				pts = mix.call(crack.call(0.0, Lp), pts, q / 0.3)
		elif c2 < Tw:
			tc = (c2 - Tl) / Tc
			var u2 := pow(tc, float(p.waccel))
			pts = crack.call(tc, Lp + (Lm - Lp) * u2 * u2)
			if Tl > 0.0 and tc < 0.25:
				pts = mix.call(lp.call(e.aim + TAU, Lp), pts, tc / 0.25)
		else:
			var rp := (c2 - Tw) / Tr
			var rs := rp * rp * (3.0 - 2.0 * rp)
			var tug := float(p.wtug) * sin(PI * rp)
			var full: Array = crack.call(1.0, Lm)
			pts = []
			for k in full.size():
				var q: Vector3 = full[k]
				var sN := k / 24.0
				pts.append(Vector3(hx + (q.x - hx) * (1.0 - rs), hy + (q.y - hy) * (1.0 - rs),
						13.0 + (q.z - 13.0) * (1.0 - rs) + tug * minf(1.0, sN * 3.0) * (1.0 - 0.6 * sN)))
		for k in 25:
			var q: Vector3 = pts[k]
			if q.z < 1.0:
				q.z = 1.0
			e.whip_pts.append(q)
			if k > 1 and randf() < float(p.shed):
				e.lick(sim, q.x, q.y, float(p.stemp) * (0.7 + 0.3 * k / 24.0), q.z - ZC, 0.12)
		var tp: Vector3 = e.whip_pts[24]
		if c2 >= Tl and c2 < Tw + 8 and (c2 >= Tw or tc > 0.3):
			sim.emit(e.slot, tp.x, tp.y, ax, ay, 1.0, float(p.stemp), float(p.wtip), 0.0, tp.z - ZC, 0.0, 0.2, 0.0)
		if c2 == roundi(Tw):
			sim.pburst(e.slot, tp.x, tp.y, float(p.popR), float(p.popT), float(p.popS), 0.0)


## Steps until the whip cracks on its target (the gameplay hit time, constant).
static func whip_hit_steps(p: Dictionary) -> int:
	return roundi(maxf(2.0, float(p.wout) * 60.0) + maxf(4.0, maxf(2.0, float(p.wext) * 60.0)))


static func _inferno(e: FireEffect, sim: FireSim, p: Dictionary) -> void:
	var ct := e.ct
	var Lt := sec_f(e, float(p.itele))
	var Lb := sec_f(e, float(p.idur))
	var R := float(p.irad)
	if ct == 0:
		e.ctr = e.tg
		e.blocks = inferno_blocks(e.ctr, R)
		e.marker = {"k": "blk", "t": 0.0}
	if ct < Lt:
		e.marker.t = float(ct) / float(Lt)
	elif ct == Lt:
		e.marker.t = 2.0
		for b in e.blocks:
			e.patch_later(b.x, b.y, 5.2, float(p.idur), 0.0)
	elif ct < Lt + Lb:
		sim.air(e.slot, e.ctr.x, e.ctr.y, 44.0, 1, float(p.ivort))
		var n := float(p.irain)
		while n > 0.0:
			if n < 1.0 and randf() > n:
				break
			n -= 1.0
			var a := randf() * TAU
			var r := R * sqrt(randf())
			e.drop(e.ctr.x + cos(a) * r, e.ctr.y + sin(a) * r, 36.0 + randf() * 14.0, 0.0, 0.0, -1.1 - randf() * 0.6, 0.0, 0.0)
	else:
		e.marker = {}


## Inferno's circle, built from half-tile (8-cell) blocks on the world's half-tile grid
## (the window's corner is a tile corner): a block is in if its centre is within the
## radius of the centre. Block centres in local cells. The host burns every tile with a
## block in it (WorldSim.inferno_tiles), so gameplay matches the drawn circle.
static func inferno_blocks(ctr: Vector2, R: float) -> Array:
	var out := []
	var j0 := floori((ctr.y - R) / 8.0) - 1
	var i0 := floori((ctr.x - R) / 8.0) - 1
	for j in range(j0, j0 + int(R / 4.0) + 3):
		for i in range(i0, i0 + int(R / 4.0) + 3):
			var c := Vector2(i * 8 + 4, j * 8 + 4)
			if c.distance_to(ctr) <= R:
				out.append(c)
	return out
