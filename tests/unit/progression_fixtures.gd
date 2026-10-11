extends RefCounted
## Shared builders for progression tests.


static func ability(id: StringName, ap_to_master: int) -> AbilityDef:
	var a := AbilityDef.new()
	a.id = id
	a.ap_to_master = ap_to_master
	a.effects = [AbilityEffect.new()]
	return a


static func item(id: StringName, slot: EquipSlot.Type, stats: Dictionary, growth: Dictionary,
		teaches: Array[AbilityDef] = []) -> ItemDef:
	var i := ItemDef.new()
	i.id = id
	i.slot = slot
	i.stats = StatBlock.make(stats)
	i.growth = StatBlock.make(growth)
	i.teaches = teaches
	return i


static func hero_with(items: Array[ItemDef]) -> Hero:
	var h := Hero.new(1, StatBlock.make({Stat.Id.HP: 100, Stat.Id.MANA: 50, Stat.Id.JUMP: 2}))
	h.inventory = items.duplicate()
	for i in items:
		h.equip(i)
	h.hp = h.stats.hp
	h.mana = h.stats.mana
	return h
