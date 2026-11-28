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
and dialogue**, `docs/quests-and-dialogue.md` and `docs/playtest-checklist-act1.md`. **Milestone 2 of
4** (zones, region music, branch `feature/v1.3.1`, 2026-10-27): see **Act I: zones and region music**
and `docs/playtest-checklist-act1-zones.md`. **Milestone 3 of 4** (the Act I quests 1-01 to
1-06 and three side quests, party-size scaling, branch `feature/act1-m3-quests`, 2026-10-27): see
**Act I: the Floor Guild quests** and `docs/playtest-checklist-act1-quests.md`. **Milestone 4 of 4**
(the Silent Shaft dungeon, the Foreman and the Grey Heart, quest 1-07, the end of Act I, branch
`feature/act1-m4-silent-shaft`, 2026-10-27): see **Act I: the Silent Shaft** and the full Act I
checklist `docs/playtest-checklist-act1-full.md`. **Free movement** (branch
`feature/free-movement`, 2026-11-01, all 6 phases): units move freely instead of tile by tile,
attacks aim at the mouse with hitbox shapes, enemies path and telegraph; see **Free movement**,
`docs/FREE_MOVEMENT_PLAN.md` and `docs/playtest-checklist-free-movement.md`. **Ability animations and effects** (branch
`feature/ability-animations`, 2026-11-21): Rock Throw's two presses, Stone Skin's stone look, Fire
Punch instant; see that section and `docs/playtest-checklist-ability-animations.md`. **Icons** (branch `feature/icons`, 2026-11-22):
every bending ability and nearly every item; see **Icons**. **Stances and effects** (branch `feature/stance-rework`,
2026-11-23, all 5 phases): stance controls and looks, effects from the approved art, code-drawn
effects; see **Stances**, **Ability effects from the approved art**, **Code-drawn effects** and
`docs/playtest-checklist-stances-and-effects.md`. **Map editor**
(2026-11-16, branch `feature/map-editor`): paint ground, heights and props; place and edit
enemies, people, spawns, graveyards, objects, landmarks and doors; resize maps; link edges; make
new maps; change their shape (maps need not be rectangles, 2026-11-17); see **Map editor** and `docs/map-editor.md`. **Critters, the stag, the Foreman, dungeon fixes** (branch
`feature/critters-boss-fixes`, 2026-11-19): see that section. **Loot, boss rolls, binding, trading,
duels**, the Wilds and boss targets removed (branch `feature/loot-trade-duel`, 2026-11-19): see those sections. Tile steps, step
cooldowns and "adjacent" in the older sections below describe the grid version. For the numbers
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

- **Start (since 2026-11-17):** a new character picks an element on the element screen
  (see **Starting elements**): its first ability mastered (scroll in the bag), its next
  scroll in the learning slot, its shirt and pants worn. **No weapon** (since
  2026-11-20): the first weapons are a choice in main quest 1-05 (see **Element set
  rewards**); vendors still sell them. Characters made before, and ones made without the screen (tests, the command
  line), keep the old kit: Ember Fist Scroll in the learning slot (Fire Punch), Mender's
  Scroll in the bag (Healing Touch). Adventurer base stats as below.
- **Keys:** hold an aimed ability's key to aim, release to cast; T ability trees;
  ` debug console (debug builds).
- **Amounts:** (tier default + Scales With stats) × effect power × (1 + 0.1% per tree
  Mastery). Tier defaults: damage 14/24/38/55/78, healing 24/36/54/76/104. Durations
  +0.05% per Mastery point. Haste −25%.
- **AP to master by tier:** 20/30/40/50/50. AP: 10 per level-up + the enemy's kill AP, to
  the learning item only. Mastery on learn 5 (T1) / 10 (T2); per use 0.2–0.6; caps 50 / 70.
- **Unlocks:** each ability at its own Mastery Required (the sheet's column). Most trees
  still use their tier's threshold, 0 / 150 / 350 / 600 / 900 permanent Mastery; **Water**
  unlocks one ability per step (2026-11-15): Water Whip and Healing Touch 0, Water Shield
  20, Soothing Mist 40, Tidal Blessing 65, Frost Shard 90, Revive 120, Leeching Tide 150,
  Spirit Water 185, Flow State 220, Water Pulse 260, Ice Spikes 300, Water Jet 345, Healing
  Rain 390, Ice Prison 440, Rising Tide 490, Tidal Wave 545, Steam Veil 600 (and Fire 350),
  Ocean Spirit 655, Bloodbending 715, Octopus Form 775, Full Moon 835, Tidal Resurgence
  900. Tiers still set AP, rarity, prices and default amounts.
- **Learning scroll growth per level** (50% applied): Fire MagAtk 3, Mana 6, Fire Mastery 2;
  Water MagAtk 2, MagDef 2, Mana 8, Water Mastery 2; Earth PhysDef 3, HP 8, Earth
  Mastery 2 (Physical Defense instead of Magic Attack since 2026-11-20); Air MagAtk 2, Evasion 1, Mana 6, Air Mastery 2. Weapons: sword PhysAtk 10 /
  Acc 4 (growth PhysAtk 3, HP 8, Sword Mastery 2), bow PhysAtk 13 / Acc 8, hammer PhysAtk
  15 / PhysDef 5 / HP 15; +50% per tier above 1.

| ID | Ability | Item | Targeting | Effect (power × tier default) | Mana | CD |
|----|---------|------|-----------|-------------------------------|------|----|
| F01 | Fire Punch | Ember Fist Scroll | Targeted, adjacent, **instant** (no bar since 2026-11-21; damage as the key is pressed) | 1.0 magical | 4 | 2 |
| F02 | Fire Kick | Cinder Kick Scroll | Targeted, adjacent; fire_kick + a flame arc (2026-11-21) | 0.8 + burn 0.6 over 3 s | 8 | 4 |
| F03 | Fire Dart | Spark Scroll | Skillshot, any angle, 4, 16 t/s | 1.0 | 10 | 2 |
| F04 | Sun Warrior's Breath | Sun Warrior's Breath Scroll | Self | next 3 Fire casts +30% (20 s), +10% max Mana over 10 s, off GCD | 10 | 20 |
| F05 | Flame Dash | Scroll of Burning Feet | Ground 8-way, 3 | dash 3, trail burns 3 s (0.4/s); charges 1 +1/300 | 10 | 8 |
| F06 | Fire Whip | Lash of Embers Scroll | Skillshot 8-way line 3, pierce | 1.1 | 10 | 6 |
| F07 | Fireball | Scroll of the Fireball | Ground 5, 3×3, 0.4 s telegraph | 1.2 | 15 | 8 |
| F08 | Burning Ground | Scorched Earth Scroll | Ground 4, 3×3 zone 6 s | 0.35 per s | 15 | 14 |
| F09 | Blazing Combo | Blazing Fist Scroll | Targeted, adjacent | 3 × 0.5, knockback 1 | 12 | 10 |
| W01 | Healing Touch | Mender's Scroll | Targeted ally, 2; water_heal (2026-11-21) | heal 1.0 | 8 | 3 |
| W02 | Water Whip | River Lash Scroll | Targeted, 3, **3 s timing bar** (hold 0.45–2.75 s since 2026-11-21; was 0.75); the Water stance 1 rope is thrown at the release and the hit lands 0.5 s later (since 2026-11-26); 4 water points | 1.0 | 6 | 2 |
| W03 | Flow State | Scroll of the Current | Targeted ally, 3 | Haste 30 s | 10 | 20 |
| W04 | Frost Shard | Frost Shard Scroll | Skillshot, 4, 12 t/s | 0.9 + slow ×1.5 2 s | 8 | 4 |
| W05 | Soothing Mist | Mist Scroll | Targeted ally, 4 | heal 1.5 over 12 s | 12 | 8 |
| W06 | Water Pulse | Wave Scroll | Skillshot 8-way line 3, pierce | 0.9 + push 1 along the wave | 12 | 8 |
| W07 | Leeching Tide | Leech Tide Scroll | Targeted, 3 | 1.0, heals you 50% | 12 | 10 |
| W08 | Tidal Blessing | Tidal Scroll | Targeted ally, 3 | +20 PhysDef/MagDef 45 s | 12 | 25 |
| W09 | Ice Spikes | Glacier Scroll | Ground 4, 3×3, 0.4 s telegraph | 1.0 + slow ×1.5 3 s | 15 | 10 |
| W12 | Water Shield | (sheet) | Targeted ally, 5; yourself with no ally targeted (2026-11-25) | shield 20 s (tier default + sheet stats); used up: splashes enemies within 1.5 tiles for 10 + 0.6×MagAtk (`BuffDef.break_ability`) | 10 | 20 |
| A01 | Air Palm | Open Palm Scroll | Targeted, adjacent; air_palm + a wind spiral (2026-11-21) | 0.6 + knockback 1 | 6 | 4 |
| A02 | Gust | Breeze Scroll | Targeted, 3; air_gust + a wind spiral (2026-11-21) | 0.5 + interrupt, off GCD | 8 | 10 |
| A03 | Air Step | Featherstep Scroll | Self | +40% speed for 4 s (free movement), off GCD | 8 | 10 |
| A05 | Air Blast | Gale Scroll | Targeted, 3 | 0.6 + knockback 3, +25 on impact | 12 | 10 |
| E01 | Rock Throw | Pebble Scroll | **Two presses** (2026-11-21): a 3 s bar while the rock waits (rooted), the second press throws it (lob 0.3 s to the cursor, range 6); no press: it throws itself at the bar's end | 1.0 physical, **threat ×3** | 6 | 3 |
| E02 | Stone Skin | Granite Skin Scroll | Self | +20 PhysDef 10 s | 8 | sheet |
| E03 | Raise Pillar | Pillar Scroll | Ground 3 | +1 level 15 s (+1 from 500 Earth) | 8 | 6 |
| E04 | Seismic Stomp | Stomp Scroll | Self, 3×3 (stance 1 entry cast) | taunt, forced 4 s, + 0.7 physical | 8 | 10 |
| E05 | Earth Wall | Bulwark Scroll | Ground 4 | 3-tile wall +2 (climbable with Jump 2), 12 s (+1 tile / 300 Earth); lifts units on it, enemies take 10 + 0.02 per Earth Mastery | 15 | 15 |
| E07 | Boulder Shield | (sheet) | Self | shield (heal default + PhysDef) 12 s | 12 | sheet |
| E08 | Rumbling Taunt | (sheet) | Self, within 2 | taunt, forced 5 s | 12 | 15 |
| E14 | Earth Armor | (sheet) | Self | +50 PhysDef, steps ×2 (half speed), 15 s (the recast to Fortress isn't built) | 15 | sheet |
| E15 | Metalbending | (sheet) | Targeted, 4 | −20 PhysDef and speed halved, 8 s (since the stance rework: no pull, no taunt) | 15 | sheet |
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

## Starting elements, faster enemies, rebalance (branch `feature/element-start`, 2026-11-17)

User brief, seven parts (part 2, element quest rewards, waits for the user's OK on its
table). Numbers as built:
- **Starting elements** (`StartingElementDef`, `content/elements/`, written by
  `tools/once/make_element_start.py`; `ElementScreen`, `ui/element_screen.gd`, opened by
  the main menu's Create; `CharacterData.apply_element`):

  | Element | Mastered (scroll kept) | Learning | Key stats | Shirt / pants (Common) |
  |---------|------------------------|----------|-----------|------------------------|
  | Earth | Rock Throw (Pebble Scroll) | Stone Skin (Granite Skin Scroll) | Phys Atk, Phys Def | Quarryman's Shirt / Trousers |
  | Water | Healing Touch (Mender's Scroll) | Water Whip (River Lash Scroll) | Magic Atk, Phys Def | Riverweave Shirt / Breeches |
  | Fire | Fire Punch (Ember Fist Scroll) | Fire Kick (Cinder Kick Scroll) | Magic Atk, Magic Def | Emberstitch Shirt / Trousers |
  | Air | Air Palm (Open Palm Scroll) | Gust (Breeze Scroll) | Phys Atk, Magic Def | Breezecloth Shirt / Leggings |

  Shirt: attack stat +2, defense stat +2 (growth 1 / 0.5); pants: +1 / +2 (growth
  0.5 / 1). `Hero.element` is saved (`"element"`) and sent in every snapshot; an unknown
  or missing element reads as none. Stone Skin (E02) is built as on the
  `feature/threat-tanking` branch (+20 Physical Defense, 10 s). `ItemDef.element` marks
  gear made for an element.
- **The Foreman's Hurled Sunstone** (`foreman_hurl`, first in his list): a 1.5 s cast bar,
  range 6, 18 + 0.9 x Physical Attack, cooldown 12 s, at whoever holds his eye.
  `AbilityDef.locks_on`: never rolls Accuracy against Evasion, and once it starts the
  target can't escape it (range and line of sight aren't checked again); a stun or an
  interrupt (Gust) still stops it. (Boss win-rate targets were removed 2026-11-19: bosses
  are tuned by playtesting.)
- **Faster enemy attacks:** wind-ups cut up to 40%, never below the warning a dodgeable
  attack needs (0.63 s: a tile at walking speed plus 0.3 s; `CastResolver.dodge_warnings`)
  nor 0.2 s for quick bites. Art frame rates raised so bites land on their hit frame
  (wolf and iron wolf bite 30 -> 50 fps, hound bite 20 -> 30, drake rake 10 -> 16.7).

  | Ability | Before | After |
  |---------|--------|-------|
  | Wolf / Iron Wolf Bite | 0.4 | 0.24 |
  | Hound Bite | 0.3 | 0.2 |
  | Quick Slash (Skirmisher) | 0.3 | 0.2 |
  | Boar Gore | 0.4 | 0.24 |
  | Talon Rake (drake) | 0.5 | 0.3 |
  | Crushing Blow (Brute) | 0.8 | 0.64 |
  | Cleave (Grizzlehide), Hollow Rake (Husk), Overseer's Crush, Pick-Hammer (Foreman) | 0.7 | 0.64 |
  | Charge (Grizzlehide), Tusk Charge (Boar) | 1.0 | 0.64 |

  Kept: Foreman's Ground Slam (1.0 s telegraph) and Mine-Cart Charge (1.1 s), the drake's
  Sunfire Breath (0.8 s) and Searing Dive (1.0 s), Cinder Pounce (0.67 s, already at the
  floor), Shadow Bolt (a projectile, 0.71 s of flight), the wolf's howl (not an attack).
- **Hero art:** eight facings: the straight screen directions drawn 2026-11-17 are rows
  5-8 (s, e, n, w) of every sheet (`tools/once/make_hero_sheets.py`);
  `CreatureArtDef.direction_for_angle` picks one of eight 45° slices of the facing angle.
- **Hero walk:** the cycle follows the distance walked on screen
  (`MoveState.screen_odometer`, art pixels) at a pace per facing
  (`CreatureArtDef.run_px_per_frame`: 2.24 px per frame on the diagonals, 2.0 across,
  1.2 up and down), measured from the planted foot; north and south can't be measured
  (the soles barely part on screen) and use the iso-foreshortened stride. Slows, haste
  and Earth Armor change it by themselves; it stops with the hero. GIF:
  `tests/visual/hero_walk_shots.tscn` + `tools/once/make_walk_gif.py`.
- **Ability rebalance** (`tools/once/ability_rebalance.py` on the sheet; the built
  abilities' behavior files too):
  - every ranged ability +2 tiles: Hitbox Range and the range in its Effect / Targeting
    Details text (Targeted beyond adjacent, Projectile, Lob, Circle, Line, ground Tiles;
    not dashes, leaps, blinks, cones or adjacent attacks). Built ones: Healing Touch 4,
    Water Whip / Flow State / Leeching Tide / Tidal Blessing / Water Pulse / Gust / Air
    Blast / Fire Whip / Raise Pillar 5, Frost Shard / Soothing Mist / Ice Spikes / Fire
    Dart / Burning Ground / Rock Throw / Earth Wall 6, Fireball / Quick Shot 7, Aimed
    Shot 9.
  - Water's heals (Healing Touch, Soothing Mist, Spirit Water, Healing Rain): 0.45 Magic
    Atk + 0.55 Phys Def.
  - Air: Phys Atk instead of Magic Atk; control and defense (Gust, Wind Snare, Stolen
    Breath, Air Sphere, Suffocate, Storm Front, Pressure Lock): 0.6 Phys Atk + 0.4 Magic Def.
  - Scales With takes a coefficient before a stat ("0.45 Magic Atk"; without one,
    `CombatRules.sheet_stat_coefficient`).

## Element set rewards (branch `feature/element-rewards`, 2026-11-20)

User request: the Act I main quests build each hero's set for their element; heroes
start without a weapon (the first ones from quest 1-05); Earth scrolls grow Physical
Defense instead of Magic Attack. Written by `tools/once/make_element_set.py`.
- **Per element** (`QuestDef.element_reward_ids` given, `element_choice_ids` joining the
  choice of one, by `Hero.element`; `QuestDef.items_for` / `choices_for`). A hero with
  no element chooses among every element's items instead (they join the choice).

  | Quest | Given | Choice of one |
  |-------|-------|---------------|
  | 1-01 | Hands piece (+ 2 health potions) | — |
  | 1-02 | Head piece | Minor Mana Potion or Minor Health Potion |
  | 1-03 | Feet piece (+ 2 health potions) | — |
  | 1-04 | 2 health potions | the ring or the element's next scroll |
  | 1-05 | potions | the charm, Rusty Shortsword, Hunter's Shortbow or Iron Mallet |
  | 1-06 | the scroll after that | — |
  | 1-07 | potions | Fireball, Glacier or Bulwark scroll (unchanged) |

- **Next scrolls** (1-04, then 1-06): Earth Pillar (Raise Pillar), Stomp (Seismic Stomp);
  Water Mist (Soothing Mist, 40 Water Mastery), Tidal (Tidal Blessing, 65); Fire Spark
  (Fire Dart), Sun Warrior's Breath; Air Featherstep (Air Step), Gale (Air Blast, tier 2,
  150 Air Mastery: Wind Snare isn't in the game).
- **The pieces** (all Common, `ItemDef.element` set). A = the element's attack stat, D its
  defense (Earth Phys Atk + Phys Def, Water Magic Atk + Phys Def, Fire Magic Atk + Magic
  Def, Air Phys Atk + Magic Def); growth per level (half applied, as for all gear):

  | Piece | Stats | Growth |
  |-------|-------|--------|
  | Hands | A +2, D +1, extra 1 | A 1, D 0.5 |
  | Head | A +1, D +3, extra 2 | A 0.5, D 1 |
  | Feet | A +2, D +2, Speed +3 | A 0.5, D 1 |
  | Ring | A +3, D +2, extra 1 | A 1, D 0.5 |
  | Charm | A +3, D +3, extra 2 | A 1, D 1 |

  Extras: Earth HP +10 / Accuracy +2; Water Mana +10 / HP +10; Fire Mana +10 / Crit Rate
  +1; Air Evasion +2 / Speed +3. Names: Earth Quarryman's Gloves, Hood, Boots, Granite
  Ring, Bedrock Charm; Water Riverweave Gloves, Hood, Sandals, Tidestone Ring, Pearl
  Pendant; Fire Emberstitch Gloves, Cap, Boots, Cinder Ring, Ashglass Pendant; Air
  Breezecloth Wraps, Hood, Shoes, Gale Ring, Feather Charm.
- Tests: `tests/unit/test_element_rewards.gd`.

## Critters, the stag, the Foreman, dungeon fixes (branch `feature/critters-boss-fixes`, 2026-11-19)

User brief, five parts. Built on `feature/element-start`.
- **Critters pack art** (`art/critters.zip`, in the repo since the first tileset import;
  `tools/once/make_critter_sheets.py`): the strips the game uses are copied to
  `assets/creatures/boar/strips/` and `assets/creatures/stag/strips/`, then laid out as
  one sheet per animation with a row per facing (SW, SE, NW, NE, like the wolf; the pack
  draws all four, nothing mirrored), plus `no_shadow/` for the hit flash. Frame sizes,
  read from the PNGs, all divide evenly: boar idle 7 x 41x30 (NW 40x30), run 4 x 41x30
  (NE/NW 30 high, SE/SW 25 high); stag idle 24, walk 11, run 10, all 32x41. Cells: boar
  41x30, bottom-aligned so the feet (frame height - 2) sit at (20.5, 28) in every row;
  stag 32x41, feet (16, 39).
  - **Boar** (`content/creatures/boar_art.tres`): idle 7 fps, run 12 fps (both loop).
    Behaviour, stats, loot and spawns unchanged.
  - Walks listed in `fps` ("run", "walk") play by time at that rate
    (`CreatureArtDef.run_frame`); art with a walk walks out of a fight and runs in one.
  - **Fallbacks for missing art** (`CreatureArtDef` "Missing animations"; used only
    while the sheet is missing, so real sheets drop in by adding them): no attack
    sheet: the wind-up holds the last run frame, then a 6 art px lunge toward its facing
    on the hit (0.2 s); no death sheet: idle's first frame tips over (0.35 s), lies 4 s,
    fades 1 s. Hits use the usual white flash.
  - Screenshots: `tests/visual/critter_shots.tscn`.
- **Stag** (`content/enemies/stag.tres`, neutral): level 3, HP 260, PhysAtk 13, PhysDef 8,
  MagDef 6, Evasion 6, 3.3 tiles/s, aggro 0, leash 18, 70 XP, 2 AP, respawn 60 s; Antler
  Thrust (`stag_antler_thrust`: 80° cone, 1.3 tiles, 8 + 1.0 x PhysAtk, 2.5 s, 0.3 s
  wind-up); loot 1-4 g, Stag Hide 60% (8 g), Stag Antler 35% (10 g).
  - `EnemyDef.neutral`: never aggros on a hero coming close (even touching it), isn't
    called by pack howls, and Tab skips it unless it is fighting
    (`PlayerInput._peaceful`). Damage puts it in combat (only the one hit), it fights
    through the usual threat table, and resets as any enemy does (its attacker dies or
    drags it past its leash: it walks home, heals to full, neutral again).
  - `EnemyDef.wander_radius` (4) and `graze_seconds_min/max` (4-10 s): idle without a
    patrol it grazes (idle animation) a random while, then walks (40% speed, walk
    animation) to a random reachable tile within 4 of its spawn; each one rolls its own
    times (the zone's seeded random numbers).
  - **Windsteppe:** four stags at (23, 25), (24, 28) by Tsaga's Camp and (42, 30),
    (44, 33) by the south camp, in place of the two "Herd" groups (7 animal shapes).
  - Tests: `tests/unit/test_stag.gd`.
- **The Foreman** (as built on top of `feature/element-start`): damage x2 on every attack
  (base and Physical Attack coefficient: Hurled Sunstone 36 + 1.8, Ground Slam 24 + 1.2,
  Mine-Cart Charge 16 + 1.2, Pick-Hammer 28 + 1.5), 2.52 tiles/s (2.1), attack areas
  +25%: slam circle 1.875 (1.5), pick cone 1.875 (1.5), charge lane 1.5 wide (1.2). The
  telegraphs are drawn from those shapes. The Hurled Sunstone is a single-target throw
  (no area), so its range stays 6.
- **Targeted casts face their target** (user report: Healing Touch faced the cursor):
  in combat a hero faced the mouse every tick, and the client sends the cursor point
  with every cast. Now a cast turns the caster toward a targeted ability's target (exact
  angle, `CastResolver.face_cast`) when it begins and as it goes off, and the hero keeps
  that facing while casting and 0.5 s after (`Hero.holds_cast_facing`, also in the
  client's prediction); mouse-aimed abilities still follow the cursor. Test:
  `tests/unit/test_cast_facing.gd`.
- **Leash x1.8** for every enemy, written in each enemy file (`EnemyDef.leash_radius`,
  default 18): Wolf, Bandit Brute, Fen Skirmisher, Goblin Shaman, Human Husk, Stag 18;
  Boar 16; Iron Wolf, Grizzlehide, Salamander Hound 22; Grey Husk, Sunscale Drake 25;
  Grey Overseer 14; Foreman 29. Not the Training Dummy (6: how far you walk to drop its
  fight) or the Grey Heart (it never moves). The testing grounds grew to fit.
- **Dungeons:**
  - Enemies in a dungeon copy don't respawn while any hero is inside: the timer starts
    over each tick, and runs as usual once the last hero has left (`EnemyBrain`, DEAD).
  - **Way out** (`ZoneDef.cleared_exit`): once every enemy in the copy is dead (summoned
    adds aside), an exit opens (`WorldSim.way_out_open`, a `way_out` event, sent in
    snapshots): a pulsing golden ring of light with "Way out" over it, a message ("A way
    out glows open in the Foreman's chamber") and the key `world_way_out`. Stepping on it
    works for every hero, like any exit. Silent Shaft: (52, 17) in the Foreman's chamber
    to Deepcut (34, 12), just outside the mine entrance.
  - Tests in `tests/unit/test_dungeons.gd`.
## Threat and tanking (branch `feature/threat-tanking`, 2026-11-17)

User brief: WoW-style tanking. Tests: `tests/unit/test_threat_table.gd`,
`test_threat_tanking.gd`, `test_earth_tanking.gd`, taunt cases in `test_ability_resolver.gd`.
- **Overtake** (`ThreatTable.update`, called each tick by `EnemyBrain.pick_target`): an
  enemy keeps its target until someone passes 110% of the target's threat within melee
  range (`melee_overtake_percent`, gap ≤ `melee_overtake_range` 1 tile, edge to edge) or
  130% farther away (`ranged_overtake_percent`). With no target yet, or when it leaves
  the table: the highest threat; ties go to whoever was added first. `top()` is gone
  (`target()`).
- **Forced taunt:** `AbilityEffect.taunt_seconds` (default 3): top threat +10% and the
  enemy stays on the taunter for that long whatever the threat; ends early if the taunter
  dies or leaves the table; a second taunt by the same hero extends it.
  `taunt_requires_buffs`: the taunt only lands while the caster has one of those buffs.
- **Physical Defense raises heroes' threat** (`AbilityResolver.defense_threat_multiplier`):
  × (1 + current PhysDef / `threat_def_divisor` 40), at most `max_def_threat_multiplier`
  3.0; heroes only, buffs count, on damage and healing threat; an effect's
  `threat_multiplier` stacks on top. Base 10 PhysDef → ×1.25; a geared tank (~60) → ×2.5;
  with Stone Skin or Earth Armor up → the cap.
- **Earth** (behaviors in `content/tree/behaviors/`, buffs `stone_skin`, `earth_armor`,
  `boulder_shield`, `metalbent`; sheet patched by `tools/once/earth_tanking.py`): see the
  E rows of the table above. Other Earth abilities make normal threat.
- **Since the stance rework (merged 2026-11-25):** the stance sheet's Effect, Cooldown and
  keys win (the newer design): Seismic Stomp (stance 1 entry cast) cooldown 10 s, Rumbling
  Taunt 15 s, Boulder Shield 18 s, Earth Armor 40 s; **Metalbending** lowers Physical
  Defense by 20 and halves its target's speed for 8 s, without the pull (moved to Metal
  Cable) or the taunt. Earth Armor's recast (Fortress: 40% less damage, rooted, 6 s) isn't
  built. Stone Skin turns a quarter of the body to stone. Sheet: `tools/once/earth_tanking_stances.py`.

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

## Hero art (PL-01-1, 4 facings and weapon sets, 2026-11-16)

The hero sprite: the user's PixelLab character PL-01-1 (no bracelets), its animations
in all four facings, and the sword and bow attacks of PL-02-1 (sword) and PL-02-2 (bow),
characters drawn as edits of PL-01-1, all approved on the `art-drafts` branch (never
merged; files copied). Checklist: `docs/playtest-checklist-hero-art.md`.
- **Source:** `art/heroes/PL-01/` and `art/heroes/PL-02/` (the frames, 9 per animation,
  48×48, plus the standing stills and `PL-01-1.png`). `tools/once/make_hero_sheets.py`
  copies them from `origin/art-drafts` and cuts `assets/heroes/pl01/<anim>.png`, rows SW,
  SE, NW, NE: idle, run (the walk), cast, hit (getting-hit), death (south-east: take 1),
  downed, revived, sword_slash, sword_lunge, bow_quick_shot, bow_aimed_shot. Art data:
  `content/heroes/pl01_art.tres` (`CreatureArtDef`), linked from `HeroDef.art`
  (`adventurer.tres`). A hero without art is still a circle.
- **Measured on the art:**
  - **Feet:** midway between the two soles on the first idle frame: x 22.25–25 and
    y 37.5–39 across the facings, so each facing's row is shifted by whole pixels onto
    one point, (24, 38): the hero doesn't jump when turning. The PL-02 bodies are lined up
    by overlaying their standing stills on PL-01-1's (81–94% overlap after 0–2 px; their
    scabbard and bow hang below the feet and fool a sole test).
  - **Walk:** the widest step is 8–10.5 art px across (a tile along a grid axis is 16),
    so a 9-frame cycle (two steps) covers 1.19 tiles: 8 frames per tile
    (`run_frames_per_tile`), from the distance walked.
- **Animations** (`CreatureAnimator.pick_hero`, in order): dead → death once (12 fps),
  then lying in downed's last frame until released or revived (death and downed both
  start standing and end lying; downed again would get up and fall twice); stunned →
  downed (15 fps), held until the stun ends; up again (stun over, resurrected, released
  at a graveyard) → revived (12 fps); an ability went off → its own animation
  (`CreatureArtDef.ability_anims`: Slash → sword_slash 20 fps, Lunge → sword_lunge 18,
  Quick Shot → bow_quick_shot 20, Aimed Shot → bow_aimed_shot 15, each only while that
  weapon type is in hand), else cast (18 fps: element spells, hammer arts, potions);
  took damage → hit (18 fps); moving → run; else idle (6 fps).
- **Network:** the host records on each hero (`Hero.anim`, sim clock) when it died, was
  stunned, got up, was hit, and which ability last went off (deaths, stuns and getting
  up from the state each tick, `WorldSim._track_hero_anims`; hits and abilities from the
  events). Snapshots carry them, so every player picks the same frame from the same host
  times, as creatures do.
- **Pixel-perfect:** drawn by the creature drawing at `PixelCamera.ART_SCALE` (2× world
  units per art pixel) with whole-pixel feet, under the whole-pixel camera.
- **Known flaws in the drafts** (used anyway): walk facing north-east has stray white streaks
  in its last frames. (Getting-hit facing west and north-west fell to the ground; since
  2026-11-19 those facings show east and north-east mirrored: `CreatureArtDef.mirror_rows`,
  flipped about the feet when drawn, same frames and timing.)
- Tests: `tests/unit/test_hero_animator.gd`, `test_hero_animation_times_are_the_hosts`
  (`test_snapshot.gd`). Screenshots: `tests/visual/hero_art_shots.tscn` (four heroes, one
  per facing, every animation).

## Ability animations and effects (branch `feature/ability-animations`, 2026-11-21)

User brief: the element abilities' own hero animations, their effects, and the
ability changes that go with them. Checklist: `docs/playtest-checklist-ability-animations.md`.
- **Hero sheets** (`tools/once/make_hero_sheets.py`, NEW_ANIMS; all eight facings, the
  frames kept in `art/heroes/PL-01/`): earth_root, earth_hold, earth_punch, fire_punch,
  fire_kick, water_heal, water_whip, air_palm, air_gust (PL-01-1) and stone_shatter
  (PL-01-3, the stone-armoured body). Each set's feet measured on its own first frame
  (the same standing pose: every set gets idle's shifts) and shifted onto (24, 38).
  stone_shatter stands on a dirt mound: everything under its soles (its top row + 31,
  PL-01-1's height) is cut, then the mound's own colours and scraps beside the feet;
  its feet are midway across its legs. Thin dark scraps remain on the soles' row in a
  few facings. Not used: `stone-skin-in-a-wide-rooted-stance-grey-` (no stone appears).
  Frame rates (`pl01_art.tres`): fire_punch 24, fire_kick / water_whip / air_palm /
  earth_punch 20, air_gust 18, earth_root 15, water_heal 14, stone_shatter 12,
  earth_hold 8 (loops).
- **Phases** (`CreatureArtDef.ability_anims` entries can be Dictionaries: "anim",
  "weapon", "strike", "windup", "loop", "from_start"; `CreatureAnimator.pick_hero`):
  when the ability goes off its animation plays from its **strike frame** (the hit
  lands as it shows): Fire Punch 5, Fire Kick 6, Healing Touch 6, Water Whip 8, Air Palm
  5, Gust 4 (1-based). While its timing bar runs: the frames before the strike, holding
  the last; Rock Throw: earth_root once, then earth_hold looping. Stone Skin plays
  earth_root when cast.
- **Release delay** (`AbilityDef.release_delay_from` / `release_delay_seconds`, set at
  load): a bar's last input releases the ability (a `release` event: its animation and
  effect start for every player) and it goes off a moment later without range being
  checked again: Rock Throw on earth_punch's strike (frame 4 at 20 fps, 0.15 s; it plays
  from frame 1, `from_start`), Water Whip on the lash's snap (frame 8 at 24 fps, 0.29 s).
  Mana and the cooldown are paid when it goes off.
- **Rock Throw (E01):** first press: a 3 s bar; the rock (`assets/effects/rock.png`,
  `AbilityDef.fx_carried`) rises beside the hero while earth_root plays, then bobs;
  Cast Move Speed 0 (the hero can't walk). Second press (its key again, right-click or Space, as every
  bar): earth_punch, and on its strike frame the rock flies along a parabola (peak 1.6
  levels, two turns of spin) to the cursor, clamped to range 6, then `rock_impact` and
  the damage in a 0.5-tile circle. No press: the client presses for the player at the
  bar's end with the cursor's aim (`AbilityDef.bar_goes_off_at_end`; past every window:
  miss power). The cooldown starts on the throw. The flight is the still rock moved and
  spun in code: FX-10-2 (the "flying rock") mostly slides across its frame without
  tumbling. Every player sees the rise and hold (the cast state) and the arc (the lob's
  pending hit carries `from` and `start`).
- **Stone Skin (E02):** earth_root on cast; while it lasts the hero is tinted grey stone
  (`BuffDef.look` = &"stone": `CreatureArtDef.looks.stone`, the sheets baked once
  through `creature_recolor.gdshader`, `CreatureRecolor.sheets(art, root, look)`); when it
  ends, stone_shatter (`BuffDef.end_anim`; the host notes when, `Hero.anim.buff_end`, in
  snapshots), then the hero without the tint.
- **Effects** (`FxDef`, `content/effects/`; sheets `assets/effects/` from
  `tools/once/make_effect_sheets.py`): water_lash (FX-09-1, 64×64, 24 fps, hit frame 8),
  fire_arc (FX-10-4, 64×64, 24 fps), air_palm_spiral and air_gust_spiral (FX-08-5, 64×64,
  60% opacity), rock_impact (FX-10-1, 32×32), rock (the approved still, 32×32, 20×18
  drawn). `AbilityDef.fx_cast` (from the caster toward its target, rotated, kept upright
  pointing left), `fx_land` (where a lob lands). The host sends `fx` events with host
  times; `FxPainter` turns them, held rocks and thrown rocks into items `WorldView`
  draws on the tile under them in its back-to-front pass (after the actors there; the
  cached-terrain pass covers them like actors). Healing Touch has no effect art yet.
- Tests: `tests/unit/test_ability_animations.gd` (two-press throw, the throw at the bar's
  end, Fire Punch instant, Water Whip's window and hit on the snap, effects), new cases
  in `test_hero_animator.gd`. Screenshots: `ha12`–`ha23` in
  `tests/visual/hero_art_shots.tscn`, `tests/visual/fx_shots.tscn`.

## Map editor (2026-11-16)

User requests: edit maps by hand with the mouse (part 1: ground, heights, props), then
everything on them, their size and how they connect (part 2). How-to:
`docs/map-editor.md`; checklist `docs/playtest-checklist-map-editor.md`.
- **Where:** its own screen, from the main menu's **Map Editor** button (or `--map_editor`),
  only when the game runs from the Godot editor (`MapEditor.can_save()`: an export can't
  write its own files). Any tiled map stored in a file (not the generated testing grounds).
- **Tools (1–7):** Ground, Height (raise / lower once per tile per drag, or an exact level
  0–9), Props, Pick, **Things** (place enemies, people, hero spawns, graveyards, objects,
  landmarks, doors), **Select** (select, cycle a tile's things, drag to move, Delete;
  settings: enemy type / level / respawn / patrol, a person's facing, an object's kind and
  label, a landmark's name, a door's destination and arrival tile picked on that map).
  Brush 1/3/5, undo / redo (200 steps), grid and height numbers; markers for spawns,
  doors, linked edge tiles, the selection and patrol routes (`EditorOverlay`).
- **Shape (tool 7, 2026-11-17, branch `feature/map-shapes`):** maps need not be
  rectangles. Right-drag removes tiles (no block left at all); left-drag adds tiles of
  the chosen ground at the chosen level into holes or past the map's sides, which grows
  it (`ZoneEdit.grow_to_include`, `GROW_MARGIN` 3 spare rows); saving trims rows and
  columns with no tile (`ZoneEdit.trim`); both shift coordinates like a resize. A faint
  grid shows where tiles can go. Holes can't be painted or hold things; the check names
  things left on one; at least one tile stays.
  - **Storage:** `ZoneDef.NO_TILE` (a space) in `height_rows` and `terrain_rows`, `#` in
    walk rows, `.` in prop and sight rows; `ZoneDef.has_tile`, `GridModel.has_tile` /
    `remove_tile`.
  - **In play** (user choice): a hole is a wall, like the map's outside: nobody walks or
    flies into it (`Mover.blocks`, `GridModel.can_fly`, the pathfinder), enemies path
    round it; it is height 0 and open to sight, so spells and arrows fly over it. Ground
    areas, shape footprints, terrain changes and Earth Wall leave holes out. Drawn as
    nothing; the tiles behind show their sides, like the map's edge. A map edge's gate is
    the tiles that exist along that side of the rectangle.
  - Tests: `tests/unit/test_map_shapes.gd`, `test_map_shape_edit.gd`, Shape cases in
    `tests/integration/test_map_editor.gd`; screenshots `tests/visual/map_shape_shots.tscn`
    and `editor_8_shape` in `map_editor_shots.tscn`.
