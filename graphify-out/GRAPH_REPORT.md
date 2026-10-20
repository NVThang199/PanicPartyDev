# Graph Report - PanicPartyDev  (2026-10-21)

## Corpus Check
- 195 files · ~15,000 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 541 nodes · 594 edges · 43 communities (6 shown, 37 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- base_minigame.gd
- Gamesession
- networking.gd
- settings_manager.gd
- player.gd
- stable_footing.gd
- waveform_display.gd
- settings_menu.gd
- bomb.gd
- hot_bomb.gd
- Networking
- tab_overlay.gd
- in_game_menu.gd
- character_switcher.gd

## God Nodes (most connected - your core abstractions)
1. `func _ready()` - 4 edges
2. `func _on_character_confirmed()` - 3 edges
3. `func _on_deferred_register_player()` - 3 edges
4. `func _restore_lobby_session()` - 3 edges
5. `func _on_connected_to_server()` - 3 edges
6. `func _on_invite_pressed()` - 3 edges
7. `func _process_match_result()` - 3 edges
8. `func _ready()` - 3 edges
9. `func _on_spectator_character_cancelled()` - 3 edges
10. `func _on_peer_disconnected()` - 3 edges

## Surprising Connections (you probably didn't know these)
- `func _on_character_confirmed()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/core/main.gd → core  _Bridges community 2 → community 13_
- `func _ready()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/core/main.gd → core  _Bridges community 2 → community 14_
- `func _ready()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/players/player.gd → core  _Bridges community 2 → community 7_
- `func _ready()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/ui/character_switcher.gd → core  _Bridges community 2 → community 17_
- `func _on_host_pressed()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/ui/main_menu.gd → core  _Bridges community 2 → community 3_
- `func _ready()` --uses_singleton--> `Networking`  [EXTRACTED]
  scripts/core/main.gd → core  _Bridges community 13 → community 14_
- `func _on_pause_invite_pressed()` --uses_singleton--> `Networking`  [EXTRACTED]
  scripts/ui/in_game_menu.gd → core  _Bridges community 13 → community 15_
- `func _on_join_code_pressed()` --uses_singleton--> `Networking`  [EXTRACTED]
  scripts/ui/main_menu.gd → core  _Bridges community 13 → community 3_

## Import Cycles
- None detected.

## Communities (43 total, 37 thin omitted)

### Community 2 - "Gamesession"
Cohesion: 0.05
Nodes (33): func _change_to_minigame(), func _on_campaign_play_again(), func _on_campaign_toggled(), func _on_target_score_pressed(), func _process_match_result(), func _sync_all_scores_to_all(), rpc func register_player(), rpc func reset_campaign_wins_rpc() (+25 more)

### Community 3 - "networking.gd"
Cohesion: 0.07
Nodes (23): func _on_host_failed(), func _exit_tree(), func _process(), func _ready(), func get_avatar_texture(), func get_local_player_name(), func get_local_steam_id(), func host_lobby() (+15 more)

### Community 6 - "settings_manager.gd"
Cohesion: 0.05
Nodes (4): class VoiceAnalyzer, signal keybinds_changed, signal settings_changed, class ButtonEffectsModule

### Community 9 - "waveform_display.gd"
Cohesion: 0.08
Nodes (4): class WaveformDisplay, signal play_again_requested, signal return_to_menu_requested, signal popup_closed

### Community 13 - "Networking"
Cohesion: 0.14
Nodes (13): func _on_character_confirmed(), func _on_connected_to_server(), func _on_copy_code_pressed(), func _on_deferred_register_player(), func _on_invite_pressed(), func _on_leave_pressed(), func _on_server_disconnected(), func _restore_lobby_session() (+5 more)

### Community 14 - "tab_overlay.gd"
Cohesion: 0.18
Nodes (5): func _ready(), func _exit_tree(), func _ready(), func refresh(), class TabOverlay

## Knowledge Gaps
- **21 isolated node(s):** `class BaseMinigame`, `signal host_created`, `signal host_failed`, `signal client_connected`, `signal avatar_updated` (+16 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 430 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **37 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `func _ready()` connect `player.gd` to `Gamesession`?**
  _High betweenness centrality (0.133) - this node is a cross-community bridge._
- **What connects `class BaseMinigame`, `signal host_created`, `signal host_failed` to the rest of the system?**
  _21 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `base_minigame.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.03773584905660377 - nodes in this community are weakly interconnected._
- **Why does `func disconnect_and_return_to_menu()` connect `Gamesession` to `networking.gd`?**
  _High betweenness centrality (0.086) - this node is a cross-community bridge._
- **Should `mimic.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.04081632653061224 - nodes in this community are weakly interconnected._
- **Why does `func initialize_game()` connect `Gamesession` to `mimic.gd`?**
  _High betweenness centrality (0.046) - this node is a cross-community bridge._
- **Should `Gamesession` be split into smaller, more focused modules?**
  _Cohesion score 0.051515151515151514 - nodes in this community are weakly interconnected._