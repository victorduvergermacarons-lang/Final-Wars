# CLAUDE.md — Living Design Doc

2D open-world co-op RPG in Godot 4 (latest stable 4.x, GDScript).

This file is the living design doc. Keep it current as decisions are made.

**Status:** Milestone 1 complete and playtested, including the post-M1 combat revision
(facing, directional abilities, faster enemies, reaction delay). Milestone 2 built and
playtested; post-playtest fixes done. **Milestone 3 (abilities, mastery, targeting) built**
(all 16 steps); awaiting a playtest with `docs/playtest-checklist-m3.md`. For the numbers
the game actually uses today, see **Gameplay as built** below (Milestone 3 section first:
the M1/M2 hero abilities and weapons are retired); the brief sections keep the original
wording.

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

## Gameplay as built: Milestone 3 (ability trees)

Abilities come from `design/Ability_Tree.xlsx` (names, tiers, cooldowns, Mastery
numbers, prerequisites, items) plus behavior files in `content/tree/behaviors/`
(targeting, range, effects, mana). Decisions 13–27 below describe the rules; tuned
values live in `content/rules/default_rules.tres` and `content/tree/tuning.tres`.

- **Start:** Rusty Shortsword in hand (Slash), Ember Fist Scroll in the learning slot
  (Fire Punch), Mender's Scroll in the bag (Healing Touch). Adventurer base stats as below.
