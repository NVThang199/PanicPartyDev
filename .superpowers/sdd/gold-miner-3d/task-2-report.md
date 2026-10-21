# Task 2 Report: Controller tính toán va chạm và logic Server-Authoritative Móc

**Status**: DONE

## Danh sách file
1. `scripts/minigames/gold_miner/gold_miner.gd` (Created)
2. `scripts/test/test_gold_miner_logic.gd` (Created)

## Chi tiết triển khai
- Class `GoldMiner` kế thừa `BaseMinigame` (`class_name GoldMiner extends BaseMinigame`).
- Enum `HookState { SWINGING, EXTENDING, RETRACTING }`.
- Constants:
  - `MATCH_DURATION = 60.0`
  - `SWING_SPEED = 2.2`
  - `MAX_SWING_ANGLE = 70.0`
  - `BASE_EXTEND_SPEED = 14.0`
  - `BASE_RETRACT_SPEED = 12.0`
  - `MAX_HOOK_LENGTH = 22.0`
- Helpers:
  - `create_default_hook_data(p_origin: Vector3) -> Dictionary`
  - `calculate_retract_speed(weight: float) -> float`
  - `find_first_hit(hook_origin: Vector3, hook_dir: Vector3, current_length: float, items_dict: Dictionary) -> int` (Duyệt `items_dict`, kiểm tra `active` & `grabbable`, tính hình chiếu lên tia và khoảng cách vuông góc bán kính, chọn item gần nhất).
  - `_tick_hook_server(peer_id: int, delta: float) -> void`
- Server-Authoritative RPC Contract:
  - `@rpc("any_peer", "call_local", "reliable") func request_drop_hook() -> void`
  - `@rpc("authority", "call_local", "reliable") func sync_hook_event(peer_id: int, new_state: int, angle: float) -> void`
  - `@rpc("authority", "call_local", "reliable") func sync_item_collected(peer_id: int, item_id: int, new_score: int) -> void`
  - Tuân thủ RPC targeting policy: Chỉ gửi đích danh tới `synced_peers`, không broadcast toàn mạng bằng `.rpc(...)`.

## Kết quả kiểm thử
- Lệnh chạy: `Godot_v4.7.2-stable_win64_console.exe --headless -s scripts/test/test_gold_miner_logic.gd`
- Kết quả: **PASS** (`TEST_GOLD_MINER_LOGIC_PASS`).
