class_name QuestLog
extends RefCounted
## Quest rules on a hero's `quest_state` (plain data, saved with the character):
##   {"<quest id>": {"state": "active", "progress": [int per objective], "ready": bool,
##                   "found": {"<objective index>": [investigate spot indices]}}}
##   {"<quest id>": {"state": "done"}}
##   {"<quest id>": {"state": "failed"}}   (an escort died: restart it from the giver)
## Functions return events (plain Dictionaries) for WorldSim to emit.
## `quests` is always a Dictionary of id -> QuestDef.

enum Status {
	UNAVAILABLE, ## Prerequisites or level not met.
	AVAILABLE, ## Can be accepted.
	ACTIVE, ## Accepted, objectives not all done.
	READY, ## Accepted, every objective done: hand it in.
	DONE, ## Handed in.
	FAILED, ## Failed (escort died): the giver offers it again.
}


static func status(hero: Hero, def: QuestDef) -> Status:
	var st := state_of(hero, def.id)
	match st.get("state", ""):
		"done":
			return Status.DONE
		"active":
			return Status.READY if is_complete(hero, def) else Status.ACTIVE
		"failed":
			return Status.FAILED
	return Status.AVAILABLE if can_accept(hero, def) == "" else Status.UNAVAILABLE


static func state_of(hero: Hero, id: StringName) -> Dictionary:
	var st = hero.quest_state.get(String(id))
	return st if typeof(st) == TYPE_DICTIONARY else {}


static func is_active(hero: Hero, id: StringName) -> bool:
	return state_of(hero, id).get("state", "") == "active"


static func is_done(hero: Hero, id: StringName) -> bool:
	return state_of(hero, id).get("state", "") == "done"


static func is_failed(hero: Hero, id: StringName) -> bool:
	return state_of(hero, id).get("state", "") == "failed"


## "" if the hero may accept `def` (a failed quest may be accepted again), else
## the reason.
static func can_accept(hero: Hero, def: QuestDef) -> String:
	if is_active(hero, def.id):
		return "quest_active"
	if is_done(hero, def.id):
		return "quest_done"
	for pre in def.prerequisites:
		if not is_done(hero, pre):
			return "prerequisite"
	if hero.level < def.min_level:
		return "level_too_low"
	return ""


## Progress on objective `i` (COLLECT counts what's in the bag).
static func progress(hero: Hero, def: QuestDef, i: int) -> int:
	var obj := def.objectives[i]
	if obj.counts_bag():
		return mini(hero.bag.count_of(obj.item), obj.needed())
	var p: Array = state_of(hero, def.id).get("progress", [])
	return int(p[i]) if i < p.size() else 0


static func is_complete(hero: Hero, def: QuestDef) -> bool:
	for i in def.objectives.size():
		if progress(hero, def, i) < def.objectives[i].needed():
			return false
	return true


## Investigate spots of objective `i` already examined (indices into `spots`).
static func found_spots(hero: Hero, def: QuestDef, i: int) -> Array:
	var found = state_of(hero, def.id).get("found", {})
	return found.get(str(i), []) if typeof(found) == TYPE_DICTIONARY else []


## Whether the items `def` hands over fit in the hero's bag.
static func given_items_fit(hero: Hero, def: QuestDef) -> bool:
	var trial := hero.bag.copy()
	for item in def.given_items:
		if trial.add(item, 1) > 0:
			return false
	return true


## Accepts (or restarts, after a failure) `def`: fresh progress, and the items the
## quest hands over (check given_items_fit first; nothing happens if they don't).
static func accept(hero: Hero, def: QuestDef) -> Array[Dictionary]:
	if not given_items_fit(hero, def):
		return [] as Array[Dictionary]
	for item in def.given_items:
		hero.bag.add(item, 1)
	var progress_list: Array = []
	progress_list.resize(def.objectives.size())
	progress_list.fill(0)
	hero.quest_state[String(def.id)] = {"state": "active", "progress": progress_list, "ready": false, "found": {}}
	var events: Array[Dictionary] = [{"type": "quest_accepted", "target": hero.id, "quest": def.id,
			"items": def.given_items.map(func(i): return String(i.id))}]
	events.append_array(refresh(hero, {def.id: def}))
	return events


