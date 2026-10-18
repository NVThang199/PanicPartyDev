extends Node

# AudioManager - Quản lý tập trung hiệu ứng âm thanh (SFX) cho 3D Low Poly Party Game

const SFX_DIR = "res://assets/audio/sfx/"

var streams: Dictionary = {}

# Node pool để tái sử dụng AudioStreamPlayer, tránh cấp phát liên tục
const POOL_SIZE_2D = 8
const POOL_SIZE_3D = 12

var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_preload_sounds()
	_init_pools()
	_setup_global_button_audio()

func _setup_global_button_audio() -> void:
	get_tree().node_added.connect(_on_node_added)
	_hook_existing_buttons(get_tree().root)

func _hook_existing_buttons(node: Node) -> void:
	if node is Button:
		_hook_button(node)
	for child in node.get_children():
		_hook_existing_buttons(child)

func _on_node_added(node: Node) -> void:
	if node is Button:
		_hook_button.call_deferred(node)

func _hook_button(btn: Button) -> void:
	if not btn.is_connected("pressed", _on_generic_button_pressed):
		btn.pressed.connect(_on_generic_button_pressed.bind(btn))
	if not btn.is_connected("mouse_entered", _on_generic_button_hovered):
		btn.mouse_entered.connect(_on_generic_button_hovered.bind(btn))

func _on_generic_button_pressed(btn: Button) -> void:
	for child in btn.get_children():
		if child.has_method("reset_tween"):
			return
	play_ui_click()

func _on_generic_button_hovered(btn: Button) -> void:
	for child in btn.get_children():
		if child.has_method("reset_tween"):
			return
	play_ui_hover()

func _preload_sounds() -> void:
	var sound_files = {
		"ui_click": "ui_click.wav",
		"ui_hover": "ui_hover.wav",
		"footstep": "footstep.wav",
		"kick_whoosh": "kick_whoosh.wav",
		"kick_hit": "kick_hit.wav",
		"knockback_fall": "knockback_fall.wav",
		"bomb_throw": "bomb_throw.wav",
		"bomb_catch": "bomb_catch.wav",
		"bomb_explode": "bomb_explode.wav",
		"bomb_tick": "bomb_tick.wav",
		"bomb_bounce": "bomb_bounce.wav",
		"bomb_rush": "bomb_rush.wav",
		"tile_flip": "tile_flip.wav",
		"tile_crumble": "tile_crumble.wav",
		"tile_fall": "tile_fall.wav",
		"player_death": "player_death.wav",
		"player_fall": "player_fall.wav",
		"player_join": "player_join.wav",
		"player_leave": "player_leave.wav",
		"player_ready": "player_ready.wav",
		"countdown_tick": "countdown_tick.wav",
		"copy_code": "copy_code.wav",
		"match_start": "match_start.wav",
		"game_win": "game_win.wav"
	}

	for key in sound_files:
		var path = SFX_DIR + sound_files[key]
		if ResourceLoader.exists(path):
			var res = load(path)
			if res:
				streams[key] = res

func _init_pools() -> void:
	for i in range(POOL_SIZE_2D):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool_2d.append(p)

	for i in range(POOL_SIZE_3D):
		var p3 = AudioStreamPlayer3D.new()
		p3.bus = "SFX"
		p3.max_distance = 150.0
		p3.unit_size = 25.0
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p3)
		_pool_3d.append(p3)

func _get_free_player_2d() -> AudioStreamPlayer:
	for p in _pool_2d:
		if not p.playing:
			return p
	return _pool_2d[0]

func _get_free_player_3d() -> AudioStreamPlayer3D:
	for p3 in _pool_3d:
		if not p3.playing:
			return p3
	return _pool_3d[0]

func play_sfx(stream: AudioStream, pitch_min: float = 0.95, pitch_max: float = 1.05, volume_db: float = 0.0) -> void:
	if not stream:
		return
	var player = _get_free_player_2d()
	player.stream = stream
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.volume_db = volume_db
	player.play()

func play_sfx_3d(stream: AudioStream, global_pos: Vector3, pitch_min: float = 0.95, pitch_max: float = 1.05, volume_db: float = 0.0, max_dist: float = 35.0) -> void:
	if not stream:
		return
	var player = _get_free_player_3d()
	player.stream = stream
	player.global_position = global_pos
	player.max_distance = max_dist
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.volume_db = volume_db
	player.play()

