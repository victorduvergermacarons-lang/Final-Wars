class_name TreeContent
extends RefCounted
## Builds the game's AbilityDefs and ItemDefs for the ability trees from the
## imported spreadsheet data (AbilityTreeData) plus, per ability, optional
## hand-written behavior in content/tree/behaviors/<ID>.tres (an AbilityDef with
## shape, effects, ranges…). Abilities without behavior are marked unimplemented.

const BEHAVIOR_DIR := "res://content/tree/behaviors"


## {"abilities": {id: AbilityDef}, "items": {id: ItemDef}}.
static func build(data: AbilityTreeData, tuning: TreeTuning, behavior_dir: String = BEHAVIOR_DIR) -> Dictionary:
	var abilities := {}
	var items := {}
	for id in data.ids():
		var row: Dictionary = data.ability(id)
		var path := "%s/%s.tres" % [behavior_dir, id]
		var ability: AbilityDef
		if ResourceLoader.exists(path):
			ability = (load(path) as AbilityDef).duplicate(true)
			ability.implemented = true
		else:
			ability = AbilityDef.new()
			ability.implemented = false
		ability.id = id
		ability.display_name = row.name
		ability.description = row.effect
		ability.tree = row.tree
		ability.tier = row.tier
		ability.cooldown_seconds = float(row.cooldown)
		ability.ap_to_master = tuning.ap_for(row.tier)
		if row.has("mana_cost"):
			ability.mana_cost = float(row.mana_cost)
		ability.sheet = row
		_apply_timing(ability, row.get("timing", {}))
		abilities[id] = ability

		var item := ItemDef.new()
		item.id = StringName(row.item_id)
		item.display_name = row.taught_by
		item.tree = row.tree
		item.tier = row.tier
		item.is_scroll = row.item_type == "Scroll"
		item.rarity = tuning.rarity_for(row.tier)
		item.price = tuning.price_for(row.tier, item.is_scroll)
		item.description = "Teaches %s (%s, tier %d)." % [row.name, row.tree, row.tier]
		if item.is_scroll:
			item.slot = EquipSlot.Type.NONE
			item.growth = tuning.scroll_growth(row.tree, row.tier)
		else:
			item.slot = EquipSlot.Type.MAIN_HAND if row.item_type == "Sword" else EquipSlot.Type.TWO_HAND
			var blocks := tuning.weapon_blocks(row.item_type, row.tier)
			item.stats = blocks[0]
			item.growth = blocks[1]
		var teaches: Array[AbilityDef] = [ability]
		item.teaches = teaches
		items[item.id] = item
	return {"abilities": abilities, "items": items}


## The timing bar comes from the sheet's timing columns (the importer's "timing"),
## never from the behavior file: a designed bar (manual or AI-generated) of more
## than 0 s becomes the ability's TimingBarDef; anything else means no bar.
static func _apply_timing(ability: AbilityDef, timing: Dictionary) -> void:
	ability.timing_status = timing.get("status", "none")
	ability.timing_bar = null
	if ability.timing_status == "none" or float(timing.get("seconds", 0.0)) <= 0.0:
		return
	var bar := TimingBarDef.new()
	bar.seconds = float(timing.seconds)
	bar.zones = _zones(timing.get("taps", []))
	bar.crit_zones = _zones(timing.get("crits", []))
	bar.hold_zones = _zones(timing.get("holds", []))
	ability.timing_bar = bar


static func _zones(list: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for z in list:
		out.append(Vector2(float(z[0]), float(z[1])))
	return out
