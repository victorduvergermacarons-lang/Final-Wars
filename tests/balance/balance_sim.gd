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
		if not h.alive:
			continue
		# "dodge": run out of a telegraph (a marked shape or a wind-up aimed at you),
		# even mid-cast (moving cancels it, as a player would).
		if spec.get("dodge", false):
			var away := _dodge_direction(world, h, foes)
			if away != Vector2.ZERO:
				# Straight away if there's room, else at an angle (sidestep).
				var escape: Variant = null
				for turn in [0.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0]:
					var tile := MoveState.tile_of(h.move.pos + away.rotated(turn) * 1.8)
					if world.grid.in_bounds(tile) and world.grid.is_walkable(tile) \
							and not world.pending_hits().any(func(m): return _marks(m, Vector2(tile))):
						escape = tile
						break
				if escape != null:
					if h.walk_target == null or Vector2(escape).distance_to(h.walk_target) > 0.5:
						world.submit(h.id, {"type": "step", "to": escape})
					continue
		if h.casting.get("kind", "") == "timing":
			play_timing_bar(world, h, spec.get("timing", "good"))
		if not h.casting.is_empty():
			continue
		var target: Enemy = foes[0] if focus == null else focus
		for e in (foes if focus == null else []):
			if h.move.pos.distance_to(e.move.pos) < h.move.pos.distance_to(target.move.pos):
				target = e
		var hurt := heroes.filter(func(x): return x.alive and x.hp < x.stats.hp * spec.get("heal_below", 0.0))
		if not hurt.is_empty() and spec.get("heal", "") != "":
			hurt.sort_custom(func(a, b): return a.hp / a.stats.hp < b.hp / b.stats.hp)
			world.submit(h.id, {"type": "cast", "ability": StringName(spec.heal), "target": hurt[0].id})
		# Close in when no attack in the rotation reaches (kiters stay at range).
		var reach := 0.0
		for id in spec.get("rotation", []):
			var r: AbilityDef = content.abilities[StringName(id)]
			if r.target == AbilityDef.TargetType.ENEMY:
				reach = maxf(reach, bot_reach(r, h, target))
		var gap := h.move.pos.distance_to(target.move.pos)
		# A dodging bot waits out a telegraph instead of walking back into it.
		if reach > 0.0 and gap > reach - 0.1:
			var next := target.tile()
			if pathing:
				var path := Pathfinder.find_path(world.grid, h.tile(), target.tile(), int(h.stats.jump),
						world.occupied_tiles(h), -1, 2048, -1, [],
						func(p: Vector2i): return Vector2(p).distance_to(target.move.pos) <= maxf(reach - 0.3, 1.0))
				if path.size() > 1:
					next = path[mini(2, path.size() - 1)]
			# A dodging bot waits rather than walk into a marked shape.
			var stop_short := h.move.pos + (Vector2(next) - h.move.pos).limit_length(1.0)
			var marked: bool = spec.get("dodge", false) and world.pending_hits().any(func(m):
				var c: Actor = world.get_actor(m.get("source", -1))
				return c != null and h.is_hostile_to(c) and _marks(m, stop_short))
			if marked:
				if h.walk_target != null:
					world.submit(h.id, {"type": "move", "dir": Vector2i.ZERO, "face": 0.0})
			elif h.walk_target == null or Vector2(next).distance_to(h.walk_target) > 0.5:
				world.submit(h.id, {"type": "step", "to": next})
		elif h.walk_target != null and gap <= reach - 0.3:
			world.submit(h.id, {"type": "move", "dir": Vector2i.ZERO, "face": 0.0}) # close enough: stop
		h.aim_angle = (target.move.pos - h.move.pos).angle()
		for id in spec.get("rotation", []):
			var a: AbilityDef = content.abilities[StringName(id)]
			var intent := {"type": "cast", "ability": a.id, "target": target.id}
			if a.uses_hitbox() and a.target == AbilityDef.TargetType.ENEMY and a.hitbox.is_aimed() \
					and gap > bot_reach(a, h, target):
				continue # a swing at empty air would only waste the GCD
			if a.uses_hitbox() and a.hitbox.is_aimed():
				intent.aim = target.move.pos
				intent.target = -1
			elif a.targeting in [AbilityDef.TargetingMode.SKILLSHOT, AbilityDef.TargetingMode.GROUND]:
				intent.aim = Vector2(target.tile())
				intent.target = -1
			elif a.targeting == AbilityDef.TargetingMode.SELF or a.target != AbilityDef.TargetType.ENEMY:
				intent.target = h.id
			world.submit(h.id, intent)


