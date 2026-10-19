class_name StableFooting
extends BaseMinigame

enum TileColor { GREEN, RED }

const TILE_GREEN_SCENE = preload("res://assets/terrains/floor/tile_green.fbx")
const TILE_RED_SCENE = preload("res://assets/terrains/floor/tile_red.fbx")

const CYCLE_DURATION = 7.0
const RANDOM_PHASE = 6.0
const LOCK_PHASE = 1.0
const GRID_ROWS = 9
const GRID_COLS = 7
const TILE_SPACING = 1.8
const TILE_FLIP_INTERVAL = 0.3

var tiles: Array[Node3D] = []
var tile_colors: Array[int] = []

var cycle_timer: float = CYCLE_DURATION
var flip_timer: float = 0.0
var is_random_phase: bool = true
var is_dropping: bool = false
var reset_scheduled: bool = false
var _last_lock_sec: int = -1

@onready var cycle_timer_label: Label = $UI/CycleTimerLabel
@onready var fall_detector: Area3D = $FallDetector
@onready var tile_grid: Node3D = $TileGrid


func _get_tutorial_data() -> Dictionary:
	return {
		"title": tr("MINIGAME_STABLE_FOOTING"),
		"rules": tr("STABLE_FOOTING_RULES"),
		"controls": tr("STABLE_FOOTING_CONTROLS_HINT"),
		"image": "res://assets/ui/tutorial/stable_footing.png"
	}


func _on_minigame_ready() -> void:
	if fall_detector:
		fall_detector.body_entered.connect(_on_fall_detected)
		fall_detector.body_exited.connect(_on_fall_detected)

	if tile_grid and tile_grid.get_child_count() == 0:
		_generate_tile_grid()
	else:
		_collect_existing_tiles()


func _on_pre_initialize() -> bool:
	if tiles.is_empty():
		push_error("[StableFooting] No tiles found in scene")
		return false
	_create_walls()
	return true


func _get_spawn_positions() -> Array[Vector3]:
	var center_pos = Vector3(0, 1.0, 0)
	return [
		center_pos + Vector3(-0.5, 0, -0.5),
		center_pos + Vector3(0.5, 0, -0.5),
		center_pos + Vector3(-0.5, 0, 0.5),
		center_pos + Vector3(0.5, 0, 0.5)
	]


func _on_post_initialize() -> void:
	_randomize_tiles()


func _on_minigame_tick(delta: float) -> void:
	if multiplayer.is_server():
		cycle_timer -= delta
		flip_timer -= delta

		if cycle_timer > LOCK_PHASE:
			is_random_phase = true
			if flip_timer <= 0.0:
				_randomize_tiles()
				flip_timer = TILE_FLIP_INTERVAL
		elif cycle_timer > 0.0:
			if is_random_phase:
				trigger_crumble_warning_rpc.rpc()
			is_random_phase = false
		elif not is_dropping:
			is_dropping = true
			_drop_red_tiles()
			_schedule_reset_tiles()

		sync_cycle_timer.rpc(cycle_timer)

		for peer_id in players:
			var p = players[peer_id]
			if is_instance_valid(p) and player_states.get(peer_id, {}).get("alive", false):
				if p.global_position.y < -2.0:
					player_died(peer_id)

		var alive_ids = get_alive_player_ids()
		var total_players = player_states.size()
		if (total_players >= 2 and alive_ids.size() <= 1) or alive_ids.size() == 0:
			_check_game_over()
			return

	if cycle_timer_label:
		if not is_random_phase and cycle_timer > 0:
			var lock_sec = int(ceil(cycle_timer))
			cycle_timer_label.text = "%d" % lock_sec
			if lock_sec != _last_lock_sec:
				_last_lock_sec = lock_sec
				if AudioManager:
					AudioManager.play_countdown_tick()
		else:
			_last_lock_sec = -1
			cycle_timer_label.text = ""


func _on_sync_custom_entities(caller_id: int) -> void:
	sync_cycle_timer.rpc_id(caller_id, cycle_timer)
	sync_all_tile_colors.rpc_id(caller_id, tile_colors)


func _on_player_died(_peer_id: int) -> void:
	_check_game_over()


