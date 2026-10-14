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

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	# Host spawns new peer on all clients
	spawn_player_rpc.rpc(peer_id)

@rpc("authority", "call_local", "reliable")
func spawn_player_rpc(peer_id: int) -> void:
	if peer_id in players:
		return
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.position = Vector3((players.size() % 4) * 2.0, 0.1, (players.size() / 4) * 2.0)
	add_child(player)
	players[peer_id] = player

func spawn_player_local(peer_id: int) -> void:
	if peer_id in players:
		return
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.position = Vector3((players.size() % 4) * 2.0, 0.1, (players.size() / 4) * 2.0)
	add_child(player)
	players[peer_id] = player

func remove_player(peer_id: int) -> void:
	if peer_id in players:
		players[peer_id].queue_free()
		players.erase(peer_id)

func _on_host_pressed() -> void:
	Networking.host_lobby()

func _on_quit_pressed() -> void:
	get_tree().quit()
