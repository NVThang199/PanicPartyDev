# PanicParty Development Guide

## Project Info
- **Engine**: Godot 4.7.2
- **Architecture**: Server-authoritative multiplayer với SteamMultiplayerPeer
- **Main scenes**:
  - `scenes/core/main.tscn` - Lobby
  - `scenes/minigames/hot_bomb/hot_bomb.tscn` - Hot Bomb minigame
  - `scenes/minigames/stable_footing/stable_footing.tscn` - Stable Footing minigame

## Multiplayer Pattern (MUST FOLLOW)

### Core Rules
1. **Server authority**: Chỉ server (`multiplayer.is_server()`) tính toán game logic, physics, timer.
2. **Client prediction**: Client chỉ render và interpolate từ server state.
3. **RPC direction**:
   - `@rpc("authority", ...)` - Server → Client broadcast
   - `@rpc("any_peer", ...)` - Client → Server request
4. **RPC Call Syntax**: Khi muốn gửi RPC qua mạng, **BẮT BUỘC** gọi `method_name.rpc(...)` hoặc `method_name.rpc_id(target_id, ...)`. Gọi `method_name(...)` trực tiếp chỉ chạy local trên máy hiện tại, **KHÔNG** gửi qua mạng dù có khai báo `@rpc`!

---

### Checklist khi thêm tính năng mới

#### 1. Entity Spawning & Deduplication
```gdscript
# Server spawns & broadcasts
func initialize_entities() -> void:
    if not multiplayer.is_server():
        return
    for pid in player_data:
        spawn_player.rpc(pid, ...)  # ← BẮT BUỘC .rpc, KHÔNG gọi spawn_player() trực tiếp

@rpc("authority", "call_local", "reliable")
func spawn_player(peer_id: int, char_path: String, p_name: String, s_id: int, pos: Vector3) -> void:
    # Tránh spawn trùng lặp khi nhận broadcast + sync trễ
    if peer_id in players and is_instance_valid(players[peer_id]):
        return
    var old_node = get_node_or_null(str(peer_id))
    if old_node:
        remove_child(old_node)
        old_node.queue_free()

    var player = PLAYER_SCENE.instantiate()
    player.name = str(peer_id)
    player.position = pos
    player.set_multiplayer_authority(peer_id)
    player.set_player_name(p_name)
    player.steam_id = s_id
    add_child(player)
    players[peer_id] = player
```

#### 2. Scene Transition & Late-join Handshake (CRITICAL)
Client có thể load scene chậm hơn Server vài frame, làm rớt các RPC broadcast ban đầu. **Luôn dùng mô hình Handshake**:
```gdscript
# Trong _ready() của scene minigame/mới:
func _ready() -> void:
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    if multiplayer.is_server():
        call_deferred("initialize_game")
    else:
        request_game_sync.rpc_id(1)  # ← Client load xong chủ động xin dữ liệu từ Server

@rpc("any_peer", "reliable")
func request_game_sync() -> void:
    if not multiplayer.is_server():
        return
    var caller_id = multiplayer.get_remote_sender_id()
    if caller_id == 0:
        caller_id = multiplayer.get_unique_id()
    
    # 1. Gửi GameState & Timer hiện tại
    sync_game_state.rpc_id(caller_id, state)
    sync_match_timer.rpc_id(caller_id, match_timer)
    
    # 2. Gửi danh sách entity đã spawn
    for pid in players:
        var p = players[pid]
        if is_instance_valid(p):
            spawn_player.rpc_id(caller_id, pid, p.character_path, p.player_name, p.steam_id, p.position)
```

#### 3. GameState & Timer Sync
```gdscript
# Server đồng bộ state (tránh client bị kẹt ở INITIALIZING và return sớm ở _process)
@rpc("authority", "call_local", "reliable")
func sync_game_state(new_state: int) -> void:
    state = new_state as GameState

# Server broadcast timer mỗi frame
func _process(delta: float) -> void:
    if state != GameState.PLAYING:
        return
    if multiplayer.is_server():
        match_timer -= delta
        sync_match_timer.rpc(match_timer)
    
    # Cập nhật UI trên cả Server lẫn Client
    if match_timer_label:
        match_timer_label.text = "Match: %d" % int(max(0, match_timer))

@rpc("authority", "unreliable")
func sync_match_timer(time_left: float) -> void:
    if multiplayer.is_server():
        return
    match_timer = time_left
    if match_timer_label:
        match_timer_label.text = "Match: %d" % int(max(0, match_timer))
```

