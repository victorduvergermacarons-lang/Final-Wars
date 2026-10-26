class_name WorldSim
extends RefCounted
## The authoritative game world. Runs on the host only, on a fixed tick.
##
## Input: intents from players, as plain Dictionaries, via submit():
##   {"type": "step", "to": Vector2i}         (also turns the hero that way; not while rooted)
##   {"type": "face", "dir": Vector2i}        (turn in place; free)
##   {"type": "cast", "ability": StringName, "target": int, "aim": Vector2 (optional)}
##       (target -1 = none/self; aim = tile coordinates for skillshots / ground)
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
##   {"type": "learn", "bag_index": int}   (a scroll into the learning slot) or
##   {"type": "learn", "slot": EquipSlot.Id}   (the worn weapon becomes the learning item)
##   {"type": "stop_learning"}
##   {"type": "debug", "line": String}   (debug console; only if debug_content is set)
##   {"type": "game_speed", "value": float}   (game clock speed, 0.1–2; same rule as debug)
##   {"type": "timing_press", "at": float}   (right-click on a timing bar: seconds since it started)
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
## Temporary enemies that died this tick, removed once it ends.
var _remove_after_tick: Array[int] = []


## Removes an actor at the end of this tick (not mid-tick: loops walk the actors).
func remove_after_tick(id: int) -> void:
	if not _remove_after_tick.has(id):
		_remove_after_tick.append(id)
var _npcs := {} # id -> Npc
var _intents: Array = [] # [hero_id, intent]
## Content lookup for the debug console; null (the default) refuses debug commands.
var debug_content = null
## One-time world events that have happened (e.g. a quest that changes the world).
## Saved by the host. Keys are event ids, values are true or small plain data.
var world_flags := {}
## Quest definitions (id -> QuestDef), shared by every zone.
var quests := {}
## Kill, talk and reach credit is shared with heroes this close (party = everyone).
const QUEST_SHARE_RADIUS := 15
var _projectiles: Array[Projectile] = []
## Telegraphed areas and lobbed shots waiting to land (CastResolver pending hits).
var _pending_hits: Array = []
## Temporary terrain changes: [{"delta": {tile: levels added}, "blocked": {tile: true}, "until"}].
var _terrain: Array = []
## Walkability of changed tiles before any change touched them.
var _terrain_base_walkable := {}
## Persistent ground zones: [{"source", "tiles", "ability", "zone_ability", "tick", "next_tick", "until", "bonus"}].
var _ground_zones: Array = []
## Loot that didn't fit in a hero's bag: {"id", "hero", "items": [[ItemDef, n]], "expires"}.
var _pending_loot: Array = []
var _next_loot_id := 1
const LOOT_WAIT_SECONDS := 60.0
var _next_projectile_id := 1
## Recent hero positions, for enemies' reaction delay: hero id -> [[time, tile], ...].
var _history := {}
const HISTORY_SECONDS := 2.0
var _acks := {} # hero id -> last processed intent "seq" (for client-side prediction)
## Heroes asking to walk off a map edge this tick: [[hero id, ZoneEdge], ...]; World moves them.
var _edge_requests: Array = []
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
		var enemy := add_enemy(spawn.enemy, spawn.tile)
		enemy.patrol = spawn.patrol.duplicate()
		enemy.respawn_seconds = spawn.respawn_seconds
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


## The edge of this zone that stepping in direction `dir` off the map leads through, or null.
func edge_for(dir: Vector2i) -> ZoneEdge:
	for e in zone.edges:
		if e != null and e.side == dir:
			return e
	return null


## Edge requests made since the last call (World handles them after each tick).
func take_edge_requests() -> Array:
	var out := _edge_requests
	_edge_requests = []
	return out


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


func remove_enemy(id: int) -> void:
	_enemies.erase(id)
	ctx.actors.erase(id)


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
	_update_casts()
	_update_projectiles()
	_update_pending_hits()
	_update_terrain_and_zones()
	_tick_heals_over_time()
	_update_combat_state()
	_expire_loot()
	for id in _remove_after_tick:
		remove_enemy(id)
	_remove_after_tick.clear()
	_regen()
	_update_quests()
	for id in _sorted(ctx.actors):
		ctx.actors[id].buffs.expire(now)
	_record_history()
	ctx.record_positions()
	return _events


## A tick for a sleeping zone (World: no heroes here for a while): the clock
## moves on and nothing else happens. Everything timed in sim time (respawns,
## buffs, ground zones, raised terrain) is due on the first real tick after.
func skip_tick() -> void:
	tick_count += 1
	now = tick_count * rules.tick_seconds
	ctx.now = now


