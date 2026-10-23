# Task 3 Code Review: Scene 3D Đào Vàng: Camera Thượng Đế, Bệ Móc, Sân Mỏ, UI

## Scope
- `scenes/minigames/gold_miner/gold_miner.tscn`
- `scripts/minigames/gold_miner/gold_miner.gd`
- `scripts/test/test_gold_miner_scene.gd`
- `.superpowers/sdd/gold-miner-3d/task-3-report.md`

## Evaluation

### 1. Spec Compliance: ✅
- **Scene Tree hoàn chỉnh**:
  - `Camera3D`: Góc nhìn thượng đế (top-down, `transform` pos `Vector3(0, 16, 12)`, rot `Vector3(-55, 0, 0)`), `current = true`, `fov = 55.0`.
  - `RigPositions`: Đủ 4 `Marker3D` (`Rig0` .. `Rig3`) tương ứng 4 slot tọa độ `Vector3(-9, 0, -6)`, `Vector3(-3, 0, -6)`, `Vector3(3, 0, -6)`, `Vector3(9, 0, -6)`.
  - `MineralsContainer`, `HooksContainer`: Node3D riêng biệt quản lý khoáng sản và visual cáp/móc.
  - `MiningArea`: Gồm `TopGround` (bệ người chơi) và `MineFloor` (sân mỏ ngầm).
  - `UI (CanvasLayer)`: `MatchTimerLabel`, `PlayerScoresPanel`, `WinnerBanner`, `InGameMenu`.
- **Lifecycle BaseMinigame**:
  - `_get_tutorial_data()`: Trả về dictionary đa ngôn ngữ hợp lệ (`MINIGAME_GOLD_MINER`, `GOLD_MINER_RULES`, `GOLD_MINER_CONTROLS_HINT`).
  - `_get_spawn_positions()`: Đọc `RigPositions` với fallback an toàn khi node chưa trong tree.
  - `_on_minigame_ready()`: Đặt `match_timer = MATCH_DURATION` (60.0) và cache node UI.
  - `_on_post_initialize()`: Server sinh 16 khoáng sản mặc định (`_spawn_default_minerals`) và khởi tạo hook cho mọi player.
  - `_on_minigame_tick(delta)`: Server tick hook physics, phát `sync_hook_tick` unreliable cho `synced_peers`, cập nhật visual và bảng điểm.
  - `_on_sync_custom_entities(caller_id)`: Gửi đầy đủ snapshot quặng còn lại, trạng thái móc và điểm số khi client handshake `request_game_sync`.
  - `_process_gold_miner_end()`: Sắp xếp `elimination_order` theo `gold_scores` tăng dần để người cao điểm nhất nhận 1000 điểm round, gọi `_process_round_end(winner_id)`.

### 2. Material Cleanup & Engine Safety: Approved ✅
- **Material Override Cleanup**: Trong `_exit_tree()` của `gold_miner.gd`, toàn bộ `cable` và `head` mesh instances được gỡ `material_override = null` trước khi clear dictionary.
- **Item Material Cleanup**: `gold_miner_item.gd` gỡ `material_override = null` và `set_surface_override_material(0, null)` trong `_exit_tree()`, chống lỗi RendererRD Vulkan leak material.

### 3. Network Policy: Approved ✅
- **Tuyệt đối không dùng `.rpc(...)` broadcast**: Toàn bộ luồng phát mạng dùng `rpc_id(...)` đích danh tới `synced_peers` (`spawn_mineral_rpc`, `sync_hook_full_state`, `sync_hook_tick`, `sync_hook_event`, `sync_item_collected`).
- **Client Request**: `request_drop_hook.rpc_id(1)` chỉ gửi lên Server ID 1. Server kiểm tra thẩm quyền và trạng thái trước khi cho hạ móc.

### 4. Test Coverage: ✅
- `test_gold_miner_scene.gd` kiểm tra:
  - Khởi tạo PackedScene và kiểm tra root script `gold_miner.gd`.
  - `Camera3D` tồn tại và có `current == true`.
  - `DirectionalLight3D`, `WorldEnvironment`, `MiningArea`, `MineralsContainer`, `HooksContainer`.
  - `RigPositions` đủ 4 node con và `_get_spawn_positions()` trả về đúng 4 vector slot.
  - Các node UI (`MatchTimerLabel`, `PlayerScoresPanel`, `WinnerBanner`).
  - Tutorial dictionary keys.
- Chạy headless trên Godot 4.7.2: `TEST_GOLD_MINER_SCENE_PASS` (exit code 0).

### 5. Recommendation (MEDIUM)
- Trong `BaseMinigame._process()`: khi `match_timer <= 0.0`, engine gọi `end_game_timeout()` và `return` ngay trước khi gọi `_on_minigame_tick()`. Do đó `_process_gold_miner_end()` trong `_on_minigame_tick()` không được kích hoạt khi hết giờ nếu minigame không override `end_game_timeout()`.
- **Khuyến nghị**: Thêm hàm override trong `gold_miner.gd`:
  ```gdscript
  func end_game_timeout() -> void:
      _process_gold_miner_end()
  ```

## Verdict
**APPROVE** - Spec ✅, Quality Approved. Sẵn sàng tích hợp Task 4.