- **People stand once in the game:** placing someone already on the map moves them;
  someone from another map is removed from it when saving.
- **Map size:** rows / columns added or removed per side (named by screen corner:
  north-east = grid up …). Things keep their place on the ground; cut-off things are listed
  first. A shift of the map's coordinates (north-west / north-east side) is tracked
  (`ZoneEdit.shift`) and applied on save to quest places in the map (reach, escort,
  investigate), other maps' doors into it, its edges' offsets and the encounter's
  victory tile.
- **Connections:** per side, the map it leads to and the offset, with where its open
  tiles land; the other map's matching edge (opposite side and offset) is written on save
  (`ZoneSaver._sync_edges`), so both always agree. Doors are things.
- **New map:** name, size, ground, height, region, music; a hero spawn and a graveyard;
  file `content/zones/<id>.tres`; `AUDIO_SPEC.md` regenerated (`AudioSpecWriter.write`).
- **How it shows:** the game's own `WorldView` draws an `EditorSession`: one zone,
  never ticked (enemies and people frozen where they spawn), no hero; the editor moves
  the camera; whole-map changes rebuild the session and view. `WorldView.refresh_tiles`
  redraws the cached ground around painted tiles.
- **Model** (`ZoneEdit`): works on a copy loaded fresh from the file; tile strokes are
  undone tile by tile, whole-map steps by snapshots; walkability and sight re-baked
  (`ZoneDef.bake_tile`); legend letters added for new terrains and props.
- **Saving** (`ZoneSaver`): Godot's `ResourceSaver` writes the map and every file the change
  reaches (partner edges, doors into it, quests and the encounter after a shift, people
  moved away); then ContentDB's copies are refreshed so Play uses them at once. Every map
  was re-saved once through it (`tools/once/resave_zones.tscn`). First `ZoneCheck` lists,
  and the editor asks about: unreachable places, doors onto blocked or missing ground,
  one-way doors, edges landing on blocked tiles, quests losing a person or every enemy of
  a kind they need.

## Salamander Hound (2026-10-20)

A fast Ashkaran fire hound (`content/enemies/salamander_hound.tres`), level 2, MELEE.
- **Stats:** HP 190, PhysAtk 13, MagAtk 14, PhysDef 5, MagDef 12, Evasion 8, Jump 2;
  aggro 5, leash 12; 0.5 s per tile in combat (the fastest enemy), 0.25 s reaction;
  light; 70 XP, 3 AP; 3–8 g, Scroll of Burning Feet 4%, Scorched Earth Scroll 4%.
- **Bite** (`hound_bite`): a 70° cone, 1.2 tiles, 5 + 1.0×PhysAtk physical, 2.0 s
  (1.6 s before free movement), 0.3 s wind-up (from the art).
- **Cinder Pounce** (`cinder_pounce`): 8 s. Since free movement it leaps onto the point
  beside a hero 1–3 tiles away, on the hound's side (`AbilityDef.aim_beside_target`),
  marking a circle of 1.2 tiles there for its 0.67 s wind-up (frame 6 at 9 fps), then
  deals 10 + 1.0×MagAtk magical (fire) damage to whoever is still in it. Moving about
  a tile away, except toward the hound, gets out.
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
  - pounce = frames 2–13 at 9 fps (springs on frame 6; was 10 fps until the free-movement balance pass)
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
- **Stats:** HP 2200 (3000 until the free-movement balance pass), PhysAtk 22, MagAtk 24, PhysDef 22, MagDef 28, Acc 5; aggro 5,
  leash 14; 1.2 s per tile; 0.3 s reaction; 700 XP, 12 AP; respawn 15 min (10 s in the
  testing grounds); 60–120 g, Fireball / Scorched Earth / Burning Feet scrolls 15% each.
