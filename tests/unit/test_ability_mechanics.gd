extends GutTest
## M2 mechanics: ARC and AROUND shapes, slow/root, heal over time, dash, flanking.

var rules: CombatRules
var world: WorldSim
var hero: Hero
var ally: Hero
var e1: Enemy
var e2: Enemy
var e3: Enemy
var dummy_def: EnemyDef


func _effect(kind: AbilityEffect.Kind, base: float) -> AbilityEffect:
	var e := AbilityEffect.new()
	e.kind = kind
	e.base_amount = base
	return e


func _ability(id: StringName, shape: AbilityDef.Shape, target: AbilityDef.TargetType, max_range: int,
		effects: Array[AbilityEffect]) -> AbilityDef:
	var a := AbilityDef.new()
	a.id = id
	a.shape = shape
	a.target = target
	a.max_range = max_range
	a.effects = effects
	a.on_gcd = false
	return a


func _buff(id: StringName, duration: float) -> BuffDef:
	var b := BuffDef.new()
	b.id = id
	b.duration_seconds = duration
	return b


func _hero(abilities: Array[AbilityDef]) -> Hero:
	var item := ItemDef.new()
	item.id = &"kit"
	item.slot = EquipSlot.Type.MAIN_HAND
	item.teaches = abilities
	var def := HeroDef.new()
	def.base_stats = StatBlock.make({Stat.Id.HP: 200, Stat.Id.ACCURACY: 100, Stat.Id.JUMP: 2})
	def.starting_items = [item]
	def.starting_equipment = [item]
	return world.add_hero(def)


func before_each() -> void:
	rules = CombatRules.new()
	var zone := ZoneDef.new()
	zone.id = &"flat"
	var rows: PackedStringArray = []
	var walk: PackedStringArray = []
	for y in 12:
		rows.append("0".repeat(12))
		walk.append(".".repeat(12))
	zone.height_rows = rows
	zone.walk_rows = walk
	zone.hero_spawns = [Vector2i(1, 1), Vector2i(1, 3)]
	world = WorldSim.new(zone, rules, 9)
	dummy_def = EnemyDef.new()
	dummy_def.stats = StatBlock.make({Stat.Id.HP: 1000})
	dummy_def.aggro_radius = 0
	e1 = world.add_enemy(dummy_def, Vector2i(6, 5))
	e2 = world.add_enemy(dummy_def, Vector2i(6, 6))
	e3 = world.add_enemy(dummy_def, Vector2i(6, 4))
	var cleave := _ability(&"cleave", AbilityDef.Shape.ARC, AbilityDef.TargetType.ENEMY, 1,
			[_effect(AbilityEffect.Kind.DAMAGE, 10)])
	var nova_root := _buff(&"frozen", 2.0)
	nova_root.roots = true
	var nova_fx := _effect(AbilityEffect.Kind.BUFF, 0)
	nova_fx.buff = nova_root
	var nova := _ability(&"nova", AbilityDef.Shape.AROUND, AbilityDef.TargetType.ENEMY, 1,
			[_effect(AbilityEffect.Kind.DAMAGE, 5), nova_fx])
	var roar_buff := _buff(&"rallied", 120.0)
	roar_buff.modifiers = [StatModifier.make(Stat.Id.PHYS_ATK, 1.2)]
	var roar_fx := _effect(AbilityEffect.Kind.BUFF, 0)
	roar_fx.buff = roar_buff
	var roar := _ability(&"roar", AbilityDef.Shape.AROUND, AbilityDef.TargetType.ALLY, 3, [roar_fx])
	var renew_fx := _effect(AbilityEffect.Kind.HEAL_OVER_TIME, 50)
	renew_fx.buff = _buff(&"renew", 5.0)
	var renew := _ability(&"renew", AbilityDef.Shape.TARGETED, AbilityDef.TargetType.ALLY, 4, [renew_fx])
	var dash := _ability(&"dash", AbilityDef.Shape.TARGETED, AbilityDef.TargetType.SELF, 0,
			[_effect(AbilityEffect.Kind.DASH, 2)])
	var stab := _ability(&"stab", AbilityDef.Shape.FRONT, AbilityDef.TargetType.ENEMY, 1,
			[_effect(AbilityEffect.Kind.DAMAGE, 100)])
	var bolt := _ability(&"bolt", AbilityDef.Shape.LINE, AbilityDef.TargetType.ENEMY, 5,
			[_effect(AbilityEffect.Kind.DAMAGE, 100)])
	hero = _hero([cleave, nova, roar, renew, dash, stab, bolt])
	ally = _hero([])
	hero.move.place(Vector2i(5, 5))
	hero.face(Vector2i.RIGHT)


