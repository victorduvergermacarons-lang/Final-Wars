extends GutTest
## The audio system (autoload/audio.gd): buses and volumes, music by context with
## fallbacks, crossfades, ducking and the bond hook, and the sound library
## (naming convention, missing files, variation, voices, positional sounds).

const AudioScript := preload("res://autoload/audio.gd")
const BEEP := "res://tests/fixtures/beep.wav"
const SETTINGS := "user://test_audio_settings.cfg"

var audio


func before_each() -> void:
	audio = AudioScript.new()
	add_child_autofree(audio)


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


func _track(id: StringName, contexts: Array, drained := false) -> MusicTrackDef:
	var t := MusicTrackDef.new()
	t.id = id
	t.file = "res://audio/music/music_idle_draft.ogg"
	t.contexts.assign(contexts)
	t.drained = drained
	return t


func test_buses_exist() -> void:
	for bus in ["Master", "Music", "Ambience", "SFX", "UI"]:
		assert_ne(AudioServer.get_bus_index(bus), -1, bus)


func test_the_first_track_plays_on_the_title_screen_and_in_town() -> void:
	var t: MusicTrackDef = audio.tracks.filter(func(x): return x.id == &"idle_draft")[0]
	assert_true(ResourceLoader.exists(t.file), "the OGG is imported")
	assert_true(t.loop)
	assert_eq(audio.pick_track(MusicTrackDef.Context.TITLE).track, t)
	assert_eq(audio.pick_track(MusicTrackDef.Context.TOWN).track, t)


func test_fallbacks() -> void:
	var town: MusicTrackDef = audio.pick_track(MusicTrackDef.Context.TOWN).track
	assert_eq(audio.pick_track(MusicTrackDef.Context.EXPLORE).track, town, "explore falls back to town music")
	assert_eq(audio.pick_track(MusicTrackDef.Context.DUNGEON).track, town, "dungeon -> explore -> town")
	assert_true(audio.pick_track(MusicTrackDef.Context.COMBAT).keep, "no combat track yet: keep what plays")
	assert_true(audio.pick_track(MusicTrackDef.Context.BOSS).keep, "boss -> combat -> keep")
	var fight := _track(&"fight", [MusicTrackDef.Context.COMBAT])
	audio.tracks.append(fight)
	assert_eq(audio.pick_track(MusicTrackDef.Context.COMBAT).track, fight)
	assert_eq(audio.pick_track(MusicTrackDef.Context.BOSS).track, fight, "no boss track: combat music")


func test_low_bond_picks_a_drained_variant_when_there_is_one() -> void:
	var normal: MusicTrackDef = audio.pick_track(MusicTrackDef.Context.TOWN, 0.1).track
	assert_false(normal.drained, "no drained track yet: the normal one plays")
	var drained := _track(&"town_drained", [MusicTrackDef.Context.TOWN], true)
	audio.tracks.append(drained)
	assert_eq(audio.pick_track(MusicTrackDef.Context.TOWN, 0.1).track, drained, "low bond: drained")
	assert_eq(audio.pick_track(MusicTrackDef.Context.TOWN, 0.9).track, normal, "healthy bond: normal")


func test_crossfade_takes_about_one_and_a_half_seconds() -> void:
	assert_almost_eq(audio.config.crossfade_seconds, 1.5, 0.001)
	audio.set_context(MusicTrackDef.Context.TITLE)
	assert_almost_eq(audio.music_fade(), 0.0, 0.001)
	audio.step(0.75)
	assert_almost_eq(audio.music_fade(), 0.5, 0.02, "halfway after 0.75 s")
	audio.step(0.8)
	assert_almost_eq(audio.music_fade(), 1.0, 0.001)
	var other := _track(&"explore", [MusicTrackDef.Context.EXPLORE])
	audio.tracks.append(other)
	var old_fade_index: int = audio._active
	audio.set_context(MusicTrackDef.Context.EXPLORE)
	assert_eq(audio.current_track, other)
	audio.step(0.75)
	assert_almost_eq(audio._fade[old_fade_index], 0.5, 0.02, "the old track fades out...")
	assert_almost_eq(audio.music_fade(), 0.5, 0.02, "...while the new one fades in")
	audio.step(0.8)
	assert_almost_eq(audio._fade[old_fade_index], 0.0, 0.001)


func test_same_track_does_not_restart() -> void:
	audio.set_context(MusicTrackDef.Context.TITLE)
	audio.step(2.0)
	audio.set_context(MusicTrackDef.Context.TOWN) # the same track serves both
	assert_almost_eq(audio.music_fade(), 1.0, 0.001, "no fade: it just keeps playing")


func test_combat_keeps_the_music_while_there_is_no_combat_track() -> void:
	audio.set_context(MusicTrackDef.Context.TOWN)
	var playing = audio.current_track
	audio.set_context(MusicTrackDef.Context.COMBAT)
	assert_eq(audio.current_track, playing)


