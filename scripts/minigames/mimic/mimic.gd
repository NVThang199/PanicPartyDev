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

	var input_devices = AudioServer.get_input_device_list()
	if input_devices.size() > 0:
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
		Vector3(-6, 0.5, 0),
		Vector3(-2, 0.5, 0),
		Vector3(2, 0.5, 0),
		Vector3(6, 0.5, 0)
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

	state = GameState.LISTENING
	sync_game_state.rpc(GameState.LISTENING)
	current_round = 1
	sync_round.rpc(current_round)
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

	sample_features_cached = VoiceAnalyzer.create_features()
	sample_features_cached.pitch_contour = VoiceAnalyzer.extract_pitch_contour(sample_mono_data, 44100)
	sample_features_cached.envelope = VoiceAnalyzer.extract_envelope(sample_mono_data)
	sample_features_cached.onsets = VoiceAnalyzer.extract_onsets(sample_mono_data)

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
	if wav.mix_rate <= 0 or wav.mix_rate != 44100:
		wav.mix_rate = 44100

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
	submit_recording.rpc_id(1, my_id, my_recording_wav.data, my_recording_wav.mix_rate, features.pitch_contour, features.envelope, features.onsets)

@rpc("any_peer", "call_local", "reliable")
func submit_recording(peer_id: int, wav_bytes: PackedByteArray, mix_rate: int, pitch: Array, envelope: float, onsets: Array) -> void:
	if not multiplayer.is_server():
		return

	var features = VoiceAnalyzer.create_features()
	features.pitch_contour = pitch.duplicate()
	features.envelope = envelope
	features.onsets = onsets.duplicate()

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.stereo = false
	wav.data = wav_bytes

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

	if not sample_features_cached:
		var mono = sample_mono_data
		if mono.is_empty():
			mono = _audio_stream_to_mono_sync(sample_audio)
		sample_features_cached = VoiceAnalyzer.create_features()
		sample_features_cached.pitch_contour = VoiceAnalyzer.extract_pitch_contour(mono, 44100)
		sample_features_cached.envelope = VoiceAnalyzer.extract_envelope(mono)
		sample_features_cached.onsets = VoiceAnalyzer.extract_onsets(mono)

	var score = VoiceAnalyzer.compare_voices(sample_features_cached, recording.features)
	player_scores[peer_id].scores.append(score)
	player_scores[peer_id].total += score

	show_player_performance.rpc(peer_id, score, player_recordings[peer_id].wav_bytes, player_recordings[peer_id].mix_rate)

	var audio_data = player_recordings[peer_id].wav_bytes
	var sample_count = audio_data.size() / 2
	var audio_duration = float(sample_count) / float(player_recordings[peer_id].mix_rate)
	var total_performance_time = audio_duration + 2.5 + 1.0

	await get_tree().create_timer(total_performance_time).timeout

	judging_index += 1
	_judge_next_player()

@rpc("authority", "call_local", "reliable")
func show_player_performance(peer_id: int, score: int, wav_bytes: PackedByteArray, mix_rate: int) -> void:
	if score_label:
		score_label.visible = false

	var stream: AudioStreamWAV
	if peer_id == multiplayer.get_unique_id() and my_recording_wav:
		stream = my_recording_wav
	else:
		stream = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 44100
		stream.stereo = false
		stream.data = wav_bytes

	var original_pos = player_spawn_positions.get(peer_id, Vector3.ZERO)

	if peer_id in players and is_instance_valid(players[peer_id]):
		var player = players[peer_id]
		var model = player.get_node_or_null("Model")
		var stage_target = Vector3(0, 0.5, 3.0)

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
		var p_name = player_scores.get(peer_id, {}).get("name", "Player")
		score_label.text = "%s\n%d / 100" % [p_name, score]
		score_label.visible = true
		await get_timer_delay(2.5).timeout if false else await get_tree().create_timer(2.5).timeout
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

func get_timer_delay(t: float):
	return get_tree().create_timer(t)

func _finish_round() -> void:
	if not multiplayer.is_server():
		return

	player_recordings.clear()
	sample_features_cached.clear()
	sample_mono_data = PackedFloat32Array()
	_sample_bars = PackedFloat32Array()

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
