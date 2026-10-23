class_name BaseMinigame
extends Node3D

## BaseMinigame Framework
## Encapsulates shared server-authoritative multiplayer networking,
## late-join handshake, two-phase scene transitions, player lifecycle,
## push/knockback validation, match timers, tutorial overlay,
## elimination-order scoring, and round scoreboard across minigames.
##
## [NETWORKING ARCHITECTURE CONTRACT]
## 1. TUYỆT ĐỐI KHÔNG dùng .rpc(...) broadcast toàn mạng Steam.
##    RPC broadcast sẽ gửi đến mọi peer kể cả peer còn ở MainMenu/Main3D làm sinh lỗi:
##    "Node not found: <SceneName>" và "Failed to get path from RPC".
## 2. Server chỉ gửi RPC cho peer đã xác nhận load xong scene (nằm trong `synced_peers`).
##    Cú pháp chuẩn khi Server phát trạng thái:
##        for pid in synced_peers:
##            if pid != 1:
##                my_rpc.rpc_id(pid, arg1, ...)
## 3. Client chủ động pull dữ liệu khi _ready(): `request_game_sync.rpc_id(1)`.
##    Khi Server nhận sẽ thêm caller vào `synced_peers` và gửi snapshot qua `rpc_id(caller_id, ...)`.
## 4. Minigame con ghi đè `_on_sync_custom_entities(caller_id)` để gửi dữ liệu entity đặc thù.

enum GameState { INITIALIZING, TUTORIAL, PLAYING, ENDED }

const PLAYER_SCENE = preload("res://scenes/players/player.tscn")
const CHARACTER_SELECT_SCENE = preload("res://scenes/menus/character_select.tscn")
const DEFAULT_MATCH_DURATION = 60.0
const TUTORIAL_DURATION = 5.0

var state: GameState = GameState.INITIALIZING
var players: Dictionary = {}  # peer_id -> player node
var player_states: Dictionary = {}  # peer_id -> {alive: bool, death_timer: float, name: String}
var match_timer: float = DEFAULT_MATCH_DURATION
var is_returning: bool = false
var synced_peers: Dictionary = {1: true}

# Tutorial Phase
var tutorial_timer: float = TUTORIAL_DURATION
var _last_tutorial_countdown_sec: int = -1
var tutorial_overlay: PanelContainer = null
var tutorial_title_label: Label = null
var tutorial_image_rect: TextureRect = null
var tutorial_rules_label: Label = null
var tutorial_controls_label: Label = null
var tutorial_countdown_label: Label = null

# Elimination Scoring & Round Scoreboard
var elimination_order: Array[int] = []
var round_scoreboard_overlay: PanelContainer = null
var round_scoreboard_title: Label = null
var round_scoreboard_list: VBoxContainer = null
var round_scoreboard_status: Label = null
var round_scoreboard_return_btn: Button = null
var next_round_timer: float = 6.0
var is_switching_round: bool = false

var match_timer_label: Label = null
var winner_banner: PanelContainer = null
var winner_label: Label = null
var return_button: Button = null
var spectator_overlay: PanelContainer = null
var spectator_label: Label = null
var spectator_change_btn: Button = null


func _ready() -> void:
	_init_base_ui()
	_create_tutorial_overlay()
	_create_round_scoreboard_overlay()
	_create_spectator_overlay()
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_on_minigame_ready()

	if multiplayer.is_server():
		call_deferred("initialize_game")
	else:
		var my_info = {
			"character": GameSession.selected_character,
			"name": Networking.get_local_player_name(),
			"steam_id": Networking.get_local_steam_id(),
			"color": GameSession.selected_color,
			"face": GameSession.selected_face,
			"hat": GameSession.selected_hat
		}
		request_game_sync.rpc_id(1, my_info)


func _exit_tree() -> void:
	if multiplayer:
		if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
			multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
		if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
			multiplayer.server_disconnected.disconnect(_on_server_disconnected)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if spectator_label:
			spectator_label.text = tr("SPECTATING_HINT")
		if spectator_change_btn:
			spectator_change_btn.text = tr("CHANGE_CHARACTER")


func _init_base_ui() -> void:
	match_timer_label = get_node_or_null("UI/MatchTimerLabel")
	winner_banner = get_node_or_null("UI/WinnerBanner")
	winner_label = get_node_or_null("UI/WinnerBanner/Margin/VBox/WinnerLabel")
	return_button = get_node_or_null("UI/WinnerBanner/Margin/VBox/ReturnButton")

	if winner_banner:
		winner_banner.visible = false
	if return_button:
		return_button.pressed.connect(_on_return_pressed)


