extends Node
## Simulation cost per tick (World.step), with empty zones sleeping or not. Runs
## the world solo with no window, one hero in town:
##   godot --headless --path . res://tools/perf/sim_profile.tscn


func _ready() -> void:
	for sleep in [false, true]:
		var rules: CombatRules = ContentDB.rules.duplicate()
		rules.empty_zone_sleep_seconds = 30.0 if sleep else -1.0
		var world := World.new(ContentDB.zones.values(), rules, 1, &"town", ContentDB.quests)
		world.add_saved_hero(CharacterData.new_character("Prof", ContentDB.heroes.values()[0]), ContentDB)
		world.advance(35.0) # past the wait
		var n := 400
		var t0 := Time.get_ticks_usec()
		for i in n:
			world.step()
		var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
		print("%-22s %.3f ms per tick (%.1f%% of a 20 Hz budget)" % [
				"empty zones sleep" if sleep else "every zone runs", ms, ms / 50.0 * 100.0])
	get_tree().quit()
