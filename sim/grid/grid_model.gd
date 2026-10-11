class_name GridModel
extends RefCounted
## Logical tile grid: height and walkability per tile. Independent of visuals.
## Coordinates are Vector2i(x, y); movement is 4-directional.

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var width: int = 0
var depth: int = 0
var _heights := PackedInt32Array()
var _walkable := PackedByteArray()


func _init(p_width: int = 0, p_depth: int = 0, fill_height: int = 0) -> void:
	width = p_width
	depth = p_depth
	_heights.resize(width * depth)
	_heights.fill(fill_height)
	_walkable.resize(width * depth)
	_walkable.fill(1)


## Builds a grid from zone data. Returns null (and logs) if the zone is invalid.
static func from_zone(zone: ZoneDef) -> GridModel:
	var errors := zone.validate()
	if not errors.is_empty():
		push_error("Invalid zone: " + "; ".join(errors))
		return null
	var grid := GridModel.new(zone.get_width(), zone.get_depth())
	for y in grid.depth:
		var hrow := zone.height_rows[y]
		var wrow := zone.walk_rows[y]
		for x in grid.width:
			grid.set_tile(Vector2i(x, y), ZoneDef.parse_height(hrow[x]), wrow[x] == ".")
	return grid


static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < depth


func set_tile(p: Vector2i, h: int, walkable: bool) -> void:
	var i := _index(p)
	_heights[i] = h
	_walkable[i] = 1 if walkable else 0


func height_at(p: Vector2i) -> int:
	return _heights[_index(p)] if in_bounds(p) else 0


func is_walkable(p: Vector2i) -> bool:
	return in_bounds(p) and _walkable[_index(p)] == 1


## Whether an actor with `jump` can step from `from` to the adjacent tile `to`.
## Climbing is limited by jump; dropping is limited by `max_drop` (-1 = unlimited).
## Occupancy is not checked here.
func can_step(from: Vector2i, to: Vector2i, jump: int, max_drop: int = -1) -> bool:
	if distance(from, to) != 1 or not is_walkable(to) or not in_bounds(from):
		return false
	var rise := height_at(to) - height_at(from)
	if rise > jump:
		return false
	if max_drop >= 0 and -rise > max_drop:
		return false
	return true


## Height levels `from` stands above `to` (negative if below).
func height_advantage(from: Vector2i, to: Vector2i) -> int:
	return height_at(from) - height_at(to)


func _index(p: Vector2i) -> int:
	return p.y * width + p.x