func _create_tutorial_overlay() -> void:
	var ui = get_node_or_null("UI")
	if not ui:
		return

	tutorial_overlay = PanelContainer.new()
	tutorial_overlay.name = "TutorialOverlay"
	tutorial_overlay.visible = false
	tutorial_overlay.anchors_preset = Control.PRESET_FULL_RECT
	tutorial_overlay.anchor_right = 1.0
	tutorial_overlay.anchor_bottom = 1.0

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.12, 0.94)
	tutorial_overlay.add_theme_stylebox_override("panel", style)

	var center = CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	tutorial_overlay.add_child(center)

	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.14, 0.22, 0.98)
	card_style.set_corner_radius_all(16)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(1.0, 0.85, 0.2, 0.8)
	card.add_theme_stylebox_override("panel", card_style)
	card.custom_minimum_size = Vector2(760, 520)
	center.add_child(card)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	tutorial_title_label = Label.new()
	tutorial_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_title_label.add_theme_font_size_override("font_size", 26)
	tutorial_title_label.modulate = Color(1.0, 0.85, 0.2)
	vbox.add_child(tutorial_title_label)

	var img_container = AspectRatioContainer.new()
	img_container.ratio = 16.0 / 9.0
	img_container.custom_minimum_size = Vector2(440, 247)
	img_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(img_container)

	tutorial_image_rect = TextureRect.new()
	tutorial_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tutorial_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img_container.add_child(tutorial_image_rect)

	tutorial_rules_label = Label.new()
	tutorial_rules_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_rules_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(tutorial_rules_label)

	tutorial_controls_label = Label.new()
	tutorial_controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_controls_label.add_theme_font_size_override("font_size", 13)
	tutorial_controls_label.modulate = Color(0.6, 0.9, 1.0)
	vbox.add_child(tutorial_controls_label)

	var hsep = HSeparator.new()
	vbox.add_child(hsep)

	tutorial_countdown_label = Label.new()
	tutorial_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_countdown_label.add_theme_font_size_override("font_size", 24)
	tutorial_countdown_label.modulate = Color(0.3, 1.0, 0.4)
	vbox.add_child(tutorial_countdown_label)

	ui.add_child(tutorial_overlay)


func _create_round_scoreboard_overlay() -> void:
	var ui = get_node_or_null("UI")
	if not ui:
		return

	round_scoreboard_overlay = PanelContainer.new()
	round_scoreboard_overlay.name = "RoundScoreboardOverlay"
	round_scoreboard_overlay.visible = false
	round_scoreboard_overlay.anchors_preset = Control.PRESET_FULL_RECT
	round_scoreboard_overlay.anchor_right = 1.0
	round_scoreboard_overlay.anchor_bottom = 1.0

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.06, 0.1, 0.94)
	round_scoreboard_overlay.add_theme_stylebox_override("panel", bg_style)

	var center = CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	round_scoreboard_overlay.add_child(center)

	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.1, 0.12, 0.2, 0.98)
	card_style.set_corner_radius_all(16)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.3, 0.7, 1.0, 0.8)
	card.add_theme_stylebox_override("panel", card_style)
	card.custom_minimum_size = Vector2(680, 480)
	center.add_child(card)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	round_scoreboard_title = Label.new()
	round_scoreboard_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_scoreboard_title.add_theme_font_size_override("font_size", 26)
	round_scoreboard_title.modulate = Color(1.0, 0.85, 0.2)
	vbox.add_child(round_scoreboard_title)

	var hsep = HSeparator.new()
	vbox.add_child(hsep)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 240)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	round_scoreboard_list = VBoxContainer.new()
	round_scoreboard_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	round_scoreboard_list.add_theme_constant_override("separation", 8)
	scroll.add_child(round_scoreboard_list)

	var hsep2 = HSeparator.new()
	vbox.add_child(hsep2)

	round_scoreboard_status = Label.new()
	round_scoreboard_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_scoreboard_status.add_theme_font_size_override("font_size", 16)
	round_scoreboard_status.modulate = Color(0.4, 0.9, 1.0)
	vbox.add_child(round_scoreboard_status)

	round_scoreboard_return_btn = Button.new()
	round_scoreboard_return_btn.text = tr("RETURN_TO_LOBBY")
	round_scoreboard_return_btn.custom_minimum_size = Vector2(200, 40)
	round_scoreboard_return_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	round_scoreboard_return_btn.visible = false
	round_scoreboard_return_btn.pressed.connect(_on_return_pressed)
	vbox.add_child(round_scoreboard_return_btn)

	ui.add_child(round_scoreboard_overlay)


func _create_spectator_overlay() -> void:
	var ui = get_node_or_null("UI")
	if not ui:
		return

	spectator_overlay = PanelContainer.new()
	spectator_overlay.name = "SpectatorOverlay"
	spectator_overlay.visible = false
	spectator_overlay.anchors_preset = Control.PRESET_TOP_WIDE
	spectator_overlay.offset_top = 16
	spectator_overlay.offset_left = 120
	spectator_overlay.offset_right = -120
	spectator_overlay.offset_bottom = 58

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.18, 0.92)
	style.set_corner_radius_all(8)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.6, 1.0, 0.7)
	spectator_overlay.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	spectator_overlay.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	spectator_label = Label.new()
	spectator_label.text = tr("SPECTATING_HINT")
	spectator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spectator_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	spectator_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spectator_label.add_theme_font_size_override("font_size", 15)
	spectator_label.modulate = Color(0.8, 0.9, 1.0)
	hbox.add_child(spectator_label)

	spectator_change_btn = Button.new()
	spectator_change_btn.text = tr("CHANGE_CHARACTER")
	spectator_change_btn.custom_minimum_size = Vector2(140, 30)
	spectator_change_btn.add_theme_font_size_override("font_size", 13)
	spectator_change_btn.pressed.connect(show_spectator_character_select)
	hbox.add_child(spectator_change_btn)

	ui.add_child(spectator_overlay)


