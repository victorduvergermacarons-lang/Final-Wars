class_name Bag
extends RefCounted
## A hero's bag: a fixed number of slots, each empty or holding a stack of one
## item (equippable items never stack). Equipped items are not in the bag.

const DEFAULT_SIZE := 20

## Each entry: null, or {"item": ItemDef, "count": int}.
var slots: Array = []


func _init(size: int = DEFAULT_SIZE) -> void:
	slots.resize(size)


func size() -> int:
	return slots.size()


func item_at(index: int) -> ItemDef:
	return slots[index].item if _valid(index) and slots[index] != null else null


func count_at(index: int) -> int:
	return slots[index].count if _valid(index) and slots[index] != null else 0


func free_slots() -> int:
	return slots.count(null)


func count_of(item: ItemDef) -> int:
	var n := 0
	for s in slots:
		if s != null and s.item == item:
			n += s.count
	return n


func index_of(item: ItemDef) -> int:
	for i in slots.size():
		if slots[i] != null and slots[i].item == item:
			return i
	return -1


## How many of `item` would fit (topping up stacks, then empty slots).
func room_for(item: ItemDef) -> int:
	var room := 0
	for s in slots:
		if s == null:
			room += item.max_stack
		elif s.item == item:
			room += item.max_stack - s.count
	return room


## Adds up to `count`; returns how many did NOT fit.
func add(item: ItemDef, count: int = 1) -> int:
	var left := count
	for s in slots:
		if left <= 0:
			break
		if s != null and s.item == item and s.count < item.max_stack:
			var put := mini(left, item.max_stack - s.count)
			s.count += put
			left -= put
	for i in slots.size():
		if left <= 0:
			break
		if slots[i] == null:
			var put := mini(left, item.max_stack)
			slots[i] = {"item": item, "count": put}
			left -= put
	return left


## Removes up to `count` from one slot; returns how many were removed.
func remove_at(index: int, count: int = 1) -> int:
	if not _valid(index) or slots[index] == null:
		return 0
	var taken := mini(count, slots[index].count)
	slots[index].count -= taken
	if slots[index].count <= 0:
		slots[index] = null
	return taken


## Removes exactly `count` of `item` from anywhere, or nothing if there aren't enough.
func remove_item(item: ItemDef, count: int = 1) -> bool:
	if count_of(item) < count:
		return false
	var left := count
	for i in range(slots.size() - 1, -1, -1):
		if left <= 0:
			break
		if slots[i] != null and slots[i].item == item:
			left -= remove_at(i, left)
	return true


## Moves a slot onto another: merges matching stacks, otherwise swaps.
func move(from: int, to: int) -> bool:
	if not _valid(from) or not _valid(to) or from == to or slots[from] == null:
		return false
	var a = slots[from]
	var b = slots[to]
	if b != null and b.item == a.item and b.count < a.item.max_stack:
		var put := mini(a.count, a.item.max_stack - b.count)
		b.count += put
		a.count -= put
		if a.count <= 0:
			slots[from] = null
		return true
	slots[from] = b
	slots[to] = a
	return true


## Splits `count` off a stack into the first empty slot.
func split(index: int, count: int) -> bool:
	if not _valid(index) or slots[index] == null or count <= 0 or count >= slots[index].count:
		return false
	var empty := slots.find(null)
	if empty < 0:
		return false
	slots[index].count -= count
	slots[empty] = {"item": slots[index].item, "count": count}
	return true


## An independent copy (for trying out changes).
func copy() -> Bag:
	var b := Bag.new(slots.size())
	for i in slots.size():
		if slots[i] != null:
			b.slots[i] = {"item": slots[i].item, "count": slots[i].count}
	return b


## Plain data: one entry per slot, null or [item id, count].
func to_array() -> Array:
	return slots.map(func(s): return null if s == null else [String(s.item.id), s.count])


## Rebuilds from plain data, resolving ids with `items` (id -> ItemDef). Unknown
## ids and bad counts are dropped.
static func from_array(data: Array, items: Dictionary, size: int = DEFAULT_SIZE) -> Bag:
	var bag := Bag.new(size)
	for i in mini(data.size(), size):
		var e = data[i]
		if typeof(e) != TYPE_ARRAY or e.size() != 2:
			continue
		var item: ItemDef = items.get(StringName(str(e[0])))
		var n := int(e[1]) if typeof(e[1]) in [TYPE_INT, TYPE_FLOAT] else 0
		if item != null and n > 0:
			bag.slots[i] = {"item": item, "count": mini(n, item.max_stack)}
	return bag


func _valid(index: int) -> bool:
	return index >= 0 and index < slots.size()
