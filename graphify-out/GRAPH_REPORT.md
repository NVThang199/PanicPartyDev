# Graph Report - PanicPartyDev  (2026-10-19)

## Corpus Check
- 189 files · ~15,000 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 426 nodes · 462 edges · 38 communities (5 shown, 33 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Gamesession
- networking.gd
- settings_menu.gd
- bomb.gd
- button_effects_config.gd
- settings_manager.gd
- campaign_victory_popup.gd
- in_game_menu.gd
- Networking

## God Nodes (most connected - your core abstractions)
1. `func _ready()` - 3 edges
2. `func _on_character_confirmed()` - 3 edges
3. `func _on_deferred_register_player()` - 3 edges
4. `func _restore_lobby_session()` - 3 edges
5. `func _on_connected_to_server()` - 3 edges
6. `func _on_invite_pressed()` - 3 edges
7. `func update_tab_overlay()` - 3 edges
8. `func _on_steam_retry()` - 3 edges
9. `func _on_host_pressed()` - 3 edges
10. `func update_tab_overlay()` - 2 edges

## Surprising Connections (you probably didn't know these)
- `func _on_character_confirmed()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/core/main.gd → core  _Bridges community 0 → community 13_
- `func _on_peer_disconnected()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/ui/in_game_menu.gd → core  _Bridges community 0 → community 12_
- `func _on_host_pressed()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/ui/main_menu.gd → core  _Bridges community 0 → community 5_
- `func _exit_tree()` --uses_singleton--> `Networking`  [EXTRACTED]
  scripts/ui/in_game_menu.gd → core  _Bridges community 13 → community 12_
- `func _on_join_code_pressed()` --uses_singleton--> `Networking`  [EXTRACTED]
  scripts/ui/main_menu.gd → core  _Bridges community 13 → community 5_

## Import Cycles
- None detected.

## Communities (38 total, 33 thin omitted)

### Community 0 - "Gamesession"
Cohesion: 0.06
Nodes (26): func _change_to_minigame(), func _on_campaign_toggled(), func _on_win_target_pressed(), func _process_match_result(), rpc func register_player(), rpc func sync_campaign_config(), func _on_peer_disconnected(), func end_game_timeout() (+18 more)

### Community 5 - "networking.gd"
Cohesion: 0.08
Nodes (21): func _on_host_failed(), func _exit_tree(), func _process(), func _ready(), func get_avatar_texture(), func get_local_player_name(), func get_local_steam_id(), func host_lobby() (+13 more)

### Community 11 - "campaign_victory_popup.gd"
Cohesion: 0.13
Nodes (3): signal play_again_requested, signal return_to_menu_requested, signal popup_closed

### Community 12 - "in_game_menu.gd"
Cohesion: 0.15
Nodes (6): func _exit_tree(), func _on_pause_invite_pressed(), func _on_pause_menu_pressed(), func _on_peer_disconnected(), func _ready(), func update_tab_overlay()

### Community 13 - "Networking"
Cohesion: 0.20
Nodes (9): func _on_character_confirmed(), func _on_connected_to_server(), func _on_copy_code_pressed(), func _on_deferred_register_player(), func _on_invite_pressed(), func _on_leave_pressed(), func _ready(), func _restore_lobby_session() (+1 more)

## Knowledge Gaps
- **15 isolated node(s):** `signal host_created`, `signal host_failed`, `signal client_connected`, `signal avatar_updated`, `signal settings_changed` (+10 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 337 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **33 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `func _ready()` connect `Gamesession` to `player.gd`?**
  _High betweenness centrality (0.170) - this node is a cross-community bridge._
- **What connects `signal host_created`, `signal host_failed`, `signal client_connected` to the rest of the system?**
  _15 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Gamesession` be split into smaller, more focused modules?**
  _Cohesion score 0.05574912891986063 - nodes in this community are weakly interconnected._
- **Why does `func _on_host_pressed()` connect `networking.gd` to `Gamesession`?**
  _High betweenness centrality (0.119) - this node is a cross-community bridge._
- **Should `main.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.047619047619047616 - nodes in this community are weakly interconnected._
- **Should `audio_manager.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `stable_footing.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.05128205128205128 - nodes in this community are weakly interconnected._