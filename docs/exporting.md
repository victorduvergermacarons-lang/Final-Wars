# Exporting the game

The Windows preset is committed in `export_presets.cfg` ("Windows Desktop", x86_64,
`build/windows/FinalWars.exe` with `FinalWars.pck` beside it; `build/` is ignored by git).

1. Install the export templates for Godot 4.7.2 once (Editor → Manage Export Templates →
   Download and Install).
2. Project → Export… → Windows Desktop → Export Project. Or from a terminal:
   `godot --headless --path . --export-release "Windows Desktop" build/windows/FinalWars.exe`

## Keep text resources as text

`project.godot` sets `editor/export/convert_text_resources_to_binary=false`. With
Godot's default (true), the export converts every `.tres` to binary, and in 4.7.2 that
conversion drops `PackedStringArray` values and script-made defaults: every tiled zone
lost its `height_rows`, `walk_rows` and `terrain_rows` ("Invalid zone: crossing: empty
height_rows", a grey world) and the ability-tree tuning lost its stat blocks. Text
resources load the same in the editor and in the export. Leave this setting off.

The game's `.json` data (`assets/tiles/*/tileset.json`, `content/tree/ability_tree.json`,
`content/dialogue/act1.json`) is listed in the preset's include filter.

## Checking an export

`tests/integration/test_export_zones.gd` exports the data pack with the committed
preset (no templates needed for a pack), starts Godot on that pack and loads the
content through ContentDB, as the shipped game does, then checks every zone. To check
a real build's pack by hand:

    godot --headless --main-pack build/windows/FinalWars.pck -s tests/export/export_probe.gd

Each zone prints a line with its rows and validation errors, then `EXPORT_PROBE_DONE`.
