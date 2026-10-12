extends Node
## Renders a few game situations to PNGs for a visual check (needs a display or
## xvfb and a Godot build with a renderer):
##   SHOTS_DIR=/tmp/shots godot --path . res://tests/visual/shots.tscn

## Where the PNGs go: $SHOTS_DIR, or user://shots/.
var out_dir := OS.get_environment("SHOTS_DIR").path_join("") if OS.get_environment("SHOTS_DIR") != "" else ProjectSettings.globalize_path("user://shots/")
var game: Game


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 8:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out_dir + name + ".png")
	print("shot ", name)


func _run() -> void:
	var cd = ContentDB
	game = Game.new()
	game.settings_path = "user://shots_settings.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Ayla", cd.heroes[&"adventurer"]))
	var session: LocalSession = game.session
	var hero := session.local_hero()
	var hud: Hud = game.get_node("Hud")
	# 1. Town next to Rowan, quest tracked, bar 2 shown.
	hero.move.place(Vector2i(11, 9))
	hero.face(Vector2i.RIGHT)
	QuestLog.accept(hero, cd.quests[&"word_to_hilda"])
	game.client.action_bar.set_page(1)
	await _shot("1_town_rowan")
	# 2. Inventory + quest log open: tracker hidden.
	game.client.action_bar.set_page(0)
	hud.inventory_window.visible = true
	await _shot("2_inventory_open")
	hud.inventory_window.visible = false
	hud.quest_log.visible = true
	await _shot("3_quest_log")
	hud.quest_log.visible = false
	# 3. Greenfields, near the bandit camp, quest active.
	hero.quest_state["wolves_at_the_gate"] = {"state": "done"}
	hero.level = 3
	QuestLog.accept(hero, cd.quests[&"bandit_camp"])
	session.world.move_hero(hero.id, &"greenfields", Vector2i(18, 24))
	await _shot("4_bandit_camp")
	# 4. Floating combat text pile-up on a Wolf next to us.
	var fields := session.world.zone(&"greenfields")
	var wolf: Enemy = fields.enemies().filter(func(e): return e.def.id == &"wolf")[0]
	hero.move.place(wolf.tile() + Vector2i(0, 1))
	hero.face(Vector2i.UP)
	var view: WorldView = game.get_node("WorldView")
	view._on_events([{"type": "damage", "target": wolf.id, "amount": 31, "crit": false},
			{"type": "damage", "target": wolf.id, "amount": 62, "crit": true, "flank": "side"},
			{"type": "miss", "target": hero.id}, {"type": "level_up", "target": hero.id, "level": 4}])
	await _shot("5_float_text")
	# 5. Grizzlehide.
	var bear: Enemy = fields.enemies().filter(func(e): return e.def.elite)[0]
	hero.move.place(bear.tile() + Vector2i(-5, 0))
	await _shot("6_grizzlehide")
	get_tree().quit()
