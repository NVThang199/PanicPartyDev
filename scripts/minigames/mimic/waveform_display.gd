extends Control
class_name WaveformDisplay

# 120 cột biên độ sóng âm
var sample_bars: PackedFloat32Array = PackedFloat32Array()
var recording_bars: PackedFloat32Array = PackedFloat32Array()
var playhead_ratio: float = -1.0  # < 0: ẩn thanh trượt

# Vùng mục tiêu (nơi sample thực sự phát ra)
var target_start_ratio: float = -1.0
var target_end_ratio: float = -1.0

const COLOR_SAMPLE = Color(0.2, 0.85, 0.45, 0.7)        # Xanh lá bản mẫu (nền)
const COLOR_RECORDING = Color(1.0, 0.55, 0.1, 0.95)     # Cam đậm âm thanh người chơi (đè lên trên)
const COLOR_PLAYHEAD = Color(1.0, 1.0, 1.0, 1.0)        # Trắng sáng cho thanh trượt
const COLOR_BASELINE = Color(1.0, 1.0, 1.0, 0.12)
const COLOR_ZONE_BG = Color(0.2, 0.85, 0.45, 0.07)      # Nền mờ đánh dấu khu vực cần nói
const COLOR_ZONE_BORDER = Color(0.2, 0.85, 0.45, 0.3)  # Vạch phân cách khu vực cần nói

func reset_recording(bar_count: int = 120) -> void:
	recording_bars.resize(bar_count)
	for i in range(bar_count):
		recording_bars[i] = 0.0
	playhead_ratio = 0.0
	queue_redraw()

func set_sample_bars(bars: PackedFloat32Array, start_ratio: float = -1.0, end_ratio: float = -1.0) -> void:
	sample_bars = bars.duplicate()
	target_start_ratio = start_ratio
	target_end_ratio = end_ratio
	queue_redraw()

func set_recording_bars(bars: PackedFloat32Array) -> void:
	recording_bars = bars.duplicate()
	queue_redraw()

func update_recording_bar(idx: int, amp: float) -> void:
	if idx >= 0 and idx < recording_bars.size():
		recording_bars[idx] = max(recording_bars[idx], amp)
	queue_redraw()

func set_playhead(ratio: float) -> void:
	playhead_ratio = ratio
	queue_redraw()

func clear_all() -> void:
	sample_bars.clear()
	recording_bars.clear()
	playhead_ratio = -1.0
	target_start_ratio = -1.0
	target_end_ratio = -1.0
	queue_redraw()

func _draw() -> void:
	var w = size.x
	var h = size.y
	if w <= 0 or h <= 0:
		return

	var cy = h * 0.5

	# 0. Vùng Karaoke target zone (khoảng thời gian cần nói)
	if target_start_ratio >= 0.0 and target_end_ratio > target_start_ratio:
		var x1 = target_start_ratio * w
		var x2 = target_end_ratio * w
		draw_rect(Rect2(x1, 0, x2 - x1, h), COLOR_ZONE_BG)
		draw_line(Vector2(x1, 0), Vector2(x1, h), COLOR_ZONE_BORDER, 1.5)
		draw_line(Vector2(x2, 0), Vector2(x2, h), COLOR_ZONE_BORDER, 1.5)

	# Đường baseline ở giữa
	draw_line(Vector2(0, cy), Vector2(w, cy), COLOR_BASELINE, 1.0)

	# 1. Vẽ sóng âm bản mẫu (sample) ở dưới
	if not sample_bars.is_empty():
		var count = sample_bars.size()
		var step = w / float(count)
		var bar_w = max(1.0, step * 0.7)
		for i in range(count):
			var amp = sample_bars[i]
			var bar_h = amp * cy * 0.85
			if bar_h > 1.0:
				var x = i * step + step * 0.5
				draw_line(Vector2(x, cy - bar_h), Vector2(x, cy + bar_h), COLOR_SAMPLE, bar_w)

	# 2. Vẽ sóng âm người chơi (recording) đè lên trên
	if not recording_bars.is_empty():
		var count = recording_bars.size()
		var step = w / float(count)
		var bar_w = max(1.0, step * 0.7)
		for i in range(count):
			var amp = recording_bars[i]
			var bar_h = amp * cy * 0.85
			if bar_h > 1.0:
				var x = i * step + step * 0.5
				draw_line(Vector2(x, cy - bar_h), Vector2(x, cy + bar_h), COLOR_RECORDING, bar_w)

	# 3. Vẽ thanh trượt (playhead) chạy từ trái qua phải
	if playhead_ratio >= 0.0 and playhead_ratio <= 1.0:
		var px = clampf(playhead_ratio * w, 0.0, w)
		draw_line(Vector2(px, 0), Vector2(px, h), COLOR_PLAYHEAD, 2.5)
		var top_marker = PackedVector2Array([
			Vector2(px - 5, 0),
			Vector2(px + 5, 0),
			Vector2(px, 7)
		])
		draw_colored_polygon(top_marker, COLOR_PLAYHEAD)
		var bot_marker = PackedVector2Array([
			Vector2(px - 5, h),
			Vector2(px + 5, h),
			Vector2(px, h - 7)
		])
		draw_colored_polygon(bot_marker, COLOR_PLAYHEAD)