#### 4. Safe State Sync (Tránh Crash Lúc Chuyển Scene)
Khi scene chuyển đổi, RPC từ frame trước có thể đến khi node hoặc `multiplayer` đang bị giải phóng.
```gdscript
@rpc("any_peer", "unreliable")
func sync_player_state(peer_id: int, pos: Vector3, rot_y: float, anim_name: String) -> void:
    # 1. Bảo vệ: scene đã ra khỏi tree
    if not is_inside_tree():
        return
    # 2. Bảo vệ: multiplayer hoặc peer bị null
    if not multiplayer or not multiplayer.multiplayer_peer or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
        return
    # 3. Cache unique_id trước để tránh race condition peer null giữa 2 dòng
    var local_id := multiplayer.get_unique_id()
    if local_id == 0 or peer_id == local_id:
        return
    # 4. Kiểm tra node tồn tại và trong tree
    var player = players.get(peer_id)
    if player and is_instance_valid(player) and player.is_inside_tree():
        player._apply_state(pos, rot_y, anim_name)
```

#### 5. Player Input → Server Validation
```gdscript
func _input(event: InputEvent) -> void:
    if is_multiplayer_authority():
        if Input.is_action_just_pressed("action"):
            if multiplayer.is_server():
                do_action()
            else:
                request_action.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func request_action() -> void:
    if not multiplayer.is_server():
        return
    var sender = multiplayer.get_remote_sender_id()
    if sender == 0:
        sender = multiplayer.get_unique_id()
    do_action()
    action_confirmed.rpc(sender)
```

---

### Common Pitfalls (CỰC KỲ QUAN TRỌNG)

❌ **Tránh**:
1. `spawn_player(...)` trong hàm của Server mà quên `.rpc(...)` → Client không bao giờ spawn được entity.
2. Tin tưởng 100% Client load scene cùng lúc với Server → Client rớt gói tin spawn ban đầu.
3. Không đồng bộ `state = GameState.PLAYING` sang Client → Client bị kẹt ở `INITIALIZING`, UI timer không chạy.
4. Gọi `multiplayer.get_unique_id()` mà không check null `multiplayer` và `multiplayer.multiplayer_peer` trước.
5. Thiếu `current = true` trên Camera3D của scene minigame.
6. `reparent()` các node có nhận/gửi RPC (như Bomb vào tay nhân vật) → làm thay đổi NodePath giữa chừng, gây lỗi `get_node: Node not found` do mạng lệch frame.
7. Gọi `queue_free()` mà không `remove_child()` trước khi thêm node mới cùng tên → Godot tự đổi tên node thành `@Node3D@...`, lệch NodePath RPC giữa các máy.
8. Gửi RPC khi peer chưa kết nối xong (`get_connection_status() != CONNECTION_CONNECTED`) → sinh lỗi `Trying to call an RPC via a multiplayer peer which is not connected`. Phải đợi `multiplayer.connected_to_server`.
9. Server tự push RPC broadcast (`.rpc()`) ngay khi server vừa chuyển xong scene mới (như quay về Lobby) → Client chưa load xong sẽ rớt gói và sinh lỗi `Node not found: "Main3D"`. Luôn để Client load xong rồi chủ động gửi RPC xin sync (`request_restore_player` / `register_player`).
10. Không ngắt `_process` khi đổi scene hoặc thiếu check `if not is_inside_tree(): return` trong các hàm RPC → gói tin RPC (như ping, sync) nhận khi node đang rời SceneTree làm sụp C++ `Node3D::get_global_transform()` sinh hàng trăm lỗi `Condition "!is_inside_tree()" is true`.
11. Quên lưu `character_path` vào Player node khi spawn → Người chơi join muộn (hoặc late-join sync) không đồng bộ được nhân vật đúng, dùng model mặc định hoặc của host.
12. Client gọi `explode_rpc.rpc()` trên RPC `@rpc("authority", ...)` → RPC không broadcast được vì chỉ server authority mới gửi được. Phải để Server gọi `.rpc()` broadcast.
13. Server gọi hàm local (như `die_in_minigame()`) trước khi broadcast RPC → Chỉ Server thấy hiệu ứng, Client không thấy. Xóa call local, để RPC với `call_local` xử lý cả Server lẫn Client.
14. Đổi scene bằng `call_local` hoặc delay một phía gây lệch frame chuyển scene (Race condition `Node not found: "Main3D"` / `Node not found: "StableFooting"`):
    - Server đổi scene ngay: Client vẫn đang ở scene cũ bắn `sync_player_state` lên Server đã sang scene mới → Server báo `Node not found: "Main3D"` hoặc `"HotBomb"`.
    - Server delay `await timer` nhưng Client đổi scene ngay: Client vào scene mới bắn `request_game_sync.rpc_id(1)` lên Server vẫn đang ở scene cũ → Server báo `Node not found: "StableFooting"`.
