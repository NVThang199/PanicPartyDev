extends Node3D

enum GameState { INITIALIZING, LISTENING, PREPARING, RECORDING, JUDGING, ENDED }

const PLAYER_SCENE = preload("res://scenes/players/player.tscn")
const ROUNDS = 3
const NUM_WAVEFORM_BARS = 120

# Karaoke lead-in/lead-out padding (giây)
const LEAD_IN = 0.8
const LEAD_OUT = 0.8

var state: GameState = GameState.INITIALIZING
var players: Dictionary = {}
var player_scores: Dictionary = {}
var current_round: int = 0
var current_sample_path: String = ""
var sample_audio: AudioStreamWAV = null
var sample_duration: float = 3.0
var total_recording_duration: float = 4.6
var sample_mono_data: PackedFloat32Array = PackedFloat32Array()
var _sample_bars: PackedFloat32Array = PackedFloat32Array()
var player_recordings: Dictionary = {}
var judging_index: int = 0
var is_returning: bool = false
var is_finishing_preparation: bool = false
var player_spawn_positions: Dictionary = {}

var _sample_pool: Array = []
var _used_samples: Array = []

var tutorial_overlay: PanelContainer = null
var tutorial_countdown_label: Label = null
var tutorial_timer: float = 5.0
var is_showing_tutorial: bool = false
var round_scoreboard_overlay: PanelContainer = null
var round_scoreboard_title: Label = null
var round_scoreboard_list: VBoxContainer = null
var round_scoreboard_status: Label = null
var round_scoreboard_return_btn: Button = null

@onready var sample_player: AudioStreamPlayer = $SamplePlayer
@onready var playback_player: AudioStreamPlayer = $PlaybackPlayer
@onready var countdown_label: Label = $UI/CountdownLabel
@onready var round_label: Label = $UI/RoundLabel
@onready var instruction_label: Label = $UI/InstructionLabel
@onready var score_label: Label = $UI/ScoreLabel
@onready var waveform_panel: PanelContainer = $UI/WaveformPanel
@onready var waveform_display: WaveformDisplay = $UI/WaveformPanel/WaveformDisplay
@onready var listen_button: Button = $UI/ControlPanel/ListenButton
@onready var record_button: Button = $UI/ControlPanel/RecordButton
@onready var replay_button: Button = $UI/ControlPanel/ReplayButton
@onready var scoreboard: PanelContainer = $UI/Scoreboard
@onready var scoreboard_vbox: VBoxContainer = $UI/Scoreboard/Margin/VBox
@onready var winner_banner: PanelContainer = $UI/WinnerBanner
@onready var winner_label: Label = $UI/WinnerBanner/Margin/VBox/WinnerLabel
@onready var return_button: Button = $UI/WinnerBanner/Margin/VBox/ReturnButton

var record_bus_idx: int = -1
var mic_player: AudioStreamPlayer = AudioStreamPlayer.new()
var record_effect: AudioEffectRecord = null
var capture_effect: AudioEffectCapture = null
var output_silencer: AudioEffectAmplify = null

var recording_data: AudioStreamWAV = null
var my_recording_wav: AudioStreamWAV = null
var sample_features_cached: Dictionary = {}
var is_recording: bool = false
var is_replaying: bool = false
var is_listening_preview: bool = false
var last_record_bar_idx: int = 0
var recording_timer: float = 0.0
var listen_preview_timer: float = 0.0
var listen_sample_started: bool = false
var countdown_timer: float = 0.0
var preparation_timer: float = 0.0
var my_recording: PackedFloat32Array = PackedFloat32Array()
var my_recorded_bars: PackedFloat32Array = PackedFloat32Array()
var is_countdown_active: bool = false
var _sample_peak: float = 1.0

func _ready() -> void:
	if has_node("Camera3D"):
		var cam = $Camera3D
		cam.position = Vector3(0.0, 4.8, 11.5)
		cam.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
		cam.fov = 48.0
		cam.current = true

	if winner_banner:
		winner_banner.visible = false
	if scoreboard:
		scoreboard.visible = false
	if score_label:
		score_label.visible = false
	if waveform_panel:
		waveform_panel.visible = false
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

	add_child(mic_player)

	if OS.request_permission("RECORD_AUDIO"):
		print("[Mimic] Microphone permission granted")
	else:
		push_warning("[Mimic] Microphone permission denied or not requested")

	_create_tutorial_overlay()
	_create_round_scoreboard_overlay()

	var saved_in_dev = SettingsManager.get_setting("audio", "input_device")
	var input_devices = AudioServer.get_input_device_list()
	if saved_in_dev != "" and saved_in_dev != "Default" and saved_in_dev in input_devices:
		AudioServer.input_device = saved_in_dev
	elif input_devices.size() > 0:
		AudioServer.input_device = input_devices[0]

	_setup_audio_capture()

	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.bus = "Record"
	mic_player.autoplay = false
	mic_player.volume_db = 0.0

	if multiplayer.is_server():
		call_deferred("initialize_game")
	else:
		request_game_sync.rpc_id(1)

