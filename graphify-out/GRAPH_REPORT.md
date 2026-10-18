# Graph Report - PanicPartyDev  (2026-10-18)

## Corpus Check
- 182 files · ~15,000 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 279 nodes · 293 edges · 31 communities (3 shown, 28 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- main.gd
- networking.gd
- settings_manager.gd
- bomb.gd
- settings_menu.gd
- character_select.gd
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
10. `func _on_leave_pressed()` - 2 edges

## Surprising Connections (you probably didn't know these)
- `func _on_confirm_pressed()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/ui/character_select.gd → core  _Bridges community 0 → community 8_
- `func _on_join_code_pressed()` --uses_singleton--> `Networking`  [EXTRACTED]
  scripts/ui/main_menu.gd → core  _Bridges community 0 → community 3_

## Import Cycles
- None detected.

## Communities (31 total, 28 thin omitted)

### Community 0 - "main.gd"
Cohesion: 0.05
Nodes (14): func _on_character_confirmed(), func _on_connected_to_server(), func _on_copy_code_pressed(), func _on_deferred_register_player(), func _on_invite_pressed(), func _on_leave_pressed(), func _ready(), func _restore_lobby_session() (+6 more)

### Community 3 - "networking.gd"
Cohesion: 0.09
Nodes (19): func _exit_tree(), func _process(), func _ready(), func get_avatar_texture(), func get_local_player_name(), func get_local_steam_id(), func host_lobby(), func join_lobby_by_id() (+11 more)

### Community 8 - "character_select.gd"
Cohesion: 0.22
Nodes (4): func _on_confirm_pressed(), func _select_character(), signal character_confirmed, signal selection_cancelled

## Knowledge Gaps
- **10 isolated node(s):** `signal bomb_caught`, `signal bomb_exploded`, `signal host_created`, `signal client_connected`, `signal avatar_updated` (+5 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 219 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **28 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `func _on_invite_pressed()` connect `main.gd` to `networking.gd`?**
  _High betweenness centrality (0.037) - this node is a cross-community bridge._
- **What connects `signal bomb_caught`, `signal bomb_exploded`, `signal host_created` to the rest of the system?**
  _10 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `main.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.05319148936170213 - nodes in this community are weakly interconnected._
- **Why does `func _on_host_pressed()` connect `main.gd` to `networking.gd`?**
  _High betweenness centrality (0.031) - this node is a cross-community bridge._
- **Should `stable_footing.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.05263157894736842 - nodes in this community are weakly interconnected._
- **Why does `func initialize_game()` connect `main.gd` to `stable_footing.gd`?**
  _High betweenness centrality (0.023) - this node is a cross-community bridge._
- **Should `hot_bomb.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.05714285714285714 - nodes in this community are weakly interconnected._