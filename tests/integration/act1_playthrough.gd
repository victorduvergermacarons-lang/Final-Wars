class_name Act1Playthrough
extends RefCounted
## Plays the Act I quests on the host World with the intents a client sends
## (accept, talk, examine, steps, turn in): one hero or a party. The first hero
## takes each quest at its giver; the others join through the co-op prompt.
## Fights are short-cut (the killing blow is dealt directly, with the whole party
## on the enemy's threat table, so XP, loot and quest credit go as in a real
## fight); enemies near an escort's path are moved out of the way for the walk
## and come back after. Used by tests/integration/test_act1_playthrough.gd.

## Every Act I quest, in the order the test plays them (1-07 last: the Silent
## Shaft, the dungeon, and the end of the act).
const ORDER := [&"act1_01_guild_comes_to_millbrook", &"act1_02_applicants_wanted",
		&"act1_03_wells_for_the_windsteppe", &"act1_side_the_white_death", &"act1_04_grain_for_deepcut",
		&"act1_side_shift_bell", &"act1_05_fever_in_millbrook", &"act1_06_recognition",
		&"act1_side_pins_on_the_map", &"act1_07_the_silent_shaft"]
const LOOP_LIMIT := 400

var db
var world: World
var party: Array[Hero] = []
## Why the last step failed ("" = fine), for the test's messages.
var problem := ""
## XP earned per quest by the first hero: [quest id, from kills, from the reward, level after, kills].
var log: Array = []
var kills := 0
## The last "act_complete" event (the last hero to hand in: the end-of-act screen's data).
var act_end := {}


func _init(p_db, size: int, seed: int = 11) -> void:
	db = p_db
	world = World.new(db.zones.values(), db.rules.duplicate(), seed, &"town", db.quests)
	# Dungeons need three; a smaller party plays with the testing setting.
	world.rules.dungeon_testing = size < world.rules.dungeon_min_party
	for i in size:
		party.append(world.add_saved_hero(CharacterData.new_character("Hero%d" % (i + 1), db.heroes[&"adventurer"]), db))


func leader() -> Hero:
	return party[0]


# --- Where things are ----------------------------------------------------------------

func zone_of_npc(npc_id: StringName) -> StringName:
	for zid in world.zone_ids():
		if npc(zid, npc_id) != null:
			return zid
	return &""


func npc(zone_id: StringName, npc_id: StringName) -> Npc:
	for n in world.zone(zone_id).npcs():
		if n.def.id == npc_id:
			return n
	return null


## A zone where `enemy_id` is placed (the first one found, sorted by id).
func zone_of_enemy(enemy_id: StringName) -> StringName:
	for zid in world.zone_ids():
		if world.zone(zid).enemies().any(func(e): return e.def.id == enemy_id and not e.temporary):
			return zid
	return &""


## Puts hero `h` on (or next to) `near` in zone `zone_id` (a dungeon: the party's
## copy, entered through its door as players do).
func place(h: Hero, zone_id: StringName, near: Vector2i) -> void:
	if world.is_dungeon(zone_id):
		zone_id = enter_dungeon(zone_id)
	if world.zone_of(h.id).key != zone_id:
		world.move_hero(h.id, zone_id, near)
	var sim := world.zone(zone_id)
	var free := not sim.is_occupied(near, h) and sim.grid.is_walkable(near)
	h.move.place(near if free else sim.find_free_tile_near(near))


## The whole party next to `near` (the first hero closest).
func gather(zone_id: StringName, near: Vector2i) -> void:
	for h in party:
		place(h, zone_id, near)


## Walks the whole party through the door of dungeon `def_id` (an exit tile in
## another zone) unless it is already inside; returns the party's copy's key.
func enter_dungeon(def_id: StringName) -> StringName:
	var key := world.instance_key(def_id, leader().id)
	for h in party:
		if world.zone_of(h.id).key == key:
			continue
		var door := _door_to(def_id)
		world.move_hero(h.id, door[0], world.zone(door[0]).find_free_tile_near(door[1] + Vector2i(0, 1)))
		world.step()
		h.move.place(door[1])
		var events := world.step()
		if world.zone_of(h.id).key != key:
			problem = "%s couldn't enter %s: %s" % [h.display_name, def_id,
					events.filter(func(e): return e.type == "rejected" and e.target == h.id)]
			return key
	return key


## [zone id, tile] of the exit that leads into `def_id`.
func _door_to(def_id: StringName) -> Array:
	for z in db.zones.values():
		for e in z.exits:
			if e.to_zone == def_id:
				return [z.id, e.tile]
	return [&"", Vector2i.ZERO]


func send(h: Hero, intent: Dictionary) -> Array[Dictionary]:
	world.submit(h.id, Intents.sanitize(intent))
	return world.step()


func talk(h: Hero, npc_id: StringName) -> Array[Dictionary]:
	var zid := zone_of_npc(npc_id)
	var n := npc(zid, npc_id)
	gather(zid, n.tile())
	return send(h, {"type": "talk", "npc": n.id})


