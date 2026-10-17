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

### Checklist khi thêm tính năng mới

#### 1. Entity spawning (player, bomb, pickup)
```gdscript
# Server spawns
func spawn_entity(peer_id: int, data: Dictionary) -> void:
    if not multiplayer.is_server():
        return
    var entity = SCENE.instantiate()
    # ... setup ...
    add_child(entity)
    spawn_entity_rpc.rpc(peer_id, data)  # ← Broadcast

@rpc("authority", "call_local", "reliable")
func spawn_entity_rpc(peer_id: int, data: Dictionary) -> void:
    # Client recreates từ data
```

#### 2. State sync (position, animation, health)
```gdscript
# Server: mỗi frame gửi state
func _physics_process(delta: float) -> void:
    if not multiplayer.is_server():
        return
    # ... tính toán ...
    sync_state.rpc(global_position, state_enum)

@rpc("authority", "unreliable")
func sync_state(pos: Vector3, state: int) -> void:
    if multiplayer.is_server():
        return
    # Client interpolate
    _target_pos = pos
    _state = state
```

#### 3. Player input → Server validation
```gdscript
# Client: gửi input
func _input(event: InputEvent) -> void:
    if is_multiplayer_authority():
        if Input.is_action_just_pressed("action"):
            if multiplayer.is_server():
                do_action()  # Local
            else:
                request_action.rpc_id(1)  # → Server

@rpc("any_peer", "call_local", "reliable")
func request_action() -> void:
    if not multiplayer.is_server():
        return
    var sender = multiplayer.get_remote_sender_id()
    if sender == 0:
        sender = multiplayer.get_unique_id()
    # Validate sender authority
    do_action()
    action_confirmed.rpc(sender)  # Broadcast result
```

#### 4. Timer/Countdown sync
```gdscript
# Server owns timer
var timer: float = 60.0

func _process(delta: float) -> void:
    if multiplayer.is_server():
        timer -= delta
        sync_timer.rpc(timer)

@rpc("authority", "unreliable")
func sync_timer(time_left: float) -> void:
    if multiplayer.is_server():
        return
    timer = time_left  # Client displays
```

#### 5. Collision/Physics events
```gdscript
func _on_body_entered(body: Node3D) -> void:
    if not multiplayer.is_server():
        return  # ← Chỉ server xử lý
    # ... emit signal / RPC broadcast ...
```

#### 6. Scene transitions
```gdscript
@rpc("authority", "call_local", "reliable")
func change_scene(path: String) -> void:
    get_tree().change_scene_to_file(path)
    # Multiplayer peer persists qua scene
```

### Common Pitfalls

❌ **Tránh**:
```gdscript
# Client cũng chạy physics → desync
func _physics_process(delta):
    velocity = ...
    move_and_slide()

# RPC vào null multiplayer peer
func sync_state(...):
    if peer_id == multiplayer.get_unique_id():  # ← Crash nếu peer == null
```

✅ **Đúng**:
```gdscript
# Server-only physics
func _physics_process(delta):
    if not multiplayer.is_server():
        # Client interpolate
        global_position = global_position.lerp(_target_pos, 15.0 * delta)
        return
    # Server physics
    velocity = ...
    move_and_slide()

# Null check multiplayer peer
func sync_state(...):
    if not multiplayer.multiplayer_peer or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
        return
    if peer_id == multiplayer.get_unique_id():
        return
```

### File Structure Reference
- `scripts/core/main.gd` - Lobby logic, player spawn/despawn
- `scripts/minigames/hot_bomb.gd` - Minigame orchestration (server authoritative)
- `scripts/minigames/bomb.gd` - Bomb entity (server physics, client interpolation)
- `scripts/players/player.gd` - Player controller (client input → server validation)

## Testing Multiplayer
1. Build → Export Windows Desktop
2. Chạy 2 instances: `--server` flag cho dedicated server hoặc host trong game
3. Kiểm tra Godot debugger **Errors tab** cho RPC/authority warnings

## Code Style
- RPC functions: `snake_case` with `_rpc` suffix for broadcast handlers
- Server authority checks: đầu mỗi authoritative function
- Comments: Vietnamese OK for game logic, English for engine patterns
