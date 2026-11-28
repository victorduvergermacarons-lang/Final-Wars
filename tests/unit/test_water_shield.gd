extends GutTest
## Water Shield (W12, built 2026-11-25): an absorb shield on an ally, or on yourself
## when no ally is targeted; when the shield is used up it splashes the enemies
## around the shielded unit.

var world: World
var sim: WorldSim
var hero: Hero
var wolf: Enemy


func before_each() -> void:
	ContentDB.rules.timing_bars_enabled = false
	ContentDB.rules.party_scaling = false
	world = World.new(ContentDB.zones.values(), ContentDB.rules, 5, &"town", ContentDB.quests)
	hero = world.add_saved_hero(CharacterData.new_character("Rook", ContentDB.heroes[&"adventurer"]), ContentDB)
	sim = world.zone_of(hero.id)
	hero.mastered[&"W12"] = ContentDB.abilities[&"W12"]
	hero.mana = 999
	hero.stance_tree = "Water" # Water Shield draws on the stance water (2026-11-28)
	hero.stance = ContentDB.abilities[&"W12"].stance
	hero.stance_water = WaterBending.full(hero.stance)
	world.step()


func after_each() -> void:
	ContentDB.rules.timing_bars_enabled = true
	ContentDB.rules.party_scaling = true


func test_water_shield_is_built_and_self_cast_without_an_ally() -> void:
	var w12: AbilityDef = ContentDB.abilities[&"W12"]
	assert_true(w12.implemented)
	assert_eq(w12.target, AbilityDef.TargetType.ALLY)
	var picked := Targeting.pick(hero, w12, null)
	assert_eq(picked.error, "")
	assert_eq(picked.target, hero.id, "no target: on yourself")
	assert_eq(sim.cast(hero, w12, hero), AbilityResolver.Result.OK)
	assert_gt(hero.buffs.shield_total(), 0.0, "a shield")
	assert_eq(ContentDB.buffs[&"water_shield"].fx, &"water_shield", "its bubble shows")


func test_the_shield_splashes_adjacent_enemies_when_it_breaks() -> void:
	sim.cast(hero, ContentDB.abilities[&"W12"], hero)
	wolf = sim.add_enemy(ContentDB.enemies[&"wolf"], hero.tile() + Vector2i(1, 0))
	var far := sim.add_enemy(ContentDB.enemies[&"wolf"], hero.tile() + Vector2i(4, 0))
	var hp: float = wolf.hp
	var far_hp: float = far.hp
	var events: Array[Dictionary] = []
	AbilityResolver.deal_damage(sim.ctx, wolf, hero, &"test", hero.buffs.shield_total() + 5.0, false, events)
	assert_eq(hero.buffs.shield_total(), 0.0, "used up")
	assert_true(events.any(func(e): return e.type == "shield_break"))
	assert_lt(wolf.hp, hp, "the enemy beside it is splashed")
	assert_eq(far.hp, far_hp, "4 tiles away: not")
