# Playtest checklist: the Sunscale Drake

For a non-programmer. Tick each box; if something looks wrong, note what you did
and what you saw. The drake is a level-6 elite built for a group of four. To try it
alone, open the debug console (`) and type `level 40`, or use `spawn sunscale_drake`.

## Finding it
- [ ] Go to the Enemy Testing Grounds (the gate in Millbrook's north-east hedge) and
      walk the road east, past the Boss Arena gate and Old Grizzlehide's pen. The last
      pen holds the **Elite Sunscale Drake (Lv 6)**.
- [ ] Gold-and-crimson dragon, hovering. Its shadow sits on its tile, under its body.
- [ ] Walk around it: it faces down-left, down-right, up-left and up-right with the
      matching picture (right-facing views are the left ones mirrored).

## Flying
- [ ] It moves slowly (about 1.2 s per tile) but steadily, flapping.
- [ ] It flies over the low stone walls and hedges between pens; you can't.
- [ ] Its own burning ground and other fire on the floor never hurt it while it flies.

## Talon Rake (melee)
- [ ] Stand next to it: it kicks with its talons. The damage number appears as the
      talons swing through (about half a second after the kick starts).

## Sunfire Breath (about every 10 s)
- [ ] It rears back for **0.8 s** while a red **cone** (4 tiles long, widening) is
      outlined on the ground toward you.
- [ ] Then flames burst over exactly those tiles. Anyone still on them is burned.
- [ ] Step out of the cone during the rear-back: no damage.
- [ ] The cone's tiles stay orange (burning) for **3 s** and hurt anyone standing in them.

## Searing Dive (about every 14 s)
- [ ] From 2–5 tiles away, a red **lane 5 tiles long** glows toward you for **1 s**
      while it holds a poised pose.
- [ ] Then it dives along the lane. Anyone in the lane is burned and **shoved one tile
      sideways**; it ends at the far end of the lane (or before something it can't pass).
- [ ] The tiles it dove over burn for about **2 s**.
- [ ] Leave the lane before the dive: no damage, no shove.

## Grounding it (Air knockbacks)
- [ ] Hit it with **Air Palm** or **Air Blast** (Air scrolls). "Grounded!" pops up and a
      "Grounded" label shows under it for **3 s**. It can't act, and your hits do
      **25% more** damage (compare the numbers).
- [ ] While grounded, burning ground under it hurts it.
- [ ] Other knockbacks (e.g. Water Pulse) don't ground it.

## Molten Fury (enrage)
- [ ] Get it **below 30% health**: "Molten Fury!" pops up, the message log says it flies
      into Molten Fury, and it glows hotter (redder).
- [ ] From then on it uses its attacks more often (cooldowns about 30% shorter) and its
      burning ground lasts **5 s** instead of 3.

## Death
- [ ] It plays its dying animation once, lies still briefly, then fades away.
- [ ] In the testing grounds it comes back 10 s later. The Reset Shrine puts it back at
      once, at full health and without Molten Fury.

## Co-op
- [ ] Two players see the same telegraphs, flames, dive and animations at the same time.
