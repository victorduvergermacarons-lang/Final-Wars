extends Node
## The game's audio (autoload "Audio"): buses and their volumes, music by context
## with crossfades and ducking, zone ambience, and the sound library.
##
## - Buses: Master, Music, Ambience, SFX, UI (default_bus_layout.tres). Volumes are
##   a client preference, saved in user://settings.cfg [audio].
## - Music: set_context() picks the track for a context (MusicTrackDef, from
##   content/audio/music/), falling back as AudioConfig.fallbacks says, and
##   crossfades to it. A low zone bond picks a drained variant if one exists.
## - Sounds: play(key) / play_at(key, position, parent). A key's file is found by
##   naming convention (AudioConfig.file_for); a missing file logs one warning and
##   plays nothing, so sounds can be added one at a time. Positional sounds use
##   AudioStreamPlayer2D, heard from the AudioListener2D the world view keeps on
##   the local hero, so every player hears the world from their own hero.
## Only the client plays sounds; the simulation never calls this.

const CONFIG_PATH := "res://content/audio/audio_config.tres"
const MUSIC_DIR := "res://content/audio/music"
const SILENT_DB := -60.0

var config: AudioConfig
var tracks: Array[MusicTrackDef] = []
var rng := RandomNumberGenerator.new()

## Music state: the track playing (null = none), the context asked for, the bond.
var current_track: MusicTrackDef = null
var context: int = -1
var bond: float = 1.0
var region: int = -1
var _players: Array[AudioStreamPlayer] = []
var _active := 0 # index of the player fading in / playing
## Per player: fade level 0..1 and where it is heading.
var _fade := [0.0, 0.0]
var _fade_target := [0.0, 0.0]
var _duck_until := -1.0
var _duck_level := 0.0 # 0 = none, 1 = fully ducked
var _clock := 0.0

var _ambience: AudioStreamPlayer
var _ambience_key: StringName = &""

var _streams := {} # path -> AudioStream (or null when missing)
var _warned := {} # key -> true
var _voices := {} # key -> count playing
## Keys asked for this session whose file doesn't exist (see missing_keys()).
var _missing := {}
const MAX_VARIANTS := 9


func _init() -> void:
	config = load(CONFIG_PATH) if ResourceLoader.exists(CONFIG_PATH) else AudioConfig.new()
	rng.randomize()
	_load_tracks()


func _ready() -> void:
	ensure_buses()
	# Every button in the game clicks (menus, HUD, windows).
	get_tree().node_added.connect(_on_node_added)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = &"Music"
		p.volume_db = SILENT_DB
		add_child(p)
		_players.append(p)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = &"Ambience"
	add_child(_ambience)
	load_volumes()


func _process(delta: float) -> void:
	step(delta)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(_click):
		node.pressed.connect(_click)


func _click() -> void:
	play(&"ui_click")


# --- Zone bond (hook for drained music) --------------------------------------------

## Bond values set at runtime (zone id -> 0..1), over ZoneDef.bond. Nothing sets
## them yet; a future bond system calls set_zone_bond().
var zone_bonds := {}


func set_zone_bond(zone_id: StringName, value: float) -> void:
	zone_bonds[zone_id] = clampf(value, 0.0, 1.0)


func bond_for(zone: ZoneDef) -> float:
	return float(zone_bonds.get(zone.id, zone.bond))


# --- Buses and volumes ---------------------------------------------------------

## Makes sure every bus exists (the layout file normally provides them).
static func ensure_buses() -> void:
	for name in AudioConfig.BUSES:
		if AudioServer.get_bus_index(name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, name)
			AudioServer.set_bus_send(i, &"Master")


## A bus's volume as a 0..1 slider value.
func get_volume(bus: String) -> float:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return 1.0
	if AudioServer.is_bus_mute(i):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(i)), 0.0, 1.0)


func set_volume(bus: String, value: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	value = clampf(value, 0.0, 1.0)
	AudioServer.set_bus_mute(i, value <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(value, 0.001)))


func load_volumes(path: String = SettingsStore.DEFAULT_PATH) -> void:
	var v := SettingsStore.load_volumes(path)
	for bus in v:
		set_volume(bus, v[bus])


func save_volumes(path: String = SettingsStore.DEFAULT_PATH) -> void:
	var v := {}
	for bus in AudioConfig.BUSES:
		v[bus] = get_volume(bus)
	SettingsStore.save_volumes(v, path)


# --- Music ------------------------------------------------------------------------

func _load_tracks() -> void:
	tracks.clear()
	if not DirAccess.dir_exists_absolute(MUSIC_DIR):
		return
	var files := ResourceLoader.list_directory(MUSIC_DIR)
	files.sort()
	for f in files:
		var name := f.trim_suffix(".remap")
		if name.ends_with(".tres"):
			var t = load(MUSIC_DIR.path_join(name))
			if t is MusicTrackDef:
				tracks.append(t)


