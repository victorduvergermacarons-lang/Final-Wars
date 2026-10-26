# Audio spec

What sound files the game expects, in which format, and where they go. The game
looks each sound up by its **key** (e.g. `fire_fireball_cast`): drop a file with that
name in the right folder and it plays the next time the game starts. Nothing else is
needed. A key without a file plays nothing (the game logs one warning), so sounds can
be added a few at a time.

## Folders

| Folder | What goes in it | Format |
|--------|-----------------|--------|
| `audio/music/` | music tracks | OGG Vorbis |
| `audio/ambience/` | background loops per zone (wind, birds, town bustle) | OGG Vorbis |
| `audio/sfx/ui/` | menu and window sounds (`ui_…`) | WAV |
| `audio/sfx/footsteps/` | hero footsteps per ground type (`footstep_…`) | WAV |
| `audio/sfx/weapons/` | Sword, Bow and Hammer abilities (`weapon_…`) | WAV |
| `audio/sfx/fire/`, `water/`, `earth/`, `air/` | element abilities (`fire_…`, `water_…`…) | WAV |
| `audio/sfx/creatures/` | enemy attacks, cries and steps (`creature_…`) | WAV |
| `audio/sfx/world/` | level-up, death, misses, potions, events (`world_…`) | WAV |

The first word of a key picks its folder. The file name is the key plus `.wav`
(`.ogg` for ambience): `fire_fireball_cast` → `audio/sfx/fire/fire_fireball_cast.wav`.

## Formats

