class_name ServerSession
extends LocalSession
## Host: runs the authoritative WorldSim like solo play, plays as one of the
## heroes itself, and serves remote players over ENet. Remote intents enter the
## world through the same receive_intent() as the host's own.

var player_name := "Host"
var _heroes_by_peer := {} # peer id -> hero id


func start_hosting(zones: Array, start_zone: StringName, rules: CombatRules, character: Dictionary, port: int) -> Error:
	var err: Error = Net.host(port)
	if err != OK:
		return err
	start(zones, start_zone, rules, character, randi())
	player_name = local_hero().display_name
	_heroes_by_peer[1] = local_hero_id
	Net.handler = self
	Net.peer_left.connect(_on_peer_left)
	return OK


func _exit_tree() -> void:
	if Net.handler == self:
		Net.close()


## A player joined with their saved character: validate it and bring the hero in.
func on_join(peer_id: int, character: Dictionary) -> void:
	if _heroes_by_peer.has(peer_id):
		return
	if _heroes_by_peer.size() >= Net.MAX_PLAYERS:
		Net.send_refused(peer_id, "The game is full (%d players)." % Net.MAX_PLAYERS)
		return
	var hero := world.add_saved_hero(character, ContentDB)
	_heroes_by_peer[peer_id] = hero.id
	Net.send_welcome(peer_id, hero.id, world.zone_of(hero.id).zone.id)
	events_received.emit([{"type": "joined", "target": hero.id, "name": hero.display_name}])


func on_remote_intent(peer_id: int, intent: Dictionary) -> void:
	var hero_id: int = _heroes_by_peer.get(peer_id, -1)
	if hero_id >= 0:
		receive_intent(hero_id, intent)


func _on_peer_left(peer_id: int) -> void:
	var hero_id: int = _heroes_by_peer.get(peer_id, -1)
	_heroes_by_peer.erase(peer_id)
	if hero_id >= 0:
		var name := world.get_actor(hero_id).display_name
		world.remove_hero(hero_id)
		events_received.emit([{"type": "left", "target": hero_id, "name": name}])


## Each remote player gets a snapshot of their own zone, with their private data,
## and only the events of that zone.
func _on_tick(events: Array) -> void:
	for peer_id in _heroes_by_peer:
		if peer_id == 1:
			continue
		var hero_id: int = _heroes_by_peer[peer_id]
		var sim := world.zone_of(hero_id)
		if sim == null:
			continue
		Net.send_snapshot(peer_id, Snapshot.capture(sim, hero_id))
		var zone_id := sim.zone.id
		var theirs := events.filter(func(e): return e.get("zone", zone_id) == zone_id)
		if not theirs.is_empty():
			Net.send_events(peer_id, theirs)