## The track for `ctx` at zone bond `p_bond` in region `p_region` (Regions.Id,
## -1 = none, e.g. the title screen), following the fallbacks; null for silence.
## "keep" is set when the context says to keep the current music.
## At each step a track of the zone's region wins over tracks for any region
## (MusicTrackDef.regions empty); another region's track never plays.
func pick_track(ctx: int, p_bond: float = 1.0, p_region: int = -1, p_zone: StringName = &"") -> Dictionary:
	var tried := {}
	var queue := [ctx]
	while not queue.is_empty():
		var c: int = queue.pop_front()
		if c == -1:
			return {"keep": true, "track": current_track}
		if tried.has(c):
			continue
		tried[c] = true
		var found := _track_for(c, p_bond, p_region, p_zone)
		if found != null:
			return {"keep": false, "track": found}
		queue.append_array(config.fallbacks.get(c, []))
	return {"keep": false, "track": null}


func _track_for(ctx: int, p_bond: float, p_region: int, p_zone: StringName = &"") -> MusicTrackDef:
	if p_zone != &"":
		var mine := _track_among(ctx, p_bond, func(t: MusicTrackDef): return t.zones.has(p_zone))
		if mine != null:
			return mine
	var anywhere := func(t: MusicTrackDef): return t.zones.is_empty()
	if p_region >= 0:
		var own := _track_among(ctx, p_bond, func(t: MusicTrackDef): return anywhere.call(t) and t.regions.has(p_region))
		if own != null:
			return own
	return _track_among(ctx, p_bond, func(t: MusicTrackDef): return anywhere.call(t) and t.regions.is_empty())


func _track_among(ctx: int, p_bond: float, allowed: Callable) -> MusicTrackDef:
	var normal: MusicTrackDef = null
	for t in tracks:
		if not t.contexts.has(ctx) or not allowed.call(t) or not _has_file(t):
			continue
		if t.drained and p_bond < config.drained_bond_below:
			return t # the zone is drained: its drained variant wins
		if not t.drained and normal == null:
			normal = t
	return normal


## The track's file is in the game (tracks can be listed before their file exists).
func _has_file(t: MusicTrackDef) -> bool:
	return t.file != "" and ResourceLoader.exists(t.file)


## Switches the music to the context `ctx` (MusicTrackDef.Context) at zone bond
## `p_bond` (0..1; low picks drained variants) in region `p_region` (Regions.Id,
## -1 = none), zone `p_zone` (its own tracks first). Same track: nothing happens.
func set_context(ctx: int, p_bond: float = 1.0, p_region: int = -1, p_zone: StringName = &"") -> void:
	context = ctx
	bond = p_bond
	region = p_region
	var pick := pick_track(ctx, p_bond, p_region, p_zone)
	if pick.keep:
		return
	_switch_to(pick.track)


func _switch_to(track: MusicTrackDef) -> void:
	if track == current_track:
		return
	current_track = track
	# The old track fades out on its player; the new one fades in on the other.
	_fade_target[_active] = 0.0
	if track == null:
		return
	var stream := _music_stream(track)
	if stream == null:
		return
	_active = 1 - _active
	var p := _players[_active] if _players.size() == 2 else null
	_fade[_active] = 0.0
	_fade_target[_active] = 1.0
	if p != null:
		p.stream = stream
		p.volume_db = SILENT_DB
		p.play()


func _music_stream(track: MusicTrackDef) -> AudioStream:
	var s := _load_stream(track.file, StringName("music:" + String(track.id)))
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = track.loop
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = track.loop
	return s


## Lowers the music for a moment (big sounds).
func duck() -> void:
	_duck_until = _clock + config.duck_hold_seconds


## Advances fades and ducking by `delta` seconds (called every frame; tests call it).
func step(delta: float) -> void:
	_clock += delta
	var rate := delta / maxf(config.crossfade_seconds, 0.01)
	for i in 2:
		_fade[i] = move_toward(_fade[i], _fade_target[i], rate)
	var duck_target := 1.0 if _clock < _duck_until else 0.0
	var duck_rate := delta / (0.1 if duck_target > _duck_level else maxf(config.duck_release_seconds, 0.01))
	_duck_level = move_toward(_duck_level, duck_target, duck_rate)
	for i in _players.size():
		var p := _players[i]
		var track_db := current_track.volume_db if (i == _active and current_track != null) else 0.0
		p.volume_db = music_db(_fade[i], track_db)
		if _fade[i] <= 0.0 and _fade_target[i] <= 0.0 and p.playing:
			p.stop()


## The volume a music player gets at fade level `fade` (0..1).
func music_db(fade: float, track_db: float = 0.0) -> float:
	if fade <= 0.0:
		return SILENT_DB
	return track_db + linear_to_db(fade) + config.duck_db * _duck_level


