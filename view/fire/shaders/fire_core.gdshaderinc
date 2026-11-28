// The fire fluid, one pass at a time (fire physics phase 1). A port of the step() of
// fire-ability-reference.html: every per-cell loop there is a pass here.
// Each pass is a canvas_item shader on a SubViewport the size of the state atlas
// (4 x 2 slots of 128 x 128 cells, half floats); FireSim chains them in tree order,
// so a pass reads the textures of the passes before it in the same frame, and the
// first passes read the last passes' textures from the frame before.
// PASS is #defined by FireSim before this file is included.

const int SW = 128;          // cells per slot side (the reference W = H)
const float ZC = 13.0;       // chest height in reference px (heights x1.55 when drawn)

uniform sampler2D t_fa : filter_nearest;   // F, fu, fv, AG
uniform sampler2D t_fb : filter_nearest;   // D, B, Z0, AH
uniform sampler2D t_fc : filter_nearest;   // ZH
uniform sampler2D t_air : filter_nearest;  // u, v (and pass data in z, w)
uniform sampler2D t_sol : filter_nearest;  // sol (0 open, 1 solid unit or wall, 2 slot border), edge factor
uniform sampler2D t_prm : filter_nearest;  // per-slot parameters, row = slot
uniform sampler2D t_src : filter_nearest;  // per-slot sources, row = slot, 4 texels each
uniform sampler2D t_keep : filter_nearest; // last stepped contact sums, 2 texels per slot
uniform sampler2D t_wall : filter_nearest; // walls per cell (red > 0.5)
uniform sampler2D t_a : filter_nearest;    // generic inputs, named per pass
uniform sampler2D t_b : filter_nearest;
uniform sampler2D t_c : filter_nearest;
uniform sampler2D t_d : filter_nearest;
uniform sampler2D t_e : filter_nearest;
uniform sampler2D t_g : filter_nearest;
uniform int n_jac = 0;     // unused, kept for passes that may need a count
uniform float band_rows = 15.0;
uniform float height_scale = 1.55;
uniform int blue_ramp = 0;

struct Ctx { ivec2 cell; ivec2 so; ivec2 lc; int slot; };
// Godot shaders have no mutable globals: every helper takes the fragment's Ctx X.
#define LC X.lc
#define SO X.so
#define SLOT X.slot

Ctx locate(vec2 frag) {
	Ctx c;
	c.cell = ivec2(floor(frag));
	c.lc = c.cell % SW;
	c.so = c.cell - c.lc;
	c.slot = (c.so.x / SW) + (c.so.y / SW) * 4;
	return c;
}

#define at(t, p) texelFetch(t, X.so + clamp(p, ivec2(0), ivec2(SW - 1)), 0)
#define prm(k) texelFetch(t_prm, ivec2(k, X.slot), 0)
#define sol_at(p) (at(t_sol, p).x)
#define is_sol(p) (at(t_sol, p).x > 0.5)
#define is_unit(p) (at(t_sol, p).x > 0.5 && at(t_sol, p).x < 1.5)

float hash(ivec2 c, float frame, float salt) {
	uint h = uint(c.x) * 374761393u + uint(c.y) * 668265263u + uint(int(frame)) * 2246822519u + uint(int(salt * 977.0)) * 3266489917u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return float(h & 16777215u) / 16777216.0;
}

// Bilinear sample of a texture at a local point (the reference's advP / adv inner part).
vec4 bil(Ctx X, sampler2D t, vec2 p) {
	vec2 q = clamp(p, vec2(0.5), vec2(float(SW) - 1.5));
	ivec2 a = ivec2(floor(q));
	vec2 s = q - vec2(a);
	vec4 d00 = at(t, a), d10 = at(t, a + ivec2(1, 0)), d01 = at(t, a + ivec2(0, 1)), d11 = at(t, a + ivec2(1, 1));
	return (1.0 - s.x) * ((1.0 - s.y) * d00 + s.y * d01) + s.x * ((1.0 - s.y) * d10 + s.y * d11);
}

#define STEPPING (prm(0).x > 0.5)
#define AIR_STEP (prm(0).x > 0.5 && prm(0).y > 0.5)

// The whole cell state, as the reference keeps it in its arrays.
struct Cell { float F; float fu; float fv; float AG; float D; float B; float Z0; float AH; float ZH; float u; float v; };

Cell load(Ctx X, sampler2D fa, sampler2D fb, sampler2D fc, sampler2D air, ivec2 lc) {
	vec4 a = at(fa, lc), b = at(fb, lc), c = at(fc, lc), w = at(air, lc);
	Cell k;
	k.F = a.x; k.fu = a.y; k.fv = a.z; k.AG = a.w;
	k.D = b.x; k.B = b.y; k.Z0 = b.z; k.AH = b.w;
	k.ZH = c.x; k.u = w.x; k.v = w.y;
	return k;
}

