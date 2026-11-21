extends GutTest
## What plays in every zone, for each context (2026-11-21): Millbrook and Greenfields
## have their own track, the Crossing its own, the Silent Shaft its dungeon track (the
## Foreman's fight keeps it until his boss file exists), the Windsteppe and Tidereach
## their region's explore tracks; the draft plays on the title screen and where nothing
## else fits. "keep" = whatever already plays carries on.

const AudioScript := preload("res://autoload/audio.gd")
const C := MusicTrackDef.Context

## zone -> [what its own context plays, combat, boss]
const EXPECTED := {
	&"town": [&"town_millbrook", "keep", "keep"],
	&"greenfields": [&"town_millbrook", "keep", "keep"],
	&"crossing": [&"town_crossing", "keep", "keep"],
	&"deepcut": [&"idle_draft", "keep", "keep"],
	&"deepcut_road": [&"idle_draft", "keep", "keep"],
	&"silent_shaft": [&"dungeon_silentshaft", "keep", "keep"],
	&"windsteppe": [&"explore_windsteppe", "keep", "keep"],
	&"tidereach_shore": [&"explore_tidereach", "keep", "keep"],
	&"wilds": [&"idle_draft", "keep", "keep"],
}

var audio


func before_each() -> void:
	audio = AudioScript.new()
	add_child_autofree(audio)


func _play(ctx: int, z: ZoneDef):
	var r: Dictionary = audio.pick_track(ctx, 1.0, z.region, z.id)
	if r.keep:
		return "keep"
	return r.track.id if r.track != null else "silence"


func test_every_zone_plays_its_music() -> void:
	assert_eq(EXPECTED.size(), ContentDB.zones.size(), "every zone is listed here")
	for id in EXPECTED:
		var z: ZoneDef = ContentDB.zones[id]
		var want: Array = EXPECTED[id]
		assert_eq(_play(z.music_context, z), want[0], "%s (%s)" % [id, C.keys()[z.music_context]])
		assert_eq(_play(C.COMBAT, z), want[1], "%s in a fight" % id)
		assert_eq(_play(C.BOSS, z), want[2], "%s against an elite" % id)


func test_the_draft_no_longer_plays_in_millbrook_or_greenfields() -> void:
	for id in [&"town", &"greenfields"]:
		var z: ZoneDef = ContentDB.zones[id]
		for ctx in [C.TOWN, C.EXPLORE]:
			assert_eq(_play(ctx, z), &"town_millbrook", "%s, %s" % [id, C.keys()[ctx]])
	assert_eq(audio.pick_track(C.TITLE).track.id, &"idle_draft", "the title screen keeps the draft")


func test_the_new_tracks_are_imported_and_loop() -> void:
	for id in [&"town_millbrook", &"town_crossing", &"dungeon_silentshaft"]:
		var t: MusicTrackDef = audio.tracks.filter(func(x): return x.id == id)[0]
		assert_true(ResourceLoader.exists(t.file), "%s is imported" % id)
		assert_true(t.loop)


func test_the_foreman_track_takes_over_once_its_file_exists() -> void:
	var shaft: ZoneDef = ContentDB.zones[&"silent_shaft"]
	var boss: MusicTrackDef = audio.tracks.filter(func(x): return x.id == &"boss_foreman")[0]
	var stand_in := boss.duplicate()
	stand_in.file = "res://audio/music/music_idle_draft.ogg" # stands in for the missing file
	audio.tracks.append(stand_in)
	assert_eq(_play(C.BOSS, shaft), &"boss_foreman", "the boss track wins in his fight")
	assert_eq(_play(C.DUNGEON, shaft), &"dungeon_silentshaft", "the dungeon track otherwise")
