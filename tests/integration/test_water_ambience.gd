extends GutTest
## The water emitters in a running solo game (WaterAmbience): they appear near
## Millbrook's river, never more than the cap, on the Ambience bus, at different
## points of the loop, fade in, go quiet away from water, and fade out on leaving.

const SETTINGS := "user://test_water_settings.cfg"

var game: Game
var hero: Hero
var water: WaterAmbience


func before_each() -> void:
	game = Game.new()
	game.settings_path = SETTINGS
	add_child(game)
	game.start_solo(CharacterData.new_character("Brook", ContentDB.heroes[&"adventurer"]))
	hero = game.session.local_hero()
	water = (game.get_node("SoundDirector") as SoundDirector).water


func after_each() -> void:
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


## A walkable tile 2 tiles from Millbrook's water, found from the map.
func _beside_water() -> Vector2i:
	var zone: ZoneDef = game.session.zone()
	var grid: GridModel = game.session.grid()
	var tiles := []
	for b in WaterSound.index(zone, ContentDB.tilesets[zone.tileset]).values():
		tiles.append_array(b)
	for t in tiles:
		for d in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			if grid.in_bounds(t + d) and grid.is_walkable(t + d):
				return t + d
	return Vector2i(-1, -1)


func _far_from_water() -> Vector2i:
	var zone: ZoneDef = game.session.zone()
	var index := WaterSound.index(zone, ContentDB.tilesets[zone.tileset])
	var grid: GridModel = game.session.grid()
	for y in grid.depth:
		for x in grid.width:
			var t := Vector2i(x, y)
			if grid.is_walkable(t) and WaterSound.near(index, Vector2(t), water.config.water_radius_tiles + 1.0).is_empty():
				return t
	return Vector2i(-1, -1)


func test_emitters_appear_beside_the_river_and_fade_in() -> void:
	assert_eq(game.session.zone().id, &"town")
	hero.move.place(_beside_water())
	water.step(water.config.water_update_seconds) # the next look around
	assert_between(water.emitter_count(), 1, water.config.water_max_emitters)
	var starts := []
	for e in water.emitters():
		var p: AudioStreamPlayer2D = e.player
		assert_eq(p.bus, &"Ambience", "the Ambience slider controls it")
		assert_not_null(p.stream, "ambience_water is in")
		assert_true(p.playing)
		assert_true((p.stream as AudioStreamOggVorbis).loop, "it loops")
		starts.append(p.get_playback_position())
		assert_lt(e.fade, 1.0, "fading in")
	for i in 30:
		water.step(0.05)
	for e in water.emitters():
		assert_almost_eq(e.fade, 1.0, 0.001, "faded in after about a second")
		assert_gt((e.player as AudioStreamPlayer2D).volume_db, -40.0, "audible beside the water")
	if starts.size() > 1:
		assert_ne(starts[0], starts[1], "emitters don't play in step")


func test_never_more_than_the_cap() -> void:
	water.config.water_max_emitters = 1
	hero.move.place(_beside_water())
	for i in 40:
		water.step(0.05)
	assert_eq(water.emitter_count(), 1)
	water.config.water_max_emitters = 3


func test_quiet_away_from_water() -> void:
	hero.move.place(_beside_water())
	for i in 40:
		water.step(0.05)
	var far := _far_from_water()
	assert_ne(far, Vector2i(-1, -1), "Millbrook has dry ground more than 10 tiles from water")
	hero.move.place(far)
	for i in 40:
		water.step(0.05)
	assert_eq(water.emitters().size(), 0, "faded out and gone")


func test_a_new_zone_fades_the_old_emitters_out() -> void:
	hero.move.place(_beside_water())
	for i in 40:
		water.step(0.05)
	var before := water.emitters().size()
	assert_gt(before, 0)
	water.set_view(water.view) # same zone: nothing changes
	assert_eq(water.emitter_count(), before)
	water._zone_id = &"elsewhere" # as if the map changed
	water.set_view(water.view)
	assert_eq(water.emitter_count(), 0, "old emitters are fading out")
	assert_eq(water.emitters().size(), before, "still there while they fade")
