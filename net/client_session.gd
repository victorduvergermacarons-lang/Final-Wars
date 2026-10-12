class_name ClientSession
extends Node
## Joined player: sends intents to the host and mirrors the world from its
## snapshots, predicting the local hero's steps. Same read API as LocalSession.

signal events_received(events: Array)
## The local hero moved to another zone; the view should switch maps.
signal zone_changed(zone: ZoneDef)
## The host accepted us; the world can be shown.
signal welcomed
## Connection ended (failed, refused or host gone), with a reason for the player.
signal ended(reason: String)

func zone() -> ZoneDef:
	return mirror.zone


## Never extrapolate drawing further than this past the last snapshot.
const MAX_EXTRAPOLATION := 0.25

var mirror: ClientWorld
var local_hero_id: int = -1
var character: Dictionary = {}
var _snapshot_received_at := 0.0
var _connected := false


func connect_to(address: String, port: int, p_character: Dictionary) -> Error:
	character = p_character
	var err: Error = Net.join(address, port)
	if err != OK:
		return err
	Net.handler = self
	Net.connected_to_host.connect(_on_connected)
	Net.connection_failed.connect(func(): ended.emit("Could not connect to %s:%d." % [address, port]))
	Net.host_disconnected.connect(func(): ended.emit("The host left the game."))
	return OK


func _exit_tree() -> void:
	if Net.handler == self:
		Net.close()


func _on_connected() -> void:
	_connected = true
	Net.send_join(character)


func on_welcome(hero_id: int, zone_id: StringName) -> void:
	var zone: ZoneDef = ContentDB.zones.get(zone_id)
	if zone == null:
		ended.emit("The host is using a zone this game doesn't have (%s)." % zone_id)
		return
	local_hero_id = hero_id
	mirror = ClientWorld.new(zone, ContentDB.rules, ContentDB)
	mirror.local_hero_id = hero_id


func on_refused(reason: String) -> void:
	ended.emit(reason)


func on_snapshot(snap: Dictionary) -> void:
	if mirror == null:
		return
	var first := mirror.tick == 0
	if snap.tick <= mirror.tick:
		return
	var snap_zone := StringName(str(snap.get("zone", mirror.zone.id)))
	if snap_zone != mirror.zone.id:
		var zone: ZoneDef = ContentDB.zones.get(snap_zone)
		if zone == null:
			ended.emit("The host moved you to a zone this game doesn't have (%s)." % snap_zone)
			return
		var next := ClientWorld.new(zone, ContentDB.rules, ContentDB)
		next.local_hero_id = local_hero_id
		next.continue_sequence_from(mirror)
		next.tick = mirror.tick
		mirror = next
		if not first:
			zone_changed.emit(zone)
	mirror.apply_snapshot(snap)
	_snapshot_received_at = _clock()
	if first:
		welcomed.emit()


func on_events(events: Array) -> void:
	if mirror != null:
		events_received.emit(events)


func send_intent(intent: Dictionary) -> void:
	if mirror == null:
		return
	var seq := mirror.take_seq()
	intent = intent.duplicate()
	intent.seq = seq
	if intent.get("type") == "step":
		mirror.predict_step(seq, intent.to, render_time())
	elif intent.get("type") == "face":
		mirror.predict_face(seq, intent.dir)
	Net.send_intent(intent)


# --- Read-only view of the world (same API as LocalSession) -----------------------

func grid() -> GridModel:
	return mirror.grid


func rules() -> CombatRules:
	return mirror.rules


func now() -> float:
	return mirror.now


func render_time() -> float:
	return mirror.now + minf(_clock() - _snapshot_received_at, MAX_EXTRAPOLATION)


func actors() -> Array[Actor]:
	return mirror.actors()


func pending_loot() -> Array:
	var hero := local_hero()
	return hero.pending_loot if hero != null else []


func projectiles() -> Array:
	return mirror.projectiles


func telegraphs() -> Array:
	return mirror.telegraphs


func world_flags() -> Dictionary:
	return mirror.world_flags


func get_actor(id: int) -> Actor:
	return mirror.get_actor(id)


func local_hero() -> Hero:
	return mirror.local_hero() if mirror != null else null


static func _clock() -> float:
	return Time.get_ticks_msec() / 1000.0