## Where `actor` stood `delay` seconds ago (its current tile if no older record).
func perceived_tile(actor: Actor, delay: float) -> Vector2i:
	if delay <= 0.0 or not _history.has(actor.id):
		return actor.tile()
	return _perceived(actor, delay, 1, actor.tile())


## The way `actor` was facing `delay` seconds ago (enemies react to turns late too).
func perceived_facing(actor: Actor, delay: float) -> Vector2i:
	if delay <= 0.0 or not _history.has(actor.id):
		return actor.facing
	return _perceived(actor, delay, 2, actor.facing)


func _perceived(actor: Actor, delay: float, field: int, current: Vector2i) -> Vector2i:
	var when := now - delay
	var best := current
	var entries: Array = _history[actor.id]
	for i in range(entries.size() - 1, -1, -1):
		best = entries[i][field]
		if entries[i][0] <= when + Cooldowns.EPSILON:
			break
	return best


func _record_history() -> void:
	for hero in heroes():
		if not _history.has(hero.id):
			_history[hero.id] = []
		var entries: Array = _history[hero.id]
		entries.append([now, hero.tile(), hero.facing])
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
	if not can_move(actor, from, to):
		return "blocked"
	for t in actor.tiles(to):
		if is_occupied(t, actor):
			return "occupied"
	if actor.buffs.is_rooted(now):
		return "rooted"
	if actor.buffs.is_stunned(now):
		return "asleep" if actor.buffs.is_asleep(now) else "stunned"
	# An enemy that just aggroed is fighting even before the end-of-tick update.
	var in_combat := actor.in_combat(now) or (actor is Enemy and (actor as Enemy).state == Enemy.State.COMBAT)
	if not actor.move.can_start_step(in_combat, actor.cooldowns, now):
		return "not_ready"
	cancel_cast(actor, "moved") # moving cancels anything with a cast bar: cast, channel, wind-up
	if not actor is Hero:
		actor.face(to - from) # heroes face the mouse, not where they walk
	var step_cd := actor.combat_step_cooldown(rules, now) * actor.buffs.step_multiplier(now)
	if walk_seconds < 0.0:
		walk_seconds = rules.walk_tile_seconds
		# Animated creatures glide over their whole step in combat, so their run
		# cycle covers the ground it shows (no sliding feet).
		if in_combat and actor is Enemy and (actor as Enemy).def.art != null:
			walk_seconds = step_cd
	actor.move.begin(to, now, walk_seconds)
	if in_combat and not actor.buffs.use_free_step(now):
		actor.cooldowns.trigger_step(now, step_cd)
	if actor is Enemy and (actor as Enemy).state == Enemy.State.COMBAT and (actor as Enemy).def.trail_ability != null:
		_leave_trail(actor as Enemy, from)
	return ""


## A fighting enemy with a trail (Ember Trail) leaves it on the tile it just left.
func _leave_trail(enemy: Enemy, tile: Vector2i) -> void:
	var events: Array[Dictionary] = []
	AbilityResolver.apply_area_effects(ctx, enemy, enemy.def.trail_ability, [tile], events)
	_emit_resolved(events)


## Whether `actor` may step from `from` to the neighbouring `to` (terrain only):
## fliers fly, everyone else climbs within their Jump.
func can_move(actor: Actor, from: Vector2i, to: Vector2i) -> bool:
	for o in actor.footprint: # a large body: every tile it covers makes the step
		if actor is Enemy and (actor as Enemy).airborne(now):
			if not grid.can_fly(from + o, to + o, (actor as Enemy).fly_rise(now)):
				return false
		elif not grid.can_step(from + o, to + o, StatCalc.jump_levels(actor.current_stats(now))):
			return false
	return true


## A path for `actor` to `goal` by its own movement rules (see can_move).
## `arrived` (optional, tile -> bool): stop at the first tile it accepts instead.
func path_for(actor: Actor, goal: Vector2i, blocked: Dictionary, max_expanded: int = 4096,
		arrived := Callable()) -> Array[Vector2i]:
	var rise := (actor as Enemy).fly_rise(now) if actor is Enemy else -1
	return Pathfinder.find_path(grid, actor.tile(), goal, StatCalc.jump_levels(actor.current_stats(now)),
			blocked, -1, max_expanded, rise, actor.footprint if actor.is_large() else [], arrived)


