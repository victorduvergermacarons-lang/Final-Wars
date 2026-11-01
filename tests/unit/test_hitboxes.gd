extends GutTest
## Free movement hitboxes (HitboxDef, Hitbox, HitboxResolver): shapes aimed at a
## point in continuous space, tested against round bodies.

var rules: CombatRules
var world: WorldSim
var hero: Hero
var ally: Hero
var wolf: Enemy
var wolf2: Enemy


func _ability(id: StringName, shape: HitboxDef.Shape, props: Dictionary, base := 10.0) -> AbilityDef:
	var a := AbilityDef.new()
	a.id = id
	a.max_range = 8
	a.targeting = AbilityDef.TargetingMode.SKILLSHOT
	var h := HitboxDef.new()
	h.shape = shape
	for k in props:
		h.set(k, props[k])
	a.hitbox = h
	var e := AbilityEffect.new()
	e.kind = AbilityEffect.Kind.DAMAGE
	e.base_amount = base
	a.effects = [e]
	return a


func _hero_with(abilities: Array[AbilityDef]) -> Hero:
	var item := ItemDef.new()
	item.id = &"kit"
	item.slot = EquipSlot.Type.MAIN_HAND
	item.teaches = abilities
	var def := HeroDef.new()
	def.base_stats = StatBlock.make({Stat.Id.HP: 100, Stat.Id.ACCURACY: 100, Stat.Id.JUMP: 2})
	def.starting_items = [item]
	def.starting_equipment = [item]
	return world.add_hero(def)


func before_each() -> void:
	rules = CombatRules.new()
	rules.party_scaling = false
	rules.timing_bars_enabled = false
	var zone := ZoneDef.new()
	zone.id = &"flat"
	var rows: PackedStringArray = []
	var walk: PackedStringArray = []
	for y in 12:
		rows.append("0".repeat(16))
		walk.append(".".repeat(16))
	zone.height_rows = rows
	zone.walk_rows = walk
	zone.hero_spawns = [Vector2i(1, 1), Vector2i(1, 10)]
	var wolf_def := EnemyDef.new()
	wolf_def.stats = StatBlock.make({Stat.Id.HP: 1000})
	wolf_def.aggro_radius = 0
	world = WorldSim.new(zone, rules, 3)
	wolf = world.add_enemy(wolf_def, Vector2i(6, 5))
	wolf2 = world.add_enemy(wolf_def, Vector2i(9, 5))
	var cone := _ability(&"cone", HitboxDef.Shape.CONE, {"reach": 1.5, "angle": 90.0})
	var line := _ability(&"line", HitboxDef.Shape.RECT, {"reach": 6.0, "width": 0.6, "pierce": true})
	var bolt := _ability(&"bolt", HitboxDef.Shape.PROJECTILE, {"reach": 8.0, "speed": 10.0, "size": 0.25})
	var spear := _ability(&"spear", HitboxDef.Shape.PROJECTILE, {"reach": 8.0, "speed": 10.0, "size": 0.25, "pierce": true})
	var blast := _ability(&"blast", HitboxDef.Shape.CIRCLE, {"reach": 6.0, "radius": 1.0})
	var nova := _ability(&"nova", HitboxDef.Shape.SELF_CIRCLE, {"radius": 2.5})
	hero = _hero_with([cone, line, bolt, spear, blast, nova])
	ally = _hero_with([])
	hero.move.place(Vector2i(5, 5))
	ally.move.place(Vector2i(5, 9))
	world.step()


func _cast(id: StringName, aim: Vector2) -> Array[Dictionary]:
	world.submit(hero.id, {"type": "cast", "ability": id, "target": -1, "aim": aim})
	return world.step()


func _run(seconds: float) -> void:
	for i in ceili(seconds / rules.tick_seconds):
		world.step()


# --- geometry ---

func test_cone_grazes_count() -> void:
	var o := Vector2.ZERO
	assert_true(Hitbox.in_cone(o, Vector2.RIGHT, 1.5, 90.0, Vector2(1, 0), 0.3))
	assert_true(Hitbox.in_cone(o, Vector2.RIGHT, 1.5, 90.0, Vector2(1, 1.1), 0.3), "the edge of the body inside")
	assert_false(Hitbox.in_cone(o, Vector2.RIGHT, 1.5, 90.0, Vector2(-1, 0), 0.3), "behind")
	assert_false(Hitbox.in_cone(o, Vector2.RIGHT, 1.5, 90.0, Vector2(2.0, 0), 0.3), "beyond reach + radius")


