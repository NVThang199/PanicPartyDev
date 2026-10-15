extends Node3D

const PLAYER_SCENE = preload("res://scenes/players/player.tscn")

var players: Dictionary = {}

func _ready() -> void:
	Networking.host_created.connect(on_host_created)
	Networking.client_connected.connect(on_client_connected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(remove_player)
	$UI/HostButton.pressed.connect(_on_host_pressed)
	$UI/QuitButton.pressed.connect(_on_quit_pressed)

func on_host_created() -> void:
	$UI/StatusLabel.text = "Hosting - ID: %d" % multiplayer.get_unique_id()
	spawn_player_local(multiplayer.get_unique_id())

func on_client_connected() -> void:
	$UI/StatusLabel.text = "Connected - ID: %d" % multiplayer.get_unique_id()
	await get_tree().process_frame
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	request_player_list.rpc_id(1)

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	print("Peer connected: ", peer_id)
	await get_tree().process_frame
	# Spawn new client on all peers
	spawn_player_rpc.rpc(peer_id)

@rpc("any_peer", "reliable")
func request_player_list() -> void:
	if not multiplayer.is_server():
		return
	var caller_id := multiplayer.get_remote_sender_id()
	print("Client %d requesting player list" % caller_id)
	# Send all existing players (including host) to requesting client
	for peer_id in players:
		spawn_player_rpc.rpc_id(caller_id, peer_id)

@rpc("authority", "call_local", "reliable")
func spawn_player_rpc(peer_id: int) -> void:
	if peer_id in players:
		return
	print("Spawning player: ", peer_id)
	var idx = players.size()
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.position = Vector3((idx % 4) * 2.0, 0.1, (idx / 4.0) * 2.0)
	add_child(player)
	player.set_multiplayer_authority(peer_id)
	if peer_id == multiplayer.get_unique_id():
		var camera := player.get_node("Camera3D") if player.has_node("Camera3D") else null
		if camera:
			camera.current = true
	players[peer_id] = player

func spawn_player_local(peer_id: int) -> void:
	if peer_id in players:
		return
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.position = Vector3(0, 0.1, 0)
	add_child(player)
	player.set_multiplayer_authority(peer_id)
	var camera := player.get_node("Camera3D") if player.has_node("Camera3D") else null
	if camera:
		camera.current = true
	players[peer_id] = player

func remove_player(peer_id: int) -> void:
	if peer_id in players:
		players[peer_id].queue_free()
		players.erase(peer_id)
		print("Removed player: ", peer_id)

func _on_host_pressed() -> void:
	Networking.host_lobby()

func _on_quit_pressed() -> void:
	get_tree().quit()
