extends Node
## Loot on screen (needs a display or xvfb):
##   SHOTS_DIR=/tmp/shots godot --path . res://tests/visual/loot_shots.tscn
## One drop of each rarity in front of the hero (beams white, green, blue, purple,
## gold, names in the hero's colour), then the boss loot summary.

var out_dir := OS.get_environment("SHOTS_DIR").path_join("") if OS.get_environment("SHOTS_DIR") != "" else ProjectSettings.globalize_path("user://shots/")
var game: Game


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	TileArt.freeze_water = true
	WorldView.freeze_pulses = true
	get_window().size = Vector2i(1920, 1080)
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out_dir + name + ".png")
	print("shot ", name)


## One item of each rarity (an existing one where there is one; Legendary has none
## yet, so a made-up one).
static func items_by_rarity() -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for r in Rarity.Id.values():
		var found: ItemDef = null
		for it: ItemDef in ContentDB.items.values():
			if it.rarity == r and not it.retired:
				found = it
				break
		if found == null:
			found = ItemDef.new()
			found.id = &"shots_legendary"
			found.display_name = "Sunforged Crown"
			found.rarity = r
			ContentDB.items[found.id] = found
		out.append(found)
	return out


func _run() -> void:
	game = Game.new()
	game.settings_path = "user://loot_shots_settings.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Kael", ContentDB.heroes[&"adventurer"]))
	var session: LocalSession = game.session
	var me := session.local_hero()
	var sim := session.zone_sim()
	me.move.place(Vector2i(12, 20))
	var items := items_by_rarity()
	for i in items.size():
		sim.drops.add(me.id, items[i], 1, Vector2(10.5 + i * 1.2, 18.5 + i * 0.4), 9999.0)
	for i in 30:
		await get_tree().process_frame
	await _shot("loot0_beams")
	(game.get_node("Hud") as Hud).boss_loot.show_summary({"boss": "Old Grizzlehide", "seconds": 60.0, "received": [
		{"name": "Kael", "gold": 42, "items": [["wolf_pelt", 2], [String(items[3].id), 1]]},
		{"name": "Mara", "gold": 42, "items": [["wolf_pelt", 2], [String(items[2].id), 1]]}]})
	await _shot("loot1_boss_summary")
	sim.rolls.start(items[3], 1, "Old Grizzlehide", [me], sim.now, sim.rules.party_play)
	me.loot_bonus = 25
	await _shot("loot2_roll_window")
	get_tree().quit()