## Resolves an ability and processes any deaths it caused.
## Uses an ability. `aim` (Vector2/Vector2i tile coordinates) is for Milestone 3
## skillshots and ground abilities; it defaults to the target's tile.
func cast(caster: Actor, ability: AbilityDef, target: Actor, aim: Variant = null) -> AbilityResolver.Result:
	if ability.targeting != AbilityDef.TargetingMode.LEGACY:
		return _cast_targeted(caster, ability, target, aim)
	var out := AbilityResolver.cast(ctx, caster, ability, target)
	_emit_resolved(out.events)
	if out.result == AbilityResolver.Result.OK and out.projectile == null:
		_credit_mastery(caster, ability, out.events)
	if out.projectile != null:
		var p: Projectile = out.projectile
		p.id = _next_projectile_id
		_next_projectile_id += 1
		_projectiles.append(p)
		emit({"type": "projectile", "projectile": p.to_dict()})
	return out.result


func _cast_targeted(caster: Actor, ability: AbilityDef, target: Actor, aim: Variant) -> AbilityResolver.Result:
	var timed := ability.cast_seconds > 0.0 or ability.windup_seconds > 0.0 or ability.channel_seconds > 0.0 \
			or _has_timing_bar(caster, ability)
	if timed:
		return _start_timed_cast(caster, ability, target, aim)
	return _finish_cast(caster, ability, target, aim, CastResolver.Pay.INSTANT)


## Only heroes play timing bars (enemies cast those abilities straight away).
static func _has_timing_bar(caster: Actor, ability: AbilityDef) -> bool:
	return caster is Hero and ability.timing_bar != null


## Starts a cast time, wind-up, channel or timing bar (see AbilityDef). Cast times
## and timing bars only take the GCD now; wind-ups and channels are paid up front.
func _start_timed_cast(caster: Actor, ability: AbilityDef, target: Actor, aim: Variant) -> AbilityResolver.Result:
	var r := CastResolver.validate(ctx, caster, ability, target, aim)
	if r != AbilityResolver.Result.OK:
		return r
	var kind := "cast" if ability.cast_seconds > 0.0 else ("windup" if ability.windup_seconds > 0.0 else "channel")
	var seconds: float = ability.cast_seconds if kind == "cast" else (ability.windup_seconds if kind == "windup" else ability.channel_seconds)
	if _has_timing_bar(caster, ability):
		kind = "timing"
		seconds = ability.timing_bar.seconds
	var point: Variant = CastResolver.aim_point(caster, target, aim)
	if point != null:
		CastResolver._face(caster, point)
	if kind == "cast" or kind == "timing":
		if ability.on_gcd:
			caster.cooldowns.trigger_gcd(now, rules.gcd_seconds * caster.buffs.cooldown_multiplier(now))
	else:
		AbilityResolver.pay(ctx, caster, ability)
	caster.casting = {"ability": ability, "target": target.id if target != null else -1, "aim": point,
			"kind": kind, "start": now, "end": now + seconds,
			"next_tick": now + (ability.channel_tick_seconds if kind == "channel" else seconds),
			"bonus": caster.buffs.damage_dealt_multiplier(ability.tree, now)}
	# A wound-up swipe or lob shows the tiles it will hit (dodge by leaving them).
	if kind == "windup" and ability.targeting == AbilityDef.TargetingMode.SKILLSHOT and point != null \
			and ability.projectile_speed <= 0.0:
		caster.casting.tiles = [CastResolver.lob_tile(caster.tile(), point, ability.max_range)] \
				if ability.arc_seconds > 0.0 else CastResolver.skillshot_tiles(ctx, caster, ability, point)
	# A wound-up charge (Searing Dive) shows its lane.
	if kind == "windup" and point != null:
		for e in ability.effects:
			if e.kind == AbilityEffect.Kind.CHARGE_THROUGH:
				caster.casting.tiles = AbilityResolver.charge_swept(caster, AbilityResolver.charge_lane(ctx, caster,
						TileGeometry.snap8(point - Vector2(caster.tile())), int(e.base_amount)))
	if kind != "cast" and kind != "timing":
		caster.buffs.consume_on_cast(ability.tree, now)
	emit({"type": "cast_start", "source": caster.id, "ability": ability.id, "kind": kind,
			"target": caster.casting.target, "end": caster.casting.end})
	return AbilityResolver.Result.OK


