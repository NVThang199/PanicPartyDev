extends CharacterBody3D

const SPEED = 5.0
const ROTATION_SPEED = 10.0
const PUSH_RANGE = 2.2
const PUSH_COOLDOWN_TIME = 0.0
var gravity = 9.8

@onready var model: Node3D = $Model
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var current_anim: String = ""
var push_cooldown: float = 0.0
var is_pushing: bool = false
var is_knocked_down: bool = false
var knockback_velocity: Vector3 = Vector3.ZERO

func _ensure_nodes():
	if not model:
		model = get_node_or_null("Model")
	if not anim_player:
		anim_player = get_node_or_null("AnimationPlayer")

func _apply_state(new_pos: Vector3, rot_y: float, anim_name: String) -> void:
	position = new_pos
	if model:
		model.rotation.y = rot_y
	if anim_name and anim_name != current_anim:
		play_anim(anim_name)

@rpc("any_peer", "unreliable")
func sync_state_to_peer(new_pos: Vector3, rot_y: float, anim_name: String) -> void:
	if is_multiplayer_authority():
		return
	_apply_state(new_pos, rot_y, anim_name)

@rpc("any_peer", "reliable")
func request_push(target_peer_id: int, push_dir: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var main_node = get_parent()
	if not main_node or not ("players" in main_node):
		return
	var sender_player = main_node.players.get(sender_id)
	var target_player = main_node.players.get(target_peer_id)
	if not sender_player or not target_player:
		print("[PUSH] Cannot find sender %d or target %d" % [sender_id, target_peer_id])
		return
	var dist = sender_player.global_position.distance_to(target_player.global_position)
	if dist > PUSH_RANGE + 1.5:
		print("[PUSH] Distance check failed: dist=%.2f > %.2f" % [dist, PUSH_RANGE + 1.5])
		return
	print("[PUSH] Server applying push from %d to %d" % [sender_id, target_peer_id])
	if target_peer_id == multiplayer.get_unique_id():
		target_player.apply_knockback(push_dir)
	else:
		target_player.apply_knockback.rpc_id(target_peer_id, push_dir)

@rpc("any_peer", "call_local", "reliable")
func apply_knockback(push_dir: Vector3) -> void:
	if not is_multiplayer_authority():
		return
	if not multiplayer.is_server() and multiplayer.get_remote_sender_id() != 1:
		return
	knockback_velocity = push_dir.normalized() * 5.0
	if is_knocked_down:
		return
	is_knocked_down = true
	is_pushing = false
	velocity = Vector3.ZERO
	play_anim("simulation/Sit_Floor_Down")
	if anim_player:
		await anim_player.animation_finished
	play_anim("simulation/Sit_Floor_StandUp")
	if anim_player:
		await anim_player.animation_finished
	is_knocked_down = false
	play_anim("general/Idle_A")

func _find_push_target() -> Node:
	var main_node = get_parent()
	if not main_node or not ("players" in main_node):
		return null
	var forward = model.global_transform.basis.z if model else global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	
	var closest_target: Node = null
	var min_dist = PUSH_RANGE
	for pid in main_node.players:
		if pid == multiplayer.get_unique_id():
			continue
		var other = main_node.players[pid]
		if not is_instance_valid(other):
			continue
		var to_other = other.global_position - global_position
		to_other.y = 0.0
		var dist = to_other.length()
		if dist <= PUSH_RANGE and dist > 0.001:
			var dir = to_other.normalized()
			if forward.dot(dir) > 0.1 or dist < 0.8:
				if dist < min_dist:
					min_dist = dist
					closest_target = other
	return closest_target

func perform_push() -> void:
	if is_pushing or is_knocked_down or push_cooldown > 0.0:
		return
	is_pushing = true
	push_cooldown = PUSH_COOLDOWN_TIME
	play_anim("combat/Melee_Unarmed_Attack_Kick", true)
	
	var target = _find_push_target()
	if target:
		var push_dir = (target.global_position - global_position)
		push_dir.y = 0.0
		if push_dir.length_squared() < 0.001:
			push_dir = model.global_transform.basis.z if model else global_transform.basis.z
			push_dir.y = 0.0
		push_dir = push_dir.normalized()
		var target_id = int(str(target.name))
		print("[PUSH] perform_push found target %d (is_server=%s)" % [target_id, multiplayer.is_server()])
		if multiplayer.is_server():
			if target_id == multiplayer.get_unique_id():
				target.apply_knockback(push_dir)
			else:
				target.apply_knockback.rpc_id(target_id, push_dir)
		else:
			request_push.rpc_id(1, target_id, push_dir)
	else:
		print("[PUSH] perform_push: No target found in front")
			
	if anim_player:
		await anim_player.animation_finished
	else:
		await get_tree().create_timer(1.0).timeout
	is_pushing = false
	push_cooldown = 0.0
	if not is_knocked_down and current_anim == "combat/Melee_Unarmed_Attack_Kick":
		play_anim("general/Idle_A")

func _physics_process(delta):
	_ensure_nodes()
	if multiplayer.multiplayer_peer == null:
		return
	
	var has_authority = is_multiplayer_authority()
	
	if has_authority:
		if push_cooldown > 0.0:
			push_cooldown -= delta
			
		if not is_on_floor():
			velocity.y -= gravity * delta

		if Input.is_key_pressed(KEY_E):
			perform_push()

		if is_knocked_down:
			velocity.x = knockback_velocity.x
			velocity.z = knockback_velocity.z
			knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 15.0 * delta)
		elif is_pushing:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
		else:
			var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
			if input_dir == Vector2.ZERO:
				if Input.is_key_pressed(KEY_W):
					input_dir.y -= 1
				if Input.is_key_pressed(KEY_S):
					input_dir.y += 1
				if Input.is_key_pressed(KEY_A):
					input_dir.x -= 1
				if Input.is_key_pressed(KEY_D):
					input_dir.x += 1
				input_dir = input_dir.normalized()

			var direction = Vector3(input_dir.x, 0, input_dir.y)

			if direction != Vector3.ZERO:
				velocity.x = direction.x * SPEED
				velocity.z = direction.z * SPEED
				if model:
					var target_rotation = atan2(direction.x, direction.z)
					model.rotation.y = lerp_angle(model.rotation.y, target_rotation, ROTATION_SPEED * delta)
				play_anim("movement/Walking_A")
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)
				velocity.z = move_toward(velocity.z, 0, SPEED)
				play_anim("general/Idle_A")

		move_and_slide()
		if multiplayer.multiplayer_peer != null:
			var rot_y: float = model.rotation.y if model else 0.0
			sync_state_to_peer.rpc(position, rot_y, current_anim)

