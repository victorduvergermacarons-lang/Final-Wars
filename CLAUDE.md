# CLAUDE.md — Living Design Doc

2D open-world co-op RPG in Godot 4 (latest stable 4.x, GDScript).

This file is the living design doc. Keep it current as decisions are made.

**Status:** Milestone 1 complete and playtested, including the post-M1 combat revision
(facing, directional abilities, faster enemies, reaction delay). Milestone 2 is in progress
(plan and decisions below). For the numbers the game actually uses today, see **Gameplay as built** below;
the brief sections keep the original wording.

## Working agreements
- Propose structure/architecture changes and wait for approval before implementing them.
- Work in small steps; commit after each one.
- Ask before making any design decision this brief doesn't cover. Record the
  answer in the **Decisions log** below.

## Vision
- 2D open world on an isometric grid with height levels, inspired by Final Fantasy
  Tactics Advance (FFTA).
- Online co-op for up to 4 players; also playable solo. Each player controls one hero.
- Main story questline, side quests, and difficult dungeons built for co-op groups.
- Character stats inspired by World of Warcraft.

## Movement and combat
- Out of combat: real-time, tile-by-tile movement (like classic Pokémon). Holding a
  direction moves continuously one tile at a time.
- Combat happens seamlessly on the overworld grid; there is no separate battle screen.
  When a hero aggros enemies, they enter combat mode and combat rules apply. Other
  players join the fight and enter combat mode. The rest of the world keeps running
  normally.
- Combat is fully real-time and never pauses. There is no turn order.
  - Every single step in combat has a short cooldown (step cooldown).
  - Every ability has its own cooldown, plus a short global cooldown (GCD) after any
    ability, like WoW.
- Height matters: a Jump stat limits how many height levels a hero can climb per step.
  Ranged abilities may get bonuses from higher ground (keep it configurable).
- Death works like WoW: at 0 HP the hero dies. An ally with a resurrection ability can
  revive them in place. Otherwise the player releases, respawns at the nearest graveyard
  point, and walks back.

## Stats (starting set, data-driven so we can tune)
HP, Mana, Physical Attack, Magic Attack, Physical Defense, Magic Defense, Crit Rate,
Crit Damage, Speed, Accuracy, Evasion, Jump.

## Progression (no fixed classes; archetypes emerge from gear)
- Each equipped item adds its stats.
- Each item defines per-level stat growth. When a hero levels up, they permanently gain
  a fraction of the growth of every item they have equipped at that moment.
  Include a configurable cap or diminishing returns, off by default.
- Items teach abilities, FFTA-style: while the item is equipped, the hero can use its
  ability and earns ability points (AP) from leveling up. At the AP threshold, the
  ability is mastered and stays usable permanently, even without the item.
- Abilities scale with specific stats defined per ability, e.g.
  damage = base + 1.2 × Magic Attack.
- All mastered abilities are available. Players place them on customizable action bars
  with keybinds, like WoW.

## Architecture requirements
- Keep the game simulation (grid, stats, combat, cooldowns) separate from rendering, so
  logic is testable and network-friendly. The grid model stores each tile's height and
  walkability independently of the TileMap visuals.
- Networking: use Godot's high-level multiplayer (ENet). One player hosts and acts as the
  authority. Clients send intents only ("step to tile X", "cast ability Y on target Z").
  The host validates cooldowns, range, and line of sight, resolves results, and
  replicates state. Design it so we could later move to a dedicated server.
- Data-driven content: define items, abilities, enemies, and stat formulas as Godot
  Resources (.tres), so they can be tuned without code changes.
- Write unit tests for combat math, cooldowns, leveling, item growth, and AP mastery,
  using GUT or gdUnit4.

## Milestone 1: build only this
- One small isometric zone (about 30×30 tiles) with a few height levels. Use placeholder
  art (colored tiles and simple shapes are fine).
- Two players connect over the internet or LAN by direct IP: one hosts, one joins.
- Each player controls one hero with real-time tile movement out of combat.
- One enemy type with simple AI: idle, aggro when a hero comes in range, step toward its
  target on its step cooldown, attack on cooldown, leash back if pulled too far.
