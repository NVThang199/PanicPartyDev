extends Node3D

enum GameState { INITIALIZING, LISTENING, PREPARING, RECORDING, JUDGING, ENDED }

const PLAYER_SCENE = preload("res://scenes/players/player.tscn")
const SAMPLE_DURATION = 3.0
const RECORD_DURATION = 3.0
const ROUNDS = 3

var state: GameState = GameState.INITIALIZING
var players: Dictionary = {}  # peer_id -> player node
var player_scores: Dictionary = {}  # peer_id -> {name: String, scores: Array, total: int}
var current_round: int = 0
var sample_audio: AudioStream = null
var player_recordings: Dictionary = {}  # peer_id -> {audio: PackedFloat32Array, features: Dictionary}
var judging_index: int = 0
var is_returning: bool = false
var is_finishing_preparation: bool = false
var player_spawn_positions: Dictionary = {}  # peer_id -> spawn position

@onready var sample_player: AudioStreamPlayer = $SamplePlayer
@onready var playback_player: AudioStreamPlayer = $PlaybackPlayer
@onready var countdown_label: Label = $UI/CountdownLabel
@onready var round_label: Label = $UI/RoundLabel
@onready var instruction_label: Label = $UI/InstructionLabel
@onready var listen_button: Button = $UI/ControlPanel/ListenButton
@onready var record_button: Button = $UI/ControlPanel/RecordButton
@onready var replay_button: Button = $UI/ControlPanel/ReplayButton
@onready var scoreboard: PanelContainer = $UI/Scoreboard
@onready var scoreboard_vbox: VBoxContainer = $UI/Scoreboard/Margin/VBox
@onready var winner_banner: PanelContainer = $UI/WinnerBanner
@onready var winner_label: Label = $UI/WinnerBanner/Margin/VBox/WinnerLabel
@onready var return_button: Button = $UI/WinnerBanner/Margin/VBox/ReturnButton
@onready var record_bus_idx: int = -1
@onready var mic_player: AudioStreamPlayer = AudioStreamPlayer.new()

var record_effect: AudioEffectRecord = null
var output_silencer: AudioEffectAmplify = null
var recording_data: AudioStreamWAV = null
var my_recording_wav: AudioStreamWAV = null  # Lưu WAV gốc để replay
var sample_features_cached: Dictionary = {}  # Cache sample features
var is_recording: bool = false
var recording_timer: float = 0.0
var countdown_timer: float = 0.0
var preparation_timer: float = 0.0
var my_recording: PackedFloat32Array = PackedFloat32Array()  # Lưu bản ghi của mình
var is_countdown_active: bool = false

func _ready() -> void:
	if winner_banner:
		winner_banner.visible = false
	if scoreboard:
		scoreboard.visible = false
	if return_button:
		return_button.pressed.connect(_on_return_pressed)
	if listen_button:
		listen_button.pressed.connect(_on_listen_pressed)
		listen_button.disabled = true
	if record_button:
		record_button.pressed.connect(_on_record_pressed)
		record_button.disabled = true
	if replay_button:
		replay_button.pressed.connect(_on_replay_pressed)
		replay_button.disabled = true

	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Setup microphone player
	add_child(mic_player)

	# Request microphone permission (Windows)
	if OS.request_permission("RECORD_AUDIO"):
		print("[Mimic] Microphone permission granted")
	else:
		push_warning("[Mimic] Microphone permission denied or not requested")

	# Check available audio input devices
	var input_devices = AudioServer.get_input_device_list()
	print("[Mimic] Available input devices: %s" % input_devices)
	if input_devices.size() > 0:
		print("[Mimic] Using device: %s" % input_devices[0])
		AudioServer.input_device = input_devices[0]

	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.bus = "Record"
	mic_player.autoplay = false
	mic_player.volume_db = 0.0  # Full volume để AudioEffectRecord capture đầy đủ

	# Setup audio capture first (creates Record bus)
	_setup_audio_capture()
	print("[Mimic] Audio setup complete, Record bus idx: %d" % record_bus_idx)

	# Debug: test if mic is working by checking device
	print("[Mimic] Godot AudioServer input device: %s" % AudioServer.input_device)
	print("[Mimic] Record bus: %d, Muted: %s" % [record_bus_idx, AudioServer.is_bus_mute(record_bus_idx)])

	if multiplayer.is_server():
		call_deferred("initialize_game")
	else:
		request_game_sync.rpc_id(1)