15. Xóa node `MeshInstance3D` (hoặc phụ kiện/model) có gắn `surface_override_material` bằng `queue_free()` mà không gỡ material trước → Gây crash/warning C++ engine RendererRD Vulkan: `material_casts_shadows: Parameter "material" is null`, `material_update_dependency: Parameter "material" is null`.
16. Load tài nguyên với đường dẫn rỗng `""` (`load("")` hoặc `ResourceLoader.load("res://")`) → Gây lỗi C++ engine: `Resource file not found: res:// (expected type: unknown)`.
17. Dùng `await anim_player.animation_finished` trần trụi trong coroutine điều khiển trạng thái (như `is_knocked_down`, `is_pushing`):
    - Trong Godot 4, khi một animation đang chạy bị ngắt bởi `play()` hoặc `stop()` khác (ví dụ: đang bị ngã mà nhấn ném bom hoặc bị đá tiếp), engine **KHÔNG BAO GIỜ** phát tín hiệu `animation_finished`.
    - Coroutine bị treo vĩnh viễn, cờ trạng thái (`is_knocked_down = true`) không bao giờ được reset về `false`, khiến nhân vật bị đơ/đứng im vĩnh viễn không thể di chuyển hay nhận input.
    - Cần bọc input action (`throw_bomb`, `push`) với điều kiện `not is_knocked_down`, và thay `await anim_player.animation_finished` bằng hàm đợi an toàn có giới hạn thời gian (timer timeout fallback + frame check).

✅ **Đúng**:
1. Luôn dùng `method.rpc(...)` để gửi RPC.
2. Dùng pattern `request_game_sync.rpc_id(1)` từ Client lên Host khi `_ready()`.
3. Đồng bộ cả GameState và Timers mỗi frame qua RPC unreliable.
4. Kiểm tra 4 lớp an toàn trong mọi RPC nhận state (`is_inside_tree`, `multiplayer`, `local_id`, `is_instance_valid`).
5. Giữ các node mạng (như Bomb) ở NodePath cố định (trực tiếp dưới root minigame), bám theo tay nhân vật bằng cách gán `global_position` trong `_physics_process` thay vì `reparent()`.
6. Luôn gọi `remove_child(old_node)` trước `old_node.queue_free()` để giữ sạch tên node.
7. Đợi peer đạt `CONNECTION_CONNECTED` (signal `connected_to_server`) trước khi phát bất kỳ RPC nào từ Client.
8. Trở về lobby dùng mô hình Client-pull: Client vào `_ready()` tự gửi `register_player.rpc_id(1)` lên Server, Server không broadcast trước.
9. Gọi `set_process(false)` và `set_physics_process(false)` trước khi gọi `get_tree().change_scene_to_file(...)`, kèm `if not is_inside_tree(): return` ở đầu tất cả các hàm RPC.
10. **Quy trình chuyển scene 2 giai đoạn (Two-Phase Scene Transition)**:
    - **Giai đoạn 1 (Freeze traffic)**: Server phát RPC `prepare_start_game_rpc.rpc()` (hoặc `prepare_return_to_lobby_rpc.rpc()`). Toàn bộ client đặt `is_starting = true` / `is_returning = true`, tắt `_process`, tắt `set_physics_process` trên tất cả players, ngừng bắn `sync_player_state` và ping.
    - **Xả mạng (Drain)**: Server đợi `await get_tree().create_timer(0.1).timeout` để các gói tin in-flight đến nốt và rơi vào node cũ an toàn.
    - **Giai đoạn 2 (Switch scene)**: Server phát RPC `start_game_rpc.rpc()` / `return_to_lobby_rpc.rpc()` rồi Server đổi scene ngay. Client nhận được RPC mới bắt đầu đổi scene. Server luôn sang scene mới trước hoặc cùng lúc Client, sẵn sàng nhận `request_game_sync`.
