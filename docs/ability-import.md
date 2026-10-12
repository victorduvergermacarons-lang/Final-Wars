# Updating abilities from the spreadsheet

`design/Ability_Tree.xlsx` is the source of truth for every ability: names, trees,
tiers, prerequisites, the item that teaches it, cooldowns and Mastery values. The game
doesn't read the spreadsheet directly; an import step turns it into
`content/tree/ability_tree.json`, which the game loads.

## After editing the spreadsheet

1. Save it as **`design/Ability_Tree.xlsx`** (same name, same folder). On GitHub: open
   the `design` folder, *Add file → Upload files*, drop the new file in, and commit. Make
   sure it replaces `design/Ability_Tree.xlsx` rather than landing next to it under
   another name.
2. Run the import (from the project folder):

   ```bash
   godot --headless --path . -s res://tools/import_ability_tree.gd
   ```

   To import a file from somewhere else:
   `godot --headless --path . -s res://tools/import_ability_tree.gd -- /path/to/file.xlsx`
3. Read the output:
   - `Imported 145 abilities and 145 items in 7 trees` means it worked; commit
     `content/tree/ability_tree.json` together with the spreadsheet.
   - `ERROR: ...` lines list every problem (row numbers included); nothing is written
     until they're fixed.
   - `WARNING: ...` lines are worth a look but don't stop the import.

If you only upload the spreadsheet, the test suite fails with "ability_tree.json is out
of date" until someone runs step 2. That's on purpose.

## What the import checks

- Every column the game needs is present (extra columns are kept as-is).
- No duplicate IDs, ability names or teaching items; every ability has a Taught By item.
- Tiers are whole numbers 1–5; Mastery Required matches the Tiers tab (the Tiers tab wins).
- Every prerequisite is an ability name spelled exactly as in the Ability column (it
  suggests the right spelling when only capitals differ), or "<Tree> Mastery N", or
  "any element Mastery N". Prerequisites can't loop back on themselves.
- Tree names exist on the Trees tab, and the Item Type matches that tree.
- Targeting is Targeted, Skillshot, Ground or Self.
- Cooldown and the three Mastery numbers are numbers; Scales With names are known stats.

## What comes from where

| Taken from the sheet | Written in the game's data per ability |
|---|---|
| ID, name, tree, branch, tier, role, prerequisites, item and item type, Scales With, targeting type, cooldown, Mastery on Learn / per Use / Cap, and all the text columns | How it behaves: shape, range, area, effects, durations, damage numbers (`content/tree/behaviors/`) |

Optional columns **Base**, **Mana Cost**, **Range** and **Duration** are read as numbers
if you add them; they then override the game's defaults for that ability.

Abilities without behavior data yet are marked unimplemented in the game and can't be
equipped.

Item ids are made from the item name (`Scroll of the Fireball` → `scroll_of_the_fireball`).
Renaming an item changes its id, so characters holding the old one lose it; ability IDs
(F01, W05…) are what saves and action bars use, so keep those stable.
