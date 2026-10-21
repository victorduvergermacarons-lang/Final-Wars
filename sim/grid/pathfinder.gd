class_name Pathfinder
extends RefCounted
## A* over GridModel using the same step rule as movement (Jump climb limit).


## Shortest 4-directional path from `start` to `goal`, both included.
## `blocked` holds tiles that can't be entered (e.g. occupied); `start` and
## `goal` are exempt so callers can path to an occupied target.
## Returns [] if there is no path within `max_expanded` node expansions.
## `fly_rise` >= 0: the path of a flier (GridModel.can_fly with that wall rise).
## `footprint`: offsets of a large body (Actor.footprint); every tile it covers must
## be able to make each step and stay clear of `blocked` (the goal step excepted).
## `goals`: when not empty, the path ends on whichever of these tiles it reaches
## first (none of them exempt from `blocked`), and `goal` with `goal_slack` only
## guides the search: every goal is within `goal_slack` steps of `goal` (a large
## body heading for the tiles beside its target).
static func find_path(grid: GridModel, start: Vector2i, goal: Vector2i, jump: int,
		blocked: Dictionary = {}, max_drop: int = -1, max_expanded: int = 4096, fly_rise: int = -1,
		footprint: Array = [], goals: Dictionary = {}, goal_slack: int = 0) -> Array[Vector2i]:
	var body: Array = footprint if not footprint.is_empty() else [Vector2i.ZERO]
	var empty: Array[Vector2i] = []
	var any_goal := not goals.is_empty()
	if not grid.in_bounds(start):
		return empty
	if not any_goal and (not grid.in_bounds(goal) \
			or (not grid.is_walkable(goal) if fly_rise < 0 else grid.blocks_sight(goal))):
		return empty
	if start == goal or goals.has(start):
		return [start] as Array[Vector2i]

	var came_from := {start: start}
	var cost := {start: 0}
	var heap := _Heap.new()
	heap.push(maxi(GridModel.distance(start, goal) - goal_slack, 0), start)
	var expanded := 0

	while not heap.is_empty():
		var current: Vector2i = heap.pop()
		if goals.has(current) or (not any_goal and current == goal):
			return _rebuild(came_from, start, current)
		expanded += 1
		if expanded > max_expanded:
			break
		for dir in GridModel.DIRECTIONS:
			var next := current + dir
			if not _body_fits(grid, current, next, body, jump, max_drop, fly_rise, blocked,
					not any_goal and next == goal):
				continue
			var new_cost: int = cost[current] + 1
			if not cost.has(next) or new_cost < cost[next]:
				cost[next] = new_cost
				came_from[next] = current
				heap.push(new_cost + maxi(GridModel.distance(next, goal) - goal_slack, 0), next)
	return empty


## Whether a body with these offsets can step from `current` to `next`.
static func _body_fits(grid: GridModel, current: Vector2i, next: Vector2i, body: Array, jump: int,
		max_drop: int, fly_rise: int, blocked: Dictionary, at_goal: bool) -> bool:
	for o in body:
		var a: Vector2i = current + o
		var b: Vector2i = next + o
		if not at_goal and blocked.has(b):
			return false
		if fly_rise >= 0:
			if not grid.can_fly(a, b, fly_rise):
				return false
		elif not grid.can_step(a, b, jump, max_drop):
			return false
	return true


static func _rebuild(came_from: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [goal]
	var p := goal
	while p != start:
		p = came_from[p]
		path.append(p)
	path.reverse()
	return path


## Minimal binary min-heap keyed by priority; ties pop in insertion order so
## results are deterministic across peers.
class _Heap:
	var _items: Array = [] # [priority, seq, value]
	var _seq := 0

	func is_empty() -> bool:
		return _items.is_empty()

	func push(priority: int, value: Variant) -> void:
		_items.append([priority, _seq, value])
		_seq += 1
		var i := _items.size() - 1
		while i > 0:
			var parent := (i - 1) / 2
			if not _less(_items[i], _items[parent]):
				break
			_swap(i, parent)
			i = parent

	func pop() -> Variant:
		var top = _items[0][2]
		var last = _items.pop_back()
		if not _items.is_empty():
			_items[0] = last
			var i := 0
			var n := _items.size()
			while true:
				var smallest := i
				var l := 2 * i + 1
				var r := l + 1
				if l < n and _less(_items[l], _items[smallest]):
					smallest = l
				if r < n and _less(_items[r], _items[smallest]):
					smallest = r
				if smallest == i:
					break
				_swap(i, smallest)
				i = smallest
		return top

	func _less(a: Array, b: Array) -> bool:
		return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])

	func _swap(i: int, j: int) -> void:
		var t = _items[i]
		_items[i] = _items[j]
		_items[j] = t
