extends Node3D

const PLAYER_SCENE = preload("res://scenes/players/player.tscn")
const CHARACTER_SELECT_SCENE = preload("res://scenes/menus/character_select.tscn")
const SETTINGS_SCENE = preload("res://scenes/menus/settings_menu.tscn")

var players: Dictionary = {}
var player_info: Dictionary = {}

@onready var status_label: Label = $UI/StatusLabel
@onready var leave_button: Button = $UI/LeaveButton
@onready var tab_overlay: PanelContainer = $UI/TabOverlay
@onready var player_list_vbox: VBoxContainer = $UI/TabOverlay/Margin/VBox/PlayerList
@onready var pause_menu: PanelContainer = $UI/PauseMenu
@onready var loading_overlay: ColorRect = $UI/LoadingOverlay
@onready var map_select_panel: PanelContainer = $UI/MapSelectPanel
@onready var btn_random_map: Button = $UI/MapSelectPanel/Margin/VBox/BtnRandom
@onready var btn_hotbomb_map: Button = $UI/MapSelectPanel/Margin/VBox/BtnHotBomb
@onready var btn_stablefooting_map: Button = $UI/MapSelectPanel/Margin/VBox/BtnStableFooting
@onready var campaign_box: VBoxContainer = $UI/MapSelectPanel/Margin/VBox/CampaignBox
@onready var check_campaign: CheckBox = $UI/MapSelectPanel/Margin/VBox/CampaignBox/CheckCampaign
@onready var btn_win_1: Button = $UI/MapSelectPanel/Margin/VBox/CampaignBox/WinsHBox/BtnWin1
@onready var btn_win_3: Button = $UI/MapSelectPanel/Margin/VBox/CampaignBox/WinsHBox/BtnWin3
@onready var btn_win_5: Button = $UI/MapSelectPanel/Margin/VBox/CampaignBox/WinsHBox/BtnWin5
@onready var btn_win_7: Button = $UI/MapSelectPanel/Margin/VBox/CampaignBox/WinsHBox/BtnWin7
@onready var btn_win_10: Button = $UI/MapSelectPanel/Margin/VBox/CampaignBox/WinsHBox/BtnWin10
@onready var map_info_popup: Control = $UI/MapInfoPopup
@onready var campaign_victory_popup: Control = $UI/CampaignVictoryPopup
@onready var lobby_panel: PanelContainer = $UI/LobbyPanel
@onready var btn_ready: Button = $UI/LobbyPanel/Margin/HBox/BtnReady
@onready var btn_start: Button = $UI/LobbyPanel/Margin/HBox/BtnStart
@onready var btn_copy_code: Button = $UI/LobbyPanel/Margin/HBox.get_node_or_null("BtnCopyCode")

var ping_timer: float = 0.0
var is_ready: bool = false
var selected_map: String = "Random"
var is_starting: bool = false