func _on_player_disconnected(_peer_id: int) -> void:
	if multiplayer.is_server() and state == GameState.PLAYING:
		_check_game_over()


func _get_draw_text() -> String:
	return tr("SURVIVORS")


# ==============================================================================
# TILE GRID GENERATION & MANAGEMENT
# ==============================================================================

func _generate_tile_grid() -> void:
	if not tile_grid:
		return

	for i in range(GRID_ROWS):
		for j in range(GRID_COLS):
			var tile_node = Node3D.new()
			tile_node.name = "Tile_%d_%d" % [i, j]

			var x = i * TILE_SPACING - (GRID_ROWS / 2.0) * TILE_SPACING + TILE_SPACING / 2.0
			var z = j * TILE_SPACING - (GRID_COLS / 2.0) * TILE_SPACING + TILE_SPACING / 2.0
			tile_node.position = Vector3(x, 0, z)

			tile_grid.add_child(tile_node)

			var color = TileColor.GREEN if randf() > 0.5 else TileColor.RED
			var fbx = TILE_GREEN_SCENE.instantiate() if color == TileColor.GREEN else TILE_RED_SCENE.instantiate()
			fbx.scale = Vector3.ONE * TILE_SPACING
			tile_node.add_child(fbx)

			var static_body = StaticBody3D.new()
			static_body.name = "StaticBody"
			tile_node.add_child(static_body)

			var collision_shape = CollisionShape3D.new()
			var box = BoxShape3D.new()
			box.size = Vector3(TILE_SPACING, 0.2, TILE_SPACING)
			collision_shape.shape = box
			static_body.add_child(collision_shape)

			tiles.append(tile_node)
			tile_colors.append(color)


func _collect_existing_tiles() -> void:
	if not tile_grid:
		return

	for child in tile_grid.get_children():
		tiles.append(child)
		tile_colors.append(TileColor.GREEN)
		_add_tile_model(child, TileColor.GREEN)


func _add_tile_model(tile_node: Node3D, color: TileColor) -> void:
	var old_model = tile_node.get_node_or_null("Model")
	if old_model:
		tile_node.remove_child(old_model)
		old_model.queue_free()

	var fbx_path = "res://assets/terrains/floor/tile_green.fbx" if color == TileColor.GREEN else "res://assets/terrains/floor/tile_red.fbx"
	var fbx_scene = load(fbx_path)
	if fbx_scene:
		var model = fbx_scene.instantiate()
		model.name = "Model"
		model.scale = Vector3.ONE * TILE_SPACING
		tile_node.add_child(model)
		if multiplayer.is_server():
			model.owner = get_tree().edited_scene_root
	else:
		print("Failed to load FBX: ", fbx_path)


func _randomize_tiles() -> void:
	for i in range(tiles.size()):
		tile_colors[i] = TileColor.GREEN if randf() > 0.5 else TileColor.RED
	sync_all_tile_colors.rpc(tile_colors)


func _drop_red_tiles() -> void:
	var red_indices: Array[int] = []
	for i in range(tile_colors.size()):
		if tile_colors[i] == TileColor.RED:
			red_indices.append(i)

	drop_tiles_rpc.rpc(red_indices)


func _reset_all_tiles() -> void:
	reset_tiles_rpc.rpc()
	cycle_timer = CYCLE_DURATION
	reset_scheduled = false
	is_dropping = false


func _schedule_reset_tiles() -> void:
	if reset_scheduled:
		return
	reset_scheduled = true
	await get_tree().create_timer(2.0).timeout
	if state == GameState.PLAYING and is_inside_tree():
		_reset_all_tiles()


@rpc("authority", "call_local", "reliable")
func reset_tiles_rpc() -> void:
	if not is_inside_tree():
		return
	for tile in tiles:
		if tile and is_instance_valid(tile):
			tile.visible = true
			tile.position.y = 0.0
			var static_body = tile.get_node_or_null("StaticBody")
			if static_body:
				var collision = static_body.get_node_or_null("CollisionShape3D")
				if collision:
					collision.disabled = false


