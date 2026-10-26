class_name SoundDirector
extends Node
## Turns what the local player sees and hears into sound (client side only):
## - game events -> sound keys (SoundCatalog): abilities when used and where they
##   land, creatures (aggro, hurt, death, steps), footsteps, world and interface
##   events. World sounds play at their place in the world view and are heard from
##   the local hero (an AudioListener2D on it), so each player hears their own mix.
## - the music context: the zone's (town, explore, dungeon), combat while a fight
##   goes on near the local hero, boss when an elite is in it; the zone's ambience
##   and bond.

var session
var client: ClientState
var view: WorldView:
	set(value):
		view = value
		_attach_listener()
var catalog: SoundCatalog

var _listener: AudioListener2D
var _last_step := {} # actor id -> move.start_time already heard
var _started := {} # caster id -> ability id whose start sound already played
var _hurt_at := {} # enemy id -> last hurt sound time (not every tick of fire)
const HURT_GAP := 0.4
const MUSIC_EVERY := 0.25
var _music_wait := 0.0


func setup(p_session, p_client: ClientState, p_view: WorldView) -> void:
	session = p_session
	client = p_client
	catalog = SoundCatalog.new(ContentDB)
	view = p_view
	session.events_received.connect(_on_events)
	_update_music(true)


func _attach_listener() -> void:
	if view == null:
		return
	_listener = AudioListener2D.new()
	view.add_child(_listener)
	_listener.make_current()
	_last_step.clear()


func _process(delta: float) -> void:
	if session == null or view == null or not is_instance_valid(view):
		return
	var me = session.local_hero()
	if me != null and _listener != null:
		_listener.position = view.actor_screen_pos(me)
	_footsteps()
	_music_wait -= delta
	if _music_wait <= 0.0:
		_music_wait = MUSIC_EVERY
		_update_music()


# --- Music ------------------------------------------------------------------------

## The music context for the local hero right now (see the class comment).
func music_context() -> int:
	var zone: ZoneDef = session.zone()
	var ctx: int = zone.music_context
	var me = session.local_hero()
	if me == null:
		return ctx
	var now: float = session.now()
	var radius := Audio.config.combat_radius_tiles
	var fight := false
	for a in session.actors():
		if a is Npc or not a.in_combat(now):
			continue
		if a != me and GridModel.distance(a.tile(), me.tile()) > radius:
			continue
		fight = true
		if a is Enemy and (a as Enemy).def.elite:
			return MusicTrackDef.Context.BOSS
	return MusicTrackDef.Context.COMBAT if fight else ctx


func _update_music(zone_changed: bool = false) -> void:
	var zone: ZoneDef = session.zone()
	if zone == null:
		return
	Audio.set_context(music_context(), Audio.bond_for(zone))
	if zone_changed:
		Audio.set_ambience(SoundCatalog.ambience_key(zone))


## A new map: new listener, ambience and music.
func on_zone_changed(new_view: WorldView) -> void:
	view = new_view
	_update_music(true)
	Audio.play(&"world_zone_enter")


# --- Footsteps --------------------------------------------------------------------

func _footsteps() -> void:
	var zone: ZoneDef = session.zone()
	for a in session.actors():
		if a is Npc or not a.alive:
			continue
		var start: float = a.move.start_time
		if _last_step.get(a.id, -1.0) == start:
			continue
		var first := not _last_step.has(a.id)
		_last_step[a.id] = start
		if first or not a.move.is_moving(session.render_time()) and a.move.from_tile == a.move.to_tile:
			continue # just seen, or placed rather than walking
		var key: StringName
		if a is Enemy:
			key = SoundCatalog.creature_key((a as Enemy).def.id, "step")
		else:
			key = SoundCatalog.footstep_key(zone.terrain_at(a.tile()) if zone.has_terrain() else "")
		_play_on(key, a)


# --- Events -----------------------------------------------------------------------

func _on_events(events: Array) -> void:
	var me: int = session.local_hero_id
	for e in events:
		match e.type:
			"cast_start":
				_started[e.source] = e.ability
				_play_on(catalog.cast_key(e.ability, _enemy_id(e.source)), _actor(e.source))
			"cast":
				if _started.get(e.source) == e.ability:
					_started.erase(e.source) # its start sound already played
				else:
					_play_on(catalog.cast_key(e.ability, _enemy_id(e.source)), _actor(e.source))
			"damage", "heal", "shield":
				var target = _actor(e.target)
				_play_on(catalog.hit_key(e.get("ability", &""), _enemy_id(e.get("source", -1))), target)
				if e.type == "damage" and target is Enemy:
					var t: float = session.now()
					if t - float(_hurt_at.get(e.target, -10.0)) >= HURT_GAP:
						_hurt_at[e.target] = t
						_play_on(SoundCatalog.creature_key(target.def.id, "hurt"), target)
			"miss":
				_play_on(&"world_miss", _actor(e.target))
			"whiff":
				_play_at_tile(&"world_whiff", e.get("tile", Vector2i.ZERO))
			"death":
				var dead = _actor(e.target)
				if dead is Enemy:
					_play_on(SoundCatalog.creature_key(dead.def.id, "death"), dead)
				elif dead != null:
					_play_on(&"world_hero_death", dead)
			"aggro":
				var who = _actor(e.source)
				if who is Enemy:
					_play_on(SoundCatalog.creature_key(who.def.id, "aggro"), who)
			"grounded":
				var g = _actor(e.target)
				if g is Enemy:
					_play_on(SoundCatalog.creature_key(g.def.id, "grounded"), g)
			"enrage":
				var r = _actor(e.source)
				if r is Enemy:
					_play_on(SoundCatalog.creature_key(r.def.id, "enrage"), r)
			"level_up":
				_play_on(&"world_level_up", _actor(e.target))
			"zone_reset":
				Audio.play(&"world_shrine_reset")
			"world_flag":
				if ContentDB.dialogue.has("quest.%s.world_flag" % e.get("quest", "")):
					Audio.play(&"world_event")
		if e.get("target", -2) != me:
			continue
		# The local player's own interface sounds (no position).
		match e.type:
			"mastered":
				Audio.play(&"world_mastered")
			"release":
				Audio.play(&"world_release")
			"buy", "sell":
				Audio.play(&"ui_coins")
			"equip", "unequip":
				Audio.play(&"ui_equip")
			"learning":
				Audio.play(&"ui_learn")
			"loot":
				Audio.play(&"ui_loot")
			"quest_accepted":
				Audio.play(&"ui_quest_accept")
			"quest_completed":
				Audio.play(&"ui_quest_complete")
			"rejected":
				if e.get("intent", "") != "debug":
					Audio.play(&"ui_error")


func _actor(id) -> Actor:
	return session.get_actor(int(id)) if id != null else null


func _enemy_id(id) -> StringName:
	var a := _actor(id)
	return (a as Enemy).def.id if a is Enemy else &""


func _play_on(key: StringName, actor) -> void:
	if key == &"":
		return
	if actor == null or view == null or not is_instance_valid(view):
		Audio.play(key)
		return
	Audio.play_at(key, view.actor_screen_pos(actor), view)


func _play_at_tile(key: StringName, tile: Vector2i) -> void:
	if view == null or not is_instance_valid(view):
		Audio.play(key)
		return
	Audio.play_at(key, view.surface_point(session.grid(), tile), view)
