extends Node
## The stance rework on screen (needs a display or xvfb), at 1920x1080:
##   SHOTS_DIR=/tmp/shots xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . res://tests/visual/stance_shots.tscn
## Phase 1: the four element trees with the new tiers and steps (Mastery 240 in each, a
## few mastered), Earth Wall with its trench on raised ground.
## Phase 2: the action bar with stance slots and the stance panel, then every stance's
## look around the hero (st2_look_<tree>_<n>, cropped; a faint ring where the art
## isn't approved yet).
## Phase 3: every ability's effects through the `fx` debug command (st3_fx_<id>,
## cropped), projectiles turned to 8 directions (st3_rot_<id>), Scorch's flames and
## debuff icon (st3_scorch).
## Phase 4: code-drawn effects through `fx` (st4_<name>): ribbons, fronts (open
## ground and against a pillar), tile effects, an L-shaped burning area, Seismic
## Sense, the fire dragon coiled and uncoiling. SHOTS_ONLY=p4 takes only these.
## Phase 5 (SHOTS_ONLY=p5): both whips at 1, 3 and 5 tiles in the four grid facings
## and a diagonal (st5_<whip>_<facing>_<d>), Seismic Stomp on grass and on stone,
## Fireball and Fire Dart flying at 0, 22.5 and 45 degrees on screen.

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


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> WorldView:
	while true:
		var view: WorldView = game.get_node_or_null("WorldView")
		if view != null and view.is_built_for(game.session.grid()):
			return view
		await get_tree().process_frame
	return null


func _run() -> void:
	var cd := ContentDB
	game = Game.new()
	game.settings_path = "user://stance_shots_settings.cfg"
	add_child(game)
	game.start_solo(CharacterData.new_character("Kael", cd.heroes[&"adventurer"]))
	var session: LocalSession = game.session
	var hero := session.local_hero()
	var hud: Hud = game.get_node("Hud")
	for tree in ["Fire", "Earth", "Water", "Air"]:
		Mastery.add_permanent(hero, tree, 240)
	for id in [&"F02", &"F03", &"F09", &"W01", &"W02", &"W05", &"E01", &"E04", &"A01", &"A02"]:
		TreeRules.master(hero, cd.abilities[id])
	hud._toggle(hud.trees_window)
	for tree in ["Fire", "Earth", "Water", "Air"]:
		hud.trees_window.show_tree(tree)
		await _shot("st1_tree_%s" % tree.to_lower())
	hud._toggle(hud.trees_window)
	var only := OS.get_environment("SHOTS_ONLY")
	if only == "":
		await phase1_trench(session, hero)
	if only in ["", "p2"]:
		await phase2_looks(session, hero)
		await phase2_behind_house(session, hero)
	if only in ["", "rot"]:
		await phase3_effects(session, hero)
	if only in ["", "p4"]:
		await phase4_code_effects(session, hero)
	if only in ["", "p5"]:
		await phase5_extra(session, hero)
	get_tree().quit()


## Earth Wall on raised ground (height 2), the hero facing south-east: the wall rises
## 2, the row in front of it sinks 1.
func phase1_trench(session: LocalSession, hero: Hero) -> void:
	session.world.move_hero(hero.id, &"crossing", Vector2i(16, 20))
	var view := await _view()
	var sim := session.zone_sim()
	var raised := []
	for x in range(14, 21):
		for y in range(20, 27):
			sim.grid.set_tile(Vector2i(x, y), 2, true)
			raised.append(Vector2i(x, y))
	view.refresh_tiles(raised)
	hero.move.place(Vector2i(17, 21))
	hero.move.ground_h = 2
	TreeRules.master(hero, ContentDB.abilities[&"E05"])
	sim.cast(hero, ContentDB.abilities[&"E05"], null, Vector2(17, 23))
	await _frames(20)
	view.camera.follow(view.actor_screen_pos(hero) + Vector2(0, 40), 0.0, true)
	await _shot("st1_earth_wall_trench")


