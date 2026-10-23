extends GutTest
## Integration tests for WorldSim: intents, combat mode, AI, death and respawn.

var rules: CombatRules
var world: WorldSim
var a: Hero
var b: Hero
var enemy: Enemy
var enemy_def: EnemyDef
var hero_def: HeroDef


func _effect(kind: AbilityEffect.Kind, base: float, scaling: Array[AbilityScaling] = []) -> AbilityEffect:
	var e := AbilityEffect.new()
	e.kind = kind
	e.base_amount = base
	e.scaling = scaling
	return e


func _ability(id: StringName, target: AbilityDef.TargetType, effect: AbilityEffect,
		max_range: int, cooldown: float, mana: float = 0.0) -> AbilityDef:
	var ab := AbilityDef.new()
	ab.id = id
	ab.target = target
	ab.effects = [effect]
	ab.max_range = max_range
	ab.cooldown_seconds = cooldown
	ab.mana_cost = mana
	return ab


func _item(id: StringName, slot: EquipSlot.Type, teaches: Array[AbilityDef]) -> ItemDef:
	var i := ItemDef.new()
	i.id = id
	i.slot = slot
	i.teaches = teaches
	return i


func before_each() -> void:
	rules = CombatRules.new()
	var zone := ZoneDef.new()
	zone.id = &"test"
	var heights: PackedStringArray = []
	var walk: PackedStringArray = []
	for y in 12:
		heights.append("000000000000")
		walk.append("............")
	# A tall wall at x=5 on rows 5..7.
	for y in [5, 6, 7]:
		heights[y] = "000009000000"
		walk[y] = ".....#......"
	zone.height_rows = heights
	zone.walk_rows = walk
	zone.graveyards = [Vector2i(0, 11), Vector2i(11, 11)]
	zone.hero_spawns = [Vector2i(1, 1), Vector2i(1, 3)]

	enemy_def = EnemyDef.new()
	enemy_def.id = &"wolf"
	enemy_def.stats = StatBlock.make({Stat.Id.HP: 100, Stat.Id.PHYS_ATK: 10,
			Stat.Id.ACCURACY: 100, Stat.Id.JUMP: 1})
	enemy_def.abilities = [_ability(&"bite", AbilityDef.TargetType.ENEMY,
			_effect(AbilityEffect.Kind.DAMAGE, 10, [AbilityScaling.make(Stat.Id.PHYS_ATK, 1.0)]), 1, 2.0)]
	enemy_def.aggro_radius = 3
	enemy_def.leash_radius = 6
	enemy_def.xp_reward = 50
	enemy_def.respawn_seconds = 10.0
	var spawn := EnemySpawn.new()
	spawn.enemy = enemy_def
	spawn.tile = Vector2i(9, 1)
	zone.enemy_spawns = [spawn]

	var strike := _ability(&"strike", AbilityDef.TargetType.ENEMY,
			_effect(AbilityEffect.Kind.DAMAGE, 10, [AbilityScaling.make(Stat.Id.PHYS_ATK, 1.0)]), 1, 0.0)
	var heal := _ability(&"heal", AbilityDef.TargetType.ALLY, _effect(AbilityEffect.Kind.HEAL, 30), 4, 0.0, 5.0)
	var rez := _ability(&"resurrect", AbilityDef.TargetType.DEAD_ALLY,
			_effect(AbilityEffect.Kind.RESURRECT, 0), 4, 0.0, 10.0)
	var sword := _item(&"sword", EquipSlot.Type.MAIN_HAND, [strike])
	var charm := _item(&"charm", EquipSlot.Type.ACCESSORY, [heal, rez])
	var staff := _item(&"staff", EquipSlot.Type.MAIN_HAND, [])
	hero_def = HeroDef.new()
	hero_def.base_stats = StatBlock.make({Stat.Id.HP: 100, Stat.Id.MANA: 50,
			Stat.Id.PHYS_ATK: 20, Stat.Id.ACCURACY: 100, Stat.Id.JUMP: 2})
	hero_def.starting_items = [sword, charm, staff]
	hero_def.starting_equipment = [sword, charm]

	world = WorldSim.new(zone, rules, 42)
	enemy = world.enemies()[0]
	a = world.add_hero(hero_def)
	b = world.add_hero(hero_def)


func _types(events: Array) -> Array:
	return events.map(func(e): return e.type)


