# Final Wars: Milestone 3 playtest checklist (abilities, mastery, targeting)

This list walks you through everything Milestone 3 added or changed. You don't need
to know anything about programming. Work through the sections in order, tick each box
when the game does what the **Expect** line says, and write down anything that doesn't
(see "Reporting a problem" at the end).

Plan about **2 hours**. Sections 1–10 can be done alone; section 11 needs 2–4 players
(real friends, or several game windows on one computer, see
[local-multiplayer-testing.md](local-multiplayer-testing.md)). Things Milestone 3 did
not change (town, quests, saving, trading, zones) are still covered by the
[Milestone 2 checklist](playtest-checklist.md); where the two disagree, this one wins.

**Words used below**
- **Ability tree:** one of seven families of abilities: Fire, Earth, Water, Air (taught
  by **scrolls**) and Sword, Bow, Hammer (taught by **weapons**). Each has 5 **tiers**.
- **Mastery:** a number per tree that grows as you master and use its abilities. Enough
  Mastery opens the next tier (150, 350, 600, 900).
- **Learning slot:** the one place that turns AP into mastery. Only the item in it (a
  scroll, or the weapon in your hand) earns **AP** (ability points) toward its ability.
- **Mastered:** reached its AP goal. A mastered element ability (Fire, Earth, Water, Air)
  works forever; a mastered weapon art needs a weapon of that kind in your hand.
- **Wind-up:** a short pause before an enemy's hit lands. Step away in time and it misses.
- **Telegraph:** red-flashing tiles that show where an attack is about to land.