func _create_walls() -> void:
	var walls_data = [
		{"name": "WallLeft", "pos": Vector3(-8.1, 0, 0), "size": Vector3(0.4, 2, 12.6)},
		{"name": "WallRight", "pos": Vector3(8.1, 0, 0), "size": Vector3(0.4, 2, 12.6)},
		{"name": "WallFront", "pos": Vector3(0, 0, -6.3), "size": Vector3(16.2, 2, 0.4)},
		{"name": "WallBack", "pos": Vector3(0, 0, 6.3), "size": Vector3(16.2, 2, 0.4)},
	]

	for wall_data in walls_data:
		var wall = StaticBody3D.new()
		wall.name = wall_data["name"]
		wall.position = wall_data["pos"]
		add_child(wall)

		var collision_shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = wall_data["size"]
		collision_shape.shape = box_shape
		wall.add_child(collision_shape)


@rpc("authority", "unreliable")
func sync_cycle_timer(time_left: float) -> void:
	if not is_inside_tree() or multiplayer.is_server():
		return
	cycle_timer = time_left


@rpc("authority", "call_local", "reliable")
func trigger_crumble_warning_rpc() -> void:
	if not is_inside_tree():
		return
	if AudioManager:
		AudioManager.play_tile_crumble(Vector3.ZERO)


@rpc("authority", "call_local", "reliable")
func sync_all_tile_colors(colors: Array[int]) -> void:
	if not is_inside_tree():
		return
	if AudioManager:
		AudioManager.play_tile_flip()
	tile_colors = colors
	for i in range(mini(tiles.size(), colors.size())):
		var tile = tiles[i]
		if tile and is_instance_valid(tile):
			_add_tile_model(tile, colors[i])


@rpc("authority", "call_local", "reliable")
func sync_tile_color(tile_idx: int, color: int) -> void:
	if not is_inside_tree():
		return
	if tile_idx < 0 or tile_idx >= tiles.size():
		return
	if tile_idx < tile_colors.size():
		tile_colors[tile_idx] = color
		var tile = tiles[tile_idx]
		if tile and is_instance_valid(tile):
			_add_tile_model(tile, color)


@rpc("authority", "call_local", "reliable")
func drop_tiles_rpc(red_indices: Array[int]) -> void:
	if not is_inside_tree():
		return
	if AudioManager:
		AudioManager.play_tile_fall(Vector3.ZERO)
	for idx in red_indices:
		if idx >= 0 and idx < tiles.size():
			var tile = tiles[idx]
			if tile and is_instance_valid(tile):
				var static_body = tile.get_node_or_null("StaticBody")
				if static_body:
					var collision = static_body.get_node_or_null("CollisionShape3D")
					if collision:
						collision.disabled = true

	var tweens: Array = []
	for idx in red_indices:
		if idx >= 0 and idx < tiles.size():
			var tile = tiles[idx]
			if tile and is_instance_valid(tile):
				var tween = create_tween()
				tween.set_ease(Tween.EASE_IN)
				tween.set_trans(Tween.TRANS_QUAD)
				tween.tween_property(tile, "position:y", -20.0, 0.8)
				tweens.append(tween)

	if tweens.size() > 0:
		await tweens[tweens.size() - 1].finished

	for idx in red_indices:
		if idx >= 0 and idx < tiles.size():
			var tile = tiles[idx]
			if tile and is_instance_valid(tile):
				tile.visible = false


func _on_fall_detected(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	if body.is_in_group("player"):
		var peer_id = int(str(body.name))
		if peer_id in player_states and player_states[peer_id].alive:
			play_player_fall_rpc.rpc(body.global_position)
			player_died(peer_id)


@rpc("authority", "call_local", "reliable")
func play_player_fall_rpc(pos: Vector3) -> void:
	if not is_inside_tree():
		return
	if AudioManager:
		AudioManager.play_player_fall(pos)


func _check_game_over() -> void:
	if state != GameState.PLAYING or not multiplayer.is_server():
		return
	var alive_ids = get_alive_player_ids()
	var total_players = player_states.size()
	if total_players >= 2:
		if alive_ids.size() == 1:
			end_game_winner(alive_ids[0])
		elif alive_ids.size() == 0:
			end_game_timeout()
	else:
		if alive_ids.size() == 0:
			end_game_timeout()
