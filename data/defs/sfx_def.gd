class_name SfxDef
extends Resource
## Tuning for one sound key (all optional): a key plays its file from the folder
## its prefix names (see AudioConfig.categories) even without an entry here. An
## entry changes its level, variation, bus or file.

@export var key: StringName = &""
## Overrides the file found by naming convention ("" = audio/sfx/<folder>/<key>.wav).
@export_file var file: String = ""
@export var volume_db: float = 0.0
## Random pitch change per play, ± this fraction (-1 = the category's default).
@export var pitch_variation: float = -1.0
## Random volume change per play, ± this many dB (-1 = the category's default).
@export var volume_variation_db: float = -1.0
## Briefly lowers the music while it plays (big sounds: breaths, dives, howls).
@export var ducks_music: bool = false
## At most this many copies at once (0 = the config's default).
@export var max_voices: int = 0