- Players enter combat mode on aggro; the second player can join the fight and enter
  combat mode.
- 3–4 starter items, each with stats, per-level growth, and one teachable ability:
  e.g. sword (melee strike), staff (fireball), shield (taunt or block),
  holy charm (heal plus resurrect).
- Working action bar with keybinds, GCD, and per-ability cooldown display; HP/Mana bars.
- Gaining XP, leveling up, and receiving item growth; earning AP and mastering an ability.
- Death, release, respawn point, and resurrection by an ally.
- Document how to run two local instances for testing (Godot's Debug >
  Customize Run Instances).

## Out of scope for milestone 1
Quests, story, dungeons, save/load, inventory UI beyond basic equipping, matchmaking,
final art, sound, and more than 2 players. Don't build these yet, but don't make
choices that block them.

## Gameplay as built (end of Milestone 1, after playtest)

Quick reference of the values in the shipped content and `content/rules/default_rules.tres`.
Tune them there; update this table when they change.

### Changes from the original brief
- **Combat steps are slow, not short:** 1.5 s per tile at 0 Speed (floor 0.5 s). Out of
  combat there is no step cooldown; walking takes 0.2 s per tile.
- **Facing:** every actor faces a direction. Tap a direction to turn in place, hold to walk.
- **Directional combat:** melee hits the tile in front; Fireball is a projectile flying
  straight ahead. Click-targeting remains only for Heal and Resurrect.
- **Enemies outpace heroes in combat** (Wolf 0.8 s/tile) and react 0.3 s late, so
  sidestepping an attack works.
- **Shield teaches Block** (not Taunt); **Holy Charm teaches two abilities** (Heal and
  Resurrect).
- **Block** doubles Physical Defense for 6 s, off the GCD; under the D/(D+100) formula
  that is ~22% less damage at level 1, not half.
- **Level-up refills HP and Mana.** No hero auto-attack.

### Timing
| What | Value |
|------|-------|
| Sim tick | 20 Hz (0.05 s) |
| Walk (out of combat) | 0.2 s per tile, no step cooldown |
| Hero step in combat | 1.5 s × 100 / (100 + Speed), min 0.5 s |
| GCD | 1.0 s |
| Leave combat | 5 s after no enemy lists you |
| Tap-to-turn threshold | 0.12 s |

### Abilities
| Ability | From | Shape | Effect | Cost / cooldown | AP to master |
|---------|------|-------|--------|-----------------|--------------|
| Strike | Sword | Front, 1 tile, ±2 height | 8 + 1.0×PhysAtk physical | GCD only | 20 |
| Fireball | Staff | Line, 5 tiles, 10 tiles/s, ranged | 25 + 1.2×MagAtk magical | 15 mana, 2.5 s | 20 |
| Block | Shield | Self buff | Physical Defense ×2 for 6 s | 20 s, off GCD | 20 |
| Heal | Holy Charm | Targeted ally, range 4 | 20 + 1.0×MagAtk heal | 15 mana | 20 |
| Resurrect | Holy Charm | Targeted dead ally, range 3 | Revive at 30% HP/Mana | 30 mana, 30 s | 30 |
| Bite (Wolf) | — | Front, 1 tile, ±2 height | 6 + 1.0×PhysAtk physical | 2 s | — |

### Heroes, items, enemies
| Thing | Stats | Per-level growth |
|-------|-------|------------------|
| Adventurer (base) | HP 120, Mana 60, PhysAtk 10, MagAtk 10, PhysDef 10, MagDef 10, Crit 5%, Jump 2 | — |
| Sword (main hand) | PhysAtk +12, Accuracy +5 | PhysAtk 4, HP 10 |
| Staff (main hand, one-handed) | MagAtk +14, Mana +30 | MagAtk 4, Mana 8 |
| Shield (off hand) | PhysDef +30, HP +30 | PhysDef 3, HP 12 |
| Holy Charm (accessory) | MagAtk +6, Mana +20, MagDef +5 | MagAtk 2, Mana 6, MagDef 2 |
| Wolf | HP 230, PhysAtk 12, PhysDef 5, Evasion 5, Jump 1; aggro 4, leash 10; 50 XP; respawn 30 s; 0.8 s/tile; 0.3 s reaction | — |

