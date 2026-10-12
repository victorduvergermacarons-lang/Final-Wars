class_name WorldSim
extends RefCounted
## The authoritative game world. Runs on the host only, on a fixed tick.
##
## Input: intents from players, as plain Dictionaries, via submit():
##   {"type": "step", "to": Vector2i}         (also turns the hero that way; not while rooted)
##   {"type": "face", "dir": Vector2i}        (turn in place; free)
##   {"type": "cast", "ability": StringName, "target": int}   (target -1 = none/self)
##   {"type": "release"}
##   {"type": "talk", "npc": int}            (within TALK_RANGE tiles)
##   {"type": "take_loot", "loot": int}      (loot that didn't fit in the bag)
##   {"type": "use_item", "bag_index": int}  (consumables, e.g. potions)
##   {"type": "buy", "npc": int, "item": StringName, "count": int}
##   {"type": "sell", "npc": int, "bag_index": int, "count": int}
##   {"type": "equip", "bag_index": int, "slot": EquipSlot.Id (optional)}
##   {"type": "unequip", "slot": EquipSlot.Id}   (into the bag)
##   {"type": "move_item", "from": int, "to": int}   (bag slots: swap or merge)
##   {"type": "split_item", "index": int, "count": int}
##   {"type": "destroy_item", "index": int}
##   {"type": "accept_quest", "npc": int, "quest": StringName}   (from its giver, within TALK_RANGE)
##   {"type": "turn_in_quest", "npc": int, "quest": StringName, "choice": int}   (choice: reward index or -1)
##   {"type": "abandon_quest", "quest": StringName}
## Output: step() returns the tick's events (plain Dictionaries) for clients/UI.
## Invalid intents produce {"type": "rejected", "target": hero, "intent", "reason"}.

var zone: ZoneDef
var grid: GridModel
var rules: CombatRules
var ctx: CombatContext
var tick_count: int = 0
## Sim clock in seconds. Derived from the tick count so it never drifts.
var now: float = 0.0

var ids: IdSource
var _heroes := {} # id -> Hero
var _enemies := {} # id -> Enemy
var _npcs := {} # id -> Npc
var _intents: Array = [] # [hero_id, intent]
## One-time world events that have happened (e.g. a quest that changes the world).
## Saved by the host. Keys are event ids, values are true or small plain data.
var world_flags := {}
## Quest definitions (id -> QuestDef), shared by every zone.
var quests := {}
## Kill, talk and reach credit is shared with heroes this close (party = everyone).
const QUEST_SHARE_RADIUS := 15
var _projectiles: Array[Projectile] = []
## Loot that didn't fit in a hero's bag: {"id", "hero", "items": [[ItemDef, n]], "expires"}.
var _pending_loot: Array = []
var _next_loot_id := 1
const LOOT_WAIT_SECONDS := 60.0
var _next_projectile_id := 1
## Recent hero positions, for enemies' reaction delay: hero id -> [[time, tile], ...].
var _history := {}
const HISTORY_SECONDS := 2.0
var _acks := {} # hero id -> last processed intent "seq" (for client-side prediction)
var _events: Array[Dictionary] = []


## `p_ids` is shared between the zones of a World; a lone zone makes its own.
func _init(p_zone: ZoneDef, p_rules: CombatRules, rng_seed: int = 0, p_ids: IdSource = null) -> void:
	ids = p_ids if p_ids != null else IdSource.new()
	zone = p_zone
	rules = p_rules
	grid = GridModel.from_zone(zone)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	ctx = CombatContext.new(grid, rules, rng)
	for spawn in zone.enemy_spawns:
		add_enemy(spawn.enemy, spawn.tile).patrol = spawn.patrol.duplicate()
	for spawn in zone.npcs:
		var npc := Npc.new(_take_id(), spawn.npc, spawn.tile)
		npc.face(spawn.facing)
		_npcs[npc.id] = npc
		ctx.add_actor(npc)


# --- Actors -----------------------------------------------------------------

func add_hero(def: HeroDef) -> Hero:
	var hero := Hero.from_def(_take_id(), def)
	_place_new_hero(hero)
	return hero


