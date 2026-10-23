# Task 6 Report: Toàn diện & Xác thực Headless (Integration Test)

## 1. Khuyến nghị Task 3 Review
- Đã override `end_game_timeout() -> void` trong `scripts/minigames/gold_miner/gold_miner.gd`:
  - Khi timeout, gọi `_process_gold_miner_end()` sắp xếp người chơi theo điểm `gold_scores` (thứ hạng điểm vàng cao nhất ở cuối mảng `elimination_order`).
  - Thêm helper `calculate_round_scores()` và `get_next_minigame_scene()` để test và gameplay logic hoạt động độc lập, an toàn khi chạy headless mà không bị phụ thuộc vào tree base node.
  - Bổ sung kiểm tra an toàn `multiplayer` và `multiplayer.has_multiplayer_peer()` tránh crash khi chạy headless standalone test.

## 2. Test tích hợp toàn diện (`scripts/test/test_gold_miner_full.gd`)
- Instantiate `scenes/minigames/gold_miner/gold_miner.tscn` (kế thừa `GoldMiner`).
- Giả lập 2 players (Host id 1, Client id 2).
- Khởi tạo spawn positions và default hooks cho cả 2 players.
- Giả lập thả móc Player 1 (`SWINGING` -> `EXTENDING`).
- Giả lập va chạm quặng Vàng Lớn (`GOLD_LARGE`, value 500, weight 4.0):
  - Hook chuyển trạng thái sang `RETRACTING`.
  - Item được đánh dấu `is_hooked = true`.
- Giả lập kéo về gốc:
  - Hook quay về trạng thái `SWINGING`, reset `target_item_id = -1`.
  - Player 1 nhận 500 điểm vàng.
  - Item bị xóa khỏi danh sách `minerals`.
- Giả lập hết giờ (`match_timer = 0.0` và gọi `end_game_timeout()`):
  - Game state chuyển sang `ENDED`.
  - `elimination_order` sắp xếp đúng: Player 2 (0đ) rank 1, Player 1 (500đ) rank 2 (winner).
  - Điểm tournament: Winner nhận 1000 điểm, Loser nhận 0 điểm.
- Kiểm tra chuyển scene tiếp theo: trả về đúng `res://scenes/minigames/mimic/mimic.tscn`.

## 3. Kết quả chạy Headless Test
- Lệnh:
  `C:\Users\nguye\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe --headless -s scripts/test/test_gold_miner_full.gd`
- Output: `TEST_GOLD_MINER_FULL_PASS` (100% PASS, exit code 0).

## 4. Cập nhật Knowledge Graph
- Đã chạy `python update_graph.py`.
- Kết quả: 604 nodes, 943 edges, 51 communities đồng bộ vào `graphify-out/graph.json`, `graphify-out/GRAPH_REPORT.md` và `graphify-out/graph.html`.
