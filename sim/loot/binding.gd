class_name Binding
extends RefCounted
## Who an item belongs to. Each bag stack may carry a bind state
## ({"bound": true, "until": host time, "fight": [character names]}; none = free):
## - Bind on Pickup (scrolls, and boss key items won in a roll): bound the moment it
##   is yours. A looted one can still go, by trade, to someone who was in the fight
##   it dropped in, until PartyPlayDef.bop_trade_seconds after it was looted.
## - Bind on Equip (all other gear): free until worn; everything worn is bound.
## - Unbound (materials, consumables, quest items, gold): always free.
## Saved characters keep "bound" but drop the trade window (it runs on a session's
## clock).

enum Kind { UNBOUND, BIND_ON_EQUIP, BIND_ON_PICKUP }

const KIND_NAMES := ["Not bound", "Bind on Equip", "Bind on Pickup"]


static func kind_of(item: ItemDef) -> Kind:
	if item == null:
		return Kind.UNBOUND
	if item.is_scroll:
		return Kind.BIND_ON_PICKUP
	if item.is_equippable():
		return Kind.BIND_ON_EQUIP
	return Kind.UNBOUND


## The bind state an item gets when it becomes someone's: bound for Bind on Pickup
## (with a trade window for the fight's members when `fight` is given; `force`
## makes any item Bind on Pickup: boss key items), else none.
static func on_acquire(item: ItemDef, fight: Array = [], until: float = -1.0, force := false) -> Dictionary:
	if not force and kind_of(item) != Kind.BIND_ON_PICKUP:
		return {}
	var b := {"bound": true}
	if not fight.is_empty() and until > 0.0:
		b.until = until
		b.fight = fight.duplicate()
	return b


static func is_bound(bind) -> bool:
	return bind is Dictionary and bind.get("bound", false)


## Whether a stack with this bind state may be traded to `to_name` at `now`.
static func can_trade(bind, to_name: String, now: float) -> bool:
	if not is_bound(bind):
		return true
	return now < float(bind.get("until", -1.0)) and Array(bind.get("fight", [])).has(to_name)


## Seconds left in a bound item's trade window (0 = none).
static func trade_seconds_left(bind, now: float) -> float:
	if not is_bound(bind):
		return 0.0
	return maxf(float(bind.get("until", -1.0)) - now, 0.0)


## The tooltip lines: the binding state, and a Bind on Pickup item's trade window.
static func describe(item: ItemDef, bind, worn: bool, now: float) -> PackedStringArray:
	var out: PackedStringArray = []
	if worn or is_bound(bind):
		out.append("Soulbound")
		var left := trade_seconds_left(bind, now)
		if left > 0.0:
			out.append("Tradeable to %s for %d:%02d" % [", ".join(PackedStringArray(bind.get("fight", []))),
					int(left) / 60, int(left) % 60])
	else:
		out.append(KIND_NAMES[kind_of(item)])
	return out


## Two stacks may merge only if they are bound the same way.
static func same(a, b) -> bool:
	var ea: Dictionary = a if a is Dictionary else {}
	var eb: Dictionary = b if b is Dictionary else {}
	return ea.hash() == eb.hash()