## Advances every cast in progress: finishes cast times and wind-ups, ticks
## channels, and cancels them when the caster is stunned or a Targeted target
## leaves range or line of sight.
func _update_casts() -> void:
	for id in _sorted(ctx.actors):
		var a: Actor = ctx.actors[id]
		var c: Dictionary = a.casting
		if c.is_empty():
			continue
		if not a.alive or a.buffs.is_stunned(now):
			cancel_cast(a, "stunned")
			continue
		var ability: AbilityDef = c.ability
		var target := get_actor(c.target)
		if c.kind != "windup" and ability.targeting == AbilityDef.TargetingMode.TARGETED and c.target != a.id \
				and CastResolver.validate(ctx, a, ability, target, c.aim, CastResolver.Pay.FREE) != AbilityResolver.Result.OK:
			cancel_cast(a, "target_lost")
			continue
		match c.kind:
			"cast":
				if now + 0.0001 >= c.end:
					a.casting = {}
					var r := _finish_cast(a, ability, target, c.aim, CastResolver.Pay.COMPLETE, c.bonus)
					if r != AbilityResolver.Result.OK:
						emit({"type": "cast_failed", "source": a.id, "ability": ability.id,
								"reason": AbilityResolver.Result.keys()[r].to_lower()})
			"windup":
				if now + 0.0001 >= c.end:
					a.casting = {}
					if a is Enemy and (a as Enemy).def.art != null:
						(a as Enemy).busy_until = now + (a as Enemy).def.art.recovery_for(ability.id)
					var r := _finish_cast(a, ability, target, c.aim, CastResolver.Pay.FREE, c.bonus)
					if r != AbilityResolver.Result.OK:
						emit({"type": "whiff", "source": a.id, "ability": ability.id, "tile": a.tile()})
			"timing":
				# No press came (or it was lost on the way): cast at miss power.
				if now + 0.0001 >= c.end + rules.timing_press_grace_seconds:
					_resolve_timing(a, -1.0)
			"channel":
				while not a.casting.is_empty() and now + 0.0001 >= c.next_tick and c.next_tick <= c.end + 0.0001:
					c.next_tick += ability.channel_tick_seconds
					_finish_cast(a, ability, target, c.aim, CastResolver.Pay.FREE, c.bonus)
				if not a.casting.is_empty() and now + 0.0001 >= c.end:
					a.casting = {}
					emit({"type": "channel_end", "source": a.id, "ability": ability.id})


## A right-click on the hero's timing bar, `at` seconds after it started as the
## player saw it (their screen runs a little behind the host, so the client
## measures it). It can't claim a moment the host hasn't reached yet (beyond a
## little clock slack).
func _intent_timing_press(hero: Hero, at: float) -> String:
	var c: Dictionary = hero.casting
	if c.is_empty() or c.kind != "timing":
		return "" # the bar already ended (cancelled, or no press in time): nothing to say
	_resolve_timing(hero, minf(at, now - float(c.start) + TIMING_CLOCK_SLACK))
	return ""


const TIMING_CLOCK_SLACK := 0.3


## Ends `caster`'s timing bar and casts its ability: full power on a green zone,
## full power and sure crits on a yellow one, rules.timing_miss_power otherwise
## (`at` < 0: no press). Mana and cooldown are paid now, like a cast time.
func _resolve_timing(caster: Actor, at: float) -> void:
	var c: Dictionary = caster.casting
	var ability: AbilityDef = c.ability
	caster.casting = {}
	var grade := ability.timing_bar.judge(at) if at >= 0.0 else TimingBarDef.Grade.MISS
	var power := rules.timing_miss_power if grade == TimingBarDef.Grade.MISS else 1.0
	emit({"type": "timing_result", "source": caster.id, "ability": ability.id,
			"grade": TimingBarDef.grade_name(grade), "at": at})
	ctx.force_crit = grade == TimingBarDef.Grade.PERFECT
	var r := _finish_cast(caster, ability, get_actor(c.target), c.aim, CastResolver.Pay.COMPLETE, c.bonus * power)
	ctx.force_crit = false
	if r != AbilityResolver.Result.OK:
		emit({"type": "cast_failed", "source": caster.id, "ability": ability.id,
				"reason": AbilityResolver.Result.keys()[r].to_lower()})


func cancel_cast(actor: Actor, reason: String) -> void:
	if actor.casting.is_empty():
		return
	emit({"type": "cast_cancel", "source": actor.id, "ability": actor.casting.ability.id, "reason": reason})
	actor.casting = {}


