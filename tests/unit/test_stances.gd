extends GutTest
## Stances (stance rework, 2026-11-23): a stance key enters a stance (the host keeps
## it, every player sees it), its branch abilities cast from it and the hero stays in
## it; Shift (stance 0), death and crowd control drop it; entering never starts the
## global cooldown; a stance's entry cast goes off as it is entered when ready.

var world: World
var sim: WorldSim
var hero: Hero
var wolf: Enemy


func before_each() -> void:
	ContentDB.rules.timing_bars_enabled = false
	world = World.new(ContentDB.zones.values(), ContentDB.rules, 5, &"town", ContentDB.quests)
	hero = world.add_saved_hero(CharacterData.new_character("Rook", ContentDB.heroes[&"adventurer"]), ContentDB)
	for id in [&"F01", &"F02", &"F03", &"W01", &"W02", &"E01", &"E04"]:
		hero.mastered[id] = ContentDB.abilities[id]
	hero.mana = hero.current_stats(0.0).mana
	hero.bag.add(ContentDB.items[Hero.WATER_POUCH]) # Water stances draw on the pouch
	hero.water = 200
	sim = world.zone_of(hero.id)
	for d in GridModel.DIRECTIONS:
		var t: Vector2i = hero.tile() + d
		if sim.grid.in_bounds(t) and sim.grid.is_walkable(t) and not sim.is_occupied(t) \
				and absi(sim.grid.height_at(t) - sim.grid.height_at(hero.tile())) <= 1:
			wolf = sim.add_enemy(ContentDB.enemies[&"wolf"], t)
			break
	wolf.threat.add(hero.id, 1.0)
	world.step()


func after_each() -> void:
	ContentDB.rules.timing_bars_enabled = true


func _stance(tree: String, n: int, target := -1) -> Array[Dictionary]:
	world.submit(hero.id, {"type": "stance", "tree": tree, "stance": n, "target": target})
	return world.step()


static func _of(events: Array, type: String) -> Array:
	return events.filter(func(e): return e.type == type)


func test_entering_a_stance_without_the_global_cooldown() -> void:
	_stance("Water", 1)
	assert_eq([hero.stance_tree, hero.stance], ["Water", 1])
	assert_eq(hero.cooldowns.gcd_remaining(world.now), 0.0, "entering doesn't start the global cooldown")
	var snap := Snapshot.capture(sim, hero.id)
	var mine: Dictionary = snap.actors.filter(func(a): return a.id == hero.id)[0]
	assert_eq(mine.stance[0], "Water", "every player sees it")
	assert_eq(mine.stance[1], 1)


func test_casting_keeps_the_stance_and_another_key_switches() -> void:
	_stance("Water", 1)
	hero.hp = 50
	world.submit(hero.id, {"type": "cast", "ability": &"W01", "target": hero.id})
	world.step()
	assert_lt(hero.cooldowns.ability_remaining(&"W01", world.now) - 0.0, 5.0)
	assert_gt(hero.cooldowns.gcd_remaining(world.now), 0.0, "casting starts the global cooldown")
	assert_eq([hero.stance_tree, hero.stance], ["Water", 1], "the hero stays in the stance")
	_stance("Fire", 1)
	assert_eq([hero.stance_tree, hero.stance], ["Fire", 1], "another stance key switches")
	_stance("", 0)
	assert_eq(hero.stance, 0, "Shift leaves")


func test_an_unknown_element_is_refused() -> void:
	world.submit(hero.id, {"type": "stance", "tree": "Air", "stance": 1, "target": -1})
	var events := world.step()
	assert_eq(hero.stance, 0, "no Air ability known")
	assert_true(_of(events, "rejected").any(func(e): return e.get("reason", "") == "unknown_element"))


func test_crowd_control_drops_the_stance() -> void:
	_stance("Water", 1)
	hero.buffs.apply(ContentDB.buffs[&"searing_dive_stun"], world.now, 0.0, wolf.id)
	world.step()
	assert_eq(hero.stance, 0, "a stun drops it")
	_stance("Water", 1)
	assert_eq(hero.stance, 0, "and it can't be taken up while stunned")
	world.advance(2.0)
	_stance("Water", 1)
	assert_eq(hero.stance, 1)
	sim.emit({"type": "pushed", "source": wolf.id, "target": hero.id})
	assert_eq(hero.stance, 0, "a knockback drops it")
	_stance("Water", 1)
	hero.hp = 0.0
	hero.die()
	world.step()
	assert_eq(hero.stance, 0, "death drops it")


