# Task 2 Code Review: Controller tính toán va chạm và logic Server-Authoritative Móc

## Scope
- `scripts/minigames/gold_miner/gold_miner.gd`
- `scripts/test/test_gold_miner_logic.gd`
- `.superpowers/sdd/gold-miner-3d/task-2-report.md`

## Evaluation

### 1. Spec Compliance: ✅
- **Kế thừa BaseMinigame**: `class_name GoldMiner extends BaseMinigame`, khởi tạo `match_timer = MATCH_DURATION` trong `_on_minigame_ready()`.
- **First-hit ray calculation**: Thuật toán `find_first_hit()` tính hình chiếu chiếu tia `vec.dot(dir_norm)`, kiểm tra bán kính vuông góc `perp_dist <= item_radius`, khoảng cách dọc tia `<= current_length + item_radius`, và chọn đúng item gần nhất (`min_proj`). Hỗ trợ cả `Dictionary` lẫn `GoldMinerItem` / `Node3D`.
- **Server-Authoritative**: Client chỉ gửi yêu cầu hạ móc qua `request_drop_hook()`. Server toàn quyền tính toán va chạm, chuyển trạng thái `SWINGING -> EXTENDING -> RETRACTING`, cập nhật `gold_scores` và gửi đồng bộ qua `sync_hook_event`, `sync_item_collected`.
- **Tốc độ thu dây**: `calculate_retract_speed(weight)` tỷ lệ nghịch với trọng lượng vật thể (`BASE_RETRACT_SPEED / max(0.1, weight)`).

### 2. Network & Safety Policies: Approved ✅
- **RPC Targeting Policy**: Tuyệt đối không dùng `.rpc(...)` broadcast. Toàn bộ thông báo dùng `rpc_id(pid, ...)` theo danh sách `synced_peers`, xử lý local cho host (`pid == 1`).
- **RPC Guards**: `sync_hook_event` và `sync_item_collected` có guard `if not is_inside_tree(): return`.
- **Lưu ý nhỏ (LOW)**: Trong `request_drop_hook()`, nên bổ sung thêm guard `if not is_inside_tree(): return` để đồng bộ hoàn toàn với các RPC còn lại khi chuyển scene ở Task 3/4.

### 3. Test Coverage: ✅
- `test_gold_miner_logic.gd` kiểm tra:
  - Khởi tạo `create_default_hook_data()`.
  - Thuật toán `find_first_hit()` chọn đúng item gần nhất trên cùng một tia.
  - Xử lý item ngoài tầm với, item inactive hoặc non-grabbable.
  - Tương thích trực tiếp với instance `GoldMinerItem`.
  - Công thức tính tốc độ kéo dây `calculate_retract_speed()`.
- Chạy headless trên Godot 4.7.2: `TEST_GOLD_MINER_LOGIC_PASS` (exit code 0).

## Verdict
**APPROVE** - Spec ✅, Quality Approved. Sẵn sàng cho Task 3.