# --- Playing a quest -------------------------------------------------------------------

## Plays quest `id` from accepting to handing in, for the whole party. False (and
## `problem`) if something along the way didn't work.
func play(id: StringName) -> bool:
	problem = ""
	var def: QuestDef = db.quests[id]
	var xp_before := _total_xp(leader())
	kills = 0
	for h in party:
		if QuestLog.status(h, def) != QuestLog.Status.AVAILABLE:
			return _fail("%s can't take %s: %s (level %d)" % [h.display_name, id, QuestLog.can_accept(h, def), h.level])
	# The first hero accepts at the giver; the others join through the prompt.
	var giver_zone := zone_of_npc(def.giver)
	var giver := npc(giver_zone, def.giver)
	gather(giver_zone, giver.tile())
	var events := send(leader(), {"type": "accept_quest", "npc": giver.id, "quest": id})
	act_end = {}
	for h in party.slice(1):
		if not events.any(func(e): return e.type == "quest_shared" and e.target == h.id):
			return _fail("%s wasn't offered %s" % [h.display_name, id])
		send(h, {"type": "accept_shared_quest", "quest": id})
	for h in party:
		if not QuestLog.is_active(h, id):
			return _fail("%s didn't get %s" % [h.display_name, id])
	for i in def.objectives.size():
		if not _objective(def, i):
			return false
		for h in party:
			if QuestLog.progress(h, def, i) < def.objectives[i].needed():
				return _fail("%s: objective %d (%s) not done for %s" % [id, i, def.objectives[i].text, h.display_name])
	var xp_mid := _total_xp(leader())
	var turn_zone := zone_of_npc(def.turn_in_npc())
	var turn_npc := npc(turn_zone, def.turn_in_npc())
	for h in party:
		_sell_loot(h)
		place(h, turn_zone, turn_npc.tile())
		var choice := 0 if not def.reward_choices.is_empty() else -1
		var done := send(h, {"type": "turn_in_quest", "npc": turn_npc.id, "quest": id, "choice": choice})
		for e in done:
			if e.type == "act_complete" and e.target == h.id: # the last hero's screen: everyone has handed in
				act_end = e
		if not QuestLog.is_done(h, id):
			var why := done.filter(func(e): return e.type == "rejected" and e.target == h.id)
			return _fail("%s couldn't hand in %s: %s" % [h.display_name, id, why])
	log.append([id, xp_mid - xp_before, _total_xp(leader()) - xp_mid, leader().level, kills])
	return true


func _objective(def: QuestDef, i: int) -> bool:
	var o := def.objectives[i]
	match o.kind:
		QuestObjective.Kind.KILL:
			var zid := zone_of_enemy(o.enemy)
			if zid != &"" and world.zone(zid).encounter != null \
					and world.zone(zid).encounter.def.heart.id == o.enemy:
				return _beat_boss(world.zone(zid))
			return _kill_until(o.enemy, func(): return _all_have(def, i))
		QuestObjective.Kind.COLLECT:
			var source := _dropper_of(o.item, def.id)
			if source == &"":
				return _fail("%s: nothing drops %s" % [def.id, o.item.id])
			return _kill_until(source, func(): return _all_have(def, i))
		QuestObjective.Kind.TALK, QuestObjective.Kind.INTERACT, QuestObjective.Kind.DELIVER:
			talk(leader(), o.npc)
		QuestObjective.Kind.INVESTIGATE:
			for s in o.spots:
				gather(o.zone, s + Vector2i(0, 1))
				place(leader(), o.zone, _beside(o.zone, s))
				send(leader(), {"type": "examine", "tile": s})
		QuestObjective.Kind.REACH:
			for h in party:
				place(h, o.zone, o.tile)
			world.step()
		QuestObjective.Kind.ESCORT:
			return _escort(def, o)
	return true


func _all_have(def: QuestDef, i: int) -> bool:
	return party.all(func(h): return QuestLog.progress(h, def, i) >= def.objectives[i].needed())


## A walkable free tile next to `tile` (examining needs to be within 1 tile).
func _beside(zone_id: StringName, tile: Vector2i) -> Vector2i:
	var sim := world.zone(zone_id)
	for d in GridModel.DIRECTIONS:
		var p: Vector2i = tile + d
		if sim.grid.is_walkable(p) and not sim.is_occupied(p, leader()):
			return p
	return tile


## The enemy type whose loot drops `item` for quest `quest_id`.
func _dropper_of(item: ItemDef, quest_id: StringName) -> StringName:
	for e in db.enemies.values():
		if e.loot != null and e.loot.entries.any(func(l): return l != null and l.item == item and l.quest_id == quest_id):
			return e.id
	return &""