float z_of(float Z0, float ZH, float AH, float AG) {
	float z = Z0 + ZH;
	if (abs(AH) > 0.01) z += AH * (1.0 - pow(0.95, AG)) * 20.0;
	return max(z, -ZC + 1.0);
}

#if PASS == 0
// ---- SOL: solids from the slot's units and walls, plus the open edge's fade ----
void fragment() {
	Ctx X = locate(FRAGCOORD.xy);
	float s = 0.0;
	if (LC.x == 0 || LC.y == 0 || LC.x == SW - 1 || LC.y == SW - 1) s = 2.0;
	else {
		if (texelFetch(t_wall, X.cell, 0).x > 0.5) s = 1.0;
		int nu = int(prm(3).w);
		for (int k = 0; k < 8; k++) {
			if (k >= nu) break;
			vec4 un = prm(8 + k);
			if (length(vec2(LC) - un.xy) <= un.z) s = 1.0;
		}
	}
	float m = float(min(min(LC.x, LC.y), min(SW - 1 - LC.x, SW - 1 - LC.y)));
	float edge = m < 8.0 ? 0.55 + 0.45 * m / 8.0 : 1.0;
	COLOR = vec4(s, edge, 0.0, 0.0);
}
#endif

#if PASS >= 1 && PASS <= 4
// ---- INJECT: last step's contact explosion (boom), wind, then this step's sources ----
Cell inject(Ctx X) {
	Cell k = load(X, t_fa, t_fb, t_fc, t_air, LC);
	if (prm(5).x > 0.5) { // a slot taken anew starts empty
		k.F = 0.0; k.fu = 0.0; k.fv = 0.0; k.AG = 0.0; k.D = 0.0; k.B = 0.0; k.Z0 = 0.0; k.AH = 0.0; k.ZH = 0.0; k.u = 0.0; k.v = 0.0;
		return k;
	}
	if (!STEPPING || is_sol(LC)) return k;
	bool edge2 = LC.x < 2 || LC.y < 2 || LC.x > SW - 3 || LC.y > SW - 3;
	vec4 p3 = prm(3), p4 = prm(4), p2 = prm(2);
	float fr = prm(0).z;
	float ax = p4.x, ay = p4.y;
	if (p4.z != 0.0) { k.u += (-p4.z - k.u) * 0.03; }
	// boom (the reference's boom(), from the contact sums of the last step)
	vec4 c1 = texelFetch(t_keep, ivec2(SLOT * 2, 0), 0), c2 = texelFetch(t_keep, ivec2(SLOT * 2 + 1, 0), 0);
	if (c1.x > 0.0 && p3.y > 0.0 && !edge2) {
		float EE = c1.x;
		vec2 c = vec2(c1.y, c1.z) / EE + vec2(64.0) - vec2(ax, ay) * 2.0;
		float En = min(EE, 30.0), Tin = c1.w / EE, zz = c2.x / EE, bm = p3.y;
		float amt = En * bm;
		float r = round(2.0 + bm * 4.0 + min(4.0, En * 0.25));
		// the reference rounds the centre plus each whole offset
		vec2 xy = vec2(LC) - round(c);
		float d = length(xy);
		if (d <= r) {
			float w = 1.0 - d / (r + 1.0);
			vec2 n = d > 0.0 ? xy / d : vec2(0.0);
			if (k.F < 0.05) { k.Z0 = zz; k.AH = 0.0; }
			k.F = max(k.F, min(Tin, Tin * w * 2.0));
			k.B = max(k.B, min(1.0, w * 1.5));
			float side = n.x * -ay + n.y * ax, sg = side < 0.0 ? -1.0 : 1.0;
			vec2 ov = vec2(n.x * 0.6 - ay * sg * 0.5, n.y * 0.6 + ax * sg * 0.5);
			k.fu += ov.x * 0.08 * amt * w; k.fv += ov.y * 0.08 * amt * w;
			k.u += ov.x * 0.04 * amt * w; k.v += ov.y * 0.04 * amt * w;
			float sp = length(vec2(k.fu, k.fv));
			if (sp > 3.5) { k.fu *= 3.5 / sp; k.fv *= 3.5 / sp; }
			k.D = min(1.0, k.D + 0.015 * amt * w);
		}
	}
	int ns = int(prm(0).w);
	vec2 P = vec2(LC);
	for (int s = 0; s < 32; s++) {
		if (s >= ns) break;
		vec4 a = texelFetch(t_src, ivec2(s * 4, SLOT), 0);
		vec4 b = texelFetch(t_src, ivec2(s * 4 + 1, SLOT), 0);
		vec4 c = texelFetch(t_src, ivec2(s * 4 + 2, SLOT), 0);
		vec4 e = texelFetch(t_src, ivec2(s * 4 + 3, SLOT), 0);
		int type = int(a.x + 0.5);
		if (type == 1) {
			// emit(sx, sy, ax, ay, rad, temp, launch, wob, zz, ah, d0, bt)
			vec2 sp = a.yz; vec2 dir = vec2(a.w, b.x); float rad = b.y;
			if (LC.x < 1 || LC.y < 1 || LC.x > SW - 2 || LC.y > SW - 2) continue;
			vec2 lo = floor(sp) - vec2(ceil(rad) + 1.0), hi = floor(sp) + vec2(ceil(rad) + 2.0);
			if (P.x < lo.x || P.y < lo.y || P.x > hi.x || P.y > hi.y) continue;
			float d = length(P - sp);
			if (d > rad) continue;
			float w = 1.0 - d / (rad + 0.35);
			k.F = max(k.F, b.z * min(1.0, 0.3 + w * 1.2));
			k.AG = 0.0; k.D = c.w; k.B = e.x; k.ZH = 0.0; k.Z0 = c.y; k.AH = c.z;
			float wob = c.x, launch = b.w;
			k.fu = (dir.x - dir.y * wob) * launch; k.fv = (dir.y + dir.x * wob) * launch;
		} else if (type == 2) {
			// pburst(cx, cy, R, T, S, zz, ring): a dome, or a ring
			if (edge2) continue;
			vec2 cp = a.yz; float R = a.w, T = b.x, S = b.y, zz = b.z, ring = b.w;
			vec2 xy = P - round(cp);
			float d = length(xy);
			if (d > R) continue;
			float q = d / R, w = 1.0 - q;
			vec2 n = d > 0.0 ? xy / d : vec2(0.0);
			float jit = 0.8 + 0.4 * hash(LC, fr, 11.0 + float(s));
			float rw = ring > 0.5 ? pow(q, 1.5) : 1.0;
			if (rw < 0.2) continue;
			float dh = R * 0.35;
			k.F = max(k.F, ring > 0.5 ? T * jit * rw : T * min(1.0, 0.35 + w) * jit);
			k.B = max(k.B, 0.6 + 0.4 * w); k.AG = 0.0; k.ZH = 0.0;
			k.Z0 = zz + (ring > 0.5 ? 0.0 : dh * sqrt(max(0.0, 1.0 - q * q))); k.AH = 0.0;
			k.D = max(k.D, 0.5);
			float spd = S * (0.25 + 0.75 * q) * jit;
			k.fu = n.x * spd; k.fv = n.y * spd;
			k.u += n.x * S * 0.5 * w; k.v += n.y * S * 0.5 * w;
		} else if (type == 3) {
			// a single flame cell (lick, burnUnit): sets F (max), B, D, Z0, and its speed
			if (edge2) continue;
			if (any(notEqual(LC, ivec2(round(a.yz))))) continue;
			k.F = max(k.F, a.w); k.B = b.x; k.AG = 0.0; k.D = b.y; k.ZH = 0.0; k.Z0 = b.z; k.AH = 0.0;
			k.fu = b.w; k.fv = c.x;
		} else if (type == 4) {
			// air: 0 radial push (jet), 1 swirl toward a vortex (inferno), 2 a uniform push in a square
			vec2 cp = a.yz; float r = a.w; int mode = int(b.x + 0.5); float kk = b.y;
			vec2 xy = P - round(cp);
			if (mode == 2) {
				if (abs(xy.x) <= r && abs(xy.y) <= r && !edge2) { k.u += b.z * kk; k.v += b.w * kk; }
				continue;
			}
			vec2 rel = P - cp; float d = length(xy);
			if (mode == 0) {
				if (d < 1.0 || d > r) continue;
				k.u += xy.x / d * kk * (1.0 - d / r); k.v += xy.y / d * kk * (1.0 - d / r);
			} else {
				if (d < 2.0 || d > r || edge2) continue;
				float w = kk * 20.0 * (1.0 - d / r);
				float tu = (-xy.y / d) * w - xy.x / d * w * 0.15, tv = (xy.x / d) * w - xy.y / d * w * 0.15;
				k.u += (tu - k.u) * 0.05; k.v += (tv - k.v) * 0.05;
			}
		}
	}
	return k;
}
void fragment() {
	Ctx X = locate(FRAGCOORD.xy);
	Cell k = inject(X);
#if PASS == 1
	COLOR = vec4(k.F, k.fu, k.fv, k.AG);
#elif PASS == 2
	COLOR = vec4(k.D, k.B, k.Z0, k.AH);
#elif PASS == 3
	COLOR = vec4(k.ZH, 0.0, 0.0, 0.0);
#else
	COLOR = vec4(k.u, k.v, 0.0, 0.0);
#endif
}
#endif

