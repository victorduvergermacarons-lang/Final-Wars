class_name QuestLog
extends RefCounted
## Quest rules on a hero's `quest_state` (plain data, saved with the character):
##   {"<quest id>": {"state": "active", "progress": [int per objective], "ready": bool}}
##   {"<quest id>": {"state": "done"}}
## Functions return events (plain Dictionaries) for WorldSim to emit.
## `quests` is always a Dictionary of id -> QuestDef.

enum Status {
	UNAVAILABLE, ## Prerequisites or level not met.
	AVAILABLE, ## Can be accepted.
	ACTIVE, ## Accepted, objectives not all done.
	READY, ## Accepted, every objective done: hand it in.
	DONE, ## Handed in.
}


static func status(hero: Hero, def: QuestDef) -> Status:
	var st := state_of(hero, def.id)
	match st.get("state", ""):
		"done":
			return Status.DONE
		"active":
			return Status.READY if is_complete(hero, def) else Status.ACTIVE
	return Status.AVAILABLE if can_accept(hero, def) == "" else Status.UNAVAILABLE


static func state_of(hero: Hero, id: StringName) -> Dictionary:
	var st = hero.quest_state.get(String(id))
	return st if typeof(st) == TYPE_DICTIONARY else {}


static func is_active(hero: Hero, id: StringName) -> bool:
	return state_of(hero, id).get("state", "") == "active"


static func is_done(hero: Hero, id: StringName) -> bool:
	return state_of(hero, id).get("state", "") == "done"


## "" if the hero may accept `def`, else the reason.
static func can_accept(hero: Hero, def: QuestDef) -> String:
	if is_active(hero, def.id):
		return "quest_active"
	if is_done(hero, def.id):
		return "quest_done"
	if hero.level < def.min_level:
		return "level_too_low"
	for pre in def.prerequisites:
		if not is_done(hero, pre):
			return "prerequisite"
	return ""


## Progress on objective `i` (COLLECT counts what's in the bag).
static func progress(hero: Hero, def: QuestDef, i: int) -> int:
	var obj := def.objectives[i]
	if obj.kind == QuestObjective.Kind.COLLECT:
		return mini(hero.bag.count_of(obj.item), obj.needed())
	var p: Array = state_of(hero, def.id).get("progress", [])
	return int(p[i]) if i < p.size() else 0


static func is_complete(hero: Hero, def: QuestDef) -> bool:
	for i in def.objectives.size():
		if progress(hero, def, i) < def.objectives[i].needed():
			return false
	return true


static func accept(hero: Hero, def: QuestDef) -> Array[Dictionary]:
	var progress_list: Array = []
	progress_list.resize(def.objectives.size())
	progress_list.fill(0)
	hero.quest_state[String(def.id)] = {"state": "active", "progress": progress_list, "ready": false}
	var events: Array[Dictionary] = [{"type": "quest_accepted", "target": hero.id, "quest": def.id}]
	events.append_array(refresh(hero, {def.id: def}))
	return events


static func abandon(hero: Hero, def: QuestDef) -> Array[Dictionary]:
	hero.quest_state.erase(String(def.id))
	return [{"type": "quest_abandoned", "target": hero.id, "quest": def.id}] as Array[Dictionary]


## Credit for killing an enemy of type `enemy_id`.
static func on_kill(hero: Hero, quests: Dictionary, enemy_id: StringName) -> Array[Dictionary]:
	return _advance(hero, quests, func(o: QuestObjective) -> bool:
		return o.kind == QuestObjective.Kind.KILL and o.enemy == enemy_id)


## Credit for talking to an NPC of type `npc_id`.
static func on_talk(hero: Hero, quests: Dictionary, npc_id: StringName) -> Array[Dictionary]:
	return _advance(hero, quests, func(o: QuestObjective) -> bool:
		return o.kind == QuestObjective.Kind.TALK and o.npc == npc_id)


## Credit for standing on `tile` in zone `zone_id`.
static func on_reach(hero: Hero, quests: Dictionary, zone_id: StringName, tile: Vector2i) -> Array[Dictionary]:
	return _advance(hero, quests, func(o: QuestObjective) -> bool:
		return o.kind == QuestObjective.Kind.REACH and o.zone == zone_id \
				and GridModel.distance(o.tile, tile) <= o.radius)


## Whether a REACH objective of an active quest is at `zone_id` (cheap pre-check).
static func has_reach_in(hero: Hero, quests: Dictionary, zone_id: StringName) -> bool:
	for key in hero.quest_state:
		var def: QuestDef = quests.get(StringName(key))
		if def == null or not is_active(hero, def.id):
			continue
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
			if def.objectives[i].kind != QuestObjective.Kind.COLLECT:
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
## in to it, "!" when it offers one, "" otherwise.
static func npc_marker(hero: Hero, quests: Dictionary, npc_id: StringName) -> String:
	var marker := ""
	for def in quests.values():
		var s := status(hero, def)
		if s == Status.READY and def.turn_in_npc() == npc_id:
			return "?"
		if s == Status.AVAILABLE and def.giver == npc_id:
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
			"active":
				var p = st.get("progress", [])
				var clean: Array = []
				for i in def.objectives.size():
					var v = p[i] if typeof(p) == TYPE_ARRAY and i < p.size() else 0
					var n := int(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else 0
					clean.append(clampi(n, 0, def.objectives[i].needed()))
				out[String(def.id)] = {"state": "active", "progress": clean, "ready": false}
	return out


static func _advance(hero: Hero, quests: Dictionary, matches: Callable) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for key in hero.quest_state.keys():
		var def: QuestDef = quests.get(StringName(key))
		if def == null or not is_active(hero, def.id):
			continue
		var p: Array = state_of(hero, def.id).progress
		for i in def.objectives.size():
			var o := def.objectives[i]
			if o.kind == QuestObjective.Kind.COLLECT or not matches.call(o):
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
