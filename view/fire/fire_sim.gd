class_name FireSim
extends Node
## The fire fluid on the GPU (fire physics phase 1): the two-fluid simulation of
## fire-ability-reference.html as a chain of shader passes on SubViewports.
##
## Every fire effect gets a slot: a 128 x 128 cell window (8 x 8 tiles, 16 cells a
## tile) in a 4 x 2 atlas of half-float textures. Sibling SubViewports render in tree
## order, so each pass reads the passes before it this frame; the first passes read
## the last ones' textures from the frame before (the state). The fluid steps 60 times
## per second of game time: a frame with a step due renders the chain once
## (UPDATE_ONCE), a frame without renders nothing. A slot at playback speed 0.5
## steps every other time; its passes copy its state through.
##
## Nothing here is gameplay: the host's events start effects, and each player runs
## the look on their own GPU.

const SW := 128                 ## cells per slot side
const COLS := 4
const ROWS := 2
const SLOTS := COLS * ROWS
const ATLAS := Vector2i(SW * COLS, SW * ROWS)
const MAX_SOURCES := 32
const MAX_UNITS := 8
const PRM_W := 16
const BAND_W := 260
const BAND_H := 128
const BANDS := 15
const STEPS_PER_SECOND := 60.0
const ZC := 13.0 ## the reference's chest height (px above the floor)
const SHADER_PATH := "res://view/fire/shaders/fire_core.gdshaderinc"

## Rings of the velocity extension each step (the reference runs up to 18, as many as
## the fastest fire cell moves; 12 covers every approved setting).
@export var extension_passes := 12
## Jacobi passes of the air's pressure: the reference runs 8 Gauss-Seidel sweeps, and Jacobi
## needs about twice as many to match them (checked against the reference: 16 keeps
## the flame within its run-to-run spread).
@export var pressure_passes := 16
@export var height_scale := 1.55
var blue_ramp := false

## slot -> {"rate", "acc", "steps", "air"} while in use
var _slots := {}
var _prm := Image.create(PRM_W, SLOTS, false, Image.FORMAT_RGBAF)
var _src := Image.create(MAX_SOURCES * 4, SLOTS, false, Image.FORMAT_RGBAF)
var _wall := Image.create(ATLAS.x, ATLAS.y, false, Image.FORMAT_R8)
var _prm_tex: ImageTexture
var _src_tex: ImageTexture
var _wall_tex: ImageTexture
var _wall_dirty := false
var _passes := {}          # name -> SubViewport
var _order: Array = []     # names in render order
var _keep_flip := false
var _sources := {}         # slot -> Array of PackedFloat32Array(16) for this step
var _params := {}          # slot -> Dictionary of P values
var _units := {}           # slot -> Array of Vector3 (x, y, r) in local cells
var _stepping := {}        # slot -> true when it steps this frame
var _ran := false
var frames_run := 0


func _ready() -> void:
	_prm.fill(Color(0, 0, 0, 0))
	_src.fill(Color(0, 0, 0, 0))
	_wall.fill(Color(0, 0, 0, 0))
	_prm_tex = ImageTexture.create_from_image(_prm)
	_src_tex = ImageTexture.create_from_image(_src)
	_wall_tex = ImageTexture.create_from_image(_wall)
	_build()


## The band image atlas (art px, transparent where nothing burns).
func bands_texture() -> Texture2D:
	return _passes.band.get_texture()


## Where band `b` of `slot` sits in bands_texture().
static func band_rect(slot: int, b: int) -> Rect2:
	var sx := slot % COLS
	var sy := slot / COLS
	return Rect2(sx * BAND_W, (sy * BANDS + b) * BAND_H, BAND_W, BAND_H)


## The art-px offset of a band's top left from the top vertex of the slot's cell (0, 0).
static func band_offset(b: int) -> Vector2:
	return Vector2(-128, b * 8 - 112)


## A free slot, or -1. `rate` is the effect's playback speed (steps per 60 per second).
func alloc(rate: float = 1.0) -> int:
	for s in SLOTS:
		if not _slots.has(s):
			_slots[s] = {"rate": rate, "acc": 0.0, "steps": 0}
			_params[s] = {}
			_units[s] = []
			_sources[s] = []
			_clear_walls(s)
			_clear_slot(s)
			return s
	return -1


func release(slot: int) -> void:
	_slots.erase(slot)
	_params.erase(slot)
	_units.erase(slot)
	_sources.erase(slot)
	_prm.set_pixel(4, slot, Color(0, 0, 0, 0))
	_prm.set_pixel(0, slot, Color(0, 0, 0, 0))


