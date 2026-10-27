class_name BalanceSim
extends RefCounted
## Scripted fights on the real WorldSim with shipped content, for tuning.
## A bot hero turns toward the nearest wolf, uses abilities in priority order,
## heals below a threshold if it can, and never moves (wolves come to it).

## Runs one fight and returns {"seconds", "hp_lost_pct" (worst hero), "won", "mana_left_pct"}.
## `loadouts`: per hero, item ids to equip. `rotation`: ability ids in priority order.
## `wolves` enemies of type `enemy_id` (Wolf by default); heroes start at `hero_level`
## with the growth of their gear.
static func fight(content, loadouts: Array, rotation: Array, wolves: int, seed: int = 1,
		heal_below: float = 0.0, block_first: bool = false, enemy_id: StringName = &"wolf",
		hero_level: int = 1) -> Dictionary:
	var zone := ZoneDef.new()
	zone.id = &"arena"
	var rows: PackedStringArray = []
	var walk: PackedStringArray = []
	for y in 12:
		rows.append("0".repeat(12))
		walk.append(".".repeat(12))
	zone.height_rows = rows
	zone.walk_rows = walk
	zone.graveyards = [Vector2i(0, 0)]
	zone.hero_spawns = [Vector2i(3, 5), Vector2i(3, 7), Vector2i(2, 6), Vector2i(3, 9)]
	var spawns: Array[EnemySpawn] = []
	for i in wolves:
		var s := EnemySpawn.new()
		s.enemy = content.enemies[enemy_id]
		s.tile = Vector2i(6, 5 + i * 2)
		spawns.append(s)
	zone.enemy_spawns = spawns
	var world := WorldSim.new(zone, content.rules, seed)
	var heroes: Array[Hero] = []
	for items in loadouts:
		var h := world.add_hero(content.heroes[&"adventurer"])
		for slot in EquipSlot.COUNT:
			h.unequip(slot)
		for id in items:
			h.wear(content.items[id])
		while h.level < hero_level:
			Leveling.add_xp(h, Leveling.xp_to_next(h.level, content.rules), content.rules)
		h.hp = h.stats.hp
		h.mana = h.stats.mana
		heroes.append(h)
	# Pull everything: first hero hits each wolf's threat table.
	for e in world.enemies():
		e.threat.add(heroes[0].id, 1.0)
	var t := 0.0
	var min_hp_frac := 1.0
	var blocked := false
	while t < 120.0:
		var alive_wolves := world.enemies().filter(func(e): return e.alive)
		if alive_wolves.is_empty():
			break
		if heroes.all(func(h): return not h.alive):
			break
		for h in heroes:
			if not h.alive:
				continue
			if block_first and not blocked and h.find_ability(&"block") != null:
				world.submit(h.id, {"type": "cast", "ability": &"block", "target": h.id})
			var target: Enemy = alive_wolves[0]
			for e in alive_wolves:
				if GridModel.distance(h.tile(), e.tile()) < GridModel.distance(h.tile(), target.tile()):
					target = e
			var delta: Vector2i = target.tile() - h.tile()
			var face := Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
			if face != Vector2i.ZERO and face != h.facing:
				world.submit(h.id, {"type": "face", "dir": face})
			var hurt := heroes.filter(func(x): return x.alive and x.hp < x.stats.hp * heal_below)
			if not hurt.is_empty() and h.find_ability(&"heal") != null:
				world.submit(h.id, {"type": "cast", "ability": &"heal", "target": hurt[0].id})
			for id in rotation:
				if h.find_ability(id) != null:
					world.submit(h.id, {"type": "cast", "ability": id, "target": target.id})
		world.step()
		t = world.now
		for h in heroes:
			min_hp_frac = minf(min_hp_frac, h.hp / h.stats.hp)
	var won := world.enemies().all(func(e): return not e.alive)
	var mana := 1.0
	for h in heroes:
		mana = minf(mana, h.mana / maxf(h.stats.mana, 1.0))
	return {"seconds": snappedf(t, 0.05), "hp_lost_pct": roundi((1.0 - min_hp_frac) * 100), "won": won,
			"mana_left_pct": roundi(mana * 100)}


