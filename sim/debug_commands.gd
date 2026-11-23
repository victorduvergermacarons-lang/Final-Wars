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
  goto <zone>                  go to a zone's start (town, crossing, deepcut_road, deepcut, windsteppe, greenfields, wilds, tidereach_shore, silent_shaft)
  gold <n>                     set your gold
  fx <ability>                 play an ability's effects from you toward the cursor (no damage, no cooldown)
  fx <Tree>:<n>                hold a stance (its look) without its checks; Shift leaves it"""

## Stats that scale with an enemy's level when spawned above or below its own.
const LEVEL_STATS := [Stat.Id.HP, Stat.Id.PHYS_ATK, Stat.Id.MAG_ATK, Stat.Id.PHYS_DEF, Stat.Id.MAG_DEF]
## Per level of difference, as a fraction of the type's stats.
const LEVEL_STEP := 0.15
const MAX_SPAWN := 10


## Runs one command line. Returns {"ok": bool, "text": String, "events": Array}.
static func run(world: WorldSim, hero: Hero, line: String, content, aim = null) -> Dictionary:
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
		"goto":
			return _goto(world, hero, args, content)
		"fx":
			return _fx(world, hero, args, content, aim)
		"gold":
			if args.size() != 1 or not args[0].is_valid_int():
				return _fail("Usage: gold <n>")
			hero.gold = clampi(int(args[0]), 0, CharacterData.MAX_GOLD)
			return _ok("Gold: %d" % hero.gold)
	return _fail("Unknown command '%s'. Type help." % cmd)


## How far ahead `fx` plays when the cursor is further (tiles), and how long held
## and looping effects show.
const FX_REACH := 6.0
const FX_HOLD := 3.0


## Plays an ability's effects as the game would, from the hero toward the cursor:
## what it holds while casting, what it fires (flying at its speed), where it
## lands, its tiles (3x3 around the point) and what it leaves on a unit (on you),
## with no damage and no cooldown. "<Tree>:<n>" holds a stance instead.
static func _fx(world: WorldSim, hero: Hero, args: Array, content, aim) -> Dictionary:
	if args.is_empty():
		return _fail("Usage: fx <ability> or fx <Tree>:<n>")
	var text := " ".join(args)
	if text.contains(":"):
		var tree := _tree_name(text.get_slice(":", 0))
		var n := int(text.get_slice(":", 1))
		if not WorldSim.BENDING_TREES.has(tree) or n < 1 or n > 5:
			return _fail("Usage: fx <Fire|Earth|Water|Air>:<1-5>")
		world.set_stance(hero, tree, n)
		return _ok("Holding %s stance %d (Shift leaves it)." % [tree, n])
	var ability := find_ability(text, content)
	if ability == null:
		return _fail("No ability '%s'." % text)
	var from := hero.move.pos
	var to: Vector2 = from + hero.facing_vector() * 3.0
	if aim is Vector2:
		to = aim if from.distance_to(aim) <= FX_REACH else from + (aim - from).normalized() * FX_REACH
	if to.distance_to(from) > 0.01:
		hero.face_angle((to - from).angle()) # as a cast would: the hand points the right way
	var now := world.now
	var events: Array = []
	var played: PackedStringArray = []
	var base := {"type": "fx", "source": hero.id, "ability": ability.id, "from": from, "to": to}
	var at := now
	if ability.fx_hands != &"":
		events.append(_with(base, {"fx": ability.fx_hands, "on": hero.id, "for": 1.0, "at": at}))
		played.append("in the hands")
		at += 1.0
	if ability.fx_cast != &"":
		var cast := _with(base, {"fx": ability.fx_cast, "at": at})
		cast.merge(world.shape_fx_data(hero, ability, ability.fx_cast, null, to), true) # ribbons, fronts, rings
		events.append(cast)
		played.append("cast")
	if ability.fx_projectile != &"":
		var hb: HitboxDef = ability.hitbox if ability.hitbox != null else ability.sheet_hitbox
		var speed := hb.speed if hb != null and hb.speed > 0.0 else 10.0
		var fly := from.distance_to(to) / speed
		events.append(_with(base, {"fx": ability.fx_projectile, "fly": fly, "for": fly, "at": at}))
		played.append("flight")
		at += fly
	if ability.fx_land != &"":
		events.append(_with(base, {"fx": ability.fx_land, "from": to, "at": at}))
		played.append("landing")
	if ability.fx_tiles != &"":
		var tiles := []
		var c := Vector2i(to.round())
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if world.grid.in_bounds(c + Vector2i(dx, dy)):
					tiles.append(c + Vector2i(dx, dy))
		events.append(_with(base, {"fx": ability.fx_tiles, "tiles": tiles, "for": FX_HOLD, "at": at}))
		played.append("tiles")
	if ability.fx_held != &"":
		events.append(_with(base, {"fx": ability.fx_held, "on": hero.id, "for": FX_HOLD, "at": at}))
		played.append("held on you")
	for e in ability.effects:
		if e.buff != null and e.buff.code_fx != "":
			events.append(_with(base, {"code": e.buff.code_fx, "on": hero.id, "for": FX_HOLD, "at": at}))
			played.append("%s (code)" % e.buff.code_fx)
	if played.is_empty():
		return _ok("%s has no effect art yet." % ability.display_name)
	return _ok("%s: %s." % [ability.display_name, ", ".join(played)], events)


static func _with(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	out.merge(b, true)
	return out


static func _goto(world: WorldSim, hero: Hero, args: Array, content) -> Dictionary:
	if args.size() != 1:
		return _fail("Usage: goto <zone>")
	var id := StringName(args[0].to_lower())
	if not content.zones.has(id):
		var ids: Array = content.zones.keys()
		ids.sort()
		return _fail("No zone '%s'. Zones: %s" % [args[0], ", ".join(ids)])
	if hero.in_combat(world.now):
		return _fail("Not while in combat.")
	world.request_zone_move(hero.id, id)
	return _ok("Going to %s." % content.zones[id].display_name)


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
	var key := text.strip_edges().to_lower()
	# By id or name; tree abilities first (the retired M1 "fireball" shares F07's name).
	var found: AbilityDef = null
	for id in content.abilities:
		var a: AbilityDef = content.abilities[id]
		if String(id).to_lower() == key or a.display_name.to_lower() == key:
			if found == null or (a.is_tree_ability() and not found.is_tree_ability()):
				found = a
	return found


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