func _update_spectator_ui() -> void:
	if not spectator_overlay or multiplayer.is_server():
		return
	var my_id = multiplayer.get_unique_id()
	var is_spectator = (state == GameState.PLAYING or state == GameState.TUTORIAL or state == GameState.ENDED) and (my_id not in player_states)
	spectator_overlay.visible = is_spectator
	if is_spectator and not GameSession.has_selected_character:
		show_spectator_character_select()


func show_spectator_character_select() -> void:
	var ui = get_node_or_null("UI")
	if not ui or ui.has_node("CharacterSelect"):
		return
	var char_select = CHARACTER_SELECT_SCENE.instantiate()
	char_select.name = "CharacterSelect"
	ui.add_child(char_select)
	char_select.character_confirmed.connect(_on_spectator_character_confirmed)
	char_select.selection_cancelled.connect(_on_spectator_character_cancelled)


func _on_spectator_character_confirmed(character_path: String, color: Color = Color.WHITE, face: String = "", hat: String = "") -> void:
	GameSession.selected_character = character_path
	GameSession.selected_color = color
	GameSession.selected_face = face
	GameSession.selected_hat = hat
	GameSession.has_selected_character = true
	var ui = get_node_or_null("UI")
	if ui:
		var char_select = ui.get_node_or_null("CharacterSelect")
		if char_select:
			char_select.queue_free()
	_update_spectator_ui()
	update_spectator_character.rpc_id(1, character_path, color, face, hat)


func _on_spectator_character_cancelled() -> void:
	var ui = get_node_or_null("UI")
	if ui:
		var char_select = ui.get_node_or_null("CharacterSelect")
		if char_select:
			char_select.queue_free()
	if not GameSession.has_selected_character:
		Networking.disconnect_and_return_to_menu()


@rpc("any_peer", "reliable")
func update_spectator_character(character_path: String, color: Color, face: String, hat: String) -> void:
	if not is_inside_tree() or not multiplayer.is_server():
		return
	var caller_id = multiplayer.get_remote_sender_id()
	if caller_id == 0:
		caller_id = multiplayer.get_unique_id()
	if caller_id in GameSession.minigame_players:
		GameSession.minigame_players[caller_id]["character"] = character_path
		GameSession.minigame_players[caller_id]["color"] = color
		GameSession.minigame_players[caller_id]["face"] = face
		GameSession.minigame_players[caller_id]["hat"] = hat
		for pid in synced_peers:
			if pid != 1:
				sync_minigame_players.rpc_id(pid, GameSession.minigame_players)


func initialize_game() -> void:
	if not multiplayer.is_server():
		return

	var minigame_data = GameSession.minigame_players
	if minigame_data.is_empty():
		push_error("[%s] No player data from GameSession" % name)
		return

	if not _on_pre_initialize():
		return

	var spawn_positions = _get_spawn_positions()
	var idx = 0

	for peer_id in minigame_data:
		var info = minigame_data[peer_id]
		var col: Color = info.get("color", Color.WHITE)
		var face: String = info.get("face", "res://assets/characters/face/robloxmanface.png")
		var hat: String = info.get("hat", "")
		var pos: Vector3 = spawn_positions[idx % spawn_positions.size()] if not spawn_positions.is_empty() else Vector3(0, 1, 0)
		for pid in synced_peers:
			if pid == 1:
				spawn_player(peer_id, info.character, info.name, info.steam_id, pos, col, face, hat)
			else:
				spawn_player.rpc_id(pid, peer_id, info.character, info.name, info.steam_id, pos, col, face, hat)
		player_states[peer_id] = {
			"alive": true,
			"death_timer": 0.0,
			"name": info.name
		}
		idx += 1

	_on_post_initialize()

	elimination_order.clear()
	var tut_data = _get_tutorial_data()
	if not tut_data.is_empty():
		state = GameState.TUTORIAL
		tutorial_timer = TUTORIAL_DURATION
		for pid in synced_peers:
			if pid == 1:
				sync_game_state(GameState.TUTORIAL)
				start_tutorial_rpc(tut_data, tutorial_timer)
			else:
				sync_game_state.rpc_id(pid, GameState.TUTORIAL)
				start_tutorial_rpc.rpc_id(pid, tut_data, tutorial_timer)
		_freeze_all_players(true)
	else:
		state = GameState.PLAYING
		for pid in synced_peers:
			if pid == 1:
				sync_game_state(GameState.PLAYING)
			else:
				sync_game_state.rpc_id(pid, GameState.PLAYING)