11. **Dọn dẹp Material trước khi queue_free**: Luôn gọi `_clear_materials_recursive(node)` (set surface override material về `null`) trước khi `queue_free()` bất kỳ mesh/model/phụ kiện nào.
12. **Kiểm tra đường dẫn tài nguyên**: Luôn check `if path != "" and ResourceLoader.exists(path):` trước khi `load(path)`. Đường dẫn face mặc định fallback về `"res://assets/characters/face/robloxmanface.png"`.
13. **Đợi Animation an toàn (Safe Animation Await Pattern)**:
    - Dùng `_safe_wait_animation(anim_name, duration)` kiểm tra mỗi frame `timer.time_left > 0` và `anim_player.current_animation == anim_name`. Nếu bị ngắt bởi animation khác hoặc hết thời gian thì tự động thoát loop, đảm bảo cờ trạng thái (`is_knocked_down = false`, `is_pushing = false`) luôn luôn được giải phóng.
    - Luôn chặn các hành động input (`throw_bomb`, `push`) khi đang ở trạng thái bị khống chế (`is_knocked_down`).

---

### File Structure Reference
- `scripts/core/main.gd` - Lobby logic, room code, player spawn/despawn
- `scenes/minigames/hot_bomb/` & `scripts/minigames/hot_bomb/` - Hot Bomb minigame (`hot_bomb.gd`, `bomb.gd`, `hot_bomb.tscn`, `bomb.tscn`)
- `scenes/minigames/stable_footing/` & `scripts/minigames/stable_footing/` - Stable Footing minigame (`stable_footing.gd`, `stable_footing.tscn`, `stable_footing_tile.gd`)
- `scripts/players/player.gd` - Player controller (client input → server validation, animation)
- `scripts/systems/networking.gd` - Steam relay transport, lobby code management

## Testing Multiplayer
1. Build → Export Windows Desktop
2. Chạy 2 instances với 2 tài khoản Steam (hoặc dùng mã phòng)
3. Kiểm tra Godot debugger **Errors tab** cho RPC/authority warnings

## Room Code System (Steam Lobby ID)
- **Host**: Bấm "Host Server" → Vào phòng lobby → Nút "COPY MÃ PHÒNG" hiện ở thanh LobbyPanel dưới màn hình. Click để copy Steam Lobby ID vào clipboard.
- **Client**: Main menu → Nhập mã vào ô "Nhập mã phòng..." dưới cùng → Bấm "Vào" để kết nối trực tiếp qua `Steam.joinLobby(lobby_id)`.
- Hoạt động cho mọi tài khoản Steam (kể cả Limited Account chưa nạp 5$), không bắt buộc kết bạn Steam.

## Graphify Codebase Exploration (Token Optimization)

Dự án đã tích hợp Graphify knowledge graph tại `graphify-out/graph.json` và `graphify-out/GRAPH_REPORT.md` để khám phá mã nguồn mà không đọc tràn lan file (tiết kiệm 80-90% token).

### Quy tắc Agent (MANDATORY):
1. **Tra cứu trước khi đọc code**: Trước khi dùng `Read` hay `Grep` trên diện rộng, **BẮT BUỘC** chạy lệnh `graphify query` để định vị kiến trúc, node liên quan và quan hệ RPC/Signal:
   ```bash
   graphify query "<từ khóa hoặc câu hỏi>" --graph graphify-out/graph.json
   ```
2. **Khám phá quan hệ & luồng gọi**:
   - `graphify explain "<tên hàm/class/signal>"`: Hiểu node và láng giềng.
   - `graphify path "<node_A>" "<node_B>"`: Tìm đường kết nối/gọi giữa 2 thành phần (ví dụ giữa UI và RPC).
   - Xem tổng quan kiến trúc tại `graphify-out/GRAPH_REPORT.md`.
3. **Cập nhật đồ thị**: Đã tự động qua hook (`.claude/settings.json` và `.githooks/pre-commit`). Chạy thủ công nếu cần:
   ```bash
   python update_graph.py
   ```
4. Chỉ mở `Read` đúng hàm/dòng đã được định vị qua Graphify thay vì đọc cả file lớn.