- **Music and ambience:** OGG Vorbis, 44.1 kHz or 48 kHz, stereo, quality 6
  (about 190 kbps). Export a loop as one seamless piece: no silence at the start or
  end (MP3 adds some, so don't go through MP3), and the last sample should flow into
  the first.
- **Sound effects:** WAV, 16-bit PCM, 44.1 kHz or 48 kHz.
  - World sounds (abilities, creatures, footsteps): **mono**. The game places them
    in the world itself, louder near your hero and quieter further away.
  - Interface sounds: mono or stereo.
- Trim silence at the start of every effect, so it plays the moment it is
  triggered. End with a short fade, not a cut.

## Naming

- Lower case, words joined by `_`, no spaces: exactly the key from the list below.
- **Several takes of one sound:** instead of `footstep_grass.wav`, provide
  `footstep_grass_1.wav`, `footstep_grass_2.wav` … (up to 9). Each play picks one
  at random, never the same one twice in a row. This is good for footsteps, hits and
  creature cries. The game also varies pitch and volume a little on every play, so
  one good take is enough to start.
- **Music:** `music_<context>_<name>.ogg`, e.g. `music_town_millbrook.ogg`. A track
  also needs one small data file in `content/audio/music/`; copy `idle_draft.tres`
  and change the name, file, contexts (title, town, explore, combat, dungeon, boss)
  and whether it loops. A track marked **drained** is used instead when a zone's
  bond is low (a hook for later; no drained tracks yet).
- **Ambience:** `ambience_<zone>.ogg` (keys below).

## Loudness targets

Measure with any LUFS meter (e.g. the free Youlean Loudness Meter). Peaks are true
peaks.

| Kind | Target | Peak at most |
|------|--------|--------------|
| Music | −16 LUFS integrated | −1 dBTP |
| Ambience | −24 LUFS integrated (it sits under everything) | −3 dBTP |
| Ability and creature sounds | −16 to −20 LUFS short-term, big ones (breath, dive, howl) up to −14 | −1 dBTP |
| Footsteps | about −26 LUFS short-term (quiet, they repeat a lot) | −6 dBTP |
| Interface | about −20 LUFS short-term | −3 dBTP |

Players set the Master, Music, Ambience, Sound effects and Interface volumes
themselves in Settings, so aim for these levels and leave the rest to the sliders.
Big sounds (Wolf howl, the drake's breath and dive, Grizzlehide's charge, level-up)
lower the music a little while they play; there is no need to make them louder to
cut through.

## Music now

| File | Plays for | Notes |
|------|-----------|-------|
| `audio/music/music_idle_draft.ogg` | title screen, town (and, until they have their own, explore and dungeon) | first draft; converted from the MP3 (kept in `art/audio/`). The MP3 started with 43 ms of silence and ended at full level, so the loop clicked: the OGG has the silence trimmed, a 10 ms fade-in and a 120 ms fade-out. |

Combat and boss music: until those tracks exist, fights keep the current music.

## Sound keys

Every key the game tries to play today. This list is generated from the game's
content (`godot --headless --path . -s res://tools/write_audio_spec.gd`), so new
abilities, enemies and ground types show up here automatically. "Lands on someone"
plays where an ability hits or heals; "is used" plays at the caster when it starts.

<!-- sound keys start: written by tools/write_audio_spec.gd -->

152 keys, 0 with a file, 152 missing. File = `audio/<folder>/<key>.wav` (`.ogg` for ambience).

### Interface (audio/sfx/ui, UI bus)

| Key | Plays when | File |
|-----|-----------|------|
| `ui_click` | any button is pressed | **missing** |
| `ui_close` | a window closes | **missing** |
| `ui_coins` | buying or selling at a vendor | **missing** |
| `ui_equip` | putting on or taking off gear | **missing** |
| `ui_error` | an action is refused (the red error text) | **missing** |
| `ui_learn` | placing an item in the learning slot | **missing** |
| `ui_loot` | loot goes into your bag | **missing** |
| `ui_open` | a window opens (inventory, quests, trees, settings...) | **missing** |
| `ui_quest_accept` | a quest is accepted | **missing** |
| `ui_quest_complete` | a quest is handed in | **missing** |

### World events (audio/sfx/world)

| Key | Plays when | File |
|-----|-----------|------|
| `world_event` | a world event is announced (the bells of Millbrook) | **missing** |
| `world_health_potion_cast` | Health Potion is used | **missing** |
| `world_hero_death` | a hero dies | **missing** |
| `world_level_up` | a hero levels up | **missing** |
| `world_mana_potion_cast` | Mana Potion is used | **missing** |
| `world_mastered` | a hero masters an ability | **missing** |
| `world_miss` | an attack misses | **missing** |
| `world_release` | a hero releases to a graveyard | **missing** |
| `world_shrine_reset` | the Reset Shrine resets the testing grounds | **missing** |
| `world_whiff` | an attack hits nothing | **missing** |
| `world_zone_enter` | you walk into another map | **missing** |

### Footsteps (audio/sfx/footsteps)

| Key | Plays when | File |
|-----|-----------|------|
| `footstep_cobble` | a hero steps on cobble | **missing** |
| `footstep_cracked` | a hero steps on cracked | **missing** |
| `footstep_dark_grass` | a hero steps on dark grass | **missing** |
| `footstep_default` | a hero steps on ground without a known surface | **missing** |
| `footstep_dense_grass` | a hero steps on dense grass | **missing** |
| `footstep_dirt` | a hero steps on dirt | **missing** |
| `footstep_ford` | a hero steps on ford | **missing** |
| `footstep_grass` | a hero steps on grass | **missing** |
| `footstep_meadow` | a hero steps on meadow | **missing** |
| `footstep_path` | a hero steps on path | **missing** |
| `footstep_rocky_dirt` | a hero steps on rocky dirt | **missing** |
| `footstep_rocky_ground` | a hero steps on rocky ground | **missing** |

### Weapons: Sword, Bow and Hammer arts (audio/sfx/weapons)

| Key | Plays when | File |
|-----|-----------|------|
| `weapon_aimed_shot_cast` | Aimed Shot is used | **missing** |
| `weapon_aimed_shot_hit` | Aimed Shot lands on someone | **missing** |
| `weapon_ground_slam_cast` | Ground Slam is used | **missing** |
| `weapon_ground_slam_hit` | Ground Slam lands on someone | **missing** |
| `weapon_lunge_cast` | Lunge is used | **missing** |
| `weapon_lunge_hit` | Lunge lands on someone | **missing** |
| `weapon_quick_shot_cast` | Quick Shot is used | **missing** |
| `weapon_quick_shot_hit` | Quick Shot lands on someone | **missing** |
| `weapon_slash_cast` | Slash is used | **missing** |
| `weapon_slash_hit` | Slash lands on someone | **missing** |
| `weapon_smash_cast` | Smash is used | **missing** |
| `weapon_smash_hit` | Smash lands on someone | **missing** |

### Fire (audio/sfx/fire)

| Key | Plays when | File |
|-----|-----------|------|
| `fire_blazing_combo_cast` | Blazing Combo is used | **missing** |
| `fire_blazing_combo_hit` | Blazing Combo lands on someone | **missing** |
| `fire_burning_ground_burn_hit` | Burning Ground: its ground zone hurts someone standing in it | **missing** |
| `fire_burning_ground_cast` | Burning Ground is used | **missing** |
| `fire_dart_cast` | Fire Dart is used | **missing** |
| `fire_dart_hit` | Fire Dart lands on someone | **missing** |
| `fire_fireball_cast` | Fireball is used | **missing** |
| `fire_fireball_hit` | Fireball lands on someone | **missing** |
| `fire_flame_dash_burn_hit` | Flame Dash: its ground zone hurts someone standing in it | **missing** |
| `fire_flame_dash_cast` | Flame Dash is used | **missing** |
| `fire_kick_cast` | Fire Kick is used | **missing** |
| `fire_kick_hit` | Fire Kick lands on someone | **missing** |
| `fire_punch_cast` | Fire Punch is used | **missing** |
| `fire_punch_hit` | Fire Punch lands on someone | **missing** |
| `fire_sun_warrior_s_breath_cast` | Sun Warrior's Breath is used | **missing** |
| `fire_whip_cast` | Fire Whip is used | **missing** |
| `fire_whip_hit` | Fire Whip lands on someone | **missing** |

### Water (audio/sfx/water)

| Key | Plays when | File |
|-----|-----------|------|
| `water_flow_state_cast` | Flow State is used | **missing** |
| `water_frost_shard_cast` | Frost Shard is used | **missing** |
| `water_frost_shard_hit` | Frost Shard lands on someone | **missing** |
| `water_healing_touch_cast` | Healing Touch is used | **missing** |
| `water_healing_touch_hit` | Healing Touch lands on someone | **missing** |
| `water_ice_spikes_cast` | Ice Spikes is used | **missing** |
| `water_ice_spikes_hit` | Ice Spikes lands on someone | **missing** |
| `water_leeching_tide_cast` | Leeching Tide is used | **missing** |
| `water_leeching_tide_hit` | Leeching Tide lands on someone | **missing** |
| `water_pulse_cast` | Water Pulse is used | **missing** |
| `water_pulse_hit` | Water Pulse lands on someone | **missing** |
| `water_soothing_mist_cast` | Soothing Mist is used | **missing** |
| `water_tidal_blessing_cast` | Tidal Blessing is used | **missing** |
| `water_whip_cast` | Water Whip is used | **missing** |
| `water_whip_hit` | Water Whip lands on someone | **missing** |

### Earth (audio/sfx/earth)

| Key | Plays when | File |
|-----|-----------|------|
| `earth_raise_pillar_cast` | Raise Pillar is used | **missing** |
| `earth_rock_throw_cast` | Rock Throw is used | **missing** |
| `earth_rock_throw_hit` | Rock Throw lands on someone | **missing** |
| `earth_seismic_stomp_cast` | Seismic Stomp is used | **missing** |
| `earth_wall_cast` | Earth Wall is used | **missing** |
| `earth_wall_hit` | Earth Wall lands on someone | **missing** |

### Air (audio/sfx/air)

| Key | Plays when | File |
|-----|-----------|------|
| `air_blast_cast` | Air Blast is used | **missing** |
| `air_blast_hit` | Air Blast lands on someone | **missing** |
| `air_gust_cast` | Gust is used | **missing** |
| `air_gust_hit` | Gust lands on someone | **missing** |
| `air_palm_cast` | Air Palm is used | **missing** |
| `air_palm_hit` | Air Palm lands on someone | **missing** |
| `air_step_cast` | Air Step is used | **missing** |

### Creatures (audio/sfx/creatures)

| Key | Plays when | File |
|-----|-----------|------|
| `creature_bandit_brute_aggro` | Bandit Brute notices a hero and starts a fight | **missing** |
| `creature_bandit_brute_crushing_blow` | Crushing Blow is used | **missing** |
| `creature_bandit_brute_crushing_blow_hit` | Crushing Blow lands on someone | **missing** |
| `creature_bandit_brute_death` | Bandit Brute dies | **missing** |
| `creature_bandit_brute_hurt` | Bandit Brute takes damage | **missing** |
| `creature_bandit_brute_step` | Bandit Brute moves one tile (paws, wings...) | **missing** |
| `creature_fen_skirmisher_aggro` | Fen Skirmisher notices a hero and starts a fight | **missing** |
| `creature_fen_skirmisher_death` | Fen Skirmisher dies | **missing** |
| `creature_fen_skirmisher_hurt` | Fen Skirmisher takes damage | **missing** |
| `creature_fen_skirmisher_quick_slash` | Quick Slash is used | **missing** |
| `creature_fen_skirmisher_quick_slash_hit` | Quick Slash lands on someone | **missing** |
| `creature_fen_skirmisher_step` | Fen Skirmisher moves one tile (paws, wings...) | **missing** |
| `creature_goblin_shaman_aggro` | Goblin Shaman notices a hero and starts a fight | **missing** |
| `creature_goblin_shaman_death` | Goblin Shaman dies | **missing** |
| `creature_goblin_shaman_hurt` | Goblin Shaman takes damage | **missing** |
| `creature_goblin_shaman_shadow_bolt` | Shadow Bolt is used | **missing** |
| `creature_goblin_shaman_shadow_bolt_hit` | Shadow Bolt lands on someone | **missing** |
| `creature_goblin_shaman_step` | Goblin Shaman moves one tile (paws, wings...) | **missing** |
| `creature_old_grizzlehide_aggro` | Old Grizzlehide notices a hero and starts a fight | **missing** |
| `creature_old_grizzlehide_charge` | Charge is used | **missing** |
| `creature_old_grizzlehide_charge_hit` | Charge lands on someone | **missing** |
| `creature_old_grizzlehide_cleave` | Cleave is used | **missing** |
| `creature_old_grizzlehide_cleave_hit` | Cleave lands on someone | **missing** |
| `creature_old_grizzlehide_death` | Old Grizzlehide dies | **missing** |
| `creature_old_grizzlehide_hurt` | Old Grizzlehide takes damage | **missing** |
| `creature_old_grizzlehide_step` | Old Grizzlehide moves one tile (paws, wings...) | **missing** |
| `creature_salamander_hound_aggro` | Salamander Hound notices a hero and starts a fight | **missing** |
| `creature_salamander_hound_bite` | Bite is used | **missing** |
| `creature_salamander_hound_bite_hit` | Bite lands on someone | **missing** |
| `creature_salamander_hound_cinder_pounce` | Cinder Pounce is used | **missing** |
| `creature_salamander_hound_cinder_pounce_hit` | Cinder Pounce lands on someone | **missing** |
| `creature_salamander_hound_death` | Salamander Hound dies | **missing** |
| `creature_salamander_hound_embers_hit` | Ember Trail: its ground zone hurts someone standing in it | **missing** |
| `creature_salamander_hound_hurt` | Salamander Hound takes damage | **missing** |
| `creature_salamander_hound_step` | Salamander Hound moves one tile (paws, wings...) | **missing** |
| `creature_sunscale_drake_aggro` | Sunscale Drake notices a hero and starts a fight | **missing** |
| `creature_sunscale_drake_death` | Sunscale Drake dies | **missing** |
| `creature_sunscale_drake_enrage` | Sunscale Drake enrages (Molten Fury) | **missing** |
| `creature_sunscale_drake_grounded` | Sunscale Drake is knocked out of the air | **missing** |
| `creature_sunscale_drake_hurt` | Sunscale Drake takes damage | **missing** |
| `creature_sunscale_drake_searing_dive` | Searing Dive is used | **missing** |
| `creature_sunscale_drake_searing_dive_hit` | Searing Dive hits someone in its path | **missing** |
| `creature_sunscale_drake_step` | Sunscale Drake moves one tile (paws, wings...) | **missing** |
| `creature_sunscale_drake_sunfire_breath` | Sunfire Breath is used | **missing** |
| `creature_sunscale_drake_sunfire_breath_hit` | Sunfire Breath lands on someone | **missing** |
| `creature_sunscale_drake_sunfire_hit` | Sunfire Breath: its ground zone hurts someone standing in it | **missing** |
| `creature_sunscale_drake_talon_rake` | Talon Rake is used | **missing** |
| `creature_sunscale_drake_talon_rake_hit` | Talon Rake lands on someone | **missing** |
| `creature_training_dummy_aggro` | Training Dummy notices a hero and starts a fight | **missing** |
| `creature_training_dummy_death` | Training Dummy dies | **missing** |
| `creature_training_dummy_hurt` | Training Dummy takes damage | **missing** |
| `creature_training_dummy_step` | Training Dummy moves one tile (paws, wings...) | **missing** |
| `creature_wolf_aggro` | Wolf notices a hero and starts a fight | **missing** |
| `creature_wolf_bite` | Bite is used | **missing** |
| `creature_wolf_bite_hit` | Bite lands on someone | **missing** |
| `creature_wolf_death` | Wolf dies | **missing** |
| `creature_wolf_howl` | Howl is used | **missing** |
| `creature_wolf_hurt` | Wolf takes damage | **missing** |
| `creature_wolf_step` | Wolf moves one tile (paws, wings...) | **missing** |

### Ambience loops (audio/ambience, OGG, Ambience bus)

| Key | Plays when | File |
|-----|-----------|------|
| `ambience_enemy_testing` | background loop in Enemy Testing Grounds (Ambience bus, OGG) | **missing** |
| `ambience_greenfields` | background loop in Greenfields (Ambience bus, OGG) | **missing** |
| `ambience_town` | background loop in Millbrook (Ambience bus, OGG) | **missing** |

<!-- sound keys end -->
