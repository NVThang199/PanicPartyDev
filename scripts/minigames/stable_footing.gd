extends Node3D

enum GameState { INITIALIZING, PLAYING, ENDED }
enum TileColor { GREEN, RED }

const PLAYER_SCENE = preload("res://scenes/players/player.tscn")
const TILE_GREEN_SCENE = preload("res://assets/terrains/floor/tile_green.fbx")
const TILE_RED_SCENE = preload("res://assets/terrains/floor/tile_red.fbx")

const MATCH_DURATION = 60.0
const CYCLE_DURATION = 8.0
const RANDOM_PHASE = 5.0
const LOCK_PHASE = 3.0
const GRID_SIZE = 8
const TILE_SPACING = 1.2
const TILE_FLIP_INTERVAL = 0.3

var state: GameState = GameState.INITIALIZING
var players: Dictionary = {}
var player_states: Dictionary = {}
var tiles: Array[Node3D] = []
var tile_colors: Array[int] = []

var match_timer: float = MATCH_DURATION
var cycle_timer: float = CYCLE_DURATION
var flip_timer: float = 0.0
var is_random_phase: bool = true
var is_dropping: bool = false
var reset_scheduled: bool = false

@onready var match_timer_label: Label = $UI/MatchTimerLabel
@onready var cycle_timer_label: Label = $UI/CycleTimerLabel
@onready var winner_banner: PanelContainer = $UI/WinnerBanner
@onready var winner_label: Label = $UI/WinnerBanner/Margin/VBox/WinnerLabel
@onready var return_button: Button = $UI/WinnerBanner/Margin/VBox/ReturnButton
@onready var fall_detector: Area3D = $FallDetector
@onready var tile_grid: Node3D = $TileGrid

func _ready() -> void:
	if winner_banner:
		winner_banner.visible = false
	if return_button:
		return_button.pressed.connect(_on_return_pressed)

	if fall_detector:
		fall_detector.body_exited.connect(_on_body_exited)

	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Generate grid if empty
	if tile_grid and tile_grid.get_child_count() == 0:
		_generate_tile_grid()
	else:
		_collect_existing_tiles()

	if multiplayer.is_server():
		call_deferred("initialize_game")
	else:
		request_game_sync.rpc_id(1)

func initialize_game() -> void:
	var minigame_data = GameSession.minigame_players
	if minigame_data.is_empty():
		push_error("[StableFooting] No player data from GameSession")
		return

	# Tiles already exist in scene
	if tiles.is_empty():
		push_error("[StableFooting] No tiles found in scene")
		return

	# Spawn players at center
	var center_x = -(GRID_SIZE / 2.0) * TILE_SPACING + TILE_SPACING / 2.0
	var center_z = -(GRID_SIZE / 2.0) * TILE_SPACING + TILE_SPACING / 2.0
	var center_pos = Vector3(center_x, 1.0, center_z)

	var spawn_positions = [
		center_pos + Vector3(-0.5, 0, -0.5),
		center_pos + Vector3(0.5, 0, -0.5),
		center_pos + Vector3(-0.5, 0, 0.5),
		center_pos + Vector3(0.5, 0, 0.5)
	]
	var idx = 0

	for peer_id in minigame_data:
		var info = minigame_data[peer_id]
		spawn_player.rpc(peer_id, info.character, info.name, info.steam_id, spawn_positions[idx % spawn_positions.size()])
		player_states[peer_id] = {
			"alive": true,
			"death_timer": 0.0,
			"name": info.name
		}
		idx += 1

	state = GameState.PLAYING
	sync_game_state.rpc(GameState.PLAYING)
	_randomize_tiles()

func _generate_tile_grid() -> void:
	if not tile_grid:
		return

	for i in range(GRID_SIZE):
		for j in range(GRID_SIZE):
			var tile_node = Node3D.new()
			tile_node.name = "Tile_%d_%d" % [i, j]

			var x = i * TILE_SPACING - (GRID_SIZE / 2.0) * TILE_SPACING + TILE_SPACING / 2.0
			var z = j * TILE_SPACING - (GRID_SIZE / 2.0) * TILE_SPACING + TILE_SPACING / 2.0
			tile_node.position = Vector3(x, 0, z)

			tile_grid.add_child(tile_node)

			var color = TileColor.GREEN if randf() > 0.5 else TileColor.RED
			var fbx = TILE_GREEN_SCENE.instantiate() if color == TileColor.GREEN else TILE_RED_SCENE.instantiate()
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
	# Remove old model if exists
	var old_model = tile_node.get_node_or_null("Model")
	if old_model:
		tile_node.remove_child(old_model)
		old_model.queue_free()

	# Load and add FBX model
	var fbx_path = "res://assets/terrains/floor/tile_green.fbx" if color == TileColor.GREEN else "res://assets/terrains/floor/tile_red.fbx"
	var fbx_scene = load(fbx_path)
	if fbx_scene:
		var model = fbx_scene.instantiate()
		model.name = "Model"
		tile_node.add_child(model)
		# Scale down if needed
		model.scale = Vector3(0.6, 0.6, 0.6)