func _rejections(events: Array) -> Array:
	return events.filter(func(e): return e.type == "rejected").map(func(e): return e.reason)


func _place(actor: Actor, tile: Vector2i) -> void:
	actor.move.place(tile)


# --- Movement -------------------------------------------------------------------

func test_heroes_spawn_on_spawn_points() -> void:
	assert_eq(a.tile(), Vector2i(1, 1))
	assert_eq(b.tile(), Vector2i(1, 3))
	assert_eq(enemy.tile(), Vector2i(9, 1))


func test_walking_out_of_combat_chains_steps_with_no_cooldown() -> void:
	world.submit(a.id, {"type": "step", "to": Vector2i(2, 1)})
	world.step()
	assert_eq(a.tile(), Vector2i(2, 1))
	world.submit(a.id, {"type": "step", "to": Vector2i(3, 1)}) # sent mid-walk: buffered
	var events := world.advance(rules.walk_tile_seconds)
	assert_eq(_rejections(events), [])
	assert_eq(a.tile(), Vector2i(3, 1), "second step starts the moment the first arrives")


func test_step_rejections() -> void:
	_place(a, Vector2i(4, 6))
	world.submit(a.id, {"type": "step", "to": Vector2i(5, 6)})
	world.submit(b.id, {"type": "step", "to": Vector2i(3, 3)})
	var events := world.step()
	assert_eq(_rejections(events), ["blocked", "not_adjacent"])
	_place(b, Vector2i(4, 5))
	world.advance(1.0)
	world.submit(a.id, {"type": "step", "to": Vector2i(4, 5)})
	assert_eq(_rejections(world.step()), ["occupied"])


# --- Aggro and combat mode ---------------------------------------------------------

func test_hero_in_range_with_line_of_sight_aggros() -> void:
	_place(a, Vector2i(6, 1))
	var events := world.step()
	assert_has(_types(events), "aggro")
	assert_eq(enemy.state, Enemy.State.COMBAT)
	assert_true(a.in_combat(world.now))
	assert_false(b.in_combat(world.now))


func test_wall_blocks_aggro() -> void:
	_place(enemy, Vector2i(6, 6))
	enemy.spawn_tile = Vector2i(6, 6)
	_place(a, Vector2i(4, 6)) # 2 tiles away, behind the height-9 wall at x=5
	world.step()
	assert_eq(enemy.state, Enemy.State.IDLE)


func test_damage_pulls_an_idle_enemy() -> void:
	_place(a, Vector2i(8, 8))
	_place(enemy, Vector2i(9, 8))
	enemy.spawn_tile = Vector2i(9, 8)
	enemy_def.aggro_radius = 0
	world.submit(a.id, {"type": "cast", "ability": &"strike", "target": enemy.id})
	world.step()
	assert_eq(enemy.state, Enemy.State.COMBAT)
	assert_true(a.in_combat(world.now))


func test_enemy_chases_and_attacks_on_cooldown() -> void:
	_place(a, Vector2i(6, 1))
	world.advance(3.0)
	assert_eq(GridModel.distance(enemy.tile(), a.tile()), 1, "closed the gap")
	# bite: 10 + 10 = 20 per hit, on a 2s cooldown
	assert_lt(a.hp, 100.0)
	assert_eq(fmod(100.0 - a.hp, 20.0), 0.0, "only whole bites landed (no HP regen in combat)")


func test_step_cooldown_applies_in_combat() -> void:
	_place(a, Vector2i(6, 1))
	world.step()
	assert_true(a.in_combat(world.now))
	world.submit(a.id, {"type": "step", "to": Vector2i(6, 2)})
	world.step()
	world.advance(rules.walk_tile_seconds)
	world.submit(a.id, {"type": "step", "to": Vector2i(6, 3)})
	assert_eq(_rejections(world.step()), ["not_ready"], "arrived, but the combat step cooldown is running")
	var cd := StatCalc.combat_step_cooldown(a.current_stats(world.now).speed, rules)
	world.advance(cd - rules.walk_tile_seconds - 2 * rules.tick_seconds)
	world.submit(a.id, {"type": "step", "to": Vector2i(6, 3)})
	assert_eq(_rejections(world.step()), [])


