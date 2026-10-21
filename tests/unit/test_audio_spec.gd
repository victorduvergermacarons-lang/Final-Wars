extends GutTest
## AUDIO_SPEC.md (written by tools/write_audio_spec.gd) lists every sound key the
## game plays, so the list handed to the sound designer never goes stale.


func test_the_spec_lists_every_sound_key() -> void:
	var spec := FileAccess.get_file_as_string("res://AUDIO_SPEC.md")
	assert_ne(spec, "", "AUDIO_SPEC.md exists")
	for k in SoundCatalog.new(ContentDB).keys():
		assert_true(spec.contains("`%s`" % k), "%s is in AUDIO_SPEC.md (run tools/write_audio_spec.gd)" % k)
