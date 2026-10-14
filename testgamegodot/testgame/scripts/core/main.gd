extends Node3D

const PLAYER_SCENE = preload("res://scenes/players/player.tscn")

var players: Dictionary = {}

func _ready() -> void:
	if !has_node("UI"):
		printerr("UI node not found in scene tree")
		return
	var ui = get_node("UI")
	if !ui.has_node("HostButton"):
		printerr("HostButton not found in UI")
		return
	Networking.host_created.connect(on_host_created)
	Networking.client_connected.connect(on_client_connected)
	multiplayer.peer_connected.connect(spawn_player)
	multiplayer.peer_disconnected.connect(remove_player)
	$UI/HostButton.pressed.connect(_on_host_pressed)
	$UI/QuitButton.pressed.connect(_on_quit_pressed)

func _process(delta):
	if Input.is_action_pressed("ui_right"):
		position.x += 100 * delta
	if Input.is_action_pressed("ui_left"):
		position.x -= 100 * delta

func on_host_created() -> void:
	print("Host created. My unique ID: ", multiplayer.get_unique_id())
	$UI/StatusLabel.text = "Hosting - ID: %d" % multiplayer.get_unique_id()
	spawn_player(multiplayer.get_unique_id())

func on_client_connected() -> void:
	print("Connected to host. My unique ID: ", multiplayer.get_unique_id())
	$UI/StatusLabel.text = "Connected - ID: %d" % multiplayer.get_unique_id()

func spawn_player(peer_id: int) -> void:
	if peer_id in players:
		return
	print("Spawning player for peer: ", peer_id)
	var player = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	add_child(player, true)
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