Growth: 50% of each equipped item's growth per level. XP to next level: 100 × level.
AP: 10 per level-up to each ability taught by an equipped item.
Regen: 2%/s HP and Mana out of combat; 0.5%/s Mana in combat. Release: 50% HP/Mana at
the nearest graveyard.

## Architecture (approved 2026-10-11)

**Engine:** Godot 4.7.x (pinned to 4.7.2-stable), GDScript, GL Compatibility renderer.
**Tests:** GUT 9.7.1 (vendored in `addons/gut`), run headless with `./run_tests.sh`.

**Core rule: the simulation is plain GDScript with no scene nodes.** `sim/` holds all
rules (grid, stats, cooldowns, combat, AI, progression) as `RefCounted` classes. It
advances on a fixed tick (~20 Hz), takes intents in, and emits events out. RNG is
injected so tests are deterministic.

- **Host** runs the only authoritative `WorldSim`.
- **Clients** render replicated state and send intents.
- **The host's own player** sends intents through the same path as remote players
  (loopback), so moving to a dedicated server only changes who runs the sim.

```
Input ─► Intent ─► [network] ─► Host WorldSim (validates cooldowns/range/LOS, resolves)
                                     │
                                     ├─ snapshots (~10–20 Hz) ─► client mirrors ─► view (interpolated)
                                     └─ events (damage, death, level up, mastered) ─► UI / effects
```

- **Networking:** ENet, direct-IP host/join. Intents, snapshots and events are explicit
  RPC messages of plain data (Dictionaries/Arrays). No `MultiplayerSynchronizer`,
  because replication should not be tied to scene nodes.
- **Content:** Resource scripts in `data/defs/`, tuned values as `.tres` in `content/`:
  `StatBlock`, `ItemDef`, `AbilityDef`, `EnemyDef`, `HeroDef`, `ZoneDef`, `CombatRules`
  (all tunable constants: hit/crit/mitigation, GCD, height bonus, growth cap, XP curve…).
- **Grid:** `GridModel` stores height + walkability per tile, built from `ZoneDef`.
  The view draws tiles from the model (placeholder diamonds with side faces), not
  from a TileMap. A TileMap → `ZoneDef` baker can come later.

### Folders
```
project.godot, run_tests.sh, .gutconfig.json
addons/gut/      GUT test framework (vendored)
autoload/        net (ENet host/join), content_db (loads .tres)
sim/             world_sim + grid/ stats/ combat/ progression/ entities/ ai/
net/             intents, snapshot, server_session, client_session
data/defs/       Resource scripts (*_def.gd, stat_block.gd, combat_rules.gd)
content/         items/ abilities/ enemies/ heroes/ zones/ rules/ (.tres)
view/            world view, iso tile renderer, actor views, camera
ui/              main menu, HUD (action bar, unit frames), death dialog, equip panel
input/           player input → intents
scenes/          main.tscn and other top-level scenes
tests/unit/      GUT tests (test_*.gd)
docs/            how-to docs (building, testing, local multiplayer)
```

### Build order (milestone 1)
1. Project skeleton, GUT, headless test script.
2. Resource definitions + `StatBlock` + stat formulas, with tests.
3. `GridModel`, Jump climbing rule, pathfinding, line of sight, with tests.
4. Cooldowns: per-ability, GCD, step cooldown, with tests.
5. Damage/heal math, ability resolution, threat, with tests.
6. Progression: XP/levels, item growth (cap off by default), AP/mastery, with tests.
7. `WorldSim`: intents, combat mode, enemy AI, death/release/respawn/resurrect, with tests.
8. Rendering of zone and actors, playable solo.
9. ENet host/join, intents and snapshots.
10. HUD: action bar, keybinds, GCD/cooldown sweeps, HP/Mana bars, basic equipping.
11. Content: 4 starter items + enemy, tuning.
12. Doc for running two local instances.

