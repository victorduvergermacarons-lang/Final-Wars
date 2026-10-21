extends GutTest
## Balance targets for the ability-tree content (Milestone 3, CLAUDE.md decision 23),
## checked with scripted fights on the real WorldSim. If you retune content and
## this fails, either the tuning drifted or the targets need updating together.
## Full numbers: godot --headless --path . tests/balance/balance_report.tscn

const ContentDBScript := preload("res://autoload/content_db.gd")
const S := preload("res://tests/balance/balance_scenarios.gd")
const RUNS := 6

var db


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func _avg(specs: Array, enemy: StringName, count: int, level: int = 1) -> Dictionary:
	return BalanceSim.tree_average(db, specs, enemy, count, RUNS, level)


func test_starter_kit_beats_one_wolf_in_about_8s_with_half_hp() -> void:
	var r := _avg([S.STARTER], &"wolf", 1)
	assert_between(r.seconds, 6.5, 10.5, str(r))
	assert_between(r.hp_lost_pct, 35, 65, str(r))
	assert_eq(r.win_rate, 1.0, str(r))


func test_two_wolves_are_dangerous_solo_but_fine_for_a_pair() -> void:
	assert_lt(_avg([S.STARTER], &"wolf", 2).win_rate, 0.5)
	var pair := _avg([S.STARTER, S.STARTER_HEALER], &"wolf", 2)
	assert_eq(pair.win_rate, 1.0, str(pair))
	assert_lt(pair.hp_lost_pct, 75, str(pair))


func test_dodging_wind_ups_pays_off() -> void:
	var still := _avg([S.STARTER], &"wolf", 1)
	var dodging := _avg([S.STARTER_DODGE], &"wolf", 1)
	assert_lt(dodging.hp_lost_pct * 2, still.hp_lost_pct, "%s vs %s" % [dodging, still])


func test_single_weapon_builds_beat_a_wolf() -> void:
	for spec in [S.SWORD_ONLY, S.ARCHER, S.HAMMER]:
		var r := _avg([spec], &"wolf", 1)
		assert_gt(r.win_rate, 0.79, "%s: %s" % [spec.weapon, r])


func test_a_wolf_costs_a_caster_most_of_their_mana() -> void:
	var r := _avg([S.CASTER], &"wolf", 1)
	assert_eq(r.win_rate, 1.0, str(r))
	assert_lt(r.mana_left_pct, 40, str(r))


func test_level_2_caster_beats_a_shaman() -> void:
	var r := _avg([S.CASTER], &"goblin_shaman", 1, 2)
	assert_gt(r.win_rate, 0.79, str(r))


func test_brute_punishes_standing_still_but_heals_and_dodging_win() -> void:
	assert_lt(_avg([S.L3_SWORD], &"bandit_brute", 1, 3).win_rate, 0.5, "trading blows loses")
	var r := _avg([S.L3_SWORD_DODGE], &"bandit_brute", 1, 3)
	assert_eq(r.win_rate, 1.0, str(r))


func test_level_4_sword_beats_a_skirmisher() -> void:
	var r := _avg([S.L4_LUNGE], &"fen_skirmisher", 1, 4)
	assert_eq(r.win_rate, 1.0, str(r))


func test_grizzlehide_needs_a_group() -> void:
	assert_eq(_avg([S.L4_LUNGE], &"old_grizzlehide", 1, 5).win_rate, 0.0, "solo loses")
	assert_lt(_avg([S.L5_TANK, S.L5_HEALER], &"old_grizzlehide", 1, 5).win_rate, 0.34, "a pair mostly loses")
	var group := _avg([S.L5_TANK, S.L5_FIRE, S.L5_HEALER, S.L5_ARCHER], &"old_grizzlehide", 1, 5)
	assert_gt(group.win_rate, 0.8, str(group))


func test_salamander_hound_is_a_fair_level_2_fight() -> void:
	var r := _avg([S.STARTER], &"salamander_hound", 1, 2)
	print("Salamander Hound vs level-2 starter: ", r)
	assert_gt(r.win_rate, 0.8, "a level-2 starter beats it: " + str(r))
	assert_between(r.hp_lost_pct, 25, 85, "but it hurts: " + str(r))


## Retuned 2026-10-20 (harder hits, 5-tile body): bots that never dodge need level 7;
## a level-6 group that dodges the telegraphs should manage.
func test_sunscale_drake_needs_a_group() -> void:
	assert_eq(_avg([S.L4_LUNGE], &"sunscale_drake", 1, 7).win_rate, 0.0, "solo loses")
	assert_eq(_avg([S.L5_TANK, S.L5_HEALER], &"sunscale_drake", 1, 7).win_rate, 0.0, "a pair loses")
	var group := _avg([S.L5_TANK, S.L5_FIRE, S.L5_HEALER, S.L5_ARCHER], &"sunscale_drake", 1, 7)
	assert_eq(group.win_rate, 0.0, "it beats a level-7 group of four every time: " + str(group))
	var l10 := _avg([S.L5_TANK, S.L5_FIRE, S.L5_HEALER, S.L5_ARCHER], &"sunscale_drake", 1, 10)
	assert_gt(l10.win_rate, 0.0, "a level-10 group can win: " + str(l10))
