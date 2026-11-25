extends GutTest

var t: ThreatTable


func before_each() -> void:
	t = ThreatTable.new()


func test_empty_table() -> void:
	assert_true(t.is_empty())
	assert_eq(t.target(), -1)


func test_add_accumulates_and_top_is_highest() -> void:
	t.add(1, 50)
	t.add(2, 30)
	t.add(2, 30)
	assert_eq(t.get_threat(2), 60.0)
	assert_eq(t.target(), 2)


func test_ties_go_to_first_added() -> void:
	t.add(7, 10)
	t.add(3, 10)
	assert_eq(t.target(), 7)


func test_negative_amounts_are_ignored_but_still_list_the_actor() -> void:
	t.add(4, -20)
	assert_true(t.has(4))
	assert_eq(t.get_threat(4), 0.0)


func test_taunt_puts_caster_on_top_with_lead() -> void:
	t.add(1, 100)
	t.add(2, 10)
	t.taunt(2, 10.0)
	assert_eq(t.target(), 2)
	assert_almost_eq(t.get_threat(2), 110.0, 0.0001)


func test_taunt_on_empty_table_still_lists_caster() -> void:
	t.taunt(5, 10.0)
	assert_eq(t.target(), 5)


func test_remove() -> void:
	t.add(1, 100)
	t.add(2, 10)
	t.remove(1)
	assert_eq(t.target(), 2)
	assert_false(t.has(1))


# --- Overtaking (110% in melee, 130% at range) and forced taunts ---------------------

const MELEE := 110.0
const RANGED := 130.0


func _update(now: float = 0.0, melee: Array = []) -> int:
	return t.update(now, MELEE, RANGED, func(id): return melee.has(id))


func test_the_target_holds_until_overtaken_by_110_percent_in_melee() -> void:
	t.add(1, 100)
	assert_eq(_update(), 1)
	t.add(2, 105)
	assert_eq(_update(0.0, [2]), 1, "more threat, but not 110%")
	t.add(2, 5) # 110: not above
	assert_eq(_update(0.0, [2]), 1, "exactly 110% isn't enough")
	t.add(2, 1) # 111
	assert_eq(_update(0.0, [2]), 2, "above 110% in melee range")


func test_at_range_it_takes_130_percent() -> void:
	t.add(1, 100)
	_update()
	t.add(2, 125)
	assert_eq(_update(), 1, "125% at range isn't enough")
	assert_eq(_update(0.0, [2]), 2, "the same threat in melee range is")
	t.clear()
	t.add(1, 100)
	_update()
	t.add(3, 131)
	assert_eq(_update(), 3)


func test_of_several_overtakers_the_most_threat_wins_ties_first_added() -> void:
	t.add(1, 100)
	_update()
	t.add(2, 140)
	t.add(3, 140)
	assert_eq(_update(), 2)


func test_falls_back_to_the_highest_when_the_target_leaves() -> void:
	t.add(1, 100)
	_update()
	t.add(2, 50)
	t.add(3, 90)
	t.remove(1)
	assert_eq(_update(), 3, "highest of who's left, no overtake needed")


func test_taunt_forces_the_target_for_its_seconds() -> void:
	t.add(1, 100)
	_update()
	t.taunt(2, 10.0, 0.0, 3.0)
	assert_eq(_update(0.1), 2)
	t.add(1, 1000) # far above 130%
	assert_eq(_update(2.9), 2, "forced: no overtaking for 3 s")
	assert_true(t.is_forced(2.9))
	assert_false(t.is_forced(3.0))
	assert_eq(_update(3.0), 1, "then the threat decides again")


func test_taunt_lead_usually_keeps_the_taunter_after_the_forced_time() -> void:
	t.add(1, 100)
	_update()
	t.taunt(2, 10.0, 0.0, 3.0) # 110, the leader stays at 100
	t.add(1, 15) # 115: not above 110 × 110%
	assert_eq(_update(5.0, [1]), 2)


func test_forced_time_ends_early_when_the_taunter_leaves() -> void:
	t.add(1, 100)
	t.add(3, 50)
	_update()
	t.taunt(2, 10.0, 0.0, 3.0)
	t.remove(2) # died or left
	assert_false(t.is_forced(1.0))
	assert_eq(_update(1.0), 1)


func test_a_second_taunt_restarts_the_forced_time() -> void:
	t.add(1, 100)
	t.taunt(2, 10.0, 0.0, 3.0)
	t.taunt(2, 10.0, 2.0, 3.0)
	assert_true(t.is_forced(4.5))
	t.taunt(3, 10.0, 4.6, 3.0) # another taunter takes over
	assert_eq(_update(4.7), 3)
	assert_true(t.is_forced(7.5))


func test_clear_forgets_target_and_taunt() -> void:
	t.add(1, 100)
	t.taunt(2, 10.0, 0.0, 3.0)
	t.clear()
	t.add(5, 1)
	assert_eq(_update(1.0), 5)