func _randomize_tiles() -> void:
	for i in range(tiles.size()):
		tile_colors[i] = TileColor.GREEN if randf() > 0.5 else TileColor.RED
		sync_tile_color.rpc(i, tile_colors[i])

func _process(delta: float) -> void:
	if not is_inside_tree():
		return
	if state != GameState.PLAYING:
		return

	if multiplayer.is_server():
		match_timer -= delta
		cycle_timer -= delta
		flip_timer -= delta

		# Check if match ended
		if match_timer <= 0.0:
			end_game_timeout()
			return

		# Handle cycle phases
		if cycle_timer > LOCK_PHASE:
			# Random phase
			is_random_phase = true
			if flip_timer <= 0.0:
				_randomize_tiles()
				flip_timer = TILE_FLIP_INTERVAL
		elif cycle_timer > 0.0:
			# Lock phase
			is_random_phase = false
		elif not is_dropping:
			# Drop phase (trigger once)
			is_dropping = true
			_drop_red_tiles()
			_schedule_reset_tiles()

		sync_match_timer.rpc(match_timer)
		sync_cycle_timer.rpc(cycle_timer)

		# Death timers
		for peer_id in player_states:
			if not player_states[peer_id].alive:
				player_states[peer_id].death_timer -= delta
				if player_states[peer_id].death_timer <= 0.0:
					remove_dead_player(peer_id)

	# Update UI
	if match_timer_label:
		match_timer_label.text = "Match: %d" % int(max(0, match_timer))
	if cycle_timer_label:
		if not is_random_phase and cycle_timer > 0:
			cycle_timer_label.text = "%d" % int(max(0, cycle_timer))
		else:
			cycle_timer_label.text = ""

func _drop_red_tiles() -> void:
	var red_indices: Array[int] = []
	for i in range(tile_colors.size()):
		if tile_colors[i] == TileColor.RED:
			red_indices.append(i)

	drop_tiles_rpc.rpc(red_indices)

	# Check if any player is on red tile
	for peer_id in players:
		var player = players[peer_id]
		if not is_instance_valid(player):
			continue

		var player_pos = player.global_position
		for tile_idx in red_indices:
			var tile = tiles[tile_idx]
			var dist = player_pos.distance_to(tile.global_position)
			if dist < TILE_SPACING / 2.0:
				player_died(peer_id)

func _reset_all_tiles() -> void:
	reset_tiles_rpc.rpc()
	cycle_timer = CYCLE_DURATION
	reset_scheduled = false
	is_dropping = false

func _schedule_reset_tiles() -> void:
	if reset_scheduled:
		return
	reset_scheduled = true
	await get_tree().create_timer(1.5).timeout
	if state == GameState.PLAYING and is_inside_tree():
		_reset_all_tiles()

@rpc("authority", "call_local", "reliable")
func reset_tiles_rpc() -> void:
	for tile in tiles:
		if tile and is_instance_valid(tile):
			tile.visible = true
			tile.position.y = 0
			var static_body = tile.get_node_or_null("StaticBody")
			if static_body:
				var collision = static_body.get_node_or_null("CollisionShape3D")
				if collision:
					collision.disabled = false

@rpc("any_peer", "reliable")
func request_game_sync() -> void:
	if not multiplayer.is_server():
		return
	var caller_id = multiplayer.get_remote_sender_id()
	if caller_id == 0:
		caller_id = multiplayer.get_unique_id()

	sync_game_state.rpc_id(caller_id, state)
	sync_match_timer.rpc_id(caller_id, match_timer)
	sync_cycle_timer.rpc_id(caller_id, cycle_timer)

	for pid in players:
		var p = players[pid]
		if is_instance_valid(p):
			var c_path = p.character_path if "character_path" in p else ""
			var p_name = p.player_name if p.player_name != "" else ("Player %d" % pid)
			spawn_player.rpc_id(caller_id, pid, c_path, p_name, p.steam_id, p.position)

	for i in range(tile_colors.size()):
		sync_tile_color.rpc_id(caller_id, i, tile_colors[i])

