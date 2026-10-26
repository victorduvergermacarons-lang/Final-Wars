extends GutTest
## Milestone 3 targeting: Targeted, Skillshot (instant / projectile / lob, any-angle
## and 8-way, pierce), Ground (telegraph), Self; the 100 ms grace window.

var rules: CombatRules
var world: WorldSim
var hero: Hero
var foe: Enemy
var foe2: Enemy


func before_each() -> void:
	rules = CombatRules.new()
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
	zone.hero_spawns = [Vector2i(5, 5)]
	var def := EnemyDef.new()
	def.id = &"dummy"
	def.stats = StatBlock.make({Stat.Id.HP: 1000, Stat.Id.EVASION: 200})
	def.aggro_radius = 0
	var s1 := EnemySpawn.new()
	s1.enemy = def
	s1.tile = Vector2i(8, 8)
	var s2 := EnemySpawn.new()
	s2.enemy = def
	s2.tile = Vector2i(10, 10)
	zone.enemy_spawns = [s1, s2]
	world = WorldSim.new(zone, rules, 3)
	foe = world.enemies()[0]
	foe2 = world.enemies()[1]
	var hd := HeroDef.new()
	hd.base_stats = StatBlock.make({Stat.Id.HP: 500, Stat.Id.MANA: 500, Stat.Id.MAG_ATK: 10})
	hero = world.add_hero(hd)


func _ability(mode: AbilityDef.TargetingMode, range_: int, kind := AbilityEffect.Kind.DAMAGE) -> AbilityDef:
	var a := AbilityDef.new()
	a.id = &"test"
	a.targeting = mode
	a.max_range = range_
	a.on_gcd = false
	var e := AbilityEffect.new()
	e.kind = kind
	e.base_amount = 10
	e.can_crit = false
	a.effects = [e] as Array[AbilityEffect]
	if kind == AbilityEffect.Kind.HEAL:
		a.target = AbilityDef.TargetType.ALLY
	return a


func _cast(a: AbilityDef, target: Actor = null, aim: Variant = null) -> Array:
	var r := world.cast(hero, a, target, aim)
	var events: Array = world._events.duplicate()
	events.append({"type": "result", "result": r})
	return events


func _hurt(actor: Actor) -> bool:
	return actor.hp < actor.stats.hp


func test_targeted_locks_on_and_cannot_miss() -> void:
	var a := _ability(AbilityDef.TargetingMode.TARGETED, 6)
	world.step()
	assert_eq(world.cast(hero, a, foe), AbilityResolver.Result.OK, "(8,8) is 6 away: diagonals count double")
	assert_true(_hurt(foe), "200 evasion doesn't matter: can't miss")
	assert_eq(world.cast(hero, a, foe2), AbilityResolver.Result.OUT_OF_RANGE)


func test_melee_does_not_reach_diagonally() -> void:
	var a := _ability(AbilityDef.TargetingMode.TARGETED, 1)
	foe.move.place(Vector2i(6, 6))
	assert_eq(world.cast(hero, a, foe), AbilityResolver.Result.OUT_OF_RANGE, "a diagonal neighbour is 2 away")
	foe.move.place(Vector2i(6, 5))
	assert_eq(world.cast(hero, a, foe), AbilityResolver.Result.OK)


func test_targeted_needs_line_of_sight() -> void:
	world.grid.set_tile(Vector2i(6, 6), 5, false)
	world.grid.set_tile(Vector2i(7, 7), 5, false)
	var a := _ability(AbilityDef.TargetingMode.TARGETED, 6)
	assert_eq(world.cast(hero, a, foe), AbilityResolver.Result.NO_LINE_OF_SIGHT)


func test_instant_skillshot_hits_the_first_unit_at_any_angle() -> void:
	var a := _ability(AbilityDef.TargetingMode.SKILLSHOT, 6)
	world.step()
	world.cast(hero, a, null, Vector2(8, 8))
	assert_true(_hurt(foe))
	assert_false(_hurt(foe2), "stopped at the first unit")
	foe.hp = foe.stats.hp
	a.pierce = true
	world.cast(hero, a, null, Vector2(8, 8))
	assert_true(_hurt(foe) and _hurt(foe2), "pierces through both")


func test_eight_way_snaps_and_walls_block() -> void:
	var a := _ability(AbilityDef.TargetingMode.SKILLSHOT, 6)
	a.aim = AbilityDef.Aim.EIGHT_WAY
	world.step()
	world.cast(hero, a, null, Vector2(9, 8)) # snaps to the diagonal
	assert_true(_hurt(foe))
	foe.hp = foe.stats.hp
	world.grid.set_tile(Vector2i(7, 7), 5, false)
	world.cast(hero, a, null, Vector2(8, 8))
	assert_false(_hurt(foe), "the wall stops the line")