func phase2_looks(session: LocalSession, hero: Hero) -> void:
	session.world.move_hero(hero.id, &"crossing", Vector2i(12, 12))
	var view := await _view()
	var sim := session.zone_sim()
	hero.move.place(Vector2i(12, 12))
	hero.move.ground_h = sim.grid.height_at(Vector2i(12, 12))
	sim.set_stance(hero, "Water", 2)
	await _frames(20)
	view.camera.follow(view.actor_screen_pos(hero), 0.0, true)
	await _shot("st2_bar_and_panel")
	for tree in ["Fire", "Earth", "Water", "Air"]:
		for n in range(1, 6):
			sim.set_stance(hero, tree, n)
			# Let the motion run a moment (host time).
			for i in 12:
				session.world.step()
			await _frames(4)
			view.camera.follow(view.actor_screen_pos(hero), 0.0, true)
			await _frames(4)
			var img := get_viewport().get_texture().get_image()
			var c := img.get_size() / 2 # the camera follows the hero
			img = img.get_region(Rect2i(c - Vector2i(160, 200), Vector2i(320, 280)))
			img.save_png(out_dir + "st2_look_%s_%d.png" % [tree.to_lower(), n])
			print("shot st2_look_%s_%d" % [tree.to_lower(), n])
	sim.set_stance(hero, "", 0)


const FX_IDS := ["F01", "F09", "F03", "F05", "F11", "F15", "F07", "F21", "F10", "F16", "F18", "E21", "E23", "W01",
	"W12", "W04", "W13", "W14", "W24", "W10", "W18", "W16", "W09", "W20", "A22", "A03", "A07", "A09", "A11", "A14",
	"A06", "A16", "A12", "A10", "A13", "A15", "F22"]


func _crop(name: String, w := 360, h := 300) -> void:
	await _frames(3)
	var img := get_viewport().get_texture().get_image()
	var c := img.get_size() / 2
	img.get_region(Rect2i(c - Vector2i(w / 2, h * 2 / 3), Vector2i(w, h))).save_png(out_dir + name + ".png")
	print("shot ", name)


## Runs a console line as the player would, the cursor at `aim`, then lets `wait`
## seconds of host time pass.
func _console(session: LocalSession, hero: Hero, line: String, aim: Vector2, wait: float) -> void:
	session.world.submit(hero.id, {"type": "debug", "line": line, "aim": aim})
	var t0: float = session.now()
	while session.now() - t0 < wait:
		await get_tree().process_frame


func phase3_effects(session: LocalSession, hero: Hero) -> void:
	var view := await _view()
	view.camera.follow(view.actor_screen_pos(hero), 0.0, true)
	var aim := hero.move.pos + Vector2(2.0, 1.0)
	for id in ([] if OS.get_environment("SHOTS_ONLY") == "rot" else FX_IDS):
		var a: AbilityDef = ContentDB.abilities[StringName(id)]
		var wait := 0.12
		if a.fx_hands != &"":
			wait = 1.12
		elif a.fx_projectile != &"":
			wait = 0.06
		elif a.fx_land != &"" and a.fx_cast == &"":
			wait = 0.3
		await _console(session, hero, "fx " + id, aim, wait)
		await _crop("st3_fx_%s" % id)
		await _console(session, hero, "heal", aim, 3.6) # let it finish
	# Projectiles turned to 8 directions, the clock slowed so they stay in the crop.
	ContentDB.rules.game_speed = 0.1
	for id in ["F03", "F07", "W04", "E21", "A22"]:
		for k in 8:
			var d := Vector2.RIGHT.rotated(k * TAU / 8.0) * 4.0
			await _console(session, hero, "fx " + id, hero.move.pos + d, 0.07)
			await _crop("st3_rot_%s_%d" % [id, k], 440, 360)
			await _console(session, hero, "heal", aim, 0.6)
	ContentDB.rules.game_speed = 1.0
	# Scorch for real: the debuff on a wolf beside the hero, with the target frame.
	var sim := session.zone_sim()
	var wolf := sim.add_enemy(ContentDB.enemies[&"wolf"], hero.tile() + Vector2i(2, 0))
	wolf.buffs.apply(ContentDB.buffs[&"scorched"], sim.now, 0.0, hero.id)
	game.get_node("Hud").client.target_id = wolf.id
	await _frames(10)
	await _shot("st3_scorch")


## [shot name, console line, aim offset from the hero (tiles), host seconds to wait].
const P4_SHOTS := [
	["water_whip_3", "fx W02", Vector2(2, 2), 0.29], ["fire_whip", "fx F06", Vector2(3, 0), 0.25],
	["fire_stream", "fx F12", Vector2(4, 1), 0.4], ["water_jet", "fx W11", Vector2(4, 1), 0.4],
	["leeching_tide", "fx W07", Vector2(3, 2), 0.3], ["metal_cable", "fx E22", Vector2(4, 0), 0.2],
	["lightning_bolt", "fx F17", Vector2(4, 2), 0.15], ["lightning_redirect", "fx F19", Vector2(2, 0), 0.6],
	["breath_of_fire", "fx F14", Vector2(3, 3), 0.25], ["water_pulse", "fx W06", Vector2(3, 3), 0.3],
	["gust", "fx A02", Vector2(3, 0), 0.15], ["air_blast", "fx A05", Vector2(3, 0), 0.15],
	["air_blade", "fx A22", Vector2(5, 0), 0.1], ["stomp_ring", "fx E04", Vector2(1, 0), 0.3],
	["sinkhole", "fx E06", Vector2(3, 0), 0.5], ["earthquake", "fx E11", Vector2(3, 0), 0.5],
	["sandstorm", "fx E16", Vector2(3, 0), 1.0], ["healing_rain", "fx W17", Vector2(3, 0), 0.6],
]