func _cast(id: StringName, target: int = -1) -> Array[Dictionary]:
	world.submit(hero.id, {"type": "cast", "ability": id, "target": target})
	return world.step()


func _damaged(events: Array) -> Array:
	return events.filter(func(e): return e.type == "damage").map(func(e): return e.target)


# --- Shapes ---------------------------------------------------------------------

func test_arc_hits_the_front_tile_and_both_sides() -> void:
	# Facing right from (5,5): front (6,5), sides (6,4) and (6,6).
	var hit := _damaged(_cast(&"cleave"))
	hit.sort()
	var expected := [e1.id, e2.id, e3.id]
	expected.sort()
	assert_eq(hit, expected)


func test_arc_misses_what_is_behind() -> void:
	hero.face(Vector2i.LEFT)
	assert_true(_cast(&"cleave").any(func(e): return e.type == "whiff"))


func test_around_hits_every_adjacent_enemy_and_roots_them() -> void:
	hero.move.place(Vector2i(7, 5))
	e3.move.place(Vector2i(9, 9)) # far away
	var events := _cast(&"nova")
	var hit := _damaged(events)
	assert_true(hit.has(e1.id) and not hit.has(e3.id))
	assert_true(e1.buffs.is_rooted(world.now))
	assert_true(e1.threat.has(hero.id), "the debuff pulled it")


func test_around_ally_ability_includes_the_caster() -> void:
	ally.move.place(Vector2i(5, 7))
	_cast(&"roar")
	assert_true(hero.buffs.has(&"rallied", world.now))
	assert_true(ally.buffs.has(&"rallied", world.now))
	assert_false(e1.buffs.has(&"rallied", world.now), "enemies aren't rallied")
	assert_almost_eq(hero.buffs.remaining(&"rallied", world.now), 120.0, 0.1)


# --- Slow and root -------------------------------------------------------------

func test_root_blocks_steps_but_not_abilities() -> void:
	var root := _buff(&"root", 2.0)
	root.roots = true
	hero.buffs.apply(root, world.now)
	world.submit(hero.id, {"type": "step", "to": Vector2i(5, 6)})
	assert_true(world.step().any(func(e): return e.type == "rejected" and e.reason == "rooted"))
	assert_false(_damaged(_cast(&"stab")).is_empty(), "can still attack")
	world.advance(2.1)
	world.submit(hero.id, {"type": "step", "to": Vector2i(5, 6)})
	world.step()
	assert_eq(hero.tile(), Vector2i(5, 6), "free again")


func test_slow_multiplies_the_combat_step_cooldown() -> void:
	var slow := _buff(&"slow", 10.0)
	slow.step_cooldown_multiplier = 2.0
	hero.buffs.apply(slow, world.now)
	hero.combat_until = world.now + 100
	world.submit(hero.id, {"type": "step", "to": Vector2i(5, 6)})
	world.step()
	var normal := hero.combat_step_cooldown(rules, world.now)
	assert_almost_eq(hero.cooldowns.step_remaining(world.now), normal * 2.0, 0.06)


# --- Heal over time ----------------------------------------------------------------

