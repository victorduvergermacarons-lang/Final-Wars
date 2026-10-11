extends GutTest


func test_every_stat_round_trips_through_get_and_set() -> void:
	var block := StatBlock.new()
	for id in Stat.all():
		block.set_stat(id, 10.0 + id)
	for id in Stat.all():
		assert_eq(block.get_stat(id), 10.0 + id, "stat %s" % Stat.property_of(id))


func test_property_table_matches_enum() -> void:
	assert_eq(Stat.PROPERTY.size(), Stat.COUNT)
	assert_eq(Stat.Id.size(), Stat.COUNT)
	var block := StatBlock.new()
	for id in Stat.all():
		assert_true(Stat.property_of(id) in block, "StatBlock has %s" % Stat.property_of(id))


func test_add_sums_in_place_and_supports_scale() -> void:
	var a := StatBlock.make({Stat.Id.HP: 100, Stat.Id.MAG_ATK: 5})
	var b := StatBlock.make({Stat.Id.HP: 20, Stat.Id.JUMP: 2})
	a.add(b, 0.5)
	assert_eq(a.hp, 110.0)
	assert_eq(a.mag_atk, 5.0)
	assert_eq(a.jump, 1.0)
	assert_eq(b.hp, 20.0, "source unchanged")


func test_add_null_is_noop() -> void:
	var a := StatBlock.make({Stat.Id.HP: 1})
	a.add(null)
	assert_eq(a.hp, 1.0)


func test_scaled_returns_new_block() -> void:
	var a := StatBlock.make({Stat.Id.SPEED: 10})
	var b := a.scaled(3.0)
	assert_eq(b.speed, 30.0)
	assert_eq(a.speed, 10.0)


func test_copy_is_independent() -> void:
	var a := StatBlock.make({Stat.Id.EVASION: 4})
	var b := a.copy()
	b.evasion = 99
	assert_eq(a.evasion, 4.0)
	assert_true(a.equals(StatBlock.make({Stat.Id.EVASION: 4})))


func test_dict_round_trip_omits_zeroes() -> void:
	var a := StatBlock.make({Stat.Id.CRIT_RATE: 5, Stat.Id.CRIT_DMG: 50})
	var d := a.to_dict()
	assert_eq(d.size(), 2)
	assert_true(StatBlock.from_dict(d).equals(a))


func test_from_dict_ignores_unknown_ids() -> void:
	var b := StatBlock.from_dict({-1: 5, 99: 5, Stat.Id.MANA: 7})
	assert_eq(b.mana, 7.0)
	assert_true(StatBlock.make({Stat.Id.MANA: 7}).equals(b))


func test_is_zero() -> void:
	assert_true(StatBlock.new().is_zero())
	assert_false(StatBlock.make({Stat.Id.JUMP: 1}).is_zero())