@rpc("authority", "call_local", "reliable")
func spawn_player(peer_id: int, character_path: String, player_name: String, steam_id: int, pos: Vector3) -> void:
	if peer_id in players and is_instance_valid(players[peer_id]):
		return
	var old_node = get_node_or_null(str(peer_id))
	if old_node:
		remove_child(old_node)
		old_node.queue_free()

	var player = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.position = pos
	player.set_multiplayer_authority(peer_id)
	player.set_player_name(player_name)
	player.steam_id = steam_id
	player.character_path = character_path
	player.add_to_group("player")
	add_child(player)
	players[peer_id] = player
	player_states[peer_id] = {
		"alive": true,
		"death_timer": 0.0,
		"name": player_name
	}

	if character_path:
		player.switch_character(character_path)

@rpc("authority", "call_local", "reliable")
func sync_game_state(new_state: int) -> void:
	state = new_state as GameState

@rpc("authority", "unreliable")
func sync_match_timer(time_left: float) -> void:
	if multiplayer.is_server():
		return
	match_timer = time_left

@rpc("authority", "unreliable")
func sync_cycle_timer(time_left: float) -> void:
	if multiplayer.is_server():
		return
	cycle_timer = time_left

@rpc("authority", "call_local", "reliable")
func sync_tile_color(tile_idx: int, color: int) -> void:
	if tile_idx < 0 or tile_idx >= tiles.size():
		return
	if tile_idx < tile_colors.size():
		tile_colors[tile_idx] = color
		var tile = tiles[tile_idx]
		if tile and is_instance_valid(tile):
			_add_tile_model(tile, color)

@rpc("authority", "call_local", "reliable")
func drop_tiles_rpc(red_indices: Array[int]) -> void:
	# Disable all red tile collisions immediately
	for idx in red_indices:
		if idx >= 0 and idx < tiles.size():
			var tile = tiles[idx]
			if tile and is_instance_valid(tile):
				var static_body = tile.get_node_or_null("StaticBody")
				if static_body:
					var collision = static_body.get_node_or_null("CollisionShape3D")
					if collision:
						collision.disabled = true

	# Drop all red tiles simultaneously
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

	# Wait for all tweens to finish
	if tweens.size() > 0:
		await tweens[tweens.size() - 1].finished

	# Hide all dropped tiles
	for idx in red_indices:
		if idx >= 0 and idx < tiles.size():
			var tile = tiles[idx]
			if tile and is_instance_valid(tile):
				tile.visible = false

func player_died(peer_id: int) -> void:
	if not is_inside_tree():
		return
	player_states[peer_id].alive = false
	player_states[peer_id].death_timer = 2.0

	player_died_rpc.rpc(peer_id)

@rpc("authority", "call_local", "reliable")
func player_died_rpc(peer_id: int) -> void:
	if not is_inside_tree():
		return
	var player = players.get(peer_id)
	if player and is_instance_valid(player) and player.is_inside_tree():
		player.die_in_minigame()

func remove_dead_player(peer_id: int) -> void:
	var player = players.get(peer_id)
	if player and is_instance_valid(player):
		player.queue_free()
	players.erase(peer_id)

func get_alive_player_ids() -> Array:
	var alive = []
	for peer_id in player_states:
		if player_states[peer_id].alive:
			alive.append(peer_id)
	return alive

func end_game_timeout() -> void:
	state = GameState.ENDED
	var alive = get_alive_player_ids()
	if alive.size() > 0:
		show_winner_banner.rpc(-1)  # Draw / all survivors
	else:
		show_winner_banner.rpc(-1)
	_start_auto_return()

func _start_auto_return() -> void:
	if not multiplayer.is_server():
		return
	await get_tree().create_timer(6.0).timeout
	if state == GameState.ENDED and is_inside_tree():
		return_to_lobby.rpc()

@rpc("authority", "call_local", "reliable")
func show_winner_banner(winner_id: int) -> void:
	if winner_banner:
		winner_banner.visible = true
	if winner_label:
		if winner_id > 0 and winner_id in player_states:
			winner_label.text = "%s WINS!" % player_states[winner_id].name
		else:
			winner_label.text = "SURVIVORS!"

func _on_body_exited(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	if body.is_in_group("player"):
		var peer_id = int(str(body.name))
		if peer_id in players and player_states[peer_id].alive:
			player_died(peer_id)

func _on_return_pressed() -> void:
	if multiplayer.is_server():
		return_to_lobby.rpc()
	else:
		request_return_to_lobby.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func request_return_to_lobby() -> void:
	if multiplayer.is_server() and state == GameState.ENDED:
		return_to_lobby.rpc()

@rpc("authority", "call_local", "reliable")
func return_to_lobby() -> void:
	set_process(false)
	set_physics_process(false)
	for pid in players:
		var p = players[pid]
		if is_instance_valid(p):
			p.set_physics_process(false)
	get_tree().change_scene_to_file("res://scenes/core/main.tscn")

func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id in players:
		players[peer_id].queue_free()
		players.erase(peer_id)
	if peer_id in player_states:
		player_states.erase(peer_id)
