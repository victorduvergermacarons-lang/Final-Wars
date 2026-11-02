extends GutTest
## Every zone must load in an exported game, not only in the editor.
##
## The exported game reads its data from a .pck built by the export, which can
## change resources on the way (Godot's export converts text .tres files to
## binary, and in 4.7.2 that conversion drops PackedStringArray values, so every
## tiled zone lost its height, walk and terrain rows). This test exports the
## data pack with the committed preset (export_presets.cfg, "Windows Desktop";
## exporting a pack needs no export templates), then starts Godot on that pack
## and loads the content through the ContentDB autoload, exactly as the shipped
## game does, and checks every zone.

const PRESET := "Windows Desktop"
const PROBE := "res://tests/export/export_probe.gd"


func test_project_keeps_text_resources_in_exports() -> void:
	assert_false(ProjectSettings.get_setting("editor/export/convert_text_resources_to_binary", true),
			"the text-to-binary conversion empties PackedStringArray rows (zones)")


func test_export_preset_is_committed_and_ships_the_json_data() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK, "export_presets.cfg is in the repository")
	var found := false
	for section in cfg.get_sections():
		if cfg.get_value(section, "name", "") == PRESET:
			found = true
			assert_eq(cfg.get_value(section, "platform", ""), "Windows Desktop")
			assert_string_contains(String(cfg.get_value(section, "include_filter", "")), "*.json",
					"tileset.json, ability_tree.json and act1.json are data the game reads")
	assert_true(found, "a \"%s\" preset" % PRESET)


func test_every_zone_loads_from_an_exported_pack() -> void:
	var godot := OS.get_executable_path()
	var project := ProjectSettings.globalize_path("res://")
	var pck := ProjectSettings.globalize_path("user://export_check/zones.pck")
	DirAccess.make_dir_recursive_absolute(pck.get_base_dir())
	if FileAccess.file_exists(pck):
		DirAccess.remove_absolute(pck)
	var out: Array = []
	var code := OS.execute(godot, ["--headless", "--path", project, "--export-pack", PRESET, pck], out, true)
	assert_eq(code, 0, "export succeeded")
	assert_true(FileAccess.file_exists(pck), "the pack was written")
	if not FileAccess.file_exists(pck):
		return
	# Run outside the project folder, so only the pack provides res://.
	out = []
	OS.execute(godot, ["--headless", "--main-pack", pck, "-s", ProjectSettings.globalize_path(PROBE)], out, true)
	var log: String = "\n".join(out)
	assert_string_contains(log, "EXPORT_PROBE_DONE", "the exported content loaded")
	var zones := 0
	for line in log.split("\n"):
		if not line.begins_with("EXPORT_PROBE_ZONE "):
			continue
		zones += 1
		var parts := line.split(" ")
		var heights := int(parts[2].trim_prefix("heights="))
		assert_gt(heights, 0, "rows survive the export: " + line)
		assert_true(line.ends_with("errors="), "no validation errors: " + line)
	assert_eq(zones, ContentDB.zones.size(), "every zone is in the exported game")
	assert_false(log.contains("SCRIPT ERROR"), "no script errors while loading the exported content")
	DirAccess.remove_absolute(pck)