#if PASS >= 5 && PASS <= 9
// ---- FORCES: thrust, heating, widening, jet push, drag, contact with units ----
// Reads the inject outputs as t_fa, t_fb, t_fc, t_air.
float J(Ctx X, ivec2 lc) { vec4 a = at(t_fa, lc); vec4 b = at(t_fb, lc); return a.x * (1.0 - b.y); }
void fragment() {
	Ctx X = locate(FRAGCOORD.xy);
	Cell k = load(X, t_fa, t_fb, t_fc, t_air, LC);
	vec4 ct1 = vec4(0.0), ct2 = vec4(0.0);
	float fl = k.F;
	if (STEPPING && !is_sol(LC) && fl >= 0.02) {
		vec4 p1 = prm(1), p2 = prm(2), p3 = prm(3);
		float fr = prm(0).z;
		float heat = p1.x, hts = p1.y, thrust = p1.z, tts = p1.w;
		float widen = p2.y, push = p2.z, brk = p3.x;
		float s = length(vec2(k.fu, k.fv));
		if (k.AG < tts && s > 0.05) { k.fu += k.fu / s * thrust; k.fv += k.fv / s * thrust; }
		if (k.AG < hts && k.B < 0.3) k.F = min(5.0, k.F + heat);
		float ag = min(1.0, k.AG / 25.0), kw = widen * ag;
		k.fu -= kw * 0.5 * (at(t_fa, LC + ivec2(1, 0)).x - at(t_fa, LC - ivec2(1, 0)).x);
		k.fv -= kw * 0.5 * (at(t_fa, LC + ivec2(0, 1)).x - at(t_fa, LC - ivec2(0, 1)).x);
		if (k.B > 0.3 && push > 0.0) {
			float gx = 0.5 * (J(X, LC + ivec2(1, 0)) - J(X, LC - ivec2(1, 0))), gy = 0.5 * (J(X, LC + ivec2(0, 1)) - J(X, LC - ivec2(0, 1)));
			float kp = 0.25 * push;
			k.fu -= kp * gx; k.fv -= kp * gy; k.u -= kp * 0.4 * gx; k.v -= kp * 0.4 * gy;
			k.D = min(1.0, k.D + 0.1 * min(1.0, length(vec2(gx, gy))));
		}
		k.fu *= 0.992; k.fv *= 0.992;
		float opp = s > 0.05 ? -(k.fu * k.u + k.fv * k.v) / s : 0.0;
		k.D = min(1.0, k.D + 0.2 * max(0.0, opp - 0.25));
		float hitS = 0.0;
		bool sxp = is_unit(LC + ivec2(1, 0)), sxm = is_unit(LC - ivec2(1, 0));
		bool syp = is_unit(LC + ivec2(0, 1)), sym = is_unit(LC - ivec2(0, 1));
		if (sxp && k.fu > 0.0) { hitS = k.fu; k.fu *= -0.15; }
		if (sxm && k.fu < 0.0) { hitS = -k.fu; k.fu *= -0.15; }
		if (syp && k.fv > 0.0) { hitS = max(hitS, k.fv); k.fv *= -0.15; }
		if (sym && k.fv < 0.0) { hitS = max(hitS, -k.fv); k.fv *= -0.15; }
		if (hitS > 0.0) {
			k.D = min(1.0, k.D + brk);
			float mode = p3.z;
			if (mode > 0.5 && !(mode > 1.5 && k.B > 0.5)) {
				float w = min(4.0, hitS) * min(1.0, fl);
				vec2 rel = vec2(LC) - vec2(64.0);
				ct1 = vec4(w, rel.x * w, rel.y * w, fl * w);
				ct2 = vec4(z_of(k.Z0, k.ZH, k.AH, k.AG) * w, 0.0, 0.0, 0.0);
				k.B = 1.0;
			}
			float r = (hash(LC, fr, 3.0) - 0.5) * hitS * 1.6;
			if (sxp || sxm) k.fv += r; else k.fu += r;
		}
		if (fl < 0.5) k.D = min(1.0, k.D + 0.035 * (0.5 - fl));
		float e = (1.0 - min(1.0, fl)) * 0.08;
		k.fu += (hash(LC, fr, 5.0) - 0.5) * e; k.fv += (hash(LC, fr, 7.0) - 0.5) * e;
		float kd = 0.005 + 0.3 * k.D + 0.35 * k.B;
		k.fu += kd * (k.u - k.fu); k.fv += kd * (k.v - k.fv);
		float q = length(vec2(k.fu, k.fv));
		if (q > 16.0) { k.fu *= 16.0 / q; k.fv *= 16.0 / q; }
		k.u += 0.06 * min(1.0, fl) * (k.fu - k.u); k.v += 0.06 * min(1.0, fl) * (k.fv - k.v);
	}
#if PASS == 5
	COLOR = vec4(k.F, k.fu, k.fv, k.AG);
#elif PASS == 6
	COLOR = vec4(k.D, k.B, k.Z0, k.AH);
#elif PASS == 7
	COLOR = vec4(k.u, k.v, 0.0, 0.0);
#elif PASS == 8
	COLOR = ct1;
#else
	COLOR = ct2;
#endif
}
#endif