- **Flight** (`EnemyDef.flying`, `GridModel.can_fly`):
  - It crosses any walkable tile whatever its height.
  - It crosses walls, hedges and water up to 1 level above it (`fly_over_levels`),
    but never tiles that block sight.
  - Ground zones don't touch it while airborne.
- **Talon Rake** (`talon_rake`): a 100° cone of 2.7 tiles from its centre (free movement), 20 + 1.2×PhysAtk, 3.0 s. The
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
- **Balance:** no target any more (boss balance targets removed 2026-11-19); its numbers
  above are plain values, tuned by playtesting.
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
- **Zone music** (2026-11-21, branch `audio/new-sounds`; every track levelled to -18 LUFS,
  masters in `art/audio/`): "Millbrook / Greenfields" (`town_millbrook.tres`: town and
  explore, zones town and greenfields), "The Crossing" (`town_crossing.tres`), "The Silent
  Shaft" (`dungeon_silentshaft.tres`, also through the Foreman's fight until
  `music_boss_foreman.ogg` exists). What plays where (`tests/unit/test_zone_music.gd`):

  | Zone | Its context plays | Combat / boss |
  |------|-------------------|---------------|
  | Millbrook (town), Greenfields (explore) | Millbrook / Greenfields | keep |
  | The Crossing (town) | The Crossing | keep |
  | The Silent Shaft (dungeon) | The Silent Shaft | keep (boss_foreman once its file exists) |
  | Windsteppe (explore, Vael) | Windsteppe | keep |
  | Tidereach Shore (explore, Tidereach) | Water Idle | keep |
  | Deepcut (town), Road to Deepcut and the Wilds (explore → town) | the draft | keep |
  | title screen | the draft | — |

- **First sound effects** (same branch; trimmed and levelled, world sounds mono; notes in
  `AUDIO_SPEC.md` "Sound effects now"): `ui_click`, `ui_quest_accept`, `ui_quest_complete`,
  `world_level_up`, `water_healing_touch_hit`, `water_whip_hit`, `air_palm_hit`,
  `air_gust_cast`, `creature_wolf_bite` = `creature_iron_wolf_bite` (one Mixkit file),
  `creature_old_grizzlehide_cleave`, `creature_stag_aggro`. Abilities with a timing bar
  use `_hit` (their `_cast` plays when the bar starts). An enemy pulled into a fight by
  damage now sends `aggro` too, once, when it switches from idle to fighting
  (`EnemyBrain`), so the neutral stag bellows when attacked.
- **Water near the hero** (`WaterAmbience`, `view/water_ambience.gd`, made by
  SoundDirector; plain functions in `WaterSound`, `view/water_sound.gd`): a zone's water
  tiles (terrains whose tiles the tileset catalog puts in the "water" category:
  `water`, `deep_water`, `light_water`, `grey_water`; fords and rocks in water are stone)
  are indexed in 8×8 buckets when the map loads. Every `water_update_seconds` (0.5) the
  tiles within `water_radius_tiles` (10) are grouped into clusters (diagonals touch) and
  the nearest tile of each of the `water_max_emitters` (3) nearest clusters gets a looping
  `ambience_water` emitter (`AudioStreamPlayer2D`, Ambience bus, a random start in the
  loop). Level: `water_volume_db` (0) × (1 − distance / radius)^`water_falloff` (1.5),
  from the grid distance (Godot's own fade is off: screen pixels per tile differ by
  direction); panned from the listener. A spot within `water_glide_tiles` (3) of an
  emitter glides there; otherwise the old one fades out and a new one fades in over
  `water_fade_seconds` (1). A new zone fades every emitter out. The emitters sit under
  WaterAmbience, not the world view (freed with its map). Plays beside the zone's
  ambience. Cost (`tools/perf/water_profile.tscn`): indexing 0.5 ms once per map; a look
  around 0.03 ms on average (0.33 ms at worst) on Greenfields and Millbrook, twice a
  second. Tests: `tests/unit/test_water_sound.gd`, `tests/integration/test_water_ambience.gd`.
- 13 of the 241 keys have a file (`AUDIO_SPEC.md`).

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
- **The placeholder Act I** of this milestone (the Guild's Summons, Ash on the East
  Road, the Ember Hand's Writ, Ore for Millbrook, What the Stone Remembers, three side
  quests) was replaced by the real one in milestone 3: see **Act I: the Floor Guild
  quests**. Rowan's and Old Ottilie's 5 Millbrook quests stay, as side quests.
- **Network:** new intents `examine` and `accept_shared_quest`; the escort flag is
  in each NPC's snapshot. The 4-player check now has the guests in town join the
  host's quest over the network.

## Act I: zones and region music (milestone 2 of 4, 2026-10-27)

User brief: build or update the Act I zones, small and hand-built, with height used
for cliffs, ramps and high ground, joined by roads with the Crossing as the hub;
music by region. Built by `tools/once/make_act1_zones.py` (+ `bake_zone_rows.gd`);
edit the zone files directly now. Screenshots: `tests/visual/zone_shots.tscn`.
- **Map** (grid sides; offsets in the zone files):
  - Millbrook (32×32) south gate (x 8–11) ↔ the Crossing's north gate; Millbrook's
    east side (rows 1–16) still leads to Greenfields and its north gate to the Enemy
    Testing Grounds.
  - The Crossing (40×40): east (rows 18–21) ↔ Road to Deepcut (60×22, rows 9–12) ↔
    Deepcut (44×40, west gate rows 16–19); west (rows 18–21) ↔ Windsteppe (56×44,
    rows 20–23).
  - Tidereach Shore (test, 18×14) ↔ a gate at the west end of the Enemy Testing
    Grounds (`TestingGrounds.WEST_GATE`, opened when the zone has a west edge).
  - Greenfields' map and the testing grounds' layout are unchanged (Greenfields lost
    its Act I NPCs).
- **Millbrook:** farming village on the river (x 24–25): grey upstream (south, from
  the Crossing), clear below the mill pond; thatched houses, fields, the Village Well
  on the green, the orchard on high ground with a rocky crest, the Healer's Hut
  (Healer Wenna) with Millbrook's graveyard.
- **The Crossing:** Floor Guild Hall (Dorne), Guild Board, market stalls with two
  vendors (Tamsin Reed: Hilda's stock; Odo the Apothecary: potions), the Crossed Keys
  Inn (Innkeeper Bram, Sabra Venn), the Graveyard Shrine on a knoll, a rocky hill and
  a ridge; the grey stream crosses it toward Millbrook.
- **Road to Deepcut:** grass to red earth between rising canyon walls, the Lookout
  Ledge (a Bandit Brute), two wolves, the grey stream along the south.
- **Deepcut:** red canyon town: Mine Entrance in the cliff north of the mine yard,
  ore carts, Foreman Brannoc, Steward's Office on a terrace (Steward Orrin Marl),
  Mine Board, the tailings pond and polluted stream, Miners' Row, the Collapsed
  Shaft in the spur's face. Two Salamander Hounds by the canyon gate (the escort's
  danger). The escort now runs from the mine yard to the canyon gate.
- **Windsteppe:** rolling steppe (heights 0–2), dry patches, Grey Ridge (4 high),
  Tsaga's Camp (gers, Elder Tsaga, a dry well, a cairn, a herd), a south camp,
  cairns, the Vael Standing Stone on its hill, six **iron wolves** patrolling in
  three packs.
- **Iron Wolf** (`content/enemies/iron_wolf.tres`): level 3, HP 320, PhysAtk 16,
  PhysDef 18, MagDef 6, Evasion 4, leash 12, 0.7 s per tile, 80 XP, 3 AP; the
  wolf's bite and howl (calls iron wolves); the wolf art recoloured to steel
  (`iron_wolf_art.tres`).
- **Placeholder art:** tiles 115–136 recolour existing ones (grey water, red canyon,
  steppe grass, roofs, red boulders; `tools/once/make_placeholder_tiles.py`).
  Objects without art are `ZoneDecor` (`ZoneDef.decor`: well, dry well, ger, cairn,
  cart, animal, shrine, stall, sign, mine, crates, label), drawn by `DecorPainter`
  as polygons (clipped like tiles for the terrain cache), labels within 12 tiles;
  they block their tile, gers and mines block sight too. Things set against a cliff
  go on its north/west side, the faces the camera sees. See `docs/tilesets.md`.
- **Respawn:** `ZoneDef.respawn_zone`: the Road, Deepcut and the Windsteppe send
  released heroes to the Crossing's shrine (`World._respawn_elsewhere`, a
  `zone_change` then a `release` in the Crossing). Millbrook, Greenfields and the
  testing grounds keep their own graveyards.
- **Regions** (`Regions`, `ZoneDef.region`): Heartland (Millbrook, the Crossing,
  Greenfields, testing grounds), Bedrun (the Road, Deepcut), Vael (Windsteppe),
  Tidereach (the test shore). `MusicTrackDef.regions`: a track for the zone's region
  wins, else a track for any region; another region's never plays
  (`Audio.pick_track(ctx, bond, region)`).
- **Music:** `audio/music/music_explore_tidereach.ogg` ("Water Idle", Vorbis q6 from
  the uploaded WAV, kept at `art/audio/music_explore_tidereach_master.wav`), explore in
  Tidereach. Not edited: it doesn't loop cleanly (2.35 s of near-silence at the start,
  ends at full level). `audio/music/music_explore_windsteppe.ogg` ("Windsteppe", the user's
  upload, 2026-11-02): explore in Vael (the Windsteppe); not edited, it loops with a small dip
  (starts about 10 dB quieter than it ends, no gap). Everything else still plays the draft.
  Crossfade 1.5 s as before.
- **Ambience keys:** `ambience_<zone id>`: `ambience_town`, `ambience_crossing`,
  `ambience_deepcut_road`, `ambience_deepcut`, `ambience_windsteppe`,
  `ambience_tidereach_shore` (in `AUDIO_SPEC.md`).