func test_projectile_flies_and_can_be_dodged_but_has_a_grace_window() -> void:
	var a := _ability(AbilityDef.TargetingMode.SKILLSHOT, 6)
	a.projectile_speed = 2.0 # 1.5 s to reach (8,8)
	world.step()
	world.cast(hero, a, null, Vector2(8, 8))
	world.advance(0.5)
	foe.move.place(Vector2i(8, 9)) # sidestep in time
	world.advance(2.0)
	assert_false(_hurt(foe), "dodged")
	world.advance(1.0)
	world.cast(hero, a, null, Vector2(8, 9))
	world.advance(1.7) # it reaches (8,9) at 1.75 s
	foe.move.place(Vector2i(9, 9)) # too late: it was there within the last 100 ms
	world.advance(0.3)
	assert_true(_hurt(foe), "grace window")


func test_lob_lands_on_the_aimed_tile() -> void:
	var a := _ability(AbilityDef.TargetingMode.SKILLSHOT, 6)
	a.arc_seconds = 0.3
	world.grid.set_tile(Vector2i(6, 6), 3, false) # lobs go over obstacles
	world.step()
	world.cast(hero, a, null, Vector2(8, 8))
	assert_eq(world.pending_hits().size(), 1)
	world.advance(0.35)
	assert_true(_hurt(foe))
	foe.hp = foe.stats.hp
	world.cast(hero, a, null, Vector2(8, 8))
	foe.move.place(Vector2i(9, 9))
	world.advance(0.4)
	assert_false(_hurt(foe), "misses if the target moved")


func test_ground_telegraph_resolves_on_whoever_is_there() -> void:
	var a := _ability(AbilityDef.TargetingMode.GROUND, 8)
	a.area_radius = 1
	a.telegraph_seconds = 0.4
	world.step()
	assert_eq(world.cast(hero, a, null, Vector2(11, 11)), AbilityResolver.Result.OUT_OF_RANGE)
	world.cast(hero, a, null, Vector2(9, 9)) # 3x3 covers both dummies
	assert_false(_hurt(foe), "nothing happens until the telegraph ends")
	foe2.move.place(Vector2i(12, 12)) # steps out
	world.advance(0.45)
	assert_true(_hurt(foe))
	assert_false(_hurt(foe2))


func test_self_area_hits_all_eight_around() -> void:
	var a := _ability(AbilityDef.TargetingMode.SELF, 0)
	a.area_radius = 1
	foe.move.place(Vector2i(6, 6))
	foe2.move.place(Vector2i(5, 4))
	world.step()
	world.cast(hero, a, null)
	assert_true(_hurt(foe), "diagonal neighbour")
	assert_true(_hurt(foe2))
	assert_false(_hurt(hero))
	var heal := _ability(AbilityDef.TargetingMode.SELF, 0, AbilityEffect.Kind.HEAL)
	heal.area_radius = 1
	hero.hp = 100
	world.cast(hero, heal, null)
	assert_gt(hero.hp, 100.0, "ally areas include the caster")


func test_casting_turns_the_caster() -> void:
	var a := _ability(AbilityDef.TargetingMode.SKILLSHOT, 6)
	hero.face(Vector2i.LEFT)
	world.cast(hero, a, null, Vector2(5, 9))
	assert_eq(hero.facing, Vector2i.DOWN)


func test_aim_intent_and_dodge_warnings() -> void:
	assert_eq(Intents.sanitize({"type": "cast", "ability": "f03", "target": -1, "aim": Vector2(3.5, 2)}).aim, Vector2(3.5, 2))
	assert_eq(Intents.sanitize({"type": "cast", "ability": "f03", "target": -1, "aim": Vector2i(3, 2)}).aim, Vector2(3, 2))
	assert_eq(Intents.sanitize({"type": "cast", "ability": "f03", "target": -1, "aim": "here"}), {})
	var fast := _ability(AbilityDef.TargetingMode.SKILLSHOT, 4)
	fast.projectile_speed = 20.0
	var slow := _ability(AbilityDef.TargetingMode.GROUND, 4)
	slow.telegraph_seconds = 2.5
	var warnings := CastResolver.dodge_warnings([fast, slow], rules)
	assert_eq(warnings.size(), 1)
	assert_string_contains(warnings[0], "can't really be dodged")