- **Keys:** hold an aimed ability's key to aim, release to cast; T ability trees;
  ` debug console (debug builds).
- **Amounts:** (tier default + Scales With stats) × effect power × (1 + 0.1% per tree
  Mastery). Tier defaults: damage 14/24/38/55/78, healing 24/36/54/76/104. Durations
  +0.05% per Mastery point. Haste −25%.
- **AP to master by tier:** 20/30/40/50/50. AP: 10 per level-up + the enemy's kill AP, to
  the learning item only. Mastery on learn 5 (T1) / 10 (T2); per use 0.2–0.6; caps 50 / 70.
- **Tiers open at** 0 / 150 / 350 / 600 / 900 permanent Mastery.
- **Learning scroll growth per level** (50% applied): Fire MagAtk 3, Mana 6, Fire Mastery 2;
  Water MagAtk 2, MagDef 2, Mana 8, Water Mastery 2; Earth MagAtk 1, PhysDef 2, HP 8, Earth
  Mastery 2; Air MagAtk 2, Evasion 1, Mana 6, Air Mastery 2. Weapons: sword PhysAtk 10 /
  Acc 4 (growth PhysAtk 3, HP 8, Sword Mastery 2), bow PhysAtk 13 / Acc 8, hammer PhysAtk
  15 / PhysDef 5 / HP 15; +50% per tier above 1.

| ID | Ability | Item | Targeting | Effect (power × tier default) | Mana | CD |
|----|---------|------|-----------|-------------------------------|------|----|
| F01 | Fire Punch | Ember Fist Scroll | Targeted, adjacent | 1.0 magical | 4 | 2 |
| F02 | Fire Kick | Cinder Kick Scroll | Targeted, adjacent | 0.8 + burn 0.6 over 3 s | 8 | 4 |
| F03 | Fire Dart | Spark Scroll | Skillshot, any angle, 4, 16 t/s | 1.0 | 6 | 2 |
| F04 | Sun Warrior's Breath | Sun Warrior's Breath Scroll | Self | next 3 Fire casts +30% (20 s), +10% max Mana over 10 s, off GCD | 10 | 20 |
| F05 | Flame Dash | Scroll of Burning Feet | Ground 8-way, 3 | dash 3, trail burns 3 s (0.4/s); charges 1 +1/300 | 10 | 8 |
| F06 | Fire Whip | Lash of Embers Scroll | Skillshot 8-way line 3, pierce | 1.1 | 10 | 6 |
| F07 | Fireball | Scroll of the Fireball | Ground 5, 3×3, 0.4 s telegraph | 1.2 | 15 | 8 |
| F08 | Burning Ground | Scorched Earth Scroll | Ground 4, 3×3 zone 6 s | 0.35 per s | 15 | 14 |
| F09 | Blazing Combo | Blazing Fist Scroll | Targeted, adjacent | 3 × 0.5, knockback 1 | 12 | 10 |
| W01 | Healing Touch | Mender's Scroll | Targeted ally, 2 | heal 1.0 | 8 | 3 |
| W02 | Water Whip | River Lash Scroll | Targeted, 3 | 1.0 | 6 | 2 |
| W03 | Flow State | Scroll of the Current | Targeted ally, 3 | Haste 30 s | 10 | 20 |
| W04 | Frost Shard | Frost Shard Scroll | Skillshot, 4, 12 t/s | 0.9 + slow ×1.5 2 s | 8 | 4 |
| W05 | Soothing Mist | Mist Scroll | Targeted ally, 4 | heal 1.5 over 12 s | 12 | 8 |
| W06 | Water Pulse | Wave Scroll | Skillshot 8-way line 3, pierce | 0.9 + push 1 along the wave | 12 | 8 |
| W07 | Leeching Tide | Leech Tide Scroll | Targeted, 3 | 1.0, heals you 50% | 12 | 10 |
| W08 | Tidal Blessing | Tidal Scroll | Targeted ally, 3 | +20 PhysDef/MagDef 45 s | 12 | 25 |
| W09 | Ice Spikes | Glacier Scroll | Ground 4, 3×3, 0.4 s telegraph | 1.0 + slow ×1.5 3 s | 15 | 10 |
| A01 | Air Palm | Open Palm Scroll | Targeted, adjacent | 0.6 + knockback 1 | 6 | 4 |
| A02 | Gust | Breeze Scroll | Targeted, 3 | 0.5 + interrupt, off GCD | 8 | 10 |
| A03 | Air Step | Featherstep Scroll | Self | 5 free steps (10 s), off GCD | 8 | 10 |
| A05 | Air Blast | Gale Scroll | Targeted, 3 | 0.6 + knockback 3, +25 on impact | 12 | 10 |
| E01 | Rock Throw | Pebble Scroll | Skillshot lob 0.3 s, 4 | 1.0 physical | 6 | 3 |
| E03 | Raise Pillar | Pillar Scroll | Ground 3 | +1 level 15 s (+1 from 500 Earth) | 8 | 6 |
| E04 | Seismic Stomp | Stomp Scroll | Self, 3×3 | taunt | 8 | 10 |
| E05 | Earth Wall | Bulwark Scroll | Ground 4 | 3-tile wall +2 (climbable with Jump 2), 12 s (+1 tile / 300 Earth) | 15 | 15 |
| S01 | Slash | Rusty Shortsword | Targeted, adjacent | 1.0 physical | — | 2 |
| S04 | Lunge | Traveler's Longsword | Targeted, 3 | dash 2, then 1.1 if adjacent | — | 8 |
| B01 | Quick Shot | Hunter's Shortbow | Targeted, 5 | 0.9 | — | 2 |
| B02 | Aimed Shot | Yew Longbow | Skillshot, 7, 1 s draw, 14 t/s | 1.8 | — | 6 |
| H01 | Smash | Iron Mallet | Targeted, adjacent, 0.3 s wind-up | 1.6 | — | 4 |
| H02 | Ground Slam | Quarry Maul | Self, 3×3 | 1.0 | — | 8 |

Enemy attacks (Milestone 3): Bite and Quick Slash 0.3 s wind-up (Targeted, adjacent, no
diagonals; Accuracy vs Evasion still rolls); Crushing Blow (Brute) 0.6 s wound-up swipe at
the tile in front and the two beside it, telegraphed red during the wind-up; Shadow Bolt
any-angle skillshot; Grizzlehide Cleave the same swipe with a 0.4 s wind-up, Charge 1 s
telegraphed tile then rush + maul. Goblin Shaman Magic Attack 12; Old Grizzlehide HP 2000. Weight (knockbacks/pulls ±1
tile): Shaman and Skirmisher light, Brute and Grizzlehide heavy, everyone else medium. Hilda: potions, Iron Helm,
Swift Boots and the 20 implemented tier-1 scrolls (25 g) and weapons (30 g).

## Gameplay as built (end of Milestone 1, after playtest)

> Milestone 3 retired the hero abilities and weapons below (Strike … Rallying Roar, Sword,
> Staff, Shield, Holy Charm, Hunting Bow, Greataxe); the armor stays as stat-only gear.
> Enemy rows still apply except where the Milestone 3 section says otherwise.

Quick reference of the values in the shipped content and `content/rules/default_rules.tres`.
Tune them there; update this table when they change.

### Changes from the original brief
- **Combat steps are slow, not short:** 1.5 s per tile at 0 Speed (floor 0.5 s). Out of
  combat there is no step cooldown; walking takes 0.2 s per tile.
- **Facing:** every actor faces a direction. The hero faces the mouse; direction keys always walk (since 2026-10-16).
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
| Leave combat | as soon as no enemy lists you (next tick; `combat_exit_seconds` = 0) |
| Tap-to-turn threshold | removed 2026-10-16 (keys always walk; the hero faces the mouse) |

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

### Milestone 2 items (step 12)
| Item | Slot | Rarity | Key stats | Teaches | AP |
|------|------|--------|-----------|---------|----|
| Iron Helm | Head | Common | PhysDef +12, HP +25 | Taunt (targeted, range 3, 8 s) | 20 |
| Hunting Bow | Two-Hand | Common | PhysAtk +14, Acc +8 | Aimed Shot (line 7, 14 tiles/s, 12 + 1.0×PhysAtk, 1.5 s) | 20 |
| Swift Boots | Feet | Common | Speed +15, Eva +3 | Dash (2 tiles, 15 s, off GCD) | 20 |
| Greataxe | Two-Hand | Uncommon | PhysAtk +22, Crit +3 | Cleave (arc, 6 + 0.9×PhysAtk, no cooldown) | 30 |
| Frostweave Robe | Chest | Uncommon | MagAtk +10, Mana +25, MagDef +8 | Frost Nova (around 1, 10 + 0.6×MagAtk, root 2 s, 20 mana, 15 s) | 30 |
| Acolyte's Leggings | Legs | Uncommon | MagAtk +6, HP +20, Mana +15 | Renew (30 + 1.0×MagAtk over 9 s, 10 mana, 6 s) | 30 |
| Ranger's Gloves | Hands | Rare | PhysAtk +6, Eva +5, Speed +10 | Pinning Shot (line 6, slow ×2 for 4 s, 10 mana, 10 s) | 40 |
| Grizzlehide Mantle | Chest | Epic | HP +60, PhysAtk +10, PhysDef +20, MagDef +10 | Rallying Roar (allies within 3: +20% attack 120 s) | 50 |

Sources: Hilda sells the Commons and potions; Wolves drop the Uncommons (2% each);
Ranger's Gloves and the Mantle come from the new enemies and the elite.

### Milestone 2 enemies (steps 13–14)
| Enemy | Lv | AI | Stats | Ability | Step / reaction | XP / AP | Drops | Where (Greenfields) |
|-------|----|----|-------|---------|-----------------|---------|-------|---------------------|
| Wolf | 1 | Melee | (see above) | Bite | 0.8 s / 0.3 s | 50 / 2 | 2–6 g, pelt, fang, Uncommons 2% | (8,13) (11,24) (5,20) (18,4) |
| Goblin Shaman | 2 | Kiter | HP 160, MagAtk 18, PhysDef 5, MagDef 10, Jump 2; aggro 5 | Shadow Bolt: line 5, 9 tiles/s, 10 + 1.0×MagAtk magical, 2.5 s | 0.9 s / 0.3 s | 70 / 3 | 4–10 g, Frostweave Robe 4%, Acolyte's Leggings 4% | west hill (6,8) (9,6) |
| Bandit Brute | 3 | Melee | HP 320, PhysAtk 22, PhysDef 15 | Crushing Blow: front, 24 + 2.0×PhysAtk, 3.5 s | 2.0 s / 0.4 s | 90 / 3 | 6–14 g, Greataxe 4% | south-east (20,20) (24,21) |
| Fen Skirmisher | 4 | Flanker | HP 220, PhysAtk 16, PhysDef 8, Eva 12, Jump 2 | Quick Slash: front, 8 + 1.0×PhysAtk, 1.5 s | 0.6 s / 0.3 s | 100 / 3 | 5–12 g, Ranger's Gloves 3% | plateau (26,5) (23,3) |
| **Old Grizzlehide** (elite) | 5 | Melee, patrols | HP 1400, PhysAtk 26, PhysDef 25, MagDef 15, Acc 5, Jump 2; aggro 4, leash 12 | Cleave: arc, 12 + 1.0×PhysAtk, 2.5 s · Charge: front 2–4 tiles, dashes up to 3 tiles then 15 + 1.0×PhysAtk, 12 s | 1.0 s / 0.3 s (patrol 0.8 s/tile) | 400 / 10 | 30–60 g, Grizzlehide Mantle 25%, Ranger's Gloves 30%; respawn 5 min | loop (8,17) → (12,12) → (22,12) → (20,16), crossing the north bridge |

XP by level: +10% per enemy level above you (max +50%); from 3 levels below, −20% per
level (3 below = 80%), never under 20%. Balance report (bots stand still and always face the enemy): a level-3 sword
hero who just trades blows with a Brute loses, but wins by healing itself (~95% HP lost) or with a shield, staff hero beats a Shaman at level 2 (~40%),
sword hero beats a Skirmisher at level 4 80% of the time; Grizzlehide kills a lone or
paired level-5 hero but a level-5 group of four wins (~46 s).

### Milestone 2 quests (step 17)
| Quest | Giver → hand in | Needs | Objectives | Rewards |
|-------|-----------------|-------|------------|---------|
| Word to Hilda | Old Maren → Hilda | Lv 1 | Talk to Hilda | 40 XP, 5 g, 2 Minor Health Potions |
| Goblin Fetishes | Old Maren | Lv 2 | Collect 5 Goblin Fetishes (Goblin Shamans, 60%, only while on the quest) | 180 XP, 25 g, choice: Iron Helm / Swift Boots / Hunting Bow |
| Wolves at the Gate (chain 1/3) | Captain Rowan | Lv 1 | Kill 4 Wolves | 120 XP, 20 g |
| The Bandit Camp (chain 2/3) | Captain Rowan | Lv 2, chain 1 | Find the camp (within 2 tiles of (22,20) in Greenfields, under the "Bandit Camp" banner), break 2 Bandit Brutes | 220 XP, 30 g |
| The Beast of Greenfields (chain 3/3) | Captain Rowan | Lv 3, chain 2 | Kill Old Grizzlehide | 500 XP, 60 g, choice: Greataxe / Frostweave Robe / Acolyte's Leggings; world event |

World event: the first time anyone hands in The Beast of Greenfields, the host sets the
`grizzlehide_slain` world flag (saved in `user://world.json`), everyone in town sees
"Bells ring in Millbrook…", and Captain Rowan greets everyone differently from then on.

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
sim/             world (all zones), world_sim (one zone) + grid/ stats/ combat/ progression/ entities/ ai/ quests/
net/             intents, snapshot, server_session, client_session
data/defs/       Resource scripts (*_def.gd, stat_block.gd, combat_rules.gd)
content/         items/ abilities/ buffs/ enemies/ loot/ npcs/ quests/ heroes/ zones/ rules/ (.tres)
view/            world view, iso tile renderer, actor views, camera
ui/              main menu, stores (characters, world, settings), HUD (action bar, unit frames,
                 inventory, character sheet, spellbook, ability trees, dialogue, vendor, loot,
                 quest log, tracker)