func test_game_speed_scales_the_combat_step_cooldown() -> void:
	rules.combat_speed = 2.0
	_place(a, Vector2i(6, 1))
	world.step()
	world.submit(a.id, {"type": "step", "to": Vector2i(6, 2)})
	world.step()
	world.advance(rules.walk_tile_seconds)
	var cd := StatCalc.combat_step_cooldown(a.current_stats(world.now).speed, rules)
	assert_gt(cd / 2.0, rules.walk_tile_seconds, "(the test needs the walk to end first)")
	world.advance(cd / 2.0 - rules.walk_tile_seconds + rules.tick_seconds)
	world.submit(a.id, {"type": "step", "to": Vector2i(6, 3)})
	assert_eq(_rejections(world.step()), [], "twice as fast: half the step cooldown")


func test_slow_game_speed_lengthens_the_combat_step_cooldown() -> void:
	rules.combat_speed = 0.5
	_place(a, Vector2i(6, 1))
	world.step()
	world.submit(a.id, {"type": "step", "to": Vector2i(6, 2)})
	world.step()
	var cd := StatCalc.combat_step_cooldown(a.current_stats(world.now).speed, rules)
	world.advance(cd + rules.walk_tile_seconds)
	world.submit(a.id, {"type": "step", "to": Vector2i(6, 3)})
	assert_eq(_rejections(world.step()), ["not_ready"], "half as fast: double the step cooldown")
	world.advance(cd)
	world.submit(a.id, {"type": "step", "to": Vector2i(6, 3)})
	assert_eq(_rejections(world.step()), [])


func test_healer_joins_combat_by_healing() -> void:
	_place(a, Vector2i(6, 1))
	world.step()
	_place(b, Vector2i(6, 4))
	a.hp = 50
	world.submit(b.id, {"type": "cast", "ability": &"heal", "target": a.id})
	world.step()
	assert_true(enemy.threat.has(b.id))
	assert_true(b.in_combat(world.now))


func test_equipping_is_blocked_in_combat() -> void:
	world.submit(a.id, {"type": "equip", "bag_index": a.bag.index_of(hero_def.starting_items[2])})
	world.step()
	assert_eq(a.equipped_in(EquipSlot.Id.MAIN_HAND).id, &"staff", "allowed out of combat")
	_place(b, Vector2i(7, 1))
	world.step()
	world.submit(b.id, {"type": "equip", "bag_index": b.bag.index_of(hero_def.starting_items[2])})
	assert_eq(_rejections(world.step()), ["in_combat"])


# --- Leash -----------------------------------------------------------------------

func test_leash_resets_enemy_and_hero_leaves_combat() -> void:
	_place(a, Vector2i(6, 1))
	world.step()
	enemy.hp = 40
	_place(enemy, Vector2i(2, 1)) # dragged 7 tiles from spawn, past the leash of 6
	_place(a, Vector2i(1, 10))
	var events := world.step()
	assert_has(_types(events), "evade")
	assert_eq(enemy.state, Enemy.State.EVADING)
	assert_eq(enemy.hp, 100.0, "healed to full")
	assert_true(enemy.threat.is_empty())
	world.submit(a.id, {"type": "cast", "ability": &"strike", "target": enemy.id})
	_place(a, Vector2i(2, 2))
	assert_has(_rejections(world.step()), "invalid_target", "evading enemies can't be hit")
	world.advance(5.0)
	assert_eq(enemy.tile(), enemy.spawn_tile)
	assert_eq(enemy.state, Enemy.State.IDLE)
	assert_false(a.in_combat(world.now))


# --- Kills, XP, respawn ----------------------------------------------------------

func test_kill_splits_xp_between_heroes_on_threat_table() -> void:
	_place(enemy, Vector2i(5, 1))
	enemy.spawn_tile = Vector2i(5, 1)
	_place(a, Vector2i(4, 1))
	_place(b, Vector2i(6, 1))
	world.submit(a.id, {"type": "cast", "ability": &"strike", "target": enemy.id})
	world.submit(b.id, {"type": "cast", "ability": &"strike", "target": enemy.id})
	world.step()
	enemy.hp = 1
	world.advance(1.0)
	world.submit(a.id, {"type": "cast", "ability": &"strike", "target": enemy.id})
	var events := world.step()
	assert_has(_types(events), "death")
	assert_false(enemy.alive)
	assert_eq(a.xp, 25.0)
	assert_eq(b.xp, 25.0)