func _setup_audio_capture() -> void:
	record_bus_idx = AudioServer.get_bus_index("Record")
	if record_bus_idx == -1:
		record_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(record_bus_idx)
		AudioServer.set_bus_name(record_bus_idx, "Record")

	AudioServer.set_bus_send(record_bus_idx, "Master")
	AudioServer.set_bus_mute(record_bus_idx, false)

	record_effect = null
	capture_effect = null
	output_silencer = null
	var effect_count = AudioServer.get_bus_effect_count(record_bus_idx)
	for i in range(effect_count):
		var effect = AudioServer.get_bus_effect(record_bus_idx, i)
		if effect is AudioEffectRecord:
			record_effect = effect
		elif effect is AudioEffectCapture:
			capture_effect = effect
		elif effect is AudioEffectAmplify:
			output_silencer = effect

	if not record_effect:
		record_effect = AudioEffectRecord.new()
		AudioServer.add_bus_effect(record_bus_idx, record_effect, 0)

	if not capture_effect:
		capture_effect = AudioEffectCapture.new()
		AudioServer.add_bus_effect(record_bus_idx, capture_effect, 1)

	if not output_silencer:
		output_silencer = AudioEffectAmplify.new()
		AudioServer.add_bus_effect(record_bus_idx, output_silencer)
	output_silencer.volume_db = -80.0

	if mic_player:
		mic_player.volume_db = 0.0
		if not mic_player.playing:
			mic_player.play()

	if sample_player:
		sample_player.bus = "Master"

func initialize_game() -> void:
	var minigame_data = GameSession.minigame_players
	if minigame_data.is_empty():
		push_error("[Mimic] No player data from GameSession")
		return

	var spawn_positions = [
		Vector3(-3.6, 0.0, -1.8),
		Vector3(-1.2, 0.0, -1.8),
		Vector3(1.2, 0.0, -1.8),
		Vector3(3.6, 0.0, -1.8)
	]
	var idx = 0

	for peer_id in minigame_data:
		var info = minigame_data[peer_id]
		var col: Color = info.get("color", Color.WHITE)
		var face: String = info.get("face", "res://assets/characters/face/robloxmanface.png")
		var hat: String = info.get("hat", "")
		var pos = spawn_positions[idx % spawn_positions.size()]
		player_spawn_positions[peer_id] = pos
		spawn_player.rpc(peer_id, info.character, info.name, info.steam_id, pos, col, face, hat)
		player_scores[peer_id] = {
			"name": info.name,
			"scores": [],
			"total": 0
		}
		idx += 1

	_build_sample_pool()
	_load_next_sample()

	current_round = 1
	sync_round.rpc(current_round)

	show_tutorial_rpc.rpc()
	await get_tree().create_timer(5.0).timeout
	hide_tutorial_rpc.rpc()

	state = GameState.LISTENING
	sync_game_state.rpc(GameState.LISTENING)
	_start_listening_phase()

func _build_sample_pool() -> void:
	_sample_pool.clear()
	_used_samples.clear()
	var dir = DirAccess.open("res://assets/audio/mimic/")
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".wav") or file_name.ends_with(".ogg"):
			_sample_pool.append("res://assets/audio/mimic/" + file_name)
		file_name = dir.get_next()
	_sample_pool.shuffle()

func _load_next_sample() -> void:
	if _sample_pool.is_empty():
		_sample_pool = _used_samples.duplicate()
		_sample_pool.shuffle()
		_used_samples.clear()

	if _sample_pool.is_empty():
		_make_fallback_sample()
		return

	current_sample_path = _sample_pool.pop_back()
	_used_samples.append(current_sample_path)
	sample_audio = load(current_sample_path) as AudioStreamWAV
	if not sample_audio:
		push_error("[Mimic] Failed to load audio: " + current_sample_path)
		_make_fallback_sample()
		return

	_setup_sample_data()

func _make_fallback_sample() -> void:
	current_sample_path = ""
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.stereo = false
	var freq = 440.0
	var dur = 1.5
	var sample_count = int(dur * 44100)
	var data = PackedByteArray()
	for i in range(sample_count):
		var t = float(i) / 44100.0
		var val = sin(2.0 * PI * freq * t) * 0.5
		var s16 = int(clamp(val * 32767, -32768, 32767))
		data.append(s16 & 0xFF)
		data.append((s16 >> 8) & 0xFF)
	wav.data = data
	sample_audio = wav
	_setup_sample_data()

