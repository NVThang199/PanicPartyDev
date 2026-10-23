# Task 4 Code Review: Tích hợp Campaign Tournament và Lobby Navigation

## Scope
- `scripts/minigames/base_minigame.gd` (hàm `_get_next_minigame_scene`)
- `scripts/core/main.gd` (hàm `_change_to_minigame` và `_pick_random_map`)
- `scripts/test/test_gold_miner_campaign_flow.gd`
- `.superpowers/sdd/gold-miner-3d/task-4-report.md`

## Evaluation

### 1. Spec Compliance: Partial ⚠️ (Spec ❌ do Test & Report)
- **Vòng lặp 4 map Campaign**: ✅ ĐẠT.
  - `scripts/minigames/base_minigame.gd` trong `_get_next_minigame_scene()` đã định tuyến xoay vòng chuẩn 4 map:
    - `"hotbomb"` / `"bomb"` -> `res://scenes/minigames/stable_footing/stable_footing.tscn`
    - `"stablefooting"` / `"footing"` -> `res://scenes/minigames/gold_miner/gold_miner.tscn`
    - `"goldminer"` / `"miner"` -> `res://scenes/minigames/mimic/mimic.tscn`
    - `"mimic"` -> `res://scenes/minigames/hot_bomb/hot_bomb.tscn`
- **Lobby Navigation & Random Map Selection**: ✅ ĐẠT.
  - `_pick_random_map()` trong `scripts/core/main.gd`: Đã thêm `"GoldMiner"` vào danh sách chọn ngẫu nhiên (`["HotBomb", "StableFooting", "GoldMiner", "Mimic"]`).
  - `_change_to_minigame()` trong `scripts/core/main.gd`: Nhánh `"GoldMiner"` đã duplicate `player_info` sang `GameSession.minigame_players` và gọi `change_scene_to_file("res://scenes/minigames/gold_miner/gold_miner.tscn")`.
- **Không phá vỡ luồng cũ**: ✅ ĐẠT.
  - Các minigame hiện hữu (`HotBomb`, `StableFooting`, `Mimic`) giữ nguyên luồng kết nối và chuyển cảnh.
- **Task 4 Report**: ❌ THIẾU.
  - File `.superpowers/sdd/gold-miner-3d/task-4-report.md` chưa được tạo.
- **Campaign Flow Test**: ❌ FAIL khi chạy standalone headless.
  - Lệnh: `Godot_v4.7.2-stable_win64_console.exe --headless -s scripts/test/test_gold_miner_campaign_flow.gd`
  - Lỗi: Khi chạy với flag `-s` kế thừa `SceneTree`, Godot không nạp các Autoload singleton (`GameSession`, `AudioManager`). Do `base_minigame.gd` và `main.gd` phụ thuộc vào các Autoload này ở tầng compile time, việc `load("res://scripts/minigames/base_minigame.gd")` bị lỗi `SCRIPT ERROR: Compile Error: Identifier not found: GameSession`, dẫn đến `instance._get_next_minigame_scene()` bị crash do node fallback về `Node3D`.
  - Hướng xử lý: Cần chuyển runner test campaign flow sang `.tscn` (tương tự pattern `test_gold_miner_runner.tscn`) hoặc load qua scene context để engine khởi tạo đầy đủ Autoload trước khi test.

### 2. Code Quality: Approved ✅
- Code sạch, tuân thủ đúng kiến trúc chuyển scene Two-Phase của game.
- Đường dẫn resource chính xác (`res://scenes/minigames/gold_miner/gold_miner.tscn`).
- Đảm bảo tính nhất quán giữa Server và Client, không vi phạm RPC targeting policy.

### 3. Issues & Action Items
1. **[HIGH] Sửa runner test campaign flow**: Chuyển đổi `test_gold_miner_campaign_flow.gd` sang scene runner (`.tscn`) hoặc cập nhật cách nạp để test chạy pass với đầy đủ Autoload singleton.
2. **[MEDIUM] Bổ sung task report**: Tạo file `.superpowers/sdd/gold-miner-3d/task-4-report.md` ghi nhận kết quả triển khai Task 4.

## Verdict
**Spec ❌ (Test chưa pass do thiếu Autoload context trong script headless, thiếu report file), Quality Approved.**
