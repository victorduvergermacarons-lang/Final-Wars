class_name WorldSim
extends RefCounted
## The authoritative game world. Runs on the host only, on a fixed tick.
##
## Input: intents from players, as plain Dictionaries, via submit():
##   {"type": "step", "to": Vector2i}         (also turns the hero that way)
##   {"type": "face", "dir": Vector2i}        (turn in place; free)
##   {"type": "cast", "ability": StringName, "target": int}   (target -1 = none/self)
##   {"type": "release"}
##   {"type": "equip", "item": StringName}
##   {"type": "unequip", "slot": EquipSlot.Id}
## Output: step() returns the tick's events (plain Dictionaries) for clients/UI.
## Invalid intents produce {"type": "rejected", "target": hero, "intent", "reason"}.

var zone: ZoneDef
var grid: GridModel
var rules: CombatRules
var ctx: CombatContext
var tick_count: int = 0
## Sim clock in seconds. Derived from the tick count so it never drifts.
var now: float = 0.0

var _next_id := 1
var _heroes := {} # id -> Hero
var _enemies := {} # id -> Enemy
var _intents: Array = [] # [hero_id, intent]
var _projectiles: Array[Projectile] = []
var _next_projectile_id := 1
## Recent hero positions, for enemies' reaction delay: hero id -> [[time, tile], ...].
var _history := {}
const HISTORY_SECONDS := 2.0
var _acks := {} # hero id -> last processed intent "seq" (for client-side prediction)
var _events: Array[Dictionary] = []


func _init(p_zone: ZoneDef, p_rules: CombatRules, rng_seed: int = 0) -> void:
	zone = p_zone
	rules = p_rules
	grid = GridModel.from_zone(zone)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	ctx = CombatContext.new(grid, rules, rng)
	for spawn in zone.enemy_spawns:
		add_enemy(spawn.enemy, spawn.tile)


# --- Actors -----------------------------------------------------------------

func add_hero(def: HeroDef) -> Hero:
	var hero := Hero.from_def(_take_id(), def)
	var spawns := zone.hero_spawns
	var want := spawns[_heroes.size() % spawns.size()] if not spawns.is_empty() else Vector2i.ZERO
	hero.move.place(find_free_tile_near(want))
	_heroes[hero.id] = hero
	ctx.add_actor(hero)
	return hero


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
	_update_combat_state()
	_regen()
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
func try_step(actor: Actor, to: Vector2i) -> String:
	if not actor.alive:
		return "dead"
	var from := actor.tile()
	if GridModel.distance(from, to) != 1:
		return "not_adjacent"
	if not grid.can_step(from, to, StatCalc.jump_levels(actor.current_stats(now))):
		return "blocked"
	if is_occupied(to, actor):
		return "occupied"
	var in_combat := actor.in_combat(now)
	if not actor.move.can_start_step(in_combat, actor.cooldowns, now):
		return "not_ready"
	actor.face(to - from)
	actor.move.begin(to, now, rules.walk_tile_seconds)
	if in_combat:
		actor.cooldowns.trigger_step(now, actor.combat_step_cooldown(rules, now))
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
		"equip":
			reason = _intent_equip(hero, intent.get("item", &""))
		"unequip":
			reason = _intent_unequip(hero, intent.get("slot", -1))
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


func _intent_equip(hero: Hero, item_id: StringName) -> String:
	if not hero.alive:
		return "dead"
	if hero.in_combat(now):
		return "in_combat"
	for item in hero.inventory:
		if item.id == item_id:
			hero.equip(item)
			emit({"type": "equip", "target": hero.id, "item": item.id})
			return ""
	return "unknown_item"


func _intent_unequip(hero: Hero, slot: int) -> String:
	if not hero.alive:
		return "dead"
	if hero.in_combat(now):
		return "in_combat"
	if slot < 0 or slot >= EquipSlot.COUNT:
		return "bad_slot"
	hero.unequip(slot as EquipSlot.Id)
	emit({"type": "unequip", "target": hero.id, "slot": slot})
	return ""


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
		if not earners.is_empty():
			var share := float(enemy.def.xp_reward) / earners.size()
			for h in earners:
				for e in Leveling.add_xp(h, share, rules):
					emit(e)
		enemy.threat.clear()
		enemy.respawn_at = now + enemy.def.respawn_seconds


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
	var id := _next_id
	_next_id += 1
	return id


static func _sorted(d: Dictionary) -> Array:
	var ids := d.keys()
	ids.sort()
	return ids