## Game rules decided beyond the brief (approved 2026-10-11)
1. **Directions:** 4 grid directions, no diagonals.
2. **Occupancy:** one actor per tile, allies included; no swapping in M1.
3. **Height:** one height per tile (no bridges/overhangs yet; would need a layered grid).
4. **Speed:** shortens the in-combat step cooldown (1.5 s per tile at 0 Speed, never
   below 0.5 s). Out of combat there is no step cooldown at all: heroes walk tile to
   tile at a fixed walking speed (`walk_tile_seconds` = 0.2 s), and the next step
   starts as soon as the previous one arrives. The host only rejects steps that start
   before the current walk has arrived.
5. **Combat membership:** each enemy keeps a WoW-style threat table. Damage and healing
   add threat; taunt forces you to the top. A hero is in combat while any enemy lists
   them. Healing/buffing a hero in combat puts you on that enemy's table too. Combat
   ends a few seconds after no enemy lists you.
6. **Line of sight:** blocked if an intermediate tile rises above the line between the
   attacker's and target's heights (configurable tolerance). High-ground bonus is
   +X% per height level of advantage, X in `CombatRules`.
7. **Combat math** (all constants in `CombatRules`):
   - Hit % = 95 + (Accuracy − Evasion) × 1, clamped to 50–100. Heals, buffs, taunts
     and resurrects always land.
   - Mitigation = Def / (Def + 100), physical or magical per effect. Hits deal ≥ 1.
   - Crit chance = Crit Rate %. Crit multiplier = 1 + (50 + Crit Damage) / 100.
     Heals can crit.
   - Ranged abilities: +10% damage per height level above the target; no penalty
     from below.
   - Mana is spent up front; a miss still costs mana and starts cooldowns.
   - Threat: damage → threat equal to damage dealt. Healing → effective healing × 0.5,
     split evenly across the enemies fighting the healed target (puts the healer on
     their tables). Taunt → top threat + 10%.
   - Resurrect restores 30% HP and 30% Mana.
8. **Equipment slots:** Main Hand, Off Hand, Accessory, Body. M1: Sword (main hand),
   Staff (main hand, one-handed), Shield (off hand), Holy Charm (accessory). Every hero starts with
   all four available to equip.
   Abilities taught: Sword → Strike; Staff → Fireball; Shield → Block (temporary buff
   that doubles Physical Defense, off the GCD); Holy Charm → Heal **and** Resurrect (two abilities,
   so items may teach more than one).
   **Ability shapes** (`AbilityDef.shape`):
   - FRONT: hits whoever stands on the tile(s) straight ahead; an empty tile whiffs
     (still costs mana/GCD/cooldown). Strike and Wolf Bite: 1 tile, only targets within
     2 height levels.
   - LINE: a projectile flying straight ahead up to its range at the caster's height,
     stopping at the first enemy or at terrain more than the LOS tolerance above it;
     passes through allies (no friendly fire). Fireball: 5 tiles at 10 tiles/s.
   - TARGETED: on the chosen target, with range and line of sight (Heal, Resurrect;
     Block targets self).
9. **XP/AP/progression** (constants in `CombatRules`):
   - Each kill's XP is split evenly among heroes on the enemy's threat table.
     Each enemy type sets its XP reward.
   - XP to go from level L to L+1 = 100 × L. Extra XP carries over. No level cap
     (`max_level` = 0).
   - Level-up: gain 50% of every equipped item's per-level growth, permanently.
     Growth limit modes CAP (per-stat maximum) and DIMINISHING (gain ×
     half_point / (half_point + growth so far)) exist but are off by default.
   - Level-up gives 10 AP to every unmastered ability taught by an equipped item;
     each ability sets its own AP threshold (`ap_to_master`). AP progress is kept
     when the item is unequipped.
   - Level-up refills HP and Mana to full.
