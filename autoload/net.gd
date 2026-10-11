extends Node
## ENet transport and the game's RPCs. Lives at /root/Net on every peer so RPC
## paths match. Holds no game logic: it forwards messages to `handler` (the
## active ServerSession or ClientSession).
##
## Client → host: join(character data), intent(dict)
## Host → client: welcome(hero_id, zone_id), refused(reason), snapshot(dict), events(array)

signal connected_to_host
signal connection_failed
signal host_disconnected
signal peer_left(peer_id: int)

const DEFAULT_PORT := 7777
## Total players including the host. Milestone 1 plays with 2.
const MAX_PLAYERS := 4
## Largest character save a joining player may send (bytes, encoded).
const MAX_CHARACTER_BYTES := 64 * 1024

var handler: Object


func _ready() -> void:
	multiplayer.connected_to_server.connect(func(): connected_to_host.emit())
	multiplayer.connection_failed.connect(func(): connection_failed.emit())
	multiplayer.server_disconnected.connect(func(): host_disconnected.emit())
	multiplayer.peer_disconnected.connect(func(id): peer_left.emit(id))


func host(port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func join(address: String, port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func close() -> void:
	handler = null
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func is_online() -> bool:
	return multiplayer.multiplayer_peer is ENetMultiplayerPeer


# --- Client → host ---------------------------------------------------------------

func send_join(character: Dictionary) -> void:
	_c2s_join.rpc_id(1, character)


func send_intent(intent: Dictionary) -> void:
	_c2s_intent.rpc_id(1, intent)


@rpc("any_peer", "call_remote", "reliable")
func _c2s_join(character: Dictionary) -> void:
	if handler == null or not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if var_to_bytes(character).size() > MAX_CHARACTER_BYTES:
		send_refused(peer, "Your character data is too large.")
		return
	handler.on_join(peer, character)


@rpc("any_peer", "call_remote", "reliable")
func _c2s_intent(intent: Dictionary) -> void:
	if handler != null and multiplayer.is_server():
		handler.on_remote_intent(multiplayer.get_remote_sender_id(), intent)


# --- Host → client ---------------------------------------------------------------

func send_welcome(peer_id: int, hero_id: int, zone_id: StringName) -> void:
	_s2c_welcome.rpc_id(peer_id, hero_id, String(zone_id))


func send_refused(peer_id: int, reason: String) -> void:
	_s2c_refused.rpc_id(peer_id, reason)


## Snapshots are deflate-compressed (~5 KB → ~0.6 KB) to stay within one packet.
func send_snapshot(peer_id: int, snap: Dictionary) -> void:
	var raw := var_to_bytes(snap)
	_s2c_snapshot.rpc_id(peer_id, raw.size(), raw.compress(FileAccess.COMPRESSION_DEFLATE))


func broadcast_events(events: Array) -> void:
	_s2c_events.rpc(events)


@rpc("authority", "call_remote", "reliable")
func _s2c_welcome(hero_id: int, zone_id: String) -> void:
	if handler != null:
		handler.on_welcome(hero_id, StringName(zone_id))


@rpc("authority", "call_remote", "reliable")
func _s2c_refused(reason: String) -> void:
	if handler != null:
		handler.on_refused(reason)


@rpc("authority", "call_remote", "unreliable_ordered")
func _s2c_snapshot(raw_size: int, packed: PackedByteArray) -> void:
	if handler == null or raw_size <= 0 or raw_size > 1 << 22:
		return
	# bytes_to_var (not _with_objects) never decodes objects, so a host can't inject code.
	var snap = bytes_to_var(packed.decompress(raw_size, FileAccess.COMPRESSION_DEFLATE))
	if typeof(snap) == TYPE_DICTIONARY:
		handler.on_snapshot(snap)


@rpc("authority", "call_remote", "reliable")
func _s2c_events(events: Array) -> void:
	if handler != null:
		handler.on_events(events)
