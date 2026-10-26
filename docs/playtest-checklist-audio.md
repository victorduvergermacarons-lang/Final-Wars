# Playtest checklist: audio

For a non-programmer. Tick each box; if something sounds wrong, note what you did and
what you heard. Only one music track exists so far (the idle draft) and no sound
effects, so most checks are about music and the settings. To try a sound effect, drop
any short WAV into the folder `AUDIO_SPEC.md` names for its key (e.g.
`audio/sfx/ui/ui_click.wav`) and restart the game.

## Music
- [ ] The title screen plays the idle draft music.
- [ ] Let it play past its end (about 33 s): it starts again with no click, gap or jump.
- [ ] Press Play and enter Millbrook: the same track keeps playing (no restart).
- [ ] Walk into Greenfields and the testing grounds: the music carries on (they don't
      have their own tracks yet).
- [ ] Start a fight: the music keeps playing (there's no combat track yet), and
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

## Sound effects (once files exist)
- [ ] Put a WAV at `audio/sfx/ui/ui_click.wav`: every button clicks.
- [ ] Put one at `audio/sfx/footsteps/footstep_grass.wav`: walking on grass makes
      footsteps that sound slightly different each time.
- [ ] Put one at `audio/sfx/creatures/creature_wolf_howl.wav`: a wolf's howl is loud
      next to it and quieter far away; the music dips a little while it howls.
- [ ] With two players far apart, each hears sounds from where their own hero stands.
- [ ] Sounds without files never crash the game or make it stutter.