## Average over several seeds.
static func average(content, loadouts: Array, rotation: Array, wolves: int, runs: int = 10,
		heal_below: float = 0.0, block_first: bool = false, enemy_id: StringName = &"wolf",
		hero_level: int = 1) -> Dictionary:
	var secs := 0.0
	var lost := 0.0
	var wins := 0
	var mana := 0.0
	for i in runs:
		var r := fight(content, loadouts, rotation, wolves, i + 1, heal_below, block_first, enemy_id, hero_level)
		secs += r.seconds
		lost += r.hp_lost_pct
		mana += r.mana_left_pct
		wins += 1 if r.won else 0
	return {"seconds": snappedf(secs / runs, 0.1), "hp_lost_pct": roundi(lost / runs),
			"win_rate": float(wins) / runs, "mana_left_pct": roundi(mana / runs)}


## Milestone 3: a fight with ability-tree heroes. Each hero spec is a Dictionary:
##   "weapon": item id held (or ""), "armor": [item ids], "learning": scroll id put
##   in the learning slot, "mastered": [ability ids], "rotation": [ability ids] in
##   priority order, "heal": ability id cast on the most hurt ally below
##   "heal_below" (fraction of max HP), "mastery": {tree: permanent Mastery},
##   "dodge": steps away from enemy wind-ups aimed at it.
## The bot turns to the nearest enemy, steps toward it only when nothing in its
## rotation reaches, and aims skillshots and ground abilities at it (it never
## dodges). Returns like fight().
static func tree_fight(content, specs: Array, enemy_id: StringName, count: int, seed: int = 1,
		hero_level: int = 1) -> Dictionary:
	var zone := ZoneDef.new()
	zone.id = &"arena"
	var rows: PackedStringArray = []
	var walk: PackedStringArray = []
	for y in 14:
		rows.append("0".repeat(14))
		walk.append(".".repeat(14))
	zone.height_rows = rows
	zone.walk_rows = walk
	zone.graveyards = [Vector2i(0, 0)]
	zone.hero_spawns = [Vector2i(3, 5), Vector2i(3, 7), Vector2i(2, 6), Vector2i(3, 9)]
	var spawns: Array[EnemySpawn] = []
	for i in count:
		var s := EnemySpawn.new()
		s.enemy = content.enemies[enemy_id]
		s.tile = Vector2i(7, 5 + i * 2)
		spawns.append(s)
	zone.enemy_spawns = spawns
	var world := WorldSim.new(zone, content.rules, seed)
	var heroes: Array[Hero] = []
	for spec in specs:
		heroes.append(make_bot(world, content, spec, hero_level))
	for e in world.enemies():
		e.threat.add(heroes[0].id, 1.0)
	var t := 0.0
	var min_hp_frac := 1.0
	while t < 180.0:
		var foes := world.enemies().filter(func(e): return e.alive and not e.evading)
		if foes.is_empty() or heroes.all(func(h): return not h.alive):
			break
		bot_turn(world, content, heroes, specs, foes)
		world.step()
		t = world.now
		for h in heroes:
			min_hp_frac = minf(min_hp_frac, h.hp / h.stats.hp)
	var won := world.enemies().all(func(e): return not e.alive)
	var mana := 1.0
	for h in heroes:
		mana = minf(mana, h.mana / maxf(h.stats.mana, 1.0))
	return {"seconds": snappedf(t, 0.05), "hp_lost_pct": roundi((1.0 - min_hp_frac) * 100), "won": won,
			"mana_left_pct": roundi(mana * 100)}