func in_use(slot: int) -> bool:
	return _slots.has(slot)


func set_rate(slot: int, rate: float) -> void:
	if _slots.has(slot):
		_slots[slot].rate = rate


## P values for the slot's steps (the reference's P: heat, hts, thrust, tts, cool,
## widen, push, fade, brk, boom; plus "contact" 0/1/2, "bmul", "aim" and "wind").
func set_params(slot: int, p: Dictionary) -> void:
	_params[slot] = p


## Round units (local cells) the fire flows around and bursts against.
func set_units(slot: int, units: Array) -> void:
	_units[slot] = units.slice(0, MAX_UNITS)


## Walls: `cells` is a PackedByteArray of SW * SW (1 = solid).
func set_walls(slot: int, cells: PackedByteArray) -> void:
	var ox := (slot % COLS) * SW
	var oy := (slot / COLS) * SW
	for y in SW:
		for x in SW:
			_wall.set_pixel(ox + x, oy + y, Color(float(cells[x + y * SW]), 0, 0))
	_wall_dirty = true


func _clear_walls(slot: int) -> void:
	_wall.fill_rect(Rect2i((slot % COLS) * SW, (slot / COLS) * SW, SW, SW), Color(0, 0, 0, 0))
	_wall_dirty = true


var _clear_pending := {}


func _clear_slot(slot: int) -> void:
	_clear_pending[slot] = true


## How many steps the slot takes this frame (0 or 1): call once per frame before
## adding its sources. `dt` is game time (the game speed already applied).
func due(slot: int, dt: float) -> int:
	if not _slots.has(slot):
		return 0
	var st: Dictionary = _slots[slot]
	st.acc = minf(st.acc + dt * STEPS_PER_SECOND * float(st.rate), 2.0)
	if st.acc >= 1.0:
		st.acc -= 1.0
		_stepping[slot] = true
		return 1
	return 0


## Sources for this step (local cells; see fire_core's inject pass).
func emit(slot: int, sx: float, sy: float, ax: float, ay: float, rad: float, temp: float, launch: float,
		wob: float = 0.0, zz: float = 0.0, ah: float = 0.0, d0: float = 0.0, bt: float = 0.0) -> void:
	_push(slot, [1, sx, sy, ax, ay, rad, temp, launch, wob, zz, ah, d0, bt, 0, 0, 0])


func pburst(slot: int, cx: float, cy: float, r: float, t: float, s: float, zz: float = 0.0, ring: bool = false) -> void:
	_push(slot, [2, cx, cy, r, t, s, zz, 1.0 if ring else 0.0, 0, 0, 0, 0, 0, 0, 0, 0])


## One flame cell (lick, burnUnit).
func point(slot: int, x: float, y: float, t: float, b: float, d: float, z0: float, fu: float, fv: float) -> void:
	_push(slot, [3, x, y, t, b, d, z0, fu, fv, 0, 0, 0, 0, 0, 0, 0])


## The air: mode 0 a radial push, 1 a swirl (inferno), 2 a push (ux, uy) in a square.
func air(slot: int, cx: float, cy: float, r: float, mode: int, k: float, ux: float = 0.0, uy: float = 0.0) -> void:
	_push(slot, [4, cx, cy, r, mode, k, ux, uy, 0, 0, 0, 0, 0, 0, 0, 0])


func _push(slot: int, v: Array) -> void:
	if not _sources.has(slot) or _sources[slot].size() >= MAX_SOURCES:
		return
	_sources[slot].append(v)


