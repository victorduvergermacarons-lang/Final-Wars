# Playtest checklist: Act I quests and dialogue

For a non-programmer. Tick each box; if something looks wrong, note what you did and
what you saw. The story is a placeholder (every line is in
`content/dialogue/act1.json`, ready to rewrite). If a step needs a higher level, open
the debug console (`) and type `level 4`.

## People and places
- [ ] In Millbrook: a **Guild Board** (blue board on posts, "!" over it), **Warden Iska
      Dorne** (blue, Floor Guild), **Sabra Venn** (red, Ember Hand), **Ilyth the Seer**
      (pale blue, Vael). Hilda, Rowan and Maren are grey (townsfolk).
- [ ] In Greenfields, east past the river: the **Bedrun camp**: the **Mine Board**
      (ochre), **Foreman Hadda Brannoc** (ochre) and the **ore caravan** (a wagon).
      Near them, the **Collapsed Shaft**; in the far south-west, the **Vael Standing Stone**.
- [ ] Each has its name above it. Standing next to one shows "[E] Talk" ("[E] Read" for
      boards, "[E] Use" for objects).

## Dialogue
- [ ] Talk to Warden Dorne (E): a paper box at the bottom of the screen shows a blue
      frame with "WD", her name, "Floor Guild", and what she says.
- [ ] Pick "What is the Floor Guild?": her answer, then **Continue**, then **Back**
      returns to her greeting. **Goodbye** closes it. Walking away closes it too.
- [ ] Ilyth also has a question to ask.

## The main chain
- [ ] **Guild Board** → "! The Guild's Summons": the offer says "Main quest ·
      Millbrook", lists the objective and reward, and the buttons read **Take the
      notice** / **Leave it pinned**. Take it: it appears on the tracker (right side).
- [ ] Talk to Dorne: the tracker says to return; "?" over Dorne. Hand it in.
- [ ] Dorne → **Ash on the East Road**. Choose **Not today** first: she answers, then the
      offer is still there. Accept it. In Greenfields, three spots glow (a cyan ring
      with "?"). Stand beside one: "[E] Examine". Press E: you describe what you find
      (your own portrait). The tracker counts 1/3, 2/3, 3/3. Hand in to Dorne.
- [ ] Sabra Venn → **The Ember Hand's Writ**: you get a **Sealed Writ** in your bag.
      Talk to Foreman Brannoc: she takes it ("Delivered"), and you hand the quest in
      to her.
- [ ] Brannoc → **Ore for Millbrook**. Talk to the caravan: it says it's setting off and
      starts rolling west, with a health bar. Walk more than 6 tiles away: it waits.
      Stay close: it walks to the glowing spot near the town road. Wolves on the way go
      for the caravan; fight them off (healing spells work on it). On arrival the
      quest is ready: hand it in to **Dorne** in Millbrook.
- [ ] Let the caravan die once (lead it into wolves and stand back): "lost!", the quest
      shows **failed** in the tracker and the log, Brannoc shows "!" again with
      "(try again)" and a different offer line, and the caravan is back at the camp
      about 5 s later. Accept again and finish it.
- [ ] Ilyth → **What the Stone Remembers**: use the standing stone (you describe a
      vision), kill three wolves, hand in to Ilyth: the "End of Act I (prototype)"
      announcement, and Dorne greets you differently afterwards.

## Side quests
- [ ] Mine Board → **The Collapsed Shaft**: use the shaft, hand in at the board ("?").
- [ ] Guild Board → **Guild Patrol: The Bridge**: walk to the north bridge (it glows), hand
      in to Dorne.
- [ ] Mine Board → **Bandits on the Ore Road** (level 3): two brutes at the bandit camp,
      hand in to Brannoc.
- [ ] The quest log (L) lists **Main quests** and **Side quests** separately, each with
      its area; Rowan's and Maren's quests still work as before (side quests).

## Co-op (two or more players, see docs/local-multiplayer-testing.md)
- [ ] When one player talks to someone, the others see a speech bubble over that NPC;
      only the talker gets the dialogue box.
- [ ] When one player accepts a quest, every other player in the same map who can take it
      gets a note at the top of the screen: "<name> took on a quest. Join them?" with
      **Join** / **Not now**. Join works from anywhere in the map.
- [ ] Progress counts for party members on the quest who are nearby (about 15 tiles):
      kills, talks, examined spots, a delivery, the caravan's arrival. A player far
      away doesn't get it.
- [ ] Each player hands in for themselves and gets their own rewards.
- [ ] Leave and rejoin: each player's quests (and examined spots) are as they left them.
