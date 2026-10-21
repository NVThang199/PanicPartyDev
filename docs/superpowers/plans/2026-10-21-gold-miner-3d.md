# Gold Miner 3D Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng minigame Đào Vàng 3D (Gold Miner) 60 giây cho 1-4 người chơi với góc nhìn thượng đế (top-down), cơ chế móc tự vung và phóng một nút bấm (first-hit, kéo chậm theo trọng lượng), kế thừa `BaseMinigame` và tích hợp trọn vẹn vào Lobby / Campaign tournament của PanicParty.

**Architecture:** Tạo minigame mới kế thừa `BaseMinigame`. Server quản lý toàn quyền (server-authoritative) trạng thái góc vung, phóng móc, va chạm first-hit, kéo quặng và cộng điểm. Client chỉ gửi duy nhất RPC tin cậy `request_drop_hook.rpc_id(1)` và render dự đoán/nội suy. Giao tiếp mạng tuyệt đối tuân thủ `rpc_id` theo danh sách `synced_peers`, không broadcast toàn mạng.

**Tech Stack:** Godot 4.7.2, GDScript, SteamMultiplayerPeer, CSG / Mesh primitives (Cube, Cylinder, Sphere) làm placeholder cho mỏ khoáng sản, CSV I18n 11 ngôn ngữ.

**Spec:** Cuộc thảo luận spec trong session hiện tại và plan tổng thể:
- 1-4 người chơi, camera top-down bao quát.
- Móc vung tự động quanh bệ đào, click chuột phóng thẳng.
- Vật thể: Vàng (lớn/vừa/nhỏ), Kim Cương, Đá (lớn/nhỏ), Vật cản (Obstacle).
- Cơ chế kéo: Tốc độ nghịch đảo với trọng lượng (`base_speed / weight`).
- Thời gian: 60 giây. Điểm hiển thị cạnh người chơi.
- Điểm tính theo xếp hạng tournament campaign dồn vào `GameSession.player_scores`.

## Global Constraints
- Engine: Godot 4.7.2 (GDScript 2.0).
- Không broadcast `.rpc(...)` toàn mạng; BẮT BUỘC dùng `rpc_id(target_id, ...)` tới `synced_peers` (`pid != 1`).
- Mọi hàm RPC nhận state/event BẮT BUỘC có guard:
  `if not is_inside_tree(): return`
  `if not multiplayer or not multiplayer.multiplayer_peer or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED: return`
- Mô hình Late-join: Client gửi `request_game_sync.rpc_id(1)` khi `_ready()`, Server trả snapshot đầy đủ qua `_on_sync_custom_entities(caller_id)`.
- Chuyển scene: Tuân thủ quy trình Two-Phase Transition (`prepare_switch_minigame_rpc` -> drain timer 0.1s -> `switch_minigame_rpc`).
- Không hardcode chuỗi text hiển thị trên UI; bắt buộc cập nhật `translations/translations.csv` đủ 11 ngôn ngữ (`en, vi, es, fr, de, pt_BR, ru, ja, ko, zh_CN, it`).
- Dọn dẹp `surface_override_material` trước khi `queue_free()` bất kỳ mesh nào.

## Review Focus
1. **Double-claim race condition:** Hai người chơi cùng phóng móc tới một viên quặng trong cùng frame/khoảng thời gian ngắn -> Server chỉ cấp quặng cho người chạm trước (`claimed_by`), người sau trượt và thu móc về rỗng.
2. **Hook stuck on scene exit:** Client/Server chuyển scene trong khi móc đang vung hoặc kéo -> RPC dở dang không làm crash SceneTree, `_exit_tree()` dọn dẹp sạch tween/timer.
3. **Empty map / All minerals collected early:** Người chơi đào hết sạch khoáng sản trước khi hết 60 giây -> Trận đấu vẫn giữ ổn định, móc phóng vào khoảng trống thu về bình thường cho tới khi timer chạm 0.
4. **Boundary collision miss:** Móc phóng ra ngoài tầm nhìn hoặc gặp góc chết không va chạm vật thể nào -> Phải có `MAX_HOOK_LENGTH` chặn lại và tự động chuyển sang `RETRACTING`.
5. **Scoreboard calculation with score ties:** Hai người chơi có số vàng bằng nhau khi hết 60s -> Xếp hạng tính điểm campaign không bị crash chia cho 0 và chia điểm công bằng.

