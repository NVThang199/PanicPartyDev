extends Node3D

const PLAYER_SCENE = preload("res://scenes/players/player.tscn")
const CHARACTER_SELECT_SCENE = preload("res://scenes/menus/character_select.tscn")

var players: Dictionary = {}
var player_characters: Dictionary = {}

@onready var status_label: Label = $UI/StatusLabel
@onready var invite_button: Button = $UI/InviteButton
@onready var leave_button: Button = $UI/LeaveButton

func _ready() -> void:
	Networking.host_created.connect(on_host_created)
	Networking.client_connected.connect(on_client_connected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(remove_player)
	invite_button.pressed.connect(_on_invite_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	
	invite_button.visible = false
	set_physics_process(true)
	
	if GameSession.is_hosting:
		GameSession.is_hosting = false
		clear_all_players()
		Networking.host_lobby()
	elif multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		status_label.text = "Connected - ID: %d" % multiplayer.get_unique_id()
		invite_button.visible = false
		show_character_select()

func show_character_select() -> void:
	if $UI.has_node("CharacterSelect"):
		return
	var char_select = CHARACTER_SELECT_SCENE.instantiate()
	char_select.name = "CharacterSelect"
	$UI.add_child(char_select)
	char_select.character_confirmed.connect(_on_character_confirmed)
	char_select.selection_cancelled.connect(_on_leave_pressed)

func _on_character_confirmed(character_path: String) -> void:
	GameSession.selected_character = character_path
	var char_select = $UI.get_node_or_null("CharacterSelect")
	if char_select:
		char_select.queue_free()
	if multiplayer.is_server():
		player_characters[1] = character_path
		spawn_player_rpc.rpc(1, character_path)
	else:
		register_player.rpc_id(1, character_path)

@rpc("any_peer", "reliable")
func register_player(character_path: String) -> void:
	if not multiplayer.is_server():
		return
	var caller_id := multiplayer.get_remote_sender_id()
	if caller_id in players:
		remove_player(caller_id)
	player_characters[caller_id] = character_path
	print("[HOST] Registered player %d with %s" % [caller_id, character_path])
	
	for pid in player_characters:
		if pid != caller_id:
			spawn_player_rpc.rpc_id(caller_id, pid, player_characters[pid])
	
	spawn_player_rpc.rpc(caller_id, character_path)

@rpc("authority", "call_local", "reliable")
func spawn_player_rpc(peer_id: int, character_path: String = "") -> void:
	if peer_id in players and is_instance_valid(players[peer_id]):
		print("[DEBUG] Player %d already spawned, skipping" % peer_id)
		return
	var old_node := get_node_or_null(str(peer_id))
	if old_node:
		remove_child(old_node)
		old_node.queue_free()
	print("[DEBUG] Spawning player: %d with character: %s (I am peer %d)" % [peer_id, character_path, multiplayer.get_unique_id()])
	var idx = players.size()
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.position = Vector3((idx % 4) * 2.0, 0.1, (idx / 4.0) * 2.0)
	add_child(player)
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	if character_path:
		player.switch_character(character_path)
	players[peer_id] = player

func clear_all_players() -> void:
	for pid in players:
		var p: Node = players[pid]
		if is_instance_valid(p):
			if p.get_parent():
				p.get_parent().remove_child(p)
			p.queue_free()
	players.clear()
	player_characters.clear()
	for child in get_children():
		if child is CharacterBody3D and child.name != "Floor":
			remove_child(child)
			child.queue_free()

func remove_player(peer_id: int) -> void:
	player_characters.erase(peer_id)
	if peer_id in players:
		var p: Node = players[peer_id]
		if is_instance_valid(p):
			if p.get_parent():
				p.get_parent().remove_child(p)
			p.queue_free()
		players.erase(peer_id)
		print("Removed player: ", peer_id)
	var node := get_node_or_null(str(peer_id))
	if node:
		remove_child(node)
		node.queue_free()

func on_host_created() -> void:
	status_label.text = "Hosting - ID: %d" % multiplayer.get_unique_id()
	invite_button.visible = true
	clear_all_players()
	show_character_select()

func on_client_connected() -> void:
	status_label.text = "Connected - ID: %d" % multiplayer.get_unique_id()
	invite_button.visible = false
	clear_all_players()
	show_character_select()

func _on_connected_to_server() -> void:
	print("[CLIENT] connected_to_server fired")
	status_label.text = "Connected - ID: %d" % multiplayer.get_unique_id()
	invite_button.visible = false
	show_character_select()

func _on_server_disconnected() -> void:
	print("[CLIENT] server_disconnected, cleaning up players")
	status_label.text = "Server disconnected"
	clear_all_players()

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	print("Peer connected: ", peer_id)

func _on_invite_pressed() -> void:
	if not multiplayer.is_server():
		return
	if Networking.current_lobby_id != 0:
		Steam.activateGameOverlayInviteDialog(Networking.current_lobby_id)
	else:
		print("[STEAM] No active lobby to invite")

func _on_leave_pressed() -> void:
	Networking.leave_current_session()
	clear_all_players()
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