**Keys (new or changed in Milestone 3)**
| Key | What it does |
|-----|--------------|
| 1 – 9, 0 | Use the ability in that slot. For an **aimed** ability (skillshot or ground), **hold** the key, aim, and **let go** to cast |
| Mouse (while aiming) | Moves the aim. Until you move the mouse, the aim sits on your target |
| Esc or right-click (while aiming) | Cancel aiming |
| T | Ability trees |
| ` (the key left of 1) | Debug console (only in test builds) |

The rest is unchanged: W A S D walk, Tab/click target, B inventory, C character sheet,
P spellbook, L quest log, E talk, R release.

---

## 0. Before you start

- [ ] **Do:** open the project in Godot 4.7, press **F5**, create a new character and **Play Solo**.
      **Expect:** you start in Millbrook as before.
- [ ] **Old characters (optional):** play a character made before Milestone 3.
      **Expect:** its old Sword, Staff, Shield, Holy Charm, Hunting Bow and Greataxe are
      gone, and so are Strike, Fireball, Heal, Block and the other old abilities. Level,
      gold, armor, potions and quests are kept, and it gets the new starting kit (next section).

## 1. Starting kit and the learning slot

- [ ] **Do:** press **B** (inventory).
      **Expect:** the **Rusty Shortsword** is in your Main Hand; **Mender's Scroll** is in
      your bag. Under your equipment there's a blue-edged **Learning** slot holding the
      **Ember Fist Scroll**, with the text "Learning: Fire Punch, AP 0 / 20".
- [ ] **Expect:** the action bar shows **Slash** (from the sword) in slot 1 and **Fire Punch** (from the scroll) in slot 2.
- [ ] **Do:** hover the Ember Fist Scroll in the Learning slot.
      **Expect:** a tooltip: "Fire tree, tier 1 · Scroll (not worn)", "In your learning
      slot: earning AP", and growth "per level while in your learning slot".
- [ ] **Do:** hover Mender's Scroll in the bag.
      **Expect:** "Right-click or drag onto Learning to learn it."
- [ ] **Do:** right-click Mender's Scroll.
      **Expect:** it moves into the Learning slot, the Ember Fist Scroll goes back to your bag,
      and **Healing Touch** appears on the action bar. Fire Punch's slot stays but goes dark
      (not usable: not mastered and not being learned).
- [ ] **Do:** drag the Rusty Shortsword from Main Hand onto the Learning slot.
      **Expect:** the sword now shows a blue **L** and a small AP bar; the scroll goes back to the bag.
- [ ] **Do:** right-click the Learning slot.
      **Expect:** it empties ("Learning: nothing").
- [ ] **Do:** press **C** (character sheet).
      **Expect:** the same Learning slot is on the sheet, a **Mastery** section, and under
      "In progress" the ability being learned marked "(learning)", others "(not learning)".
- [ ] Put the **Ember Fist Scroll** back into the Learning slot before continuing.

## 2. The ability trees (T)

- [ ] **Do:** press **T**.
      **Expect:** a big window with tabs **Fire, Earth, Water, Air, Sword, Bow, Hammer**.
- [ ] **Expect (Fire tab):** a header with your Fire Mastery and "Tiers need 0 / 150 / 350 /
      600 / 900"; five rows labelled Tier 1 to Tier 5, each saying "open" (green) or "needs N" (red).
- [ ] **Expect:** ability boxes coloured by state: **blue** = being learned (Fire Punch),
      **white** = you can learn it now, **grey** = locked, **dark** = not in the game yet,
      **gold** = mastered. Lines join each ability to the ones it requires.
- [ ] **Do:** hover a grey (locked) box, e.g. Fire Whip.
      **Expect:** its tooltip says why it's locked (needs Fire Mastery 150, or an earlier ability).
- [ ] **Do:** hover any box.
      **Expect:** name, tree, tier, what it does, the item that teaches it, and "Mastery from this ability: x / cap".
- [ ] **Do:** drag **Fire Punch** from the tree onto an empty action bar slot.
      **Expect:** it lands there. A box you can't use yet (white or grey) can't be dragged.
- [ ] **Do:** check the Sword, Bow and Hammer tabs.
      **Expect:** each shows its abilities; Slash (Sword) shows "Can learn" or your progress.

## 3. Using abilities: the four kinds of targeting

Go to **Greenfields** (walk off the east edge of town) and find a Wolf.

- [ ] **Targeted (Slash, Fire Punch):** click the Wolf to target it, stand next to it
      (diagonals count) and press 1 or 2.
      **Expect:** it hits straight away and can't miss. Pressing it from too far away says you're out of range.
- [ ] **Skillshot (Fire Dart):** buy a **Spark Scroll** from Hilda (25 g), put it in the
      Learning slot, and put **Fire Dart** on your bar. Hold its key.
      **Expect:** while held, blue tiles show the dart's exact path, stopping at the first
      enemy. Moving the mouse moves the aim (any angle). Letting go fires a small orange bolt along that path.
- [ ] **Do:** aim Fire Dart beyond its range (4 tiles) or behind a hill.
      **Expect:** the path stops at the range or at the wall. Esc or right-click while holding cancels without casting.
- [ ] **Ground (needs the debug console, section 9: `master Fireball`):** hold Fireball's key and point at a tile.
      **Expect:** a 3×3 square of blue tiles; red if the tile is more than 5 tiles away.
      Letting go marks the square **red** for a moment, then it explodes on whoever stands there.
- [ ] **Self (Sun Warrior's Breath; `master F04`):** press its key.
      **Expect:** it works at once without aiming; your next 3 Fire abilities hit harder (bigger numbers),
      and your Mana bar refills by 10% of its maximum over the next 10 seconds.
- [ ] **Cast bars:** **Expect:** when an enemy winds up an attack, a small **red** bar with
      the attack's name appears under it. Aimed Shot (a bow) shows a **yellow** bar for its 1 s draw.

## 4. Learning, AP and Mastery

- [ ] **Do:** kill a few Wolves with the Ember Fist Scroll in the Learning slot.
      **Expect:** each kill gives a little AP (2) to **Fire Punch only**; each level-up gives
      10 AP. Nothing else gains AP. The Learning slot text and the tree show the progress.
- [ ] **Do:** reach 20 AP.
      **Expect:** "You mastered Fire Punch!", your Fire Mastery goes up by 5 (Mastery on
      learn), and its box turns gold in the tree. Fire Punch keeps working with the scroll out of the slot.
- [ ] **Do:** keep using Fire Punch on enemies near your level.
      **Expect:** Fire Mastery creeps up a little (0.2) with each use, until the ability
      has given its cap (50 for tier 1). Using it on enemies 4 or more levels below you
      gives nothing.
- [ ] **Do:** level up with the Ember Fist Scroll in the Learning slot.
      **Expect:** the character sheet shows extra Magic Attack, Mana and Fire Mastery growth
      (scrolls grow you while you learn from them).
- [ ] **Tier unlock:** with `mastery fire 150` (console) the Fire tab's Tier 2 row turns "open"
      and abilities whose requirements you meet turn white.
- [ ] **Weapon arts:** master Slash, then take the sword off.
      **Expect:** Slash goes dark (needs a sword in hand). Hold any sword again and it works.
      Mastered Fire abilities work with no scroll at all.

## 5. What the first abilities do

Use the console (section 9) to `master` each one, or learn them from scrolls. Each line is one ability.

- [ ] **Fire Kick:** hits and leaves a short burn (small numbers for a few seconds).
- [ ] **Flame Dash** (Ground, 8-way): dash up to 3 tiles toward the aim, stopping at walls, units or climbs too high; the tiles behind you burn (orange) for 3 s. With 300 Fire Mastery you get 2 charges.
- [ ] **Fire Whip** (8-way line of 3): hits every enemy in the line.
- [ ] **Burning Ground** (Ground): a 3×3 orange area for 6 s; enemies burn only while standing in it.
- [ ] **Blazing Combo:** three quick hits, the last knocks the target back 1 tile.
- [ ] **Healing Touch / Soothing Mist:** heal you or an ally (Mist slowly over 12 s). Ally abilities with no ally targeted heal you.
- [ ] **Water Whip:** hits an enemy within 3. **Leeching Tide:** hits and heals you half the damage.
- [ ] **Flow State:** Haste for 30 s (steps and cooldowns 25% shorter). **Tidal Blessing:** +20 Physical and Magic Defense for 45 s.
- [ ] **Frost Shard** (skillshot) and **Ice Spikes** (Ground 3×3, 0.4 s warning): damage and slow (enemy steps take longer).
- [ ] **Water Pulse** (8-way line of 3): damages and pushes enemies 1 tile along the wave.
- [ ] **Air Palm:** light hit + knock back 1. **Air Blast:** knock back 3; extra damage if the enemy slams into a wall, rock or ledge.
- [ ] **Gust:** light hit that interrupts a cast. (No Greenfields enemy has a cast to interrupt yet; wind-ups can't be interrupted.)
- [ ] **Air Step:** your next 5 steps have no step cooldown, even in combat.
- [ ] **Rock Throw:** a rock lobbed onto the aimed tile after 0.3 s; it misses if the enemy moved away.
- [ ] **Raise Pillar:** lifts a tile 1 level for 15 s (2 levels from 500 Earth Mastery); anyone on it rides up.
- [ ] **Earth Wall:** a 3-tile wall (+2 height) across the way you face, centred on the aimed tile, for 12 s. Nobody can walk through it and it blocks shots. Tiles with someone on them are skipped.
- [ ] **Seismic Stomp:** every enemy next to you turns on you (taunt).
- [ ] **Lunge** (Traveler's Longsword): steps up to 2 tiles to the enemy and strikes; blocked by a wall in between, it falls short and misses.
- [ ] **Quick Shot** (Hunter's Shortbow): instant arrow, range 5, can't miss. **Aimed Shot** (Yew Longbow): 1 s draw, then a heavy arrow along the aimed line (range 7). Moving during the draw cancels it.
- [ ] **Smash** (Iron Mallet): 0.3 s wind-up, then a heavy hit; if the enemy steps away first, it misses. **Ground Slam** (Quarry Maul): hits all 8 tiles around you.
- [ ] **Not in the game yet:** dark boxes in the tree (e.g. Stone Skin) can't be learned; their scrolls say "This ability isn't in the game yet."

## 6. Enemies and dodging

- [ ] **Wolf:** when next to you it shows a red "Bite" bar for 0.3 s before biting.
      **Do:** step straight away during the bar. **Expect:** "Whiff", no damage.
- [ ] **Bandit Brute:** same with a slower 0.6 s "Crushing Blow". It hits very hard, so dodging matters.
- [ ] **Goblin Shaman:** shoots purple bolts at any angle (no longer only along rows). Stepping off the path dodges.
- [ ] **Old Grizzlehide:** its Cleave hits the 3 tiles in front of it after a short wind-up;
      its **Charge** marks a tile 2–4 tiles away in **red** for 1 s, then it rushes there and
      mauls whoever is still on it. **Do:** step off the red tile. **Expect:** it rushes in but misses.
- [ ] **Expect:** Old Grizzlehide is tougher than before (2000 HP); it takes a group.

## 7. Trading, loot and quest rewards (changed)

- [ ] **Do:** talk to Hilda and open her shop.
      **Expect:** potions, Iron Helm, Swift Boots, and the tier-1 scrolls (25 g) and weapons
      (30 g) of every tree: Ember Fist, Cinder Kick, Spark, Sun Warrior's Breath, Mender's, River Lash,
      Scroll of the Current, Frost Shard, Open Palm, Breeze, Featherstep, Pebble, Pillar,
      Stomp; Rusty Shortsword, Traveler's Longsword, Hunter's Shortbow, Yew Longbow, Iron
      Mallet, Quarry Maul. No Hunting Bow.
- [ ] **Expect:** Greenfields enemies sometimes drop **tier-2 scrolls** (green name), e.g.
      Scroll of the Fireball or Glacier Scroll from Shamans, Bulwark Scroll from Brutes.
- [ ] **Do:** finish "Goblin Fetishes". **Expect:** the choice is Iron Helm / Swift Boots / Hunter's Shortbow.
- [ ] **Do:** finish "The Beast of Greenfields". **Expect:** the choice is Scroll of the Fireball / Glacier Scroll / Bulwark Scroll.
- [ ] **Expect:** armor (Iron Helm, robes, boots…) only gives stats now; it teaches nothing.

## 8. Death

- [ ] **Do:** die. **Expect:** release (R or the button) works as before. There is no
      resurrection ability yet (it comes back with Water tier 3, Revive), so allies can't raise you.

## 9. Debug console (test builds only)

- [ ] **Do:** press **`** (left of 1).
      **Expect:** a dark box with a text line appears at the top. Typing W A S D in it does not walk.