## Uploads this frame's parameters and sources and renders the chain if any slot steps.
## Call after every effect has added its sources.
func run() -> void:
	_ran = not _stepping.is_empty() or not _clear_pending.is_empty()
	for s in SLOTS:
		var st: bool = _stepping.has(s)
		var used: bool = _slots.has(s)
		var steps := 0
		if used:
			if st:
				_slots[s].steps += 1
			steps = _slots[s].steps
		var p: Dictionary = _params.get(s, {})
		var srcs: Array = _sources.get(s, []) if st else []
		var aim: Vector2 = p.get("aim", Vector2.RIGHT)
		var units: Array = _units.get(s, [])
		_prm.set_pixel(0, s, Color(1.0 if st else 0.0, 1.0 if (steps % 2) == 1 else 0.0, float(steps), float(srcs.size())))
		_prm.set_pixel(1, s, Color(float(p.get("heat", 0.0)), float(p.get("hts", 0.0)) * 60.0, float(p.get("thrust", 0.0)), float(p.get("tts", 0.0)) * 60.0))
		_prm.set_pixel(2, s, Color(float(p.get("cool", 0.05)), float(p.get("widen", 0.1)), float(p.get("push", 2.0)), float(p.get("fade", 0.02))))
		_prm.set_pixel(3, s, Color(float(p.get("brk", 0.75)), float(p.get("boom", 1.0)) * float(p.get("bmul", 1.0)), float(p.get("contact", 0)), float(units.size())))
		_prm.set_pixel(4, s, Color(aim.x, aim.y, float(p.get("wind", 0.0)), 1.0 if used else 0.0))
		for k in MAX_UNITS:
			var u: Vector3 = units[k] if k < units.size() else Vector3.ZERO
			_prm.set_pixel(8 + k, s, Color(u.x, u.y, u.z, 1.0))
		for i in srcs.size():
			var v: Array = srcs[i]
			for t in 4:
				_src.set_pixel(i * 4 + t, s, Color(v[t * 4], v[t * 4 + 1], v[t * 4 + 2], v[t * 4 + 3]))
		if _clear_pending.has(s):
			# A slot taken anew starts empty: its state passes see "clear" and write zeros.
			_prm.set_pixel(5, s, Color(1, 0, 0, 0))
		else:
			_prm.set_pixel(5, s, Color(0, 0, 0, 0))
	_clear_pending.clear()
	_prm_tex.update(_prm)
	_src_tex.update(_src)
	if _wall_dirty:
		_wall_tex.update(_wall)
		_wall_dirty = false
	_keep_flip = not _keep_flip
	var keep_now: String = "keep_a" if _keep_flip else "keep_b"
	var keep_old: String = "keep_b" if _keep_flip else "keep_a"
	for n in ["i_fa", "i_fb", "i_fc", "i_air"]:
		(_passes[n].get_child(0).material as ShaderMaterial).set_shader_parameter("t_keep", _passes[keep_old].get_texture())
	(_passes[keep_now].get_child(0).material as ShaderMaterial).set_shader_parameter("t_b", _passes[keep_old].get_texture())
	for n in _order:
		var vp: SubViewport = _passes[n]
		if n == "keep_a" or n == "keep_b":
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE if (_ran and n == keep_now) else SubViewport.UPDATE_DISABLED
		else:
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE if _ran else SubViewport.UPDATE_DISABLED
	if _ran:
		frames_run += 1
	_stepping.clear()
	for s in _sources:
		_sources[s] = []


func ran_this_frame() -> bool:
	return _ran


# --- The chain -------------------------------------------------------------

func _shader(pass_id: int) -> Shader:
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nrender_mode blend_disabled;\n#define PASS %d\n#include \"%s\"\n" % [pass_id, SHADER_PATH]
	return sh


## One pass: a SubViewport of `size` with one rect running pass `pass_id`;
## `inputs` maps sampler names to the names of earlier (or later) passes.
func _pass(name: String, pass_id: int, size: Vector2i, inputs: Dictionary, extra := {}, hdr := true) -> void:
	var vp := SubViewport.new()
	vp.name = name
	vp.size = size
	vp.use_hdr_2d = hdr
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	var r := ColorRect.new()
	r.size = Vector2(size)
	var m := ShaderMaterial.new()
	m.shader = _shader(pass_id)
	r.material = m
	vp.add_child(r)
	add_child(vp)
	_passes[name] = vp
	_order.append(name)
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	vp.set_meta("inputs", inputs)