func _process(delta: float) -> void:
	if not is_inside_tree() or state == GameState.INITIALIZING:
		return

	if state == GameState.TUTORIAL:
		if multiplayer.is_server():
			tutorial_timer -= delta
			for pid in synced_peers:
				if pid != 1:
					sync_tutorial_timer.rpc_id(pid, tutorial_timer)
			if tutorial_timer <= 0.0:
				_finish_tutorial()
				return
		_update_tutorial_ui()
		return

	if state != GameState.PLAYING:
		return

	if multiplayer.is_server():
		match_timer -= delta
		if match_timer <= 0.0:
			end_game_timeout()
			return

		for peer_id in player_states:
			if not player_states[peer_id].alive:
				player_states[peer_id].death_timer -= delta
				if player_states[peer_id].death_timer <= 0.0:
					remove_dead_player(peer_id)

		for pid in synced_peers:
			if pid != 1:
				sync_match_timer.rpc_id(pid, match_timer)

	if match_timer_label:
		match_timer_label.text = tr("MATCH_TIMER") % int(max(0, match_timer))

	_on_minigame_tick(delta)


# ==============================================================================
# TUTORIAL SYSTEM
# ==============================================================================

func _finish_tutorial() -> void:
	if not multiplayer.is_server():
		return
	state = GameState.PLAYING
	for pid in synced_peers:
		if pid == 1:
			sync_game_state(GameState.PLAYING)
			finish_tutorial_rpc()
		else:
			sync_game_state.rpc_id(pid, GameState.PLAYING)
			finish_tutorial_rpc.rpc_id(pid)
	_freeze_all_players(false)
	_on_tutorial_finished()


@rpc("authority", "call_local", "reliable")
func start_tutorial_rpc(data: Dictionary, duration: float) -> void:
	state = GameState.TUTORIAL
	tutorial_timer = duration
	_show_tutorial_overlay(data)
	_freeze_all_players(true)


@rpc("authority", "call_local", "reliable")
func finish_tutorial_rpc() -> void:
	state = GameState.PLAYING
	if tutorial_overlay:
		tutorial_overlay.visible = false
	_freeze_all_players(false)
	if not multiplayer.is_server():
		_on_tutorial_finished()
	_update_spectator_ui()


@rpc("authority", "unreliable")
func sync_tutorial_timer(time_left: float) -> void:
	if multiplayer.is_server():
		return
	tutorial_timer = time_left
	_update_tutorial_ui()


func _show_tutorial_overlay(data: Dictionary) -> void:
	if not tutorial_overlay:
		return
	tutorial_overlay.visible = true
	if tutorial_title_label:
		tutorial_title_label.text = data.get("title", "")
	if tutorial_rules_label:
		tutorial_rules_label.text = data.get("rules", "")
	if tutorial_controls_label:
		tutorial_controls_label.text = data.get("controls", "")
	if tutorial_image_rect and data.has("image"):
		var img_path = data["image"]
		if img_path != "" and ResourceLoader.exists(img_path):
			tutorial_image_rect.texture = load(img_path)
	_update_tutorial_ui()


func _update_tutorial_ui() -> void:
	if tutorial_countdown_label and tutorial_overlay and tutorial_overlay.visible:
		var sec = int(ceil(max(0, tutorial_timer)))
		tutorial_countdown_label.text = tr("STARTING_IN") % sec if sec > 0 else tr("READY")
		if sec != _last_tutorial_countdown_sec:
			_last_tutorial_countdown_sec = sec
			if AudioManager:
				AudioManager.play_countdown_tick()


func _freeze_all_players(frozen: bool) -> void:
	for pid in players:
		var p = players[pid]
		if is_instance_valid(p):
			p.set_physics_process(not frozen)


# ==============================================================================
# NETWORKING & RPCs
# ==============================================================================