func test_enemy_respawns_after_timer() -> void:
	_place(a, Vector2i(8, 1))
	world.submit(a.id, {"type": "cast", "ability": &"strike", "target": enemy.id})
	enemy.hp = 1
	world.step()
	assert_eq(enemy.state, Enemy.State.DEAD)
	_place(a, Vector2i(1, 10))
	world.advance(9.5)
	assert_false(enemy.alive)
	var events := world.advance(0.6)
	assert_has(_types(events), "respawn")
	assert_eq(enemy.hp, 100.0)
	assert_eq(enemy.tile(), Vector2i(9, 1))


func test_kill_can_level_up() -> void:
	enemy_def.xp_reward = 250
	_place(a, Vector2i(8, 1))
	_place(b, Vector2i(1, 10))
	enemy.hp = 1
	world.submit(a.id, {"type": "cast", "ability": &"strike", "target": enemy.id})
	var events := world.step()
	assert_eq(a.level, 2)
	assert_has(_types(events), "level_up")


# --- Death, release, resurrection ---------------------------------------------------

func _kill(hero: Hero) -> void:
	hero.hp = 1
	_place(hero, Vector2i(8, 1))
	world.advance(2.5) # aggro, bite


func test_dead_hero_leaves_threat_table_and_enemy_resets() -> void:
	_kill(a)
	assert_false(a.alive)
	assert_false(enemy.threat.has(a.id))
	assert_ne(enemy.state, Enemy.State.COMBAT)


func test_release_respawns_at_nearest_graveyard_with_half_resources() -> void:
	_kill(a)
	world.submit(a.id, {"type": "release"})
	var events := world.step()
	assert_has(_types(events), "release")
	assert_true(a.alive)
	assert_eq(a.tile(), Vector2i(11, 11), "closer to (8,1) than (0,11)")
	assert_almost_eq(a.hp, 50.0, 0.5)
	assert_almost_eq(a.mana, 25.0, 0.5)


func test_release_leaves_combat() -> void:
	_kill(a)
	a.combat_until = world.now + 100.0 # as if still listed somewhere
	world.submit(a.id, {"type": "release"})
	world.step()
	assert_false(a.in_combat(world.now), "out of combat at the graveyard")
	assert_false(enemy.threat.has(a.id))


func test_release_rejected_while_alive_and_dead_cannot_act() -> void:
	world.submit(a.id, {"type": "release"})
	assert_eq(_rejections(world.step()), ["not_dead"])
	_kill(a)
	world.submit(a.id, {"type": "step", "to": a.tile() + Vector2i.LEFT})
	world.submit(a.id, {"type": "cast", "ability": &"strike", "target": enemy.id})
	assert_eq(_rejections(world.step()), ["dead", "caster_dead"])


func test_dead_heroes_do_not_block_tiles() -> void:
	_kill(a)
	assert_false(world.is_occupied(a.tile()))


func test_ally_resurrects_in_place() -> void:
	_kill(a)
	var corpse := a.tile()
	enemy_def.aggro_radius = 0 # keep the wolf next to the corpse from biting again
	_place(b, corpse + Vector2i(0, 3))
	world.submit(b.id, {"type": "cast", "ability": &"resurrect", "target": a.id})
	var events := world.step()
	assert_has(_types(events), "resurrect")
	assert_true(a.alive)
	assert_eq(a.tile(), corpse)
	assert_almost_eq(a.hp, 30.0, 0.5)


# --- Regen ---------------------------------------------------------------------

func test_regen_out_of_combat_and_in_combat() -> void:
	a.hp = 50
	a.mana = 0
	world.advance(1.0)
	assert_almost_eq(a.hp, 52.0, 0.01, "2% of 100 per second")
	assert_almost_eq(a.mana, 1.0, 0.01, "2% of 50 per second")
	b.mana = 0
	b.hp = 100
	_place(b, Vector2i(9, 4))
	world.step()
	enemy_def.abilities[0].cooldown_seconds = 1000.0 # stop biting
	enemy.cooldowns.trigger(enemy_def.abilities[0], world.now, 0.0)
	var hp_before := b.hp
	world.advance(2.0)
	assert_true(b.in_combat(world.now))
	assert_almost_eq(b.hp, hp_before, 0.01, "no HP regen in combat")
	assert_almost_eq(b.mana, 0.5 + 0.0125, 0.02, "0.5% of 50 per second")


# --- Misc ----------------------------------------------------------------------