## Forgets the quest and takes back what it handed over (if still in the bag).
static func abandon(hero: Hero, def: QuestDef) -> Array[Dictionary]:
	hero.quest_state.erase(String(def.id))
	_take_given(hero, def)
	return [{"type": "quest_abandoned", "target": hero.id, "quest": def.id}] as Array[Dictionary]


## The quest fails (its escort died): its handed-over items go, and the giver
## offers it again.
static func fail(hero: Hero, def: QuestDef) -> Array[Dictionary]:
	if not is_active(hero, def.id):
		return [] as Array[Dictionary]
	hero.quest_state[String(def.id)] = {"state": "failed"}
	_take_given(hero, def)
	return [{"type": "quest_failed", "target": hero.id, "quest": def.id}] as Array[Dictionary]


## Credit for killing an enemy of type `enemy_id`.
static func on_kill(hero: Hero, quests: Dictionary, enemy_id: StringName) -> Array[Dictionary]:
	return _advance(hero, quests, func(o: QuestObjective) -> bool:
		return o.kind == QuestObjective.Kind.KILL and o.enemy == enemy_id)


## Credit for talking to an NPC (TALK) or using an object (INTERACT) of type `npc_id`.
static func on_talk(hero: Hero, quests: Dictionary, npc_id: StringName) -> Array[Dictionary]:
	return _advance(hero, quests, func(o: QuestObjective) -> bool:
		return (o.kind == QuestObjective.Kind.TALK or o.kind == QuestObjective.Kind.INTERACT) and o.npc == npc_id)


## Credit for standing on `tile` in zone `zone_id`.
static func on_reach(hero: Hero, quests: Dictionary, zone_id: StringName, tile: Vector2i) -> Array[Dictionary]:
	return _advance(hero, quests, func(o: QuestObjective) -> bool:
		return o.kind == QuestObjective.Kind.REACH and o.zone == zone_id \
				and GridModel.distance(o.tile, tile) <= o.radius)


## DELIVER objectives this hero can hand to NPC `npc_id` now: [[QuestDef, index]].
static func deliverable(hero: Hero, quests: Dictionary, npc_id: StringName) -> Array:
	var out := []
	for def in _active_defs(hero, quests):
		for i in def.objectives.size():
			var o: QuestObjective = def.objectives[i]
			if o.kind == QuestObjective.Kind.DELIVER and o.npc == npc_id and progress(hero, def, i) < o.needed() \
					and hero.bag.count_of(o.item) >= o.needed():
				out.append([def, i])
	return out


## `deliverer` hands objective `i`'s items over: they leave its bag, and the
## objective is done for it and for every `sharer` on the same quest (their own
## copies of a handed-over item are no longer needed and go too).
static func deliver(deliverer: Hero, sharers: Array, def: QuestDef, i: int) -> Array[Dictionary]:
	var o := def.objectives[i]
	var events: Array[Dictionary] = []
	deliverer.bag.remove_item(o.item, o.needed())
	for h in sharers:
		if not is_active(h, def.id) or progress(h, def, i) >= o.needed():
			continue
		if h != deliverer and def.given_items.has(o.item):
			h.bag.remove_item(o.item, mini(h.bag.count_of(o.item), o.needed()))
		events.append_array(set_progress(h, def, i, o.needed()))
	events.append({"type": "delivered", "target": deliverer.id, "quest": def.id, "objective": i,
			"item": o.item.id, "count": o.needed()})
	return events


## Examining `tile` in zone `zone_id`: the INVESTIGATE spots there (within 1
## tile) not yet examined. Returns [[QuestDef, objective index, spot index]].
static func spots_at(hero: Hero, quests: Dictionary, zone_id: StringName, tile: Vector2i) -> Array:
	var out := []
	for def in _active_defs(hero, quests):
		for i in def.objectives.size():
			var o: QuestObjective = def.objectives[i]
			if o.kind != QuestObjective.Kind.INVESTIGATE or o.zone != zone_id:
				continue
			var found := found_spots(hero, def, i)
			for n in o.spots.size():
				if not found.has(n) and GridModel.distance(o.spots[n], tile) <= 1:
					out.append([def, i, n])
	return out