10. **Regen & respawn:** out of combat 2% max HP and 2% max Mana per second; in
    combat 0.5% max Mana per second, no HP regen. Release (any time, no auto-release)
    → graveyard nearest the death spot, or the nearest free tile to it, at 50% HP and
    Mana. Resurrect → 30% HP and Mana, in place. Dead heroes don't block tiles.
    Enemies respawn at their spawn tile at full HP after their timer, waiting if the
    tile is occupied. All configurable.
11. **Party:** in M1 all connected players are one party. Real party system later.
12. **World sim & enemy AI** (approved 2026-10-11):
    - Fixed 20 Hz tick on the host.
    - Gear can only be changed out of combat.
    - Aggro: an idle enemy aggros on the nearest living hero within its aggro radius
      and in line of sight. Damage also pulls it. No group/social aggro.
    - In combat the enemy attacks the top of its threat table whenever an ability is
      ready and in reach; otherwise it paths toward the target on its step cooldown.
      It turns to face a target next to it (free) before a FRONT attack.
    - Per enemy type: `combat_step_seconds` (Wolf 0.8 s/tile, faster than heroes'
      1.5 s, so heroes can't outrun an aggroed Wolf) and `reaction_seconds` (Wolf
      0.3 s): the enemy sees heroes where they were that long ago — for aggro,
      chasing, turning and aiming — so a well-timed sidestep makes a bite whiff.
    - Leash: past its leash radius from spawn, or with an empty threat table, the
      enemy evades: clears threat, heals to full, is untargetable, walks home.
    - Combat ends 5 s after no fighting enemy lists the hero.
    - Heroes have no auto-attack; they only use action-bar abilities.
13. **View & controls** (approved 2026-10-11):
    - Isometric tiles 64×32 px, 16 px per height level; camera follows the hero,
      mouse-wheel zoom.
    - W/↑ = grid up (screen up-right), D/→ = right (down-right), S/↓ = down
      (down-left), A/← = left (up-left), like FFTA.
    - Every actor faces one of the four directions (arrow on the ground). Stepping
      turns you. Pokémon-style: from a standstill, tapping a direction you don't face
      only turns you; holding it (> 0.12 s) walks. Turning is free and instant, in
      combat too.
    - WoW-style targeting (click an actor, Tab cycles nearby enemies, Esc clears) is
      used by TARGETED abilities; ally abilities fall back to self. FRONT/LINE
      abilities aim where you face; their action bar slot is red when nothing would
      be hit.
    - Placeholder art: height-tinted tiles, blue water, grey rocks, heroes as
      circles, enemies as red diamonds, floating combat text.
    - Test zone "Greenfields" (30×30): hill, height-4 plateau reached by a ramp,
      river with two bridges, two graveyards, five Wolves.
14. **Networking** (approved 2026-10-11):
    - Main menu: name, Play Solo, Host (port 7777), Join (address + port).
    - The host plays too; its intents go through the same `receive_intent()` +
      `Intents.sanitize()` path as remote players.
    - Host → clients every tick: full snapshot (deflate-compressed, ~0.6 KB) plus
      the event stream. Content is referenced by id, never sent.
    - Client-side prediction for the local hero's steps; host corrects via
      acknowledged intent sequence numbers. Abilities are not predicted.
    - Client disconnect → hero removed (enemies drop it from threat). Host
      disconnect → clients return to the menu with a message.
    - `Net.MAX_PLAYERS` = 4 (M2). Joining sends your saved character; the host
      validates it (`CharacterData.restore`). Each client gets its own snapshot:
      other heroes' bag, gold, AP, XP and quests are never sent.
    - The host (or solo player) saves world state (one-time events) to
      `user://world.json`; each player saves their own character.
15. **HUD** (approved 2026-10-11):
    - One action bar of 10 slots on 1–9, 0. Cooldown sweep + seconds, GCD sweep.
      Tint: blue = not enough mana, red = out of range / no valid target, dark =
      not usable right now (item unequipped and not mastered; the slot stays).
    - Spellbook (P): drag abilities onto slots; drag between slots to swap;
      right-click clears. Newly available abilities auto-fill the first empty slot,
      once per ability.
    - Keybind mode: hover a slot and press a key; movement/target/panel keys are
      reserved. Layout and keybinds are saved to `user://settings.cfg` (client
      preference, not game progress).
    - Unit frames: player (with XP), target, party members (click to target).
    - Character panel (C): one dropdown per equipment slot, stats, AP progress.
    - Death: centered "Release to graveyard" button (R also works).
    - Errors shown mid-screen in red for 2 s; message log bottom-left.
