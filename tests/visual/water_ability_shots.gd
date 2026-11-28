extends Node
## Phase 4 of feature/water-physics (2026-11-28): the water abilities. Water Whip
## thrown, waiting on the ground, called back; Healing Touch's helix on an ally and on
## yourself; Water Shield going out, up, stretched, hit, broken and run out.
##   SHOTS_DIR=/tmp/w4 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . res://tests/visual/water_ability_shots.tscn
## SHOTS_ONLY=whip|heal|shield|shard|leech: one group.

var out_dir := OS.get_environment("SHOTS_DIR").path_join("") if OS.get_environment("SHOTS_DIR") != "" else ProjectSettings.globalize_path("user://shots/")
var game: Game
var world: World
var hero: Hero
var crop := Rect2i(960 - 260, 540 - 230, 520, 360)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1920, 1080)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String, region := crop) -> void:
	await _frames(2)
	var img := get_viewport().get_texture().get_image()
	if region.has_area():
		img = img.get_region(region)
	img.save_png(out_dir + name + ".png")
	print("shot ", name, "  stance ", hero.stance, "  stance water ", hero.stance_water, "  pouch ", hero.water)


func _stance(n: int) -> void:
	world.submit(hero.id, {"type": "stance", "tree": "Water" if n > 0 else "", "stance": n})


## A walkable tile with nothing within `away` tiles but water within `near` of it.
func _spot(sim: WorldSim, min_d: float, max_d: float) -> Vector2i:
	var idx := WaterTiles.of(sim.zone)
	for y in range(4, sim.grid.depth - 4):
		for x in range(4, sim.grid.width - 4):
			var t := Vector2i(x, y)
			if not sim.grid.is_walkable(t) or sim.is_occupied(t):
				continue
			var w = WaterTiles.nearest(idx, Vector2(t), max_d)
			if w != null and WaterTiles.nearest(idx, Vector2(t), min_d) == null:
				return t
	return Vector2i(-1, -1)


func _go(t: Vector2i) -> void:
	var sim := world.zone_of(hero.id)
	hero.move.place(t)
	hero.move.ground_h = sim.grid.height_at(t)
	await _frames(8)


var ally: Hero
var dummy: Enemy
var only := OS.get_environment("SHOTS_ONLY")


func _cast(id: StringName, target: Actor, aim: Variant = null) -> void:
	var intent := {"type": "cast", "ability": id, "target": target.id if target != null else -1}
	if aim != null:
		intent.aim = aim
	world.submit(hero.id, intent)


func _ready_again(stance := 1) -> void:
	hero.cooldowns = Cooldowns.new()
	hero.mana = 999
	hero.stance_tree = "Water"
	hero.stance = stance
	hero.stance_water = WaterBending.full(stance)
	await _wait(2.5)


