extends Node
class_name VoiceAnalyzer

# Feature container
static func create_features() -> Dictionary:
	return {
		"pitch_contour": [],
		"envelope": 0.0,
		"onsets": [],
		"mfcc_frames": [],
		"is_voiced": false,
		"rms_energy": 0.0
	}

# ─────────────────────────────────────────────────────────────────────────────
# 1. Voice Activity Detection (VAD)
# ─────────────────────────────────────────────────────────────────────────────

const MIN_ACTIVE_RMS = 0.015
const MIN_VOICED_FRAME_RATIO = 0.10

# Checks if audio buffer contains sufficient voice energy.
# Returns false for complete silence or absolute quiet.
static func has_voice_activity(samples: PackedFloat32Array) -> bool:
	if samples.is_empty():
		return false

	var total_sq := 0.0
	var max_peak := 0.0
	for s in samples:
		var abs_s = absf(s)
		if abs_s > max_peak:
			max_peak = abs_s
		total_sq += s * s

	var overall_rms = sqrt(total_sq / float(samples.size()))
	# Chặn im lặng tuyệt đối / mic không có tín hiệu
	if overall_rms < MIN_ACTIVE_RMS and max_peak < 0.025:
		return false

	const FRAME_SIZE = 512
	var active_frames := 0
	var total_frames := 0
	var idx := 0

	while idx + FRAME_SIZE <= samples.size():
		var frame_sq := 0.0
		for i in range(FRAME_SIZE):
			var val = samples[idx + i]
			frame_sq += val * val
		var frame_rms = sqrt(frame_sq / float(FRAME_SIZE))
		if frame_rms >= MIN_ACTIVE_RMS:
			active_frames += 1
		total_frames += 1
		idx += FRAME_SIZE

	if total_frames == 0:
		return false

	return (float(active_frames) / float(total_frames)) >= MIN_VOICED_FRAME_RATIO

# Trim leading and trailing silence
static func trim_silence(samples: PackedFloat32Array, threshold: float = 0.02) -> PackedFloat32Array:
	if samples.is_empty():
		return samples

	var start_idx := 0
	while start_idx < samples.size() and absf(samples[start_idx]) < threshold:
		start_idx += 1

	if start_idx >= samples.size():
		return PackedFloat32Array()

	var end_idx := samples.size() - 1
	while end_idx > start_idx and absf(samples[end_idx]) < threshold:
		end_idx -= 1

	return samples.slice(start_idx, end_idx + 1)

# ─────────────────────────────────────────────────────────────────────────────
# 2. Optimized Fast MFCC (Lookup tables + downsampled spectral processing)
# ─────────────────────────────────────────────────────────────────────────────

const DOWNSAMPLE_RATE = 11025
const MFCC_FRAME_SIZE = 256
const MFCC_HOP_SIZE = 256
const MFCC_FFT_BINS = 129 # FRAME_SIZE / 2 + 1
const MFCC_NUM_MEL_FILTERS = 16
const MFCC_NUM_COEFFS = 12

static var _tables_initialized: bool = false
static var _hann_window: PackedFloat32Array = PackedFloat32Array()
static var _cos_table: Array = [] # [k][n]
static var _sin_table: Array = [] # [k][n]
static var _mel_filterbank: Array = []
static var _dct_matrix: Array = []

