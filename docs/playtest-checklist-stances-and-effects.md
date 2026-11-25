# Playtest checklist: stances and effects

Abilities are now cast through **stances**. Each element (Fire, Earth, Water, Air) has 5
stances, and each stance has 4 abilities ("branches"). This checklist also covers the new
effects: the pictures, whips, streams, waves, burning ground and the rest.

## Before you start
- Open the debug console with the ` key (top-left of the keyboard).
- `mastery fire 900` (and `earth`, `water`, `air`) opens every tier, so the stances have
  abilities in them. `master F01`, `master W02`… masters single abilities.
- `spawn wolf` puts a wolf next to you, something to hit.
- `fx <ability>` plays any ability's effects toward your mouse without hurting anyone, even
  abilities not in the game yet (for example `fx Fireball`, `fx F14`, `fx Tidal Wave`).
- `fx Fire:5` (or `Water:3`, `Earth:2`…) puts you in that stance so you can see its look.
- To slow everything down and look closely: Escape menu → Gameplay test → Game speed ×0.2.

## Stance keys
- [ ] Out of a stance, keys 1 to 0 are the action bar. Your element's stances 1–5 sit in
      slots 1–5 (coloured squares with the element's letter and the stance number).
- [ ] Press a stance key: you enter that stance. Its slot lights up, and a panel above the
      action bar shows the element, the stance number and its 4 abilities with their
      cooldowns.
- [ ] Entering a stance does not start the global cooldown (an ability right after works).
- [ ] In a stance, keys 1–4 cast its 4 abilities, and you stay in the stance. Slots 1–4 on
      the bar are dimmed meanwhile.
- [ ] Keys 5–0 still use their slots. Another stance there switches to that stance.
- [ ] **Shift** leaves the stance.
- [ ] Being stunned, silenced, rooted, put to sleep, knocked back, pulled or falling drops
      you out of the stance. So does dying.
- [ ] Entering Fire stance 1 throws a Fire Punch at your target, Earth 1 a Seismic Stomp,
      Water 5 Octopus Form, but only when they're off cooldown.
- [ ] Action bar pages are now Ctrl+1 to Ctrl+6 (they were Shift).
- [ ] You can drag any stance to any slot from 1 to 0.
- [ ] Two players: each sees the other's stance (the look around the hero).

## Stance looks (shown while you hold a stance)
- [ ] Fire 1: a ring of fire turning on the ground around you. Fire 2: a flame ribbon
      spinning. Fire 3: flames at your heels. Fire 4: a small sun bobbing over your head.
- [ ] Fire 5: a fire dragon (a flame ribbon for now) coiled around you. Using a stance-5
      Fire ability makes it uncoil toward where you aim, fade, and come back coiled.
- [ ] Earth 1–4: you turn to stone from the feet up: a quarter, half, three quarters, then
      all of you. Stone Skin turns a quarter of you to stone.
- [ ] Water 2: a water hoop at the waist. Water 3: a water sphere circling you. Water 5:
      water arms behind you, swaying.
- [ ] Air 3: an air ball circling you. Air 5: a see-through wind column.
- [ ] Earth 5, Water 1, Water 4, Air 1, Air 2 and Air 4 show only a faint coloured ring:
      their art isn't approved yet.
- [ ] Rings around you: the back half goes behind you, the front half in front.

## Effects from the approved pictures
- [ ] `fx` each of these and check it looks right: Fire Punch (a burst on the target),
      Fire Dart and Fireball (they fly pointing the way they go, in every direction, with
      no blur), Frost Shard, Metal Shards, Air Blade (with a trail), Healing Touch (a water
      ball in your hands, then a splash on the target), Water Shield (a bubble), Ice Prison,
      Revive (a column of water), Ice Wall, Steam Veil and Ice Spikes (one per tile),
      Boulder Crush (a boulder drops), Updraft, Tornado, Hurricane, Vortex, Suffocate (a
      ring at head height), Solar Zenith (a halo), Flame Wheel and Cyclone Spin (rings).
- [ ] Scorch on an enemy: small orange flames on it, and a small flame icon on its frame at
      the top of the screen. Hovering the frame says "+15% damage taken".

## Whips, streams and lightning (they start at your hand)
- [ ] Water Whip (in play, drawn in code since 2026-11-25): a flowing whip of water leaves
      your right hand, sways and glides, then stiffens for an instant and cracks on the
      target (droplets splash). The damage lands on that crack, a moment after you let go.
      Then it pulls back into the hand and is gone. Facing up (N, NE, NW) it goes behind you.
- [ ] Walk while it's out: the whip trails after your hand.
- [ ] Escape menu → Gameplay test → "Show whip chain points and hand anchors": white dots
      along the whip, a magenta cross on your hand. Does the cross sit on the hand in every
      direction? (The hand points are guesses until the marked Aseprite file.)
- [ ] `tests/visual/whip_lab.tscn` (F6 in the editor): keys 1–8 cast in each direction, −/=
      slow down and speed up, R reloads `content/effects/water_whip_feel.tres` after you tune it.
- [ ] Fire Whip: the same with fire, and it pulls the first enemy toward you.
- [ ] Leeching Tide: a dark blue stream flowing from the target back to you.
- [ ] `fx F12` (Fire Stream) and `fx W11` (Water Jet): a straight, thick stream that flows
      outward. Aim it at a wolf: it stops at the wolf. Aim it at a wall: it stops at the wall.
- [ ] `fx E22` (Metal Cable): a taut cable with sparks where it bites.
- [ ] `fx F17` (Lightning Bolt): jagged and flickering. `fx F19`: lightning drawn as an
      infinity sign around you, starting in the middle and going up first.
- [ ] Stand so a wall or tall rock is between you and the end of a whip or stream: the
      wall covers the part behind it.

## Waves and blasts
- [ ] `fx F14` (Breath of Fire) into open ground: a fan of fire rolling out.
- [ ] Stand 2 tiles from a tall rock or pillar and breathe fire past it: there's a gap
      behind the pillar (the fire doesn't go through it), and flames burst where it stops.
- [ ] Water Pulse (in play) and `fx W15` (Tidal Wave): a wave rolls out and the ground
      behind it looks wet for a few seconds.
- [ ] Gust and Air Blast (in play): a gust of wind toward the target. Air Blast's is
      bigger. The old wind spirals are gone.

## Ground effects
- [ ] Burning Ground (in play): only flames are drawn on the burning tiles, no tile. The
      flames fade toward the sides where nothing burns.
- [ ] Seismic Stomp (in play): a ring rolls out over the ground, lifting each tile as it
      passes. Try it on grass and on cobblestone: it looks different on each.
- [ ] `fx E06` (Sinkhole): sandy tiles. `fx E11` (Earthquake): cracks that shake.
- [ ] `fx E16` (Sandstorm): swirling sand. `fx W17` (Healing Rain): falling drops and wet
      ground.
- [ ] `fx E13` (Seismic Sense): the screen turns grey and white rings spread from your
      hero, then the colours come back.
- [ ] Raise Pillar, Earth Wall: only the height changes, no extra effect.

## Looking for problems
- [ ] Four players breathing fire or using whips at once: does the game slow down?
- [ ] Effects that stay after they should have ended, or flicker.
- [ ] Effects drawn over a wall that should hide them, or hidden when they shouldn't be. A
      ring lying on the ground in front of a cliff may show over the cliff: say if it bothers you.
- [ ] Whips or streams that don't start at the hand.
- [ ] Two players: the other player sees the same whip curve, the same wave and the same
      lightning as you (they are built from the same data).

Screenshots of all of this are in `tests/visual/stance_shots.tscn`.
