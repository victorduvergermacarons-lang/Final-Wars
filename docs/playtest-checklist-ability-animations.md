# Playtest checklist: ability animations and effects

The element abilities now have their own hero animations and effects. Rock Throw works
differently: you press twice. Fire Punch hits as soon as you press its key. Water Whip's
hold starts earlier.

Getting the abilities: use the debug console (` key) with `master E01`, `master E02`,
`master F01`, `master F02`, `master W01`, `master W02`, `master A01` and `master A02`, then
put them on the action bar from the Spellbook (P). `spawn wolf` gives you something to hit.

Try each one facing several directions: down-left, down-right, up-left, up-right, and
straight up, down, left and right. Move the mouse around your hero to turn.

## Rock Throw (Earth)
- [ ] First press: the hero drops into a rooted stance, and a rock rises out of the ground
      beside them. Then the hero holds the pose (a slow loop) and the rock bobs gently.
- [ ] A timing bar runs (3 seconds). While it runs, the hero can't walk.
- [ ] Second press (right-click or Space): the hero punches, and the rock leaves on the
      punch. It flies in an arc to where your mouse points, spinning, then breaks apart
      where it lands.
- [ ] An enemy standing where it lands takes damage. One a little to the side doesn't.
- [ ] Aiming further than the ability's range: the rock lands at the edge of the range.
- [ ] Not pressing a second time: when the bar ends, the hero throws the rock by
      themselves at the mouse. It does a bit less damage (like a missed timing).
- [ ] The cooldown starts when the rock is thrown, not on the first press.
- [ ] Pressing in the bar's crit zone (the yellow part) gives a critical hit.
- [ ] Two players: the other player sees the rock rise, wait, fly and break, at the same
      moments you do.

## Stone Skin (Earth)
- [ ] Casting it: the hero does the rooted stance, then turns grey, like stone.
- [ ] The grey tint stays while the buff lasts, while walking and using other abilities.
- [ ] When it ends, the hero plays the stone shattering, then looks normal again.
- [ ] Two players: the other player sees the grey tint and the shatter too.

## Fire Punch and Fire Kick (Fire)
- [ ] Fire Punch has no timing bar anymore: the punch plays and the damage appears as
      soon as you press the key.
- [ ] Its cooldown is still 2 seconds, and the other abilities still wait for the global
      cooldown after it.
- [ ] Fire Kick: the hero kicks, and an arc of flame sweeps out in front of them when the
      kick lands, pointing at the enemy.

## Water Whip and Healing Touch (Water)
- [ ] Water Whip's blue hold zone now starts earlier: at about 0.45 seconds, sooner
      than before (it was 0.75 s). It still ends at the same place.
- [ ] Letting go: the hero swings, and a lash of water curls out toward the target. The
      damage appears when the lash snaps, a moment after you let go, not when you let go.
- [ ] Healing Touch: the hero plays its own healing pose. The heal looks the same as
      before otherwise.

## Air Palm and Gust (Air)
- [ ] Air Palm: the hero pushes out a palm, and a spiral of wind shoots toward the enemy.
- [ ] Gust: the hero's own gust pose, with a wider spiral of wind sweeping outward.
- [ ] Both wind effects are see-through (you can see the ground through them).

## Looking for problems
- [ ] When an animation starts or ends, the hero's feet stay on the same spot. The hero
      shouldn't jump up, down or sideways.
- [ ] Effects point the right way in every direction. Effects pointing left aren't
      upside down.
- [ ] Effects are drawn in the right order: a wall or tree in front of an effect covers it.
- [ ] The rock's size next to the hero. It may look too big; say so if it does.
- [ ] Stone shattering: small dark specks may show at the hero's feet in a few
      directions (leftovers of the dirt mound in the art). Say if they're distracting.
- [ ] Anything that keeps playing after the ability ended, or a rock left floating.

Screenshots of every animation in all eight directions are in
`tests/visual/hero_art_shots.tscn`; screenshots of the effects are in `tests/visual/fx_shots.tscn`.
