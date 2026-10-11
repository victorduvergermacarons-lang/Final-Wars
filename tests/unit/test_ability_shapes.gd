extends GutTest
## FRONT and LINE abilities: geometry, resolution and projectiles in flight.

var rules: CombatRules
var world: WorldSim
var hero: Hero
var ally: Hero
var wolf: Enemy
var wolf2: Enemy


func _ability(id: StringName, shape: AbilityDef.Shape, max_range: int, base: float) -> AbilityDef:
	var a := AbilityDef.new()
	a.id = id
	a.shape = shape
	a.max_range = max_range
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
	var zone := ZoneDef.new()
	zone.id = &"flat"
	var rows: PackedStringArray = []
	var walk: PackedStringArray = []
	for y in 10:
		rows.append("0".repeat(12))
		walk.append(".".repeat(12))
	zone.height_rows = rows
	zone.walk_rows = walk
	zone.hero_spawns = [Vector2i(1, 1), Vector2i(1, 8)]
	var wolf_def := EnemyDef.new()
	wolf_def.stats = StatBlock.make({Stat.Id.HP: 1000})
	wolf_def.aggro_radius = 0
	world = WorldSim.new(zone, rules, 3)
	wolf = world.add_enemy(wolf_def, Vector2i(5, 5))
	wolf2 = world.add_enemy(wolf_def, Vector2i(7, 5))
	var strike := _ability(&"strike", AbilityDef.Shape.FRONT, 1, 10)
	strike.max_height_difference = 2
	var bolt := _ability(&"bolt", AbilityDef.Shape.LINE, 5, 30)
	bolt.projectile_speed = 10.0
	var zap := _ability(&"zap", AbilityDef.Shape.LINE, 5, 20)
	hero = _hero_with([strike, bolt, zap])
	ally = _hero_with([])
	hero.move.place(Vector2i(4, 5))
	hero.face(Vector2i.RIGHT)


func _cast(id: StringName) -> Array[Dictionary]:
	world.submit(hero.id, {"type": "cast", "ability": id, "target": -1})
	return world.step()


func _types(events: Array) -> Array:
	return events.map(func(e): return e.type)


func test_strike_hits_the_tile_in_front_without_a_target() -> void:
	var events := _cast(&"strike")
	assert_has(_types(events), "damage")
	assert_lt(wolf.hp, 1000.0)


func test_strike_whiffs_on_an_empty_tile_but_still_costs_the_gcd() -> void:
	hero.face(Vector2i.UP)
	var events := _cast(&"strike")
	assert_has(_types(events), "whiff")
	assert_eq(wolf.hp, 1000.0)
	assert_gt(hero.cooldowns.gcd_remaining(world.now), 0.0)


func test_strike_cannot_reach_far_above_or_below() -> void:
	world.grid.set_tile(Vector2i(5, 5), 3, true) # wolf now 3 levels up
	assert_has(_types(_cast(&"strike")), "whiff")
	world.grid.set_tile(Vector2i(5, 5), 2, true)
	world.advance(2.0)
	assert_has(_types(_cast(&"strike")), "damage", "2 levels is within reach")


func test_projectile_takes_time_to_arrive() -> void:
	wolf.move.place(Vector2i(8, 5)) # 4 tiles ahead; wolf2 at (7,5) is now nearer
	wolf2.move.place(Vector2i(0, 0))
	var events := _cast(&"bolt")
	assert_has(_types(events), "projectile")
	assert_eq(wolf.hp, 1000.0, "not hit at launch")
	world.advance(0.2)
	assert_eq(wolf.hp, 1000.0, "still flying after 2 tiles")
	world.advance(0.3)
	assert_lt(wolf.hp, 1000.0, "hit after ~0.4 s at 10 tiles/s")
	assert_eq(world.projectiles().size(), 0)


func test_projectile_stops_at_the_first_enemy() -> void:
	_cast(&"bolt")
	world.advance(1.0)
	assert_lt(wolf.hp, 1000.0)
	assert_eq(wolf2.hp, 1000.0, "the one behind is untouched")


func test_projectile_passes_through_allies() -> void:
	ally.move.place(Vector2i(5, 5))
	wolf.move.place(Vector2i(6, 5))
	_cast(&"bolt")
	world.advance(1.0)
	assert_eq(ally.hp, ally.stats.hp)
	assert_lt(wolf.hp, 1000.0)


func test_projectile_is_stopped_by_a_wall() -> void:
	world.grid.set_tile(Vector2i(5, 5), 5, false)
	wolf.move.place(Vector2i(6, 5))
	var events := _cast(&"bolt")
	events.append_array(world.advance(1.0))
	assert_eq(wolf.hp, 1000.0)
	var end: Array = events.filter(func(e): return e.type == "projectile_end")
	assert_eq(end.size(), 1)
	assert_eq(end[0].target, -1)