func _ready() -> void:
	Networking.host_created.connect(on_host_created)
	Networking.host_failed.connect(_on_host_failed)
	Networking.client_connected.connect(on_client_connected)
	Networking.avatar_updated.connect(_on_avatar_updated)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(remove_player)
	leave_button.pressed.connect(_on_leave_pressed)

	if btn_random_map:
		btn_random_map.pressed.connect(_on_map_selected.bind("Random"))
	if btn_hotbomb_map:
		btn_hotbomb_map.pressed.connect(_on_map_selected.bind("HotBomb"))
	if btn_stablefooting_map:
		btn_stablefooting_map.pressed.connect(_on_map_selected.bind("StableFooting"))
	if check_campaign:
		check_campaign.toggled.connect(_on_campaign_toggled)
	if btn_win_1:
		btn_win_1.pressed.connect(_on_win_target_pressed.bind(1))
	if btn_win_3:
		btn_win_3.pressed.connect(_on_win_target_pressed.bind(3))
	if btn_win_5:
		btn_win_5.pressed.connect(_on_win_target_pressed.bind(5))
	if btn_win_7:
		btn_win_7.pressed.connect(_on_win_target_pressed.bind(7))
	if btn_win_10:
		btn_win_10.pressed.connect(_on_win_target_pressed.bind(10))
	if campaign_victory_popup:
		campaign_victory_popup.play_again_requested.connect(_on_campaign_play_again)
		campaign_victory_popup.return_to_menu_requested.connect(_on_leave_pressed)
	if btn_ready:
		btn_ready.pressed.connect(_on_ready_pressed)
	if btn_start:
		btn_start.pressed.connect(_on_start_pressed)
	if btn_copy_code:
		btn_copy_code.pressed.connect(_on_copy_code_pressed)
	_update_ui_text()

	status_label.visible = false
	leave_button.visible = false
	tab_overlay.visible = false

	if map_select_panel:
		map_select_panel.visible = false
	if lobby_panel:
		lobby_panel.visible = false

	if loading_overlay:
		loading_overlay.visible = true
	if pause_menu:
		pause_menu.visible = false
		var btn_settings = pause_menu.get_node_or_null("Margin/VBox/BtnSettings")
		if btn_settings:
			btn_settings.pressed.connect(_on_pause_settings_pressed)
		var btn_invite = pause_menu.get_node_or_null("Margin/VBox/BtnInvite")
		if btn_invite:
			btn_invite.pressed.connect(_on_pause_invite_pressed)
		var btn_menu = pause_menu.get_node_or_null("Margin/VBox/BtnMenu")
		if btn_menu:
			btn_menu.pressed.connect(_on_pause_menu_pressed)
	set_physics_process(true)
	set_process(true)
	
	if GameSession.is_hosting:
		GameSession.is_hosting = false
		clear_all_players()
		Networking.host_lobby()
	elif multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_restore_lobby_session()
	elif multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		show_character_select()

	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(loading_overlay) and loading_overlay.visible and not $UI.has_node("CharacterSelect"):
			loading_overlay.visible = false
	)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_update_ui_text()

func _update_ui_text() -> void:
	if btn_ready:
		btn_ready.text = tr("UNREADY") if is_ready else tr("READY")
	if btn_copy_code:
		btn_copy_code.text = tr("COPY_ROOM_CODE")
	if check_campaign:
		check_campaign.text = tr("CAMPAIGN_MODE")
	if campaign_box:
		var wins_label = campaign_box.get_node_or_null("WinsHBox/WinsLabel")
		if wins_label:
			wins_label.text = tr("FIRST_TO")
	if tab_overlay and tab_overlay.visible:
		update_tab_overlay()

func _process(delta: float) -> void:
	if not is_inside_tree():
		return
	# ESC toggle pause menu
	if Input.is_action_just_pressed("ui_cancel"):
		if pause_menu:
			pause_menu.visible = not pause_menu.visible

	# TAB toggle player list
	if Input.is_action_just_pressed("ui_focus_next") or Input.is_key_pressed(KEY_TAB):
		if not tab_overlay.visible:
			tab_overlay.visible = true
			update_tab_overlay()
	elif not Input.is_key_pressed(KEY_TAB) and tab_overlay.visible:
		tab_overlay.visible = false

	if not is_starting and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		ping_timer += delta
		if ping_timer >= 1.0:
			ping_timer = 0.0
			if not multiplayer.is_server():
				request_ping.rpc_id(1, Time.get_ticks_msec())

@rpc("any_peer", "unreliable")
func sync_player_state(peer_id: int, pos: Vector3, rot_y: float, anim_name: String) -> void:
	if not is_inside_tree() or is_starting:
		return
	if not multiplayer or not multiplayer.multiplayer_peer or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var local_id := multiplayer.get_unique_id()
	if local_id == 0 or peer_id == local_id:
		return
	var player = players.get(peer_id)
	if player and is_instance_valid(player) and player.is_inside_tree():
		player._apply_state(pos, rot_y, anim_name)

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
	if not is_inside_tree():
		return
	var my_id = multiplayer.get_unique_id()
	if my_id in players and is_instance_valid(players[my_id]):
		players[my_id].apply_knockback(push_dir)

@rpc("any_peer", "unreliable")
func request_ping(client_time: int) -> void:
	if not is_inside_tree() or is_starting or not multiplayer.is_server():
		return
	var sender = multiplayer.get_remote_sender_id()
	respond_ping.rpc_id(sender, client_time)

