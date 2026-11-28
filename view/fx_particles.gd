class_name FxParticles
extends RefCounted
## A fixed pool of small particles (embers, drops, sparks) thrown off ribbons and
## fronts (stance rework phase 4). Preallocated arrays, reused in a ring: nothing is
## allocated per frame. Cosmetic only: each player's own (they change no shape).

const CAPACITY := 384

var pos := PackedVector3Array() # x, y in tiles; z = lift in levels
var vel := PackedVector3Array()
var age := PackedFloat32Array()
var life := PackedFloat32Array()
var color := PackedColorArray()
var base_tile := PackedVector2Array() # whose ground height they are measured from
var _next := 0


func _init() -> void:
	pos.resize(CAPACITY)
	vel.resize(CAPACITY)
	age.resize(CAPACITY)
	life.resize(CAPACITY)
	color.resize(CAPACITY)
	base_tile.resize(CAPACITY)
	for i in CAPACITY:
		life[i] = 0.0


## Starts one particle (the oldest slot is reused).
func emit(p: Vector3, v: Vector3, lifetime: float, c: Color, tile: Vector2i) -> void:
	var i := _next
	_next = (_next + 1) % CAPACITY
	pos[i] = p
	vel[i] = v
	age[i] = 0.0
	life[i] = lifetime
	color[i] = c
	base_tile[i] = Vector2(tile)


func update(dt: float) -> void:
	if dt <= 0.0:
		return
	for i in CAPACITY:
		if life[i] <= 0.0:
			continue
		age[i] += dt
		if age[i] >= life[i]:
			life[i] = 0.0
			continue
		pos[i] += vel[i] * dt


func alive(i: int) -> bool:
	return life[i] > 0.0


func clear() -> void:
	for i in CAPACITY:
		life[i] = 0.0
