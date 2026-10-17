# Graph Report - PanicPartyDev  (2026-10-17)

## Corpus Check
- 174 files · ~15,000 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 220 nodes · 238 edges · 24 communities (2 shown, 22 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- networking.gd
- Gamesession
- button_effects_config.gd
- bomb.gd
- settings_menu.gd
- settings_manager.gd

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
10. `func _on_leave_pressed()` - 2 edges

## Surprising Connections (you probably didn't know these)
- `func _on_host_pressed()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/ui/main_menu.gd → core  _Bridges community 3 → community 1_

## Import Cycles
- None detected.

## Communities (24 total, 22 thin omitted)

### Community 1 - "networking.gd"
Cohesion: 0.09
Nodes (19): func _exit_tree(), func _process(), func _ready(), func get_avatar_texture(), func get_local_player_name(), func get_local_steam_id(), func host_lobby(), func join_lobby_by_id() (+11 more)

### Community 3 - "Gamesession"
Cohesion: 0.09
Nodes (17): func _on_character_confirmed(), func _on_connected_to_server(), func _on_copy_code_pressed(), func _on_deferred_register_player(), func _on_invite_pressed(), func _on_leave_pressed(), func _ready(), func _restore_lobby_session() (+9 more)

## Knowledge Gaps
- **10 isolated node(s):** `signal bomb_caught`, `signal bomb_exploded`, `signal host_created`, `signal client_connected`, `signal avatar_updated` (+5 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 166 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **22 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `func _on_invite_pressed()` connect `Gamesession` to `networking.gd`, `main.gd`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._
- **What connects `signal bomb_caught`, `signal bomb_exploded`, `signal host_created` to the rest of the system?**
  _10 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `hot_bomb.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.0625 - nodes in this community are weakly interconnected._
- **Why does `func _on_host_pressed()` connect `networking.gd` to `Gamesession`?**
  _High betweenness centrality (0.039) - this node is a cross-community bridge._
- **Should `networking.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.09462365591397849 - nodes in this community are weakly interconnected._
- **Why does `func initialize_game()` connect `Gamesession` to `hot_bomb.gd`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **Should `main.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.06666666666666667 - nodes in this community are weakly interconnected._