func _run() -> void:
	game = Game.new()
	game.settings_path = "user://water_ability_shots.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Kanna", ContentDB.heroes[&"adventurer"], ContentDB.elements[&"water"]))
	world = game.session.world
	hero = world.heroes()[0]
	for id in [&"W01", &"W02", &"W12", &"W04", &"W05", &"W07"]:
		TreeRules.master(hero, ContentDB.abilities[id])
	Mastery.add_permanent(hero, "Water", 300)
	var sim := world.zone_of(hero.id)
	await _go(_spot(sim, 9.0, 30.0))
	var t := hero.tile()
	ally = world.add_saved_hero(CharacterData.new_character("Bram", ContentDB.heroes[&"adventurer"]), ContentDB)
	var at := t + Vector2i(2, 0)
	for d in [Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1), Vector2i(2, -1), Vector2i(0, 3), Vector2i(-3, 0)]:
		var c: Vector2i = t + d
		if sim.grid.is_walkable(c) and sim.grid.height_at(c) == sim.grid.height_at(t) and not sim.is_occupied(c):
			at = c
			break
	ally.move.place(at)
	ally.move.ground_h = sim.grid.height_at(at)
	print("ally at ", at, " hero at ", t)
	var dd := EnemyDef.new()
	dd.id = &"shot_dummy"
	dd.display_name = "Dummy"
	dd.immobile = true
	dd.stats = StatBlock.make({Stat.Id.HP: 100000})
	dd.aggro_radius = 0
	var dt := t + Vector2i(0, 3)
	for d in [Vector2i(0, 3), Vector2i(-1, 3), Vector2i(1, 3), Vector2i(-3, 1), Vector2i(0, -3)]:
		var c: Vector2i = t + d
		if sim.grid.is_walkable(c) and not sim.is_occupied(c) and c != at:
			dt = c
			break
	dummy = sim.add_enemy(dd, dt)
	world.submit(hero.id, {"type": "stance", "tree": "Water", "stance": 1})
	await _ready_again()
	if only == "" or only == "whip":
		_cast(&"W02", dummy)
		await _wait(0.3)
		await _shot("w4_01_whip_thrown")
		await _wait(0.6)
		await _shot("w4_02_whip_waiting_on_the_ground")
		world.submit(hero.id, {"type": "water_return"}) # at about 1 s: half comes back
		await _wait(0.35)
		await _shot("w4_03_whip_half_called_back")
		await _wait(1.5)
		await _shot("w4_04_whip_home_12_points")
		await _ready_again()
	if only == "" or only == "heal":
		ally.hp = ally.current_stats(world.zone_of(hero.id).now).hp * 0.5
		_cast(&"W01", ally)
		await _wait(0.6)
		await _shot("w4_05_heal_ally_helix")
		await _wait(0.65)
		await _shot("w4_06_heal_ally_mist_at_the_top")
		await _wait(0.6)
		await _shot("w4_07_heal_ally_after")
		await _ready_again()
		hero.hp = hero.current_stats(world.zone_of(hero.id).now).hp # full health: it all comes back
		_cast(&"W01", hero)
		await _wait(0.7)
		await _shot("w4_08_heal_self_helix")
		await _wait(0.7)
		await _shot("w4_09_heal_self_at_full_health_unwinds")
		await _ready_again()
	if only == "selfshield":
		crop = Rect2i(960 - 160, 540 - 200, 320, 260)
		_cast(&"W12", hero)
		var waited := 0.0
		for when in [0.3, 0.6, 0.9, 1.4, 2.5, 4.5]:
			await _wait(when - waited)
			waited = when
			await _shot("w4z_self_%.1f" % when)
	if only == "" or only == "shield":
		_cast(&"W12", ally)
		await _wait(0.45)
		await _shot("w4_10_shield_going_out")
		await _wait(0.6)
		await _shot("w4_11_shield_up")
		await _wait(3.5)
		await _shot("w4_12_shield_stretched")
		ally.buffs.absorb(ally.buffs.shield_total() * 0.6)
		await _wait(0.4)
		await _shot("w4_13_shield_hit_40_left")
		ally.buffs.absorb(ally.buffs.shield_total() * 0.6)
		await _wait(1.0)
		await _shot("w4_14_shield_cracking")
		var events: Array[Dictionary] = []
		AbilityResolver.deal_damage(sim.ctx, dummy, ally, &"shot", ally.buffs.shield_total() + 5.0, false, events)
		for e in events:
			sim.emit(e)
		await _wait(0.25)
		await _shot("w4_15_shield_broken_burst")
		await _wait(1.0)
		await _shot("w4_16_shield_broken_soaked")
		await _ready_again()
		_cast(&"W12", hero)
		await _wait(1.5)
		await _shot("w4_17_shield_self")
		ally.buffs.absorb(0.0)
		hero.buffs.absorb(hero.buffs.shield_total() * 0.5)
		var b: Dictionary = hero.buffs._active.get(&"water_shield", {})
		if not b.is_empty():
			b.expires = world.zone_of(hero.id).now + 0.1 # run it out now
		await _wait(0.6)
		await _shot("w4_18_shield_run_out_coming_home")
		await _wait(1.5)
		await _shot("w4_19_shield_home")
	if only == "" or only == "shard":
		await _ready_again()
		_cast(&"W04", dummy, dummy.move.pos)
		var waited := 0.0
		for when in [0.05, 0.12, 0.2, 0.4]:
			await _wait(when - waited)
			waited = when
			await _shot("w4_2%d_shard_%.2f" % [int(when * 100) % 10, when])
	if only == "" or only == "leech":
		await _ready_again(2)
		await _wait(1.5) # the hoop closes
		await _shot("w4_30_hoop_before_leech")
		_cast(&"W07", dummy)
		var waited2 := 0.0
		for when in [0.2, 0.6, 1.5, 3.2, 4.5]:
			await _wait(when - waited2)
			waited2 = when
			await _shot("w4_3%d_leech_%.1f" % [int(when * 10) % 10, when])
	get_tree().quit()