func _setup_audio_capture() -> void:
	if record_bus_idx == -1:
		record_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(record_bus_idx)
		AudioServer.set_bus_name(record_bus_idx, "Record")

	# Chuỗi bắt buộc: microphone → Record effect → Silencer → Master.
	# Recorder lấy raw mic trước; silencer chặn output nên không monitor/echo.
	AudioServer.set_bus_send(record_bus_idx, "Master")
	AudioServer.set_bus_mute(record_bus_idx, false)

	var effect_count = AudioServer.get_bus_effect_count(record_bus_idx)
	for i in range(effect_count):
		var effect = AudioServer.get_bus_effect(record_bus_idx, i)
		if effect is AudioEffectRecord:
			record_effect = effect
		if effect is AudioEffectAmplify:
			output_silencer = effect

	if not record_effect:
		record_effect = AudioEffectRecord.new()
		AudioServer.add_bus_effect(record_bus_idx, record_effect, 0)

	if not output_silencer:
		output_silencer = AudioEffectAmplify.new()
		AudioServer.add_bus_effect(record_bus_idx, output_silencer)
	output_silencer.volume_db = -80.0
	print("[Mimic] Record bus: recorder then silencer (-80 dB)")

func initialize_game() -> void:
	var minigame_data = GameSession.minigame_players
	if minigame_data.is_empty():
		push_error("[Mimic] No player data from GameSession")
		return

	# Spawn players at fixed stage positions (no movement needed)
	var spawn_positions = [
		Vector3(-6, 0.5, 0),   # Left
		Vector3(-2, 0.5, 0),   # Center-left
		Vector3(2, 0.5, 0),    # Center-right
		Vector3(6, 0.5, 0)     # Right
	]
	var idx = 0

	for peer_id in minigame_data:
		var info = minigame_data[peer_id]
		var col: Color = info.get("color", Color.WHITE)
		var face: String = info.get("face", "res://assets/characters/face/robloxmanface.png")
		var hat: String = info.get("hat", "")
		var pos = spawn_positions[idx % spawn_positions.size()]
		player_spawn_positions[peer_id] = pos  # Lưu spawn position
		spawn_player.rpc(peer_id, info.character, info.name, info.steam_id, pos, col, face, hat)
		player_scores[peer_id] = {
			"name": info.name,
			"scores": [],
			"total": 0
		}
		idx += 1

	# Load random sample audio (ponytail: hardcoded 1 sample, add pool when needed)
	_load_sample_audio()

	state = GameState.LISTENING
	sync_game_state.rpc(GameState.LISTENING)
	current_round = 1
	sync_round.rpc(current_round)
	_start_listening_phase()