func test_big_sounds_duck_the_music() -> void:
	audio.set_context(MusicTrackDef.Context.TITLE)
	audio.step(2.0)
	var full: float = audio.music_db(1.0)
	audio.duck()
	audio.step(0.2)
	assert_almost_eq(audio.music_db(1.0), full + audio.config.duck_db, 0.01, "ducked")
	audio.step(audio.config.duck_hold_seconds + audio.config.duck_release_seconds + 0.1)
	assert_almost_eq(audio.music_db(1.0), full, 0.01, "back up after it")


func test_sound_files_follow_the_naming_convention() -> void:
	var cfg: AudioConfig = audio.config
	assert_eq(cfg.file_for(&"fire_fireball_cast"), "res://audio/sfx/fire/fire_fireball_cast.wav")
	assert_eq(cfg.file_for(&"creature_wolf_howl"), "res://audio/sfx/creatures/creature_wolf_howl.wav")
	assert_eq(cfg.file_for(&"footstep_grass"), "res://audio/sfx/footsteps/footstep_grass.wav")
	assert_eq(cfg.file_for(&"ui_click"), "res://audio/sfx/ui/ui_click.wav")
	assert_eq(cfg.file_for(&"ambience_greenfields"), "res://audio/ambience/ambience_greenfields.ogg")
	assert_eq(cfg.category(&"ui_click").bus, "UI")
	assert_eq(cfg.category(&"fire_fireball_cast").bus, "SFX")


func test_missing_sounds_warn_and_play_nothing() -> void:
	assert_null(audio.play(&"fire_not_a_real_sound_cast"))
	assert_null(audio.play(&"fire_not_a_real_sound_cast"), "asking again is fine too")
	assert_true(audio.missing_keys().has(&"fire_not_a_real_sound_cast"))
	assert_null(audio.play(&"zzz_unknown_prefix"), "unknown categories don't crash either")
	assert_null(audio.play_at(&"creature_wolf_howl_missing", Vector2(10, 10), self))


func _beep_entry(key: StringName, ducks := false) -> void:
	var e := SfxDef.new()
	e.key = key
	e.file = BEEP
	e.ducks_music = ducks
	audio.config = audio.config.duplicate()
	audio.config.sfx.append(e)


func test_a_sound_plays_from_its_entry_with_variation() -> void:
	_beep_entry(&"ui_test_beep")
	var p = audio.play(&"ui_test_beep")
	assert_not_null(p)
	assert_true(p is AudioStreamPlayer, "UI sounds have no position")
	assert_eq(p.bus, &"UI")
	var pitches := {}
	for i in 20:
		pitches[snappedf(audio.varied(0.0, 0.08, 2.0).pitch, 0.001)] = true
	assert_gt(pitches.size(), 5, "repeated sounds vary")
	for i in 50:
		var v: Dictionary = audio.varied(0.0, 0.08, 2.0)
		assert_between(v.pitch, 0.92, 1.08)
		assert_between(v.volume_db, -2.0, 2.0)


func test_world_sounds_are_positional_and_limited() -> void:
	_beep_entry(&"creature_test_beep")
	var parent := Node2D.new()
	add_child_autofree(parent)
	var p = audio.play_at(&"creature_test_beep", Vector2(320, 64), parent)
	assert_true(p is AudioStreamPlayer2D, "world sounds are positional")
	assert_eq(p.position, Vector2(320, 64))
	assert_almost_eq(p.max_distance, audio.config.hearing_tiles * Iso.TILE_W, 0.01, "fade out with distance")
	for i in 10:
		audio.play_at(&"creature_test_beep", Vector2.ZERO, parent)
	assert_eq(audio._voices[&"creature_test_beep"], audio.config.max_voices, "no more than the voice limit at once")


func test_ducking_sounds_duck() -> void:
	_beep_entry(&"creature_test_roar", true)
	audio.play(&"creature_test_roar")
	audio.step(0.2)
	assert_gt(audio.duck_level(), 0.9)


func test_volumes_are_saved_per_player() -> void:
	audio.set_volume("Music", 0.25)
	audio.set_volume("SFX", 0.0)
	audio.save_volumes(SETTINGS)
	audio.set_volume("Music", 1.0)
	audio.set_volume("SFX", 1.0)
	audio.load_volumes(SETTINGS)
	assert_almost_eq(audio.get_volume("Music"), 0.25, 0.01)
	assert_almost_eq(audio.get_volume("SFX"), 0.0, 0.01, "zero mutes")
	audio.set_volume("Music", 1.0)
	audio.set_volume("SFX", 1.0)


func test_numbered_takes_play_in_turn() -> void:
	_beep_entry(&"footstep_test_takes")
	audio.config.sfx.back().file = "res://tests/fixtures/beep_take.wav" # only _1 and _2 exist
	var p = audio.play(&"footstep_test_takes")
	assert_not_null(p, "takes stand in for the missing single file")
	assert_true(p.stream is AudioStreamRandomizer)
	assert_eq(p.stream.streams_count, 2)
	assert_false(audio.missing_keys().has(&"footstep_test_takes"))
