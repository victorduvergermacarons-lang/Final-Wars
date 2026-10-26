# CLAUDE.md — Living Design Doc

2D open-world co-op RPG in Godot 4 (latest stable 4.x, GDScript).

This file is the living design doc. Keep it current as decisions are made.

**Status:** Milestone 1 complete and playtested, including the post-M1 combat revision
(facing, directional abilities, faster enemies, reaction delay). Milestone 2 built and
playtested; post-playtest fixes done. **Milestone 3 (abilities, mastery, targeting) built**
(all 16 steps); awaiting a playtest with `docs/playtest-checklist-m3.md`. **The ground now
uses the first real tileset** (`iso_basic`, 8 steps, 2026-10-16; see **Map art** below and
`docs/playtest-checklist-tiles.md`). **Wolves are animated** (2026-10-18; see **Creature
art** below and `docs/playtest-checklist-wolves.md`). **Enemy Testing Grounds and the
Salamander Hound** added (2026-10-20; see those sections and
`docs/playtest-checklist-testing-grounds.md`). **The Sunscale Drake** (flying elite) added
(2026-10-20; see its section and `docs/playtest-checklist-sunscale-drake.md`). **Performance
work** (terrain cache, sleeping empty zones) is on the `optimised-build-1` branch
(2026-10-21; see **Performance**). **Audio system** and the first music track added
(2026-10-21; see **Audio**, `AUDIO_SPEC.md` and `docs/playtest-checklist-audio.md`). **Veyra Act I,
milestone 1 of 4** (quests and dialogue, branch `feature/v1.2.1`, 2026-10-26): see **Act I: quests
and dialogue**, `docs/quests-and-dialogue.md` and `docs/playtest-checklist-act1.md`. For the numbers
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
| F01 | Fire Punch | Ember Fist Scroll | Targeted, adjacent, **1 s timing bar** (zones at the end) | 1.0 magical | 4 | 2 |
| F02 | Fire Kick | Cinder Kick Scroll | Targeted, adjacent | 0.8 + burn 0.6 over 3 s | 8 | 4 |
| F03 | Fire Dart | Spark Scroll | Skillshot, any angle, 4, 16 t/s | 1.0 | 6 | 2 |
| F04 | Sun Warrior's Breath | Sun Warrior's Breath Scroll | Self | next 3 Fire casts +30% (20 s), +10% max Mana over 10 s, off GCD | 10 | 20 |
| F05 | Flame Dash | Scroll of Burning Feet | Ground 8-way, 3 | dash 3, trail burns 3 s (0.4/s); charges 1 +1/300 | 10 | 8 |
| F06 | Fire Whip | Lash of Embers Scroll | Skillshot 8-way line 3, pierce | 1.1 | 10 | 6 |
| F07 | Fireball | Scroll of the Fireball | Ground 5, 3×3, 0.4 s telegraph | 1.2 | 15 | 8 |
| F08 | Burning Ground | Scorched Earth Scroll | Ground 4, 3×3 zone 6 s | 0.35 per s | 15 | 14 |
| F09 | Blazing Combo | Blazing Fist Scroll | Targeted, adjacent | 3 × 0.5, knockback 1 | 12 | 10 |
| W01 | Healing Touch | Mender's Scroll | Targeted ally, 2 | heal 1.0 | 8 | 3 |
| W02 | Water Whip | River Lash Scroll | Targeted, 3, **3 s timing bar** (hold 0.75–2.75 s) | 1.0 | 6 | 2 |
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
| E05 | Earth Wall | Bulwark Scroll | Ground 4 | 3-tile wall +2 (climbable with Jump 2), 12 s (+1 tile / 300 Earth); lifts units on it, enemies take 10 + 0.02 per Earth Mastery | 15 | 15 |
| S01 | Slash | Rusty Shortsword | Targeted, adjacent, **1 s timing bar** (see **Timing bars**) | 1.0 physical | — | 2 |
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

## Map art (tileset, 2026-10-16)

How-to: `docs/tilesets.md`.
- **Tilesets:** a tileset is a folder under `assets/tiles/` with its images and a
  `tileset.json` catalog. A new one needs no code.
- **The catalog** gives each tile:
  - its category and kind (block / prop / surface / overlay)
  - whether it is walkable and whether it blocks sight
  - an optional water drop and shoreline sides

  It also defines terrain kinds (weighted variants, a fill block underneath, an
  optional walkability override, shoreline picking), prop groups, and the water
  sparkle animation.
- **Tiled zones:** zones name a tileset and add `terrain_rows` / `prop_rows` with
  legends. ContentDB bakes `walk_rows` and the new `sight_rows` from the catalog;
  the simulation reads only those rows. `GridModel.blocks_sight` stops line of
  sight and projectiles.
