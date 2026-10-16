extends CharacterBody3D

enum State { HELD, THROWN, HOMING }

signal bomb_caught(catcher_id: int)
signal bomb_exploded(holder_id: int)

var state: State = State.HELD
var holder_id: int = -1
var target_player: Node = null
var timer: float = 15.0
var throw_velocity: Vector3 = Vector3.ZERO

const HOMING_SPEED = 7.5
const THROW_SPEED = 10.0
const GRAVITY = 9.8
const BOUNCE_DAMPING = 0.4

@onready var model: Node3D = $Model
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var explosion_particles: GPUParticles3D = $ExplosionParticles
@onready var catch_area: Area3D = $CatchArea

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

	match state:
		State.HELD:
			# Position handled by parent attachment
			pass

		State.THROWN:
			throw_velocity.y -= GRAVITY * delta
			var collision = move_and_collide(throw_velocity * delta)
			if collision:
				throw_velocity = throw_velocity.bounce(collision.get_normal()) * BOUNCE_DAMPING
				if throw_velocity.length() < 2.0:
					state = State.HOMING

		State.HOMING:
			update_target()
			if target_player and is_instance_valid(target_player):
				var dir = (target_player.global_position - global_position)
				dir.y = 0.0
				if dir.length() > 0.1:
					dir = dir.normalized()
					velocity = dir * HOMING_SPEED
					move_and_slide()

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
	throw_velocity = direction.normalized() * THROW_SPEED
	set_physics_process(true)

func attach_to_holder(player: Node, peer_id: int) -> void:
	state = State.HELD
	holder_id = peer_id

	# Reparent to player
	if get_parent():
		get_parent().remove_child(self)
	player.add_child(self)

	# Position at right hand
	position = Vector3(0.5, 1.2, 0.3)
	rotation = Vector3.ZERO

func detach_from_holder() -> void:
	if get_parent() and get_parent().name != "HotBomb":
		var old_global_pos = global_position
		var old_global_rot = global_rotation

		var minigame = get_tree().current_scene
		get_parent().remove_child(self)
		minigame.add_child(self)

		global_position = old_global_pos
		global_rotation = old_global_rot

	holder_id = -1

func snap_to_nearest_and_explode() -> void:
	update_target()
	if target_player and is_instance_valid(target_player):
		holder_id = int(str(target_player.name))
		explode()

func explode() -> void:
	if explosion_particles:
		explosion_particles.emitting = true

	bomb_exploded.emit(holder_id)

	# Visual effect duration
	await get_tree().create_timer(2.0).timeout
	queue_free()

func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return

	if state == State.HOMING and body.is_in_group("player"):
		var peer_id = int(str(body.name))
		if peer_id != holder_id:
			bomb_caught.emit(peer_id)
