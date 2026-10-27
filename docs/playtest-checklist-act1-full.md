# Playthrough checklist: all of Act I, "The Floor Guild" (1-01 to the end screen)

For the whole party, no programming needed. Play Act I from new characters, as
a group of three or four if you can: the dungeon at the end is built for that.
Tick each box and write down anything that reads wrong, feels unfair, or breaks.
Every line of dialogue is in `content/dialogue/act1.json`.

Expect about 2–3 hours and level 12 at the end.

## Before you start

- [ ] **Connecting.** One of you hosts (main menu → Host, port 7777); the others
      choose Join and type the host's address (`127.0.0.1` on the same computer, the
      host's local IP on the same network, or their public IP with port 7777/UDP
      forwarded over the internet). More detail in `docs/local-multiplayer-testing.md`.
- [ ] Everyone starts in Millbrook and sees everyone else.
- [ ] **Escape menu → Gameplay test.** The **Dungeon testing** box should be ticked in
      a debug build. Ticked, any party size may enter a dungeon; unticked, the real rule
      applies (3 players at least). Leave it ticked if fewer than three of you play.
- [ ] Handy debug commands (` key): `goto <zone>` (town, crossing, deepcut_road,
      deepcut, windsteppe, silent_shaft), `level <n>`, `heal`.
- [ ] **Co-op quests.** When one of you accepts a quest, the others get a "Join them?"
      note at the top of the screen. Join takes the quest without walking to its giver.

## Part 1: The Floor Guild's first missions (levels 1–10)

Follow `docs/playtest-checklist-act1-quests.md` for each of these. The short version:

- [ ] **1-01 The Guild Comes to Millbrook:** Maren Voss by Millbrook's south bridge;
      drive off 3 wolves and 2 boars (boars mark a red tile before charging: step off it).
- [ ] **1-02 Applicants Wanted:** Maren at the Crossing's Guild Hall; talk to Warden
      Dorne and Quartermaster Harrow.
- [ ] **1-03 Wells for the Windsteppe:** escort the well-diggers to Tsaga's Camp and kill
      4 iron wolves; hand in to Saran. Let them die once: the quest fails and can be retried.
- [ ] **The White Death** (side): 4 iron wolf pelts and the winter stores to Elder Tsaga.
- [ ] **1-04 Grain for Deepcut:** escort the grain wagon down the Road to Deepcut; hand in
      to Steward Brann in Deepcut.
- [ ] **Shift Bell** (side, from the Mine Board): clear the Collapsed Shaft, put down 3 Human
      Husks, talk to Miner Ostrik. **New:** you hand it in to Ostrik himself.
- [ ] **1-05 Fever in Millbrook:** Odo, Healer Wenna, then examine the grey river in three places.
- [ ] **1-06 Recognition:** Maren sends you to Prince Caedan at the hall steps. When it is
      handed in, a message says Steward Brann went down into the deep seams alone.
- [ ] **Brann is gone from Deepcut** after 1-06 (his office terrace is empty).
- [ ] **Pins on the Map** (side): four troubled places, then the Guild Map.
- [ ] Rewards along the way cover all seven trees; you should be around **level 10** now.

## Part 2: 1-07 The Silent Shaft (the dungeon)

### Getting in
- [ ] Caedan (Guild Hall steps) offers **1-07 The Silent Shaft** (level 8 and up). His
      offer says to take three people at least. Accept it; the others join.
- [ ] In Deepcut, walk into the **Mine Entrance** in the cliff north of the mine yard.
- [ ] Without the quest, a red message says you need it first.
- [ ] With Dungeon testing **off** and fewer than three of you: "You need a party of 3 to
      go in". With it on, or with three or more, you go in.
- [ ] Inside, the music changes to the dungeon's (today the draft track plays, because the
      dungeon track isn't recorded yet).
- [ ] Everyone who walks in ends up in the **same** copy of the mine (you all see each other).
- [ ] Walking back out (the tile at the far west end of the entrance hall) takes you
      to Deepcut. Coming back within a minute finds the mine as you left it; after a minute
      away it is fresh again.

### Section 1: the upper tunnels
- [ ] Dark rock, rails and an abandoned ore cart; side tunnels choked with rubble; the
      floor turns grey further in.
- [ ] Silent miners turned into **Human Husks** (level 8): slow, heavy hitters.
- [ ] The **Mine Lift** (a cart and a labelled platform in the south-east corner): step onto
      the platform tile and you ride down. A message says the lift rattles along its shaft.
- [ ] The quest's first step ("Ride the lift down to the deep seams") ticks when you arrive.
- [ ] The lift works back up too (the platform beside where you arrive).

### Section 2: the deep seams
- [ ] Sunstone seams glow **gold** in the walls to the east (untouched) and are **grey**
      to the west (mined out), with gold and grey crystal clusters on the floor.
- [ ] A raised grey ledge and a higher seam face, with ramps: Husks stand at different
      heights. Pillars block line of sight (skillshots and targeted spells need a clear view).
- [ ] **Optional:** the **Old Shift Office** south of the seam hall, through a narrow cut:
      the **Grey Overseer** guards a strongbox. He drops potions, a Sunstone Shard and often
      a tier-2 scroll. Skipping him is fine.
- [ ] The drift east leads to **The Foreman's Chamber**; "Find where the silence comes
      from" ticks at its door.

### Section 3: the Foreman and the Grey Heart
- [ ] **The Foreman** (gold "Elite" name): the Steward, now a hulking corrupted miner. Behind
      him on a raised dais pulses **the Grey Heart**, a cracked black-and-gold crystal
      leaking grey smoke, ringed while it is shielded ("Shielded by the Foreman").
- [ ] The boss music should start (today the music simply carries on: no boss track yet).
- [ ] **Phase 1 (full to 60% health): tank and spread.**
  - [ ] **Ground Slam:** a 3×3 square around his target turns red for almost 2 seconds,
        then the hammer lands. Whoever is not his target should stand apart and step out.
  - [ ] **Mine-Cart Charge:** a tile 2–5 away is marked for about a second, then he barrels
        onto it. Step off the mark.
  - [ ] **Threat:** he hits whoever has done the most to him. The tank should start the
        fight and taunt him back (Seismic Stomp) if he turns on a caster.
  - [ ] Hitting the Heart now shows **"Immune"**.
- [ ] **Phase 2 (below 60%): "Phase 2!"** floats over him.
  - [ ] Every 12 seconds the Heart pulses ("Pulse!"): a **Grey Husk** climbs out (at most two
        at a time) and a few tiles around you turn grey.
  - [ ] Standing on grey ground **slows** you and **drains your mana**. Move off it.
- [ ] **Phase 3 (below 25%): "Phase 3!"**, and the message log says he flies into **Grey Fury**
      (he hits harder and more often).
  - [ ] The Heart's shield drops: now **damage the Heart**. It keeps greying the floor every
        9 seconds until it breaks.
  - [ ] The Foreman can't be finished while the Heart beats (he stops at a sliver of health).
- [ ] **Breaking the Heart ends the fight:** the Foreman falls with it, the husks and the
      grey vanish, everyone who fought gets the kill, XP and their own loot. A message says
      someone is coming down; **Prince Caedan** appears at the chamber door with a speech bubble.
- [ ] **Party wipe:** let everyone die once (in phase 2 is a good test). "Your party has
      fallen", then 3 seconds later everyone stands up at the dungeon's entrance with half
      health. Walk back (two sections and the lift):
  - [ ] the Foreman is at the health where his phase began (60% if you wiped in phase 2), not full;
  - [ ] he's still in that phase (the pulses go on); the Heart is whole again.
- [ ] One player dying alone (not everyone) releases to the entrance as usual, or can be
      resurrected where they fell.
- [ ] **Party size:** with more players the Foreman, the Heart and the husks have more health
      and hit a little harder. Three or four players is the intended fight; one or two
      (testing only) should be hard and possible at best.

## Part 3: the end of Act I

- [ ] Talk to **Caedan** in the chamber. He is shaken (he knew Brann for twenty years), sees
      that the Sunstone paid for everything the Guild did, and asks you to join him in the
      **Ember Hand**. You get two choices along the way; read both if you can (one of you
      each).
- [ ] Hand in 1-07 to him: XP, gold, potions, a choice of Fireball, Glacier or Bulwark
      scroll. The world announces the end.
- [ ] When the conversation closes, the **End of Act I** screen appears over a darkened
      world: "Act I: The Floor Guild", a line of story, and a table with each of you (level,
      enemies defeated, damage, healing, deaths, quests). Do the numbers look about right?
- [ ] **Return to The Crossing** takes you there.
- [ ] Maren Voss now greets you differently.
- [ ] **Saved:** leave the game and come back with the same character: 1-07 shows as
      done (quest log), and the host's world remembers Act I is over (Maren's greeting).
- [ ] You should be about **level 12**.

## Sound (no files yet; just check nothing is missing that should be there)

- [ ] `AUDIO_SPEC.md` lists the new keys: `music_dungeon_silentshaft`, `music_boss_foreman`,
      the Foreman's and the Heart's sounds (phase, enrage, reset, pulse, break), the dungeon
      events (enter, lift, wipe, wake, act complete), `ambience_silent_shaft`,
      `footstep_mine_floor`, `footstep_grey_rock`.

## Notes for us

- Is the dungeon about 20–30 minutes?
- Was the boss fair with three? With four? Which mechanic killed you most?
- Did the grey ground read clearly as "get off it"?
- Was the Ember Hand turn clear and surprising?