func _ready():
	_ensure_nodes()
	# Camera is managed by main.tscn, not here
	if anim_player:
		if not anim_player.has_animation_library("movement"):
			var move_lib = load("res://assets/animations/movement_animations.res")
			if move_lib:
				anim_player.add_animation_library("movement", move_lib)
		if not anim_player.has_animation_library("general"):
			var gen_lib = load("res://assets/animations/general_animations.res")
			if gen_lib:
				anim_player.add_animation_library("general", gen_lib)
		if not anim_player.has_animation_library("combat"):
			var combat_lib = load("res://assets/animations/combat_animations.res")
			if combat_lib:
				anim_player.add_animation_library("combat", combat_lib)
		if not anim_player.has_animation_library("simulation"):
			var sim_lib = load("res://assets/animations/simulation_animations.res")
			if sim_lib:
				anim_player.add_animation_library("simulation", sim_lib)
	play_anim("general/Idle_A")

func play_anim(anim_name: String, force_restart: bool = false):
	_ensure_nodes()
	if anim_player and anim_player.has_animation(anim_name):
		if current_anim != anim_name or force_restart:
			anim_player.stop()
			anim_player.play(anim_name)
			current_anim = anim_name

func switch_character(glb_path: String):
	_ensure_nodes()
	if model:
		model.queue_free()
	var new_scene = load(glb_path)
	if not new_scene:
		return
	var new_model = new_scene.instantiate()
	new_model.name = "Model"
	add_child(new_model)
	model = new_model
	if anim_player:
		anim_player.root_node = anim_player.get_path_to(model)
	current_anim = ""
	await get_tree().process_frame
	play_anim("general/Idle_A")