@rpc("authority", "unreliable")
func respond_ping(client_time: int) -> void:
	if not is_inside_tree():
		return
	var rtt = Time.get_ticks_msec() - client_time
	var my_id = multiplayer.get_unique_id()
	if my_id in player_info:
		player_info[my_id].ping = rtt
	report_ping.rpc(rtt)

@rpc("any_peer", "unreliable")
func report_ping(ping_val: int) -> void:
	if not is_inside_tree():
		return
	var sender = multiplayer.get_remote_sender_id()
	if sender in player_info:
		player_info[sender].ping = ping_val
	if tab_overlay and tab_overlay.visible:
		update_tab_overlay()

func update_tab_overlay() -> void:
	for child in player_list_vbox.get_children():
		child.queue_free()

	var sorted_pids = player_info.keys()
	sorted_pids.sort_custom(func(a, b):
		return player_info[a].get("wins", 0) > player_info[b].get("wins", 0)
	)

	for idx in range(sorted_pids.size()):
		var pid = sorted_pids[idx]
		var info = player_info[pid]
		var p_name: String = info.get("name", "Player %d" % pid)
		var p_steam_id: int = info.get("steam_id", 0)
		var p_ping: int = info.get("ping", 0)
		var p_wins: int = info.get("wins", 0)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var rank_lbl := Label.new()
		rank_lbl.text = "#%d" % (idx + 1)
		rank_lbl.custom_minimum_size = Vector2(28, 0)
		rank_lbl.add_theme_font_size_override("font_size", 16)
		if idx == 0 and p_wins > 0:
			rank_lbl.modulate = Color(1.0, 0.85, 0.2)
		else:
			rank_lbl.modulate = Color(0.7, 0.7, 0.7)
		row.add_child(rank_lbl)

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

		var wins_lbl := Label.new()
		wins_lbl.text = "%d %s" % [p_wins, tr("WINS")]
		wins_lbl.custom_minimum_size = Vector2(65, 0)
		wins_lbl.add_theme_font_size_override("font_size", 14)
		wins_lbl.modulate = Color(1.0, 0.85, 0.3) if p_wins > 0 else Color(0.6, 0.6, 0.6)
		row.add_child(wins_lbl)

		var is_p_ready: bool = info.get("ready", false)
		var ready_lbl := Label.new()
		ready_lbl.text = tr("STATUS_READY") if is_p_ready else tr("STATUS_NOT_READY")
		ready_lbl.modulate = Color(0.3, 0.9, 0.3) if is_p_ready else Color(0.7, 0.7, 0.7)
		ready_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(ready_lbl)

		var ping_lbl := Label.new()
		if pid == 1:
			ping_lbl.text = tr("HOST")
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

func _on_character_confirmed(character_path: String, color: Color = Color.WHITE, face: String = "", hat: String = "") -> void:
	GameSession.selected_character = character_path
	GameSession.selected_color = color
	GameSession.selected_face = face
	GameSession.selected_hat = hat
	var char_select = $UI.get_node_or_null("CharacterSelect")
	if char_select:
		char_select.queue_free()
	if loading_overlay:
		var tween = create_tween()
		tween.tween_property(loading_overlay, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func(): loading_overlay.visible = false)

	# Show map/ready UI
	if map_select_panel:
		map_select_panel.visible = true
	if lobby_panel:
		lobby_panel.visible = true
	if btn_start and multiplayer.is_server():
		btn_start.visible = true
		btn_start.disabled = true
	if btn_copy_code and multiplayer.is_server():
		btn_copy_code.visible = true

	var my_name = Networking.get_local_player_name()
	var my_steam_id = Networking.get_local_steam_id()
	if multiplayer.is_server():
		var existing_wins: int = player_info.get(1, {}).get("wins", 0)
		player_info[1] = {
			"character": character_path,
			"name": my_name,
			"steam_id": my_steam_id,
			"color": color,
			"face": face,
			"hat": hat,
			"ping": 0,
			"ready": false,
			"wins": existing_wins
		}
		spawn_player_rpc(1, character_path, my_name, my_steam_id, color, face, hat)
		sync_ready_states.rpc({})
		_sync_all_wins_to_all()
		sync_campaign_config.rpc(GameSession.campaign_active, GameSession.wins_to_win)
	else:
		if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			register_player.rpc_id(1, character_path, my_name, my_steam_id, color, face, hat)
		else:
			print("[CLIENT] Peer not connected yet, deferring register_player until connected_to_server...")
			if not multiplayer.connected_to_server.is_connected(_on_deferred_register_player):
				multiplayer.connected_to_server.connect(_on_deferred_register_player, CONNECT_ONE_SHOT)

