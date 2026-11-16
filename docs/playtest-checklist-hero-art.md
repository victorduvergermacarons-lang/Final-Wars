# Playtest checklist: hero art (4 facings and weapon sets)

The hero is drawn with the PL-01-1 art in all four facings, with the sword and bow
attacks from PL-02. Turn the hero by moving the mouse around them.

## Facings and movement
- [ ] Standing still, the hero breathes (idle) facing each of the four directions:
      down-left, down-right, up-left, up-right. Facing away shows their back, animated.
- [ ] Turning doesn't make the hero jump sideways; the feet stay on the same spot.
- [ ] Walking in each direction: the walk plays, and the feet roughly keep pace with
      the ground (no ice-skating, no running on the spot).
- [ ] Two players (host + join): both see the same frames at the same moment
      (cast, hit, falling, getting up).

## Abilities
- [ ] A Fire, Water, Earth or Air spell plays the cast animation when it goes off
      (after its timing bar, not at the start).
- [ ] With a sword in hand (Rusty Shortsword or Traveler's Longsword): Slash plays the
      sword slash, Lunge the sword lunge, the hero holding the sword.
- [ ] With a bow in hand (Hunter's Shortbow or Yew Longbow): Quick Shot and Aimed Shot
      play the bow animations.
- [ ] A hammer art (Smash, Ground Slam) and a potion play the plain cast for now.
- [ ] Without a weapon of that type the hero never shows the sword or bow.

## Hits, death and getting up
- [ ] Taking damage plays getting-hit.
- [ ] A stun (e.g. the Sunscale Drake's dive) knocks the hero down; they lie there
      until it ends, then get up (revived).
- [ ] Dying plays the death animation once, then the hero lies on the ground until you
      release or an ally resurrects you.
- [ ] Resurrected: the hero gets up where they lay. Released: the hero gets up at the
      graveyard.

## Known flaws in the drafts (used as they are)
- [ ] Getting-hit facing north-west (up-left): the hero falls to the ground instead of
      flinching.
- [ ] Walk facing north-east (up-right): stray white streaks in the last frames.

Screenshots of every animation in all four facings: `tests/visual/hero_art_shots.tscn`.
