extends GutTest
## The Stag (Critters pack, 2026-11-19): neutral. It wanders and grazes, never
## aggros on a hero who comes close, fights only what damages it (only the one
## hit), and goes back to neutral when its attacker dies or drags it past its
## leash. Also the boar's new art.

var world: WorldSim
var hero: Hero
var stag: Enemy
var other: Enemy
var def: EnemyDef


func before_each() -> void:
	ContentDB.rules.timing_bars_enabled = false
	var zone := ZoneDef.new()
	zone.id = &"steppe"
	var rows: PackedStringArray = []
	var walk: PackedStringArray = []
	for y in 60:
		rows.append("0".repeat(60))
		walk.append(".".repeat(60))
	zone.height_rows = rows
	zone.walk_rows = walk
	zone.graveyards = [Vector2i(0, 0)]
	zone.hero_spawns = [Vector2i(0, 0)]
	world = WorldSim.new(zone, ContentDB.rules, 7)
	def = ContentDB.enemies[&"stag"]
	var hd := HeroDef.new()
	hd.base_stats = StatBlock.make({Stat.Id.HP: 2000, Stat.Id.MANA: 500, Stat.Id.PHYS_ATK: 10, Stat.Id.JUMP: 2})
	hero = world.add_hero(hd)
	stag = world.add_enemy(def, Vector2i(20, 20))
	other = world.add_enemy(def, Vector2i(23, 20))


func after_each() -> void:
	ContentDB.rules.timing_bars_enabled = true


func _run(seconds: float) -> void:
	for i in roundi(seconds / world.rules.tick_seconds):
		world.step()


func _hurt(e: Enemy, amount := 5.0) -> void:
	var events: Array[Dictionary] = []
	AbilityResolver.deal_damage(world.ctx, hero, e, &"test", amount, false, events)
	world._emit_resolved(events)
	world.step()


func test_data_and_art() -> void:
	assert_true(def.neutral)
	assert_eq(def.abilities.size(), 1)
	assert_gt(def.wander_radius, 0)
	assert_not_null(def.loot)
	var art: CreatureArtDef = def.art
	assert_eq(art.frame_count("idle"), 24)
	assert_eq(art.frame_count("walk"), 11)
	assert_eq(art.frame_count("run"), 10)
	assert_eq(art.feet, Vector2(16, 39))
	var boar: CreatureArtDef = ContentDB.enemies[&"boar"].art
	assert_eq(boar.frame_count("idle"), 7)
	assert_eq(boar.frame_count("run"), 4)
	assert_eq(boar.anim_fps("run"), 12.0)
	assert_false(boar.sheets.has("death"), "no death art yet: the fallback tips it over")
	assert_eq(boar.corpse_total(), boar.fallback_death_tip_seconds + boar.corpse_seconds + boar.fade_seconds)


func test_windsteppe_stags_replace_the_herd() -> void:
	var z: ZoneDef = ContentDB.zones[&"windsteppe"]
	var stags := z.enemy_spawns.filter(func(s): return s.enemy.id == &"stag")
	assert_eq(stags.size(), 4)
	for s in stags:
		assert_true(z.walk_rows[s.tile.y][s.tile.x] != "#", "on open ground")
	for d in z.decor:
		assert_ne(d.kind, ZoneDecor.Kind.ANIMAL, "no herd animals left")


func test_a_hero_close_by_never_starts_a_fight() -> void:
	hero.move.place(Vector2i(21, 20)) # right beside it
	_run(8.0)
	assert_eq(stag.state, Enemy.State.IDLE)
	assert_true(stag.threat.is_empty())
	assert_false(hero.in_combat(world.now))
	assert_eq(hero.hp, hero.stats.hp, "never attacked")


func test_it_wanders_and_grazes_near_its_spawn() -> void:
	hero.move.place(Vector2i(2, 2))
	var seen := {}
	var moved := false
	var still := false
	for i in 600: # 30 s
		world.step()
		seen[stag.tile()] = true
		if stag.move.vel.length() > 0.1:
			moved = true
		elif moved:
			still = true
		assert_lte(GridModel.distance(stag.tile(), stag.spawn_tile), def.wander_radius + 1)
	assert_true(moved, "it walked")
	assert_true(still, "and stood grazing between walks")
	assert_gt(seen.size(), 2)


func test_only_the_stag_that_is_hit_fights_back() -> void:
	hero.move.place(Vector2i(21, 20))
	_hurt(stag)
	assert_eq(stag.state, Enemy.State.COMBAT)
	assert_eq(other.state, Enemy.State.IDLE, "its neighbour stays neutral")
	_run(4.0)
	assert_lt(hero.hp, hero.stats.hp, "it attacks the one who hurt it")
	assert_true(other.threat.is_empty())


func test_it_bellows_once_when_it_turns_hostile() -> void:
	hero.move.place(Vector2i(21, 20))
	var aggro := []
	for i in 80: # 4 s of fighting, hit again and again
		if i % 10 == 0:
			var events: Array[Dictionary] = []
			AbilityResolver.deal_damage(world.ctx, hero, stag, &"test", 5.0, false, events)
			world._emit_resolved(events)
		for e in world.step():
			if e.type == "aggro":
				aggro.append(e)
	assert_eq(aggro.size(), 1, "one aggro for the fight, not one per hit")
	assert_eq(aggro[0].source, stag.id)
	assert_eq(aggro[0].target, hero.id)
	assert_eq(SoundCatalog.creature_key(&"stag", "aggro"), &"creature_stag_aggro")
	assert_true(ResourceLoader.exists("res://audio/sfx/creatures/creature_stag_aggro.wav"), "its bellow is in")


func test_it_resets_when_its_attacker_dies() -> void:
	hero.move.place(Vector2i(21, 20))
	_hurt(stag, 40.0)
	_run(0.5)
	var events: Array[Dictionary] = []
	AbilityResolver.deal_damage(world.ctx, stag, hero, &"test", 100000.0, false, events)
	world._emit_resolved(events) # as a real hit's events are handled
	world.step()
	assert_false(hero.alive)
	_run(6.0)
	assert_eq(stag.state, Enemy.State.IDLE, "neutral again")
	assert_eq(stag.hp, stag.stats.hp, "back to full health")


func test_it_resets_past_its_leash() -> void:
	hero.move.place(Vector2i(21, 20))
	_hurt(stag)
	assert_eq(def.leash_radius, 18, "x1.8 like every enemy")
	# The hero runs off; the stag gives up past its leash and walks home.
	var evaded := false
	for i in 1200:
		hero.move.place(Vector2i(mini(21 + i / 8, 58), 20))
		world.step()
		if stag.state == Enemy.State.EVADING:
			evaded = true
			assert_gt(GridModel.distance(stag.tile(), stag.home_tile), 15, "only once dragged far")
			break
	assert_true(evaded)
	_run(15.0)
	assert_eq(stag.state, Enemy.State.IDLE)