## The Silent Shaft's boss (the Foreman and the Grey Heart) in its real chamber,
## with its encounter: the bots fight the Foreman, and the Heart once it opens in
## phase 3, killing any add that reaches them first (before phase 3). Won when the Heart breaks; lost at the
## first party wipe. Returns like tree_fight(), plus "phase" (the furthest reached).
static func boss_fight(content, specs: Array, seed: int = 1, hero_level: int = 10) -> Dictionary:
	var world := WorldSim.new(content.zones[&"silent_shaft"], content.rules, seed)
	var heroes: Array[Hero] = []
	for i in specs.size():
		var h := make_bot(world, content, specs[i], hero_level)
		h.move.place(world.find_free_tile_near(Vector2i(52, 13 + i * 2)))
		heroes.append(h)
	world.step() # scaled for the party
	var enc := world.encounter
	enc.boss(world).threat.add(heroes[0].id, 300.0) # the tank (first) pulls and holds a lead
	enc.boss(world).state = Enemy.State.COMBAT
	var t := world.now
	var start := t
	var min_hp_frac := 1.0
	var phase := 1
	while t - start < 300.0 and not enc.defeated:
		if heroes.all(func(h): return not h.alive):
			break
		var heart := enc.heart(world)
		# Adds first (as players would), then the Heart once it opens, else the Foreman.
		var focus: Enemy = heart if enc.phase == 3 and heart.alive else enc.boss(world)
		for e in world.enemies():
			if enc.phase < 3 and e.temporary and e.alive and heroes.any(func(h): return h.alive and TileGeometry.distance(h.tile(), e.tile()) <= 2):
				focus = e # an add that has reached the party
				break
		var foes := world.enemies().filter(func(e): return e.alive and not e.evading and e.state == Enemy.State.COMBAT)
		bot_turn(world, content, heroes, specs, foes, focus, true)
		world.step()
		t = world.now
		phase = maxi(phase, enc.phase)
		for h in heroes:
			min_hp_frac = minf(min_hp_frac, h.hp / h.stats.hp)
	var mana := 1.0
	for h in heroes:
		mana = minf(mana, h.mana / maxf(h.stats.mana, 1.0))
	return {"seconds": snappedf(t - start, 0.05), "hp_lost_pct": roundi((1.0 - min_hp_frac) * 100),
			"won": enc.defeated, "mana_left_pct": roundi(mana * 100), "phase": phase}


static func boss_average(content, specs: Array, runs: int = 6, hero_level: int = 10) -> Dictionary:
	var secs := 0.0
	var wins := 0
	var phases := 0.0
	var lost := 0.0
	for i in runs:
		var r := boss_fight(content, specs, i + 1, hero_level)
		secs += r.seconds
		wins += 1 if r.won else 0
		phases += r.phase
		lost += r.hp_lost_pct
	return {"seconds": snappedf(secs / runs, 0.1), "win_rate": float(wins) / runs,
			"phase": snappedf(phases / runs, 0.1), "hp_lost_pct": roundi(lost / runs)}


## A bot hero built from `spec` (see tree_fight) at `hero_level`, in `world`.
static func make_bot(world: WorldSim, content, spec: Dictionary, hero_level: int) -> Hero:
	var h := world.add_hero(content.heroes[&"adventurer"])
	for slot in EquipSlot.COUNT:
		h.unequip(slot)
	h.learning_item = null
	h.bag = Bag.new()
	if spec.get("weapon", "") != "":
		h.wear(content.items[StringName(spec.weapon)])
	for id in spec.get("armor", []):
		h.wear(content.items[StringName(id)])
	for tree in spec.get("mastery", {}):
		Mastery.add_permanent(h, tree, float(spec.mastery[tree]))
	for id in spec.get("mastered", []):
		TreeRules.master(h, content.abilities[StringName(id)])
	if spec.get("learning", "") != "":
		h.bag.add(content.items[StringName(spec.learning)])
		TreeRules.learn_from_bag(h, 0)
	while h.level < hero_level:
		Leveling.add_xp(h, Leveling.xp_to_next(h.level, content.rules), content.rules)
	h.refresh_stats()
	h.hp = h.stats.hp
	h.mana = h.stats.mana
	return h


