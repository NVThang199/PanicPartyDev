extends Node3D

const PLAYER_SCENE = preload("res://scenes/players/player.tscn")

var players: Dictionary = {}
var player_characters: Dictionary = {}

func _ready() -> void:
	Networking.host_created.connect(on_host_created)
	Networking.client_connected.connect(on_client_connected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(remove_player)
	$UI/HostButton.pressed.connect(_on_host_pressed)
	$UI/QuitButton.pressed.connect(_on_quit_pressed)
	
	set_physics_process(true)

@rpc("any_peer", "reliable")
func register_player(character_path: String) -> void:
	if not multiplayer.is_server():
		return
	var caller_id := multiplayer.get_remote_sender_id()
	if caller_id in player_characters:
		return
	player_characters[caller_id] = character_path
	print("[HOST] Registered player %d with %s" % [caller_id, character_path])
	
	for pid in player_characters:
		if pid != caller_id:
			spawn_player_rpc.rpc_id(caller_id, pid, player_characters[pid])
	
	spawn_player_rpc.rpc(caller_id, character_path)

@rpc("authority", "call_local", "reliable")
func spawn_player_rpc(peer_id: int, character_path: String = "") -> void:
	if peer_id in players:
		print("[DEBUG] Player %d already spawned, skipping" % peer_id)
		return
	print("[DEBUG] Spawning player: %d with character: %s (I am peer %d)" % [peer_id, character_path, multiplayer.get_unique_id()])
	var idx = players.size()
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.position = Vector3((idx % 4) * 2.0, 0.1, (idx / 4.0) * 2.0)
	add_child(player)
	player.set_multiplayer_authority(peer_id)
	if character_path:
		player.switch_character(character_path)
	if peer_id == multiplayer.get_unique_id():
		var camera := player.get_node("Camera3D") if player.has_node("Camera3D") else null
		if camera:
			camera.current = true
	players[peer_id] = player

func remove_player(peer_id: int) -> void:
	player_characters.erase(peer_id)
	if peer_id in players:
		players[peer_id].queue_free()
		players.erase(peer_id)
		print("Removed player: ", peer_id)

func on_host_created() -> void:
	$UI/StatusLabel.text = "Hosting - ID: %d" % multiplayer.get_unique_id()
	player_characters[1] = GameSession.selected_character
	spawn_player_rpc(1, GameSession.selected_character)

func on_client_connected() -> void:
	$UI/StatusLabel.text = "Connected - ID: %d" % multiplayer.get_unique_id()
	print("[CLIENT] Connected as peer %d, registering..." % multiplayer.get_unique_id())

func _on_connected_to_server() -> void:
	print("[CLIENT] connected_to_server fired, sending character")
	register_player.rpc_id(1, GameSession.selected_character)

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		if peer_id == 1:
			register_player.rpc_id(1, GameSession.selected_character)
		return
	print("Peer connected: ", peer_id)

func _on_host_pressed() -> void:
	Networking.host_lobby()

func _on_quit_pressed() -> void:
	get_tree().quit()