func _load_sample_audio() -> void:
	# Load từ assets/audio/mimic/
	var audio_files = []
	var dir = DirAccess.open("res://assets/audio/mimic/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".wav") or file_name.ends_with(".ogg") or file_name.ends_with(".mp3"):
				audio_files.append("res://assets/audio/mimic/" + file_name)
			file_name = dir.get_next()

	if audio_files.is_empty():
		# Fallback: generate placeholder
		push_warning("[Mimic] No audio files in res://assets/audio/mimic/, using placeholder sine wave")
		sample_audio = AudioStreamWAV.new()
		sample_audio.format = AudioStreamWAV.FORMAT_16_BITS
		sample_audio.mix_rate = 44100
		sample_audio.stereo = false
		var duration = 3.0
		var freq = 440.0
		var sample_count = int(duration * 44100)
		var data = PackedByteArray()
		for i in range(sample_count):
			var t = float(i) / 44100.0
			var val = sin(2.0 * PI * freq * t) * 0.3
			var sample_16 = int(clamp(val * 32767, -32768, 32767))
			data.append(sample_16 & 0xFF)
			data.append((sample_16 >> 8) & 0xFF)
		sample_audio.data = data
	else:
		# Load ngẫu nhiên từ folder
		var random_file = audio_files[randi() % audio_files.size()]
		sample_audio = load(random_file)
		if not sample_audio:
			push_error("[Mimic] Failed to load audio: " + random_file)

@rpc("any_peer", "reliable")
func request_game_sync() -> void:
	if not multiplayer.is_server():
		return
	var caller_id = multiplayer.get_remote_sender_id()
	if caller_id == 0:
		caller_id = multiplayer.get_unique_id()

	sync_game_state.rpc_id(caller_id, state)
	sync_round.rpc_id(caller_id, current_round)

	for pid in players:
		var p = players[pid]
		if is_instance_valid(p):
			var c_path = p.character_path if "character_path" in p else ""
			var p_name = p.player_name if p.player_name != "" else ("Player %d" % pid)
			var col: Color = p.character_color if "character_color" in p else Color.WHITE
			var face: String = p.character_face if "character_face" in p and p.character_face != "" else "res://assets/characters/face/robloxmanface.png"
			var hat: String = p.character_hat if "character_hat" in p else ""
			spawn_player.rpc_id(caller_id, pid, c_path, p_name, p.steam_id, p.position, col, face, hat)

@rpc("authority", "call_local", "reliable")
func spawn_player(peer_id: int, character_path: String, player_name: String, steam_id: int, pos: Vector3, color: Color = Color.WHITE, face: String = "res://assets/characters/face/robloxmanface.png", hat: String = "") -> void:
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

	if character_path and character_path != "":
		player.switch_character(character_path)
		player.set_character_customization(color, face, hat)

	# Disable player movement
	player.set_physics_process(false)

@rpc("authority", "call_local", "reliable")
func sync_game_state(new_state: int) -> void:
	state = new_state as GameState

@rpc("authority", "call_local", "reliable")
func sync_round(round_num: int) -> void:
	current_round = round_num
	if round_label:
		round_label.text = "Round %d/%d" % [current_round, ROUNDS]

func _start_listening_phase() -> void:
	if not multiplayer.is_server():
		return
	update_instruction.rpc("Get ready! Sample will play in...")
	start_countdown.rpc(3.0)  # 3s countdown trước khi phát

func _process(delta: float) -> void:
	if not is_inside_tree():
		return

	# Local countdown
	if is_countdown_active:
		countdown_timer -= delta
		if countdown_label:
			countdown_label.text = "%d" % max(0, int(ceil(countdown_timer)))
			countdown_label.visible = countdown_timer > 0
		if countdown_timer <= 0:
			is_countdown_active = false
			countdown_label.visible = false

	match state:
		GameState.PREPARING:
			if multiplayer.is_server():
				preparation_timer -= delta
				sync_preparation_timer.rpc(preparation_timer)
				if preparation_timer <= 0:
					_finish_preparation()
			if instruction_label:
				instruction_label.text = "Prepare your recording! Time: %ds" % max(0, int(preparation_timer))

		GameState.RECORDING:
			if is_recording:
				recording_timer -= delta
				if record_button:
					record_button.text = "Recording... %ds" % max(0, int(ceil(recording_timer)))
				if recording_timer <= 0:
					_stop_recording()

@rpc("authority", "unreliable")
func sync_preparation_timer(time: float) -> void:
	preparation_timer = time

@rpc("authority", "call_local", "reliable")
func start_countdown(duration: float) -> void:
	countdown_timer = duration
	is_countdown_active = true
	# Mute mic khi countdown để tránh tạp âm
	AudioServer.set_bus_mute(record_bus_idx, true)
	await get_tree().create_timer(duration).timeout
	if multiplayer.is_server() and state == GameState.LISTENING:
		_play_sample()

@rpc("authority", "call_local", "reliable")
func update_instruction(text: String) -> void:
	if instruction_label:
		instruction_label.text = text

@rpc("authority", "call_local", "reliable")
func enable_buttons(listen: bool, record: bool, replay: bool) -> void:
	if listen_button:
		listen_button.disabled = not listen
	if record_button:
		record_button.disabled = not record
	if replay_button:
		replay_button.disabled = not replay

func _play_sample() -> void:
	if not multiplayer.is_server():
		return
	play_sample_rpc.rpc()

@rpc("authority", "call_local", "reliable")
func play_sample_rpc() -> void:
	# Mute mic khi phát sample để tránh feedback
	AudioServer.set_bus_mute(record_bus_idx, true)
	if sample_player and sample_audio:
		sample_player.stream = sample_audio
		sample_player.play()
		update_instruction.rpc("Listening to sample...")
	# Start preparation exactly when the sample finishes; no fixed trailing delay.
	if sample_player and sample_player.playing:
		await sample_player.finished
	if multiplayer.is_server() and state == GameState.LISTENING:
		_start_preparation_phase()

func _start_preparation_phase() -> void:
	if not multiplayer.is_server():
		return
	state = GameState.PREPARING
	sync_game_state.rpc(GameState.PREPARING)
	preparation_timer = 10.0
	sync_preparation_timer.rpc(preparation_timer)
	enable_buttons.rpc(true, true, false)
	update_instruction.rpc("Prepare your recording! Time: 10s")

func _finish_preparation() -> void:
	if not multiplayer.is_server() or is_finishing_preparation:
		return
	is_finishing_preparation = true
	enable_buttons.rpc(false, false, false)
	update_instruction.rpc("Submitting recordings...")
	request_final_submissions.rpc()
	print("[Mimic] Checking submissions: %d/%d" % [player_recordings.size(), players.size()])
	_start_judging_phase()

func _on_listen_pressed() -> void:
	# Mute mic khi nghe lại sample
	AudioServer.set_bus_mute(record_bus_idx, true)
	if sample_player and sample_audio:
		sample_player.stream = sample_audio
		sample_player.play()

func _on_replay_pressed() -> void:
	# Nghe lại bản ghi của mình
	if not my_recording_wav:
		print("[Mimic] No recording to replay")
		return

	print("[Mimic] Replaying recording, length: %f" % my_recording_wav.get_length())

	if playback_player:
		playback_player.stream = my_recording_wav
		playback_player.play()

func _on_record_pressed() -> void:
	if is_recording:
		return
	var my_id = multiplayer.get_unique_id()
	if my_id == 1:  # Host
		start_recording_rpc.rpc_id(my_id)
	else:
		request_start_recording.rpc_id(1)

@rpc("any_peer", "reliable")
func request_start_recording() -> void:
	var sender = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	start_recording_rpc.rpc_id(sender)

@rpc("authority", "call_local", "reliable")
func start_recording_rpc() -> void:
	is_recording = true
	recording_timer = RECORD_DURATION
	state = GameState.RECORDING

	# Bus luôn hoạt động; AudioEffectAmplify sau recorder chặn loa.
	AudioServer.set_bus_mute(record_bus_idx, false)

	# Start mic
	if not mic_player.playing:
		mic_player.play()

	# Start recording
	if record_effect:
		record_effect.set_recording_active(true)

	if record_button:
		record_button.text = "Recording... 3s"
		record_button.disabled = true
	if listen_button:
		listen_button.disabled = true
	if replay_button:
		replay_button.disabled = true

	print("[Mimic] Recording started")

func _stop_recording() -> void:
	is_recording = false
	state = GameState.PREPARING

	# Stop recording
	if record_effect and record_effect.is_recording_active():
		record_effect.set_recording_active(false)
		recording_data = record_effect.get_recording()

	# Stop mic. Bus vẫn unmuted: silencer giữ loa im lặng.
	if mic_player.playing:
		mic_player.stop()

	if record_button:
		record_button.text = "Record Again"
		record_button.disabled = false
	if listen_button:
		listen_button.disabled = false

	# Process recording
	if recording_data:
		_process_wav_recording(recording_data)
	else:
		print("[Mimic] No recording data!")

func _process_wav_recording(wav: AudioStreamWAV) -> void:
	# Keep the rate produced by AudioEffectRecord. Rewriting it changes pitch/speed.
	if wav.mix_rate <= 0:
		wav.mix_rate = AudioServer.get_mix_rate()

	# Lưu WAV trực tiếp (không convert)
	my_recording_wav = wav
	my_recording = _audio_stream_to_mono_sync(wav)

	# Enable replay
	if replay_button:
		replay_button.disabled = false

	# Check audio level
	var max_sample = 0.0
	for s in my_recording:
		max_sample = max(max_sample, abs(s))

	print("[Mimic] Recorded %d samples, mix_rate: %d, max level: %.4f" % [my_recording.size(), wav.mix_rate, max_sample])

func _audio_stream_to_mono_sync(stream: AudioStream) -> PackedFloat32Array:
	if stream is AudioStreamWAV:
		var wav = stream as AudioStreamWAV
		var mono = PackedFloat32Array()
		var data = wav.data
		for i in range(0, data.size(), 2):
			if i + 1 < data.size():
				var sample_16 = data[i] | (data[i + 1] << 8)
				if sample_16 >= 32768:
					sample_16 -= 65536
				mono.append(float(sample_16) / 32768.0)
		return mono
	elif stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		# MP3/OGG: không hỗ trợ sync, return empty
		push_warning("[Mimic] MP3/OGG not supported for sync conversion")
		return PackedFloat32Array()
	return PackedFloat32Array()

func _process_recording(buffer: PackedVector2Array) -> void:
	# Deprecated - using AudioEffectRecord now
	pass

@rpc("authority", "call_local", "reliable")
func request_final_submissions() -> void:
	# Client submit bản ghi cuối cùng
	if my_recording.is_empty() or not my_recording_wav:
		print("[Mimic] No recording to submit")
		return

	# Extract features
	var features = VoiceAnalyzer.create_features()
	features.pitch_contour = VoiceAnalyzer.extract_pitch_contour(my_recording, 44100)
	features.envelope = VoiceAnalyzer.extract_envelope(my_recording)
	features.onsets = VoiceAnalyzer.extract_onsets(my_recording)

	# Send WAV bytes gốc + mix_rate
	var my_id = multiplayer.get_unique_id()
	submit_recording.rpc_id(1, my_id, my_recording_wav.data, my_recording_wav.mix_rate, features.pitch_contour, features.envelope, features.onsets)

@rpc("any_peer", "call_local", "reliable")
func submit_recording(peer_id: int, wav_bytes: PackedByteArray, mix_rate: int, pitch: Array, envelope: float, onsets: Array) -> void:
	if not multiplayer.is_server():
		return

	var features = VoiceAnalyzer.create_features()
	features.pitch_contour = pitch.duplicate()
	features.envelope = envelope
	features.onsets = onsets.duplicate()

	# Reconstruct WAV từ bytes gốc + mix_rate từ client
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = wav_bytes

	# Convert WAV bytes → float array cho scoring
	var audio = PackedFloat32Array()
	for i in range(0, wav_bytes.size(), 2):
		if i + 1 < wav_bytes.size():
			var sample_16 = wav_bytes[i] | (wav_bytes[i + 1] << 8)
			if sample_16 >= 32768:
				sample_16 -= 65536
			audio.append(float(sample_16) / 32768.0)

	player_recordings[peer_id] = {
		"audio": audio,
		"features": features,
		"wav": wav,
		"wav_bytes": wav_bytes,
		"mix_rate": mix_rate
	}

	print("[Mimic] Submission %d/%d" % [player_recordings.size(), players.size()])

func _start_judging_phase() -> void:
	if not multiplayer.is_server():
		return
	state = GameState.JUDGING
	sync_game_state.rpc(GameState.JUDGING)
	judging_index = 0
	_judge_next_player()

func _judge_next_player() -> void:
	if not multiplayer.is_server():
		return

	var peer_ids = player_recordings.keys()
	if judging_index >= peer_ids.size():
		_finish_round()
		return

	var peer_id = peer_ids[judging_index]
	var recording = player_recordings[peer_id]

	# Extract sample features (sync - cached)
	if not sample_features_cached:
		var sample_mono = _audio_stream_to_mono_sync(sample_audio)
		sample_features_cached = VoiceAnalyzer.create_features()
		sample_features_cached.pitch_contour = VoiceAnalyzer.extract_pitch_contour(sample_mono, 44100)
		sample_features_cached.envelope = VoiceAnalyzer.extract_envelope(sample_mono)
		sample_features_cached.onsets = VoiceAnalyzer.extract_onsets(sample_mono)

	# Compare
	var score = VoiceAnalyzer.compare_voices(sample_features_cached, recording.features)
	player_scores[peer_id].scores.append(score)
	player_scores[peer_id].total += score

	# Broadcast score + audio (use WAV bytes + mix_rate để tránh re-encode)
	show_player_performance.rpc(peer_id, score, player_recordings[peer_id].wav_bytes, player_recordings[peer_id].mix_rate)

	# Calculate performance time: audio + 2s show + 1s tween back
	var audio_data = player_recordings[peer_id].wav_bytes
	var sample_count = audio_data.size() / 2  # 16-bit = 2 bytes
	var audio_duration = float(sample_count) / float(player_recordings[peer_id].mix_rate)
	var total_performance_time = audio_duration + 2.0 + 1.0

	# Wait for this player to finish complete performance
	await get_tree().create_timer(total_performance_time).timeout

	judging_index += 1
	_judge_next_player()

@rpc("authority", "call_local", "reliable")
func show_player_performance(peer_id: int, score: int, wav_bytes: PackedByteArray, mix_rate: int) -> void:
	var stream: AudioStreamWAV

	# Nếu là bản ghi của chính mình, dùng my_recording_wav gốc (không reconstruct)
	if peer_id == multiplayer.get_unique_id() and my_recording_wav:
		stream = my_recording_wav
	else:
		# Reconstruct từ bytes (người khác)
		stream = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = mix_rate
		stream.stereo = false
		stream.data = wav_bytes

	# Get original spawn position
	var original_pos = player_spawn_positions.get(peer_id, Vector3.ZERO)

	# Move player to center stage first
	if peer_id in players and is_instance_valid(players[peer_id]):
		var player = players[peer_id]
		var tween = create_tween()
		tween.tween_property(player, "position", Vector3(0, 0.5, 0), 1.0)
		await tween.finished

	# Play audio after reaching center
	if playback_player and stream:
		playback_player.stream = stream
		playback_player.play()
		await playback_player.finished

	# Only reveal score after the recording finishes
	if instruction_label:
		var p_name = player_scores.get(peer_id, {}).get("name", "Player")
		instruction_label.text = "%s\n%d / 100" % [p_name, score]
		instruction_label.add_theme_font_size_override("font_size", 48)
		await get_tree().create_timer(2.0).timeout

	# Move back to original spawn position
	if peer_id in players and is_instance_valid(players[peer_id]):
		var player = players[peer_id]
		var tween_back = create_tween()
		tween_back.tween_property(player, "position", original_pos, 1.0)
		await tween_back.finished

func _audio_stream_to_mono(stream: AudioStream) -> PackedFloat32Array:
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		# MP3/OGG không có raw data access, play và capture
		return await _capture_stream_playback(stream)
	if not stream is AudioStreamWAV:
		push_error("[Mimic] Unsupported stream type")
		return PackedFloat32Array()

	var wav = stream as AudioStreamWAV
	var mono = PackedFloat32Array()
	var data = stream.data
	for i in range(0, data.size(), 2):
		if i + 1 < data.size():
			var sample_16 = data[i] | (data[i + 1] << 8)
			if sample_16 >= 32768:
				sample_16 -= 65536
			mono.append(float(sample_16) / 32768.0)
	return mono

func _capture_stream_playback(stream: AudioStream) -> PackedFloat32Array:
	# Play stream và capture output (cho MP3/OGG)
	var temp_player = AudioStreamPlayer.new()
	temp_player.stream = stream
	temp_player.bus = "Record"
	add_child(temp_player)

	temp_player.play()
	await temp_player.finished
	temp_player.queue_free()
	return PackedFloat32Array()

func _finish_round() -> void:
	if not multiplayer.is_server():
		return

	player_recordings.clear()
	sample_features_cached.clear()

	# Reset player positions
	var spawn_positions = [
		Vector3(-6, 0.5, 0),
		Vector3(-2, 0.5, 0),
		Vector3(2, 0.5, 0),
		Vector3(6, 0.5, 0)
	]
	var idx = 0
	for peer_id in players:
		if is_instance_valid(players[peer_id]):
			players[peer_id].position = spawn_positions[idx % spawn_positions.size()]
			idx += 1

	# Reset recordings
	reset_recordings.rpc()
	player_recordings.clear()
	is_finishing_preparation = false

	if current_round >= ROUNDS:
		_end_game()
	else:
		current_round += 1
		sync_round.rpc(current_round)
		state = GameState.LISTENING
		sync_game_state.rpc(GameState.LISTENING)
		_start_listening_phase()

@rpc("authority", "call_local", "reliable")
func reset_recordings() -> void:
	my_recording.clear()
	if replay_button:
		replay_button.disabled = true

func _end_game() -> void:
	if not multiplayer.is_server():
		return
	state = GameState.ENDED
	sync_game_state.rpc(GameState.ENDED)

	# Find winner
	var winner_id = -1
	var max_score = -1
	for peer_id in player_scores:
		if player_scores[peer_id].total > max_score:
			max_score = player_scores[peer_id].total
			winner_id = peer_id

	show_winner.rpc(winner_id, max_score)

@rpc("authority", "call_local", "reliable")
func show_winner(winner_id: int, score: int) -> void:
	if winner_banner and winner_label:
		var winner_name = player_scores.get(winner_id, {}).get("name", "Unknown")
		winner_label.text = "%s wins with %d points!" % [winner_name, score]
		winner_banner.visible = true

func _on_return_pressed() -> void:
	if not multiplayer.is_server():
		return_to_lobby_request.rpc_id(1)
	else:
		_return_to_lobby()

@rpc("any_peer", "reliable")
func return_to_lobby_request() -> void:
	if not multiplayer.is_server():
		return
	_return_to_lobby()

func _return_to_lobby() -> void:
	if not multiplayer.is_server() or is_returning:
		return
	is_returning = true
	set_process(false)
	prepare_return_to_lobby.rpc()
	await get_tree().create_timer(0.1).timeout
	return_to_lobby.rpc()
	get_tree().change_scene_to_file("res://scenes/core/main.tscn")

@rpc("authority", "call_local", "reliable")
func prepare_return_to_lobby() -> void:
	is_returning = true
	set_process(false)

@rpc("authority", "call_local", "reliable")
func return_to_lobby() -> void:
	if not multiplayer.is_server():
		get_tree().change_scene_to_file("res://scenes/core/main.tscn")

func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id in players:
		var player = players[peer_id]
		if is_instance_valid(player):
			remove_child(player)
			player.queue_free()
		players.erase(peer_id)
	player_scores.erase(peer_id)
	player_recordings.erase(peer_id)