func _finish_cast(caster: Actor, ability: AbilityDef, target: Actor, aim: Variant, pay_mode: CastResolver.Pay,
		bonus: float = -1.0) -> AbilityResolver.Result:
	var out := CastResolver.cast(ctx, caster, ability, target, aim, pay_mode, bonus)
	_emit_resolved(out.events)
	if out.result != AbilityResolver.Result.OK:
		return out.result
	if out.projectile != null:
		var p: Projectile = out.projectile
		p.id = _next_projectile_id
		_next_projectile_id += 1
		_projectiles.append(p)
		emit({"type": "projectile", "projectile": p.to_dict()})
	elif out.pending != null:
		_pending_hits.append(out.pending)
	else:
		_credit_mastery(caster, ability, out.events)
	return out.result


## Telegraphed areas and lobbed shots in flight, as plain data for clients:
## [{"source", "ability", "tiles", "at"}].
func pending_hits() -> Array:
	var out := _pending_hits.map(func(h): return {"source": h.caster, "ability": h.ability.id,
			"tiles": h.tiles, "at": h.at})
	# Wind-ups aimed at the ground (Grizzlehide's Charge) or swipes (Crushing Blow,
	# Cleave) are telegraphed too.
	for id in _sorted(ctx.actors):
		var a: Actor = ctx.actors[id]
		var c: Dictionary = a.casting
		if c.is_empty() or c.kind != "windup":
			continue
		if c.has("tiles"):
			out.append({"source": a.id, "ability": c.ability.id, "tiles": c.tiles, "at": c.end})
		elif c.ability.targeting == AbilityDef.TargetingMode.GROUND and c.aim != null:
			var center := Vector2i(roundi(c.aim.x), roundi(c.aim.y))
			out.append({"source": a.id, "ability": c.ability.id,
					"tiles": CastResolver.area_tiles(grid, center, c.ability.area_radius, c.ability.area_diamond), "at": c.end})
	return out


func _update_pending_hits() -> void:
	var waiting: Array = []
	for h in _pending_hits:
		if now + 0.0001 < h.at:
			waiting.append(h)
			continue
		var caster := get_actor(h.caster)
		if caster == null:
			continue
		var events: Array[Dictionary] = []
		ctx.damage_bonus = h.bonus
		CastResolver.hit_tiles(ctx, caster, h.ability, h.tiles, h.grace, events)
		ctx.damage_bonus = 1.0
		_emit_resolved(events)
		_credit_mastery(caster, h.ability, events)
	_pending_hits = waiting


## Projectiles currently in flight.
func projectiles() -> Array[Projectile]:
	return _projectiles


## Per-use tree Mastery for a hero's ability use, judged from what it did:
## hitting an enemy near the hero's level, or healing/buffing while in combat.
func _credit_mastery(caster: Actor, ability: AbilityDef, events: Array) -> void:
	if not (caster is Hero) or not ability.is_tree_ability():
		return
	var hero := caster as Hero
	var levels: Array = []
	var helped := false
	for e in events:
		if e.get("source", -1) != hero.id:
			continue
		var t := get_actor(e.get("target", -1))
		if t is Enemy:
			if not (t as Enemy).def.training_dummy: # practice gives no Mastery
				levels.append((t as Enemy).level)
		elif t != null and e.type in ["heal", "buff", "shield"] and hero.in_combat(now):
			helped = true
	for e in TreeRules.on_use(hero, ability, levels, helped, rules):
		emit(e)


## Emits resolution events and handles any deaths among them, then whatever the
## resolution asked the world to do (terrain, ground zones, counters).
func _emit_resolved(events: Array) -> void:
	for event in events:
		emit(event)
		if event.type == "death":
			_on_death(get_actor(event.target))
	_handle_requests()


func _handle_requests() -> void:
	while not ctx.requests.is_empty():
		var r: Dictionary = ctx.requests.pop_front()
		match r.type:
			"terrain":
				_raise_terrain(r)
			"zone":
				_ground_zones.append({"source": r.source, "tiles": r.tiles, "ability": r.ability,
						"zone_ability": r.zone_ability, "tick": r.tick, "next_tick": now + r.tick,
						"until": r.until, "bonus": r.bonus})
				emit({"type": "zone", "source": r.source, "ability": r.ability.id, "tiles": r.tiles, "until": r.until})
			"counter":
				var owner := get_actor(r.owner)
				var attacker := get_actor(r.target)
				if owner != null and owner.alive and attacker != null and attacker.alive and r.ability != null:
					_finish_cast(owner, r.ability, attacker, null, CastResolver.Pay.FREE)