func test_rect_and_capsule() -> void:
	assert_true(Hitbox.in_rect(Vector2.ZERO, Vector2.RIGHT, 5.0, 0.6, Vector2(4, 0.5), 0.3))
	assert_false(Hitbox.in_rect(Vector2.ZERO, Vector2.RIGHT, 5.0, 0.6, Vector2(4, 0.7), 0.3))
	assert_true(Hitbox.in_capsule(Vector2.ZERO, Vector2(4, 4), 0.5, Vector2(2, 2.5), 0.3))
	assert_false(Hitbox.in_capsule(Vector2.ZERO, Vector2(4, 4), 0.2, Vector2(2, 3), 0.3))


func test_line_of_sight_and_clear_distance_stop_at_walls() -> void:
	var grid := GridModel.new(10, 3)
	grid.set_tile(Vector2i(5, 1), 0, false)
	grid.set_blocks_sight(Vector2i(5, 1), true)
	assert_false(Hitbox.has_los(grid, Vector2(1, 1), Vector2(8, 1), 0.5))
	assert_true(Hitbox.has_los(grid, Vector2(1, 0), Vector2(8, 0), 0.5))
	assert_almost_eq(Hitbox.clear_distance(grid, Vector2(1, 1), Vector2.RIGHT, 8.0, 0.5), 3.5, 0.11)


func test_outlines_and_tiles_inside() -> void:
	var circle := Hitbox.outline("circle", Vector2.ZERO, Vector2.RIGHT, 1.1, 0.0, Vector2(5, 5))
	var grid := GridModel.new(10, 10)
	var tiles := Hitbox.tiles_in(grid, circle)
	assert_eq(tiles.size(), 5, "centre + 4 neighbours within 1.1")
	var cone := Hitbox.outline("cone", Vector2(2, 2), Vector2.RIGHT, 2.0, 90.0)
	assert_eq(cone[0], Vector2(2, 2), "a cone starts at the caster")


# --- casting ---

func test_cone_hits_at_any_angle() -> void:
	var start := wolf.hp
	_cast(&"cone", Vector2(7, 5)) # wolf at (6, 5), one tile right
	assert_lt(wolf.hp, start, "in the cone")
	assert_eq(wolf2.hp, 1000.0, "out of reach")


func test_cone_misses_behind() -> void:
	_cast(&"cone", Vector2(3, 5))
	assert_eq(wolf.hp, 1000.0)


func test_piercing_line_hits_every_body_on_it() -> void:
	_cast(&"line", Vector2(10, 5))
	assert_lt(wolf.hp, 1000.0)
	assert_lt(wolf2.hp, 1000.0)


func test_a_projectile_flies_then_stops_at_the_first_body() -> void:
	_cast(&"bolt", Vector2(12, 5))
	assert_eq(wolf.hp, 1000.0, "not there yet")
	_run(1.0)
	assert_lt(wolf.hp, 1000.0)
	assert_eq(wolf2.hp, 1000.0, "stopped at the first")


func test_a_piercing_projectile_goes_through() -> void:
	_cast(&"spear", Vector2(12, 5))
	_run(1.0)
	assert_lt(wolf.hp, 1000.0)
	assert_lt(wolf2.hp, 1000.0)


func test_a_projectile_can_be_dodged() -> void:
	_cast(&"bolt", Vector2(12, 5))
	wolf2.move.place(Vector2i(9, 8))
	wolf.move.place(Vector2i(6, 8)) # stepped out of the path
	_run(1.5)
	assert_eq(wolf.hp, 1000.0)
	assert_eq(wolf2.hp, 1000.0)


func test_circle_lands_at_the_aim_pulled_back_to_reach() -> void:
	_cast(&"blast", Vector2(9, 5))
	assert_lt(wolf2.hp, 1000.0, "centred on the aim")
	assert_eq(wolf.hp, 1000.0, "3 tiles from the centre")
	var hp := wolf2.hp
	wolf2.move.place(Vector2i(15, 5))
	_run(3.0) # cooldown
	_cast(&"blast", Vector2(15, 5)) # 10 away: pulled back to 6, lands at (11, 5)
	assert_eq(wolf2.hp, hp, "out of reach, nothing there")


func test_self_circle_around_the_caster() -> void:
	ally.move.place(Vector2i(5, 6))
	var ally_hp := ally.hp
	_cast(&"nova", Vector2(5, 5))
	assert_lt(wolf.hp, 1000.0)
	assert_eq(wolf2.hp, 1000.0)
	assert_eq(ally.hp, ally_hp, "allies spared")


func test_aim_preview_outline_matches_the_shape() -> void:
	var p := AimPreview.preview(world.grid, rules, world.ctx.actors.values(), hero, hero.find_ability(&"cone"),
			Vector2(7, 5), null, world.now)
	assert_gt(p.outline.size(), 3)
	assert_eq(p.outline[0], hero.move.pos)
