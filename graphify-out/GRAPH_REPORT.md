# Graph Report - PanicPartyDev  (2026-10-18)

## Corpus Check
- 183 files · ~15,000 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 347 nodes · 360 edges · 35 communities (4 shown, 31 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- networking.gd
- button_effects_config.gd
- settings_menu.gd
- bomb.gd
- Gamesession
- settings_manager.gd
- main_menu.gd
- character_select.gd
- character_switcher.gd

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
  scripts/ui/character_select.gd → core  _Bridges community 9 → community 12_
- `func _ready()` --uses_singleton--> `Gamesession`  [EXTRACTED]
  scripts/ui/character_switcher.gd → core  _Bridges community 9 → community 14_
- `func _on_join_code_pressed()` --uses_singleton--> `Networking`  [EXTRACTED]
  scripts/ui/main_menu.gd → core  _Bridges community 9 → community 11_
- `func _on_invite_pressed()` --uses_singleton--> `Steam`  [EXTRACTED]
  scripts/core/main.gd → core  _Bridges community 4 → community 9_
- `func _on_join_pressed()` --uses_singleton--> `Steam`  [EXTRACTED]
  scripts/ui/main_menu.gd → core  _Bridges community 4 → community 11_

## Import Cycles
- None detected.

## Communities (35 total, 31 thin omitted)

### Community 4 - "networking.gd"
Cohesion: 0.16
Nodes (14): func _exit_tree(), func _process(), func _ready(), func get_avatar_texture(), func get_local_player_name(), func get_local_steam_id(), func host_lobby(), func join_lobby_by_id() (+6 more)

### Community 9 - "Gamesession"
Cohesion: 0.16
Nodes (14): func _on_character_confirmed(), func _on_connected_to_server(), func _on_copy_code_pressed(), func _on_deferred_register_player(), func _on_invite_pressed(), func _on_leave_pressed(), func _ready(), func _restore_lobby_session() (+6 more)

### Community 11 - "main_menu.gd"
Cohesion: 0.17
Nodes (3): func _on_join_code_pressed(), func _on_join_pressed(), func _ready()

### Community 12 - "character_select.gd"
Cohesion: 0.18
Nodes (4): func _on_confirm_pressed(), func _select_character(), signal character_confirmed, signal selection_cancelled

## Knowledge Gaps
- **11 isolated node(s):** `signal host_created`, `signal client_connected`, `signal avatar_updated`, `signal settings_changed`, `signal keybinds_changed` (+6 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 287 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **31 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `func _on_host_pressed()` connect `Gamesession` to `main_menu.gd`, `networking.gd`?**
  _High betweenness centrality (0.041) - this node is a cross-community bridge._
- **What connects `signal host_created`, `signal client_connected`, `signal avatar_updated` to the rest of the system?**
  _11 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `stable_footing.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Why does `func _on_invite_pressed()` connect `Gamesession` to `main.gd`, `networking.gd`?**
  _High betweenness centrality (0.025) - this node is a cross-community bridge._
- **Should `audio_manager.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Why does `func initialize_game()` connect `Gamesession` to `stable_footing.gd`?**
  _High betweenness centrality (0.019) - this node is a cross-community bridge._
- **Should `hot_bomb.gd` be split into smaller, more focused modules?**
  _Cohesion score 0.05405405405405406 - nodes in this community are weakly interconnected._