## How close (centre to centre) a bot must be for `a` to reach `target`.
static func bot_reach(a: AbilityDef, h: Hero, target: Actor) -> float:
	var radii := h.move.radius + target.move.radius
	if a.uses_hitbox():
		var hb := a.hitbox
		match hb.shape:
			HitboxDef.Shape.TARGETED:
				return hb.reach + radii
			HitboxDef.Shape.CONE:
				return hb.reach + target.move.radius * 0.5
			HitboxDef.Shape.RECT, HitboxDef.Shape.PROJECTILE:
				return hb.reach
			HitboxDef.Shape.CIRCLE, HitboxDef.Shape.LOB:
				return hb.reach + hb.radius * 0.5
			HitboxDef.Shape.SELF_CIRCLE:
				return hb.radius + target.move.radius * 0.5
			HitboxDef.Shape.DASH, HitboxDef.Shape.LEAP:
				return hb.reach + radii
	return float(maxi(a.max_range, 1)) + radii * 0.5


## Whether a telegraph (pending_hits entry) covers point `p`: its outline, or for
## tile-based ones (the drake's dive lane) its tiles.
static func _marks(mark: Dictionary, p: Vector2) -> bool:
	var poly: PackedVector2Array = mark.get("outline", PackedVector2Array())
	if poly.size() > 2:
		return Geometry2D.is_point_in_polygon(p, poly)
	return Array(mark.get("tiles", [])).has(MoveState.tile_of(p))


## Which way to run (unit grid vector) when a telegraph covers the bot, else ZERO:
## away from the marked shape's centre, or from an enemy winding up at it.
static func _dodge_direction(world: WorldSim, h: Hero, foes: Array) -> Vector2:
	for mark in world.pending_hits():
		var poly: PackedVector2Array = mark.get("outline", PackedVector2Array())
		var caster: Actor = world.get_actor(mark.get("source", -1))
		if caster == null or not h.is_hostile_to(caster):
			continue
		var covered := false
		if poly.size() >= 3:
			covered = Geometry2D.is_point_in_polygon(h.move.pos, poly)
		else:
			covered = Array(mark.get("tiles", [])).has(h.tile())
		if covered:
			# A shape from the caster (cone, lane): straight away from the caster.
			# A circle elsewhere: away from its centre.
			var centre := caster.move.pos
			if poly.size() >= 3 and poly[0].distance_to(caster.move.pos) > 0.3:
				centre = Vector2.ZERO
				for q in poly:
					centre += q
				centre /= poly.size()
			var away := h.move.pos - centre
			return away.normalized() if away.length() > 0.01 else Vector2.RIGHT
	# Standing in an enemy's burning ground: step off it, away from its middle.
	for z in world.ground_zones():
		var src: Actor = world.get_actor(z.get("source", -1))
		if src == null or not h.is_hostile_to(src) or not Array(z.tiles).has(h.tile()):
			continue
		var centre := Vector2.ZERO
		for t in z.tiles:
			centre += Vector2(t)
		centre /= maxf(z.tiles.size(), 1)
		var off := h.move.pos - centre
		return off.normalized() if off.length() > 0.2 else (h.move.pos - src.move.pos).normalized()
	for e in foes:
		if e.alive and e.casting.get("kind", "") == "windup" and e.casting.get("target", -1) == h.id:
			var away: Vector2 = h.move.pos - e.move.pos
			return away.normalized() if away.length() > 0.01 else Vector2.RIGHT
	return Vector2.ZERO


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
