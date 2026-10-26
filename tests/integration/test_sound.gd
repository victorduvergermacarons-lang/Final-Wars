extends GutTest
## Sound in the running game: the sound key catalogue (data/sound_catalog.gd), and
## the SoundDirector turning events, steps and fights into sounds and music.

const SETTINGS := "user://test_sound_settings.cfg"


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


func test_catalogue_names_sounds_by_key() -> void:
	var c := SoundCatalog.new(ContentDB)
	var keys := c.keys()
	for k in [&"fire_fireball_cast", &"fire_fireball_hit", &"fire_dart_cast", &"water_healing_touch_hit",
			&"weapon_slash_cast", &"creature_wolf_howl", &"creature_wolf_bite", &"creature_wolf_bite_hit",
			&"creature_wolf_step", &"creature_sunscale_drake_searing_dive_hit",
			&"creature_sunscale_drake_grounded", &"creature_salamander_hound_embers_hit",
			&"footstep_grass", &"footstep_default", &"ambience_town", &"ui_click", &"world_level_up"]:
		assert_true(keys.has(k), str(k))
	assert_false(keys.has(&"fire_fire_dart_cast"), "no doubled tree word")
	assert_false(keys.has(&"air_step_hit"), "a self buff never lands on anyone")
	assert_eq(c.cast_key(&"F07"), &"fire_fireball_cast")
	assert_eq(c.hit_key(&"S01"), &"weapon_slash_hit")
	assert_eq(c.cast_key(&"wolf_bite", &"wolf"), &"creature_wolf_bite")
	assert_eq(c.cast_key(&"searing_dive_hit"), &"", "parts of an ability only have a hit key")
	for k in keys:
		assert_eq(String(k), String(k).to_lower(), "lower case")
		assert_true(Audio.config.categories.has(String(k).get_slice("_", 0)), "%s has a folder" % k)


func test_game_sounds_and_combat_music() -> void:
	var game := Game.new()
	game.settings_path = SETTINGS
	add_child_autofree(game)
	game.start_solo(CharacterData.new_character("Tester", ContentDB.heroes[&"adventurer"]))
	var session: LocalSession = game.session
	var sound: SoundDirector = game.get_node("SoundDirector")
	assert_not_null(sound, "the game has a sound director")
	await wait_process_frames(2)
	assert_eq(sound.music_context(), MusicTrackDef.Context.TOWN, "Millbrook plays town music")
	assert_eq(Audio.context, MusicTrackDef.Context.TOWN)
	assert_eq(Audio.current_track.id, &"idle_draft")

	# Walking plays footsteps; sounds without files are skipped, never fatal.
	var hero := session.local_hero()
	session.send_intent({"type": "step", "to": hero.tile() + Vector2i.UP})
	await wait_physics_frames(12)
	await wait_process_frames(2)
	assert_true(Audio.missing_keys().keys().any(func(k): return String(k).begins_with("footstep_")),
			"a footstep was asked for")

	# A wolf next to the hero starts a fight: combat music, then back afterwards.
	session.send_intent({"type": "debug", "line": "spawn wolf"})
	await wait_physics_frames(4)
	var wolf: Enemy = null
	for a in session.actors():
		if a is Enemy:
			wolf = a
	assert_not_null(wolf, "a wolf spawned")
	await wait_physics_frames(10) # the hero's step has ended
	var beside := hero.tile() + Vector2i.RIGHT
	if not session.grid().is_walkable(beside):
		beside = hero.tile() + Vector2i.LEFT
	wolf.move.place(beside)
	session.send_intent({"type": "cast", "ability": &"S01", "target": wolf.id})
	await wait_physics_frames(10)
	await wait_process_frames(2)
	assert_true(hero.in_combat(session.now()), "the hero is fighting")
	assert_eq(sound.music_context(), MusicTrackDef.Context.COMBAT)
	assert_true(Audio.missing_keys().has(&"weapon_slash_cast"), "Slash asked for its sound")
	session.send_intent({"type": "debug", "line": "heal"})
	wolf.die()
	await wait_physics_frames(6)
	await wait_process_frames(2)
	assert_false(hero.in_combat(session.now()), "the fight is over")
	assert_eq(sound.music_context(), MusicTrackDef.Context.TOWN, "back to the zone's music")