static func _init_fast_tables() -> void:
	if _tables_initialized:
		return

	# Hann window
	_hann_window.resize(MFCC_FRAME_SIZE)
	for i in range(MFCC_FRAME_SIZE):
		_hann_window[i] = 0.5 * (1.0 - cos((2.0 * PI * float(i)) / float(MFCC_FRAME_SIZE - 1)))

	# Precomputed cos/sin for Real DFT: 129 x 256 table (avoids repeated cos/sin calls in loops)
	var factor := 2.0 * PI / float(MFCC_FRAME_SIZE)
	_cos_table.resize(MFCC_FFT_BINS)
	_sin_table.resize(MFCC_FFT_BINS)
	for k in range(MFCC_FFT_BINS):
		var c_row := PackedFloat32Array()
		var s_row := PackedFloat32Array()
		c_row.resize(MFCC_FRAME_SIZE)
		s_row.resize(MFCC_FRAME_SIZE)
		var angle_step := factor * float(k)
		for n in range(MFCC_FRAME_SIZE):
			var a = angle_step * float(n)
			c_row[n] = cos(a)
			s_row[n] = sin(a)
		_cos_table[k] = c_row
		_sin_table[k] = s_row

	# 16 Mel filters
	var low_mel := 2595.0 * log(1.0 + 100.0 / 700.0) / log(10.0)
	var high_mel := 2595.0 * log(1.0 + 5500.0 / 700.0) / log(10.0)
	var mel_points := PackedFloat32Array()
	mel_points.resize(MFCC_NUM_MEL_FILTERS + 2)
	for i in range(MFCC_NUM_MEL_FILTERS + 2):
		mel_points[i] = low_mel + float(i) * (high_mel - low_mel) / float(MFCC_NUM_MEL_FILTERS + 1)

	var bin_indices := PackedInt32Array()
	bin_indices.resize(MFCC_NUM_MEL_FILTERS + 2)
	for i in range(MFCC_NUM_MEL_FILTERS + 2):
		var hz = 700.0 * (pow(10.0, mel_points[i] / 2595.0) - 1.0)
		var bin = int(floor((float(MFCC_FRAME_SIZE) + 1.0) * hz / float(DOWNSAMPLE_RATE)))
		bin_indices[i] = clampi(bin, 0, MFCC_FFT_BINS - 1)

	_mel_filterbank.clear()
	for m in range(1, MFCC_NUM_MEL_FILTERS + 1):
		var filter := PackedFloat32Array()
		filter.resize(MFCC_FFT_BINS)
		for k in range(MFCC_FFT_BINS):
			filter[k] = 0.0
		var left = bin_indices[m - 1]
		var center = bin_indices[m]
		var right = bin_indices[m + 1]
		if center > left:
			for k in range(left, center):
				filter[k] = float(k - left) / float(center - left)
		if right > center:
			for k in range(center, right):
				filter[k] = float(right - k) / float(right - center)
		_mel_filterbank.append(filter)

	# DCT-II matrix: 12 x 16
	_dct_matrix.resize(MFCC_NUM_COEFFS)
	for c in range(MFCC_NUM_COEFFS):
		var row := PackedFloat32Array()
		row.resize(MFCC_NUM_MEL_FILTERS)
		var f = PI * float(c) / float(MFCC_NUM_MEL_FILTERS)
		for m in range(MFCC_NUM_MEL_FILTERS):
			row[m] = cos(f * (float(m) + 0.5))
		_dct_matrix[c] = row

	_tables_initialized = true

# Extracts sequence of 12 MFCC vectors in ~100-200ms using lookup tables
static func extract_mfcc(samples: PackedFloat32Array, sample_rate: int) -> Array:
	if samples.size() < 512:
		return []

	_init_fast_tables()

	# Downsample to 11025Hz
	var downsample_factor = maxi(1, int(round(float(sample_rate) / float(DOWNSAMPLE_RATE))))
	var ds_size = samples.size() / downsample_factor
	if ds_size < MFCC_FRAME_SIZE:
		return []

	var ds := PackedFloat32Array()
	ds.resize(ds_size)
	for i in range(ds_size):
		ds[i] = samples[i * downsample_factor]

	var frames: Array = []
	var offset := 0
	var windowed := PackedFloat32Array()
	windowed.resize(MFCC_FRAME_SIZE)
	var power := PackedFloat32Array()
	power.resize(MFCC_FFT_BINS)
	var mel_energies := PackedFloat32Array()
	mel_energies.resize(MFCC_NUM_MEL_FILTERS)

	while offset + MFCC_FRAME_SIZE <= ds.size():
		for i in range(MFCC_FRAME_SIZE):
			windowed[i] = ds[offset + i] * _hann_window[i]

		for k in range(MFCC_FFT_BINS):
			var r_part := 0.0
			var i_part := 0.0
			var c_row: PackedFloat32Array = _cos_table[k]
			var s_row: PackedFloat32Array = _sin_table[k]
			for n in range(MFCC_FRAME_SIZE):
				var w = windowed[n]
				r_part += w * c_row[n]
				i_part -= w * s_row[n]
			power[k] = (r_part * r_part + i_part * i_part) / float(MFCC_FRAME_SIZE)

		for m in range(MFCC_NUM_MEL_FILTERS):
			var filter: PackedFloat32Array = _mel_filterbank[m]
			var sum := 0.0
			for k in range(MFCC_FFT_BINS):
				sum += power[k] * filter[k]
			mel_energies[m] = log(maxf(sum, 1e-5))

		var coeffs := PackedFloat32Array()
		coeffs.resize(MFCC_NUM_COEFFS)
		var norm := 0.0
		for c in range(MFCC_NUM_COEFFS):
			var sum := 0.0
			var d_row: PackedFloat32Array = _dct_matrix[c]
			for m in range(MFCC_NUM_MEL_FILTERS):
				sum += mel_energies[m] * d_row[m]
			coeffs[c] = sum
			norm += sum * sum

		norm = sqrt(norm)
		if norm > 0.0001:
			for c in range(MFCC_NUM_COEFFS):
				coeffs[c] /= norm

		frames.append(coeffs)
		offset += MFCC_HOP_SIZE

	return frames

