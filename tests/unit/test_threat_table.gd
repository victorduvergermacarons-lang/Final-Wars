extends GutTest

var t: ThreatTable


func before_each() -> void:
	t = ThreatTable.new()


func test_empty_table() -> void:
	assert_true(t.is_empty())
	assert_eq(t.top(), -1)


func test_add_accumulates_and_top_is_highest() -> void:
	t.add(1, 50)
	t.add(2, 30)
	t.add(2, 30)
	assert_eq(t.get_threat(2), 60.0)
	assert_eq(t.top(), 2)


func test_ties_go_to_first_added() -> void:
	t.add(7, 10)
	t.add(3, 10)
	assert_eq(t.top(), 7)


func test_negative_amounts_are_ignored_but_still_list_the_actor() -> void:
	t.add(4, -20)
	assert_true(t.has(4))
	assert_eq(t.get_threat(4), 0.0)


func test_taunt_puts_caster_on_top_with_lead() -> void:
	t.add(1, 100)
	t.add(2, 10)
	t.taunt(2, 10.0)
	assert_eq(t.top(), 2)
	assert_almost_eq(t.get_threat(2), 110.0, 0.0001)


func test_taunt_on_empty_table_still_lists_caster() -> void:
	t.taunt(5, 10.0)
	assert_eq(t.top(), 5)


func test_remove() -> void:
	t.add(1, 100)
	t.add(2, 10)
	t.remove(1)
	assert_eq(t.top(), 2)
	assert_false(t.has(1))