func test_fire_1_throws_fire_punch_as_it_is_entered() -> void:
	var hp := wolf.hp
	var events := _stance("Fire", 1, wolf.id)
	assert_eq(hero.stance, 1)
	assert_lt(wolf.hp, hp, "Fire Punch went off")
	assert_true(_of(events, "cast").any(func(e): return e.ability == &"F01"))
	var cd := hero.cooldowns.ability_remaining(&"F01", world.now)
	assert_gt(cd, 0.0)
	_stance("Water", 1)
	world.advance(1.1) # past the global cooldown, Fire Punch still cooling down
	hp = wolf.hp
	events = _stance("Fire", 1, wolf.id)
	assert_eq([hero.stance_tree, hero.stance], ["Fire", 1], "on cooldown the key only enters the stance")
	assert_eq(wolf.hp, hp)
	assert_false(_of(events, "cast").any(func(e): return e.ability == &"F01"))


func test_earth_1_stomps_as_it_is_entered() -> void:
	var events := _stance("Earth", 1)
	assert_true(_of(events, "cast").any(func(e): return e.ability == &"E04"), "Seismic Stomp")
	assert_eq(hero.stance, 1)


func test_casting_a_bending_ability_from_elsewhere_takes_its_stance() -> void:
	world.submit(hero.id, {"type": "cast", "ability": &"W02", "target": wolf.id})
	world.step()
	assert_eq([hero.stance_tree, hero.stance], ["Water", 1], "an old action bar slot: Water Whip's stance")


func test_stance_abilities_by_key() -> void:
	assert_eq(WorldSim.stance_ability(ContentDB.abilities, "Water", 1, 1).id, &"W01", "1 then 1: Healing Touch")
	assert_eq(WorldSim.stance_ability(ContentDB.abilities, "Water", 1, 3).id, &"W12", "1 then 3: Water Shield")
	assert_eq(WorldSim.stance_ability(ContentDB.abilities, "Water", 4, 4).id, &"W19", "4 then 4: Bloodbending")
	assert_eq(WorldSim.stance_ability(ContentDB.abilities, "Fire", 1, 1).id, &"F02", "Fire 1 → 1: Fire Kick")


# --- Stance looks (what a held stance shows around the hero) ---

func _art() -> CreatureArtDef:
	return ContentDB.heroes[&"adventurer"].art


func test_every_stance_has_a_look_or_a_ring() -> void:
	var art := _art()
	var unapproved := []
	for tree in ["Fire", "Earth", "Water", "Air"]:
		for n in range(1, 6):
			var key := art.stance_look(tree, n)
			if key == "":
				unapproved.append("%s:%d" % [tree, n])
			elif key.begins_with("look:"):
				assert_true(art.looks.has(StringName(key.trim_prefix("look:"))), key)
			else:
				var fx: FxDef = ContentDB.effects.get(StringName(key))
				assert_not_null(fx, key)
				if fx != null:
					assert_not_null(fx.sheet, key)
	# The ones still waiting for approved art (a faint ring meanwhile).
	assert_eq(unapproved, ["Earth:5", "Water:1", "Water:4", "Air:1", "Air:2", "Air:4"])


func test_earth_stances_turn_more_of_the_body_to_stone() -> void:
	var art := _art()
	var last := 0.0
	for n in range(1, 5):
		var look := StringName(art.stance_look("Earth", n).trim_prefix("look:"))
		var cov := float(art.looks[look].get("coverage", 1.0))
		assert_gt(cov, last, "stance %d covers more than %d" % [n, n - 1])
		last = cov
	assert_eq(last, 1.0, "stance 4: all stone")


func test_held_stance_gives_its_items_and_a_ring_when_unapproved() -> void:
	var painter := FxPainter.new()
	var art_for := func(_a): return _art()
	sim.set_stance(hero, "Fire", 1)
	var items := painter.stance_items(1.0, [hero], ContentDB.effects, art_for)
	assert_eq(items.size(), 2, "the fire ring, split around the hero")
	assert_true(items[0].behind and not items[1].behind)
	assert_false(items[1].behind, "its front half goes in front of the hero")
	sim.set_stance(hero, "Air", 1)
	items = painter.stance_items(1.0, [hero], ContentDB.effects, art_for)
	assert_true(items.size() == 2 and items[0].has("ring"), "a faint ring until the art is approved")
	sim.set_stance(hero, "Earth", 2)
	assert_eq(painter.stance_items(1.0, [hero], ContentDB.effects, art_for).size(), 0, "stone is a body look")
	sim.set_stance(hero, "", 0)
	assert_eq(painter.stance_items(1.0, [hero], ContentDB.effects, art_for).size(), 0, "no stance, nothing")


func test_motion_comes_from_the_host_time_of_the_stance() -> void:
	var fx: FxDef = ContentDB.effects[&"stance_water_sphere"]
	var a: Dictionary = FxPainter.held_items(fx, 0.0, hero)[0]
	var b: Dictionary = FxPainter.held_items(fx, 0.5 / fx.motion_hz, hero)[0]
	assert_almost_eq((a.offset + b.offset).length(), 0.0, 0.001, "half a turn: the other side")
	assert_ne(a.behind, b.behind, "it passes behind the hero")