func test_renew_heals_its_total_over_its_duration() -> void:
	ally.move.place(Vector2i(5, 7))
	ally.hp = 100
	var events := _cast(&"renew", ally.id)
	assert_almost_eq(ally.hp, 100.0, 0.5, "nothing up front (bar a tick of regen)")
	events.append_array(world.advance(5.2))
	var ticks := events.filter(func(e): return e.type == "heal" and e.target == ally.id)
	assert_eq(ticks.size(), 5, "one tick per second")
	var healed := 0.0
	for t in ticks:
		healed += t.amount
	assert_almost_eq(healed, 50.0, 0.5, "50 in total from Renew")


# --- Dash ---------------------------------------------------------------------------

func test_dash_moves_two_tiles_forward() -> void:
	hero.face(Vector2i.UP)
	_cast(&"dash")
	assert_eq(hero.tile(), Vector2i(5, 3))


func test_dash_stops_at_walls_and_actors() -> void:
	world.grid.set_tile(Vector2i(5, 3), 5, false)
	hero.face(Vector2i.UP)
	_cast(&"dash")
	assert_eq(hero.tile(), Vector2i(5, 4), "stopped before the wall")
	hero.face(Vector2i.RIGHT)
	var events := _cast(&"dash")
	assert_eq(hero.tile(), Vector2i(5, 4), "an enemy is in the way at (6,4)")
	assert_true(events.any(func(e): return e.type == "dash"))


# --- Flanking --------------------------------------------------------------------------

func _stab_from(attacker_tile: Vector2i, facing_of_target: Vector2i) -> Dictionary:
	e1.face(facing_of_target)
	e1.hp = 1000
	hero.move.place(attacker_tile)
	hero.face(e1.tile() - attacker_tile)
	var events := _cast(&"stab")
	world.advance(1.0)
	for e in events:
		if e.type == "damage":
			return e
	return {}


func test_flank_classification() -> void:
	var t := Vector2i(5, 5)
	assert_eq(CombatMath.flank(Vector2i(6, 5), t, Vector2i.RIGHT), CombatMath.Flank.FRONT)
	assert_eq(CombatMath.flank(Vector2i(4, 5), t, Vector2i.RIGHT), CombatMath.Flank.BEHIND)
	assert_eq(CombatMath.flank(Vector2i(5, 4), t, Vector2i.RIGHT), CombatMath.Flank.SIDE)
	assert_eq(CombatMath.flank(Vector2i(5, 6), t, Vector2i.RIGHT), CombatMath.Flank.SIDE)
	assert_eq(CombatMath.flank(Vector2i(9, 9), t, Vector2i.RIGHT), CombatMath.Flank.FRONT)


func test_side_and_behind_bonuses() -> void:
	e2.move.place(Vector2i(10, 10))
	e3.move.place(Vector2i(10, 11))
	var front := _stab_from(Vector2i(7, 5), Vector2i.RIGHT) # e1 at (6,5) facing the hero
	var side := _stab_from(Vector2i(6, 6), Vector2i.RIGHT) # (e2 was moved out below)
	var behind := _stab_from(Vector2i(5, 5), Vector2i.RIGHT)
	assert_eq(front.amount, 100.0)
	assert_eq(front.flank, "")
	assert_eq(behind.amount, 150.0)
	assert_eq(behind.flank, "behind")
	assert_eq(side.amount, 125.0)
	assert_eq(side.flank, "side")


func test_behind_never_misses_but_ranged_gets_no_flank_bonus() -> void:
	e2.move.place(Vector2i(10, 10))
	e3.move.place(Vector2i(10, 11))
	hero.stats.accuracy = -1000 # would always miss
	hero.base_stats.accuracy = -1000
	hero.refresh_stats()
	var behind := _stab_from(Vector2i(5, 5), Vector2i.RIGHT)
	assert_eq(behind.get("amount", 0.0), 150.0, "can't miss from behind")
	hero.base_stats.accuracy = 100
	hero.refresh_stats()
	e1.face(Vector2i.RIGHT)
	hero.move.place(Vector2i(2, 5))
	hero.face(Vector2i.RIGHT)
	var events := _cast(&"bolt") # no projectile speed: hits at once
	events.append_array(world.advance(1.0))
	var hit: Array = events.filter(func(e): return e.type == "damage")
	assert_eq(hit[0].flank, "", "projectiles don't flank")