func test_projectile_expires_at_max_range() -> void:
	hero.face(Vector2i.UP)
	var events := _cast(&"bolt")
	events.append_array(world.advance(1.0))
	var end: Array = events.filter(func(e): return e.type == "projectile_end")
	assert_eq(end.size(), 1)
	assert_eq(end[0].tile, Vector2i(4, 0), "stopped at range 5 (4 tiles up is the map edge row 0)")


func test_projectile_hits_someone_who_steps_into_its_path() -> void:
	wolf.move.place(Vector2i(4, 8)) # off the line
	wolf2.move.place(Vector2i(0, 0))
	_cast(&"bolt")
	world.advance(0.05)
	wolf.move.place(Vector2i(8, 5)) # steps in front of it while it flies
	world.advance(1.0)
	assert_lt(wolf.hp, 1000.0)


func test_instant_line_ability_hits_immediately() -> void:
	var events := _cast(&"zap")
	assert_has(_types(events), "damage")


func test_wolf_turns_toward_the_hero_and_bites() -> void:
	var bite := _ability(&"bite", AbilityDef.Shape.FRONT, 1, 25)
	bite.cooldown_seconds = 2.0
	wolf.def.abilities = [bite]
	wolf.def.aggro_radius = 3
	wolf.def.stats.accuracy = 100
	wolf.face(Vector2i.UP) # looking away from the hero at (4,5)
	world.step()
	assert_eq(wolf.facing, Vector2i.LEFT, "turned toward the hero")
	assert_lt(hero.hp, hero.stats.hp, "and bit")


# --- Enemy speed and reaction delay ------------------------------------------------

func _bite_wolf(reaction: float) -> AbilityDef:
	var bite := _ability(&"bite", AbilityDef.Shape.FRONT, 1, 25)
	bite.cooldown_seconds = 2.0
	wolf.def.abilities = [bite]
	wolf.def.aggro_radius = 3
	wolf.def.stats.accuracy = 100
	wolf.def.reaction_seconds = reaction
	return bite


func test_enemy_combat_step_overrides_speed() -> void:
	wolf.def.combat_step_seconds = 0.8
	assert_eq(wolf.combat_step_cooldown(rules, 0.0), 0.8)
	assert_almost_eq(hero.combat_step_cooldown(rules, 0.0), rules.combat_step_base_seconds, 0.001)
	wolf.def.combat_step_seconds = 0.0
	assert_almost_eq(wolf.combat_step_cooldown(rules, 0.0), rules.combat_step_base_seconds, 0.001,
			"0 falls back to the Speed formula")


func test_wolf_chases_faster_than_a_hero_walks_in_combat() -> void:
	_bite_wolf(0.0)
	wolf.def.combat_step_seconds = 0.8
	wolf.move.place(Vector2i(8, 5))
	wolf2.move.place(Vector2i(0, 0))
	hero.move.place(Vector2i(5, 5)) # 3 tiles away
	world.step() # aggro, and the first step right away
	world.advance(0.85) # second step 0.8 s later; a hero would need 1.5 s per tile
	assert_eq(GridModel.distance(wolf.tile(), hero.tile()), 1)


func test_perceived_position_lags_by_the_reaction_delay() -> void:
	world.advance(1.0)
	var old := hero.tile()
	hero.move.place(old + Vector2i.DOWN)
	world.step()
	assert_eq(world.perceived_tile(hero, 0.3), old, "still seen at the old tile")
	assert_eq(world.perceived_tile(hero, 0.0), old + Vector2i.DOWN)
	world.advance(0.35)
	assert_eq(world.perceived_tile(hero, 0.3), old + Vector2i.DOWN, "caught up")


func test_sidestepping_just_before_a_bite_makes_it_whiff() -> void:
	var bite := _bite_wolf(0.3)
	wolf2.move.place(Vector2i(0, 0))
	hero.move.place(Vector2i(4, 5)) # adjacent, left of the wolf at (5,5)
	wolf.threat.add(hero.id, 1.0)
	wolf.state = Enemy.State.COMBAT
	wolf.cooldowns.trigger(bite, world.now, 0.0) # bite ready in 2 s
	world.advance(1.9)
	hero.move.place(Vector2i(4, 8)) # steps out of the way 0.1 s before the bite
	var events := world.advance(0.2)
	assert_has(_types(events), "whiff", "bit where the hero used to be")
	assert_eq(hero.hp, hero.stats.hp)


func test_without_reaction_delay_the_same_sidestep_is_too_late() -> void:
	var bite := _bite_wolf(0.0)
	wolf2.move.place(Vector2i(0, 0))
	hero.move.place(Vector2i(4, 5))
	wolf.threat.add(hero.id, 1.0)
	wolf.state = Enemy.State.COMBAT
	wolf.cooldowns.trigger(bite, world.now, 0.0)
	world.advance(1.9)
	hero.move.place(Vector2i(4, 8))
	var events := world.advance(0.2)
	assert_does_not_have(_types(events), "whiff", "it saw the move and didn't bite empty air")
