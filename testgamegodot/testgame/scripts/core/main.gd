extends Node3D

const PLAYER_SCENE = preload("res://scenes/players/player.tscn")
const CHARACTER_SELECT_SCENE = preload("res://scenes/menus/character_select.tscn")

var players: Dictionary = {}
var player_info: Dictionary = {}

@onready var status_label: Label = $UI/StatusLabel
@onready var invite_button: Button = $UI/InviteButton
@onready var leave_button: Button = $UI/LeaveButton
@onready var tab_overlay: PanelContainer = $UI/TabOverlay
@onready var player_list_vbox: VBoxContainer = $UI/TabOverlay/Margin/VBox/PlayerList

var ping_timer: float = 0.0

func _ready() -> void:
	Networking.host_created.connect(on_host_created)
	Networking.client_connected.connect(on_client_connected)
	Networking.avatar_updated.connect(_on_avatar_updated)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(remove_player)
	invite_button.pressed.connect(_on_invite_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	
	status_label.visible = false
	invite_button.visible = false
	tab_overlay.visible = false
	set_physics_process(true)
	set_process(true)
	
	if GameSession.is_hosting:
		GameSession.is_hosting = false
		clear_all_players()
		Networking.host_lobby()
	elif multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		invite_button.visible = false
		show_character_select()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_focus_next") or Input.is_key_pressed(KEY_TAB):
		if not tab_overlay.visible:
			tab_overlay.visible = true
			update_tab_overlay()
	elif not Input.is_key_pressed(KEY_TAB) and tab_overlay.visible:
		tab_overlay.visible = false

	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		ping_timer += delta
		if ping_timer >= 1.0:
			ping_timer = 0.0
			if not multiplayer.is_server():
				request_ping.rpc_id(1, Time.get_ticks_msec())

@rpc("any_peer", "unreliable")
func sync_player_state(peer_id: int, pos: Vector3, rot_y: float, anim_name: String) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	if peer_id in players and is_instance_valid(players[peer_id]):
		players[peer_id]._apply_state(pos, rot_y, anim_name)

@rpc("any_peer", "reliable")
func request_push(target_peer_id: int, push_dir: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var sender_player = players.get(sender_id)
	var target_player = players.get(target_peer_id)
	if not sender_player or not target_player:
		print("[PUSH] Cannot find sender %d or target %d" % [sender_id, target_peer_id])
		return
	var dist = sender_player.global_position.distance_to(target_player.global_position)
	if dist > 2.2 + 1.5:
		print("[PUSH] Distance check failed: dist=%.2f > %.2f" % [dist, 2.2 + 1.5])
		return
	print("[PUSH] Server applying push from %d to %d" % [sender_id, target_peer_id])
	if target_peer_id == multiplayer.get_unique_id():
		target_player.apply_knockback(push_dir)
	else:
		apply_knockback_rpc.rpc_id(target_peer_id, push_dir)

@rpc("authority", "reliable")
func apply_knockback_rpc(push_dir: Vector3) -> void:
	var my_id = multiplayer.get_unique_id()
	if my_id in players and is_instance_valid(players[my_id]):
		players[my_id].apply_knockback(push_dir)

@rpc("any_peer", "unreliable")
func request_ping(client_time: int) -> void:
	if not multiplayer.is_server():
		return
	var sender = multiplayer.get_remote_sender_id()
	respond_ping.rpc_id(sender, client_time)

@rpc("authority", "unreliable")
func respond_ping(client_time: int) -> void:
	var rtt = Time.get_ticks_msec() - client_time
	var my_id = multiplayer.get_unique_id()
	if my_id in player_info:
		player_info[my_id].ping = rtt
	report_ping.rpc(rtt)

@rpc("any_peer", "unreliable")
func report_ping(ping_val: int) -> void:
	var sender = multiplayer.get_remote_sender_id()
	if sender in player_info:
		player_info[sender].ping = ping_val
	if tab_overlay.visible:
		update_tab_overlay()

func update_tab_overlay() -> void:
	for child in player_list_vbox.get_children():
		child.queue_free()
	
	for pid in player_info:
		var info = player_info[pid]
		var p_name: String = info.get("name", "Player %d" % pid)
		var p_steam_id: int = info.get("steam_id", 0)
		var p_ping: int = info.get("ping", 0)
		
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		
		var avatar_rect := TextureRect.new()
		avatar_rect.custom_minimum_size = Vector2(36, 36)
		avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var tex = Networking.get_avatar_texture(p_steam_id)
		if tex:
			avatar_rect.texture = tex
		else:
			avatar_rect.texture = _create_placeholder_avatar(p_name)
		row.add_child(avatar_rect)
		
		var name_lbl := Label.new()
		name_lbl.text = p_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 16)
		if pid == 1:
			name_lbl.text += " [HOST]"
		if pid == multiplayer.get_unique_id():
			name_lbl.modulate = Color(0.4, 0.9, 1.0)
		row.add_child(name_lbl)
		
		var ping_lbl := Label.new()
		if pid == 1:
			ping_lbl.text = "HOST"
			ping_lbl.modulate = Color(1.0, 0.8, 0.2)
		else:
			ping_lbl.text = "%d ms" % p_ping
			if p_ping < 60:
				ping_lbl.modulate = Color(0.3, 0.9, 0.3)
			elif p_ping < 120:
				ping_lbl.modulate = Color(0.9, 0.8, 0.2)
			else:
				ping_lbl.modulate = Color(0.9, 0.3, 0.3)
		row.add_child(ping_lbl)
		
		player_list_vbox.add_child(row)

func _create_placeholder_avatar(display_name: String) -> ImageTexture:
	var img := Image.create(36, 36, false, Image.FORMAT_RGBA8)
	var hue = (display_name.hash() % 360) / 360.0
	var col = Color.from_hsv(hue, 0.6, 0.5)
	img.fill(col)
	return ImageTexture.create_from_image(img)

func _on_avatar_updated(_steam_id: int, _tex: Texture2D) -> void:
	if tab_overlay.visible:
		update_tab_overlay()

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
	var my_name = Networking.get_local_player_name()
	var my_steam_id = Networking.get_local_steam_id()
	if multiplayer.is_server():
		player_info[1] = {
			"character": character_path,
			"name": my_name,
			"steam_id": my_steam_id,
			"ping": 0
		}
		spawn_player_rpc.rpc(1, character_path, my_name, my_steam_id)
	else:
		register_player.rpc_id(1, character_path, my_name, my_steam_id)

@rpc("any_peer", "reliable")
func register_player(character_path: String, player_name: String = "", steam_id: int = 0) -> void:
	if not multiplayer.is_server():
		return
	var caller_id := multiplayer.get_remote_sender_id()
	if caller_id in players:
		remove_player(caller_id)
	player_info[caller_id] = {
		"character": character_path,
		"name": player_name if player_name != "" else "Player %d" % caller_id,
		"steam_id": steam_id,
		"ping": 0
	}
	print("[HOST] Registered player %d (%s) with %s" % [caller_id, player_name, character_path])
	
	for pid in player_info:
		if pid != caller_id:
			var info = player_info[pid]
			spawn_player_rpc.rpc_id(caller_id, pid, info.character, info.name, info.steam_id)
	
	spawn_player_rpc.rpc(caller_id, character_path, player_name, steam_id)

@rpc("authority", "call_local", "reliable")
func spawn_player_rpc(peer_id: int, character_path: String = "", player_name: String = "", steam_id: int = 0) -> void:
	if peer_id in players and is_instance_valid(players[peer_id]):
		print("[DEBUG] Player %d already spawned, skipping" % peer_id)
		return
	var old_node := get_node_or_null(str(peer_id))
	if old_node:
		remove_child(old_node)
		old_node.queue_free()
	print("[DEBUG] Spawning player: %d (%s) with character: %s" % [peer_id, player_name, character_path])
	var idx = players.size()
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.position = Vector3((idx % 4) * 2.0, 0.1, (idx / 4.0) * 2.0)
	add_child(player)
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	player.set_player_name(player_name)
	player.steam_id = steam_id
	if character_path:
		player.switch_character(character_path)
	players[peer_id] = player
	if not (peer_id in player_info):
		player_info[peer_id] = {
			"character": character_path,
			"name": player_name if player_name != "" else "Player %d" % peer_id,
			"steam_id": steam_id,
			"ping": 0
		}
	else:
		player_info[peer_id].name = player_name
		player_info[peer_id].steam_id = steam_id
	if tab_overlay.visible:
		update_tab_overlay()

func clear_all_players() -> void:
	for pid in players:
		var p: Node = players[pid]
		if is_instance_valid(p):
			if p.get_parent():
				p.get_parent().remove_child(p)
			p.queue_free()
	players.clear()
	player_info.clear()
	for child in get_children():
		if child is CharacterBody3D and child.name != "Floor":
			remove_child(child)
			child.queue_free()
	if tab_overlay and tab_overlay.visible:
		update_tab_overlay()

func remove_player(peer_id: int) -> void:
	player_info.erase(peer_id)
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
	if tab_overlay and tab_overlay.visible:
		update_tab_overlay()

func on_host_created() -> void:
	status_label.visible = false
	invite_button.visible = true
	clear_all_players()
	show_character_select()

func on_client_connected() -> void:
	status_label.visible = false
	invite_button.visible = false
	clear_all_players()
	show_character_select()

func _on_connected_to_server() -> void:
	print("[CLIENT] connected_to_server fired")
	status_label.visible = false
	invite_button.visible = false
	show_character_select()

func _on_server_disconnected() -> void:
	print("[CLIENT] server_disconnected, cleaning up players")
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