@rpc("any_peer", "reliable")
func request_game_sync(client_info: Dictionary = {}) -> void:
	if not is_inside_tree() or not multiplayer.is_server():
		return
	var caller_id = multiplayer.get_remote_sender_id()
	if caller_id == 0:
		caller_id = multiplayer.get_unique_id()
	synced_peers[caller_id] = true

	if caller_id not in GameSession.minigame_players:
		var p_name = client_info.get("name", "Player %d" % caller_id)
		var s_id = client_info.get("steam_id", 0)
		var c_path = client_info.get("character", "res://assets/characters/Blank_Character/Blank_Character.glb")
		var col: Color = client_info.get("color", Color.WHITE)
		var face: String = client_info.get("face", "res://assets/characters/face/robloxmanface.png")
		var hat: String = client_info.get("hat", "")
		GameSession.minigame_players[caller_id] = {
			"character": c_path,
			"name": p_name,
			"steam_id": s_id,
			"ready": true,
			"wins": 0,
			"score": 0,
			"color": col,
			"face": face,
			"hat": hat
		}
		for pid in synced_peers:
			if pid == 1:
				sync_minigame_players(GameSession.minigame_players)
			else:
				sync_minigame_players.rpc_id(pid, GameSession.minigame_players)
	else:
		sync_minigame_players.rpc_id(caller_id, GameSession.minigame_players)

	sync_game_state.rpc_id(caller_id, state)
	sync_campaign_state.rpc_id(caller_id, GameSession.campaign_active, GameSession.target_score, GameSession.player_scores)
	if state == GameState.TUTORIAL:
		var tut_data = _get_tutorial_data()
		start_tutorial_rpc.rpc_id(caller_id, tut_data, tutorial_timer)
	sync_match_timer.rpc_id(caller_id, match_timer)

	for pid in players:
		var p = players[pid]
		if is_instance_valid(p):
			var c_path = p.character_path if "character_path" in p else ""
			var p_name = p.player_name if p.player_name != "" else ("Player %d" % pid)
			var col: Color = p.character_color if "character_color" in p else Color.WHITE
			var face: String = p.character_face if "character_face" in p and p.character_face != "" else "res://assets/characters/face/robloxmanface.png"
			var hat: String = p.character_hat if "character_hat" in p else ""
			spawn_player.rpc_id(caller_id, pid, c_path, p_name, p.steam_id, p.position, col, face, hat)

	_on_sync_custom_entities(caller_id)


@rpc("authority", "call_local", "reliable")
func sync_minigame_players(all_players: Dictionary) -> void:
	if not is_inside_tree():
		return
	GameSession.minigame_players = all_players.duplicate(true)


@rpc("authority", "call_local", "reliable")
func sync_game_state(new_state: int) -> void:
	if not is_inside_tree():
		return
	state = new_state as GameState
	_update_spectator_ui()


@rpc("authority", "reliable")
func sync_campaign_state(active: bool, target_score: int, scores: Dictionary) -> void:
	if not is_inside_tree():
		return
	GameSession.campaign_active = active
	GameSession.target_score = target_score
	GameSession.player_scores = scores.duplicate(true)



@rpc("authority", "call_local", "reliable")
func spawn_player(peer_id: int, character_path: String, player_name: String, steam_id: int, pos: Vector3, color: Color = Color.WHITE, face: String = "res://assets/characters/face/robloxmanface.png", hat: String = "") -> void:
	if not is_inside_tree():
		return
	if peer_id in players and is_instance_valid(players[peer_id]):
		return
	var old_node = get_node_or_null(str(peer_id))
	if old_node:
		remove_child(old_node)
		old_node.queue_free()

	var player = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.position = pos
	player.set_multiplayer_authority(peer_id)
	player.set_player_name(player_name)
	player.steam_id = steam_id
	player.character_path = character_path
	player.character_color = color
	player.character_face = face
	player.character_hat = hat
	player.add_to_group("player")
	add_child(player)
	player.set_character_customization(color, face, hat)
	players[peer_id] = player
	player_states[peer_id] = {
		"alive": true,
		"death_timer": 0.0,
		"name": player_name
	}

	if character_path and character_path != player.character_path:
		player.switch_character(character_path)
		player.set_character_customization(color, face, hat)

	if state == GameState.TUTORIAL:
		player.set_physics_process(false)

	_update_spectator_ui()


@rpc("any_peer", "unreliable")
func sync_player_state(peer_id: int, pos: Vector3, rot_y: float, anim_name: String) -> void:
	if not is_inside_tree() or is_returning or is_switching_round or state != GameState.PLAYING:
		return
	if not multiplayer or not multiplayer.multiplayer_peer or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var local_id := multiplayer.get_unique_id()
	if local_id == 0 or peer_id == local_id:
		return
	var player = players.get(peer_id)
	if player and is_instance_valid(player) and player.is_inside_tree():
		player._apply_state(pos, rot_y, anim_name)


@rpc("authority", "unreliable")
func sync_match_timer(time_left: float) -> void:
	if multiplayer.is_server():
		return
	match_timer = time_left
	if match_timer_label:
		match_timer_label.text = tr("MATCH_TIMER") % int(max(0, match_timer))


@rpc("any_peer", "reliable")
func request_push(target_peer_id: int, push_dir: Vector3) -> void:
	if not is_inside_tree() or not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var sender_player = players.get(sender_id)
	var target_player = players.get(target_peer_id)
	if not sender_player or not target_player:
		return
	var dist = sender_player.global_position.distance_to(target_player.global_position)
	if dist > 2.2 + 1.5:
		return
	if target_peer_id == multiplayer.get_unique_id():
		target_player.apply_knockback(push_dir)
	else:
		apply_knockback_rpc.rpc_id(target_peer_id, push_dir)