- [ ] **Do:** type `help` and press Enter.
      **Expect:** the list of commands.
- [ ] **Do:** try each: `level 5`, `mastery fire 350`, `ap 20`, `master Fireball`,
      `master W05`, `spawn wolf 3 2`, `spawn "Bandit Brute"`, `heal`, `gold 200`.
      **Expect:** a green answer each time and the change happens (level, Mastery in the
      tree window, the learning ability mastered, abilities mastered, two level-3 Wolves next to you, …).
- [ ] **Expect:** spawned enemies show the level you asked for and don't come back after they die.
- [ ] **Do:** type `spawn dragon`. **Expect:** a red answer listing the enemies that exist.
- [ ] **Do:** press Up. **Expect:** the last command comes back. Esc or ` closes the console.

## 10. Readability

- [ ] **Expect:** blue aim tiles, red telegraphs and orange burning ground are easy to tell apart, and characters stay visible on top of them.
- [ ] **Expect:** with the character sheet and the inventory both open, they sit side by side and nothing runs off the screen.

## 11. Playing together (2–4 players)

- [ ] **Expect:** everyone sees each other's projectiles, telegraphs, burning ground, walls and pillars, and enemies' wind-up bars.
- [ ] **Expect:** your Learning slot, AP and Mastery are your own; others can't see your bag or progress.
- [ ] **Do:** one player raises an Earth Wall between a Wolf and another player.
      **Expect:** the Wolf has to walk around it; arrows and bolts stop at it.
- [ ] **Do:** a healer heals a friend with Healing Touch (target the friend first).
      **Expect:** the friend's health goes up on everyone's screen.
- [ ] **Do:** fight Old Grizzlehide together. **Expect:** a group of 4 at level 5 can win if they spread out and dodge the Charge.

## For the designer: updating abilities from the spreadsheet

After editing `design/Ability_Tree.xlsx`, ask a programmer (or follow
[ability-import.md](ability-import.md)) to run the importer. It lists any problems
(unknown prerequisite names, duplicate IDs, missing items, tiers outside 1–5) and
changes nothing until they're fixed. Names, tiers, cooldowns and Mastery numbers come
straight from the sheet.

## Reporting a problem

For each problem, write down: what you did, what you expected, what happened instead,
and (if you can) a screenshot. Note whether you were alone or with others, and which
character and level.
