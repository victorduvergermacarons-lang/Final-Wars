class_name WaterAmbience
extends Node2D
## The sound of water near the local hero (client side, made by SoundDirector).
## Every AudioConfig.water_update_seconds it looks at the water tiles within
## water_radius_tiles of the hero (WaterSound: the zone's water is indexed once when
## its map loads) and keeps up to water_max_emitters looping emitters of
## SoundCatalog.WATER_AMBIENCE, each at the nearest tile of a cluster of water.
## - Emitters are AudioStreamPlayer2Ds on the Ambience bus (its slider controls
##   them), each starting at a random point of the loop so two never play in step.
## - Level: water_volume_db at the water, falling with the grid distance to the hero
##   (WaterSound.gain) to silence at the radius; heard left / right from the
##   listener as any world sound. Godot's own distance fade is off: on an isometric
##   map a tile is a different number of screen pixels in each direction.
## - A spot that moves a little (walking along a river) glides there; one that jumps,
##   appears or goes fades in / out over water_fade_seconds. A new zone fades every
##   emitter out and indexes the new map. It plays alongside the zone's ambience.
## Emitters live under this node (not the world view, which is freed with its map)
## and are placed through the view's transform.

var session
var view: WorldView
var config: AudioConfig

var _index := {} # WaterSound.index of the zone
var _zone_id: StringName = &""
var _wait := 0.0
var _stream: AudioStream
## Each emitter: {"player", "tile" (Vector2i, where it heads), "at" (Vector2, where
## it is now), "fade" (0..1), "dying" (bool), "gain" (its level by distance, last
## measured: kept while it fades out, so leaving a map doesn't jump its level)}.
var _emitters: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()


func setup(p_session, p_view: WorldView, p_config: AudioConfig) -> void:
	session = p_session
	config = p_config
	set_view(p_view)


## A new world view (a new map): emitters of the old map fade out, its water is indexed.
func set_view(p_view: WorldView) -> void:
	view = p_view
	var zone: ZoneDef = session.zone() if session != null else null
	var id: StringName = zone.id if zone != null else &""
	if id == _zone_id and not _index.is_empty():
		return
	_zone_id = id
	_index = WaterSound.index(zone, ContentDB.tilesets.get(zone.tileset) if zone != null else null)
	for e in _emitters:
		e.dying = true
	_wait = 0.0


func emitter_count() -> int:
	return _emitters.filter(func(e): return not e.dying).size()


func emitters() -> Array[Dictionary]:
	return _emitters


func _process(delta: float) -> void:
	step(delta)


## Advances by `delta` seconds (tests call it directly).
func step(delta: float) -> void:
	if session == null or config == null:
		return
	var me = session.local_hero()
	var hero_at: Vector2 = me.move.pos if me != null else Vector2.INF
	_wait -= delta
	if _wait <= 0.0:
		_wait = config.water_update_seconds
		_retarget(hero_at if me != null else Vector2.INF)
	var fade_step := delta / maxf(config.water_fade_seconds, 0.01)
	var glide := 1.0 - exp(-delta * 4.0 / maxf(config.water_fade_seconds, 0.01))
	for i in range(_emitters.size() - 1, -1, -1):
		var e: Dictionary = _emitters[i]
		e.fade = clampf(e.fade + (-fade_step if e.dying else fade_step), 0.0, 1.0)
		if e.dying and e.fade <= 0.0:
			if is_instance_valid(e.player):
				e.player.queue_free()
			_emitters.remove_at(i)
			continue
		if not e.dying:
			e.at = e.at.lerp(Vector2(e.tile), glide)
		_place(e, hero_at)


## Matches the emitters to the spots around the hero: the same or a nearby spot keeps
## its emitter (gliding), a far one is replaced (fade out, fade in).
func _retarget(hero_at: Vector2) -> void:
	var spots: Array[Vector2i] = []
	if hero_at != Vector2.INF:
		spots = WaterSound.spots(WaterSound.near(_index, hero_at, config.water_radius_tiles), hero_at,
				config.water_max_emitters)
	var free_spots := spots.duplicate()
	for e in _emitters:
		if e.dying:
			continue
		var best := -1
		var best_d := INF
		for j in free_spots.size():
			var d: float = Vector2(free_spots[j]).distance_to(e.at)
			if d < best_d:
				best_d = d
				best = j
		if best >= 0 and best_d <= config.water_glide_tiles:
			e.tile = free_spots[best]
			free_spots.remove_at(best)
		else:
			e.dying = true
	for t in free_spots:
		if emitter_count() >= config.water_max_emitters:
			break
		_add(t)


func _add(tile: Vector2i) -> void:
	if _stream == null:
		_stream = Audio.stream(SoundCatalog.WATER_AMBIENCE)
		if _stream is AudioStreamOggVorbis:
			(_stream as AudioStreamOggVorbis).loop = true
	var p := AudioStreamPlayer2D.new()
	p.bus = &"Ambience"
	p.attenuation = 0.0 # the level is set from the grid distance (see the class comment)
	p.max_distance = 1.0e6
	p.volume_db = -80.0
	add_child(p)
	if _stream != null:
		p.stream = _stream
		p.play(rng.randf() * maxf(_stream.get_length() - 0.1, 0.0))
	_emitters.append({"player": p, "tile": tile, "at": Vector2(tile), "fade": 0.0, "dying": false, "gain": 0.0})


func _place(e: Dictionary, hero_at: Vector2) -> void:
	var p: AudioStreamPlayer2D = e.player
	if not is_instance_valid(p):
		return
	if not e.dying:
		e.gain = 0.0 if hero_at == Vector2.INF else \
				WaterSound.gain(hero_at.distance_to(e.at), config.water_radius_tiles, config.water_falloff)
	var level: float = e.gain * e.fade
	p.volume_db = config.water_volume_db + linear_to_db(level) if level > 0.0001 else -80.0
	if view != null and is_instance_valid(view) and not e.dying:
		var grid: GridModel = session.grid()
		var h := float(grid.height_at(e.tile)) if grid != null and grid.in_bounds(e.tile) else 0.0
		p.global_position = view.get_global_transform() * Iso.to_screen(e.at, h)