func _place_new_hero(hero: Hero) -> void:
	var spawns := zone.hero_spawns
	var want := spawns[_heroes.size() % spawns.size()] if not spawns.is_empty() else Vector2i.ZERO
	hero.move.place(find_free_tile_near(want))
	_heroes[hero.id] = hero
	ctx.add_actor(hero)


## Brings a saved character into the world (see CharacterData), at a hero spawn.
func add_saved_hero(data: Dictionary, content) -> Hero:
	var hero := CharacterData.restore(_take_id(), data, content)
	_place_new_hero(hero)
	return hero


## Takes a hero out of this zone (for moving it to another zone). Enemies forget
## it and it leaves combat; the Hero object itself is kept intact.
func transfer_out(hero_id: int) -> Hero:
	var hero: Hero = _heroes.get(hero_id)
	if hero == null:
		return null
	remove_hero(hero_id)
	hero.pending_step = null
	hero.combat_until = -1.0
	return hero


## Brings a hero in from another zone, at the free tile nearest `tile`.
func transfer_in(hero: Hero, tile: Vector2i, ack: int = 0) -> void:
	hero.move.place(find_free_tile_near(tile))
	_heroes[hero.id] = hero
	ctx.add_actor(hero)
	if ack > 0:
		_acks[hero.id] = ack


## The exit on `tile`, or null.
func exit_at(tile: Vector2i) -> ZoneExit:
	for e in zone.exits:
		if e.tile == tile:
			return e
	return null


func add_enemy(def: EnemyDef, tile: Vector2i) -> Enemy:
	var enemy := Enemy.new(_take_id(), def, tile)
	_enemies[enemy.id] = enemy
	ctx.add_actor(enemy)
	return enemy


func remove_hero(id: int) -> void:
	for enemy in enemies():
		enemy.threat.remove(id)
	_heroes.erase(id)
	_acks.erase(id)
	_history.erase(id)
	ctx.actors.erase(id)


func get_actor(id: int) -> Actor:
	return ctx.get_actor(id)


func heroes() -> Array[Hero]:
	var out: Array[Hero] = []
	for id in _sorted(_heroes):
		out.append(_heroes[id])
	return out


func npcs() -> Array[Npc]:
	var out: Array[Npc] = []
	for id in _sorted(_npcs):
		out.append(_npcs[id])
	return out


func enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for id in _sorted(_enemies):
		out.append(_enemies[id])
	return out


# --- Ticking ------------------------------------------------------------------

func submit(hero_id: int, intent: Dictionary) -> void:
	_intents.append([hero_id, intent])


## Advances one fixed tick and returns the events it produced.
func step() -> Array[Dictionary]:
	tick_count += 1
	now = tick_count * rules.tick_seconds
	ctx.now = now
	_events = []

	var intents := _intents
	_intents = []
	for entry in intents:
		_handle_intent(entry[0], entry[1])
	for hero in heroes():
		_take_pending_step(hero)
	for enemy in enemies():
		EnemyBrain.update(self, enemy)
	_update_projectiles()
	_tick_heals_over_time()
	_update_combat_state()
	_expire_loot()
	_regen()
	_update_quests()
	for id in _sorted(ctx.actors):
		ctx.actors[id].buffs.expire(now)
	_record_history()
	return _events


## Where `actor` stood `delay` seconds ago (its current tile if no older record).
func perceived_tile(actor: Actor, delay: float) -> Vector2i:
	if delay <= 0.0 or not _history.has(actor.id):
		return actor.tile()
	var when := now - delay
	var best := actor.tile()
	var entries: Array = _history[actor.id]
	for i in range(entries.size() - 1, -1, -1):
		best = entries[i][1]
		if entries[i][0] <= when + Cooldowns.EPSILON:
			break
	return best


func _record_history() -> void:
	for hero in heroes():
		if not _history.has(hero.id):
			_history[hero.id] = []
		var entries: Array = _history[hero.id]
		entries.append([now, hero.tile()])
		while not entries.is_empty() and entries[0][0] < now - HISTORY_SECONDS:
			entries.pop_front()


