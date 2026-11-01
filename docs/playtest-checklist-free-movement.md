# Playtest checklist: free movement and mouse-aimed attacks

For a non-programmer. Tick each box; if something looks wrong, note where you were
(the zone and roughly where), what you pressed and what you saw. Shortcuts in the
debug console (`): `goto <zone>` (for example `goto greenfields`, `goto enemy_testing`,
`goto crossing`), `level 10`, `heal` (also resets cooldowns), `master <ability>`
(for example `master F07`), `spawn <enemy> [level] [count]` (for example
`spawn bandit_brute`). The **Enemy Testing Grounds** (north gate of Millbrook) have a
pen for every enemy and a training dummy by the entrance.

## 1. Moving
- [ ] **W** walks up the screen, **S** down, **A** left, **D** right. Two keys together
      walk diagonally (W+D = up-right on screen), and diagonals are not faster.
- [ ] You are no longer stuck to tiles: you can stop anywhere, between tiles.
- [ ] Starting and stopping feel quick but smooth (full speed almost at once, no
      sliding when you let go).
- [ ] Speed: in town, crossing about 3 tiles takes about a second. It is the same
      speed in a fight.
- [ ] Out of combat the hero faces where it walks. In a fight it faces the mouse,
      even while walking another way.
- [ ] Walls, houses, rocks, hedges and water stop you; you slide along them instead
      of getting stuck. Corners don't catch you.
- [ ] Other players and enemies push you aside instead of overlapping; a heavy enemy
      (the Bandit Brute, Grizzlehide) barely moves when you walk into it.
- [ ] An enemy in the middle of an attack (a red shape on the ground) doesn't move
      when you walk into it.

## 2. Heights, slopes and falls
- [ ] Walk up a ramp (Greenfields: the ramp to the high plateau): you climb smoothly.
- [ ] Walk at a cliff that is too high to climb: it stops you like a wall.
- [ ] Step off a 1-level ledge: you step down smoothly.
- [ ] Walk off a 2–3-level drop: you fall (it looks like gravity pulls you down, with a
      shadow on the ground below), no damage. You can't steer while falling, and a
      cast in progress is cancelled.
- [ ] Walk off a drop of 4 or more levels (Greenfields' plateau edge): you fall and
      lose some health (about 10% per level above 3). It never kills you.
- [ ] Ranged attacks from higher ground still deal a little more damage.

## 3. Aiming (each kind of ability)
Hold an aimed ability's key to aim, release to cast (with a timing bar, the bar starts
at once and the attack goes where the mouse points at the end).
- [ ] **Cone, Slash (starter sword) and Smash (Iron Mallet):** a short blue cone in
      front of you, toward the mouse. Slash swings as soon as you press the key. Hits
      every enemy in the cone, at any angle, not only straight lines.
- [ ] **Projectile, Fire Dart (Spark Scroll), Frost Shard, Aimed Shot:** a blue lane
      toward the mouse; the shot flies along it and stops at the first enemy (or a wall).
- [ ] **Line, Fire Whip (Lash of Embers), Water Pulse (Wave Scroll):** a blue band
      toward the mouse at any angle; hits everyone on it; Water Pulse pushes them along.
- [ ] **Circle, Fireball (`master F07`):** a blue circle under the mouse. Aim farther
      than its range: the circle stops at the edge of the range. It lands after a
      short red warning.
- [ ] **Lob, Rock Throw (Pebble Scroll):** lands where you aimed after a short arc,
      over low walls.
- [ ] **Around you, Seismic Stomp and Ground Slam:** a circle around your hero.
- [ ] **Dash, Flame Dash (Scroll of Burning Feet) and Lunge (Traveler's Longsword):**
      the path shows; you dash toward the mouse (or your target) and stop at walls and
      enemies. Flame Dash leaves burning tiles behind you.
- [ ] **Targeted, Fire Punch, Water Whip, Healing Touch, Gust, Air Palm, Air Blast,
      Quick Shot…:** they use your target (click an enemy or press Tab) and say "out of
      range" when it is too far; walls in between block them.
- [ ] **Still on tiles, Burning Ground, Ice Spikes, Raise Pillar, Earth Wall:** the
      highlight snaps to the tile under the mouse, like before.
- [ ] **Air Step:** a short burst of speed (about 4 s).
- [ ] Knockbacks (Air Palm, Air Blast, Blazing Combo) slide the enemy straight away from
      you and stop at walls; a wall hit hurts a little more.
- [ ] Red when it can't be cast (out of range, nothing in sight); blue otherwise.
- [ ] Timing bars, cooldowns, the global cooldown, crits and threat still work as before.

## 4. Enemies
- [ ] Enemies run after you smoothly around walls and up ramps (no tile hopping) and
      don't get stuck on corners. Wolves are a little faster than you; the Bandit
      Brute and the husks are slower (you can walk away from them).
- [ ] Wolves still howl and call their pack.
- [ ] Patrols (Grizzlehide in Greenfields, iron wolves on the Windsteppe) walk their
      loop calmly, then run when they spot you.
- [ ] Pulled too far, an enemy gives up and walks home.
- [ ] The **Sunscale Drake** (Boss Arena of the testing grounds) is big: you can't walk
      through its body. It flies over low walls and water.
- [ ] Escorts (quest 1-03 Wells for the Windsteppe, 1-04 Grain for Deepcut) walk their
      road smoothly and wait when nobody is near.

## 5. Dodging telegraphs
Big attacks show a red shape on the ground first. Walk out of it in time and you take
no damage. Try each one standing still (you get hit) and walking out (you don't):
- [ ] **Bandit Brute, Crushing Blow:** a wide red cone in front of it (0.8 s). Step
      back or to the side.
- [ ] **Old Grizzlehide, Cleave** (cone) and **Charge** (a red lane toward you, 1 s):
      step out of the lane.
- [ ] **Boar, Tusk Charge** and **the Foreman, Mine-Cart Charge:** red lanes.
- [ ] **Salamander Hound, Cinder Pounce:** a red circle beside you on its side; move
      about a tile away (not toward it).
- [ ] **Goblin Shaman, Shadow Bolt:** a purple bolt you can sidestep.
- [ ] **Sunscale Drake:** Sunfire Breath (a long cone, 0.8 s, then fire on the ground)
      and Searing Dive (a lit lane, 1 s).
- [ ] **The Foreman (the Silent Shaft):** Ground Slam (a red circle under you, 1 s).
- [ ] Wolf, hound and boar bites and the drake's Talon Rake are quick: they are meant
      to land if you stand next to them.

## 6. Co-op (two or more computers)
- [ ] Your own hero moves the instant you press a key, also on the computer that joined.
- [ ] Other players and enemies move smoothly on your screen (no jerks or jumps).
- [ ] Bumping into another player pushes you both a little; nobody overlaps.
- [ ] A dodge works the same for the player who joined: walk out of a red shape and
      the hit misses on every screen.
- [ ] After a knockback or a teleport (release, lift, zone edge) everyone sees you in
      the same place.

## 7. Values to judge by feel (tell me what you'd change)
- Walking speed 3 tiles/s, the same in and out of combat (`content/rules/movement.tres`).
- Acceleration (full speed in 0.1 s) and stopping (0.08 s).
- Body sizes: heroes 0.3 tiles, wolves 0.35, big enemies 0.45, the drake 1.35.
- Melee reach: Slash 1.4 tiles at 100°, Smash 1.4 at 70°; enemy bites 1.2 at 70°.
- Enemy speeds: hound 3.5, Skirmisher 3.4, wolf 3.25 … Brute 1.7 tiles/s.
- Telegraph times: Crushing Blow 0.8 s, Cleave 0.7 s, charges 1.0–1.1 s, Ground Slam 1.0 s.
- Air Step as +40% speed for 4 s.
- Fall damage: 10% of max health per level above 3, at most 60%.
