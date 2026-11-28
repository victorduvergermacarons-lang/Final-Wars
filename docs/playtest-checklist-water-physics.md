# Playtest checklist: water physics (branch `feature/water-physics`)

For anyone: no programming needed. Make a **Water** character (it starts with a full
Water Pouch of 200 water). Debug builds: the console (`` ` ``) has `master W12`,
`master W04`, `master W07`, `mastery Water 300` and `level 10` to unlock the abilities below.
Escape → Gameplay test → "Show water rope points" helps to see the water.

## 1. The screen and the menu
- [ ] Main menu: pick an old character and press **Delete**. A box asks "Delete <name>? This
      can't be undone." Cancel keeps it; Delete removes it.
- [ ] Two characters keep **their own action bars**: change one bar, log in with the other,
      it has its own.
- [ ] There are no stance buttons on the bar. Every learned ability is on it; Water ones have a
      small number in a corner (their stance), lit while you hold that stance.

## 2. Stances and water
- [ ] Press **Water Whip** out of any stance: you **enter Water stance 1**, nothing is cast.
      Press it again: it casts.
- [ ] Entering stance 1 away from a river: the rope grows out of the hip **one point at a
      time** (about 3.5 s to full; it was 7 s). Hover Water Whip: "Water: x / 24 in stance 1, power y%".
- [ ] Near a river (3 tiles), the water flows **from the river** instead.
- [ ] Empty pouch (spend it, far from water): the rope stops growing.
- [ ] A short rope hits softer (half a rope: 60%); casting with no water says
      **"Not enough water"**.
- [ ] Stand still out of combat for **10 s** without casting: the stance drops and the water
      flows back into the hip (tail first). The pouch gets it all back.
- [ ] **Shift**, a stun or a knockback do the same.
- [ ] Press a stance 2 ability (Leeching Tide) with less than **27** water in all: "Not enough
      water", nothing happens. With enough: the rope rises to the chest and closes into a
      **hoop**. Back to stance 1: the extra water spills as droplets.
- [ ] In stance 2 (the hoop), press **Water Whip** or **Healing Touch**: the hoop turns back
      into the rope and the ability goes off a quarter of a second later, without a second
      press.
- [ ] **Hilda** in Millbrook sells the Water Pouch.
- [ ] **E at a river** fills the pouch: "Filling Water Pouch (x / 200)" over you; empty to
      full takes 10 s. Walking or getting hit stops it.

## 3. The abilities
- [ ] **Water Whip:** goes at once; the whole rope flies, the hit lands half a second later.
      A bar "Call the water back" appears: press the key again (or Space / right-click).
      At the yellow mark (0.5 s) all the water comes back; at once, half; late, little;
      never, none (a message says how many came back). Pressed after 0.5 s, the water waits
      on the ground until you press. Pressed **before** 0.5 s (say at 0.2 s): the hit still
      lands, then that share comes home, and the rope doesn't vanish afterwards.
- [ ] **Healing Touch:** the rope winds round the ally and climbs to above the head; the heal
      lands about 1.2 s after the cast. Heal someone badly hurt (the whole heal is used): the
      **whole rope** climbs to the top of their head and turns to mist, not just its tip.
      Heal someone already at full health: the water comes back in **one smooth arc** from
      the top of the helix to your orbit (no turning back down); on yourself it unwinds into
      the orbit. It heals half again as much as before.
- [ ] **Water Shield:** the **whole** rope goes out (none of it disappears first) and becomes
      a ball of yarn round the target after 0.8 s, slowly stretching and thinning. While it is
      up, your rope **doesn't grow back**.
- [ ] With the shield up, press **Water Whip** (or Healing Touch, or a stance 2 ability): the
      shield ends, its rope flies home, then the whip goes. Only what was left of the shield
      comes back (a half-used shield: half a rope).
- [ ] With a shield on **yourself**, press **Frost Shard**: the shard leaves the bubble toward
      the cursor; the bubble gets shorter and absorbs less (a sixth of a full one per shard).
- [ ] With a shield on an **ally**, press **Frost Shard**: the shard leaves the ally's bubble
      on the side away from you and flies on along the line from you through them (wherever
      the cursor is).
- [ ] The shield's ball of yarn slowly stretches and thins. Hits dent it and splash; it gets shorter as it
      absorbs; below a quarter, gaps open. Broken: it bursts and the water soaks in (none comes
      back). Let it run out: what's left comes home. The tooltip shows the absorb number.
- [ ] **Frost Shard:** goes at once; 4 points of the rope (the side facing the target) break
      off, pull together and become a small ice shard drawn in pale ice (pointed ahead, a
      glint along its top), sparkling as it freezes. It shatters into little fragments and
      drops where it hits, or at the end of its range. Cooldown 0.5 s; it hits a third as
      hard as before.
- [ ] **Leeching Tide** (stance 2): the hoop opens and reaches the enemy; dark water flows
      back for 3 s, fading to blue in the hoop, which closes again at the end. It **doesn't
      heal**; the pouch gains 4 water every half second (24 in all, never over 200). The
      tooltip says so.

## 4. Pressing early
- [ ] Press any ability (Water Whip, Fire Punch, a potion…) just before its cooldown or the
      global cooldown ends (within about a third of a second): it goes off by itself the
      moment it's ready. Pressed a full second early, nothing happens.

## 5. Drawing
- [ ] The rope's shadow darkens the ground under it (a darker green on grass, a darker grey
      on stone), never a grey smear, and never twice as dark where two shadows cross.
- [ ] Walk round Millbrook's houses with the rope out: no wall shows through in a box round
      you, and the flower beds have no dark band under them.

## 6. Co-op (two to four players)
- [ ] Everyone sees the same ropes, hoops, shields and returns at the same moments.
- [ ] **Four waterbenders casting at once** in the same spot: the game stays smooth, nothing
      flickers, each rope stays with its hero (watch the frame rate and the shields).
- [ ] A shield on another player follows them as they walk.