---

### Task 1: Dữ liệu khoáng sản và script quặng mẫu

**Files:**
- Create: `scripts/minigames/gold_miner/gold_miner_item.gd`
- Create: `scenes/minigames/gold_miner/gold_miner_item.tscn`
- Test: `scripts/test/test_gold_miner_item.gd`

**Interfaces:**
- Consumes: Nothing
- Produces:
  - Class `GoldMinerItem` (extends `Area3D`)
  - Enum `Type { GOLD_LARGE, GOLD_MEDIUM, GOLD_SMALL, DIAMOND, ROCK_LARGE, ROCK_SMALL, OBSTACLE }`
  - Function `setup_item(item_id: int, item_type: int, custom_pos: Vector3) -> void`
  - Function `get_item_value() -> int`
  - Function `get_item_weight() -> float`
  - Function `is_grabbable() -> bool`

- [ ] **Step 1: Viết test kiểm tra cấu hình item quặng**
Tạo file test `scripts/test/test_gold_miner_item.gd`:
```gdscript
@tool
extends SceneTree

func _init() -> void:
	var item_script = load("res://scripts/minigames/gold_miner/gold_miner_item.gd")
	assert(item_script != null, "GoldMinerItem script must exist")
	var item = item_script.new()
	item.setup_item(1, item_script.Type.GOLD_LARGE, Vector3(0, -5, 0))
	assert(item.get_item_value() == 500, "Large gold should be 500 pts")
	assert(item.get_item_weight() >= 3.0, "Large gold should be heavy")
	assert(item.is_grabbable() == true, "Gold should be grabbable")

	item.setup_item(2, item_script.Type.OBSTACLE, Vector3(2, -5, 0))
	assert(item.is_grabbable() == false, "Obstacle should not be grabbable")
	print("TEST_GOLD_MINER_ITEM_PASS")
	quit(0)
```

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Chạy: `Godot_v4.7.2-stable_win64.exe --headless -s scripts/test/test_gold_miner_item.gd`
Kỳ vọng: FAIL vì chưa có file `scripts/minigames/gold_miner/gold_miner_item.gd`.

- [ ] **Step 3: Triển khai `gold_miner_item.gd` và scene `gold_miner_item.tscn`**
Triển khai `scripts/minigames/gold_miner/gold_miner_item.gd`:
- Định nghĩa enum `Type`
- Từ điển cấu hình `CONFIGS`:
  - `GOLD_LARGE`: value = 500, weight = 4.0, radius = 1.0, color = Yellow/Gold
  - `GOLD_MEDIUM`: value = 250, weight = 2.5, radius = 0.7, color = Yellow
  - `GOLD_SMALL`: value = 100, weight = 1.2, radius = 0.45, color = Light Yellow
  - `DIAMOND`: value = 800, weight = 0.5, radius = 0.35, color = Cyan
  - `ROCK_LARGE`: value = 50, weight = 5.0, radius = 1.1, color = Gray
  - `ROCK_SMALL`: value = 25, weight = 2.5, radius = 0.5, color = Dark Gray
  - `OBSTACLE`: value = 0, weight = 1.0, radius = 0.8, color = Dark Red/Brown, grabbable = false
- Gắn `CollisionShape3D` dạng Sphere/Box phù hợp. Tạo MeshInstance3D với CSGSphere3D/BoxMesh tương ứng.

- [ ] **Step 4: Chạy lại test để xác nhận PASS**
Chạy: `Godot_v4.7.2-stable_win64.exe --headless -s scripts/test/test_gold_miner_item.gd`
Kỳ vọng: `TEST_GOLD_MINER_ITEM_PASS` và exit code 0.

---

### Task 2: Controller tính toán va chạm và logic Server-Authoritative Móc

**Files:**
- Create: `scripts/minigames/gold_miner/gold_miner.gd`
- Create: `scenes/minigames/gold_miner/gold_miner.tscn`
- Test: `scripts/test/test_gold_miner_logic.gd`

**Interfaces:**
- Consumes:
  - `BaseMinigame` (`scripts/minigames/base_minigame.gd`)
  - `GoldMinerItem` (`scripts/minigames/gold_miner/gold_miner_item.gd`)