func _setup_sample_data() -> void:
	sample_mono_data = _audio_stream_to_mono_sync(sample_audio)
	sample_duration = float(sample_mono_data.size()) / 44100.0
	total_recording_duration = sample_duration + LEAD_IN + LEAD_OUT

	# Tạo mảng bars có chèn khoảng đệm (padding) 0 ở đầu và cuối theo chuẩn karaoke
	_sample_bars = _extract_karaoke_amplitude_bars(sample_mono_data, NUM_WAVEFORM_BARS)

	var trimmed_sample = VoiceAnalyzer.trim_silence(sample_mono_data)
	sample_features_cached = VoiceAnalyzer.create_features()
	sample_features_cached.pitch_contour = VoiceAnalyzer.extract_pitch_contour(trimmed_sample, 44100)
	sample_features_cached.envelope = VoiceAnalyzer.extract_envelope(trimmed_sample)
	sample_features_cached.onsets = VoiceAnalyzer.extract_onsets(trimmed_sample)
	sample_features_cached.mfcc_frames = VoiceAnalyzer.extract_mfcc(trimmed_sample, 44100)
	sample_features_cached.is_voiced = true

	_sample_peak = 0.0
	for s in sample_mono_data:
		_sample_peak = max(_sample_peak, abs(s))
	_sample_peak = max(0.2, _sample_peak)

func _extract_karaoke_amplitude_bars(samples: PackedFloat32Array, num_bars: int = NUM_WAVEFORM_BARS) -> PackedFloat32Array:
	var bars = PackedFloat32Array()
	bars.resize(num_bars)
	for i in range(num_bars):
		bars[i] = 0.0

	if samples.is_empty():
		return bars

	var lead_in_bars = int(round(NUM_WAVEFORM_BARS * (LEAD_IN / total_recording_duration)))
	var lead_out_bars = int(round(NUM_WAVEFORM_BARS * (LEAD_OUT / total_recording_duration)))
	var sample_bars_count = NUM_WAVEFORM_BARS - lead_in_bars - lead_out_bars
	sample_bars_count = maxi(10, sample_bars_count)

	var chunk_size = int(ceil(float(samples.size()) / float(sample_bars_count)))
	var max_peak = 0.001
	var temp_peaks = PackedFloat32Array()
	temp_peaks.resize(sample_bars_count)

	for b in range(sample_bars_count):
		var start_idx = b * chunk_size
		var end_idx = mini(start_idx + chunk_size, samples.size())
		var peak = 0.0
		for i in range(start_idx, end_idx):
			peak = max(peak, abs(samples[i]))
		temp_peaks[b] = peak
		max_peak = max(max_peak, peak)

	for b in range(sample_bars_count):
		var target_idx = lead_in_bars + b
		if target_idx < num_bars:
			var val = temp_peaks[b] / max_peak if max_peak > 0.001 else 0.0
			bars[target_idx] = clampf(pow(val, 0.5), 0.05, 1.0) if val > 0.01 else 0.0

	return bars

@rpc("any_peer", "reliable")
func request_game_sync() -> void:
	if not multiplayer.is_server():
		return
	var caller_id = multiplayer.get_remote_sender_id()
	if caller_id == 0:
		caller_id = multiplayer.get_unique_id()

	sync_game_state.rpc_id(caller_id, state)
	sync_round.rpc_id(caller_id, current_round)
	sync_sample_info.rpc_id(caller_id, current_sample_path)

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
func sync_sample_info(path: String) -> void:
	current_sample_path = path
	if path != "":
		sample_audio = load(path) as AudioStreamWAV
		if sample_audio:
			_setup_sample_data()

@rpc("authority", "call_local", "reliable")
func spawn_player(peer_id: int, character_path: String, player_name: String, steam_id: int, pos: Vector3, color: Color = Color.WHITE, face: String = "res://assets/characters/face/robloxmanface.png", hat: String = "") -> void:
	player_spawn_positions[peer_id] = pos
	player_scores[peer_id] = {
		"name": player_name,
		"scores": [],
		"total": 0
	}
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

	player.set_physics_process(false)
	var model_node = player.get_node_or_null("Model")
	if model_node:
		model_node.rotation.y = 0.0

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
	_hide_waveform_rpc.rpc()
	update_instruction.rpc("Get ready! Sample will play in...")
	start_countdown.rpc(3.0)

@rpc("authority", "call_local", "reliable")
func _hide_waveform_rpc() -> void:
	_stop_listen_preview()
	if waveform_panel:
		waveform_panel.visible = false
	if waveform_display:
		waveform_display.clear_all()

func _stop_listen_preview() -> void:
	if is_listening_preview:
		is_listening_preview = false
		listen_sample_started = false
		if sample_player and sample_player.playing:
			sample_player.stop()
		if waveform_display:
			waveform_display.set_playhead(-1.0)