# ─────────────────────────────────────────────────────────────────────────────
# 3. Dynamic Time Warping (DTW) with Calibrated Distance
# ─────────────────────────────────────────────────────────────────────────────

# Cosine similarity for MFCC (nhận diện hình dạng ngữ âm / nguyên âm - phụ âm độc lập âm lượng)
static func _vector_distance(vec_a: PackedFloat32Array, vec_b: PackedFloat32Array) -> float:
	var dot := 0.0
	var count = mini(vec_a.size(), vec_b.size())
	for i in range(count):
		dot += vec_a[i] * vec_b[i]
	# Cosine distance: 0.0 = trùng khớp ngữ âm hoàn toàn, 1.0 = khác biệt
	return clampf(1.0 - dot, 0.0, 1.0)

static func compute_dtw_distance(seq_a: Array, seq_b: Array, window_radius: int = 25) -> float:
	var n = seq_a.size()
	var m = seq_b.size()

	if n == 0 or m == 0:
		return 1.0

	var prev_row := PackedFloat32Array()
	var curr_row := PackedFloat32Array()
	prev_row.resize(m + 1)
	curr_row.resize(m + 1)

	for j in range(m + 1):
		prev_row[j] = INF
		curr_row[j] = INF
	prev_row[0] = 0.0

	var max_warp = maxi(window_radius, int(abs(n - m)) + 4)

	for i in range(1, n + 1):
		curr_row[0] = INF
		var expected_j = int(round(float(i) * float(m) / float(n)))
		var start_j = maxi(1, expected_j - max_warp)
		var end_j = mini(m, expected_j + max_warp)

		for j in range(start_j, end_j + 1):
			var cost = _vector_distance(seq_a[i - 1], seq_b[j - 1])
			var min_prev = minf(prev_row[j], minf(curr_row[j - 1], prev_row[j - 1]))
			curr_row[j] = cost + min_prev

		var tmp = prev_row
		prev_row = curr_row
		curr_row = tmp

	var total_cost = prev_row[m]
	if is_inf(total_cost) or total_cost < 0.0:
		return 1.0

	var path_len = float(n + m) / 2.0
	return total_cost / maxf(1.0, path_len)

# ─────────────────────────────────────────────────────────────────────────────
# 4. Strict Pitch Contour, Rhythm, and Envelope
# ─────────────────────────────────────────────────────────────────────────────

# Approximate pitch via zero crossings
static func extract_pitch_contour(samples: PackedFloat32Array, sample_rate: int) -> Array[float]:
	const FRAME_SIZE = 2048
	const HOP_SIZE = 1024
	const SILENCE_THRESHOLD = 0.02
	var contour: Array[float] = []

	var offset = 0
	while offset + FRAME_SIZE <= samples.size():
		var crossings := 0
		var previous := samples[offset]
		var peak := 0.0
		for i in range(1, FRAME_SIZE):
			var current := samples[offset + i]
			peak = maxf(peak, absf(current))
			if (previous < 0.0 and current >= 0.0) or (previous >= 0.0 and current < 0.0):
				crossings += 1
			previous = current

		var freq = (float(crossings) * sample_rate) / (2.0 * float(FRAME_SIZE))
		contour.append(freq if peak >= SILENCE_THRESHOLD else 0.0)
		offset += HOP_SIZE

	return contour

static func extract_envelope(samples: PackedFloat32Array) -> float:
	if samples.is_empty():
		return 0.0
	var rms := 0.0
	var peak := 0.0
	for s in samples:
		rms += s * s
		var abs_val = absf(s)
		if abs_val > peak:
			peak = abs_val
	rms = sqrt(rms / float(samples.size()))
	return (rms + peak) / 2.0

