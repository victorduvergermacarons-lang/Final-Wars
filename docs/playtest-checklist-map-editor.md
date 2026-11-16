# Playtest checklist: map editor

Run the game from the Godot editor (F5). How-to: `docs/map-editor.md`.
Tip: try things on a map, then leave without saving (or undo) if you don't want to keep them.

- [ ] The main menu shows **Map Editor**; clicking it opens Millbrook with its people
      and wolves standing still.
- [ ] WASD / arrows and a middle-mouse drag move around; the wheel zooms.
- [ ] **Ground:** pick Water in the list and paint a pond (try the 3×3 brush). The
      water ripples and gets a shoreline. Right-click a cobble tile: Cobble is chosen.
- [ ] **Height:** left-drag over grass raises it one level (dragging back over it
      doesn't raise it again); right-drag lowers it. Tick Exact level, set 3, paint a
      plateau.
- [ ] **Props:** place flowers and a boulder; right-click removes them.
- [ ] **Pick (4):** click a tile; its ground, height and prop are copied, and the
      tool goes back to Ground.
- [ ] **Grid** and **Height numbers** show; red numbers are tiles you can't walk on.
- [ ] **Ctrl+Z** takes back a whole drag; **Ctrl+Y** brings it back.
- [ ] Surround the graveyard (next to the Healer's Hut) with water and press
      **Ctrl+S**: a warning says the graveyard can't be reached. Answer No, undo.
- [ ] Make a small change and save: the status says "Saved town.tres". Back to menu,
      **Play Solo**: your change is there, and you can walk on (or not into) it.
- [ ] Change maps in the **Map** list with unsaved changes: it asks first.
- [ ] GitHub Desktop shows only `content/zones/<map>.tres` changed. Commit it if you
      want to keep it, or discard it.