func phase4_code_effects(session: LocalSession, hero: Hero) -> void:
	var view := await _view()
	var sim := session.zone_sim()
	session.world.move_hero(hero.id, &"crossing", Vector2i(12, 12))
	view = await _view()
	sim = session.zone_sim()
	hero.move.place(Vector2i(12, 12))
	hero.move.ground_h = sim.grid.height_at(Vector2i(12, 12))
	sim.set_stance(hero, "", 0)
	await _frames(10)
	view.camera.follow(view.actor_screen_pos(hero), 0.0, true)
	ContentDB.rules.game_speed = 0.2
	for shot in P4_SHOTS:
		await _console(session, hero, shot[1], hero.move.pos + shot[2], shot[3])
		await _crop("st4_" + shot[0], 480, 380)
		await _console(session, hero, "heal", hero.move.pos, 2.5)
	# Whips at 1, 3 and 5 tiles.
	for d in [1, 3, 5]:
		await _console(session, hero, "fx W02", hero.move.pos + Vector2(d, 0), 0.29)
		await _crop("st4_water_whip_at_%d" % d, 480, 380)
		await _console(session, hero, "heal", hero.move.pos, 1.0)
	# A pillar (height 4) in front: Breath of Fire and Tidal Wave leave a gap behind it.
	var pillar := hero.tile() + Vector2i(2, 2)
	var old_h := sim.grid.height_at(pillar)
	sim.grid.set_tile(pillar, old_h + 4, false)
	view.refresh_tiles([pillar])
	for shot in [["breath_pillar", "fx F14", 0.3], ["tidal_pillar", "fx W15", 0.3], ["fire_stream_wall", "fx F12", 0.4]]:
		await _console(session, hero, shot[1], hero.move.pos + Vector2(3, 3), shot[2])
		await _crop("st4_" + shot[0], 480, 380)
		await _console(session, hero, "heal", hero.move.pos, 2.5)
	sim.grid.set_tile(pillar, old_h, true)
	view.refresh_tiles([pillar])
	# An L-shaped burning area (Burning Ground's zone).
	var tiles := []
	for k in 4:
		tiles.append(hero.tile() + Vector2i(2 + k, 1))
	for k in range(1, 3):
		tiles.append(hero.tile() + Vector2i(2, 1 + k))
	sim.add_ground_zone(hero.id, tiles, ContentDB.abilities[&"F08"], ContentDB.abilities[&"F08"], 1.0, sim.now + 30.0)
	await _console(session, hero, "heal", hero.move.pos, 0.3)
	await _crop("st4_burning_L", 480, 380)
	# Seismic Sense: the whole screen.
	await _console(session, hero, "fx E13", hero.move.pos, 1.2)
	await _shot("st4_seismic_sense")
	await _console(session, hero, "heal", hero.move.pos, 6.5)
	# The fire dragon coiled, then uncoiling toward an aim (a stance-5 Fire cast).
	await _console(session, hero, "fx Fire:5", hero.move.pos, 0.5)
	await _crop("st4_dragon_coiled", 480, 380)
	view._fx.on_casts([{"type": "cast", "source": hero.id, "ability": &"F16", "at": session.render_time(),
			"point": hero.move.pos + Vector2(3, 1)}], ContentDB.abilities)
	await _console(session, hero, "heal", hero.move.pos, 0.2)
	await _crop("st4_dragon_uncoiling", 480, 380)
	sim.set_stance(hero, "", 0)
	ContentDB.rules.game_speed = 1.0


