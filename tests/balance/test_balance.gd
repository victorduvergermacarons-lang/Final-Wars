extends GutTest
## Balance targets for milestone-1 content (CLAUDE.md rule 16), checked with
## scripted fights on the real WorldSim. If you retune content and this fails,
## either the tuning drifted or the targets need updating together.
## Full numbers: godot --headless --path . tests/balance/balance_report.tscn

const ContentDBScript := preload("res://autoload/content_db.gd")
const RUNS := 6

var db


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func test_sword_solo_vs_one_wolf_takes_about_8s_and_half_hp() -> void:
	var r := BalanceSim.average(db, [[&"sword", &"holy_charm"]], [&"strike"], 1, RUNS)
	assert_between(r.seconds, 6.5, 9.5, str(r))
	assert_between(r.hp_lost_pct, 35, 65, str(r))
	assert_eq(r.win_rate, 1.0, str(r))


func test_two_wolves_are_dangerous_solo_without_healing() -> void:
	var r := BalanceSim.average(db, [[&"sword", &"holy_charm"]], [&"strike"], 2, RUNS)
	assert_lt(r.win_rate, 0.5, str(r))


func test_two_wolves_are_fine_for_a_pair() -> void:
	var r := BalanceSim.average(db, [[&"sword", &"shield"], [&"staff", &"holy_charm"]],
			[&"strike", &"fireball"], 2, RUNS, 0.5)
	assert_eq(r.win_rate, 1.0, str(r))
	assert_lt(r.hp_lost_pct, 75, str(r))


func test_fireball_out_damages_strike_but_costs_mana() -> void:
	var staff_hero := Hero.from_def(1, db.heroes[&"adventurer"])
	staff_hero.unequip(EquipSlot.Id.MAIN_HAND)
	staff_hero.wear(db.items[&"staff"])
	var sword_hero := Hero.from_def(2, db.heroes[&"adventurer"])
	var fireball: AbilityDef = db.abilities[&"fireball"]
	var strike: AbilityDef = db.abilities[&"strike"]
	var fb := StatCalc.scaled_amount(fireball.effects[0].base_amount, fireball.effects[0].scaling, staff_hero.stats)
	var st := StatCalc.scaled_amount(strike.effects[0].base_amount, strike.effects[0].scaling, sword_hero.stats)
	assert_gt(fb, st * 1.5, "fireball %s vs strike %s" % [fb, st])
	assert_gt(fireball.mana_cost, 0.0)
	var r := BalanceSim.average(db, [[&"staff", &"holy_charm"]], [&"fireball"], 1, RUNS)
	assert_lt(r.mana_left_pct, 60, "one wolf costs a big share of the staff hero's mana: %s" % r)


func test_block_cuts_wolf_bites_by_at_least_a_fifth() -> void:
	var tank := Hero.from_def(1, db.heroes[&"adventurer"])
	tank.wear(db.items[&"shield"])
	var bite: AbilityDef = db.abilities[&"wolf_bite"]
	var raw := StatCalc.scaled_amount(bite.effects[0].base_amount, bite.effects[0].scaling, db.enemies[&"wolf"].stats)
	var k: float = db.rules.physical_defense_k
	var normal := raw * (1.0 - CombatMath.mitigation(tank.stats.phys_def, k))
	var blocked := raw * (1.0 - CombatMath.mitigation(tank.stats.phys_def * 2.0, k))
	assert_between(1.0 - blocked / normal, 0.2, 0.4, "normal %s, blocked %s" % [normal, blocked])


func test_level_2_after_two_wolves_and_first_mastery_at_level_3() -> void:
	var rules: CombatRules = db.rules
	var xp: int = db.enemies[&"wolf"].xp_reward
	assert_eq(int(Leveling.xp_to_next(1, rules)) / xp, 2, "wolves to level 2")
	var to_level_3 := Leveling.xp_to_next(1, rules) + Leveling.xp_to_next(2, rules)
	assert_eq(ceili(to_level_3 / xp), 6, "wolves to level 3")
	for id in [&"strike", &"fireball", &"heal", &"block"]:
		assert_eq(db.abilities[id].ap_to_master, rules.ap_per_level * 2, "%s mastered after 2 level-ups" % id)
	assert_eq(db.abilities[&"resurrect"].ap_to_master, rules.ap_per_level * 3)