#if PASS == 10
// ---- SMOOTH: fire velocity coherence (t_a = forces FA, t_b = forces FB) ----
void fragment() {
	Ctx X = locate(FRAGCOORD.xy);
	vec4 a = at(t_a, LC);
	if (STEPPING && a.x >= 0.02 && !is_sol(LC)) {
		vec2 su = vec2(0.0); float n = 0.0;
		ivec2 nb[4] = ivec2[4](ivec2(-1, 0), ivec2(1, 0), ivec2(0, -1), ivec2(0, 1));
		for (int e = 0; e < 4; e++) {
			ivec2 j = LC + nb[e];
			vec4 o = at(t_a, j);
			if (o.x > 0.02 && !is_sol(j)) { su += o.yz; n += 1.0; }
		}
		if (n > 0.0) { float al = 0.3 * (1.0 - at(t_b, LC).x); a.yz += (su / n - a.yz) * al; }
	}
	COLOR = a;
}
#endif

#if PASS == 11
// ---- EXTEND, start: the mask of fire cells (t_a = smoothed FA) ----
void fragment() {
	Ctx X = locate(FRAGCOORD.xy);
	vec4 a = at(t_a, LC);
	bool m = a.x >= 0.02 && !is_sol(LC);
	COLOR = vec4(m ? a.yz : vec2(0.0), m ? 1.0 : 0.0, 0.0);
}
#endif

