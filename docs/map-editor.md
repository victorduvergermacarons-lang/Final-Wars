# Map editor

Paint the ground, heights and props of a map with the mouse; place, move and edit
its enemies, people, spawn points, graveyards, objects, landmarks and doors; change
its size; link its edges to other maps; make new maps. You see everything as the
game draws it, and save straight into the game's files.

## Opening it

Run the game **from the Godot editor** (F5) and click **Map Editor** on the main
menu (right page, under Host / Join). The button only appears there: an exported
`.exe` can't rewrite its own files, so your friends never see it.

Shortcut: run with `--map_editor` (Debug > Customize Run Instances, or the command
line) to open it directly.

Pick the map in the **Map** list at the top. Every hand-made map is there. The
Enemy Testing Grounds aren't: they are built from the enemy list each time the game
starts (other maps can still link to them).

Enemies and people stand frozen where they spawn.

## Tools (left panel, keys 1–7)

| Tool | Left click / drag | Right click |
|---|---|---|
| **1 Ground** | paint the ground chosen in the list | copy the ground under the mouse |
| **2 Height** | raise one level (each tile once per drag) | lower one level |
| **3 Props** | place the chosen prop | remove props |
| **4 Pick** | copy the tile's ground, height and prop, then back to Ground | |
| **5 Things** | place the chosen thing (it gets selected) | remove the thing under the mouse |
| **6 Select** | select a thing; click again for the next one on that tile; drag to move it | select nothing |
| **7 Shape** | add tiles of the ground chosen in the list, at **Level** (also beyond the map: it grows) | remove tiles |

- **Height:** tick **Exact level** (or change **Level**) to paint that height
  instead of raising. Heights go from 0 to 9. A hero climbs 2 levels at a time, so
  a jump of 3 or more is a cliff, and steps of 1 make a ramp.
- **Brush:** 1×1, 3×3 or 5×5 for the painting tools (`[` and `]` change it).
- **Grid** and **Height numbers** draw tile outlines and heights over the map. Red
  numbers are tiles you can't walk on.

### Shape: maps that aren't rectangles

The **Shape** tool changes the outline of the map.
- **Right-click / drag** removes tiles: nothing is left there, not even the bottom
  block. In the game a missing tile is a wall: nobody walks or flies into it and
  enemies go round it, but spells and arrows fly over it. The tiles around it show
  their sides, like the map's outer edge.
- **Left-click / drag** adds tiles of the ground chosen in the list, at the height in
  **Level**: into a hole, or past the map's side. A faint grid shows where tiles can
  go, a few tiles out from the map. Adding past a side grows the map (with a few
  spare rows, so a drag can carry on); like **Map size**, growing on the north-west
  or north-east side moves everything's coordinates for you.
- **Saving** cuts off rows and columns along the sides that hold no tile, so the
  map is always as small as its shape.
- Ground, height and props can't be painted on a hole, and nothing can be placed
  there. Things already standing where you remove tiles stay, and the check before
  saving names them ("… is where the map has no tile").
- The map must keep at least one tile. A map edge's gate is the tiles that exist
  along that side.

### Things

Choose a kind in the Things list, then what to place:

