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
- **Region music:** every zone belongs to a region (Heartland, Bedrun, Vael,
  Tidereach, Ashkara). A track's data file can list `regions`: it then plays only
  in zones of those regions, and wins there over the tracks for any region. A
  region without its own track for the context gets the any-region track (today
  the draft). Name region tracks `music_<context>_<region>.ogg`, e.g.
  `music_explore_bedrun.ogg`.
- **Zone music:** a track's data file can also list `zones` (e.g. a dungeon's own
  theme): it plays only there and wins over region tracks. A track may be listed
  before its file exists: until the file is in `audio/music/`, the game falls back
  as if it weren't there.
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
| `audio/music/music_explore_tidereach.ogg` | explore in Tidereach zones (none in Act I: hear it on the Tidereach Shore test map, west of the Enemy Testing Grounds, or with the debug command `goto tidereach_shore`) | "Water Idle", converted from the uploaded WAV (kept in `art/audio/music_explore_tidereach_master.wav`) to OGG Vorbis quality 6, not edited otherwise. **It doesn't loop cleanly yet:** it starts with 2.35 s of near-silence (−80 to −63 dB) and ends at full level (about −26 dB RMS in the last 50 ms, no fade), so every loop drops from full volume into that 2.35 s gap. A version that ends on the material it starts with (or with the lead-in trimmed) would loop seamlessly. |

### Waiting for their file (listed in `content/audio/music/`)

