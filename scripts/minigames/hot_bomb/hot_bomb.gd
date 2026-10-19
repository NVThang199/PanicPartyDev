class_name HotBomb
extends BaseMinigame

const BOMB_SCENE = preload("res://scenes/minigames/hot_bomb/bomb.tscn")
const BOMB_DURATION = 15.0

var bomb: Node = null
var current_bomb_holder: int = -1
var _last_bomb_countdown_sec: int = -1

@onready var bomb_timer_label: Label = $UI/BombTimerLabel
@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _get_tutorial_data() -> Dictionary:
	return {
		"title": tr("MINIGAME_HOT_BOMB"),
		"rules": tr("HOT_BOMB_RULES"),
		"controls": tr("HOT_BOMB_CONTROLS_HINT"),
		"image": "res://assets/ui/tutorial/hot_bomb.png"
	}


func _get_spawn_positions() -> Array[Vector3]:
	return [
		Vector3(-10, 0.5, -10),
		Vector3(10, 0.5, -10),
		Vector3(-10, 0.5, 10),
		Vector3(10, 0.5, 10)
	]


func _on_post_initialize() -> void:
	pass


func _on_tutorial_finished() -> void:
	if multiplayer.is_server():
		var alive_ids = get_alive_player_ids()
		if alive_ids.size() > 0:
			current_bomb_holder = alive_ids[randi() % alive_ids.size()]
			spawn_bomb(current_bomb_holder)


func _on_minigame_tick(_delta: float) -> void:
	if bomb_timer_label and bomb and is_instance_valid(bomb):
		bomb_timer_label.text = tr("BOMB_TIMER") % int(max(0, bomb.timer))
		if multiplayer.is_server():
			for pid in synced_peers:
				if pid != 1:
					sync_bomb_timer.rpc_id(pid, bomb.timer)

		if bomb.timer > 0.0 and bomb.timer <= 3.0:
			var sec = int(ceil(bomb.timer))
			if sec != _last_bomb_countdown_sec:
				_last_bomb_countdown_sec = sec
				if AudioManager:
					AudioManager.play_countdown_tick()
		else:
			_last_bomb_countdown_sec = -1


func _on_sync_custom_entities(caller_id: int) -> void:
	if current_bomb_holder != -1 and bomb and is_instance_valid(bomb):
		spawn_bomb_rpc.rpc_id(caller_id, current_bomb_holder)
		sync_bomb_timer.rpc_id(caller_id, bomb.timer)


func _on_prepare_return_to_lobby() -> void:
	if bomb and is_instance_valid(bomb):
		bomb.set_physics_process(false)


func spawn_bomb(holder_id: int) -> void:
	if not multiplayer.is_server():
		return
	spawn_bomb_rpc(holder_id)
	for pid in synced_peers:
		if pid != 1:
			spawn_bomb_rpc.rpc_id(pid, holder_id)


@rpc("authority", "call_local", "reliable")
func spawn_bomb_rpc(holder_id: int) -> void:
	var old_bomb = get_node_or_null("Bomb")
	if old_bomb:
		remove_child(old_bomb)
		old_bomb.queue_free()
	if bomb and is_instance_valid(bomb) and bomb != old_bomb:
		if bomb.get_parent():
			bomb.get_parent().remove_child(bomb)
		bomb.queue_free()
	bomb = null

	bomb = BOMB_SCENE.instantiate()
	bomb.name = "Bomb"
	bomb.holder_id = holder_id
	bomb.timer = BOMB_DURATION
	if multiplayer.is_server():
		bomb.bomb_caught.connect(_on_bomb_caught)
		bomb.bomb_exploded.connect(_on_bomb_exploded)
	add_child(bomb)

	current_bomb_holder = holder_id
	var holder = players.get(holder_id)
	if holder and is_instance_valid(holder):
		holder.pick_up_bomb(bomb)
		bomb.attach_to_holder(holder, holder_id)
	else:
		bomb.state = 2  # HOMING


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

	var has_peer = multiplayer and multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	if has_peer:
		throw_bomb_rpc(thrower_id, throw_origin, direction)
		for pid in synced_peers:
			if pid != 1:
				throw_bomb_rpc.rpc_id(pid, thrower_id, throw_origin, direction)
	else:
		throw_bomb_rpc(thrower_id, throw_origin, direction)


@rpc("authority", "call_local", "reliable")
func throw_bomb_rpc(thrower_id: int, origin: Vector3, direction: Vector3) -> void:
	if not is_inside_tree():
		return
	if not bomb or not is_instance_valid(bomb):
		bomb = BOMB_SCENE.instantiate()
		bomb.name = "Bomb"
		add_child(bomb)
	elif not bomb.is_inside_tree():
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
	if AudioManager:
		AudioManager.play_bomb_throw(origin)


func _on_bomb_caught(catcher_id: int) -> void:
	if not multiplayer.is_server():
		return

	current_bomb_holder = catcher_id
	var catcher = players.get(catcher_id)
	if catcher and is_instance_valid(catcher):
		catcher.pick_up_bomb(bomb)

	var has_peer = multiplayer and multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	if has_peer:
		bomb_caught_rpc(catcher_id)
		for pid in synced_peers:
			if pid != 1:
				bomb_caught_rpc.rpc_id(pid, catcher_id)
	else:
		bomb_caught_rpc(catcher_id)


@rpc("authority", "call_local", "reliable")
func bomb_caught_rpc(catcher_id: int) -> void:
	if not is_inside_tree():
		return
	if not bomb or not is_instance_valid(bomb):
		bomb = BOMB_SCENE.instantiate()
		bomb.name = "Bomb"
		add_child(bomb)
	elif not bomb.is_inside_tree():
		add_child(bomb)

	current_bomb_holder = catcher_id
	var catcher = players.get(catcher_id)
	if catcher and is_instance_valid(catcher):
		catcher.pick_up_bomb(bomb)
		bomb.attach_to_holder(catcher, catcher_id)
		if AudioManager:
			AudioManager.play_bomb_catch(catcher.global_position)


func _on_bomb_exploded(holder_id: int) -> void:
	if not multiplayer.is_server():
		return

	player_died(holder_id)

	var alive_ids = get_alive_player_ids()
	if alive_ids.size() >= 2:
		await get_tree().create_timer(0.5).timeout
		current_bomb_holder = alive_ids[randi() % alive_ids.size()]
		spawn_bomb(current_bomb_holder)
	elif alive_ids.size() == 1:
		end_game_winner(alive_ids[0])
	else:
		end_game_timeout()


func _on_player_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server() or state != GameState.PLAYING:
		return
	if current_bomb_holder == peer_id:
		var alive_ids = get_alive_player_ids()
		if alive_ids.size() >= 2:
			current_bomb_holder = alive_ids[randi() % alive_ids.size()]
			spawn_bomb(current_bomb_holder)
		elif alive_ids.size() == 1:
			end_game_winner(alive_ids[0])
		else:
			end_game_timeout()


@rpc("authority", "unreliable")
func sync_bomb_timer(time_left: float) -> void:
	if multiplayer.is_server():
		return
	if bomb and is_instance_valid(bomb):
		bomb.timer = time_left
	if bomb_timer_label:
		bomb_timer_label.text = tr("BOMB_TIMER") % int(max(0, time_left))