# Tiện ích phát âm thanh theo key
func play(key: String, pitch_min: float = 0.95, pitch_max: float = 1.05, volume_db: float = 0.0) -> void:
	if streams.has(key):
		play_sfx(streams[key], pitch_min, pitch_max, volume_db)

func play_3d(key: String, global_pos: Vector3, pitch_min: float = 0.95, pitch_max: float = 1.05, volume_db: float = 0.0, max_dist: float = 35.0) -> void:
	if streams.has(key):
		play_sfx_3d(streams[key], global_pos, pitch_min, pitch_max, volume_db, max_dist)

# Shortcut methods
func play_ui_click() -> void:
	play("ui_click", 0.96, 1.04, 0.0)

func play_ui_hover() -> void:
	play("ui_hover", 0.98, 1.02, -4.0)

func play_footstep(pos: Vector3) -> void:
	play_3d("footstep", pos, 0.92, 1.08, 3.0, 120.0)

func play_kick_whoosh(pos: Vector3) -> void:
	play_3d("kick_whoosh", pos, 0.95, 1.08, 2.0, 100.0)

func play_kick_hit(pos: Vector3) -> void:
	play_3d("kick_hit", pos, 0.92, 1.05, 4.0, 120.0)

func play_knockback_fall(pos: Vector3) -> void:
	play_3d("knockback_fall", pos, 0.9, 1.1, 3.0, 120.0)

func play_bomb_throw(pos: Vector3) -> void:
	play_3d("bomb_throw", pos, 0.95, 1.05, 3.0, 120.0)

func play_bomb_catch(pos: Vector3) -> void:
	play_3d("bomb_catch", pos, 0.95, 1.08, 4.0, 120.0)

func play_bomb_explode(_pos: Vector3 = Vector3.ZERO) -> void:
	# Bomb explosion is a game-wide dramatic event, broadcast in stereo + 3D
	play("bomb_explode", 0.95, 1.05, 6.0)

func play_tile_crumble(pos: Vector3) -> void:
	play_3d("tile_crumble", pos, 0.9, 1.1, 3.0, 100.0)

func play_tile_fall(pos: Vector3) -> void:
	play_3d("tile_fall", pos, 0.9, 1.1, 3.0, 100.0)

func play_bomb_tick(pos: Vector3, is_urgent: bool = false) -> void:
	if is_urgent:
		play_3d("bomb_tick", pos, 1.35, 1.5, 4.0, 140.0)
	else:
		play_3d("bomb_tick", pos, 0.95, 1.05, 1.5, 120.0)

func play_bomb_bounce(pos: Vector3) -> void:
	play_3d("bomb_bounce", pos, 0.9, 1.1, 3.0, 120.0)

func play_bomb_rush(_pos: Vector3 = Vector3.ZERO) -> void:
	# Rocket whistle rush echoes across the whole arena
	play("bomb_rush", 0.95, 1.05, 5.0)

func play_tile_flip(pos: Vector3 = Vector3.ZERO) -> void:
	if pos == Vector3.ZERO:
		play("tile_flip", 0.9, 1.1, 0.0)
	else:
		play_3d("tile_flip", pos, 0.9, 1.1, 1.0, 100.0)

func play_player_death(pos: Vector3) -> void:
	play_3d("player_death", pos, 0.9, 1.1, 4.0, 120.0)

func play_player_fall(pos: Vector3) -> void:
	play_3d("player_fall", pos, 0.9, 1.1, 3.0, 120.0)

func play_player_join() -> void:
	play("player_join", 0.95, 1.05, 2.0)

func play_player_leave() -> void:
	play("player_leave", 0.95, 1.05, 2.0)

func play_player_ready(is_ready: bool = true) -> void:
	if is_ready:
		play("player_ready", 0.98, 1.02, 2.0)
	else:
		play("player_leave", 1.05, 1.15, 0.0)

func play_countdown_tick() -> void:
	play("countdown_tick", 0.98, 1.02, 3.0)

func play_copy_code() -> void:
	play("copy_code", 0.95, 1.05, 0.0)

func play_match_start() -> void:
	play("match_start", 1.0, 1.0, 3.0)

func play_game_win() -> void:
	play("game_win", 1.0, 1.0, 2.0)
