extends GutTest
## Wolves howl when they start a fight; idle wolves within 6 tiles join in.

var world: WorldSim
var hero: Hero
var wolf_def: EnemyDef


func before_each() -> void:
	var zone := ZoneDef.new()
	zone.id = &"plain"
	var rows: PackedStringArray = []
	var walk: PackedStringArray = []
	for y in 20:
		rows.append("0".repeat(20))
		walk.append(".".repeat(20))
	zone.height_rows = rows
	zone.walk_rows = walk
	zone.graveyards = [Vector2i(0, 0)]
	zone.hero_spawns = [Vector2i(0, 0)]
	world = WorldSim.new(zone, ContentDB.rules, 3)
	wolf_def = ContentDB.enemies[&"wolf"]
	var hd := HeroDef.new()
	hd.base_stats = StatBlock.make({Stat.Id.HP: 5000})
	hero = world.add_hero(hd)
	hero.move.place(Vector2i(2, 10))


func _run(seconds: float) -> Array:
	var events := []
	for i in roundi(seconds / world.rules.tick_seconds):
		events.append_array(world.step())
	return events


func test_spotting_wolf_howls_then_the_pack_joins() -> void:
	var spotter := world.add_enemy(wolf_def, Vector2i(5, 10)) # 3 tiles from the hero
	var near := world.add_enemy(wolf_def, Vector2i(10, 10)) # 5 from the spotter, 8 from the hero
	var far := world.add_enemy(wolf_def, Vector2i(5, 17)) # 7 from the spotter
	world.step()
	assert_eq(spotter.casting.get("ability").id, &"wolf_howl", "howls on spotting you")
	assert_eq(spotter.tile(), Vector2i(5, 10), "stands still to howl")
	assert_true(near.threat.is_empty(), "the pack hears it when the howl ends")
	var events := _run(1.0)
	assert_true(near.threat.has(hero.id), "a wolf 5 tiles away joins")
	assert_true(near.called_by_pack)
	assert_true(far.threat.is_empty(), "7 tiles is too far")
	assert_true(events.any(func(e): return e.type == "pack_called" and e.target == near.id))
	world.step()
	assert_true(near.casting.is_empty() or near.casting.ability.id != &"wolf_howl", "called wolves don't howl")


func test_a_wolf_hit_first_howls_too() -> void:
	var w := world.add_enemy(wolf_def, Vector2i(15, 15)) # out of aggro range
	w.threat.add(hero.id, 10.0) # as if hit by a long shot
	world.step()
	assert_eq(w.casting.get("ability").id, &"wolf_howl")


func test_an_interrupted_howl_calls_nobody() -> void:
	var spotter := world.add_enemy(wolf_def, Vector2i(5, 10))
	var near := world.add_enemy(wolf_def, Vector2i(10, 10))
	world.step()
	world.cancel_cast(spotter, "interrupted")
	_run(1.0)
	assert_true(near.threat.is_empty())


func test_howl_timing_comes_from_the_art() -> void:
	var howl: AbilityDef = wolf_def.howl_ability
	assert_almost_eq(howl.windup_seconds, 9.0 / 10.0, 0.0001, "9 frames at 10 fps")
	assert_eq(wolf_def.pack_call_radius, 6)


func test_the_howl_animation_plays_during_the_howl() -> void:
	var spotter := world.add_enemy(wolf_def, Vector2i(5, 10))
	world.step()
	var anim := CreatureAnimator.new()
	var pick := anim.pick(spotter, wolf_def.art, world.now)
	assert_eq(pick.anim, "howl")
