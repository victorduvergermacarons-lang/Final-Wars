extends GutTest
## A guaranteed hit (AbilityDef.locks_on, the Foreman's Hurled Sunstone): a cast bar
## warns its target; once it starts the target can't run out of it or dodge it on
## Evasion; a stun or an interrupt still stops it.

var world: WorldSim
var foreman: Enemy
var hero: Hero


func before_each() -> void:
	var rules: CombatRules = ContentDB.rules.duplicate()
	rules.party_scaling = false
	world = WorldSim.new(ContentDB.zones[&"greenfields"], rules, 3)
	for e in world.enemies():
		world.remove_enemy(e.id)
	foreman = world.add_enemy(ContentDB.enemies[&"foreman"], Vector2i(3, 25)) # the open path
	hero = world.add_hero(ContentDB.heroes[&"adventurer"])
	hero.move.place(Vector2i(9, 25)) # within its 6 tiles, outside its aggro radius (5)
	hero.base_stats.hp = 5000.0
	hero.refresh_stats()
	hero.hp = hero.stats.hp
	world.step()


func _hurl() -> AbilityDef:
	return ContentDB.abilities[&"foreman_hurl"]


func test_it_shows_a_cast_bar_and_hits_after_it() -> void:
	assert_eq(world.cast(foreman, _hurl(), hero), AbilityResolver.Result.OK)
	assert_eq(foreman.casting.kind, "cast", "a cast bar every player sees")
	var hp := hero.hp
	world.advance(1.4)
	assert_eq(hero.hp, hp, "not before the bar ends")
	world.advance(0.2)
	assert_lt(hero.hp, hp)


func test_running_away_does_not_escape_it() -> void:
	world.cast(foreman, _hurl(), hero)
	hero.move.place(Vector2i(13, 27)) # beyond its 6 tiles
	var hp := hero.hp
	world.advance(1.6)
	assert_lt(hero.hp, hp, "locked on")


func test_evasion_does_not_dodge_it() -> void:
	hero.base_stats.evasion = 500.0 # every rolled hit is at its 50% floor
	hero.refresh_stats()
	var hurled := 0
	var picked := 0
	for i in 20:
		var events: Array[Dictionary] = []
		AbilityResolver.apply_effects(world.ctx, foreman, _hurl(), hero, events)
		hurled += events.filter(func(e): return e.type == "damage").size()
		events = []
		AbilityResolver.apply_effects(world.ctx, foreman, ContentDB.abilities[&"foreman_pick"], hero, events)
		picked += events.filter(func(e): return e.type == "damage").size()
	assert_eq(hurled, 20, "never misses")
	assert_lt(picked, 20, "his pick-hammer still rolls")


func test_an_interrupt_stops_it() -> void:
	world.cast(foreman, _hurl(), hero)
	world.cancel_cast(foreman, "interrupted")
	var hp := hero.hp
	world.advance(1.6)
	assert_eq(hero.hp, hp)


func test_the_foreman_uses_it_on_a_cooldown() -> void:
	assert_true(ContentDB.enemies[&"foreman"].abilities.has(_hurl()))
	assert_eq(_hurl().cooldown_seconds, 12.0)
	assert_true(_hurl().locks_on)
