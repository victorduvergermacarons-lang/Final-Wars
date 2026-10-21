extends GutTest
## The Settings window: one volume slider per bus, applied at once, saved per player.

const PATH := "user://test_settings_window.cfg"


func after_each() -> void:
	for bus in AudioConfig.BUSES:
		Audio.set_volume(bus, 1.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_a_slider_per_bus_that_changes_and_saves_the_volume() -> void:
	var w := SettingsWindow.new()
	w.settings_path = PATH
	add_child_autofree(w)
	assert_eq(w.sliders.keys(), AudioConfig.BUSES, "Master, Music, Ambience, SFX, UI")
	w.sliders["Music"].value = 40
	assert_almost_eq(Audio.get_volume("Music"), 0.4, 0.01, "applies at once")
	w.sliders["UI"].value = 0
	assert_almost_eq(Audio.get_volume("UI"), 0.0, 0.01, "0 mutes")
	w.save()
	var saved := SettingsStore.load_volumes(PATH)
	assert_almost_eq(saved["Music"], 0.4, 0.01)
	assert_almost_eq(saved["UI"], 0.0, 0.01)
	assert_almost_eq(saved["Master"], 1.0, 0.01)
