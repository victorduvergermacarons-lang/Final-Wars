# Final Wars: Milestone 2 playtest checklist

This list walks you through every feature in the game. You don't need to know
anything about programming. Work through the sections in order, tick each box when
the game does what the **Expect** line says, and write down anything that doesn't
(see "Reporting a problem" at the end).

Plan about **2–3 hours** for a full pass. Sections 1–11 can be done alone. Section 12
needs 2–4 players: real friends, or several game windows on one computer (see
[local-multiplayer-testing.md](local-multiplayer-testing.md)).

**Words used below**
- **Tile:** one diamond-shaped square of ground.
- **Facing:** the small arrow on the ground under every character, showing which way it looks.
- **Target:** the character you clicked. Its frame shows at the top of the screen next to yours.
- **In combat:** a red outline around your hero.

**Keys**
| Key | What it does |
|-----|--------------|
| W A S D or arrow keys | Walk. A quick tap only turns you; holding walks. W = up-right, D = down-right, S = down-left, A = up-left |
| 1 – 9, 0 | Use the ability or potion in that action bar slot |
| Left click | Target a character (also: click a frame at the top left) |
| Tab / Esc | Target the next enemy / clear your target |
| E, or right-click a townsperson | Talk (you must stand within 2 tiles) |
| B | Inventory (your gear and bag) |
| C | Character sheet |
| P | Spellbook |
| L | Quest log |
| R | Release when dead |
| Mouse wheel | Zoom |

---

## 0. Starting the game

- [ ] **Do:** open the project in Godot 4.7 and press **F5**.
      **Expect:** the main menu appears with a character list, a name box, and the buttons Play Solo, Host Game and Join Game.

## 1. Characters and saving

- [ ] **Do:** type a new name (for example "Tester") and create the character.
      **Expect:** it appears in the character list at level 1.
- [ ] **Do:** select it and click **Play Solo**.
      **Expect:** your hero (a circle) appears in the town of **Millbrook**, near the middle of town.
- [ ] **Do:** play a few minutes, then click **Leave game** (bottom of the screen) or close the window, and start Play Solo again with the same character.
      **Expect:** same level, gear, bag and gold as when you left.
- [ ] **Do:** create a second character.
      **Expect:** both characters show in the list, each with its own level.

## 2. Town and townspeople

- [ ] **Expect:** three townspeople (coloured rectangles with names): **Hilda** (the trader), **Captain Rowan** and **Old Maren**.
- [ ] **Expect:** a yellow **!** over Captain Rowan and over Old Maren (they have quests for you). Hilda has none.
- [ ] **Do:** walk into a townsperson.
      **Expect:** you can't walk through them, and they never attack you.
- [ ] **Do:** stand next to Hilda and press **E** (or right-click her).
      **Expect:** a dialogue box with her name, a greeting, a **Browse goods** button and **Goodbye**.
- [ ] **Do:** walk away from her.
      **Expect:** the dialogue box closes on its own.
- [ ] **Do:** press E when no one is within 2 tiles.
      **Expect:** a short red message ("There's no one to talk to here" or similar).

## 3. Movement and basic combat (the Milestone 1 basics)

- [ ] **Do:** tap D once.
      **Expect:** your hero turns to face down-right without moving.
- [ ] **Do:** hold D.
      **Expect:** your hero walks tile by tile, quickly, with no pause between tiles.
- [ ] **Do:** walk to the town's down-right edge (hold D; the road out is near Captain Rowan).
      **Expect:** stepping onto the edge takes you to **Greenfields**, a bigger map with grey wolves (red diamonds labelled "Wolf Lv1").
- [ ] **Do:** walk near a Wolf.
      **Expect:** it charges you, and you get a red outline (in combat).
- [ ] **Expect:** in combat you walk much more slowly (about 1.5 s per tile), and the Wolf is faster than you.
- [ ] **Do:** face the Wolf (tap toward it) and press the key for **Strike** (slot 1 by default).
      **Expect:** a damage number floats up and the Wolf's health bar drops. If you face away, the attack shows "Whiff".
- [ ] **Expect:** after each ability, all slots dim with a short sweep (global cooldown, 1 second).
- [ ] **Do:** kill the Wolf.
      **Expect:** XP in the message log; your XP bar fills; some gold and maybe a Wolf Pelt or Wolf Fang ("You loot …").