@rpc("authority", "reliable")
func apply_knockback_rpc(push_dir: Vector3) -> void:
	if not is_inside_tree():
		return
	var local_id = multiplayer.get_unique_id()
	var player = players.get(local_id)
	if player and is_instance_valid(player):
		player.apply_knockback(push_dir)


# ==============================================================================
# PLAYER LIFECYCLE & ELIMINATION
# ==============================================================================

func player_died(peer_id: int) -> void:
	if not is_inside_tree() or not multiplayer.is_server():
		return
	if not (peer_id in player_states) or not player_states[peer_id].alive:
		return
	player_states[peer_id].alive = false
	player_states[peer_id].death_timer = 2.0
	if peer_id not in elimination_order:
		elimination_order.append(peer_id)

	for pid in synced_peers:
		if pid == 1:
			player_died_rpc(peer_id)
		else:
			player_died_rpc.rpc_id(pid, peer_id)
	_on_player_died(peer_id)


@rpc("authority", "call_local", "reliable")
func player_died_rpc(peer_id: int) -> void:
	if not is_inside_tree():
		return
	var player = players.get(peer_id)
	if player and is_instance_valid(player) and player.is_inside_tree():
		player.die_in_minigame()


func remove_dead_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	for pid in synced_peers:
		if pid == 1:
			remove_player_rpc(peer_id)
		else:
			remove_player_rpc.rpc_id(pid, peer_id)


@rpc("authority", "call_local", "reliable")
func remove_player_rpc(peer_id: int) -> void:
	if not is_inside_tree():
		return
	var player = players.get(peer_id)
	if player and is_instance_valid(player):
		player.queue_free()
	players.erase(peer_id)


func get_alive_player_ids() -> Array:
	var alive = []
	for peer_id in player_states:
		if player_states[peer_id].alive:
			alive.append(peer_id)
	return alive


func get_alive_players() -> Array:
	var alive = []
	for peer_id in get_alive_player_ids():
		if peer_id in players and is_instance_valid(players[peer_id]):
			alive.append(players[peer_id])
	return alive


# ==============================================================================
# WIN CONDITIONS, SCORING & GAME END
# ==============================================================================

func end_game_winner(winner_id: int) -> void:
	if state == GameState.ENDED:
		return
	state = GameState.ENDED
	if multiplayer.is_server():
		GameSession.pending_match_winner = winner_id
		for pid in get_alive_player_ids():
			if pid not in elimination_order:
				elimination_order.append(pid)
		_process_round_end(winner_id)


func end_game_timeout() -> void:
	if state == GameState.ENDED:
		return
	state = GameState.ENDED
	var alive = get_alive_player_ids()
	var winner_id = alive[0] if alive.size() == 1 else -1
	if multiplayer.is_server():
		GameSession.pending_match_winner = winner_id
		for pid in alive:
			if pid not in elimination_order:
				elimination_order.append(pid)
		_process_round_end(winner_id)


func _calculate_round_scores() -> Dictionary:
	var scores: Dictionary = {}
	var total_n = player_states.size()
	if total_n <= 1:
		for pid in player_states:
			scores[pid] = 1000
		return scores

	for rank_idx in range(elimination_order.size()):
		var pid = elimination_order[rank_idx]
		var k = rank_idx + 1  # 1-based rank (1 = died first, total_n = last standing)
		var pts = int(round(float(k - 1) / float(total_n - 1) * 1000.0))
		scores[pid] = pts

	for pid in player_states:
		if pid not in scores:
			scores[pid] = 1000
	return scores


func _process_round_end(winner_id: int) -> void:
	if not multiplayer.is_server():
		return

	var round_scores = _calculate_round_scores()
	GameSession.round_scores = round_scores
	for pid in round_scores:
		GameSession.player_scores[pid] = GameSession.player_scores.get(pid, 0) + round_scores[pid]
	GameSession.elimination_order = elimination_order.duplicate()
	GameSession.last_played_map = name

	if winner_id > 0:
		GameSession.player_wins[winner_id] = GameSession.player_wins.get(winner_id, 0) + 1

	var tournament_winner_id: int = -1
	if GameSession.campaign_active:
		for pid in GameSession.player_scores:
			if GameSession.player_scores[pid] >= GameSession.target_score:
				if tournament_winner_id == -1 or GameSession.player_scores[pid] > GameSession.player_scores[tournament_winner_id]:
					tournament_winner_id = pid

	for pid in synced_peers:
		if pid == 1:
			show_round_scoreboard_rpc(round_scores, GameSession.player_scores, tournament_winner_id)
		else:
			show_round_scoreboard_rpc.rpc_id(pid, round_scores, GameSession.player_scores, tournament_winner_id)

	if tournament_winner_id > 0:
		_start_auto_return()
	elif GameSession.campaign_active:
		_start_next_minigame_countdown()
	else:
		_start_auto_return()


func _start_auto_return() -> void:
	if not multiplayer.is_server():
		return
	await get_tree().create_timer(7.0).timeout
	if state == GameState.ENDED and is_inside_tree() and not is_returning and not is_switching_round:
		return_to_lobby()