## Temporary terrain: raises (or lowers) tiles, optionally making them walls.
## Units on raised tiles ride up with them. Restored when it expires.
func _raise_terrain(r: Dictionary) -> void:
	var delta := {}
	var blocked := {}
	for t in r.tiles:
		if not grid.in_bounds(t):
			continue
		if not _terrain_base_walkable.has(t):
			_terrain_base_walkable[t] = grid.is_walkable(t)
		var h := grid.height_at(t)
		var new_h := maxi(h + int(r.levels), 0)
		delta[t] = new_h - h # what this change really added (lowering stops at 0)
		var walkable := grid.is_walkable(t)
		if r.blocks and not is_occupied(t):
			blocked[t] = true
			walkable = false
		grid.set_tile(t, new_h, walkable)
	if delta.is_empty():
		return
	_terrain.append({"delta": delta, "blocked": blocked, "until": r.until})
	emit({"type": "terrain", "source": r.source, "ability": r.ability, "tiles": delta.keys(), "levels": r.levels,
			"until": r.until})


## Each change expires on its own: its height is taken off again, so stacked
## pillars come down one by one and the ground ends where it started.
func _update_terrain_and_zones() -> void:
	var ended: Array = []
	for i in range(_terrain.size() - 1, -1, -1):
		if now + 0.0001 >= _terrain[i].until:
			ended.append(_terrain[i])
			_terrain.remove_at(i)
	for change in ended:
		for t in change.delta:
			var still_blocked := false
			var still_changed := false
			for other in _terrain:
				if other.delta.has(t):
					still_changed = true
					still_blocked = still_blocked or other.blocked.has(t)
			var walkable: bool = _terrain_base_walkable.get(t, true) and not still_blocked
			grid.set_tile(t, maxi(grid.height_at(t) - int(change.delta[t]), 0), walkable)
			if not still_changed:
				_terrain_base_walkable.erase(t)
		emit({"type": "terrain_end", "tiles": change.delta.keys()})
	var active: Array = []
	for z in _ground_zones:
		var owner := get_actor(z.source)
		while owner != null and now + 0.0001 >= z.next_tick and z.next_tick <= z.until + 0.0001:
			z.next_tick += z.tick
			var events: Array[Dictionary] = []
			ctx.damage_bonus = z.bonus
			for t in z.tiles:
				for a in CastResolver.actors_on(ctx, t, owner, z.zone_ability, 0.0):
					if a is Enemy and (a as Enemy).airborne(now):
						continue # fliers pass over burning ground
					AbilityResolver.apply_effects(ctx, owner, z.zone_ability, a, events)
			ctx.damage_bonus = 1.0
			_emit_resolved(events)
			_credit_mastery(owner, z.ability, events)
		if owner != null and now + 0.0001 < z.until:
			active.append(z)
	_ground_zones = active


## Tiles changed by abilities right now, for clients: [[tile, height, walkable]].
func changed_terrain() -> Array:
	var tiles := {}
	for change in _terrain:
		for t in change.delta:
			tiles[t] = true
	return tiles.keys().map(func(t): return [t, grid.height_at(t), grid.is_walkable(t)])


## Ground zones for clients: [{"source", "ability", "tiles", "until"}].
func ground_zones() -> Array:
	return _ground_zones.map(func(z): return {"source": z.source, "ability": z.ability.id, "tiles": z.tiles,
			"until": z.until})


## Moves every projectile along its path; the first affected actor on a tile it
## reaches takes the hit. Spent or blocked projectiles disappear.
func _update_projectiles() -> void:
	var flying: Array[Projectile] = []
	for p in _projectiles:
		var caster := get_actor(p.caster_id)
		if caster == null:
			continue
		if p.ability.targeting != AbilityDef.TargetingMode.LEGACY:
			if _fly_skillshot(p, caster):
				flying.append(p)
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
			_credit_mastery(caster, p.ability, events)
		elif p.is_spent(now):
			var end_tile := p.path[p.path.size() - 1] if not p.path.is_empty() else p.origin
			emit({"type": "projectile_end", "id": p.id, "tile": end_tile, "target": -1})
		else:
			flying.append(p)
	_projectiles = flying


