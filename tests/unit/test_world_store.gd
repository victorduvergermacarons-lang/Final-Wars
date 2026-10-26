extends GutTest

const PATH := "user://test_world.json"


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_flags_round_trip_and_missing_file() -> void:
	var store := WorldStore.new(PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	assert_eq(store.load_flags(), {})
	store.save({"bridge_repaired": true})
	assert_eq(WorldStore.new(PATH).load_flags(), {"bridge_repaired": true})


func test_corrupt_file_loads_as_empty() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	assert_eq(WorldStore.new(PATH).load_flags(), {})