input/           player input → intents
scenes/          main.tscn and other top-level scenes
tools/           ability spreadsheet importer (xlsx reader, converter, CLI), behavior generator
design/          Ability_Tree.xlsx (source of truth for abilities)
tools/once/      one-off content conversions (kept for the record)
tests/           unit/ integration/ balance/ (GUT, test_*.gd; balance builds in balance_scenarios.gd),
                 net/ (multi-process check), visual/ (screenshot scene), fixtures/ (legacy M1 hero)
docs/            local multiplayer testing, playtest checklists (M2, M3), ability import
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
   ends as soon as no enemy lists you (changed from 5 s after the M2 playtest).
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
    - Combat ends as soon as no fighting enemy lists the hero (was 5 s until the M2
      playtest). An enemy counts as in combat from the moment it aggros, so its first
      steps already use its combat step time (no dash on aggro).
    - Heroes have no auto-attack; they only use action-bar abilities.
13. **View & controls** (approved 2026-10-11):
    - Isometric tiles 64×32 px, 16 px per height level; camera follows the hero,
      mouse-wheel zoom.
    - W/↑ = grid up (screen up-right), D/→ = right (down-right), S/↓ = down
      (down-left), A/← = left (up-left), like FFTA.
    - Every actor faces one of the four directions (arrow on the ground). **Since
      2026-10-16 the hero faces the mouse** (the side of the hero the pointer is on,
      4-way), and direction keys always walk, even a short tap (the Pokémon-style
      turn-only tap is gone). Stepping still turns you toward the step until the mouse
      turns you back. Turning is free and instant, in combat too.
      The newest held direction key wins; pressing a new direction turns at once even
      while another is held or the step is on cooldown; in combat no step is queued
      ahead, and a turn cancels any queued step (post-M2 playtest fix).
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
      **Pages (post-M2 playtest):** 6 bars of 10 slots, WoW-style. Shift+1–6 (or the
      arrows) shows that bar; the slot keys fire the shown bar. A panel in the screen's
      bottom-right corner shows the bar number. New abilities fill bar 1 first, then
      bar 2… All pages and the shown page are saved with the layout.
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
    shared clock with shared actor ids. **Map edges** (`ZoneDef.edges`, post-M2
    playtest): stepping off the map from any walkable tile on a linked side puts you on
    the matching edge tile of the next zone (row + `offset`; nudged up to 2 tiles along
    the edge if blocked), still facing the way you walked. Town east edge ↔ Greenfields
    west edge, offset 13 (town rows 1–16 = Greenfields rows 14–29). Single exit tiles
    (`ZoneDef.exits`) still exist for doors later. Neither works while you're in combat. Each client only gets
    its own zone's snapshot and events and rebuilds its map when it changes zone.
    Town "Millbrook" (18×18) is the start/join zone; its east edge leads to
    Greenfields' west edge.
14. **Ability mechanics (as built in step 11):** shapes ARC (front tile + both sides)
    and AROUND (all tiles within range; ally versions include the caster); buffs can
    slow (multiply the step cooldown) or root (no stepping, abilities still allowed);
    HEAL_OVER_TIME heals its total in 1 s ticks over the buff's duration; DASH moves
    the caster forward, stopping at walls, actors and climbs over its Jump; cooldown
    groups share one cooldown (potions); a debuff on an enemy pulls it onto the
    caster. Flanking applies to melee (FRONT/ARC) only; projectiles never flank.
15. **Enemy AI types (as built in step 13, `EnemyDef.behavior`):** MELEE chases and
    attacks when in reach (Wolf, Brute). KITER steps away when a hero is within
    `keep_away_distance` (2), otherwise moves to share a row or column with its
    target within range, turns and shoots. FLANKER paths to a free tile behind or
    beside its target and strikes from there; in front of its target it keeps
    circling and strikes head-on only if it hasn't attacked for 2 s (or can't get around).
    All types act on positions seen `reaction_seconds` ago and stay inside their leash.
16. **Elite and patrols (as built in step 14):** `EnemySpawn.patrol` lists waypoints an
    idle enemy walks in a loop at `patrol_step_seconds` per tile. Any enemy's leash
    anchor is where it was pulled, so a patroller walks back there after evading and
    resumes its route. Elites (`EnemyDef.elite`) are drawn 1.6× bigger with a gold
    outline and "Elite" before the name (and on the unit frame).
17. **Quest system (as built in step 15):** `QuestDef` resources in `content/quests/`
    (giver and turn-in NPC, prerequisites, minimum level, objectives, XP/gold/item
    rewards, optional choice of one item, optional world flag) with `QuestObjective`s
    of kind KILL, COLLECT, TALK or REACH. Accept and hand in by talking to the NPC
    (within 2 tiles). COLLECT counts what's in your bag and takes it at turn-in;
    quest drops (`LootEntry.quest_id`) only roll while you still need them.
    **Shared progress:** kill, talk and reach credit goes to every hero on the
    quest who is on the enemy's threat table or within 15 tiles of the event, in
    the same zone. Turn-in is refused (nothing lost) if the rewards don't fit in the
    bag. Abandoning forgets progress. Progress is saved with the character; the host
    saves world flags. Quests are not repeatable.
