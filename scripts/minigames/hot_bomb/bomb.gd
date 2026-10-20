extends CharacterBody3D

enum State { HELD, THROWN, HOMING, RUSHING }

signal bomb_caught(catcher_id: int)
signal bomb_exploded(holder_id: int)

var state: State = State.HELD
var holder_id: int = -1
var target_player: Node = null
var timer: float = 15.0
var throw_velocity: Vector3 = Vector3.ZERO
var last_thrower_id: int = -1
var throw_grace_timer: float = 0.0
var tick_timer: float = 0.0

# Client-side interpolation
var _client_target_pos: Vector3 = Vector3.ZERO
var _client_interp_speed: float = 15.0

const HOMING_SPEED = 7.5
const RUSH_SPEED = 26.0
const THROW_SPEED = 10.0
const GRAVITY = 9.8
const BOUNCE_DAMPING = 0.4

@onready var model: Node3D = $Model
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var explosion_particles: GPUParticles3D = $ExplosionParticles
@onready var catch_area: Area3D = $CatchArea
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
var anim_player: AnimationPlayer = null

func _ready() -> void:
	if catch_area:
		catch_area.body_entered.connect(_on_body_entered)
	if model:
		anim_player = model.get_node_or_null("AnimationPlayer")
	_update_animation()

func _update_animation() -> void:
	if not anim_player:
		return
	var target_anim = "run"
	if state == State.HELD:
		target_anim = "held" if anim_player.has_animation("held") else "run"
	elif state == State.HOMING or state == State.RUSHING or state == State.THROWN:
		target_anim = "run"

	if anim_player.has_animation(target_anim):
		var anim = anim_player.get_animation(target_anim)
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR
		if anim_player.current_animation != target_anim:
			anim_player.play(target_anim)

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	var has_peer = multiplayer and multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	var is_server = multiplayer.is_server() if has_peer else true

	# Bomb ticking sound plays for everyone
	if state != State.RUSHING:
		tick_timer -= delta
		var tick_interval = 0.25 if timer <= 4.0 else 1.0
		if tick_timer <= 0.0:
			tick_timer = tick_interval
			if AudioManager:
				AudioManager.play_bomb_tick(global_position, timer <= 4.0)

	if not is_server:
		timer -= delta
		if state == State.HELD:
			_update_held_transform()
		elif _client_target_pos != Vector3.ZERO:
			var interp_speed = 35.0 if state == State.RUSHING else _client_interp_speed
			var old_pos = global_position
			global_position = global_position.lerp(_client_target_pos, interp_speed * delta)
			var diff = global_position - old_pos
			diff.y = 0.0
			if diff.length_squared() > 0.0001:
				var target_rot_y = atan2(diff.x, diff.z) + PI
				rotation.y = lerp_angle(rotation.y, target_rot_y, 10.0 * delta)
			_update_animation()
		return

	timer -= delta

	# Timer expired: nếu trên tay thì nổ ngay, nếu đang rơi/lăn thì lao siêu nhanh tới người gần nhất
	if timer <= 0.0:
		if state == State.HELD:
			explode()
			return
		elif state != State.RUSHING:
			state = State.RUSHING
			if AudioManager:
				AudioManager.play_bomb_rush(global_position)
			if has_peer and is_inside_tree():
				var minigame = get_parent()
				if minigame and ("synced_peers" in minigame):
					for pid in minigame.synced_peers:
						if pid != 1:
							sync_bomb_state.rpc_id(pid, global_position, state)
			update_target()
			if not target_player or not is_instance_valid(target_player):
				explode()
				return

	if throw_grace_timer > 0.0:
		throw_grace_timer -= delta
		if throw_grace_timer <= 0.0 and last_thrower_id != -1:
			var minigame = get_parent()
			if minigame and ("players" in minigame):
				var thrower = minigame.players.get(last_thrower_id)
				if thrower and is_instance_valid(thrower):
					remove_collision_exception_with(thrower)

	match state:
		State.HELD:
			_update_held_transform()

		State.THROWN:
			throw_velocity.y -= GRAVITY * delta
			var collision = move_and_collide(throw_velocity * delta)
			if collision:
				var collider = collision.get_collider()
				if collider and collider.is_in_group("player"):
					var peer_id = int(str(collider.name))
					if peer_id != last_thrower_id or throw_grace_timer <= 0.0:
						bomb_caught.emit(peer_id)
						return
				throw_velocity = throw_velocity.bounce(collision.get_normal()) * BOUNCE_DAMPING
				if AudioManager:
					AudioManager.play_bomb_bounce(global_position)
				if throw_velocity.length() < 2.0:
					state = State.HOMING
					_update_animation()

		State.HOMING:
			_homing_process(delta)

		State.RUSHING:
			_rush_process(delta)

	if state != State.HELD and is_inside_tree() and has_peer:
		var minigame = get_parent()
		if minigame and ("synced_peers" in minigame):
			for pid in minigame.synced_peers:
				if pid != 1:
					sync_bomb_state.rpc_id(pid, global_position, state)

func _rush_process(_delta: float) -> void:
	update_target()
	if not target_player or not is_instance_valid(target_player):
		explode()
		return

	var dist = global_position.distance_to(target_player.global_position)
	if dist <= 1.0:
		holder_id = int(str(target_player.name))
		global_position = target_player.global_position + Vector3(0, 0.8, 0)
		explode()
		return

	_move_towards_target(RUSH_SPEED)

	for i in range(get_slide_collision_count()):
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider and collider.is_in_group("player"):
			holder_id = int(str(collider.name))
			explode()
			return

