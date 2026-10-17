extends CharacterBody3D

enum State { HELD, THROWN, HOMING }

signal bomb_caught(catcher_id: int)
signal bomb_exploded(holder_id: int)

var state: State = State.HELD
var holder_id: int = -1
var target_player: Node = null
var timer: float = 15.0
var throw_velocity: Vector3 = Vector3.ZERO
var last_thrower_id: int = -1
var throw_grace_timer: float = 0.0

const HOMING_SPEED = 7.5
const THROW_SPEED = 10.0
const GRAVITY = 9.8
const BOUNCE_DAMPING = 0.4

@onready var model: Node3D = $Model
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var explosion_particles: GPUParticles3D = $ExplosionParticles
@onready var catch_area: Area3D = $CatchArea
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

func _ready() -> void:
	if catch_area:
		catch_area.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	timer -= delta

	# Timer expired: snap to nearest and explode
	if timer <= 0.0:
		if state != State.HELD:
			snap_to_nearest_and_explode()
		else:
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
			# Position handled by parent attachment
			pass

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
				if throw_velocity.length() < 2.0:
					state = State.HOMING

		State.HOMING:
			_homing_process(delta)

	if state != State.HELD:
		sync_bomb_state.rpc(global_position, state)

func _homing_process(delta: float) -> void:
	update_target()
	if not target_player or not is_instance_valid(target_player):
		return

	if nav_agent:
		nav_agent.target_position = target_player.global_position
		var next_path_pos = nav_agent.get_next_path_position()
		var move_dir = next_path_pos - global_position
		move_dir.y = 0.0

		if move_dir.length_squared() > 0.01:
			move_dir = move_dir.normalized()
		else:
			var direct_dir = target_player.global_position - global_position
			direct_dir.y = 0.0
			move_dir = direct_dir.normalized()

		velocity.x = move_dir.x * HOMING_SPEED
		velocity.z = move_dir.z * HOMING_SPEED
	else:
		var direct_dir = target_player.global_position - global_position
		direct_dir.y = 0.0
		var move_dir = direct_dir.normalized()
		velocity.x = move_dir.x * HOMING_SPEED
		velocity.z = move_dir.z * HOMING_SPEED

	velocity.y = -GRAVITY
	move_and_slide()

	# Bắt người chơi nếu va chạm lúc đang lướt
	for i in range(get_slide_collision_count()):
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider and collider.is_in_group("player"):
			var peer_id = int(str(collider.name))
			if peer_id != holder_id:
				bomb_caught.emit(peer_id)
				return

@rpc("authority", "unreliable")
func sync_bomb_state(pos: Vector3, new_state: int) -> void:
	if multiplayer.is_server():
		return
	state = new_state as State
	if state != State.HELD:
		global_position = pos

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
	var throw_dir = (direction.normalized() + Vector3(0, 0.35, 0)).normalized()
	throw_velocity = throw_dir * 12.0
	throw_grace_timer = 0.8
	set_physics_process(true)

func attach_to_holder(player: Node, peer_id: int) -> void:
	state = State.HELD
	holder_id = peer_id
	last_thrower_id = -1
	throw_grace_timer = 0.0
	set_physics_process(true)
	for p in get_collision_exceptions():
		remove_collision_exception_with(p)
	_reparent_to_holder.call_deferred(player)

func _reparent_to_holder(player: Node) -> void:
	if not is_instance_valid(player):
		return
	var socket = player.get_hand_socket() if player.has_method("get_hand_socket") else null
	var target_parent = socket if socket else player
	if get_parent() == target_parent:
		return
	if is_inside_tree() and get_parent():
		reparent(target_parent, false)
	else:
		target_parent.add_child(self)
	if socket:
		position = Vector3(0.0, 0.05, 0.0)
	else:
		position = Vector3(-0.31, 0.75, 0.53)
	rotation = Vector3.ZERO

func detach_from_holder() -> void:
	holder_id = -1
	_reparent_to_scene()

func _reparent_to_scene() -> void:
	var current_p = get_parent()
	var minigame = get_tree().current_scene if get_tree() else null
	if not minigame or current_p == minigame:
		return
	reparent(minigame, true)

func snap_to_nearest_and_explode() -> void:
	update_target()
	if target_player and is_instance_valid(target_player):
		holder_id = int(str(target_player.name))
		explode()

func explode() -> void:
	if model:
		model.visible = false
	if explosion_particles:
		explosion_particles.emitting = true

	bomb_exploded.emit(holder_id)

	# Visual effect duration
	await get_tree().create_timer(2.0).timeout
	queue_free()

func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return

	if body.is_in_group("player"):
		var peer_id = int(str(body.name))
		if peer_id == last_thrower_id and throw_grace_timer > 0.0:
			return
		if state == State.HOMING or state == State.THROWN:
			bomb_caught.emit(peer_id)