func _start_next_minigame_countdown() -> void:
	if not multiplayer.is_server():
		return
	await get_tree().create_timer(6.0).timeout
	if state == GameState.ENDED and is_inside_tree() and not is_switching_round and not is_returning:
		var next_scene = _get_next_minigame_scene()
		switch_to_next_minigame(next_scene)


func _get_next_minigame_scene() -> String:
	var current_map_name = name.to_lower()
	if "hotbomb" in current_map_name or "bomb" in current_map_name:
		return "res://scenes/minigames/stable_footing/stable_footing.tscn"
	elif "stablefooting" in current_map_name or "footing" in current_map_name:
		return "res://scenes/minigames/mimic/mimic.tscn"
	elif "mimic" in current_map_name:
		return "res://scenes/minigames/hot_bomb/hot_bomb.tscn"
	return "res://scenes/minigames/hot_bomb/hot_bomb.tscn"


@rpc("authority", "call_local", "reliable")
func show_round_scoreboard_rpc(round_scores: Dictionary, total_scores: Dictionary, tournament_winner_id: int) -> void:
	state = GameState.ENDED
	if not is_inside_tree():
		return
	_update_spectator_ui()
	GameSession.player_scores = total_scores.duplicate(true)
	if AudioManager:
		AudioManager.play_game_win()
	if winner_banner:
		winner_banner.visible = false

	if not round_scoreboard_overlay:
		return

	round_scoreboard_overlay.visible = true

	if tournament_winner_id > 0:
		var w_name = player_states.get(tournament_winner_id, {}).get("name", GameSession.minigame_players.get(tournament_winner_id, {}).get("name", "Player %d" % tournament_winner_id))
		round_scoreboard_title.text = tr("TOURNAMENT_WINNER") % w_name
		round_scoreboard_title.modulate = Color(1.0, 0.85, 0.2)
		round_scoreboard_status.text = tr("CAMPAIGN_SCORE_WINNER_TEXT") % [w_name, total_scores.get(tournament_winner_id, 0)]
		if round_scoreboard_return_btn:
			round_scoreboard_return_btn.visible = multiplayer.is_server()
	elif GameSession.campaign_active:
		round_scoreboard_title.text = tr("ROUND_SCOREBOARD")
		round_scoreboard_status.text = tr("NEXT_MINIGAME_IN") % 6
	else:
		round_scoreboard_title.text = tr("ROUND_SCOREBOARD")
		round_scoreboard_status.text = ""
		if round_scoreboard_return_btn:
			round_scoreboard_return_btn.visible = multiplayer.is_server()

	for child in round_scoreboard_list.get_children():
		child.queue_free()

	var sorted_pids = total_scores.keys()
	sorted_pids.sort_custom(func(a, b):
		return total_scores[a] > total_scores[b]
	)

	for rank_idx in range(sorted_pids.size()):
		var pid = sorted_pids[rank_idx]
		var p_name = player_states.get(pid, {}).get("name", GameSession.minigame_players.get(pid, {}).get("name", "Player %d" % pid))
		var p_round_score = round_scores.get(pid, 0)
		var p_total_score = total_scores.get(pid, 0)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var rank_lbl = Label.new()
		rank_lbl.text = "#%d" % (rank_idx + 1)
		rank_lbl.custom_minimum_size = Vector2(30, 0)
		rank_lbl.add_theme_font_size_override("font_size", 16)
		rank_lbl.modulate = Color(1.0, 0.85, 0.2) if rank_idx == 0 else Color(0.7, 0.7, 0.7)
		row.add_child(rank_lbl)

		var name_lbl = Label.new()
		name_lbl.text = p_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 16)
		if pid == multiplayer.get_unique_id():
			name_lbl.modulate = Color(0.4, 0.9, 1.0)
		row.add_child(name_lbl)

		var round_lbl = Label.new()
		round_lbl.text = "+%d pts" % p_round_score
		round_lbl.custom_minimum_size = Vector2(80, 0)
		round_lbl.add_theme_font_size_override("font_size", 14)
		round_lbl.modulate = Color(0.3, 1.0, 0.4)
		row.add_child(round_lbl)

		var total_lbl = Label.new()
		if GameSession.campaign_active:
			total_lbl.text = "%d / %d pts" % [p_total_score, GameSession.target_score]
		else:
			total_lbl.text = "%d pts" % p_total_score
		total_lbl.custom_minimum_size = Vector2(110, 0)
		total_lbl.add_theme_font_size_override("font_size", 14)
		total_lbl.modulate = Color(1.0, 0.85, 0.3) if p_total_score >= GameSession.target_score else Color(0.9, 0.9, 0.9)
		row.add_child(total_lbl)

		round_scoreboard_list.add_child(row)


