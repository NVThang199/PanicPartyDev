extends CanvasLayer

const SETTINGS_SCENE = preload("res://scenes/menus/settings_menu.tscn")

@onready var pause_menu: PanelContainer = $PauseMenu
@onready var tab_overlay: PanelContainer = $TabOverlay
@onready var player_list_vbox: VBoxContainer = $TabOverlay/Margin/VBox/PlayerList
@onready var btn_settings: Button = $PauseMenu/Margin/VBox/BtnSettings
@onready var btn_invite: Button = $PauseMenu/Margin/VBox/BtnInvite
@onready var btn_menu: Button = $PauseMenu/Margin/VBox/BtnMenu

func _ready() -> void:
	layer = 5
	if pause_menu:
		pause_menu.visible = false
	if tab_overlay:
		tab_overlay.visible = false

	if btn_settings:
		btn_settings.pressed.connect(_on_pause_settings_pressed)
	if btn_invite:
		btn_invite.pressed.connect(_on_pause_invite_pressed)
	if btn_menu:
		btn_menu.pressed.connect(_on_pause_menu_pressed)

	Networking.avatar_updated.connect(_on_avatar_updated)
	if multiplayer:
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _exit_tree() -> void:
	if Networking.avatar_updated.is_connected(_on_avatar_updated):
		Networking.avatar_updated.disconnect(_on_avatar_updated)
	if multiplayer and multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		if tab_overlay and tab_overlay.visible:
			update_tab_overlay()

func _unhandled_input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		if pause_menu:
			pause_menu.visible = not pause_menu.visible
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not is_inside_tree():
		return

	# TAB toggle / hold player list
	if Input.is_action_just_pressed("ui_focus_next") or Input.is_key_pressed(KEY_TAB):
		if not tab_overlay.visible:
			tab_overlay.visible = true
			update_tab_overlay()
	elif not Input.is_key_pressed(KEY_TAB) and tab_overlay.visible:
		tab_overlay.visible = false

func _on_pause_settings_pressed() -> void:
	var settings = SETTINGS_SCENE.instantiate()
	add_child(settings)
	settings.settings_closed.connect(func(): pass)

func _on_pause_invite_pressed() -> void:
	Networking.open_invite_overlay()
	if pause_menu:
		pause_menu.visible = false

func _on_pause_menu_pressed() -> void:
	var root = owner if owner != null else get_parent()
	if root:
		root.set_process(false)
		root.set_physics_process(false)
	Networking.leave_current_session()
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")

func _on_avatar_updated(_steam_id: int, _tex: Texture2D) -> void:
	if tab_overlay and tab_overlay.visible:
		update_tab_overlay()

func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id in GameSession.minigame_players:
		GameSession.minigame_players.erase(peer_id)
	if tab_overlay and tab_overlay.visible:
		update_tab_overlay()

func update_tab_overlay() -> void:
	if not player_list_vbox:
		return
	for child in player_list_vbox.get_children():
		child.queue_free()

	var players_data = GameSession.minigame_players
	var sorted_pids = players_data.keys()
	sorted_pids.sort_custom(func(a, b):
		return players_data[a].get("wins", 0) > players_data[b].get("wins", 0)
	)

	var root = owner if owner != null else get_parent()
	var p_states: Dictionary = {}
	if root and "player_states" in root:
		p_states = root.player_states

	for idx in range(sorted_pids.size()):
		var pid = sorted_pids[idx]
		var info = players_data[pid]
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
		if multiplayer and pid == multiplayer.get_unique_id():
			name_lbl.modulate = Color(0.4, 0.9, 1.0)
		row.add_child(name_lbl)

		var wins_lbl := Label.new()
		wins_lbl.text = "%d %s" % [p_wins, tr("WINS")]
		wins_lbl.custom_minimum_size = Vector2(65, 0)
		wins_lbl.add_theme_font_size_override("font_size", 14)
		wins_lbl.modulate = Color(1.0, 0.85, 0.3) if p_wins > 0 else Color(0.6, 0.6, 0.6)
		row.add_child(wins_lbl)

		var status_lbl := Label.new()
		status_lbl.add_theme_font_size_override("font_size", 14)
		if not p_states.is_empty():
			var is_alive: bool = p_states.get(pid, {}).get("alive", true)
			status_lbl.text = tr("STATUS_ALIVE") if is_alive else tr("STATUS_ELIMINATED")
			status_lbl.modulate = Color(0.3, 0.9, 0.3) if is_alive else Color(0.9, 0.3, 0.3)
		else:
			var is_p_ready: bool = info.get("ready", false)
			status_lbl.text = tr("STATUS_READY") if is_p_ready else tr("STATUS_NOT_READY")
			status_lbl.modulate = Color(0.3, 0.9, 0.3) if is_p_ready else Color(0.7, 0.7, 0.7)
		row.add_child(status_lbl)

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
