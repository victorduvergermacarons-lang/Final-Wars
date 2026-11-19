class_name GroundDrops
extends RefCounted
## Personal loot lying on the ground in one zone (host only). Each drop belongs to
## one hero: only that hero is sent it (Snapshot private "drops") and only that hero
## can pick it up. Drops last PartyPlayDef.drop_seconds.

## {id, owner, item: ItemDef, count, pos: Vector2, expires, source: StringName}
var _drops: Array = []
var _next_id := 1


func add(owner: int, item: ItemDef, count: int, pos: Vector2, expires: float, source: StringName = &"") -> int:
	var id := _next_id
	_next_id += 1
	_drops.append({"id": id, "owner": owner, "item": item, "count": count, "pos": pos,
			"expires": expires, "source": source})
	return id


func find(id: int) -> Dictionary:
	for d in _drops:
		if d.id == id:
			return d
	return {}


func remove(id: int) -> void:
	_drops = _drops.filter(func(d): return d.id != id)


func expire(now: float) -> void:
	_drops = _drops.filter(func(d): return d.expires > now)


func clear() -> void:
	_drops.clear()


func all() -> Array:
	return _drops


## One hero's drops as plain data: [{"id", "item" (id), "count", "pos", "expires"}].
func for_owner(owner: int) -> Array:
	var out: Array = []
	for d in _drops:
		if d.owner == owner:
			out.append({"id": d.id, "item": String(d.item.id), "count": d.count, "pos": d.pos,
					"expires": d.expires})
	return out