18. **Quest UI (as built in step 16):** NPCs show a yellow "!" when they have a quest
    you can accept and "?" when you can hand one in to them. Talking opens the dialogue
    with one option per quest: "! Title" (offer page with objectives, rewards, Accept
    / Not now), "… Title (in progress)" and "? Title (complete)" (rewards; with a
    choice, one button per item, hover for its tooltip). Quest log on L (active
    quests, details, Abandon). The tracker on the right edge lists every active
    quest's objectives, turning gold with "Return to …" when done. Quest messages go
    to the message log.
19. **World events (as built in step 17):** a quest can set a world flag on hand-in
    (`QuestDef.sets_world_flag`, once per world, with an announcement). Flags are sent
    to clients in every snapshot; NPCs can swap their greeting per flag
    (`NpcDef.flag_greetings`). Quest items (`ItemDef.quest_item`) show "Quest item" and
    can't be sold.
20. **Polish (step 18):** a "Leave game" button saves and returns to the menu;
    enemy projectiles are purple (heroes' orange); a quest's prerequisites are checked
    before its level, so a locked chain quest says "finish an earlier quest first".
21. **Readability (post-M2 playtest):** an "[E] Talk" prompt sits over the townsperson
    E would talk to; NPC "!"/"?" markers are bigger. Named places (`ZoneDef.landmarks`)
    get a red banner and a gold name on the map, and the tiles of an unfinished
    "reach" objective in your zone glow yellow. Names, health bars and markers are
    drawn last so terrain never covers them; floating combat texts that pop up
    together on one character stack instead of overlapping, and every name, marker and
    floating text is nudged up so none overlap. The quest tracker has a dark backdrop,
    sits behind every window and hides while one covers it. The message log wraps left
    of the action bar. The default font lacks ◀ ▶ ⚔ ✓, so the UI uses < > [combat]
    and "(done)" instead. Checked on real renders (`tests/visual/shots.tscn`).

## Milestone 3: ability, mastery and targeting systems (brief, 2026-10-12)

**Source of truth for abilities: `design/Ability_Tree.xlsx`** (all tabs, especially
Abilities and Rules & Legend). The designer edits and re-uploads it often. (The first
upload landed at the repo root as `Ability_Tree_1.xlsx`.)

### 1. Data pipeline
- A script converts `design/Ability_Tree.xlsx` into Godot ability Resources (or one data
  file the game loads). Document how to re-run it.
- Import every column. Effect and Targeting Details text is for humans; behavior is
  implemented in code/data per ability, but numbers (cooldown, tier, mastery values,
  prerequisites, item names) come from the sheet.
- Validate on import with clear errors: unknown prerequisite names, duplicate IDs,
  missing items, tiers outside 1–5.

### 2. Learning and mastery rules
- Trees: Fire, Earth, Water, Air (taught by scrolls), Sword, Bow, Hammer (taught by
  weapons). Each tree has its own Mastery stat (0 and up).
- Every ability is taught by exactly one named item (Taught By column); those items exist
  in the game.
- Single learning slot: the hero designates one equipped item as the learning item. Only
  it earns AP toward its ability. Other equipped items still give stats and their already
  mastered abilities, but don't teach.
- An ability can be learned only when the hero meets its Mastery Required (tier
  thresholds 0/150/350/600/900, Tiers tab) and has mastered every prerequisite.
  "Air Mastery 350" requires that much Mastery in the other tree; "any element Mastery
  350" means any one of Fire/Earth/Water/Air.
- Mastery gain per ability, from the sheet:
  - Mastery on Learn: one-time bonus when the ability is mastered (full AP).
  - Mastery per Use: each use against an enemy at or near the hero's level (configurable;
    default within 3 levels below or any level above). Heals and buffs count when used
    during combat.
  - Per-use Mastery stops once that ability has contributed its Mastery Cap in total.
- Item per-level growth may include Mastery. Gear-bonus Mastery boosts ability power but
  does NOT count toward unlocking tiers; only permanent Mastery does.
- Ability power scales with the tree's Mastery plus the stats in Scales With; the formulas
  live in one tunable place.

### 3. Targeting (Rules & Legend > Targeting)
- **Targeted:** pick a unit; locks on, can't miss. Range and line of sight checked at
  cast. Abilities with a cast or channel fail if the target leaves range or breaks LOS.
- **Skillshot:** aim at an enemy or direction; direction locks on release. Per ability:
  any-angle (rasterize the line from caster through the aim point onto tiles) or 8-way.
  Projectiles travel at a per-ability speed and hit the first unit unless they pierce.
  Height and walls block lines.
- **Ground:** pick a tile; the affected area is telegraphed for the listed time, then
  resolves on whoever stands there at that moment.
- **Self:** centered on or affecting the caster.
- While aiming, highlight the exact tiles that will be affected.
- Knockbacks and pulls move units along tile lines snapped to 8 directions, stopping at
  walls, units and unclimbable height; hitting a wall can deal bonus damage where noted.
- Dodge rule: debug warning when a skillshot's travel time or a telegraph is shorter than
  the step cooldown + 0.3 s.
- Networking: the host resolves all hits, with a ~100 ms grace window (a skillshot hits if
  the target occupied the tile at any moment in the last 100 ms).
- Enemies use the same targeting rules as players.

### 4. Effect building blocks
Reusable, data-driven effects, so most abilities are combinations: damage, heal,
damage/heal over time, shields, buffs/debuffs on any stat, taunt,
stun/root/slow/silence/sleep, knockback/pull, dash/leap/blink, terrain raise/lower and
walls, persistent ground zones, counters/reflects, resurrection, cast times, channels,
wind-ups, and charges (e.g. Flame Dash charges scaling with Fire Mastery).

### 5. First abilities (~30)
All Tier 1 and Tier 2 abilities of Fire and Water, plus Air Palm, Gust, Air Step, Air
Blast, Rock Throw, Raise Pillar, Earth Wall, Seismic Stomp, Slash, Lunge, Quick Shot,
Aimed Shot, Smash, Ground Slam. Unimplemented abilities are marked in the data and can't
be equipped yet.

### 6. UI
- Ability tree screen per tree: tiers, prerequisite lines, locked/learnable/learning/
  mastered states, current Mastery vs thresholds, each ability's mastery progress to its cap.
- Learning slot indicator on the character sheet and item tooltips.
- Abilities can be dragged from the tree to the action bar.

### 7. Debug tools
Console commands: set level, set a tree's Mastery, grant AP, master an ability, spawn
enemies at a chosen level.

When finished: a playtest checklist written for a non-programmer.

### Milestone 3 build order (approved 2026-10-12)
A. Data: 1 spreadsheet importer + validation + docs · 2 Mastery stats (permanent vs gear).
B. Learning: 3 learning slot, unlock checks, Mastery on learn / per use / caps ·
   4 power formula in one place.
