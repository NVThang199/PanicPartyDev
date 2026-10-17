extends Node3D

enum GameState { INITIALIZING, PLAYING, ENDED }

const PLAYER_SCENE = preload("res://scenes/players/player.tscn")
const BOMB_SCENE = preload("res://scenes/minigames/bomb.tscn")
const MATCH_DURATION = 60.0
const BOMB_DURATION = 15.0

var state: GameState = GameState.INITIALIZING
var players: Dictionary = {}  # peer_id -> player node
var player_states: Dictionary = {}  # peer_id -> {alive: bool, death_timer: float, name: String}
var bomb: Node = null
var current_bomb_holder: int = -1
var match_timer: float = MATCH_DURATION

@onready var match_timer_label: Label = $UI/MatchTimerLabel
@onready var bomb_timer_label: Label = $UI/BombTimerLabel
@onready var winner_banner: PanelContainer = $UI/WinnerBanner
@onready var winner_label: Label = $UI/WinnerBanner/Margin/VBox/WinnerLabel
@onready var return_button: Button = $UI/WinnerBanner/Margin/VBox/ReturnButton
@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

func _ready() -> void:
	if nav_region:
		nav_region.bake_navigation_mesh(false)

	if winner_banner:
		winner_banner.visible = false
	if return_button:
		return_button.pressed.connect(_on_return_pressed)

	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if multiplayer.is_server():
		call_deferred("initialize_game")

func initialize_game() -> void:
	var minigame_data = GameSession.minigame_players
	if minigame_data.is_empty():
		push_error("[HotBomb] No player data from GameSession")
		return

	# Spawn players
	var spawn_positions = [
		Vector3(-8, 0.5, -8),
		Vector3(8, 0.5, -8),
		Vector3(-8, 0.5, 8),
		Vector3(8, 0.5, 8)
	]
	var idx = 0

	for peer_id in minigame_data:
		var info = minigame_data[peer_id]
		spawn_player(peer_id, info.character, info.name, info.steam_id, spawn_positions[idx % spawn_positions.size()])
		player_states[peer_id] = {
			"alive": true,
			"death_timer": 0.0,
			"name": info.name
		}
		idx += 1

	# Random first bomb holder
	var alive_ids = get_alive_player_ids()
	if alive_ids.size() > 0:
		current_bomb_holder = alive_ids[randi() % alive_ids.size()]
		spawn_bomb(current_bomb_holder)

	state = GameState.PLAYING
	sync_game_state.rpc()

@rpc("authority", "call_local", "reliable")
func spawn_player(peer_id: int, character_path: String, player_name: String, steam_id: int, pos: Vector3) -> void:
	var player = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.position = pos
	player.set_multiplayer_authority(peer_id)
	player.set_player_name(player_name)
	player.steam_id = steam_id
	player.add_to_group("player")
	add_child(player)
	players[peer_id] = player

	if character_path:
		player.switch_character(character_path)

func spawn_bomb(holder_id: int) -> void:
	if bomb:
		bomb.queue_free()

	bomb = BOMB_SCENE.instantiate()
	bomb.name = "Bomb"
	bomb.holder_id = holder_id
	bomb.timer = BOMB_DURATION
	bomb.bomb_caught.connect(_on_bomb_caught)
	bomb.bomb_exploded.connect(_on_bomb_exploded)

	var holder = players.get(holder_id)
	if not holder or not is_instance_valid(holder):
		add_child(bomb)
		bomb.state = 2  # HOMING

	current_bomb_holder = holder_id
	sync_bomb_holder.rpc(holder_id)

@rpc("authority", "call_local", "reliable")
func sync_bomb_holder(holder_id: int) -> void:
	if not bomb or not is_instance_valid(bomb):
		bomb = BOMB_SCENE.instantiate()
		bomb.name = "Bomb"
		add_child(bomb)

	current_bomb_holder = holder_id
	var holder = players.get(holder_id)
	if holder and is_instance_valid(holder):
		holder.pick_up_bomb(bomb)
		bomb.attach_to_holder(holder, holder_id)

func _process(delta: float) -> void:
	if state != GameState.PLAYING:
		return

	if multiplayer.is_server():
		match_timer -= delta
		if match_timer <= 0.0:
			end_game_timeout()
			return

		# Death timers
		for peer_id in player_states:
			if not player_states[peer_id].alive:
				player_states[peer_id].death_timer -= delta
				if player_states[peer_id].death_timer <= 0.0:
					remove_dead_player(peer_id)

	# Update UI
	if match_timer_label:
		match_timer_label.text = "Match: %d" % int(max(0, match_timer))
	if bomb_timer_label and bomb and is_instance_valid(bomb):
		bomb_timer_label.text = "Bomb: %d" % int(max(0, bomb.timer))
		sync_bomb_timer.rpc(bomb.timer)

@rpc("authority", "call_local", "reliable")
func sync_game_state() -> void:
	# Lightweight state sync
	pass

