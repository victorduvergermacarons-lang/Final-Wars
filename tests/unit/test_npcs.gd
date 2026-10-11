extends GutTest
## Town NPCs: neutral, solid, talkable within range.

const ContentDBScript := preload("res://autoload/content_db.gd")

var db
var world: World
var hero: Hero
var town: WorldSim


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func before_each() -> void:
	world = World.new(db.zones.values(), db.rules, 1, &"town")
	hero = world.add_saved_hero(CharacterData.new_character("Zed", db.heroes[&"adventurer"]), db)
	town = world.zone(&"town")


func _npc(id: StringName) -> Npc:
	for n in town.npcs():
		if n.def.id == id:
			return n
	return null


func test_town_has_a_vendor_and_two_quest_givers() -> void:
	assert_eq(town.npcs().size(), 3)
	assert_not_null(_npc(&"hilda"))
	assert_not_null(_npc(&"rowan"))
	assert_not_null(_npc(&"maren"))


func test_npcs_are_neutral_and_solid() -> void:
	var rowan := _npc(&"rowan")
	assert_false(hero.is_hostile_to(rowan))
	assert_false(hero.is_ally_of(rowan))
	assert_true(town.is_occupied(rowan.tile()))


func test_npcs_cant_be_healed_or_struck() -> void:
	var rowan := _npc(&"rowan")
	hero.move.place(rowan.tile() + Vector2i.RIGHT)
	hero.face(Vector2i.LEFT)
	var heal: AbilityDef = db.abilities[&"heal"]
	assert_eq(AbilityResolver.validate(town.ctx, hero, heal, rowan), AbilityResolver.Result.INVALID_TARGET)
	assert_null(AbilityShapes.front_victim(town.ctx, hero, db.abilities[&"strike"]), "strike ignores NPCs")
	assert_eq(Targeting.pick(hero, heal, rowan).target, hero.id, "heal falls back to self")


func test_talking_needs_to_be_close() -> void:
	var hilda := _npc(&"hilda")
	world.submit(hero.id, {"type": "talk", "npc": hilda.id})
	var events := world.step()
	assert_true(events.any(func(e): return e.type == "rejected" and e.reason == "too_far"))
	hero.move.place(hilda.tile() + Vector2i(0, 2))
	world.submit(hero.id, {"type": "talk", "npc": hilda.id})
	events = world.step()
	var talk := events.filter(func(e): return e.type == "dialogue")
	assert_eq(talk.size(), 1)
	assert_eq(talk[0].def, &"hilda")


func test_npcs_are_in_snapshots_and_rebuilt_on_clients() -> void:
	var mirror := ClientWorld.new(town.zone, db.rules, db)
	mirror.local_hero_id = hero.id
	mirror.apply_snapshot(Snapshot.capture(town, hero.id))
	var npcs := mirror.actors().filter(func(a): return a is Npc)
	assert_eq(npcs.size(), 3)
	assert_eq(npcs.map(func(n): return n.def.id).has(&"maren"), true)


func test_enemies_ignore_npcs() -> void:
	var gf := world.zone(&"greenfields")
	var wolf: Enemy = gf.enemies()[0]
	var npc := Npc.new(999, db.npcs[&"maren"], wolf.tile() + Vector2i.LEFT)
	gf.ctx.add_actor(npc)
	gf.advance(1.0)
	assert_eq(wolf.state, Enemy.State.IDLE, "an NPC next to a wolf doesn't aggro it")
