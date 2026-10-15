extends Node

signal host_created()
signal client_connected()
signal avatar_updated(steam_id: int, texture: Texture2D)

const LOBBY_TYPE := Steam.LobbyType.LOBBY_TYPE_FRIENDS_ONLY
const MAX_MEMBERS := 4

var peer: SteamMultiplayerPeer
var current_lobby_id: int = 0
var avatar_cache: Dictionary = {}

func _ready() -> void:
	if not Steam.isSteamRunning():
		push_warning("Steam not running; multiplayer unavailable")
		return
	Steam.initRelayNetworkAccess()
	Steam.lobby_created.connect(on_lobby_created)
	Steam.lobby_joined.connect(on_lobby_joined)
	Steam.join_requested.connect(on_join_requested)
	if Steam.has_signal("avatar_loaded"):
		Steam.avatar_loaded.connect(_on_avatar_loaded)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _exit_tree() -> void:
	if current_lobby_id != 0:
		Steam.leaveLobby(current_lobby_id)
	if peer != null:
		peer.close()

func _process(_delta: float) -> void:
	Steam.run_callbacks()

func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		print("Peer disconnected: ", peer_id)

func leave_current_session() -> void:
	if peer != null:
		peer.close()
		multiplayer.multiplayer_peer = null
		peer = null
	if current_lobby_id != 0:
		Steam.leaveLobby(current_lobby_id)
		current_lobby_id = 0

func host_lobby() -> void:
	leave_current_session()
	await get_tree().process_frame
	Steam.createLobby(LOBBY_TYPE, MAX_MEMBERS)

func on_lobby_created(_connect: int, lobby_id: int) -> void:
	if _connect == Steam.RESULT_OK:
		current_lobby_id = lobby_id
		peer = SteamMultiplayerPeer.new()
		peer.server_relay = true
		peer.create_host()
		multiplayer.multiplayer_peer = peer
		await get_tree().process_frame
		await get_tree().process_frame
		host_created.emit()
	else:
		push_error("Failed to create Steam lobby: %s" % _connect)

func on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		push_error("Failed to join Steam lobby: %s" % response)
		return
	current_lobby_id = lobby_id
	if Steam.getLobbyOwner(lobby_id) == Steam.getSteamID():
		return
	if peer != null:
		peer.close()
		multiplayer.multiplayer_peer = null
		peer = null
		await get_tree().process_frame
	peer = SteamMultiplayerPeer.new()
	peer.server_relay = true
	var error := peer.create_client(Steam.getLobbyOwner(lobby_id))
	if error != OK:
		push_error("Failed to create Steam client peer: %s" % error)
		return
	multiplayer.multiplayer_peer = peer
	client_connected.emit()
	var current = get_tree().current_scene
	if current and current.scene_file_path != "res://scenes/core/main.tscn":
		get_tree().change_scene_to_file("res://scenes/core/main.tscn")

func on_join_requested(lobby_id: int, _steam_id: int) -> void:
	if current_lobby_id == lobby_id and peer != null and multiplayer.multiplayer_peer != null:
		print("[NETWORKING] Already in lobby %d, ignoring duplicate join" % lobby_id)
		return
	leave_current_session()
	await get_tree().process_frame
	Steam.joinLobby(lobby_id)

func get_local_player_name() -> String:
	if Steam.isSteamRunning():
		var p_name = Steam.getPersonaName()
		if p_name != "":
			return p_name
	return "Player_%d" % (randi() % 900 + 100)

func get_local_steam_id() -> int:
	if Steam.isSteamRunning():
		return Steam.getSteamID()
	return 0

func get_avatar_texture(steam_id: int) -> Texture2D:
	if steam_id in avatar_cache:
		return avatar_cache[steam_id]
	if Steam.isSteamRunning() and steam_id != 0:
		Steam.getPlayerAvatar(Steam.AVATAR_MEDIUM, steam_id)
		var handle = Steam.getMediumFriendAvatar(steam_id)
		if handle > 0:
			var size_dict = Steam.getImageSize(handle)
			var w = size_dict.get("width", 64) if size_dict is Dictionary else 64
			var h = size_dict.get("height", 64) if size_dict is Dictionary else 64
			var buf_data = Steam.getImageRGBA(handle)
			var raw_bytes: PackedByteArray
			if buf_data is Dictionary:
				raw_bytes = buf_data.get("buffer", PackedByteArray())
			elif buf_data is PackedByteArray:
				raw_bytes = buf_data
			if raw_bytes.size() > 0:
				var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, raw_bytes)
				var tex := ImageTexture.create_from_image(img)
				avatar_cache[steam_id] = tex
				return tex
	return null

func _on_avatar_loaded(user_id: int, size: int, buffer: PackedByteArray) -> void:
	if buffer.size() > 0 and size > 0:
		var img := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, buffer)
		if img:
			var tex := ImageTexture.create_from_image(img)
			avatar_cache[user_id] = tex
			avatar_updated.emit(user_id, tex)
