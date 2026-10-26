class_name DebugCommands
extends RefCounted
## Debug console commands (Milestone 3 §7), run by the host on the player's own
## hero. Only accepted when the host allows it (debug builds; see
## WorldSim.debug_content). Type "help" in the console (`) for the list.

const HELP := """Commands:
  help                         this list
  level <n>                    set your level (levelling up applies growth and AP)
  mastery <tree> <n>           set your permanent Mastery in a tree (Fire, Earth, Water, Air, Sword, Bow, Hammer)
  ap <n>                       give AP to the ability you are learning
  master <ability>             master an ability (id like F07 or a name like "Fireball")
  spawn <enemy> [level] [n]    spawn n enemies (default 1) at a level (default theirs) next to you
  heal                         full HP and Mana, cooldowns reset
  gold <n>                     set your gold"""

## Stats that scale with an enemy's level when spawned above or below its own.
const LEVEL_STATS := [Stat.Id.HP, Stat.Id.PHYS_ATK, Stat.Id.MAG_ATK, Stat.Id.PHYS_DEF, Stat.Id.MAG_DEF]
## Per level of difference, as a fraction of the type's stats.
const LEVEL_STEP := 0.15
const MAX_SPAWN := 10


## Runs one command line. Returns {"ok": bool, "text": String, "events": Array}.
static func run(world: WorldSim, hero: Hero, line: String, content) -> Dictionary:
	var words := _split(line)
	if words.is_empty():
		return _fail("Type help for the commands.")
	var cmd := words[0].to_lower()
	var args := words.slice(1)
	match cmd:
		"help", "?":
			return _ok(HELP)
		"level":
			return _level(world, hero, args)
		"mastery":
			return _mastery(hero, args)
		"ap":
			return _ap(hero, args)
		"master":
			return _master(hero, args, content)
		"spawn":
			return _spawn(world, hero, args, content)
		"heal":
			hero.hp = hero.current_stats(world.now).hp
			hero.mana = hero.current_stats(world.now).mana
			hero.cooldowns = Cooldowns.new()
			return _ok("Healed; cooldowns reset.")
		"gold":
			if args.size() != 1 or not args[0].is_valid_int():
				return _fail("Usage: gold <n>")
			hero.gold = clampi(int(args[0]), 0, CharacterData.MAX_GOLD)
			return _ok("Gold: %d" % hero.gold)
	return _fail("Unknown command '%s'. Type help." % cmd)


static func _level(world: WorldSim, hero: Hero, args: Array) -> Dictionary:
	if args.size() != 1 or not args[0].is_valid_int():
		return _fail("Usage: level <n>")
	var target := clampi(int(args[0]), 1, 60)
	var events: Array = []
	if target < hero.level:
		hero.level = target
		hero.xp = 0.0
	for i in 60:
		if hero.level >= target:
			break
		events.append_array(Leveling.add_xp(hero, Leveling.xp_to_next(hero.level, world.rules) - hero.xp, world.rules))
	hero.refresh_stats()
	return _ok("Level %d." % hero.level, events)


static func _mastery(hero: Hero, args: Array) -> Dictionary:
	if args.size() != 2 or not args[1].is_valid_float():
		return _fail("Usage: mastery <tree> <n>")
	var tree := _tree_name(args[0])
	if tree == "":
		return _fail("No tree '%s'. Trees: %s" % [args[0], ", ".join(Mastery.TREES)])
	var amount := clampf(float(args[1]), 0.0, 5000.0)
	Mastery.add_permanent(hero, tree, amount - Mastery.permanent(hero, tree))
	hero.refresh_stats()
	return _ok("%s Mastery %d (permanent)." % [tree, roundi(Mastery.permanent(hero, tree))])


static func _ap(hero: Hero, args: Array) -> Dictionary:
	if args.size() != 1 or not args[0].is_valid_int():
		return _fail("Usage: ap <n>")
	if hero.active_learning_item() == null:
		return _fail("You aren't learning anything: put a scroll or your weapon in the learning slot.")
	var ability := hero.active_learning_item().tree_ability()
	var events := TreeRules.award_ap(hero, clampi(int(args[0]), 1, 1000))
	hero.refresh_stats()
	return _ok("AP given%s." % (" (%s: %d / %d)" % [ability.display_name, hero.ap.get(ability.id, 0),
			ability.ap_to_master] if ability != null else ""), events)