- **Enemies:** any enemy. Selected, you can change its type, its **level** (0 = the
  type's own level) and **respawn seconds** (−1 = the usual), and its **patrol**:
  click **Edit patrol**, then left-click tiles to add waypoints (the walk starts
  where it stands; numbered orange points joined by lines); right-click a waypoint to
  remove it; **Clear patrol** makes it stand guard again. Moving an enemy moves its
  route with it.
- **People:** each person stands in **one place in the whole game**. The list says
  where each one is now ("here", another map's name, or "not placed"). Placing
  someone who is already on this map moves them; placing someone from another map
  moves them here when you save. Selected, you can change which way they face.
- **Hero spawn point** (blue "Spawn" marker): where heroes arrive (`goto`, joining).
- **Graveyard:** where released heroes come back.
- **Objects:** well, cart, stall, ger, sign, mine and the rest, with an optional label
  shown over them. Objects block their tile (gers and mines block sight too).
- **Landmark:** the red banner with a name.
- **Doors** (purple marker): stepping on the tile takes you elsewhere. Choose
  "Lift (inside this map)" or "Door to …" another map. Selected, **Choose where it
  leads…** shows that map: click the arrival tile there (right-click or Esc
  cancels). A lift's arrival shows with a line on this map.

**Delete** (or the **Remove** button) removes the selected thing.

## Map size

**Map size** (top bar): add (+) or remove (−) rows and columns on each side:
north-east (top right), south-east (bottom right), south-west (bottom left),
north-west (top left). New tiles get the ground and height you choose.

Everything on the map keeps its place on the ground. Adding or removing on the
north-west or north-east side changes the coordinates of everything, and the
editor moves them for you: things on this map, patrols, lifts, and, when you save,
quest places in this map (reach spots, escort routes, places to examine), doors in
other maps that lead here, the matching edges of linked maps, and the boss fight's
victory spot. If shrinking would cut things off, it lists them and asks first.

## Connections

**Connections** (top bar): for each side, the map you walk into and an **offset**
that lines the two sides up (rows or columns). Under each side it says where its
open tiles arrive and how many land on walkable ground there. The other map gets
the matching edge (its opposite side, with the opposite offset) when you save, so
both maps always agree. Linked sides show their open tiles in green on the map,
with the destination's name.

## New map

**New map** (top bar): a name, a size, the starting ground and height, a region
(for the music) and the kind of music (town, explore or dungeon). It starts with a
hero spawn point and a graveyard in the middle; link it to another map in
Connections (or with a door) so heroes can walk there. Its file is
`content/zones/<name>.tres`, and its ambience sound key is added to
`AUDIO_SPEC.md`.

## Moving around

WASD or the arrow keys, or drag with the middle mouse button. Mouse wheel zooms.

## Undo and saving

- **Ctrl+Z** undoes a whole drag or one change to things, size or connections;
  **Ctrl+Y** (or Ctrl+Shift+Z) redoes.
- **Ctrl+S** or **Save** writes the map, and every other file the change reaches
  (see above). The status bar lists what was saved and what else changed.
- Before saving, the editor checks:
  - every spawn point, graveyard, person, enemy, patrol point, door and linked edge
    can still be reached on foot from where heroes start;
  - doors lead onto ground you can stand on, and back (a one-way door is reported);
  - each linked edge has open tiles that land on walkable ground;
  - no quest lost a person it needs, or every enemy of a kind it asks you to defeat.
  It lists what it found and asks whether to save anyway.
- Switching maps, making a new map or going **Back to menu** with unsaved changes
  asks first.
- After saving, **Play Solo** uses the new maps straight away (no restart).
- Commit the changed files in GitHub Desktop like any other change.

Big changes to the Act I maps can make some automatic tests fail, because they
stand on exact spots (for example a wolf at (8, 13)). That's expected: when you ask
to merge your map changes, the tests get updated with them.

## For programmers

`editor/`:
- `ZoneEdit`: the model. Painting (tile strokes) and whole-map steps (things, size,
  links: snapshots), undo, re-baking walkability into the rows and the live grid.
  The Shape tool's strokes are a `SHAPE` layer (`remove_tiles` / `add_tiles`);
  `grow_to_include` and `trim` are whole-map steps.
  Works on a copy loaded fresh from the file.
- `ZoneSaver`: writes with `ResourceSaver` and syncs the other files: partner edges,
  doors into the map, quests and the encounter after a shift, people moved away.
  Then it refreshes ContentDB.
- `ZoneCheck`: playability, links and quest people/enemies (also run on every map by
  `tests/unit/test_zone_layout.gd`).
- `EditorSession`: one frozen zone with the read API `WorldView` draws from.
- `MapEditor`: the screen. `EditorOverlay`: grid, numbers, markers, patrols, edges.

Missing tiles are `ZoneDef.NO_TILE` (a space) in `height_rows` and `terrain_rows`
(`#` in walk rows, `.` in prop and sight rows); `GridModel.has_tile` is false there.

`WorldView.refresh_tiles` redraws the cached ground around painted tiles. Tests:
`tests/unit/test_zone_edit.gd`, `tests/unit/test_map_shape_edit.gd`,
`tests/unit/test_map_shapes.gd` (the game's rules), `tests/integration/test_map_editor.gd` (both save
into a scratch folder, `ZoneSaver.redirect`); screenshots:
`tests/visual/map_editor_shots.tscn`. `tools/once/resave_zones.tscn` re-saved every
map once through the saver (2026-11-16).
