extends GutTest
## World: several zones, map edges that lead into each other, per-zone state.

const ContentDBScript := preload("res://autoload/content_db.gd")

var db
var world: World
var hero: Hero


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func before_each() -> void:
	world = World.new(db.zones.values(), db.rules, 1, &"town")
	hero = world.add_saved_hero(CharacterData.new_character("Zed", db.heroes[&"adventurer"]), db)


func _walk_to(target: Vector2i) -> void:
	var sim := world.zone_of(hero.id)
	var path := Pathfinder.find_path(sim.grid, hero.tile(), target, 2, sim.occupied_tiles(hero), -1, 10000)
	assert_false(path.is_empty(), "path to %s" % target)
	for i in range(1, path.size()):
		world.submit(hero.id, {"type": "step", "to": path[i]})
		world.advance(db.rules.walk_tile_seconds + 0.05)


func test_heroes_start_in_town() -> void:
	assert_eq(world.zone_of(hero.id).zone.id, &"town")
	assert_true(world.zone(&"town").zone.hero_spawns.has(hero.tile()))


func test_ids_are_unique_across_zones() -> void:
	var seen := {}
	for z in world.zone_ids():
		for id in world.zone(z).ctx.actors:
			assert_false(seen.has(id), "id %d used twice" % id)
			seen[id] = true


## Millbrook's east edge (to Greenfields): its last column.
func _east() -> int:
	return world.zone(&"town").grid.width - 1


func test_walking_off_the_edge_moves_the_hero() -> void:
	_walk_to(Vector2i(_east(), 12))
	world.submit(hero.id, {"type": "step", "to": Vector2i(_east() + 1, 12)})
	var events := world.advance(0.3)
	assert_eq(world.zone_of(hero.id).zone.id, &"greenfields")
	assert_eq(hero.tile(), Vector2i(0, 25), "on the very edge of the next map, same row + offset")
	assert_null(world.zone(&"town").get_actor(hero.id), "gone from town")
	assert_true(events.any(func(e): return e.type == "zone_change" and e.to == &"greenfields"))
	# Intents now go to the new zone; stepping onto the edge tile itself doesn't bounce you back.
	world.submit(hero.id, {"type": "step", "to": Vector2i(1, 25)})
	world.advance(0.3)
	assert_eq(hero.tile(), Vector2i(1, 25))
	world.submit(hero.id, {"type": "step", "to": Vector2i(0, 25)})
	world.advance(0.3)
	assert_eq(world.zone_of(hero.id).zone.id, &"greenfields")


func test_any_edge_tile_works_and_back_again() -> void:
	for row in [1, 5, 16]:
		_walk_to(Vector2i(_east(), row))
		world.submit(hero.id, {"type": "step", "to": Vector2i(_east() + 1, row)})
		world.advance(0.3)
		assert_eq(world.zone_of(hero.id).zone.id, &"greenfields", "row %d" % row)
		assert_eq(hero.tile(), Vector2i(0, row + 13))
		world.submit(hero.id, {"type": "step", "to": Vector2i(-1, row + 13)})
		world.advance(0.3)
		assert_eq(world.zone_of(hero.id).zone.id, &"town")
		assert_eq(hero.tile(), Vector2i(_east(), row))


func test_edges_without_a_neighbour_are_walls() -> void:
	world.move_hero(hero.id, &"greenfields", Vector2i(5, 29))
	world.submit(hero.id, {"type": "step", "to": Vector2i(5, 30)}) # Greenfields' south edge leads nowhere
	var events := world.advance(0.3)
	assert_eq(world.zone_of(hero.id).zone.id, &"greenfields")
	assert_eq(hero.tile(), Vector2i(5, 29))
	assert_true(events.any(func(e): return e.type == "rejected" and e.reason == "blocked"))


func test_edges_are_refused_in_combat() -> void:
	_walk_to(Vector2i(_east(), 9))
	hero.combat_until = world.now + 100.0
	world.submit(hero.id, {"type": "step", "to": Vector2i(_east() + 1, 9)})
	var events := world.advance(0.3)
	assert_eq(world.zone_of(hero.id).zone.id, &"town")
	assert_true(events.any(func(e): return e.type == "rejected" and e.reason == "in_combat"))


func test_events_carry_their_zone() -> void:
	var events := world.advance(0.2)
	world.submit(hero.id, {"type": "cast", "ability": &"heal", "target": hero.id})
	events = world.step()
	assert_true(events.all(func(e): return e.zone == &"town"))


func test_snapshot_only_contains_the_viewers_zone() -> void:
	var snap := Snapshot.capture(world.zone_of(hero.id), hero.id)
	assert_eq(snap.zone, &"town")
	assert_eq(snap.actors.filter(func(d): return d.kind == Snapshot.KIND_ENEMY).size(), 0,
			"no wolves from Greenfields in the town snapshot")
	assert_eq(snap.actors.filter(func(d): return d.kind == Snapshot.KIND_HERO).size(), 1)


func test_release_uses_a_graveyard_in_the_same_zone() -> void:
	world.move_hero(hero.id, &"greenfields", Vector2i(2, 25))
	hero.die()
	world.submit(hero.id, {"type": "release"})
	world.step()
	assert_eq(world.zone_of(hero.id).zone.id, &"greenfields")
	assert_eq(hero.tile(), Vector2i(27, 14), "Greenfields' only graveyard")


func test_world_steps_all_zones_on_one_clock() -> void:
	world.advance(1.0)
	for z in world.zone_ids():
		assert_almost_eq(world.zone(z).now, world.now, 0.0001)