@rpc("authority", "call_local", "reliable")
func show_winner_banner(winner_id: int) -> void:
	state = GameState.ENDED
	if not is_inside_tree():
		return
	_update_spectator_ui()
	if AudioManager:
		AudioManager.play_game_win()
	if winner_banner:
		winner_banner.visible = true
	if winner_label:
		if winner_id > 0 and winner_id in player_states:
			winner_label.text = tr("PLAYER_WINS") % player_states[winner_id].name
		else:
			winner_label.text = _get_draw_text()


func _get_draw_text() -> String:
	return tr("DRAW")


# ==============================================================================
# RETURN TO LOBBY & SWITCH MINIGAME (TWO-PHASE TRANSITIONS)
# ==============================================================================

func _on_return_pressed() -> void:
	if multiplayer.is_server():
		return_to_lobby()
	else:
		request_return_to_lobby.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func request_return_to_lobby() -> void:
	if multiplayer.is_server() and state == GameState.ENDED:
		return_to_lobby()


func return_to_lobby() -> void:
	if is_returning or is_switching_round:
		return
	is_returning = true
	set_process(false)
	set_physics_process(false)
	for pid in players:
		var p = players[pid]
		if is_instance_valid(p):
			p.set_physics_process(false)
	_on_prepare_return_to_lobby()

	if multiplayer.is_server():
		for pid in synced_peers:
			if pid != 1:
				prepare_return_to_lobby_rpc.rpc_id(pid)
		await get_tree().create_timer(0.1).timeout
		if not is_inside_tree():
			return
		for pid in synced_peers:
			if pid != 1:
				return_to_lobby_rpc.rpc_id(pid)

	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/core/main.tscn")


@rpc("authority", "call_remote", "reliable")
func prepare_return_to_lobby_rpc() -> void:
	is_returning = true
	set_process(false)
	set_physics_process(false)
	for pid in players:
		var p = players[pid]
		if is_instance_valid(p):
			p.set_physics_process(false)
	_on_prepare_return_to_lobby()


@rpc("authority", "call_remote", "reliable")
func return_to_lobby_rpc() -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/core/main.tscn")


func switch_to_next_minigame(next_scene_path: String) -> void:
	if is_switching_round or is_returning:
		return
	is_switching_round = true
	set_process(false)
	set_physics_process(false)
	for pid in players:
		var p = players[pid]
		if is_instance_valid(p):
			p.set_physics_process(false)
	_on_prepare_return_to_lobby()

	if multiplayer.is_server():
		for pid in synced_peers:
			if pid != 1:
				prepare_switch_minigame_rpc.rpc_id(pid, next_scene_path)
		await get_tree().create_timer(0.1).timeout
		if not is_inside_tree():
			return
		for pid in synced_peers:
			if pid != 1:
				switch_minigame_rpc.rpc_id(pid, next_scene_path)

	if is_inside_tree():
		get_tree().change_scene_to_file(next_scene_path)


@rpc("authority", "call_remote", "reliable")
func prepare_switch_minigame_rpc(_next_scene_path: String) -> void:
	is_switching_round = true
	set_process(false)
	set_physics_process(false)
	for pid in players:
		var p = players[pid]
		if is_instance_valid(p):
			p.set_physics_process(false)
	_on_prepare_return_to_lobby()


@rpc("authority", "call_remote", "reliable")
func switch_minigame_rpc(next_scene_path: String) -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file(next_scene_path)


func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id == 1 and not multiplayer.is_server():
		print("[MINIGAME] Host left, returning to menu")
		Networking.disconnect_and_return_to_menu()
		return
	if peer_id in players:
		if is_instance_valid(players[peer_id]):
			players[peer_id].queue_free()
		players.erase(peer_id)
	if peer_id in player_states:
		player_states.erase(peer_id)
	if peer_id in GameSession.minigame_players:
		GameSession.minigame_players.erase(peer_id)
	synced_peers.erase(peer_id)
	_on_player_disconnected(peer_id)


func _on_server_disconnected() -> void:
	print("[MINIGAME] Server disconnected, returning to menu")
	Networking.disconnect_and_return_to_menu()


# ==============================================================================
# VIRTUAL HOOKS FOR SUBCLASSES
# ==============================================================================

func _get_tutorial_data() -> Dictionary:
	return {}

func _on_minigame_ready() -> void:
	pass

func _on_pre_initialize() -> bool:
	return true

func _get_spawn_positions() -> Array[Vector3]:
	return [
		Vector3(-10, 0.5, -10),
		Vector3(10, 0.5, -10),
		Vector3(-10, 0.5, 10),
		Vector3(10, 0.5, 10)
	]

func _on_post_initialize() -> void:
	pass

func _on_minigame_tick(_delta: float) -> void:
	pass

func _on_sync_custom_entities(_caller_id: int) -> void:
	pass

func _on_player_died(_peer_id: int) -> void:
	pass

func _on_player_disconnected(_peer_id: int) -> void:
	pass

func _on_prepare_return_to_lobby() -> void:
	pass

func _on_tutorial_finished() -> void:
	pass