static func _master(hero: Hero, args: Array, content) -> Dictionary:
	if args.is_empty():
		return _fail("Usage: master <ability>")
	var ability := find_ability(" ".join(args), content)
	if ability == null:
		return _fail("No ability '%s'." % " ".join(args))
	if hero.is_mastered(ability.id):
		return _ok("%s is already mastered." % ability.display_name)
	var events: Array = []
	if ability.is_tree_ability():
		events.append_array(TreeRules.master(hero, ability))
	else:
		hero.mastered[ability.id] = ability
	hero.refresh_stats()
	return _ok("Mastered %s%s." % [ability.display_name, "" if ability.implemented else " (not in the game yet: can't be used)"],
			events)


static func _spawn(world: WorldSim, hero: Hero, args: Array, content) -> Dictionary:
	if args.is_empty():
		return _fail("Usage: spawn <enemy> [level] [n]   e.g. spawn wolf 3 2")
	var rest := args.duplicate()
	var count := 1
	var level := -1
	if rest.size() >= 2 and rest[-1].is_valid_int() and rest[-2].is_valid_int():
		count = clampi(int(rest.pop_back()), 1, MAX_SPAWN)
	if rest.size() >= 2 and rest[-1].is_valid_int():
		level = clampi(int(rest.pop_back()), 1, 60)
	var def := find_enemy(" ".join(rest), content)
	if def == null:
		return _fail("No enemy '%s'. Enemies: %s" % [" ".join(rest), ", ".join(content.enemies.keys().map(func(k): return String(k)))])
	var scaled := at_level(def, level if level > 0 else def.level)
	var tiles := _free_tiles_near(world, hero.tile(), count)
	if tiles.is_empty():
		return _fail("No free tile next to you.")
	for t in tiles:
		var e := world.add_enemy(scaled, t)
		e.level = scaled.level
		e.temporary = true
	return _ok("Spawned %d %s (level %d). They don't respawn." % [tiles.size(), def.display_name, scaled.level])


## A copy of `def` at another level: HP, attack and defense ±15% per level, XP too.
static func at_level(def: EnemyDef, level: int) -> EnemyDef:
	if level == def.level:
		return def
	var out: EnemyDef = def.duplicate()
	out.level = level
	var k := maxf(1.0 + LEVEL_STEP * (level - def.level), 0.3)
	out.stats = def.stats.copy()
	for id in LEVEL_STATS:
		out.stats.set_stat(id, roundf(def.stats.get_stat(id) * k))
	out.xp_reward = roundi(def.xp_reward * k)
	return out


static func find_ability(text: String, content) -> AbilityDef:
	var key := text.strip_edges()
	for id in content.abilities:
		var a: AbilityDef = content.abilities[id]
		if String(id).to_lower() == key.to_lower() or a.display_name.to_lower() == key.to_lower():
			return a
	return null


static func find_enemy(text: String, content) -> EnemyDef:
	var key := text.strip_edges().to_lower()
	for id in content.enemies:
		var e: EnemyDef = content.enemies[id]
		if String(id) == key.replace(" ", "_") or e.display_name.to_lower() == key:
			return e
	return null


static func _tree_name(text: String) -> String:
	for t in Mastery.TREES:
		if t.to_lower() == text.to_lower():
			return t
	return ""


## Free walkable tiles around `center`, nearest first.
static func _free_tiles_near(world: WorldSim, center: Vector2i, count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in range(1, 6):
		for t in TileGeometry.square(center, r):
			if out.size() >= count:
				return out
			if TileGeometry.distance(center, t) == r and world.grid.in_bounds(t) and world.grid.is_walkable(t) \
					and not world.is_occupied(t):
				out.append(t)
	return out


## Words, keeping "quoted names" together.
static func _split(line: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var parts := line.strip_edges().split("\"")
	for i in parts.size():
		if i % 2 == 1:
			if parts[i].strip_edges() != "":
				out.append(parts[i].strip_edges())
		else:
			for w in parts[i].split(" ", false):
				out.append(w)
	return out


static func _ok(text: String, events: Array = []) -> Dictionary:
	return {"ok": true, "text": text, "events": events}


static func _fail(text: String) -> Dictionary:
	return {"ok": false, "text": text, "events": []}