func _process(delta: float) -> void:
	if not is_inside_tree():
		return

	if is_showing_tutorial:
		tutorial_timer -= delta
		if tutorial_countdown_label:
			tutorial_countdown_label.text = "%d" % max(1, int(ceil(tutorial_timer)))

	if is_countdown_active:
		countdown_timer -= delta
		if countdown_label:
			countdown_label.text = "%d" % max(0, int(ceil(countdown_timer)))
			countdown_label.visible = countdown_timer > 0
		if countdown_timer <= 0:
			is_countdown_active = false
			countdown_label.visible = false

	# ─── Đang ghi âm: thanh trượt chạy theo thời gian thực (dynamic duration) ───
	if is_recording:
		recording_timer -= delta
		var elapsed = total_recording_duration - recording_timer
		var ratio = clampf(elapsed / total_recording_duration, 0.0, 1.0)

		if record_button:
			record_button.text = "Recording... %ds" % max(0, int(ceil(recording_timer)))

		if waveform_display:
			waveform_display.set_playhead(ratio)

			var peak: float = 0.0
			if capture_effect and capture_effect.get_frames_available() > 0:
				var frames = capture_effect.get_buffer(capture_effect.get_frames_available())
				for f in frames:
					var val = absf(f.x)
					if val > peak:
						peak = val

			var norm_amp = clampf(peak * 3.5, 0.0, 1.0)
			var bar_idx = clampi(int(ratio * NUM_WAVEFORM_BARS), 0, NUM_WAVEFORM_BARS - 1)
			if bar_idx >= last_record_bar_idx:
				for b in range(last_record_bar_idx, bar_idx + 1):
					waveform_display.update_recording_bar(b, norm_amp)
				last_record_bar_idx = bar_idx + 1

		if recording_timer <= 0:
			_stop_recording()

	elif is_listening_preview:
		listen_preview_timer -= delta
		var elapsed = total_recording_duration - listen_preview_timer
		var ratio = clampf(elapsed / total_recording_duration, 0.0, 1.0)

		if waveform_display:
			waveform_display.set_playhead(ratio)

		if not listen_sample_started and elapsed >= LEAD_IN:
			listen_sample_started = true
			if sample_player and sample_audio:
				sample_player.stream = sample_audio
				sample_player.play()

		if listen_preview_timer <= 0:
			_stop_listen_preview()

	elif is_replaying:
		if playback_player and playback_player.playing and my_recording_wav:
			var total_len = maxf(0.1, my_recording_wav.get_length())
			var cur_pos = playback_player.get_playback_position()
			var ratio = clampf(cur_pos / total_len, 0.0, 1.0)
			if waveform_display:
				waveform_display.set_playhead(ratio)
		else:
			is_replaying = false
			if waveform_display:
				waveform_display.set_playhead(-1.0)

	match state:
		GameState.PREPARING:
			if multiplayer.is_server():
				preparation_timer -= delta
				sync_preparation_timer.rpc(preparation_timer)
				if preparation_timer <= 0:
					_finish_preparation()
			if instruction_label:
				instruction_label.text = "Prepare your recording! Time: %ds" % max(0, int(preparation_timer))

@rpc("authority", "unreliable")
func sync_preparation_timer(time: float) -> void:
	preparation_timer = time

@rpc("authority", "call_local", "reliable")
func start_countdown(duration: float) -> void:
	countdown_timer = duration
	is_countdown_active = true
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
		if not record and not is_recording:
			record_button.text = "Record"
	if replay_button:
		replay_button.disabled = not replay

func _play_sample() -> void:
	if not multiplayer.is_server():
		return
	play_sample_rpc.rpc(current_sample_path)

@rpc("authority", "call_local", "reliable")
func play_sample_rpc(sample_path: String) -> void:
	AudioServer.set_bus_mute(record_bus_idx, true)
	if sample_path != "":
		current_sample_path = sample_path
		sample_audio = load(sample_path) as AudioStreamWAV
		if sample_audio:
			_setup_sample_data()

	if sample_player and sample_audio:
		sample_player.stream = sample_audio
		sample_player.play()
		if multiplayer.is_server():
			update_instruction.rpc("Listening to sample...")

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

	# ─── Hiện thanh sóng âm ngay từ lúc chuẩn bị (Karaoke style) ─────────
	show_preparation_waveform.rpc(current_sample_path)

@rpc("authority", "call_local", "reliable")
func show_preparation_waveform(sample_path: String) -> void:
	if sample_path != "" and sample_path != current_sample_path:
		current_sample_path = sample_path
		sample_audio = load(sample_path) as AudioStreamWAV
		if sample_audio:
			_setup_sample_data()

	if waveform_panel:
		waveform_panel.visible = true
	if waveform_display:
		var start_r = LEAD_IN / total_recording_duration
		var end_r = (LEAD_IN + sample_duration) / total_recording_duration
		waveform_display.reset_recording(NUM_WAVEFORM_BARS)
		waveform_display.set_sample_bars(_sample_bars, start_r, end_r)
		waveform_display.set_playhead(-1.0)  # Chưa ghi nên chưa có playhead

func _finish_preparation() -> void:
	if not multiplayer.is_server() or is_finishing_preparation:
		return
	is_finishing_preparation = true
	enable_buttons.rpc(false, false, false)
	_hide_waveform_rpc.rpc()
	update_instruction.rpc("Submitting recordings...")
	request_final_submissions.rpc()
	print("[Mimic] Checking submissions: %d/%d" % [player_recordings.size(), players.size()])

	# Đợi nhận đủ packet từ các client (tối đa 1.5 giây)
	var wait_time = 0.0
	while player_recordings.size() < players.size() and wait_time < 1.5:
		await get_tree().create_timer(0.1).timeout
		wait_time += 0.1

	_start_judging_phase()

