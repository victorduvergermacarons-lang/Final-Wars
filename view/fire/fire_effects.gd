class_name FireEffects
extends RefCounted
## The fire effects on screen (fire physics): owned by WorldView like the water ropes.
## Starts effects, steps them on the GPU fluid (FireSim) at 60 steps per second of
## game time, and hands WorldView one item per tile diagonal of each effect's window
## (its band of fire), filed under a tile of that diagonal so walls and units in front
## of it cover it in the back-to-front pass.

var sim: FireSim
var effects: Array[FireEffect] = []

## Low graphics: no fluid fire; burning zones keep the old flame sprites (FxPainter).
static var low_graphics := false

## Ground zones that burn (by the ability that made them) and how their fire looks:
## spread speed (cells/s) and flame height (px). Inferno and Fireball use their own
## look's settings. The host owns which tiles burn and until when; this is the look.
const GROUND_LOOKS := {
	&"F05": {"gspread": 12.0, "gh": 7.0},        # Flame Dash's trail
	&"F08": {"gspread": 14.0, "gh": 10.0},       # Burning Ground
	&"F16": {},                                  # Inferno (its look)
	&"F07": {},                                  # Fireball (its look)
	&"F18": {},                                  # Combustion Blast (its look)
	&"F15": {},                                  # Phoenix Kick's fire drops (its look)
	&"F11": {},                                  # Jet Propulsion's splash (its look)
	&"sunfire_breath": {"gspread": 16.0, "gh": 10.0},
	&"searing_dive": {"gspread": 14.0, "gh": 9.0},
	&"ember_trail": {"gspread": 10.0, "gh": 6.0},
}
## Char fades in 30 s on grass, plants and wood, in 5 s on everything else (stone,
## earth). Seconds.
const CHAR_FADE_LONG := 30.0
const CHAR_FADE_SHORT := 5.0
const LONG_FADE_TERRAINS := ["grass", "meadow", "dark_grass", "dense_grass", "tall_grass", "bush", "steppe",
		"steppe_dry", "roof_thatch"]
const WOOD_PROPS := ["logs", "stump"]
## Plants that burn away, and grow back a minute after the fire.
const REGROW_TERRAINS := ["tall_grass", "dense_grass"]
const REGROW_PROPS := ["flowers", "weeds"]
const REGROW_SECONDS := 60.0
## Burnt plants: tile -> when they grow back (host clock).
var burnt := {}
var _zones_seen := {}
## Air abilities pushing the fire's air: [{"from", "to", "left"}] (steps left).
var _gusts: Array = []
## Water for the fire this frame (WaterRopes.water_points).
var water: Array = []
## Extra water for benches and tests (kept; added to `water`).
var extra_water: Array = []


## `parent` hosts the GPU passes (WorldView).
func attach(parent: Node) -> void:
	sim = FireSim.new()
	sim.name = "FireSim"
	parent.add_child(sim)


## Starts `look` for a caster at world point `pos` (ground height `h`) aiming at
## world point `at`, at this Fire Mastery. Returns null when every slot is taken.
func start(look: FireLookDef, caster_id: int, pos: Vector2, h: float, at: Vector2, mastery: float) -> FireEffect:
	if sim == null:
		return null
	var slot := sim.alloc(look.time_scale)
	if slot < 0:
		return null
	var e := FireEffect.new()
	e.look = look
	e.p = look.settings(mastery)
	e.slot = slot
	e.caster_id = caster_id
	var dir := (at - pos)
	if dir.length() < 0.01:
		dir = Vector2.RIGHT
	e.origin = FireEffect.place_origin(pos, dir)
	e.base_h = h
	e.hero = e.to_local(pos)
	e.start = e.hero
	e.tg = e.to_local(at)
	e.aim = atan2(dir.y, dir.x)
	e.aim_t = e.aim
	if look.kind == "combo":
		e.p_punch = (load("res://content/effects/fire/F01.tres") as FireLookDef).settings(mastery)
		e.p_kick = (load("res://content/effects/fire/F02.tres") as FireLookDef).settings(mastery)
	e.done_after = FireKinds.length(e)
	effects.append(e)
	return e


