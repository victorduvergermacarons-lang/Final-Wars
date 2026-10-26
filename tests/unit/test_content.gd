extends GutTest
## The shipped content loads and is valid.

const ContentDBScript := preload("res://autoload/content_db.gd")

var db


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func test_all_content_validates() -> void:
	assert_eq(db.validate(), PackedStringArray())


func test_starter_items_teach_the_agreed_abilities() -> void:
	var teaches := func(id): return db.items[id].teaches.map(func(a): return a.id)
	assert_eq(teaches.call(&"sword"), [&"strike"])
	assert_eq(teaches.call(&"staff"), [&"fireball"])
	assert_eq(teaches.call(&"shield"), [&"block"])
	assert_eq(teaches.call(&"holy_charm"), [&"heal", &"resurrect"])


func test_items_share_ability_resources() -> void:
	assert_same(db.items[&"sword"].teaches[0], db.abilities[&"strike"])


func test_block_doubles_physical_defense_off_the_gcd() -> void:
	var block: AbilityDef = db.abilities[&"block"]
	var buff: BuffDef = block.effects[0].buff
	assert_eq(buff.modifiers[0].stat, Stat.Id.PHYS_DEF)
	assert_eq(buff.modifiers[0].multiplier, 2.0)
	assert_false(block.on_gcd, "Block neither waits for nor triggers the GCD")


func test_zone_is_30_by_30_with_heights_and_enemies() -> void:
	var zone: ZoneDef = db.zones[&"greenfields"]
	var grid := GridModel.from_zone(zone)
	assert_eq(grid.width, 30)
	assert_eq(grid.depth, 30)
	assert_eq(grid.height_at(Vector2i(25, 5)), 4, "plateau")
	assert_eq(zone.enemy_spawns.size(), 14) # 11 + the wolf pack of 3
	var counts := {}
	for s in zone.enemy_spawns:
		counts[s.enemy.id] = counts.get(s.enemy.id, 0) + 1
		assert_true(grid.is_walkable(s.tile))
		var path := Pathfinder.find_path(grid, zone.hero_spawns[0], s.tile, 2, {}, -1, 100000)
		assert_false(path.is_empty(), "%s at %s is reachable" % [s.enemy.id, s.tile])
	assert_eq(counts, {&"wolf": 7, &"goblin_shaman": 2, &"bandit_brute": 2, &"fen_skirmisher": 2,
			&"old_grizzlehide": 1})


func test_plateau_is_reachable_by_ramp_only() -> void:
	var zone: ZoneDef = db.zones[&"greenfields"]
	var grid := GridModel.from_zone(zone)
	var path := Pathfinder.find_path(grid, zone.hero_spawns[0], Vector2i(26, 5), 2, {}, -1, 100000)
	assert_false(path.is_empty())
	assert_true(path.has(Vector2i(24, 10)) or path.has(Vector2i(25, 10)), "climbs the ramp")


func test_world_starts_from_shipped_content() -> void:
	var world := WorldSim.new(db.zones[&"greenfields"], db.rules, 1)
	var hero := world.add_hero(db.heroes[&"adventurer"])
	assert_eq(world.enemies().size(), 14)
	assert_eq(hero.equipped_in(EquipSlot.Id.MAIN_HAND).id, &"rusty_shortsword")
	assert_eq(hero.learning_item.id, &"ember_fist_scroll", "starts learning Fire Punch")
	assert_eq(hero.bag.count_of(db.items[&"menders_scroll"]), 1)
	var ids := hero.available_abilities().map(func(a): return String(a.id))
	ids.sort()
	assert_eq(ids, ["F01", "S01"])
	world.advance(1.0)
	assert_true(hero.alive)


func test_enemy_types_levels_and_behaviors() -> void:
	var expect := {
		&"wolf": [1, EnemyDef.Behavior.MELEE],
		&"goblin_shaman": [2, EnemyDef.Behavior.KITER],
		&"bandit_brute": [3, EnemyDef.Behavior.MELEE],
		&"fen_skirmisher": [4, EnemyDef.Behavior.FLANKER],
	}
	for id in expect:
		var def: EnemyDef = db.enemies[id]
		assert_eq(def.level, expect[id][0], "%s level" % id)
		assert_eq(def.behavior, expect[id][1], "%s behavior" % id)
		assert_not_null(def.loot, "%s has loot" % id)
		assert_eq(def.abilities.size(), 1)
	assert_gt(db.enemies[&"bandit_brute"].combat_step_seconds, 1.5, "Brute is slower than a hero")
	assert_lt(db.enemies[&"fen_skirmisher"].combat_step_seconds, db.enemies[&"wolf"].combat_step_seconds,
			"Skirmisher is the fastest")
	var bolt: AbilityDef = db.enemies[&"goblin_shaman"].abilities[0]
	assert_eq(bolt.shape, AbilityDef.Shape.LINE)
	assert_true(bolt.ranged)
	assert_eq(bolt.effects[0].damage_type, AbilityEffect.DamageType.MAGICAL)