func _on_listen_pressed() -> void:
	AudioServer.set_bus_mute(record_bus_idx, true)
	_stop_listen_preview()
	is_replaying = false
	is_listening_preview = true
	listen_preview_timer = total_recording_duration
	listen_sample_started = false

	if waveform_panel:
		waveform_panel.visible = true
	if waveform_display:
		var start_r = LEAD_IN / total_recording_duration
		var end_r = (LEAD_IN + sample_duration) / total_recording_duration
		waveform_display.reset_recording(NUM_WAVEFORM_BARS)
		waveform_display.set_sample_bars(_sample_bars, start_r, end_r)
		waveform_display.set_playhead(0.0)

func _on_replay_pressed() -> void:
	if not my_recording_wav:
		print("[Mimic] No recording to replay")
		return
	_stop_listen_preview()

	if playback_player:
		var rec_peak = 0.0
		for s in my_recording:
			rec_peak = max(rec_peak, abs(s))
		if rec_peak > 0.001:
			var gain = clampf(_sample_peak / rec_peak, 0.5, 6.0)
			playback_player.volume_db = linear_to_db(gain)
		else:
			playback_player.volume_db = 0.0

		playback_player.stream = my_recording_wav
		playback_player.play()

		if waveform_panel:
			waveform_panel.visible = true
		if waveform_display:
			var start_r = LEAD_IN / total_recording_duration
			var end_r = (LEAD_IN + sample_duration) / total_recording_duration
			waveform_display.set_sample_bars(_sample_bars, start_r, end_r)
			if not my_recorded_bars.is_empty():
				waveform_display.set_recording_bars(my_recorded_bars)
			waveform_display.set_playhead(0.0)
		is_replaying = true

func _on_record_pressed() -> void:
	if is_recording:
		return
	_stop_listen_preview()
	var my_id = multiplayer.get_unique_id()
	if my_id == 1:
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
	_stop_listen_preview()
	is_recording = true
	is_replaying = false
	recording_timer = total_recording_duration
	last_record_bar_idx = 0

	if waveform_panel:
		waveform_panel.visible = true
	if waveform_display:
		var start_r = LEAD_IN / total_recording_duration
		var end_r = (LEAD_IN + sample_duration) / total_recording_duration
		waveform_display.reset_recording(NUM_WAVEFORM_BARS)
		waveform_display.set_sample_bars(_sample_bars, start_r, end_r)
		waveform_display.set_playhead(0.0)

	AudioServer.set_bus_mute(record_bus_idx, false)

	if not mic_player.playing:
		mic_player.play()

	if record_effect:
		record_effect.set_recording_active(true)
	if capture_effect:
		capture_effect.clear_buffer()

	if record_button:
		record_button.text = "Recording... %.1fs" % total_recording_duration
		record_button.disabled = true
	if listen_button:
		listen_button.disabled = true
	if replay_button:
		replay_button.disabled = true

	print("[Mimic] Recording started, duration: %.2fs" % total_recording_duration)

func _stop_recording() -> void:
	is_recording = false

	if record_effect and record_effect.is_recording_active():
		record_effect.set_recording_active(false)
		recording_data = record_effect.get_recording()

	if mic_player.playing:
		mic_player.stop()

	if record_button:
		record_button.text = "Record Again"
		record_button.disabled = false
	if listen_button:
		listen_button.disabled = false

	if recording_data:
		_process_wav_recording(recording_data)
	else:
		print("[Mimic] No recording data!")

func _process_wav_recording(wav: AudioStreamWAV) -> void:
	if wav.mix_rate <= 0:
		wav.mix_rate = int(AudioServer.get_mix_rate())

	my_recording_wav = wav
	my_recording = _audio_stream_to_mono_sync(wav)

	if replay_button:
		replay_button.disabled = false

	if waveform_display:
		my_recorded_bars = waveform_display.recording_bars.duplicate()
		waveform_display.set_playhead(-1.0)

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
		return PackedFloat32Array()
	return PackedFloat32Array()

@rpc("authority", "call_local", "reliable")
func request_final_submissions() -> void:
	if is_recording:
		_stop_recording()
	if my_recording.is_empty() or not my_recording_wav:
		print("[Mimic] No recording to submit")
		return

	var features = VoiceAnalyzer.create_features()
	features.pitch_contour = VoiceAnalyzer.extract_pitch_contour(my_recording, 44100)
	features.envelope = VoiceAnalyzer.extract_envelope(my_recording)
	features.onsets = VoiceAnalyzer.extract_onsets(my_recording)

	var my_id = multiplayer.get_unique_id()
	submit_recording.rpc_id(1, my_id, my_recording_wav.data, my_recording_wav.mix_rate, my_recording_wav.format, my_recording_wav.stereo, features.pitch_contour, features.envelope, features.onsets)