#if PASS == 12
// ---- EXTEND, one ring: an empty cell next to masked cells takes their average (t_a = last ring) ----
void fragment() {
	Ctx X = locate(FRAGCOORD.xy);
	vec4 a = at(t_a, LC);
	if (a.z < 0.5 && !is_sol(LC)) {
		vec2 su = vec2(0.0); float n = 0.0;
		for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) {
			if (dx == 0 && dy == 0) continue;
			vec4 o = at(t_a, LC + ivec2(dx, dy));
			if (o.z > 0.5) { su += o.xy; n += 1.0; }
		}
		if (n > 0.0) a = vec4(su / n, 1.0, 0.0);
	}
	COLOR = a;
}
#endif

#if PASS == 13
// ---- EXTEND, end: cells the rings never reached move with the air (t_a = last ring, t_b = forces AIR) ----
void fragment() {
	Ctx X = locate(FRAGCOORD.xy);
	vec4 a = at(t_a, LC);
	if (a.z < 0.5) a.xy = at(t_b, LC).xy;
	COLOR = a;
}
#endif

#if PASS >= 14 && PASS <= 19
// ---- AIR, every other step: curl, vorticity, self-advection, divergence, pressure, gradient ----
// A pass that is not an air step copies its input's u, v (and so everything after it).
void fragment() {
	Ctx X = locate(FRAGCOORD.xy);
	vec4 a = at(t_a, LC);
	bool on = AIR_STEP;
#if PASS == 14
	// curl (t_a = forces AIR)
	float cu = 0.5 * ((at(t_a, LC + ivec2(1, 0)).y - at(t_a, LC - ivec2(1, 0)).y) - (at(t_a, LC + ivec2(0, 1)).x - at(t_a, LC - ivec2(0, 1)).x));
	COLOR = vec4(a.xy, on ? cu : 0.0, 0.0);
#elif PASS == 15
	// vorticity confinement (t_a = curl, t_b = forces FB, t_c = smoothed FA)
	if (on && !is_sol(LC) && LC.x >= 2 && LC.y >= 2 && LC.x < SW - 2 && LC.y < SW - 2) {
		float F = at(t_c, LC).x;
		vec4 b = at(t_b, LC);
		float e = 0.5 * b.x + 0.6 * b.y * min(F, 1.0);
		if (e >= 0.01) {
			float gx = 0.5 * (abs(at(t_a, LC + ivec2(1, 0)).z) - abs(at(t_a, LC - ivec2(1, 0)).z));
			float gy = 0.5 * (abs(at(t_a, LC + ivec2(0, 1)).z) - abs(at(t_a, LC - ivec2(0, 1)).z));
			float l = length(vec2(gx, gy)) + 1e-5;
			a.x += e * gy / l * a.z; a.y -= e * gx / l * a.z;
		}
	}
	COLOR = vec4(a.xy, 0.0, 0.0);
#elif PASS == 16
	// self-advection (t_a = after vorticity)
	if (on) {
		if (is_sol(LC)) a.xy = vec2(0.0);
		else a.xy = bil(X, t_a, vec2(LC) - a.xy).xy;
	}
	COLOR = vec4(a.xy, 0.0, 0.0);
#elif PASS == 17
	// divergence (t_a = advected)
	float dv = -0.5 * (at(t_a, LC + ivec2(1, 0)).x - at(t_a, LC - ivec2(1, 0)).x + at(t_a, LC + ivec2(0, 1)).y - at(t_a, LC - ivec2(0, 1)).y);
	COLOR = vec4(a.xy, on ? dv : 0.0, 0.0);
#elif PASS == 18
	// one Jacobi pass of the pressure (t_a = last pass: u, v, dv, p)
	if (on && !is_sol(LC)) {
		float s = a.z;
		ivec2 nb[4] = ivec2[4](ivec2(-1, 0), ivec2(1, 0), ivec2(0, -1), ivec2(0, 1));
		for (int e = 0; e < 4; e++) { ivec2 j = LC + nb[e]; s += is_sol(j) ? a.w : at(t_a, j).w; }
		a.w = s / 4.0;
	}
	COLOR = a;
#else
	// subtract the pressure gradient (t_a = last Jacobi pass)
	if (on) {
		if (is_sol(LC)) a.xy = vec2(0.0);
		else {
			a.x -= 0.5 * (at(t_a, LC + ivec2(1, 0)).w - at(t_a, LC - ivec2(1, 0)).w);
			a.y -= 0.5 * (at(t_a, LC + ivec2(0, 1)).w - at(t_a, LC - ivec2(0, 1)).w);
		}
	}
	COLOR = vec4(a.xy, 0.0, 0.0);
#endif
}
#endif

