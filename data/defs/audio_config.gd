class_name AudioConfig
extends Resource
## Every tunable number of the audio system, in one place
## (content/audio/audio_config.tres), plus the sound library's tuning entries.

const BUSES := ["Master", "Music", "Ambience", "SFX", "UI"]

@export_group("Music")
@export var crossfade_seconds: float = 1.5
## How far big sounds (SfxDef.ducks_music) lower the music, and for how long.
@export var duck_db: float = -6.0
@export var duck_hold_seconds: float = 0.8
@export var duck_release_seconds: float = 0.6
## A fight this close to the local hero (tiles) switches to combat music.
@export var combat_radius_tiles: int = 12
## When a context has no track, try these contexts instead, in order
## (MusicTrackDef.Context ids). A context mapped to [-1] keeps whatever plays.
@export var fallbacks: Dictionary = {
	MusicTrackDef.Context.BOSS: [MusicTrackDef.Context.COMBAT],
	MusicTrackDef.Context.COMBAT: [-1],
	MusicTrackDef.Context.DUNGEON: [MusicTrackDef.Context.EXPLORE, MusicTrackDef.Context.TOWN],
	MusicTrackDef.Context.EXPLORE: [MusicTrackDef.Context.TOWN],
}
## Below this zone bond (0..1), a drained variant of the track is used if one exists.
@export var drained_bond_below: float = 0.35

@export_group("Sound effects")
## Where positional sounds fade out completely, in tiles from the listener.
@export var hearing_tiles: float = 14.0
## How quickly they fade with distance (Godot's AudioStreamPlayer2D attenuation).
@export var attenuation: float = 1.6
## Copies of one key playing at once, unless its entry says otherwise.
@export var max_voices: int = 4
## Key prefix -> {"folder", "bus", "pitch" (± fraction), "volume" (± dB), "ext"}.
@export var categories: Dictionary = {
	"ui": {"folder": "sfx/ui", "bus": "UI", "pitch": 0.0, "volume": 0.0, "ext": "wav"},
	"footstep": {"folder": "sfx/footsteps", "bus": "SFX", "pitch": 0.08, "volume": 2.0, "ext": "wav"},
	"weapon": {"folder": "sfx/weapons", "bus": "SFX", "pitch": 0.05, "volume": 1.5, "ext": "wav"},
	"fire": {"folder": "sfx/fire", "bus": "SFX", "pitch": 0.05, "volume": 1.5, "ext": "wav"},
	"earth": {"folder": "sfx/earth", "bus": "SFX", "pitch": 0.05, "volume": 1.5, "ext": "wav"},
	"water": {"folder": "sfx/water", "bus": "SFX", "pitch": 0.05, "volume": 1.5, "ext": "wav"},
	"air": {"folder": "sfx/air", "bus": "SFX", "pitch": 0.05, "volume": 1.5, "ext": "wav"},
	"creature": {"folder": "sfx/creatures", "bus": "SFX", "pitch": 0.06, "volume": 1.5, "ext": "wav"},
	"world": {"folder": "sfx/world", "bus": "SFX", "pitch": 0.03, "volume": 1.0, "ext": "wav"},
	"ambience": {"folder": "ambience", "bus": "Ambience", "pitch": 0.0, "volume": 0.0, "ext": "ogg"},
}
## Tuning per key (optional; see SfxDef).
@export var sfx: Array[SfxDef] = []

const ROOT := "res://audio"


## The category of a key (its first word), or {} if the prefix is unknown.
func category(key: StringName) -> Dictionary:
	var prefix := String(key).get_slice("_", 0)
	return categories.get(prefix, {})


func entry(key: StringName) -> SfxDef:
	for e in sfx:
		if e.key == key:
			return e
	return null


## The file a key plays: its entry's file, else audio/<folder>/<key>.<ext>.
func file_for(key: StringName) -> String:
	var e := entry(key)
	if e != null and e.file != "":
		return e.file
	var cat := category(key)
	if cat.is_empty():
		return ""
	return "%s/%s/%s.%s" % [ROOT, cat.folder, key, cat.get("ext", "wav")]
