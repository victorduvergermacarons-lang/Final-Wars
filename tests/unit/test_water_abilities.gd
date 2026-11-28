extends GutTest
## The water abilities of the water physics pass (phase 4, 2026-11-28): what each
## does with the stance water. Water Whip's throw and return: test_water_pouch.gd.

var world: World
var sim: WorldSim
var hero: Hero


func before_each() -> void:
	ContentDB.rules.timing_bars_enabled = true
	ContentDB.rules.party_scaling = false
	world = World.new(ContentDB.zones.values(), ContentDB.rules, 5, &"town", ContentDB.quests)
	var data := CharacterData.new_character("Mira", ContentDB.heroes[&"adventurer"], ContentDB.elements[&"water"])
	hero = world.add_saved_hero(data, ContentDB)
	sim = world.zone_of(hero.id)
	for id in [&"W01", &"W02", &"W04", &"W07", &"W12"]:
		TreeRules.master(hero, ContentDB.abilities[id])
	hero.stance_tree = "Water"
	hero.stance = 1
	hero.stance_water = 24
	hero.mana = 999
	world.step()


func after_each() -> void:
	ContentDB.rules.party_scaling = true


func _heal_self() -> Array:
	world.submit(hero.id, {"type": "cast", "ability": &"W01", "target": hero.id})
	var events := world.step()
	events.append_array(world.advance(ContentDB.abilities[&"W01"].release_delay_seconds + 0.05))
	return events


# --- Healing Touch -----------------------------------------------------------------

func test_healing_touch_heals_half_again_after_1_2_s() -> void:
	var w01: AbilityDef = ContentDB.abilities[&"W01"]
	assert_null(w01.timing_bar, "no bar since 2026-11-28")
	assert_almost_eq(w01.effects[0].power, 1.5, 0.001, "+50% healing")
	assert_almost_eq(w01.release_delay_seconds, 1.2, 0.001, "lands 1.2 s after the cast")
	hero.hp = 10.0
	world.submit(hero.id, {"type": "cast", "ability": &"W01", "target": hero.id})
	world.step()
	assert_eq(hero.stance_water, 0, "the whole rope goes")
	world.advance(1.0)
	assert_almost_eq(hero.hp, 10.0, 15.0, "not yet (only regeneration)")
	world.advance(0.3)
	assert_gt(hero.hp, 30.0, "healed")


func test_at_full_health_all_the_water_comes_back() -> void:
	hero.hp = hero.current_stats(world.now).hp
	var events := _heal_self()
	var back: Array = events.filter(func(e): return e.type == "water_return")
	assert_eq(back.size(), 1)
	assert_almost_eq(float(back[0].share), 1.0, 0.001)
	assert_eq(hero.stance_water, 24)


func test_what_full_health_turns_away_comes_back() -> void:
	var w01: AbilityDef = ContentDB.abilities[&"W01"]
	var full := AbilityPower.amount(hero, w01, w01.effects[0], world.now, ContentDB.rules)
	var max_hp := hero.current_stats(world.now).hp
	hero.hp = max_hp - roundf(full / 4.0) # room for a quarter of the heal
	var events := _heal_self()
	var back: Array = events.filter(func(e): return e.type == "water_return")
	assert_eq(back.size(), 1)
	assert_almost_eq(float(back[0].share), 0.75, 0.05, "three quarters turned away")
	assert_almost_eq(hero.stance_water, 18, 1)


func test_a_short_rope_heals_less() -> void:
	var w01: AbilityDef = ContentDB.abilities[&"W01"]
	hero.cast_water.clear()
	var full := AbilityPower.amount(hero, w01, w01.effects[0], world.now, ContentDB.rules)
	hero.stance_water = 12
	var half := AbilityPower.amount(hero, w01, w01.effects[0], world.now, ContentDB.rules)
	assert_almost_eq(half / full, 0.6, 0.01, "0.2 + 0.8 × 12/24")


# --- Water Shield ------------------------------------------------------------------

func _shield_self() -> void:
	world.submit(hero.id, {"type": "cast", "ability": &"W12", "target": hero.id})
	world.step()
	world.advance(ContentDB.abilities[&"W12"].release_delay_seconds + 0.05)


func test_the_shield_takes_the_rope_and_goes_up_after_0_8_s() -> void:
	var w12: AbilityDef = ContentDB.abilities[&"W12"]
	assert_almost_eq(w12.release_delay_seconds, 0.8, 0.001)
	world.submit(hero.id, {"type": "cast", "ability": &"W12", "target": hero.id})
	world.step()
	assert_eq(hero.stance_water, 0, "the whole rope goes")
	assert_eq(int(hero.shield_out.points), 24)
	world.advance(w12.release_delay_seconds + 0.05)
	assert_gt(hero.buffs.shield_total(), 0.0)
	assert_almost_eq(float(hero.shield_out.left), 1.0, 0.001)


func test_a_short_rope_makes_a_weaker_shield() -> void:
	_shield_self()
	var full := hero.buffs.shield_total()
	hero.buffs.absorb(full + 1.0)
	world.advance(25.0)
	hero.stance_water = 12
	hero.cooldowns = Cooldowns.new()
	_shield_self()
	assert_almost_eq(hero.buffs.shield_total() / full, 0.6, 0.02, "0.2 + 0.8 × 12/24")


func test_broken_all_its_water_is_lost() -> void:
	_shield_self()
	var water := hero.stance_water + hero.water # the rope refills from the pouch meanwhile
	var wolf := sim.add_enemy(ContentDB.enemies[&"wolf"], hero.tile() + Vector2i(1, 0))
	var events: Array[Dictionary] = []
	AbilityResolver.deal_damage(sim.ctx, wolf, hero, &"test", hero.buffs.shield_total() + 5.0, false, events)
	for e in events:
		sim.emit(e)
	assert_true(hero.shield_out.is_empty(), "settled")
	world.advance(1.0)
	assert_eq(hero.stance_water + hero.water, water, "none of it came back")


func test_expired_what_is_left_comes_home() -> void:
	_shield_self()
	hero.buffs.absorb(hero.buffs.shield_total() * 0.25) # a quarter used
	hero.water = 100 # room in the pouch for what overflows the refilled rope
	var water := hero.stance_water + hero.water
	var events := world.advance(ContentDB.buffs[&"water_shield"].duration_seconds * 1.5)
	var back: Array = events.filter(func(e): return e.type == "water_return" and e.ability == &"W12")
	assert_eq(back.size(), 1)
	assert_almost_eq(float(back[0].share), 0.75, 0.02, "three quarters left")
	assert_eq(int(back[0].points), 18)
	assert_eq(hero.stance_water + hero.water, water + 18, "18 points home (the rope or the pouch)")