#if PASS == 20
// ---- TRACE: where each cell's fire came from (P) and goes to (R), stopping at units and walls ----
// t_a = extended velocity (fu, fv, mask). Stored as offsets from the cell.
vec2 trace_one(Ctx X, vec2 f, float sg, bool masked) {
	vec2 d = -f * sg;
	vec2 x = vec2(LC);
	vec2 q;
	if (!masked) q = x + d;
	else {
		float n = max(1.0, ceil(max(abs(d.x), abs(d.y))));
		q = x;
		for (int k = 1; k <= 17; k++) {
			if (float(k) > n) break;
			vec2 nx = x + d * float(k) / n;
			ivec2 ix = clamp(ivec2(floor(nx + 0.5)), ivec2(0), ivec2(SW - 1));
			float s = sol_at(ix);
			if (s > 0.5 && s < 1.5) break;
			q = nx;
		}
	}
	q = clamp(q, vec2(0.5), vec2(float(SW) - 1.5));
	return q - x;
}
void fragment() {
	Ctx X = locate(FRAGCOORD.xy);
	vec4 a = at(t_a, LC);
	if (is_sol(LC)) { COLOR = vec4(0.0); }
	else COLOR = vec4(trace_one(X, a.xy, 1.0, a.z > 0.5), trace_one(X, a.xy, -1.0, a.z > 0.5));
}
#endif