static var _has_look := {}


## Whether the fire physics draws this ability (then its old sprite effects are skipped,
## unless on low graphics).
static func draws(id: StringName) -> bool:
	if low_graphics:
		return false
	if not _has_look.has(id):
		_has_look[id] = ResourceLoader.exists("res://content/effects/fire/%s.tres" % id)
	return _has_look[id]


## The look of an ability (content/effects/fire/<id>.tres), or null.
static func look_of(id: StringName) -> FireLookDef:
	var path := "res://content/effects/fire/%s.tres" % id
	return load(path) if ResourceLoader.exists(path) else null


## A Fire ability went off on the host ("cast" with "fire": WorldSim._add_fire_look):
## start its look on this player's GPU.
func start_from_event(ev: Dictionary, abilities: Dictionary, grid: GridModel) -> FireEffect:
	if low_graphics:
		return null
	var look := look_of(StringName(ev.get("ability", "")))
	if look == null:
		return null
	var e := start(look, int(ev.get("source", -1)), Vector2(ev.from), float(ev.get("h", 0.0)), Vector2(ev.to), float(ev.get("mastery", 0.0)))
	if e == null:
		return null
	e.target_id = int(ev.get("target", -1))
	var ab: AbilityDef = abilities.get(StringName(ev.get("ability", "")))
	if look.kind == "stream":
		var secs := ab.channel_seconds if ab != null and ab.channel_seconds > 0.0 else 2.0
		e.hold_steps = roundi(secs * 60.0 * look.time_scale)
		e.done_after = e.hold_steps
	set_walls(e, grid)
	return e


## Burning zones from the host: each gets the ground fire in a window holding its tiles
## (a window already there takes it when they fit). Returns the tiles whose plants just
## burnt or grew back (WorldView redraws them).
func sync_ground(zones: Array, now: float, grid: GridModel, zone: ZoneDef) -> Array:
	var changed := []
	if sim == null:
		return changed
	for z in zones:
		var ab := StringName(z.get("ability", ""))
		if not GROUND_LOOKS.has(ab) or low_graphics:
			continue
		var tiles: Array = z.get("tiles", [])
		if tiles.is_empty():
			continue
		var key := "%s|%s|%s|%s" % [z.get("source", -1), ab, z.get("until", 0.0), tiles[0]]
		if _zones_seen.has(key):
			continue
		_zones_seen[key] = float(z.until)
		var e := _ground_window(tiles, ab, grid, zone)
		if e == null:
			continue
		e.ground = true
		for t in tiles:
			e.ground_until[t] = maxf(float(e.ground_until.get(t, 0.0)), float(z.until))
			# An ability's own window lays its fuel itself (its ragged patches): the zone only
			# says where and until when. A plain burning zone is fueled tile by tile.
			if e.look.kind == "ground":
				e.ground_new.append(t)
			if zone != null and _plant_burns(zone, t):
				if not burnt.has(t):
					changed.append(t)
				burnt[t] = maxf(float(burnt.get(t, 0.0)), float(z.until) + REGROW_SECONDS)
		e.ground_light.append(_middle(tiles))
		e.done_after = maxi(e.done_after, e.ct + int((float(z.until) - now) * 60.0) + 60)
		e.tail_steps = maxi(e.tail_steps, int((CHAR_FADE_LONG + 3.0) * 60.0))
	for t in burnt.keys():
		if now >= float(burnt[t]):
			burnt.erase(t)
			changed.append(t)
	for k in _zones_seen.keys():
		if now > float(_zones_seen[k]) + 5.0:
			_zones_seen.erase(k)
	for e in effects:
		e.now = now
	return changed


static func _plant_burns(zone: ZoneDef, t: Vector2i) -> bool:
	return zone.terrain_at(t) in REGROW_TERRAINS or zone.prop_at(t) in REGROW_PROPS


