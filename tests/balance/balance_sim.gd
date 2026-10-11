class_name BalanceSim
extends RefCounted
## Scripted fights on the real WorldSim with shipped content, for tuning.
## A bot hero turns toward the nearest wolf, uses abilities in priority order,
## heals below a threshold if it can, and never moves (wolves come to it).

## Runs one fight and returns {"seconds", "hp_lost_pct" (worst hero), "won", "mana_left_pct"}.
## `loadouts`: per hero, item ids to equip. `rotation`: ability ids in priority order.
static func fight(content, loadouts: Array, rotation: Array, wolves: int, seed: int = 1,
		heal_below: float = 0.0, block_first: bool = false) -> Dictionary:
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
	zone.hero_spawns = [Vector2i(3, 5), Vector2i(3, 7)]
	var spawns: Array[EnemySpawn] = []
	for i in wolves:
		var s := EnemySpawn.new()
		s.enemy = content.enemies[&"wolf"]
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
		heal_below: float = 0.0, block_first: bool = false) -> Dictionary:
	var secs := 0.0
	var lost := 0.0
	var wins := 0
	var mana := 0.0
	for i in runs:
		var r := fight(content, loadouts, rotation, wolves, i + 1, heal_below, block_first)
		secs += r.seconds
		lost += r.hp_lost_pct
		mana += r.mana_left_pct
		wins += 1 if r.won else 0
	return {"seconds": snappedf(secs / runs, 0.1), "hp_lost_pct": roundi(lost / runs),
			"win_rate": float(wins) / runs, "mana_left_pct": roundi(mana / runs)}
