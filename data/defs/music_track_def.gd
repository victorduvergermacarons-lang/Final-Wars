class_name MusicTrackDef
extends Resource
## One music track. Adding a track needs only its file in audio/music/ and one of
## these in content/audio/music/. A track whose file isn't there yet is skipped
## (the context falls back), so a track can be listed before its file exists. The music manager (Audio) plays the track whose
## contexts include the current one, crossfading between tracks.

## Where a track can play. The game picks one context at a time (SoundDirector).
enum Context { TITLE, TOWN, EXPLORE, COMBAT, DUNGEON, BOSS }

@export var id: StringName = &""
@export var display_name: String = ""
## The audio file (OGG Vorbis), e.g. "res://audio/music/music_idle_draft.ogg".
@export_file("*.ogg") var file: String = ""
@export var contexts: Array[Context] = []
## Regions this track belongs to (ZoneDef.region). Empty = any region. In a zone
## of a region with its own track for the context, that track wins; a region
## without one falls back to the tracks for any region.
@export var regions: Array[Regions.Id] = []
## Zones this track belongs to (ZoneDef.id), e.g. a dungeon's own theme. Empty =
## any zone. A zone's own track wins over its region's; a track for some zones
## never plays elsewhere.
@export var zones: Array[StringName] = []
@export var loop: bool = true
## Mixing level of this track (0 = as mastered).
@export var volume_db: float = 0.0
## A "drained" variant: chosen over the normal tracks of its contexts while the
## zone's bond is low (see AudioConfig.drained_bond_below). None exist yet.
@export var drained: bool = false