## The tile in the middle of a set (the one nearest its centre): where the fire is lit.
static func _middle(tiles: Array) -> Vector2i:
	var c := Vector2.ZERO
	for t in tiles:
		c += Vector2(t)
	c /= float(tiles.size())
	var best: Vector2i = tiles[0]
	for t in tiles:
		if Vector2(t).distance_to(c) < Vector2(best).distance_to(c):
			best = t
	return best


func _ground_window(tiles: Array, ab: StringName, grid: GridModel, zone: ZoneDef) -> FireEffect:
	var lo := Vector2i(tiles[0])
	var hi := lo
	for t in tiles:
		lo = Vector2i(mini(lo.x, t.x), mini(lo.y, t.y))
		hi = Vector2i(maxi(hi.x, t.x), maxi(hi.y, t.y))
	for e in effects:
		if e.look.kind != "ground" and e.look.id != ab:
			continue
		var a := e.origin + Vector2i(1, 1)
		var b := e.origin + Vector2i(6, 6)
		if lo.x >= a.x and lo.y >= a.y and hi.x <= b.x and hi.y <= b.y:
			return e
	var look := FireLookDef.new()
	look.id = ab
	look.kind = "ground"
	var gl: Dictionary = GROUND_LOOKS.get(ab, {})
	if gl.is_empty():
		var own: FireLookDef = load("res://content/effects/fire/%s.tres" % ab) if ResourceLoader.exists("res://content/effects/fire/%s.tres" % ab) else null
		gl = own.settings(0.0) if own != null else {}
	look.s0 = {"gspread": float(gl.get("gspread", 12.0)), "gh": float(gl.get("gh", 10.0)), "cool": 0.05, "fade": 0.03}
	look.m1 = look.s0
	var slot := sim.alloc(1.0)
	if slot < 0:
		return null
	var e := FireEffect.new()
	e.look = look
	e.p = look.settings(0.0)
	e.slot = slot
	e.ground = true
	var mid := (Vector2(lo) + Vector2(hi)) * 0.5
	e.origin = Vector2i(roundi(mid.x) - 3, roundi(mid.y) - 3)
	var h := 0.0
	if grid != null and grid.in_bounds(_middle(tiles)):
		h = float(grid.height_at(_middle(tiles)))
	e.base_h = h
	e.hero = Vector2(64, 64)
	e.zone = zone
	e.grid = grid
	e.tail_steps = int((CHAR_FADE_LONG + 3.0) * 60.0) # the char stays, then fades
	effects.append(e)
	set_walls(e, grid)
	return e


## An Air ability went off: its wind pushes the fire's air from `from` toward `to`.
func on_events(events: Array, abilities: Dictionary, grid: GridModel = null) -> void:
	for ev in events:
		if str(ev.get("type", "")) in ["cast", "release"] and bool(ev.get("fire", false)):
			# An ability released ahead of its hit (Fire Whip) starts its look at the release.
			var ab: AbilityDef = abilities.get(StringName(ev.get("ability", "")))
			var delayed := ab != null and ab.release_delay_seconds > 0.0
			if (str(ev.type) == "release") == delayed:
				start_from_event(ev, abilities, grid)
			continue
		if str(ev.get("type", "")) != "fx" or not ev.has("from") or not ev.has("to"):
			continue
		var ab: AbilityDef = abilities.get(StringName(ev.get("ability", "")))
		if ab == null or ab.tree != "Air":
			continue
		_gusts.append({"from": Vector2(ev.from), "to": Vector2(ev.to), "left": 20})


