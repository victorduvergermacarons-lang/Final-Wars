class_name FireEffects
extends RefCounted
## The fire effects on screen (fire physics): owned by WorldView like the water ropes.
## Starts effects, steps them on the GPU fluid (FireSim) at 60 steps per second of
## game time, and hands WorldView one item per tile diagonal of each effect's window
## (its band of fire), filed under a tile of that diagonal so walls and units in front
## of it cover it in the back-to-front pass.

var sim: FireSim
var effects: Array[FireEffect] = []


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
	e.aim = atan2(dir.y, dir.x)
	e.aim_t = e.aim
	effects.append(e)
	return e


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
			sim.set_units(e.slot, _units(e, actors))
			e.step(sim)
	sim.run()


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
					var i := i0 + sgn * k
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
	return out


func draw(canvas: CanvasItem, item: Dictionary) -> void:
	canvas.draw_texture_rect_region(sim.bands_texture(), item.rect, FireSim.band_rect(int(item.fireband), int(item.band)))