## Fade level 0..1 of the track now playing (tests, debugging).
func music_fade() -> float:
	return _fade[_active]


func duck_level() -> float:
	return _duck_level


# --- Ambience -----------------------------------------------------------------------

## Loops the ambience `key` (e.g. "ambience_greenfields") on the Ambience bus; "" stops it.
func set_ambience(key: StringName) -> void:
	if key == _ambience_key:
		return
	_ambience_key = key
	if _ambience == null:
		return
	_ambience.stop()
	if key == &"":
		return
	var s := _sfx_stream(key)
	if s == null:
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	_ambience.stream = s
	_ambience.play()


# --- Sound effects ----------------------------------------------------------------

## Plays `key` without position (UI, the local hero's own sounds). Returns the
## player, or null when nothing plays (missing file, too many copies).
func play(key: StringName) -> Node:
	return _play(key, null, null)


## Plays `key` at `position` in `parent`'s canvas (the world view): louder near the
## listener, quieter far away.
func play_at(key: StringName, position: Vector2, parent: Node) -> Node:
	return _play(key, position, parent)


func _play(key: StringName, position: Variant, parent: Node) -> Node:
	var cat := config.category(key)
	var stream := _sfx_stream(key)
	if stream == null:
		return null
	var e := config.entry(key)
	var limit := e.max_voices if e != null and e.max_voices > 0 else config.max_voices
	if int(_voices.get(key, 0)) >= limit:
		return null
	var pitch_var: float = e.pitch_variation if e != null and e.pitch_variation >= 0.0 else float(cat.get("pitch", 0.0))
	var vol_var: float = e.volume_variation_db if e != null and e.volume_variation_db >= 0.0 else float(cat.get("volume", 0.0))
	var v := varied(e.volume_db if e != null else 0.0, pitch_var, vol_var)
	var player: Node
	if position != null and parent != null and is_instance_valid(parent):
		var p2 := AudioStreamPlayer2D.new()
		p2.position = position
		p2.max_distance = config.hearing_tiles * Iso.TILE_W
		p2.attenuation = config.attenuation
		p2.stream = stream
		p2.bus = StringName(cat.get("bus", "SFX"))
		p2.volume_db = v.volume_db
		p2.pitch_scale = v.pitch
		parent.add_child(p2)
		p2.play()
		p2.finished.connect(_on_finished.bind(p2, key))
		player = p2
	else:
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.bus = StringName(cat.get("bus", "SFX"))
		p.volume_db = v.volume_db
		p.pitch_scale = v.pitch
		add_child(p)
		p.play()
		p.finished.connect(_on_finished.bind(p, key))
		player = p
	_voices[key] = int(_voices.get(key, 0)) + 1
	if e != null and e.ducks_music:
		duck()
	return player


## A volume and pitch with random variation (so repeated sounds don't sound robotic).
func varied(volume_db: float, pitch_variation: float, volume_variation_db: float) -> Dictionary:
	return {"volume_db": volume_db + rng.randf_range(-volume_variation_db, volume_variation_db),
			"pitch": maxf(0.05, 1.0 + rng.randf_range(-pitch_variation, pitch_variation))}


func _on_finished(player: Node, key: StringName) -> void:
	_voices[key] = maxi(int(_voices.get(key, 1)) - 1, 0)
	if is_instance_valid(player):
		player.queue_free()


func _sfx_stream(key: StringName) -> AudioStream:
	var path := config.file_for(key)
	if path == "":
		_warn(key, "Audio: unknown sound key '%s' (its first word names no category)" % key)
		return null
	return _load_stream(path, key)


func _load_stream(path: String, key: StringName) -> AudioStream:
	if _streams.has(path):
		if _streams[path] == null:
			_missing[key] = path
		return _streams[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path) as AudioStream
	else:
		s = _variants(path)
	_streams[path] = s
	if s == null:
		_missing[key] = path
		_warn(key, "Audio: missing sound '%s' (expected %s)" % [key, path])
	return s


## Numbered takes of one sound (<key>_1.wav, <key>_2.wav...) instead of <key>.wav:
## each play picks one at random, never the same twice in a row. null if none.
static func _variants(path: String) -> AudioStream:
	var r := AudioStreamRandomizer.new()
	r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	r.random_pitch = 1.0 # pitch and volume are varied by varied()
	r.random_volume_offset_db = 0.0
	for i in range(1, MAX_VARIANTS + 1):
		var p := "%s_%d.%s" % [path.get_basename(), i, path.get_extension()]
		if not ResourceLoader.exists(p):
			break
		r.add_stream(-1, load(p))
	return r if r.streams_count > 0 else null


func _warn(key: StringName, text: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(text)


## Keys asked for this session that have no file yet: key -> expected path.
func missing_keys() -> Dictionary:
	return _missing.duplicate()
