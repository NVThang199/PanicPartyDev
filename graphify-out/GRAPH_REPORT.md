# Graph Report - PanicPartyDev  (2026-10-23)

## Corpus Check
- 220 files · ~15,000 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 646 nodes · 688 edges · 65 communities (7 shown, 58 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- base_minigame.gd
- networking.gd
- gold_miner.gd
- player.gd
- stable_footing.gd
- character_select.gd
- waveform_display.gd
- Gamesession
- settings_menu.gd
- bomb.gd
- hot_bomb.gd
- settings_manager.gd
- Networking
- Node
- tab_overlay.gd
- gold_miner_item.gd
- button_effects_config.gd
- Node3d
- in_game_menu.gd

## God Nodes (most connected - your core abstractions)
1. `func _ready()` - 4 edges
2. `func _on_character_confirmed()` - 3 edges
3. `func _on_deferred_register_player()` - 3 edges
4. `func _restore_lobby_session()` - 3 edges
5. `func _on_connected_to_server()` - 3 edges
6. `func _on_invite_pressed()` - 3 edges
7. `func _on_leave_pressed()` - 3 edges
8. `func _process_match_result()` - 3 edges
9. `func _ready()` - 3 edges
10. `func _on_spectator_character_cancelled()` - 3 edges

## Surprising Connections (you probably didn't know these)
- `func _on_character_confirmed()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/core/main.gd → core  _Bridges community 10 → community 15_
- `func _process_match_result()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/core/main.gd → core  _Bridges community 10 → community 2_
- `func _ready()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/core/main.gd → core  _Bridges community 10 → community 17_
- `func _on_pre_initialize()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/minigames/gold_miner/gold_miner.gd → core  _Bridges community 10 → community 3_
- `func _ready()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/players/player.gd → core  _Bridges community 10 → community 6_
- `func _on_confirm_pressed()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/ui/character_select.gd → core  _Bridges community 10 → community 8_
- `func _on_invite_pressed()` --uses_singleton--> `Networking`  [EXTRACTED]
  scripts/core/main.gd → core  _Bridges community 15 → community 2_
- `func _ready()` --uses_singleton--> `Networking`  [EXTRACTED]
  scripts/core/main.gd → core  _Bridges community 15 → community 17_
- `func _on_pause_invite_pressed()` --uses_singleton--> `Networking`  [EXTRACTED]
  scripts/ui/in_game_menu.gd → core  _Bridges community 15 → community 21_

## Import Cycles
- None detected.

## Communities (65 total, 58 thin omitted)

### Community 2 - "networking.gd"
Cohesion: 0.06
Nodes (26): func _on_host_failed(), func _on_invite_pressed(), func _process_match_result(), func _exit_tree(), func _process(), func _ready(), func disconnect_and_return_to_menu(), func get_avatar_texture() (+18 more)

### Community 3 - "gold_miner.gd"
Cohesion: 0.05
Nodes (3): func _on_pre_initialize(), func _update_scores_ui(), class GoldMiner

### Community 8 - "character_select.gd"
Cohesion: 0.07
Nodes (11): func _on_confirm_pressed(), func _select_character(), func _select_color(), func _select_face(), func _select_hat(), func _setup_color_buttons(), func _setup_face_buttons(), func _setup_hat_buttons() (+3 more)

### Community 9 - "waveform_display.gd"
Cohesion: 0.08
Nodes (4): class WaveformDisplay, signal play_again_requested, signal return_to_menu_requested, signal popup_closed

### Community 10 - "Gamesession"
Cohesion: 0.08
Nodes (23): func _change_to_minigame(), func _on_campaign_play_again(), func _on_campaign_toggled(), func _on_target_score_pressed(), func _sync_all_scores_to_all(), rpc func register_player(), rpc func reset_campaign_wins_rpc(), rpc func sync_all_scores() (+15 more)

### Community 15 - "Networking"
Cohesion: 0.15
Nodes (12): func _on_character_confirmed(), func _on_connected_to_server(), func _on_copy_code_pressed(), func _on_deferred_register_player(), func _on_leave_pressed(), func _on_server_disconnected(), func _restore_lobby_session(), func remove_player() (+4 more)

### Community 17 - "tab_overlay.gd"
Cohesion: 0.18
Nodes (5): func _ready(), func _exit_tree(), func _ready(), func refresh(), class TabOverlay

## Knowledge Gaps
- **24 isolated node(s):** `class BaseMinigame`, `signal host_created`, `signal host_failed`, `signal client_connected`, `signal avatar_updated` (+19 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 523 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **58 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `func _ready()` connect `player.gd` to `Gamesession`?**
  _High betweenness centrality (0.114) - this node is a cross-community bridge._
- **What connects `class BaseMinigame`, `signal host_created`, `signal host_failed` to the rest of the system?**
  _24 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `mimic.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.03636363636363636 - nodes in this community are weakly interconnected._
- **Why does `func _on_pre_initialize()` connect `gold_miner.gd` to `Gamesession`?**
  _High betweenness centrality (0.042) - this node is a cross-community bridge._
- **Should `base_minigame.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.038461538461538464 - nodes in this community are weakly interconnected._
- **Why does `func _update_scores_ui()` connect `gold_miner.gd` to `Gamesession`?**
  _High betweenness centrality (0.042) - this node is a cross-community bridge._
- **Should `networking.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.06060606060606061 - nodes in this community are weakly interconnected._