- Produces:
  - Class `GoldMiner` extends `BaseMinigame`
  - Enum `HookState { SWINGING, EXTENDING, RETRACTING }`
  - Function `_tick_hook_server(peer_id: int, delta: float) -> void`
  - Function `_check_first_hit(peer_id: int, hook_origin: Vector3, hook_dir: Vector3, length: float) -> int`
  - RPC `@rpc("any_peer", "reliable") func request_drop_hook() -> void`
  - RPC `@rpc("authority", "reliable") func sync_hook_event(peer_id: int, state: int, angle: float) -> void`
  - RPC `@rpc("authority", "reliable") func sync_item_collected(peer_id: int, item_id: int, new_score: int) -> void`

- [ ] **Step 1: Viết test cho máy trạng thái và kiểm tra va chạm first-hit**
Tạo file `scripts/test/test_gold_miner_logic.gd`:
```gdscript
@tool
extends SceneTree

func _init() -> void:
	var gm_script = load("scripts/minigames/gold_miner/gold_miner.gd")
	assert(gm_script != null, "GoldMiner script must exist")
	var gm = gm_script.new()
	# Kiểm tra khởi tạo hook state
	var h = gm.create_default_hook_data(Vector3(0, 5, 0))
	assert(h.state == gm_script.HookState.SWINGING, "Hook must start SWINGING")

	# Test first-hit sorting: vật thể A cách 2m, vật thể B cách 5m trên cùng tia
	var items = {
		1: {"pos": Vector3(0, 0, 0), "radius": 0.8, "active": true, "grabbable": true}, # length = 5
		2: {"pos": Vector3(0, 3, 0), "radius": 0.8, "active": true, "grabbable": true}  # length = 2
	}
	var hit_id = gm.find_first_hit(Vector3(0, 5, 0), Vector3(0, -1, 0), 6.0, items)
	assert(hit_id == 2, "Must hit item 2 first because it is closest along the ray")

	# Test speed formula
	var speed_diamond = gm.calculate_retract_speed(0.5)
	var speed_rock = gm.calculate_retract_speed(5.0)
	assert(speed_diamond > speed_rock, "Diamond must retract faster than rock")

	print("TEST_GOLD_MINER_LOGIC_PASS")
	quit(0)
```

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Chạy: `Godot_v4.7.2-stable_win64.exe --headless -s scripts/test/test_gold_miner_logic.gd`
Kỳ vọng: FAIL vì chưa có `scripts/minigames/gold_miner/gold_miner.gd`.

- [ ] **Step 3: Triển khai core logic trong `gold_miner.gd`**
- Kế thừa `BaseMinigame`.
- Định nghĩa constants:
  - `MATCH_DURATION = 60.0`
  - `SWING_SPEED = 2.2` rad/s
  - `MAX_SWING_ANGLE = 70.0` độ
  - `BASE_EXTEND_SPEED = 14.0`
  - `BASE_RETRACT_SPEED = 12.0`
  - `MAX_HOOK_LENGTH = 22.0`
- Quản lý `hooks: Dictionary` (`peer_id -> {state, angle, length, target_item_id, origin}`)
- Quản lý `minerals: Dictionary` (`item_id -> GoldMinerItem`)
- Quản lý `gold_scores: Dictionary` (`peer_id -> int`)
- Thuật toán `find_first_hit`: Duyệt tất cả item còn active và grabbable, tính hình chiếu lên tia và khoảng cách, chọn item có `distance_along_ray` nhỏ nhất trong phạm vi `length`.
- Quản lý va chạm và thu dây:
  - Khi `EXTENDING`: tăng `length`. Nếu chạm item, gán `target_item_id = hit_id`, đổi sang `RETRACTING`. Nếu chạm `MAX_HOOK_LENGTH`, đổi sang `RETRACTING` không mục tiêu.
  - Khi `RETRACTING`: giảm `length` theo `speed = BASE_RETRACT_SPEED / item.weight`. Khi `length <= 0`, cộng điểm cho `peer_id`, xóa item khỏi map, reset về `SWINGING`.

- [ ] **Step 4: Chạy lại test để xác nhận PASS**
Chạy: `Godot_v4.7.2-stable_win64.exe --headless -s scripts/test/test_gold_miner_logic.gd`
Kỳ vọng: `TEST_GOLD_MINER_LOGIC_PASS`.

---

### Task 3: Scene 3D Đào Vàng (Camera Thượng Đế, Bệ Móc, Sân Mỏ, UI)

