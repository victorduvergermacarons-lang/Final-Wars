extends Node
## Icons on screen (needs a display or xvfb), at 1280x720 and at 1920x1080 (whole
## screen pixels per art pixel at both: 1x and 2x in most slots):
##   SHOTS_DIR=/tmp/shots xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . res://tests/visual/icon_shots.tscn
## Per size (suffix _720 / _1080): the action bar (bending icons, a potion, a weapon
## art keeping its name, the cooldown sweep), the Fire and Water trees (locked ones
## greyed), the inventory with an item of each rarity (worn and in the bag, plus a
## Legs item with no art yet and a placeholder), the spellbook, an item tooltip, a
## shop, loot on the ground, the boss summary, the roll window and the trade window.

var out_dir := OS.get_environment("SHOTS_DIR").path_join("") if OS.get_environment("SHOTS_DIR") != "" else ProjectSettings.globalize_path("user://shots/")
var game: Game


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	TileArt.freeze_water = true
	WorldView.freeze_pulses = true
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out_dir + name + ".png")
	print("shot ", name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	for res in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = res
		await _frames(4)
		await _pass("_%d" % res.y)
	get_tree().quit()


func _pass(suffix: String) -> void:
	var cd := ContentDB
	game = Game.new()
	game.settings_path = "user://icon_shots_settings.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Kael", cd.heroes[&"adventurer"]))
	var session: LocalSession = game.session
	var hero := session.local_hero()
	var sim := session.zone_sim()
	var hud: Hud = game.get_node("Hud")
	hero.move.place(Vector2i(12, 20))
	# The action bar: bending abilities (icons), a potion, a sword art (its name).
	for id in [&"F01", &"F07", &"W01", &"W02", &"E01", &"A01", &"A02", &"S01"]:
		TreeRules.master(hero, cd.abilities[id])
	hero.wear(cd.items[&"rusty_shortsword"])
	hero.bag.add(cd.items[&"minor_health_potion"], 3)
	var bar_ids := [&"F01", &"F07", &"W01", &"W02", &"E01", &"A01", &"A02", &"S01"]
	for i in bar_ids.size():
		game.client.action_bar.assign(i, bar_ids[i])
	game.client.action_bar.assign(8, ActionBarModel.item_entry(&"minor_health_potion"))
	hero.mana = hero.current_stats(session.now()).mana
	# A cooldown sweep over Fireball's icon and the global cooldown on the others.
	hero.cooldowns.trigger(cd.abilities[&"F07"], session.now(), 1.0)
	await _frames(20)
	await _shot("icons0_action_bar" + suffix)
	# Trees: Fire with tier 2 open, Water at the start (most locked: grey).
	Mastery.add_permanent(hero, "Fire", 160)
	hud._toggle(hud.trees_window)
	hud.trees_window.show_tree("Fire")
	await _shot("icons1_fire_tree" + suffix)
	hud.trees_window.show_tree("Water")
	await _shot("icons2_water_tree" + suffix)
	hud._toggle(hud.trees_window)
	# Inventory: an item of each rarity worn and in the bag, a Legs item with no art
	# (its name), an element piece with no art (the placeholder), scrolls, a weapon.
	for id in [&"frostweave_robe", &"rangers_gloves", &"grizzlehide_mantle", &"iron_helm",
			&"scroll_of_the_fireball", &"glacier_scroll", &"yew_longbow", &"wolf_pelt",
			&"acolytes_leggings", &"cinder_ring", &"swift_boots"]:
		if cd.items.has(id):
			hero.bag.add(cd.items[id], 3 if id == &"wolf_pelt" else 1)
	var legendary := ItemDef.new()
	legendary.id = &"shots_legendary"
	legendary.display_name = "Sunforged Crown"
	legendary.rarity = Rarity.Id.LEGENDARY
	legendary.icon = cd.items[&"grizzlehide_mantle"].icon
	hero.bag.add(legendary)
	for id in [&"iron_helm", &"rangers_gloves", &"grizzlehide_mantle", &"swift_boots"]:
		hero.equip_from_bag(hero.bag.index_of(cd.items[id]))
	hud.inventory_window.visible = true
	await _shot("icons3_inventory" + suffix)
	# A tooltip, shown in a paper panel like the real one (a screenshot can't hover).
	var tip := PanelContainer.new()
	tip.theme = UiPalette.paper_theme()
	tip.add_theme_stylebox_override("panel", UiPalette.paper_theme().get_stylebox("panel", "TooltipPanel"))
	tip.add_child(ItemTooltip.label(cd.items[&"scroll_of_the_fireball"], hero, session.rules(), false, session.now()))
	tip.position = Vector2(700, 120)
	hud.add_child(tip)
	await _shot("icons4_item_tooltip" + suffix)
	tip.queue_free()
	var atip := PanelContainer.new()
	atip.add_child(Icons.tooltip(hud, cd.abilities[&"F07"].icon, SlotButton._tooltip(cd.abilities[&"F07"])))
	atip.position = Vector2(500, 400)
	hud.add_child(atip)
	hud._spellbook.visible = true
	await _shot("icons5_spellbook_ability_tooltip" + suffix)
	atip.queue_free()
	hud.close_menus()
	# Loot on the ground (one of each rarity), the boss summary, a roll, a trade.
	var drops: Array = [cd.items[&"wolf_pelt"], cd.items[&"frostweave_robe"], cd.items[&"rangers_gloves"],
			cd.items[&"grizzlehide_mantle"], legendary]
	cd.items[legendary.id] = legendary
	for i in drops.size():
		sim.drops.add(hero.id, drops[i], 1, Vector2(10.5 + i * 1.2, 18.5 + i * 0.4), 9999.0)
	await _frames(10)
	await _shot("icons6_ground_loot" + suffix)
	hud.boss_loot.show_summary({"boss": "Old Grizzlehide", "seconds": 60.0, "received": [
		{"name": "Kael", "gold": 42, "items": [["wolf_pelt", 2], ["grizzlehide_mantle", 1]]},
		{"name": "Mara", "gold": 42, "items": [["rangers_gloves", 1]]}]})
	sim.rolls.start(cd.items[&"grizzlehide_mantle"], 1, "Old Grizzlehide", [hero], sim.now, sim.rules.party_play)
	await _shot("icons7_roll_window_boss_summary" + suffix)
	hud.boss_loot.visible = false
	sim.rolls = LootRolls.new()
	var mara := session.world.add_saved_hero(CharacterData.new_character("Mara", cd.heroes[&"adventurer"]), cd)
	mara.move.place(Vector2i(13, 20))
	mara.bag.add(cd.items[&"wolf_pelt"], 3)
	mara.bag.add(cd.items[&"frostweave_robe"])
	hero.bag.add(cd.items[&"iron_helm"])
	sim.submit(mara.id, {"type": "trade_request", "target": hero.id})
	await _frames(4)
	hud.request_window.answer(true)
	await _frames(4)
	sim.submit(hero.id, {"type": "trade_add", "index": hero.bag.index_of(cd.items[&"iron_helm"]), "count": 1})
	sim.submit(mara.id, {"type": "trade_add", "index": mara.bag.index_of(cd.items[&"wolf_pelt"]), "count": 3})
	sim.submit(mara.id, {"type": "trade_add", "index": mara.bag.index_of(cd.items[&"frostweave_robe"]), "count": 1})
	sim.submit(mara.id, {"type": "trade_offer"})
	await _frames(4)
	await _shot("icons8_trade_window" + suffix)
	sim.submit(hero.id, {"type": "trade_offer"})
	await _frames(4)
	await _shot("icons9_trade_contract" + suffix)
	sim.submit(hero.id, {"type": "trade_cancel"})
	cd.items.erase(legendary.id)
	game.queue_free()
	await _frames(4)