## Runs ticks until `seconds` of sim time have passed. Returns all events.
func advance(seconds: float) -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	var ticks := roundi(seconds / rules.tick_seconds)
	for i in ticks:
		all.append_array(step())
	return all


## Sequence number of the last intent processed for this hero (0 if none).
func intent_ack(hero_id: int) -> int:
	return _acks.get(hero_id, 0)


func emit(event: Dictionary) -> void:
	_events.append(event)


# --- Shared actions (used by intents and EnemyBrain) -----------------------------

## Starts a step if every rule allows it. Returns "" or a rejection reason.
## `walk_seconds` overrides the walk time (enemy patrols); < 0 = the rules' value.
func try_step(actor: Actor, to: Vector2i, walk_seconds: float = -1.0) -> String:
	if not actor.alive:
		return "dead"
	var from := actor.tile()
	if GridModel.distance(from, to) != 1:
		return "not_adjacent"
	if not grid.can_step(from, to, StatCalc.jump_levels(actor.current_stats(now))):
		return "blocked"
	if is_occupied(to, actor):
		return "occupied"
	if actor.buffs.is_rooted(now):
		return "rooted"
	var in_combat := actor.in_combat(now)
	if not actor.move.can_start_step(in_combat, actor.cooldowns, now):
		return "not_ready"
	actor.face(to - from)
	actor.move.begin(to, now, walk_seconds if walk_seconds >= 0.0 else rules.walk_tile_seconds)
	if in_combat:
		actor.cooldowns.trigger_step(now, actor.combat_step_cooldown(rules, now) * actor.buffs.step_multiplier(now))
	return ""


## Resolves an ability and processes any deaths it caused.
func cast(caster: Actor, ability: AbilityDef, target: Actor) -> AbilityResolver.Result:
	var out := AbilityResolver.cast(ctx, caster, ability, target)
	_emit_resolved(out.events)
	if out.projectile != null:
		var p: Projectile = out.projectile
		p.id = _next_projectile_id
		_next_projectile_id += 1
		_projectiles.append(p)
		emit({"type": "projectile", "projectile": p.to_dict()})
	return out.result


## Projectiles currently in flight.
func projectiles() -> Array[Projectile]:
	return _projectiles


## Emits resolution events and handles any deaths among them.
func _emit_resolved(events: Array) -> void:
	for event in events:
		emit(event)
		if event.type == "death":
			_on_death(get_actor(event.target))


## Moves every projectile along its path; the first affected actor on a tile it
## reaches takes the hit. Spent or blocked projectiles disappear.
func _update_projectiles() -> void:
	var flying: Array[Projectile] = []
	for p in _projectiles:
		var caster := get_actor(p.caster_id)
		if caster == null:
			continue
		var hit: Actor = null
		var reached := p.tile_index_at(now)
		for i in range(maxi(p.checked, 0), reached + 1):
			hit = AbilityShapes.actor_at(ctx, p.path[i], caster, p.ability)
			if hit != null:
				reached = i
				break
		p.checked = maxi(reached, p.checked)
		if hit != null:
			var events: Array[Dictionary] = []
			AbilityResolver.apply_effects(ctx, caster, p.ability, hit, events)
			emit({"type": "projectile_end", "id": p.id, "tile": hit.tile(), "target": hit.id})
			_emit_resolved(events)
		elif p.is_spent(now):
			var end_tile := p.path[p.path.size() - 1] if not p.path.is_empty() else p.origin
			emit({"type": "projectile_end", "id": p.id, "tile": end_tile, "target": -1})
		else:
			flying.append(p)
	_projectiles = flying


func is_occupied(tile: Vector2i, ignore: Actor = null) -> bool:
	for id in ctx.actors:
		var a: Actor = ctx.actors[id]
		if a != ignore and a.alive and a.tile() == tile:
			return true
	return false


## Tiles holding living actors other than `ignore`, as a set for pathfinding.
func occupied_tiles(ignore: Actor = null) -> Dictionary:
	var out := {}
	for id in ctx.actors:
		var a: Actor = ctx.actors[id]
		if a != ignore and a.alive:
			out[a.tile()] = true
	return out