## This step's air and water on the effect: gusts push its air along their line;
## water in the air cools flame cells, water on the ground puts the fire out there.
func _hooks(e: FireEffect) -> void:
	for g in _gusts:
		var a := e.to_local(g.from)
		var b := e.to_local(g.to)
		var d := b - a
		if d.length() < 0.5:
			continue
		var dir := d.normalized()
		var n := clampi(int(d.length() / 16.0) + 1, 1, 6)
		for i in n:
			var c := a + d * (float(i) + 0.5) / float(n)
			if c.x < -10 or c.y < -10 or c.x > FireSim.SW + 10 or c.y > FireSim.SW + 10:
				continue
			sim.air(e.slot, c.x, c.y, 10.0, 2, 0.06, dir.x, dir.y)
	var k := 0
	for w in water + extra_water:
		var lp := e.to_local(w.pos)
		if lp.x < 0 or lp.y < 0 or lp.x >= FireSim.SW or lp.y >= FireSim.SW:
			continue
		if bool(w.ground):
			sim.water_ground(e.slot, lp.x, lp.y, 3.0)
		else:
			sim.water_air(e.slot, lp.x, lp.y, 2.5, 0.35)
		k += 1
		if k >= 12:
			break


## Walls for a new effect: tiles of its window that rise more than a level above its
## ground, block sight, or don't exist.
func set_walls(e: FireEffect, grid: GridModel) -> void:
	var cells := PackedByteArray()
	cells.resize(FireSim.SW * FireSim.SW)
	for ty in 8:
		for tx in 8:
			var t := e.origin + Vector2i(tx, ty)
			var solid := false
			if grid != null:
				solid = not grid.in_bounds(t) or not grid.has_tile(t) or grid.blocks_sight(t) \
						or float(grid.height_at(t)) > e.base_h + 1.0
			if not solid:
				continue
			for y in 16:
				for x in 16:
					cells[tx * 16 + x + (ty * 16 + y) * FireSim.SW] = 1
	sim.set_walls(e.slot, cells)


## Ends every effect at once.
func clear() -> void:
	for e in effects:
		sim.release(e.slot)
	effects.clear()
	_zones_seen.clear()


## Steps every effect that is due (dt: game time) and renders the passes.
## `actors`: every unit, for the bodies fire flows around.
func advance(dt: float, actors: Array) -> void:
	if sim == null:
		return
	for e in effects.duplicate():
		if e.finished():
			sim.release(e.slot)
			effects.erase(e)
			continue
		if sim.due(e.slot, dt) > 0:
			_follow(e, actors)
			e.units = _units(e, actors)
			sim.set_units(e.slot, e.units)
			_hooks(e)
			e.step(sim)
	for g in _gusts:
		g.left -= 1
	_gusts = _gusts.filter(func(g): return g.left > 0)
	sim.run()


## The caster and the target move: the look follows them.
func _follow(e: FireEffect, actors: Array) -> void:
	for a in actors:
		if a.id == e.caster_id and a.alive:
			e.hero = e.to_local(a.move.pos)
		elif a.id == e.target_id and a.alive and e.target_id >= 0:
			e.tg = e.to_local(a.move.pos)


func _units(e: FireEffect, actors: Array) -> Array:
	var out := []
	for a in actors:
		if a.id == e.caster_id or not a.alive:
			continue
		var lp := e.to_local(a.move.pos)
		if lp.x < -8 or lp.y < -8 or lp.x > FireSim.SW + 8 or lp.y > FireSim.SW + 8:
			continue
		out.append(Vector3(lp.x, lp.y, a.move.radius * FireEffect.UNIT_CELLS_PER_TILE))
	return out