C. Engine: 5 grid geometry (8-way/any-angle lines, square areas, push paths) · 6 four
   targeting types, aim intents, 100 ms grace, dodge warning · 7 effects part 1 (damage,
   heal, over-time, shields, stat buffs, taunt, CC, casts/channels/wind-ups, interrupts,
   charges) · 8 effects part 2 (knockback/pull, dash/leap/blink, terrain + walls,
   ground zones, counters/reflects, resurrection).
D. Content: 9 the ~32 first abilities + items for all 145 · 10 convert old content and
   enemies · 11 balance pass.
E. UI: 12 aiming (hold key, mouse aim, tile highlights, telegraphs) · 13 ability tree
   screen + drag to bar · 14 learning slot indicator.
F. 15 debug console · 16 docs + playtest checklist.

### Milestone 3 decisions (approved 2026-10-12, "defaults OK")
1. **Numbers not in the sheet** (damage/heal amounts, mana costs, some ranges and
   durations): damage/heal and mana default by tier and role from one tuning file,
   overridable per ability; numbers written in the Effect text (range 4, 3×3, 2 s,
   knockback 3…) go into each ability's behavior data. The importer also reads optional
   Base / Mana Cost / Range / Duration columns if they are ever added to the sheet.
2. **Diagonals:** movement stays 4-directional. **Ability ranges count a diagonal as 2
   tiles** (changed 2026-10-15; was square distance): "adjacent" / range 1 means the four
   straight neighbours, so no melee hits diagonally, and "within 4" is a diamond
   (`TileGeometry.range_distance`). Areas stay square (3×3, "the 8 tiles around you"),
   and aiming and knockbacks stay 8-way. Skillshot lines are still N tiles long in any
   direction.
3. **Old content:** the M1/M2 abilities (Strike, Fireball, Block, Heal, Resurrect,
   Taunt, Cleave, Aimed Shot, Frost Nova, Renew, Dash, Pinning Shot, Rallying Roar) are
   retired. Armor pieces stay as stat-only gear. New heroes start with Rusty Shortsword,
   Ember Fist Scroll and Mender's Scroll.
4. **Scrolls and weapons:** weapons go in the main hand (swords one-handed, bows and
   hammers two-handed). Scrolls aren't worn: one is placed from the bag into the
   learning slot. An unmastered ability is usable only while its item is in the learning
   slot (or, for a weapon, wielded). Mastered weapon arts need a weapon of that type in
   hand; mastered bending always works.
5. **Items:** weapon stats by tier; rarity T1 Common, T2 Uncommon, T3 Rare, T4–5 Epic.
   Hilda sells T1 scrolls and weapons; T2 items drop from Greenfields enemies and quest
   rewards; T3+ wait for future zones.
6. **Hit and miss:** Targeted abilities can't miss; skillshots and ground attacks hit
   whoever is in the path or area (no Accuracy/Evasion roll; dodge by moving).
   Accuracy/Evasion remain for enemy melee. Flanking bonuses stay for melee.
7. **Enemies:** melee becomes Targeted with a short wind-up (Wolf 0.3 s) so stepping away
   still dodges; the Shaman's bolt becomes a skillshot; Grizzlehide's Charge becomes a
   telegraphed Ground ability.
8. **Haste:** −25% step cooldown, ability cooldowns and GCD while active (tunable).
9. **Healing / resurrect:** Water only; resurrection returns at Water Tier 3 (Revive).
10. **AP:** 10 per level-up plus a little per kill, to the learning item only. AP to
    master by tier: 20 / 30 / 40 / 50 / 50 (T1–T5).
11. **Casting:** moving during a cast, channel or wind-up (anything with a cast bar)
    cancels it (cooldown not spent; changed 2026-10-16, wind-ups used to hold you in place).
    Enemies stand still while their cast bar shows and never start an attack mid-step.
12. **Importer:** GDScript run by Godot, no Python needed.
13. **Ability data (as built in step 1):** `tools/import_ability_tree.gd` (with
    `tools/xlsx_reader.gd`, `tools/ability_tree_importer.gd`) writes one data file,
    `content/tree/ability_tree.json` (tiers, trees, abilities, items, rules text), loaded
    as `ContentDB.tree` (`AbilityTreeData`). Ability ids are the sheet IDs (F01…); item
    ids are slugs of the item names. Per-ability behavior will live in
    `content/tree/behaviors/` so re-importing never touches it. A test fails if the JSON
    is older than the spreadsheet. How-to: `docs/ability-import.md`.
14. **Mastery stats (as built in step 2):** 7 new stats (Fire, Earth, Water, Air, Sword,
    Bow, Hammer Mastery) after the 12 combat stats, so items and item growth can carry
    them. `Mastery.permanent` = base + growth (Mastery earned from learning and using
    abilities is added to growth, so it saves with the character); `Mastery.total` adds
    gear and buffs. The character sheet lists each tree's Mastery with the gear part.
15. **Learning (as built in step 3):** `TreeContent` builds the game's 145 tree
    abilities and items from the imported data (+ `content/tree/tuning.tres`: AP by
    tier, rarity, prices, weapon stats/growth by tier, weapons grow their tree's Mastery
    a little). `TreeRules`: unlock checks, the learning slot (`learn` / `stop_learning`
    intents, out of combat; a scroll moves from the bag into the slot, a worn weapon can
    be designated; taking that weapon off empties the slot), AP to the learning item
    only, Mastery on Learn, per-use Mastery. Choices made here:
    - A locked ability (tier Mastery or prerequisites not met) can't be used either,
      even from a worn weapon; otherwise tiers would mean nothing for weapons.
    - The Mastery Cap counts the learn bonus: per-use gains stop at cap − what the
      ability already gave; the learn bonus itself is always granted.
    - Per-use Mastery also accrues while still learning the ability.
    - A use counts once, judged from what it did: it affected an enemy at most 3 levels
      below (`CombatRules.mastery_level_window_below`) or any level above, or it
      healed/buffed while the caster was in combat.
16. **Power formula (as built in step 4):** `AbilityPower` with constants in
    `CombatRules` ("Ability power"): amount = (base + Σ coefficient × stat) × (1 +
    Mastery × 0.001); durations × (1 + Mastery × 0.0005); charges = base + floor(Mastery
    / per-charge). Mastery = total in the ability's tree (gear counts for power).
    Tree effects can use the tier default base (damage 10/18/30/45/65, heal
    14/24/38/55/80 by tier) and the sheet's Scales With stats at 1.0 each; Crit Rate
    in Scales With affects crits, not the amount.