#if PASS >= 21 && PASS <= 26
// ---- ADVECTION (BFECC for F) and the step's end ----
// t_a = smoothed FA (F0, AG), t_b = extended velocity, t_c = forces FB (D, B, Z0, AH),
// t_d = inject FC (ZH), t_e = trace offsets, t_g = P1 out (or P3 out for the last passes)
float adv1(Ctx X, sampler2D t, int ch, vec2 off) {
	vec4 v = bil(X, t, vec2(LC) + off);
	return ch == 0 ? v.x : ch == 1 ? v.y : ch == 2 ? v.z : v.w;
}
// Bilinear of F0 * something at P (the flame-weighted advection of AG, Z0, AH).
float advw(Ctx X, sampler2D tf, sampler2D t, int ch, vec2 off) {
	vec2 q = clamp(vec2(LC) + off, vec2(0.5), vec2(float(SW) - 1.5));
	ivec2 a = ivec2(floor(q)); vec2 s = q - vec2(a);
	float r = 0.0;
	for (int j = 0; j < 4; j++) {
		ivec2 o = ivec2(j & 1, j >> 1);
		vec4 v = at(t, a + o);
		float val = ch == 0 ? v.x : ch == 1 ? v.y : ch == 2 ? v.z : v.w;
		float w = (o.x == 1 ? s.x : 1.0 - s.x) * (o.y == 1 ? s.y : 1.0 - s.y);
		r += w * at(tf, a + o).x * val;
	}
	return r;
}
#if PASS == 24 || PASS == 26
struct Post { float F; float AG; float ZH; };
// F after BFECC and its clamp, then the reference's per-cell end of step.
// t_g = P3 out (ZH', corrected F), t_c = forces FB, and P1 (FA forward) is t_e's partner: passed as t_d here.
Post post(Ctx X, sampler2D p1, sampler2D p2, sampler2D p3) {
	Post o;
	vec4 tr = at(t_e, LC);
	vec4 a1 = at(p1, LC);
	float Ffwd = a1.x;
	float F = 0.0;
	if (!is_sol(LC)) {
		F = bil(X, p3, vec2(LC) + tr.xy).y;
		vec2 q = clamp(vec2(LC) + tr.xy, vec2(0.5), vec2(float(SW) - 1.5));
		ivec2 b = ivec2(floor(q));
		float f00 = at(t_a, b).x, f10 = at(t_a, b + ivec2(1, 0)).x, f01 = at(t_a, b + ivec2(0, 1)).x, f11 = at(t_a, b + ivec2(1, 1)).x;
		float lo = min(min(f00, f10), min(f01, f11)), hi = max(max(f00, f10), max(f01, f11));
		if (F < lo || F > hi) F = Ffwd;
	}
	float AG = Ffwd > 1e-4 ? a1.w / Ffwd : 0.0;
	if (F > 0.02) AG = min(AG + 1.0, 1000.0); else AG = 0.0;
	float ZH = at(p3, LC).x;
	if (is_sol(LC)) { o.F = 0.0; o.AG = AG; o.ZH = ZH; return o; }
	vec4 s = at(t_sol, LC);
	if (s.y < 1.0) F *= s.y;
	float B = at(p2, LC).w * 0.995;
	if (F > 0.02) { ZH += 0.35 * B * min(1.0, F); if (ZH > 5.0) F *= 0.8; } else ZH = 0.0;
	vec4 p2p = prm(2);
	float c = min(F, (p2p.x + p2p.w * B + (F < 0.15 ? 0.012 : 0.0)) * (0.4 + F));
	F = min(5.0, F - c);
	o.F = F; o.AG = AG; o.ZH = ZH;
	return o;
}
#endif
void fragment() {
	Ctx X = locate(FRAGCOORD.xy);
	vec4 tr = at(t_e, LC);
	bool sol = is_sol(LC);
#if PASS == 21
	// P1: F forward, fu, fv, F*AG
	if (sol) { COLOR = vec4(0.0); }
	else {
		vec2 P = tr.xy;
		COLOR = vec4(adv1(X, t_a, 0, P), adv1(X, t_b, 0, P), adv1(X, t_b, 1, P), advw(X, t_a, t_a, 3, P));
	}
#elif PASS == 22
	// P2: F*Z0, F*AH, D, B
	if (sol) { COLOR = vec4(0.0); }
	else {
		vec2 P = tr.xy;
		COLOR = vec4(advw(X, t_a, t_c, 2, P), advw(X, t_a, t_c, 3, P), adv1(X, t_c, 0, P), adv1(X, t_c, 1, P));
	}
#elif PASS == 23
	// P3: ZH advected, and BFECC's corrected F: F0 + 0.5 (F0 - back(forward))  (t_g = P1)
	float zh = sol ? 0.0 : adv1(X, t_d, 0, tr.xy);
	float f0 = at(t_a, LC).x;
	float back = sol ? 0.0 : bil(X, t_g, vec2(LC) + tr.zw).x;
	COLOR = vec4(zh, f0 + 0.5 * (f0 - back), 0.0, 0.0);
#elif PASS == 24
	// P4: the new FA (t_d = P1, t_c = P2 is read through t_b here, t_g = P3); off-step: inject FA
	if (!STEPPING) { COLOR = at(t_b, LC); }
	else {
		Post o = post(X, t_d, t_c, t_g);
		vec4 a1 = at(t_d, LC);
		COLOR = vec4(o.F, a1.y, a1.z, o.AG);
	}
#elif PASS == 25
	// P5: the new FB: D x0.96, B x0.995, Z0 and AH divided by the forward F (t_d = P1, t_c = P2, t_b = inject FB)
	if (!STEPPING) { COLOR = at(t_b, LC); }
	else {
		vec4 a1 = at(t_d, LC), a2 = at(t_c, LC);
		float Ff = a1.x;
		float z0 = Ff > 1e-4 ? a2.x / Ff : 0.0, ah = Ff > 1e-4 ? a2.y / Ff : 0.0;
		COLOR = vec4(a2.z * 0.96, a2.w * 0.995, z0, ah);
	}
#else
	// P6: the new FC (ZH)
	if (!STEPPING) { COLOR = at(t_b, LC); }
	else {
		Post o = post(X, t_d, t_c, t_g);
		COLOR = vec4(o.ZH, 0.0, 0.0, 0.0);
	}
#endif
}
#endif

#if PASS == 27
// ---- CONTACT SUMS, one level: each texel sums 4 x 4 of the level below ----
// The level below is t_a; ct2 sums sit right of ct1 sums in every level (each level is twice as wide).
uniform int lvl_in = 128; // the cell size of the input level per slot (128, 32, 8, 2)
void fragment() {
	ivec2 c = ivec2(floor(FRAGCOORD.xy));
	int f = lvl_in == 2 ? 2 : 4;
	int outs = lvl_in / f;
	int sx = c.x / (outs * 2), sy = c.y / outs;
	ivec2 lc = ivec2(c.x - sx * outs * 2, c.y - sy * outs);
	int half_ = lc.x >= outs ? 1 : 0;
	ivec2 lo = ivec2(lc.x - half_ * outs, lc.y);
	vec4 s = vec4(0.0);
	for (int j = 0; j < 4; j++) for (int i = 0; i < 4; i++) {
		if (i >= f || j >= f) continue;
		ivec2 src;
		if (lvl_in == 128) src = ivec2(sx * 128 + lo.x * 4 + i, sy * 128 + lo.y * 4 + j);
		else src = ivec2(sx * lvl_in * 2 + half_ * lvl_in + lo.x * f + i, sy * lvl_in + lo.y * f + j);
		if (lvl_in == 128) s += half_ == 0 ? texelFetch(t_a, src, 0) : texelFetch(t_b, src, 0);
		else s += texelFetch(t_a, src, 0);
	}
	COLOR = s;
}
#endif