## One item per tile diagonal of every effect: {"fireband", "band", "pos", "rect"}.
## `screen_of(world point, height)` gives screen positions (Iso.to_screen).
func items(grid: GridModel) -> Array:
	var out := []
	for e in effects:
		var top := Iso.to_screen(Vector2(e.origin) - Vector2(0.5, 0.5), e.base_h)
		for b in FireSim.BANDS:
			var tile := Vector2i(-1, -1)
			var i0 := clampi(b / 2, maxi(0, b - 7), mini(7, b))
			for k in 8:
				for sgn in [1, -1]:
					var i: int = i0 + int(sgn) * k
					if i < maxi(0, b - 7) or i > mini(7, b):
						continue
					var t := e.origin + Vector2i(i, b - i)
					if grid == null or grid.in_bounds(t):
						tile = t
						break
				if tile.x >= 0:
					break
			if tile.x < 0:
				continue
			var off := FireSim.band_offset(b) * PixelCamera.ART_SCALE
			var rect := Rect2(top + off, Vector2(FireSim.BAND_W, FireSim.BAND_H) * PixelCamera.ART_SCALE)
			out.append({"fireband": e.slot, "band": b, "pos": Vector2(tile), "rect": rect})
			out.append({"fireparts": e, "band": b, "pos": Vector2(tile), "rect": rect, "top": top})
			if e.ground:
				var frect := Rect2(top + Vector2(-128, b * 8) * PixelCamera.ART_SCALE, Vector2(FireSim.BAND_W, FireSim.FLOOR_H) * PixelCamera.ART_SCALE)
				out.append({"firefloor": e.slot, "band": b, "pos": Vector2(tile), "rect": frect, "behind": true})
	return out


func draw(canvas: CanvasItem, item: Dictionary) -> void:
	if item.has("firefloor"):
		canvas.draw_texture_rect_region(sim.floor_texture(), item.rect, FireSim.floor_rect(int(item.firefloor), int(item.band)))
		return
	if item.has("fireparts"):
		_draw_parts(canvas, item)
		return
	canvas.draw_texture_rect_region(sim.bands_texture(), item.rect, FireSim.band_rect(int(item.fireband), int(item.band)))


# --- Particles and heads, drawn in code with the reference's ramps ------------

const RAMP := [Color8(255, 251, 230), Color8(255, 226, 122), Color8(255, 176, 48), Color8(242, 102, 28), Color8(200, 50, 26), Color8(110, 28, 22)]
const RAMP_BLUE := [Color8(244, 251, 255), Color8(191, 230, 255), Color8(108, 195, 255), Color8(47, 128, 232), Color8(29, 75, 176), Color8(20, 40, 94)]
const GOLD := [Color8(255, 246, 200), Color8(255, 224, 122), Color8(246, 192, 74), Color8(201, 138, 38)]
const BAY := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


func _ramp(q: int) -> Color:
	return (RAMP_BLUE if sim.blue_ramp else RAMP)[clampi(q, 0, 5)]


## The band a local point belongs to (its tile diagonal).
static func band_of(x: float, y: float) -> int:
	return (int(floor(x)) >> 4) + (int(floor(y)) >> 4)


func _px(canvas: CanvasItem, top: Vector2, x: float, y: float, c: Color, w := 1, h := 1) -> void:
	var s := PixelCamera.ART_SCALE
	canvas.draw_rect(Rect2(top + Vector2(roundf(x), roundf(y)) * s, Vector2(w, h) * s), c)


## Screen (art px from the window's top vertex) of a local point `z` px above the floor.
func _sp(x: float, y: float, z: float) -> Vector2:
	return Vector2(x - y, (x + y) * 0.5 - z * sim.height_scale)