@rpc("any_peer", "call_local", "reliable")
func submit_recording(peer_id: int, wav_bytes: PackedByteArray, mix_rate: int, format: int, stereo: bool, pitch: Array, envelope: float, onsets: Array) -> void:
	if not multiplayer.is_server():
		return

	var features = VoiceAnalyzer.create_features()
	features.pitch_contour = pitch.duplicate()
	features.envelope = envelope
	features.onsets = onsets.duplicate()

	var wav = AudioStreamWAV.new()
	wav.format = format as AudioStreamWAV.Format
	wav.mix_rate = mix_rate
	wav.stereo = stereo
	wav.data = wav_bytes

	var audio = _audio_stream_to_mono_sync(wav)

	player_recordings[peer_id] = {
		"audio": audio,
		"features": features,
		"wav": wav,
		"wav_bytes": wav_bytes,
		"mix_rate": mix_rate,
		"format": format,
		"stereo": stereo
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

	sample_features_cached.clear()
	if sample_features_cached.is_empty():
		var mono = sample_mono_data
		if mono.is_empty():
			mono = _audio_stream_to_mono_sync(sample_audio)
		var trimmed_sample = VoiceAnalyzer.trim_silence(mono)
		sample_features_cached = VoiceAnalyzer.create_features()
		sample_features_cached.pitch_contour = VoiceAnalyzer.extract_pitch_contour(trimmed_sample, 44100)
		sample_features_cached.envelope = VoiceAnalyzer.extract_envelope(trimmed_sample)
		sample_features_cached.onsets = VoiceAnalyzer.extract_onsets(trimmed_sample)
		sample_features_cached.mfcc_frames = VoiceAnalyzer.extract_mfcc(trimmed_sample, 44100)
		sample_features_cached.is_voiced = true

	# Ensure player features & VAD are extracted server-side from raw audio
	var player_audio: PackedFloat32Array = recording.audio
	var is_voiced = VoiceAnalyzer.has_voice_activity(player_audio)
	recording.features.is_voiced = is_voiced
	if is_voiced:
		var trimmed_player = VoiceAnalyzer.trim_silence(player_audio)
		recording.features.mfcc_frames = VoiceAnalyzer.extract_mfcc(trimmed_player, recording.mix_rate)
		recording.features.pitch_contour = VoiceAnalyzer.extract_pitch_contour(trimmed_player, recording.mix_rate)
		recording.features.onsets = VoiceAnalyzer.extract_onsets(trimmed_player)
		recording.features.envelope = VoiceAnalyzer.extract_envelope(trimmed_player)

	var result = VoiceAnalyzer.compare_voices(sample_features_cached, recording.features)
	var score: int = result.get("score", 0)
	var reason: String = result.get("reason", "")
	player_scores[peer_id].scores.append(score)
	player_scores[peer_id].total += score

	var rec = player_recordings[peer_id]
	show_player_performance.rpc(peer_id, score, reason, rec.wav_bytes, rec.mix_rate, rec.format, rec.stereo)

	var audio_data = player_recordings[peer_id].wav_bytes
	var sample_count = audio_data.size() / 2
	var audio_duration = float(sample_count) / float(player_recordings[peer_id].mix_rate)
	var total_performance_time = audio_duration + 2.5 + 1.0

	await get_tree().create_timer(total_performance_time).timeout

	judging_index += 1
	_judge_next_player()

@rpc("authority", "call_local", "reliable")
func show_player_performance(peer_id: int, score: int, reason: String, wav_bytes: PackedByteArray, mix_rate: int, format: int = AudioStreamWAV.FORMAT_16_BITS, stereo: bool = false) -> void:
	if score_label:
		score_label.visible = false

	var stream: AudioStreamWAV
	if peer_id == multiplayer.get_unique_id() and my_recording_wav:
		stream = my_recording_wav
	else:
		stream = AudioStreamWAV.new()
		stream.format = format as AudioStreamWAV.Format
		stream.mix_rate = mix_rate
		stream.stereo = stereo
		stream.data = wav_bytes

	var original_pos = player_spawn_positions.get(peer_id, Vector3.ZERO)

	if peer_id in players and is_instance_valid(players[peer_id]):
		var player = players[peer_id]
		var model = player.get_node_or_null("Model")
		var stage_target = Vector3(0.0, 0.0, 1.2)

		if model:
			var dir = stage_target - player.position
			dir.y = 0.0
			if dir.length_squared() > 0.0001:
				model.rotation.y = atan2(dir.x, dir.z)

		player.play_anim("movement/Running_A")
		var tween = create_tween()
		tween.tween_property(player, "position", stage_target, 1.0)
		await tween.finished

		if model:
			model.rotation.y = 0.0
		player.play_anim("general/Idle_A")

	if playback_player and stream:
		var rec_peak = 0.0
		var rec_data = stream.data
		for i in range(0, rec_data.size(), 2):
			if i + 1 < rec_data.size():
				var s16 = rec_data[i] | (rec_data[i + 1] << 8)
				if s16 >= 32768:
					s16 -= 65536
				rec_peak = max(rec_peak, abs(float(s16) / 32768.0))
		if rec_peak > 0.001:
			var gain = clampf(_sample_peak / rec_peak, 0.5, 6.0)
			playback_player.volume_db = linear_to_db(gain)
		else:
			playback_player.volume_db = 0.0

		playback_player.stream = stream
		playback_player.play()
		await playback_player.finished

	if score_label:
		var p_name = "Player"
		if peer_id in players and is_instance_valid(players[peer_id]) and players[peer_id].player_name != "":
			p_name = players[peer_id].player_name
		else:
			p_name = player_scores.get(peer_id, {}).get("name", "Player")
		if score == 0:
			var reason_text = "No Voice Detected!"
			if reason == "Wrong word":
				reason_text = "Wrong Word Spoken!"
			elif reason == "Wrong length":
				reason_text = "Wrong Duration / Gibberish!"
			elif reason == "Too quiet":
				reason_text = "Too Quiet!"
			score_label.text = "%s\n%s\n0 / 100" % [p_name, reason_text]
		else:
			score_label.text = "%s\n%d / 100" % [p_name, score]
		score_label.visible = true
		await get_tree().create_timer(2.5).timeout
		score_label.visible = false

	if peer_id in players and is_instance_valid(players[peer_id]):
		var player = players[peer_id]
		var model = player.get_node_or_null("Model")

		if model:
			var dir = original_pos - player.position
			dir.y = 0.0
			if dir.length_squared() > 0.0001:
				model.rotation.y = atan2(dir.x, dir.z)

		player.play_anim("movement/Running_A")
		var tween_back = create_tween()
		tween_back.tween_property(player, "position", original_pos, 1.0)
		await tween_back.finished

		if model:
			model.rotation.y = 0.0
		player.play_anim("general/Idle_A")

func _finish_round() -> void:
	if not multiplayer.is_server():
		return

	player_recordings.clear()
	sample_features_cached.clear()
	sample_mono_data = PackedFloat32Array()
	_sample_bars = PackedFloat32Array()

	var spawn_positions = [
		Vector3(-3.6, 0.0, -1.8),
		Vector3(-1.2, 0.0, -1.8),
		Vector3(1.2, 0.0, -1.8),
		Vector3(3.6, 0.0, -1.8)
	]
	var idx = 0
	for peer_id in players:
		if is_instance_valid(players[peer_id]):
			players[peer_id].position = spawn_positions[idx % spawn_positions.size()]
			idx += 1

	reset_recordings.rpc()
	player_recordings.clear()
	is_finishing_preparation = false

	if current_round >= ROUNDS:
		_end_game()
	else:
		current_round += 1
		sync_round.rpc(current_round)
		_load_next_sample()
		state = GameState.LISTENING
		sync_game_state.rpc(GameState.LISTENING)
		_start_listening_phase()

@rpc("authority", "call_local", "reliable")
func reset_recordings() -> void:
	my_recording.clear()
	my_recording_wav = null
	my_recorded_bars.clear()
	if replay_button:
		replay_button.disabled = true
	if waveform_display:
		waveform_display.reset_recording(NUM_WAVEFORM_BARS)

func _end_game() -> void:
	if not multiplayer.is_server():
		return
	state = GameState.ENDED
	sync_game_state.rpc(GameState.ENDED)

	var winner_id = -1
	var winner_name = "Unknown"
	var max_score = -1

	# Sắp xếp xếp hạng người chơi theo tổng điểm
	var ranked_peers = player_scores.keys()
	ranked_peers.sort_custom(func(a, b): return player_scores[a].total > player_scores[b].total)

	if not ranked_peers.is_empty():
		winner_id = ranked_peers[0]
		winner_name = player_scores[winner_id].get("name", "Unknown")
		max_score = player_scores[winner_id].total

	if GameSession.campaign_active:
		# Phân bổ điểm Campaign theo thứ hạng (1st: 1000, 2nd: 600, 3rd: 300, 4th: 100)
		var rank_pts = [1000, 600, 300, 100]
		for i in range(ranked_peers.size()):
			var pid = ranked_peers[i]
			var pts = rank_pts[i] if i < rank_pts.size() else 50
			GameSession.player_scores[pid] = GameSession.player_scores.get(pid, 0) + pts

		if winner_id != -1:
			GameSession.player_wins[winner_id] = GameSession.player_wins.get(winner_id, 0) + 1

		# Chuẩn bị danh sách hiển thị bảng điểm
		var entries = []
		for i in range(ranked_peers.size()):
			var pid = ranked_peers[i]
			entries.append({
				"rank": i + 1,
				"name": player_scores[pid].get("name", "Player"),
				"score": GameSession.player_scores.get(pid, 0)
			})

		var has_campaign_winner = false
		for pid in GameSession.player_scores:
			if GameSession.player_scores[pid] >= GameSession.target_score:
				has_campaign_winner = true
				break

		var status_msg = tr("NEXT_MINIGAME_IN") % 5 if not has_campaign_winner else tr("CAMPAIGN_FINISHED")
		show_round_scoreboard.rpc(tr("CAMPAIGN_SCOREBOARD"), entries, status_msg, has_campaign_winner)

		await get_tree().create_timer(5.0).timeout

		if has_campaign_winner:
			_return_to_lobby()
		else:
			_switch_to_next_minigame("res://scenes/minigames/hot_bomb/hot_bomb.tscn")
	else:
		show_winner.rpc(winner_id, winner_name, max_score)

func _switch_to_next_minigame(next_scene_path: String) -> void:
	if not multiplayer.is_server() or is_returning:
		return
	is_returning = true
	set_process(false)
	prepare_return_to_lobby.rpc()
	await get_tree().create_timer(0.1).timeout
	switch_minigame_rpc.rpc(next_scene_path)
	get_tree().change_scene_to_file(next_scene_path)

@rpc("authority", "call_local", "reliable")
func switch_minigame_rpc(scene_path: String) -> void:
	if not multiplayer.is_server():
		get_tree().change_scene_to_file(scene_path)

@rpc("authority", "call_local", "reliable")
func show_winner(winner_id: int, winner_name: String, score: int) -> void:
	if winner_banner and winner_label:
		if winner_name == "" or winner_name == "Unknown":
			if winner_id in players and is_instance_valid(players[winner_id]) and players[winner_id].player_name != "":
				winner_name = players[winner_id].player_name
			else:
				winner_name = player_scores.get(winner_id, {}).get("name", "Unknown")
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

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.06, 0.1, 0.94)
	tutorial_overlay.add_theme_stylebox_override("panel", bg_style)

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

	var title_lbl = Label.new()
	title_lbl.text = tr("MINIGAME_MIMIC")
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.modulate = Color(1.0, 0.85, 0.2)
	vbox.add_child(title_lbl)

	var img_container = AspectRatioContainer.new()
	img_container.ratio = 16.0 / 9.0
	img_container.custom_minimum_size = Vector2(440, 247)
	img_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(img_container)

	var img_rect = TextureRect.new()
	img_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex_path = "res://assets/ui/tutorial/mimic.png"
	var loaded_tex: Texture2D = null
	if ResourceLoader.exists(tex_path):
		loaded_tex = load(tex_path) as Texture2D
	if not loaded_tex:
		var img = Image.new()
		var abs_path = ProjectSettings.globalize_path(tex_path)
		if img.load(abs_path) == OK:
			loaded_tex = ImageTexture.create_from_image(img)
	if loaded_tex:
		img_rect.texture = loaded_tex
	img_container.add_child(img_rect)

	var rules_lbl = Label.new()
	rules_lbl.text = tr("MIMIC_RULES")
	rules_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(rules_lbl)

	var ctrl_lbl = Label.new()
	ctrl_lbl.text = tr("MIMIC_CONTROLS_HINT")
	ctrl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctrl_lbl.add_theme_font_size_override("font_size", 13)
	ctrl_lbl.modulate = Color(0.6, 0.9, 1.0)
	vbox.add_child(ctrl_lbl)

	var hsep = HSeparator.new()
	vbox.add_child(hsep)

	tutorial_countdown_label = Label.new()
	tutorial_countdown_label.text = "5"
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
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
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