func _on_deferred_register_player() -> void:
	var char_path = GameSession.selected_character
	var my_name = Networking.get_local_player_name()
	var my_steam_id = Networking.get_local_steam_id()
	var col = GameSession.selected_color
	var face = GameSession.selected_face
	var hat = GameSession.selected_hat
	if char_path != "" and not multiplayer.is_server():
		print("[CLIENT] Connection established! Sending deferred register_player...")
		register_player.rpc_id(1, char_path, my_name, my_steam_id, col, face, hat)

func _restore_lobby_session() -> void:
	print("[LOBBY] Restoring lobby session after minigame...")
	if loading_overlay:
		var tween = create_tween()
		tween.tween_property(loading_overlay, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func(): loading_overlay.visible = false)

	if lobby_panel:
		lobby_panel.visible = true
	is_ready = false
	if btn_ready:
		btn_ready.text = tr("READY")
		btn_ready.modulate = Color(1, 1, 1)

	var my_name = Networking.get_local_player_name()
	var my_steam_id = Networking.get_local_steam_id()
	var char_path = GameSession.selected_character
	var col = GameSession.selected_color
	var face = GameSession.selected_face
	var hat = GameSession.selected_hat

	if multiplayer.is_server():
		if map_select_panel:
			map_select_panel.visible = true
		if btn_start:
			btn_start.visible = true
			btn_start.disabled = true
		if btn_copy_code:
			btn_copy_code.visible = true

		var host_wins: int = player_info.get(1, {}).get("wins", 0)
		player_info.clear()
		player_info[1] = {
			"character": char_path,
			"name": my_name,
			"steam_id": my_steam_id,
			"color": col,
			"face": face,
			"hat": hat,
			"ping": 0,
			"ready": false,
			"wins": host_wins
		}
		spawn_player_rpc(1, char_path, my_name, my_steam_id, col, face, hat)
		sync_ready_states.rpc({})
		call_deferred("_process_match_result")
	else:
		if map_select_panel:
			map_select_panel.visible = false
		register_player.rpc_id(1, char_path, my_name, my_steam_id, col, face, hat)

@rpc("any_peer", "reliable")
func register_player(character_path: String, player_name: String = "", steam_id: int = 0, color: Color = Color.WHITE, face: String = "res://assets/characters/face/robloxmanface.png", hat: String = "") -> void:
	if not is_inside_tree() or not multiplayer.is_server():
		return
	if face == "":
		face = "res://assets/characters/face/robloxmanface.png"
	var caller_id := multiplayer.get_remote_sender_id()
	if caller_id in players:
		remove_player(caller_id)
	var prev_wins: int = player_info.get(caller_id, {}).get("wins", 0)
	player_info[caller_id] = {
		"character": character_path,
		"name": player_name if player_name != "" else "Player %d" % caller_id,
		"steam_id": steam_id,
		"color": color,
		"face": face,
		"hat": hat,
		"ping": 0,
		"ready": false,
		"wins": prev_wins
	}
	print("[HOST] Registered player %d (%s) with %s, color=%s, hat=%s" % [caller_id, player_name, character_path, color, hat])

	# Sync existing players to new joiner
	for pid in player_info:
		if pid != caller_id:
			var info = player_info[pid]
			spawn_player_rpc.rpc_id(caller_id, pid, info.character, info.name, info.steam_id, info.get("color", Color.WHITE), info.get("face", "res://assets/characters/face/robloxmanface.png"), info.get("hat", ""))

	# Spawn new joiner for everyone (host call_local + all clients)
	spawn_player_rpc.rpc(caller_id, character_path, player_name, steam_id, color, face, hat)

	sync_ready_states.rpc(get_ready_states())
	_sync_all_wins_to_all()
	sync_campaign_config.rpc_id(caller_id, GameSession.campaign_active, GameSession.wins_to_win)