- [ ] **Expect:** as soon as the last enemy fighting you dies, the red outline goes away and your health starts coming back.
- [ ] **Do:** step away from a Wolf just before it bites.
      **Expect:** it sometimes bites the empty tile where you were (it reacts slightly late).

## 4. Inventory, equipment and tooltips (B)

- [ ] **Do:** press **B**.
      **Expect:** a window with 9 equipment slots (Head, Chest, Legs, Feet, Hands, Main Hand, Off Hand, 2 Accessories) and a bag of 20 slots. You wear the Sword and the Holy Charm; the Staff and Shield are in your bag.
- [ ] **Do:** hover over any item.
      **Expect:** a tooltip with its name in its rarity colour (white Common, green Uncommon, blue Rare, purple Epic), stats, "Per level while worn", the ability it teaches and your AP progress toward mastering it.
- [ ] **Do:** hover over the Shield in your bag.
      **Expect:** an "If equipped:" section with green (better) and red (worse) stat changes.
- [ ] **Do:** drag the Shield onto the Off Hand slot (or right-click it).
      **Expect:** it's equipped, and **Block** appears on the action bar.
- [ ] **Do:** right-click an equipped item.
      **Expect:** it goes back to the bag.
- [ ] **Do:** try to change gear while in combat.
      **Expect:** refused with "You can't do that in combat".
- [ ] **Do:** shift+click a stack of several items (e.g. Wolf Pelts).
      **Expect:** it splits into two stacks. Dragging one stack onto the other merges them.
- [ ] **Do:** ctrl+right-click a junk item.
      **Expect:** it's destroyed.
- [ ] **Two-handed weapons** (needs a Hunting Bow from Hilda, or a Greataxe drop):
      **Do:** equip it while wearing a Shield.
      **Expect:** the Shield moves to your bag and the weapon fills both hands. With a full bag, the swap is refused.

## 5. Character sheet, spellbook and action bar

- [ ] **Do:** press **C**.
      **Expect:** level, XP, every stat split into base / growth / gear / buffs, and lists of mastered and in-progress abilities with AP (e.g. "Strike 0/20").
- [ ] **Do:** press **P** and drag an ability onto an empty action bar slot.
      **Expect:** it lands there. Dragging between slots swaps them; right-clicking a slot clears it.
- [ ] **Do:** click **Keybinds**, hover a slot and press a free key (e.g. Q).
      **Expect:** that slot now uses Q. Movement keys and B/C/P/L/E/R are refused. Click Done binding to finish.
- [ ] **Do:** restart the game.
      **Expect:** your bar layout and keybinds are still there.
- [ ] **Expect:** slot colours: **blue** = not enough mana, **red** = nothing would be hit / out of range, **dark** = not usable (item removed and ability not mastered).

## 6. Gold, loot, trader and potions

- [ ] **Expect:** killing enemies gives gold (shown in the inventory window) and items straight into your bag.
- [ ] **Do:** fill your bag completely, then kill something that drops an item.
      **Expect:** "Your bag is full" and a **loot window** with the leftovers, which you can take for 60 seconds after making room.
- [ ] **Do:** at Hilda, click **Browse goods**.
      **Expect:** a list with Minor Health Potion (20 g), Minor Mana Potion (20 g), Iron Helm (30 g), Hunting Bow (40 g) and Swift Boots (35 g).
- [ ] **Do:** buy a potion.
      **Expect:** the gold is taken and the potion is in your bag. Buying without enough gold is refused.
- [ ] **Do:** with the shop open, right-click a Wolf Pelt in your bag.
      **Expect:** sold for a quarter of its price (2 gold). Quest items can't be sold.
- [ ] **Do:** take damage, then right-click a Health Potion (or put it on the action bar and press its key).
      **Expect:** it heals 40% of your max HP and works in combat. Then both potion types are on a 30-second cooldown.

## 7. Enemies and flanking (Greenfields)

Each enemy shows its name and level ("Goblin Shaman Lv2").
- [ ] **Wolves** (level 1) near the entrance: fast, simple chasers.
- [ ] **Goblin Shamans** (level 2) on the hill at the top (north) of the map:
      **Expect:** they keep their distance, shoot purple bolts (your own Fireballs are orange) in straight lines, and step back when you get within 2 tiles. Stepping out of their line dodges the bolt.