## Git & Workflow Discipline (MANDATORY)
- **Revert over patching**: Khi nhận phản hồi tiếp cận sai hoặc yêu cầu làm lại: BẮT BUỘC dùng `git restore <file>` để đưa file về trạng thái sạch ban đầu trước khi viết lại, KHÔNG viết code vá chắp vá đè lên code hỏng gây rác codebase.
- **Không tự ý commit/push**: Tuyệt đối không tự ý chạy `git commit` hoặc `git push` trừ khi người dùng yêu cầu rõ ràng.

---

## Multilingual & Localization Architecture (HỆ THỐNG ĐA NGÔN NGỮ)

### 1. Supported Languages (11 ngôn ngữ)
- **English** (`en`) - Mặc định (Default & Fallback)
- **Tiếng Việt** (`vi`) - Bắt buộc hỗ trợ đầy đủ dấu thanh
- **Español** (`es`) - Tây Ban Nha
- **Français** (`fr`) - Pháp
- **Deutsch** (`de`) - Đức
- **Português (Brasil)** (`pt_BR`) - Bồ Đào Nha
- **Русский** (`ru`) - Nga
- **日本語** (`ja`) - Nhật
- **한국어** (`ko`) - Hàn
- **简体中文** (`zh_CN`) - Trung giản thể
- **Italiano** (`it`) - Ý

### 2. File Organization & Registration
- **CSV Translation Source**: `translations/translations.csv` (UTF-8 format, Header: `keys,en,vi,es,fr,de,pt_BR,ru,ja,ko,zh_CN,it`).
- **Compiled Resources**: Tự động sinh bởi Godot engine khi import CSV: `translations.<locale>.translation`.
- **Project Registration**: Đã cấu hình trong `project.godot`:
  ```ini
  [internationalization]
  locale/translations=PackedStringArray("res://translations/translations.en.translation", "res://translations/translations.vi.translation", "res://translations/translations.es.translation", "res://translations/translations.fr.translation", "res://translations/translations.de.translation", "res://translations/translations.pt_BR.translation", "res://translations/translations.ru.translation", "res://translations/translations.ja.translation", "res://translations/translations.ko.translation", "res://translations/translations.zh_CN.translation", "res://translations/translations.it.translation")
  locale/fallback="en"
  ```

### 3. Setting & Persistence (`SettingsManager`)
- **Vị trí UI**: Menu Cài đặt (`settings_menu.tscn`) -> Tab **Display** (`setting-display`) -> Dòng đầu tiên `LanguageHBox/LanguageOption`.
- **Lưu trữ cấu hình**: `user://settings.cfg` dưới section `[display]` với key `language = "en"`.
- **Áp dụng ngôn ngữ**:
  ```gdscript
  TranslationServer.set_locale(settings["display"].get("language", "en"))
  ```

### 4. Development Rules (BẮT BUỘC TUÂN THỦ KHI PHÁT TRIỂN TIẾP)
1. **Không hardcode chuỗi text hiển thị trên UI**:
   - Tất cả Label, Button, Tooltip, Dialog, Banners phải dùng `tr("KEY")` hoặc key CSV tương ứng.
   - Text có tham số: dùng `tr("KEY") % value` hoặc `tr("KEY") % [val1, val2]`.
2. **Dynamic UI Refresh**:
   - Với các script quản lý UI có string khởi tạo runtime bằng code, luôn cài đặt listener:
   ```gdscript
   func _notification(what: int) -> void:
       if what == NOTIFICATION_TRANSLATION_CHANGED:
           _update_localized_texts()
   ```
3. **Quy trình thêm text mới**:
   - Mở `translations/translations.csv`.
   - Thêm dòng mới với `KEY` và bản dịch cho đủ 11 ngôn ngữ (không để trống).
   - Lưu file dưới định dạng UTF-8.
   - Chạy Editor hoặc `filesystem_manage(op="scan")` để Godot build lại `.translation`.
4. **Font & Glyph Rendering**:
   - Font chính `assets/ui/FSEX300.ttf` đã hỗ trợ đầy đủ Latin mở rộng, tiếng Việt có dấu (`àáạảãâ...`), tiếng Nga (Cyrillic).
   - `assets/ui/FSEX300.ttf.import` đã bật `allow_system_fallback=true` để tự động render mượt mà các ký tự CJK (Nhật/Hàn/Trung) từ font hệ thống của OS mà không bị ô vuông (tofu).