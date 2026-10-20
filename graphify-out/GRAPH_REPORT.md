# Graph Report - PanicPartyDev  (2026-10-20)

## Corpus Check
- 191 files · ~15,000 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 477 nodes · 528 edges · 41 communities (6 shown, 35 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- base_minigame.gd
- networking.gd
- Gamesession
- settings_manager.gd
- player.gd
- stable_footing.gd
- settings_menu.gd
- bomb.gd
- hot_bomb.gd
- campaign_victory_popup.gd
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
  scripts/core/main.gd → core  _Bridges community 2 → community 12_
- `func _process_match_result()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/core/main.gd → core  _Bridges community 2 → community 1_
- `func _ready()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/core/main.gd → core  _Bridges community 2 → community 13_
- `func _ready()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/players/player.gd → core  _Bridges community 2 → community 6_
- `func _ready()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/ui/character_switcher.gd → core  _Bridges community 2 → community 16_
- `func _on_invite_pressed()` --uses_singleton--> `Networking`  [EXTRACTED]
  scripts/core/main.gd → core  _Bridges community 12 → community 1_
- `func _ready()` --uses_singleton--> `Networking`  [EXTRACTED]
  scripts/core/main.gd → core  _Bridges community 12 → community 13_
- `func _on_pause_invite_pressed()` --uses_singleton--> `Networking`  [EXTRACTED]
  scripts/ui/in_game_menu.gd → core  _Bridges community 12 → community 14_

## Import Cycles
- None detected.

## Communities (41 total, 35 thin omitted)

### Community 1 - "networking.gd"
Cohesion: 0.06
Nodes (25): func _on_host_failed(), func _on_invite_pressed(), func _process_match_result(), func _exit_tree(), func _process(), func _ready(), func disconnect_and_return_to_menu(), func get_avatar_texture() (+17 more)

### Community 2 - "Gamesession"
Cohesion: 0.06
Nodes (30): func _change_to_minigame(), func _on_campaign_play_again(), func _on_campaign_toggled(), func _on_target_score_pressed(), func _sync_all_scores_to_all(), rpc func register_player(), rpc func reset_campaign_wins_rpc(), rpc func sync_all_scores() (+22 more)

### Community 5 - "settings_manager.gd"
Cohesion: 0.06
Nodes (3): signal keybinds_changed, signal settings_changed, class ButtonEffectsModule

### Community 11 - "campaign_victory_popup.gd"
Cohesion: 0.13
Nodes (3): signal play_again_requested, signal return_to_menu_requested, signal popup_closed

### Community 12 - "Networking"
Cohesion: 0.15
Nodes (12): func _on_character_confirmed(), func _on_connected_to_server(), func _on_copy_code_pressed(), func _on_deferred_register_player(), func _on_leave_pressed(), func _on_server_disconnected(), func _restore_lobby_session(), func remove_player() (+4 more)

### Community 13 - "tab_overlay.gd"
Cohesion: 0.18
Nodes (5): func _ready(), func _exit_tree(), func _ready(), func refresh(), class TabOverlay

## Knowledge Gaps
- **19 isolated node(s):** `class BaseMinigame`, `signal host_created`, `signal host_failed`, `signal client_connected`, `signal avatar_updated` (+14 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 371 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **35 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `func _ready()` connect `player.gd` to `Gamesession`?**
  _High betweenness centrality (0.140) - this node is a cross-community bridge._
- **What connects `class BaseMinigame`, `signal host_created`, `signal host_failed` to the rest of the system?**
  _19 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `base_minigame.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.03773584905660377 - nodes in this community are weakly interconnected._
- **Why does `func disconnect_and_return_to_menu()` connect `networking.gd` to `Gamesession`?**
  _High betweenness centrality (0.096) - this node is a cross-community bridge._
- **Should `networking.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.0613107822410148 - nodes in this community are weakly interconnected._
- **Why does `func _on_host_pressed()` connect `networking.gd` to `Gamesession`?**
  _High betweenness centrality (0.021) - this node is a cross-community bridge._
- **Should `Gamesession` be split into smaller, more focused modules?**
  _Cohesion score 0.05574912891986063 - nodes in this community are weakly interconnected._