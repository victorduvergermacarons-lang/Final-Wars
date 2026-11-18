extends Node
## Dumps every item the game knows, with its stats and every way to get it (enemy
## drops, shops, quest rewards, starting kits), as JSON for
## tools/make_item_database.py, which writes design/Item_Database.xlsx.
##
##   godot --headless --path . res://tools/item_database.tscn -- <out.json>
##   python3 tools/make_item_database.py <out.json>
##
## It reads the same content the game loads (ContentDB), so the sheet is always what
## the game really has; regenerate it after changing items, loot, shops or quests.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if not args.is_empty() else ProjectSettings.globalize_path("user://item_database.json")
	var data := collect()
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	print("wrote %d items, %d sources to %s" % [data.items.size(), data.sources.size(), out])
	get_tree().quit()


static func _stats(block: StatBlock) -> Dictionary:
	var d := {}
	if block == null:
		return d
	for id in Stat.all():
		var v := block.get_stat(id)
		if not is_zero_approx(v):
			d[ItemTooltip.STAT_LABELS[id]] = v
	return d


## Where each enemy type stands in the world (not the generated testing grounds).
static func _enemy_places() -> Dictionary:
	var out := {}
	for z: ZoneDef in ContentDB.zones.values():
		if z.enemy_pens:
			continue
		for s in z.enemy_spawns:
			if s == null or s.enemy == null:
				continue
			var lv: int = s.level if s.level > 0 else s.enemy.level
			var key := "%s (Lv %d)" % [z.display_name, lv]
			var list: Array = out.get(s.enemy.id, [])
			if not list.has(key):
				list.append(key)
			out[s.enemy.id] = list
	return out


static func _npc_places() -> Dictionary:
	var out := {}
	for z: ZoneDef in ContentDB.zones.values():
		for n in z.npcs:
			if n != null and n.npc != null:
				out[n.npc.id] = z.display_name
	return out


static func collect() -> Dictionary:
	var rules: CombatRules = ContentDB.rules
	var items := []
	var ids := ContentDB.items.keys()
	ids.sort()
	for id in ids:
		var it: ItemDef = ContentDB.items[id]
		var kind := "Equipment"
		if it.quest_item:
			kind = "Quest item"
		elif it.use_ability != null:
			kind = "Consumable"
		elif it.is_scroll:
			kind = "Scroll"
		elif it.tree != "":
			kind = "Weapon"
		elif not it.is_equippable():
			kind = "Material"
		var teaches := []
		for a in it.teaches:
			if a != null:
				teaches.append("%s (%s)%s" % [a.display_name, a.id, "" if a.implemented else ", not in the game yet"])
		items.append({
			"id": String(id), "name": it.display_name, "kind": kind,
			"slot": EquipSlot.Type.keys()[it.slot].capitalize() if it.slot != EquipSlot.Type.NONE else "",
			"rarity": Rarity.Id.keys()[it.rarity].capitalize(), "tree": it.tree, "tier": it.tier,
			"element": String(it.element), "teaches": ", ".join(teaches), "retired": it.retired,
			"price": it.price, "sells_for": floori(it.price * rules.vendor_sell_fraction),
			"stack": it.max_stack, "stats": _stats(it.stats), "growth": _stats(it.growth),
			"description": it.description,
		})
	var sources := []
	var loot := []
	var places := _enemy_places()
	var eids := ContentDB.enemies.keys()
	eids.sort()
	for eid in eids:
		var e: EnemyDef = ContentDB.enemies[eid]
		if e.loot == null:
			continue
		var where := ", ".join(places.get(eid, ["testing grounds only"]))
		loot.append({"enemy": e.display_name, "level": e.level, "where": where, "item": "Gold",
				"chance": 1.0, "count": "%d-%d" % [e.loot.gold_min, e.loot.gold_max], "quest": ""})
		for entry in e.loot.entries:
			if entry == null or entry.item == null:
				continue
			var count := str(entry.min_count) if entry.min_count == entry.max_count \
					else "%d-%d" % [entry.min_count, entry.max_count]
			var quest := String(entry.quest_id)
			loot.append({"enemy": e.display_name, "level": e.level, "where": where, "item": entry.item.display_name,
					"item_id": String(entry.item.id), "chance": entry.chance, "count": count, "quest": quest})
			sources.append({"item_id": String(entry.item.id), "how": "Enemy drop", "from": e.display_name,
					"where": where, "detail": "%d%%%s" % [roundi(entry.chance * 100),
					" (only while on %s)" % quest if quest != "" else ""]})
	var npc_places := _npc_places()
	for n: NpcDef in ContentDB.npcs.values():
		for it in n.sells:
			if it != null:
				sources.append({"item_id": String(it.id), "how": "Shop", "from": n.display_name,
						"where": npc_places.get(n.id, ""), "detail": "%d gold" % it.price})
	for q: QuestDef in ContentDB.quests.values():
		var label := "%s (Lv %d)" % [q.title, q.min_level]
		for it in q.reward_items:
			if it != null:
				sources.append({"item_id": String(it.id), "how": "Quest reward", "from": label, "where": "", "detail": "always"})
		for it in q.reward_choices:
			if it != null:
				sources.append({"item_id": String(it.id), "how": "Quest reward", "from": label, "where": "",
						"detail": "choice of one of %d" % q.reward_choices.size()})
		for it in q.given_items:
			if it != null:
				sources.append({"item_id": String(it.id), "how": "Quest item (given)", "from": label, "where": "",
						"detail": "handed over on accepting"})
	for h: HeroDef in ContentDB.heroes.values():
		for it in h.starting_items:
			if it != null:
				sources.append({"item_id": String(it.id), "how": "Starting kit", "from": "%s (no element)" % h.display_name,
						"where": "", "detail": ""})
	for el: StartingElementDef in ContentDB.elements.values():
		for pair in [[el.mastered_scroll_id, "first ability, mastered"], [el.learning_scroll_id, "in the learning slot"]]:
			sources.append({"item_id": String(pair[0]), "how": "Starting kit", "from": "%s element" % el.display_name,
					"where": "", "detail": pair[1]})
		for c in el.clothes_ids:
			sources.append({"item_id": String(c), "how": "Starting kit", "from": "%s element" % el.display_name,
					"where": "", "detail": "worn"})
	return {"items": items, "sources": sources, "loot": loot, "stat_labels": ItemTooltip.STAT_LABELS}
