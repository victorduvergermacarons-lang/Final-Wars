extends GutTest
## Releasing after a Wolf kills you: you come back out of combat, and the Wolf
## doesn't "see" you at your death spot (it reacts to where you were 0.3 s ago).

const ContentDBScript := preload("res://autoload/content_db.gd")


func test_the_wolf_that_killed_you_does_not_chase_your_released_self() -> void:
	var db = ContentDBScript.new()
	var world := World.new(db.zones.values(), db.rules, 3, &"greenfields", db.quests)
	var hero := world.add_saved_hero(CharacterData.new_character("D", db.heroes[&"adventurer"]), db)
	var sim := world.zone_of(hero.id)
	var wolf: Enemy = sim.enemies().filter(func(e): return e.def.id == &"wolf")[0]
	hero.move.place(wolf.tile() + Vector2i(1, 0))
	hero.hp = 5
	for i in 200:
		world.step()
		if not hero.alive:
			break
	assert_false(hero.alive, "killed by the wolf")
	world.advance(2.0)
	world.submit(hero.id, {"type": "release"})
	world.step()
	for i in 60:
		world.step()
		assert_false(hero.in_combat(world.now), "out of combat after the release (tick %d)" % i)
	assert_false(wolf.threat.has(hero.id))
	db.free()