- [ ] **Bandit Brutes** (level 3) at the bottom (south) of the map, across the river:
      **Expect:** they move slowly but hit very hard (Crushing Blow).
- [ ] **Fen Skirmishers** (level 4) on the high plateau on the right (east) side, up the ramp:
      **Expect:** very fast; they try to get beside or behind you before attacking. Keep turning to face them.
- [ ] **Flanking:** attack an enemy from its side, then from behind (melee abilities like Strike only).
      **Expect:** "Flank" for +25% damage from the side, "Backstab" for +50% from behind (which never misses). Enemies get the same bonus against you.
- [ ] **Leash:** pull an enemy far from its home.
      **Expect:** it gives up, heals fully, can't be hit, and walks back.
- [ ] **XP by level:** compare the XP from a level-1 Wolf at level 1 with the XP at level 4 or higher.
      **Expect:** much less XP once the enemy is 3+ levels below you. Higher-level enemies give bonus XP.

## 8. The elite: Old Grizzlehide

- [ ] **Expect:** a much bigger red diamond with a gold outline, labelled **"Elite Old Grizzlehide Lv5"**, walking a loop through the middle of Greenfields, across the middle bridge.
- [ ] **Do:** watch him without getting close.
      **Expect:** he keeps walking his route.
- [ ] **Do:** fight him alone.
      **Expect:** you lose. He has **Cleave** (hits everyone in front of him and beside that tile) and **Charge** (rushes 2–4 tiles straight at you and hits hard).
- [ ] **Do:** run far away from him.
      **Expect:** he goes back to where you pulled him, then carries on with his patrol.
- [ ] **Do:** fight him with a full group of 4 at around level 5.
      **Expect:** beatable with a tank, healing and damage. He drops 30–60 gold and sometimes the **Grizzlehide Mantle** (purple, Epic) or **Ranger's Gloves** (blue, Rare). He comes back after 5 minutes.

## 9. Levels, item growth and mastering abilities

- [ ] **Expect:** on level-up, a "You reached level N!" message, and your HP and mana fill up.
- [ ] **Expect:** after a level-up, the character sheet's "growth" column has gone up for the stats of the items you were wearing.
- [ ] **Expect:** each kill also gives a little AP (2 per Wolf) to the abilities of your equipped items; each level-up gives 10 AP.
- [ ] **Do:** reach the AP needed (e.g. Strike 20).
      **Expect:** "You mastered Strike!" Unequip the Sword: Strike still works.

## 10. Quests

General
- [ ] **Do:** talk to Old Maren.
      **Expect:** "! Word to Hilda" in her dialogue. Clicking it shows her request, the objective and the rewards, with **Accept** and **Not now**.
- [ ] **Do:** click **Accept**.
      **Expect:** "Quest accepted" in the message log; the quest appears in the **tracker** on the right edge of the screen and in the **quest log (L)**.
- [ ] **Do:** open the quest log (L).
      **Expect:** a list of your quests on the left; details, objectives, "Hand in to" and rewards on the right; an **Abandon quest** button.

The five quests
- [ ] **Word to Hilda** (talk). **Do:** talk to Hilda.
      **Expect:** the objective gets a green check, and her dialogue offers "? Word to Hilda (complete)". Hand it in: 40 XP, 5 gold and 2 Health Potions.
- [ ] **Wolves at the Gate** (Captain Rowan, kill quest, chain part 1). **Do:** kill 4 Wolves.
      **Expect:** the tracker counts 1/4 … 4/4, then turns gold with "Return to Captain Rowan", and a **?** appears over Rowan. Hand in: 120 XP and 20 gold.
- [ ] **Chain lock:** before finishing part 1, Rowan does **not** offer "The Bandit Camp". Afterwards he does (new **!**).
- [ ] **The Bandit Camp** (chain part 2, reach + kill). **Do:** find the camp at the bottom (south) of Greenfields and break 2 Bandit Brutes.
      **Expect:** "Find the bandit camp" ticks off when you get close to the camp; the brutes count 1/2, 2/2. Hand in to Rowan.
