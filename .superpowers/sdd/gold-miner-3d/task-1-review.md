# Task 1 Code Review: Dữ liệu khoáng sản và script quặng mẫu

## Scope
- `scripts/minigames/gold_miner/gold_miner_item.gd`
- `scenes/minigames/gold_miner/gold_miner_item.tscn`
- `scripts/test/test_gold_miner_item.gd`

## Evaluation

### 1. Spec Compliance: ✅
- `class_name GoldMinerItem extends Area3D`: Đúng spec.
- `enum Type`: Đủ 7 loại (`GOLD_LARGE`, `GOLD_MEDIUM`, `GOLD_SMALL`, `DIAMOND`, `ROCK_LARGE`, `ROCK_SMALL`, `OBSTACLE`).
- `CONFIGS`: Đầy đủ value, weight, radius, color, grabbable cho từng loại quặng theo spec plan.
- Methods: `setup_item()`, `get_item_value()`, `get_item_weight()`, `is_grabbable()` hoạt động chính xác.
- Collision & Visuals: Cập nhật động kích thước `SphereShape3D` và `SphereMesh` theo cấu hình bán kính `radius`.

### 2. Code Quality: Approved ✅
- GDScript 2.0 chuẩn, static typing đầy đủ.
- Tuân thủ quy tắc RendererRD Vulkan: implement `_exit_tree()` dọn dẹp `material_override` và `surface_override_material` trước khi node bị giải phóng.
- Collision layer cấu hình rõ ràng (layer 4 - items, mask 0).

### 3. Test Coverage: ✅
- `test_gold_miner_item.gd` bao phủ khởi tạo script, `setup_item` cho các loại quặng khác nhau, kiểm tra grabbable, scene instantiation và cập nhật collision radius.
- Chạy headless trên Godot 4.7.2: `TEST_GOLD_MINER_ITEM_PASS` (exit code 0).

## Verdict
**APPROVE** - Sẵn sàng chuyển sang Task 2.