func _draw_parts(canvas: CanvasItem, item: Dictionary) -> void:
	var e: FireEffect = item.fireparts
	var b: int = item.band
	var top: Vector2 = item.top
	for o in e.parts:
		if band_of(o.x, o.y) != b:
			continue
		var p := _sp(o.x, o.y, o.z)
		var q := float(o.l) / float(o.L)
		match int(o.k):
			0:
				var c: Color = GOLD[mini(3, int(q * 4.0))]
				_px(canvas, top, p.x, p.y, c, 2 if q < 0.5 else 1)
			2:
				_px(canvas, top, p.x, p.y, _ramp(mini(4, 1 + int(q * 3.0))))
				_px(canvas, top, p.x, p.y - 1, _ramp(1))
			4:
				for k in 4:
					_px(canvas, top, p.x, p.y - k, _ramp(1 + k))
			_:
				var c := _ramp(mini(4, 1 + int(q * 4.0)))
				_px(canvas, top, p.x, p.y, c, 2 if (o.k == 3 and q < 0.4) else 1)
	# Fire Whip: its segments, each with the band of its middle (the reference's drawSeg)
	var wp := e.whip_pts
	var wt := maxi(1, roundi(float(e.p.get("wthick", 2.0))))
	for k in range(wp.size() - 1):
		var a: Vector3 = wp[k]
		var c: Vector3 = wp[k + 1]
		if band_of((a.x + c.x) * 0.5, (a.y + c.y) * 0.5) != b:
			continue
		var p0 := _sp(a.x, a.y, a.z)
		var p1 := _sp(c.x, c.y, c.z)
		_line(canvas, top, p0 - Vector2(0, wt >> 1), p1 - Vector2(0, wt >> 1), _ramp(3), wt + 1)
		_line(canvas, top, p0, p1, _ramp(1), maxi(1, wt - 1))
	# Combustion Blast: the first laser and the beam, from the eyes, drawn with the hero's band
	if (e.streak > 0.0 or e.beam > 0.0) and band_of(e.hero.x, e.hero.y) == b:
		_draw_beam(canvas, top, e)
	# Inferno's warning: the dotted, blinking outline of its blocks, on the floor
	if not e.marker.is_empty() and float(e.marker.t) < 1.5:
		_draw_marker(canvas, top, e, b)
	var hd := e.head
	if not hd.is_empty() and band_of(hd.x, hd.y) == b:
		var p := _sp(hd.x, hd.y, FireSim.ZC)
		if not bool(hd.get("ball", false)):
			# the dart: a short streak, hot at its tip
			var d := _sp(hd.dx, hd.dy, 0.0) - _sp(0, 0, 0)
			d = d.normalized() if d.length() > 0.0 else Vector2.RIGHT
			var size := float(hd.size)
			var L := int(3.0 + size * 2.0)
			var t := maxi(1, roundi(size / 2.0))
			for k in range(L, -1, -1):
				var w := t + 1 if k < 2 else t
				_px(canvas, top, p.x - d.x * k, p.y - d.y * k, _ramp(mini(4, int(float(k) / L * 4.0))), w, w)
		else:
			# the fireball: a dithered ball, white at its heart
			var r := float(hd.size) + (0.5 if (e.f & 2) != 0 else 0.0)
			var n := int(ceil(r))
			for j in range(-n, n + 1):
				for i in range(-n, n + 1):
					var dd := Vector2(i, j).length() / r
					if dd > 1.0:
						continue
					var X := roundi(p.x + i)
					var Y := roundi(p.y + j)
					if dd > 0.8 and BAY[(X & 3) | ((Y & 3) << 2)] > 10:
						continue
					_px(canvas, top, X, Y, _ramp(0 if dd < 0.35 else 1 if dd < 0.6 else 2 if dd < 0.85 else 3))



func _line(canvas: CanvasItem, top: Vector2, a: Vector2, b: Vector2, c: Color, t: int) -> void:
	var n := maxi(1, ceili(maxf(absf(b.x - a.x), absf(b.y - a.y))))
	for k in n + 1:
		var q := float(k) / n
		_px(canvas, top, roundf(a.x + (b.x - a.x) * q), roundf(a.y + (b.y - a.y) * q), c, t, t)


func _draw_beam(canvas: CanvasItem, top: Vector2, e: FireEffect) -> void:
	var a := _sp(e.hero.x, e.hero.y, 21.0 + e.hz)
	var z := _sp(e.tg.x, e.tg.y, FireKinds.ZC)
	var n := maxi(40, roundi(a.distance_to(z)))
	var st := e.streak
	var ci := 0 if st > 0.8 else 1 if st > 0.5 else 2 if st > 0.3 else 3 if st > 0.2 else 4
	for k in n + 1:
		var q := float(k) / n
		var X := roundf(a.x + (z.x - a.x) * q)
		var Y := roundf(a.y + (z.y - a.y) * q)
		if e.beam > 0.0 and q <= e.beam and q >= e.btail:
			var hd := e.beam - q < 0.06
			_px(canvas, top, X, Y, _ramp(0) if hd else _ramp(1))
			_px(canvas, top, X, Y - 1, _ramp(0) if hd else _ramp(2))
			_px(canvas, top, X, Y + 1, _ramp(3))
			continue
		if st <= 0.0 or (st < 0.5 and randf() > st * 1.8):
			continue
		_px(canvas, top, X, Y + (1.0 if randf() < 0.25 else 0.0), _ramp(0) if (q > 0.92 and st > 0.5) else _ramp(ci))