## The INVESTIGATE spots in zone `zone_id` still to examine (the view makes them
## glow; E examines the one beside you).
static func open_spots(hero: Hero, quests: Dictionary, zone_id: StringName) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for def in _active_defs(hero, quests):
		for i in def.objectives.size():
			var o: QuestObjective = def.objectives[i]
			if o.kind != QuestObjective.Kind.INVESTIGATE or o.zone != zone_id:
				continue
			var found := found_spots(hero, def, i)
			for n in o.spots.size():
				if not found.has(n) and not out.has(o.spots[n]):
					out.append(o.spots[n])
	return out


## Marks investigate spot `n` of objective `i` examined.
static func mark_spot(hero: Hero, def: QuestDef, i: int, n: int) -> Array[Dictionary]:
	if not is_active(hero, def.id):
		return [] as Array[Dictionary]
	var st := state_of(hero, def.id)
	if typeof(st.get("found")) != TYPE_DICTIONARY:
		st.found = {}
	var list: Array = st.found.get(str(i), [])
	if list.has(n):
		return [] as Array[Dictionary]
	list.append(n)
	st.found[str(i)] = list
	return set_progress(hero, def, i, list.size())


## Sets objective `i` to `count` (escorts arriving, deliveries, spots) and emits
## the progress and readiness that follow.
static func set_progress(hero: Hero, def: QuestDef, i: int, count: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not is_active(hero, def.id):
		return events
	var p: Array = state_of(hero, def.id).progress
	var n := clampi(count, 0, def.objectives[i].needed())
	if n == int(p[i]):
		return events
	p[i] = n
	events.append(_progress_event(hero, def, i))
	events.append_array(refresh(hero, {def.id: def}))
	return events


## Whether a REACH objective of an active quest is at `zone_id` (cheap pre-check).
static func has_reach_in(hero: Hero, quests: Dictionary, zone_id: StringName) -> bool:
	for def in _active_defs(hero, quests):
		for o in def.objectives:
			if o.kind == QuestObjective.Kind.REACH and o.zone == zone_id:
				return true
	return false


## Whether `item` still counts toward an active COLLECT objective of `quest_id`.
static func needs_item(hero: Hero, quests: Dictionary, quest_id: StringName, item: ItemDef) -> bool:
	var def: QuestDef = quests.get(quest_id)
	if def == null or not is_active(hero, quest_id):
		return false
	for o in def.objectives:
		if o.kind == QuestObjective.Kind.COLLECT and o.item == item and hero.bag.count_of(item) < o.needed():
			return true
	return false


## Syncs stored COLLECT counts with the bag and the "ready" flag with the
## objectives; emits quest_progress / quest_ready for what changed.
static func refresh(hero: Hero, quests: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for key in hero.quest_state.keys():
		var def: QuestDef = quests.get(StringName(key))
		var st := state_of(hero, StringName(key))
		if def == null or st.get("state", "") != "active":
			continue
		var p: Array = st.progress
		for i in def.objectives.size():
			if not def.objectives[i].counts_bag():
				continue
			var n := progress(hero, def, i)
			if n != int(p[i]):
				p[i] = n
				events.append(_progress_event(hero, def, i))
		var complete := is_complete(hero, def)
		if complete != bool(st.get("ready", false)):
			st.ready = complete
			if complete:
				events.append({"type": "quest_ready", "target": hero.id, "quest": def.id})
	return events


## Hands in a READY quest: takes COLLECT items, pays XP, gold and items (one of
## `reward_choices` by index `choice`). Returns {"reason": "" or why not, "events"}.
static func turn_in(hero: Hero, def: QuestDef, choice: int, rules: CombatRules) -> Dictionary:
	var events: Array[Dictionary] = []
	if status(hero, def) != Status.READY:
		return {"reason": "quest_not_ready", "events": events}
	var rewards: Array[ItemDef] = []
	rewards.append_array(def.reward_items)
	if not def.reward_choices.is_empty():
		if choice < 0 or choice >= def.reward_choices.size():
			return {"reason": "choose_reward", "events": events}
		rewards.append(def.reward_choices[choice])
	# Try it on a copy first so a full bag changes nothing.
	var trial := hero.bag.copy()
	for o in def.objectives:
		if o.kind == QuestObjective.Kind.COLLECT:
			trial.remove_item(o.item, o.needed())
	for item in rewards:
		if trial.add(item, 1) > 0:
			return {"reason": "bag_full", "events": events}
	hero.bag = trial
	hero.quest_state[String(def.id)] = {"state": "done"}
	hero.gold = mini(hero.gold + def.reward_gold, CharacterData.MAX_GOLD)
	events.append({"type": "quest_completed", "target": hero.id, "quest": def.id, "xp": def.reward_xp,
			"gold": def.reward_gold, "items": rewards.map(func(i): return String(i.id))})
	events.append_array(Leveling.add_xp(hero, def.reward_xp, rules))
	return {"reason": "", "events": events}


## What an NPC shows over its head for this hero: "?" when a quest can be handed
## in to it, "!" when it offers one (or a failed one again), "" otherwise.
static func npc_marker(hero: Hero, quests: Dictionary, npc_id: StringName) -> String:
	var marker := ""
	for def in quests.values():
		var s := status(hero, def)
		if s == Status.READY and def.turn_in_npc() == npc_id:
			return "?"
		if (s == Status.AVAILABLE or s == Status.FAILED) and def.giver == npc_id:
			marker = "!"
	return marker


## Cleans quest state loaded from a save (JSON): known quests only, int progress
## clamped to each objective, anything malformed dropped.
static func normalize(raw: Variant, quests: Dictionary) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for key in raw:
		var def: QuestDef = quests.get(StringName(str(key)))
		var st = raw[key]
		if def == null or typeof(st) != TYPE_DICTIONARY:
			continue
		match st.get("state"):
			"done":
				out[String(def.id)] = {"state": "done"}
			"failed":
				out[String(def.id)] = {"state": "failed"}
			"active":
				var p = st.get("progress", [])
				var clean: Array = []
				for i in def.objectives.size():
					var v = p[i] if typeof(p) == TYPE_ARRAY and i < p.size() else 0
					var n := int(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else 0
					clean.append(clampi(n, 0, def.objectives[i].needed()))
				var found := {}
				var raw_found = st.get("found", {})
				if typeof(raw_found) == TYPE_DICTIONARY:
					for i in def.objectives.size():
						var o := def.objectives[i]
						var list = raw_found.get(str(i), [])
						if o.kind != QuestObjective.Kind.INVESTIGATE or typeof(list) != TYPE_ARRAY:
							continue
						var spots: Array = []
						for n in list:
							if typeof(n) in [TYPE_INT, TYPE_FLOAT] and int(n) >= 0 and int(n) < o.spots.size() \
									and not spots.has(int(n)):
								spots.append(int(n))
						found[str(i)] = spots
						clean[i] = spots.size()
				# An escort in progress isn't saved: it restarts from where it stands.
				out[String(def.id)] = {"state": "active", "progress": clean, "ready": false, "found": found}
	return out


static func _active_defs(hero: Hero, quests: Dictionary) -> Array[QuestDef]:
	var out: Array[QuestDef] = []
	var keys := hero.quest_state.keys()
	keys.sort()
	for key in keys:
		var def: QuestDef = quests.get(StringName(key))
		if def != null and is_active(hero, def.id):
			out.append(def)
	return out


static func _take_given(hero: Hero, def: QuestDef) -> void:
	for item in def.given_items:
		hero.bag.remove_item(item, mini(hero.bag.count_of(item), 1))


static func _advance(hero: Hero, quests: Dictionary, matches: Callable) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for def in _active_defs(hero, quests):
		var p: Array = state_of(hero, def.id).progress
		for i in def.objectives.size():
			var o := def.objectives[i]
			if o.counts_bag() or not matches.call(o):
				continue
			if int(p[i]) >= o.needed():
				continue
			p[i] = int(p[i]) + 1
			events.append(_progress_event(hero, def, i))
	if not events.is_empty():
		events.append_array(refresh(hero, quests))
	return events


static func _progress_event(hero: Hero, def: QuestDef, i: int) -> Dictionary:
	return {"type": "quest_progress", "target": hero.id, "quest": def.id, "objective": i,
			"count": progress(hero, def, i), "needed": def.objectives[i].needed(),
			"text": def.objectives[i].text}
