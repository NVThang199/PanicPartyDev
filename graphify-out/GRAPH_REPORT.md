# Graph Report - PanicPartyDev  (2026-10-19)

## Corpus Check
- 183 files · ~15,000 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 379 nodes · 400 edges · 32 communities (3 shown, 29 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- main.gd
- networking.gd
- character_select.gd
- settings_manager.gd
- settings_menu.gd
- bomb.gd
- button_effects_config.gd

## God Nodes (most connected - your core abstractions)
1. `func _ready()` - 3 edges
2. `func _on_character_confirmed()` - 3 edges
3. `func _on_deferred_register_player()` - 3 edges
4. `func _restore_lobby_session()` - 3 edges
5. `func _on_connected_to_server()` - 3 edges
6. `func _on_invite_pressed()` - 3 edges
7. `func _on_steam_retry()` - 3 edges
8. `func _on_host_pressed()` - 3 edges
9. `func update_tab_overlay()` - 2 edges
10. `func _on_host_failed()` - 2 edges

## Surprising Connections (you probably didn't know these)
- `func _on_character_confirmed()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/core/main.gd → core  _Bridges community 5 → community 0_
- `func _on_host_pressed()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/ui/main_menu.gd → core  _Bridges community 5 → community 4_
- `func _on_join_code_pressed()` --uses_singleton--> `Networking`  [EXTRACTED]
  scripts/ui/main_menu.gd → core  _Bridges community 0 → community 4_

## Import Cycles
- None detected.

## Communities (32 total, 29 thin omitted)

### Community 0 - "main.gd"
Cohesion: 0.06
Nodes (9): func _on_character_confirmed(), func _on_connected_to_server(), func _on_copy_code_pressed(), func _on_deferred_register_player(), func _on_invite_pressed(), func _on_leave_pressed(), func _ready(), func _restore_lobby_session() (+1 more)

### Community 4 - "networking.gd"
Cohesion: 0.08
Nodes (21): func _on_host_failed(), func _exit_tree(), func _process(), func _ready(), func get_avatar_texture(), func get_local_player_name(), func get_local_steam_id(), func host_lobby() (+13 more)

### Community 5 - "character_select.gd"
Cohesion: 0.08
Nodes (15): func start_game(), func initialize_game(), func initialize_game(), func _ready(), func _on_confirm_pressed(), func _select_character(), func _select_color(), func _select_face() (+7 more)

## Knowledge Gaps
- **12 isolated node(s):** `signal host_created`, `signal host_failed`, `signal client_connected`, `signal avatar_updated`, `signal settings_changed` (+7 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 311 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **29 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `func _ready()` connect `character_select.gd` to `player.gd`?**
  _High betweenness centrality (0.182) - this node is a cross-community bridge._
- **What connects `signal host_created`, `signal host_failed`, `signal client_connected` to the rest of the system?**
  _12 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `main.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.05537098560354374 - nodes in this community are weakly interconnected._
- **Why does `func _on_host_pressed()` connect `networking.gd` to `character_select.gd`?**
  _High betweenness centrality (0.118) - this node is a cross-community bridge._
- **Should `stable_footing.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.04878048780487805 - nodes in this community are weakly interconnected._
- **Why does `func initialize_game()` connect `character_select.gd` to `stable_footing.gd`?**
  _High betweenness centrality (0.052) - this node is a cross-community bridge._
- **Should `audio_manager.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._