- **Pixel-perfect:** art is drawn at 2× world units (32 px tiles on the 64 px grid,
  8 art px = one height level). `PixelCamera` zooms only to whole art scales
  (counting the window's stretch: 3× at 1280×720, 4× at 1080p) and moves by whole
  pixels.
- **Drawing:** each tile is a column of blocks plus its prop, back to front.
  Characters are fitted in so terrain and props in front cover them.
- **Greenfields:**
  - grass fields with patches, dirt paths, fords at the bridges
  - the height-4 plateau as rocky ground with boulders
  - the river with rocks in it, and a light-water pond with foam in the south-east
  - rock pillars topped with grey boulders, scattered flowers, logs and stumps

  Spawns, heights, patrols and quest areas are unchanged.
- **River:** its water ripples, each tile cycling through tiles 86–89 at 6 fps from its
  own starting frame (`ripple` animation; a terrain's `animation` field).
- **Millbrook:** a bush hedge, stone houses, a cobblestone plaza, dirt paths and a
  fountain.

## Creature art (wolf, 2026-10-18)

- **Sprites:** `assets/creatures/wolf/` holds the sheets (with shadows and effects, plus
  `no_effects/` and `no_shadow_or_effects/`). Every frame is 64×64, one row per
  facing: SW, SE, NW, NE.
- **Art data:** `content/creatures/wolf_art.tres` (`CreatureArtDef`, linked from
  `wolf.tres`) holds:
  - the sheets and the feet point (32, 46), which stands on the tile centre
  - frame rates: idle 6, bite 30, howl 10, death 10 fps; run plays 4 frames per tile (one cycle spans 2 tiles, matching the paws to the ground)
  - the bite's hit frame (12)
  - corpse 4 s and fade 1 s; hit flash 0.1 s
- **Timing comes from the art:** ContentDB sets each timed ability's wind-up from its
  hit frame. Bite 12 / 30 fps = 0.4 s (was 0.3). Howl 9 / 10 fps = 0.9 s.
- **Facing:** grid up → NE, right → SE, down → SW, left → NW. Enemies face where they
  step, and toward their target when attacking.
- **Behaviour:**
  - In combat a wolf glides over its whole 0.65 s step, so the run cycle matches the
	ground.
  - The bite plays from its wind-up; damage lands on frame 12. The wolf stays put for
	the wind-up and the 2 recovery frames after it.
  - A wolf that starts a fight (spots a hero, or is hit first) stands and howls.
	When the howl ends, idle wolves within 6 tiles (`pack_call_radius`) join on the
	same hero. Wolves called in don't howl.
  - Death plays once, the corpse lies 4 s, then fades. Taking damage flashes the body
    white (the shadowless sheet, saturated).
- **Networking:** clients pick every frame from host times: steps, wind-ups (bite and
  howl), and the time of death (`died_at`, now in snapshots). All players see the
  same frame at the same moment.
- **Greenfields:** a pack of 3 wolves in the north-west corner at (2,1), (4,1) and
  (3,3), 15+ tiles from the lone wolves.
- Other enemies keep the placeholder diamond until they get art.

## Salamander Hound (2026-10-20)

A fast Ashkaran fire hound (`content/enemies/salamander_hound.tres`), level 2, MELEE.
- **Stats:** HP 190, PhysAtk 13, MagAtk 14, PhysDef 5, MagDef 12, Evasion 8, Jump 2;
  aggro 5, leash 12; 0.5 s per tile in combat (the fastest enemy), 0.25 s reaction;
  light; 70 XP, 3 AP; 3–8 g, Scroll of Burning Feet 4%, Scorched Earth Scroll 4%.
- **Bite** (`hound_bite`): Targeted, adjacent, 5 + 1.0×PhysAtk physical, 1.6 s,
  0.3 s wind-up (from the art).
- **Cinder Pounce** (`cinder_pounce`): Ground, 8 s. Aims at the free tile beside a
  hero 1–3 tiles away, on the hound's side (`AbilityDef.aim_beside_target`), and
  marks that tile plus its four neighbours (`area_diamond`) for its 0.6 s wind-up.
  Then it leaps onto the tile and deals 10 + 1.0×MagAtk magical (fire) damage to
  whoever is still on the mark. The hero stands on one arm of the plus, so any step
  except toward the hound gets out.
- **Ember Trail** (passive, `EnemyDef.trail_ability` = `ember_trail`): every tile it
  leaves while fighting becomes a 2 s ground zone dealing 2 + 0.15×MagAtk magical
  every 0.5 s (`ember_trail_burn`).
- Balance: a level-2 starter beats it every time in about 7 s, losing about 65% HP
  (`tests/balance/test_balance.gd`).
- **Art:** `art/Red-Salamander-Hound.aseprite` holds one 16-frame loop (smoke puffs, a
  crouch, a rise) facing SE and SW, 48×48. `tools/once/aseprite_export.py` reads
  .aseprite files (no Aseprite needed); `tools/once/make_salamander_hound_sheets.py`
  cuts the sheets into `assets/creatures/salamander_hound/` (plus `no_shadow/` for the
  hit flash). Art data: `content/creatures/salamander_hound_art.tres`, feet (24, 33).
  - idle = the authored loop at 10 fps
  - bite = loop frames 3–9 at 20 fps (jaws on frame 6)
  - pounce = frames 2–13 at 10 fps (springs on frame 6)
  - **Placeholders (art missing):** run reuses frames 0–3, death reuses the
	crouch (frames 4–10), and NE/NW reuse the SE/SW rows.

## Sunscale Drake (2026-10-20)

A flying elite (`content/enemies/sunscale_drake.tres`), level 6, MELEE AI, heavy.
- **Body (since the 2026-10-20 playtest):** a plus of 5 tiles (`EnemyDef.footprint`,
  `Actor.footprint`):
  - It is hit on any of those tiles (skillshots, areas, telegraphs), and blocks
	them: nobody walks into it.
  - Ranges are measured to and from its nearest body tile
	(`Actor.body_distance`), so melee works from beside any arm and it rakes
	heroes beside its arms.
  - It needs room for its whole body to move (3-wide gaps), and knockbacks don't
    move it.
  - The tiles it covers are outlined faintly on the ground, and its target ring
    surrounds the whole body.
- **Stats:** HP 3000, PhysAtk 22, MagAtk 24, PhysDef 22, MagDef 28, Acc 5; aggro 5,
  leash 14; 1.2 s per tile; 0.3 s reaction; 700 XP, 12 AP; respawn 15 min (10 s in the
  testing grounds); 60–120 g, Fireball / Scorched Earth / Burning Feet scrolls 15% each.
- **Flight** (`EnemyDef.flying`, `GridModel.can_fly`):
  - It crosses any walkable tile whatever its height.
  - It crosses walls, hedges and water up to 1 level above it (`fly_over_levels`),
    but never tiles that block sight.
  - Ground zones don't touch it while airborne.
- **Talon Rake** (`talon_rake`): Targeted, adjacent, 20 + 1.2×PhysAtk, 2.5 s. The
  0.5 s wind-up comes from the art: the talons swing through kick frame 13.
- **Sunfire Breath** (`sunfire_breath`): skillshot cone, 8-way, 4 tiles, 10 s.
  - It rears back for 0.8 s with the cone outlined.
  - Then 18 + 1.0×MagAtk magical damage, with flames drawn over the cone
	(`AbilityDef.flame_effect`).
  - The cone burns for 3 s (`sunfire_burn`: 3 + 0.15×MagAtk every 0.5 s).
- **Searing Dive** (`searing_dive`): Ground, range 2–5, 14 s.
  - The tiles its whole body will sweep glow for 1 s: 5 steps, 3 lanes wide when
	straight (`AbilityResolver.charge_lane` / `charge_swept`, the same tiles the dive
	uses).
  - Then the new effect `CHARGE_THROUGH` moves the drake along the lane at
	0.16 s per tile.
  - Each enemy its body reaches gets `searing_dive_hit`: 18 + 0.9×MagAtk magical,
    a shove sideways (`AbilityEffect.push_aside`) toward the side of the lane it was
    on, just out of the marked lane (1 tile from an edge lane, 2 from the centre,
    whatever its weight; `CombatContext.push_tiles`), then a 1.5 s stun
    (`searing_dive_stun`) that starts once the shove lands. Anyone still in the way
    stops the dive.
  - The swept tiles burn for 2 s.
- **Airborne passive:** a knockback from an Air ability (`grounded_by_tree`) applies
  `drake_grounded` even when its weight cancels the push: stunned 3 s and 25% more
  damage taken. While grounded it isn't airborne, so burning ground hurts it.
- **Molten Fury:** below 30% HP (`enrage_below`) it gains `molten_fury`: cooldowns ×0.7,
  and its ground zones last 2 s longer (`BuffDef.zone_seconds_bonus`), so the breath's
  fire burns 5 s. It glows hotter and the message log announces it. Evading clears it.
- **Balance** (`tests/balance/test_balance.gd`, bots that never dodge): it beats a
  level-7 group of four every time (user request, 2026-10-21); see the decisions log for
  the measured rates. A pair or a lone hero loses.
- **Chasing:** it heads for any tile where its body is beside its target
  (`Pathfinder.find_path`'s `arrived` test), not the target's own tile, which its body
  can never reach. A chase search that finds nothing waits 0.5 s before the next.
- **Art:** `art/Crimson_dragon_animated.aseprite` (in `art/`, not `art/creatures/`):
  128×128, 56 frames at 100 ms.
  - Its two layers face SW and NW. SE and NE mirror them.
  - `tools/once/make_sunscale_drake_sheets.py` shifts each layer into 160×128
	frames so the drawn-in shadow's centre sits on feet (80, 95).
  - Animations:
    - idle = Standing 0–7, 8 fps
    - run = Moving 48–55, 8 frames per tile
    - rake = kick 8–15, 10 fps
    - breath = 16–23 at 5 fps (16–19 rear back, 20–23 head forward)
    - dive = frame 24 held 1 s, then 24–31
    - Facings: SE shows the SW layer as drawn and SW shows it mirrored (they were
      swapped in the first build). NW and NE are unchanged.
    - death = Dying 32–47, then 1 s still and a 1 s fade
  - `no_shadow/` sheets are used for the hit flash.
- **Recolour:** `CreatureArtDef.recolor` with colours in data (dark, mid and light,
  plus strength, saturation cut-off, centre and contrast in
  `content/creatures/sunscale_drake_art.tres`).
  - `view/shaders/creature_recolor.gdshader` maps each opaque, low-saturation pixel's
	brightness onto dark crimson → crimson → gold.
  - Flames and the semi-transparent shadow keep their colours.
  - `CreatureRecolor` renders each sheet once through the shader into an off-screen
	viewport, so the drake still draws in the world's back-to-front order.
- Animated elites are labelled "Elite …" in gold. "Grounded!" and "Molten Fury!" float
  over the drake, and a grounded drake shows "Grounded" under it.
- **Placement:** its own pen in the testing grounds' Boss Arena. Spacing now counts how
  far an enemy's abilities can carry it (`AbilityDef.moves_caster_tiles`: dashes,
  charges, leaps), so its dive can't reach other pens. There is no Ashkaran caldera
  area yet, so the planned rare spawn there waits for that zone.

## Audio (2026-10-21)

`AUDIO_SPEC.md` is the sound designer's guide (formats, naming, loudness, every key with
its status). Regenerate its key list with
`godot --headless --path . -s res://tools/write_audio_spec.gd`; a test fails when a key
is missing from it.
- **Buses** (`default_bus_layout.tres`): Master, with Music, Ambience, SFX and UI under it.
  A slider per bus: the main menu's Settings button and, in game, the Escape menu's
  **Sound** tab (since the merge with the menu book, which removed the button row);
  volumes are saved per player in `user://settings.cfg` `[audio]`.
- **`Audio` autoload** (`autoload/audio.gd`), tuned by `content/audio/audio_config.tres`
  (`AudioConfig`):
  - **Music** by context (`MusicTrackDef.Context`: title, town, explore, combat,
    dungeon, boss). Tracks are data: one `MusicTrackDef` per file in
    `content/audio/music/` (name, file, contexts, loop, volume, drained). Two players
    crossfade over 1.5 s; the same track never restarts.
  - **Fallbacks** while tracks are missing: boss → combat; combat keeps whatever is
    playing; dungeon → explore → town.
  - **Ducking:** sounds whose `SfxDef` says `ducks_music` lower the music 6 dB for 0.8 s
    (howl, breath, dive, charge, big deaths, level-up, world events).
  - **Bond hook:** `ZoneDef.bond` (0–1, default 1), overridable with
    `Audio.set_zone_bond`. Below 0.35 a track marked `drained` for the context is
    preferred. No drained tracks exist yet.
  - **Sound effects by key.** The first word of the key picks the folder and bus
    (`AudioConfig.categories`), and the file is `audio/<folder>/<key>.wav`. Numbered
    takes (`<key>_1.wav` …) rotate at random. An optional `SfxDef` entry changes the
    file, level, variation, voice limit or ducking. A missing file logs one warning
    and plays nothing.
  - **Variation:** random pitch and volume per category (footsteps ±8% / ±2 dB, hits
    ±5% / ±1.5 dB, UI none). At most 4 copies of a key play at once.
  - **Positional:** world sounds are `AudioStreamPlayer2D`s in the world view, heard
    from an `AudioListener2D` on the local hero, fading out over 14 tiles. Each
    player hears their own position.
- **Keys** (`SoundCatalog`, `data/sound_catalog.gd`, built from the content):
  - hero abilities: `<tree>_<ability>_cast` when used and `…_hit` where they land.
    The tree is fire, water, earth or air, or weapon for Sword/Bow/Hammer, and its
    name isn't repeated (`fire_dart_cast`).
  - creature attacks: `creature_<enemy>_<ability>` and `…_hit`; creatures also have
    `_aggro`, `_hurt`, `_death`, `_step` (+ `_grounded`, `_enrage`).
  - parts of abilities (ground-zone ticks, dive hits) only have a `_hit` key.
    Abilities that never damage, heal or shield have no `_hit` key, and potions
    (`world_…_cast`) have none either.
  - footsteps `footstep_<terrain>` per walkable terrain (`footstep_default` without a
    tileset), `ambience_<zone>` per zone (or `ZoneDef.ambience`), `ui_…`, `world_…`.
- **`SoundDirector`** (`view/sound_director.gd`, made by `Game`, client side): turns
  events into keys. A wind-up or cast plays its sound when it starts, not again when
  it lands; hurt sounds play at most every 0.4 s per enemy. It plays footsteps for
  every walking actor. Each 0.25 s it sets the music context: the zone's
  (`ZoneDef.music_context`; Millbrook = town, others explore), combat while any
  fighter within 12 tiles of the local hero (or the hero) is in combat, and boss
  when one of them is an elite.
- **First track:** `audio/music/music_idle_draft.ogg` (title and town), converted from
  the uploaded MP3 (now `art/audio/`). The MP3 had 43 ms of encoder silence at the start
  and ended at full level, so it clicked when looping. The OGG trims the silence and
  fades 10 ms in and 120 ms out.
- No sound effect or ambience files exist yet: all 152 keys are listed as missing in
  `AUDIO_SPEC.md`.

## Act I: quests and dialogue (milestone 1 of 4, 2026-10-26)

User brief: a playable prototype of Act I of Veyra; this first milestone extends the
quest system to carry the story and adds dialogue. How to edit: `docs/quests-and-dialogue.md`.
- **Dialogue file:** every line is in `content/dialogue/act1.json`, by id
  (`DialogueLines`, `ContentDB.dialogue`). A line is text or {text, speaker, next,
  choices}. Ids follow conventions: `npc.<npc>.greeting[.<world flag>]`,
  `quest.<quest>.offer / restart / accept / decline / accepted / declined / progress /
  complete / failed / world_flag`, `quest.<quest>.interact.<i> / deliver.<i> /
  escort.<i>`, `quest.<quest>.spot.<i>.<n>`. The Millbrook quests' and NPCs' texts
  moved there from their .tres files. Content checks: every quest has offer and
  complete lines, every NPC a greeting, every `next` and choice leads somewhere.
- **Dialogue box** (`DialogueBox`, bottom centre): a portrait (`PortraitView`: the
  NPC's `portrait`, else a frame in its faction's colour with its initials; "hero"
  lines show yours), name and faction, the line, then its choices, Continue, or
  the main page (quests, shop, Goodbye). Quest pages (`QuestDialogue`) put the
  objectives and rewards under the NPC's line; the offer's buttons are the file's
  accept / decline answers.
- **Quests** (`QuestDef`): main or side (`category`), `area`, `given_items` (handed
  over on accept, taken back on abandon or failure). Objective kinds added to kill,
  collect, talk and reach:
  - **Escort:** talk to the escortee (`NpcDef` with `max_hp`) to set it off along
    `path`; it walks at 0.7 s per tile, only while a party member on the quest is
    within 6 tiles; it's on the heroes' side meanwhile (enemies aggro on it,
    heroes heal it). At the last point the objective is done for party members
    within 15 tiles; it goes home 30 s later. If it dies, the quest **fails** for
    everyone on it in the zone (state `failed`, saved), the giver shows "!" again
    ("(try again)", line `restart`), and it's back home 5 s later.
  - **Deliver:** talk to `npc` with the items in your bag; they're handed over and
    party members nearby on the quest get the credit (their own copies of a
    handed-over item go too).
  - **Interact:** use an object (`NpcDef` of kind Object) with E.
  - **Investigate:** examine every spot in `spots` with E (within 1 tile); spots glow
    (a cyan ring with "?") until examined; each counts once, for party members
    nearby; which ones were found is saved (`found`).
- **Co-op:** a quest is the party's: when someone accepts at the giver, everyone else
  in the zone who can take it gets a prompt (`QuestPrompt`, top of the screen: Join /
  Not now; `accept_shared_quest`, no need to go to the giver). Progress counts for
  party members on the quest within 15 tiles (as before). The one who talks sees the
  dialogue; the others see a speech bubble over the NPC. Each hero's quests save
  with that hero.
- **NPCs** (`NpcDef`): `kind` Person / Board / Object / Caravan, `faction` Townsfolk
  (grey), Floor Guild (blue), Ember Hand (red), Bedrun (ochre), Vael (pale blue), None
  (wood) (`Factions`). Placeholders are a shape per kind in the faction's colour with
  the name above (`WorldView._draw_npc`); with `art` set they're drawn like the
  creatures, so real sprites only need the art. Quest boards are NPCs of kind Board:
  they give quests and take hand-ins like anyone. "[E] Talk / Read / Use / Examine".
- **Tracker and log:** main quests first; the log groups Main / Side with each area;
  failed quests show where to restart them.
- **Placeholder Act I** (story to be replaced; all lines in the file):
  - Millbrook: Guild Board (3,7), Warden Iska Dorne (5,8), Sabra Venn (15,8), Ilyth
    the Seer (9,14).
  - Greenfields: Bedrun camp with the Mine Board (26,13), Foreman Hadda Brannoc
    (26,15) and the ore caravan (23,15, 320 HP); the Collapsed Shaft (28,12); the
    Vael Standing Stone (2,27).
  - Main chain:
    1. The Guild's Summons (board, talk)
    2. Ash on the East Road (investigate 3 spots)
    3. The Ember Hand's Writ (deliver)
    4. Ore for Millbrook (escort, level 2, hand in to Dorne)
    5. What the Stone Remembers (interact + kill 3 wolves, level 2). Sets
       `act1_complete`.
  - Side: Bandits on the Ore Road, The Collapsed Shaft, Guild Patrol: The Bridge.
    Rowan's and Maren's 5 quests are side quests.
- **Network:** new intents `examine` and `accept_shared_quest`; the escort flag is
  in each NPC's snapshot. The 4-player check now has the guests in town join the
  host's quest over the network.

## Enemy Testing Grounds (2026-10-20)

- **Getting there:** a 2-tile gate in Millbrook's north-east hedge at (15–16, 0), with an
  "Enemy Testing Grounds" sign at (17, 1) and a dirt road down to the town's main path.
  The zone edges link it with the gate at the west end of the testing map's
  south-west edge (offset ±12). Like every edge, it works for each player and not in combat.
- **Built from data:** `content/zones/enemy_testing.tres` only names the tileset, the
  edge and `enemy_pens = true`. `TestingGrounds.build` (`data/testing_grounds.gd`),
  called by ContentDB at load, lays out:
  - one pen per enemy type in `content/enemies/`, so new enemies get a pen
    automatically
  - pens ordered by level, then id
  - elites in a **Boss Arena** behind a hedge at the far east end
  - a sign per pen, e.g. "Wolf (Lv 1)"
  - an entrance plaza at the west end with hero spawns, a graveyard and the
    **Reset Shrine**
- **Spacing:** neighbouring spawns are at least
  max(reach A + aggro B, reach B + aggro A, leash + pack call) + 3 tiles apart. Reach
  is the leash radius, plus the longest distance its abilities can carry it, plus its
  longest attack range. Bosses get 4 more tiles. The road is out of every aggro radius.
  Pens are separated by low stone walls and open onto the road. Today the map is 209×14.
- **Respawn:** 10 s, from `ZoneDef.enemy_respawn_seconds` (per spawn:
  `EnemySpawn.respawn_seconds`). Grizzlehide doesn't patrol here.
- **Training Dummy** (2026-10-26, `content/enemies/training_dummy.tres`,
  `EnemyDef.training_dummy`): a straw mannequin in the grass corner behind the
  entrance, at (3, 2) (`TestingGrounds.DUMMY`), for practising abilities and timing bars.
  - HP 1,000,000, no defenses, no attacks, aggro 0; it never moves or turns.
  - Knockbacks and pulls don't move it.
  - It gives no XP, AP, loot or Mastery.
  - Hitting it is a fight (combat rules apply). Walk more than 6 tiles away (its leash
    radius) and it drops you, so your combat ends; it then resets to full health.
  - Dummies get no pen or sign; every other enemy still does.
- **Reset Shrine** (`content/npcs/reset_shrine.tres`, `NpcDef.resets_zone`): talking to
  it runs `WorldSim.reset_zone()`:
  - every enemy goes back to its pen at full health (debug spawns are removed)
  - projectiles, telegraphs, ground zones and raised terrain are cleared
  - every buff and debuff in the zone is removed, and heroes there leave combat

## Menu book (branch `ui-book-menus`, 2026-10-21; work in progress)

- **Art:** `art/menu_book.aseprite` (the user's "livre menu", still being drawn; marks
  and icons to come). **Layer 1** (the book) is exported to `assets/ui/menu_book.png`
  (480×270) with Aseprite's command line:
  `Aseprite.exe -b --layer "Layer 1" art/menu_book.aseprite --save-as assets/ui/menu_book.png`
- **Layers of `art/menu_book.aseprite`** (2026-10-23): 1 the book; 2 and 3 the user's
  drawing templates (not used); 4 the inventory page, exported to
  `assets/ui/inventory_page.png` and drawn over the book while the inventory is open
  (`BookSpread.page_art`); 5 the rarity borders, cut into `assets/ui/rarity/common.png`,
  `uncommon`, `rare`, `epic` (28×29 each; grey, green, blue, purple).
- **Inventory on the drawn page** (`InventoryWindow`): every slot sits on its drawn frame
  (art pixels: equipment frames 34×35, bag frames 26×26 every 29 px from (261, 65)).
  Left page by picture: scroll = learning slot (93, 66), hat = Head (129, 66), sword =
  Main Hand (165, 66), glove = Hands (93, 103), chest = Chest (129, 103), arrow = Off
  Hand (165, 103), band = Accessory (93, 140), trousers = Legs (129, 140), ring =
  Accessory (165, 140), boots = Feet (130, 178) (confirmed by the user). An empty slot
  draws nothing (the picture shows). A filled equipment slot covers its picture with
  paper and shows the full rarity border, centred as drawn; a filled bag slot is tinted
  30% with the rarity's colour. Then the item name in ink, until items have icons.
  "Equipment" and "Bag" head the pages; the learning text sits left of the boots, gold
  centred under the bag. Other menus (loot) keep the dark slots.
- **Item tooltips** (`ItemTooltip.text` / `label`, text 13, 280 wide; every tooltip opens
  after 0.15 s: `gui/timers/tooltip_delay_sec`), on every item: bag,
  equipment, shop and loot rows (`ItemLabel`), quest rewards. Name in rarity colour,
  rarity and slot, stats, growth per level, then for each taught ability (and a
  consumable's Use) what it does in numbers for your hero now (`ability_lines`): how it
  is aimed and its range or area, mana, cooldown, cast / wind-up / channel, each effect
  (damage, healing, % of max, over time, shields, buffs, knockbacks, dashes, terrain,
  ground zones with their damage per tick), what it scales with, and the Mastery it has
  given. Then where a tree item stands for you, potions' shared cooldown and stack size,
  sell price and the comparison with what you wear.
- **Where it goes:** hovering an equippable bag item (or dragging any item) lights up the
  equipment slot(s) it would go in, in gold (`ItemSlotView.fits`: accessories light both,
  a two-handed weapon the main and off hand).
- **`BookView`** (`ui/book_view.gd`): draws the book filling the screen (the 1280×720 UI:
  exactly 4 screen pixels per art pixel at 1080p; uneven art pixels in other windows).
  Writable areas measured on the art: left page (66, 46, 166×174), right page
  (250, 46, 158×174), and the spread over both. A Close button sits above the right
  page. Arrows under the pages' bottom corners turn to the previous and next menu
  ("<  Character", "Spellbook  >"): Character → Inventory → Spellbook → Trees → Quests,
  wrapping around (`Hud._turn_page`; from the loot menu they lead to the ends).
- **Every menu fills both pages** (since 2026-10-21, user request), one menu at a time:
  opening another closes the one before (`Hud._update_book`). Menus extend `BookSpread`
  (`ui/book_spread.gd`): a `left` and a `right` column, one per page. How-to hints are
  in the Escape menu's Controls tab, not on the pages.

  | Menu | Left page | Right page |
  |------|-----------|------------|
  | Inventory (B) | "Equipment", the hand-drawn page (Layer 4): learning slot, 9 equipment slots, learning text | "Bag", the hand-drawn 5×4 bag, gold |
  | Character (C) | name with level and XP beside it, stat table | Mastery, learning slot, abilities |
  | Spellbook (P) | title, first part of the list | the rest |
  | Quests (L) | quest list | the selected quest (scrolls), Abandon |
  | Loot | waiting loot ("your bag was full") | your bag |
  | Trees (T) | title, tabs, tier 1–3 columns | Mastery line, tier 4–5 columns |

  The trees read left to right: one column per tier, headed by the Mastery it needs,
  the tier's abilities going down; prerequisite lines run sideways between tiers.
  The book shows while a menu is open, under the rest of the HUD (unit frames, action
  bar, menu buttons stay on top), and blocks clicks to the world. The quest tracker hides.
  New loot opens the loot menu once; closed, it stays closed until more loot comes.
- **Sharp text in any window:** the book always fills the UI, so menus are drawn at
  their real size (scale 1) and never resampled. (Earlier: pages shrank slightly
  too-big content by a fraction, and a 1280×720 window drew the book at 2× and every
  menu at 75%; both blurred the text.) The cost: outside 1080p the art pixels are
  uneven (2 or 3 screen pixels at 720p). Content too tall for its page is cut at the
  page bottom; long lists scroll.
- **The shop is its own sheet** (`VendorWindow`, a paper panel apart from the book):
  open together with the book. "Browse goods" opens it and your inventory and hides the
  conversation box (the shop closes when you walk away); writing 17, title 22. Sell
  with a right-click in the bag. Drag it by its title; it has its own Close button, and
  closes when the conversation ends. Its goods list fits between where it sits and the
  action bar.
- **Moving the book:** drag its top edge (move cursor) to move it in the window; part of
  the top edge always stays on screen (`KEEP_VISIBLE`). The book stays where you put it
  while the game runs.
- **Text sizes** (user request): paper text 20 (Godot's default 16), page titles 26,
  notes 16, spacing 4. Item slots are 64 px (were 48) with the item name on up to two
  lines at 14 (was 6 letters at 11); rarity colours are lightened inside the dark slots.
- **Main menu:** title, character and Play Solo on the left page; Host / Join on the right.
- **Ink on parchment** (`ui/ui_palette.gd`): paper and leather colours come from the art.
  The paper theme makes window boxes see-through, text dark ink, buttons and tabs
  leather, fields and tooltips paper. Shared text colours (`ItemTooltip`, `QuestText`)
  and rarity colours are dark enough for paper, so the quest tracker and the dialogue
  box became paper sheets too. Item slots stay dark squares. Unit frames, the action
  bar, the message log and the death panel keep the dark default look.

## Escape menu and a cleaner screen (branch `ui-book-menus`, 2026-10-21)

User request. Replaces parts of HUD rule 15 (the button row and the message log).
- **Off the screen:** the row of buttons above the action bar (Spellbook, Trees,
  Character, Inventory, Quests, Keybinds, Leave game: menus open with P T C B L), the
  bottom-left message log and its controls line, and every how-to hint in the book and
  the shop. Red errors still flash mid-screen; a banner shows above the action bar in
  keybind mode.
- **Escape menu** (`ui/hud/game_menu.gd`, plain dark boxes, not the book): Resume,
  Keybinds (starts keybind mode and gets out of the way), Leave game, and tabs: **Log**
  (every message this session, up to 300: `ClientState.history`), **Controls** (all
  the how-to text), **Keybinds** (how binding works), **Gameplay test** (below).
- **Game speed** (Gameplay test tab, 2026-10-24): a slider (drag; sent on
  release) and a box to type an exact value, ×0.1 to ×2, plus "Reset to ×1".
  - It sets `CombatRules.game_speed`. The whole sim clock runs at that speed, in
	and out of combat (`World.time_scale`, applied by the session that drives the
	ticks; clients get it in each snapshot to pace their clock): walking, steps,
	ability cooldowns, the GCD, casts, wind-ups, projectiles, telegraphs, buffs, ground
	zones, regen, respawns, enemy reactions and animations all scale together.
  - It goes to the host as a `game_speed` intent, allowed only where the debug console
	is (debug builds), and applies to every zone. Not saved: it lasts while the game runs.
- **Esc, WoW-style** (`Hud._escape`): cancel aiming; else leave keybind mode; else close
  the Escape menu if open; else close the menu book, shop and conversation; else clear
  the target; else open the Escape menu. (The dialogue box no longer handles Esc itself.)
- **Quest tracker:** a "Quests" heading (drag it to move the tracker) with a fold button
  (– / +) that hides the list;
  text 15, 260 wide.

## Timing bars (2026-10-26)

The rhythm part of casting (user brief). A hero's ability with a timing bar
(`AbilityDef.timing_bar`, a `TimingBarDef`) doesn't go off at once: the bar runs,
and the player right-clicks on its zones.
- **Zones:**
  - Green: a tap there gives full power.
  - Yellow (inside a green zone): full power and a sure critical strike
    (`CombatContext.force_crit`).
  - Blue (hold): press right-click as the zone starts and let go as it ends. Rule:
    a hold zone ends 0.2–0.3 s before the end of its bar (`HOLD_END_GAP`; a test
    checks every ability), so letting go on time is part of it. Accuracy = 1 −
	(how early or late you pressed + how early or late you let go) ÷ the zone's
	length (`TimingBarDef.hold_accuracy`). 95% or more: a sure crit at full power;
	50% or less: miss power; in between, power rises steadily from 0.7 to 1
	(`hold_power`). A press up to 0.2 s early starts the hold (the early part counts
	as mistiming); earlier, it's a missed tap. Judged when you let go, or at the bar's
	end if still held.
  - A tap anywhere else, a hold that falls short, or no press:
	`CombatRules.timing_miss_power` (0.7).
  - The reward is for good timing; nothing worse than a reduced hit.
- **Where the bars come from:** `design/Ability_Tree.xlsx` (source of truth since
  2026-10-26): four columns at the end of the Abilities tab (Timing Status, Timing Bar
  (s), Timing Zones, Timing Notes) and a **Timing Rules** tab (zones, outcomes, holds,
  margins, display, how to write the columns, tunable values). The importer reads and
  checks them (`AbilityTreeImporter._timing`, see `docs/ability-import.md`); TreeContent
  builds each `TimingBarDef`; `AbilityDef.timing_status` keeps manual / generated / none.
  Behavior files no longer hold bars. No runtime cost: the import runs offline.
- **Which abilities** (test lengths, not balanced):
  - Manual (the user's): Slash 1 s (tap 0.35–0.65, crit 0.45–0.55), Fire Punch 1 s
    (tap 0.7–1.0, crit 0.9–1.0), Water Whip 3 s (hold 0.75–2.75), Quick Shot 2 s (hold
    0.25–1.75), Aimed Shot 4 s (tap 0.2–0.6 with crit 0.35–0.45, then hold 1.0–3.75).
  - Generated (AI drafts, in the game, to be confirmed), by tree feel: Fire late snaps
    (F02, F03, F06–F09), Water holds (W01, W04–W07, W09), Air early beats (A01, A05),
    Earth one heavy late beat (E01), Hammer late heavy beats (H01, H02). Instants
    marked "none": F04, F05, W03, W08, A02, A03, E03, E04, E05, S04 (dashes,
    interrupts, buffs, taunt, terrain).
  - The other 113 abilities: Not implemented.
  - A bar replaces the ability's cast time or wind-up (Aimed Shot's draw, Smash's).
- **Several inputs** (2026-10-26, Aimed Shot first): a bar's inputs (each tap zone with
  the crits inside it, each hold zone; `TimingBarDef.inputs()`) are played in order,
  one press each. A press goes to the next input whose window isn't over
  (`input_for_press`); skipped or unplayed inputs are misses. The ability goes off
  after the last input (or at the bar's end). Power = the inputs' average; a sure crit
  only if every input is perfect; MISS only if every input missed (`combine`). The
  accuracy shown is the average (a tap: 100% hit, 0% missed). Input zones can't
  overlap (import check).
- **Aimed abilities aim at the end** (2026-10-26): a skillshot or ground ability with a
  bar starts its bar as soon as the key is pressed (no aim-then-release); the affected
  tiles follow the cursor during the bar (`PlayerInput._start_bar_aiming`), each input
  carries the cursor (`aim` on `timing_press` / `timing_release`), and it fires where
  the last one pointed. A ground aim beyond range is pulled back to the edge of it
  (`WorldSim._clamp_aim`), at the start and at each input. A hold still held when the
  bar ends is let go by the client then, with the final aim. Aimed abilities without a
  bar keep aim-then-release.
- **Crits travel:** a critical success is carried by the projectile or delayed hit
  (lob, telegraphed area) it launches (`Projectile.force_crit`, the pending hit's
  `force_crit`), like the damage bonus.
- **What power scales:** damage (through the damage bonus), and since 2026-10-26
  healing, heals over time and shields (`CombatContext.timing_power`). Buffs aren't scaled.
- **Test switch:** `CombatRules.timing_bars_enabled` (on); tests of ability effects turn
  it off so abilities go off at once.
- **Rules (a cast kind `timing`):**
  - The GCD starts with the bar; mana and cooldown are paid when it goes off.
  - A tap that is the last input casts the ability at once, a hold when let go.
  - Moving, a stun, an interrupt or the target leaving range cancels it (cooldown
	not spent).
  - Enemies cast these abilities without a bar.
- **Network:** the client measures its presses against the bar as it saw it and
  sends `{"type": "timing_press", "at"}` and, for a hold, `{"type":
  "timing_release", "at"}`. The host judges them (`TimingBarDef.judge`,
  `hold_accuracy`), never accepting a moment it hasn't reached (+0.3 s slack). With no
  press it waits `timing_press_grace_seconds` (0.25) after the bar ends, then casts
  at miss power. It emits `timing_result` (miss / good / perfect, and a hold's accuracy).
- **Display** (`TimingBarView`): the ability's name above the bar (so a wrong key
  shows at once; "Hold!" while holding, "Let go!" past the zone), then "Perfect!" /
  "Good" / "Miss" (a hold adds its accuracy, e.g. "Good 88%") for
  0.8 s. Time always moves at the same speed on screen: the full bar length is 3 s
  (`FULL_SECONDS`). Other players see a small green cast bar under you. Two options
  (Escape menu → Gameplay test; saved in `user://settings.cfg`):
  - **Where:** under your hero (220×15) or above the action bar (440×30).
  - **Mode:** *length follows the ability* (a cursor sweeps a bar as long as the
	ability, centred: Slash's 1 s bar is a third of the full length), or *zones
	slide to a fixed hit line* (the full-length bar is a window on the track: the
	white hit line sits 0.4 s from the left and the zones slide toward it; thin
	marks show where the ability's bar starts and ends).
- **Balance:** the bots tap early in the green zone and hold blue zones exactly.
  The bars make abilities hit later, so some balance targets are pending (the
  starter and a lone sword vs a Wolf, a pair vs 2 Wolves, a caster's mana vs a Wolf,
  a level-2 caster vs the Shaman, plus the drake from before) until the planned
  combat pacing pass, which slows the enemies down.

## Performance (branch `optimised-build-1`, 2026-10-21)

Measure with `tools/perf/` (headless, no window; a headless frame costs at least
~6.9 ms by itself): `draw_profile.tscn` (frame time per map, both drawing modes) and
`sim_profile.tscn` (sim cost per tick, zones sleeping or not).
- **Terrain cache** (`WorldView.use_terrain_cache`, on by default for tileset maps):
  - The ground is drawn once into chunk nodes of 8 depth rows under the view, and
	Godot keeps them. A chunk is redrawn only when a height in it changes (and the
	row behind it).
  - The river ripples and water sparkles use self-animating textures
	(`TileArt.animated_texture` / `sparkle_texture`), so nothing redraws for them.
  - Each frame the view draws actors and tile highlights back to front. Inside a box
	around each (merged where boxes overlap), it draws again, in order, the tiles from
	that depth row forward, cut to the box. Projectiles, labels and bars go on top.
  - Same picture as redrawing every tile: the screenshot test with
	`SHOTS_COMPARE_CACHE=1` saves each shot both ways on one frame; all 42 match.
  - Frame time: Greenfields 28 → 9 ms, testing grounds 77 → 7 ms.
- **Empty zones sleep** (`CombatRules.empty_zone_sleep_seconds` = 30; negative turns it
  off):
  - A zone with no heroes for that long only advances its clock
	(`WorldSim.skip_tick`). Its enemies, patrols, projectiles and ground zones wait.
  - Anything timed in sim time (respawns, buffs, raised terrain, ground zones) still
	runs out on schedule and resolves on the first tick after a hero arrives.
  - The 30 s wait lets a fight that was just left settle (enemies evade, heal and
	walk home) before the zone sleeps.
  - Sim cost with one hero in town: 1.30 → 0.22 ms per tick.

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
- **Enemies outpace heroes in combat** (Wolf 0.65 s/tile since 2026-10-19) and react 0.3 s late, so
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
| Wolf | HP 230, PhysAtk 12, PhysDef 5, Evasion 5, Jump 1; aggro 4, leash 10; 50 XP; respawn 30 s; 0.65 s/tile; 0.3 s reaction | — |

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
| Wolf | 1 | Melee | (see above) | Bite | 0.65 s / 0.3 s | 50 / 2 | 2–6 g, pelt, fang, Uncommons 2% | (8,13) (11,24) (5,20) (18,4) |
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
autoload/        net (ENet host/join), content_db (loads .tres), audio (music, sound effects, volumes)
sim/             world (all zones), world_sim (one zone) + grid/ stats/ combat/ progression/ entities/ ai/ quests/
net/             intents, snapshot, server_session, client_session
data/defs/       Resource scripts (*_def.gd, stat_block.gd, combat_rules.gd)
content/         items/ abilities/ buffs/ enemies/ loot/ npcs/ quests/ heroes/ zones/ rules/ audio/ (.tres),
                 dialogue/act1.json (every line of dialogue, by id)
audio/           music/ (OGG), ambience/ (OGG), sfx/<category>/ (WAV); see AUDIO_SPEC.md
assets/tiles/    tilesets: one folder each (tile images + tileset.json)
assets/creatures/ creature sprite sheets (one folder per creature; art data in content/creatures/)
assets/ui/       interface art (the menu book)
art/             uploaded source art (zips, .aseprite, audio/ masters; ignored by Godot, never exported)
view/            world view, iso tile renderer, actor views, camera
ui/              main menu, stores (characters, world, settings), HUD (action bar, unit frames,
				 inventory, character sheet, spellbook, ability trees, dialogue, vendor, loot,
				 quest log, tracker)
input/           player input → intents
scenes/          main.tscn and other top-level scenes
tools/           ability spreadsheet importer (xlsx reader, converter, CLI), behavior generator,
                 write_audio_spec.gd (sound key list in AUDIO_SPEC.md)
design/          Ability_Tree.xlsx (source of truth for abilities)
tools/once/      one-off content conversions and generators (kept for the record)
tools/perf/      headless profilers: frame time per map, sim cost per tick
tests/           unit/ integration/ balance/ (GUT, test_*.gd; balance builds in balance_scenarios.gd),
				 net/ (multi-process check), visual/ (screenshot scene), fixtures/ (legacy M1 hero)
docs/            local multiplayer testing, playtest checklists (M2, M3, tiles, wolves, testing grounds, Sunscale Drake, audio, Act I), ability import, tilesets, quests and dialogue
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
	  and in line of sight. Damage also pulls it. No group/social aggro, except wolf
	  packs (since 2026-10-18): a wolf's howl calls idle wolves within 6 tiles.
	- In combat the enemy attacks the top of its threat table whenever an ability is
	  ready and in reach; otherwise it paths toward the target on its step cooldown.
	  It turns to face a target next to it (free) before a FRONT attack.
	- Per enemy type: `combat_step_seconds` (Wolf 0.65 s/tile, faster than heroes'
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
	  turn-only tap is gone). Stepping never turns a hero (since 2026-10-17); enemies
	  still face where they step. Turning is free and instant, in combat too.
	  The newest held direction key wins; pressing a new direction turns at once even
	  while another is held or the step is on cooldown; in combat no step is queued
	  ahead, and a turn cancels any queued step (post-M2 playtest fix).
	- WoW-style targeting (click an actor, Tab cycles nearby enemies, Esc clears) is
	  used by TARGETED abilities; ally abilities fall back to self. FRONT/LINE
	  abilities aim where you face; their action bar slot is red when nothing would
	  be hit.
	- Placeholder art: height-tinted tiles, blue water, grey rocks, heroes as
	  circles, enemies as red diamonds, floating combat text. (Since 2026-10-16 the
	  ground uses the `iso_basic` tileset; see **Map art**. Characters and effects
	  are still placeholders.)
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
| 2026-10-26 | Veyra Act I, milestone 1 of 4: quest system extended for the story, and dialogue | User brief ("make sensible decisions, list them"). See **Act I: quests and dialogue**. My decisions are in the next rows. |
| 2026-10-26 | Branch `feature/v1.2.1` from `main`, fast-forwarded to `claude/godot-2d-coop-rpg-5nvase` | `main` was still at Milestone 1, without the quest system this extends; `main` is an ancestor of the working branch, so the new branch holds both and the pull request into `main` carries everything since. |
| 2026-10-26 | One JSON file of lines, by id convention; existing texts moved into it | JSON over .tres: readable and editable in any text editor. Conventions (`npc.<id>.greeting`, `quest.<id>.offer`…) mean quests and NPCs need no extra fields; a missing line falls back to a short default. The world-flag announcement moved there too (`quest.<id>.world_flag`). |
| 2026-10-26 | Quest boards and objects are NPCs (kind Board / Object) | They give quests, take hand-ins and are used with E like anyone, with no new system. |
| 2026-10-26 | Escort rules | Mine: it sets off when a party member on the quest talks to it; 0.7 s per tile; it waits while no one on the quest is within 6 tiles; on the heroes' side while walking (enemies aggro on it, heroes heal it); arrival credits party members within 15 tiles; home 30 s after arriving, 5 s after dying. A failure fails the quest for every hero on it in that zone; heroes in other zones keep it active. |
| 2026-10-26 | Failed quests restart from the giver with fresh progress | A failed quest is saved as failed and shown in the tracker and log; the giver offers it again with its `restart` line. Handed-over items are taken back on failure (and on abandon). |
| 2026-10-26 | Deliver: one hand-over credits the party nearby; their copies go | Each party member gets the item on accepting; when anyone delivers, the others' copies are no longer needed. |
| 2026-10-26 | Investigate: E within 1 tile of a glowing spot; each spot once; found spots saved | E prefers the NPC in front of you, then a spot beside you, then the nearest NPC. |
| 2026-10-26 | Co-op accept: a prompt to the party in the same zone, Join from anywhere in it | "The others get the quest prompt too": sent when someone accepts (not when they merely open the offer), only to those who can take it (prerequisites, level). A player joining the session at that very moment can miss it; the giver still offers it. |
| 2026-10-26 | Speech bubbles: the NPC's greeting over it for 4 s (70 characters), for the other players | The talker's later lines stay private (the dialogue is client-side); the escortee's setting-off line shows as a bubble for everyone. |
| 2026-10-26 | Placeholder look: a shape per kind (person, board, wagon, block) in the faction's colour; portraits are a coloured frame with initials | Faction colours: Floor Guild blue, Ember Hand red, Bedrun ochre, Vael pale blue, townsfolk grey, objects wood. An NPC with `art` is drawn by the same creature code as the wolves (idle and walk). |
| 2026-10-26 | Placeholder Act I story and placement | Mine, to exercise every objective kind: 5 main quests (Guild summons, scorched places, Ember Hand writ, ore caravan, Vael stone) and 3 side quests from the two boards, on the existing maps (Millbrook and Greenfields; no new zone). The 5 Millbrook quests become side quests. |
| 2026-10-26 | Quick Shot: 2 s bar, hold 0.25–1.75. Aimed Shot: 4 s, a tap at the start, then a hold to the end. Aimed abilities (skillshots and ground) with a bar start at the key press and fire where the cursor points at the last input | User request and choices: skillshots and ground both aim at the end; Aimed Shot as tap 0.2–0.6 (yellow 0.35–0.45), pause, hold 1.0–3.75; several inputs average their power, crit only if all are perfect. My choices: holds end 0.25 s early (the user's rule); a press goes to the next input whose window isn't over, skipped inputs are misses; ground aims beyond range are pulled back to its edge; the client lets a hold go at the bar's end with the final aim; crits now travel with projectiles and delayed hits; input zones can't overlap (import check); the level-6 drake target became pending (the group now always wins: the bots' fight plays out differently, not a bug, checked). |
| 2026-10-26 | Timing design in `design/Ability_Tree.xlsx`: four columns (Timing Status: Manual / Generated (AI, not yet confirmed) / Not implemented; Timing Bar (s); Timing Zones; Timing Notes) and a Timing Rules tab; the sheet is now the source of truth for bars; AI drafts for the other 29 playable abilities, in the game | User request and choices (columns + rules tab; drafts for the 29 and in game; tunable values listed); "choose the best option" for the source: the sheet, since the import runs offline (no lag) and one readable place suits complex multi-input spells later. My choices: the zone syntax (`Tap a–b; Crit a–b; Hold a–b`), the import checks, the 29 drafts by tree feel, instants (dashes, interrupts, buffs, taunt, terrain) get "none", bars replace cast times and wind-ups, timing power now also scales healing and shields, a `timing_bars_enabled` test switch, one more balance target pending (caster vs Shaman). |
| 2026-10-26 | Holds: a hold zone ends 0.2–0.3 s before its bar; accuracy loses the mistiming at both ends in proportion; 95%+ = crit, 50% or less = miss, power rises steadily in between; Water Whip 3 s | User rule. My choices: accuracy = 1 − (press error + release error) ÷ zone length, so holding past the zone counts too; power 0.7 → 1 linearly from 50% to 95%; a hold still held at the bar's end is judged as let go then; Water Whip keeps its 2 s hold (0.75–2.75 s); held-past and pressed-early parts drawn red, "Let go!" past the zone; results show a hold's percentage. |
| 2026-10-26 | Timing bar options corrected: under the hero or above the action bar only; steady speed only, as "length follows the ability" or "zones slide to a fixed hit line" (sliding mode and "over the hero" removed). Fire Punch gets a 1 s bar with its zones at the end; Water Whip a 5 s bar with a new blue hold zone (last 2 s) | User correction and request (lengths are for tests, balance ignored). My choices: the hit line sits 0.4 s from the bar's left edge; a hold may start 0.2 s early and needs 90% of its zone held; it's judged on release, or when the zone ends while still held; letting go early = miss power; "Hold!" shows while holding; held part drawn lighter blue; a saved "over the hero" setting reads as under the hero. |
| 2026-10-26 | Training Dummy in the testing grounds (top-left, behind the entrance) | User request: a mannequin with huge health, no attacks, completely still. My choices: 1,000,000 HP and no defenses (the damage numbers are raw); no Mastery, XP or loot from it (no farming); it lets you out of combat once you walk 6 tiles away; it can't be knocked back; drawn as a straw mannequin; a flag on the enemy data, so more dummies can be added. |
| 2026-10-26 | Timing bar options: over the hero as a third place; sliding (same length for all) or steady speed (full length = 3 s, shorter abilities shorter, centred) | User request, to compare the two (a scrolling track may follow). My choices: over the hero sits above the name and health bar; steady speed is the second option, sliding stays the default; bars over 3 s grow up to the screen's width. |
| 2026-10-26 | Slash's bar: 1 s, green 0.3 s, crit zone 0.1 s, both centred; the crit zone is yellow (was blue); under the hero the bar is half as long and half as tall (220×15) | User request. My choices: the zones stay centred (green 0.35–0.65 s, yellow 0.45–0.55 s); "Perfect!" is yellow too; the text keeps its size. |
| 2026-10-26 | Timing bars, first step: Slash runs a 2 s bar (green 0.5 s in the middle); right-click on green = full power, on blue (its middle) = sure crit, else reduced; the bar under the hero or above the action bar (option) | User brief: rhythm in casting, rewarding good timing; long bars only for important abilities, none for instants; moving cancels; enemies changed later. My choices: miss power 70%; blue 0.1 s wide; one press per bar, which casts at once; the client measures the press and the host judges it (0.25 s grace, 0.3 s slack); GCD at the start, mana and cooldown when it goes off; enemies skip bars; 440×30 bar; the pending balance targets. See **Timing bars**. |
| 2026-10-24 | Game speed slider in a "Gameplay test" tab of the Escape menu, ×0.1 to ×2 | User request: everything fight-related scales (steps, cooldowns, wind-ups, projectiles), for heroes and enemies. Then (user request) out of combat too: the whole sim clock runs at that speed all the time (`combat_speed` renamed `game_speed`). My choices: host-only, gated like the debug console; applies to the whole session and isn't saved; the slider sends on release, the box on each change. |
| 2026-10-23 | Tooltips open faster and are smaller | User request. My numbers: every tooltip opens after 0.15 s (Godot's default 0.5 s); item tooltips and paper tooltips use text 13 (was 16 / 20), item tooltips 280 wide (was 340). |
| 2026-10-23 | Full item tooltips (abilities and consumables in numbers) everywhere items appear; the equipment slot an item would go in lights up on hover | User request. My choices: amounts are computed for your hero at that moment (stats, buffs and Mastery included); a consumable's own description is left out when its Use lines already say it; shop and loot rows got the same tooltip; dragging keeps the highlight until the drop; tooltip text 16. |
| 2026-10-23 | Inventory: slot mapping confirmed; titles back; learning text left of the boots, gold centred under the bag; full rarity borders on equipment, a rarity tint in the bag | User request. My choices: the bag tint is the border's colour at 30% over the paper; the learning text is centred in the space left of the boots, gold 18. |
| 2026-10-23 | The inventory uses the user's hand-drawn page (Layer 4) and rarity borders (Layer 5) | User request ("put this into the game"; layers 2–3 are templates, not used). My choices, to confirm: the arrow slot is the Off Hand and the band slot the first Accessory; a filled slot hides its picture under paper and shows the name in ink until there are item icons; the 28×29 borders are squeezed (nine-patch) into the smaller 26×26 bag slots; the "Equipment"/"Bag" titles are gone (the drawing has none); learning text and gold sit under the bag. |
| 2026-10-26 | Merged `V1.1.1-Optimised+UI-book` (menu book, Escape menu, timing bars, performance, Training Dummy) into `claude/godot-2d-coop-rpg-5nvase` | User request. Conflicts: both branches fixed the drake-dive lag; theirs (the pathfinder's `arrived` test) was kept. Their screen has no button row, so the volume sliders moved to a **Sound** tab in the Escape menu (the main menu keeps its Settings button). With timing bars the bots fight differently and a level-7 group always beat the 2500-HP drake, so, to keep "it beats a level-7 group of four every time": HP 2500 → 3000 (bots: level 7 wins 0 of 50, level 8 ~33%, level 10 always; at 2650 HP level 7 still won 90%, so the step is steep). The testing-grounds walkthrough fights bosses at level 60 (its hero never plays timing bars). |
| 2026-10-21 | Fixed: the game lagged after the Sunscale Drake's dive | User report. After the dive the drake chased toward the hero's own tile, where its 5-tile body can never be centred, so every tick it searched 4096 tiles × 5, failed and tried again (~300 ms per tick). It now heads for the tiles beside its target, and an enemy whose search fails waits 0.5 s before searching again. Ticks are back to 2–6 ms. The same bug was fixed in parallel on `V1.1.1-Optimised+UI-book` (an `arrived` test in the pathfinder); when merging, that version was kept (2026-10-26). |
| 2026-10-21 | Searing Dive shoves just out of the lane (1 tile from an edge lane, 2 from the centre), then stuns 1.5 s | User request. My choices: the distance ignores weight; the stun is 1.5 s and starts when the shove lands. Then, per the user, the drake must beat a level-7 group of four every time: HP 2200 → 2500 (0 of 50 level-7 wins, 0 of 50 at level 8, 10–20% at levels 9–10; bots that never dodge). |
| 2026-10-21 | Audio system + first track | User brief ("make sensible decisions, list them"). See **Audio**. My decisions are in the next rows. |
| 2026-10-21 | Sound effects found by naming convention; data entries optional | `audio/<folder>/<key>.wav`, folder from the key's first word. Adding a sound needs only the file; `SfxDef` entries tune level, variation, ducking. Numbered takes rotate. Missing files warn once per key. |
| 2026-10-21 | Key names derived from content | Ability and enemy display names give the keys (`fire_fireball_cast`, `creature_wolf_howl`), so new content gets keys and a line in `AUDIO_SPEC.md` automatically. Sword/Bow/Hammer share `weapon_`; a tree word isn't repeated. |
| 2026-10-21 | Combat music within 12 tiles; boss music when an elite fights | "A fight near the player": any fighter within 12 tiles of the local hero, or the hero. Until combat tracks exist, fights keep the current music. Explore and dungeon fall back to the town track. |
| 2026-10-21 | Bond hook: `ZoneDef.bond` + `Audio.set_zone_bond`, drained below 0.35 | Just the hook; a drained track is a `MusicTrackDef` with `drained = true`. |
| 2026-10-21 | Every button clicks; windows play open/close | `Audio` hooks every button as it enters the tree, so new UI gets clicks for free. |
| 2026-10-21 | First track: MP3 moved to `art/audio/`; OGG trimmed and faded at the loop | The upload landed at the repo root. 43 ms lead-in silence removed, 10 ms fade-in, 120 ms fade-out (it ended at full level). |
| 2026-10-21 | Layout tweaks: menus lower on the page, smaller quest text, shorter Abandon, indented abilities, centred inventory titles, smaller tree tiers, Play Solo on the left, draggable quest tracker, Browse goods hides the conversation, smaller shop writing | User requests. My choices: `BookSpread.TOP_GAP` 12 px; quest text 17 (its name stays 20), quest text box 330 px before it scrolls with Abandon (200 wide) under it; abilities indented 18 px; tree headers 14, nodes 13 with bigger gaps; the shop closes by itself when you walk away (the conversation that used to close it is hidden); the tracker's position isn't saved between sessions. |
| 2026-10-21 | Arrows at the bottom of the book turn between menus | User request. My choices: they name the menu they lead to; order Character, Inventory, Spellbook, Trees, Quests, wrapping; the loot menu isn't in the cycle (it opens on its own when loot waits). |
| 2026-10-21 | Escape menu (log, controls, keybinds, leave game); on-screen button row, message log and how-to hints removed; foldable, smaller quest tracker | User request. My choices: Esc order like WoW (aim → keybind mode → menu → open windows → target → menu), so with a target the first Esc clears it; the log keeps the last 300 messages; the loot menu keeps its "bag was full" line (information, not a how-to); the fold state isn't saved between sessions. See **Escape menu and a cleaner screen**. |
| 2026-10-21 | The book always fills the screen; the shop is a separate, draggable paper sheet open beside the book | User report (text still blurred in a 1280×720 window) and request (trading separate from inventory/character/trees, both open). Cause: at 720p the book was drawn at 2× and menus at 75%. Trade-off chosen: sharp text in any window over whole-pixel art outside 1080p. My choices: the shop opens with your inventory in the book, starts at the screen's left over the equipment page, has its own Close, and sits above the message log. |
| 2026-10-21 | Book menus: sharp text, trees left to right (tiers 1–3 left, 4–5 right), level and XP beside the name, equipment centred, how-to hints as footnotes, tighter spacing, the book can be dragged by its top edge | User requests (text looked aliased in trees, character, inventory and quest details). Cause: pages shrank slightly-too-big content by a fraction, resampling the text; menus are now laid out at the 1080p size and never shrunk at 1080p. My choices: footnotes on the right page; while an ability is learned its tree node shows AP only (Mastery in its tooltip) so two lines fit; the tree header shows only your Mastery (tier needs head each column); the book can move partly off screen but its top edge stays reachable; its place isn't saved between sessions. |
| 2026-10-21 | Each menu fills both pages of the book, one at a time; all book text bigger | User request (e.g. inventory: worn items left, bag right; text hard to read). My choices: the split for each menu (table in **Menu book**); the shop and loot menus show your bag on their right page (the shop no longer opens the inventory beside it); text 20 / titles 28 / notes 17; 64 px item slots with two-line names; the trees laid out for 1080p and scaled as a whole. Screenshot test: `SHOTS_RESOLUTION=1920x1080` (Godot keeps `--resolution` from the script), new shots of the character sheet and spellbook. |
| 2026-10-21 | Menus are written in the user's pixel-art book (Layer 1 only), ink on parchment | User request, as a first test (the art is unfinished). User choices: ink on parchment (not dark boxes on the pages); a new branch `ui-book-menus` from `optimised-build-1`. My choices: two windows at a time (older left, newer right, a third closes the oldest); trees across both pages; whole-pixel book scale; oversized windows scaled down to fit a page; a Close button; HUD bars and buttons stay on top; tracker, dialogue box and tooltips on paper so every coloured text reads as ink. See **Menu book**. |
| 2026-10-21 | Fixed: the drake froze and the game lagged in its fight. Large bodies chase to "body beside the target"; a failed chase search waits 0.5 s; chase searches stop at 1024 tiles | User report (lag 2 s into the drake fight). Cause: it pathed onto the hero's tile, which its body never reaches, so every tick ran a failed whole-map search (~170 ms). The 0.5 s wait and 1024-tile limit (`EnemyBrain.CHASE_RETRY_SECONDS`, `CHASE_SEARCH`) are mine, for every enemy. The drake is now much harder (level-7 group ~17%, target 50%); user: don't change it, it will be retuned later, so that test target is pending. |
| 2026-10-21 | Empty zones sleep after 30 s: only their clock runs | User request ("skip empty map simulation", on the `optimised-build-1` branch). My choices: the clock keeps running so timers (respawns, buffs, ground fire) run out on time and the shared clock (read from town) stays right; things due meanwhile happen on the first tick after a hero arrives; patrols and evading enemies wait where they are; the 30 s wait (`empty_zone_sleep_seconds`, tunable) lets a fight that was just left settle first. See **Performance**. |
| 2026-10-21 | Terrain cache: the ground is drawn once; each frame only actors and highlights, with the tiles in front redrawn inside a box around each | User request (lag on large maps; test on a separate branch, `optimised-build-1`). Cause measured: every tile redrawn every frame, off-screen too. Exact same picture, checked on all 42 screenshots. Placeholder (non-tileset) maps still draw in full. See **Performance**. |
| 2026-10-20 | Drake playtest fixes: 5-tile body (a plus), SW/SE swapped, harder hits, the dive sweeps 3 lanes | User requests. My choices: the body blocks movement as well as being hit; ranges are measured body to body; it can't be knocked back (Air knockbacks still ground it); the dive shoves 2 tiles to the side the unit was on; damage roughly ×1.5 on every attack; the drake stays level 6, so bots that never dodge now need level 7 (dodging players should manage at 6). |
| 2026-10-20 | Sunscale Drake (flying elite) | User brief ("make sensible decisions, list them"). See **Sunscale Drake**. My decisions are in the next rows. |
| 2026-10-20 | Drake art: both layers used; right views mirrored; frames widened to 160×128 | The brief said one layer facing left, but the file has SW and NW layers, so there are real front-left and back-left views. Each layer is shifted so its shadow's centre is the feet point, which lets mirrored rows share it. The file is at `art/`, not `art/creatures/`. |
| 2026-10-20 | Recolour via a shader baked once per sheet in an off-screen viewport | A shader on the world canvas can't be set per creature without breaking back-to-front drawing. Colours live in the art data. Flames and the shadow are kept. |
| 2026-10-20 | Flight rule | Any walkable tile at any height. Unwalkable tiles (walls, hedges, water) up to 1 level above. Never tall props (tiles that block sight). Ground zones skip airborne fliers. There are no lava tiles yet; burning ground stands in for them. |
| 2026-10-20 | Searing Dive mechanics | New `CHARGE_THROUGH` effect: hits and shoves each enemy as the drake reaches it; anyone it can't shove stops the dive. The lane is 8-way, 5 tiles, shown with the same lane function the dive uses. Trail 2 s. Range 2–5 to pick it. |
| 2026-10-20 | Grounding applies even when weight cancels the push | The drake is heavy, so a 1-tile Air Palm doesn't move it, but it still grounds it ("any Air ability with knockback"). Water Pulse and other non-Air knockbacks don't. |
| 2026-10-20 | Molten Fury lasts for the rest of the fight; +2 s on all its ground zones | 3 → 5 s for the breath's fire, and the dive trail goes 2 → 4 s. The cooldown cut doesn't speed its flying. |
| 2026-10-20 | Drake numbers tuned so a level-6 group of four wins | My first numbers (HP 2600, harder hits) beat even a level-7 group. Balance bots never dodge, which flatters any enemy with ground fire. |
| 2026-10-20 | Testing-grounds reach counts movement abilities | The drake's dive, Grizzlehide's Charge and the hound's pounce can carry them past the leash before they turn back. The map grew from 155 to 209 tiles. |
| 2026-10-20 | Enemy Testing Grounds + Salamander Hound | User brief ("make sensible decisions, list them"). See those sections. My decisions are listed in the next rows. |
| 2026-10-20 | Testing map is generated at load from the enemy data, not stored | So any enemy added later gets a pen. Pens sit in a row north of a road and are ordered by level. Elites count as bosses. Spacing = reach + aggro (or leash + pack call) + 3. The road is kept out of aggro range. Low stone walls separate pens, and a hedge with a road gap marks the arena. |
| 2026-10-20 | Millbrook gate on the north-east hedge (15–16, 0), linked as a zone edge; edges may now be 2-tile gates | The map edge (grid up = screen north-east) acts as the exit, like the Greenfields link. The zone-layout test now accepts gates of 2+ tiles (it wanted 4). |
| 2026-10-20 | Reset Shrine is an NPC you talk to | Reuses the [E] Talk prompt and dialogue. It also clears every buff on heroes in the zone and takes them out of combat. |
| 2026-10-20 | Cinder Pounce lands beside the hero, not on them; it marks a plus (the landing tile + its 4 neighbours) | With 1.5 s hero steps in combat, a mark centred on the hero could never be stepped out of in 0.6 s. Landing beside the target makes "step out of the marker" possible with one step. Range 1–3 for the landing tile, used when the hero is 2–3 tiles away (adjacent: it bites). |
| 2026-10-20 | Ember Trail only while fighting; fire damage = magical | Idle or leashing hounds leave no trail. The game has no separate fire damage type. |
| 2026-10-20 | Hound numbers | Mine: HP 190, 0.5 s steps, aggro 5, leash 12, level 2, light, Bite 5 + PhysAtk / 1.6 s, Pounce 10 + MagAtk / 8 s, embers 2 + 0.15×MagAtk per 0.5 s. |
| 2026-10-20 | Hound animations cut from its one loop; NE/NW use SE/SW | The .aseprite has only an idle loop in two directions. Run, death and back views are placeholders (see **Salamander Hound**). |
| 2026-10-19 | Wolf faster (0.65 s per tile in combat, was 0.8); its run cycle now spans 2 tiles so the paws don't slide | User report ("too slow", paws sliding). Measured: a planted paw moves about 4 art px per frame, a tile is 16 across, so 4 frames per tile (was 8). Each step plays the half of the cycle set by its start tile, so the stride carries on in any direction. 0.65 s is my "a little faster"; still slower than the Skirmisher (0.6). Balance tests pass. |
| 2026-10-19 | The river ripples (tiles 86–89 cycle at 6 fps, each tile from its own frame) | User choice. The deep-water variants that were mixed into the river are gone (they don't animate). |
| 2026-10-18 | Animated wolf art (6 steps): sprites, idle/run/bite/howl/death, hit flash, pack howl | User brief; plan approved with all recommended options. See **Creature art**. Measured: feet at y ≈ 46 (brief said 44); jaws close on bite frame 12. |
| 2026-10-18 | Bite: 30 fps, damage on frame 12, so a 0.4 s wind-up (was 0.3) | User choice (recommended). Balance tests still pass. |
| 2026-10-18 | Howl: the wolf stands still for it (0.9 s); the pack is called when it ends; a wolf hit first howls too | User choice (recommended). An exception to "no group aggro" (rule 12). Called wolves don't howl; an interrupted howl calls nobody. |
| 2026-10-18 | Wolves glide across their whole 0.8 s combat step | User choice (recommended), so the run cycle matches the ground. A wolf can't start a bite while still gliding. |
| 2026-10-18 | Implementation choices for the wolf | Mine. Art numbers live in `CreatureArtDef` (`content/creatures/wolf_art.tres`) and set the timed abilities' wind-ups at load. Wolves are drawn in the existing back-to-front order (not as separate nodes). The hit flash uses the shadowless sheet so the shadow stays dark. Debug-spawned enemies with art now stay until their corpse fades. A pack of 3 sits in Greenfields' north-west corner. |
| 2026-10-16 | First real tileset (`iso_basic`) for the ground, in 8 steps | User brief; plan approved. See **Map art**. User answers: all water (light and dark) unwalkable; stone-slab fords for the bridges; Millbrook retiled too; the purple crystal catalogued as unwalkable. The catalog table was reviewed and accepted. |
| 2026-10-16 | Tileset facts that differ from the brief | Measured: a block's side is 8 art px, not 16 (so 2× art matches the existing 64×32 grid and 16 px levels). The separate tile files are the numbering; the spritesheet has 6 empty cells and 20 cells that differ from the files, so it isn't used. Props start at tile 41. Light water 104–113 are shoreline pieces, not animation frames; only the sparkles (82–85) animate. |
| 2026-10-16 | Pixel-perfect without integer window scaling | My choice. Integer window scaling showed 1080p as a letterboxed 720p picture. Instead the camera picks zooms where art pixels are whole screen pixels, counting the window's stretch (3× at 720p, 4× at 1080p; the old fractional 4.5× view is gone), and snaps its position. The HUD scales as before. |
| 2026-10-16 | Walkability and sight come from the catalog, baked into zone rows at load | My choice of mechanism. The simulation still reads walk/sight rows only, so it stays independent of images. New per-tile sight blocking (tall props, rocks in water) stops line of sight and projectiles. Terrains may override walkability (`stone_wall`). |
| 2026-10-16 | Zone art choices | Mine. Rock pillars are cobble columns topped with grey boulders. The plateau is rocky ground with brown boulders, and its ramp is rocky dirt. The bandit camp sits on cracked earth. Millbrook: houses as slab-topped stone, the border as a bush hedge, the raised plaza as cobblestone, a fountain at (7,9). Only the pond and a few logs, stumps and rocks change where you can walk in Greenfields. |
| 2026-10-17 | Earth Wall's lift damage scales with Earth Mastery: 10 + 0.02 per point (then the usual +0.1% power per point) | User request. `AbilityEffect.lift_damage_per_mastery`. 0 Mastery: 10; 500: 30. The 0.02 is my number. |
| 2026-10-17 | Fixed: a hero who stepped away from the camera was drawn over terrain in front of it (half showing over an Earth Wall) | User report. The view sorted a standing actor by the tile it came from; it now uses its own tile once it has arrived. Mid-step (the flicker): each depth row draws every tile followed by the actors on it, ordered so the tiles in front of a walking actor come after it, so a wall beside a walking hero covers it in both directions, even with someone standing on the wall. Screenshots `13_behind_wall`, `13b_walking_away`, `13c_walking_toward`, `13d_wall_tile_occupied` in `tests/visual/shots.gd`. |
| 2026-10-17 | Steps no longer turn the hero: only the mouse sets which way a hero faces | User request. Enemies still turn toward their steps. Crossing into another zone keeps your facing too. |
| 2026-10-17 | Dragging an ability (or potion) off the action bar and dropping it outside any slot clears that slot | User request. `SlotButton` on drag end. |
| 2026-10-17 | Knockbacks and pulls deal a little damage when the unit is stopped by a wall, ledge or another unit; an enemy it is slammed into takes the same | User request. `CombatRules.collision_damage` = 8 (physical, × Mastery power, before defense) unless the ability sets `impact_damage` (Air Blast 25). My choice: the unit hit takes it too, if it is the caster's enemy (allies never). Nothing happens when weight cancels the push. |
| 2026-10-17 | Earth Wall rises under units standing in it (they ride up) and enemies take a little damage | User request. `AbilityEffect.lift_damage` (Earth Wall 10, physical, × Mastery power). Occupied tiles were skipped before. |
| 2026-10-17 | Fixed: after releasing, the enemy that killed you re-aggroed and kept you in combat | User report. Enemies react to where they saw you 0.3 s ago, so right after the release they still "saw" you at your death spot. Releasing now clears that memory. |
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