@rpc("authority", "call_local", "reliable")
func show_tutorial_rpc() -> void:
	if tutorial_overlay:
		tutorial_overlay.visible = true
	tutorial_timer = 5.0
	is_showing_tutorial = true

@rpc("authority", "call_local", "reliable")
func hide_tutorial_rpc() -> void:
	if tutorial_overlay:
		tutorial_overlay.visible = false
	is_showing_tutorial = false

@rpc("authority", "call_local", "reliable")
func show_round_scoreboard(title: String, entries: Array, status_text: String, show_btn: bool) -> void:
	if not round_scoreboard_overlay:
		return
	round_scoreboard_title.text = title
	round_scoreboard_status.text = status_text
	round_scoreboard_return_btn.visible = show_btn

	for child in round_scoreboard_list.get_children():
		child.queue_free()

	for entry in entries:
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 16)

		var rank_lbl = Label.new()
		rank_lbl.text = "#%d" % entry.get("rank", 1)
		rank_lbl.custom_minimum_size = Vector2(40, 0)
		rank_lbl.add_theme_font_size_override("font_size", 16)
		row.add_child(rank_lbl)

		var name_lbl = Label.new()
		name_lbl.text = entry.get("name", "Player")
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 16)
		row.add_child(name_lbl)

		var pts_lbl = Label.new()
		pts_lbl.text = "%d pts" % entry.get("score", 0)
		pts_lbl.add_theme_font_size_override("font_size", 16)
		pts_lbl.modulate = Color(1.0, 0.85, 0.3)
		row.add_child(pts_lbl)

		round_scoreboard_list.add_child(row)

	round_scoreboard_overlay.visible = true