16. **Milestone-1 balance targets** (approved 2026-10-11; enforced by
    `tests/balance/test_balance.gd`, numbers via `tests/balance/balance_report.tscn`):
    - Sword hero solo vs 1 Wolf: ~8 s, ~50% HP lost (measured after the combat
      revision: 8.5 s, 57%, standing still without dodging). 2 Wolves solo without
      healing is usually lethal; a pair handles 2 Wolves.
    - Fireball hits ~2× Strike but one Wolf costs ~60% of a staff hero's mana.
    - Wolf: 230 HP, 50 XP, respawn 30 s. Fireball: 25 + 1.2×MagAtk, 15 mana, 2.5 s cd.
      Shield: +30 Physical Defense.
    - Leveling: level 2 after 2 Wolves, level 3 after 6. Starter abilities master
      at 20 AP (2 level-ups), Resurrect at 30 AP.
    - Block cuts Wolf bites by ~22% at level 1 (D/(D+K) can never halve damage by
      doubling D; its share grows with Physical Defense). Block is off the GCD, so
      using it costs no attack time.

## Milestone 2: the core RPG loop (brief, 2026-10-11)

### Up to 4 players
- Support 4 players per session. Players can join a session already in progress and
  spawn in town.
- Handle disconnects: a disconnected player's hero leaves the world cleanly. If the host
  disconnects, clients return to the main menu with a clear message.

### Equipment and inventory
- Equipment slots: Head, Chest, Legs, Feet, Hands, Main Hand, Off Hand, 2 Accessories.
  Two-handed weapons occupy both hand slots.
- Bag inventory with limited slots.
- Item rarity tiers: Common, Uncommon, Rare, Epic. Higher rarity means better stats,
  stronger per-level growth, and better abilities. Show rarity by name color.
- Item tooltips show stats, per-level growth, the ability taught, and AP progress toward
  mastering it. When hovering an unequipped item, compare it to what's currently equipped
  (green/red stat differences).
- Character sheet: level, XP, all stats (with gear bonus vs permanent growth shown
  separately), and a list of mastered and in-progress abilities.
- Action bar: drag mastered abilities onto it; keybinds can be changed.

### Loot and gold
- Enemies drop gold and items from data-driven loot tables.
- Personal loot: each player in the combat zone gets their own drops, so there's no loot
  competition. Kills inside a shared combat zone give XP, AP, and quest credit to every
  participating player.
- Town vendor: sell items for gold, buy a few basic items and consumables
  (health and mana potions on a shared potion cooldown).

### Content
- Add a small town hub connected to the existing zone. It includes a vendor, quest
  givers, and the respawn graveyard.
- 10–12 items covering emerging archetypes: tank, melee damage, ranged physical, caster,
  and healer. Each teaches a distinct ability.
- 3 enemy types with distinct AI, plus enemy levels:
  - melee brute: slow steps, hits hard
  - ranged caster: keeps distance, retreats when approached
  - fast skirmisher: short step cooldown, flanks
- One elite enemy that roams the zone and needs teamwork to beat.

### Quest system foundation
- Data-driven quests defined as Resources, with types: kill X, collect Y (drops), talk
  to NPC, and reach a location.
- Quests support prerequisites, so we can build chains later for the main story.
- NPC quest givers show a marker for available quests and turn-ins. Include a simple
  dialogue box.
- Quest log UI and a small on-screen tracker. Shared progress: party members on the same
  quest progress together.
- Rewards: XP, gold, and optionally a choice of one item from a list.
- Create 4–5 sample quests, including a short 3-quest chain.

### Saving
- Each player's character (level, stats, permanent growth, inventory, equipment,
  mastered abilities, AP, quest progress, gold) saves on their own computer, so they can
  bring the same hero into anyone's session.