**Files:**
- Create: `scenes/minigames/gold_miner/gold_miner.tscn`
- Modify: `scripts/minigames/gold_miner/gold_miner.gd`

**Interfaces:**
- Consumes:
  - `scenes/players/player.tscn`
  - `scenes/minigames/gold_miner/gold_miner_item.tscn`
- Produces:
  - Hoàn thiện Scene Tree của `gold_miner.tscn`:
    - `Camera3D` cố định góc nhìn từ trên xuống bao quát toàn bộ 4 bệ đào vàng và vùng mỏ (Y=18, Z=10, rotation_degrees=(-55, 0, 0)) với `current = true`.
    - Node `MiningSurface`: Sàn ngầm màu đất tối.
    - Node `RigPositions`: 4 vị trí gắn bệ cẩu trải đều hàng ngang:
      - Slot 0: `Vector3(-9, 0, -6)`
      - Slot 1: `Vector3(-3, 0, -6)`
      - Slot 2: `Vector3(3, 0, -6)`
      - Slot 3: `Vector3(9, 0, -6)`
    - Node `MineralsContainer`: Chứa các node quặng spawn ra.
    - Node `HooksContainer`: Chứa dây cáp và đầu móc. Vẽ dây bằng `ImmediateMesh` hoặc `CylinderMesh`.
    - Node `UI`: Kế thừa UI chuẩn từ `BaseMinigame` (Timer label, Tutorial overlay, Scoreboard overlay) kèm `PlayerScoresVBox` ở góc trên bên phải hiển thị điểm đào vàng real-time.

- [ ] **Step 1: Tạo scene 3D `scenes/minigames/gold_miner/gold_miner.tscn`**
Tạo file scene `.tscn` bằng Godot hoặc text editor chứa đầy đủ cấu trúc node, môi trường ánh sáng `DirectionalLight3D`, `WorldEnvironment`, `Camera3D`, container node và CanvasLayer UI.

- [ ] **Step 2: Nối các hàm lifecycle `BaseMinigame` trong `gold_miner.gd`**
- `_get_tutorial_data()`: Trả về metadata tutorial (Title, Rules, Controls, Image).
- `_get_spawn_positions()`: Trả về 4 tọa độ của `RigPositions`.
- `_on_minigame_ready()`: Đặt `match_timer = MATCH_DURATION`.
- `_on_post_initialize()`: Server sinh bãi quặng mẫu (seed cố định hoặc procedural cân bằng) và khởi tạo hook data cho tất cả player.
- `_on_minigame_tick(delta)`: Server cập nhật swing / extend / retract của các hook, gửi timer và state unreliable cho client. Client nội suy vị trí đầu gắp và vẽ dây cáp.
- `_on_sync_custom_entities(caller_id)`: Gửi toàn bộ snapshot khoáng sản còn lại, hook state và điểm số của tất cả người chơi cho client vừa handshake.

- [ ] **Step 3: Xử lý hết giờ và kết thúc round**
Khi `match_timer <= 0.0`:
- Server khóa input, xếp hạng người chơi theo `gold_scores` giảm dần (người nhiều điểm nhất xếp cuối cùng trong `elimination_order` để nhận 1000 điểm campaign theo công thức `_calculate_round_scores`).
- Gọi `_process_round_end(winner_id)` hiển thị scoreboard chuẩn của `BaseMinigame`.

---

### Task 4: Tích hợp Campaign Tournament và Lobby Navigation

**Files:**
- Modify: `scripts/minigames/base_minigame.gd:929-938`
- Modify: `scripts/core/main.gd:636-639, 913-927`
- Test: `scripts/test/test_gold_miner_campaign_flow.gd`

**Interfaces:**
- Consumes:
  - `scenes/minigames/gold_miner/gold_miner.tscn`
- Produces:
  - Bổ sung `GoldMiner` vào danh sách vòng lặp Campaign (`_get_next_minigame_scene`)
  - Bổ sung `GoldMiner` vào lobby transition (`_change_to_minigame` và `_pick_random_map`)