const MARK := Color8(216, 69, 44)
const MARK2 := Color8(122, 36, 24)


func _draw_marker(canvas: CanvasItem, top: Vector2, e: FireEffect, b: int) -> void:
	var t := float(e.marker.t)
	if t < 1.0 and ((e.f >> 3) & 1) == 0:
		return
	var c := MARK if t < 1.0 else MARK2
	var inside := {}
	for bc in e.blocks:
		inside[Vector2i(int(bc.x) >> 3, int(bc.y) >> 3)] = true
	for bk in inside:
		# the edges of a block that has no neighbour on that side, dotted
		var x0: int = bk.x * 8
		var y0: int = bk.y * 8
		for side in [[Vector2i(-1, 0), Vector2i(0, 0), Vector2i(0, 1)], [Vector2i(1, 0), Vector2i(8, 0), Vector2i(0, 1)],
				[Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(0, 1), Vector2i(0, 8), Vector2i(1, 0)]]:
			if inside.has(bk + side[0]):
				continue
			for k in 8:
				var X: int = x0 + side[1].x + side[2].x * k
				var Y: int = y0 + side[1].y + side[2].y * k
				if (X + Y) % 3 == 2 or band_of(X, Y) != b:
					continue
				var sp := _sp(X, Y, 0.0)
				_px(canvas, top, sp.x, sp.y, c)


# --- Heat haze (Overheat): rows of pixels shifted sideways over the target ----------

var _haze_nodes := {}
const HAZE_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float haze = 0.0;
uniform float t = 0.0;
uniform float px = 2.0; // screen pixels per art pixel
void fragment() {
	float r = floor(FRAGCOORD.y / px);
	float off = round(sin(r * 0.9 + t * 0.35) * haze * 1.6) * px;
	COLOR = texture(screen_tex, (FRAGCOORD.xy - vec2(off, 0.0)) * SCREEN_PIXEL_SIZE);
	if (off == 0.0) COLOR.a = 0.0;
}
"""


## Places a shimmering rect over each Overheat target (in `parent`'s canvas, above the world).
func update_haze(parent: Node2D, screen_scale: float) -> void:
	var live := {}
	for e in effects:
		if e.haze < 0.03:
			continue
		live[e] = true
		var r: ColorRect = _haze_nodes.get(e)
		if r == null:
			r = ColorRect.new()
			var m := ShaderMaterial.new()
			var sh := Shader.new()
			sh.code = HAZE_SHADER
			m.shader = sh
			r.material = m
			r.z_index = 50
			parent.add_child(r)
			_haze_nodes[e] = r
		var hw := maxf(4.0, roundf(9.0 * float(e.p.get("ohsize", 1.0))))
		var hr := maxf(8.0, roundf(30.0 * float(e.p.get("ohsize", 1.0))))
		var feet := Iso.to_screen(e.to_world(e.tg), e.base_h)
		var s := PixelCamera.ART_SCALE
		r.position = feet + Vector2(-hw, -2.0 - hr) * s
		r.size = Vector2(hw * 2.0 + 1.0, hr) * s
		(r.material as ShaderMaterial).set_shader_parameter("haze", e.haze)
		(r.material as ShaderMaterial).set_shader_parameter("t", float(e.f))
		(r.material as ShaderMaterial).set_shader_parameter("px", s * screen_scale)
	for e in _haze_nodes.keys():
		if not live.has(e):
			_haze_nodes[e].queue_free()
			_haze_nodes.erase(e)
