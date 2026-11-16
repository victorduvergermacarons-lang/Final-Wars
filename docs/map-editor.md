# Map editor

Paint the ground, heights and props of a map with the mouse, see it as the game
draws it, and save it straight into the map's file.

## Opening it

Run the game **from the Godot editor** (F5) and click **Map Editor** on the main
menu (right page, under Host / Join). The button only appears there: an exported
`.exe` can't rewrite its own files, so your friends never see it.

Shortcut: run with `--map_editor` (Debug > Customize Run Instances, or the command
line) to open it directly.

Pick the map in the **Map** list at the top. Every hand-made map is there
(Millbrook, the Crossing, the Road to Deepcut, Deepcut, the Windsteppe, the Silent
Shaft, Greenfields, Tidereach Shore). The Enemy Testing Grounds aren't: they are
built from the enemy list each time the game starts.

Enemies and people stand frozen where they spawn, so you can see where they are.

## Tools (left panel)

| Tool (key) | Left click / drag | Right click / drag |
|---|---|---|
| **1 Ground** | paint the ground chosen in the list | copy the ground under the mouse |
| **2 Height** | raise one level (each tile once per drag) | lower one level |
| **3 Props** | place the prop chosen in the list | remove props |
| **4 Pick** | copy the tile's ground, height and prop, then back to Ground | |

- **Height:** tick **Exact level** (or change **Level**) to paint that height
  instead of raising. Heights go from 0 to 9. A hero climbs 2 levels at a time,
  so a jump of 3 or more is a cliff, and steps of 1 make a ramp.
- **Brush:** 1×1, 3×3 or 5×5 (`[` and `]` change it).
- **Grid** and **Height numbers** draw tile outlines and each tile's height over
  the map. Heights in red are tiles you can't walk on (water, walls, boulders).
- The status bar shows the map, "(unsaved changes)", and the tile under the mouse.

## Moving around

WASD or the arrow keys, or drag with the middle mouse button. Mouse wheel zooms.

## Undo and saving

- **Ctrl+Z** undoes a whole drag at once, **Ctrl+Y** (or Ctrl+Shift+Z) redoes.
- **Ctrl+S** or **Save** writes the map into its file (`content/zones/<map>.tres`).
  Only the ground, height and prop rows change in the file; enemies, people,
  objects, exits and settings stay exactly as they were. The walk and sight rows
  are updated for you.
- Before saving, the editor checks the map is still playable: every spawn point,
  graveyard, person, enemy, patrol point, exit and map edge must be reachable on
  foot from where heroes start. If something isn't, it lists it and asks whether
  to save anyway.
- Switching maps or going **Back to menu** with unsaved changes asks first.
- After saving, **Play Solo** uses the new map straight away (no restart).
- Commit the changed `.tres` in GitHub Desktop like any other change.

## Not in this version

Placing or moving enemies, people, spawn points, graveyards and objects, and
making a map bigger or smaller. Edit those in the `.tres` file for now (see
`docs/tilesets.md`).

## For programmers

`editor/`: `ZoneEdit` (painting, undo, re-baking walkability into the rows and the
live grid), `ZoneFile` (writes rows and legends into the .tres in place),
`ZoneCheck` (playability, also used by `tests/unit/test_zone_layout.gd`),
`EditorSession` (one frozen zone with the read API `WorldView` draws from),
`MapEditor` (the screen), `EditorOverlay` (grid and height numbers).
`WorldView.refresh_tiles` redraws the cached ground around painted tiles. Tests:
`tests/unit/test_zone_edit.gd`, `tests/integration/test_map_editor.gd`;
screenshots: `tests/visual/map_editor_shots.tscn`.
