class_name Trades
extends RefCounted
## Player-to-player requests and trades in one zone (host only; WorldSim owns one).
##
## Requests (trade or duel): the target answers Accept / Decline; no answer within
## PartyPlayDef.request_seconds declines it.
##
## A trade: each side puts items (and gold) into the window. They leave the owner's
## bag into escrow at once, so they can't be used, dropped or sold meanwhile. Each
## side clicks Offer to lock it; any change unlocks both. With both locked, the
## contract shows what each gives and gets: both Accept and the host swaps everything
## in one go (refused, and everything returned, if a bag can't hold what it gets);
## a Decline, a disconnect, walking out of range or entering combat cancels it and
## everything goes back to its owner (to the ground at their feet if their bag is
## full). Only tradeable stacks may go in (Binding.can_trade toward the other side).

## {id, kind: "trade" | "duel", from, to, expires}
var requests: Array = []
## {id, a, b, side: {hero id: {"items": [{"item", "count", "bind"}], "gold", "locked",
##  "accepted"}}, stage: "edit" | "contract"}
var trades: Array = []
var _next_id := 1


func request(kind: String, from: int, to: int, now: float, pp: PartyPlayDef) -> Dictionary:
	var r := {"id": _next_id, "kind": kind, "from": from, "to": to, "expires": now + pp.request_seconds}
	_next_id += 1
	requests.append(r)
	return r


func find_request(id: int) -> Dictionary:
	for r in requests:
		if r.id == id:
			return r
	return {}


func pending_between(a: int, b: int, kind: String) -> bool:
	for r in requests:
		if r.kind == kind and ((r.from == a and r.to == b) or (r.from == b and r.to == a)):
			return true
	return false


func trade_of(hero_id: int) -> Dictionary:
	for t in trades:
		if t.a == hero_id or t.b == hero_id:
			return t
	return {}


func open(a: int, b: int) -> Dictionary:
	var t := {"id": _next_id, "a": a, "b": b, "stage": "edit", "side": {
		a: {"items": [], "gold": 0, "locked": false, "accepted": false},
		b: {"items": [], "gold": 0, "locked": false, "accepted": false}}}
	_next_id += 1
	trades.append(t)
	return t


static func other(t: Dictionary, hero_id: int) -> int:
	return t.b if t.a == hero_id else t.a


## Anything changed: both sides unlock and the contract (if shown) is withdrawn.
static func unlock(t: Dictionary) -> void:
	t.stage = "edit"
	for id in t.side:
		t.side[id].locked = false
		t.side[id].accepted = false


## Puts `count` of the stack in bag slot `index` into `hero`'s side (escrow).
func add_item(t: Dictionary, hero: Hero, to_name: String, index: int, count: int, now: float,
		pp: PartyPlayDef) -> String:
	var item := hero.bag.item_at(index)
	if item == null:
		return "empty"
	if item.quest_item:
		return "cant_trade"
	var bind := hero.bag.bind_at(index)
	if not Binding.can_trade(bind, to_name, now):
		return "bound"
	var side: Dictionary = t.side[hero.id]
	if side.items.size() >= pp.trade_slots:
		return "trade_full"
	var n := clampi(count, 1, hero.bag.count_at(index))
	hero.bag.remove_at(index, n)
	side.items.append({"item": item, "count": n, "bind": bind.duplicate(true)})
	unlock(t)
	_mirror_escrow(t, hero)
	return ""


## Takes entry `slot` of `hero`'s side back into its bag.
func remove_item(t: Dictionary, hero: Hero, slot: int, drop: Callable) -> String:
	var side: Dictionary = t.side[hero.id]
	if slot < 0 or slot >= side.items.size():
		return "empty"
	var e: Dictionary = side.items[slot]
	side.items.remove_at(slot)
	_give_back(hero, e, drop)
	unlock(t)
	_mirror_escrow(t, hero)
	return ""


## Sets how much gold `hero` offers (taken from its purse into escrow).
func set_gold(t: Dictionary, hero: Hero, amount: int) -> String:
	var side: Dictionary = t.side[hero.id]
	var total: int = hero.gold + side.gold
	var g := clampi(amount, 0, total)
	hero.gold = total - g
	side.gold = g
	unlock(t)
	_mirror_escrow(t, hero)
	return ""


func offer(t: Dictionary, hero_id: int) -> void:
	t.side[hero_id].locked = true
	if t.side[t.a].locked and t.side[t.b].locked:
		t.stage = "contract"


## Accepts the contract; true once both have (the caller then swaps).
func accept(t: Dictionary, hero_id: int) -> bool:
	if t.stage != "contract":
		return false
	t.side[hero_id].accepted = true
	return t.side[t.a].accepted and t.side[t.b].accepted


## Swaps everything in one go, or nothing ("" or "bag_full").
func complete(t: Dictionary, a: Hero, b: Hero) -> String:
	for pair in [[a, b], [b, a]]:
		var trial: Bag = pair[0].bag.copy()
		for e in t.side[pair[1].id].items:
			if trial.add(e.item, e.count, e.bind) > 0:
				return "bag_full"
	for pair in [[a, b], [b, a]]:
		var receiver: Hero = pair[0]
		var giver: Hero = pair[1]
		for e in t.side[giver.id].items:
			receiver.bag.add(e.item, e.count, e.bind)
		receiver.gold = mini(receiver.gold + t.side[giver.id].gold, CharacterData.MAX_GOLD)
	trades.erase(t)
	a.escrow = []
	b.escrow = []
	a.escrow_gold = 0
	b.escrow_gold = 0
	return ""


## Ends a trade, everything back to its owner (`heroes`: id -> Hero, missing =
## gone; `drop` (hero, item, count, bind) puts what doesn't fit on the ground).
func cancel(t: Dictionary, heroes: Dictionary, drop: Callable) -> void:
	trades.erase(t)
	for id in [t.a, t.b]:
		var h: Hero = heroes.get(id)
		if h == null:
			continue
		for e in t.side[id].items:
			_give_back(h, e, drop)
		h.gold = mini(h.gold + t.side[id].gold, CharacterData.MAX_GOLD)
		h.escrow = []
		h.escrow_gold = 0


static func _give_back(hero: Hero, e: Dictionary, drop: Callable) -> void:
	var left := hero.bag.add(e.item, e.count, e.bind)
	if left > 0:
		drop.call(hero, e.item, left, e.bind)


## Keeps the hero's escrow on the hero too, so a save made mid-trade keeps it.
static func _mirror_escrow(t: Dictionary, hero: Hero) -> void:
	var side: Dictionary = t.side[hero.id]
	hero.escrow = side.items.map(func(e): return [String(e.item.id), e.count, e.bind])
	hero.escrow_gold = side.gold


## One player's view of its trade, as plain data (Snapshot private "trade").
static func view(t: Dictionary, hero_id: int, names: Dictionary) -> Dictionary:
	if t.is_empty():
		return {}
	var o := other(t, hero_id)
	var plain := func(side: Dictionary) -> Dictionary:
		return {"items": side.items.map(func(e): return [String(e.item.id), e.count, e.bind]),
				"gold": side.gold, "locked": side.locked, "accepted": side.accepted}
	return {"id": t.id, "with": o, "with_name": names.get(o, "?"), "stage": t.stage,
			"mine": plain.call(t.side[hero_id]), "theirs": plain.call(t.side[o])}
