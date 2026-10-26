extends GutTest
## Creature sprite art (CreatureArtDef) and the wolf's sheets.

var wolf: EnemyDef
var art: CreatureArtDef


func before_all() -> void:
	wolf = ContentDB.enemies[&"wolf"]
	art = wolf.art


func test_wolf_sheets_have_the_expected_frames() -> void:
	assert_not_null(art)
	var expected := {"idle": 4, "run": 8, "bite": 15, "death": 12, "howl": 9}
	for anim in expected:
		assert_eq(art.frame_count(anim), expected[anim], anim)
		assert_eq((art.sheets[anim] as Texture2D).get_height(), 4 * 64, "%s: 4 rows, one per facing" % anim)


func test_sprite_frames_have_every_animation_and_direction() -> void:
	var sf := art.build_sprite_frames()
	for anim in ["idle", "run", "bite", "howl", "death"]:
		for dir in CreatureArtDef.DIRECTIONS:
			var name := StringName("%s_%s" % [anim, dir])
			assert_true(sf.has_animation(name), name)
			assert_eq(sf.get_frame_count(name), art.frame_count(anim), name)
	assert_true(sf.get_animation_loop(&"idle_sw"))
	assert_false(sf.get_animation_loop(&"death_ne"), "death plays once")
	var first: AtlasTexture = sf.get_frame_texture(&"bite_nw", 3)
	assert_eq(first.region, Rect2(3 * 64, 2 * 64, 64, 64), "row 2 is NW")


func test_bite_lands_on_the_jaw_frame() -> void:
	var bite: AbilityDef = ContentDB.abilities[&"wolf_bite"]
	assert_almost_eq(bite.windup_seconds, 12.0 / 30.0, 0.0001, "frame 12 at 30 fps = 0.4 s")
	assert_almost_eq(art.recovery_for(&"wolf_bite"), 2.0 / 30.0, 0.0001)


func test_grid_facing_maps_to_screen_diagonals() -> void:
	assert_eq(CreatureArtDef.direction_for(Vector2i(0, -1)), "ne", "grid up is screen up-right")
	assert_eq(CreatureArtDef.direction_for(Vector2i(1, 0)), "se")
	assert_eq(CreatureArtDef.direction_for(Vector2i(0, 1)), "sw")
	assert_eq(CreatureArtDef.direction_for(Vector2i(-1, 0)), "nw")


func test_pixel_art_import_settings() -> void:
	for anim in art.sheets:
		var path: String = (art.sheets[anim] as Texture2D).resource_path
		var cfg := ConfigFile.new()
		assert_eq(cfg.load(path + ".import"), OK)
		assert_false(cfg.get_value("params", "mipmaps/generate", true), "%s: no mipmaps" % path)