@rpc("any_peer", "unreliable")
func sync_player_state(peer_id: int, pos: Vector3, rot_y: float, anim_name: String) -> void:
	if not multiplayer.multiplayer_peer or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if peer_id == multiplayer.get_unique_id():
		return
	if peer_id in players and is_instance_valid(players[peer_id]):
		players[peer_id]._apply_state(pos, rot_y, anim_name)

@rpc("any_peer", "call_local", "reliable")
func request_throw_bomb(direction: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	throw_bomb(sender_id, direction)

func throw_bomb(thrower_id: int, direction: Vector3) -> void:
	if not multiplayer.is_server() or not bomb:
		return

	if current_bomb_holder != thrower_id:
		return

	var thrower = players.get(thrower_id)
	if thrower and thrower.has_method("release_bomb"):
		thrower.release_bomb()

	var throw_origin = (thrower.global_position + Vector3(0, 1.2, 0) + direction.normalized() * 1.0) if thrower else bomb.global_position
	bomb.detach_from_holder()
	bomb.global_position = throw_origin
	if thrower:
		bomb.add_collision_exception_with(thrower)
	bomb.last_thrower_id = thrower_id
	bomb.throw_grace_timer = 0.8
	bomb.throw(direction)
	current_bomb_holder = -1

	throw_bomb_rpc.rpc(thrower_id, throw_origin, direction)

@rpc("authority", "call_local", "reliable")
func throw_bomb_rpc(thrower_id: int, origin: Vector3, direction: Vector3) -> void:
	if not bomb or not is_instance_valid(bomb):
		bomb = BOMB_SCENE.instantiate()
		bomb.name = "Bomb"
		add_child(bomb)

	var thrower = players.get(thrower_id)
	if thrower and thrower.has_method("release_bomb"):
		thrower.release_bomb()

	bomb.detach_from_holder()
	bomb.global_position = origin
	bomb.last_thrower_id = thrower_id
	bomb.throw_grace_timer = 0.8
	bomb.throw(direction)
	current_bomb_holder = -1

func _on_bomb_caught(catcher_id: int) -> void:
	if not multiplayer.is_server():
		return

	current_bomb_holder = catcher_id
	var catcher = players.get(catcher_id)
	if catcher and is_instance_valid(catcher):
		catcher.pick_up_bomb(bomb)

	bomb_caught_rpc.rpc(catcher_id)

@rpc("authority", "call_local", "reliable")
func bomb_caught_rpc(catcher_id: int) -> void:
	if not bomb or not is_instance_valid(bomb):
		bomb = BOMB_SCENE.instantiate()
		bomb.name = "Bomb"
		add_child(bomb)

	current_bomb_holder = catcher_id
	var catcher = players.get(catcher_id)
	if catcher and is_instance_valid(catcher):
		catcher.pick_up_bomb(bomb)
		bomb.attach_to_holder(catcher, catcher_id)

func _on_bomb_exploded(holder_id: int) -> void:
	if not multiplayer.is_server():
		return

	player_died(holder_id)

	var alive_ids = get_alive_player_ids()
	if alive_ids.size() >= 2:
		# Spawn new bomb
		await get_tree().create_timer(0.5).timeout
		current_bomb_holder = alive_ids[randi() % alive_ids.size()]
		spawn_bomb(current_bomb_holder)
	elif alive_ids.size() == 1:
		end_game_winner(alive_ids[0])
	else:
		end_game_timeout()

func player_died(peer_id: int) -> void:
	player_states[peer_id].alive = false
	player_states[peer_id].death_timer = 10.0

	var player = players.get(peer_id)
	if player and is_instance_valid(player):
		player.die_in_minigame()

	player_died_rpc.rpc(peer_id)

@rpc("authority", "call_local", "reliable")
func player_died_rpc(peer_id: int) -> void:
	var player = players.get(peer_id)
	if player and is_instance_valid(player):
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

func get_alive_players() -> Array:
	var alive = []
	for peer_id in get_alive_player_ids():
		if peer_id in players and is_instance_valid(players[peer_id]):
			alive.append(players[peer_id])
	return alive

func end_game_winner(winner_id: int) -> void:
	state = GameState.ENDED
	show_winner_banner.rpc(winner_id)
	_start_auto_return()

func end_game_timeout() -> void:
	state = GameState.ENDED
	var alive = get_alive_player_ids()
	if alive.size() == 1:
		show_winner_banner.rpc(alive[0])
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
			winner_label.text = "DRAW!"

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
	get_tree().change_scene_to_file("res://scenes/core/main.tscn")

@rpc("authority", "unreliable")
func sync_bomb_timer(time_left: float) -> void:
	if multiplayer.is_server():
		return
	if bomb and is_instance_valid(bomb):
		bomb.timer = time_left

func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id in players:
		players[peer_id].queue_free()
		players.erase(peer_id)
	if peer_id in player_states:
		player_states.erase(peer_id)