## Moves a Milestone 3 projectile; returns whether it is still flying.
func _fly_skillshot(p: Projectile, caster: Actor) -> bool:
	var reached := p.tile_index_at(now)
	var events: Array[Dictionary] = []
	var stopped_at := -1
	for i in range(maxi(p.checked + 1, 0), reached + 1):
		for a in CastResolver.actors_on(ctx, p.path[i], caster, p.ability, rules.skillshot_grace_seconds):
			if p.hit_ids.has(a.id):
				continue
			p.hit_ids[a.id] = true
			ctx.damage_bonus = p.damage_bonus
			AbilityResolver.apply_effects(ctx, caster, p.ability, a, events)
			ctx.damage_bonus = 1.0
			if not p.pierce:
				stopped_at = i
				break
		if stopped_at >= 0:
			break
	p.checked = maxi(p.checked, reached if stopped_at < 0 else stopped_at)
	if not events.is_empty():
		_emit_resolved(events)
		_credit_mastery(caster, p.ability, events)
	if stopped_at >= 0:
		emit({"type": "projectile_end", "id": p.id, "tile": p.path[stopped_at], "target": events[0].get("target", -1)})
		return false
	if p.is_spent(now):
		emit({"type": "projectile_end", "id": p.id, "tile": p.path.back() if not p.path.is_empty() else p.origin, "target": -1})
		return false
	return true


func is_occupied(tile: Vector2i, ignore: Actor = null) -> bool:
	for id in ctx.actors:
		var a: Actor = ctx.actors[id]
		if a != ignore and a.alive and a.covers(tile):
			return true
	return false


## Whether anyone but `actor` stands on a tile its body would cover centred on `center`.
func body_blocked(actor: Actor, center: Vector2i) -> bool:
	for t in actor.tiles(center):
		if is_occupied(t, actor):
			return true
	return false


## Tiles holding living actors other than `ignore`, as a set for pathfinding.
func occupied_tiles(ignore: Actor = null) -> Dictionary:
	var out := {}
	for id in ctx.actors:
		var a: Actor = ctx.actors[id]
		if a != ignore and a.alive:
			for t in a.tiles():
				out[t] = true
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
			reason = _intent_cast(hero, intent.get("ability", &""), intent.get("target", -1), intent.get("aim"))
		"release":
			reason = _intent_release(hero)
		"timing_press":
			reason = _intent_timing_press(hero, intent.get("at", 0.0))
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
		"learn", "stop_learning":
			reason = _intent_learn(hero, kind, intent)
		"debug":
			if debug_content == null:
				reason = "debug_disabled"
			else:
				var r := DebugCommands.run(self, hero, intent.get("line", ""), debug_content)
				for e in r.events:
					emit(e)
				emit({"type": "debug", "target": hero.id, "ok": r.ok, "text": r.text})
		"game_speed":
			# A test setting, allowed when the debug console is (rules are shared by
			# every zone, so it changes every fight in the world).
			if debug_content == null:
				reason = "debug_disabled"
			else:
				rules.game_speed = clampf(intent.get("value", 1.0), CombatRules.GAME_SPEED_MIN,
						CombatRules.GAME_SPEED_MAX)
				emit({"type": "game_speed", "value": rules.game_speed})
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
	return _step_or_leave(hero, to)


## A step off the map leaves through that edge (if it leads somewhere).
func _step_or_leave(hero: Hero, to: Vector2i) -> String:
	if grid.in_bounds(to) or GridModel.distance(hero.tile(), to) != 1:
		return try_step(hero, to)
	var edge := edge_for(to - hero.tile())
	if edge == null:
		return "blocked"
	if hero.in_combat(now):
		return "in_combat"
	if hero.buffs.is_rooted(now):
		return "rooted"
	_edge_requests.append([hero.id, edge])
	return ""


## Turning is free and instant, in and out of combat. It also cancels a step
## buffered while walking, so a later step can't swing the hero back.
func _intent_face(hero: Hero, dir: Vector2i) -> String:
	if not hero.alive:
		return "dead"
	if not hero.face(dir):
		return "bad_direction"
	if hero.pending_step != null and hero.pending_step - hero.tile() != dir:
		hero.pending_step = null
	return ""


func _take_pending_step(hero: Hero) -> void:
	if hero.pending_step == null or not hero.alive:
		return
	if not hero.move.can_start_step(hero.in_combat(now), hero.cooldowns, now):
		return
	var to: Vector2i = hero.pending_step
	hero.pending_step = null
	var reason := _step_or_leave(hero, to)
	if reason != "":
		emit({"type": "rejected", "target": hero.id, "intent": "step", "reason": reason})


func _intent_cast(hero: Hero, ability_id: StringName, target_id: int, aim: Variant = null) -> String:
	var ability := hero.find_ability(ability_id)
	if ability == null:
		return "unknown_ability"
	var result := cast(hero, ability, get_actor(target_id), aim)
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
	if npc.def.resets_zone:
		reset_zone(hero.id)
	for h in _quest_sharers(hero, npc.tile()):
		for e in QuestLog.on_talk(h, quests, npc.def.id):
			emit(e)
	return ""