func _homing_process(_delta: float) -> void:
	update_target()
	if not target_player or not is_instance_valid(target_player):
		return

	_move_towards_target(HOMING_SPEED)

	# Bắt người chơi nếu va chạm lúc đang lướt
	for i in range(get_slide_collision_count()):
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider and collider.is_in_group("player"):
			var peer_id = int(str(collider.name))
			if peer_id != holder_id:
				bomb_caught.emit(peer_id)
				return

func _move_towards_target(speed: float) -> void:
	var move_dir := Vector3.ZERO
	if nav_agent:
		nav_agent.target_position = target_player.global_position
		if not nav_agent.is_navigation_finished():
			var next_path_pos = nav_agent.get_next_path_position()
			var to_next = next_path_pos - global_position
			to_next.y = 0.0
			if to_next.length_squared() > 0.01:
				move_dir = to_next.normalized()

	if move_dir == Vector3.ZERO:
		var direct_dir = target_player.global_position - global_position
		direct_dir.y = 0.0
		move_dir = direct_dir.normalized() if direct_dir.length_squared() > 0.01 else Vector3.ZERO

	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed
	velocity.y = -GRAVITY
	if move_dir.length_squared() > 0.01:
		var target_rot_y = atan2(move_dir.x, move_dir.z) + PI
		rotation.y = lerp_angle(rotation.y, target_rot_y, 10.0 * get_physics_process_delta_time())
	move_and_slide()

@rpc("authority", "unreliable")
func sync_bomb_state(pos: Vector3, new_state: int) -> void:
	if not is_inside_tree():
		return
	if multiplayer.is_server():
		return
	if new_state == State.RUSHING and state != State.RUSHING:
		if AudioManager:
			AudioManager.play_bomb_rush(global_position)
	state = new_state as State
	_update_animation()
	if state != State.HELD:
		_client_target_pos = pos

func update_target() -> void:
	var minigame = get_parent()
	if not minigame or not minigame.has_method("get_alive_players"):
		return

	var alive_players = minigame.get_alive_players()
	var closest: Node = null
	var min_dist = INF

	for player in alive_players:
		if not is_instance_valid(player):
			continue
		var dist = global_position.distance_to(player.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = player

	target_player = closest

func throw(direction: Vector3) -> void:
	state = State.THROWN
	_update_animation()
	var throw_dir = (direction.normalized() + Vector3(0, 0.35, 0)).normalized()
	throw_velocity = throw_dir * 12.0
	throw_grace_timer = 0.8
	set_physics_process(true)

func attach_to_holder(_player: Node, peer_id: int) -> void:
	state = State.HELD
	_update_animation()
	holder_id = peer_id
	last_thrower_id = -1
	throw_grace_timer = 0.0
	set_physics_process(true)
	for p in get_collision_exceptions():
		remove_collision_exception_with(p)
	_update_held_transform()

func detach_from_holder() -> void:
	holder_id = -1

func _update_held_transform() -> void:
	var holder = _get_holder_player()
	if holder and is_instance_valid(holder):
		var socket = holder.get_hand_socket() if holder.has_method("get_hand_socket") else null
		if socket and is_instance_valid(socket):
			global_position = socket.global_position + socket.global_transform.basis * Vector3(0, 0.05, 0)
			global_rotation = socket.global_rotation
		else:
			global_position = holder.global_position + Vector3(0, 1.0, 0)

func _get_holder_player() -> Node:
	if holder_id == -1:
		return null
	var minigame = get_parent()
	if minigame and ("players" in minigame):
		return minigame.players.get(holder_id)
	return null

func explode() -> void:
	set_physics_process(false)
	if catch_area:
		catch_area.set_deferred("monitoring", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	var has_peer = multiplayer and multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	if has_peer:
		if multiplayer.is_server():
			explode_rpc()
			var minigame = get_parent()
			if minigame and ("synced_peers" in minigame):
				for pid in minigame.synced_peers:
					if pid != 1:
						explode_rpc.rpc_id(pid)
	else:
		explode_rpc()
	bomb_exploded.emit(holder_id)

@rpc("authority", "call_local", "reliable")
func explode_rpc() -> void:
	if AudioManager:
		AudioManager.play_bomb_explode(global_position)
	if model:
		model.visible = false
	if catch_area:
		catch_area.monitoring = false
	if collision_shape:
		collision_shape.disabled = true
	if explosion_particles:
		var arena = get_parent()
		if arena and is_inside_tree():
			var p_pos = explosion_particles.global_position
			explosion_particles.reparent(arena, true)
			explosion_particles.global_position = p_pos
			explosion_particles.restart()
			explosion_particles.emitting = true
			get_tree().create_timer(2.0).timeout.connect(func():
				if is_instance_valid(explosion_particles):
					explosion_particles.queue_free()
			)
		else:
			explosion_particles.restart()
			explosion_particles.emitting = true

func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return

	if body.is_in_group("player"):
		var peer_id = int(str(body.name))
		if peer_id == last_thrower_id and throw_grace_timer > 0.0:
			return
		if state == State.HOMING or state == State.THROWN:
			bomb_caught.emit(peer_id)