@rpc("authority", "call_local", "reliable")
func spawn_player_rpc(peer_id: int, character_path: String = "", player_name: String = "", steam_id: int = 0, color: Color = Color.WHITE, face: String = "res://assets/characters/face/robloxmanface.png", hat: String = "") -> void:
	if not is_inside_tree():
		return
	if face == "":
		face = "res://assets/characters/face/robloxmanface.png"
	print("[DEBUG %d] spawn_player_rpc called: peer=%d, char=%s, name=%s, color=%s, hat=%s" % [multiplayer.get_unique_id(), peer_id, character_path, player_name, color, hat])

	# Check if already exists with same character and customization - update only if different
	if peer_id in players and is_instance_valid(players[peer_id]):
		var existing_player = players[peer_id]
		if existing_player.character_path == character_path and existing_player.character_color == color and existing_player.character_face == face and existing_player.character_hat == hat:
			print("[DEBUG] Player %d already spawned with same customization, skipping" % peer_id)
			return
		else:
			print("[DEBUG] Player %d customization changed, re-spawning" % peer_id)
			remove_player(peer_id)

	var old_node := get_node_or_null(str(peer_id))
	if old_node:
		remove_child(old_node)
		old_node.queue_free()
	print("[DEBUG] Spawning player: %d (%s) with character: %s" % [peer_id, player_name, character_path])
	var idx = players.size()
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.position = Vector3((idx % 4) * 2.0, 0.1, (idx / 4.0) * 2.0)
	player.set_multiplayer_authority(peer_id)
	player.set_player_name(player_name)
	player.steam_id = steam_id
	player.character_path = character_path
	player.character_color = color
	player.character_face = face
	player.character_hat = hat
	add_child(player)
	player.set_character_customization(color, face, hat)
	players[peer_id] = player
	if AudioManager and peer_id != multiplayer.get_unique_id():
		AudioManager.play_player_join()
	if not (peer_id in player_info):
		player_info[peer_id] = {
			"character": character_path,
			"name": player_name if player_name != "" else "Player %d" % peer_id,
			"steam_id": steam_id,
			"color": color,
			"face": face,
			"hat": hat,
			"ping": 0,
			"ready": false,
			"wins": 0
		}
	else:
		player_info[peer_id].name = player_name
		player_info[peer_id].steam_id = steam_id
		player_info[peer_id]["color"] = color
		player_info[peer_id]["face"] = face
		player_info[peer_id]["hat"] = hat
		if not ("ready" in player_info[peer_id]):
			player_info[peer_id]["ready"] = false
		if not ("wins" in player_info[peer_id]):
			player_info[peer_id]["wins"] = 0

	# Switch character after player is fully in tree
	if character_path and character_path != player.character_path:
		await get_tree().process_frame
		if is_instance_valid(player) and player.is_inside_tree():
			player.switch_character(character_path)
			player.set_character_customization(color, face, hat)

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
	if AudioManager:
		AudioManager.play_player_leave()
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
	clear_all_players()
	show_character_select()

func _on_host_failed(err_code: int) -> void:
	if loading_overlay:
		loading_overlay.visible = false
	if status_label:
		status_label.visible = true
		status_label.text = "Failed to create Steam lobby (Error %d)" % err_code
	if leave_button:
		leave_button.visible = true
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_inside_tree() and not $UI.has_node("CharacterSelect"):
			_on_leave_pressed()
	)

func on_client_connected() -> void:
	status_label.visible = false
	clear_all_players()
	show_character_select()

func _on_connected_to_server() -> void:
	print("[CLIENT] connected_to_server fired")
	status_label.visible = false
	var char_path = GameSession.selected_character
	if char_path != "" and not multiplayer.is_server():
		var my_name = Networking.get_local_player_name()
		var my_steam_id = Networking.get_local_steam_id()
		print("[CLIENT] Auto-registering previously selected character: %s" % char_path)
		register_player.rpc_id(1, char_path, my_name, my_steam_id)
	else:
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
	set_process(false)
	set_physics_process(false)
	Networking.leave_current_session()
	clear_all_players()
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")

func _on_pause_settings_pressed() -> void:
	var settings = SETTINGS_SCENE.instantiate()
	$UI.add_child(settings)
	settings.settings_closed.connect(func(): pass)