- [ ] **Step 1: Viết test cho chuyển cảnh Campaign**
Tạo file `scripts/test/test_gold_miner_campaign_flow.gd`:
```gdscript
@tool
extends SceneTree

func _init() -> void:
	var bm_script = load("res://scripts/minigames/base_minigame.gd")
	var bm = bm_script.new()
	bm.name = "StableFooting"
	var next_scene = bm._get_next_minigame_scene()
	# Kiểm tra vòng lặp có chứa gold_miner.tscn
	assert("gold_miner" in next_scene or "mimic" in next_scene, "Next scene must route properly")
	print("TEST_GOLD_MINER_CAMPAIGN_FLOW_PASS")
	quit(0)
```

- [ ] **Step 2: Cập nhật `base_minigame.gd`**
Trong `_get_next_minigame_scene()`:
Xoay vòng 4 map: `HotBomb` -> `StableFooting` -> `GoldMiner` -> `Mimic` -> `HotBomb`:
```gdscript
func _get_next_minigame_scene() -> String:
	var current_map_name = name.to_lower()
	if "hotbomb" in current_map_name or "bomb" in current_map_name:
		return "res://scenes/minigames/stable_footing/stable_footing.tscn"
	elif "stablefooting" in current_map_name or "footing" in current_map_name:
		return "res://scenes/minigames/gold_miner/gold_miner.tscn"
	elif "goldminer" in current_map_name or "miner" in current_map_name:
		return "res://scenes/minigames/mimic/mimic.tscn"
	elif "mimic" in current_map_name:
		return "res://scenes/minigames/hot_bomb/hot_bomb.tscn"
	return "res://scenes/minigames/hot_bomb/hot_bomb.tscn"
```

- [ ] **Step 3: Cập nhật `main.gd`**
Trong `_change_to_minigame(map_name)`:
Thêm nhánh:
```gdscript
elif map_name == "GoldMiner":
	GameSession.minigame_players = player_info.duplicate(true)
	get_tree().change_scene_to_file("res://scenes/minigames/gold_miner/gold_miner.tscn")
```
Trong `_pick_random_map()`:
Thêm `"GoldMiner"` vào mảng: `["HotBomb", "StableFooting", "GoldMiner", "Mimic"]`.

- [ ] **Step 4: Chạy test campaign flow để xác nhận PASS**
Chạy: `Godot_v4.7.2-stable_win64.exe --headless -s scripts/test/test_gold_miner_campaign_flow.gd`
Kỳ vọng: `TEST_GOLD_MINER_CAMPAIGN_FLOW_PASS`.

---

### Task 5: Đa ngôn ngữ (Localization - 11 ngôn ngữ)

**Files:**
- Modify: `translations/translations.csv`
- Test: `scripts/test/test_gold_miner_i18n.gd`

**Interfaces:**
- Consumes: Nothing
- Produces:
  - 11 bản dịch cho các key:
    - `MINIGAME_GOLD_MINER`
    - `GOLD_MINER_RULES`
    - `GOLD_MINER_CONTROLS_HINT`
    - `GOLD_MINER_SCORE_ITEM`
    - `GOLD_MINER_SCORE_HUD`

- [ ] **Step 1: Viết test xác nhận đầy đủ 11 ngôn ngữ trong CSV**
Tạo file `scripts/test/test_gold_miner_i18n.gd`:
```gdscript
@tool
extends SceneTree

func _init() -> void:
	var f = FileAccess.open("res://translations/translations.csv", FileAccess.READ)
	assert(f != null, "translations.csv must exist")
	var header = f.get_line()
	var cols = header.split(",")
	assert(cols.size() == 12, "Must have 12 columns: keys + 11 locales")
	
	var found_keys = {}
	while not f.eof_reached():
		var line = f.get_line().strip_edges()
		if line.begins_with("MINIGAME_GOLD_MINER,"):
			found_keys["MINIGAME_GOLD_MINER"] = true
		elif line.begins_with("GOLD_MINER_RULES,"):
			found_keys["GOLD_MINER_RULES"] = true
		elif line.begins_with("GOLD_MINER_CONTROLS_HINT,"):
			found_keys["GOLD_MINER_CONTROLS_HINT"] = true

	assert("MINIGAME_GOLD_MINER" in found_keys, "MINIGAME_GOLD_MINER key missing")
	assert("GOLD_MINER_RULES" in found_keys, "GOLD_MINER_RULES key missing")
	assert("GOLD_MINER_CONTROLS_HINT" in found_keys, "GOLD_MINER_CONTROLS_HINT key missing")
	print("TEST_GOLD_MINER_I18N_PASS")
	quit(0)
```

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Chạy: `Godot_v4.7.2-stable_win64.exe --headless -s scripts/test/test_gold_miner_i18n.gd`
Kỳ vọng: FAIL vì chưa thêm các key trên vào CSV.

