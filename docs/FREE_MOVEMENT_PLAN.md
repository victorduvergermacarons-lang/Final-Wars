# Free movement and mouse-aimed combat: plan

Status: **approved 2026-11-01** with these changes from the first draft: movement is
**3 tiles/s in and out of combat**; drops of any height are allowed, **falling more
than 3 levels deals fall damage**, and falls follow gravity (§3.3); enemies follow the
same rules. The other proposals were accepted as written.

Veyra moves from a tile-locked game (one actor per tile, a step cooldown per tile,
abilities that hit tiles) to free movement with continuous positions, smooth
acceleration, circle colliders and mouse-aimed hitboxes. The tile grid stays as
the **world's data**: heights, walkability, sight blocking, terrain abilities and
ground zones. It stops being the grid that **units** live on.

Branch `feature/free-movement` from `main` (after #7 and #8 are merged), with the
current `main` tagged `v0.2-grid-final` first. One pull request at the end, not merged.

---

## 1. Ground rules

| Topic | Decision |
|-------|----------|
| World units | **1 unit = 1 tile edge.** Positions are `Vector2` floats in tile coordinates; the centre of tile (x, y) is the point (x, y). `tile()` stays as "the tile under my centre" (`round(pos)`), so spawns, zone files, quests, NPC placement, landmarks and terrain abilities need no data changes. |
| Sim tick | Stays **20 Hz** (0.05 s). Movement integrates once per tick, the same code on host and client (prediction). Rendering interpolates between ticks so motion is smooth at 60+ fps. If 20 Hz feels steppy in the playtest, the tick is one constant (`CombatRules.tick_seconds`); 30 Hz is the fallback (costs ~50% more sim time). |
| Facing | A **float angle** (`Actor.facing_angle`, plus a unit `Vector2`). In combat the hero faces the mouse; out of combat the movement direction (standing still keeps the last facing). Enemies face their movement, or their target while attacking. Sprites pick the nearest of the 4 diagonals (SW, SE, NW, NE), as the art already has. |
| Ranges | Measured **edge to edge**: centre distance minus both colliders' radii. So melee works the same against a wolf and the 5-tile drake, and "range 4" keeps meaning about 4 tiles of gap. |
| What stays on the grid | Heights and cliffs; walkable / sight-blocking tiles; **terrain abilities** (Raise Pillar, Earth Wall, and the future sinkhole, ramp, trench, lava, crater…); **persistent ground zones** (Burning Ground, Flame Dash's trail, Ice Spikes' field if kept as a zone, the drake's fires, ember trails, the Grey Heart's greyed tiles). A unit is in a zone or on terrain when **the tile under its centre** is. These snap to the tile under the cursor and keep today's tile preview. |
| Everything else | Continuous: positions, collisions, knockbacks, dashes, projectiles, cones, lines and circles. |

---

## 2. What changes, what stays

### Stays as it is
- `GridModel` data (height, walkable, sight). Zone files, tilesets, the bake step and the
  terrain cache don't change.
- Stats, buffs, cooldowns, the GCD, mana, threat tables, crits, Accuracy/Evasion for
  enemy melee, hit chance, party scaling, loot, XP, AP, Mastery, quests, dialogue,
  dungeons, the boss encounter logic (phases, pulses, wipe reset), saving.
- **Timing bars:** unchanged rules. Aimed abilities with a bar keep aiming at the end
  (the aim follows the mouse during the bar and fires at the last input).
- The intent → host → snapshot architecture; the host stays authoritative.

### Changes (by system)

| System | Today | After |
|--------|-------|-------|
| `MoveState` (sim/entities) | from/to tile + walk time | **`Motion`**: `pos`, `vel`, `wish_dir`, `facing_angle`, `height` (smoothed for drawing), `radius`; `to_dict` sends pos/vel/facing. `MoveState` is removed once every user is moved over. |
| Stepping (`WorldSim.try_step`, step intents, step cooldown, `walk_tile_seconds`, `Cooldowns.can_step`) | one tile per step, cooldown in combat | **removed**. A `move` intent carries the input direction (8-way, screen-relative, normalized) and the facing angle. No per-step cooldown. |
| Speed | Speed stat shortens the step cooldown; slows multiply it; Haste −25% | Speed stat raises move speed (`speed × (1 + Speed/100)`); slows divide it (×1.5 slow → speed / 1.5); Haste ×1.25; roots stop movement; Air Step's "free steps" becomes "+30% speed for 5 s" (Air Step reworked, §6). |
| Collision | one actor per tile (`is_occupied`) | **circle colliders**; terrain blocks per tile edge; units push and slide around each other (§3). |
| Height | `can_step(from, to, jump)` | climbing a tile edge needs rise ≤ Jump; drops are always allowed, 2+ levels is a gravity fall, more than 3 levels deals fall damage (§3.3). |
| Line of sight | tile line between tile centres | a **continuous segment** sampled through the tiles it crosses (DDA), compared with the line between the two eye heights; same tolerance. |
| High ground | height of tiles | height of the tile under each centre (same numbers). |
| Flanking | facing direction vs attacker tile | angle between the target's facing and the direction to the attacker: behind = more than 135°, side = 45–135°. |
| Abilities (`AbilityShapes`, `CastResolver`, `TileGeometry`) | tile lists | **`Hitbox`** shapes in data (§5), tested against colliders; projectiles fly in continuous space. |
| Knockbacks, pulls, dashes, charges, leaps | tile paths (`TileGeometry.push_path`) | continuous slides with collision (swept circle); "impact damage" when stopped early by a wall, cliff or unit. Distances keep their tile values. |
| Enemy AI (`EnemyBrain`) | tile chase, `_best_neighbor`, flank tiles | steering toward a path point, same behaviours (melee, kiter, flanker, patrols, leash, evade, howl, packs) with continuous distances (§7). |
| Pathfinding (`Pathfinder`) | A* tile to tile, 4-way | A* on the **tile graph, 8-way**, edges obeying the height rule and corner cutting, then **path smoothing** (string-pulling with a walkability sweep) and per-frame steering. Large bodies path on a graph inflated by their radius. Cached per enemy, re-planned when the target moves > 1 tile or the path is blocked. This is the navigation that respects heights, ramps and cliffs; a full navmesh isn't needed for tile-built maps (§7.1). |
| Networking | step intents, client step prediction | move-input intents, **prediction + reconciliation** for your hero, **interpolation** (~100 ms buffer) for everyone else (§4). |
| Input (`PlayerInput`) | held direction → step intents; hero faces mouse | 8-way WASD screen-relative (W = up the screen), `move` intent every tick the input or facing changes; aiming with the mouse. |
| View (`WorldView`, `CreatureAnimator`) | actors glide tile to tile | actors drawn at interpolated positions; back-to-front sort by continuous depth; run animation speed from actual velocity; aim indicators (§5.3). |
| Content | tile ranges and tile shapes in behaviors | hitbox fields in data; importer and spreadsheet gain the columns (§6). |

---

## 3. Movement (phase 1)

### 3.1 Feel, all values in data (`MovementDef`, `content/rules/movement.tres`)
| Value | Default | Why |
|-------|---------|-----|
| `walk_speed` | 3.0 tiles/s | user decision: the same in and out of combat |
| `combat_speed_factor` | 1.0 | user decision (kept as a value so it can be tuned) |
| `accel_time` | 0.10 s | 0 → full speed |
| `decel_time` | 0.08 s | full speed → 0 |
| `turn_rate` | instant | facing follows the mouse at once (as today) |
| per-terrain `friction` | 1.0 | a terrain may lower it for ice-like sliding (none do yet) |
| hero `radius` | 0.30 | fits through 1-tile gaps with room to spare |

Enemies get their own `move_speed` and `radius` in `EnemyDef` (replacing
`combat_step_seconds` / `patrol_step_seconds`, converted §7.3).

### 3.2 Collision
- Terrain: each unwalkable or sight-blocking tile is a solid square; each tile edge whose
  height difference breaks the height rule is a wall segment. A unit moves by
  **sub-stepped move-and-slide** (circle against axis-aligned edges and corners), so it
  slides along walls instead of sticking.
- Units: circles. After movement, overlapping pairs are pushed apart (mass by weight:
  heavy units move less; immobile and the dummy don't move). Allies and enemies both
  collide (no walking through monsters); dead heroes don't collide.
- A spatial hash (cell = 1 tile) keeps unit checks cheap.
- The Sunscale Drake: one circle of radius ~1.35 (covers today's plus of 5 tiles).

### 3.3 Height, drops and falling
- Each tile keeps one height. A unit's height is the tile under its centre.
- **Climbing:** crossing a tile edge upward is allowed when the rise is ≤ the unit's
  Jump (ramps and stairs are 1-level steps; Earth Wall's +2 stays climbable with Jump 2).
  Higher rises are cliff faces and block.
- **Dropping (user decision):** any drop is allowed. A 1-level drop is a step down,
  smoothed like a stair. A drop of **2 or more levels is a fall**:
  - the unit leaves the ledge with its horizontal speed and **falls under gravity**:
    its height `z` accelerates downward (`gravity`, data, default 40 levels/s², so a
    4-level drop takes about 0.45 s and lands fast, not at a constant glide);
  - while falling it can't steer, cast, or start a timing bar (casts in progress are
    cancelled, like being moved); it still collides with walls and units;
  - the shadow stays on the ground below it, so the fall reads clearly;
  - **fall damage** on landing for drops of **more than 3 levels**:
    `fall_damage_percent_per_level` (data, default 10%) of max HP for each level beyond
    3, capped at `fall_damage_max_percent` (default 60%), not reduced by defense. It
    shows as a floating number and a `world_fall` sound; it can't kill below 1 HP unless
    `fall_damage_can_kill` is set (default off) — a value to playtest.
- **Enemies use the same rules:** they can drop and take fall damage. Navigation treats
  drops as one-way edges that cost extra (more for damaging falls), so enemies prefer
  ramps unless a drop is much shorter; leashing enemies walk home by any legal path.
- Fliers (the drake) ignore heights as today and never fall.
- Raise Pillar / Earth Wall lift whoever stands on the tile (as today); a unit knocked
  off a high ledge falls (and can take fall damage).

### 3.4 Single-player first
Phase 1 keeps enemies on their old tile-stepping logic, adapted: their tile steps
become continuous slides between tile centres, so they collide and render with the
new system until phase 5 replaces their brains. Abilities still resolve through the
old shapes, using the tile under each unit. The game stays playable.

---

## 4. Networking (phase 2)

- **Intent:** `{"type": "move", "dir": Vector2 (−1..1, 8-way), "face": float, "seq": int}`
  sent each tick the input or facing changes (and a keep-alive every 0.5 s while moving).
  Sanitized: direction clamped and snapped to 8 ways, facing finite.
- **Host:** applies each hero's latest input every tick (the same `Mover` code as the
  client), acknowledges the last `seq`, sends pos/vel/facing in snapshots (still every
  tick; ~16 bytes more per actor before compression).
- **Client prediction (own hero):** runs the same movement on its inputs at the same
  tick rate, keeps unacknowledged inputs, and on each snapshot rewinds to the host
  position and replays them. Small errors (< 0.25 tile) are smoothed over 0.1 s; big
  ones snap.
- **Interpolation (everyone else):** a ~100 ms buffer of snapshots; actors are drawn
  between the two surrounding them (extrapolated briefly if one is late).
- **Hit fairness:** the host keeps 0.15 s of position history (today: tile history for the
  0.1 s skillshot grace); skillshot and cone hits against heroes check where the hero was
  within the grace window, so a hero who dodged on their own screen isn't hit by lag.
- **4-player network check** extended: guests move in all 8 directions and diagonals,
  their positions on the host match their own predicted positions within 0.25 tiles
  after settling, everyone sees everyone move, one guest fights a wolf and dodges a
  telegraph, and the three-zone test still runs. A latency mode (artificial 100 ms delay
  in the probe) checks reconciliation.

---

## 5. Hitbox system (phase 3)

### 5.1 Data (`HitboxDef`, a sub-resource on `AbilityDef`)
| Field | Meaning |
|-------|---------|
| `shape` | `TARGETED` (no hitbox, a chosen unit), `CONE` (arc/cone), `RECT` (line/rectangle from the caster), `CIRCLE` (at a point), `PROJECTILE`, `SELF_CIRCLE`, `DASH` (swept path), `TILES` (terrain/zone, grid) |
| `range` | max distance (edge to edge for targeted; to the aim point for circles, dashes, tiles) |
| `angle` | cone/arc width in degrees |
| `length`, `width` | rectangle |
| `radius` | circle / self circle |
| `projectile_speed`, `projectile_radius`, `pierce` | projectiles |
| `telegraph_seconds` | shown on the ground before it lands (existing field, kept) |
| `min_range` | (charges, pounces) |

`AbilityDef.targeting` (TARGETED / SKILLSHOT / GROUND / SELF) stays as the input mode;
the hitbox says what gets hit.

### 5.2 Resolution
Pure geometry in `sim/combat/hitbox.gd` (circle vs cone/rect/circle/capsule tests),
used by heroes and enemies alike; terrain blocks a cone/line beyond the first wall
(per ray), and projectiles stop at walls and cliffs higher than the line. Height still
limits melee (±2 levels) and gives the ranged high-ground bonus.

### 5.3 Aim indicators (client)
While aiming: a translucent **cone**, **rectangle**, **circle at the cursor** (clamped
to range), **projectile lane**, **dash path** (stopping where it would stop), or the
**tile preview** for terrain/zone abilities, as today. Red when out of range or blocked.
Enemy telegraphs draw the same shapes in red, brightening as they land.

### 5.4 Importer and spreadsheet
`design/Ability_Tree.xlsx` gains eight columns at the end of the Abilities tab:
**Hitbox Shape, Range, Angle, Width, Radius, Projectile Speed, Projectile Size, Pierce**,
plus a short "Hitbox Rules" note in the Timing Rules tab. The importer reads and
validates them (unknown shape, missing value for the shape, negative numbers) into
`ability_tree.json`; `TreeContent` builds each `HitboxDef`. Behavior files keep effects
and mana only. The columns are filled for all 145 abilities by a one-off script
(`tools/once/fill_hitbox_columns.py`, openpyxl), using the tables in §6 and Appendix B.

---

## 6. The 32 implemented abilities (phase 4)

Distances in tiles. "Melee" = targeted, range 1.0 edge to edge.

| ID | Ability | Today | New hitbox | Notes |
|----|---------|-------|------------|-------|
| F01 | Fire Punch | Targeted adjacent | Targeted, melee | timing bar kept |
| F02 | Fire Kick | Targeted adjacent | Targeted, melee | burn kept |
| F03 | Fire Dart | Skillshot any angle, 4, 16 t/s | Projectile, range 4.5, speed 16, size 0.25 | first unit |
| F04 | Sun Warrior's Breath | Self | Self (no hitbox) | |
| F05 | Flame Dash | Ground 8-way, 3 | Dash, length 3 toward the cursor (any angle), width 0.6 | trail burns the **tiles** crossed (grid zone) |
| F06 | Fire Whip | Skillshot 8-way line 3, pierce | Rect, length 3, width 0.9, pierce | any angle now |
| F07 | Fireball | Ground 5, 3×3, 0.4 s | Circle at point, range 5, radius 1.5, telegraph 0.4 | |
| F08 | Burning Ground | Ground 4, 3×3 zone 6 s | **Tiles (grid zone)**, range 4, 3×3 | snaps to tile |
| F09 | Blazing Combo | Targeted adjacent, knockback 1 | Targeted, melee; knockback 1.0 along caster → target | |
| W01 | Healing Touch | Targeted ally 2 | Targeted ally, range 2, LOS | |
| W02 | Water Whip | Targeted 3 | Targeted, range 3 | timing bar kept |
| W03 | Flow State | Targeted ally 3 | Targeted ally, range 3 | Haste = speed ×1.25 |
| W04 | Frost Shard | Skillshot 4, 12 t/s | Projectile, range 4.5, speed 12, size 0.25 | slow = speed ÷1.5 |
| W05 | Soothing Mist | Targeted ally 4 | Targeted ally, range 4 | |
| W06 | Water Pulse | Skillshot 8-way line 3, push 1 | Rect, length 3, width 1.2, pierce; push 1.0 along the aim | |
| W07 | Leeching Tide | Targeted 3 | Targeted, range 3 | |
| W08 | Tidal Blessing | Targeted ally 3 | Targeted ally, range 3 | |
| W09 | Ice Spikes | Ground 4, 3×3, 0.4 s | **Tiles (grid)**, range 4, 3×3, telegraph 0.4 | the brief lists it with the grid abilities |
| A01 | Air Palm | Targeted adjacent, knockback 1 | Targeted, melee; knockback 1.0 | |
| A02 | Gust | Targeted 3, interrupt | Targeted, range 3 | |
| A03 | Air Step | Self, 5 free steps | Self: **+40% speed for 4 s** | "free steps" no longer exist; to confirm |
| A05 | Air Blast | Targeted 3, knockback 3 | Targeted, range 3; knockback 3.0 | impact +25 |
| E01 | Rock Throw | Skillshot lob 0.3 s, 4 | Projectile (lob): lands at the cursor after 0.3 s, circle radius 0.5 | arcs over low walls |
| E03 | Raise Pillar | Ground 3 | **Tiles (grid)**, range 3, 1 tile | |
| E04 | Seismic Stomp | Self 3×3 taunt | Self circle, radius 1.6 | |
| E05 | Earth Wall | Ground 4 | **Tiles (grid)**, range 4, 3 tiles across the caster's facing (snapped to 8) | |
| S01 | Slash | Targeted adjacent | **Cone 100°, range 1.4** in front (mouse-aimed) | the brief's "attacks aim at the mouse": melee strikes become arcs |
| S04 | Lunge | Targeted 3, dash 2 | Dash, length 2 toward the target, then Targeted melee strike if adjacent | |
| B01 | Quick Shot | Targeted 5 | Targeted, range 5, LOS | |
| B02 | Aimed Shot | Skillshot 7, 1 s draw, 14 t/s | Projectile, range 7, speed 14, size 0.3 | |
| H01 | Smash | Targeted adjacent, 0.3 s wind-up | **Cone 70°, range 1.4** | |
| H02 | Ground Slam | Self 3×3 | Self circle, radius 1.6 | |

**Decision to confirm:** the brief says attacks aim at the mouse, while targeted
abilities keep a target. I propose: **weapon strikes that hit "the tile in front"**
(Slash, Smash) become mouse-aimed cones; **spells that lock on** (Fire Punch, Fire
Kick, Blazing Combo, Air Palm, Water Whip, Gust…) stay targeted with a range check, as
their sheet text says "locks on; can't miss".

Knockback, pull and dash distances keep their tile numbers, now in continuous space
(a 3-tile knockback slides 3.0 units, stopping early at walls, cliffs and units).

The 113 unimplemented abilities: proposed hitboxes in **Appendix B**, written to the
spreadsheet in phase 3 so they are ready when each is implemented.

---

## 7. Enemies (phase 5)

### 7.1 Navigation
- Graph = walkable tiles, 8-connected; an edge exists when the height rule allows it
  and, for diagonals, both side tiles are passable (no corner cutting). Fliers use
  `can_fly`; large bodies use a graph where tiles within their radius must be free.
- A* (bounded, as today's 1024-node chase limit), then string-pulling: drop waypoints
  while a capsule sweep between them stays walkable and on legal heights.
- Steering: seek the next waypoint, separate from nearby allies, slow on arrival.
  Re-plan when the target moved more than 1 tile from the planned goal, every 0.5 s at
  most, or when blocked.

### 7.2 Attacks
Each enemy ability gets a hitbox aimed at where the enemy **saw** its target
(`reaction_seconds`, kept), with a telegraph for big attacks so moving dodges them.

| Enemy | Ability | New hitbox |
|-------|---------|------------|
| Wolf, Iron Wolf | Bite | Cone 70°, range 1.2, wind-up 0.4 (from the art) |
| | Howl | Self (calls the pack within 6) |
| Goblin Shaman (kiter) | Shadow Bolt | Projectile range 5, speed 9, size 0.3 |
| Bandit Brute | Crushing Blow | Cone 120°, range 1.6, wind-up 0.6, **telegraphed** |
| Fen Skirmisher (flanker) | Quick Slash | Cone 90°, range 1.3, wind-up 0.3 |
| Old Grizzlehide | Cleave | Cone 120°, range 1.8, wind-up 0.4, telegraphed |
| | Charge | Dash 2–4 toward the target, width 1.2, telegraphed lane 1.0 s |
| Salamander Hound | Bite | Cone 70°, range 1.2, wind-up 0.3 |
| | Cinder Pounce | Leap to the point beside the target, circle radius 1.2 at landing, telegraph 0.6 |
| | Ember Trail | Tiles (grid zone) under it, as today |
| Sunscale Drake (radius 1.35, flying) | Talon Rake | Cone 90°, range 1.5, wind-up 0.5 |
| | Sunfire Breath | Cone 60°, range 4, telegraph 0.8; then a 3 s burning zone on the **tiles** the cone covered |
| | Searing Dive | Dash 2–5, width 2.7 (its body), telegraph 1.0 s; shoves aside + stun as today; burning trail tiles |
| Boar | Gore | Cone 70°, range 1.2, wind-up 0.4 |
| | Tusk Charge | Dash 2–3, width 0.9, telegraph 1.0 s |
| Human Husk, Grey Husk | Hollow Rake | Cone 90°, range 1.3, wind-up 0.6 |
| Grey Overseer | Overseer's Crush | Cone 90°, range 1.4, wind-up 0.6 |
| The Foreman | Pick-Hammer | Cone 80°, range 1.5, wind-up 0.5 |
| | Ground Slam | Circle radius 1.5 at the target's position, telegraph 1.0 s (was 1.8 s, which suited 1.5 s tile steps; at 3 tiles/s a hero crosses 1.5 tiles in 0.5 s, plus 0.3 s to react) |
| | Mine-Cart Charge | Dash 2–5, width 1.2, telegraph 1.1 s |
| The Grey Heart | — | immobile collider radius 0.6; pulses unchanged |
| Training Dummy | — | collider 0.35, never moves, can't be pushed |

### 7.3 Speeds (converted, then tuned in phase 6)
Today heroes take 1.5 s per tile in combat and enemies 0.5–2.0 s. Heroes now move at
3 tiles/s. Each enemy keeps roughly its old ratio to a fighting hero, compressed so the
fastest are only a little quicker than a hero (a wolf still can't be outrun, as rule 12
wants) and the slowest can be kited:

| Enemy | Today (s/tile) | Proposed speed (tiles/s) |
|-------|----------------|--------------------------|
| Salamander Hound | 0.5 | 3.5 |
| Fen Skirmisher | 0.6 | 3.4 |
| Wolf | 0.65 | 3.25 |
| Iron Wolf | 0.7 | 3.1 |
| Boar | (1.0) | 2.8 |
| Goblin Shaman | 0.9 | 2.7 |
| Old Grizzlehide | 1.0 | 2.7 (patrol 1.8) |
| Sunscale Drake | 1.2 | 2.5 |
| The Foreman | 1.1 | 2.1 |
| Husks, Overseer | 1.3 | 1.85 |
| Bandit Brute | 2.0 | 1.7 |

Collider radii: wolves, hounds, boars 0.35; humanoids 0.3; brute, husks, Grizzlehide,
Foreman 0.45; drake 1.35; Heart 0.6.

---

## 8. Every test affected

Counted on the current code: `tile()` appears in 41 test files, `move.place` in 40,
`GridModel.distance` in 15, step intents in 13. The rule: **update, don't delete**:
each test keeps checking the same behaviour in the new terms.

| Tests | What changes |
|-------|--------------|
| `test_move_state`, `test_cooldowns` (step parts), `test_grid_model` (`can_step`) | become `test_motion` / `test_mover` (acceleration, deceleration, diagonal normalization, slow/haste/root), `test_collision` (walls, corners, units, push by weight), `test_height_rules` (ramps, cliffs, drops) |
| `test_pathfinder` | 8-way graph, height edges, corner cutting, smoothing, large bodies, fliers |
| `test_line_of_sight`, `test_ability_shapes`, `test_effects_part1/2`, `test_first_abilities`, `test_ability_mechanics`, `test_ability_resolver` | hitbox geometry (cone/rect/circle/projectile/dash), knockbacks and dashes in continuous space, impact damage, LOS from continuous points |
| `test_enemy_behaviors`, `test_m3_content`, `test_salamander_hound`, `test_sunscale_drake` (in content tests), `test_foreman`, `test_party_scaling` | enemies placed at positions; "dodge by stepping away" becomes "dodge by moving out of the telegraph" |
| `test_world_sim`, `test_release_combat`, `test_npcs`, `test_quests`, `test_quest_objectives`, `test_dungeons`, `test_snapshot`, `test_intents`, `test_debug_commands` | `move` intents instead of `step`; positions in snapshots; talk/examine ranges as distances |
| `test_player_input`, `test_aiming` | 8-way screen-relative keys, aim indicators per shape |
| `test_zone_layout`, `test_act1_zones`, `test_testing_grounds` | reachability with the new height rule (8-way, drop limit); testing-grounds spacing from speeds and hitbox reach |
| `tests/balance/*` | bots move continuously (they can kite and dodge); targets re-measured in phase 6 |
| `test_act1_playthrough`, `test_testing_grounds_playthrough`, `test_quest_chain` | escorts and placement with positions |
| `tests/net/*` | the extended 4-player check (§4) |
| `tests/visual/*` | screenshots re-taken; new shots of each aim indicator and enemy telegraph |

New tests: prediction/reconciliation (`ClientWorld` replays inputs and converges),
interpolation, the importer's hitbox columns, every hitbox shape, every ability's hitbox
against its table above, every enemy attack dodgeable at hero speed (a new "dodge rule"
check replacing today's step-cooldown warning: telegraph ≥ distance-to-escape ÷ speed +
0.3 s reaction).

---

## 9. Risks

1. **Size.** It touches movement, combat, AI, networking, view, input and content at
   once. Mitigation: the phase order keeps the game runnable after each phase, with a
   compatibility layer (`tile()` derived from position) so quests, zones and terrain
   abilities don't change.
2. **Prediction drift.** Host and client must run the same movement code with the
   same inputs. Mitigation: one `Mover` used by both, a fixed tick, inputs tagged by
   tick, a reconciliation test, and a latency mode in the net check.
3. **Smoothness at 20 Hz.** Movement integrated at 20 Hz must render at 60+ fps.
   Mitigation: render interpolation; the tick can go to 30 Hz if needed.
4. **Collision corner cases.** Circles against tile corners, height edges and other
   units can jitter or tunnel. Mitigation: sub-steps (≤ 0.25 tile per sub-step), tests on
   every case, push-apart capped per tick.
5. **Pathfinding cost.** 8-way A* plus smoothing per enemy on 60-tile maps. Mitigation:
   bounded searches, caching, re-plan limits, sleeping zones (already in), measured
   with `tools/perf/sim_profile.tscn`.
6. **Balance shifts.** Everything was tuned for 1.5 s steps; free movement makes
   dodging much easier and kiting possible. Phase 6 re-measures every balance target;
   some will need new numbers (to be listed, not hidden).
7. **Falls.** Drops stay possible, so nothing becomes unreachable, but a fall can strand
   a unit below a cliff with no ramp back (as today) and now costs HP. Enemies pulled
   off ledges could take fall damage or get stuck below; their navigation and leash
   (walk home by any legal path, teleport home if none) cover it.
8. **Draw order.** Sorting units by continuous depth among tile columns of different
   heights is where today's "walking behind a wall" bugs lived. The existing wall
   screenshots (`13_behind_wall`…) are re-checked.
9. **Old saves.** Characters store no positions (they spawn in town), so saves are
   unaffected. `settings.cfg` keybinds for the action bar stay.

---

## 10. Phase order (each ends runnable, tests passing, committed)

1. **Hero movement and collision (single player), height rules.** `Motion`, `Mover`,
   collision, height edges, 8-way screen-relative input, facing by combat state,
   rendering at continuous positions; enemies and NPCs slide between tile centres via a
   compatibility path; abilities resolve on `tile()`. Tests updated.
2. **Networking.** `move` intents, host integration, prediction + reconciliation,
   interpolation, position history for hits; 4-player check extended.
3. **Hitbox system, aim indicators, importer.** `HitboxDef`, geometry, projectiles in
   continuous space, knockback/dash slides; aim indicators; spreadsheet columns filled
   for all 145; importer validation. Old shapes still work alongside.
4. **All 32 abilities reworked** to the table in §6; terrain and zone abilities kept
   on the grid with the tile preview; old tile shapes removed from hero abilities.
5. **Enemies.** Navigation, steering, continuous movement, attack hitboxes and
   telegraphs; all 14 enemy types (wolf, iron wolf, shaman, brute, skirmisher,
   Grizzlehide, hound, drake, boar, human husk, grey husk, overseer, Foreman, Grey
   Heart) and the dummy; the drake's collider and flight; NPC escorts on the new paths.
   `MoveState` and the tile-step code removed.
6. **Balance pass.** Speeds, ranges, hitbox sizes and telegraph times so enemies
   telegraph and players can dodge; bots that move; balance targets re-measured and
   updated; tests updated.

Then: docs (CLAUDE.md, a manual test checklist: slopes, cliffs, dodging telegraphs,
co-op smoothness, each ability type), the pull request with a summary per phase.

### Decisions (confirmed 2026-11-01)
1. Movement 3 tiles/s in and out of combat (user).
2. Drops of any height are possible; falls of 2+ levels follow gravity; more than 3
   levels deals fall damage; enemies follow the same rules (user).
3. Weapon strikes (Slash, Smash) become mouse-aimed cones; lock-on spells stay targeted.
4. Air Step becomes a short speed burst (+40% for 4 s), since steps no longer exist.
5. Sim stays at 20 Hz with render interpolation (30 Hz only if the playtest says so).
6. Enemy speeds as in §7.3, rescaled to the 3 tiles/s hero.

---

## Appendix A: current numbers this replaces
Hero walk 0.2 s/tile out of combat, 1.5 s/tile × 100/(100+Speed) in combat (min 0.5 s);
enemy step times per `EnemyDef.combat_step_seconds`; skillshot grace 0.1 s; dodge
warning when a telegraph or travel time is under step + 0.3 s.

## Appendix B: proposed hitboxes for the 113 unimplemented abilities
Generated from each ability's Targeting / Effect text (`targeting_details`, `effect`) and
reviewed; written into the spreadsheet's new columns in phase 3. "Terrain (grid)" and
"Zone (grid)" snap to tiles like today.

| ID | Ability | Sheet targeting | Hitbox | Values (tiles) |
|----|---------|-----------------|--------|----------------|
| F10 | Flame Wheel | Self | Self circle | r 1.5 |
| F11 | Jet Propulsion | Self | Self (no hitbox) | buff / stance |
| F12 | Fire Stream | Skillshot | Line (rect), channel | length 4, width 0.8, aim turns slowly |
| F13 | Heat Wave | Skillshot | Cone | 60°, r 3 |
| F14 | Breath of Fire | Skillshot | Cone | 60°, r 4 |
| F15 | Phoenix Kick | Targeted | Targeted | range 4, LOS, moves caster beside target |
| F16 | Inferno | Ground | Zone (grid) | range 6, 5x5 tiles |
| F17 | Lightning Bolt | Targeted | Targeted | range 8, LOS |
| F18 | Combustion Blast | Ground | Circle at point | range 10, r 1.5, telegraph 1s |
| F19 | Lightning Redirection | Self | Self (no hitbox) | counter: the next spell that hits you is sent back as a projectile |
| F20 | Blue Fire | Self | Self (no hitbox) | buff / stance |
| F21 | Solar Zenith | Self | Self (no hitbox) | buff / stance |
| E02 | Stone Skin | Self | Self (no hitbox) | buff / stance |
| E06 | Sinkhole | Ground | Terrain (grid) | range 4, tiles as written |
| E07 | Boulder Shield | Self | Self (no hitbox) | buff / stance |
| E08 | Rumbling Taunt | Self | Self circle | r 2.5 |
| E09 | Earth Ramp | Ground | Terrain (grid) | range 3, a ramp of tiles built along the aim direction |
| E10 | Fortress Stance | Self | Self (no hitbox) | buff / stance |
| E11 | Earthquake | Ground | Terrain (grid) | range 5, tiles as written |
| E12 | Trench | Ground | Terrain (grid) | range 3, tiles as written |
| E13 | Seismic Sense | Self | Self circle | r 6 (reveal) |
| E14 | Earth Armor | Self | Self (no hitbox) | buff / stance |
| E15 | Metalbending | Targeted | Targeted | range 4, LOS |
| E16 | Sandstorm | Ground | Zone (grid) | range 5, 4x4 tiles |
| E17 | Lavabending | Ground | Terrain (grid) | range 4, tiles as written |
| E18 | Mountain's Stand | Self | Self circle | r 2.5 |
| E19 | Living Fortress | Self | Terrain (grid) | range 3, tiles as written |
| E20 | Tectonic Shift | Ground | Terrain (grid) | range 3, tiles as written |
| W10 | Spirit Water | Targeted | Targeted | range 3, LOS |
| W11 | Water Jet | Skillshot | Projectile | range 5, speed 14, size 0.25, pierce |
| W12 | Water Shield | Targeted | Targeted | range 3, LOS |
| W13 | Ice Prison | Targeted | Targeted | range 4, LOS |
| W14 | Revive | Targeted | Targeted | range 3, LOS |
| W15 | Tidal Wave | Skillshot | Projectile (slow, wide) | length 5, width 3, speed 3 (walking pace), pierce, pushes |
| W16 | Rising Tide | Self | Self circle | r 3.5 |
| W17 | Healing Rain | Ground | Zone (grid) | range 5, 3x3 tiles |
| W18 | Steam Veil | Ground | Zone (grid) | range 5, 4x4 tiles |
| W19 | Bloodbending | Targeted | Targeted | range 4, LOS |
| W20 | Octopus Form | Self | Self circle (aura) | r 1.5, blocks projectiles |
| W21 | Full Moon | Self | Self (no hitbox) | buff / stance |
| W22 | Ocean Spirit | Self | Self circle | r 3.5 |
| W23 | Tidal Resurgence | Self | Self circle | r 3.5 |
| A04 | Wind Snare | Skillshot | Projectile | range 4, speed 14, size 0.25 |
| A06 | Vortex | Ground | Circle at point | range 5, r 2.5 |
| A07 | Stolen Breath | Targeted | Targeted | range 3, LOS |
| A08 | Glide | Self | Self (no hitbox) | buff / stance |
| A09 | Air Scooter | Self | Self (no hitbox) | buff / stance |
| A10 | Tornado | Skillshot | Projectile (slow, wide) | length 5, width 1.2, speed 2.5, pierce, drags |
| A11 | Air Sphere | Targeted | Targeted | range 4, LOS |
| A12 | Suffocate | Targeted | Targeted | range 3, LOS |
| A13 | Cyclone Spin | Self | Self circle | r 1.5 |
| A14 | Wind Walk | Ground | Blink to point | range 7, then self circle r 1.5 |
| A15 | Hurricane | Ground | Zone (grid) | range 6, 5x5 tiles |
| A16 | Updraft | Targeted | Targeted | range 4, LOS |
| A17 | Storm Front | Ground | Zone (grid) | range 5, 4x4 tiles |
| A18 | Pressure Lock | Self | Self circle | r 2.5 |
| A19 | Sky Dancer | Self | Self (no hitbox) | buff / stance |
| A20 | Weightless | Self | Self circle | r 4.5 |
| A21 | Eye of the Storm | Ground | Circle at point | range 6, r 3.5, telegraph 1s |
| S02 | Thrust | Skillshot | Line (rect) | length 2, width 0.8 |
| S03 | Parry | Self | Self (no hitbox) | 1 s block window (counter buff) |
| S05 | Double Slash | Targeted | Targeted | range 1 (melee) |
| S06 | Riposte | Self | Self (no hitbox) | buff / stance |
| S07 | Bleeding Cut | Targeted | Targeted | range 1 (melee) |
| S08 | Piercing Thrust | Skillshot | Line (rect) | length 2, width 0.8, pierce |
| S09 | Feint | Targeted | Targeted | range 1 (melee) |
| S10 | Flurry | Targeted | Targeted | range 1 (melee) |
| S11 | Disarm | Targeted | Targeted | range 1 (melee) |
| S12 | Execute | Targeted | Targeted | range 1 (melee) |
| S13 | Blade Dance | Ground | Dash path | length 3, width 0.8 |
| S14 | Focus Stance | Self | Self (no hitbox) | buff / stance |
| S15 | Thousand Cuts | Targeted | Targeted | range 1 (melee) |
| S16 | Counter Stance | Self | Self (no hitbox) | buff / stance |
| S17 | Shadow Step | Targeted | Targeted | range 4, LOS, moves caster beside target |
| S18 | Elemental Edge | Self | Self (no hitbox) | buff / stance |
| S19 | Perfect Strike | Targeted | Targeted | range 1 (melee) |
| S20 | Sword Saint | Self | Self (no hitbox) | buff / stance |
| B03 | Disengage | Self | Dash path | length 2, backwards |
| B04 | Hunter's Mark | Targeted | Targeted | range 6, LOS |
| B05 | Multi-Shot | Targeted | Targeted + 2 extra | range 5, LOS |
| B06 | Piercing Arrow | Skillshot | Projectile | range 6, speed 14, size 0.25, pierce |
| B07 | Poison Arrow | Targeted | Targeted | range 5, LOS |
| B08 | Pinning Shot | Skillshot | Projectile | range 5, speed 14, size 0.25 |
| B09 | High Ground | Self | Self (no hitbox) | buff / stance |
| B10 | Volley | Ground | Circle at point | range 7, r 1.5, telegraph 0.5s |
| B11 | Snipe | Targeted | Targeted | range 10, LOS |
| B12 | Explosive Trap | Ground | Terrain (grid) | range 3, tiles as written |
| B13 | Rapid Fire | Targeted | Targeted, channel | range 5, LOS |
| B14 | Camouflage | Self | Self (no hitbox) | buff / stance |
| B15 | Rain of Arrows | Ground | Zone (grid) | range 8, 5x5 tiles |
| B16 | Wind Arrow | Skillshot | Projectile | range 12, speed 14, size 0.25 |
| B17 | Kill Shot | Targeted | Targeted | range 8, LOS |
| B18 | Ricochet | Targeted | Targeted + bounces | range 5, LOS; bounces to enemies within 3 |
| B19 | Deadeye | Self | Self (no hitbox) | buff / stance |
| B20 | Arrowstorm | Ground | Zone (grid) | range 8, 7x7 tiles |
| H03 | Brace | Self | Self (no hitbox) | buff / stance |
| H04 | Wide Swing | Skillshot | Arc | 120°, r 1.6 |
| H05 | Shockwave | Skillshot | Projectile (wide) | length 4, width 1, speed 10, pierce |
| H06 | Concussive Blow | Targeted | Targeted | range 1 (melee) |
| H07 | Leap Slam | Ground | Leap to point + circle | range 3, r 1.5 at landing |
| H08 | Sweeping Strike | Skillshot | Arc | 120°, r 1.6 |
| H09 | Momentum | Self | Self (no hitbox) | buff / stance |
| H10 | Crater | Ground | Terrain (grid) | range 2, tiles as written |
| H11 | Hammer Cyclone | Self | Self circle | r 2.5 |
| H12 | Armor Crush | Skillshot | Arc | 120°, r 1.6 |
| H13 | Tremor | Ground | Zone (grid) | range 4, 3x3 tiles |
| H14 | Unstoppable | Self | Self (no hitbox) | buff / stance |
| H15 | Meteor Leap | Ground | Leap to point + circle | range 5, r 2.5 at landing, telegraph 0.75s |
| H16 | Earthshatter | Skillshot | Cone | 60°, r 4 |
| H17 | Thunderclap | Self | Self circle | r 2.5 |
| H18 | Juggernaut Charge | Ground | Dash path | length 5, width 0.8 |
| H19 | Worldbreaker | Ground | Circle at point | range 3, r 2.5, telegraph 1s |
| H20 | Titan's Fury | Self | Self circle | r 1.5 |