func _on_pause_invite_pressed() -> void:
	_on_invite_pressed()
	if pause_menu:
		pause_menu.visible = false

func _on_pause_menu_pressed() -> void:
	_on_leave_pressed()

func _on_copy_code_pressed() -> void:
	var code := Networking.get_lobby_code()
	if code != "":
		DisplayServer.clipboard_set(code)
		if AudioManager:
			AudioManager.play_copy_code()
		if btn_copy_code:
			btn_copy_code.text = tr("COPIED")
			get_tree().create_timer(1.5).timeout.connect(func():
				if is_instance_valid(btn_copy_code):
					btn_copy_code.text = tr("COPY_ROOM_CODE")
			)

func _on_map_selected(map_name: String) -> void:
	selected_map = map_name
	print("[LOBBY] Selected map: ", map_name)
	if map_info_popup:
		map_info_popup.show_map_info(map_name)

func _pick_random_map() -> String:
	var maps := ["HotBomb", "StableFooting"]
	return maps[randi() % maps.size()]

func _on_campaign_toggled(enabled: bool) -> void:
	if not multiplayer.is_server():
		return
	GameSession.campaign_active = enabled
	sync_campaign_config.rpc(enabled, GameSession.wins_to_win)

func _on_win_target_pressed(target_wins: int) -> void:
	if not multiplayer.is_server():
		return
	GameSession.wins_to_win = target_wins
	sync_campaign_config.rpc(GameSession.campaign_active, target_wins)

@rpc("authority", "call_local", "reliable")
func sync_campaign_config(active: bool, wins: int) -> void:
	GameSession.campaign_active = active
	GameSession.wins_to_win = wins
	if check_campaign:
		check_campaign.set_pressed_no_signal(active)
	_update_win_buttons_style(wins)

func _update_win_buttons_style(target_wins: int) -> void:
	var win_buttons = [btn_win_1, btn_win_3, btn_win_5, btn_win_7, btn_win_10]
	var win_values = [1, 3, 5, 7, 10]
	for i in range(win_buttons.size()):
		var btn = win_buttons[i]
		if btn:
			if win_values[i] == target_wins:
				btn.modulate = Color(1.0, 0.85, 0.2)
			else:
				btn.modulate = Color(1, 1, 1)

func _sync_all_wins_to_all() -> void:
	if not multiplayer.is_server():
		return
	var wins_dict := {}
	for pid in player_info:
		wins_dict[pid] = player_info[pid].get("wins", 0)
	sync_all_wins.rpc(wins_dict)

@rpc("authority", "call_local", "reliable")
func sync_all_wins(wins_dict: Dictionary) -> void:
	if not is_inside_tree():
		return
	for pid in wins_dict:
		if pid in player_info:
			player_info[pid]["wins"] = wins_dict[pid]
	if tab_overlay and tab_overlay.visible:
		update_tab_overlay()

@rpc("authority", "call_local", "reliable")
func sync_player_wins(peer_id: int, new_wins: int) -> void:
	if not is_inside_tree():
		return
	if peer_id in player_info:
		player_info[peer_id]["wins"] = new_wins
	if tab_overlay and tab_overlay.visible:
		update_tab_overlay()

func _process_match_result() -> void:
	if not multiplayer.is_server():
		return
	var winner_id = GameSession.pending_match_winner
	GameSession.pending_match_winner = -1
	if winner_id <= 0:
		return
	print("[LOBBY] Processing match winner: ", winner_id)
	if winner_id in player_info:
		player_info[winner_id]["wins"] = player_info[winner_id].get("wins", 0) + 1
		_sync_all_wins_to_all()
		if tab_overlay and tab_overlay.visible:
			update_tab_overlay()
		if GameSession.campaign_active and player_info[winner_id]["wins"] >= GameSession.wins_to_win:
			var winner_name: String = player_info[winner_id].get("name", "Player %d" % winner_id)
			show_campaign_victory_rpc.rpc(winner_name, player_info[winner_id]["wins"])

@rpc("authority", "call_local", "reliable")
func show_campaign_victory_rpc(winner_name: String, wins_count: int) -> void:
	if not is_inside_tree():
		return
	if campaign_victory_popup:
		campaign_victory_popup.show_victory(winner_name, wins_count, multiplayer.is_server())

