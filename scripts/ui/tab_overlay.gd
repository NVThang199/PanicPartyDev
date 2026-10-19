class_name TabOverlay
extends PanelContainer

@onready var player_list_vbox: VBoxContainer = get_node_or_null("Margin/VBox/PlayerList")

func _ready() -> void:
	visible = false
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
		if is_node_ready() and visible:
			refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	if event.is_action_pressed("ui_focus_next") or (event is InputEventKey and event.keycode == KEY_TAB and event.pressed):
		if not visible:
			visible = true
			refresh()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.keycode == KEY_TAB and not event.pressed:
		if visible:
			visible = false
			get_viewport().set_input_as_handled()

func _on_avatar_updated(_steam_id: int, _tex: Texture2D) -> void:
	if visible:
		refresh()

func _on_peer_disconnected(_peer_id: int) -> void:
	if visible:
		refresh()

func refresh() -> void:
	if not player_list_vbox:
		player_list_vbox = get_node_or_null("Margin/VBox/PlayerList")
	if not player_list_vbox:
		return

	for child in player_list_vbox.get_children():
		child.queue_free()

	var current_node: Node = self
	var scene_root: Node = null
	while current_node != null:
		if "player_info" in current_node or "player_states" in current_node:
			scene_root = current_node
			break
		current_node = current_node.get_parent()

	var in_lobby: bool = (scene_root != null and "player_info" in scene_root)
	var players_data: Dictionary = {}
	var p_states: Dictionary = {}

	if in_lobby:
		players_data = scene_root.player_info
	else:
		players_data = GameSession.minigame_players
		if scene_root and "player_states" in scene_root:
			p_states = scene_root.player_states

	var sorted_pids = players_data.keys()
	var is_campaign: bool = GameSession.campaign_active

	if is_campaign and not in_lobby:
		sorted_pids.sort_custom(func(a, b):
			var score_a = GameSession.player_scores.get(a, 0)
			var score_b = GameSession.player_scores.get(b, 0)
			if score_a != score_b:
				return score_a > score_b
			return players_data[a].get("wins", 0) > players_data[b].get("wins", 0)
		)
	else:
		sorted_pids.sort_custom(func(a, b):
			return players_data[a].get("wins", 0) > players_data[b].get("wins", 0)
		)

	for idx in range(sorted_pids.size()):
		var pid = sorted_pids[idx]
		var info = players_data[pid]
		var p_name: String = info.get("name", "Player %d" % pid)
		var p_steam_id: int = info.get("steam_id", 0)
		var p_ping: int = info.get("ping", 0)
		var p_wins: int = info.get("wins", 0)
		var p_score: int = GameSession.player_scores.get(pid, 0) if not in_lobby else 0

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var rank_lbl := Label.new()
		rank_lbl.text = "#%d" % (idx + 1)
		rank_lbl.custom_minimum_size = Vector2(28, 0)
		rank_lbl.add_theme_font_size_override("font_size", 16)
		var has_lead = (p_score > 0) if (is_campaign and not in_lobby) else (p_wins > 0)
		if idx == 0 and has_lead:
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

		var score_lbl := Label.new()
		if is_campaign and not in_lobby:
			if GameSession.target_score > 0:
				score_lbl.text = "%d / %d pts" % [p_score, GameSession.target_score]
			else:
				score_lbl.text = "%d pts" % p_score
			score_lbl.custom_minimum_size = Vector2(95, 0)
			score_lbl.add_theme_font_size_override("font_size", 14)
			score_lbl.modulate = Color(1.0, 0.85, 0.3) if p_score >= GameSession.target_score else (Color(1.0, 0.85, 0.3) if p_score > 0 else Color(0.6, 0.6, 0.6))
		elif is_campaign and in_lobby:
			score_lbl.text = "0 / %d pts" % GameSession.target_score
			score_lbl.custom_minimum_size = Vector2(95, 0)
			score_lbl.add_theme_font_size_override("font_size", 14)
			score_lbl.modulate = Color(0.6, 0.6, 0.6)
		else:
			score_lbl.text = "%d %s" % [p_wins, tr("WINS")]
			score_lbl.custom_minimum_size = Vector2(65, 0)
			score_lbl.add_theme_font_size_override("font_size", 14)
			score_lbl.modulate = Color(1.0, 0.85, 0.3) if p_wins > 0 else Color(0.6, 0.6, 0.6)
		row.add_child(score_lbl)

		var status_lbl := Label.new()
		status_lbl.add_theme_font_size_override("font_size", 14)
		if not p_states.is_empty():
			if pid in p_states:
				var is_alive: bool = p_states.get(pid, {}).get("alive", true)
				status_lbl.text = tr("STATUS_ALIVE") if is_alive else tr("STATUS_ELIMINATED")
				status_lbl.modulate = Color(0.3, 0.9, 0.3) if is_alive else Color(0.9, 0.3, 0.3)
			else:
				status_lbl.text = tr("STATUS_SPECTATING")
				status_lbl.modulate = Color(0.7, 0.7, 0.9)
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