- **Debug console:** `goto <zone>` (a zone's first hero spawn).
- **Sound keys:** a creature ability shared by several enemies gets keys for each
  (`creature_wolf_bite` and `creature_iron_wolf_bite`).
- **Network:** the 4-player check has the guests join Rowan's quest in Millbrook,
  then Guest1 goes to Greenfields and Guest2 to the Crossing: three zones at once.

## Act I: the Floor Guild quests (milestone 3 of 4, 2026-10-27)

User brief: Act I, "The Floor Guild" (levels 1–12, about 2–3 hours): the party earns a
place in the Floor Guild through three relief missions; each succeeds on paper, but
the suffering returns, and every one traces back to a Sunstone mine or supply road.
Prince Caedan Ashvale, the Guild's founder, is sincere. Quests written by
`tools/once/make_act1_quests.py` (edit the .tres files now); every line in
`content/dialogue/act1.json`. Checklist: `docs/playtest-checklist-act1-quests.md`.
- **Quests** (`content/quests/act1_*.tres`; level, giver → hand-in, objectives):

  | Quest | Lv | Giver → hand-in | Objectives | XP |
  |-------|----|-----------------|------------|----|
  | 1-01 The Guild Comes to Millbrook | 1 | Maren Voss (Millbrook) | kill 3 wolves, 2 boars in the south fields | 120 |
  | 1-02 Applicants Wanted | 2 | Maren Voss (Crossing) | talk to Warden Dorne, Quartermaster Harrow | 150 |
  | 1-03 Wells for the Windsteppe | 3 | Maren → Saran | escort the Well-Digging Crew to Tsaga's Camp; kill 4 iron wolves | 400 |
  | 1-04 Grain for Deepcut | 3 | Guild Board → Steward Brann | escort the Guild Grain Wagon down the Road to Deepcut | 450 |
  | 1-05 Fever in Millbrook | 3 | Guild Board → Healer Wenna | talk to Odo; deliver 3 Fever Draughts to Wenna; examine the grey river in Millbrook, on the Road and in Deepcut | 450 |
  | 1-06 Recognition | 6 | Maren → Caedan | talk to Caedan (after 1-03, 1-04, 1-05); leads to 1-07 The Silent Shaft (milestone 4) | 450 |
  | The White Death (side) | 4 | Saran | collect 4 iron wolf pelts (quest drop, 60%); deliver Winter Stores to Elder Tsaga | 300 |
  | Shift Bell (side) | 6 | Mine Board → Miner Ostrik | use the Collapsed Shaft; kill 3 Human Husks; talk to Miner Ostrik | 350 |
  | Pins on the Map (side) | 7 | Guild Board → Maren | reach 4 troubled sites; use the Guild Map | 500 |

  Escorts fail if the escortee dies and restart from the giver (milestone 1 rules).
- **Rewards:** gold, potions, and since 2026-11-20 the hero's element set and next
  scrolls (see **Element set rewards**). (Before: a choice of one tier-1 scroll or
  weapon per main quest.)
- **Missing tier-1 abilities** (not implemented, so not rewarded): E02 Stone Skin
  (Granite Skin Scroll), A04 Wind Snare (Snaring Wind Scroll), S02 Thrust (Militia
  Rapier), S03 Parry (Duelist's Sabre), B03 Disengage (Ranger's Bow), B04 Hunter's
  Mark (Tracker's Bow), H03 Brace (Bulwark Hammer), H04 Wide Swing (Broad Maul).
- **Levels:** the quests' XP plus their required kills take a party to level 10
  (`tests/integration/test_act1_playthrough.gd`: solo 4,770 XP, a party of four 4,578
  each, in the measured run; the curve itself is unchanged, 100 × level). The Silent
  Shaft has to give about 2,100 XP more to reach 12. Rowan's and Ottilie's Millbrook
  quests are extra (about 1,060 XP).
- **People** (new): Maren Voss (two placements, `maren_voss_field` by Millbrook's
  south bridge and `maren_voss` at the Guild Hall), Prince Caedan Ashvale and
  Quartermaster Ilse Harrow (the Guild vendor: Iron Helm, Swift Boots, potions and the
  20 implemented tier-1 scrolls and weapons) at the hall, the Guild Map (a board), Saran
  and the Well-Digging Crew (260 HP) on the Windsteppe, the Guild Grain Wagon (420 HP)
  on the Road to Deepcut, Miner Ostrik in Deepcut. Renamed: Steward Orrin Marl → Steward
  Brann; Old Maren → Old Ottilie (id `maren` kept). Gone: Foreman Brannoc, the ore
  caravan, the Sealed Writ. Sabra, Ilyth and the Vael stone stay as people to talk to.
- **Enemies:** Boar (level 2: HP 240, PhysAtk 12, PhysDef 10; Gore 7 + PhysAtk, 0.4 s
  wind-up; Tusk Charge, a 1 s telegraphed rush 2–3 tiles, 8 + PhysAtk) and Human Husk
  (level 7: HP 420, PhysAtk 22, PhysDef 14, MagDef 24, heavy, 1.3 s per tile; Hollow
  Rake 10 + PhysAtk, 0.6 s wind-up; drops Sunstone Shards). Placeholder diamonds until
  art (the Boar has the Critters pack's since 2026-11-19). `EnemySpawn.level` places an enemy at another level (±15% per level): road
  wolves 3, road Bandit Brutes 5 (two ambushes beside the road), iron wolves 4–5,
  Deepcut's hounds 6.
- **Party size** (`CombatRules` "Party size"): enemies grow with the heroes in their
  zone (1–4): +70% max HP and +10% damage per extra hero (×3.1 HP and ×1.3 damage for
  four); a kill's XP grows the same, so every hero who fought earns a solo share
  (`share = xp × min(fighters, party size) / fighters`). Scaled while not fighting (a
  fight keeps the size it began with; a hurt enemy keeps its share of health).
  Elites and training dummies don't scale. Tests of exact numbers switch it off
  (`party_scaling`).
- **Dialogue:** `quest.<id>.talk.<i>` lines: what the person of a Talk objective says
  when you come to them for it.
- **Test:** `Act1Playthrough` (`tests/integration/act1_playthrough.gd`) plays every
  quest in order through intents, for one hero and for a party of four who join each
  quest through the co-op prompt; kills are short-cut, escorts are walked.

## Act I: the Silent Shaft (milestone 4 of 4, 2026-10-27)

User brief: quest 1-07 and Act I's dungeon; dungeon rules for every dungeon; the boss; the end of
the act. Content written by `tools/once/make_silent_shaft.py` (enemies, abilities, buffs, loot,
encounter, the zone) and `tools/once/make_act1_quests.py` (1-07); edit the files directly now.
Checklist: `docs/playtest-checklist-act1-full.md`.
- **Dungeon rules (every dungeon, `ZoneDef.dungeon`):**
  - **Instanced per party:** no copy exists until the party walks in; then the party gets its
    own (`World.dungeon_instance`, key `<zone>@<party>`, its own enemies, boss and loot). All
    connected players are one party (rule 11), so for now there is one copy. A copy nobody has
    been in for `dungeon_close_seconds` (60) closes; the next visit starts fresh. Zones are found
    by key (`WorldSim.key`); `zone.id` stays the map's id, so clients load the right map.
  - **Entry** (an exit tile into the dungeon, `ZoneDef.exits`): needs the dungeon's quest
    (`ZoneDef.requires_quest`, active or done) and a party of `CombatRules.min_dungeon_party()`:
    `dungeon_min_party` (3) in the real game, 1 with **dungeon testing** (`dungeon_testing`: on
    in debug builds, a switch in the Escape menu's Gameplay test tab, sent as the
    `dungeon_testing` intent, allowed where the debug console is). Refused: a red message.
  - **Party wipe:** when every hero in a dungeon is dead at once, after
    `wipe_respawn_seconds` (3) everyone stands up at its entrance (the zone's first graveyard)
    at half health and mana, and enemies forget them. A boss goes back to the start of its
    current phase, not full health.
  - **Lifts:** an exit with no `to_zone` (or its own) moves you within the map.
- **The Silent Shaft** (`content/zones/silent_shaft.tres`, 66×30, region Bedrun, music context
  dungeon): entered by stepping into Deepcut's mine entrance (34, 11); you arrive at (3, 14).
  Walls 6 high everywhere but three sections:
  1. **Upper tunnels** (x 1–20): the entrance (graveyard), an abandoned ore cart and rails,
     collapsed side drifts, the rock turning grey, four Human Husks (level 8); the **Mine Lift**
     at (19, 19) rides down to the seams (and back from (24, 21)).
  2. **Deep seams** (x 23–44): Sunstone seams gold where untouched (east), grey where mined
     out (west), a worked-out ledge (height 2) and a high seam face (3) with ramps, pillars
     that break line of sight, four Husks (level 9, one on each height), and the optional
     **Old Shift Office** (south) with the **Grey Overseer** (level 9, 760 HP; drops tier-2
     scrolls 35% each, potions, a Sunstone Shard).
  3. **The Foreman's chamber** (x 47–64): grey floor, gold seams, four pillars, the Foreman
     before the Grey Heart on its dais.
  New placeholder tiles 137–146 (mine floor and stone, grey rock, gold and spent seams,
  Sunstone and grey clusters). Steward Brann leaves Deepcut once 1-06 is handed in (world flag
  `brann_descended`, `NpcDef.gone_after_flag`): he has become the Foreman.
- **The boss** (`content/encounters/foreman.tres`, `BossEncounterDef`, run by `BossEncounter`):
  - **The Foreman** (level 10 elite, `dungeon_boss`: scales with the party like other enemies;
    HP 1100 solo, PhysAtk 16, PhysDef 18, MagDef 22; heavy; leash 16; +45% health per extra hero,
    `EnemyDef.party_hp_per_hero`): Pick-Hammer (an 80° cone of 1.5 tiles, 14 + 0.75×PhysAtk,
    2.4 s, 0.7 s wind-up), **Ground Slam** (a circle of 1.5 tiles at his target, marked red for
    1.0 s, 12 + 0.6×PhysAtk, 8 s) and **Mine-Cart Charge** (a lane 2–5 long marked for 1.1 s, then
    a rush and 8 + 0.6×PhysAtk, 15 s). Values as of the free-movement balance pass. Threat decides his target: the
    tank holds him (taunts work).
  - **The Grey Heart** (level 10, 300 HP solo, +45% per extra hero, `immobile`, drawn as a cracked black-gold
    crystal leaking smoke, `EnemyDef.Look.CRYSTAL`): fights beside him, shielded ("Immune",
    "Shielded by the Foreman") until phase 3.
  - **Phase 1** (100–60%): slams and charges; tank and spread.
  - **Phase 2** (below 60%): the Heart pulses every 12 s: one Grey Husk climbs out (90 HP solo,
    at most 2) and 6 tiles around the heroes turn grey for 12 s (`greyed`: steps ×1.5, −3% of
    max mana per second).
  - **Phase 3** (below 25%): the Foreman enrages (**Grey Fury**: +30% damage, cooldowns ×0.85),
    the Heart opens and pulses every 9 s (8 grey tiles, no husks). He can't fall below 5% while it
    beats. **Breaking the Heart ends the fight:** he falls with it (his kill and XP go to the
    party), adds and grey fade, and Caedan comes down to the chamber door (50, 15).
  - Its numbers are plain values, tuned by playtesting (the bot boss-fight benchmark and its
    targets were removed 2026-11-19).
- **Quest 1-07 The Silent Shaft** (main, level 8, Caedan at the hall → Caedan in the shaft):
  ride the lift to the deep seams, find where the silence comes from (the chamber), break the
  Grey Heart, speak with Caedan. Shaken, he recruits the party into the Ember Hand (a dialogue
  with choices, `quest.act1_07_the_silent_shaft.talk.3…`). Rewards: 1,200 XP, 120 gold, potions,
  a choice of Fireball, Glacier or Bulwark scroll. Hand-in sets `act1_complete` (saved by the host)
  and ends the act (`QuestDef.ends_act` = 1, `return_zone` = crossing).
- **End of Act I** (`ActEndScreen`): opens after the hand-in conversation, over a dimmed world:
  the act's name, a line of story, and the party's records (level, enemies defeated, damage
  dealt, healing done, deaths, quests handed in); its button sends `finish_act` and the host
  takes the hero to the Crossing. Records are kept per hero (`Hero.records`, from the sim's
  events) and saved with the character, with the acts finished (`records.acts`: [1]); the
  character saves the moment the act ends.
- **Levels:** the scripted playthrough ends Act I at level 12, solo (7,190 XP) and for a party
  of four (6,934 each), without the dungeon's husks and the Overseer (about 1,500 XP more).
- **Audio:** tracks `music_dungeon_silentshaft` (dungeon) and `music_boss_foreman` (boss) are
  listed for the Silent Shaft only (`MusicTrackDef.zones`); a track whose file is missing is
  skipped, so the draft plays (dungeon → explore → town) and the boss fight keeps the music. New
  sound keys: the Foreman's, the Heart's, the grey husk's and the Overseer's (generated), plus
  `creature_foreman_phase` / `_enrage` / `_reset`, `creature_grey_heart_pulse` / `_break`,
  `world_dungeon_enter`, `world_lift`, `world_party_wipe`, `world_wipe_respawn`,
  `world_act_complete`, `ambience_silent_shaft`, `footstep_mine_floor`, `footstep_grey_rock`.
- **Testing grounds:** dungeon bosses and immobile enemies (the Foreman, the Heart) get no pen;
  the grey husk and the Overseer do.
- **Debug:** `goto silent_shaft` goes straight into the party's copy.
- **Tests:** `tests/unit/test_dungeons.gd` (entry rules, testing setting, copies, closing,
  lifts, wipes), `tests/integration/test_foreman.gd` (phases with 1 and 4 heroes, greyed
  ground, the wipe reset, threat), `tests/integration/test_act_end_screen.gd`, and
  `Act1Playthrough` now plays 1-01 to 1-07, the
  end screen and the walk home.

## Free movement (branch `feature/free-movement`, 2026-11-01)

User brief: free movement and mouse-aimed attacks instead of the tile grid. Plan, every
system affected and the phase order: `docs/FREE_MOVEMENT_PLAN.md` (approved with 3 tiles/s
everywhere and gravity falls). The grid stays as the world's data (heights, walls, sight,
terrain abilities, ground zones); units live at continuous positions (tile units, the
centre of tile (x, y) is the point (x, y); `tile()` is the tile under the centre).
- **Phase 1 (done): hero movement.** `MoveState` holds `pos`, `vel`, a fall (`z`, `vz`),
  the drawn height, a radius and an odometer; `Mover` moves a unit for one tick.
  - Values in `content/rules/movement.tres` (`MovementDef`, `CombatRules.movement`):
    3 tiles/s in and out of combat (`combat_speed_factor` 1.0), full speed in 0.1 s, stop
    in 0.08 s, hero radius 0.3. Speed stat +1% per point (up to ×3); slows and Haste act
    through the buffs' step multiplier (×1.5 slow = 2 tiles/s); roots and stuns stop it.
  - Input: WASD give 8 directions: one key walks straight along the screen (W = up the
    screen), two keys walk exactly along a grid line (W+A grid left, W+D grid up, S+D
    grid right, S+A grid down; since 2026-11-15, they used to cut across at 45° on
    screen and drift off the row); diagonals no faster. Sent
    as `{"type": "move", "dir": Vector2i (screen), "face": angle}` with the mouse's
    grid-space angle. In combat the hero faces the mouse, otherwise where it walks;
    `facing` is the nearest of the 4 grid directions (sprites).
  - Collisions: unwalkable tiles and the map's outside are solid squares; a tile more
    than the unit's Jump above is a cliff face; units slide along them. Heroes push each
    other (the lighter more) and are pushed out of enemies and NPCs.
  - Drops are always allowed: 1 level is a step down (drawn smoothly); 2+ levels is a
    fall under gravity (40 levels/s², 60% of the speed carried, no steering, casts
    cancelled, a shadow on the ground below); more than 3 levels hurts 10% of max HP per
    extra level, at most 60%, never below 1 HP unless `fall_damage_can_kill`.
  - `{"type": "step", "to": tile}` walks to a tile's centre (tests, later click-to-move);
    a cast ends such a walk, a held key cancels a cast bar.
  - Map edges: pushing against a side that leads somewhere leaves through it.
  - Terrain friction (`friction` on a tileset terrain) lowers acceleration (ice); none set.
  - Enemies and NPCs still step tile to tile (gliding between centres, 0.4 s per tile out
    of combat) until phase 5. Abilities still resolve on tiles until phases 3–4.
  - Balance targets that assumed tile steps are pending until phase 6.
  - Screenshots: `tests/visual/free_move_shots.tscn`.
- **Phase 2 (done): networking.**
  - Input: a `move` intent every sim tick while a key is held (and whenever the
    direction or the mouse angle changes), each with its own sequence number.
  - **Prediction** (`ClientWorld.predict_move` / `predict_tick`, driven by
    `ClientSession` at the sim's tick rate): the local hero moves at once with the same
    `Mover` as the host, remembering the input each tick used. On each snapshot it takes
    the host's position after the acknowledged input and replays the later ticks; a
    difference under 1.5 tiles fades out over 0.1 s (`MoveState.smooth_offset`), a bigger
    one (a teleport) snaps. A forced move (knockback, glide) is left to the host.
  - **Interpolation:** everyone else is drawn 0.1 s behind the newest snapshot, between
    buffered snapshots (`MoveState.samples`, `INTERP_DELAY`), so uneven arrival never shows.
  - The host keeps 2 s of exact positions per hero (`perceived_pos`, `positions_within`)
    for enemies' reaction delay and for forgiving hits (phase 3).
  - Network check: guests walk all 8 directions, stop, and must agree with the host
    within 0.25 tiles; `NETCHECK_DELAY=0.1` holds every guest intent 100 ms
    (`ClientSession.send_delay`). Both pass with 4 players (0.00 tiles apart after settling).
  - Tests: `tests/unit/test_prediction.gd` (latency simulated by delaying intents).
- **Phase 3 (done): hitboxes, aim indicators, importer.** The engine is ready; no
  ability uses it yet (phase 4 switches them over, so play is unchanged).
  - `HitboxDef` (`AbilityDef.hitbox`): None, Targeted, Cone, Line (rectangle), Circle,
    Projectile, Lob, Self Circle, Dash, Leap, Blink, and Tiles (stays on the grid:
    terrain and ground zones). Values in tiles: range, angle, width, radius, projectile
    speed and size, pierce.
  - `Hitbox` (geometry against round bodies: grazing counts; ranges edge to edge; line
    of sight sampled along the segment) and `HitboxResolver` (CastResolver hands over
    when `AbilityDef.uses_hitbox()`). Cooldowns, GCD, mana, timing bars, crits and
    threat are unchanged. Projectiles fly in continuous space (a swept circle; heroes
    count where they were within the 0.1 s grace window). Knockbacks, pulls and dashes
    slide in continuous space and stop at walls, cliffs and units (`Hitbox.slide`).
  - Aim indicators: the exact shape follows the mouse (blue, red when it can't be
    cast); telegraphs with an outline draw in red, brighter as they land
    (`WorldView._draw_outlines`). Tiles abilities keep the tile preview.
  - **Spreadsheet:** eight columns at the end of the Abilities tab (Hitbox Shape,
    Hitbox Range, Hitbox Angle, Hitbox Width, Hitbox Radius, Projectile Speed,
    Projectile Size, Pierce) and a "Hitbox Rules" note on the Timing Rules tab, filled
    for all 145 abilities from the plan's tables (`tools/once/fill_hitbox_columns.py`;
    it patches the file's XML, because openpyxl would drop the cached results of the
    sheet's formulas, which the importer reads). The importer checks the shape name,
    the values each shape needs, negatives and Pierce (Yes / No); `TreeContent` keeps
    each as `AbilityDef.sheet_hitbox` until phase 4 makes it the ability's hitbox.
  - Tests: `tests/unit/test_hitboxes.gd`, hitbox cases in `test_ability_import.gd`.
- **Phase 4 (done): all 32 abilities on hitboxes.** Each implemented ability uses its
  sheet hitbox (`TreeContent`; shapes in the plan's §6 table, checked by
  `test_each_ability_has_the_planned_hitbox`).
  - Slash and Smash are mouse-aimed cones (100° and 70°, 1.4 tiles) that swing on the
    key press, toward the mouse (with a timing bar, the bar starts and the swing goes
    where the mouse points at the end). Lock-on spells stay targeted, with ranges
    measured edge to edge.
  - Fire Dart, Frost Shard and Aimed Shot are projectiles; Fire Whip and Water Pulse
    are lines; Fireball a circle; Rock Throw a lob; Flame Dash and Lunge dashes;
    Seismic Stomp and Ground Slam circles around you. Burning Ground, Ice Spikes,
    Raise Pillar and Earth Wall stay on the tiles.
  - Aims are the exact mouse point (`PlayerInput.mouse_point`), always (since 2026-11-15:
    no lock-on to the targeted enemy, and a cursor off the map still gives the direction
    toward it); a timing bar's inputs re-aim every mouse-aimed ability, Slash's cone
    included (`WorldSim.is_mouse_aimed`); a circle aimed too far
    lands at the edge of its range (grid abilities still refuse it).
  - **Air Step** is now +40% speed for 4 s (the "free steps" no longer exist).
  - Outlines are drawn flat at the height under their centre, so they don't tear
    across ledges. Screenshots `fm5`–`fm7` in `tests/visual/free_move_shots.tscn`.
  - Balance targets the new shapes moved (dodging wind-ups, the hammer alone vs a
    Wolf, the drake vs a level-7 group) are pending until phase 6.
- **Phase 5 (done): enemies move freely and attack with hitboxes.**
  - **Navigation** (`Navigator`): A* over the tile graph (the same height, ramp, cliff,
    large-body and flight rules as before; no squeezing past corners), string-pulled
    into straight runs, then followed with the heroes' `Mover` (acceleration,
    collisions, falls). A brain calls `Navigator.go` with a goal tile; it searches
    again when the goal changes, every 0.5 s, or when the path runs out.
  - **Speeds** (`EnemyDef.move_speed`, tiles/s): Salamander Hound 3.5, Fen Skirmisher
    3.4, Wolf 3.25, Iron Wolf 3.1, Boar 2.8, Goblin Shaman and Grizzlehide 2.7, Sunscale
    Drake 2.5, Foreman 2.52 (2.1 until 2026-11-19), Husks and the Overseer 1.85, Bandit Brute 1.7 (heroes 3).
    Patrols walk at `EnemyBrain.patrol_pace`. **Colliders** (`collider_radius`):
    wolves, hounds, boars 0.35; Shaman and Skirmisher 0.3; Brute, Husks, Overseer,
    Grizzlehide, Foreman 0.45; the drake 1.35; the Grey Heart 0.6. Free movers push
    each other apart by weight.
  - **Attacks** (hitboxes in each ability's .tres, aimed where the enemy saw its target
    `reaction_seconds` ago; reach checked in continuous space, `EnemyBrain.reaches`):
    bites, rakes, slashes and swipes are cones (70–120°, 1.2–1.8 tiles; the drake's
    rake 2.7 and breath 5.3 from its centre); Shadow Bolt a projectile; Grizzlehide's,
    the boar's and the Foreman's charges are dashes with a telegraphed lane; Cinder
    Pounce a leap onto a circle beside its prey; the Foreman's Ground Slam a circle of
    1.5 at the target, telegraphed 1.0 s (was 1.8 s). The drake's Searing Dive stays on
    its tile lane (`CHARGE_THROUGH`), and Ember Trail on the tiles the hound leaves.
  - Escorted NPCs walk their route the same way (0.7 s per tile, 1.43 tiles/s).
  - **Removed:** tile stepping for everyone (`WorldSim.try_step`, step cooldowns, the
    "free steps" buff field). `combat_step_seconds` and `walk_tile_seconds` stay in
    the data files unused; `combat_step_base_seconds / combat_step_min_seconds` caps
    how much the Speed stat can raise walking speed (×3).
  - Dodge warnings (debug builds, at load) now compare against the time to move a tile
    plus the reaction time (0.63 s); most enemy wind-ups (0.3–0.6 s) are under it, to
    be tuned in phase 6.
  - Network check: Guest3 spawns a Bandit Brute and runs out of its telegraphed swipe
    over the network (also with `NETCHECK_DELAY=0.1`). Since phase 6 it does this in
    the Enemy Testing Grounds (`goto`), so the brute can't pull other guests into combat.
- **Phase 6 (done): balance.** Every target in `tests/balance/test_balance.gd` is met and
  enforced again (the ones pending since the timing bars included); numbers from
  `tests/balance/balance_report.tscn`.
  - **Fair telegraphs:** big enemy attacks are `AbilityDef.dodgeable` and give at least
    0.63 s (a tile at 3 tiles/s plus 0.3 s to react): Crushing Blow 0.8 s; Cleave, Hollow
    Rake, Overseer's Crush, Pick-Hammer 0.7 s; Cinder Pounce 0.67 s; Shadow Bolt 7 tiles/s
    (0.71 s over its range); charges 1.0–1.1 s; Ground Slam 1.0 s; breath 0.8 s; dive 1.0 s.
    Quick bites (wolf, hound, boar, Skirmisher, Talon Rake) stay chip damage. Debug builds
    warn at load about a dodgeable attack under that time.
  - **Combat pacing:** Wolf bite 2.5 s (was 2.0), Wolf HP 200 (230); hound bite 2.0 s (1.6);
    Shadow Bolt 3.0 s (2.5), Goblin Shaman HP 130 (160); Talon Rake 3.0 s (2.5), drake HP
    2200 (3000); Fire Dart mana 10 (6).
  - **The Foreman:** HP 1100 (800), Pick-Hammer 14 + 0.75×PhysAtk (8 + 0.6), Grey Fury +30%
    (+15%), Grey Heart 300 HP (150); both grow +45% health per extra hero instead of +70%
    (`EnemyDef.party_hp_per_hero`).
  - A unit mid-attack stands firm: pushes from other units don't move it.
  - **Bots** (`BalanceSim.bot_turn`) move continuously: close in to each ability's reach
    (`bot_reach`), aim at positions, never swing at empty air; with "dodge" they run out of
    telegraph outlines (sidestepping when straight back is blocked), step off burning
    ground and wait rather than walk into a marked shape. The level-5 group's damage
    dealers and healer dodge; tanks hold still.
  - Measured (bots): starter vs a Wolf 9.0 s, 36% HP lost (dodging: 10%); sword, bow or
    hammer alone win; a pair beats 2 Wolves (70%); a caster spends 64% of its mana on a
    Wolf and beats the Shaman; heals + dodges beat the Brute (54%), standing still loses.
    (The boss rows, Grizzlehide, the drake and the Foreman, were removed 2026-11-19.)
  - Manual checklist: `docs/playtest-checklist-free-movement.md`.

## Loot, boss rolls, binding, trading, duels (branch `feature/loot-trade-duel`, 2026-11-19)

User brief, eight phases (also: boss balance targets removed, the Wilds, mirrored hit
animations; see their sections). Built on `feature/critters-boss-fixes`. The host decides
every roll, award, trade and duel. **Every number** is in one resource:
`content/rules/party_play.tres` (`PartyPlayDef`, linked as `CombatRules.party_play`).
Multi-client checks: `tests/net/run_party_check.sh loot | roll | bind | trade | duel` (a host
and two clients on localhost; each passes).
- **Personal loot** (`GroundDrops`, `sim/loot/ground_drops.gd`; `WorldSim._loot_kill`):
  - A kill's gold and crafting materials (`ItemDef.is_material`: nothing to wear, use or learn,
    no quest) are rolled once and **copied** to every hero who fought (on its threat table),
    straight into the bag; what doesn't fit drops at their feet.
  - Everything else is rolled for each fighter and **drops on the ground** for that hero only,
    scattered within 0.8 tiles: only they are sent it (Snapshot private `drops`), only they can
    pick it up (E within 1.6 tiles, `pick_up` intent). Drops last 300 s. The old "bag full"
    loot window is gone (leftovers lie on the ground instead).
  - Drawn as a light beam in the rarity's colour (white, green, blue, purple, gold;
    `Rarity.BEAM_COLORS`) with the item's name in your colour.
  - Party feed on pickup: "<Player> looted <Item> [Rarity]"; a Rare or better drop also says
    so. Sounds by rarity: `world_loot_common` … `world_loot_legendary` (`Rarity.SOUND_KEYS`,
    listed in `AUDIO_SPEC.md`).
  - After a boss (elite or dungeon boss): an end-of-fight summary (`BossLootSummary`, top
    centre, 12 s) of what each player got; roll winners are added as they're decided.
  - **Legendary** rarity added (gold; its bag border reuses Epic's until drawn). No chests
    exist yet; drops are generic, so a chest only needs to call the same code.
- **Boss rolls** (`LootRolls`, `sim/loot/loot_rolls.gd`; bosses only, user choice):
  - A boss's **key items** (scrolls, tree weapons, or gear that would raise at least one
    fighter's stats over what they wear in that place) are rolled once for the party; every
    fighter gets a window (`RollWindow`: item with tooltip, the boss, a 30 s bar, your bonus,
    Need / Greed / Pass). No answer or leaving = Pass without the bonus.
  - Everyone who chose Need or Greed rolls 1-100 + their bonus (all shown); the winner comes
    from the Needs if any, else the Greeds; ties roll again between the tied (at most 10
    times, then the lowest id). If everyone passes, nobody gets it.
  - Bad-luck bonus (`Hero.loot_bonus`, saved with the character): +10 per Need lost, +15 per
    chosen Pass, 0 on winning.
  - Feed: "Mara: Need 87 (+25) = 112" per player, then "Mara wins <Item>." (`Hud.roll_lines`).
  - The winner gets it in the bag (else at their feet). A winner who has left the zone or the
    game: a **claim box** (`World.claims`, by character name, saved by the host in
    `user://world.json`), delivered when they're next in the world.
- **Binding** (`Binding`, `sim/loot/binding.gd`; a bag stack's `bind`):
  - Bind on Pickup: scrolls, and boss key items won in a roll; bound once they're yours. A
    looted one can still be traded to a member of the fight it dropped in for 20 min (its
    `until` and `fight`), shown in the tooltip ("Tradeable to Ana, Bo for 19:42").
  - Bind on Equip: other gear; free in the bag, bound once worn (everything worn is bound; it
    comes back to the bag bound).
  - Unbound: materials, consumables, quest items, gold.
  - Tooltips show the state ("Bind on Pickup" / "Bind on Equip" / "Not bound" /
    "Soulbound"). Bound and free stacks never merge. Saves keep "bound" and drop the trade
    window (it ran on that session's clock).
- **Trading** (`Trades`, `sim/social/trades.gd`; `TradeWindow`, `RequestWindow`):
  - Right-click another player (their unit frame, or the hero in the world): Trade / Duel.
    The target gets a centred request (Accept / Decline, declines itself after 30 s); both
    within 6 tiles, out of combat, not already trading.
  - Each side adds tradeable bag stacks (and sets gold): they leave the bag into **escrow** on
    the host at once (can't be used, dropped or sold). Bound items can't go in, except Bind on
    Pickup items still in their window going to someone from that fight. 6 slots a side.
  - Offer locks a side; any change unlocks both. Both offered: the **contract** (exactly what
    each gives and gets), Accept / Decline. Both accept: one swap of everything (refused, all
    returned, if a bag can't hold what it gets).
  - Decline at any stage, a disconnect, moving out of range, dying or entering combat
    cancels: everything back to its owner (to their feet if the bag is full). Feed lines for
    done and cancelled trades. A save mid-trade keeps escrowed items (`Hero.escrow`).
- **Duels** (`WorldSim` "Duels"; WoW rules):
  - Right-click Duel; the centred request as for trades (within 15 tiles; none in dungeons).
  - Accepted: a flag at the midpoint with a 10-tile boundary circle, a 3 s countdown over it,
    then the two are hostile to each other only (`Actor.duel_with`, `duel_live`;
    `is_hostile_to`, `is_ally_of`). Nobody else can damage or be damaged by them
    (`Actor.damage_allowed`), and idle enemies don't aggro on them. Pets / companions don't
    exist yet.
  - The duel ends when a duelist would drop to 1 HP: they stay at 1 HP, alive, and yield.
    Also: leaving the boundary shows "Return to the duel area: N" and forfeits after 10 s;
    a disconnect or leaving the zone forfeits; dying to something else ends it.
  - At the end: the buffs and debuffs each put on the other are removed; health, cooldowns,
    items, gold and XP are untouched. Players within 30 tiles of the flag read "<Winner> has
    defeated <Loser> in a duel." The flag stays 3 s.
- Tests: `tests/unit/test_loot.gd`, `test_loot_rolls.gd`, `test_binding.gd`, `test_trades.gd`,
  `test_duels.gd`; screenshots `tests/visual/loot_shots.tscn` (beams, boss summary, roll
  window, request, trade window, contract, duel flag, the Wilds).

## The Wilds (2026-11-19)

A 64 x 64 map in place of the Enemy Testing Grounds (`content/zones/wilds.tres`, written by
`tools/once/make_wilds.py`; edit the file or use the map editor now). Region Heartland,
explore music. Reached through the same gate in Millbrook's north-east hedge (town north edge,
offset -12: its x 15-16 lands on our x 3-4 at the south row) and from Tidereach Shore's east
side (our west column, rows 2-9). Spawn and graveyard in the clearing by the south gate.
- Four winding streams (`water`, not walkable) with stone-slab fords (`ford`, the tileset's
  only wadeable water) where the paths cross and at a few other points; 22 puddles of
  `light_water` (not walkable, shoreline pieces picked by the tileset).
- Dense vegetation over most of the land: tall and dense grass (walkable), leafy-bush
  thickets (not walkable, like Millbrook's hedge), flowers, weeds, logs and stumps (logs,
  stumps and rocks block movement); a few low hummocks (height 1); a bush hedge along the
  border but for the two gates. Every walkable tile is reachable from the gate (pockets the
  generator cut off became thicket). The tileset has no trees: bushes, logs and stumps stand in.
- Empty: no enemies, people, quests or loot yet.
- Tests: `tests/unit/test_wilds.gd`. Screenshots: `wilds0_gate`, `wilds1_inland` in
  `tests/visual/loot_shots.tscn`.

## Enemy Testing Grounds (2026-10-20; retired 2026-11-19)

**Retired:** nothing loads it any more. Its zone file moved to `content/retired/enemy_testing.tres`
(outside the folders ContentDB reads), Millbrook's gate and Tidereach Shore lead to the Wilds,
`goto` lists `wilds`, and its tests (`test_testing_grounds.gd`, the walkthrough) were removed;
`data/testing_grounds.gd`, the Training Dummy and the Reset Shrine stay in the repo, unused. The
network check's brute-dodging guest now does it in the Wilds. As it was:

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

## Icons (branch `feature/icons`, 2026-11-22)

Every Fire, Earth, Water and Air ability (85) and almost every item (172) has an icon,
cut from four bought sprite sheets on the `art-drafts` branch (`icons/`, with a README,
two CSV maps, contact sheets and every sliced icon). Helper: `Icons` (`data/icons.gd`).
- **Where they live:** `assets/icons/abilities/<ID>.png` (33×33: a 32 px tile plus a 1 px
  shadow; named by ability ID, so renaming an ability keeps its icon) and
  `assets/icons/items/<item_id>.png` (36×36, with room around the art for glows), plus
  `assets/icons/placeholder.png` (a "?" tile).
- **In the data:**
  - Abilities: the **Icon** column at the end of the Abilities tab of
    `design/Ability_Tree.xlsx` (a path such as `assets/icons/abilities/F07.png`; added by
    `tools/once/add_icon_column.py`), read by the importer (an error if it isn't a .png
    under `assets/icons/`, a warning if the file is missing) into `ability_tree.json`
    (`icon`), and set as `AbilityDef.icon` by `TreeContent`. Sword, Bow and Hammer rows are
    empty: those abilities keep showing their name.
  - Items: `ItemDef.icon`. The item files in `content/items/` point at their PNG
    (`tools/once/link_item_icons.py`); scrolls and tree weapons (built from the sheet) get
    `assets/icons/items/<item_id>.png` by id in `TreeContent`. The six retired items have
    icons too. `design/Item_Database.xlsx` has an **Icon** column (`tools/item_database.gd`).
- **Missing:** the placeholder, and one warning per missing id when the content first
  loads (`ContentDB`, once per run), never a crash. Exceptions: weapon-tree abilities
  (their name) and the five Legs items in `Icons.KEEP_NAME` (their name). Known gaps
  today (`tests/unit/test_icons.gd`): those five Legs items (the sheets have no trousers)
  and the 20 element set pieces of 2026-11-20 (the placeholder).
- **Import settings** (pixel art): lossless (`compress/mode=0`), no mipmaps, no
  fix-alpha-border, in each icon's `.import` file. Godot has no per-folder import presets,
  so `tools/pull_icons.py` writes these for every icon it copies, and a test checks every
  file. Nearest filtering is the project's default for every texture.
- **Drawing:** never stretched; always a whole number of **screen** pixels per art pixel,
  centred (`Icons.fit_rect` / `draw_fitted`, `screen_scale_of` counts the window's stretch,
  like the world camera). In text (`Icons.bbcode`): k screen pixels per art pixel, k = the
  whole part of the window's stretch.

  | Where | 1280×720 | 1920×1080 |
  |-------|----------|-----------|
  | Action bar (56 UI px; under the cooldown and global sweep; key and potion count kept) | 1× | 2× |
  | Ability tree nodes (44 UI px square left of the text; greyscale and dimmed while locked or not in the game) | 1× | 2× |
  | Bag slots on the book page (art frame 26) | 1× | 2× |
  | Equipment and learning slots (inside the rarity border) | 1× | 2× |
  | Dark item slots (64 UI px) | 1× | 2× |
  | Spellbook rows, item buttons (quest reward choices) | 1× | 1× |
  | Text: item tooltips, ability tooltips (action bar, tree, spellbook), shop, trade and roll rows, quest rewards, boss loot summary, loot feed (Log tab) | 1× | 1× (24 UI px) |
  | Loot on the ground (at the beam's top, half the world art's pixel size) | 1× | 2× |

  Tree nodes are 14 UI px apart (were 22) with 12 px text beside an icon, so names keep
  a word per line.
- **Add or swap an icon:** change it on `art-drafts` (`icons/abilities/` or
  `icons/items/`, cut from `icons/sliced/`), then
  `git fetch origin art-drafts && python3 tools/pull_icons.py [IDs…]` and
  `godot --headless --path . --import`. A new ability also needs its Icon cell on the
  sheet (then re-import the sheet); a new item file, `icon = ExtResource(...)` (or run
  `tools/once/link_item_icons.py`). Take a gap off `KNOWN_GAPS` in the test once its art
  is in. Never merge `art-drafts`.
- Tests: `tests/unit/test_icons.gd`. Screenshots: `tests/visual/icon_shots.tscn` (action
  bar, trees, inventory with every rarity, tooltips, spellbook, ground loot, boss
  summary, roll and trade windows, at both sizes).

## Stances (branch `feature/stance-rework`, 2026-11-23)

User brief, five phases. Abilities are learned and cast through **stances**: each
bending element (Fire, Earth, Water, Air) has 5 stances with 4 branch abilities each.
Checklist: `docs/playtest-checklist-stances-and-effects.md`.
- **The sheet** (`design/Ability_Tree.xlsx`, importer `tools/ability_tree_importer.gd`):
  columns **Key (stance → branch)** (e.g. `2 → 3`; a stance-entry cast or a passive is
  marked there), **Unlock Step** and the Tiers tab's **Step Points**; `AbilityDef.stance`,
  `branch_key`, `entry_cast`, `passive`, `upgrades` (its first prerequisite ability),
  `mastery_levels` ("X Mastery 200 / 400 / 600"). Removed ids F13, E10, E12, A08 (merged;
  their scrolls become the merge target's, `CharacterData.RENAMED_ITEMS`). The importer
  checks the 5 × 4 grid per element, entry casts, passives (no cooldown, no timing bar;
  a hitbox is a warning) and the step rule.
- **Tier rule (new):** Mastery Required = tier base 0 / 100 / 225 / 375 / 550 + Unlock
  Step × the tier's step points 25 / 30 / 35 / 40 / 50. Fire, Earth and Air copy Water's
  steps (2026-11-23). New characters start with 25 permanent Mastery in their element
  (`StartingElementDef.starting_mastery`).
- **Act I gives tier 1 only;** beating the Silent Shaft (the Foreman) gives the first
  tier-2 scrolls (`tools/once/act1_tier1_rewards.py`).
- **Since 2026-11-28 (water physics, phase 2) the controls below are replaced:** every
  learned ability sits on the action bar again (stance entries are gone; old ones are
  dropped on load and their abilities placed again). Pressing a bending ability while not
  in its stance enters that stance instead of casting (`PlayerInput.needs_stance`); the
  next press casts; one from another stance switches stance. A press during the ability's
  own timing bar still plays the bar. A corner badge on each bending slot shows its stance
  number in the element's colour, lit while that stance is held; the stance panel is
  hidden. Unchanged: the hero stays in the stance after casting; Shift and crowd control
  leave it; entering doesn't start the global cooldown; entry casts still fire when off
  cooldown; stances are host-validated intents in each hero's snapshot (the host still
  switches stance itself when a cast arrives from another one). **Each character keeps its
  own action bar** (`SettingsStore` section `action_bar.<name>`; a new character starts
  empty with the shared layout's keybinds), and the main menu's **Delete** removes a
  character after a confirmation ("Delete <name>? This can't be undone."), with its bar.
  Tests: `tests/unit/test_hotbar_stances.gd`; screenshots `tests/visual/hotbar_shots.tscn`.
- **Controls as built 2026-11-23** (`PlayerInput`, `ActionBarModel`):
  - Out of a stance, 1–0 are the action bar. Stances are bar entries
    (`stance:<Tree>:<n>`); your element's 1–5 start in slots 1–5, other elements' in
    free slots; any stance can go in any slot. Bending abilities left the bar once.
  - A stance key enters that stance (entering never starts the GCD); in a stance keys
    1–4 cast its branches (`WorldSim.stance_ability`) and you stay in it; 5–0 keep their
    slots (another stance key switches). **Shift** leaves. Bar pages are **Ctrl+1–6**.
  - Entry casts when entered and off cooldown: Fire 1 Fire Punch, Earth 1 Seismic Stomp,
    Water 5 Octopus Form.
  - Crowd control drops the stance: stun, silence, root, sleep, knockback, pull, a fall;
    so does death. Casting a bending ability from the bar takes its stance.
- **Network:** a `stance` intent (tree, n, target, aim); the host validates and keeps
  `Hero.stance_tree / stance / stance_at`, sent in snapshots (`stance`).
- **Stance panel** (`ui/hud/stance_panel.gd`) above the action bar: element, stance number,
  the 4 branches with icons and cooldowns. Stance slots draw the element's colour.
  Branches not in the game yet are crossed out ("not built"); hovering lists the four.
- **Entry animations:** one table, `CreatureArtDef.stance_anims` (`pl01_art.tres`): Fire 1
  fire_punch, Earth 1 earth_root then earth_hold, otherwise cast (`stance_anim_default`).
- **Stance looks** (`CreatureArtDef.stance_looks`, drawn while held, from the host time
  the stance was taken):

  | | 1 | 2 | 3 | 4 | 5 |
  |---|---|---|---|---|---|
  | Fire | ring of fire FX-15-2 (turns, flat) | flame ribbon FX-15-1 (spins) | heel flames FX-15-3 (flicker) | small sun FX-15-4 (bobs) | the fire dragon (code ribbon, see below) |
  | Earth | stone ¼ | ½ | ¾ | all stone | faint ring (FX-15-9 not approved) |
  | Water | faint ring (FX-15-10) | hoop FX-15-11 (bobs) | sphere FX-15-12 (orbits) | faint ring (FX-15-13) | octopus arms FX-13-21 (behind, sways) |
  | Air | faint ring (FX-15-14) | faint ring (FX-15-15) | air ball FX-14-5 (orbits) | faint ring (FX-15-16) | wind column FX-15-17 (see-through, flickers) |

  Earth's stone covers the body from the feet up: `coverage` in
  `view/shaders/creature_recolor.gdshader` (looks `stone_25`, `stone_50`, `stone_75`,
  `stone`); the Stone Guard buffs use the same levels (Stone Skin ¼ today; Boulder
  Shield ½, Mountain's Stand ¾, Earth Armor full once built). A buff and a stance: the
  one with more stone shows. Rings around the hero are split: the back half behind the
  hero, the front half after the ground it lies on.
- **Scorch (F22)**, the example new stance-1 ability: enemy within 5, burns 6 s (small
  damage each second) and +15% damage taken (`scorched`); flames drawn in code
  (`BuffDef.code_fx` "flames") and a debuff icon on unit frames (`BuffDef.icon`,
  `icon_text`; `assets/icons/buffs/scorched.png`).
- Tests: `tests/unit/test_stances.gd`, `test_ability_import.gd`, `test_first_abilities.gd`.
  Screenshots: `tests/visual/stance_shots.tscn` (phases 1–5; `SHOTS_ONLY=rot|p4|p5`).

## Water stance 1 rope, Water Whip and the Water Pouch (branch `feature/stance-rework`, 2026-11-26)

User brief: physics-driven water, ported from `docs/reference/water_whip_reference.html` (the
source of truth). Waterbending: the water never attaches to the hand; it lives in the
bender's space. Replaces the Verlet whip of 2026-11-25 (removed).
- **The rope** (`view/water_rope.gd`, `WaterRope`): 24 Verlet points in 2.5D (ground x, y and
  height z; screen = (x, y × 0.5 − z) × WATER_SCALE, our 2:1 view instead of the reference's
  0.4), the reference's states in order: idle (Water stance 1: a loop every 3 s at waist
  height, radius 24, a ripple rolling along it) → spin (near throws) → fly (a timed Catmull-Rom
  throw, pull-back over the shoulder when near, accelerating, impact 30 frames = 0.5 s after the
  cast, near or far) → pour (whole until point 12 arrives, each point splashing off) → fall →
  regroup (the farthest point becomes the front; strays over 12 px soak in, keeping at least 8)
  → rise → return (one Bézier, out to the hero's left, into the entry point on the right along
  the orbit's tangent, speed by length, rebuilt on the way and whole before the mark) → wrap
  (the orbit brakes to its 3 s loop) → idle. Plus `drain`: leaving the stance, the water flows
  back to where it came from. A cast while the water is still out snaps it onto its orbit and
  throws at once (the cooldown is shorter than a return).
- **Every constant** under the reference's name: `content/effects/water_rope_settings.tres`
  (`WaterRopeSettings`), plus `WATER_SCALE` (1.0: the reference hero is ~36 px, ours ~34 art px),
  `K` (0.5), `HIP_Z` (12), `FORM_EVERY` (3) and `REBUILD_EVERY` (4).
- **Water comes from** the hips (the pouch) or, within 3 tiles of a water tile, from the
  water itself: the orbit forms point by point from there; lost points are rebuilt from there
  on the way home, chasing the tail at the rope's own speed.
- **Per hero** (`view/water_ropes.gd`, `WaterRopes`, owned by WorldView): a rope while the host
  says the hero has one (`Hero.rope`, in snapshots); Water Whip's effect event
  (`water_whip`, `FxDef.Path.ROPE`) throws it at its host time. 60 steps per second of game
  time in `_physics_process` (the game speed slows it too); heroes off screen aren't
  simulated and come back on their orbit. Cosmetic: each player simulates their own.
- **Drawing:** whole art pixels, four colours (outline #0C447C, body #378ADD, highlight
  #9DC5EE, droplets #85B7EB) and grey shadows: rippled slices lit by a sun at the top left
  (dark rim on the shaded side, highlight rows, the second rows inside the body), lit balls
  for the tip and loose points, splash pixels, puddles fading. Each piece is filed under the
  tile it is over; on the hero's tile the water behind the hero goes before it.
- **The Water Pouch** (`content/items/water_pouch.tres`, a bag item, no icon yet): 200 water
  points (`Hero.water`, saved; private in snapshots). Forming the orbit away from water takes
  24 (`CombatRules.water_rope_points`), given back when the stance is left; Water Whip takes 4
  (`AbilityDef.water_cost`, paid when it goes off). Within 3 tiles of water
  (`water_near_tiles`) water is free. No water: no orbit ("No water for the orbit") and Water
  Whip is refused (`NO_WATER`, "No water"). **E** at water (within 1.6 tiles,
  `water_fill_reach`; "[E] Fill Water Pouch") fills it to 200 (`fill_water` intent). New Water
  heroes start with a full one (`StartingElementDef.bag_ids`); older Water heroes get one on
  load; Odo and Tamsin sell it (20 g). Water tiles: `WaterTiles` (`sim/world/water_tiles.gd`,
  also used by the water sound).
- **Water Whip:** damage, mana 6, range 5, cooldown 2 s and the timing bar unchanged; the hit
  lands **0.5 s** after the release (was 0.29 s).
- **Debug:** Escape menu → Gameplay test: "Show water rope points" and "Show the water rope's
  return path". `tests/visual/water_lab.tscn`: a Water hero in stance 1, a near and a far
  dummy, click to throw (the `fx` command), the reference's four sliders, Points / Return
  path / Slow (×1/3), and its readouts; `WATER_SHOTS=<dir>` takes screenshots.
- Tests: `tests/unit/test_water_rope.gd`, `tests/unit/test_water_pouch.gd`.
- **Body anchors** (from 2026-11-25, kept): `content/heroes/pl01_anchors.json` and
  `tools/hand_anchors.py` (guesses, or magenta pixels from the marked Aseprite file).

## Water as a resource (water physics phase 3, branch `feature/water-physics`, 2026-11-28)

User brief and answers. Replaces the rope's water rules of 2026-11-26 (the orbit taking 24
and giving them back, free water near a river for abilities, the instant pouch fill).
Rules in `WorldSim` "Water as a resource" and `WaterBending` (`sim/combat/water_bending.gd`).
- **Two places, both counted by the host and sent in snapshots:** the **stance water**
  (`Hero.stance_water`, public: the Water stance 1 rope, full at 24; the stance 2 hoop,
  full at 33) and the **reserve** (`Hero.water`, private: the Water Pouch, 200).
- **Entering** stance 1 takes nothing at once: the rope builds by the refill below (24
  points in 6.8 s; user rule, 2026-11-28); stance 2 takes stance water first, then the
  pouch, up to 33, and needs 27 in all (`WaterBending.STANCE_2_ENTRY`; refused with "Not
  enough water", also when a stance 2 ability's key is pressed). 27–32 points are spread
  evenly round the same hoop. Within 3 tiles of a water tile the water is free and comes
  from it (drawn flowing from the nearest water tile).
- **Stance 1 refills** one point every 17 frames (0.283 s) from water nearby or the pouch;
  with the pouch empty the rope stops growing. Stance 2 doesn't refill.
- **Leaving:** stance 2 → 1 sheds the points above 24 into the pouch (they spill as
  droplets); leaving the Water stances (Shift, crowd control, death, another element, or
  10 s out of combat without casting: `WATER_STANCE_IDLE_SECONDS`, Water stances only)
  puts all the stance water back in the pouch (capped at 200); the rope flows back to the
  hip, tail first, over 0.5 s (`WaterRope.drain`).
- **Abilities** of Water stances 1–2 (`WaterBending.uses_stance_water`) need at least 1
  point and at least their `water_cost` in the stance ("Not enough water", `NO_WATER`);
  the water they use is gone. **Power** = 0.2 + 0.8 × stance points ÷ full, from the
  points the ability was cast with (`Hero.cast_water`, recorded when paid), applied to
  damage, healing and shields in `AbilityPower.amount`; tooltips show "Water: x / full in
  stance n, power y%".
- **The pouch at water (E):** fills at 20 points a second (10 s from empty, less from
  part full); moving or losing health stops it ("Filling Water Pouch" over the hero).
- **The hoop** (`WaterRope` `goal`, `sb`, `wrap`; settings "Stance 2 hoop" in
  `WaterRopeSettings`, from `water_stance2_demo_approved.html`): the rope rises to the
  chest over 48 frames, points join every 4 frames, it closes once every point is there
  (the closing link fades in over 20 frames), one lap every 4 s, breathing and tilting,
  ripples fitted round it, a shadow a pixel wider. The FX-15-11 sprite is no longer drawn.
  Uses the existing hero art (no arm pose).
- Tests: `tests/unit/test_water_pouch.gd`; screenshots `tests/visual/water_resource_shots.tscn`.

## Ability effects from the approved art (stance rework phase 3, 2026-11-23)

- **Source:** only `approved/<KEY>.png` on `art-drafts`; animation frames
  (`art/<ID>/<KEY>+<action>_<date>_<n>.png`) are used automatically once the art bot makes
  them. `tools/once/make_effect_sheets.py` copies them to `assets/effects/` and writes
  missing `content/effects/<name>.tres`. No piece has frames yet: every still moves in code
  (`FxDef.motion`: spin, bob, orbit, flicker, sway, pulse, drop; `fade_out`, `hold_seconds`).
- **Which ability shows what, by role:** `content/effects/ability_effects.json` (cast,
  hands, projectile, land, tiles, held; a role set in a behaviour file wins), linked at
  load by ContentDB (`AbilityDef.fx_cast / fx_hands / fx_projectile / fx_land / fx_tiles /
  fx_held`; a held effect goes on the ability's buffs as `BuffDef.fx`).

  | Element | Effects (approved key → ability) |
  |---|---|
  | Fire | FX-11-1 Fire Punch / Blazing Combo burst · FX-11-2 Fire Dart · FX-11-8 Flame Dash trail · FX-11-10 Jet Propulsion · FX-11-12 Phoenix Kick ring · FX-11-13 Fireball · FX-11-14 Solar Zenith halo · FX-11-16 Flame Wheel · FX-11-17 Inferno / Burning Ground flames · FX-11-19 Combustion Blast |
  | Earth | FX-12-3 Metal Shards · FX-12-10 Boulder Crush (drops) |
  | Water | FX-13-1 Healing Touch ball, FX-13-2 splash · FX-13-3 Water Shield · FX-13-4 Frost Shard · FX-13-8 Ice Prison · FX-13-9 Revive / Tidal Resurgence · FX-13-12 Ice Wall · FX-13-13 Spirit Water · FX-13-15 Steam Veil · FX-13-19 Rising Tide · FX-13-20 Ice Spikes · FX-13-21 Octopus Form |
  | Air | FX-14-1 Air Blade · FX-14-2 Air Step puff · FX-14-4 Stolen Breath · FX-14-5 Air Scooter · FX-14-8 Air Sphere · FX-14-9 Wind Walk · FX-14-10 Vortex / Eye of the Storm · FX-14-11 Updraft · FX-14-12 Suffocate · FX-14-14 Tornado · FX-14-15 Cyclone Spin · FX-14-18 Hurricane |

- **Projectiles** turn to their flight without blurring: 32 pre-rotated cells made with
  RotSprite (`<name>_rot.png`; `FxDef.drawn_angle`, `rot_sheet`, `rot_steps`). Drawn
  directions: Fireball and Fire Dart south (90°), Frost Shard north (−90°), Metal Shards
  right (0°), Air Blade 30°. The Tornado is drawn upright. Everything else is never turned.
- **`fx <ability id or name>`** (debug console): plays an ability's effects from your hero
  toward the cursor, no damage or cooldown; `fx <Tree>:<n>` holds a stance.
- Most of these abilities aren't built yet: their effects show only through `fx`.

## Code-drawn effects (stance rework phase 4, 2026-11-23)

Effects that change shape with distance, angle or terrain, or need no art, built each
frame from small pieces on FxDef / FxPainter / WorldView's back-to-front pass.
- **Draw order:** no Line2D or particle nodes. A ribbon is cut into quads, one strip copy
  at a time (`RibbonPath.quads`); every piece (quad, front piece, particle, shaded tile) is
  filed under the tile it is over and drawn with that tile's actors, so walls and pillars
  in front cover them. Ground pieces (wet, sand, cracks, the shock ring) go before the
  tile's actors, back halves of rings too, front halves after. Since 2026-11-25 (user
  report: looks cut off by the ground) bare ground at or below a tile's height never
  covers what stands there (`WorldView._covers`: only higher tiles, props, objects and
  graveyard markers are drawn again over actors and effects), so feet, rings and
  effects on open ground show whole and walls and houses in front still hide them.
  Seismic Sense is a screen shader on a canvas layer over the world, under the HUD.
- **FxDef fields** (`data/defs/fx_def.gd`):
  - Ribbon: `ribbon`, `path` (LINE / WHIP / FIGURE8 / COIL), `strip_rect`, `tip_fx`,
    `head_fx`, `impact_fx`, `hand_fx`, `thickness` (whole pixels), `scroll_speed`, `curl`,
    `extend_frames` / `snap_frame` / `retract_frames`, `jag_seconds` / `jag_amount`, `tint`.
  - Front: `front`, `ray_spacing` (0.25), `front_speed`, `trail_fx`, `trail_fade_seconds`,
    `blocked_fx`, `piece_scale`, `wets`.
  - Tiles: `tile_mode` (WET, BURNING, SAND, RING, CRACKS, SANDSTORM, SENSE, RAIN),
    `tile_tint`, `tile_seconds`.
  - Effect data: `tools/once/make_code_effects.py` (writes missing files).
- **Hand points by hand** (2026-11-25, user request): `tools/once/make_hand_point_aseprite.py`
  writes `art/heroes/PL-01/<anim>_hand_points.aseprite` (the game's 48×48 cells, feet on
  (24, 38), a tag per facing, an empty "Hand <FACING> (#FF00FF)" layer per facing, the
  palette magenta) for the user to mark the hand; water_whip first.
- **Hand points** (`CreatureArtDef.hand_points`, `hand_point`): measured on the strike
  frame of water_whip, air_palm, fire_punch, water_heal, air_gust and fire_kick, for six
  facings (the furthest opaque pixel toward the facing in the body band); south and north
  hide the hand, so they are midway between their diagonals; other animations use
  water_whip's.
- **Ribbons** (`view/ribbon_path.gd`): whips (Water Whip, Fire Whip) curve to the side the
  seed picks, deep close up and nearly straight at full range, reaching out, snapping
  (Water Whip's hit lands on the snap: `hit_frame` 7 at 24 fps) and pulling back; streams
  and jets (Fire Stream, Water Jet) straight, doubled, flowing, with a head and an impact;
  Leeching Tide flows back to you; Metal Cable taut with sparks (its hook FX-16-17 isn't
  approved); Lightning Bolt re-jagged every 0.05 s; Lightning Redirection a figure 8 from
  the centre, up first. Strips (`tools/once/make_effect_sheets.py` STRIPS): each cut to
  its most seamless span (the columns whose ends match best, empty end columns excluded):
  water whip 10 px (cut from the lash's left bar, FX-09-1), fire 49 px (FX-16-4), cable
  52 px (FX-16-16), lightning 50 px (FX-16-19), Air Blade trail 29 px (FX-16-35).
- **Fronts:** Breath of Fire (FX-16-23, blocked FX-16-24), Tidal Wave (FX-16-28), Water
  Pulse (FX-16-25, blocked FX-16-29), Gust (FX-16-30) and Air Blast (Gust's at double
  size). The host fans rays across the cone, or lays them across the line's width, a
  quarter tile apart (`FrontRays`); each stops where `Hitbox.clear_distance` stops a shot,
  so a pillar in the cone leaves a gap. Pieces at the tips, a fading trail, the blocked
  piece where a ray stops; near-duplicates (within a sixth of a tile) dropped. Waves wet
  the tiles behind them. Gust and Air Blast lost their FX-08-5 spirals (Air Palm keeps its).
- **Tiles and the screen:** wet ground (a glossy tint; FX-16-37 not approved), burning
  ground (Burning Ground, Inferno: FX-11-17 flames on each tile, each side's edge at the
  average of its two neighbours, full where they burn, 25% where open; FX-16-38/39 not
  approved), Sinkhole sand (a tint; FX-12-5 not approved), Seismic Stomp / Rumbling Taunt
  (a ring lifting and brightening the real tiles), Earthquake / Tectonic Shift (cracks,
  shaking), Sandstorm (swirling sand), Healing Rain (drops + wet ground; FX-13-17 not
  approved), Seismic Sense (greyscale and rings of light from the hero). Height changes
  (pillars, walls) have no extra effect. Bloodbending draws nothing.
- **Particles:** embers, drops and sparks off ribbons and fronts from a fixed pool of 384
  (`view/fx_particles.gd`), cosmetic and each player's own.
- **The fire dragon** (Fire stance 5): a flame ribbon (FX-16-4 stands in for FX-16-40/41/42,
  not approved) coiled around the hero; a stance-5 Fire cast uncoils it toward the aim
  over 0.4 s, it fades, and returns coiled.
- **Network:** the host adds to each effect event what a shape needs
  (`WorldSim.shape_fx_data`): a ribbon's end (clipped at the first unit or blocker), the
  ability's reach and a seed (from the cast, not the combat dice); a front's rays with
  where each stopped; a ring's radius. Clients decide nothing that changes a shape.
- Used in play today: Water Whip, Fire Whip, Water Pulse, Leeching Tide, Gust, Air Blast,
  Burning Ground, Seismic Stomp (and Stone Skin's stone level). The others through `fx`.
- Tests: `tests/unit/test_code_effects.gd` (whip curve, stream stops, front rays and the
  pillar gap, burning edges, clients rebuilding the same shapes), `test_ability_effects.gd`.

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
  30% with the rarity's colour. Then the item's icon (since 2026-11-22; the name in ink
  for items with no art).
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
  (– / +) that folds the whole panel down to its heading, moved or not (since
  2026-11-15; once dragged it used to keep its full-size frame);
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
  - Manual (the user's): Slash 1 s (tap 0.35–0.65, crit 0.45–0.55), Water Whip 3 s
    (hold 0.45–2.75 since 2026-11-21; was 0.75–2.75), Quick Shot 2 s (hold
    0.25–1.75), Aimed Shot 4 s (tap 0.2–0.6 with crit 0.35–0.45, then hold 1.0–3.75).
    Fire Punch is instant since 2026-11-21 (it was 1 s, tap 0.7–1.0, crit 0.9–1.0).
  - Rock Throw (2026-11-21, AI draft): 3 s, tap 0.6–2.6, crit 0.9–1.1, the two-press
    throw (see **Ability animations and effects**); was 1.6 s, tap 1.1–1.5.
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
  - A stun, an interrupt, a knockback, a fall, the target leaving range or Esc
	cancels it (cooldown not spent). Walking doesn't (since 2026-11-21): it slows you
	to the ability's Cast Move Speed (see **Moving while casting**).
  - Enemies cast these abilities without a bar.
  - **On or off** (2026-11-21): the Escape menu's Gameplay test tab has a "Timing
	bars" switch (`timing_bars` intent, host-only like the game speed, debug builds;
	`CombatRules.timing_bars_enabled`, sent in snapshots). Off: abilities go off at once.

## Moving while casting (2026-11-21)

User request. Walking during a cast bar, wind-up, channel or timing bar no longer
cancels it: the hero keeps casting and walks at the ability's share of their current
speed (`Mover.cast_move_factor`, inside `Mover.speed_of`, so client prediction agrees;
Speed stat, haste and slows still count).
- **Per ability:** `AbilityDef.cast_move_speed` (0–1; < 0 = the default), from the sheet's
  **Cast Move Speed (%)** column (Abilities tab, after Pierce; 0–100, checked on import;
  empty = default). Default `CombatRules.cast_move_speed_default` = 0.3. No ability sets
  its own yet. A note on the Timing Rules tab explains it
  (`tools/once/add_cast_move_speed_column.ps1`).
- **Still cancels:** a stun, an interrupt, a knockback or pull, a fall, the target
  leaving range or sight, another ability's key during a bar, and **Esc** (new,
  `cancel_cast` intent: the first thing Esc does after cancelling an aim; a cast bar or
  timing bar gives its global cooldown back, a wind-up or channel stays paid).
- Enemies stay planted while they attack.
- Balance bots cancel their cast (Esc) before running out of a telegraph and don't start
  a new one during that run. The "dodging halves the HP lost" target, already failing on
  `main` (38% vs 51%), moved to 55% vs 51%: a dodging bot now cancels its bar for every
  quick wolf bite; for the combat pacing pass.
- **Playing a bar (since 2026-11-21):** right-click, **Space** (`timing_press` action,
  reserved from keybinds) or the ability's own hotkey pressed again (the 2026-11-15
  second press; removed earlier on 2026-11-21, restored the same day at the user's
  request); letting go of whichever started it ends a hold. Another
  ability's hotkey stops the bar unplayed (`cancel_bar` intent: nothing paid, its global
  cooldown given back) and starts the new ability. An aimed ability without a bar
  (Lunge, Flame Dash, Raise Pillar, Earth Wall) still fires when its key is let go, and
  now also on a second press (after a click on the bar). Held keys never count (no
  key repeat).
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
| Wolf | HP 200 (free movement; was 230), PhysAtk 12, PhysDef 5, Evasion 5, Jump 1; aggro 4, leash 10; 50 XP; respawn 30 s; 0.65 s/tile; 0.3 s reaction | — |

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
| Goblin Shaman | 2 | Kiter | HP 130 (free movement; was 160), MagAtk 18, PhysDef 5, MagDef 10, Jump 2; aggro 5 | Shadow Bolt: line 5, 9 tiles/s, 10 + 1.0×MagAtk magical, 2.5 s | 0.9 s / 0.3 s | 70 / 3 | 4–10 g, Frostweave Robe 4%, Acolyte's Leggings 4% | west hill (6,8) (9,6) |
| Bandit Brute | 3 | Melee | HP 320, PhysAtk 22, PhysDef 15 | Crushing Blow: front, 24 + 2.0×PhysAtk, 3.5 s | 2.0 s / 0.4 s | 90 / 3 | 6–14 g, Greataxe 4% | south-east (20,20) (24,21) |
| Fen Skirmisher | 4 | Flanker | HP 220, PhysAtk 16, PhysDef 8, Eva 12, Jump 2 | Quick Slash: front, 8 + 1.0×PhysAtk, 1.5 s | 0.6 s / 0.3 s | 100 / 3 | 5–12 g, Ranger's Gloves 3% | plateau (26,5) (23,3) |
| **Old Grizzlehide** (elite) | 5 | Melee, patrols | HP 1400, PhysAtk 26, PhysDef 25, MagDef 15, Acc 5, Jump 2; aggro 4, leash 12 | Cleave: arc, 12 + 1.0×PhysAtk, 2.5 s · Charge: front 2–4 tiles, dashes up to 3 tiles then 15 + 1.0×PhysAtk, 12 s | 1.0 s / 0.3 s (patrol 0.8 s/tile) | 400 / 10 | 30–60 g, Grizzlehide Mantle 25%, Ranger's Gloves 30%; respawn 5 min | loop (8,17) → (12,12) → (22,12) → (20,16), crossing the north bridge |

XP by level: +10% per enemy level above you (max +50%); from 3 levels below, −20% per
level (3 below = 80%), never under 20%. Balance report (bots stand still and always face the enemy): a level-3 sword
hero who just trades blows with a Brute loses, but wins by healing itself (~95% HP lost) or with a shield, staff hero beats a Shaman at level 2 (~40%),
sword hero beats a Skirmisher at level 4 80% of the time. (Grizzlehide's group target was
removed with every boss target, 2026-11-19.)

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
sim/             world (all zones), world_sim (one zone) + grid/ stats/ combat/ progression/ entities/ ai/ quests/ dungeon/ loot/ (ground drops, boss rolls, binding) social/ (requests, trades)
net/             intents, snapshot, server_session, client_session
data/defs/       Resource scripts (*_def.gd, stat_block.gd, combat_rules.gd)
content/         items/ abilities/ buffs/ enemies/ loot/ npcs/ quests/ heroes/ zones/ encounters/ rules/ audio/ (.tres),
                 dialogue/act1.json (every line of dialogue, by id)
audio/           music/ (OGG), ambience/ (OGG), sfx/<category>/ (WAV); see AUDIO_SPEC.md
assets/tiles/    tilesets: one folder each (tile images + tileset.json)
assets/creatures/ creature sprite sheets (one folder per creature; art data in content/creatures/)
assets/heroes/   hero sprite sheets (art data in content/heroes/; source frames in art/heroes/)
assets/effects/  effect sprite sheets (FxDef data in content/effects/; source frames in art/effects/)
assets/icons/    ability and item icons (pixel art; tools/pull_icons.py brings them from art-drafts)
assets/ui/       interface art (the menu book)
art/             uploaded source art (zips, .aseprite, audio/ masters; ignored by Godot, never exported)
view/            world view, iso tile renderer, actor views, camera, decor painter (placeholder objects)
ui/              main menu, stores (characters, world, settings), HUD (action bar, unit frames,
				 inventory, character sheet, spellbook, ability trees, dialogue, vendor, loot,
				 quest log, tracker)
editor/          map editor (ZoneEdit, ZoneSaver, ZoneCheck, EditorSession, MapEditor, EditorOverlay)
input/           player input → intents
scenes/          main.tscn and other top-level scenes
tools/           ability spreadsheet importer (xlsx reader, converter, CLI), behavior generator,
                 write_audio_spec.gd (sound key list in AUDIO_SPEC.md), write_quest_list.gd (docs/quests.md)
design/          Ability_Tree.xlsx (source of truth for abilities); Item_Database.xlsx (generated: every item,
                 its stats, growth and every source: tools/item_database.tscn + tools/make_item_database.py)
tools/once/      one-off content conversions and generators (kept for the record)
tools/perf/      headless profilers: frame time per map, sim cost per tick
tests/           unit/ integration/ balance/ (GUT, test_*.gd; balance builds in balance_scenarios.gd), net/run_party_check.sh (loot, rolls, binding, trades, duels with 3 processes),
				 net/ (multi-process check), visual/ (screenshot scene), fixtures/ (legacy M1 hero)
docs/            quests.md (every quest, generated), exporting, local multiplayer testing, playtest checklists (M2, M3, tiles, wolves, testing grounds, Sunscale Drake, audio, Act I, Act I zones, Act I quests, Act I full, free movement, map editor, hero art), ability import, tilesets, quests and dialogue, the free movement plan, the map editor
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
	  dodging the 0.6 s wind-up wins; a level-4 Lunge sword beats a Skirmisher.
	  (Grizzlehide's target removed 2026-11-19 with every boss target.)
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
| 2026-11-28 | Water physics phase 3: water as a resource (stance water + pouch), the stance 2 hoop | User brief and answers (see **Water as a resource**). User answer (2026-11-28): entering stance 1 builds the rope by the 17-frame refill only (7 s is fine; my first build took 24 at once). My choices, to confirm: only stance 1 refills (stance 2's refill isn't in the brief); the 10 s idle drop applies to the Water stances only and a cast bar or combat keeps the stance up; power uses the stance water at the moment the ability is paid; the pouch fills at capacity ÷ 10 per second, stopped by moving or losing health; without a pouch, water put back is lost; the hoop's new points come from the hips (or the river), not from the tail as in the demo; test heroes and balance bots that use Water abilities now carry a full pouch. |
| 2026-11-28 | Water physics phase 2: stances off the hotbar; a bar per character; deleting characters | User brief and requests. My choices: the second press of a timing bar is unchanged (same key, Space or right-click while that ability's bar runs; it never re-enters the stance); bending slots get a small stance badge (element colour, stance number, lit while held) and the stance panel is hidden; the host keeps switching stance on a cast from another stance (old clients, tests) while the client only switches; a new character's bar starts empty and takes the shared layout's keybinds; keybinds are saved with each character's bar; deleting a character also forgets its bar. Abilities whose stance can't be entered (stance 2 without water, phase 3) will show blue like "not enough mana" with "Not enough water". |
| 2026-11-28 | Water physics pass (branch `feature/water-physics` from `feature/stance-rework`), phase 1: render fixes | User brief and screenshot. Shadow: black at 30% (`WaterRopeSettings.SHADOW_DARKEN`), which darkens what's under it by 30%, each screen pixel once a frame (`WaterRopes._shadow_seen`). The wall showing through in a box round the hero, and the flower bed's lower faces: the terrain cache redraws a covering tile (a wall, a prop) whole, including lower faces the cached picture hides under the bare ground in front; since 2026-11-25 that ground was never redrawn, so they showed (the rope's pieces filed behind the hero pulled the redraw box back to the house). Now the bare tiles in front of a redrawn tile are put back right after it, before anything in front is drawn (`WorldView._collect_cover` `patch`). The faint stance ring under Water stance 1 is gone (the rope is its look). User answers for later phases: the river stays a water source and stance water visibly flows from the nearest water tile when entering a stance; the pouch stays and refills fully in 10 s, interrupted by damage or moving; "Not enough water" counts the stance's water; stance 2's pose uses existing hero art; the whip's 1.5 s bar also decides when the water returns (no press by 0.5 s: the water stays on the ground until the press); Frost Shard's sprite scaled 50%; delete characters from the main menu with a confirmation; hotbars saved per character. |
| 2026-11-25 | Playtest fixes: Water Shield built; bare ground no longer covers effects; unbuilt branches marked; a hand-point Aseprite file | User report and requests. My choices: Water Shield's shield size from the tier default and the sheet's Scales With (like Boulder Shield), its splash 10 + 0.6 Magic Attack to enemies within 1.5 tiles when the shield is used up (not when it times out), 10 mana; covering rule: only tiles higher than the ground an actor or effect stands on, or holding a prop, object or graveyard marker, are drawn again over it (the ground bucketing of ring halves removed); unbuilt stance branches crossed out with "not built" and a hover list; the Aseprite file has one empty layer per facing, a tag per facing, the palette set to #FF00FF. |
| 2026-11-25 | Threat and tanking merged into the stance rework (`feature/threat-tanking` into `feature/stance-rework`; the art bot and Eloi's branch left out) | User request. My choices where the two designs differ: the stance sheet wins (it is the newer design): cooldowns from the sheet; Metalbending is the sheet's debuff (−20 Physical Defense, speed halved, 8 s) without the pull or the Stone Skin taunt; Seismic Stomp keeps the threat branch's light damage (it keeps threat after the taunt; the sheet's text only says taunt); Earth Armor's recast (Fortress) isn't built; Rock Throw keeps threat ×3. See **Threat and tanking**. |
| 2026-11-23 | Stance rework, phases 2–5: stance controls and looks, effects from the approved art, code-drawn effects, tests and docs | User brief and choices: other elements' stances can go in any of slots 1–0; Shift leaves; pages on Ctrl+1–6; "start it" for phases 3, 4 and 5 after the phase 4 fields and draw order were shown. My choices: Stone Skin turns a quarter of the body to stone (the Stone Guard levels); rings around the hero split behind / in front; Octopus Form drawn upright behind the hero (flat on the ground it was cut by the tiles beside it); unapproved looks are a faint ring in the element's colour; code motion per still (listed in **Ability effects from the approved art**); 32 RotSprite turns per projectile, made offline; one JSON table of effects by role; Scorch's icon drawn by hand (16 × 16); `fx` also holds stances; strips cut to their most seamless span automatically; burning edges at the average of their two neighbours' sides; Gust and Air Blast lose their spirals; ribbon seeds from the cast, not the combat dice; the dragon's polished transformation proposed (the ability's effect from its head), not built. See **Stances**, **Ability effects from the approved art**, **Code-drawn effects**. |
| 2026-11-23 | Stance rework, phase 1 follow-up: Act I gives tier 1 only; Fire, Earth and Air copy Water's unlock steps; dodging and Lunge balance targets removed | User decisions. Every Act I loot table's scrolls are built tier-1 ones of the same element (`tools/once/act1_tier1_rewards.py`: Fire Whip → Fire Dart, Flame Dash → Sun Warrior's Breath, Fireball → Scorch, Burning Ground → Fire Kick, Blazing Combo → Fire Punch, Soothing Mist → Healing Touch, Leeching Tide and Water Pulse → Water Whip, Tidal Blessing and Ice Spikes → Frost Shard, Air Blast → Gust, Earth Wall → Raise Pillar; chances kept); the Foreman (beating the Silent Shaft) drops the built tier-2 scrolls, 20% each (Blazing Combo, Burning Ground, Soothing Mist, Leeching Tide, Tidal Blessing); shops sell Scorch Scroll instead of Scroll of the Current; quest 1-04 gives Water Frost Shard, 1-06 gives Water and Air no scroll (no third built tier-1 one yet), the finales (1-07, The Beast of Greenfields) offer Scorch, Frost Shard, Raise Pillar or Air Step. Unlock steps: each Fire, Earth and Air ability unlocks like the Water ability in its stance slot (`tools/once/stance_copy_water_steps.py`; only stance 1 changed: Fire Kick, Stone Skin, Gust 0; Sun Warrior's Breath, Raise Pillar, Air Step 25; Scorch, Metal Shards 50; Air Blade 50). Removed from `tests/balance/test_balance.gd`: dodging halves the HP lost, heals + dodges beat the Brute, level-4 Lunge beats a Skirmisher (the report still measures them). The 25 starting Mastery stays (the starting kit no longer needs it; it opens the step-1 abilities). |
| 2026-11-23 | Stance rework, phase 1: importer and abilities (branch `feature/stance-rework`, from `design/stance-rework` + the icons branch) | User brief and choices ("all the recommendations look good"): new characters start with 25 permanent Mastery in their element (`StartingElementDef.starting_mastery`; Fire Kick, Stone Skin and Gust unlock at 25 now); the four merged abilities' scrolls become their merge target's scroll (`CharacterData.RENAMED_ITEMS`; no AP kept, none were in the game); Ocean Spirit uses the Abilities row (225 / 375 / 550); Overheat's prerequisite "Spark" is Scorch (sheet fix). My choices: provisional Projectile Speed / Size for the four new projectiles (Fireball 12 / 0.4, Metal Shards 16 / 0.25, Metal Cable 18 / 0.2, Air Blade 18 / 0.3; `tools/once/stance_sheet_fixes.py`), to confirm; a passive with a hitbox (Ocean Spirit, Tidal Resurgence, Eye of the Storm) is a warning, not an error; Fireball also explodes where its flight ends or terrain stops it (impact radius 1); Fire Whip's pull uses the usual weight rule; Earth Wall's trench lowers the row just in front of the wall for its 12 s; Air Step's glide (10 s, a second buff) crosses holes in the map at the height it left from and turns drops into glides (no fall); Scorch: 0.3 × the tier default over 6 s (ticks each second), 6 mana, +15% damage taken from all sources (`scorched`). Shop, loot and quest fixes wait for the user (phase 1 report). |
| 2026-11-22 | Icons for every bending ability and item, from the art-drafts icons/ folder | User brief and choices ("go with your recommendations"): the 20 element set pieces with no art are known gaps showing the placeholder (with a warning), like the five Legs items (which keep their name); whole-number scales count screen pixels (1× at 720p, 2× at 1080p where a slot fits it); 1× rich-text icons accepted in the loot feed and lists (taller lines). My choices: an Icon column on the sheet; `ItemDef.icon` / `AbilityDef.icon`; per-file import settings (Godot has no folder presets) written by `tools/pull_icons.py` and checked by a test; the action bar shows the icon instead of the name (weapon arts keep their name); tree nodes closer together (14) with 12 px text beside the icon; locked or not-in-game abilities in greyscale; ground loot icons at half the world art's pixel size (full size covered the hero); a warning once per run. **Need art:** `acolytes_leggings`, `emberstitch_trousers`, `riverweave_breeches`, `quarrymans_trousers`, `breezecloth_leggings` (no leg art in the sheets), and the 20 element set pieces (`quarrymans_gloves`, `_hood`, `_boots`, `granite_ring`, `bedrock_charm`; `riverweave_gloves`, `_hood`, `_sandals`, `tidestone_ring`, `pearl_pendant`; `emberstitch_gloves`, `_cap`, `_boots`, `cinder_ring`, `ashglass_pendant`; `breezecloth_wraps`, `_hood`, `_shoes`, `gale_ring`, `feather_charm`). |
| 2026-11-21 | First sound effects, zone music and water near the hero (branch `audio/new-sounds`) | User brief. Theirs: the files (trimmed, levelled; music at -18 LUFS so zones never jump in volume); Healing Touch, Water Whip and Air Palm on `_hit` (their `_cast` plays when the timing bar starts), Gust on `_cast` (no bar); the Mixkit wolf bite shared with the iron wolf (free for games, no credit); the stag's first bellow cut from a 6 s take; "Millbrook / Greenfields" for town and explore in those two zones, "The Crossing", the draft kept for the title screen and zones with no track; the water emitters (approved): radius 10, at most 3, every 0.5 s, 1 s fades, client side, Ambience bus, numbers in AudioConfig. Mine: water = terrains whose tiles the catalog puts in "water" (fords and rocks in water are stone); clusters touch diagonally; a spot that moves under 3 tiles glides (walking along a river would otherwise fade every half second), further it crossfades; level from the grid distance with falloff 1.5 and 0 dB at the water; emitters kept outside the world view so they fade out on a zone change; every enemy pulled into a fight by damage sends `aggro` (not only the stag), once per fight. |
| 2026-11-21 | Pressing an ability's key again during its timing bar plays the bar again, alongside right-click and Space | User request after testing the ability animations: the second press had been removed that morning (Space added instead). Both stay: right-click, Space or the key; letting go of the key ends a hold, as before. |
| 2026-11-21 | Ability animations and effects; Rock Throw two presses; Stone Skin's look and shatter; Fire Punch instant; Water Whip from 0.45 s | User brief (all eight facings, user choice; "defaults fine": the phase model, walking shows the ability's pose, stone look on Stone Skin, my frame rates). My choices: strike frames read off the art (table in **Ability animations and effects**); hits on strike frames without delaying taps, by playing the frames before the strike during the bar and the rest from the strike when it goes off (heroes had no strike timing before: only creatures' `timed_abilities`); Rock Throw keeps a timing bar, adapted (3 s, tap 0.6–2.6, crit 0.9–1.1, no press throws at miss power through a client press at the end, Cast Move Speed 0); the throw and the whip go off after a release delay taken from the art (0.15 s, 0.29 s), paying mana and cooldown then and not re-checking range; the flying rock is the still moved and spun in code (FX-10-2 barely tumbles); effects drawn in the back-to-front pass on the tile under them; stone tint baked once per sheet; the mound cut from stone_shatter by height and colours (thin scraps remain). |
| 2026-11-21 | Timing bars are played with right-click or Space only; the ability's own key no longer plays its bar | User request. My choices: Space is a new reserved action (`timing_press`), so it can't be bound to an action bar slot; letting Space go ends a hold, like right-click; a second press of the ability's key during its bar is ignored (another ability's key still switches). |
| 2026-11-21 | Walking while casting slows instead of cancelling (per-ability Cast Move Speed, default 30%); Esc cancels your cast; a Gameplay test switch turns timing bars on or off | User request and choices: the percentage in a new sheet column, default 30%, of the hero's current speed; stuns, interrupts, knockbacks and falls still cancel. My choices: Esc as the way to cancel a cast on purpose (walking no longer does), giving back a cast's or bar's global cooldown; enemies unchanged; the timing-bar switch host-only like the game speed; balance bots cancel before dodging. See **Moving while casting**. |
| 2026-11-21 | Online fixes: a pushed hero (or charging enemy) no longer stays drawn at the push's end on a joining player's screen; the client's clock runs steadily; movement travels unreliably | User report (jittery online play; after Air Palm the pushed friend stayed put on the joiner's screen while abilities used their real position). Causes: `MoveState.to_dict` kept sending a finished glide (its `duration` outlives it), and a client drew any actor with a glide at its end point forever (the host's own view didn't); the client's clock jumped to each snapshot's time, back and forth with uneven arrival; every input went reliable, so one lost packet held all later ones. Fixes: glides sent only while they last, other actors on a client always follow the snapshot buffer (pushes included); `ClientSession.render_time` runs with real time and leans toward the host's at most 10% faster or slower, jumping only when 0.3 s off, never backwards; `move` intents on an `unreliable_ordered` RPC (`Net._c2s_move`), sent every tick while walking and for 0.5 s after stopping. Checked: `run_net_check.sh` with and without `NETCHECK_DELAY=0.1`, the duel, trade and loot party checks. Three tests already failing on `main` still fail (a dodge balance target, the export probe, the settings window). |
| 2026-11-20 | `docs/quests.md`: every quest in one page, generated from the quest files | User request. `tools/write_quest_list.gd` (`godot --headless --path . -s res://tools/write_quest_list.gd`) writes it: a summary table, then per quest its giver and hand-in (with their maps), prerequisites, items handed over, objectives, rewards (per element too), world flag and offer text. A test fails when it is out of date. |
| 2026-11-20 | Element set rewards for the Act I main quests; no starting weapon; Earth scrolls grow Physical Defense | User request and table: 1-01 Hands, 1-02 Head + a choice of mana or health potion, 1-03 Feet, 1-04 the ring or the next scroll (one pick), 1-05 the charm or a first weapon (one pick), 1-06 the next scroll, 1-07 unchanged; all Common; stats, extras and names as proposed; heroes without an element pick any element's piece. My choices: the other quests' always-given potions stay (1-02's two mana potions became its choice); the "next scrolls" follow each element's unlock order among abilities in the game (Air's second is Air Blast, a tier-2 ability, since Wind Snare isn't built); vendors keep selling weapons; Water and Air scroll growth unchanged. |
| 2026-11-19 | Loot, boss rolls, binding, trading, duels: my choices | User brief (phases 1-5; bosses-only rolls and the branch chosen by the user). Mine: gold + materials copied to fighters (threat table), other drops personal on the ground (300 s, pickup 1.6 tiles, E); the old bag-full loot window removed; Legendary rarity (gold; epic border until drawn); feed and boss summary messages; "key item" = scroll, tree weapon, or gear whose summed core stats beat what a fighter wears there; everyone who chose Need or Greed rolls (all shown), all-pass = nobody gets it, ties re-roll up to 10 times; claim box by character name, delivered on next appearance; Bind on Pickup for scrolls and roll winnings, Bind on Equip for other gear, worn = bound, saves drop the trade window; trade range 6, duel request range 15, 6 trade slots, gold escrowed too, a full bag refuses the swap; duels count as combat (no zone exits mid-duel), idle enemies ignore duelists, the flag lingers 3 s, the end message reaches 30 tiles. |
| 2026-11-19 | Hero hit W / NW mirrored from E / NE | User request (phase 8). The "hit animation" is the getting-hit one (the only `hit` sheet; its NW row was a known flaw). Mirroring is data (`mirror_rows`), applied by the animator for every pick and drawn flipped about the feet, so nothing is duplicated. |
| 2026-11-19 | The Wilds replace the Enemy Testing Grounds | User request (phase 7; "same gate" and "retire with the map" chosen by the user). My choices: the name; four streams, 22 puddles, fords at path crossings plus four per stream so no bank is cut off; bushes as the blocking vegetation (no tree tiles exist); the testing grounds' file moved to `content/retired/` so ContentDB never loads it; the screenshot scene's creature shots staged on Greenfields. |
| 2026-11-19 | Boss balance targets removed | User request (phase 6). Removed: the tests `test_grizzlehide_needs_a_group`, `test_sunscale_drake_needs_a_group`, `test_the_foreman_is_a_fight_for_a_group`; the boss rows of `balance_scenarios.gd` (Grizzlehide rows, `FOREMAN_ROWS`, the level-5 group builds used only by them) and of `balance_report.gd`; the bot boss-fight benchmark `BalanceSim.boss_fight` / `boss_average`; the target sentences in this file (Hurled Sunstone win rates, drake "beats a level-7 group", Foreman "tuned with bots", phase-6 measured boss rates, Grizzlehide group targets) and the drake checklist. Boss HP, damage and timers stay as plain values in their .tres files. Older log rows below keep their history. Non-boss balance targets (wolves, Shaman, Brute, Skirmisher, hound) stay. |
| 2026-11-19 | Critters pack: boar art, a neutral Stag, Foreman x2 damage / +20% speed / +25% areas, targeted casts face their target, leash x1.8, dungeon respawn hold and way out | User brief (branch `feature/critters-boss-fixes`, from `feature/element-start`). See **Critters, the stag, the Foreman, dungeon fixes**. My decisions are in the next rows. |
| 2026-11-19 | The pack was zipped (`art/critters.zip`), not unzipped in the repo; strips copied into `assets/creatures/<name>/strips/`, sheets built from them | Only the strips the game uses (the pack also has per-frame PNGs, sheets and a badger and wolf). One sheet per animation keeps the existing art format; feet line up across rows by bottom-aligning frames in one cell size. |
| 2026-11-19 | Facing bug was Healing Touch, not Frost Shard | User correction mid-task. Fix covers every targeted cast; hold 0.5 s after it goes off (my number) so the cast animation faces the target. |
| 2026-11-19 | Stag numbers, loot and placement | Mine: level 3 (between the steppe's boars and iron wolves), stats above, 2 new materials, 4 stags in place of the 2 herds, wander 4 tiles, graze 4-10 s, 40% speed while wandering. |
| 2026-11-19 | Neutral means: no proximity aggro, no pack call, skipped by Tab until fighting | "Not counted as enemies for aggro/pulls/enemy-nearby checks". Healing someone it fights still puts the healer on its threat table, as with any enemy. |
| 2026-11-19 | Foreman "radius" = the slam circle, the pick cone's reach and the charge lane's width | The charge's length (how far he rushes) and the Hurled Sunstone's range are distances, not areas, so they stay. |
| 2026-11-19 | Leash x1.8 written per enemy file; dummy and Grey Heart excluded | A shared multiplier would need the rules where the testing grounds are laid out; per-file values show the real numbers. |
| 2026-11-19 | Respawn hold for every enemy in any dungeon, not only husks | The Overseer too; the boss never respawns mid-visit anyway. |
| 2026-11-19 | Way out: opens when every enemy (Overseer included) is dead; a portal-like glow, not a new object | "After every dungeon enemy is dead". Uses the exit system (any hero stepping on it), placed in the Foreman's chamber (where a party ends up), arriving where the mine entrance lets out. |
| 2026-11-18 | An item database spreadsheet, generated from the game's content | User request (a spreadsheet). `design/Item_Database.xlsx`: Items (kind, slot, rarity, stats, growth per level, price, sells for, what it teaches, where it comes from), Sources (every drop, shop, quest reward and starting kit), Enemy Loot (each enemy's table and where it lives), About. Regenerate with `godot --headless --path . res://tools/item_database.tscn -- <file.json>` then `python3 tools/make_item_database.py <file.json>`; never edit the sheet by hand. |
| 2026-11-17 | Starting elements, the Foreman's guaranteed hit, faster enemy attacks, eight-facing hero art, a walk that keeps pace on screen, ability rebalance | User brief (seven parts; part 2 waits for the OK on its reward table). My choices: elements as data files; old characters and tool-made ones keep the old kit; shirt / pants numbers; Stone Skin ported from the threat-tanking branch; the Foreman's new ability Hurled Sunstone rather than changing slam, charge or pick, interruptible; wind-up floors 0.63 s for dodgeable attacks (the dodge warning) and 0.2 s for bites, boss telegraphs kept; eight facings by 45° slices of the facing angle; the walk by screen distance with per-facing measured strides; range +2 on every ranged ability (dashes excluded), only the first range number in each text cell; Air control and defense abilities 0.6 Phys Atk + 0.4 Magic Def. See **Starting elements, faster enemies, rebalance**. |
| 2026-11-17 | The user's map edits merged: Greenfields, the Silent Shaft, Millbrook, Windsteppe, Deepcut, the Road to Deepcut, the Crossing | User's own edits in the map editor. User choices: the Foreman stays at his own level 10 (the edit had set level 1); Greenfields stays as edited: no Goblin Shamans, Fen Skirmishers or graveyard (a release there goes to its hero spawn), so Goblin Fetishes can only be done in the testing grounds for now (to rework later). Mine: the Silent Shaft's top row was trimmed, so the encounter's victory spot and quest 1-07's two places move up a row; tests describing the old maps follow the new ones. |
| 2026-11-17 | Maps need not be rectangles: a Shape tool removes and adds tiles; a missing tile is a wall that shots fly over | User request and choice (a hole is a wall like the map's outside, not a pit). My choices: a space in `height_rows`/`terrain_rows` marks a missing tile, so existing maps are unchanged; maps stay stored as their bounding rectangle; adding past a side grows the map with 3 spare rows of holes and saving trims every empty side; new tiles take the Ground list's choice at the Level box's height; things already on removed tiles stay and are warned about; holes can't be painted or hold things; a map keeps at least one tile; fliers can't cross holes either; ground areas and terrain changes skip them. |
| 2026-11-17 | WoW-style threat: overtake 110% in melee / 130% at range, forced taunts, Physical Defense threat multiplier, Earth tanking abilities | User brief. User choices: Metalbending's threat multiplier stays 0 (so the ×3 has no effect); Boulder Shield built. My choices: divisor 40 and cap 3.0 (cloth ×1.25, geared tank ~60 PhysDef ×2.5, Stone Skin or Earth Armor reach the cap); melee range 1 tile edge to edge; Seismic Stomp damage 0.7 × Rock Throw's; Stone Skin +20 PhysDef 10 s; Earth Armor +50 and half speed 15 s; Metalbent −20 for 8 s; Boulder Shield the tier heal default + PhysDef, 12 s; taunt durations don't scale with Mastery; the Earth abilities live as tree behaviors (`content/tree/behaviors/`), not `content/abilities/` (legacy only; `taunt.tres` got `taunt_seconds` 3). The footstep sound test now waits for the first footstep (it was timing-flaky). |
| 2026-11-16 | The hero shows PL-01-1 in all four facings, with the PL-02 sword and bow attacks; frames picked from host times | User brief (replaces the 2026-11-15 mirrored south-east art and back stills). User choices: downed for stuns as well as while dead; animations play when the ability goes off, not over the timing bar; hammer arts and potions play the plain cast until they have their own; revived also after a release at a graveyard; death take 1 (was take 4). |
| 2026-11-16 | Hero art measurements and fixes | Mine: facings shifted onto one feet point (24, 38) by whole pixels; the PL-02 bodies lined up by overlaying their stills on PL-01-1's (a scabbard below the feet fooled the sole test); walk 8 frames per tile from the stride, not a planted foot (the generated walk has no planted foot); while dead, death then downed's last frame held, not downed replayed or looped (both animations fall from standing); 20 / 18 / 20 / 15 fps for slash, lunge, quick shot, aimed shot; the source frames live in `art/heroes/PL-01`, `PL-02` (the old `art/heroes/PL-01-1` sheets and `make_pl01_sheets.py` removed). |
| 2026-11-16 | Map editor part 2: things, map size, connections, new maps; saving through Godot's resource writer | User request and choices: each person placed once in the whole game; a New map button; a one-time re-save of every map (format only); all three parts. My choices: a Things tool and a Select tool (click again cycles a tile's things, drag moves, Delete removes); patrols start where the enemy stands; a resize keeps things on their ground and moves every reference to the map's coordinates in other files on save (quests, doors, edges, the encounter); this map's edges decide the partner's (opposite side and offset); doors pick their arrival on the destination map; warnings (asked, not refused) for one-way doors, edges landing on blocked ground, and quests losing a person or every enemy of a kind; new maps start with a spawn and a graveyard and regenerate `AUDIO_SPEC.md`. |
| 2026-11-16 | Map editor: its own screen from the main menu, painting ground, heights and props, saving into the zone files | User choices: a separate screen (not in-game), enemies frozen, ground/height/props first (objects later). My choices: offered only when running from the Godot editor; heights 0–9; height raise/lower changes each tile once per drag; right-click copies ground / removes props; Pick returns to Ground; saving warns (and asks) when a spawn, graveyard, NPC, enemy, patrol point, exit or edge can't be reached; saving also updates the loaded map; the rows are rewritten in place so nothing else in the file changes. |
| 2026-11-15 | Water abilities unlock one per Mastery step (per-ability Mastery Required, read by the importer; Water rows' formula replaced by their own text); Tidal Blessing, Water Shield and Revive lose the prerequisites that now unlock later | User request (the 23 steps). The rules already read each ability's `mastery_required`; the importer used to take the tier's threshold and now takes the Mastery Required cell (empty: the tier's). My choices: tiers stay as they are for everything else (AP, rarity, prices, damage defaults, the tree screen's columns); a prerequisite unlocking later is an import warning and a content test; the tree screen heads a column with its first ability's step, orders it by step, and a locked node shows "Needs N"; Excel's calcChain.xml was dropped from the workbook (Excel rebuilds it) since it listed the replaced formulas (`tools/once/water_mastery_steps.py`). |
| 2026-11-15 | The hero gets PL-01-1's sprite and animations (idle, walk, cast, hit, death, downed, revived) | User approval of the art-drafts animations. User choices: death take 4; downed for stuns (then revived to get up; revived also after a resurrection or a release); back stills when facing away until back animations exist; cast plays when an ability goes off. My choices: frame rates (idle 6, cast and hit 18, death 12, downed 15, revived 12, run 4 frames per tile); death, downed and revived use the front frames facing away too; no white hit flash for heroes (the hit animation shows it); state changes noted by each view rather than new snapshot fields. |
| 2026-11-15 | Playtest fixes: two-key movement follows the grid lines; the folded quest tracker shrinks after being moved; mouse-aimed abilities always aim at the cursor; a second press of an ability's key uses it | User playtest report (5 items; item 4, gradual unlocks, waits for the user's approval of a schedule). Causes: two keys gave a 45° screen diagonal, but the grid's lines run at 26.6° (`Mover.screen_to_grid`); a dragged tracker kept a fixed size, and folding only hid its text; the host ignored the cursor sent with Slash's bar inputs (Targeted in the sheet, cone hitbox), the client aimed at the targeted enemy until the mouse moved, and a cursor off the map fell back to the hero's facing. My choices: the lock-on to the target is gone for every aimed ability (it was decision 24's default); a second press during a bar plays it like a right-click; another ability's key cancels the bar and gives back its global cooldown, so the new ability isn't blocked; aimed abilities without a bar keep release-to-fire. |
| 2026-11-02 | The Windsteppe track plays: a music entry (`explore_windsteppe.tres`, explore, region Vael); the duplicate upload at `audio/music_explore_windsteppe.ogg` deleted | User approval. The upload had no `MusicTrackDef`, so the draft played. Not edited (measured: no silence; the last 0.5 s average −28 dB, the first −38 dB, so a small dip at the loop). |
| 2026-11-02 | Exports keep text resources as text (`editor/export/convert_text_resources_to_binary=false`); the Windows export preset is committed | User report: the exported Windows build showed a grey world ("Invalid zone: …: empty height_rows" for every tiled zone). Cause measured: Godot 4.7.2's export conversion of `.tres` to binary drops `PackedStringArray` values (reproduced with a two-file project) and script-made defaults (the tree tuning's stat blocks). Not the `.json` files: they were packed. `tests/integration/test_export_zones.gd` exports a pack and loads every zone from it; `docs/exporting.md`. |
| 2026-11-01 | Free movement: all 6 phases built on `feature/free-movement` | User brief and plan approval (3 tiles/s in and out of combat; drops of more than 3 levels hurt but are allowed; falls under gravity; enemies follow the same rules). See **Free movement** and `docs/FREE_MOVEMENT_PLAN.md`. My decisions are in the next rows. |
| 2026-11-01 | Branch from the Act I milestone 4 tip, not `main` | `main` didn't have milestones 3 and 4 yet (their pull requests were open). The tags `v0.2-act1-prototype` and `v0.2-grid-final` go on `main` once those merge. |
| 2026-11-01 | Hitbox columns written into the spreadsheet by patching its XML | openpyxl drops the cached results of the sheet's 193 formulas, which the importer reads. |
| 2026-11-01 | Slash and Smash are cones that swing on the key press toward the mouse; lock-on spells stay targeted | Plan §6. Out-of-range circles land at the edge of their range (as timing-bar aims already did); terrain abilities still refuse. |
| 2026-11-01 | Air Step: +40% speed for 4 s | "Free steps" don't exist without step cooldowns (plan §6, to confirm in playtest). |
| 2026-11-01 | Telegraph outlines drawn flat at the height under their centre | Corners at their own tile heights tore circles apart across ledges. |
| 2026-11-01 | The drake's Searing Dive stays on its tile lane; Ember Trail and ground zones stay on tiles | The dive's shove-aside and stun rules are written for lanes; it still telegraphs and can be dodged. Terrain and zones are grid abilities by the brief. |
| 2026-11-01 | Tile stepping removed entirely (`try_step`, step cooldowns, free steps) | The brief: "Remove the per-step movement cooldown". Data fields `combat_step_seconds` and `walk_tile_seconds` stay so old files load. |
| 2026-11-01 | Big enemy attacks flagged `dodgeable`; quick bites aren't | The brief wants big attacks telegraphed and dodgeable; a 0.3–0.4 s bite stays chip damage like in WoW. |
| 2026-11-01 | A unit mid-attack can't be pushed by other units | A hero walking into the Brute shoved it out of its own swing. |
| 2026-11-01 | Bosses can grow less with the party (`EnemyDef.party_hp_per_hero`; the Foreman and Heart +45%) | Four heroes don't deal four times one tank's damage (a healer barely attacks), so +70% made groups worse off than a soloist. |
| 2026-11-01 | Balance bots dodge where their spec says; the level-5 group's damage dealers and healer do | The M4 notes said real groups would dodge; free movement makes that the fair measure. Tanks hold still. |
| 2026-10-27 | Act I milestone 4 of 4: dungeon rules, the Silent Shaft, the Foreman and the Grey Heart, quest 1-07, the end of Act I | User brief ("list every decision"). See **Act I: the Silent Shaft**. My decisions are in the next rows. |
| 2026-10-27 | Branch `feature/act1-m4-silent-shaft` from `feature/act1-m3-quests`, not `main` | `main` doesn't have milestone 3 yet (its pull request is open, not merged), and 1-07 follows 1-06. The pull request into `main` therefore carries milestone 3 too; merging milestone 3's first leaves only milestone 4 in it. |
| 2026-10-27 | One party = every connected player, so one dungeon copy at a time; copies close 60 s after the last hero leaves | Rule 11 (no party system yet). `World.party_of` is the one place a real party system would change. Closing after a minute lets a hero step out and back without losing progress. |
| 2026-10-27 | Entry needs the dungeon's quest (active or done) and the minimum party; the testing setting is on by default in debug builds and is a host-side switch like the game speed | "Minimum party size is a setting... on by default in debug builds". The quest gate keeps the dungeon in the story's order. |
| 2026-10-27 | Wipe: everyone revives after 3 s at the dungeon's entrance at half health and mana; enemies forget the party; adds and grey tiles vanish | "Everyone respawns at the dungeon entrance". Half, like a release. The boss also resets after a wipe only to its phase's start, and walking home doesn't heal it past that. |
| 2026-10-27 | Single deaths in a dungeon release to its entrance (its only graveyard); a resurrection still works in place | The usual death rules; only a wipe is special. |
| 2026-10-27 | Sections joined by a lift (exits within one map), not separate zones | One instance holds the whole dungeon (one party copy, one wipe rule); the lift is the brief's "mine-cart or lift down". |
| 2026-10-27 | Phases follow the Foreman's health; the Heart is shielded until phase 3 and holds him at 5%; breaking it ends the fight and kills him | "Players must damage the Grey Heart to stop its pulse... Breaking the Heart ends the fight." The 5% floor makes the Heart the only way to win. His kill (and XP, loot) go to his threat table. |
| 2026-10-27 | Phase 2: one husk per pulse (at most 2) and 6 grey tiles every 12 s; phase 3: 8 grey tiles every 9 s, no husks | First numbers (2 husks per pulse, more grey) killed every bot group; husks in phase 3 kept them off the Heart. Grey tiles slow (×1.5) and drain 3% of max mana per second (both, not either). |
| 2026-10-27 | The Foreman scales with the party although he is an elite (`EnemyDef.dungeon_boss`); the Heart and the husks scale too | "Health and damage scale with party size". Other elites still don't. |
| 2026-10-27 | Boss numbers: Foreman HP 800 / PhysAtk 16, Heart 150 (solo, before party scaling), slam 1.8 s telegraph (one step out from beside the target), Grey Fury +15% / ×0.85 | Tuned with bots that never dodge, at level 10: four win about half the time (3 of 6), three a third (2 of 6), a pair 5 of 6 (healer + tank), a lone tank never. The slam can't be dodged by the hero it's centred on (two steps out): the tank takes it, the others spread. |
| 2026-10-27 | XP: 1-07 gives 1,200 and the Foreman 900, so the act ends at level 12 | Brief M3: Act I is levels 1–12. Measured: solo 7,190 XP, a party of four 6,934 each, without the dungeon's husks. |
| 2026-10-27 | Steward Brann leaves Deepcut when 1-06 is handed in (`NpcDef.gone_after_flag`, world flag `brann_descended`); Shift Bell is handed in to Miner Ostrik | The brief makes Brann the Foreman. Shift Bell (still open after 1-06 for some) needed another hand-in. 1-06 now announces his descent. |
| 2026-10-27 | Caedan is a second NPC (`caedan_shaft`) who appears at the chamber door when the Heart breaks; the Ember Hand recruitment is his Talk line with choices | NPCs don't walk between zones; "Caedan arrives" is his appearance, a message and a speech bubble. The choices change nothing yet (both lead to the same answer). |
| 2026-10-27 | End of Act I: a screen with the party's records after the hand-in conversation, then back to the Crossing by its button; Act I saved per character (`records.acts`) and per world (`act1_complete`) | "Show an End of Act I screen with the party's stats, then return players to the Crossing. Save that Act I is complete." Records (kills, damage, healing, deaths, quests) count from milestone 4 on, so older characters start at 0. |
| 2026-10-27 | Dungeon and boss music listed for the Silent Shaft only, skipped until their files exist | The keys from the brief; zone-only tracks (`MusicTrackDef.zones`) so another dungeon won't play them. |
| 2026-10-27 | Dungeon bosses and immobile enemies get no pen in the testing grounds | They need their encounter; a lone Foreman would teach the wrong fight. |
| 2026-10-27 | Act I milestone 3 of 4: quests 1-01 to 1-06, three side quests, party-size scaling | User brief ("list every decision"). See **Act I: the Floor Guild quests**. My decisions are in the next rows. |
| 2026-10-27 | The placeholder Act I quests, the foreman, the ore caravan and the writ are removed | The brief's quests replace them; Sabra, Ilyth and the Vael stone stay as people to talk to. Rowan's and Ottilie's Millbrook quests stay. |
| 2026-10-27 | Maren Voss stands in two places (two NPC files): Millbrook for 1-01, the Guild Hall for 1-02 on | The brief has her in both. NPCs don't move between zones yet; per-player NPC visibility would be new machinery. The village's old woman, "Old Maren", is now "Old Ottilie" so the names don't clash. |
| 2026-10-27 | Steward Orrin Marl becomes Steward Brann; Dorne is the Guild's registrar; Harrow is the Guild vendor; Caedan always stands at the hall | Reuse of milestone 2's people. Caedan "arrives" in the dialogue; a scripted entrance would need staging tools (milestone 4 or later). |
| 2026-10-27 | Turn-ins: 1-03 Saran, 1-04 Brann, 1-05 Healer Wenna, 1-06 Caedan, sides as in the table | "Then Saran", "then Steward Brann" read as the hand-in. 1-05's hand-in to Wenna lets you tell her where the fever comes from. |
| 2026-10-27 | Objectives where the brief leaves room | 1-01: 3 wolves + 2 boars in Millbrook's south fields (static spawns, no scripted wave); 1-02: two talks; 1-03: one escortee for the whole crew (an escort has one NPC) plus 4 iron wolves; 1-05: Odo, then three draughts to Wenna, then three single-spot investigations, one per zone, upstream; Shift Bell: rubble, 3 Husks, the miner; Pins: reach 4 sites, then the map (in any order). |
| 2026-10-27 | Levels: 1-03, 1-04, 1-05 at 3; 1-06 and Shift Bell at 6; Pins at 7 | So the chain flows with the XP it gives; the playthrough test checks each quest can be taken when reached. |
| 2026-10-27 | XP: quest rewards tuned (120 to 500), the curve unchanged | A party doing everything listed reaches level 10 (solo 4,770, party 4,578 each in the measured run); the dungeon needs about 2,100 more for 12. The optional Millbrook quests add about 1,060. |
| 2026-10-27 | Party size = heroes in the enemy's zone; +70% HP, +10% damage per extra hero; XP scales the same; elites and dummies excluded | "Scale enemy health and damage with party size". The zone is where help can come from. Elites are already built for groups (the drake and Grizzlehide targets assume four). XP grows so a party levels like a solo hero. A fight keeps its size; idle enemies rescale and keep their share of health. |
| 2026-10-27 | New placeholder enemies: Boar (level 2) and Human Husk (level 7) | Boars charge like a small Grizzlehide; Husks are slow, hit hard and shrug off magic, and drop Sunstone Shards (a hint). Their loot follows the tier-2 rule for enemy drops. |
| 2026-10-27 | Spawns can set a level (`EnemySpawn.level`) | So one enemy type serves several zones' level ranges (road wolves 3, iron wolves 4–5, road brutes 5, Deepcut's hounds 6). |
| 2026-10-27 | Rewards: one choice per main quest from all seven trees' implemented tier-1 items; side quests give gold and potions | Only implemented abilities. Missing tier-1 abilities listed in the section. |
| 2026-10-27 | The Guild vendor is a new Quartermaster at the hall | "Sells starter gear and tier 1 scrolls": helm, boots, potions, the 20 implemented tier-1 scrolls and weapons. Tamsin and Odo keep their stalls. |
| 2026-10-27 | Talk objectives can have their own line, `quest.<id>.talk.<i>` | So Dorne, Harrow, Odo, Caedan and Ostrik say something about the quest instead of their greeting. |
| 2026-10-27 | Commits: the quests were written together, then committed one by one as the playthrough test covered each | Quest data and lines are one file each; each per-quest commit adds that quest to the scripted playthrough once it passed. |
| 2026-10-27 | Act I milestone 2 of 4: zones (Millbrook rebuilt, the Crossing, Road to Deepcut, Deepcut, Windsteppe), region music, the Tidereach track | User brief ("list every decision"). See **Act I: zones and region music**. My decisions are in the next rows. |
| 2026-10-27 | Branch `feature/v1.3.1` from `main` after milestone 1's merge | User correction of the brief's branch name (first given as `feature/act1-m2-zones`, renamed before any commit); merged at the end. |
| 2026-10-27 | Zone size: 32–60 tiles across, not 2–3 minutes' walk | At the current walking speed (5 tiles/s) 2–3 minutes would be 600–900 tiles; "small and hand-built" and the existing maps (30×30) point the other way. The zones take 10–15 s to cross straight, longer along the roads and around cliffs. To revisit with the walking speed. |
| 2026-10-27 | Zones built from hand-placed shapes by a script, then baked | `tools/once/make_act1_zones.py` (like the earlier `make_tiled_zones.py`): houses, roads, rivers, cliffs and camps placed by coordinates, written as ordinary zone files. |
| 2026-10-27 | Regions: Heartland (Millbrook, the Crossing, Greenfields, testing grounds), Bedrun (the Road, Deepcut), Vael (Windsteppe), Tidereach (test shore) | Bedrun runs the mines; the felt tents, cairns and the Vael stone make the steppe Vael's. No Act I zone is Ashkara. |
| 2026-10-27 | A region's own track wins; tracks with no region are the fallback; other regions' tracks never play | The draft (no region) plays wherever a region has no track. The water track is explore only: a Tidereach town would play town music. |
| 2026-10-27 | Tidereach track not edited; its loop problem reported | The brief: tell rather than edit. Measured: 2.35 s of near-silence at the start, about −26 dB at the very end. The WAV master is kept in `art/audio/` like the earlier MP3. |
| 2026-10-27 | Tidereach test zone, west of the Enemy Testing Grounds (plus a `goto` debug command) | Walking in and out shows the crossfade between regions; off the testing grounds so the Act I map stays as briefed. `goto` reaches every zone for playtests. |
| 2026-10-27 | Respawn: zones beyond the Crossing send released heroes to its shrine; Millbrook, Greenfields and the testing grounds keep their graveyards | "The graveyard shrine where players respawn". Millbrook's graveyard sits by the healer's hut. |
| 2026-10-27 | Act I's people moved to where the brief puts them | Guild Board, Dorne, Sabra → the Crossing (guild hall, inn); Mine Board, Brannoc, caravan, Collapsed Shaft → Deepcut; Vael stone → Windsteppe, its quest now kills iron wolves (level 3). The escort runs through Deepcut to the canyon gate past two Salamander Hounds (the Ember Hand's fire hounds), since an escort stays in one zone. Lines naming old places rewritten in `act1.json`. |
| 2026-10-27 | New people: Healer Wenna (Millbrook), Tamsin Reed and Odo the Apothecary (vendors), Innkeeper Bram (the Crossing), Steward Orrin Marl (Deepcut), Elder Tsaga (Windsteppe) | Talk only, apart from the two vendors (Tamsin: Hilda's stock; Odo: potions). Wenna mentions the grey river (for quest 1-05). |
| 2026-10-27 | Iron wolves: level 3, the wolf's bite and howl, steel recolour of the wolf art | HP 320, PhysDef 18 (iron hide), 80 XP. Packs of two on patrol loops. |
| 2026-10-27 | Placeholder tiles are recolours; objects are shapes with labels (`ZoneDecor`) | The brief allows simple shapes. Recolours keep the tile style; shapes are drawn as clipped polygons so the terrain cache still draws exactly. Labels show within 12 tiles to avoid clutter. |
| 2026-10-27 | Test changes forced by the new layout | Tests that used Millbrook's old tiles read them from the map now; the aiming test plays on open ground at the Crossing; the testing-grounds walkthrough hero is level 15 (12 lost to the Bandit Brute once the extra zones changed the random draws). |
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