## Kills enemies of type `enemy_id` (the party fighting each) until `done` holds.
func _kill_until(enemy_id: StringName, done: Callable) -> bool:
	var zid := zone_of_enemy(enemy_id)
	if zid == &"":
		return _fail("no %s anywhere" % enemy_id)
	var sim := world.zone(zid)
	for n in LOOP_LIMIT:
		if done.call():
			return true
		var target: Enemy = null
		for e in sim.enemies():
			if e.def.id == enemy_id and e.alive and not e.evading:
				target = e
				break
		if target == null:
			gather(zid, sim.zone.hero_spawns[0])
			world.advance(5.0) # wait for a respawn
			continue
		gather(zid, target.tile())
		world.step() # scaled for the party here
		for h in party:
			target.threat.add(h.id, 1.0)
		target.state = Enemy.State.COMBAT
		var hits: Array[Dictionary] = []
		AbilityResolver.deal_damage(sim.ctx, leader(), target, &"S01", 999999.0, false, hits)
		sim._emit_resolved(hits)
		kills += 1
		world.step()
	return _fail("gave up killing %s" % enemy_id)


## A boss encounter, short-cut like the other fights but through its phases: the
## party brings the boss down to each phase's threshold, then breaks the Heart
## once it opens (phase 3). The party is on both tables, so the kill counts for all.
func _beat_boss(sim: WorldSim) -> bool:
	var enc := sim.encounter
	var boss := enc.boss(sim)
	var heart := enc.heart(sim)
	gather(sim.key, boss.tile() + Vector2i(-3, 0))
	world.step()
	for h in party:
		boss.threat.add(h.id, 1.0)
	boss.state = Enemy.State.COMBAT
	world.step()
	for f in [enc.def.phase_at[0] - 0.01, enc.def.phase_at[1] - 0.01]:
		var hits: Array[Dictionary] = []
		AbilityResolver.deal_damage(sim.ctx, leader(), boss, &"S01", boss.hp - roundf(boss.stats.hp * f), false, hits)
		sim._emit_resolved(hits)
		world.step()
	if enc.phase != 3 or heart.invulnerable:
		return _fail("the boss stayed in phase %d" % enc.phase)
	for h in party:
		heart.threat.add(h.id, 1.0)
	var hits: Array[Dictionary] = []
	AbilityResolver.deal_damage(sim.ctx, leader(), heart, &"S01", heart.hp + 1.0, false, hits)
	sim._emit_resolved(hits)
	kills += 2
	world.step()
	if not enc.defeated:
		return _fail("the Heart didn't end the fight")
	return true


## Closes the end-of-act screen for every hero (the finish_act intent), as the
## button does; true when they are all back in `zone_id`.
func finish_act(quest_id: StringName, zone_id: StringName) -> bool:
	for h in party:
		world.submit(h.id, Intents.sanitize({"type": "finish_act", "quest": quest_id}))
	world.step()
	world.step()
	return party.all(func(h): return world.zone_of(h.id).key == zone_id)


## Starts the escort and walks the party beside it until it arrives. Enemies near
## its path step aside for the walk (the escort's dangers are tested elsewhere).
func _escort(def: QuestDef, o: QuestObjective) -> bool:
	var sim := world.zone(o.zone)
	var cart := npc(o.zone, o.npc)
	var moved := []
	for e in sim.enemies():
		var near := GridModel.distance(e.tile(), cart.tile()) <= 10
		for p in o.path:
			near = near or GridModel.distance(e.tile(), p) <= 10
		if near and e.alive:
			e.die()
			e.state = Enemy.State.DEAD
			e.respawn_at = 1.0e9
			moved.append(e)
	talk(leader(), o.npc)
	if not cart.escorting:
		return _fail("%s didn't set off" % o.npc)
	var arrived := false
	# The party follows on its trail, a few tiles behind (never in its way).
	var trail: Array[Vector2i] = [cart.tile()]
	for n in 4000:
		if cart.tile() != trail.back():
			trail.append(cart.tile())
		for k in party.size():
			var at: Vector2i = trail[maxi(trail.size() - 3 - k, 0)]
			if party[k].tile() != at:
				place(party[k], o.zone, at)
		if world.step().any(func(e): return e.type == "escort_arrived"):
			arrived = true
			break
	for e in moved:
		e.respawn_at = sim.now
	if not arrived:
		return _fail("%s stuck at %s" % [o.npc, cart.tile()])
	return true


## Sells what the party picked up along the way, so rewards always fit.
func _sell_loot(h: Hero) -> void:
	for i in h.bag.slots.size():
		var item := h.bag.item_at(i)
		# Junk (pelts, tusks, shards): not gear, not a scroll, not a potion, not for a quest.
		if item != null and not item.quest_item and item.use_ability == null and item.teaches.is_empty() \
				and item.slot == EquipSlot.Type.NONE:
			h.bag.remove_at(i, h.bag.count_at(i))


func _total_xp(h: Hero) -> float:
	var total := h.xp
	for l in range(1, h.level):
		total += Leveling.xp_to_next(l, db.rules)
	return total


func total_xp(h: Hero) -> float:
	return _total_xp(h)


func _fail(text: String) -> bool:
	problem = text
	return false