- [ ] **The Beast of Greenfields** (chain part 3). **Do:** kill Old Grizzlehide (bring friends).
      **Expect:** hand-in shows three reward buttons (Greataxe, Frostweave Robe, Acolyte's Leggings). Hovering one shows its tooltip with comparison; clicking one completes the quest and gives that item.
- [ ] **World event:** the first time anyone hands in The Beast of Greenfields, everyone in town gets "Bells ring in Millbrook: Old Grizzlehide is dead!", and from then on Captain Rowan greets everyone differently.
- [ ] **Goblin Fetishes** (Old Maren, needs level 2, collect). **Do:** kill Goblin Shamans **before** accepting.
      **Expect:** no fetishes drop.
      **Do:** accept and kill Shamans again.
      **Expect:** Goblin Fetishes drop (gold "Quest item" in the tooltip) and the tracker counts them up to 5. More stop dropping once you have 5.
      **Do:** hand in.
      **Expect:** the fetishes leave your bag and you pick one of Iron Helm / Swift Boots / Hunting Bow.

Edge cases
- [ ] **Do:** try to hand in a quest before it's done.
      **Expect:** the NPC shows "(in progress)" with your progress, and no hand-in button.
- [ ] **Do:** hand in a quest with an item reward while your bag is completely full.
      **Expect:** "Your bag is full", and nothing is lost. Make room and try again.
- [ ] **Do:** abandon a quest from the quest log.
      **Expect:** it disappears; its giver shows **!** again; progress starts over if you take it again.
- [ ] **Do:** quit and restart in the middle of a quest.
      **Expect:** progress is kept.

## 11. Death, graveyards and resurrection

- [ ] **Do:** die (for example to Grizzlehide).
      **Expect:** "You have died." with a **Release to graveyard** button (R also works).
- [ ] **Do:** release.
      **Expect:** you come back at the nearest graveyard in your zone (in Greenfields: the right-hand side; in town: the top corner) with half health and mana.
- [ ] **(2+ players)** Another player with the Holy Charm targets your body and casts **Resurrect**.
      **Expect:** you stand up where you died with 30% health and mana.

## 12. Playing together (2–4 players)

- [ ] **Do:** one player clicks **Host Game**, the others **Join Game** with the host's address (on one computer: `127.0.0.1`).
      **Expect:** everyone appears in town and sees each other with names and levels; party frames show at the top left.
- [ ] **Up to 4:** a fifth player trying to join gets "The game is full."
- [ ] **Joining late:** while others are already out in Greenfields, a new player joins.
      **Expect:** they start in town and can walk out to meet the others.
- [ ] **Bring your own hero:** join someone else's game with a character you levelled solo.
      **Expect:** same level, gear, gold and quests as in your own game. Afterwards, that character keeps what it earned there.
- [ ] **Personal loot:** two players kill a Wolf together.
      **Expect:** each gets their own loot message and items; nobody can take the other's drops.
- [ ] **Shared kills:** both players have "Wolves at the Gate". One kills a Wolf while the other stands nearby (or helped).
      **Expect:** both trackers go up. A player far away (more than about 15 tiles) gets no credit.
- [ ] **Shared XP:** XP from a kill is split between the players who fought it.
- [ ] **Private info:** you can't see other players' bags, gold or quests.
- [ ] **Zones:** players in town don't see what happens in Greenfields, and the other way around.
- [ ] **Leaving the field in combat:** try to walk back into town while in combat.
      **Expect:** refused until the fight is over.
- [ ] **A guest leaves:** close one guest's window.
      **Expect:** their hero vanishes for everyone, and enemies that were fighting them calm down.
- [ ] **The host leaves:** close the host's window.
      **Expect:** guests return to the main menu with a message that the host left.

## 13. After the session

- [ ] Each player's character kept its progress (level, gear, bag, gold, mastered abilities, quests).
- [ ] **World event persists:** host again after Grizzlehide's quest was handed in in an earlier session.
      **Expect:** Captain Rowan still uses his "after" greeting.

---

## Reporting a problem

For each problem, write down:
1. **Section and step** (e.g. "10, Goblin Fetishes").
2. **What you did**, step by step.
3. **What you expected** and **what happened instead**.
4. Solo or multiplayer, and whether you were the host or a guest.
5. A screenshot if anything looks wrong on screen. The art is placeholder; we mainly need to know whether it's readable.

Things the developer could **not** check without a screen, so please look closely:
tile drawing order on hills, overlapping labels, the size of the elite, the "!" / "?"
markers, the quest tracker's position, and the dialogue and quest log windows.
