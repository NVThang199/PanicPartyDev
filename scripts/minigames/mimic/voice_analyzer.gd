extends Node
class_name VoiceAnalyzer

# Extract voice features: pitch contour, envelope, onset
static func create_features() -> Dictionary:
	return {
		"pitch_contour": [],
		"envelope": 0.0,
		"onsets": []
	}

# Approximate relative pitch from zero crossings.
# ponytail: adequate for arcade scoring; replace with threaded YIN if accuracy matters.
static func extract_pitch_contour(samples: PackedFloat32Array, sample_rate: int) -> Array[float]:
	const FRAME_SIZE = 2048
	const HOP_SIZE = 2048
	const SILENCE_THRESHOLD = 0.01
	var contour: Array[float] = []

	var offset = 0
	while offset + FRAME_SIZE <= samples.size():
		var crossings := 0
		var previous := samples[offset]
		var peak := 0.0
		for i in range(1, FRAME_SIZE):
			var current := samples[offset + i]
			peak = max(peak, abs(current))
			if (previous < 0.0 and current >= 0.0) or (previous >= 0.0 and current < 0.0):
				crossings += 1
			previous = current
		contour.append(float(crossings) * sample_rate / (2.0 * FRAME_SIZE) if peak >= SILENCE_THRESHOLD else 0.0)
		offset += HOP_SIZE

	if contour.is_empty():
		return contour
	var voiced := contour.filter(func(p): return p > 0.0)
	if voiced.is_empty():
		return contour
	var mean: float = voiced.reduce(func(total: float, pitch: float) -> float: return total + pitch, 0.0) / float(voiced.size())
	for i in range(contour.size()):
		contour[i] = contour[i] / mean if contour[i] > 0.0 else 0.0
	return contour

# Extract envelope (RMS energy)
static func extract_envelope(samples: PackedFloat32Array) -> float:
	if samples.is_empty():
		return 0.0
	var rms = 0.0
	for s in samples:
		rms += s * s
	rms = sqrt(rms / samples.size())

	var peak = 0.0
	for s in samples:
		var abs_val = abs(s)
		if abs_val > peak:
			peak = abs_val

	return (rms + peak) / 2.0

# Extract onset strength (attack points)
static func extract_onsets(samples: PackedFloat32Array) -> Array[float]:
	const FRAME_SIZE = 512
	var onsets: Array[float] = []
	var prev_energy = 0.0

	var i = 0
	while i + FRAME_SIZE < samples.size():
		var frame = samples.slice(i, i + FRAME_SIZE)
		var energy = 0.0
		for s in frame:
			energy += s * s
		energy /= FRAME_SIZE

		var onset = max(0.0, energy - prev_energy)
		onsets.append(onset)
		prev_energy = energy * 0.9  # Decay
		i += FRAME_SIZE

	return onsets

# Simple YIN pitch estimator
static func _estimate_pitch(frame: PackedFloat32Array, sample_rate: int) -> float:
	var min_period = int(sample_rate / 400.0)  # 400 Hz max
	var max_period = int(sample_rate / 80.0)   # 80 Hz min

	var min_diff = INF
	var period = max_period

	for tau in range(min_period, max_period):
		var diff = 0.0
		for i in range(frame.size() - tau):
			diff += abs(frame[i] - frame[i + tau])
		if diff < min_diff:
			min_diff = diff
			period = tau

	return float(sample_rate) / float(period)

# Compare two voice features -> score 0-100
static func compare_voices(sample: Dictionary, player: Dictionary) -> int:
	var pitch_score = _compare_pitch_contour(sample.pitch_contour, player.pitch_contour)
	var envelope_score = _compare_envelope(sample.envelope, player.envelope)
	var onset_score = _compare_onsets(sample.onsets, player.onsets)

	# Weighted: pitch 50%, envelope 30%, onset 20%
	var score = (pitch_score * 0.5 + envelope_score * 0.3 + onset_score * 0.2) * 100
	return clampi(int(score), 0, 100)

static func _compare_pitch_contour(sample: Array[float], player: Array[float]) -> float:
	if sample.is_empty() or player.is_empty():
		return 0.0

	var min_len = mini(sample.size(), player.size())
	var sum = 0.0
	for i in range(min_len):
		var diff = abs(sample[i] - player[i])
		sum += (1.0 - clampf(diff, 0.0, 1.0))
	return sum / min_len

static func _compare_envelope(sample: float, player: float) -> float:
	var diff = abs(sample - player)
	return max(0.0, 1.0 - diff)

static func _compare_onsets(sample: Array[float], player: Array[float]) -> float:
	if sample.is_empty() or player.is_empty():
		return 0.0

	var min_len = mini(sample.size(), player.size())
	var sum = 0.0
	for i in range(min_len):
		var diff = abs(sample[i] - player[i])
		sum += (1.0 - clampf(diff, 0.0, 1.0))
	return sum / min_len
