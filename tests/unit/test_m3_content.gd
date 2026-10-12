extends GutTest
## Milestone 3 step 10: enemies use the new targeting (wind-ups, skillshots, a
## telegraphed charge), and loot, vendor, quests and the starting kit point at
## ability-tree items.

const ContentDBScript := preload("res://autoload/content_db.gd")

var db
var world: WorldSim
var hero: Hero


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func _arena(enemy_id: StringName, enemy_tile: Vector2i, hero_tile: Vector2i) -> Enemy:
	var zone := ZoneDef.new()
	zone.id = &"arena"
	var heights: PackedStringArray = []
	var walk: PackedStringArray = []
	for y in 15:
		heights.append("0".repeat(15))
		walk.append(".".repeat(15))
	zone.height_rows = heights
	zone.walk_rows = walk
	zone.graveyards = [Vector2i(0, 0)]
	zone.hero_spawns = [hero_tile]
	world = WorldSim.new(zone, db.rules, 11)
	var e := world.add_enemy(db.enemies[enemy_id], enemy_tile)
	hero = world.add_hero(db.heroes[&"adventurer"])
	hero.move.place(hero_tile)
	return e


func test_enemy_abilities_use_milestone_3_targeting() -> void:
	for id in [&"wolf_bite", &"crushing_blow", &"quick_slash"]:
		var a: AbilityDef = db.abilities[id]
		assert_eq(a.targeting, AbilityDef.TargetingMode.TARGETED, id)
		assert_gt(a.windup_seconds, 0.0, "%s winds up" % id)
	assert_eq(db.abilities[&"wolf_bite"].windup_seconds, 0.3)
	assert_eq(db.abilities[&"shadow_bolt"].targeting, AbilityDef.TargetingMode.SKILLSHOT)
	assert_eq(db.abilities[&"grizzly_cleave"].line_shape, AbilityDef.LineShape.CONE)
	assert_eq(db.abilities[&"charge"].targeting, AbilityDef.TargetingMode.GROUND)


func test_wolf_bite_winds_up_and_can_be_dodged() -> void:
	var wolf := _arena(&"wolf", Vector2i(6, 5), Vector2i(5, 5))
	wolf.threat.add(hero.id, 1.0)
	wolf.state = Enemy.State.COMBAT
	var hp := hero.hp
	for i in 20: # until the wind-up starts
		world.step()
		if not wolf.casting.is_empty():
			break
	assert_eq(wolf.casting.get("kind", ""), "windup")
	hero.move.place(Vector2i(3, 5)) # step out of reach
	world.advance(0.4)
	assert_eq(hero.hp, hp, "the bite whiffed")


func test_wolf_bite_lands_if_you_stay() -> void:
	var wolf := _arena(&"wolf", Vector2i(6, 5), Vector2i(5, 5))
	wolf.threat.add(hero.id, 1.0)
	wolf.state = Enemy.State.COMBAT
	var hp := hero.hp
	var hits := 0
	for i in 40:
		for e in world.step():
			if e.type == "damage" and e.target == hero.id:
				hits += 1
	assert_gt(hits + (1 if hero.hp < hp else 0), 0, "bitten (or missed by Evasion at worst)")


func test_shaman_shoots_a_skillshot_at_any_angle() -> void:
	var shaman := _arena(&"goblin_shaman", Vector2i(9, 8), Vector2i(5, 5))
	shaman.threat.add(hero.id, 1.0)
	shaman.state = Enemy.State.COMBAT
	var shot := false
	for i in 60:
		for e in world.step():
			if e.type == "projectile" or (e.type == "cast" and e.source == shaman.id):
				shot = true
		if shot:
			break
	assert_true(shot, "fires without lining up on a row or column")


func test_grizzlehide_charge_is_telegraphed_then_rushes_in() -> void:
	var bear := _arena(&"old_grizzlehide", Vector2i(9, 5), Vector2i(5, 5))
	var charge: AbilityDef = db.abilities[&"charge"]
	assert_eq(world.cast(bear, charge, null, Vector2(5, 5)), AbilityResolver.Result.OK)
	var marks := world.pending_hits()
	assert_eq(marks.size(), 1, "the target tile is telegraphed")
	assert_eq(marks[0].tiles, [Vector2i(5, 5)])
	var hp := hero.hp
	world.advance(1.05)
	assert_eq(bear.tile(), Vector2i(6, 5), "rushed up next to the hero")
	assert_lt(hero.hp, hp, "and mauled them")


func test_charge_misses_a_hero_who_moved() -> void:
	var bear := _arena(&"old_grizzlehide", Vector2i(9, 5), Vector2i(5, 5))
	world.cast(bear, db.abilities[&"charge"], null, Vector2(5, 5))
	var hp := hero.hp
	hero.move.place(Vector2i(5, 8))
	world.advance(1.05)
	assert_eq(hero.hp, hp)


func test_loot_quests_and_vendor_point_at_tree_items() -> void:
	var drops := {}
	for e in db.enemies.values():
		if e.loot == null:
			continue
		for entry in e.loot.entries:
			assert_not_null(entry.item, "%s loot entry linked" % e.id)
			assert_false(entry.item.retired, "%s drops nothing retired" % e.id)
			if entry.item.tree != "":
				drops[entry.item.id] = entry.item
	assert_gt(drops.size(), 5, "tier 2 scrolls drop in Greenfields")
	for item in drops.values():
		assert_eq(item.tier, 2, "%s is tier 2" % item.id)
		assert_true(item.tree_ability().implemented)
	for q in db.quests.values():
		for item in q.reward_items + q.reward_choices:
			assert_false(item.retired, "%s rewards nothing retired" % q.id)
	var beast: QuestDef = db.quests[&"beast_of_greenfields"]
	assert_eq(beast.reward_choices.map(func(i): return i.id),
			[&"scroll_of_the_fireball", &"glacier_scroll", &"bulwark_scroll"])


func test_linking_twice_does_not_duplicate() -> void:
	var again = ContentDBScript.new()
	var hilda: NpcDef = again.npcs[&"hilda"]
	var ids := hilda.sells.map(func(i): return i.id)
	var unique := {}
	for id in ids:
		unique[id] = true
	assert_eq(unique.size(), ids.size())
	again.free()


func test_a_scroll_being_learned_grows_the_hero_on_level_up() -> void:
	var h := Hero.from_def(1, db.heroes[&"adventurer"])
	assert_eq(h.learning_item.id, &"ember_fist_scroll")
	var before := h.stats.mag_atk
	var fire := Mastery.permanent(h, "Fire")
	Leveling.add_xp(h, Leveling.xp_to_next(1, db.rules), db.rules)
	var share: float = db.rules.growth_fraction
	assert_almost_eq(h.stats.mag_atk - before, 3.0 * share, 0.01, "Fire scrolls grow Magic Attack")
	assert_almost_eq(Mastery.permanent(h, "Fire") - fire, 2.0 * share, 0.01, "and Fire Mastery")
