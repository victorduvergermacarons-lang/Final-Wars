extends GutTest
## A targeted ability turns the caster toward its target when the cast begins and
## keeps that facing until it goes off (and a moment after, for its animation),
## even in combat where a hero otherwise faces the mouse, and even though the
## client sends the cursor point with every cast (2026-11-19 fix: Healing Touch on
## an ally faced the cursor).

var world: WorldSim
var healer: Hero
var ally: Hero
var foe: Enemy


func before_each() -> void:
	var zone := ZoneDef.new()
	zone.id = &"plain"
	var rows: PackedStringArray = []
	var walk: PackedStringArray = []
	for y in 30:
		rows.append("0".repeat(30))
		walk.append(".".repeat(30))
	zone.height_rows = rows
	zone.walk_rows = walk
	zone.graveyards = [Vector2i(0, 0)]
	zone.hero_spawns = [Vector2i(0, 0)]
	world = WorldSim.new(zone, ContentDB.rules, 3)
	healer = world.add_saved_hero(CharacterData.new_character("Mender", ContentDB.heroes[&"adventurer"],
			ContentDB.elements[&"water"]), ContentDB)
	ally = world.add_hero(ContentDB.heroes[&"adventurer"])
	healer.move.place(Vector2i(10, 10))
	ally.move.place(Vector2i(13, 10)) # due east (grid +x)
	# Something fighting the healer, so it's in combat (faces the mouse).
	var d := EnemyDef.new()
	d.id = &"post"
	d.immobile = true
	foe = world.add_enemy(d, Vector2i(25, 25))
	foe.state = Enemy.State.COMBAT
	foe.threat.add(healer.id, 1.0)
	world.step()
	assert_true(healer.in_combat(world.now))


## The mouse points west (grid -x), away from the ally.
func _mouse_west() -> void:
	world.submit(healer.id, {"type": "move", "dir": Vector2i.ZERO, "face": PI})
	world.step()


func test_healing_touch_faces_the_ally_until_it_goes_off() -> void:
	_mouse_west()
	assert_almost_eq(absf(healer.facing_angle), PI, 0.01, "in combat: faces the mouse")
	assert_true(healer.available_abilities().any(func(a): return a.id == &"W01"))
	# The cast carries the cursor point (west), as a client sends it.
	world.submit(healer.id, {"type": "cast", "ability": &"W01", "target": ally.id, "aim": Vector2(5, 10)})
	world.step()
	assert_false(healer.casting.is_empty(), "its timing bar runs")
	assert_almost_eq(healer.facing_angle, 0.0, 0.01, "turned toward the ally (east)")
	for i in 5:
		_mouse_west()
		assert_almost_eq(healer.facing_angle, 0.0, 0.01, "kept while casting, whatever the mouse")
	world.advance(healer.casting.end - world.now + 0.3) # the bar runs out: casts at miss power
	assert_true(healer.casting.is_empty(), "gone off")
	_mouse_west()
	if world.now - float(healer.anim.act_at) < Hero.FACE_HOLD_SECONDS:
		assert_almost_eq(healer.facing_angle, 0.0, 0.01, "held a moment for the cast animation")
	world.advance(Hero.FACE_HOLD_SECONDS)
	_mouse_west()
	assert_almost_eq(absf(healer.facing_angle), PI, 0.01, "then back to the mouse")


func test_the_turn_is_exact_for_eight_facings() -> void:
	ally.move.place(Vector2i(13, 13)) # grid diagonal: straight down the screen
	world.submit(healer.id, {"type": "cast", "ability": &"W01", "target": ally.id, "aim": Vector2(5, 10)})
	world.step()
	assert_almost_eq(healer.facing_angle, PI / 4.0, 0.01)
	var art: CreatureArtDef = ContentDB.heroes[&"adventurer"].art
	assert_eq(art.direction_for_angle(healer.facing_angle, healer.facing), "s")
