extends Node
## Fire physics bench: an ability's look on the GPU fluid against a dummy, in the game's
## own world view, at Fire Mastery 0, 185 and 1000, near and far (the reference
## bench's distances), with frame times.
##   SHOTS_DIR=<dir> FIRE_ABILITY=F12 godot --path . res://tests/visual/fire_bench.tscn
## FIRE_STRESS=1: four casters on the same spot, for the frame time on your machine.
## From the Godot editor: open this scene, tick "Stress" on the FireBench node (or set
## "Ability"), and run it with F6; the times show in the Output panel.

## Four casters at once (same as FIRE_STRESS=1).
@export var stress := false
## The ability to show (same as FIRE_ABILITY), F12 when empty.
@export var ability_id := ""

var out_dir := OS.get_environment("SHOTS_DIR").path_join("") if OS.get_environment("SHOTS_DIR") != "" else ProjectSettings.globalize_path("user://shots/")
var ability := StringName(OS.get_environment("FIRE_ABILITY")) if OS.get_environment("FIRE_ABILITY") != "" else &"F12"
var game: Game
var world: World
var hero: Hero
var view: WorldView
var dummy: Enemy
const DIR := Vector2(1, -1) # straight right on screen


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1920, 1080)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _spot(sim: WorldSim, reach: int) -> Vector2i:
	for y in range(reach + 2, sim.grid.depth - 4):
		for x in range(4, sim.grid.width - reach - 4):
			var t := Vector2i(x, y)
			var ok := true
			for k in range(-2, reach + 2):
				for side in [-1, 0, 1]:
					var c := t + Vector2i(k, -k) + Vector2i(side, side)
					if not sim.grid.in_bounds(c) or not sim.grid.is_walkable(c) or sim.grid.height_at(c) != sim.grid.height_at(t) \
							or sim.grid.blocks_sight(c) or sim.is_occupied(c):
						ok = false
			if ok:
				return t
	return Vector2i(8, 8)


func _run() -> void:
	game = Game.new()
	game.settings_path = "user://fire_bench.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Ember", ContentDB.heroes[&"adventurer"], ContentDB.elements[&"fire"]))
	world = game.session.world
	hero = world.heroes()[0]
	view = game.get_node("WorldView")
	var sim := world.zone_of(hero.id)
	var t := _spot(sim, 6)
	hero.move.place(t)
	hero.move.ground_h = sim.grid.height_at(t)
	var dd := EnemyDef.new()
	dd.id = &"bench_dummy"
	dd.display_name = "Dummy"
	dd.immobile = true
	dd.collider_radius = 0.3
	dd.stats = StatBlock.make({Stat.Id.HP: 100000})
	dd.aggro_radius = 0
	dummy = sim.add_enemy(dd, t + Vector2i(2, -2))
	await _frames(10)
	if ability == &"all" or OS.get_environment("FIRE_LIST") != "":
		await _all_bench(sim, t)
		get_tree().quit()
		return
	if ability == &"ground":
		await _ground_bench(sim, t)
		get_tree().quit()
		return
	var look: FireLookDef = load("res://content/effects/fire/%s.tres" % ability)
	stress = stress or OS.get_environment("FIRE_STRESS") == "1" or "--stress" in OS.get_cmdline_user_args()
	if ability_id != "":
		ability = StringName(ability_id)
	var ms_idle := await _frame_ms(20)
	print("frame time with no fire: %.2f ms" % ms_idle)
	var dists := [look.near, look.far] if OS.get_environment("FIRE_QUICK") != "1" else [look.near]
	for dist in dists:
		var at := Vector2(t) + DIR.normalized() * (float(dist) / 16.0)
		dummy.move.place(at)
		dummy.move.pos = at
		for m in ([0, 185, 1000] if OS.get_environment("FIRE_QUICK") != "1" else [1000]):
			var casters := 4 if stress else 1
			for c in casters:
				var e := view.fire.start(look, hero.id, Vector2(t), float(sim.grid.height_at(t)), at, float(m))
				if e == null:
					continue
				view.fire.set_walls(e, sim.grid)
				e.hold_steps = 190
				e.done_after = 190
				e.tail_steps = 60
			await _frames(40)
			var ms := await _frame_ms(20)
			await _shot("fire_%s_%s_m%d" % [String(ability), "near" if dist == look.near else "far", m], Vector2(t))
			print("%s %s mastery %d: %.2f ms a frame (%d effects, %d GPU steps run)" % [ability, "near" if dist == look.near else "far", m, ms,
					view.fire.effects.size(), view.fire.sim.frames_run])
			view.fire.clear()
			await _frames(2)
	print("Fire bench done. Screenshots in ", out_dir)
	get_tree().quit()


func _frame_ms(n: int) -> float:
	var t0 := Time.get_ticks_usec()
	await _frames(n)
	return (Time.get_ticks_usec() - t0) / 1000.0 / n