static func extract_onsets(samples: PackedFloat32Array) -> Array[float]:
	const FRAME_SIZE = 512
	var onsets: Array[float] = []
	var prev_energy := 0.0

	var i = 0
	while i + FRAME_SIZE <= samples.size():
		var energy := 0.0
		for j in range(FRAME_SIZE):
			var s = samples[i + j]
			energy += s * s
		energy /= float(FRAME_SIZE)

		var onset = maxf(0.0, energy - prev_energy)
		onsets.append(onset)
		prev_energy = energy * 0.85
		i += FRAME_SIZE

	return onsets

# ─────────────────────────────────────────────────────────────────────────────
# 5. Master Scoring Algorithm (Gate kiểm soát nội dung từ ngữ)
# ─────────────────────────────────────────────────────────────────────────────

static func compare_voices(sample: Dictionary, player: Dictionary) -> Dictionary:
	# Gate 1: Check VAD flag
	if player.has("is_voiced") and not player.is_voiced:
		print("[VoiceAnalyzer] VAD gate failed: No voice activity detected.")
		return {"score": 0, "reason": "No voice detected"}

	# Gate 2: Check minimal audio envelope
	if player.get("envelope", 0.0) < 0.003:
		print("[VoiceAnalyzer] Audio envelope too low (< 0.003). Returning 0.")
		return {"score": 0, "reason": "Too quiet"}

	var sample_mfcc: Array = sample.get("mfcc_frames", [])
	var player_mfcc: Array = player.get("mfcc_frames", [])

	# 1. Thời lượng phát âm (Duration bonus/penalty)
	var dur_penalty := 1.0
	if not sample_mfcc.is_empty() and not player_mfcc.is_empty():
		var len_a = float(sample_mfcc.size())
		var len_b = float(player_mfcc.size())
		var ratio = minf(len_a, len_b) / maxf(len_a, len_b)
		dur_penalty = clampf(ratio * 1.5, 0.85, 1.0)

	# 2. So khớp nội dung từ ngữ ngữ âm (MFCC + DTW Cosine)
	var phonetic_score := 0.0
	var dtw_dist := 1.0
	if not sample_mfcc.is_empty() and not player_mfcc.is_empty():
		dtw_dist = compute_dtw_distance(sample_mfcc, player_mfcc)
		# Căn chỉnh thang điểm mượt mà theo cảm nhận người chơi:
		# Giọng giống hệt / cùng file: dtw_dist ~ 0.0 - 0.15 => 92 - 100%
		# Nói chuẩn từ mẫu: dtw_dist ~ 0.15 - 0.35 => 80 - 92%
		# Nói tương đối giống: dtw_dist ~ 0.35 - 0.50 => 60 - 80%
		# Khác từ / nói linh tinh: dtw_dist > 0.65 => < 20%
		phonetic_score = clampf(1.0 - pow(clampf(dtw_dist / 0.70, 0.0, 1.0), 1.4), 0.0, 1.0)

	# Chặn khi nói sai hẳn từ, lảm nhảm, hoặc im lặng (dist > 0.65)
	if phonetic_score <= 0.08:
		print("[VoiceAnalyzer] Phonetic mismatch! (dist: %.3f). Wrong word. Score: 0" % dtw_dist)
		return {"score": 0, "reason": "Wrong word"}

	# 3. Pitch Contour & Rhythm
	var pitch_score = _compare_pitch_contour_strict(sample.get("pitch_contour", []), player.get("pitch_contour", []))
	var onset_score = _compare_onsets_strict(sample.get("onsets", []), player.get("onsets", []))

	# Trọng số: Phonetic (nội dung lời nói) 70%, Ngữ điệu 15%, Nhịp điệu 15%
	var base_score = (phonetic_score * 0.70 + pitch_score * 0.15 + onset_score * 0.15) * 100.0
	var final_percent = base_score * dur_penalty
	var final_score = clampi(int(round(final_percent)), 0, 100)

	print("[VoiceAnalyzer] Scoring -> Phonetic: %.1f (dist: %.3f), Pitch: %.1f, Rhythm: %.1f | DurPen: %.2f => Final: %d" % [
		phonetic_score * 100.0, dtw_dist, pitch_score * 100.0, onset_score * 100.0, dur_penalty, final_score
	])

	return {"score": final_score, "reason": ""}