#if PASS == 28
// ---- KEEP: the contact sums of the last step a slot took (t_a = last level, laid 2 x 1 per slot
// in rows by slot row; t_b = the other KEEP, from the frame before) ----
void fragment() {
	ivec2 c = ivec2(floor(FRAGCOORD.xy));
	int slot = c.x / 2, h = c.x - slot * 2;
	bool st = texelFetch(t_prm, ivec2(0, slot), 0).x > 0.5;
	ivec2 src = ivec2((slot % 4) * 2 + h, slot / 4);
	COLOR = st ? texelFetch(t_a, src, 0) : texelFetch(t_b, c, 0);
}
#endif

#if PASS == 29
// ---- BANDS: the fire drawn as the reference draws it, one tile diagonal per band ----
// Every slot gets 15 bands of 260 x 128 art px (stacked); a band holds the cells of the slot's
// tiles with tx + ty = band, so WorldView can draw it in that row of its back-to-front pass.
// t_fa, t_fb, t_fc: the new state. Heights (z, ZC and the columns) x height_scale.
const int BW = 260;
const int BH = 128;
const int UP = 112; // art px above the band's ground kept
const vec3 RO[6] = vec3[6](vec3(255, 251, 230), vec3(255, 226, 122), vec3(255, 176, 48), vec3(242, 102, 28), vec3(200, 50, 26), vec3(110, 28, 22));
const vec3 RB[6] = vec3[6](vec3(244, 251, 255), vec3(191, 230, 255), vec3(108, 195, 255), vec3(47, 128, 232), vec3(29, 75, 176), vec3(20, 40, 94));
const float TH[6] = float[6](0.72, 0.52, 0.36, 0.22, 0.12, 0.05);
const int BAY[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
vec3 ramp(int q) { q = min(q, 5); return (blue_ramp == 1 ? RB[q] : RO[q]) / 255.0; }
void fragment() {
	ivec2 px = ivec2(floor(FRAGCOORD.xy));
	int sx = px.x / BW, by = px.y / BH;
	int slot_row = by / 15;
	int band = by - slot_row * 15;
	int slot = sx + slot_row * 4;
	Ctx X;
	X.cell = px; X.lc = ivec2(0);
	X.so = ivec2(sx * SW, slot_row * SW);
	X.slot = slot;
	int QX = px.x - sx * BW - 128;              // screen x relative to cell (0, 0)
	int QY = px.y - by * BH + band * 8 - UP;     // screen y relative to cell (0, 0)
	vec4 col = vec4(0.0);
	bool on_slot = prm(4).w > 0.5; // a slot not in use draws nothing
	for (int s = band * 16; on_slot && s <= band * 16 + 30; s++) {
		for (int kk = 0; kk < 2; kk++) {
			int k = QX - 1 + kk;                    // gx - gy of the column (a column is 2 px wide)
			if (((s + k) & 1) != 0) continue;
			int gx = (s + k) / 2, gy = (s - k) / 2;
			if (gx < 0 || gy < 0 || gx >= SW || gy >= SW) continue;
			if ((gx >> 4) + (gy >> 4) != band) continue;
			ivec2 lc = ivec2(gx, gy);
			vec4 a = at(t_fa, lc);
			float t = a.x;
			if (t <= 0.05) continue;
			vec4 b = at(t_fb, lc);
			int bd = 5;
			for (int q = 0; q < 6; q++) if (t >= TH[q]) { bd = q; break; }
			float tt = min(1.0, t / 1.2);
			int hh = 1 + int(round(b.y * tt * tt * 9.0 + b.x));
			if (hh > 6 && ((s & 1) == 1) && (((gx >> 1) & 1) == 1)) continue;
			float z = z_of(b.z, at(t_fc, lc).x, b.w, a.w);
			if (z < -ZC + float(hh) * 0.6) z = -ZC + float(hh) * 0.6;
			float y = float(s >> 1) + ((s & 1) == 1 ? 0.5 : 0.0);
			int hs = max(1, int(round(float(hh) * height_scale)));
			int yc = int(round(y - (ZC + z + (b.y > 0.3 ? float(hh) * 0.3 : 0.0)) * height_scale));
			int dz = QY - yc;
			if (dz < -hs || dz >= hs) continue;
			float kq = (dz < 0 ? float(-dz) - 0.5 : float(dz) + 0.5) / float(hs);
			int bx = (QX + 4096) & 3, byy = (QY + 4096) & 3;
			if (kq > 0.7 && BAY[bx | (byy << 2)] > 9) continue;
			int q = bd + (kq > 0.7 ? 2 : kq > 0.4 ? 1 : 0);
			col = vec4(ramp(q), 1.0);
		}
	}
	COLOR = col;
}
#endif