func _shot(name: String, centre: Vector2) -> void:
	await _frames(1)
	var img := get_viewport().get_texture().get_image()
	if OS.get_environment("FIRE_FULL") == "1":
		img.save_png(out_dir + name + "_full.png")
	# The camera follows the hero: the hero is at the screen's centre, the fire to its right.
	var c := Vector2i(img.get_size() / 2) + Vector2i(140, -40)
	var r := Rect2i(c.x - 300, c.y - 170, 600, 300).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(r).save_png(out_dir + name + ".png")


## FIRE_ABILITY=ground: the hero casts Burning Ground (F08) on the dummy's spot; shots
## as the front spreads, burns, goes out and leaves char.
func _ground_bench(sim: WorldSim, t: Vector2i) -> void:
	TreeRules.master(hero, ContentDB.abilities[&"F08"])
	hero.mana = 9999.0
	var at := Vector2(t) + DIR.normalized() * 2.5
	dummy.move.place(at)
	dummy.move.pos = at
	world.submit(hero.id, {"type": "cast", "ability": &"F08", "target": -1, "aim": at})
	var t0 := Time.get_ticks_msec()
	for when in [0.4, 1.0, 2.5, 4.5, 6.5, 12.0]:
		while world.zone_of(hero.id).now < float(when) + _cast_at(sim):
			if OS.get_environment("FIRE_HOOKS") == "1" and world.zone_of(hero.id).now > 3.5 + _cast_at(sim) \
					and world.zone_of(hero.id).now < 4.0 + _cast_at(sim):
				# a line of water lying across the fire, and a gust blowing over it (the hooks)
				var pts := []
				for i in 12:
					pts.append({"pos": at + Vector2(-1.2 + i * 0.2, 1.2 - i * 0.2) + Vector2(0.4, 0.4), "z": 0.0, "ground": true})
				view.fire.extra_water = pts
				if view.fire._gusts.is_empty() and view.fire.extra_water.size() < 13:
					view.fire._gusts.append({"from": at + Vector2(-2, -2), "to": at + Vector2(2, 2), "left": 30})
			await _frames(1)
		view.fire.extra_water = []
		await _shot("ground_F08_%04.1fs" % when, Vector2(t))
		print("ground %.1f s: zones %d, fire windows %d, burnt plants %d" % [when, world.zone_of(hero.id).ground_zones().size(),
				view.fire.effects.size(), view.fire.burnt.size()])


var _cast_t := -1.0


func _cast_at(sim: WorldSim) -> float:
	if _cast_t < 0.0:
		_cast_t = sim.now
	return _cast_t



## Seconds after the cast for each look's three shots (its moments).
const MOMENTS := {"F01": [0.05, 0.1, 0.25], "F02": [0.08, 0.15, 1.0], "F09": [0.15, 0.45, 0.75], "F03": [0.08, 0.16, 0.3],
	"F04": [0.2, 0.45, 0.8], "F12": [0.5, 1.5, 2.4], "F23": [0.2, 4.0, 8.35], "F06": [0.4, 0.76, 0.95],
	"F11": [0.4, 1.5, 3.1], "F15": [0.25, 0.52, 1.2], "F07": [0.2, 0.45, 0.8], "F10": [0.15, 0.3, 0.6],
	"F16": [0.5, 2.0, 4.5], "F14": [0.3, 0.7, 1.2], "F18": [0.2, 0.95, 1.3]}


## FIRE_ABILITY=all (or FIRE_LIST=F01,F06,...): every Fire look through the host's cast
## event path (start_from_event), at Fire Mastery 1000 against the dummy at the look's
## near distance; shots at a quarter, half and most of the way through.
func _all_bench(sim: WorldSim, t: Vector2i) -> void:
	var ids := ["F01", "F02", "F09", "F03", "F04", "F12", "F23", "F06", "F11", "F15", "F07", "F10", "F16", "F14", "F18"]
	if OS.get_environment("FIRE_LIST") != "":
		ids = OS.get_environment("FIRE_LIST").split(",")
	var m := float(OS.get_environment("FIRE_MASTERY")) if OS.get_environment("FIRE_MASTERY") != "" else 1000.0
	for id in ids:
		var look := FireEffects.look_of(StringName(id))
		var at := Vector2(t) + DIR.normalized() * (float(look.near) / 16.0)
		dummy.move.place(at)
		dummy.move.pos = at
		await _frames(2)
		var ev := {"type": "cast", "fire": true, "ability": StringName(id), "source": hero.id, "target": dummy.id,
				"from": Vector2(t), "to": at, "h": float(sim.grid.height_at(t)), "mastery": m}
		var e := view.fire.start_from_event(ev, ContentDB.abilities, sim.grid)
		if e == null:
			print(id, ": no look")
			continue
		var steps := FireKinds.length(e)
		var k := 0
		for sec in MOMENTS.get(id, [0.25, 0.5, 1.0]):
			while e.ct < int(float(sec) * 60.0 * look.time_scale) and view.fire.effects.has(e):
				await _frames(1)
			await _shot("look_%s_m%d_%d" % [id, int(m), k], Vector2(t))
			k += 1
		print("%s (%s): %d steps" % [id, look.kind, steps])
		view.fire.clear()
		await _frames(3)