| File | Plays for | Until then |
|------|-----------|------------|
| `audio/music/music_dungeon_silentshaft.ogg` | exploring the Silent Shaft (Act I's dungeon, quest 1-07) | the draft (dungeon → explore → town) |
| `audio/music/music_boss_foreman.ogg` | the fight with the Foreman and the Grey Heart (an elite fighting within 12 tiles of you) | whatever is playing (boss → combat → keep) |

Combat and boss music: until those tracks exist, fights keep the current music.

## Sound keys

Every key the game tries to play today. This list is generated from the game's
content (`godot --headless --path . -s res://tools/write_audio_spec.gd`), so new
abilities, enemies and ground types show up here automatically. "Lands on someone"
plays where an ability hits or heals; "is used" plays at the caster when it starts.

<!-- sound keys start: written by tools/write_audio_spec.gd -->

224 keys, 0 with a file, 224 missing. File = `audio/<folder>/<key>.wav` (`.ogg` for ambience).

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
| `world_act_complete` | an act of the story ends (the end-of-act screen opens) | **missing** |
| `world_dungeon_enter` | your party enters a dungeon (its own copy) | **missing** |
| `world_event` | a world event is announced (the bells of Millbrook) | **missing** |
| `world_health_potion_cast` | Health Potion is used | **missing** |
| `world_hero_death` | a hero dies | **missing** |
| `world_level_up` | a hero levels up | **missing** |
| `world_lift` | a mine lift rattles along its shaft (you ride it) | **missing** |
| `world_mana_potion_cast` | Mana Potion is used | **missing** |
| `world_mastered` | a hero masters an ability | **missing** |
| `world_miss` | an attack misses | **missing** |
| `world_party_wipe` | the whole party has fallen in a dungeon | **missing** |
| `world_release` | a hero releases to a graveyard | **missing** |
| `world_shrine_reset` | the Reset Shrine resets the testing grounds | **missing** |
| `world_whiff` | an attack hits nothing | **missing** |
| `world_wipe_respawn` | the fallen party wakes at the dungeon's entrance | **missing** |
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
| `footstep_grey_rock` | a hero steps on grey rock | **missing** |
| `footstep_meadow` | a hero steps on meadow | **missing** |
| `footstep_mine_floor` | a hero steps on mine floor | **missing** |
| `footstep_path` | a hero steps on path | **missing** |
| `footstep_red_earth` | a hero steps on red earth | **missing** |
| `footstep_red_rock` | a hero steps on red rock | **missing** |
| `footstep_red_stone` | a hero steps on red stone | **missing** |
| `footstep_rocky_dirt` | a hero steps on rocky dirt | **missing** |
| `footstep_rocky_ground` | a hero steps on rocky ground | **missing** |
| `footstep_slab` | a hero steps on slab | **missing** |
| `footstep_steppe` | a hero steps on steppe | **missing** |
| `footstep_steppe_dry` | a hero steps on steppe dry | **missing** |
| `footstep_tall_grass` | a hero steps on tall grass | **missing** |
| `footstep_tilled` | a hero steps on tilled | **missing** |

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
| `creature_boar_aggro` | Boar notices a hero and starts a fight | **missing** |
| `creature_boar_death` | Boar dies | **missing** |
| `creature_boar_gore` | Gore is used | **missing** |
| `creature_boar_gore_hit` | Gore lands on someone | **missing** |
| `creature_boar_hurt` | Boar takes damage | **missing** |
| `creature_boar_step` | Boar moves one tile (paws, wings...) | **missing** |
| `creature_boar_tusk_charge` | Tusk Charge is used | **missing** |
| `creature_boar_tusk_charge_hit` | Tusk Charge lands on someone | **missing** |
| `creature_fen_skirmisher_aggro` | Fen Skirmisher notices a hero and starts a fight | **missing** |
| `creature_fen_skirmisher_death` | Fen Skirmisher dies | **missing** |
| `creature_fen_skirmisher_hurt` | Fen Skirmisher takes damage | **missing** |
| `creature_fen_skirmisher_quick_slash` | Quick Slash is used | **missing** |
| `creature_fen_skirmisher_quick_slash_hit` | Quick Slash lands on someone | **missing** |
| `creature_fen_skirmisher_step` | Fen Skirmisher moves one tile (paws, wings...) | **missing** |
| `creature_foreman_aggro` | The Foreman notices a hero and starts a fight | **missing** |
| `creature_foreman_death` | The Foreman dies | **missing** |
| `creature_foreman_enrage` | The Foreman enrages (Grey Fury, phase 3) | **missing** |
| `creature_foreman_ground_slam` | Ground Slam is used | **missing** |
| `creature_foreman_ground_slam_hit` | Ground Slam lands on someone | **missing** |
| `creature_foreman_hurt` | The Foreman takes damage | **missing** |
| `creature_foreman_mine_cart_charge` | Mine-Cart Charge is used | **missing** |
| `creature_foreman_mine_cart_charge_hit` | Mine-Cart Charge lands on someone | **missing** |
| `creature_foreman_phase` | The Foreman enters a new phase of the fight (phases 2 and 3) | **missing** |
| `creature_foreman_pick_hammer` | Pick-Hammer is used | **missing** |
| `creature_foreman_pick_hammer_hit` | Pick-Hammer lands on someone | **missing** |
| `creature_foreman_reset` | The Foreman goes back to the start of its phase (after a party wipe) | **missing** |
| `creature_foreman_step` | The Foreman moves one tile (paws, wings...) | **missing** |
| `creature_goblin_shaman_aggro` | Goblin Shaman notices a hero and starts a fight | **missing** |
| `creature_goblin_shaman_death` | Goblin Shaman dies | **missing** |
| `creature_goblin_shaman_hurt` | Goblin Shaman takes damage | **missing** |
| `creature_goblin_shaman_shadow_bolt` | Shadow Bolt is used | **missing** |
| `creature_goblin_shaman_shadow_bolt_hit` | Shadow Bolt lands on someone | **missing** |
| `creature_goblin_shaman_step` | Goblin Shaman moves one tile (paws, wings...) | **missing** |
| `creature_grey_heart_aggro` | The Grey Heart notices a hero and starts a fight | **missing** |
| `creature_grey_heart_break` | The Grey Heart breaks and the fight is won | **missing** |
| `creature_grey_heart_death` | The Grey Heart dies | **missing** |
| `creature_grey_heart_hurt` | The Grey Heart takes damage | **missing** |
| `creature_grey_heart_pulse` | The Grey Heart pulses: adds climb out, the floor turns grey | **missing** |
| `creature_grey_husk_aggro` | Grey Husk notices a hero and starts a fight | **missing** |
| `creature_grey_husk_death` | Grey Husk dies | **missing** |
| `creature_grey_husk_hollow_rake` | Hollow Rake is used | **missing** |
| `creature_grey_husk_hollow_rake_hit` | Hollow Rake lands on someone | **missing** |
| `creature_grey_husk_hurt` | Grey Husk takes damage | **missing** |
| `creature_grey_husk_step` | Grey Husk moves one tile (paws, wings...) | **missing** |
| `creature_grey_overseer_aggro` | Grey Overseer notices a hero and starts a fight | **missing** |
| `creature_grey_overseer_death` | Grey Overseer dies | **missing** |
| `creature_grey_overseer_hurt` | Grey Overseer takes damage | **missing** |
| `creature_grey_overseer_overseer_s_crush` | Overseer's Crush is used | **missing** |
| `creature_grey_overseer_overseer_s_crush_hit` | Overseer's Crush lands on someone | **missing** |
| `creature_grey_overseer_step` | Grey Overseer moves one tile (paws, wings...) | **missing** |
| `creature_human_husk_aggro` | Human Husk notices a hero and starts a fight | **missing** |
| `creature_human_husk_death` | Human Husk dies | **missing** |
| `creature_human_husk_hollow_rake` | Hollow Rake is used | **missing** |
| `creature_human_husk_hollow_rake_hit` | Hollow Rake lands on someone | **missing** |
| `creature_human_husk_hurt` | Human Husk takes damage | **missing** |
| `creature_human_husk_step` | Human Husk moves one tile (paws, wings...) | **missing** |
| `creature_iron_wolf_aggro` | Iron Wolf notices a hero and starts a fight | **missing** |
| `creature_iron_wolf_bite` | Bite is used | **missing** |
| `creature_iron_wolf_bite_hit` | Bite lands on someone | **missing** |
| `creature_iron_wolf_death` | Iron Wolf dies | **missing** |
| `creature_iron_wolf_howl` | Howl is used | **missing** |
| `creature_iron_wolf_hurt` | Iron Wolf takes damage | **missing** |
| `creature_iron_wolf_step` | Iron Wolf moves one tile (paws, wings...) | **missing** |
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
| `ambience_crossing` | background loop in The Crossing (Ambience bus, OGG) | **missing** |
| `ambience_deepcut` | background loop in Deepcut (Ambience bus, OGG) | **missing** |
| `ambience_deepcut_road` | background loop in Road to Deepcut (Ambience bus, OGG) | **missing** |
| `ambience_enemy_testing` | background loop in Enemy Testing Grounds (Ambience bus, OGG) | **missing** |
| `ambience_greenfields` | background loop in Greenfields (Ambience bus, OGG) | **missing** |
| `ambience_silent_shaft` | background loop in The Silent Shaft (Ambience bus, OGG) | **missing** |
| `ambience_tidereach_shore` | background loop in Tidereach Shore (test) (Ambience bus, OGG) | **missing** |
| `ambience_town` | background loop in Millbrook (Ambience bus, OGG) | **missing** |
| `ambience_windsteppe` | background loop in Windsteppe (Ambience bus, OGG) | **missing** |

<!-- sound keys end -->