17. **Tile geometry (as built in step 5):** `TileGeometry`: square distance, square
    areas and rings, `snap8`, 8-way lines, any-angle lines (one tile per step along the
    longer axis, continuing past the aim point), cones (row k is 2k−1 wide), line
    clipping (a tile more than the LOS tolerance above the shooter, or the map edge,
    stops it; water doesn't), and push/pull paths that stop before walls, water, units
    and climbs over the unit's Jump (drops allowed), reporting what stopped them.
18. **Targeting (as built in step 6):** `AbilityDef.targeting` (LEGACY for the old
    shapes; TARGETED / SKILLSHOT / GROUND / SELF) resolved by `CastResolver`. Cast
    intents carry an optional `aim` (tile coordinates, any angle). Skillshots: instant,
    flying (`projectile_speed`, `pierce`) or lobbed (`arc_seconds`, lands on the aimed
    tile over obstacles); `aim` ANY_ANGLE or EIGHT_WAY; `line_shape` LINE or CONE.
    Ground/self areas are squares (`area_radius`); ground can be telegraphed
    (`telegraph_seconds`). Units count as on a tile if they were there within
    `skillshot_grace_seconds` (0.1) — for skillshots only. No hit roll; crits roll.
    Telegraphs/lobs are sent to clients (`telegraphs` in the snapshot). Dodge warnings
    print at load in debug builds. Choices made here:
    - Ground abilities don't need line of sight (only range); "at that moment" means no
      grace window for telegraphs.
    - Casting turns the caster (4-way facing) toward the target or aim point.
    - Melee for flanking = Targeted enemy abilities with range 1.
    - Cones are blocked tile by tile by terrain higher than the caster, not by occlusion.
19. **Effects part 1 (as built in step 7):** new effect kinds DAMAGE_OVER_TIME, SHIELD,
    INTERRUPT (with HEAL, HEAL_OVER_TIME, BUFF, TAUNT, RESURRECT…); `BuffDef` gains stun,
    silence (blocks spells: element abilities, heals, magical attacks; weapon arts
    still work), sleep (broken by damage), haste (`cooldown_multiplier`), damage dealt /
    taken multipliers (optionally for one tree), charges (Kindle: next N casts of a
    tree) and free steps (Air Step). Durations of tree buffs scale with Mastery.
    `AbilityDef` gains `cast_seconds` (only the GCD is taken at the start; mana and
    cooldown when it goes off; moving, a stun, an interrupt or a Targeted target
    leaving range/LOS cancels it), `windup_seconds` (paid up front; the caster can't
    move; the target can step away), `channel_seconds` + `channel_tick_seconds` (paid
    up front, resolves each tick, moving/stun/interrupt ends it), and charges
    (`charges_base` + 1 per `mastery_per_charge` tree Mastery, recharging one at a
    time). Casts in progress are shown to clients (`cast` in each actor's snapshot).
    Choices made here: interrupts cancel casts, channels and (since 2026-10-15) wind-ups; damage
    doesn't push back casts; a damage bonus (Kindle) is fixed when the ability goes off
    and its charge is used then (wind-ups/channels: at the start).
20. **Effects part 2 (as built in step 8):** effects say who they apply to
    (`AbilityEffect.applies`: each unit hit, the CASTER once, or the cast's AREA once).
    New kinds: KNOCKBACK / PULL (8-way slide; stops before walls, water, units and
    climbs over the unit's Jump; optional impact damage when stopped; a pull stops
    next to the caster; waves can push along the cast direction), DASH_TO (caster
    slides toward the aim, stopping next to a unit; with `hit_range` 1 a Lunge then
    strikes only if it got there), LEAP (over anything onto a free walkable tile) and
    BLINK (instant), TERRAIN (raise/lower the area by N levels for a while, never
    below 0; units ride up with it; walls make tiles impassable, built across the
    caster's facing through the aimed tile, 3 tiles + 1 per `mastery_per_extra`,
    skipping occupied tiles) and ZONE (a ground zone that applies `zone_ability` to
    whoever stands in it every tick). `BuffDef` counters: `negate_hits` (Parry, uses a
    charge each), `reflect_fraction`, `counter_ability` (used for free on the
    attacker), `melee_only`. Being moved cancels a cast. Terrain changes and zones
    are sent to clients in every snapshot. Resurrection already existed (RESURRECT).
21. **First abilities (as built in step 9):** 32 behavior files (`content/tree/behaviors/`,
    written by `tools/make_behaviors.gd`, then tuned by hand): Fire F01–F09, Water
    W01–W09, Air Palm, Gust, Air Step, Air Blast, Rock Throw, Raise Pillar, Seismic
    Stomp, Earth Wall, Slash, Lunge, Quick Shot, Aimed Shot, Smash, Ground Slam. Every
    other tree ability is unimplemented. Amounts = tier default + Scales With stats,
    × a per-effect `power` (light 0.5–0.6, normal 1, Aimed Shot 1.8, Smash 1.6); new
    `AbilityEffect.lifesteal` (Leeching Tide 50%) and `max_extra` (Raise Pillar: 2
    levels from 500 Earth Mastery, never 3). Starting numbers I chose (step 11 tunes
    them): element spells cost 5–15 mana, weapon arts none; Kindle +30% for 3 Fire
    casts within 20 s and doesn't use its own charge; Haste (Flow State) −25%;
    chills ×1.5 step time; Tidal Blessing +20 Physical and Magic Defense; Fire Kick
    burn and Flame Dash trail 3 s; Air Blast impact 25; projectiles 12–16 tiles/s.
    Seismic Stomp is a one-off taunt (top threat + 10%), not a 4 s forced target.
    Soothing Mist uses range 4 (Targeting Details), not 3 (Effect text).
22. **Old content converted (as built in step 10):** the M1/M2 weapons and accessories
    (Sword, Staff, Shield, Holy Charm, Hunting Bow, Greataxe) are `retired`: never
    handed out, and removed from characters when they load; the old abilities stay on
    disk only as engine test fixtures (`tests/fixtures/legacy_adventurer.tres` keeps the
    M1 kit for tests). The six armor pieces teach nothing now. Content refers to tree
    items by id (`item_id`, `sells_ids`, `reward_*_ids`, `starting_*_ids`), linked by
    ContentDB at load. New heroes: Rusty Shortsword in hand, Ember Fist Scroll in the
    learning slot, Mender's Scroll in the bag. A character from before M3 loses retired
    gear and old mastered abilities/AP, keeps everything else, and gets that kit.
    Hilda sells potions, Iron Helm, Swift Boots and the 20 implemented tier-1 scrolls and
    weapons. Tier-2 scrolls drop in Greenfields (Wolf 2%, Shaman/Skirmisher 4%, Brute
    4–5%, Grizzlehide 15%); Goblin Fetishes offers Hunter's Shortbow instead of the
    Hunting Bow; The Beast of Greenfields offers the Fireball, Glacier or Bulwark scroll.
    Enemies: Bite/Quick Slash wind up 0.3 s, Crushing Blow 0.6 s (Targeted range 1;
    enemy melee still rolls Accuracy vs Evasion); Shadow Bolt is an any-angle skillshot
    aimed where the Shaman saw you, so it no longer lines up on rows; Grizzlehide's Cleave
    is a 0.4 s wound-up cone on the 3 tiles in front, and Charge marks a tile 2–4 away
    for 1 s (sent to clients as a telegraph), then rushes there and mauls whoever stands
    on it.
23. **Balance pass (step 11; enforced by `tests/balance/test_balance.gd`, numbers via
    `tests/balance/balance_report.tscn`, builds in `balance_scenarios.gd`):**
    - Tier defaults raised: damage 14/24/38/55/78, healing 24/36/54/76/104 (T1–T5).
    - A scroll in the learning slot grows the hero on level-up like worn gear (per
      element in `content/tree/tuning.tres`: Fire Magic Attack 3, Mana 6, Fire
      Mastery 2; Water, Earth and Air similar), so bending builds grow too.
    - Goblin Shaman Magic Attack 18 → 12; Old Grizzlehide HP 1400 → 2000.
    - The bot turns to the nearest enemy, closes in only when nothing reaches, and can
      dodge (step away from a wind-up aimed at it).
    - Targets (bots never dodge unless stated): starter kit vs 1 Wolf ≈ 8 s, ~50% HP
      lost; 2 Wolves usually kill a lone starter, a starter + healer pair wins; a
      dodging starter loses under half the HP; sword, bow or hammer alone beats a
      Wolf; a Wolf costs a Fire Dart caster over 60% of its mana; a level-2 caster
      beats a Shaman; a level-3 hero trading blows with a Brute loses, but healing and
      dodging the 0.6 s wind-up wins; a level-4 Lunge sword beats a Skirmisher;
      Grizzlehide kills a lone level-5 hero and mostly a pair, a group of four wins
      (~21 s).
    - The dodge warning counts wind-up time as time to react.
24. **Aiming UI (as built in step 12):** pressing a Skillshot or Ground ability's key
    starts aiming; the exact tiles it would affect are highlighted (blue; red when out
    of range or line of sight; a dart's line stops at the first enemy, Earth Wall shows
    its wall, Flame Dash its path), following the mouse, or the targeted enemy until
    the mouse moves. Releasing the key casts at that point. Clicking such an ability
    on the bar aims until a left click on the map. Esc or a right click cancels.
    Targeted abilities use the current target (ally abilities fall back to self) and
    Self abilities fire at once. Enemy telegraphs (Fireball-style areas, Grizzlehide's
    Charge) flash red, brighter as they land; ground zones are orange; units casting,
    winding up or channelling show a bar (yellow / red / blue) with the ability name.
    Slot tint for aimed abilities ignores range (you can aim elsewhere).
25. **Ability tree screen (as built in step 13):** T (or the "Trees (T)" button) opens a
    window with a tab per tree. The header shows the tree's permanent Mastery (and the
    gear bonus, power only) and the tier thresholds; each tier row says "open" or
    "needs N". Ability nodes are colored by state: blue = learning (its item is in the
    learning slot / wielded), gold = mastered, white = can learn now, grey = locked
    (the tooltip says why), dark = not in the game yet. Each node shows AP while
    learning and the Mastery it has given vs its cap. Lines join prerequisites (gold
    once mastered). Abilities you can use right now drag onto the action bar.
26. **Learning slot UI (as built in step 14):** the inventory and the character sheet show
    a Learning slot (blue) with what is being learned and its AP. Drop a scroll from the
    bag (or right-click the scroll) or drag the weapon in hand onto it to learn; right-
    click it or drag it to the bag to stop. The item being learned has a blue "L" and an
    AP bar wherever it shows (slot or worn weapon). Item tooltips say where a tree item
    stands: in your learning slot, how to learn it, locked (and why), mastered, or not
    in the game yet; a scroll's growth reads "per level while in your learning slot".
    The character sheet marks which in-progress ability is being learned. With the slot
    empty, the weapon in hand learns automatically (since 2026-10-15). The right-
    hand windows now sit side by side (stacked, they ran off a 720p screen).
27. **Debug console (as built in step 15):** ` opens it (Esc or ` closes; Up/Down recall
    earlier lines). Commands are sent as a `debug` intent and run by the host on your own
    hero, only when the host allows it: debug builds (editor runs, debug exports)
    allow it for everyone in the session, release builds refuse it. Commands: `help`,
    `level <n>` (levelling up applies growth and AP), `mastery <tree> <n>` (permanent),
    `ap <n>` (to the learning item), `master <ability>` (id or "name"), `spawn <enemy>
    [level] [n]` (next to you; ±15% HP/attack/defense and XP per level from the type's
    own; spawned enemies don't respawn), `heal` (and resets cooldowns), `gold <n>`.
    Enemies now carry their own level (shown and used for XP and Mastery-per-use).
    Typing in the console doesn't walk.

## Decisions log
| Date | Decision | Notes |
|------|----------|-------|
| 2026-10-16 | The hero faces the mouse; WASD/arrows always walk (no turn-only taps) | User request. `PlayerInput.face_toward()` sends a face intent when the pointer's side changes. Replaces the tap-to-turn rule (13). |
| 2026-10-16 | Moving cancels anything with a cast bar, wind-ups included; enemies don't move while attacking and don't start an attack mid-step | User request (a Wolf looked like it moved mid-bite: it started biting while still sliding onto its tile). Changes M3 decision 11. |
| 2026-10-16 | Stacked pillars come down one by one and nothing reappears; Earth Wall can be climbed by anyone whose Jump covers its +2 height | User reports. Terrain changes now store the height they added and take it off on expiry (they used to restore a saved snapshot, so the first to expire flattened both and the second then restored the first). Earth Wall no longer marks its tiles impassable; it still blocks shots. |
| 2026-10-15 | Bandit Brute's Crushing Blow hits the ground: the tile in front and the two beside it, telegraphed during its 0.6 s wind-up | User request (easier to dodge). New skillshot shape ARC; wound-up swipes and lobs are telegraphed. Fixed Grizzlehide's Cleave, which hit only 1 tile (a range-1 cone) instead of 3; it uses ARC now. Balance targets still met (a group of 4 still beats Grizzlehide, but one bot usually dies now). |
| 2026-10-15 | Ability ranges count diagonals as 2 tiles; melee (range 1) no longer hits diagonally, for heroes and enemies | User request; "ranges only" chosen by the user, so 3×3 areas and 8-way aiming stay. Changes M3 decision 2. |
| 2026-10-15 | Weight: light / medium / heavy. Knockbacks and pulls move light characters 1 tile further, heavy ones 1 tile less (a 1-tile push doesn't move them) | User request; ±1 tile chosen by the user. Heroes and Wolves medium, Goblin Shaman and Fen Skirmisher light, Bandit Brute and Old Grizzlehide heavy (`EnemyDef.weight`, `Weight.adjust`). The target frame shows Light/Heavy. |
| 2026-10-15 | With the learning slot empty, the weapon in hand learns automatically (earns AP) | User request. A scroll in the slot takes over. `Hero.active_learning_item()`; the Learning slot text says "(from your weapon)". |
| 2026-10-15 | Kindle renamed Sun Warrior's Breath (scroll: Sun Warrior's Breath Scroll; renamed in the spreadsheet) and also restores 10% of max Mana over 10 s | User request. New `BuffDef.mana_regen_percent`. Saves holding the old Kindling Scroll get the new one (`CharacterData.RENAMED_ITEMS`). |
| 2026-10-15 | Projectiles are drawn along their real path (any angle; the Shaman's bolt went diagonally); the shop list scrolls | User reports. |
| 2026-10-15 | Post-M3 fixes: Fire Punch 4 mana; Gust interrupts wind-ups (e.g. a Wolf's Bite); releasing at a graveyard ends combat | User requests. |
| 2026-10-12 | Milestone 3 built (step 16: docs, playtest checklist) | `docs/playtest-checklist-m3.md` for a non-programmer; the M2 checklist points to it for the changed parts. "Gameplay as built: Milestone 3" added. |
| 2026-10-12 | M3 step 15: debug console | Decision 27. My choices: debug builds allow it for every player (playtesting), release builds never; +15% per level for spawned enemies; extra heal and gold commands. |
| 2026-10-12 | M3 step 14: learning slot indicator | Decision 26. Right-click a scroll learns it; windows on the right now sit side by side. |
| 2026-10-12 | M3 step 13: ability tree screen | Decision 25. T opens it (a new reserved key); only usable abilities can be dragged. |
| 2026-10-12 | M3 step 12: aiming UI | Decision 24. My choices: hold-and-release on the key, the targeted enemy is the default aim until the mouse moves, red only for range/line-of-sight problems. |
| 2026-10-12 | M3 step 11: balance pass | Decision 23. Flagged: scrolls in the learning slot now give level-up growth (casters had no way to grow Magic Attack); Shaman and Grizzlehide retuned. |
| 2026-10-12 | M3 step 10: old content converted to the trees | Decision 22. My choices: the old weapons and accessories are retired outright (armor stays); older characters get the new kit; drop rates and Hilda's stock; Charge 1 s mark. |
| 2026-10-12 | M3 step 9: the first 32 abilities | Decision 21. Mana costs, power multipliers, buff sizes and projectile speeds are my starting numbers; step 11 balances them. |
| 2026-10-12 | M3 step 8: effect building blocks part 2 | Decision 20 (choices: walls skip occupied tiles; knocked-back units stop before obstacles instead of passing over them; terrain restores newest-first). |
| 2026-10-12 | M3 step 7: effect building blocks part 1 | Decision 19 (choices: interrupts don't stop wind-ups; no cast pushback; silence spares weapon arts). |
| 2026-10-12 | M3 step 6: targeting types, aim intents, grace window, dodge warnings | Decision 18 (choices: ground needs no LOS and has no grace; casting turns you; range-1 targeted = melee). |
| 2026-10-12 | M3 step 5: tile geometry | Decision 17. Cones widen by one tile per side per row (Breath of Fire's "4-tile cone"). |
| 2026-10-12 | M3 step 4: power formula in one place | Decision 16. Starting numbers (+0.1% power and +0.05% duration per Mastery point; tier bases) are mine, tunable in `content/rules/default_rules.tres`. |
| 2026-10-12 | M3 step 3: learning slot, unlocks, Mastery gain | Decision 15 (choices: locked abilities unusable; cap includes the learn bonus; per-use Mastery while learning; a use counts once). |
| 2026-10-12 | M3 step 2: Mastery stats | Decision 14. Earned Mastery lives in permanent growth. |
| 2026-10-12 | M3 step 1: spreadsheet importer | Decision 13. Choices: one JSON data file (diff-friendly); sheet IDs as ability ids; item ids are name slugs; Mastery Required taken from the Tiers tab (a mismatching cell is a warning). |
| 2026-10-12 | Milestone 3 plan (16 steps) and 12 decisions approved | "defaults OK". See "Milestone 3 decisions". |
| 2026-10-12 | Milestone 3 brief recorded (abilities, mastery, targeting); `design/Ability_Tree.xlsx` is the source of truth for abilities | Plan and open questions sent for approval. Supersedes the earlier "disciplines" specialization proposal. |
| 2026-10-12 | Readability: [E] Talk prompt, Bandit Camp banner + glowing quest area, tracker behind menus, texts no longer overlap | User reports (decision 21). The camp was unmarked, so "Find the bandit camp" was hard to find; its goal is now the banner tile, radius 2. |
| 2026-10-12 | Action bar pages: 6 bars, Shift+1–6, page number bottom-right | User request (WoW-style). 6 pages is my default (WoW's count); one constant, `ActionBarModel.PAGE_COUNT`. |
| 2026-10-12 | Zones connect along whole map edges: walk off the edge to enter the next map | User change; replaces the 3 exit tiles that dropped you 1–2 tiles in from the edge. |
| 2026-10-12 | Turning in combat made immediate; Skirmisher sees your facing 0.3 s late | User reports. Causes: a second held key didn't turn, and a step queued while walking turned you back when the step cooldown ended. |
| 2026-10-12 | Combat ends as soon as the last enemy fighting you dies, evades or drops you | User change (was 5 s). Fixed enemies darting 2 tiles on aggro (first steps skipped the step cooldown). |
| 2026-10-12 | Post-M2 playtest fixes: Brute hits twice as hard; Renew costs 10 mana; Skirmisher reacts 0.3 s | User changes. Also fixed Frozen (no root), Pinned (no slow) and Rallied (no attack bonus): values lost when the content was generated; a content test now checks them. |
| 2026-10-12 | Milestone 2 built (step 18: polish, docs, playtest checklist) | `docs/playtest-checklist.md` covers every feature for a non-programmer. Visuals still unchecked on a real screen. |
| 2026-10-12 | M2 step 17: 5 sample quests incl. Rowan's 3-quest chain; world event "grizzlehide_slain" | See "Milestone 2 quests". Quest texts, rewards and the Rowan greeting change are content choices, easy to edit in `content/quests/`. |
| 2026-10-12 | M2 step 16: quest UI | Decision 18. Quest log on L. |
| 2026-10-12 | M2 step 15: quest system | Decision 17. Implementation choices: shared credit within 15 tiles or via the threat table; turn-in refused when the bag can't hold the rewards; abandon allowed; no repeatable quests. |
| 2026-10-12 | M2 step 14: Old Grizzlehide roams Greenfields | Patrol + elite as built (decision 16). Brute retuned to HP 320 / Crushing Blow 12 + 1.0×PhysAtk every 3.5 s and Skirmisher to HP 220 after the balance report. |
| 2026-10-12 | M2 step 13: enemy levels, XP by level, Goblin Shaman / Bandit Brute / Fen Skirmisher | Skirmisher strikes head-on after 2 s without attacking (implementation choice so a hero can't stall it forever by turning; `EnemyBrain.FLANK_PATIENCE`). |
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
