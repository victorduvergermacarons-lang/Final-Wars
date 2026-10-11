class_name ServerSession
extends LocalSession
## Host: runs the authoritative WorldSim like solo play, plays as one of the
## heroes itself, and serves remote players over ENet. Remote intents enter the
## world through the same receive_intent() as the host's own.

var player_name := "Host"
var _heroes_by_peer := {} # peer id -> hero id


func start_hosting(zone: ZoneDef, rules: CombatRules, hero_def: HeroDef, port: int, p_name: String) -> Error:
	var err: Error = Net.host(port)
	if err != OK:
		return err
	start(zone, rules, hero_def, randi())
	player_name = p_name
	local_hero().display_name = p_name
	_heroes_by_peer[1] = local_hero_id
	Net.handler = self
	Net.peer_left.connect(_on_peer_left)
	return OK


func _exit_tree() -> void:
	if Net.handler == self:
		Net.close()


func on_join(peer_id: int, p_name: String) -> void:
	if _heroes_by_peer.has(peer_id):
		return
	if _heroes_by_peer.size() >= Net.MAX_PLAYERS:
		Net.send_refused(peer_id, "The game is full.")
		return
	var hero := world.add_hero(ContentDB.heroes[&"adventurer"])
	hero.display_name = p_name.strip_edges().left(16) if not p_name.strip_edges().is_empty() else "Player %d" % hero.id
	_heroes_by_peer[peer_id] = hero.id
	Net.send_welcome(peer_id, hero.id, world.zone.id)
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


func _on_tick(events: Array) -> void:
	if _heroes_by_peer.size() <= 1:
		return # nobody to send to
	Net.broadcast_snapshot(Snapshot.capture(world))
	if not events.is_empty():
		Net.broadcast_events(events)