func test_unknown_ability_and_intent_are_rejected() -> void:
	world.submit(a.id, {"type": "cast", "ability": &"meteor", "target": enemy.id})
	world.submit(a.id, {"type": "dance"})
	assert_eq(_rejections(world.step()), ["unknown_ability", "unknown_intent"])


func test_same_seed_and_intents_give_same_result() -> void:
	var results := []
	for run in 2:
		before_each()
		_place(a, Vector2i(6, 1))
		_place(b, Vector2i(6, 3))
		for i in 60:
			world.submit(a.id, {"type": "cast", "ability": &"strike", "target": enemy.id})
			world.submit(b.id, {"type": "cast", "ability": &"heal", "target": a.id})
			world.step()
		results.append([a.hp, b.mana, enemy.hp, enemy.tile(), enemy.threat.top()])
	assert_eq(results[0], results[1])


# --- Facing ----------------------------------------------------------------------

func test_steps_dont_turn_the_hero_and_face_turns_in_place() -> void:
	var facing := a.facing
	world.submit(a.id, {"type": "step", "to": a.tile() + Vector2i.RIGHT})
	world.step()
	assert_eq(a.facing, facing, "heroes face the mouse, not where they walk")
	world.advance(1.0)
	var tile := a.tile()
	world.submit(a.id, {"type": "face", "dir": Vector2i.UP})
	world.step()
	assert_eq(a.facing, Vector2i.UP)
	assert_eq(a.tile(), tile, "turning doesn't move")


func test_turning_is_free_in_combat() -> void:
	_place(a, Vector2i(6, 1))
	world.step()
	world.submit(a.id, {"type": "step", "to": Vector2i(6, 2)})
	world.step()
	world.submit(a.id, {"type": "face", "dir": Vector2i.LEFT})
	assert_eq(_rejections(world.step()), [], "no step cooldown for turning")
	assert_eq(a.facing, Vector2i.LEFT)


func test_bad_face_direction_is_rejected() -> void:
	world.submit(a.id, {"type": "face", "dir": Vector2i(1, 1)})
	assert_eq(_rejections(world.step()), ["bad_direction"])


# --- Bag intents ---------------------------------------------------------------------

func test_bag_intents_move_split_destroy() -> void:
	var staff_index := a.bag.index_of(hero_def.starting_items[2])
	world.submit(a.id, {"type": "move_item", "from": staff_index, "to": 10})
	world.step()
	assert_eq(a.bag.item_at(10), hero_def.starting_items[2])
	world.submit(a.id, {"type": "destroy_item", "index": 10})
	assert_has(_types(world.step()), "destroy_item")
	assert_null(a.bag.item_at(10))
	world.submit(a.id, {"type": "split_item", "index": 10, "count": 1})
	assert_eq(_rejections(world.step()), ["cannot_split"])


func test_unequip_into_bag_and_back() -> void:
	world.submit(a.id, {"type": "unequip", "slot": EquipSlot.Id.MAIN_HAND})
	world.step()
	assert_null(a.equipped_in(EquipSlot.Id.MAIN_HAND))
	var sword_index := a.bag.index_of(hero_def.starting_items[0])
	assert_gt(sword_index, -1)
	world.submit(a.id, {"type": "equip", "bag_index": sword_index})
	world.step()
	assert_eq(a.equipped_in(EquipSlot.Id.MAIN_HAND), hero_def.starting_items[0])


func test_aggroed_enemy_does_not_dart_two_tiles() -> void:
	enemy_def.combat_step_seconds = 0.8
	_place(a, Vector2i(6, 1)) # 3 tiles away: aggro
	var step_times: Array[float] = []
	var last := enemy.tile()
	for i in 40: # 2 s
		world.step()
		if enemy.tile() != last:
			step_times.append(world.now)
			last = enemy.tile()
	assert_gt(step_times.size(), 1)
	assert_gte(step_times[1] - step_times[0], 0.8 - 0.001, "second step waits for the step cooldown")


func test_combat_ends_as_soon_as_the_enemy_dies() -> void:
	_place(a, Vector2i(8, 1))
	world.step()
	assert_true(a.in_combat(world.now))
	enemy.hp = 1.0
	enemy.die()
	world._on_death(enemy)
	world.advance(0.1)
	assert_false(a.in_combat(world.now), "out of combat within 0.1 s")