- [ ] **Step 3: Thêm các dòng dịch thuật vào `translations/translations.csv`**
Cập nhật đúng format CSV:
- `MINIGAME_GOLD_MINER,Gold Miner 3D,Đào Vàng 3D,Minería de Oro 3D,Mineur d'Or 3D,Goldgräber 3D,Minerador de Ouro 3D,Золотоискатель 3D,ゴールドマイナー3D,골드 마이너 3D,黄金矿工3D,Minatore d'Oro 3D`
- `GOLD_MINER_RULES,Launch your hook to grab gold and diamonds! Avoid heavy rocks and obstacles. Most points wins!,Phóng móc gắp vàng và kim cương! Tránh đá nặng và vật cản. Ai nhiều điểm nhất sẽ thắng!,¡Lanza tu gancho para agarrar oro y diamantes! Evita rocas pesadas y obstáculos.,Lancez votre crochet pour attraper l'or et les diamants! Évitez les rochers lourds.,Wirf deinen Haken nach Gold und Diamanten! Weiche schweren Steinen aus.,Lance seu gancho para pegar ouro e diamantes! Evite pedras pesadas e obstáculos.,Запускайте крюк за золотом и алмазами! Избегайте тяжелых камней и препятствий.,フックを放って金やダイヤモンドをつかもう！重い岩や障害物を避けよう。,갈고리를 발사해 금과 다이아몬드를 획득하세요! 무거운 돌과 장애물을 피하세요.,发射钩爪抓取黄金和钻石！避开沉重的石头和障碍物，得分最高者获胜！,Lancia l'arpione per prendere oro e diamanti! Evita rocce pesanti e ostacoli.`
- `GOLD_MINER_CONTROLS_HINT,Left Click / Space: Drop Hook,Chuột trái / Phím cách: Thả móc,Clic Izquierdo / Espacio: Soltar Gancho,Clic Gauche / Espace: Lancer le Crochet,Linksklick / Leertaste: Haken Auswerfen,Clique Esquerdo / Espaço: Soltar Gancho,ЛКМ / Пробел: Сбросить Крюк,左クリック / スペース: フックを落とす,좌클릭 / 스페이스: 갈고리 발사,左键点击 / 空格: 释放钩爪,Clic Sinistro / Spazio: Lancia Arpione`

- [ ] **Step 4: Chạy lại test để xác nhận PASS**
Chạy: `Godot_v4.7.2-stable_win64.exe --headless -s scripts/test/test_gold_miner_i18n.gd`
Kỳ vọng: `TEST_GOLD_MINER_I18N_PASS`.

---

### Task 6: Toàn diện & Xác thực Headless (Integration Test)

**Files:**
- Create: `scripts/test/test_gold_miner_full.gd`

**Interfaces:**
- Consumes: Toàn bộ hệ thống Gold Miner vừa dựng
- Produces: Test kịch bản tích hợp hoàn chỉnh

- [ ] **Step 1: Viết script test tích hợp end-to-end**
Tạo file `scripts/test/test_gold_miner_full.gd`:
- Instantiate `scenes/minigames/gold_miner/gold_miner.tscn`.
- Giả lập 2 player kết nối.
- Giả lập Player 1 click thả móc -> Hook chuyển sang `EXTENDING`.
- Giả lập hook bay trúng quặng Vàng Lớn -> Hook chuyển sang `RETRACTING` với trọng lượng 4.0.
- Giả lập hook kéo về gốc -> Player 1 nhận 500 điểm.
- Giả lập hết giờ (timer = 0) -> Kiểm tra hàm `_calculate_round_scores` phân bổ điểm tournament chính xác.

- [ ] **Step 2: Chạy headless test**
Chạy: `Godot_v4.7.2-stable_win64.exe --headless -s scripts/test/test_gold_miner_full.gd`
Kỳ vọng: PASS không có bất kỳ warning hay lỗi logic nào.

- [ ] **Step 3: Cập nhật knowledge graph**
Chạy lệnh đồng bộ đồ thị: `python update_graph.py` để cập nhật các node mới của Gold Miner vào `graphify-out/graph.json`.
