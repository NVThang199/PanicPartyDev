# Task 3 Report: Scene 3D Đào Vàng (Gold Miner 3D)

## Overview
- **Task ID**: Task 3 (Plan: `docs/superpowers/plans/2026-10-21-gold-miner-3d.md`)
- **Status**: Completed
- **Target Files**:
  - `scenes/minigames/gold_miner/gold_miner.tscn`
  - `scripts/minigames/gold_miner/gold_miner.gd`
  - `scripts/test/test_gold_miner_scene.gd`

---

## 1. Scene 3D Hierarchy (`scenes/minigames/gold_miner/gold_miner.tscn`)
Constructed complete 3D scene conforming to Godot 4 standard TSCN:
- **Root Node**: `GoldMiner` (`Node3D`), attached to `scripts/minigames/gold_miner/gold_miner.gd`.
- **DirectionalLight3D**: Sunlight with cast shadow enabled, transform `Vector3(0, 18, 0)` tilted for depth.
- **WorldEnvironment**: Inherits `default_env.tres`.
- **Camera3D**: Top-down god-view with `current = true`, `fov = 55.0`, `position = Vector3(0, 16, 12)`, `rotation_degrees = Vector3(-55, 0, 0)`.
- **MiningArea**:
  - `TopGround` (`BoxMesh 32x1x6`, `position = Vector3(0, -0.5, -6)`): Upper bank where player hook rigs sit.
  - `MineFloor` (`BoxMesh 32x1x24`, `position = Vector3(0, -0.5, 9)`): Underground gold pit where minerals are placed.
- **RigPositions**: 4 `Marker3D` positions:
  - `Rig0`: `Vector3(-9, 0, -6)`
  - `Rig1`: `Vector3(-3, 0, -6)`
  - `Rig2`: `Vector3(-3, 0, -6)` (Rig2 is `Vector3(3, 0, -6)`)
  - `Rig3`: `Vector3(9, 0, -6)`
- **Containers**: `MineralsContainer` (`Node3D`), `HooksContainer` (`Node3D`).
- **UI CanvasLayer**:
  - `MatchTimerLabel`: Centered countdown label (`Match: 60`).
  - `PlayerScoresPanel`: Top-right `VBoxContainer` displaying real-time player scores.
  - `WinnerBanner`: Hidden `PanelContainer` showing winner & return button.
  - `InGameMenu`: Standard pause menu instance.

---

## 2. Minigame Integration (`scripts/minigames/gold_miner/gold_miner.gd`)
Implemented lifecycle methods and input handling inheriting from `BaseMinigame`:
- `_get_tutorial_data()`: Returns localized dictionary for `title`, `rules`, `controls`, `image`.
- `_get_spawn_positions()`: Reads `RigPositions` markers or falls back to standard 4 rig coordinates safely supporting tree / non-tree mode.
- `_on_minigame_ready()`: Caches UI references (`PlayerScoresPanel`, `MineralsContainer`, `HooksContainer`) and sets match timer to 60.0.
- `_on_post_initialize()`: Server spawns default 16 minerals distributed across the mine floor and initializes default hook parameters for connected players.
- `_unhandled_input(event)`: Validates input action (`action` or left mouse click) while in `GameState.PLAYING`, triggering hook launch via server-authoritative RPC (`request_drop_hook.rpc_id(1)`).
- `_update_hook_visuals(delta)`: Visualizes active cable (`CylinderMesh`) and hook claw/head (`SphereMesh`) oriented via `look_at` along the hook extension vector.
- `_update_scores_ui()`: Real-time dynamic UI labels for each player, highlighting the local player in gold yellow.
- `_process_gold_miner_end()`: Sorts `elimination_order` ascending by gold score (highest scorer awarded 1st place / 1000 pts) and triggers `_process_round_end(winner_id)`.

---

## 3. Unit Test Verification (`scripts/test/test_gold_miner_scene.gd`)
- Verified scene instantiation and root script type.
- Verified Camera3D presence, placement, and `current = true`.
- Verified lighting, environment, and container nodes (`MiningArea`, `MineralsContainer`, `HooksContainer`).
- Verified `RigPositions` count (>= 4) and exact spawn position values (`Vector3(-9, 0, -6)`, `Vector3(-3, 0, -6)`, `Vector3(3, 0, -6)`, `Vector3(9, 0, -6)`).
- Verified UI nodes (`MatchTimerLabel`, `PlayerScoresPanel`, `WinnerBanner`) and tutorial dictionary data.
- Execution result:
  `Godot_v4.7.2-stable_win64_console.exe --headless -s scripts/test/test_gold_miner_scene.gd` -> **TEST_GOLD_MINER_SCENE_PASS**.
