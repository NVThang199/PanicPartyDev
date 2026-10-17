# PanicParty Development Guide

## Project Info
- **Engine**: Godot 4.7.2
- **Architecture**: Server-authoritative multiplayer với SteamMultiplayerPeer
- **Main scenes**:
  - `scenes/core/main.tscn` - Lobby
  - `scenes/minigames/hot_bomb.tscn` - Hot Bomb minigame

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

---

### File Structure Reference
- `scripts/core/main.gd` - Lobby logic, room code, player spawn/despawn
- `scripts/minigames/hot_bomb.gd` - Minigame orchestration (server authoritative, timers, sync)
- `scripts/minigames/bomb.gd` - Bomb entity (server physics, homing, rushing on timeout, client interpolation)
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
