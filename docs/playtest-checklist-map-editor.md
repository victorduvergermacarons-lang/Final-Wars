# Playtest checklist: map editor

Run the game from the Godot editor (F5). How-to: `docs/map-editor.md`.
Tip: try things, then leave without saving (or undo) if you don't want to keep them.
Saving writes the real files: GitHub Desktop shows them, and Discard puts them back.

## Painting
- [ ] The main menu shows **Map Editor**; clicking it opens Millbrook with its people
      and wolves standing still.
- [ ] WASD / arrows and a middle-mouse drag move around; the wheel zooms.
- [ ] **Ground (1):** pick Water and paint a pond (try the 3×3 brush). The water
      ripples and gets a shoreline. Right-click a cobble tile: Cobble is chosen.
- [ ] **Height (2):** left-drag raises grass one level (dragging back over it doesn't
      raise it again); right-drag lowers it. Tick Exact level, set 3, paint a plateau.
- [ ] **Props (3):** place flowers and a boulder; right-click removes them.
- [ ] **Pick (4):** click a tile; its ground, height and prop are copied.
- [ ] **Grid** and **Height numbers** show; red numbers are tiles you can't walk on.
- [ ] **Ctrl+Z** takes back a whole drag; **Ctrl+Y** brings it back.

## Shape
- [ ] **Shape (7):** right-drag across a patch of grass: the tiles vanish, and the
      ground around shows its sides. **Ctrl+Z** brings them back.
- [ ] Pick Dirt in the list, set **Level** 1, and left-click a hole: dirt at height 1.
- [ ] Left-drag past the map's north-west side (the faint grid): new dirt appears out
      there, and the map grows (the size in the top bar goes up).
- [ ] Save: the size in the top bar shrinks back to just around the shape.
- [ ] Remove the tiles under the graveyard and save: a warning says it's where the
      map has no tile.
- [ ] Play: you can't walk into a hole; a Fire Dart flies across one; a wolf chasing
      you goes round it.

## Things
- [ ] **Things (5) → Enemies:** pick Wolf, click grass: a wolf appears, selected, with
      its settings on the left. Set its level to 3: its name says Lv 3.
- [ ] **Edit patrol:** click three tiles: numbered orange points and lines. Right-click
      one: it goes. **Clear patrol** removes them all.
- [ ] **Select (6):** drag the wolf to another tile: it moves with its patrol.
      **Delete** removes it. Ctrl+Z brings it back.
- [ ] **People:** the list says where each person is. Place Hilda somewhere else in
      Millbrook: she moves (she isn't copied). Change which way she faces.
- [ ] **Objects:** place a Well with a label; you can't walk through it in Play.
- [ ] **Landmark, Hero spawn point, Graveyard:** place one of each; spawns show a blue
      "Spawn" marker.
- [ ] **Doors:** place a "Door to The Crossing", then **Choose where it leads…**: the
      Crossing shows; click a tile. Back in Millbrook the door says "→ The Crossing".
      Save, Play Solo, walk onto it: you arrive there.
- [ ] Click a tile with two things on it twice: the selection switches between them.

## Size and connections
- [ ] **Map size:** add 3 on the north-west side. The map grows; everything stays on
      the same ground. Save: the status lists the other files it updated (if any).
- [ ] Shrink a side so the graveyard would be cut off: a question lists it first.
- [ ] **Connections:** each side shows where it leads and "N of N tiles walkable there".
      Change an offset: the line updates. Link the north-west side of a map to
      another map, save, open that map: its opposite side now leads back.
- [ ] Linked sides show green tiles on the map with the destination's name.

## New map and saving
- [ ] **New map:** "Test Glade", 20 × 20, grass. It opens with a spawn point and a
      graveyard. Link one side to Millbrook in Connections, save, Play Solo and walk
      there through Millbrook's matching side.
- [ ] Remove a quest giver (e.g. Captain Rowan) and save: a warning names the quest
      and the person. Answer No, undo.
- [ ] Surround the graveyard with water and save: a warning says it can't be reached.
- [ ] Changing maps or going Back to menu with unsaved changes asks first.
- [ ] GitHub Desktop shows the changed `content/zones/…` (and any quest) files.
      Commit to keep, or Discard to undo.