- The host saves world state (completed one-time events, etc.).
- Autosave at regular intervals and on quit.

### Out of scope for Milestone 2
Dungeons, bosses with special mechanics, main story content, difficulty scaling,
crafting, final art, and sound. Don't make choices that block these.

When finished: a playtest checklist covering every feature, written for a non-programmer.

### Milestone 2 build order (approved 2026-10-11)
A. Items & inventory: 1 item model (9 slots, two-handed, rarity, stacks) · 2 bag ·
   3 inventory UI + tooltips/compare · 4 character sheet.
B. Saving & sessions: 5 character saves + character select + autosave · 6 join with your
   hero, 4 players, join in progress (spawn in town), private per-player state, host
   world save.
C. World: 7 multiple zones with exit tiles + per-zone replication · 8 town hub, NPCs,
   talking, dialogue box.
D. Economy: 9 gold, loot tables, personal loot, kill credit · 10 vendor + potions.
E. Combat content: 11 new ability mechanics · 12 new items · 13 enemy levels + 3 enemy
   types · 14 roaming elite.
F. Quests: 15 quest system · 16 quest UI (markers, dialogue, log, tracker) · 17 sample
   quests + host world events · 18 polish, docs, playtest checklist.

### Milestone 2 decisions (approved 2026-10-11)
1. **Zones:** town and Greenfields are separate zones joined by exit tiles; each client
   only receives its own zone. Town ≈ 18×18 west of Greenfields with vendor, two quest
   givers and the graveyard. Graveyards: town + far side of Greenfields (the Greenfields
   spawn graveyard is removed). Release goes to the nearest one in your zone.
2. **Party:** all connected players are one party (max 4). Kill participants = heroes on
   the enemy's threat table at its death.
3. **Rarity** is fixed per item design (no random rolls). Colors: Common white,
   Uncommon green, Rare blue, Epic purple.
4. **Bag:** 20 slots; potions and quest items stack to 20. Equipping a two-handed weapon
   moves the off-hand item to the bag (refused if full). Gear changes only out of combat.
5. **Loot:** auto-loot personal drops into the bag with a message; if the bag is full,
   leftovers wait in a loot window on the corpse for 60 s. Quest items drop only for
   players on the quest and take bag slots.
6. **AP from kills:** each enemy gives a small AP reward per kill (e.g. Wolf 2) to the
   abilities taught by the participant's equipped items, in addition to level-up AP.
7. **XP vs level:** enemies 3+ levels below give reduced XP (down to 20%); higher-level
   enemies up to +50%.
8. **Vendor:** sells at 25% of price. Stock: Minor Health Potion (40% max HP), Minor Mana
   Potion (40% max Mana), 2–3 Common items. Potions: usable in combat, off the GCD,
   30 s cooldown shared by all potions.
9. **New items (8 new, 12 total):** Iron Helm (Head, C) → Taunt · Greataxe (2H, U) →
   Cleave (front tile + both side tiles) · Hunting Bow (2H, C) → Aimed Shot (7-tile
   physical projectile) · Ranger's Gloves (Hands, R) → Pinning Shot (projectile, target's
   speed halved 4 s) · Frostweave Robe (Chest, U) → Frost Nova (damage + root all
   adjacent enemies 2 s) · Acolyte's Leggings (Legs, U) → Renew (heal over time) · Swift
   Boots (Feet, C) → Dash (move 2 tiles forward instantly, 15 s) · Grizzlehide Mantle
   (Chest, Epic, elite drop) → Rallying Roar (allies within 3 tiles +20% attack for 120 s).
10. **Flanking:** FRONT attacks from the target's side deal +25% damage; from directly
    behind +50% and they can't miss. Applies to heroes and enemies.
11. **Enemies (levels 2–4, own areas):** Bandit Brute (2.0 s/tile, slow heavy hits) ·
    Goblin Shaman (casts line bolts, steps back when a hero is within 2 tiles) ·
    Skirmisher (0.6 s/tile, moves to your side or back before attacking).
    **Elite "Old Grizzlehide":** level 5 bear on a patrol loop, ~6× Wolf HP, Cleave +
    Charge, respawn 5 min, drops the Epic mantle and Rares.