func _on_campaign_play_again() -> void:
	if not multiplayer.is_server():
		return
	for pid in player_info:
		player_info[pid]["wins"] = 0
	reset_campaign_wins_rpc.rpc()

@rpc("authority", "call_local", "reliable")
func reset_campaign_wins_rpc() -> void:
	if not is_inside_tree():
		return
	for pid in player_info:
		player_info[pid]["wins"] = 0
	if campaign_victory_popup:
		campaign_victory_popup.visible = false
	if tab_overlay and tab_overlay.visible:
		update_tab_overlay()

func _on_ready_pressed() -> void:
	is_ready = not is_ready
	if AudioManager:
		AudioManager.play_player_ready(is_ready)
	if btn_ready:
		btn_ready.text = tr("UNREADY") if is_ready else tr("READY")
		btn_ready.modulate = Color(0.3, 0.9, 0.3) if is_ready else Color(1, 1, 1)
	if multiplayer.is_server():
		player_info[1]["ready"] = is_ready
		sync_ready_states.rpc(get_ready_states())
		update_start_button()
		if tab_overlay.visible:
			update_tab_overlay()
	else:
		set_ready_state.rpc_id(1, is_ready)

@rpc("any_peer", "reliable")
func set_ready_state(p_ready: bool) -> void:
	if not is_inside_tree() or not multiplayer.is_server():
		return
	var sender = multiplayer.get_remote_sender_id()
	if sender in player_info:
		player_info[sender]["ready"] = p_ready
	sync_ready_states.rpc(get_ready_states())
	update_start_button()
	if tab_overlay and tab_overlay.visible:
		update_tab_overlay()

@rpc("authority", "call_local", "reliable")
func sync_ready_states(states: Dictionary) -> void:
	if not is_inside_tree():
		return
	for pid in states:
		if pid in player_info:
			player_info[pid]["ready"] = states[pid]
	if tab_overlay and tab_overlay.visible:
		update_tab_overlay()

func get_ready_states() -> Dictionary:
	var states = {}
	for pid in player_info:
		states[pid] = player_info[pid].get("ready", false)
	return states

func update_start_button() -> void:
	if not multiplayer.is_server() or not btn_start:
		return
	var all_ready = true
	var count = player_info.size()
	if count < 1:
		all_ready = false
	for pid in player_info:
		if not player_info[pid].get("ready", false):
			all_ready = false
			break
	btn_start.disabled = not all_ready

func _on_start_pressed() -> void:
	if not multiplayer.is_server():
		return
	start_game(selected_map)

func start_game(map_name: String) -> void:
	if is_starting:
		return
	var actual_map = map_name
	if actual_map == "Random":
		actual_map = _pick_random_map()
	is_starting = true
	print("[GAME] Starting match on map: ", actual_map)
	if AudioManager:
		AudioManager.play_match_start()
	set_process(false)
	set_physics_process(false)
	for pid in players:
		var p = players[pid]
		if is_instance_valid(p):
			p.set_physics_process(false)

	if multiplayer.is_server():
		prepare_start_game_rpc.rpc()
		await get_tree().create_timer(0.1).timeout
		if not is_inside_tree():
			return
		start_game_rpc.rpc(actual_map)

	_change_to_minigame(actual_map)

func _change_to_minigame(map_name: String) -> void:
	if not is_inside_tree():
		return
	if map_name == "HotBomb":
		GameSession.minigame_players = player_info.duplicate(true)
		get_tree().change_scene_to_file("res://scenes/minigames/hot_bomb/hot_bomb.tscn")
	elif map_name == "StableFooting":
		GameSession.minigame_players = player_info.duplicate(true)
		get_tree().change_scene_to_file("res://scenes/minigames/stable_footing/stable_footing.tscn")
	else:
		print("[GAME] Map %s is lobby, nothing to start" % map_name)

@rpc("authority", "call_remote", "reliable")
func prepare_start_game_rpc() -> void:
	is_starting = true
	set_process(false)
	set_physics_process(false)
	for pid in players:
		var p = players[pid]
		if is_instance_valid(p):
			p.set_physics_process(false)

@rpc("authority", "call_remote", "reliable")
func start_game_rpc(map_name: String) -> void:
	_change_to_minigame(map_name)
