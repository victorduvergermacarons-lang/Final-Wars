# CLAUDE.md — Living Design Doc

2D open-world co-op RPG in Godot 4 (latest stable 4.x, GDScript).

This file is the living design doc. Keep it current as decisions are made.

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
4. **Speed:** shortens the in-combat step cooldown, down to a floor. Out of combat,
   everyone walks at a fixed pace.
5. **Combat membership:** each enemy keeps a WoW-style threat table. Damage and healing
   add threat; taunt forces you to the top. A hero is in combat while any enemy lists
   them. Healing/buffing a hero in combat puts you on that enemy's table too. Combat
   ends a few seconds after no enemy lists you.
6. **Line of sight:** blocked if an intermediate tile rises above the line between the
   attacker's and target's heights (configurable tolerance). High-ground bonus is
   +X% per height level of advantage, X in `CombatRules`.
7. **Combat math:** hit chance = clamp(base + Accuracy − Evasion); mitigation =
   Def / (Def + K); crit chance = Crit Rate, crit multiplier = Crit Damage. All
   constants in `CombatRules`.
8. **Equipment slots:** Main Hand, Off Hand, Accessory, Body. M1: Sword (main hand),
   Staff (main hand, one-handed), Shield (off hand), Holy Charm (accessory). Every hero starts with
   all four available to equip.
   Abilities taught: Sword → Strike; Staff → Fireball; Shield → Block (temporary buff
   that doubles Physical Defense); Holy Charm → Heal **and** Resurrect (two abilities,
   so items may teach more than one).
9. **XP/AP:** each kill's XP is split evenly among heroes on the enemy's threat table.
   Each level-up gives a fixed AP amount to every ability taught by an equipped item.
10. **Regen & respawn:** slow HP/Mana regen out of combat, small Mana regen in combat.
    Release → nearest graveyard at 50% HP. Resurrect → 30% HP. Enemies respawn on a
    timer. All configurable.
11. **Party:** in M1 all connected players are one party. Real party system later.

## Decisions log
| Date | Decision | Notes |
|------|----------|-------|
| 2026-10-11 | Holy Charm teaches two abilities: Heal and Resurrect | Items can teach several abilities (`ItemDef.teaches` is a list). |
| 2026-10-11 | Shield ability is Block | Temporary buff that doubles Physical Defense. Duration/cooldown tuned in content. |
| 2026-10-11 | Staff is one-handed | Sword or Staff can be paired with the Shield. |
| 2026-10-11 | Architecture + 11 rule defaults approved | See sections above. Godot pinned to 4.7.2-stable, GUT 9.7.1. |
| 2026-10-11 | Repo is Final-Wars | Design doc moved here from the Middleware repo. |
| 2026-10-11 | Brief saved as CLAUDE.md | Restored a garbled line in "Movement and combat" to "The rest of the world keeps running normally." |