12. **Saving:** plain-data JSON per character in the user folder; several characters per
    computer. The host validates a joining hero's data (known ids, sane values) but
    otherwise trusts it.
13. **Zones (as built in step 7):** `World` holds one `WorldSim` per zone, stepped on a
    shared clock with shared actor ids. Exit tiles (`ZoneDef.exits`) move a hero when
    they arrive on one; exits don't work while you're in combat. Each client only gets
    its own zone's snapshot and events and rebuilds its map when it changes zone.
    Town "Millbrook" (18×18) is the start/join zone; its east edge leads to
    Greenfields' west edge.

## Decisions log
| Date | Decision | Notes |
|------|----------|-------|
| 2026-10-11 | Zone exits are blocked while in combat | Implementation choice in M2 step 7 (prevents escaping fights by zoning); easy to change in `World._handle_exits`. |
| 2026-10-11 | Milestone 2 plan and decisions approved | Flanking +25% side / +50% behind (user change); Rallying Roar lasts 120 s (user change); all other proposed defaults accepted. |
| 2026-10-11 | Milestone 1 playtested; design doc brought up to date; Milestone 2 brief recorded | Added "Gameplay as built" reference. M2 plan pending approval. |
| 2026-10-11 | Combat revision complete; no retuning needed | Balance targets (rule 16) still met with facing, directional abilities, faster wolves and reaction delay. |
| 2026-10-11 | Wolf: 0.8 s/tile in combat, 0.3 s reaction delay | Rule 12. Part 3 of the combat revision. |
| 2026-10-11 | Directional abilities: FRONT (Strike, Bite), LINE projectile (Fireball, 10 tiles/s); Heal/Resurrect stay targeted | Rule 8. Part 2 of the combat revision. |
| 2026-10-11 | Combat step 1.5 s/tile (floor 0.5 s), walking 0.2 s/tile; facing + tap-to-turn | Rules 4 and 13. Part 1 of the post-M1 combat revision (facing, directional abilities, faster wolves, reaction delay). |
| 2026-10-11 | Milestone 1 build order complete | Multiplayer testing doc: docs/local-multiplayer-testing.md. |
| 2026-10-11 | Block is off the GCD | Chosen over a stronger multiplier or flat reduction. |
| 2026-10-11 | Step 11 balance targets approved and tuned | See rule 16. Block's effect is weaker than "half" under the approved formula; flagged to the user. |
| 2026-10-11 | Step 10 HUD approved; bar layout + keybinds saved to user://settings.cfg | See rule 15. |
| 2026-10-11 | Step 9 networking approved, with client-side movement prediction | See rule 14. |
| 2026-10-11 | Step 8 view/controls/zone approved | See rule 13. Enemy type: Wolf. |
| 2026-10-11 | Step 7 world/AI rules approved | See rules 10 and 12. No hero auto-attack. |
| 2026-10-11 | Step 6 progression numbers approved; level-up refills HP/Mana | See rule 9. |
| 2026-10-11 | Step 5 combat numbers approved | See rule 7. |
| 2026-10-11 | No step cooldown out of combat | Only the walk animation time limits steps out of combat. In combat: arrival + step cooldown. |
| 2026-10-11 | Holy Charm teaches two abilities: Heal and Resurrect | Items can teach several abilities (`ItemDef.teaches` is a list). |
| 2026-10-11 | Shield ability is Block | Temporary buff that doubles Physical Defense. Duration/cooldown tuned in content. |
| 2026-10-11 | Staff is one-handed | Sword or Staff can be paired with the Shield. |
| 2026-10-11 | Architecture + 11 rule defaults approved | See sections above. Godot pinned to 4.7.2-stable, GUT 9.7.1. |
| 2026-10-11 | Repo is Final-Wars | Design doc moved here from the Middleware repo. |
| 2026-10-11 | Brief saved as CLAUDE.md | Restored a garbled line in "Movement and combat" to "The rest of the world keeps running normally." |