func _build() -> void:
	var A := ATLAS
	_pass("sol", 0, A, {})
	# The state of the last frame is read by name: fa, fb, fc (P4, P5, P6) and air (the gradient).
	var prev := {"t_fa": "fa", "t_fb": "fb", "t_fc": "fc", "t_air": "air", "t_sol": "sol"}
	_pass("i_fa", 1, A, prev)
	_pass("i_fb", 2, A, prev)
	_pass("i_fc", 3, A, prev)
	_pass("i_air", 4, A, prev)
	var inj := {"t_fa": "i_fa", "t_fb": "i_fb", "t_fc": "i_fc", "t_air": "i_air", "t_sol": "sol"}
	_pass("f_fa", 5, A, inj)
	_pass("f_fb", 6, A, inj)
	_pass("f_air", 7, A, inj)
	_pass("f_ct1", 8, A, inj)
	_pass("f_ct2", 9, A, inj)
	_pass("s_fa", 10, A, {"t_a": "f_fa", "t_b": "f_fb", "t_sol": "sol"})
	_pass("e0", 11, A, {"t_a": "s_fa", "t_sol": "sol"})
	var last := "e0"
	for i in extension_passes:
		var n := "e%d" % (i + 1)
		_pass(n, 12, A, {"t_a": last, "t_sol": "sol"})
		last = n
	_pass("ext", 13, A, {"t_a": last, "t_b": "f_air", "t_sol": "sol"})
	_pass("a_curl", 14, A, {"t_a": "f_air", "t_sol": "sol"})
	_pass("a_vort", 15, A, {"t_a": "a_curl", "t_b": "f_fb", "t_c": "s_fa", "t_sol": "sol"})
	_pass("a_adv", 16, A, {"t_a": "a_vort", "t_sol": "sol"})
	_pass("a_div", 17, A, {"t_a": "a_adv", "t_sol": "sol"})
	last = "a_div"
	for i in pressure_passes:
		var n := "a_j%d" % i
		_pass(n, 18, A, {"t_a": last, "t_sol": "sol"})
		last = n
	_pass("air", 19, A, {"t_a": last, "t_sol": "sol"})
	_pass("tr", 20, A, {"t_a": "ext", "t_sol": "sol"})
	_pass("p1", 21, A, {"t_a": "s_fa", "t_b": "ext", "t_e": "tr", "t_sol": "sol"})
	_pass("p2", 22, A, {"t_a": "s_fa", "t_c": "f_fb", "t_e": "tr", "t_sol": "sol"})
	_pass("p3", 23, A, {"t_a": "s_fa", "t_d": "i_fc", "t_e": "tr", "t_g": "p1", "t_sol": "sol"})
	var fin := {"t_a": "s_fa", "t_c": "p2", "t_d": "p1", "t_e": "tr", "t_g": "p3", "t_sol": "sol"}
	var f4 := fin.duplicate(); f4["t_b"] = "i_fa"
	var f5 := fin.duplicate(); f5["t_b"] = "i_fb"
	var f6 := fin.duplicate(); f6["t_b"] = "i_fc"
	_pass("fa", 24, A, f4)
	_pass("fb", 25, A, f5)
	_pass("fc", 26, A, f6)
	# Contact sums: 128 -> 32 -> 8 -> 2 -> 1 per slot, ct2 beside ct1 at every level.
	_pass("r1", 27, Vector2i(COLS * 64, ROWS * 32), {"t_a": "f_ct1", "t_b": "f_ct2"}, {"lvl_in": 128})
	_pass("r2", 27, Vector2i(COLS * 16, ROWS * 8), {"t_a": "r1"}, {"lvl_in": 32})
	_pass("r3", 27, Vector2i(COLS * 4, ROWS * 2), {"t_a": "r2"}, {"lvl_in": 8})
	_pass("r4", 27, Vector2i(COLS * 2, ROWS * 1), {"t_a": "r3"}, {"lvl_in": 2})
	_pass("keep_a", 28, Vector2i(SLOTS * 2, 1), {"t_a": "r4"})
	_pass("keep_b", 28, Vector2i(SLOTS * 2, 1), {"t_a": "r4"})
	_pass("band", 29, Vector2i(COLS * BAND_W, ROWS * BANDS * BAND_H), {"t_fa": "fa", "t_fb": "fb", "t_fc": "fc"},
			{"height_scale": height_scale}, false)
	for n in _order:
		var vp: SubViewport = _passes[n]
		var m: ShaderMaterial = vp.get_child(0).material
		var ins: Dictionary = vp.get_meta("inputs")
		for k in ins:
			m.set_shader_parameter(k, _passes[ins[k]].get_texture())
		m.set_shader_parameter("t_prm", _prm_tex)
		m.set_shader_parameter("t_src", _src_tex)
		m.set_shader_parameter("t_wall", _wall_tex)
		m.set_shader_parameter("t_keep", _passes.keep_a.get_texture())
	_passes.band.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS


func set_blue(on: bool) -> void:
	blue_ramp = on
	(_passes.band.get_child(0).material as ShaderMaterial).set_shader_parameter("blue_ramp", 1 if on else 0)


## Reads one state texture back (tests and benches only: it stalls the GPU).
func read(name: String) -> Image:
	return _passes[name].get_texture().get_image()