func phase5_extra(session: LocalSession, hero: Hero) -> void:
	session.world.move_hero(hero.id, &"crossing", Vector2i(12, 12))
	var view := await _view()
	var sim := session.zone_sim()
	hero.move.place(Vector2i(12, 12))
	hero.move.ground_h = sim.grid.height_at(Vector2i(12, 12))
	sim.set_stance(hero, "", 0)
	await _frames(10)
	view.camera.follow(view.actor_screen_pos(hero), 0.0, true)
	ContentDB.rules.game_speed = 0.2
	var facings := {"x+": Vector2(1, 0), "y+": Vector2(0, 1), "x-": Vector2(-1, 0), "y-": Vector2(0, -1),
			"diag": Vector2(1, 1).normalized()}
	for whip in [["water", "W02"], ["fire", "F06"]]:
		for f in facings:
			for d in [1, 3, 5]:
				var snap := 0.29 if whip[0] == "water" else 0.25
				await _console(session, hero, "fx " + whip[1], hero.move.pos + facings[f] * d, snap)
				await _crop("st5_%s_whip_%s_%d" % [whip[0], f, d], 480, 380)
				await _console(session, hero, "heal", hero.move.pos, 0.6)
	# Seismic Stomp on grass (here) and on stone (the nearest cobblestone).
	await _console(session, hero, "fx E04", hero.move.pos, 0.3)
	await _crop("st5_stomp_grass", 480, 380)
	await _console(session, hero, "heal", hero.move.pos, 1.0)
	var zone: ZoneDef = ContentDB.zones[&"crossing"]
	var stone := Vector2i(-1, -1)
	for r in range(1, 20):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var t := hero.tile() + Vector2i(dx, dy)
				if stone == Vector2i(-1, -1) and sim.grid.in_bounds(t) and sim.grid.is_walkable(t) \
						and String(zone.terrain_at(t)).contains("cobble"):
					stone = t
	if stone != Vector2i(-1, -1):
		hero.move.place(stone)
		hero.move.ground_h = sim.grid.height_at(stone)
		await _frames(6)
		view.camera.follow(view.actor_screen_pos(hero), 0.0, true)
		await _console(session, hero, "fx E04", hero.move.pos, 0.3)
		await _crop("st5_stomp_stone", 480, 380)
		await _console(session, hero, "heal", hero.move.pos, 1.0)
	# Fireball and Fire Dart at 0, 22.5 and 45 degrees on screen.
	ContentDB.rules.game_speed = 0.05
	for id in ["F07", "F03"]:
		for deg in [0.0, 22.5, 45.0]:
			var sdir := Vector2.from_angle(deg_to_rad(deg))
			# Screen to tile directions: x - y = sx / 32, x + y = sy / 16.
			var tdir := Vector2((sdir.x / 32.0 + sdir.y / 16.0) * 0.5, (sdir.y / 16.0 - sdir.x / 32.0) * 0.5).normalized()
			await _console(session, hero, "fx " + id, hero.move.pos + tdir * 4.0, 0.08)
			await _crop("st5_%s_%d" % [id, int(deg * 10)], 480, 380)
			await _console(session, hero, "heal", hero.move.pos, 0.4)
	ContentDB.rules.game_speed = 1.0


## A hero just behind a house and just in front of one, holding the water hoop and the
## fire ring: the house in front covers the looks; open ground in front doesn't cut them.
func phase2_behind_house(session: LocalSession, hero: Hero) -> void:
	session.world.move_hero(hero.id, &"town", Vector2i(10, 10))
	var view := await _view()
	var sim := session.zone_sim()
	var spots := {}
	for y in range(2, sim.grid.depth - 3):
		for x in range(2, sim.grid.width - 3):
			var t := Vector2i(x, y)
			if not sim.grid.is_walkable(t) or sim.grid.height_at(t) != 0:
				continue
			if not spots.has("behind") and sim.grid.height_at(t + Vector2i(1, 1)) >= 2 \
					and sim.grid.height_at(t + Vector2i(1, 0)) >= 2:
				spots.behind = t
			if not spots.has("open") and t.x > 6:
				var flat := true
				for dx in range(-2, 3):
					for dy in range(-2, 3):
						if sim.grid.height_at(t + Vector2i(dx, dy)) != 0 or not sim.grid.is_walkable(t + Vector2i(dx, dy)):
							flat = false
				if flat:
					spots.open = t
	for where in spots:
		hero.move.place(spots[where])
		hero.move.ground_h = 0
		for look in [["Water", 2], ["Fire", 1]]:
			sim.set_stance(hero, look[0], look[1])
			await _frames(8)
			view.camera.follow(view.actor_screen_pos(hero), 0.0, true)
			await _crop("st2_%s_%s_%d" % [where, String(look[0]).to_lower(), look[1]], 360, 300)
	sim.set_stance(hero, "", 0)
