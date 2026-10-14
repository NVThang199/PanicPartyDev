extends Node

signal host_created()
signal client_connected()

const LOBBY_TYPE := Steam.LobbyType.LOBBY_TYPE_FRIENDS_ONLY
const MAX_MEMBERS := 4

var peer: SteamMultiplayerPeer
var current_lobby_id: int = 0

func _ready() -> void:
	if not Steam.isSteamRunning():
		push_warning("Steam not running; multiplayer unavailable")
		return
	Steam.initRelayNetworkAccess()
	Steam.lobby_created.connect(on_lobby_created)
	Steam.lobby_joined.connect(on_lobby_joined)
	Steam.join_requested.connect(on_join_requested)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _exit_tree() -> void:
	if current_lobby_id != 0:
		Steam.leaveLobby(current_lobby_id)
	if peer != null:
		peer.close()

func _process(delta: float) -> void:
	Steam.run_callbacks()

func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		print("Peer disconnected: ", peer_id)

func host_lobby() -> void:
	if peer != null:
		peer.close()
		multiplayer.multiplayer_peer = null
		peer = null
	if current_lobby_id != 0:
		Steam.leaveLobby(current_lobby_id)
		current_lobby_id = 0
		await get_tree().process_frame
	Steam.createLobby(LOBBY_TYPE, MAX_MEMBERS)

func on_lobby_created(connect: int, lobby_id: int) -> void:
	if connect == Steam.RESULT_OK:
		current_lobby_id = lobby_id
		peer = SteamMultiplayerPeer.new()
		peer.server_relay = true
		peer.create_host()
		multiplayer.multiplayer_peer = peer
		await get_tree().process_frame
		await get_tree().process_frame
		host_created.emit()
	else:
		push_error("Failed to create Steam lobby: %s" % connect)

func on_lobby_joined(lobby_id: int, permissions: int, locked: bool, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		push_error("Failed to join Steam lobby: %s" % response)
		return
	current_lobby_id = lobby_id
	if Steam.getLobbyOwner(lobby_id) == Steam.getSteamID():
		return
	if peer != null:
		peer.close()
	peer = SteamMultiplayerPeer.new()
	peer.server_relay = true
	var error := peer.create_client(Steam.getLobbyOwner(lobby_id))
	if error != OK:
		push_error("Failed to create Steam client peer: %s" % error)
		return
	multiplayer.multiplayer_peer = peer
	client_connected.emit()

func on_join_requested(lobby_id: int, steam_id: int) -> void:
	Steam.joinLobby(lobby_id)
