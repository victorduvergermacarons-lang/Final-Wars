# Playtest checklist: audio

For a non-programmer. Tick each box; if something sounds wrong, note what you did and
what you heard. `AUDIO_SPEC.md` lists every sound the game knows and which ones have a
file yet. To try a sound that has none, drop a short WAV into the folder it names for
its key (e.g. `audio/sfx/footsteps/footstep_grass.wav`) and restart the game.

## Music
- [ ] The title screen plays the idle draft music.
- [ ] Let it play past its end (about 33 s): it starts again with no click, gap or jump.
- [ ] Press Play and enter Millbrook: **"Millbrook / Greenfields"** plays, not the draft.
      It fades in and out, so expect a short dip to silence each time it loops.
- [ ] Walk into Greenfields: the same track carries on with no restart.
- [ ] Walk south to the Crossing: it crossfades (about 1.5 s) to **"The Crossing"**. It
      dips at every loop (it ends with a fade).
- [ ] Walk on to the Road to Deepcut, Deepcut or the Wilds: the draft plays there (they
      have no track yet).
- [ ] Walk west of the Crossing to the Windsteppe: its own track plays.
- [ ] Enter the Silent Shaft (quest 1-07, or the debug command `goto silent_shaft`):
      **"The Silent Shaft"** plays. It dips at every loop (it ends in a fade).
- [ ] Fight the Foreman: the Silent Shaft's track keeps playing (his own track doesn't
      exist yet).
- [ ] Walking between any two zones never jumps in volume (every track is at the same
      loudness).
- [ ] Start a fight anywhere: the music keeps playing (there's no combat track yet), and
      nothing stutters when the fight ends.
- [ ] "Leave game" back to the menu: the music doesn't cut out or double up.

## Settings
- [ ] The main menu has a **Settings** button (right page, under Host / Join). It opens
      a window with five sliders: Master, Music, Ambience, Sound effects, Interface.
- [ ] In game, press Esc for the menu: its **Sound** tab has the same five sliders.
- [ ] Drag Music down: the music gets quieter straight away. All the way left: silent.
- [ ] Drag Master down: everything gets quieter.
- [ ] Close the game and start it again: the sliders are where you left them.
- [ ] A second player on the same computer with their own settings file keeps their
      own volumes (volumes are saved per player, with the keybinds).

## The first sound effects
- [ ] Every button clicks (menus, the book, dialogue). The Interface slider controls it.
- [ ] Accept a quest: the accept sound plays. Hand one in: the completion sound plays.
- [ ] Level up: the level-up sound plays, and the music dips a little under it.
- [ ] Healing Touch: the sound plays when the heal lands (at the end of the timing
      bar), not when the bar starts.
- [ ] Water Whip: the crack plays when it hits, at the end of its bar.
- [ ] Air Palm: the sound plays when the palm hits, at the end of its bar.
- [ ] Gust: the sound plays the moment you use it (it has no bar).
- [ ] A wolf's bite (Greenfields, the Road to Deepcut) and an iron wolf's bite (the
      Windsteppe) sound the same, and play as the wolf lunges, just before the hit.
- [ ] Old Grizzlehide's cleave (he patrols Greenfields) plays as he winds up the swipe.
- [ ] Stags on the Windsteppe: walk right up to one: silence (it's peaceful). Hit it: it
      bellows **once**, and not again while you keep hitting it. Let it reset (walk away
      or let it kill you), hit it again: it bellows again.
- [ ] Sounds are loud next to their source and quieter far away; with two players far
      apart, each hears sounds from where their own hero stands.
- [ ] Sounds without files never crash the game or make it stutter.

## Water near you
- [ ] In Millbrook, walk toward the river: the sound of running water fades in, loudest
      at the bank, and comes from the river's side (left or right in headphones).
- [ ] Walk away: it fades out and is gone about 10 tiles from the water.
- [ ] Walk along the river: the sound follows you smoothly, without stopping and
      starting.
- [ ] Stand where two waters are near (Greenfields: the river and the pond in the
      south-east): you hear both, from their own directions, and they don't sound like
      one copy played twice.
- [ ] The zone's own background sound (when it has one) still plays alongside.
- [ ] Drag the **Ambience** slider down: the water gets quieter; all the way: silent.
      The Sound effects slider doesn't change it.
- [ ] Walk into another zone while next to water: the old water fades out (no click),
      and the new zone's water, if any, fades in where it is.
- [ ] It works the same everywhere with water: Greenfields' river and pond, the
      Crossing's grey stream, the Road to Deepcut, Deepcut's polluted stream and tailings
      pond, the Wilds' streams and puddles, Tidereach Shore.
- [ ] Nothing stutters near water, even with lots of it around (the Wilds).