## One tick of play for every bot hero (see tree_fight), against the nearest of
## `foes`, or `focus` when given.
## With `pathing`, bots walk around whatever is in their way (a boss chamber).
static func bot_turn(world: WorldSim, content, heroes: Array[Hero], specs: Array, foes: Array,
		focus: Enemy = null, pathing := false) -> void:
	for i in heroes.size():
		var h := heroes[i]
		var spec: Dictionary = specs[i]
		if h.alive and h.casting.get("kind", "") == "timing":
			play_timing_bar(world, h, spec.get("timing", "good"))
		if not h.alive or not h.casting.is_empty():
			continue
		var target: Enemy = foes[0] if focus == null else focus
		for e in (foes if focus == null else []):
			if TileGeometry.distance(h.tile(), e.tile()) < TileGeometry.distance(h.tile(), target.tile()):
				target = e
		var delta: Vector2i = target.tile() - h.tile()
		var face := Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
		if face != Vector2i.ZERO and face != h.facing:
			world.submit(h.id, {"type": "face", "dir": face})
		var hurt := heroes.filter(func(x): return x.alive and x.hp < x.stats.hp * spec.get("heal_below", 0.0))
		if not hurt.is_empty() and spec.get("heal", "") != "":
			hurt.sort_custom(func(a, b): return a.hp / a.stats.hp < b.hp / b.stats.hp)
			world.submit(h.id, {"type": "cast", "ability": StringName(spec.heal), "target": hurt[0].id})
		# "dodge": step directly away from an enemy winding up at you.
		if spec.get("dodge", false) and h.cooldowns.can_step(world.now):
			var dodged := false
			for e in foes:
				if e.casting.get("kind", "") == "windup" and (e.casting.get("target", -1) == h.id \
						or e.casting.get("tiles", []).has(h.tile())):
					var away := TileGeometry.snap8(Vector2(h.tile() - e.tile()))
					for d in [Vector2i(away.x, 0), Vector2i(0, away.y)]:
						if d != Vector2i.ZERO and not dodged and world.grid.is_walkable(h.tile() + d) \
								and not world.is_occupied(h.tile() + d):
							world.submit(h.id, {"type": "step", "to": h.tile() + d})
							dodged = true
			if dodged:
				continue
		# Close in when no attack in the rotation reaches (kiters stay at range).
		var reach := 0
		for id in spec.get("rotation", []):
			var r: AbilityDef = content.abilities[StringName(id)]
			if r.target == AbilityDef.TargetType.ENEMY:
				reach = maxi(reach, r.max_range)
		if reach > 0 and TileGeometry.distance(h.tile(), target.tile()) > reach and face != Vector2i.ZERO:
			var next := h.tile() + face
			if pathing:
				var path := Pathfinder.find_path(world.grid, h.tile(), target.tile(), int(h.stats.jump),
						world.occupied_tiles(h), -1, 2048, -1, [],
						func(p: Vector2i): return TileGeometry.distance(p, target.tile()) <= maxi(reach, 1))
				if path.size() > 1:
					next = path[1]
			world.submit(h.id, {"type": "step", "to": next})
		for id in spec.get("rotation", []):
			var a: AbilityDef = content.abilities[StringName(id)]
			var intent := {"type": "cast", "ability": a.id, "target": target.id}
			if a.targeting in [AbilityDef.TargetingMode.SKILLSHOT, AbilityDef.TargetingMode.GROUND]:
				intent.aim = Vector2(target.tile())
				intent.target = -1
			elif a.targeting == AbilityDef.TargetingMode.SELF or a.target != AbilityDef.TargetType.ENEMY:
				intent.target = h.id
			world.submit(h.id, intent)


## The bot's play on a timing bar, one input at a time (TimingBarDef.inputs): a tap
## early in its green zone ("good": full power, no sure crit) or in the middle of
## its first yellow zone ("perfect"); a hold pressed as its zone starts and let go
## as it ends; "miss" plays nothing (the bar runs out at miss power).
static func play_timing_bar(world: WorldSim, h: Hero, skill: String) -> void:
	var c: Dictionary = h.casting
	var elapsed: float = world.now - float(c.start)
	if c.has("hold_from"):
		var zone: Vector2 = c.hold_zone
		if elapsed + 0.0001 >= zone.x + zone.y:
			world.submit(h.id, {"type": "timing_release", "at": elapsed})
		return
	var inputs: Array = (c.ability as AbilityDef).timing_bar.inputs()
	var i: int = c.get("next_input", 0)
	if skill == "miss" or i >= inputs.size():
		return
	var input: Dictionary = inputs[i]
	var when: float = input.zone.x if input.kind == "hold" else input.zone.x + 0.05
	if skill == "perfect" and not input.crits.is_empty():
		when = input.crits[0].x + input.crits[0].y / 2.0
	if elapsed + 0.0001 >= when:
		world.submit(h.id, {"type": "timing_press", "at": elapsed})


static func tree_average(content, specs: Array, enemy_id: StringName, count: int, runs: int = 10,
		hero_level: int = 1) -> Dictionary:
	var secs := 0.0
	var lost := 0.0
	var wins := 0
	var mana := 0.0
	for i in runs:
		var r := tree_fight(content, specs, enemy_id, count, i + 1, hero_level)
		secs += r.seconds
		lost += r.hp_lost_pct
		mana += r.mana_left_pct
		wins += 1 if r.won else 0
	return {"seconds": snappedf(secs / runs, 0.1), "hp_lost_pct": roundi(lost / runs),
			"win_rate": float(wins) / runs, "mana_left_pct": roundi(mana / runs)}
