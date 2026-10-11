extends GutTest

const ContentDBScript := preload("res://autoload/content_db.gd")

var db
var rules: CombatRules
var grid: GridModel
var hero: Hero
var ally: Hero
var wolf: Actor


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func before_each() -> void:
	rules = db.rules
	grid = GridModel.new(10, 10)
	hero = Hero.from_def(1, db.heroes[&"adventurer"])
	hero.move.place(Vector2i(2, 2))
	ally = Hero.from_def(2, db.heroes[&"adventurer"])
	ally.move.place(Vector2i(2, 4))
	wolf = Actor.new(3, Actor.Team.ENEMIES, StatBlock.make({Stat.Id.HP: 50}))
	wolf.move.place(Vector2i(3, 2))


func _a(id: StringName) -> AbilityDef:
	return db.abilities[id]


func test_pick_targets() -> void:
	assert_eq(Targeting.pick(hero, _a(&"strike"), wolf).target, wolf.id)
	assert_eq(Targeting.pick(hero, _a(&"strike"), null).error, "No enemy targeted")
	assert_eq(Targeting.pick(hero, _a(&"strike"), ally).error, "No enemy targeted")
	assert_eq(Targeting.pick(hero, _a(&"heal"), ally).target, ally.id)
	assert_eq(Targeting.pick(hero, _a(&"heal"), wolf).target, hero.id, "heal falls back to self")
	assert_eq(Targeting.pick(hero, _a(&"block"), wolf).target, hero.id, "self ability")
	assert_eq(Targeting.pick(hero, _a(&"resurrect"), ally).error, "Target a fallen ally")
	ally.die()
	assert_eq(Targeting.pick(hero, _a(&"resurrect"), ally).target, ally.id)


func test_usability_states() -> void:
	var U := Targeting.Usability
	assert_eq(Targeting.usability(hero, _a(&"strike"), wolf, grid, rules, 0.0), U.READY)
	assert_eq(Targeting.usability(hero, _a(&"strike"), null, grid, rules, 0.0), U.NO_TARGET)
	wolf.move.place(Vector2i(8, 8))
	assert_eq(Targeting.usability(hero, _a(&"strike"), wolf, grid, rules, 0.0), U.OUT_OF_RANGE)
	assert_eq(Targeting.usability(hero, _a(&"fireball"), wolf, grid, rules, 0.0), U.UNAVAILABLE, "staff not equipped")
	hero.mana = 0
	assert_eq(Targeting.usability(hero, _a(&"heal"), null, grid, rules, 0.0), U.NO_MANA)
	hero.mana = 100
	hero.cooldowns.trigger(_a(&"heal"), 0.0, rules.gcd_seconds)
	assert_eq(Targeting.usability(hero, _a(&"heal"), null, grid, rules, 0.5), U.COOLDOWN)
	hero.die()
	assert_eq(Targeting.usability(hero, _a(&"heal"), null, grid, rules, 5.0), U.DEAD)