func test_old_grizzlehide_is_a_patrolling_elite() -> void:
	var def: EnemyDef = db.enemies[&"old_grizzlehide"]
	assert_true(def.elite)
	assert_eq(def.level, 5)
	assert_eq(def.stats.hp, 2000.0, "raised from ~6x Wolf HP in the Milestone 3 balance pass")
	assert_eq(def.respawn_seconds, 300.0)
	assert_eq(def.abilities.map(func(a): return a.id), [&"grizzly_cleave", &"charge"])
	var drops: Array = def.loot.entries.map(func(e): return e.item.id)
	assert_has(drops, &"grizzlehide_mantle")
	assert_has(drops, &"rangers_gloves")
	var zone: ZoneDef = db.zones[&"greenfields"]
	var grid := GridModel.from_zone(zone)
	for s in zone.enemy_spawns:
		if s.enemy.id != &"old_grizzlehide":
			continue
		assert_gt(s.patrol.size(), 2, "has a patrol loop")
		for i in s.patrol.size():
			var path := Pathfinder.find_path(grid, s.patrol[i], s.patrol[(i + 1) % s.patrol.size()],
					int(def.stats.jump), {}, -1, 100000)
			assert_false(path.is_empty(), "patrol leg %d is walkable" % i)


func test_sample_quests() -> void:
	assert_eq(db.quests.size(), 5)
	var chain := [&"wolves_at_the_gate", &"bandit_camp", &"beast_of_greenfields"]
	for i in range(1, chain.size()):
		assert_eq(db.quests[chain[i]].prerequisites, [chain[i - 1]] as Array[StringName], "%s follows %s" % [chain[i], chain[i - 1]])
	var kinds := {}
	for q in db.quests.values():
		assert_true(db.npcs.has(q.giver), "%s giver exists" % q.id)
		for o in q.objectives:
			kinds[o.kind] = true
			if o.kind == QuestObjective.Kind.KILL:
				assert_true(db.enemies.has(o.enemy), "%s: enemy %s exists" % [q.id, o.enemy])
			elif o.kind == QuestObjective.Kind.REACH:
				assert_true(GridModel.from_zone(db.zones[o.zone]).is_walkable(o.tile))
	assert_eq(kinds.size(), 4, "every objective kind is used")
	var beast: QuestDef = db.quests[&"beast_of_greenfields"]
	assert_eq(beast.reward_choices.size(), 3, "item choice")
	assert_eq(beast.sets_world_flag, &"grizzlehide_slain")
	var fetish: ItemDef = db.items[&"goblin_fetish"]
	assert_true(fetish.quest_item)
	var drops: Array = db.enemies[&"goblin_shaman"].loot.entries.filter(func(e): return e.item == fetish)
	assert_eq(drops.size(), 1)
	assert_eq(drops[0].quest_id, &"goblin_fetishes", "fetishes only drop while on the quest")


func test_rowan_greets_differently_after_grizzlehide() -> void:
	var rowan: NpcDef = db.npcs[&"rowan"]
	assert_eq(rowan.greeting_line({}, db.dialogue), "npc.rowan.greeting")
	assert_eq(rowan.greeting_line({"grizzlehide_slain": true}, db.dialogue), "npc.rowan.greeting.grizzlehide_slain")
	assert_ne(db.dialogue.text("npc.rowan.greeting.grizzlehide_slain"), db.dialogue.text("npc.rowan.greeting"))


func test_bandit_camp_is_marked_and_reachable() -> void:
	var zone: ZoneDef = db.zones[&"greenfields"]
	var camp: ZoneLandmark = zone.landmarks.filter(func(l): return l.name == "Bandit Camp")[0]
	var obj: QuestObjective = db.quests[&"bandit_camp"].objectives[0]
	assert_eq(obj.kind, QuestObjective.Kind.REACH)
	assert_eq(obj.tile, camp.tile, "the quest asks for the marked spot")
	var grid := GridModel.from_zone(zone)
	var reachable := 0
	for y in range(obj.tile.y - obj.radius, obj.tile.y + obj.radius + 1):
		for x in range(obj.tile.x - obj.radius, obj.tile.x + obj.radius + 1):
			var p := Vector2i(x, y)
			if GridModel.distance(p, obj.tile) <= obj.radius and grid.is_walkable(p):
				reachable += 1
	assert_gt(reachable, 6, "plenty of walkable tiles count as finding the camp")