## The walkable, unoccupied tile closest to `tile` (breadth-first, deterministic).
func find_free_tile_near(tile: Vector2i) -> Vector2i:
	var seen := {tile: true}
	var queue: Array[Vector2i] = [tile]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if grid.is_walkable(p) and not is_occupied(p):
			return p
		for dir in GridModel.DIRECTIONS:
			var n: Vector2i = p + dir
			if grid.in_bounds(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return tile


# --- Intents ------------------------------------------------------------------

func _handle_intent(hero_id: int, intent: Dictionary) -> void:
	var hero: Hero = _heroes.get(hero_id)
	var kind: String = intent.get("type", "")
	if hero == null:
		return
	if intent.has("seq"):
		_acks[hero_id] = maxi(_acks.get(hero_id, 0), int(intent.seq))
	var reason := ""
	match kind:
		"step":
			reason = _intent_step(hero, intent.get("to", hero.tile()))
		"face":
			reason = _intent_face(hero, intent.get("dir", Vector2i.ZERO))
		"cast":
			reason = _intent_cast(hero, intent.get("ability", &""), intent.get("target", -1))
		"release":
			reason = _intent_release(hero)
		"talk":
			reason = _intent_talk(hero, intent.get("npc", -1))
		"accept_quest":
			reason = _intent_accept_quest(hero, intent.get("npc", -1), intent.get("quest", &""))
		"turn_in_quest":
			reason = _intent_turn_in_quest(hero, intent.get("npc", -1), intent.get("quest", &""),
					intent.get("choice", -1))
		"abandon_quest":
			var def: QuestDef = quests.get(StringName(intent.get("quest", &"")))
			if def == null or not QuestLog.is_active(hero, def.id):
				reason = "no_quest"
			else:
				for e in QuestLog.abandon(hero, def):
					emit(e)
		"take_loot":
			reason = _intent_take_loot(hero, intent.get("loot", -1))
		"use_item":
			reason = _intent_use_item(hero, intent.get("bag_index", -1))
		"buy":
			reason = _intent_buy(hero, intent.get("npc", -1), intent.get("item", &""), intent.get("count", 1))
		"sell":
			reason = _intent_sell(hero, intent.get("npc", -1), intent.get("bag_index", -1), intent.get("count", 1))
		"equip":
			reason = _intent_equip(hero, intent.get("bag_index", -1), intent.get("slot", -1))
		"unequip":
			reason = _intent_unequip(hero, intent.get("slot", -1))
		"move_item":
			reason = "" if hero.bag.move(intent.get("from", -1), intent.get("to", -1)) else "cannot_move"
		"split_item":
			reason = "" if hero.bag.split(intent.get("index", -1), intent.get("count", 0)) else "cannot_split"
		"destroy_item":
			var index: int = intent.get("index", -1)
			var item := hero.bag.item_at(index)
			if item == null:
				reason = "empty"
			else:
				var n := hero.bag.remove_at(index, hero.bag.count_at(index))
				emit({"type": "destroy_item", "target": hero.id, "item": item.id, "count": n})
		_:
			reason = "unknown_intent"
	if reason != "":
		emit({"type": "rejected", "target": hero.id, "intent": kind, "reason": reason})


func _intent_step(hero: Hero, to: Vector2i) -> String:
	if not hero.alive:
		return "dead"
	# Still walking: buffer the step if it continues from where we're heading.
	if hero.move.is_moving(now) and GridModel.distance(hero.tile(), to) == 1:
		hero.pending_step = to
		return ""
	return try_step(hero, to)


## Turning is free and instant, in and out of combat.
func _intent_face(hero: Hero, dir: Vector2i) -> String:
	if not hero.alive:
		return "dead"
	return "" if hero.face(dir) else "bad_direction"


func _take_pending_step(hero: Hero) -> void:
	if hero.pending_step == null or not hero.alive:
		return
	if not hero.move.can_start_step(hero.in_combat(now), hero.cooldowns, now):
		return
	var to: Vector2i = hero.pending_step
	hero.pending_step = null
	var reason := try_step(hero, to)
	if reason != "":
		emit({"type": "rejected", "target": hero.id, "intent": "step", "reason": reason})


func _intent_cast(hero: Hero, ability_id: StringName, target_id: int) -> String:
	var ability := hero.find_ability(ability_id)
	if ability == null:
		return "unknown_ability"
	var result := cast(hero, ability, get_actor(target_id))
	if result != AbilityResolver.Result.OK:
		return AbilityResolver.Result.keys()[result].to_lower()
	return ""


const TALK_RANGE := 2


func _intent_talk(hero: Hero, npc_id: int) -> String:
	if not hero.alive:
		return "dead"
	var npc: Npc = _npcs.get(npc_id)
	if npc == null:
		return "no_npc"
	if GridModel.distance(hero.tile(), npc.tile()) > TALK_RANGE:
		return "too_far"
	emit({"type": "dialogue", "target": hero.id, "npc": npc.id, "def": npc.def.id})
	for h in _quest_sharers(hero, npc.tile()):
		for e in QuestLog.on_talk(h, quests, npc.def.id):
			emit(e)
	return ""


func _intent_accept_quest(hero: Hero, npc_id: int, quest_id: StringName) -> String:
	var def: QuestDef = quests.get(quest_id)
	if def == null:
		return "no_quest"
	var reason := _check_quest_npc(hero, npc_id, def.giver)
	if reason == "":
		reason = QuestLog.can_accept(hero, def)
	if reason != "":
		return reason
	for e in QuestLog.accept(hero, def):
		emit(e)
	return ""


func _intent_turn_in_quest(hero: Hero, npc_id: int, quest_id: StringName, choice: int) -> String:
	var def: QuestDef = quests.get(quest_id)
	if def == null:
		return "no_quest"
	var reason := _check_quest_npc(hero, npc_id, def.turn_in_npc())
	if reason != "":
		return reason
	var out := QuestLog.turn_in(hero, def, choice, rules)
	if out.reason != "":
		return out.reason
	for e in out.events:
		emit(e)
	if def.sets_world_flag != &"" and not world_flags.has(String(def.sets_world_flag)):
		world_flags[String(def.sets_world_flag)] = true
		emit({"type": "world_flag", "flag": def.sets_world_flag})
	return ""


## "" if `hero` is alive and within talking range of NPC actor `npc_id`, whose type is `npc_def_id`.
func _check_quest_npc(hero: Hero, npc_id: int, npc_def_id: StringName) -> String:
	if not hero.alive:
		return "dead"
	var npc: Npc = _npcs.get(npc_id)
	if npc == null or npc.def.id != npc_def_id:
		return "wrong_npc"
	if GridModel.distance(hero.tile(), npc.tile()) > TALK_RANGE:
		return "too_far"
	return ""


## `hero` plus every other hero in this zone within QUEST_SHARE_RADIUS of `at`.
func _quest_sharers(hero: Hero, at: Vector2i) -> Array[Hero]:
	var out: Array[Hero] = [hero]
	for h in heroes():
		if h != hero and GridModel.distance(h.tile(), at) <= QUEST_SHARE_RADIUS:
			out.append(h)
	return out


## REACH objectives (shared with nearby heroes) and COLLECT counts / ready flags.
func _update_quests() -> void:
	if quests.is_empty():
		return
	for hero in heroes():
		if hero.alive and QuestLog.has_reach_in(hero, quests, zone.id):
			for h in _quest_sharers(hero, hero.tile()):
				for e in QuestLog.on_reach(h, quests, zone.id, hero.tile()):
					emit(e)
	for hero in heroes():
		for e in QuestLog.refresh(hero, quests):
			emit(e)


## Uses one of a consumable: its ability is cast on the hero (cooldown and GCD
## rules apply as for any ability); the item is used up only if that worked.
func _intent_use_item(hero: Hero, bag_index: int) -> String:
	var item := hero.bag.item_at(bag_index)
	if item == null:
		return "empty"
	if item.use_ability == null:
		return "not_usable"
	var result := cast(hero, item.use_ability, hero)
	if result != AbilityResolver.Result.OK:
		return AbilityResolver.Result.keys()[result].to_lower()
	hero.bag.remove_at(bag_index, 1)
	emit({"type": "use_item", "target": hero.id, "item": item.id})
	return ""


func _vendor(hero: Hero, npc_id: int) -> Npc:
	var npc: Npc = _npcs.get(npc_id)
	if npc == null or npc.def.sells.is_empty() or GridModel.distance(hero.tile(), npc.tile()) > TALK_RANGE + 1:
		return null
	return npc


func _intent_buy(hero: Hero, npc_id: int, item_id: StringName, count: int) -> String:
	if not hero.alive:
		return "dead"
	var npc := _vendor(hero, npc_id)
	if npc == null:
		return "too_far"
	var item: ItemDef = null
	for it in npc.def.sells:
		if it.id == item_id:
			item = it
	if item == null:
		return "not_sold_here"
	count = clampi(count, 1, item.max_stack)
	var cost := item.price * count
	if hero.gold < cost:
		return "not_enough_gold"
	if hero.bag.room_for(item) < count:
		return "bag_full"
	hero.gold -= cost
	hero.bag.add(item, count)
	emit({"type": "buy", "target": hero.id, "item": item.id, "count": count, "gold": cost})
	return ""


func _intent_sell(hero: Hero, npc_id: int, bag_index: int, count: int) -> String:
	if not hero.alive:
		return "dead"
	if _vendor(hero, npc_id) == null:
		return "too_far"
	var item := hero.bag.item_at(bag_index)
	if item == null:
		return "empty"
	if item.price <= 0:
		return "cant_sell"
	var n := hero.bag.remove_at(bag_index, clampi(count, 1, hero.bag.count_at(bag_index)))
	var paid := floori(item.price * rules.vendor_sell_fraction) * n
	hero.gold = mini(hero.gold + paid, CharacterData.MAX_GOLD)
	emit({"type": "sell", "target": hero.id, "item": item.id, "count": n, "gold": paid})
	return ""


func _intent_release(hero: Hero) -> String:
	if hero.alive:
		return "not_dead"
	var near := hero.death_tile
	var best := near
	var best_dist := -1
	var points := zone.graveyards if not zone.graveyards.is_empty() else zone.hero_spawns
	for p in points:
		var d := GridModel.distance(near, p)
		if best_dist < 0 or d < best_dist:
			best = p
			best_dist = d
	var stats := hero.current_stats(now)
	hero.alive = true
	hero.hp = maxf(roundf(stats.hp * rules.release_fraction), 1.0)
	hero.mana = roundf(stats.mana * rules.release_fraction)
	hero.move.place(find_free_tile_near(best))
	emit({"type": "release", "target": hero.id, "tile": hero.tile()})
	return ""


func _intent_equip(hero: Hero, bag_index: int, slot: int = -1) -> String:
	if not hero.alive:
		return "dead"
	if hero.in_combat(now):
		return "in_combat"
	var item := hero.bag.item_at(bag_index)
	var reason := hero.equip_from_bag(bag_index, slot)
	if reason == "":
		emit({"type": "equip", "target": hero.id, "item": item.id})
	return reason


func _intent_unequip(hero: Hero, slot: int) -> String:
	if not hero.alive:
		return "dead"
	if hero.in_combat(now):
		return "in_combat"
	if slot < 0 or slot >= EquipSlot.COUNT:
		return "bad_slot"
	var reason := hero.unequip_to_bag(slot)
	if reason == "":
		emit({"type": "unequip", "target": hero.id, "slot": slot})
	return reason


# --- Rules applied every tick -----------------------------------------------

func _on_death(actor: Actor) -> void:
	if actor is Hero:
		for enemy in enemies():
			enemy.threat.remove(actor.id)
	elif actor is Enemy:
		var enemy := actor as Enemy
		var earners: Array[Hero] = []
		for id in enemy.threat.ids():
			var h: Hero = _heroes.get(id)
			if h != null and h.alive:
				earners.append(h)
		for h in heroes():
			if earners.has(h) or GridModel.distance(h.tile(), enemy.tile()) <= QUEST_SHARE_RADIUS:
				for e in QuestLog.on_kill(h, quests, enemy.def.id):
					emit(e)
		if not earners.is_empty():
			var share := float(enemy.def.xp_reward) / earners.size()
			for h in earners:
				emit({"type": "kill", "target": h.id, "enemy": enemy.def.id})
				var xp := share * Leveling.xp_level_multiplier(h.level, enemy.def.level, rules)
				for e in Leveling.add_xp(h, xp, rules):
					emit(e)
				for e in ApMastery.award(h, enemy.def.ap_reward):
					emit(e)
				_give_loot(h, Loot.roll(enemy.def.loot, ctx.rng, h, quests))
		enemy.threat.clear()
		enemy.respawn_at = now + enemy.def.respawn_seconds


func _tick_heals_over_time() -> void:
	for id in _sorted(ctx.actors):
		var a: Actor = ctx.actors[id]
		if not a.alive:
			continue
		for tick in a.buffs.due_heals(now):
			var max_hp := a.current_stats(now).hp
			var healed := clampf(roundf(tick.amount), 0.0, maxf(max_hp - a.hp, 0.0))
			a.hp += healed
			emit({"type": "heal", "source": tick.source, "target": a.id, "ability": tick.buff,
					"amount": healed, "crit": false})


## Gold and items straight into the hero's bag; what doesn't fit waits 60 s.
func _give_loot(hero: Hero, roll: Dictionary) -> void:
	if roll.gold <= 0 and roll.items.is_empty():
		return
	hero.gold = mini(hero.gold + roll.gold, CharacterData.MAX_GOLD)
	var leftover: Array = []
	for pair in roll.items:
		var left := hero.bag.add(pair[0], pair[1])
		if left > 0:
			leftover.append([pair[0], left])
	var loot_id := -1
	if not leftover.is_empty():
		loot_id = _next_loot_id
		_next_loot_id += 1
		_pending_loot.append({"id": loot_id, "hero": hero.id, "items": leftover,
				"expires": now + LOOT_WAIT_SECONDS})
	emit({"type": "loot", "target": hero.id, "gold": roll.gold,
			"items": Loot.items_to_array(roll.items), "left": loot_id})


## Waiting loot for one hero, as plain data: [{"id", "items": [[id, n]], "expires"}].
func pending_loot_for(hero_id: int) -> Array:
	var out: Array = []
	for p in _pending_loot:
		if p.hero == hero_id:
			out.append({"id": p.id, "items": Loot.items_to_array(p.items), "expires": p.expires})
	return out


func _intent_take_loot(hero: Hero, loot_id: int) -> String:
	for p in _pending_loot:
		if p.id != loot_id or p.hero != hero.id:
			continue
		var still: Array = []
		for pair in p.items:
			var left := hero.bag.add(pair[0], pair[1])
			if left > 0:
				still.append([pair[0], left])
		p.items = still
		if still.is_empty():
			_pending_loot.erase(p)
			return ""
		return "bag_full"
	return "no_loot"


func _expire_loot() -> void:
	_pending_loot = _pending_loot.filter(func(p): return p.expires > now)


## Everyone on a fighting enemy's threat table (and the enemy) is in combat.
func _update_combat_state() -> void:
	var until := now + rules.combat_exit_seconds
	for enemy in enemies():
		if enemy.state != Enemy.State.COMBAT or not enemy.alive:
			continue
		enemy.combat_until = until
		for id in enemy.threat.ids():
			var a := get_actor(id)
			if a != null and a.alive:
				a.combat_until = until


func _regen() -> void:
	var dt := rules.tick_seconds
	for id in _sorted(ctx.actors):
		var a: Actor = ctx.actors[id]
		if not a.alive:
			continue
		var s := a.current_stats(now)
		var fighting := a.in_combat(now)
		var hp_pct := rules.in_combat_hp_regen_percent if fighting else rules.out_of_combat_hp_regen_percent
		var mana_pct := rules.in_combat_mana_regen_percent if fighting else rules.out_of_combat_mana_regen_percent
		a.hp = minf(a.hp + s.hp * hp_pct / 100.0 * dt, s.hp)
		a.mana = minf(a.mana + s.mana * mana_pct / 100.0 * dt, s.mana)


func _take_id() -> int:
	return ids.next()


static func _sorted(d: Dictionary) -> Array:
	var ids := d.keys()
	ids.sort()
	return ids
