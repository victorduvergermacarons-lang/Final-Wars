# Playtest checklist: Act I zones and region music

For a non-programmer. Tick each box; if something looks wrong, note where you were
(the zone and roughly where) and what you saw. Shortcut for any step: open the debug
console (`) and type `goto crossing` (or `town`, `deepcut_road`, `deepcut`,
`windsteppe`, `greenfields`, `enemy_testing`, `tidereach_shore`) to jump to a zone,
and `level 5` if the wolves are too much. Objects without art yet are simple
shapes with a small label that shows when you are near them.

## Millbrook (start here)
- [ ] A farming village: thatched houses, fields of tilled soil, a cobbled green
      with the **Village Well**, Hilda's stall, flowers, an orchard on a hill.
- [ ] A river runs through it: **grey upstream** (the south part, where it comes
      from the Crossing) and clear blue below the mill pond.
- [ ] The **Healer's Hut** (slate roof) in the south-west, Healer Wenna beside it.
      Talk to her: she mentions the grey river.
- [ ] Three ways out: the south gate (sign "Road to the Crossing"), the east side
      (Greenfields, as before), the north gate (Enemy Testing Grounds, as before).
- [ ] Die here and release: you come back by the Healer's Hut (Millbrook keeps
      its own graveyard).

## The Crossing (the hub)
- [ ] Walk out of Millbrook's south gate: you arrive at the Crossing's north gate.
- [ ] The **Floor Guild Hall** (big slate-roofed building, north-west) with Warden
      Dorne at its door; the **Guild Board** on the square; a well; three market
      stalls with **Tamsin Reed** (scrolls, weapons, gear) and **Odo the
      Apothecary** (potions): both sell.
- [ ] **The Crossed Keys Inn** (south-west), Innkeeper Bram and Sabra Venn beside it.
- [ ] The grey stream comes in from the east and flows north toward Millbrook; the
      east road crosses it on a stone bridge.
- [ ] High ground: a rocky hill in the north-east (a cliff on the stream side) and a
      ridge along the south edge.
- [ ] The **Graveyard Shrine** on a grassy knoll in the south-east, ringed by stones.
- [ ] Signs point west (Windsteppe), east (Road to Deepcut) and north (Millbrook).

## Road to Deepcut
- [ ] East from the Crossing: grass turns to red earth, and red canyon walls rise
      on both sides. The grey stream runs along the south.
- [ ] The road climbs past the **Lookout Ledge** (a ramp up to high ground on the
      north side; a Bandit Brute waits there). Two wolves near the west end.
- [ ] An abandoned ore cart by the road; signs at both ends.

## Deepcut
- [ ] A mining town in a red canyon: high red cliffs all round, red boulders.
- [ ] The **Mine Entrance** (dark timbered opening in the cliff north of the mine
      yard), ore carts, Foreman Brannoc, the ore caravan.
- [ ] The **Steward's Office** (red roof) on a raised terrace, Steward Orrin Marl in
      front of it, the **Mine Board** at the foot of its ramp.
- [ ] The polluted grey stream and its pond by the mine, flowing west out of town;
      a footbridge to **Miners' Row** (huts) south of it.
- [ ] The **Collapsed Shaft** (another opening, in the cliff spur north of the
      street) for the Mine Board's side quest.
- [ ] Two Salamander Hounds lurk near the canyon gate (west end).

## Windsteppe
- [ ] West from the Crossing: pale, cold grassland that rolls up and down, patches
      of dry yellow grass, a rocky ridge (Grey Ridge) in the north-west.
- [ ] **Tsaga's Camp**: round felt tents (gers), Elder Tsaga, a **Dry Well**, a stone
      cairn, a herd grazing nearby. A second, smaller camp in the south-east with
      its own dry well and herd.
- [ ] **Stone cairns** dotted across the steppe.
- [ ] **Iron wolves** (grey-steel wolves, level 3) walk loops in packs; one howls and
      the pack comes.
- [ ] The **Vael Standing Stone** on its hill (moved here from Greenfields).

## Respawning at the Crossing
- [ ] Die on the Road to Deepcut, in Deepcut or on the Windsteppe and release: you
      come back at the **Crossing's Graveyard Shrine** at half health, out of combat.
- [ ] Die at the Crossing: same shrine.

## The Act I quests in their new places
- [ ] Guild Board (the Crossing) → The Guild's Summons → hand in to Dorne (the Crossing).
- [ ] Ash on the East Road: the three scorched spots are still in Greenfields.
- [ ] Sabra (the Crossing) → the writ → Foreman Brannoc in **Deepcut**.
- [ ] Ore for Millbrook: the caravan sets off from the Deepcut mine yard and rolls
      down the street to the **canyon gate**; the hounds go for it. Hand in to Dorne.
- [ ] What the Stone Remembers (level 3): the stone is on the **Windsteppe** and the
      three wolves are **iron wolves**.
- [ ] The Mine Board's side quests (Deepcut) and the Guild Board's patrol (Greenfields'
      north bridge) still work.

## Music and ambience
- [ ] Title screen, Millbrook, the Crossing, Deepcut, the Road and the Windsteppe all
      play the draft track for now (no regional music exists yet except Tidereach).
- [ ] Go to the Enemy Testing Grounds (Millbrook's north gate), then walk off its
      **west end** (the gap in the hedge at the top-left corner, by the training
      dummy): you are on the **Tidereach Shore (test)** and the music **crossfades**
      (about 1.5 s) into the water track.
- [ ] Walk back east off the shore: it crossfades back to the draft.
- [ ] The water track loops back to its start after 75 s: expect a gap (it begins
      with 2.35 s of near-silence and ends at full volume; see AUDIO_SPEC.md).
- [ ] No ambience plays yet (no ambience files exist); the game doesn't complain.

## Co-op (two to four players, see docs/local-multiplayer-testing.md)
- [ ] Players can be in different zones at the same time (one in Millbrook, one at
      the Crossing, one on the Windsteppe…); each sees only their own zone's people
      and enemies.
- [ ] Walking between zones works for each player separately, never in combat.
- [ ] A quest prompt ("Join them?") reaches party members in the same zone only.
- [ ] Kills and other progress count only for party members in the same zone.
- [ ] A player who dies on the Windsteppe and releases goes to the Crossing; the
      others keep fighting on the steppe.