# Syllable penalty: kiểm tra số lượng âm tiết nổi bật
static func _calculate_syllable_penalty(sample_onsets: Array, player_onsets: Array) -> float:
	var s_count := 0
	for o in sample_onsets:
		if float(o) > 0.02:
			s_count += 1

	var p_count := 0
	for o in player_onsets:
		if float(o) > 0.02:
			p_count += 1

	if s_count == 0 or p_count == 0:
		return 1.0

	var max_s = maxi(s_count, p_count)
	var min_s = mini(s_count, p_count)
	var ratio = float(min_s) / float(max_s)
	# Giữ sàn tối thiểu 0.70 để không phạt gắt người chơi
	return clampf(ratio, 0.70, 1.0)

# Căn chỉnh DTW 1D cho chuỗi số float (pitch hoặc onset)
static func _compute_1d_dtw_distance(seq_a: Array, seq_b: Array, max_diff: float) -> float:
	var n = seq_a.size()
	var m = seq_b.size()
	if n == 0 or m == 0:
		return 1.0

	var prev_row := PackedFloat32Array()
	var curr_row := PackedFloat32Array()
	prev_row.resize(m + 1)
	curr_row.resize(m + 1)

	for j in range(m + 1):
		prev_row[j] = INF
		curr_row[j] = INF
	prev_row[0] = 0.0

	var max_warp = maxi(15, int(abs(n - m)) + 4)

	for i in range(1, n + 1):
		curr_row[0] = INF
		var expected_j = int(round(float(i) * float(m) / float(n)))
		var start_j = maxi(1, expected_j - max_warp)
		var end_j = mini(m, expected_j + max_warp)

		var val_a = float(seq_a[i - 1])

		for j in range(start_j, end_j + 1):
			var val_b = float(seq_b[j - 1])
			var cost: float
			if val_a <= 0.0 and val_b <= 0.0:
				cost = 0.0
			elif val_a <= 0.0 or val_b <= 0.0:
				cost = 1.0
			else:
				var ratio = val_b / val_a
				var diff = absf(12.0 * log(ratio) / log(2.0)) if max_diff > 1.0 else absf(val_a - val_b)
				cost = clampf(diff / max_diff, 0.0, 1.0)

			var min_prev = minf(prev_row[j], minf(curr_row[j - 1], prev_row[j - 1]))
			curr_row[j] = cost + min_prev

		var tmp = prev_row
		prev_row = curr_row
		curr_row = tmp

	var total_cost = prev_row[m]
	if is_inf(total_cost) or total_cost < 0.0:
		return 1.0
	var path_len = float(n + m) / 2.0
	return total_cost / maxf(1.0, path_len)

# Pitch contour: So sánh ngữ điệu qua DTW (tự căn chỉnh lệch nhịp thời gian / lead-in)
static func _compare_pitch_contour_strict(sample: Array, player: Array) -> float:
	if sample.is_empty() or player.is_empty():
		return 0.0

	# Lọc frame có cao độ thực tế
	var s_voiced: Array = []
	for v in sample:
		if float(v) > 0.0:
			s_voiced.append(v)
	var p_voiced: Array = []
	for v in player:
		if float(v) > 0.0:
			p_voiced.append(v)

	if s_voiced.is_empty() or p_voiced.is_empty():
		return 0.0

	# Cho phép dung sai 12 nửa cung (1 octave) giữa giọng mẫu và người chơi
	var dist = _compute_1d_dtw_distance(s_voiced, p_voiced, 12.0)
	return clampf(1.0 - dist, 0.0, 1.0)

# Onset rhythm: So sánh nhịp điệu phát âm qua DTW
static func _compare_onsets_strict(sample: Array, player: Array) -> float:
	if sample.is_empty() or player.is_empty():
		return 0.0

	var s_onsets: Array = []
	for o in sample:
		if float(o) > 0.005:
			s_onsets.append(o)
	var p_onsets: Array = []
	for o in player:
		if float(o) > 0.005:
			p_onsets.append(o)

	if s_onsets.is_empty() or p_onsets.is_empty():
		return 0.0

	var dist = _compute_1d_dtw_distance(s_onsets, p_onsets, 0.05)
	return clampf(1.0 - dist, 0.0, 1.0)
