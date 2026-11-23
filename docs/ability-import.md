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

- Every column the game needs is present (extra columns are kept as-is), and the Timing
  columns read (see below).
- No duplicate IDs, ability names or teaching items; every ability has a Taught By item.
- Tiers are whole numbers 1–5.
- **Icon** (last column): a .png under `assets/icons/` (an error otherwise); a missing file
  is a warning (the game shows the placeholder). See CLAUDE.md, Icons.
- Mastery Required decides when each ability unlocks: "<its own tree> Mastery N" (another
  tree's name, or anything else, is an error). An empty cell takes the tier's threshold
  from the Tiers tab.
- **Unlock steps** (stance rework, 2026-11-23): each row's Mastery Required is a formula,
  the tier's base (Tiers tab, column B: 0 / 100 / 225 / 375 / 550) plus its **Unlock
  Step** (last-but-one column of the Abilities tab) times the tier's **Points per unlock
  step** (Tiers tab, column D: 25 / 30 / 35 / 40 / 50). The import checks that each row's
  number matches that sum, for every tree, weapons included; a mismatch is an error. To
  retune, edit the Tiers tab (or a row's Unlock Step), recalculate in Excel or LibreOffice,
  save, import.
- **Stances** (the Stance and Key columns): every Fire, Earth, Water and Air ability has a
  Key, one of
  - `S → B`: cast from stance S with branch key B (1–4). S must equal the tier, and each
    tree must fill all 5 × 4 stance slots exactly once.
  - `N (casts on entering stance N)`: the stance's entry cast (Fire Punch, Seismic Stomp,
    Octopus Form); at most one per stance.
  - `Passive`: always on once learned. Its Mastery Required lists the levels at which it
    gets stronger ("Water Mastery 200 / 400 / 600"; they must go up); it unlocks at the
    first. Cooldown 0 and no timing bar (errors); a hitbox other than None is a warning.
  - `Passive upgrade`: changes another ability, the first ability in its Prerequisites
    (Tidal Resurgence upgrades Healing Rain, Eye of the Storm upgrades Hurricane).
  Weapon rows have no Key.
- **Hybrids:** a bending ability that needs Mastery in another element should need 225
  (a warning otherwise).
- **Removed abilities** (merged in the stance rework) are refused if a row comes back:
  F13 Heat Wave (into Breath of Fire), E10 Fortress Stance (into Earth Armor), E12 Trench
  (into Earth Wall), A08 Glide (into Air Step). Characters holding their scrolls get the
  scroll of the ability each merged into (`CharacterData.RENAMED_ITEMS`).
- A warning when an ability's prerequisite (in the same tree) unlocks at more Mastery
  than the ability itself.
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

## Timing bars (the four Timing columns)

The sheet is the source of truth for timing bars too. The rules are on its **Timing
Rules** tab; per ability, at the end of the Abilities tab:

| Column | What to write |
|---|---|
| Timing Status | `Manual` (your design), `Generated (AI, not yet confirmed)` (a draft to review) or `Not implemented` |
| Timing Bar (s) | The bar's length in seconds, or `none` for no bar (an instant) |
| Timing Zones | Zones separated by `;`: `Tap a–b`, `Crit a–b` or `Hold a–b`, seconds from the bar's start, e.g. `Tap 0.35–0.65; Crit 0.45–0.55` or `Hold 0.75–2.75`. Dots or commas; `-` or `–` |
| Timing Notes | Free text |

Manual and Generated bars are both used by the game. The import refuses: an unknown
status, a zone it can't read or that goes past its bar, a hold that doesn't end 0.2–0.3 s
before the bar, a bar with no zones (or zones with no bar), and a "Not implemented" row
with a bar, and input zones that overlap. It warns about a crit outside every tap.
Several inputs are played in order (a tap then a hold, e.g. Aimed Shot). The behavior files no longer hold bars.

The import runs only when you run the command above, never while playing: the game
loads the already-converted JSON, so bars cost nothing at runtime.

Item ids are made from the item name (`Scroll of the Fireball` → `scroll_of_the_fireball`).
Renaming an item changes its id, so characters holding the old one lose it; ability IDs
(F01, W05…) are what saves and action bars use, so keep those stable.

## Hitboxes (the eight Hitbox columns, free movement)

What an ability hits since free movement. A short version is on the **Timing Rules**
tab ("Hitbox Rules"). Distances are in tiles.

| Column | What to write |
|--------|---------------|
| Hitbox Shape | `None` (a buff on yourself), `Targeted`, `Cone`, `Line`, `Circle`, `Projectile`, `Lob`, `Self Circle`, `Dash`, `Leap`, `Blink` or `Tiles` |
| Hitbox Range | Targeted: edge to edge; Cone, Line, Dash: length; Circle, Lob, Leap, Blink, Tiles: how far away you can aim |
| Hitbox Angle | A cone's width in degrees |
| Hitbox Width | A line's or a dash's width |
| Hitbox Radius | A circle's radius (Self Circle, Circle, Lob, Leap); for Tiles, tiles around the aimed one (1 = 3×3) |
| Projectile Speed | Tiles per second |
| Projectile Size | The projectile's radius |
| Pierce | `Yes` hits everything on its path; empty or `No` stops at the first |

Each shape needs some of them: Targeted a range, Cone a range and angle, Line and
Dash a range and width, Circle and Lob a range and radius, Projectile a range, speed
and size, Self Circle a radius, Leap / Blink / Tiles a range. The import refuses an
unknown shape, a missing value, a negative number, or values without a shape.
`Tiles` abilities (terrain, burning ground) stay on the tile grid.

## Behavior files

Each implemented ability has `content/tree/behaviors/<ID>.tres` (an `AbilityDef`: targeting,
range, area, effects). The buffs they apply live in `content/buffs/`. The first set was
written by a generator:

    godot --headless --path . -s res://tools/make_behaviors.gd          # only missing files
    godot --headless --path . -s res://tools/make_behaviors.gd -- --force  # rewrite all

Without `--force` it never touches existing files, so tune the `.tres` files in the
Godot inspector freely. Damage and healing use the tier default (`base_amount` = −1) plus
the sheet's Scales With stats, times the effect's `power` (light hits below 1, heavy
above). Name, cooldown, tier and Mastery numbers always come from the sheet.

When the game loads in a debug build it prints a **DODGE WARNING** for every skillshot or
telegraph that resolves faster than a step (step cooldown + 0.3 s).
