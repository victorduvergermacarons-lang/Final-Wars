extends GutTest

var block: BuffDef
var buffs: ActiveBuffs


func before_each() -> void:
	block = BuffDef.new()
	block.id = &"block"
	block.duration_seconds = 6.0
	block.modifiers = [StatModifier.make(Stat.Id.PHYS_DEF, 2.0)]
	buffs = ActiveBuffs.new()


func test_block_doubles_physical_defense() -> void:
	var base := StatBlock.make({Stat.Id.PHYS_DEF: 40, Stat.Id.MAG_DEF: 10})
	buffs.apply(block, 0.0)
	var s := buffs.modify(base, 1.0)
	assert_eq(s.phys_def, 80.0)
	assert_eq(s.mag_def, 10.0)
	assert_eq(base.phys_def, 40.0, "input untouched")


func test_buff_expires() -> void:
	buffs.apply(block, 0.0)
	assert_true(buffs.has(&"block", 5.9))
	assert_false(buffs.has(&"block", 6.0))
	assert_eq(buffs.modify(StatBlock.make({Stat.Id.PHYS_DEF: 40}), 6.0).phys_def, 40.0)
	assert_eq(buffs.expire(6.0), [&"block"] as Array[StringName])
	assert_eq(buffs.to_dict().size(), 0)


func test_reapply_refreshes_without_stacking() -> void:
	buffs.apply(block, 0.0)
	buffs.apply(block, 4.0)
	assert_almost_eq(buffs.remaining(&"block", 5.0), 5.0, 0.0001)
	assert_eq(buffs.modify(StatBlock.make({Stat.Id.PHYS_DEF: 10}), 5.0).phys_def, 20.0)


func test_flat_bonuses_apply_before_multipliers() -> void:
	var fort := BuffDef.new()
	fort.id = &"fort"
	fort.modifiers = [StatModifier.make(Stat.Id.PHYS_DEF, 1.0, 10.0)]
	buffs.apply(block, 0.0)
	buffs.apply(fort, 0.0)
	assert_eq(buffs.modify(StatBlock.make({Stat.Id.PHYS_DEF: 20}), 1.0).phys_def, 60.0)