## Puts this zone back as it started (the testing map's Reset Shrine): every
## enemy at its spawn with full health (debug-spawned ones removed), and every
## lingering effect gone: casts, projectiles, telegraphs, ground zones, raised
## terrain, and buffs and debuffs on everyone. Heroes here leave combat.
func reset_zone(by: int = -1) -> void:
	_projectiles.clear()
	_pending_hits.clear()
	_ground_zones.clear()
	for change in _terrain:
		change.until = now # taken off at the end of this tick
	for id in _sorted(ctx.actors):
		var a: Actor = ctx.actors[id]
		a.casting = {}
		a.buffs.clear()
	for enemy in enemies():
		if enemy.temporary:
			remove_after_tick(enemy.id)
			continue
		enemy.reset_at_spawn()
		if is_occupied(enemy.spawn_tile, enemy):
			enemy.move.place(find_free_tile_near(enemy.spawn_tile))
		emit({"type": "respawn", "target": enemy.id})
	for hero in heroes():
		hero.combat_until = -1.0
	emit({"type": "zone_reset", "source": by})


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
		emit({"type": "world_flag", "flag": def.sets_world_flag, "text": def.world_flag_message})
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
	# A fresh start at the graveyard: out of combat, off every threat table.
	for enemy in enemies():
		enemy.threat.remove(hero.id)
	hero.combat_until = 0.0
	# Enemies react to where they saw you a moment ago: forget the death spot, or the
	# enemy that killed you "sees" you there and aggroes on your new self.
	_history.erase(hero.id)
	emit({"type": "release", "target": hero.id, "tile": hero.tile()})
	return ""


func _intent_learn(hero: Hero, kind: String, intent: Dictionary) -> String:
	if not hero.alive:
		return "dead"
	if hero.in_combat(now):
		return "in_combat"
	var reason := ""
	if kind == "stop_learning":
		reason = TreeRules.stop_learning(hero)
	elif intent.has("bag_index"):
		reason = TreeRules.learn_from_bag(hero, intent.bag_index)
	else:
		reason = TreeRules.learn_from_equipped(hero, intent.get("slot", -1))
	if reason == "":
		emit({"type": "learning", "target": hero.id,
				"item": hero.learning_item.id if hero.learning_item != null else &""})
	return reason


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
				var xp := share * Leveling.xp_level_multiplier(h.level, enemy.level, rules)
				for e in Leveling.add_xp(h, xp, rules):
					emit(e)
				for e in ApMastery.award(h, enemy.def.ap_reward):
					emit(e)
				_give_loot(h, Loot.roll(enemy.def.loot, ctx.rng, h, quests))
		enemy.threat.clear()
		enemy.died_at = now
		enemy.respawn_at = now + enemy.respawn_delay()
		if enemy.temporary:
			# Spawned enemies don't respawn: they go once their corpse has faded.
			enemy.respawn_at = now + (enemy.def.art.corpse_total() if enemy.def.art != null else 0.0)


## Heal-over-time and damage-over-time ticks.
func _tick_heals_over_time() -> void:
	for id in _sorted(ctx.actors):
		var a: Actor = ctx.actors[id]
		if not a.alive:
			continue
		for tick in a.buffs.due_ticks(now):
			if tick.damage:
				var src := get_actor(tick.source)
				var def := CombatMath.defense_for(tick.damage_type, a.current_stats(now), rules)
				var events: Array[Dictionary] = []
				AbilityResolver.deal_damage(ctx, src, a, tick.buff, CombatMath.final_damage(tick.amount, def.x, def.y, rules),
						false, events)
				_emit_resolved(events)
				if not a.alive:
					break
				continue
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
## Everyone an enemy is fighting stays in combat until the next tick re-checks
## (plus `combat_exit_seconds`, 0 by default: combat ends when the last enemy
## fighting you dies, evades or drops you).
func combat_until_from_now() -> float:
	return now + rules.combat_exit_seconds + rules.tick_seconds * 1.5


func _update_combat_state() -> void:
	var until := combat_until_from_now()
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
		mana_pct += a.buffs.mana_regen_percent(now)
		a.hp = minf(a.hp + s.hp * hp_pct / 100.0 * dt, s.hp)
		a.mana = minf(a.mana + s.mana * mana_pct / 100.0 * dt, s.mana)


func _take_id() -> int:
	return ids.next()


static func _sorted(d: Dictionary) -> Array:
	var ids := d.keys()
	ids.sort()
	return ids
